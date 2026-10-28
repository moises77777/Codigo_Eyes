import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/resultado.dart';

/// Abstracción sobre SharedPreferences para guardar toda la configuración
/// y datos persistentes de EYES.
class StorageService {
  StorageService._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------- Claves ----------
  static const _kNombre = 'eyes_nombre';
  static const _kHistorial = 'eyes_historial';
  static const _kGuardados = 'eyes_guardados';
  static const _kSpeechRate = 'eyes_speech_rate';
  static const _kPitch = 'eyes_pitch';
  static const _kEscuchaContinua = 'eyes_escucha_continua';
  static const _kUsarIaNube = 'eyes_usar_ia_nube';
  static const _kAceptoGemini = 'eyes_acepto_gemini';
  static const _kPrimerUso = 'eyes_primer_uso_completado';
  static const _kGeminiApiKey = 'eyes_gemini_api_key';
  static const _kGeminiModel = 'eyes_gemini_model';

  // ---------- Nombre ----------
  static Future<void> setNombre(String nombre) async {
    await _prefs?.setString(_kNombre, nombre.trim());
  }

  static Future<String> getNombre() async {
    await init();
    return _prefs?.getString(_kNombre) ?? '';
  }

  // ---------- Historial ----------
  static Future<List<Resultado>> getHistorial() async {
    await init();
    final raw = _prefs?.getString(_kHistorial);
    if (raw == null || raw.isEmpty) return [];
    try {
      final lista = jsonDecode(raw) as List<dynamic>;
      return lista
          .map((e) => Resultado.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> agregarHistorial(Resultado r) async {
    await init();
    final lista = await getHistorial();
    lista.insert(0, r);
    while (lista.length > AppConfig.maxHistorial) {
      lista.removeLast();
    }
    await _prefs?.setString(_kHistorial, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<void> borrarHistorial() async {
    await init();
    await _prefs?.remove(_kHistorial);
  }

  // ---------- Guardados ----------
  static Future<List<Resultado>> getGuardados() async {
    await init();
    final raw = _prefs?.getString(_kGuardados);
    if (raw == null || raw.isEmpty) return [];
    try {
      final lista = jsonDecode(raw) as List<dynamic>;
      return lista
          .map((e) => Resultado.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> agregarGuardado(Resultado r) async {
    await init();
    final lista = await getGuardados();
    lista.insert(0, r);
    await _prefs?.setString(_kGuardados, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<void> eliminarGuardado(String id) async {
    await init();
    final lista = await getGuardados();
    lista.removeWhere((e) => e.id == id);
    await _prefs?.setString(_kGuardados, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  // ---------- Ajustes de voz ----------
  static Future<void> setSpeechRate(double rate) async {
    await init();
    await _prefs?.setDouble(_kSpeechRate, rate);
  }

  static Future<double> getSpeechRate() async {
    await init();
    return _prefs?.getDouble(_kSpeechRate) ?? AppConfig.defaultSpeechRate;
  }

  static Future<void> setPitch(double pitch) async {
    await init();
    await _prefs?.setDouble(_kPitch, pitch);
  }

  static Future<double> getPitch() async {
    await init();
    return _prefs?.getDouble(_kPitch) ?? AppConfig.defaultPitch;
  }

  // ---------- Modo escucha continua ----------
  static Future<void> setEscuchaContinua(bool activo) async {
    await init();
    await _prefs?.setBool(_kEscuchaContinua, activo);
  }

  static Future<bool> getEscuchaContinua() async {
    await init();
    return _prefs?.getBool(_kEscuchaContinua) ?? true;
  }

  // ---------- IA en la nube ----------
  static Future<void> setUsarIaNube(bool activo) async {
    await init();
    await _prefs?.setBool(_kUsarIaNube, activo);
  }

  static Future<bool> getUsarIaNube() async {
    await init();
    return _prefs?.getBool(_kUsarIaNube) ?? false;
  }

  static Future<void> setAceptoGemini(bool acepto) async {
    await init();
    await _prefs?.setBool(_kAceptoGemini, acepto);
  }

  static Future<bool> getAceptoGemini() async {
    await init();
    return _prefs?.getBool(_kAceptoGemini) ?? false;
  }

  // ---------- Primer uso ----------
  static Future<void> setPrimerUsoCompletado(bool completado) async {
    await init();
    await _prefs?.setBool(_kPrimerUso, completado);
  }

  static Future<bool> getPrimerUsoCompletado() async {
    await init();
    return _prefs?.getBool(_kPrimerUso) ?? false;
  }

  // ---------- Gemini ----------
  static Future<void> setGeminiApiKey(String key) async {
    await init();
    await _prefs?.setString(_kGeminiApiKey, key.trim());
  }

  static Future<String> getGeminiApiKey() async {
    await init();
    return _prefs?.getString(_kGeminiApiKey) ?? '';
  }

  static Future<void> setGeminiModel(String model) async {
    await init();
    await _prefs?.setString(_kGeminiModel, model.trim());
  }

  static Future<String> getGeminiModel() async {
    await init();
    return _prefs?.getString(_kGeminiModel) ?? AppConfig.defaultGeminiModel;
  }
}
