import 'dart:io';
import 'dart:ui' show Offset, Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../utils/latencia.dart';
import 'permission_service.dart';

/// Servicio que encapsula el control de la cámara trasera.
/// Usa el stream de imágenes para detección en tiempo real y takePicture()
/// para capturas puntuales (OCR, IA en la nube).
class CameraService {
  CameraController? _controller;
  bool _isInitializing = false;
  void Function(CameraImage)? _onFrame;
  bool _linternaEncendida = false;

  // Contador de FPS del stream (media móvil por ventana de 1 s).
  int _framesVentana = 0;
  DateTime _inicioVentana = DateTime.now();
  double _fpsStream = 0;
  DateTime _ultimoLogFps = DateTime.now();

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get isStreaming => _controller?.value.isStreamingImages ?? false;

  bool get linternaEncendida => _linternaEncendida;

  /// FPS medidos del stream de imágenes (media móvil).
  double get fpsStream => _fpsStream;

  /// Resolución actual del preview/stream.
  Size? get resolucionActual => _controller?.value.previewSize;

  /// Rotación del sensor de la cámara trasera (grados).
  int get sensorOrientation => _controller?.description.sensorOrientation ?? 0;

  /// Inicializa la cámara trasera. Devuelve false si no hay permiso o no hay cámaras.
  Future<bool> initialize() async {
    if (_isInitializing) return false;
    if (isInitialized) return true;

    _isInitializing = true;
    try {
      final hasPermission = await PermissionService.haveCameraAndMic();
      if (!hasPermission) {
        final granted = await PermissionService.requestCameraAndMic();
        if (!granted) {
          _isInitializing = false;
          return false;
        }
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _isInitializing = false;
        return false;
      }

      final back = _elegirCamaraPrincipal(cameras);

      await _controller?.dispose();
      // Un solo CameraController sirve para preview, stream y fotos:
      // cambiar de resolución reabriría la cámara (~1 s). Se usa 'high'
      // (720p): con detección real por frame, veryHigh saturaba el CPU
      // del Vivo y la vista se trababa.
      _controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();

      // Enfoque y exposición automáticos (algunos equipos no los soportan).
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('FocusMode.auto no soportado: $e');
      }
      try {
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (e) {
        debugPrint('ExposureMode.auto no soportado: $e');
      }

      final res = resolucionActual;
      debugPrint(
        '[EYES camara] resolución ${res?.width.toInt() ?? 0}x${res?.height.toInt() ?? 0}',
      );
      _isInitializing = false;
      return true;
    } catch (e) {
      debugPrint('Error al inicializar cámara: $e');
      _isInitializing = false;
      return false;
    }
  }

  /// Elige la cámara trasera principal: sin 'wide', 'ultra', 'tele' ni
  /// 'macro' en el nombre (lentes secundarios); si quedan varias, la de
  /// id numérico menor, porque en Android la cámara lógica '0' suele
  /// ser la principal.
  static CameraDescription _elegirCamaraPrincipal(
    List<CameraDescription> cameras,
  ) {
    final traseras = cameras
        .where((c) => c.lensDirection == CameraLensDirection.back)
        .toList();
    if (traseras.isEmpty) return cameras.first;

    final principales = traseras.where((c) {
      final nombre = c.name.toLowerCase();
      return !nombre.contains('wide') &&
          !nombre.contains('ultra') &&
          !nombre.contains('tele') &&
          !nombre.contains('macro');
    }).toList();

    final candidatas = principales.isEmpty ? traseras : principales;
    candidatas.sort((a, b) {
      final idA = int.tryParse(a.name) ?? 999;
      final idB = int.tryParse(b.name) ?? 999;
      return idA.compareTo(idB);
    });
    return candidatas.first;
  }

  /// Inicia el stream de frames. [onFrame] se llama por cada imagen capturada.
  Future<void> startImageStream(void Function(CameraImage) onFrame) async {
    if (!isInitialized || isStreaming) return;
    _onFrame = onFrame;
    _framesVentana = 0;
    _inicioVentana = DateTime.now();
    try {
      await _controller!.startImageStream((frame) {
        _contarFrame();
        onFrame(frame);
      });
    } catch (e) {
      debugPrint('Error al iniciar stream: $e');
    }
  }

  /// Cuenta frames del stream y calcula el FPS en ventanas de 1 s;
  /// lo registra cada 5 s en el log y en Latencia.ultimas['fps'].
  void _contarFrame() {
    _framesVentana++;
    final ahora = DateTime.now();
    final transcurrido = ahora.difference(_inicioVentana).inMilliseconds;
    if (transcurrido >= 1000) {
      _fpsStream = _framesVentana * 1000 / transcurrido;
      Latencia.ultimas['fps'] = _fpsStream.round();
      _framesVentana = 0;
      _inicioVentana = ahora;
      if (ahora.difference(_ultimoLogFps).inSeconds >= 5) {
        _ultimoLogFps = ahora;
        debugPrint('[EYES fps] ${_fpsStream.toStringAsFixed(1)}');
      }
    }
  }

  /// Detiene el stream de frames.
  Future<void> stopImageStream() async {
    if (!isInitialized || !isStreaming) return;
    try {
      await _controller!.stopImageStream();
    } catch (e) {
      debugPrint('Error al detener stream: $e');
    }
    _onFrame = null;
  }

  /// Toma una foto y devuelve la ruta del archivo.
  /// Antes enfoca y expone al centro (punto 0.5, 0.5) con 350 ms de
  /// espera para que el enfoque automático termine de trabajar.
  Future<String?> takePicture() async {
    if (!isInitialized || _controller == null) return null;
    try {
      try {
        await _controller!.setFocusPoint(const Offset(0.5, 0.5));
        await _controller!.setExposurePoint(const Offset(0.5, 0.5));
      } catch (e) {
        debugPrint('Puntos de enfoque/exposición no soportados: $e');
      }
      await Future.delayed(const Duration(milliseconds: 350));
      // Tope duro: en algunos equipos takePicture nunca responde tras
      // cortar el stream, y eso dejaba la app "ocupada" para siempre.
      final file = await _controller!
          .takePicture()
          .timeout(const Duration(seconds: 8));
      return file.path;
    } catch (e) {
      debugPrint('Error al capturar imagen: $e');
      return null;
    }
  }

  /// Enciende o apaga la linterna (flash en modo torch).
  /// Devuelve false si el equipo no la soporta.
  /// Nota: el plugin `camera` no expone estabilización de imagen.
  Future<bool> setLinterna(bool encender) async {
    if (!isInitialized || _controller == null) return false;
    try {
      await _controller!
          .setFlashMode(encender ? FlashMode.torch : FlashMode.off);
      _linternaEncendida = encender;
      return true;
    } catch (e) {
      debugPrint('Linterna no soportada: $e');
      _linternaEncendida = false;
      return false;
    }
  }

  /// Libera los recursos de la cámara.
  Future<void> dispose() async {
    await stopImageStream();
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
  }

  /// Pausa la cámara cuando la app va a segundo plano.
  Future<void> pause() async {
    await setLinterna(false);
    await stopImageStream();
    if (_controller?.value.isInitialized ?? false) {
      await _controller!.dispose();
      _controller = null;
    }
  }

  /// Reanuda la cámara cuando la app vuelve al primer plano.
  /// Devuelve true si se reinició correctamente.
  Future<bool> resume() async {
    if (isInitialized) return true;
    final ok = await initialize();
    if (ok && _onFrame != null) {
      await startImageStream(_onFrame!);
    }
    return ok;
  }

  /// Comprime/elimina metadatos del archivo si fuera necesario.
  /// Por ahora solo confirma que existe.
  Future<bool> fileExists(String path) async {
    final file = File(path);
    return file.existsSync();
  }
}
