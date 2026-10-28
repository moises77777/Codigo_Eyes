import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'permission_service.dart';

/// Servicio que encapsula el control de la cámara trasera.
/// Usa el stream de imágenes para detección en tiempo real y takePicture()
/// para capturas puntuales (OCR, Gemini).
class CameraService {
  CameraController? _controller;
  bool _isInitializing = false;
  void Function(CameraImage)? _onFrame;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get isStreaming => _controller?.value.isStreamingImages ?? false;

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

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      await _controller?.dispose();
      _controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitializing = false;
      return true;
    } catch (e) {
      debugPrint('Error al inicializar cámara: $e');
      _isInitializing = false;
      return false;
    }
  }

  /// Inicia el stream de frames. [onFrame] se llama por cada imagen capturada.
  Future<void> startImageStream(void Function(CameraImage) onFrame) async {
    if (!isInitialized || isStreaming) return;
    _onFrame = onFrame;
    try {
      await _controller!.startImageStream(onFrame);
    } catch (e) {
      debugPrint('Error al iniciar stream: $e');
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
  Future<String?> takePicture() async {
    if (!isInitialized || _controller == null) return null;
    try {
      final file = await _controller!.takePicture();
      return file.path;
    } catch (e) {
      debugPrint('Error al capturar imagen: $e');
      return null;
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
