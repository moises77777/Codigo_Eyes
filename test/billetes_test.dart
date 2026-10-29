import 'package:eyes_app/services/billetes_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('denominacionDesdeTexto', () {
    test('detecta número y palabra', () {
      expect(
        BilletesService.denominacionDesdeTexto('BANCO DE MEXICO 100 CIEN PESOS'),
        100,
      );
    });

    test('1000 no cuenta como 100', () {
      expect(
        BilletesService.denominacionDesdeTexto('1000 MIL PESOS'),
        1000,
      );
    });

    test('detecta palabra veinte', () {
      expect(BilletesService.denominacionDesdeTexto('veinte pesos'), 20);
    });

    test('detecta quinientos', () {
      expect(
        BilletesService.denominacionDesdeTexto('quinientos pesos oro'),
        500,
      );
    });

    test('texto sin denominación devuelve null', () {
      expect(BilletesService.denominacionDesdeTexto('hola'), isNull);
      expect(BilletesService.denominacionDesdeTexto(''), isNull);
    });

    test('en empate prefiere la que aparece como número', () {
      // 'mil' (1000) y '200' empatan en una ocurrencia; gana el número.
      expect(
        BilletesService.denominacionDesdeTexto('mil gracias, 200 pesos'),
        200,
      );
    });
  });

  group('denominacionPorColor', () {
    test('colores con una o dos denominaciones posibles', () {
      expect(BilletesService.denominacionPorColor('verde'), '20 o 200');
      expect(BilletesService.denominacionPorColor('azul'), '20 o 500');
      expect(BilletesService.denominacionPorColor('rosa'), '50 o 1000');
      expect(BilletesService.denominacionPorColor('magenta'), '50 o 1000');
      expect(BilletesService.denominacionPorColor('rojo'), '100');
      expect(BilletesService.denominacionPorColor('morado'), '1000');
      expect(BilletesService.denominacionPorColor('café'), '500');
    });

    test('color desconocido devuelve null', () {
      expect(BilletesService.denominacionPorColor('amarillo'), isNull);
      expect(BilletesService.denominacionPorColor(''), isNull);
    });
  });
}
