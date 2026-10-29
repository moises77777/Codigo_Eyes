import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/traducciones.dart';
import 'storage_service.dart';

/// Una detección del modelo TFLite: etiqueta traducida, la original
/// en inglés, la confianza y la caja en píxeles del frame derecho.
class Deteccion {
  final String etiqueta;
  final String etiquetaOriginal;
  final double confianza;
  final Rect caja;

  const Deteccion({
    required this.etiqueta,
    required this.etiquetaOriginal,
    required this.confianza,
    required this.caja,
  });
}

/// Detector de objetos COCO-80 con EfficientDet-Lite0 (TFLite).
/// Reemplaza a ML Kit: las cajas y clases son por objeto, no de la
/// imagen completa, así que no "alucina" objetos que no están.
class DetectorService {
  DetectorService._();

  static const _assetPreentrenado = 'assets/modelos/preentrenado';
  static const _assetPropio = 'assets/modelos/propio';
  static const _tamEntrada = 320;

  /// Frames seguidos con la misma etiqueta antes de anunciarla.
  static const framesConfirmacion = 3;

  static IsolateInterpreter? _interprete;
  static List<String> _etiquetas = [];
  static bool _esUint8 = true;
  static bool _cargado = false;

  /// Formas reales de los tensores de salida del modelo cargado;
  /// se leen del intérprete en vez de suponer el formato fijo.
  static List<List<int>> _formasSalida = [];

  /// Confianza mínima para considerar una detección (0.5 - 0.9).
  static double umbralConfianza = 0.70;

  /// True si se cargó el modelo propio; false si cayó al preentrenado.
  static bool _usandoPropio = false;
  static bool get usandoPropio => _usandoPropio;
  static bool get cargado => _cargado;

  /// Carga el intérprete y las etiquetas. Si [modeloPropio] falla o sus
  /// etiquetas son el marcador de posición, cae al preentrenado.
  static Future<void> cargar({required bool modeloPropio}) async {
    umbralConfianza = await StorageService.getUmbralConfianza();
    _usandoPropio = false;

    if (modeloPropio) {
      final ok = await _cargarDesde(_assetPropio);
      if (ok && !_etiquetasEsMarcador(_etiquetas)) {
        _usandoPropio = true;
        return;
      }
      debugPrint('Modelo propio no válido, se usa el preentrenado.');
    }
    await _cargarDesde(_assetPreentrenado);
  }

  /// Las etiquetas del marcador solo tienen comentarios: al quitarlos
  /// queda la lista vacía o puro '???'.
  static bool _etiquetasEsMarcador(List<String> etiquetas) {
    return etiquetas.isEmpty ||
        etiquetas.every((e) => e.isEmpty || e == '???');
  }

  static Future<bool> _cargarDesde(String carpeta) async {
    try {
      await _interprete?.close();
      _interprete = null;
      _cargado = false;

      final base = await Interpreter.fromAsset(
        '$carpeta/modelo.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      _interprete = await IsolateInterpreter.create(address: base.address);
      _esUint8 = base.getInputTensor(0).type == TensorType.uint8;
      _formasSalida =
          base.getOutputTensors().map((t) => t.shape).toList();

      _etiquetas = parsearEtiquetas(
        await rootBundle.loadString('$carpeta/etiquetas.txt'),
      );
      _cargado = true;
      debugPrint(
        '[EYES detector] cargado $carpeta '
        '(entrada ${_esUint8 ? 'uint8' : 'float32'}, ${_etiquetas.length} etiquetas)',
      );
      return true;
    } catch (e) {
      debugPrint('Error cargando detector de $carpeta: $e');
      return false;
    }
  }

  /// Parsea etiquetas.txt: una por línea, ignora comentarios '#'.
  static List<String> parsearEtiquetas(String contenido) {
    return contenido
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
  }

  /// Detecta objetos en un [frame] del stream de la cámara.
  /// Convierte YUV420 → RGB 320×320 muestreando directo (sin NV21 ni
  /// decodificar): con stride sale en ~5-15 ms.
  static Future<List<Deteccion>> detectarFrame(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    if (!_cargado || _interprete == null) return const [];
    try {
      final entrada = _frameATensor(frame, sensorOrientation);
      final rotado = sensorOrientation == 90 || sensorOrientation == 270;
      final w = rotado ? frame.height.toDouble() : frame.width.toDouble();
      final h = rotado ? frame.width.toDouble() : frame.height.toDouble();
      return await _inferir(entrada, w, h);
    } catch (e) {
      debugPrint('Error en detector (frame): $e');
      return const [];
    }
  }

  /// Detecta objetos en una foto guardada en [ruta].
  static Future<List<Deteccion>> detectarFoto(String ruta) async {
    if (!_cargado || _interprete == null) return const [];
    try {
      final bytes = await File(ruta).readAsBytes();
      var imagen = img.decodeImage(bytes);
      if (imagen == null) return const [];
      // Aplicar la rotación EXIF: el JPEG del teléfono viene en apaisado
      // con etiqueta de giro; sin esto el objeto llega de lado al modelo.
      imagen = img.bakeOrientation(imagen);
      final original = imagen;
      imagen = img.copyResize(
        original,
        width: _tamEntrada,
        height: _tamEntrada,
      );

      // Mismo buffer reutilizado del stream: evita reservar ~300 mil
      // objetos por foto, que era lo que trababa la vista al analizar.
      _asegurarBuffer();
      final entrada =
          (_esUint8 ? _bufInt![0] : _bufFloat![0]);
      for (var y = 0; y < _tamEntrada; y++) {
        final fila = entrada[y];
        for (var x = 0; x < _tamEntrada; x++) {
          final p = imagen.getPixel(x, y);
          final pixel = fila[x];
          if (_esUint8) {
            pixel[0] = p.r.toInt();
            pixel[1] = p.g.toInt();
            pixel[2] = p.b.toInt();
          } else {
            pixel[0] = p.r / 255;
            pixel[1] = p.g / 255;
            pixel[2] = p.b / 255;
          }
        }
      }
      // El intérprete espera el tensor 4D completo [1,320,320,3].
      return await _inferir(
        _esUint8 ? _bufInt! : _bufFloat!,
        original.width.toDouble(),
        original.height.toDouble(),
      );
    } catch (e) {
      debugPrint('Error en detector (foto): $e');
      return const [];
    }
  }

  /// Corre el intérprete y arma las detecciones traducidas.
  static Future<List<Deteccion>> _inferir(
    Object entrada,
    double anchoReal,
    double altoReal,
  ) async {
    final salidas = <int, Object>{
      for (var i = 0; i < _formasSalida.length; i++)
        i: _crearBuffer(_formasSalida[i]),
    };
    await _interprete!.runForMultipleInputs([entrada], salidas);

    // Identificar salidas por forma, no por índice fijo.
    List<List<double>> outBoxes = const [];
    List<double> outClases = const [];
    List<double> outScores = const [];
    for (final valor in salidas.values) {
      final forma = _formaDe(valor);
      if (forma.length == 3 && forma[2] == 4) {
        outBoxes = _a2d(valor);
      } else if (forma.length == 2) {
        final plana = _a1d(valor);
        // Las clases son enteros pequeños; los scores flotantes 0-1.
        final parecenClases =
            plana.every((v) => v == v.roundToDouble() && v >= 0 && v < 100);
        if (parecenClases && outClases.isEmpty) {
          outClases = plana;
        } else {
          outScores = plana;
        }
      }
    }

    final detecciones = <Deteccion>[];
    for (var i = 0; i < outScores.length && i < outBoxes.length; i++) {
      final score = outScores[i];
      if (score < 0.25) continue; // piso mínimo, el filtrado fino va afuera
      final idx = i < outClases.length ? outClases[i].round() : 0;
      if (idx < 0 || idx >= _etiquetas.length) continue;
      final original = _etiquetas[idx];
      if (original == '???') continue;
      final b = outBoxes[i];
      detecciones.add(Deteccion(
        etiqueta: Traducciones.traducir(original),
        etiquetaOriginal: original,
        confianza: score,
        caja: cajaAPixeles(b[0], b[1], b[2], b[3], anchoReal, altoReal),
      ));
    }
    detecciones.sort((a, b) => b.confianza.compareTo(a.confianza));
    return detecciones;
  }

  /// Crea un buffer anidado de dobles con la forma exacta del tensor.
  static Object _crearBuffer(List<int> forma) {
    if (forma.isEmpty) return <double>[];
    if (forma.length == 1) return List.filled(forma[0], 0.0);
    return List.generate(
      forma[0],
      (_) => _crearBuffer(forma.sublist(1)),
    );
  }

  /// Devuelve la forma (shape) de un tensor de salida simulado o real:
  /// [1,25,4] → [1,25,4], [1,25] → [1,25], [1] → [1].
  static List<int> _formaDe(Object valor) {
    final forma = <int>[];
    Object? actual = valor;
    while (actual is List) {
      forma.add(actual.length);
      actual = actual.isEmpty ? null : actual.first;
    }
    return forma;
  }

  static List<List<double>> _a2d(Object valor) {
    final outer = (valor as List).first as List;
    return outer
        .map((fila) => (fila as List).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  static List<double> _a1d(Object valor) {
    final plana = (valor as List).first as List;
    return plana.map((v) => (v as num).toDouble()).toList();
  }

  /// Convierte una caja normalizada (ymin, xmin, ymax, xmax, 0-1) a
  /// píxeles del frame derecho (el ancho/alto ya vienen intercambiados
  /// si la rotación es 90/270).
  static Rect cajaAPixeles(
    double ymin,
    double xmin,
    double ymax,
    double xmax,
    double ancho,
    double alto,
  ) {
    return Rect.fromLTRB(
      (xmin * ancho).clamp(0, ancho),
      (ymin * alto).clamp(0, alto),
      (xmax * ancho).clamp(0, ancho),
      (ymax * alto).clamp(0, alto),
    );
  }

  /// Buffers de entrada reutilizados: crear una lista anidada de
  /// 320×320×3 por frame generaba ~300 mil objetos y trababa la cámara.
  static List<List<List<List<int>>>>? _bufInt;
  static List<List<List<List<double>>>>? _bufFloat;

  /// Crea el buffer de entrada reutilizable según el tipo del modelo.
  static void _asegurarBuffer() {
    if (_esUint8) {
      _bufInt ??= List.generate(
        1,
        (_) => List.generate(
          _tamEntrada,
          (_) => List.generate(_tamEntrada, (_) => List.filled(3, 0)),
        ),
      );
    } else {
      _bufFloat ??= List.generate(
        1,
        (_) => List.generate(
          _tamEntrada,
          (_) => List.generate(_tamEntrada, (_) => List.filled(3, 0.0)),
        ),
      );
    }
  }

  /// Muestrea un frame YUV420 directo a RGB 320×320, aplicando la
  /// rotación del sensor para que la imagen quede derecha.
  static Object _frameATensor(
    CameraImage frame,
    int sensorOrientation,
  ) {
    final rotado = sensorOrientation == 90 || sensorOrientation == 270;
    final w = rotado ? frame.height : frame.width;
    final h = rotado ? frame.width : frame.height;

    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];
    final uvStride = uPlane.bytesPerPixel ?? 1;

    _asegurarBuffer();
    final entrada = _esUint8 ? _bufInt![0] : _bufFloat![0];

    for (var oy = 0; oy < _tamEntrada; oy++) {
      final fila = entrada[oy];
      for (var ox = 0; ox < _tamEntrada; ox++) {
        // Punto en la imagen derecha → punto en el frame crudo.
        final ux = (ox * w / _tamEntrada).round().clamp(0, w - 1);
        final uy = (oy * h / _tamEntrada).round().clamp(0, h - 1);
        int rx, ry;
        switch (sensorOrientation) {
          case 90:
            rx = uy;
            ry = frame.height - 1 - ux;
          case 270:
            rx = frame.width - 1 - uy;
            ry = ux;
          case 180:
            rx = frame.width - 1 - ux;
            ry = frame.height - 1 - uy;
          default:
            rx = ux;
            ry = uy;
        }
        rx = rx.clamp(0, frame.width - 1);
        ry = ry.clamp(0, frame.height - 1);

        final yv = yPlane.bytes[ry * yPlane.bytesPerRow + rx];
        final uvX = rx ~/ 2;
        final uvY = ry ~/ 2;
        final u = uPlane.bytes[uvY * uPlane.bytesPerRow + uvX * uvStride] - 128;
        final v = vPlane.bytes[uvY * vPlane.bytesPerRow + uvX * uvStride] - 128;

        final pixel = fila[ox];
        if (_esUint8) {
          pixel[0] = (yv + 1.402 * v).round().clamp(0, 255);
          pixel[1] = (yv - 0.344 * u - 0.714 * v).round().clamp(0, 255);
          pixel[2] = (yv + 1.772 * u).round().clamp(0, 255);
        } else {
          pixel[0] = (yv + 1.402 * v).clamp(0, 255) / 255;
          pixel[1] = (yv - 0.344 * u - 0.714 * v).clamp(0, 255) / 255;
          pixel[2] = (yv + 1.772 * u).clamp(0, 255) / 255;
        }
      }
    }
    return _esUint8 ? _bufInt! : _bufFloat!;
  }

  /// Libera el intérprete.
  static Future<void> dispose() async {
    await _interprete?.close();
    _interprete = null;
    _cargado = false;
  }

  /// Marca de prueba: expone el mínimo útil para tests de integración.
  @visibleForTesting
  static bool get esUint8 => _esUint8;

  /// sqrt disponible para helpers de prueba.
  static double distanciaCentro(Rect a, Rect b) {
    final dx = a.center.dx - b.center.dx;
    final dy = a.center.dy - b.center.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
