import '../services/storage_service.dart';

/// Constantes y configuración central de EYES.
class AppConfig {
  AppConfig._();

  // --- IA en la nube (Anthropic Messages API) ---
  static const String anthropicUrl = 'https://api.anthropic.com/v1/messages';
  static const String anthropicVersion = '2023-06-01';
  static const String defaultIaModel = 'claude-sonnet-5-5';
  static const int iaTimeoutSeconds = 15;
  static const int maxImageDimension = 1024;

  /// Lee la API key: prioridad a la clave guardada en SharedPreferences,
  /// luego a la variable de compilación --dart-define=ANTHROPIC_API_KEY.
  static Future<String> getApiKey() async {
    final guardada = await StorageService.getIaApiKey();
    if (guardada.trim().isNotEmpty) return guardada.trim();

    const desdeDartDefine = String.fromEnvironment('ANTHROPIC_API_KEY');
    return desdeDartDefine.trim();
  }

  /// Lee el modelo: Ajustes guardado, luego --dart-define=ANTHROPIC_MODEL,
  /// luego el modelo por defecto.
  static Future<String> getIaModel() async {
    final guardado = await StorageService.getIaModel();
    if (guardado.trim().isNotEmpty) return guardado.trim();

    const desdeDartDefine = String.fromEnvironment('ANTHROPIC_MODEL');
    if (desdeDartDefine.trim().isNotEmpty) return desdeDartDefine.trim();
    return defaultIaModel;
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

  // --- Instrucción del sistema para la IA en la nube ---
  static const String systemInstruction =
      'Eres EYES, un asistente para personas ciegas o con baja visión. '
      'Responde siempre en español de México, con frases cortas y claras '
      'pensadas para escucharse en voz alta. '
      'No uses formato markdown, listas con símbolos ni emojis. '
      'Si no puedes identificar algo con claridad, di "no estoy seguro" '
      'en lugar de adivinar. '
      'Nunca inventes marcas, textos, números ni cantidades que no se vean '
      'claramente.';

  // --- Texto de ayuda leído por voz ---
  static const String textoAyuda =
      'Para ver: di qué es esto, qué color es, qué billete es, describe todo, '
      'lee el texto, o lee continuo. '
      'Para moverte: di encuadrar, detección continua, o detener. '
      'Para la cámara: di enciende la linterna, o apaga la linterna. '
      'Para recordar: di guardar esto, historial, guardados, o repetir. '
      'Para la nube: di sincronizar o respaldar. '
      'Para pedir apoyo: di llama a y el nombre, pide ayuda, o agregar contacto. '
      'Para ajustar: di más rápido, más lento, sube el volumen, baja el volumen, '
      'quita la vibración, o mi nombre es. '
      'También puedes decir qué hora es, algoritmos, o ayuda.';
}
