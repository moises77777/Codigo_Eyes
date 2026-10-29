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
      final r = CommandParser.interpretar('¿cuánto pesa?');
      expect(r.comando, Comando.preguntaImagen);
      expect(r.argumento, 'cuanto pesa');
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

    test('detecta billete', () {
      expect(CommandParser.interpretar('qué billete es').comando,
          Comando.billete);
      expect(CommandParser.interpretar('cuánto dinero tengo').comando,
          Comando.billete);
    });

    test('detecta color', () {
      expect(CommandParser.interpretar('de qué color es').comando,
          Comando.color);
      expect(CommandParser.interpretar('qué color tiene').comando,
          Comando.color);
    });

    test('detecta describir todo', () {
      expect(CommandParser.interpretar('qué hay en la imagen').comando,
          Comando.describirTodo);
      expect(CommandParser.interpretar('describe todo').comando,
          Comando.describirTodo);
    });

    test('detecta encuadrar', () {
      expect(CommandParser.interpretar('encuadrar').comando,
          Comando.encuadrar);
      expect(CommandParser.interpretar('ayúdame a centrar').comando,
          Comando.encuadrar);
    });

    test('detecta llama a con nombre', () {
      final r = CommandParser.interpretar('llama a mamá');
      expect(r.comando, Comando.llamar);
      expect(r.argumento, 'mama');
    });

    test('distingue pide ayuda de ayuda', () {
      expect(CommandParser.interpretar('pide ayuda').comando,
          Comando.pedirAyuda);
      expect(CommandParser.interpretar('necesito ayuda').comando,
          Comando.pedirAyuda);
      expect(CommandParser.interpretar('ayuda').comando, Comando.ayuda);
    });

    test('detecta agregar contacto', () {
      expect(CommandParser.interpretar('agregar contacto').comando,
          Comando.agregarContacto);
    });

    test('detecta mis contactos', () {
      expect(CommandParser.interpretar('mis contactos').comando,
          Comando.misContactos);
    });

    test('detecta eliminar contacto', () {
      expect(CommandParser.interpretar('eliminar contacto').comando,
          Comando.eliminarContacto);
    });

    test('detecta subir y bajar volumen', () {
      expect(CommandParser.interpretar('sube el volumen').comando,
          Comando.subirVolumen);
      expect(CommandParser.interpretar('baja el volumen').comando,
          Comando.bajarVolumen);
    });

    test('detecta encender y apagar linterna', () {
      expect(CommandParser.interpretar('enciende la linterna').comando,
          Comando.linternaOn);
      expect(CommandParser.interpretar('linterna').comando,
          Comando.linternaOn);
      expect(CommandParser.interpretar('apaga la linterna').comando,
          Comando.linternaOff);
      expect(CommandParser.interpretar('apaga la luz').comando,
          Comando.linternaOff);
    });

    test('detecta quitar y poner vibración', () {
      expect(CommandParser.interpretar('quita la vibración').comando,
          Comando.quitarVibracion);
      expect(CommandParser.interpretar('activa la vibración').comando,
          Comando.ponerVibracion);
    });
  });
}
