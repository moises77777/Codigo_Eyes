import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Servicio de reconocimiento de voz en español.
class VoiceInputService {
  VoiceInputService._();

  static final SpeechToText _speech = SpeechToText();
  static bool _initialized = false;
  static bool _isListening = false;
  static String? _localeId;
  static DateTime? _ultimoParcial;

  static bool get isListening => _isListening;
  static bool get isAvailable => _speech.isAvailable;

  /// Momento del último resultado parcial (el usuario está hablando).
  static DateTime? get ultimoParcial => _ultimoParcial;

  /// Inicializa el reconocimiento y selecciona el mejor español disponible.
  static Future<bool> init() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );

      if (_initialized) {
        final locales = await _speech.locales();
        final preferidos = ['es_MX', 'es-MX', 'es_ES', 'es-ES', 'es_US', 'es-US', 'es'];
        for (final pref in preferidos) {
          final encontrado = locales.firstWhere(
            (l) => l.localeId.toLowerCase().startsWith(pref.toLowerCase()),
            orElse: () => LocaleName('', ''),
          );
          if (encontrado.localeId.isNotEmpty) {
            _localeId = encontrado.localeId;
            break;
          }
        }
      }
      return _initialized;
    } catch (e) {
      debugPrint('Error inicializando voz: $e');
      return false;
    }
  }

  /// Empieza a escuchar y devuelve el texto reconocido por [onResult].
  /// [onPartial] recibe el texto parcial mientras el usuario habla,
  /// para mostrarlo en pantalla sin esperar al resultado final.
  static Future<void> listen({
    required void Function(String) onResult,
    void Function(String)? onError,
    void Function(String)? onPartial,
  }) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) {
        onError?.call('Reconocimiento de voz no disponible.');
        return;
      }
    }

    if (_isListening) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isListening = true;
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _isListening = false;
            onResult(result.recognizedWords);
          } else if (result.recognizedWords.isNotEmpty) {
            _ultimoParcial = DateTime.now();
            onPartial?.call(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(milliseconds: 1800),
          localeId: _localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      _isListening = false;
      onError?.call('Error al escuchar: $e');
    }
  }

  /// Detiene la escucha actual.
  static Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }

  /// Libera recursos.
  static Future<void> dispose() async {
    await _speech.cancel();
    _initialized = false;
    _isListening = false;
  }
}
