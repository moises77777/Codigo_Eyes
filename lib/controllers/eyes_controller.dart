import 'dart:async';

import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/resultado.dart';
import '../services/camera_service.dart';
import '../services/command_parser.dart';
import '../services/gemini_service.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/vision_service.dart';
import '../services/voice_input_service.dart';
import '../utils/busquedas.dart';
import '../utils/prioridades.dart';

/// Estados que se muestran en el panel de estado de Home.
enum EstadoEyes {
  listo,
  escuchando,
  identificando,
  leyendo,
  consultandoIA,
  sinConexionLocal,
  hablando,
  error,
}

/// Orquesta todos los servicios y la lógica de voz de EYES.
class EyesController extends ChangeNotifier {
  EyesController() {
    TtsService.onQueueEmpty = _onTtsQueueEmpty;
  }

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final CameraService _cameraService = CameraService();

  // Estado observable
  EstadoEyes _estado = EstadoEyes.listo;
  String _mensajeEstado = 'Listo para ayudarte';
  String _ultimoComandoEscuchado = '';
  Resultado? _ultimoResultado;
  List<Resultado> _historial = [];
  List<Resultado> _guardados = [];
  String _nombreUsuario = '';
  bool _escuchaContinua = true;
  bool _usarIaNube = false;
  bool _aceptoGemini = false;
  bool _hayInternet = true;
  bool _tiempoRealActivo = false;
  bool _ocupado = false;
  bool _procesandoFrame = false;
  int _reintentosEscucha = 0;
  String _ultimaRespuesta = '';
  String _ultimaEtiquetaContinua = '';
  int _framesVacios = 0;
  DateTime? _ultimoAnuncioTiempo;
  bool _esperandoConfirmacionBorrar = false;

  /// Etiquetas en español que significan "hay una persona enfrente".
  /// Se revisan antes que cualquier otro objeto detectado.
  static const _etiquetasPersona = {
    'persona', 'gente', 'hombre', 'mujer', 'niño', 'niña',
    'bebé', 'rostro', 'multitud', 'retrato',
  };

  /// Indica si la pantalla actual permite reiniciar la escucha automáticamente.
  /// Solo la pantalla principal lo activa, para no interferir en la bienvenida.
  bool autoEscucha = false;

  // Timers
  Timer? _timerReinicioEscucha;

  // Getters
  EstadoEyes get estado => _estado;
  String get mensajeEstado => _mensajeEstado;
  String get ultimoComandoEscuchado => _ultimoComandoEscuchado;
  Resultado? get ultimoResultado => _ultimoResultado;
  List<Resultado> get historial => List.unmodifiable(_historial);
  List<Resultado> get guardados => List.unmodifiable(_guardados);
  String get nombreUsuario => _nombreUsuario;
  bool get escuchaContinua => _escuchaContinua;
  bool get usarIaNube => _usarIaNube;
  bool get aceptoGemini => _aceptoGemini;
  bool get hayInternet => _hayInternet;
  bool get tiempoRealActivo => _tiempoRealActivo;
  bool get ocupado => _ocupado;
  bool get geminiDisponible => _hayInternet && _usarIaNube && _aceptoGemini;

  // -------------------- Inicialización --------------------

  Future<void> init() async {
    await StorageService.init();
    await TtsService.init();
    await VoiceInputService.init();
    await _cargarPreferencias();
    await _actualizarConexion();

    // Escuchar cambios de conectividad.
    Connectivity().onConnectivityChanged.listen((resultados) async {
      _hayInternet = resultados.isNotEmpty &&
          !resultados.contains(ConnectivityResult.none);
      if (!_hayInternet && _usarIaNube) {
        _setEstado(EstadoEyes.sinConexionLocal, 'Sin conexión - modo local');
        await hablar('Sin conexión, uso el modo local.');
      }
      notifyListeners();
    });
  }

  Future<void> _cargarPreferencias() async {
    _nombreUsuario = await StorageService.getNombre();
    _escuchaContinua = await StorageService.getEscuchaContinua();
    _usarIaNube = await StorageService.getUsarIaNube();
    _aceptoGemini = await StorageService.getAceptoGemini();
    _historial = await StorageService.getHistorial();
    _guardados = await StorageService.getGuardados();
    notifyListeners();
  }

  Future<void> _actualizarConexion() async {
    final result = await Connectivity().checkConnectivity();
    _hayInternet = result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  // -------------------- Utilidades de estado y voz --------------------

  void _setEstado(EstadoEyes e, [String mensaje = '']) {
    _estado = e;
    _mensajeEstado = mensaje.isEmpty ? _textoDeEstado(e) : mensaje;
    notifyListeners();
  }

  String _textoDeEstado(EstadoEyes e) {
    switch (e) {
      case EstadoEyes.listo:
        return 'Listo para ayudarte';
      case EstadoEyes.escuchando:
        return 'Escuchando…';
      case EstadoEyes.identificando:
        return 'Identificando objeto';
      case EstadoEyes.leyendo:
        return 'Leyendo texto';
      case EstadoEyes.consultandoIA:
        return 'Consultando a la IA';
      case EstadoEyes.sinConexionLocal:
        return 'Sin conexión - modo local';
      case EstadoEyes.hablando:
        return 'Hablando…';
      case EstadoEyes.error:
        return 'Error';
    }
  }

  Future<void> hablar(String texto, {bool guardarRespuesta = true}) async {
    if (texto.trim().isEmpty) return;
    _setEstado(EstadoEyes.hablando, 'Hablando…');
    if (guardarRespuesta) {
      _ultimaRespuesta = texto;
    }
    await TtsService.speak(texto);
  }

  Future<void> _onTtsQueueEmpty() async {
    // Volver a estado listo si no estamos en medio de otro proceso.
    if (!_ocupado && _estado == EstadoEyes.hablando) {
      _setEstado(
        _hayInternet ? EstadoEyes.listo : EstadoEyes.sinConexionLocal,
        _hayInternet ? 'Listo para ayudarte' : 'Sin conexión - modo local',
      );
    }
    // Reiniciar escucha continua de forma segura, solo si la pantalla lo permite.
    if (_escuchaContinua && autoEscucha && _reintentosEscucha < 3) {
      await Future.delayed(const Duration(milliseconds: 300));
      await iniciarEscucha();
    }
  }

  Future<void> _guardarEnHistorial(Resultado r) async {
    _ultimoResultado = r;
    _historial.insert(0, r);
    while (_historial.length > AppConfig.maxHistorial) {
      _historial.removeLast();
    }
    await StorageService.agregarHistorial(r);
    notifyListeners();
  }

  // -------------------- Cámara --------------------

  CameraService get cameraService => _cameraService;

  Future<bool> iniciarCamara() async {
    try {
      return await _cameraService.initialize();
    } catch (e) {
      await hablar('No pude abrir la cámara. Verifica los permisos.');
      return false;
    }
  }

  /// Toma una foto pausando el stream de tiempo real si está activo.
  Future<String?> _capturarImagen() async {
    final estabaActivo = _tiempoRealActivo;
    if (estabaActivo) await _cameraService.stopImageStream();
    final ruta = await _cameraService.takePicture();
    if (estabaActivo) await _cameraService.startImageStream(_procesarFrame);
    return ruta;
  }

  Future<void> detenerCamara() async {
    await _cameraService.dispose();
  }

  Future<void> pausarCamara() async {
    await _cameraService.pause();
    notifyListeners();
  }

  Future<bool> reanudarCamara() async {
    final ok = await _cameraService.resume();
    notifyListeners();
    return ok;
  }

  // -------------------- Escucha por voz --------------------

  Future<void> iniciarEscucha() async {
    if (VoiceInputService.isListening) return;

    // Detener voz solo si está hablando, para no escucharse a sí misma.
    if (TtsService.isSpeaking) {
      await TtsService.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    HapticFeedback.lightImpact();
    _setEstado(EstadoEyes.escuchando, 'Escuchando…');
    notifyListeners();

    await VoiceInputService.listen(
      onResult: (texto) async {
        // Ignorar ruido o susurros de menos de 2 letras.
        if (texto.trim().length < 2) {
          if (_escuchaContinua) await iniciarEscucha();
          return;
        }
        HapticFeedback.lightImpact();
        _reintentosEscucha = 0;
        _ultimoComandoEscuchado = texto;
        notifyListeners();
        await procesarComando(texto);
      },
      // Mostrar en el panel lo que va escuchando, sin esperar al final.
      onPartial: (parcial) {
        _ultimoComandoEscuchado = parcial;
        notifyListeners();
      },
      onError: (error) async {
        _reintentosEscucha++;
        if (_reintentosEscucha >= 3) {
          await hablar('El micrófono no responde. Toca la pantalla para volver a intentar.');
          _setEstado(EstadoEyes.error, 'Error de micrófono');
        } else if (_escuchaContinua) {
          await Future.delayed(const Duration(milliseconds: 400));
          await iniciarEscucha();
        } else {
          _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
        }
      },
    );

    // Timer de seguridad: si no se reconoció nada en 4 s, reiniciar.
    _timerReinicioEscucha?.cancel();
    _timerReinicioEscucha = Timer(const Duration(seconds: 4), () async {
      if (_escuchaContinua && !VoiceInputService.isListening && !_ocupado && _reintentosEscucha < 3) {
        _reintentosEscucha++;
        await iniciarEscucha();
      }
    });
  }

  Future<void> detenerEscucha() async {
    _timerReinicioEscucha?.cancel();
    await VoiceInputService.stop();
    if (_estado == EstadoEyes.escuchando) {
      _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    }
  }

  // -------------------- Procesamiento de comandos --------------------

  Future<void> procesarComando(String texto) async {
    await detenerEscucha();
    final parsed = CommandParser.interpretar(texto);

    switch (parsed.comando) {
      case Comando.identificar:
        await identificarObjeto();
        break;
      case Comando.describir:
        await describirEscena();
        break;
      case Comando.ocr:
        await leerTexto();
        break;
      case Comando.resumir:
        await leerYResumir();
        break;
      case Comando.preguntaImagen:
        final pregunta = parsed.argumento ?? parsed.textoOriginal;
        await preguntarSobreImagen(pregunta);
        break;
      case Comando.guardar:
        await guardarUltimoResultado();
        break;
      case Comando.repetir:
        await repetirUltimo();
        break;
      case Comando.historial:
        await abrirHistorial();
        break;
      case Comando.guardados:
        await abrirGuardados();
        break;
      case Comando.borrarHistorial:
        await _pedirConfirmacionBorrarHistorial();
        break;
      case Comando.deteccionContinua:
        await activarDeteccionContinua();
        break;
      case Comando.detener:
        await detenerTodo();
        break;
      case Comando.masRapido:
        await masRapido();
        break;
      case Comando.masLento:
        await masLento();
        break;
      case Comando.cambiarNombre:
        final nombre = _limpiarNombre(parsed.argumento ?? '');
        if (nombre.isNotEmpty) {
          await cambiarNombre(nombre);
        } else {
          await hablar(
            'No escuché tu nombre. Di "mi nombre es" seguido de tu nombre.',
            guardarRespuesta: false,
          );
        }
        break;
      case Comando.hora:
        await decirHora();
        break;
      case Comando.ayuda:
        await hablar(AppConfig.textoAyuda);
        break;
      case Comando.algoritmos:
        await demoAlgoritmos();
        break;
      case Comando.regresar:
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        break;
      case Comando.dejaDeEscuchar:
        _escuchaContinua = false;
        await StorageService.setEscuchaContinua(false);
        await hablar('Escucha continua desactivada. Toca el botón del micrófono cuando me necesites.');
        notifyListeners();
        break;
      case Comando.si:
        if (_esperandoConfirmacionBorrar) {
          await confirmarBorrarHistorial();
        } else if (geminiDisponible) {
          await _consultarGeminiConversacion(parsed.textoOriginal);
        } else {
          await hablar(
            'No entendí el comando. Di ayuda para conocer las opciones.',
            guardarRespuesta: false,
          );
        }
        break;
      case Comando.no:
        if (_esperandoConfirmacionBorrar) {
          _esperandoConfirmacionBorrar = false;
          await hablar('Borrado cancelado.', guardarRespuesta: false);
        } else if (geminiDisponible) {
          await _consultarGeminiConversacion(parsed.textoOriginal);
        } else {
          await hablar(
            'No entendí el comando. Di ayuda para conocer las opciones.',
            guardarRespuesta: false,
          );
        }
        break;
      case Comando.ninguno:
      case Comando.conversar:
        if (geminiDisponible) {
          await _consultarGeminiConversacion(parsed.textoOriginal);
        } else {
          await hablar(
            'No entendí el comando. Di ayuda para conocer las opciones.',
            guardarRespuesta: false,
          );
        }
        break;
    }
  }

  String _limpiarNombre(String texto) {
    final prefijos = [
      'me llamo ', 'mi nombre es ', 'soy ', 'yo soy ',
      'me dicen ', 'dime ', 'llamame ', 'llamame',
      'puedes decirme ', 'mi nombre ', 'nombre ',
    ];
    var t = texto.toLowerCase().trim();
    for (final p in prefijos) {
      if (t.startsWith(p)) {
        t = t.substring(p.length).trim();
        break;
      }
    }
    if (t.isEmpty) return '';
    return t
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  Future<void> _consultarGeminiConversacion(String pregunta) async {
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
    var respuesta = await GeminiService.conversar(pregunta);
    if (respuesta.isEmpty) {
      respuesta = 'No pude consultar a la inteligencia artificial. '
          'Revisa tu conexión o la clave en ajustes.';
    }
    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'conversar', texto: respuesta, usoIaNube: true),
    );
    await hablar(respuesta);
  }

  // -------------------- Funciones principales --------------------

  Future<void> identificarObjeto() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.identificando, 'Identificando objeto');

    final ruta = await _capturarImagen();
    if (ruta == null) {
      await hablar('No pude tomar la foto. Inténtalo de nuevo.');
      _ocupado = false;
      _setEstado(EstadoEyes.error, 'Error al capturar');
      return;
    }

    final local = await VisionService.identificar(ruta);
    String mensaje;
    bool usoIa = false;

    if (local != null && local.confianza >= 0.5) {
      final porcentaje = (local.confianza * 100).round();
      mensaje = 'Parece ${local.etiquetaEs}, con $porcentaje por ciento de confianza.';
    } else {
      if (geminiDisponible) {
        _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
        final detalle = await GeminiService.identificarDetallado(ruta);
        mensaje = detalle.isNotEmpty ? detalle : 'No reconozco el objeto. Acércalo un poco y mejora la iluminación.';
        usoIa = true;
      } else {
        mensaje = 'No reconozco el objeto. Acércalo un poco y mejora la iluminación.';
      }
    }

    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'identificar', texto: mensaje, usoIaNube: usoIa),
    );
    await hablar(mensaje);
    _ocupado = false;
    if (!_tiempoRealActivo) {
      _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    }
  }

  Future<void> leerTexto() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.leyendo, 'Leyendo texto');

    final ruta = await _capturarImagen();
    if (ruta == null) {
      await hablar('No pude tomar la foto. Inténtalo de nuevo.');
      _ocupado = false;
      return;
    }

    final texto = await OcrService.leerTexto(ruta);
    String mensaje;
    if (texto.isEmpty) {
      mensaje = 'No encuentro texto. Acerca el documento y mejora la iluminación.';
    } else {
      mensaje = texto;
    }

    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'ocr', texto: mensaje, usoIaNube: false),
    );
    await hablar(mensaje);
    _ocupado = false;
    if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
  }

  Future<void> describirEscena() async {
    if (!geminiDisponible) {
      await hablar('No hay conexión para describir la escena. Conecta internet o activa la IA en la nube.');
      return;
    }
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');

    final ruta = await _capturarImagen();
    if (ruta == null) {
      await hablar('No pude tomar la foto. Inténtalo de nuevo.');
      _ocupado = false;
      return;
    }

    var descripcion = await GeminiService.describirEscena(ruta);
    if (descripcion.isEmpty) {
      descripcion = 'No pude obtener la descripción. Revisa tu conexión.';
    }
    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'describir', texto: descripcion, usoIaNube: true),
    );
    await hablar(descripcion);
    _ocupado = false;
    if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
  }

  Future<void> preguntarSobreImagen(String pregunta) async {
    if (!geminiDisponible) {
      await hablar('No puedo consultar a la IA sin conexión o sin permiso. Revisa los ajustes.');
      return;
    }
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');

    final ruta = await _capturarImagen();
    if (ruta == null) {
      await hablar('No pude tomar la foto. Inténtalo de nuevo.');
      _ocupado = false;
      return;
    }

    var respuesta = await GeminiService.preguntarSobreImagen(ruta, pregunta);
    if (respuesta.isEmpty) {
      respuesta = 'No pude obtener una respuesta. Revisa tu conexión.';
    }
    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'pregunta', texto: respuesta, usoIaNube: true),
    );
    await hablar(respuesta);
    _ocupado = false;
    if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
  }

  Future<void> leerYResumir() async {
    if (!geminiDisponible) {
      await hablar('Necesito conexión a internet para resumir textos. Activa la IA en la nube.');
      return;
    }
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');

    final ruta = await _capturarImagen();
    if (ruta == null) {
      await hablar('No pude tomar la foto. Inténtalo de nuevo.');
      _ocupado = false;
      return;
    }

    var resumen = await GeminiService.leerYResumir(ruta);
    if (resumen.isEmpty) {
      resumen = 'No pude leer ni resumir el texto. Revisa tu conexión.';
    }
    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'resumen', texto: resumen, usoIaNube: true),
    );
    await hablar(resumen);
    _ocupado = false;
    if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
  }

  // -------------------- Detección en tiempo real --------------------

  /// Activa el stream de la cámara para detectar objetos en tiempo real.
  Future<void> activarDeteccionContinua() async {
    if (_tiempoRealActivo) {
      await hablar('La detección en tiempo real ya está activa.');
      return;
    }
    _tiempoRealActivo = true;
    _ultimaEtiquetaContinua = '';
    await hablar('Detección en tiempo real activada. Di detener para parar.');
    notifyListeners();

    await _cameraService.startImageStream(_procesarFrame);
  }

  /// Procesa cada frame del stream de la cámara.
  /// Solo anuncia cuando detecta un objeto distinto al anterior.
  Future<void> _procesarFrame(CameraImage frame) async {
    if (!_tiempoRealActivo || _ocupado || _procesandoFrame) return;
    if (TtsService.isSpeaking) return;

    // No interrumpir si el usuario está hablando ahora mismo
    // (o hizo una pausa corta dentro de su frase).
    final parcial = VoiceInputService.ultimoParcial;
    if (VoiceInputService.isListening &&
        parcial != null &&
        DateTime.now().difference(parcial).inMilliseconds < 2200) {
      return;
    }

    // Intervalo mínimo de 2.5 s entre anuncios para no cortar el micrófono
    // a cada rato — así la escucha se siente más rápida.
    if (_ultimoAnuncioTiempo != null &&
        DateTime.now().difference(_ultimoAnuncioTiempo!).inMilliseconds < 2500) {
      return;
    }

    _procesandoFrame = true;
    try {
      final candidatos = await VisionService.identificarFrameTodos(
        frame,
        _cameraService.sensorOrientation,
      );

      // Elegir el objeto más relevante con la heurística (como A* elige
      // el nodo con menor f): primero personas, luego el mayor puntaje
      // confianza × peso.
      final validos = candidatos.where((c) => c.confianza >= 0.5).toList();
      VisionResult? resultado;
      if (validos.isNotEmpty) {
        for (final c in validos) {
          if (_etiquetasPersona.contains(c.etiquetaEs.toLowerCase()) &&
              (resultado == null || c.confianza > resultado.confianza)) {
            resultado = c;
          }
        }
        resultado ??= validos.reduce((a, b) =>
            Prioridades.puntaje(a.etiquetaEs, a.confianza) >=
                    Prioridades.puntaje(b.etiquetaEs, b.confianza)
                ? a
                : b);
      }

      if (resultado == null) {
        // Si llevamos varios frames sin detectar nada, olvidamos la última
        // etiqueta para poder volver a anunciar el mismo objeto si reaparece.
        _framesVacios++;
        if (_framesVacios >= 12) {
          _ultimaEtiquetaContinua = '';
          _framesVacios = 0;
        }
        return;
      }
      _framesVacios = 0;

      // No repetir el mismo objeto dos veces seguidas.
      if (resultado.etiquetaEs.toLowerCase() ==
          _ultimaEtiquetaContinua.toLowerCase()) {
        return;
      }
      _ultimaEtiquetaContinua = resultado.etiquetaEs;

      // Aviso extra si el objeto es peligroso ("Cuidado: cuchillo").
      final esPeligroso = Prioridades.esPeligroso(resultado.etiquetaEs);
      final porcentaje = (resultado.confianza * 100).round();
      final texto = esPeligroso
          ? 'Cuidado: ${resultado.etiquetaEs}, $porcentaje por ciento.'
          : '${resultado.etiquetaEs}, $porcentaje por ciento.';

      // Guardar como último resultado para poder usar "guardar esto" o "repetir",
      // pero sin llenar el historial con cada frame.
      _ultimoResultado = Resultado.ahora(
        tipo: 'tiempo_real',
        texto: texto,
        confianza: resultado.confianza,
      );

      // Detener el micrófono para que no reconozca la propia voz de EYES.
      if (VoiceInputService.isListening) {
        await VoiceInputService.stop();
      }
      _ultimoAnuncioTiempo = DateTime.now();
      await hablar(_ultimoResultado!.texto);
      notifyListeners();
    } catch (e) {
      debugPrint('Error en frame: $e');
    } finally {
      _procesandoFrame = false;
    }
  }

  /// Detiene la detección en tiempo real.
  Future<void> detenerDeteccionContinua() async {
    _tiempoRealActivo = false;
    _ultimaEtiquetaContinua = '';
    await _cameraService.stopImageStream();
    notifyListeners();
  }

  // -------------------- Guardar, repetir, historial --------------------

  Future<void> guardarUltimoResultado() async {
    if (_ultimoResultado == null) {
      await hablar('No hay nada guardado aún. Primero identifica algo o lee un texto.');
      return;
    }
    await StorageService.agregarGuardado(_ultimoResultado!);
    _guardados = await StorageService.getGuardados();
    await hablar('Guardado como ${_ultimoResultado!.texto.split('.').first}.');
    notifyListeners();
  }

  Future<void> repetirUltimo() async {
    final texto = _ultimaRespuesta.isNotEmpty
        ? _ultimaRespuesta
        : _ultimoResultado?.texto ?? '';
    if (texto.isEmpty) {
      await hablar('No tengo nada que repetir.');
      return;
    }
    await hablar(texto, guardarRespuesta: false);
  }

  Future<void> abrirHistorial() async {
    navigatorKey.currentState?.pushNamed('/historial');
    if (_historial.isEmpty) {
      await hablar('No hay historial todavía.');
      return;
    }
    final n = _historial.length > 5 ? 5 : _historial.length;
    await hablar('Últimas $n cosas:');
    for (var i = 0; i < n; i++) {
      await hablar('${i + 1}. ${_historial[i].texto}', guardarRespuesta: false);
    }
  }

  Future<void> abrirGuardados() async {
    navigatorKey.currentState?.pushNamed('/guardados');
    if (_guardados.isEmpty) {
      await hablar('No tienes objetos guardados.');
      return;
    }
    await hablar('Tienes ${_guardados.length} objetos guardados.');
    for (final g in _guardados.take(5)) {
      await hablar(g.texto, guardarRespuesta: false);
    }
  }

  Future<void> _pedirConfirmacionBorrarHistorial() async {
    _esperandoConfirmacionBorrar = true;
    await hablar('Voy a borrar el historial. Di confirmar para continuar.');
  }

  /// Borra el historial de verdad: limpia SharedPreferences, actualiza
  /// la lista en pantalla y lo confirma por voz.
  /// Lo usan tanto el botón de la pantalla Historial como la voz.
  Future<void> borrarHistorial() async {
    await StorageService.borrarHistorial();
    _historial = [];
    _esperandoConfirmacionBorrar = false;
    await hablar('Historial borrado.');
    notifyListeners();
  }

  /// Confirma el borrado pedido por voz. Solo actúa si antes se dijo
  /// "borrar historial" y la app pidió confirmación.
  Future<void> confirmarBorrarHistorial() async {
    if (!_esperandoConfirmacionBorrar) return;
    await borrarHistorial();
  }

  Future<void> eliminarGuardado(String id) async {
    await StorageService.eliminarGuardado(id);
    _guardados = await StorageService.getGuardados();
    await hablar('Objeto eliminado.');
    notifyListeners();
  }

  // -------------------- Ajustes --------------------

  Future<void> masRapido() async {
    await TtsService.increaseRate();
    await hablar('Velocidad aumentada.', guardarRespuesta: false);
  }

  Future<void> masLento() async {
    await TtsService.decreaseRate();
    await hablar('Velocidad reducida.', guardarRespuesta: false);
  }

  Future<void> cambiarNombre(String nombre) async {
    _nombreUsuario = nombre;
    await StorageService.setNombre(nombre);
    notifyListeners();
    await hablar('Te llamaré $nombre.');
  }

  Future<void> decirHora() async {
    final ahora = DateTime.now();
    final h = ahora.hour.toString().padLeft(2, '0');
    final m = ahora.minute.toString().padLeft(2, '0');
    final meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    await hablar('Son las $h:$m del ${ahora.day} de ${meses[ahora.month - 1]} de ${ahora.year}.');
  }

  /// Demo por voz de los algoritmos de la práctica de heurística:
  /// ejecuta costo uniforme y A* sobre el árbol y explica el recorrido.
  Future<void> demoAlgoritmos() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.hablando, 'Ejecutando algoritmos');

    final ucs = Busquedas.costoUniforme('A', 'J');
    final ast = Busquedas.aEstrella('A', 'J');

    final resumen = 'Demostración de búsquedas. '
        'Costo uniforme: exploré ${ucs.orden.join(', ')}. '
        'La mejor ruta es ${ucs.camino.join(' a ')} con costo ${ucs.costoTotal}. '
        'A estrella: exploré ${ast.orden.join(', ')}. '
        'La mejor ruta es ${ast.camino.join(' a ')} con costo ${ast.costoTotal}. '
        'A estrella revisó ${ast.orden.length} nodos y costo uniforme '
        'revisó ${ucs.orden.length}.';

    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'algoritmos', texto: resumen),
    );
    await hablar(resumen);
    _ocupado = false;
    _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
  }

  Future<void> detenerTodo() async {
    await detenerDeteccionContinua();
    await TtsService.stop();
    await detenerEscucha();
    await hablar('Detenido.');
  }

  Future<void> setEscuchaContinua(bool valor) async {
    _escuchaContinua = valor;
    await StorageService.setEscuchaContinua(valor);
    notifyListeners();
  }

  Future<void> setUsarIaNube(bool valor) async {
    _usarIaNube = valor;
    await StorageService.setUsarIaNube(valor);
    await _actualizarConexion();
    notifyListeners();
  }

  Future<void> setAceptoGemini(bool valor) async {
    _aceptoGemini = valor;
    await StorageService.setAceptoGemini(valor);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    await StorageService.setGeminiApiKey(key);
    notifyListeners();
  }

  Future<void> setGeminiModel(String model) async {
    await StorageService.setGeminiModel(model);
    notifyListeners();
  }

  // -------------------- Bienvenida --------------------

  Future<void> finalizarBienvenida(String nombre, bool aceptaGemini) async {
    await cambiarNombre(nombre);
    await setAceptoGemini(aceptaGemini);
    await setUsarIaNube(aceptaGemini);
    await StorageService.setPrimerUsoCompletado(true);
  }

  // -------------------- Limpieza --------------------

  @override
  void dispose() {
    _timerReinicioEscucha?.cancel();
    _cameraService.dispose();
    VoiceInputService.dispose();
    TtsService.stop();
    super.dispose();
  }
}
