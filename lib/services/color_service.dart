import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Resultado del análisis de color: el color principal, un posible
/// secundario y sus porcentajes dentro de la región central.
class ResultadoColor {
  final String principal;
  final String? secundario;
  final double porcentajePrincipal;
  final double porcentajeSecundario;

  const ResultadoColor({
    required this.principal,
    this.secundario,
    required this.porcentajePrincipal,
    required this.porcentajeSecundario,
  });
}

/// Servicio offline de detección de color dominante.
/// Clasifica los píxeles de la zona central de la foto en nombres
/// de color sencillos para leerlos en voz alta.
class ColorService {
  ColorService._();

  /// Nombre de color para un tono/saturación/valor dados (h: 0-360,
  /// s y v: 0-1). Función pura pensada para pruebas.
  static String nombreDeColor(double h, double s, double v) {
    if (v < 0.18) return 'negro';
    if (s < 0.15) return v > 0.80 ? 'blanco' : 'gris';
    // Los cafés son naranjas oscuros con algo de saturación.
    if (h >= 15 && h < 45 && v < 0.65) return 'café';
    if (h < 15 || h >= 345) return 'rojo';
    if (h < 45) return 'naranja';
    if (h < 70) return 'amarillo';
    if (h < 170) return 'verde';
    if (h < 200) return 'azul claro';
    if (h < 260) return 'azul';
    if (h < 300) return 'morado';
    return 'rosa';
  }

  /// Analiza la foto de [ruta] y devuelve el color dominante de la
  /// región central (40 % del ancho y del alto). Corre en un isolate
  /// para no congelar la interfaz.
  static Future<ResultadoColor> colorDominante(String ruta) {
    return compute(_colorDominanteEnIsolate, ruta);
  }

  static ResultadoColor _colorDominanteEnIsolate(String ruta) {
    const vacio = ResultadoColor(
      principal: '',
      porcentajePrincipal: 0,
      porcentajeSecundario: 0,
    );
    try {
      final bytes = File(ruta).readAsBytesSync();
      final original = img.decodeImage(bytes);
      if (original == null) return vacio;

      // Reducir a 96 px de ancho basta para clasificar colores.
      final chica = img.copyResize(original, width: 96);

      // Región central: el 40 % del ancho y del alto.
      final ancho = chica.width;
      final alto = chica.height;
      final x0 = (ancho * 0.3).floor();
      final x1 = (ancho * 0.7).ceil();
      final y0 = (alto * 0.3).floor();
      final y1 = (alto * 0.7).ceil();

      final conteo = <String, int>{};
      var total = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final p = chica.getPixel(x, y);
          final hsv = _rgbToHsv(
            p.r.toDouble() / 255,
            p.g.toDouble() / 255,
            p.b.toDouble() / 255,
          );
          final nombre = nombreDeColor(hsv[0], hsv[1], hsv[2]);
          conteo[nombre] = (conteo[nombre] ?? 0) + 1;
          total++;
        }
      }
      if (total == 0 || conteo.isEmpty) return vacio;

      final ordenados = conteo.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final principal = ordenados.first;
      String? secundario;
      var porcSec = 0.0;
      if (ordenados.length > 1 && ordenados[1].value / total >= 0.2) {
        secundario = ordenados[1].key;
        porcSec = ordenados[1].value / total;
      }
      return ResultadoColor(
        principal: principal.key,
        secundario: secundario,
        porcentajePrincipal: principal.value / total,
        porcentajeSecundario: porcSec,
      );
    } catch (e) {
      debugPrint('Error en ColorService: $e');
      return vacio;
    }
  }

  /// Convierte RGB (0-1) a HSV (h: 0-360, s y v: 0-1).
  static List<double> _rgbToHsv(double r, double g, double b) {
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final delta = maxC - minC;

    var h = 0.0;
    if (delta > 0) {
      if (maxC == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (maxC == g) {
        h = 60 * (((b - r) / delta) + 2);
      } else {
        h = 60 * (((r - g) / delta) + 4);
      }
    }
    if (h < 0) h += 360;

    final s = maxC == 0 ? 0.0 : delta / maxC;
    return [h, s, maxC];
  }
}
