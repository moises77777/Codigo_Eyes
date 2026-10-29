import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio de reconocimiento de voz en español, sin conexión (Vosk).
///
/// El reconocedor de Google no funcionaba en el Vivo: le faltaba el
/// paquete offline de es-MX y el camino de red no devolvía resultados.
/// Vosk corre 100 % en el teléfono con el modelo de `android/.../assets`.
///
/// El contrato público se mantiene idéntico al anterior para no tocar
/// el controlador: [init], [listen], [escucharUnaVez], [stop], [dispose],
/// [isListening], [isAvailable] y [ultimoParcial].
class VoiceInputService {
  VoiceInputService._();

  static const MethodChannel _canal = MethodChannel('eyes/voz');
  static const EventChannel _eventos = EventChannel('eyes/voz/eventos');

  static StreamSubscription<dynamic>? _subEventos;
  static bool _initialized = false;
  static bool _isListening = false;
  static DateTime? _ultimoParcial;

  /// Callbacks de la escucha en curso.
  static void Function(String)? _onResultActual;
  static void Function(String)? _onParcialActual;
  static void Function(String)? _onErrorActual;
  static void Function()? _onFinActual;
  static bool _resultadoEntregado = false;

  /// La pausa de silencio la controla Dart (igual que antes): se
  /// reinicia con cada parcial no vacío; al cumplirse se pide el
  /// resultado final al motor nativo.
  static Timer? _timerSilencio;
  static Timer? _timerMaximo;
  static Duration _pausaSilencio = const Duration(seconds: 2);

  /// True cuando ya se pidió el cierre con 'parar': el resultado vacío
  /// que sigue significa "no se escuchó nada" (fin). Sin el pedido, un
  /// resultado vacío es solo ruido ambiente y la sesión continúa.
  static bool _esperandoFinal = false;

  static bool get isListening => _isListening;
  static bool get isAvailable => _initialized;

  /// Momento del último resultado parcial (el usuario está hablando).
  static DateTime? get ultimoParcial => _ultimoParcial;

  /// Inicializa el motor: desempaqueta el modelo de assets la primera
  /// vez (tarda unos segundos) y lo deja cargado en memoria.
  static Future<bool> init() async {
    if (_initialized) return true;
    try {
      _subEventos ??= _eventos.receiveBroadcastStream().listen(
            _procesarEvento,
            onError: (Object e) => debugPrint('Voz eventos error: $e'),
          );
      final ok = await _canal.invokeMethod<bool>('inicializar');
      _initialized = ok == true;
      return _initialized;
    } catch (e) {
      debugPrint('Error inicializando voz: $e');
      return false;
    }
  }

  /// Extrae el texto del JSON que entrega Vosk: {"partial": ...} o
  /// {"text": ...}. Devuelve '' si no hay texto.
  static String _textoDe(String? crudo, String campo) {
    if (crudo == null || crudo.isEmpty) return '';
    try {
      final dec = jsonDecode(crudo);
      if (dec is Map && dec[campo] is String) {
        return (dec[campo] as String).trim();
      }
    } catch (_) {
      // Si no es JSON, se toma el texto tal cual.
      return crudo.trim();
    }
    return '';
  }

  static void _procesarEvento(dynamic evento) {
    if (evento is! Map) return;
    final tipo = evento['tipo'] as String?;
    final crudo = evento['crudo'] as String?;
    final error = evento['error'] as String?;
    switch (tipo) {
      case 'parcial':
        final texto = _textoDe(crudo, 'partial');
        if (texto.isEmpty || !_isListening) return;
        debugPrint('[EYES voz] parcial: $texto');
        _ultimoParcial = DateTime.now();
        _onParcialActual?.call(texto);
        _timerSilencio?.cancel();
        _timerSilencio = Timer(_pausaSilencio, () {
          // Silencio tras hablar: pedir el resultado final al nativo.
          _esperandoFinal = true;
          _invocar('parar');
        });
      case 'resultado':
      case 'final':
        if (!_isListening && _resultadoEntregado) return;
        final texto = _textoDe(crudo, 'text');
        // Resultado vacío sin haber pedido el cierre: es solo ruido,
        // la sesión sigue viva hasta el timeout o el próximo texto.
        if (texto.isEmpty && !_esperandoFinal) return;
        if (texto.isNotEmpty) debugPrint('[EYES voz] resultado: $texto');
        _terminarEscucha(texto.isEmpty ? null : texto);
      case 'timeout':
        if (_isListening) _terminarEscucha(null);
      case 'error':
        _isListening = false;
        _resultadoEntregado = true;
        _timerSilencio?.cancel();
        _timerMaximo?.cancel();
        _onErrorActual?.call(error ?? 'Error de reconocimiento.');
    }
  }

  /// Cierra una escucha: entrega el resultado (o [onFin] si no hubo
  /// texto) una sola vez y cancela el micro del lado nativo.
  static void _terminarEscucha(String? texto) {
    _isListening = false;
    _esperandoFinal = false;
    _timerSilencio?.cancel();
    _timerMaximo?.cancel();
    if (_resultadoEntregado) return;
    _resultadoEntregado = true;
    // Si quedó una sesión abierta en el nativo, se cierra ya.
    _invocar('cancelar');
    if (texto != null && texto.isNotEmpty) {
      _onResultActual?.call(texto);
    } else {
      final fin = _onFinActual;
      _onFinActual = null;
      fin?.call();
    }
  }

  static Future<void> _invocar(String metodo) async {
    try {
      await _canal.invokeMethod(metodo);
    } catch (e) {
      debugPrint('Voz $metodo: $e');
    }
  }

  /// Empieza a escuchar y devuelve el texto reconocido por [onResult].
  /// [onPartial] recibe el texto parcial mientras el usuario habla.
  /// [onFin] se llama si la escucha se cierra sin resultado.
  ///
  /// [maxDuracion] es el tope duro del micro (lo aplica el nativo).
  /// [pausaSilencio] se mide con los parciales: tras ese tiempo sin
  /// hablar se pide el resultado final, sin cortar al usuario.
  static Future<void> listen({
    required void Function(String) onResult,
    void Function(String)? onError,
    void Function(String)? onPartial,
    void Function()? onFin,
    Duration maxDuracion = const Duration(seconds: 10),
    Duration pausaSilencio = const Duration(seconds: 2),
  }) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) {
        onError?.call('Reconocimiento de voz no disponible.');
        return;
      }
    }

    if (_isListening) {
      await _invocar('cancelar');
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _resultadoEntregado = false;
    _onResultActual = onResult;
    _onParcialActual = onPartial;
    _onErrorActual = onError;
    _onFinActual = onFin;
    _pausaSilencio = pausaSilencio;
    _timerSilencio?.cancel();
    _timerMaximo?.cancel();
    _esperandoFinal = false;
    _isListening = true;

    // Red de seguridad: si el timeout nativo no llega, pedimos el
    // resultado final desde aquí un poco después del tope.
    _timerMaximo = Timer(maxDuracion + const Duration(seconds: 2), () {
      if (_isListening) {
        _esperandoFinal = true;
        _invocar('parar');
      }
    });

    try {
      final ok = await _canal.invokeMethod<bool>('escuchar', {
        'timeoutMs': maxDuracion.inMilliseconds,
      });
      if (ok != true) _terminarEscucha(null);
    } catch (e) {
      _isListening = false;
      _timerMaximo?.cancel();
      onError?.call('Error al escuchar: $e');
    }
  }

  /// Escucha una sola frase y devuelve el texto final, o null si no se
  /// escuchó nada, hubo error o la escucha se cerró sin resultado.
  /// Siempre se completa (timeout de seguridad de [maxDuracion] + 3 s).
  static Future<String?> escucharUnaVez({
    Duration maxDuracion = const Duration(seconds: 8),
    Duration pausaSilencio = const Duration(seconds: 2),
    void Function(String)? onPartial,
  }) async {
    final completer = Completer<String?>();
    var hecho = false;

    void terminar(String? texto) {
      if (hecho) return;
      hecho = true;
      if (!completer.isCompleted) completer.complete(texto);
    }

    await listen(
      onResult: (texto) => terminar(texto.trim().isEmpty ? null : texto.trim()),
      onPartial: onPartial,
      onError: (_) => terminar(null),
      onFin: () => terminar(null),
      maxDuracion: maxDuracion,
      pausaSilencio: pausaSilencio,
    );

    return completer.future.timeout(
      maxDuracion + const Duration(seconds: 4),
      onTimeout: () {
        stop();
        return null;
      },
    );
  }

  /// Detiene la escucha actual de forma intencional: nunca dispara
  /// onFin ni onError, porque no es un cierre inesperado.
  static Future<void> stop() async {
    _timerSilencio?.cancel();
    _timerMaximo?.cancel();
    _resultadoEntregado = true;
    _onFinActual = null;
    _onErrorActual = null;
    _isListening = false;
    await _invocar('cancelar');
  }

  /// Libera recursos.
  static Future<void> dispose() async {
    _timerSilencio?.cancel();
    _timerMaximo?.cancel();
    await _invocar('cancelar');
    _initialized = false;
    _isListening = false;
  }
}
