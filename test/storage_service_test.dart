import 'package:eyes_app/models/resultado.dart';
import 'package:eyes_app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await StorageService.init();
  });

  group('StorageService', () {
    test('guarda y lee el nombre', () async {
      await StorageService.setNombre('Juan');
      expect(await StorageService.getNombre(), 'Juan');
    });

    test('guarda y lee historial', () async {
      final r = Resultado.ahora(tipo: 'ocr', texto: 'Hola');
      await StorageService.agregarHistorial(r);
      final lista = await StorageService.getHistorial();
      expect(lista.length, 1);
      expect(lista.first.texto, 'Hola');
    });

    test('borra historial', () async {
      await StorageService.agregarHistorial(Resultado.ahora(tipo: 'x', texto: 'x'));
      await StorageService.borrarHistorial();
      expect(await StorageService.getHistorial(), isEmpty);
    });

    test('guarda y lee guardados', () async {
      final r = Resultado.ahora(tipo: 'identificar', texto: 'Silla');
      await StorageService.agregarGuardado(r);
      final lista = await StorageService.getGuardados();
      expect(lista.length, 1);
      expect(lista.first.texto, 'Silla');
    });

    test('elimina guardado', () async {
      final r = Resultado.ahora(tipo: 'identificar', texto: 'Mesa');
      await StorageService.agregarGuardado(r);
      await StorageService.eliminarGuardado(r.id);
      expect(await StorageService.getGuardados(), isEmpty);
    });

    test('guarda velocidad y tono', () async {
      await StorageService.setSpeechRate(0.8);
      await StorageService.setPitch(1.2);
      expect(await StorageService.getSpeechRate(), 0.8);
      expect(await StorageService.getPitch(), 1.2);
    });

    test('guarda clave API y modelo', () async {
      await StorageService.setGeminiApiKey('clave123');
      await StorageService.setGeminiModel('gemini-test');
      expect(await StorageService.getGeminiApiKey(), 'clave123');
      expect(await StorageService.getGeminiModel(), 'gemini-test');
    });

    test('primer uso', () async {
      expect(await StorageService.getPrimerUsoCompletado(), isFalse);
      await StorageService.setPrimerUsoCompletado(true);
      expect(await StorageService.getPrimerUsoCompletado(), isTrue);
    });
  });
}
