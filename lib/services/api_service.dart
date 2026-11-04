import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente de la API propia (backend FastAPI en MongoDB).
/// Investigación 100% propia: objetos, billetes, color, OCR e
/// intención de preguntas corren en nuestros modelos.
class ApiService {
  ApiService._();

  static const String _kApi = 'api_url';
  static const String _kToken = 'api_token';
  static const String _kRefresh = 'api_refresh';

  static Future<String> baseUrl() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString(_kApi) ?? 'http://127.0.0.1:8000').trim();
  }

  static Future<void> setBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kApi, url.trim());
  }

  static Future<String?> token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  /// Login con correo+password; guarda access+refresh. Devuelve
  /// null si falla (sin conexión o credenciales malas).
  static Future<bool> login(String correo, String password) async {
    try {
      final r = await http
          .post(Uri.parse('${await baseUrl()}/api/v1/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'correo': correo, 'password': password}))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body);
      final p = await SharedPreferences.getInstance();
      await p.setString(_kToken, j['access_token']);
      await p.setString(_kRefresh, j['refresh_token'] ?? '');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kRefresh);
  }

  static Future<Map<String, String>> _headers() async {
    final t = await token();
    return t == null ? {} : {'Authorization': 'Bearer $t'};
  }

  /// POST multipart imagen a un endpoint de reconocimiento.
  /// Devuelve el JSON o null si no hay conexión/token.
  static Future<Map<String, dynamic>?> inferir(
      String ruta, String archivo) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('${await baseUrl()}/api/v1/$ruta'));
      req.headers.addAll(await _headers());
      req.files.add(await http.MultipartFile.fromPath('imagen', archivo));
      final res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 30)));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {'error': res.body};
    } catch (_) {
      return null;
    }
  }

  /// Pregunta de seguimiento sobre el último escaneo (intención
  /// propia + resultado). Devuelve la frase para TTS.
  static Future<String?> preguntar(String idEscaneo, String texto) async {
    try {
      final r = await http
          .post(
              Uri.parse(
                  '${await baseUrl()}/api/v1/escaneos/$idEscaneo/pregunta'),
              headers: {
                'Content-Type': 'application/json',
                ...await _headers()
              },
              body: jsonEncode({'texto': texto}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body)['respuesta'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Descarga el .tflite activo de una tarea (modelo propio) para
  /// correrlo en el teléfono. Devuelve la ruta local o null.
  static Future<String?> descargarModelo(String tarea) async {
    try {
      final r = await http.get(
          Uri.parse(
              '${await baseUrl()}/api/v1/modelos/$tarea/activo/tflite'),
          headers: await _headers()).timeout(const Duration(seconds: 60));
      if (r.statusCode != 200) return null;
      final f = File(
          '${Directory.systemTemp.path}/modelo_$tarea.tflite');
      await f.writeAsBytes(r.bodyBytes, flush: true);
      return f.path;
    } catch (_) {
      return null;
    }
  }
}
