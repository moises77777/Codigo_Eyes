import 'package:flutter/foundation.dart';

/// Medición simple de latencia por función: de la captura de la imagen
/// hasta el inicio de la voz. Sirve para el reporte de rendimiento.
class Latencia {
  Latencia._();

  /// Último tiempo medido por función, en milisegundos.
  static final Map<String, int> ultimas = {};

  /// Empieza a medir una operación llamada [nombre].
  static Stopwatch iniciar(String nombre) => Stopwatch()..start();

  /// Termina la medición, la guarda en [ultimas] y la imprime.
  static void fin(String nombre, Stopwatch sw) {
    sw.stop();
    ultimas[nombre] = sw.elapsedMilliseconds;
    debugPrint('[EYES latencia] $nombre: ${sw.elapsedMilliseconds} ms');
  }
}
