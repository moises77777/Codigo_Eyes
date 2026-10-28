import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../config/app_config.dart';
import 'storage_service.dart';

/// Servicio de texto a voz con cola de mensajes.
/// Evita que las respuestas se encimen y notifica cuando termina de hablar.
class TtsService {
  TtsService._();

  static final FlutterTts _flutterTts = FlutterTts();
  static final List<String> _cola = [];
  static bool _hablando = false;
  static double _rate = AppConfig.defaultSpeechRate;
  static double _pitch = AppConfig.defaultPitch;
  static VoidCallback? onQueueEmpty;

  static bool get isSpeaking => _hablando || _cola.isNotEmpty;

  /// Inicializa el motor TTS en español y recupera la velocidad guardada.
  static Future<void> init() async {
    _rate = await StorageService.getSpeechRate();
    _pitch = await StorageService.getPitch();

    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setVolume(1.0);

    final lenguajes = await _flutterTts.getLanguages as List<dynamic>?;
    final preferidos = ['es-MX', 'es_ES', 'es-US', 'es_US', 'es'];
    String? seleccionado;
    if (lenguajes != null) {
      for (final pref in preferidos) {
        if (lenguajes.any((l) => l.toString().toLowerCase() == pref.toLowerCase())) {
          seleccionado = pref;
          break;
        }
      }
    }
    if (seleccionado != null) {
      await _flutterTts.setLanguage(seleccionado);
    }

    _flutterTts.setStartHandler(() {
      _hablando = true;
    });

    _flutterTts.setCompletionHandler(() async {
      _hablando = false;
      await _procesarCola();
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('Error TTS: $msg');
      _hablando = false;
      _procesarCola();
    });
  }

  static Future<void> _procesarCola() async {
    if (_cola.isEmpty) {
      onQueueEmpty?.call();
      return;
    }
    final texto = _cola.removeAt(0);
    _hablando = true;
    await _flutterTts.speak(texto);
  }

  /// Agrega un mensaje a la cola de voz.
  static Future<void> speak(String texto) async {
    if (texto.trim().isEmpty) return;
    _cola.add(texto.trim());
    if (!_hablando) {
      await _procesarCola();
    }
  }

  /// Detiene la voz inmediatamente y limpia la cola.
  static Future<void> stop() async {
    _cola.clear();
    _hablando = false;
    await _flutterTts.stop();
  }

  /// Ajusta la velocidad de habla y la guarda.
  static Future<void> setRate(double rate) async {
    _rate = rate.clamp(AppConfig.minSpeechRate, AppConfig.maxSpeechRate);
    await StorageService.setSpeechRate(_rate);
    await _flutterTts.setSpeechRate(_rate);
  }

  static Future<void> increaseRate() async {
    await setRate(_rate + AppConfig.speechRateStep);
  }

  static Future<void> decreaseRate() async {
    await setRate(_rate - AppConfig.speechRateStep);
  }

  static double get rate => _rate;

  /// Ajusta el tono de voz y lo guarda.
  static Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(AppConfig.minPitch, AppConfig.maxPitch);
    await StorageService.setPitch(_pitch);
    await _flutterTts.setPitch(_pitch);
  }

  static Future<void> increasePitch() async {
    await setPitch(_pitch + AppConfig.pitchStep);
  }

  static Future<void> decreasePitch() async {
    await setPitch(_pitch - AppConfig.pitchStep);
  }

  static double get pitch => _pitch;
}
