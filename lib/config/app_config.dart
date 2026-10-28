import '../services/storage_service.dart';

/// Constantes y configuración central de EYES.
class AppConfig {
  AppConfig._();

  // --- Gemini ---
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String defaultGeminiModel = 'gemini-2.5-flash';
  static const int geminiTimeoutSeconds = 20;
  static const int maxImageDimension = 1024;

  /// Lee la API key: prioridad a la clave guardada en SharedPreferences,
  /// luego a la variable de compilación --dart-define=GEMINI_API_KEY.
  static Future<String> getApiKey() async {
    final guardada = await StorageService.getGeminiApiKey();
    if (guardada.trim().isNotEmpty) return guardada.trim();

    const desdeDartDefine = String.fromEnvironment('GEMINI_API_KEY');
    return desdeDartDefine.trim();
  }

  // --- Voz ---
  static const double defaultSpeechRate = 0.55;
  static const double minSpeechRate = 0.3;
  static const double maxSpeechRate = 1.0;
  static const double speechRateStep = 0.1;

  static const double defaultPitch = 1.0;
  static const double minPitch = 0.5;
  static const double maxPitch = 1.5;
  static const double pitchStep = 0.1;

  // --- Historial ---
  static const int maxHistorial = 30;

  // --- Instrucción del sistema para Gemini ---
  static const String systemInstruction =
      'Eres EYES, asistente para personas con discapacidad visual. '
      'Responde siempre en español de México, de forma breve, clara y directa, '
      'sin markdown, sin emojis ni listas, porque tu respuesta será leída en voz alta.';

  // --- Texto de ayuda leído por voz ---
  static const String textoAyuda =
      'Di "qué es esto" para identificar un objeto. '
      'Di "describe la escena" para saber qué hay alrededor. '
      'Di "lee el texto" para leer un documento. '
      'Di "resume" para resumir un texto largo. '
      'Di "guarda esto" para recordar un objeto. '
      'Di "historial" para las últimas identificaciones. '
      'Di "guardados" para tus objetos guardados. '
      'Di "más rápido" o "más lento" para cambiar la velocidad. '
      'Di "detener" para cancelar lo actual. '
      'Di "algoritmos" para la demostración de búsquedas. '
      'Di "ayuda" para escuchar los comandos. '
      'También puedes hacer cualquier pregunta sobre la imagen.';
}
