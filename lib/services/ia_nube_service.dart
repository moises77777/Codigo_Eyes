import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/app_config.dart';

/// Resultado de una consulta a la IA en la nube: [texto] con la
/// respuesta lista para leerse en voz, o [error] con un mensaje
/// hablable que explica qué falló.
class ResultadoIa {
  final String texto;
  final String? error;

  const ResultadoIa(this.texto) : error = null;
  const ResultadoIa.conError(this.error) : texto = '';

  bool get ok => error == null;
}

/// Funciones de IA en la nube usando la API de mensajes de Anthropic.
/// Solo se envían fotos si el usuario aceptó la IA en la nube.
class IaNubeService {
  IaNubeService._();

  /// Cliente HTTP inyectable para pruebas (MockClient).
  @visibleForTesting
  static http.Client? clientParaPruebas;

  /// Timeout configurable para pruebas; por defecto el de AppConfig.
  @visibleForTesting
  static Duration? timeoutParaPruebas;

  /// Clave y modelo forzados para pruebas (evitan leer ajustes/defines).
  @visibleForTesting
  static String? apiKeyParaPruebas;
  @visibleForTesting
  static String? modeloParaPruebas;

  /// Bandera de conectividad forzada para pruebas.
  @visibleForTesting
  static bool? conexionParaPruebas;

  static http.Client get _client => clientParaPruebas ?? http.Client();

  static Duration get _timeout =>
      timeoutParaPruebas ??
      const Duration(seconds: AppConfig.iaTimeoutSeconds);

  static Future<String> _getApiKey() async {
    if (apiKeyParaPruebas != null) return apiKeyParaPruebas!;
    return AppConfig.getApiKey();
  }

  static Future<String> _getModelo() async {
    if (modeloParaPruebas != null) return modeloParaPruebas!;
    return AppConfig.getIaModel();
  }

  static Future<bool> _hayConexion() async {
    if (conexionParaPruebas != null) return conexionParaPruebas!;
    final result = await Connectivity().checkConnectivity();
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  /// Redimensiona la imagen a máx. 1024 px de lado mayor y la devuelve
  /// como JPEG calidad 80 en base64. Corre en un isolate para no
  /// congelar la interfaz. La foto nunca se sube sin redimensionar
  /// para no mandar archivos de varios megabytes.
  static Future<String> _prepararImagenBase64(String ruta) async {
    return compute(_imagenBase64EnIsolate, ruta);
  }

  static String _imagenBase64EnIsolate(String ruta) {
    final bytes = File(ruta).readAsBytesSync();
    var imagen = img.decodeImage(bytes);
    if (imagen == null) return base64Encode(bytes);

    const maxDim = AppConfig.maxImageDimension;
    if (imagen.width > maxDim || imagen.height > maxDim) {
      imagen = img.copyResize(
        imagen,
        width: imagen.width > imagen.height ? maxDim : null,
        height: imagen.height >= imagen.width ? maxDim : null,
      );
    }
    return base64Encode(img.encodeJpg(imagen, quality: 80));
  }

  static Map<String, dynamic> _crearCuerpo({
    required String prompt,
    required String modelo,
    required int maxTokens,
    String? imagenBase64,
  }) {
    final contenido = <Map<String, dynamic>>[];
    if (imagenBase64 != null && imagenBase64.isNotEmpty) {
      contenido.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/jpeg',
          'data': imagenBase64,
        },
      });
    }
    contenido.add({'type': 'text', 'text': prompt});

    return {
      'model': modelo,
      'max_tokens': maxTokens,
      'system': AppConfig.systemInstruction,
      'messages': [
        {'role': 'user', 'content': contenido},
      ],
    };
  }

  /// Mensaje de error listo para hablar según el código HTTP.
  static String _mensajeDeError(int statusCode, String cuerpo) {
    debugPrint('IA nube error $statusCode');
    final cuerpoLower = cuerpo.toLowerCase();
    if (statusCode == 401 || statusCode == 403) {
      return 'La clave de la inteligencia artificial no es válida. '
          'Revísala en ajustes.';
    }
    if (statusCode == 429) {
      return 'Se alcanzó el límite de uso de la inteligencia artificial. '
          'Intenta más tarde.';
    }
    if (statusCode == 402 ||
        cuerpoLower.contains('billing') ||
        cuerpoLower.contains('credit')) {
      return 'La inteligencia artificial no tiene saldo disponible.';
    }
    if (statusCode == 404) {
      return 'El modelo configurado no existe. Revísalo en ajustes.';
    }
    if (statusCode >= 500) {
      return 'Hubo un error en el servidor de la inteligencia artificial. '
          'Intenta más tarde.';
    }
    return 'No pude consultar a la inteligencia artificial.';
  }

  /// Llama a la API de mensajes. Devuelve [ResultadoIa] con el texto
  /// o con un mensaje de error hablable.
  static Future<ResultadoIa> _llamarApi({
    required String prompt,
    String? rutaImagen,
    int maxTokens = 150,
  }) async {
    if (!await _hayConexion()) {
      return const ResultadoIa.conError(
        'No hay conexión a internet. Sigo con las funciones locales.',
      );
    }

    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      return const ResultadoIa.conError(
        'No hay clave de inteligencia artificial configurada. '
            'Agrégala en ajustes.',
      );
    }

    final modelo = await _getModelo();
    String? imagenBase64;
    if (rutaImagen != null && rutaImagen.isNotEmpty) {
      imagenBase64 = await _prepararImagenBase64(rutaImagen);
    }

    final body = jsonEncode(_crearCuerpo(
      prompt: prompt,
      modelo: modelo,
      maxTokens: maxTokens,
      imagenBase64: imagenBase64,
    ));

    try {
      final response = await _client
          .post(
            Uri.parse(AppConfig.anthropicUrl),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': AppConfig.anthropicVersion,
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>?;
        if (content == null || content.isEmpty) {
          return const ResultadoIa.conError(
            'No obtuve una respuesta. Intenta de nuevo.',
          );
        }
        final textos = <String>[];
        for (final parte in content) {
          final p = parte as Map<String, dynamic>;
          final t = p['text'] as String?;
          if (t != null && t.trim().isNotEmpty) textos.add(t.trim());
        }
        if (textos.isEmpty) {
          return const ResultadoIa.conError(
            'No obtuve una respuesta. Intenta de nuevo.',
          );
        }
        return ResultadoIa(textos.join(' '));
      }

      return ResultadoIa.conError(
        _mensajeDeError(response.statusCode, response.body),
      );
    } on SocketException {
      return const ResultadoIa.conError(
        'No hay conexión a internet. Sigo con las funciones locales.',
      );
    } on TimeoutException {
      return const ResultadoIa.conError(
        'La inteligencia artificial tardó demasiado en responder. '
            'Inténtalo de nuevo.',
      );
    } catch (e) {
      debugPrint('Error en IaNubeService: $e');
      return const ResultadoIa.conError(
        'No pude consultar a la inteligencia artificial.',
      );
    }
  }

  // ---------- Funciones públicas ----------

  /// Descripción breve de la escena para una persona ciega.
  static Future<ResultadoIa> describirEscena(String rutaImagen) async {
    return _llamarApi(
      prompt:
          'Describe esta escena en máximo 3 frases cortas. '
          'Di qué hay, dónde está y posibles obstáculos para una persona ciega.',
      rutaImagen: rutaImagen,
      maxTokens: 300,
    );
  }

  /// Responde una pregunta del usuario sobre la imagen.
  static Future<ResultadoIa> preguntarSobreImagen(
    String rutaImagen,
    String pregunta,
  ) async {
    return _llamarApi(
      prompt: 'Responde, breve y claro, a esta pregunta sobre la imagen: $pregunta',
      rutaImagen: rutaImagen,
      maxTokens: 150,
    );
  }

  /// Identificación detallada del objeto principal.
  static Future<ResultadoIa> identificarDetallado(String rutaImagen) async {
    return _llamarApi(
      prompt:
          'Identifica el objeto principal de la imagen. '
          'Di su nombre, color aproximado, marca o modelo si se lee, y para qué sirve en una frase.',
      rutaImagen: rutaImagen,
      maxTokens: 150,
    );
  }

  /// Lee el texto de la imagen y, si es largo, lo resume.
  static Future<ResultadoIa> leerYResumir(String rutaImagen) async {
    return _llamarApi(
      prompt:
          'Lee el texto visible en esta imagen. Si es largo, resúmelo '
          'conservando los puntos más importantes. Si no hay texto, di "No hay texto visible".',
      rutaImagen: rutaImagen,
      maxTokens: 300,
    );
  }

  /// Conversación general sin imagen.
  static Future<ResultadoIa> conversar(String pregunta) async {
    return _llamarApi(
      prompt: 'Responde breve y claro, sin listas ni emojis: $pregunta',
      maxTokens: 150,
    );
  }

  /// Prueba la conexión con la clave y el modelo configurados con una
  /// petición mínima. Devuelve un mensaje legible para voz.
  static Future<String> probarConexion() async {
    if (!await _hayConexion()) {
      return 'No hay conexión a internet.';
    }
    final key = await _getApiKey();
    if (key.isEmpty) {
      return 'No hay clave guardada. Pega tu clave y guarda primero.';
    }
    final respuesta = await _llamarApi(
      prompt: 'Responde solamente: ok',
      maxTokens: 10,
    );
    if (!respuesta.ok) {
      return respuesta.error!;
    }
    if (respuesta.texto.toLowerCase().contains('ok')) {
      return 'Conexión correcta. La inteligencia artificial está lista.';
    }
    return 'La inteligencia artificial respondió algo inesperado: '
        '${respuesta.texto}';
  }
}
