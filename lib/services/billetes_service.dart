import 'color_service.dart';
import 'ocr_service.dart';

/// Resultado de identificar un billete mexicano.
/// [denominacion] se llena cuando se leyó el número con OCR;
/// [pista] se llena cuando solo se pudo inferir por el color.
class ResultadoBillete {
  final int? denominacion;
  final String? pista;
  final bool confiable;

  const ResultadoBillete({this.denominacion, this.pista})
      : confiable = denominacion != null;
}

/// Identificador offline de billetes mexicanos: primero intenta leer la
/// denominación con OCR local y, si no la encuentra, usa el color
/// dominante del billete como pista aproximada.
class BilletesService {
  BilletesService._();

  /// Denominaciones válidas en circulación.
  static const _numeros = {
    '20': 20,
    '50': 50,
    '100': 100,
    '200': 200,
    '500': 500,
    '1000': 1000,
  };

  static const _palabras = {
    'veinte': 20,
    'cincuenta': 50,
    'cien': 100,
    'doscientos': 200,
    'quinientos': 500,
    'mil': 1000,
  };

  /// Busca la denominación dentro del texto del OCR.
  /// Cuenta ocurrencias por denominación (números y palabras) y devuelve
  /// la más frecuente; en empate prefiere la que apareció como número.
  /// Devuelve null si no encontró nada.
  static int? denominacionDesdeTexto(String textoOcr) {
    final t = _normalizar(textoOcr);
    if (t.isEmpty) return null;

    var mejor = 0;
    var mejorConteo = 0;
    var mejorConNumero = false;

    for (final denominacion in _numeros.values) {
      var conteo = 0;
      var conNumero = false;

      for (final entrada in _numeros.entries) {
        if (entrada.value != denominacion) continue;
        // Límites de palabra: '1000' no cuenta como '100'.
        final matches = RegExp('\\b${entrada.key}\\b').allMatches(t);
        conteo += matches.length;
        if (matches.isNotEmpty) conNumero = true;
      }
      for (final entrada in _palabras.entries) {
        if (entrada.value != denominacion) continue;
        conteo += RegExp('\\b${entrada.key}\\b').allMatches(t).length;
      }

      if (conteo > mejorConteo ||
          (conteo == mejorConteo && conteo > 0 && conNumero && !mejorConNumero)) {
        mejor = denominacion;
        mejorConteo = conteo;
        mejorConNumero = conNumero;
      }
    }
    return mejorConteo > 0 ? mejor : null;
  }

  /// Pista aproximada por color del billete (familia G del Banco de
  /// México). Compara la clave sin acento ('cafe').
  static String? denominacionPorColor(String colorPrincipal) {
    final c = _normalizar(colorPrincipal);
    switch (c) {
      case 'verde':
        return '20 o 200';
      case 'azul':
        return '20 o 500';
      case 'rosa':
      case 'magenta':
        return '50 o 1000';
      case 'rojo':
        return '100';
      case 'morado':
        return '1000';
      case 'cafe':
        return '500';
      default:
        return null;
    }
  }

  /// Identifica el billete de la foto en [rutaImagen]: OCR primero y,
  /// si no hay número legible, el color dominante como pista.
  static Future<ResultadoBillete> identificar(String rutaImagen) async {
    final texto = await OcrService.leerTexto(rutaImagen);
    final denominacion = denominacionDesdeTexto(texto);
    if (denominacion != null) {
      return ResultadoBillete(denominacion: denominacion);
    }

    final color = await ColorService.colorDominante(rutaImagen);
    final pista = color.principal.isEmpty
        ? null
        : denominacionPorColor(color.principal);
    return ResultadoBillete(pista: pista);
  }

  /// Minúsculas, sin acentos y sin signos.
  static String _normalizar(String texto) {
    var t = texto.toLowerCase().trim();
    const conAcentos = 'áéíóúüñ';
    const sinAcentos = 'aeiouun';
    final buffer = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      final idx = conAcentos.indexOf(ch);
      if (idx >= 0) {
        buffer.write(sinAcentos[idx]);
        continue;
      }
      final code = ch.codeUnitAt(0);
      final letra = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
      buffer.write(letra ? ch : ' ');
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
