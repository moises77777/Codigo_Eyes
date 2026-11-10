/// Registro opcional de detecciones para reentrenar el modelo.
///
/// APAGADO por defecto (`registrarDataset = false` en Ajustes).
/// Cuando está activo guarda en un CSV las 7 variables de cada
/// anuncio, igual que el dataset ficticio de
/// practicas/proyecto_eyes/p02_a_crear_dataset_eyes.py.
///
/// Columna extra `correcto`: si en los 5 s siguientes al anuncio el
/// usuario dice "correcto"/"incorrecto" (o sí/no), se marca 1/0;
/// si no dice nada queda vacío. Sirve para etiquetar datos reales.
///
/// El archivo se guarda en el directorio externo de la app
/// (`/sdcard/Android/data/com.eyes.eyes_app/files/`): es persistente,
/// la app puede escribir ahí sin permisos extras y se puede extraer con:
///   adb pull /sdcard/Android/data/com.eyes.eyes_app/files/eyes_registro_detecciones.csv
/// No se usan dependencias nuevas (solo dart:io).
library;

import 'dart:io' show Directory, File, FileMode;

import 'caracteristicas.dart';

/// Registro de anuncios a CSV para reentrenamiento.
class RegistroDetecciones {
  RegistroDetecciones._();

  static const nombreArchivo = 'eyes_registro_detecciones.csv';
  static const ventanaFeedbackSegundos = 5;

  static bool _activo = false;
  static File? _archivo;
  static DateTime? _ultimoAnuncio;
  static String? _lineaPendiente;

  static bool get activo => _activo;
  static String? get rutaArchivo => _archivo?.path;

  /// Activa/desactiva el registro (desde el controller/ajustes).
  static void configurar(bool activo) {
    _activo = activo;
    if (!activo) {
      _lineaPendiente = null;
      _ultimoAnuncio = null;
    }
  }

  /// Directorio externo privado de la app (Android lo permite sin
  /// permisos y sobrevive a reinicios; visible vía adb pull).
  static const _dirExterno =
      '/sdcard/Android/data/com.eyes.eyes_app/files';

  static Future<File> _asegurarArchivo() async {
    if (_archivo != null) return _archivo!;
    final dir = Directory(_dirExterno);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _archivo = File('${dir.path}/$nombreArchivo');
    if (!_archivo!.existsSync()) {
      _archivo!.writeAsStringSync(
        'etiqueta,confianza,area_relativa,distancia_centro,'
        'frames_seguidos,peso_prioridad,es_peligroso,brillo,'
        'anunciar,correcto,fecha\n');
    }
    return _archivo!;
  }

  /// Guarda un anuncio (siempre `anunciar=1`: solo se registran los
  /// que sí se dijeron). La columna `correcto` queda pendiente del
  /// feedback del usuario durante [ventanaFeedbackSegundos] s.
  static Future<void> registrarAnuncio(
      String etiqueta, CaracteristicasDeteccion c) async {
    if (!_activo) return;
    final f = await _asegurarArchivo();
    final fecha = DateTime.now().toIso8601String();
    _lineaPendiente = '$etiqueta,${c.confianza},${c.areaRelativa},'
        '${c.distanciaCentro},${c.framesSeguidos},${c.pesoPrioridad},'
        '${c.esPeligroso},${c.brillo},1,,$fecha';
    _ultimoAnuncio = DateTime.now();
    f.writeAsStringSync('$_lineaPendiente\n', flush: true, mode: FileMode.append);
  }

  /// Marca la última línea como correcta (1) o incorrecta (0) si el
  /// usuario respondió dentro de la ventana. Devuelve true si marcó.
  static Future<bool> confirmar(bool correcto) async {
    if (!_activo || _lineaPendiente == null) return false;
    final espero = DateTime.now().difference(_ultimoAnuncio!).inSeconds;
    if (espero > ventanaFeedbackSegundos) {
      _lineaPendiente = null;
      return false;
    }
    // Reescribir la última línea llenando la columna `correcto`
    // (índice 9: está justo antes de la fecha).
    final f = await _asegurarArchivo();
    final contenido = f.readAsStringSync();
    final partes = _lineaPendiente!.split(',');
    partes[9] = correcto ? '1' : '0';
    final lineaCorregida = partes.join(',');
    f.writeAsStringSync(
      contenido.replaceFirst('$_lineaPendiente\n', '$lineaCorregida\n'),
    );
    _lineaPendiente = null;
    return true;
  }
}
