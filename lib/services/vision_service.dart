import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../utils/traducciones.dart';

/// Resultado simple de la visión artificial local.
class VisionResult {
  final String etiquetaEs;
  final double confianza;
  final String fuente;

  VisionResult({
    required this.etiquetaEs,
    required this.confianza,
    required this.fuente,
  });

  @override
  String toString() {
    return 'VisionResult($etiquetaEs, ${(confianza * 100).toStringAsFixed(0)}%)';
  }
}

/// Combina detección de objetos y etiquetado de imágenes de ML Kit para
/// obtener la mejor etiqueta posible, traducida al español.
class VisionService {
  VisionService._();

  static ObjectDetector? _objectDetector;
  static ImageLabeler? _imageLabeler;

  static ObjectDetector get _detector {
    _objectDetector ??= ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    return _objectDetector!;
  }

  static ImageLabeler get _labeler {
    _imageLabeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.4),
    );
    return _imageLabeler!;
  }

  /// Procesa una foto guardada en [ruta] y devuelve la mejor etiqueta.
  static Future<VisionResult?> identificar(String ruta) async {
    try {
      final inputImage = InputImage.fromFilePath(ruta);
      return _mejorEtiqueta(await _procesar(inputImage));
    } catch (e) {
      debugPrint('Error en VisionService (archivo): $e');
      return null;
    }
  }

  /// Procesa un frame del stream de la cámara en tiempo real.
  /// [sensorOrientation] es la rotación del sensor (90 en la mayoría de teléfonos).
  static Future<VisionResult?> identificarFrame(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    try {
      final bytes = _yuv420ToNv21(frame);
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
      return _mejorEtiqueta(await _procesar(inputImage));
    } catch (e) {
      debugPrint('Error en VisionService (frame): $e');
      return null;
    }
  }

  /// Devuelve TODOS los candidatos detectados en el frame, ya traducidos
  /// al español y sin duplicados (se conserva la mayor confianza de cada
  /// etiqueta). El controlador elige el más relevante con la heurística
  /// de [Prioridades], igual que A* elige el nodo con menor f(n).
  static Future<List<VisionResult>> identificarFrameTodos(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    try {
      final bytes = _yuv420ToNv21(frame);
      final rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
              InputImageRotation.rotation0deg;
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
      return _candidatos(await _procesar(inputImage));
    } catch (e) {
      debugPrint('Error en VisionService (frame todos): $e');
      return const [];
    }
  }

  /// Traduce las etiquetas crudas y quita duplicados conservando la
  /// mayor confianza por etiqueta en español.
  static List<VisionResult> _candidatos(List<_EtiquetaCruda> crudas) {
    final mejores = <String, VisionResult>{};
    for (final e in crudas) {
      final es = Traducciones.traducir(e.texto);
      final previo = mejores[es];
      if (previo == null || e.confianza > previo.confianza) {
        mejores[es] =
            VisionResult(etiquetaEs: es, confianza: e.confianza, fuente: e.fuente);
      }
    }
    return mejores.values.toList();
  }

  /// Ejecuta los dos modelos de ML Kit sobre la misma imagen.
  static Future<List<_EtiquetaCruda>> _procesar(InputImage inputImage) async {
    final etiquetas = <_EtiquetaCruda>[];

    final objetos = await _detector.processImage(inputImage);
    for (final obj in objetos) {
      for (final label in obj.labels) {
        etiquetas.add(_EtiquetaCruda(label.text, label.confidence, 'objeto'));
      }
    }

    final labels = await _labeler.processImage(inputImage);
    for (final label in labels) {
      etiquetas.add(_EtiquetaCruda(label.label, label.confidence, 'etiqueta'));
    }

    return etiquetas;
  }

  /// Palabras en inglés que indican que hay una persona frente a la cámara.
  /// El detector de objetos de ML Kit NO tiene la clase "persona", así que
  /// depende del etiquetador de imágenes.
  static const _etiquetasPersona = {
    'person', 'people', 'human', 'man', 'woman', 'face', 'boy', 'girl',
    'child', 'baby', 'crowd', 'portrait', 'selfie',
  };

  /// Elige la mejor etiqueta con prioridades:
  /// 1) Si hay una persona con confianza suficiente, se anuncia primero.
  /// 2) Después las categorías del detector de objetos (más fiables que las
  ///    etiquetas genéricas, que a veces dicen cosas como "instrumento").
  /// 3) Por último, la mejor etiqueta genérica del etiquetador.
  static VisionResult? _mejorEtiqueta(List<_EtiquetaCruda> etiquetas) {
    if (etiquetas.isEmpty) return null;

    _EtiquetaCruda? persona;
    for (final e in etiquetas) {
      if (_etiquetasPersona.contains(e.texto.toLowerCase().trim()) &&
          (persona == null || e.confianza > persona.confianza)) {
        persona = e;
      }
    }
    if (persona != null && persona.confianza >= 0.5) {
      return VisionResult(
        etiquetaEs: Traducciones.traducir(persona.texto),
        confianza: persona.confianza,
        fuente: persona.fuente,
      );
    }

    final deObjetos = etiquetas.where((e) => e.fuente == 'objeto').toList()
      ..sort((a, b) => b.confianza.compareTo(a.confianza));
    if (deObjetos.isNotEmpty && deObjetos.first.confianza >= 0.5) {
      final o = deObjetos.first;
      return VisionResult(
        etiquetaEs: Traducciones.traducir(o.texto),
        confianza: o.confianza,
        fuente: o.fuente,
      );
    }

    etiquetas.sort((a, b) => b.confianza.compareTo(a.confianza));
    final mejor = etiquetas.first;
    return VisionResult(
      etiquetaEs: Traducciones.traducir(mejor.texto),
      confianza: mejor.confianza,
      fuente: mejor.fuente,
    );
  }

  /// Convierte un frame YUV420 (3 planos de la cámara en Android) a NV21,
  /// que es el formato que ML Kit acepta en Android.
  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + (width * height) ~/ 2);

    // Plano Y.
    int index = 0;
    for (int y = 0; y < height; y++) {
      final inicio = y * yPlane.bytesPerRow;
      nv21.setRange(index, index + width, yPlane.bytes, inicio);
      index += width;
    }

    // Planos U y V intercalados (NV21 = VU).
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;

    for (int y = 0; y < uvHeight; y++) {
      for (int x = 0; x < uvWidth; x++) {
        final uvIndex = index + y * width + x * 2;
        nv21[uvIndex] = vPlane.bytes[y * vRowStride + x * vPixelStride];
        nv21[uvIndex + 1] = uPlane.bytes[y * uRowStride + x * uPixelStride];
      }
    }

    return nv21;
  }

  static Future<void> dispose() async {
    await _objectDetector?.close();
    await _imageLabeler?.close();
    _objectDetector = null;
    _imageLabeler = null;
  }
}

class _EtiquetaCruda {
  final String texto;
  final double confianza;
  final String fuente;

  _EtiquetaCruda(this.texto, this.confianza, this.fuente);
}
