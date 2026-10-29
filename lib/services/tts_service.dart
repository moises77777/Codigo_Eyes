import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../config/app_config.dart';
import 'storage_service.dart';

/// Entrada de la cola de voz: el texto y el Completer que se resuelve
/// cuando ESA frase terminó de sonar.
class _EntradaCola {
  final String texto;
  final Completer<void> completer = Completer<void>();

  _EntradaCola(this.texto);
}

/// Servicio de texto a voz con cola de mensajes.
/// Evita que las respuestas se encimen y notifica cuando termina de hablar.
class TtsService {
  TtsService._();

  static final FlutterTts _flutterTts = FlutterTts();
  static final List<_EntradaCola> _cola = [];
  static _EntradaCola? _actual;
  static bool _hablando = false;
  static double _rate = AppConfig.defaultSpeechRate;
  static double _pitch = AppConfig.defaultPitch;
  static double _volume = 1.0;
  static Completer<void>? _esperandoSilencio;
  static Timer? _timerSeguridad;
  static VoidCallback? onQueueEmpty;

  static bool get isSpeaking => _hablando || _cola.isNotEmpty;

  /// Inicializa el motor TTS en español y recupera la velocidad guardada.
  static Future<void> init() async {
    _rate = await StorageService.getSpeechRate();
    _pitch = await StorageService.getPitch();
    _volume = await StorageService.getVolume();

    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setVolume(_volume);

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
      _timerSeguridad?.cancel();
      _completarActual();
      _hablando = false;
      await _procesarCola();
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('Error TTS: $msg');
      _timerSeguridad?.cancel();
      _completarActual();
      _hablando = false;
      _procesarCola();
    });

    // Algunos motores cancelan la frase en vez de completarla:
    // se trata igual que un completion para no colgar la cola.
    _flutterTts.setCancelHandler(() {
      _timerSeguridad?.cancel();
      _completarActual();
      _hablando = false;
      _procesarCola();
    });
  }

  /// Marca la frase actual como terminada para quien la esté esperando.
  static void _completarActual() {
    final entrada = _actual;
    _actual = null;
    if (entrada != null && !entrada.completer.isCompleted) {
      entrada.completer.complete();
    }
  }

  static Future<void> _procesarCola() async {
    if (_cola.isEmpty) {
      onQueueEmpty?.call();
      final esperando = _esperandoSilencio;
      _esperandoSilencio = null;
      if (esperando != null && !esperando.isCompleted) {
        esperando.complete();
      }
      return;
    }
    _actual = _cola.removeAt(0);
    _hablando = true;
    // Timer de seguridad por frase: si el motor nunca dispara
    // completion/error, la cola no se queda colgada.
    final entrada = _actual!;
    _timerSeguridad?.cancel();
    _timerSeguridad = Timer(_duracionSeguridad(entrada.texto), () {
      if (identical(_actual, entrada)) {
        _completarActual();
        _hablando = false;
        _procesarCola();
      }
    });
    final resultado = await _flutterTts.speak(entrada.texto);
    // speak devuelve distinto de 1 si el motor rechazó la frase:
    // se da por terminada y se sigue con la cola.
    if (resultado != 1) {
      _timerSeguridad?.cancel();
      _completarActual();
      _hablando = false;
      await _procesarCola();
    }
  }

  /// Duración estimada de una frase para el timer de seguridad:
  /// ~90 ms por carácter, entre 3 y 45 segundos.
  static Duration _duracionSeguridad(String texto) {
    final ms = 2000 + texto.length * 90;
    return Duration(milliseconds: ms.clamp(3000, 45000));
  }

  /// Agrega un mensaje a la cola de voz.
  /// El Future se completa cuando ESA frase terminó de sonar.
  static Future<void> speak(String texto) {
    if (texto.trim().isEmpty) return Future.value();
    final entrada = _EntradaCola(texto.trim());
    _cola.add(entrada);
    if (!_hablando) {
      _procesarCola();
    }
    return entrada.completer.future;
  }

  /// Completa cuando ya no hay nada hablando ni en cola.
  /// Si ya está en silencio, regresa de inmediato.
  static Future<void> esperarSilencio() async {
    if (!isSpeaking) return;
    _esperandoSilencio ??= Completer<void>();
    await _esperandoSilencio!.future;
  }

  /// Detiene la voz inmediatamente y limpia la cola.
  static Future<void> stop() async {
    _timerSeguridad?.cancel();
    _completarActual();
    for (final entrada in _cola) {
      if (!entrada.completer.isCompleted) {
        entrada.completer.complete();
      }
    }
    _cola.clear();
    _hablando = false;
    await _flutterTts.stop();
    final esperando = _esperandoSilencio;
    _esperandoSilencio = null;
    if (esperando != null && !esperando.isCompleted) {
      esperando.complete();
    }
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

  /// Ajusta el volumen de voz (0.2 a 1.0) y lo guarda.
  static Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.2, 1.0);
    await StorageService.setVolume(_volume);
    await _flutterTts.setVolume(_volume);
  }

  static Future<void> increaseVolume() async {
    await setVolume(_volume + 0.2);
  }

  static Future<void> decreaseVolume() async {
    await setVolume(_volume - 0.2);
  }

  static double get volume => _volume;
}
