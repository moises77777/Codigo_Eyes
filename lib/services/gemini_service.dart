import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/app_config.dart';
import 'storage_service.dart';

/// Funciones de IA en la nube usando la API REST de Google Gemini.
class GeminiService {
  GeminiService._();

  // ---------- Utilidades ----------

  static Future<String> _getApiKey() async {
    final key = await AppConfig.getApiKey();
    return key;
  }

  static Future<String> _getModelo() async {
    final modelo = await StorageService.getGeminiModel();
    if (modelo.isNotEmpty) return modelo;
    return AppConfig.defaultGeminiModel;
  }

  /// Redimensiona la imagen si excede 1024 px en su lado mayor y la devuelve
  /// como JPEG base64.
  static Future<String> _prepararImagenBase64(String ruta) async {
    final bytes = await File(ruta).readAsBytes();
    var imagen = img.decodeImage(bytes);
    if (imagen == null) return base64Encode(bytes);

    final maxDim = AppConfig.maxImageDimension;
    if (imagen.width > maxDim || imagen.height > maxDim) {
      imagen = img.copyResize(
        imagen,
        width: imagen.width > imagen.height ? maxDim : null,
        height: imagen.height >= imagen.width ? maxDim : null,
      );
    }

    final jpeg = img.encodeJpg(imagen, quality: 85);
    return base64Encode(jpeg);
  }

  static Future<bool> _hayConexion() async {
    final result = await Connectivity().checkConnectivity();
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  static Map<String, dynamic> _crearCuerpo({
    required String prompt,
    String? imagenBase64,
  }) {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];

    if (imagenBase64 != null && imagenBase64.isNotEmpty) {
      parts.add({
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': imagenBase64,
        },
      });
    }

    return {
      'systemInstruction': {
        'parts': [
          {'text': AppConfig.systemInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        // gemini-2.5-flash "piensa" antes de responder; sin presupuesto
        // de pensamiento evita que la respuesta salga vacía.
        'thinkingConfig': {'thinkingBudget': 0},
        'maxOutputTokens': 512,
      },
    };
  }

  static Future<String> _llamarGemini({
    required String prompt,
    String? rutaImagen,
  }) async {
    if (!await _hayConexion()) {
      return '';
    }

    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      return '';
    }

    final modelo = await _getModelo();
    final url = Uri.parse(
      '${AppConfig.geminiBaseUrl}/$modelo:generateContent',
    );

    String? imagenBase64;
    if (rutaImagen != null && rutaImagen.isNotEmpty) {
      imagenBase64 = await _prepararImagenBase64(rutaImagen);
    }

    final body = jsonEncode(_crearCuerpo(
      prompt: prompt,
      imagenBase64: imagenBase64,
    ));

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: AppConfig.geminiTimeoutSeconds),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          return 'No obtuve una respuesta. Intenta de nuevo.';
        }
        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          return 'No obtuve una respuesta. Intenta de nuevo.';
        }
        // Unir todas las partes de texto y saltar las de "pensamiento".
        final textos = <String>[];
        for (final part in parts) {
          final p = part as Map<String, dynamic>;
          if (p['thought'] == true) continue;
          final t = p['text'] as String?;
          if (t != null && t.trim().isNotEmpty) textos.add(t.trim());
        }
        return textos.join(' ');
      }

      debugPrint('Gemini error ${response.statusCode}: ${response.body}');
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        return 'La clave de la inteligencia artificial no es válida. Revisa la configuración.';
      }
      if (response.statusCode == 404) {
        return 'El modelo de inteligencia artificial no existe o no está disponible. Revisa el nombre del modelo en ajustes.';
      }
      if (response.statusCode == 429) {
        return 'Se agotó la cuota de la inteligencia artificial. Intenta más tarde.';
      }
      if (response.statusCode >= 500) {
        return 'Hubo un error en el servidor de la inteligencia artificial. Intenta más tarde.';
      }

      return 'Error de la inteligencia artificial: ${response.statusCode}.';
    } on SocketException {
      return '';
    } on TimeoutException {
      return 'La inteligencia artificial tardó demasiado. Revisa tu conexión.';
    } catch (e) {
      debugPrint('Error en GeminiService: $e');
      return 'No pude consultar a la inteligencia artificial en este momento.';
    }
  }

  // ---------- Funciones públicas ----------

  /// a) Descripción breve de la escena para una persona ciega.
  static Future<String> describirEscena(String rutaImagen) async {
    return _llamarGemini(
      prompt:
          'Describe esta escena en español de México en máximo 3 frases cortas. '
          'Di qué hay, dónde está y posibles obstáculos para una persona ciega.',
      rutaImagen: rutaImagen,
    );
  }

  /// b) Responde una pregunta del usuario sobre la imagen.
  static Future<String> preguntarSobreImagen(
    String rutaImagen,
    String pregunta,
  ) async {
    return _llamarGemini(
      prompt:
          'Responde en español de México, breve y claro, a esta pregunta sobre la imagen: $pregunta',
      rutaImagen: rutaImagen,
    );
  }

  /// c) Identificación detallada del objeto principal.
  static Future<String> identificarDetallado(String rutaImagen) async {
    return _llamarGemini(
      prompt:
          'Identifica el objeto principal de la imagen en español de México. '
          'Di su nombre, color aproximado, marca o modelo si se lee, y para qué sirve en una frase.',
      rutaImagen: rutaImagen,
    );
  }

  /// d) Lee el texto de la imagen y, si es largo, resúmelo.
  static Future<String> leerYResumir(String rutaImagen) async {
    return _llamarGemini(
      prompt:
          'Lee el texto visible en esta imagen. Si es largo, resúmelo en español de México '
          'conservando los puntos más importantes. Si no hay texto, di "No hay texto visible".',
      rutaImagen: rutaImagen,
    );
  }

  /// e) Conversación general sin imagen.
  static Future<String> conversar(String pregunta) async {
    return _llamarGemini(
      prompt:
          'Responde en español de México, breve y claro, sin listas ni emojis: $pregunta',
    );
  }

  /// Prueba la conexión con la clave y el modelo configurados.
  /// Devuelve un mensaje legible para mostrarlo o decirlo en voz alta.
  static Future<String> probarConexion() async {
    if (!await _hayConexion()) {
      return 'No hay conexión a internet.';
    }
    final key = await _getApiKey();
    if (key.isEmpty) {
      return 'No hay clave guardada. Pega tu clave y guarda primero.';
    }
    final respuesta = await _llamarGemini(
      prompt: 'Responde solamente: ok',
    );
    if (respuesta.isEmpty) {
      return 'No hubo respuesta de Gemini. Revisa tu conexión.';
    }
    if (respuesta.toLowerCase().contains('ok')) {
      return 'Conexión correcta. Gemini está listo.';
    }
    return respuesta; // mensaje de error ya en español
  }
}
