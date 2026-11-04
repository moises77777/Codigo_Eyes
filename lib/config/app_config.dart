/// Constantes y configuración central de EYES.
class AppConfig {
  AppConfig._();

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
