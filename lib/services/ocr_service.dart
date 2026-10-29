import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/input_image_helper.dart';

/// Servicio de reconocimiento óptico de caracteres (OCR) local con ML Kit.
class OcrService {
  OcrService._();

  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extrae todo el texto reconocido en la imagen de [ruta].
  static Future<String> leerTexto(String ruta) async {
    try {
      final inputImage = InputImage.fromFilePath(ruta);
      final recognizedText = await _recognizer.processImage(inputImage);
      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        buffer.writeln(block.text);
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('Error en OcrService: $e');
      return '';
    }
  }

  /// Reconoce texto directamente sobre un [frame] del stream de la cámara,
  /// sin necesidad de tomar una foto. Lo usa la lectura continua.
  static Future<String> reconocerFrame(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    try {
      final inputImage = InputImageHelper.fromCameraImage(frame, sensorOrientation);
      if (inputImage == null) return '';
      final recognizedText = await _recognizer.processImage(inputImage);
      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        buffer.writeln(block.text);
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('Error en OcrService (frame): $e');
      return '';
    }
  }

  /// Unión de las cajas de todos los bloques de texto del [frame], en el
  /// sistema de coordenadas de la imagen rotada que reporta ML Kit.
  /// Devuelve null si no hay texto. Lo usa la guía de encuadre.
  static Future<Rect?> cajaTextoFrame(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    try {
      final inputImage = InputImageHelper.fromCameraImage(frame, sensorOrientation);
      if (inputImage == null) return null;
      final recognizedText = await _recognizer.processImage(inputImage);
      Rect? union;
      for (final block in recognizedText.blocks) {
        union = union == null
            ? block.boundingBox
            : union.expandToInclude(block.boundingBox);
      }
      return union;
    } catch (e) {
      debugPrint('Error en OcrService (caja frame): $e');
      return null;
    }
  }

  static Future<void> dispose() async {
    await _recognizer.close();
  }
}
