import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';
import '../models/contacto_apoyo.dart';
import '../models/resultado.dart';
import '../services/billetes_service.dart';
import '../services/camera_service.dart';
import '../services/color_service.dart';
import '../services/command_parser.dart';
import '../services/ia_nube_service.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../services/sincronizacion_service.dart';
import '../services/tts_service.dart';
import '../services/detector_service.dart';
import '../services/voice_input_service.dart';
import '../utils/busquedas.dart';
import '../utils/latencia.dart';
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
  bool _aceptoIaNube = false;
  bool _hayInternet = true;
  bool _tiempoRealActivo = false;
  bool _ocupado = false;
  bool _procesandoFrame = false;

  /// Última vez que se corrió el pipeline de detección/OCR de un frame.
  /// Sin este tope la inferencia se ejecuta en cada frame libre y el
  /// CPU se satura (la cámara se traba).
  DateTime? _ultimoProcesado;
  bool _vibracionActivada = true;
  bool _lecturaContinua = false;
  bool _encuadreActivo = false;
  String _ultimaInstruccionEncuadre = '';
  DateTime? _ultimoAnuncioEncuadre;
  String _candidatoActual = '';
  int _framesCandidato = 0;
  int _medicionesOscuras = 0;
  DateTime? _ultimaMedicionLuz;
  DateTime? _ultimoAvisoPocaLuz;
  List<ContactoApoyo> _contactos = [];
  final Set<String> _lineasLeidas = {};
  int _reintentosEscucha = 0;
  String _ultimaRespuesta = '';
  String _ultimaEtiquetaContinua = '';
  int _framesVacios = 0;
  DateTime? _ultimoAnuncioTiempo;
  bool _esperandoConfirmacionBorrar = false;
  String? _ultimaFoto;
  Timer? _timerSincronizacion;

  /// Etiquetas en español que significan "hay una persona enfrente".
  /// Se revisan antes que cualquier otro objeto detectado.
  static const _etiquetasPersona = {
    'persona', 'gente', 'hombre', 'mujer', 'niño', 'niña',
    'bebé', 'rostro', 'multitud', 'retrato',
  };

  /// Indica si la pantalla actual permite reiniciar la escucha automáticamente.
  /// Solo la pantalla principal lo activa, para no interferir en la bienvenida.
  bool autoEscucha = false;

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
  bool get aceptoIaNube => _aceptoIaNube;
  bool get hayInternet => _hayInternet;
  bool get tiempoRealActivo => _tiempoRealActivo;
  bool get ocupado => _ocupado;
  bool get vibracionActivada => _vibracionActivada;
  bool get lecturaContinua => _lecturaContinua;
  bool get encuadreActivo => _encuadreActivo;
  List<ContactoApoyo> get contactos => List.unmodifiable(_contactos);
  bool get iaNubeDisponible => _hayInternet && _usarIaNube && _aceptoIaNube;

  // -------------------- Inicialización --------------------

  Future<void> init() async {
    await StorageService.init();
    await StorageService.migrarClavesIa();
    await TtsService.init();
    await VoiceInputService.init();
    await DetectorService.cargar(
      modeloPropio: await StorageService.getModeloPropio(),
    );
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
      if (_hayInternet) {
        // Al recuperar internet, sincroniza lo pendiente con la nube.
        unawaited(SincronizacionService.sincronizarPendientes());
      }
      notifyListeners();
    });

    // Sincronización con la nube: al arrancar (tras 5 s) y cada 60 s.
    // Es fire-and-forget: nunca bloquea la voz ni la interfaz.
    Future.delayed(const Duration(seconds: 5), () {
      unawaited(SincronizacionService.sincronizarPendientes());
    });
    _timerSincronizacion = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(SincronizacionService.sincronizarPendientes());
    });
  }

  Future<void> _cargarPreferencias() async {
    _nombreUsuario = await StorageService.getNombre();
    _escuchaContinua = await StorageService.getEscuchaContinua();
    _usarIaNube = await StorageService.getUsarIaNube();
    _aceptoIaNube = await StorageService.getAceptoIaNube();
    _historial = await StorageService.getHistorial();
    _guardados = await StorageService.getGuardados();
    _vibracionActivada = await StorageService.getVibracion();
    _contactos = await StorageService.getContactos();
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

  /// Habla y además espera a que la cola quede vacía antes de regresar.
  /// Como [hablar] ya espera el fin de su frase, esto solo refuerza
  /// que no quede nada pendiente en la cola.
  Future<void> hablarYEsperar(String texto) async {
    await hablar(texto);
    await TtsService.esperarSilencio();
  }

  /// Vibración de apoyo, solo si el usuario la tiene activada.
  Future<void> _vibrar({bool fuerte = false}) async {
    if (!_vibracionActivada) return;
    if (fuerte) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Activa el modelo propio de detección; si no carga, queda el
  /// preentrenado y se avisa por voz.
  Future<void> setModeloPropio(bool valor) async {
    await StorageService.setModeloPropio(valor);
    unawaited(StorageService.setConfigPendiente(true));
    await DetectorService.cargar(modeloPropio: valor);
    if (valor && !DetectorService.usandoPropio) {
      await hablar('No encontré un modelo propio válido. Sigo con el preentrenado.');
    } else {
      await hablar(
        valor ? 'Modelo propio activado.' : 'Modelo preentrenado activado.',
        guardarRespuesta: false,
      );
    }
    notifyListeners();
  }

  /// Ajusta el umbral de confianza para anunciar detecciones.
  Future<void> setUmbralConfianza(double umbral) async {
    DetectorService.umbralConfianza = umbral;
    await StorageService.setUmbralConfianza(umbral);
    unawaited(StorageService.setConfigPendiente(true));
    notifyListeners();
  }

  Future<void> setVibracion(bool activa) async {
    _vibracionActivada = activa;
    await StorageService.setVibracion(activa);
    unawaited(StorageService.setConfigPendiente(true));
    notifyListeners();
  }

  Future<void> _onTtsQueueEmpty() async {
    // Volver a estado listo si no estamos en medio de otro proceso.
    if (!_ocupado && _estado == EstadoEyes.hablando) {
      _setEstado(
        _hayInternet ? EstadoEyes.listo : EstadoEyes.sinConexionLocal,
        _hayInternet ? 'Listo para ayudarte' : 'Sin conexión - modo local',
      );
    }
    // Reiniciar escucha continua de forma segura, solo si la pantalla lo
    // permite y no hay otra escucha o proceso en curso.
    if (_escuchaContinua &&
        autoEscucha &&
        !_ocupado &&
        !VoiceInputService.isListening &&
        _reintentosEscucha < 3) {
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
  /// El stream se reanuda SIEMPRE, aunque la captura falle.
  /// Las fotos son temporales: la anterior se borra al capturar otra.
  Future<String?> _capturarImagen() async {
    final estabaActivo = _tiempoRealActivo;
    if (estabaActivo) await _cameraService.stopImageStream();
    try {
      // Borrar la foto temporal anterior para no acumular archivos.
      if (_ultimaFoto != null) {
        try {
          await File(_ultimaFoto!).delete();
        } catch (_) {
          // Si ya no existe, no pasa nada.
        }
        _ultimaFoto = null;
      }
      final ruta = await _cameraService.takePicture();
      _ultimaFoto = ruta;
      return ruta;
    } finally {
      if (estabaActivo) await _cameraService.startImageStream(_procesarFrame);
    }
  }

  Future<void> detenerCamara() async {
    await _cameraService.dispose();
  }

  Future<void> pausarCamara() async {
    await _cameraService.setLinterna(false);
    await _cameraService.pause();
    notifyListeners();
  }

  Future<bool> reanudarCamara() async {
    final ok = await _cameraService.resume();
    // Si la detección en tiempo real estaba activa, reanudar el stream.
    if (ok && _tiempoRealActivo && !_cameraService.isStreaming) {
      await _cameraService.startImageStream(_procesarFrame);
    }
    notifyListeners();
    return ok;
  }

  // -------------------- Escucha por voz --------------------

  /// Abre el micrófono para escuchar un comando.
  /// Si [manual] es true (toque en pantalla) corta la voz y abre el micro
  /// al instante; si no, espera a que la app termine de hablar.
  Future<void> iniciarEscucha({bool manual = false}) async {
    if (VoiceInputService.isListening) return;

    if (manual) {
      // El usuario tiene prioridad: cortar cualquier anuncio de inmediato.
      _reintentosEscucha = 0;
      if (TtsService.isSpeaking) {
        await TtsService.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else if (TtsService.isSpeaking) {
      // Escucha automática: esperar a que termine de hablar, sin cortar.
      await TtsService.esperarSilencio();
      if (VoiceInputService.isListening) return;
    }

    await _vibrar();
    _setEstado(EstadoEyes.escuchando, 'Escuchando…');
    notifyListeners();

    await VoiceInputService.listen(
      maxDuracion: const Duration(seconds: 10),
      pausaSilencio: const Duration(seconds: 2),
      onResult: (texto) async {
        // Ignorar ruido o susurros de menos de 2 letras.
        if (texto.trim().length < 2) {
          await _onEscuchaSinResultado();
          return;
        }
        await _vibrar();
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
        await _onEscuchaSinResultado();
      },
      onFin: () async {
        await _onEscuchaSinResultado();
      },
    );
  }

  /// La escucha terminó sin reconocer nada: reintentar en silencio hasta
  /// 3 veces y después avisar una sola vez, sin entrar en bucle.
  Future<void> _onEscuchaSinResultado() async {
    if (!_escuchaContinua || _ocupado) {
      if (_estado == EstadoEyes.escuchando) {
        _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
      }
      return;
    }
    _reintentosEscucha++;
    if (_reintentosEscucha >= 3) {
      await hablar('No te escucho. Toca la pantalla cuando quieras hablarme.');
      return;
    }
    await Future.delayed(const Duration(seconds: 1));
    if (!_ocupado && !VoiceInputService.isListening && !TtsService.isSpeaking) {
      await iniciarEscucha();
    }
  }

  Future<void> detenerEscucha() async {
    await VoiceInputService.stop();
    if (_estado == EstadoEyes.escuchando) {
      _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    }
  }

  /// Pregunta de sí/no por voz. Devuelve true (sí), false (no) o null si
  /// tras [maxIntentos] no se entendió la respuesta.
  Future<bool?> pedirConfirmacion(
    String pregunta, {
    int maxIntentos = 3,
  }) async {
    final estabaOcupado = _ocupado;
    _ocupado = true;
    try {
      var textoPregunta = pregunta;
      for (var intento = 1; intento <= maxIntentos; intento++) {
        await hablar(textoPregunta, guardarRespuesta: false);
        await TtsService.esperarSilencio();
        await _vibrar();
        _setEstado(EstadoEyes.escuchando, 'Escuchando…');

        final texto = await VoiceInputService.escucharUnaVez(
          maxDuracion: const Duration(seconds: 8),
          pausaSilencio: const Duration(seconds: 2),
          onPartial: (parcial) {
            _ultimoComandoEscuchado = parcial;
            notifyListeners();
          },
        );
        if (CommandParser.esAfirmativo(texto ?? '')) return true;
        if (CommandParser.esNegativo(texto ?? '')) return false;
        if (intento < maxIntentos) {
          textoPregunta = 'No te escuché. Di sí o no.';
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      await hablar(
        'No te escuché. Lo dejamos para después; puedes volver a intentarlo cuando quieras.',
        guardarRespuesta: false,
      );
      return null;
    } finally {
      _ocupado = estabaOcupado;
      _restaurarEstadoIdle();
    }
  }

  /// Vuelve a un estado de reposo (según conectividad) sin pisar
  /// estados de proceso como identificando o consultando a la IA.
  void _restaurarEstadoIdle() {
    if (_estado == EstadoEyes.escuchando || _estado == EstadoEyes.hablando) {
      _setEstado(
        _hayInternet ? EstadoEyes.listo : EstadoEyes.sinConexionLocal,
        _hayInternet ? 'Listo para ayudarte' : 'Sin conexión - modo local',
      );
    }
  }

  /// Pregunta de texto libre por voz (nombre, contactos, etc.).
  /// Devuelve el texto o null si tras [maxIntentos] no se escuchó nada.
  Future<String?> pedirRespuesta(
    String pregunta, {
    int maxIntentos = 3,
    String mensajeReintento = 'No te escuché. Intentemos de nuevo.',
  }) async {
    final estabaOcupado = _ocupado;
    _ocupado = true;
    try {
      var textoPregunta = pregunta;
      for (var intento = 1; intento <= maxIntentos; intento++) {
        await hablar(textoPregunta, guardarRespuesta: false);
        await TtsService.esperarSilencio();
        await _vibrar();
        _setEstado(EstadoEyes.escuchando, 'Escuchando…');

        final texto = await VoiceInputService.escucharUnaVez(
          maxDuracion: const Duration(seconds: 8),
          pausaSilencio: const Duration(seconds: 2),
          onPartial: (parcial) {
            _ultimoComandoEscuchado = parcial;
            notifyListeners();
          },
        );
        if (texto != null && texto.trim().isNotEmpty) {
          return texto.trim();
        }
        if (intento < maxIntentos) {
          textoPregunta = mensajeReintento;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      await hablar(
        'No te escuché. Lo dejamos para después; puedes volver a intentarlo cuando quieras.',
        guardarRespuesta: false,
      );
      return null;
    } finally {
      _ocupado = estabaOcupado;
      _restaurarEstadoIdle();
    }
  }

  // -------------------- Procesamiento de comandos --------------------

  Future<void> procesarComando(String texto) async {
    // El comando del usuario tiene prioridad sobre cualquier anuncio.
    await TtsService.stop();
    await detenerEscucha();
    final parsed = CommandParser.interpretar(texto);
    debugPrint('[EYES cmd] "$texto" -> ${parsed.comando} (ocupado=$_ocupado)');

    try {
      if (_ocupado) {
        // Nunca ignorar en silencio: la persona no ve que seguimos
        // trabajando, hay que decírselo.
        await hablar('Un momento, todavía estoy trabajando.');
      } else {
        await _ejecutarComando(parsed);
      }
    } catch (e) {
      debugPrint('[EYES cmd] error ejecutando $texto: $e');
      await hablar('Algo falló al hacer eso. Inténtalo de nuevo.');
    } finally {
      // Tras cualquier comando, volver a abrir el micrófono aunque la
      // última frase se haya dicho con _ocupado = true (confirmaciones).
      if (_escuchaContinua &&
          autoEscucha &&
          !_ocupado &&
          !VoiceInputService.isListening &&
          !TtsService.isSpeaking &&
          _reintentosEscucha < 3) {
        await Future.delayed(const Duration(milliseconds: 300));
        await iniciarEscucha();
      }
    }
  }

  Future<void> _ejecutarComando(ComandoVoz parsed) async {
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
      case Comando.sincronizar:
        await sincronizarAhora();
        break;
      case Comando.borrarHistorial:
        final ok = await pedirConfirmacion(
          '¿Seguro que quieres borrar el historial? Di sí o no.',
        );
        if (ok == true) {
          await borrarHistorial();
        } else if (ok == false) {
          await hablar('Borrado cancelado.', guardarRespuesta: false);
        }
        break;
      case Comando.deteccionContinua:
        await activarDeteccionContinua();
        break;
      case Comando.leerContinuo:
        await activarLecturaContinua();
        break;
      case Comando.encuadrar:
        await activarGuiaEncuadre();
        break;
      case Comando.billete:
        await identificarBillete();
        break;
      case Comando.color:
        await identificarColor();
        break;
      case Comando.describirTodo:
        await describirTodo();
        break;
      case Comando.agregarContacto:
        await agregarContactoPorVoz();
        break;
      case Comando.llamar:
        await llamarContactoPorVoz(parsed.argumento ?? '');
        break;
      case Comando.pedirAyuda:
        await pedirAyuda();
        break;
      case Comando.misContactos:
        await listarContactos();
        break;
      case Comando.eliminarContacto:
        await eliminarContactoPorVoz(parsed.argumento ?? '');
        break;
      case Comando.subirVolumen:
        await subirVolumen();
        break;
      case Comando.bajarVolumen:
        await bajarVolumen();
        break;
      case Comando.quitarVibracion:
        await setVibracion(false);
        await hablar('Vibración desactivada.', guardarRespuesta: false);
        break;
      case Comando.ponerVibracion:
        await setVibracion(true);
        await hablar('Vibración activada.', guardarRespuesta: false);
        break;
      case Comando.linternaOn:
        await encenderLinterna();
        break;
      case Comando.linternaOff:
        await apagarLinterna();
        break;
      case Comando.detener:
        if (_encuadreActivo) {
          // Solo apaga la guía: el stream sigue en su modo anterior.
          _encuadreActivo = false;
          _ultimaInstruccionEncuadre = '';
          await hablar('Guía de encuadre desactivada.');
        } else if (_lecturaContinua) {
          // Solo apaga la lectura: el stream sigue en modo objetos.
          _lecturaContinua = false;
          _lineasLeidas.clear();
          _ultimaEtiquetaContinua = '';
          await hablar('Lectura continua desactivada. Sigo detectando objetos.');
        } else {
          await detenerTodo();
        }
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
          final respuesta = await pedirRespuesta(
            '¿Cómo quieres que te llame?',
            mensajeReintento: 'No escuché tu nombre. Dímelo otra vez.',
          );
          final nombreVoz = _limpiarNombre(respuesta ?? '');
          if (nombreVoz.isNotEmpty) {
            await cambiarNombre(nombreVoz);
          } else {
            await hablar(
              'No escuché tu nombre. Puedes cambiarlo después en ajustes.',
              guardarRespuesta: false,
            );
          }
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
        } else if (iaNubeDisponible) {
          await _consultarIaConversacion(parsed.textoOriginal);
        } else {
          await hablar(
            'No entendí el comando. Di ayuda para conocer las opciones.',
            guardarRespuesta: false,
          );
        }
        break;
      case Comando.no:
        if (_esperandoConfirmacionBorrar) {
          await cancelarBorrarHistorial();
        } else if (iaNubeDisponible) {
          await _consultarIaConversacion(parsed.textoOriginal);
        } else {
          await hablar(
            'No entendí el comando. Di ayuda para conocer las opciones.',
            guardarRespuesta: false,
          );
        }
        break;
      case Comando.ninguno:
      case Comando.conversar:
        if (iaNubeDisponible) {
          await _consultarIaConversacion(parsed.textoOriginal);
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

  /// Elige la detección más relevante: primero personas, luego el
  /// mayor puntaje confianza × peso de [Prioridades].
  Deteccion? _mejorDeteccion(Iterable<Deteccion> candidatas) {
    final lista = candidatas.toList();
    if (lista.isEmpty) return null;
    Deteccion? persona;
    for (final d in lista) {
      if (_etiquetasPersona.contains(d.etiqueta.toLowerCase()) &&
          (persona == null || d.confianza > persona.confianza)) {
        persona = d;
      }
    }
    if (persona != null) return persona;
    return lista.reduce((a, b) =>
        Prioridades.puntaje(a.etiqueta, a.confianza) >=
                Prioridades.puntaje(b.etiqueta, b.confianza)
            ? a
            : b);
  }

  Future<void> _consultarIaConversacion(String pregunta) async {
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
    final respuesta = await IaNubeService.conversar(pregunta);
    final mensaje = respuesta.ok
        ? respuesta.texto
        : (respuesta.error ??
            'No pude consultar a la inteligencia artificial.');
    await _guardarEnHistorial(
      Resultado.ahora(tipo: 'conversar', texto: mensaje, usoIaNube: true),
    );
    await hablar(mensaje);
  }

  // -------------------- Funciones principales --------------------

  Future<void> identificarObjeto() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.identificando, 'Identificando objeto');
    final sw = Latencia.iniciar('identificar');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
        _setEstado(EstadoEyes.error, 'Error al capturar');
        return;
      }

      final detecciones = await DetectorService.detectarFoto(ruta);
      final validas = detecciones
          .where((d) => d.etiqueta != 'objeto')
          .toList();
      final segura = _mejorDeteccion(
        validas.where((d) => d.confianza >= DetectorService.umbralConfianza),
      );
      final dudosa = _mejorDeteccion(
        validas.where((d) => d.confianza >= 0.45),
      );

      String mensaje;
      var usoIa = false;

      if (segura != null) {
        final porcentaje = (segura.confianza * 100).round();
        mensaje =
            'Es ${segura.etiqueta}, con $porcentaje por ciento de confianza.';
      } else if (dudosa != null && iaNubeDisponible) {
        // Confianza media: solo la IA puede detallarlo sin adivinar.
        _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
        final detalle = await IaNubeService.identificarDetallado(ruta);
        mensaje = detalle.ok
            ? detalle.texto
            : (detalle.error ??
                'No estoy seguro de qué es. Acércalo o mejora la luz.');
        usoIa = detalle.ok;
      } else {
        mensaje = 'No estoy seguro de qué es. Acércalo o mejora la luz.';
      }

      await _guardarEnHistorial(
        Resultado.ahora(tipo: 'identificar', texto: mensaje, usoIaNube: usoIa),
      );
      Latencia.fin('identificar', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) {
        _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
      }
    } finally {
      _ocupado = false;
    }
  }

  Future<void> leerTexto() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.leyendo, 'Leyendo texto');
    final sw = Latencia.iniciar('leer texto');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
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
      Latencia.fin('leer texto', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
  }

  Future<void> describirEscena() async {
    if (!iaNubeDisponible) {
      await hablar('No hay conexión para describir la escena. Conecta internet o activa la IA en la nube.');
      return;
    }
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
    final sw = Latencia.iniciar('describir');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
        return;
      }

      final descripcion = await IaNubeService.describirEscena(ruta);
      final mensaje = descripcion.ok
          ? descripcion.texto
          : (descripcion.error ??
              'No pude obtener la descripción. Revisa tu conexión.');
      await _guardarEnHistorial(
        Resultado.ahora(tipo: 'describir', texto: mensaje, usoIaNube: true),
      );
      Latencia.fin('describir', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
  }

  Future<void> preguntarSobreImagen(String pregunta) async {
    if (!iaNubeDisponible) {
      await hablar('No puedo consultar a la IA sin conexión o sin permiso. Revisa los ajustes.');
      return;
    }
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
    final sw = Latencia.iniciar('pregunta imagen');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
        return;
      }

      final respuesta = await IaNubeService.preguntarSobreImagen(ruta, pregunta);
      final mensaje = respuesta.ok
          ? respuesta.texto
          : (respuesta.error ??
              'No pude obtener una respuesta. Revisa tu conexión.');
      await _guardarEnHistorial(
        Resultado.ahora(tipo: 'pregunta', texto: mensaje, usoIaNube: true),
      );
      Latencia.fin('pregunta imagen', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
  }

  Future<void> leerYResumir() async {
    if (!iaNubeDisponible) {
      await hablar('Necesito conexión a internet para resumir textos. Activa la IA en la nube.');
      return;
    }
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
    final sw = Latencia.iniciar('resumir');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
        return;
      }

      final resumen = await IaNubeService.leerYResumir(ruta);
      final mensaje = resumen.ok
          ? resumen.texto
          : (resumen.error ??
              'No pude leer ni resumir el texto. Revisa tu conexión.');
      await _guardarEnHistorial(
        Resultado.ahora(tipo: 'resumen', texto: mensaje, usoIaNube: true),
      );
      Latencia.fin('resumir', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
  }

  /// Identifica un billete mexicano: número por OCR local, pista por
  /// color y, como último recurso con internet, una pregunta a la IA.
  Future<void> identificarBillete() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.identificando, 'Identificando billete');
    final sw = Latencia.iniciar('billete');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
        _setEstado(EstadoEyes.error, 'Error al capturar');
        return;
      }

      final billete = await BilletesService.identificar(ruta);
      String mensaje;
      var usoIa = false;

      if (billete.confiable) {
        mensaje = 'Es un billete de ${billete.denominacion} pesos.';
      } else if (billete.pista != null) {
        mensaje = 'No alcanzo a leer el número. Por el color podría ser de '
            '${billete.pista} pesos. Estira el billete y acércalo a la cámara.';
      } else if (iaNubeDisponible) {
        _setEstado(EstadoEyes.consultandoIA, 'Consultando a la IA');
        final respuesta = await IaNubeService.preguntarSobreImagen(
          ruta,
          '¿Qué billete mexicano aparece y de qué denominación? '
          'Responde en una frase corta, solo la denominación en pesos.',
        );
        mensaje = respuesta.ok
            ? respuesta.texto
            : (respuesta.error ?? 'No pude reconocer el billete. '
                'Estira el billete, acércalo a la cámara y busca buena luz.');
        usoIa = respuesta.ok;
      } else {
        mensaje = 'No pude reconocer el billete. Estira el billete, '
            'acércalo a la cámara y busca buena luz.';
      }

      await _guardarEnHistorial(
        Resultado.ahora(tipo: 'billete', texto: mensaje, usoIaNube: usoIa),
      );
      Latencia.fin('billete', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
  }

  /// Dice el color dominante de lo que está frente a la cámara.
  Future<void> identificarColor() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.identificando, 'Identificando color');
    final sw = Latencia.iniciar('color');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
        _setEstado(EstadoEyes.error, 'Error al capturar');
        return;
      }

      final color = await ColorService.colorDominante(ruta);
      final String mensaje;
      if (color.principal.isEmpty) {
        mensaje = 'No pude distinguir el color. Acércate y mejora la luz.';
      } else if (color.secundario != null) {
        mensaje = 'El color principal es ${color.principal}, '
            'con algo de ${color.secundario}.';
      } else {
        mensaje = 'Es de color ${color.principal}.';
      }

      await _guardarEnHistorial(
        Resultado.ahora(tipo: 'color', texto: mensaje, usoIaNube: false),
      );
      Latencia.fin('color', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
  }

  /// Describe todo lo que ve la cámara: con la IA si hay conexión,
  /// si no con los modelos locales (objetos + color + texto).
  Future<void> describirTodo() async {
    if (_ocupado) return;
    _ocupado = true;
    _setEstado(EstadoEyes.consultandoIA, 'Describiendo la escena');
    final sw = Latencia.iniciar('describe todo');

    try {
      final ruta = await _capturarImagen();
      if (ruta == null) {
        await hablar('No pude tomar la foto. Inténtalo de nuevo.');
        _setEstado(EstadoEyes.error, 'Error al capturar');
        return;
      }

      String mensaje;
      var usoIa = false;
      if (iaNubeDisponible) {
        final descripcion = await IaNubeService.describirEscena(ruta);
        mensaje = descripcion.ok
            ? descripcion.texto
            : (descripcion.error ??
                'No pude obtener la descripción. Revisa tu conexión.');
        usoIa = descripcion.ok;
      } else {
        // Versión local: hasta 3 objetos, el color y el texto visible.
        final partes = <String>[];

        final candidatos = await DetectorService.detectarFoto(ruta);
        final etiquetas = candidatos
            .where((c) =>
                c.confianza >= DetectorService.umbralConfianza &&
                c.etiqueta != 'objeto')
            .map((c) => c.etiqueta)
            .take(3)
            .toList();
        if (etiquetas.isNotEmpty) {
          final ultima = etiquetas.length > 1 ? etiquetas.removeLast() : null;
          partes.add(ultima == null
              ? 'Veo: ${etiquetas.first}.'
              : 'Veo: ${etiquetas.join(', ')} y $ultima.');
        }

        final color = await ColorService.colorDominante(ruta);
        if (color.principal.isNotEmpty) {
          partes.add('El color principal es ${color.principal}.');
        }

        final texto = await OcrService.leerTexto(ruta);
        if (texto.isNotEmpty) {
          final corto =
              texto.length > 120 ? texto.substring(0, 120) : texto;
          partes.add('Hay texto que dice: $corto');
        }

        mensaje = partes.isEmpty
            ? 'No distingo objetos claros. Acércate o mejora la luz.'
            : partes.join(' ');
      }

      await _guardarEnHistorial(
        Resultado.ahora(tipo: 'describir', texto: mensaje, usoIaNube: usoIa),
      );
      Latencia.fin('describe todo', sw);
      await hablar(mensaje);
      if (!_tiempoRealActivo) _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
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

    if (!_cameraService.isStreaming) {
      await _cameraService.startImageStream(_procesarFrame);
    }
  }

  /// Activa la lectura continua de texto sobre el stream de la cámara.
  Future<void> activarLecturaContinua() async {
    if (_lecturaContinua) {
      await hablar('La lectura continua ya está activa.');
      return;
    }
    _lecturaContinua = true;
    _tiempoRealActivo = true;
    _lineasLeidas.clear();
    _ultimoAnuncioTiempo = null;
    await hablar('Lectura continua activada. Di detener para parar.');
    notifyListeners();

    if (!_cameraService.isStreaming) {
      await _cameraService.startImageStream(_procesarFrame);
    }
  }

  /// Activa la guía de encuadre por voz y vibración: dice hacia dónde
  /// mover el teléfono para centrar lo que hay enfrente.
  Future<void> activarGuiaEncuadre() async {
    if (_encuadreActivo) {
      await hablar('La guía de encuadre ya está activa.');
      return;
    }
    _encuadreActivo = true;
    _tiempoRealActivo = true;
    _ultimaInstruccionEncuadre = '';
    _ultimoAnuncioEncuadre = null;
    await hablar(
      'Guía de encuadre activada. Te diré hacia dónde mover el teléfono. '
      'Di detener para salir.',
    );
    notifyListeners();

    if (!_cameraService.isStreaming) {
      await _cameraService.startImageStream(_procesarFrame);
    }
  }

  /// Rama de guía de encuadre: busca la caja más grande (objetos, o
  /// texto si la lectura continua está activa o no hay objetos) y dice
  /// cómo centrarla. ML Kit devuelve las cajas en el sistema de la
  /// imagen YA ROTADA, así que con rotación de 90/270 grados el ancho y
  /// el alto del frame se intercambian.
  Future<void> _procesarFrameEncuadre(CameraImage frame) async {
    final sensor = _cameraService.sensorOrientation;
    final detecciones = await DetectorService.detectarFrame(frame, sensor);
    // Para encuadrar basta 0.4 de confianza (no hace falta el umbral alto).
    final cajas = detecciones
        .where((d) => d.confianza >= 0.4)
        .map((d) => d.caja)
        .toList();

    Rect? caja;
    for (final c in cajas) {
      if (caja == null || c.width * c.height > caja.width * caja.height) {
        caja = c;
      }
    }
    if (caja == null || _lecturaContinua) {
      final cajaTexto = await OcrService.cajaTextoFrame(frame, sensor);
      if (cajaTexto != null &&
          (caja == null ||
              cajaTexto.width * cajaTexto.height >
                  caja.width * caja.height)) {
        caja = cajaTexto;
      }
    }

    // Ancho y alto "derechos": igual que se muestran en el preview.
    final rotado = sensor == 90 || sensor == 270;
    final w = rotado ? frame.height.toDouble() : frame.width.toDouble();
    final h = rotado ? frame.width.toDouble() : frame.height.toDouble();

    String instruccion;
    // 0: sin vibración, 1: mover, 2: acercar/alejar, 3: centrado.
    var tipoVibracion = 0;

    if (caja == null) {
      instruccion = 'No veo nada enfrente. Mueve el teléfono despacio.';
    } else {
      final dx = (caja.center.dx - w / 2) / (w / 2);
      final dy = (caja.center.dy - h / 2) / (h / 2);
      final area = (caja.width * caja.height) / (w * h);

      if (dx.abs() > 0.22) {
        instruccion = dx > 0
            ? 'Mueve el teléfono a la derecha'
            : 'Mueve el teléfono a la izquierda';
        tipoVibracion = 1;
      } else if (dy.abs() > 0.22) {
        instruccion = dy < 0
            ? 'Mueve el teléfono hacia arriba'
            : 'Mueve el teléfono hacia abajo';
        tipoVibracion = 1;
      } else if (area < 0.12) {
        instruccion = 'Acércate un poco';
        tipoVibracion = 2;
      } else if (area > 0.75) {
        instruccion = 'Aléjate un poco';
        tipoVibracion = 2;
      } else {
        instruccion = 'Bien, está centrado.';
        tipoVibracion = 3;
      }
    }

    // Anunciar solo cuando la instrucción cambia o tras el intervalo
    // (3 s la misma, 5 s si ya está centrado).
    final ahora = DateTime.now();
    final centrado = instruccion.startsWith('Bien');
    final intervalo = centrado ? 5000 : 3000;
    if (instruccion == _ultimaInstruccionEncuadre &&
        _ultimoAnuncioEncuadre != null &&
        ahora.difference(_ultimoAnuncioEncuadre!).inMilliseconds < intervalo) {
      return;
    }
    _ultimaInstruccionEncuadre = instruccion;
    _ultimoAnuncioEncuadre = ahora;
    _ultimoAnuncioTiempo = ahora;

    if (tipoVibracion == 1) {
      await _vibrar();
    } else if (tipoVibracion == 2) {
      await _vibrar();
      await Future.delayed(const Duration(milliseconds: 120));
      await _vibrar();
    } else if (tipoVibracion == 3) {
      for (var i = 0; i < 3; i++) {
        if (i > 0) await Future.delayed(const Duration(milliseconds: 90));
        await _vibrar(fuerte: true);
      }
    }

    if (VoiceInputService.isListening) {
      await VoiceInputService.stop();
    }
    await hablar(instruccion, guardarRespuesta: false);
    notifyListeners();
  }

  /// Procesa cada frame del stream de la cámara.
  /// Solo anuncia cuando detecta un objeto distinto al anterior.
  Future<void> _procesarFrame(CameraImage frame) async {
    if (!_tiempoRealActivo || _ocupado || _procesandoFrame) return;
    if (TtsService.isSpeaking) return;

    // No interrumpir si el usuario está hablando ahora mismo
    // (o hizo una pausa corta dentro de su frase). Ventana corta:
    // con Vosk los parciales por ruido ambiente son frecuentes y una
    // ventana larga silenciaba del todo los anuncios.
    final parcial = VoiceInputService.ultimoParcial;
    if (VoiceInputService.isListening &&
        parcial != null &&
        DateTime.now().difference(parcial).inMilliseconds < 1200) {
      return;
    }

    // El throttle de 2.5 s se aplica solo a la ETAPA de anuncio; al
    // análisis se le aplica un tope de ~2.5 fps para no saturar el CPU
    // (la confirmación de 3 frames sigue funcionando a ese ritmo).
    final ahoraProc = DateTime.now();
    if (_ultimoProcesado != null &&
        ahoraProc.difference(_ultimoProcesado!).inMilliseconds < 400) {
      return;
    }
    _ultimoProcesado = ahoraProc;
    _procesandoFrame = true;
    final sw = Latencia.iniciar('tiempo real');
    try {
      // Vigilar la luz ambiente cada ~3 s para sugerir la linterna.
      await _vigilarLuzAmbiente(frame);

      // La guía de encuadre tiene prioridad sobre objetos y lectura.
      if (_encuadreActivo) {
        await _procesarFrameEncuadre(frame);
        return;
      }
      // Modo lectura continua: OCR por frame en lugar de objetos.
      if (_lecturaContinua) {
        await _procesarFrameOcr(frame, sw);
        return;
      }

      final detecciones = await DetectorService.detectarFrame(
        frame,
        _cameraService.sensorOrientation,
      );

      // Candidatos sobre el umbral con nombre real (nunca 'objeto' ni '???').
      final validos = detecciones
          .where((d) =>
              d.confianza >= DetectorService.umbralConfianza &&
              d.etiqueta != 'objeto')
          .toList();
      final mejor = _mejorDeteccion(validos);

      if (mejor == null) {
        // Frames vacíos: tras 12 se olvida la última etiqueta anunciada.
        _framesVacios++;
        _candidatoActual = '';
        _framesCandidato = 0;
        if (_framesVacios >= 12) {
          _ultimaEtiquetaContinua = '';
          _framesVacios = 0;
        }
        return;
      }
      _framesVacios = 0;

      // Confirmación: la misma etiqueta debe verse 3 frames seguidos
      // para no anunciar parpadeos del modelo.
      if (mejor.etiqueta == _candidatoActual) {
        _framesCandidato++;
      } else {
        _candidatoActual = mejor.etiqueta;
        _framesCandidato = 1;
      }
      if (_framesCandidato < DetectorService.framesConfirmacion) return;

      // No repetir el mismo objeto dos veces seguidas.
      if (mejor.etiqueta.toLowerCase() ==
          _ultimaEtiquetaContinua.toLowerCase()) {
        return;
      }

      // Throttle de anuncio (2.5 s) aquí, no en el análisis.
      if (_ultimoAnuncioTiempo != null &&
          DateTime.now().difference(_ultimoAnuncioTiempo!).inMilliseconds <
              2500) {
        return;
      }
      _ultimaEtiquetaContinua = mejor.etiqueta;

      // Aviso extra si el objeto es peligroso ("Cuidado: cuchillo").
      final esPeligroso = Prioridades.esPeligroso(mejor.etiqueta);
      final porcentaje = (mejor.confianza * 100).round();
      final texto = esPeligroso
          ? 'Cuidado: ${mejor.etiqueta}, $porcentaje por ciento.'
          : '${mejor.etiqueta}, $porcentaje por ciento.';

      // Guardar como último resultado para poder usar "guardar esto" o "repetir",
      // pero sin llenar el historial con cada frame.
      _ultimoResultado = Resultado.ahora(
        tipo: 'tiempo_real',
        texto: texto,
        confianza: mejor.confianza,
      );

      // Detener el micrófono para que no reconozca la propia voz de EYES.
      if (VoiceInputService.isListening) {
        await VoiceInputService.stop();
      }
      _ultimoAnuncioTiempo = DateTime.now();
      Latencia.fin('tiempo real', sw);
      await hablar(_ultimoResultado!.texto);
      notifyListeners();
    } catch (e) {
      debugPrint('Error en frame: $e');
    } finally {
      _procesandoFrame = false;
    }
  }

  /// Rama OCR de [_procesarFrame]: lee el texto del frame y anuncia solo
  /// las líneas nuevas (que no se hayan leído ya en esta sesión).
  Future<void> _procesarFrameOcr(CameraImage frame, Stopwatch sw) async {
    final texto = await OcrService.reconocerFrame(
      frame,
      _cameraService.sensorOrientation,
    );
    if (texto.isEmpty) return;

    final nuevas = <String>[];
    for (final linea in texto.split('\n')) {
      final normalizada = _normalizarLinea(linea);
      if (normalizada.length < 3) continue;
      if (_lineasLeidas.add(normalizada)) {
        // El Set conserva orden de inserción: al llenarse se quita la más vieja.
        if (_lineasLeidas.length > 80) {
          _lineasLeidas.remove(_lineasLeidas.first);
        }
        final limpia = linea.trim();
        if (limpia.isNotEmpty) nuevas.add(limpia);
      }
    }
    if (nuevas.isEmpty) return;

    var mensaje = nuevas.join('. ');
    if (mensaje.length > 250) {
      mensaje = mensaje.substring(0, 250);
    }

    _ultimoResultado = Resultado.ahora(tipo: 'lectura_continua', texto: mensaje);

    // Detener el micrófono para que no reconozca la propia voz de EYES.
    if (VoiceInputService.isListening) {
      await VoiceInputService.stop();
    }
    _ultimoAnuncioTiempo = DateTime.now();
    Latencia.fin('tiempo real', sw);
    await hablar(mensaje);
    notifyListeners();
  }

  /// Mide la luminancia media del plano Y cada ~3 s. Si hay poca luz
  /// (media < 50 de 255) durante 3 mediciones seguidas y la linterna
  /// está apagada, pregunta una vez por minuto si encenderla.
  Future<void> _vigilarLuzAmbiente(CameraImage frame) async {
    final ahora = DateTime.now();
    if (_ultimaMedicionLuz != null &&
        ahora.difference(_ultimaMedicionLuz!).inMilliseconds < 3000) {
      return;
    }
    _ultimaMedicionLuz = ahora;

    // Muestrear 1 de cada 64 píxeles para que sea barato.
    final plane = frame.planes.first;
    var suma = 0;
    var cuenta = 0;
    for (var i = 0; i < plane.bytes.length; i += 64) {
      suma += plane.bytes[i];
      cuenta++;
    }
    final media = cuenta == 0 ? 0 : suma ~/ cuenta;

    if (media < 50) {
      _medicionesOscuras++;
    } else {
      _medicionesOscuras = 0;
    }

    final pasoMinuto = _ultimoAvisoPocaLuz == null ||
        ahora.difference(_ultimoAvisoPocaLuz!).inSeconds >= 60;
    if (_medicionesOscuras >= 3 &&
        !_cameraService.linternaEncendida &&
        pasoMinuto &&
        !_ocupado) {
      _ultimoAvisoPocaLuz = ahora;
      _medicionesOscuras = 0;
      final ok = await pedirConfirmacion(
        'Hay poca luz. ¿Enciendo la linterna? Di sí o no.',
      );
      if (ok == true) {
        await encenderLinterna();
      }
    }
  }

  /// Enciende la linterna o avisa que el equipo no tiene.
  Future<void> encenderLinterna() async {
    final ok = await _cameraService.setLinterna(true);
    await hablar(
      ok ? 'Linterna encendida.' : 'Este teléfono no tiene linterna.',
      guardarRespuesta: false,
    );
  }

  /// Apaga la linterna o avisa que el equipo no tiene.
  Future<void> apagarLinterna() async {
    final ok = await _cameraService.setLinterna(false);
    await hablar(
      ok ? 'Linterna apagada.' : 'Este teléfono no tiene linterna.',
      guardarRespuesta: false,
    );
  }

  /// Normaliza una línea de texto para compararla: minúsculas,
  /// sin acentos y sin espacios extra.
  static String _normalizarLinea(String linea) {
    var t = linea.toLowerCase().trim();
    const conAcentos = 'áéíóúüñ';
    const sinAcentos = 'aeiouun';
    final buffer = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final idx = conAcentos.indexOf(t[i]);
      buffer.write(idx >= 0 ? sinAcentos[idx] : t[i]);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Detiene la detección en tiempo real.
  Future<void> detenerDeteccionContinua() async {
    _tiempoRealActivo = false;
    _lecturaContinua = false;
    _encuadreActivo = false;
    _ultimaInstruccionEncuadre = '';
    _lineasLeidas.clear();
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

  /// Marca que se pidió confirmación de borrado (usado por la UI).
  Future<void> pedirConfirmacionBorrarHistorial() async {
    _esperandoConfirmacionBorrar = true;
    await hablar('Voy a borrar el historial. Di confirmar para continuar.');
  }

  /// Borra el historial de verdad: limpia SharedPreferences, actualiza
  /// la lista en pantalla y lo confirma por voz.
  /// Lo usan tanto el botón de la pantalla Historial como la voz.
  Future<void> borrarHistorial() async {
    await StorageService.borrarHistorial();
    // Encolar el borrado completo para la nube.
    await StorageService.encolarBorrado('historial:*');
    _historial = [];
    _esperandoConfirmacionBorrar = false;
    await hablar('Historial borrado.');
    notifyListeners();
  }

  /// Sincroniza los datos pendientes con la nube ahora (comando de voz
  /// 'sincronizar' y botón 'Sincronizar ahora' de Ajustes).
  Future<void> sincronizarAhora() async {
    final url = await SincronizacionService.urlConfigurada();
    if (url.isEmpty) {
      await hablar(
        'No hay servidor configurado. Agrégalo en ajustes.',
        guardarRespuesta: false,
      );
      return;
    }
    if (!_hayInternet) {
      await hablar(
        'No hay conexión. Se sincronizará cuando haya internet.',
        guardarRespuesta: false,
      );
      return;
    }
    final ok = await SincronizacionService.sincronizarPendientes();
    await hablar(
      ok
          ? 'Datos sincronizados con la nube.'
          : 'No pude sincronizar: ${SincronizacionService.ultimoError ?? 'error desconocido'}.',
      guardarRespuesta: false,
    );
    notifyListeners();
  }

  /// Confirma el borrado pedido por voz. Solo actúa si antes se dijo
  /// "borrar historial" y la app pidió confirmación.
  Future<void> confirmarBorrarHistorial() async {
    if (!_esperandoConfirmacionBorrar) return;
    await borrarHistorial();
  }

  /// Cancela el borrado pedido por voz, si había una confirmación pendiente.
  Future<void> cancelarBorrarHistorial() async {
    if (!_esperandoConfirmacionBorrar) return;
    _esperandoConfirmacionBorrar = false;
    await hablar('Borrado cancelado.', guardarRespuesta: false);
  }

  Future<void> eliminarGuardado(String id) async {
    // Buscar el idLocal antes de borrar para encolar el borrado en la nube.
    final previo = _guardados.where((e) => e.id == id).toList();
    await StorageService.eliminarGuardado(id);
    if (previo.isNotEmpty) {
      await StorageService.encolarBorrado('guardado:${previo.first.idLocal}');
    }
    _guardados = await StorageService.getGuardados();
    await hablar('Objeto eliminado.');
    notifyListeners();
  }

  // -------------------- Contactos de apoyo --------------------

  /// Alta por voz: pide nombre, número dígito por dígito y confirma.
  Future<void> agregarContactoPorVoz() async {
    final respuestaNombre = await pedirRespuesta('¿Cómo se llama la persona?');
    final nombre = _limpiarNombre(respuestaNombre ?? '');
    if (nombre.isEmpty) {
      await hablar(
        'No escuché el nombre. Puedes intentarlo de nuevo cuando quieras.',
        guardarRespuesta: false,
      );
      return;
    }

    var telefono = '';
    for (var intento = 0; intento < 2; intento++) {
      final respuestaNumero = await pedirRespuesta(
        intento == 0
            ? 'Dime el número de teléfono, dígito por dígito.'
            : 'No entendí el número. Dímelo despacio, número por número.',
      );
      telefono = ContactoApoyo.normalizarTelefono(respuestaNumero ?? '');
      if (telefono.length >= 7 && telefono.length <= 15) break;
      telefono = '';
    }
    if (telefono.isEmpty) {
      await hablar(
        'No entendí el número. Puedes intentarlo de nuevo cuando quieras.',
        guardarRespuesta: false,
      );
      return;
    }

    final digitosHablados = telefono.split('').join(' ');
    final ok = await pedirConfirmacion(
      'Guardo a $nombre con el número $digitosHablados. ¿Es correcto? Di sí o no.',
    );
    if (ok == true) {
      await agregarContacto(nombre, telefono);
      await hablar('Contacto guardado.');
    } else if (ok == false) {
      await hablar('No guardé el contacto.', guardarRespuesta: false);
    }
  }

  /// Guarda o reemplaza un contacto con [nombre] y [telefono].
  Future<void> agregarContacto(String nombre, String telefono) async {
    _contactos.removeWhere(
      (c) => c.nombre.toLowerCase() == nombre.toLowerCase(),
    );
    _contactos.add(ContactoApoyo(nombre: nombre, telefono: telefono));
    await StorageService.setContactos(_contactos);
    await StorageService.setContactosPendientes(true);
    notifyListeners();
  }

  /// Baja por voz: el argumento del comando o una pregunta por voz
  /// dicen a quién eliminar, y se confirma antes de borrar.
  Future<void> eliminarContactoPorVoz(String argumento) async {
    var nombre = argumento.trim();
    if (nombre.isEmpty) {
      nombre = (await pedirRespuesta('¿Qué contacto quieres eliminar?')) ?? '';
    }
    if (nombre.isEmpty) return;

    final contacto = _buscarContacto(nombre);
    if (contacto == null) {
      await hablar(_mensajeContactoNoEncontrado(nombre),
          guardarRespuesta: false);
      return;
    }
    final ok = await pedirConfirmacion(
      '¿Elimino a ${contacto.nombre} de tus contactos? Di sí o no.',
    );
    if (ok == true) {
      await eliminarContacto(contacto.nombre);
      await hablar('Eliminé a ${contacto.nombre}.');
    } else if (ok == false) {
      await hablar('No lo eliminé.', guardarRespuesta: false);
    }
  }

  /// Elimina el contacto llamado [nombre] (si existe).
  Future<void> eliminarContacto(String nombre) async {
    _contactos.removeWhere(
      (c) => c.nombre.toLowerCase() == nombre.toLowerCase(),
    );
    await StorageService.setContactos(_contactos);
    await StorageService.setContactosPendientes(true);
    notifyListeners();
  }

  /// Llamada por voz: [argumento] es el nombre dicho tras "llama a".
  Future<void> llamarContactoPorVoz(String argumento) async {
    var nombre = argumento.trim();
    if (nombre.isEmpty) {
      nombre = (await pedirRespuesta('¿A quién quieres llamar?')) ?? '';
    }
    if (nombre.isEmpty) return;
    await llamarContacto(nombre);
  }

  /// Llama al contacto más parecido a [nombre]. Si hay permiso de
  /// teléfono marca directo; si no, abre el marcador con el número.
  Future<void> llamarContacto(String nombre) async {
    if (_contactos.isEmpty) {
      await hablar(
        'No tienes contactos de apoyo. Di agregar contacto para registrar uno.',
      );
      return;
    }
    final contacto = _buscarContacto(nombre);
    if (contacto == null) {
      await hablar(_mensajeContactoNoEncontrado(nombre),
          guardarRespuesta: false);
      return;
    }

    await hablar('Llamando a ${contacto.nombre}.');
    try {
      final permiso = await Permission.phone.request();
      if (permiso.isGranted) {
        await AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:${contacto.telefono}',
        ).launch();
      } else {
        await AndroidIntent(
          action: 'android.intent.action.DIAL',
          data: 'tel:${contacto.telefono}',
        ).launch();
        await hablar(
          'Abrí el marcador con el número de ${contacto.nombre}. Toca llamar.',
          guardarRespuesta: false,
        );
      }
    } catch (e) {
      debugPrint('Error al llamar: $e');
      await hablar(
        'No pude hacer la llamada. Revisa los permisos de teléfono.',
        guardarRespuesta: false,
      );
    }
  }

  /// Llama al primer contacto de apoyo registrado.
  Future<void> pedirAyuda() async {
    if (_contactos.isEmpty) {
      await hablar(
        'No tienes contactos de apoyo. Di agregar contacto para registrar uno.',
      );
      return;
    }
    await llamarContacto(_contactos.first.nombre);
  }

  /// Lee en voz alta la lista de contactos guardados.
  Future<void> listarContactos() async {
    if (_contactos.isEmpty) {
      await hablar(
        'No tienes contactos de apoyo. Di agregar contacto para registrar uno.',
      );
      return;
    }
    final nombres = _contactos.map((c) => c.nombre).join(', ');
    await hablar(
      'Tienes ${_contactos.length} contacto${_contactos.length == 1 ? '' : 's'}: $nombres.',
    );
  }

  /// Busca el contacto cuyo nombre más se parece a [nombre]
  /// (similitud Levenshtein, umbral 0.6).
  ContactoApoyo? _buscarContacto(String nombre) {
    ContactoApoyo? mejor;
    var mejorSim = 0.0;
    for (final c in _contactos) {
      final sim = CommandParser.similitudTexto(nombre, c.nombre);
      if (sim > mejorSim) {
        mejorSim = sim;
        mejor = c;
      }
    }
    return mejorSim >= 0.6 ? mejor : null;
  }

  String _mensajeContactoNoEncontrado(String nombre) {
    if (_contactos.isEmpty) {
      return 'No tienes contactos de apoyo. Di agregar contacto para registrar uno.';
    }
    final nombres = _contactos.map((c) => c.nombre).join(', ');
    return 'No encontré a $nombre en tus contactos. Tus contactos son: $nombres.';
  }

  // -------------------- Volumen y vibración --------------------

  /// Sube el volumen de voz un paso (0.2) y lo dice en porcentaje.
  Future<void> subirVolumen() async {
    if (TtsService.volume >= 1.0) {
      await hablar('Ya está en el volumen máximo.', guardarRespuesta: false);
      return;
    }
    await TtsService.increaseVolume();
    unawaited(StorageService.setConfigPendiente(true));
    final porcentaje = (TtsService.volume * 100).round();
    await hablar('Volumen al $porcentaje por ciento.', guardarRespuesta: false);
  }

  /// Baja el volumen de voz un paso (0.2) y lo dice en porcentaje.
  Future<void> bajarVolumen() async {
    if (TtsService.volume <= 0.2) {
      await hablar('Ya está en el volumen mínimo.', guardarRespuesta: false);
      return;
    }
    await TtsService.decreaseVolume();
    unawaited(StorageService.setConfigPendiente(true));
    final porcentaje = (TtsService.volume * 100).round();
    await hablar('Volumen al $porcentaje por ciento.', guardarRespuesta: false);
  }

  // -------------------- Ajustes --------------------

  Future<void> masRapido() async {
    await TtsService.increaseRate();
    unawaited(StorageService.setConfigPendiente(true));
    await hablar('Velocidad aumentada.', guardarRespuesta: false);
  }

  Future<void> masLento() async {
    await TtsService.decreaseRate();
    unawaited(StorageService.setConfigPendiente(true));
    await hablar('Velocidad reducida.', guardarRespuesta: false);
  }

  Future<void> cambiarNombre(String nombre) async {
    _nombreUsuario = nombre;
    await StorageService.setNombre(nombre);
    unawaited(StorageService.setConfigPendiente(true));
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

    try {
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
      _setEstado(EstadoEyes.listo, 'Listo para ayudarte');
    } finally {
      _ocupado = false;
    }
  }

  Future<void> detenerTodo() async {
    _lecturaContinua = false;
    _encuadreActivo = false;
    await _cameraService.setLinterna(false);
    _ultimaInstruccionEncuadre = '';
    _lineasLeidas.clear();
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
    unawaited(StorageService.setConfigPendiente(true));
    await _actualizarConexion();
    notifyListeners();
  }

  Future<void> setAceptoIaNube(bool valor) async {
    _aceptoIaNube = valor;
    await StorageService.setAceptoIaNube(valor);
    unawaited(StorageService.setConfigPendiente(true));
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    await StorageService.setIaApiKey(key);
    notifyListeners();
  }

  Future<void> setIaModel(String model) async {
    await StorageService.setIaModel(model);
    notifyListeners();
  }

  // -------------------- Bienvenida --------------------

  Future<void> finalizarBienvenida(String nombre, bool aceptaIaNube) async {
    await cambiarNombre(nombre);
    await setAceptoIaNube(aceptaIaNube);
    await setUsarIaNube(aceptaIaNube);
    await StorageService.setPrimerUsoCompletado(true);
  }

  // -------------------- Limpieza --------------------

  @override
  void dispose() {
    _timerSincronizacion?.cancel();
    _cameraService.dispose();
    VoiceInputService.dispose();
    TtsService.stop();
    super.dispose();
  }
}
