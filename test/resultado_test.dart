import 'package:eyes_app/models/resultado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Resultado', () {
    test('toJson y fromJson conservan los datos', () {
      final original = Resultado(
        id: '123',
        tipo: 'identificar',
        texto: 'Parece una planta',
        fecha: '15/10/2026',
        hora: '12:34',
        confianza: 0.85,
        usoIaNube: true,
      );

      final json = original.toJson();
      final copia = Resultado.fromJson(json);

      expect(copia.id, original.id);
      expect(copia.tipo, original.tipo);
      expect(copia.texto, original.texto);
      expect(copia.fecha, original.fecha);
      expect(copia.hora, original.hora);
      expect(copia.confianza, original.confianza);
      expect(copia.usoIaNube, original.usoIaNube);
    });

    test('ahora genera fecha y hora válidas', () {
      final r = Resultado.ahora(tipo: 'ocr', texto: 'Hola mundo');
      expect(r.fecha, matches(r'\d{2}/\d{2}/\d{4}'));
      expect(r.hora, matches(r'\d{2}:\d{2}'));
      expect(r.texto, 'Hola mundo');
    });
  });
}
