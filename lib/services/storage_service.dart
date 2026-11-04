import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/contacto_apoyo.dart';
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
  static const _kPrimerUso = 'eyes_primer_uso_completado';
  // Claves de versiones anteriores que ya no se usan: se eliminan sin
  // leerlas al arrancar.
  static const _clavesObsoletas = [
    'eyes_usar_ia_nube', 'eyes_acepto_ia_nube', 'eyes_ia_api_key',
    'eyes_ia_model', 'eyes_acepto_' 'gem' 'ini', 'eyes_gem' 'ini_api_key',
    'eyes_gem' 'ini_model',
  ];

  /// Elimina de SharedPreferences las claves de versiones anteriores.
  static Future<void> purgarClavesObsoletas() async {
    await init();
    for (final k in _clavesObsoletas) {
      await _prefs?.remove(k);
    }
  }
  static const _kVolume = 'eyes_volume';
  static const _kVibracion = 'eyes_vibracion';
  static const _kContactos = 'eyes_contactos';
  static const _kModeloPropio = 'eyes_modelo_propio';
  static const _kUmbralConfianza = 'eyes_umbral_confianza';
  static const _kNubeUrl = 'eyes_nube_url';
  static const _kNubeKey = 'eyes_nube_key';
  static const _kIdDispositivo = 'eyes_id_dispositivo';
  static const _kContactosPendientes = 'eyes_contactos_pendientes';
  static const _kConfigPendiente = 'eyes_config_pendiente';
  static const _kBorradosPendientes = 'eyes_borrados_pendientes';

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

  static Future<void> setVolume(double volume) async {
    await init();
    await _prefs?.setDouble(_kVolume, volume);
  }

  static Future<double> getVolume() async {
    await init();
    return _prefs?.getDouble(_kVolume) ?? 1.0;
  }

  // ---------- Vibración ----------
  static Future<void> setVibracion(bool activa) async {
    await init();
    await _prefs?.setBool(_kVibracion, activa);
  }

  static Future<bool> getVibracion() async {
    await init();
    return _prefs?.getBool(_kVibracion) ?? true;
  }

  // ---------- Motor de OCR: 'mlkit' (local, por defecto) o 'servidor'
  // (nuestro OCR propio en el backend) ----------
  static const _kOcrMotor = 'eyes_ocr_motor';
  static Future<void> setOcrMotor(String motor) async {
    await init();
    await _prefs?.setString(_kOcrMotor, motor);
  }

  static Future<String> getOcrMotor() async {
    await init();
    return _prefs?.getString(_kOcrMotor) ?? 'mlkit';
  }

  // ---------- Contactos de apoyo ----------
  static Future<void> setContactos(List<ContactoApoyo> contactos) async {
    await init();
    final raw = jsonEncode(contactos.map((c) => c.toJson()).toList());
    await _prefs?.setString(_kContactos, raw);
  }

  static Future<List<ContactoApoyo>> getContactos() async {
    await init();
    final raw = _prefs?.getString(_kContactos);
    if (raw == null || raw.isEmpty) return [];
    try {
      final lista = jsonDecode(raw) as List<dynamic>;
      return lista
          .map((e) => ContactoApoyo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- Nube (sincronización) ----------
  static Future<void> setApiUrl(String url) async {
    await init();
    await _prefs?.setString(_kNubeUrl, url.trim());
  }

  static Future<String> getApiUrl() async {
    await init();
    return _prefs?.getString(_kNubeUrl) ?? '';
  }

  static Future<void> setApiKey(String key) async {
    await init();
    await _prefs?.setString(_kNubeKey, key.trim());
  }

  static Future<String> getApiKey() async {
    await init();
    return _prefs?.getString(_kNubeKey) ?? '';
  }

  /// Identificador único del dispositivo (uuid v4), generado una vez.
  static Future<String> getIdDispositivo() async {
    await init();
    var id = _prefs?.getString(_kIdDispositivo);
    if (id == null || id.isEmpty) {
      id = Resultado.generarIdLocal();
      await _prefs?.setString(_kIdDispositivo, id);
    }
    return id;
  }

  static Future<void> setContactosPendientes(bool v) async {
    await init();
    await _prefs?.setBool(_kContactosPendientes, v);
  }

  static Future<bool> getContactosPendientes() async {
    await init();
    return _prefs?.getBool(_kContactosPendientes) ?? false;
  }

  static Future<void> setConfigPendiente(bool v) async {
    await init();
    await _prefs?.setBool(_kConfigPendiente, v);
  }

  static Future<bool> getConfigPendiente() async {
    await init();
    return _prefs?.getBool(_kConfigPendiente) ?? false;
  }

  ///// Cola de borrados pendientes: `historial:*` o `guardado:` + idLocal.
  static Future<List<String>> getBorradosPendientes() async {
    await init();
    return _prefs?.getStringList(_kBorradosPendientes) ?? [];
  }

  static Future<void> encolarBorrado(String clave) async {
    await init();
    final lista = await getBorradosPendientes();
    if (!lista.contains(clave)) lista.add(clave);
    await _prefs?.setStringList(_kBorradosPendientes, lista);
  }

  static Future<void> quitarBorrado(String clave) async {
    await init();
    final lista = await getBorradosPendientes();
    lista.remove(clave);
    await _prefs?.setStringList(_kBorradosPendientes, lista);
  }

  /// Marca como sincronizados los resultados cuyo idLocal está en la lista.
  static Future<void> marcarHistorialSincronizado(List<String> ids) async {
    await init();
    final lista = await getHistorial();
    var cambio = false;
    for (final r in lista) {
      if (ids.contains(r.idLocal) && !r.sincronizado) {
        r.sincronizado = true;
        cambio = true;
      }
    }
    if (cambio) {
      await _prefs?.setString(
        _kHistorial,
        jsonEncode(lista.map((e) => e.toJson()).toList()),
      );
    }
  }

  static Future<void> marcarGuardadosSincronizado(List<String> ids) async {
    await init();
    final lista = await getGuardados();
    var cambio = false;
    for (final r in lista) {
      if (ids.contains(r.idLocal) && !r.sincronizado) {
        r.sincronizado = true;
        cambio = true;
      }
    }
    if (cambio) {
      await _prefs?.setString(
        _kGuardados,
        jsonEncode(lista.map((e) => e.toJson()).toList()),
      );
    }
  }

  // ---------- Modelo propio de detección ----------
  static Future<void> setModeloPropio(bool activo) async {
    await init();
    await _prefs?.setBool(_kModeloPropio, activo);
  }

  static Future<bool> getModeloPropio() async {
    await init();
    return _prefs?.getBool(_kModeloPropio) ?? false;
  }

  // ---------- Umbral de confianza para anunciar ----------
  static Future<void> setUmbralConfianza(double umbral) async {
    await init();
    await _prefs?.setDouble(_kUmbralConfianza, umbral);
  }

  static Future<double> getUmbralConfianza() async {
    await init();
    // EfficientDet-Lite0 int8 da 0.55-0.80 en objetos claros y de cerca;
    // 0.70 descartaba aciertos reales y respondía "no estoy seguro".
    return _prefs?.getDouble(_kUmbralConfianza) ?? 0.55;
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

  // ---------- Primer uso ----------
  static Future<void> setPrimerUsoCompletado(bool completado) async {
    await init();
    await _prefs?.setBool(_kPrimerUso, completado);
  }

  static Future<bool> getPrimerUsoCompletado() async {
    await init();
    return _prefs?.getBool(_kPrimerUso) ?? false;
  }

}
