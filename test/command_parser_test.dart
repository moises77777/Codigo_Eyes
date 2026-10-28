import 'package:eyes_app/services/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandParser', () {
    test('detecta identificar', () {
      final r = CommandParser.interpretar('qué es esto');
      expect(r.comando, Comando.identificar);
    });

    test('detecta identificar con sinónimo', () {
      final r = CommandParser.interpretar('qué tengo enfrente');
      expect(r.comando, Comando.identificar);
    });

    test('detecta describir', () {
      final r = CommandParser.interpretar('describe la escena');
      expect(r.comando, Comando.describir);
    });

    test('detecta leer texto', () {
      final r = CommandParser.interpretar('lee el texto');
      expect(r.comando, Comando.ocr);
    });

    test('detecta guardar', () {
      final r = CommandParser.interpretar('guarda esto');
      expect(r.comando, Comando.guardar);
    });

    test('detecta repetir', () {
      final r = CommandParser.interpretar('repite');
      expect(r.comando, Comando.repetir);
    });

    test('detecta historial', () {
      final r = CommandParser.interpretar('muéstrame el historial');
      expect(r.comando, Comando.historial);
    });

    test('detecta más rápido', () {
      final r = CommandParser.interpretar('más rápido');
      expect(r.comando, Comando.masRapido);
    });

    test('detecta más lento', () {
      final r = CommandParser.interpretar('habla más lento');
      expect(r.comando, Comando.masLento);
    });

    test('detecta cambiar nombre con argumento', () {
      final r = CommandParser.interpretar('mi nombre es Juan');
      expect(r.comando, Comando.cambiarNombre);
      expect(r.argumento, 'juan');
    });

    test('detecta cambiar nombre con llámame', () {
      final r = CommandParser.interpretar('llámame María');
      expect(r.comando, Comando.cambiarNombre);
      expect(r.argumento, 'maria');
    });

    test('detecta pregunta sobre imagen', () {
      final r = CommandParser.interpretar('de qué color es');
      expect(r.comando, Comando.preguntaImagen);
      expect(r.argumento, 'de que color es');
    });

    test('detecta pregunta con prefijo pregunta', () {
      final r = CommandParser.interpretar('pregunta ¿cuánto pesa?');
      expect(r.comando, Comando.preguntaImagen);
      expect(r.argumento, 'cuanto pesa');
    });

    test('detecta sí', () {
      final r = CommandParser.interpretar('sí');
      expect(r.comando, Comando.si);
    });

    test('detecta detener', () {
      final r = CommandParser.interpretar('detener');
      expect(r.comando, Comando.detener);
    });

    test('ignora palabras de relleno', () {
      final r = CommandParser.interpretar('eyes, por favor identifica esto');
      expect(r.comando, Comando.identificar);
    });

    test('devuelve ninguno para texto sin sentido', () {
      final r = CommandParser.interpretar('xyz abc 123');
      expect(r.comando, Comando.ninguno);
    });
  });
}
