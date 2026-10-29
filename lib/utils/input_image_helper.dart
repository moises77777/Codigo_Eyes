import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Conversión compartida de frames de la cámara (YUV420 de Android) a
/// [InputImage] de ML Kit, usada tanto por visión de objetos como por OCR.
class InputImageHelper {
  InputImageHelper._();

  /// Convierte [frame] a un [InputImage] en formato NV21 con la rotación
  /// del sensor. Devuelve null si el frame no se pudo convertir.
  static InputImage? fromCameraImage(CameraImage frame, int sensorOrientation) {
    try {
      final bytes = _yuv420ToNv21(frame);
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('Error convirtiendo frame a InputImage: $e');
      return null;
    }
  }

  /// Convierte un frame YUV420 (3 planos de la cámara en Android) a NV21,
  /// que es el formato que ML Kit acepta en Android.
  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + (width * height) ~/ 2);

    // Plano Y.
    int index = 0;
    for (int y = 0; y < height; y++) {
      final inicio = y * yPlane.bytesPerRow;
      nv21.setRange(index, index + width, yPlane.bytes, inicio);
      index += width;
    }

    // Planos U y V intercalados (NV21 = VU).
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;

    for (int y = 0; y < uvHeight; y++) {
      for (int x = 0; x < uvWidth; x++) {
        final uvIndex = index + y * width + x * 2;
        nv21[uvIndex] = vPlane.bytes[y * vRowStride + x * vPixelStride];
        nv21[uvIndex + 1] = uPlane.bytes[y * uRowStride + x * uPixelStride];
      }
    }

    return nv21;
  }
}
