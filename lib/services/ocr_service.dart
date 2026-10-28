import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

  static Future<void> dispose() async {
    await _recognizer.close();
  }
}
