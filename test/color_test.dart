import 'package:eyes_app/services/color_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nombreDeColor', () {
    test('negro con valor muy bajo', () {
      expect(ColorService.nombreDeColor(0, 0.9, 0.1), 'negro');
    });

    test('blanco con saturación baja y valor alto', () {
      expect(ColorService.nombreDeColor(0, 0.05, 0.95), 'blanco');
    });

    test('gris con saturación baja y valor medio', () {
      expect(ColorService.nombreDeColor(0, 0.05, 0.5), 'gris');
    });

    test('rojo cerca de 0 y de 360 grados', () {
      expect(ColorService.nombreDeColor(5, 0.9, 0.9), 'rojo');
      expect(ColorService.nombreDeColor(350, 0.9, 0.9), 'rojo');
    });

    test('verde', () {
      expect(ColorService.nombreDeColor(120, 0.9, 0.8), 'verde');
    });

    test('azul y azul claro', () {
      expect(ColorService.nombreDeColor(230, 0.9, 0.8), 'azul');
      expect(ColorService.nombreDeColor(185, 0.9, 0.9), 'azul claro');
    });

    test('amarillo', () {
      expect(ColorService.nombreDeColor(55, 0.95, 0.9), 'amarillo');
    });

    test('café es naranja oscuro', () {
      expect(ColorService.nombreDeColor(30, 0.8, 0.4), 'café');
      // El mismo tono pero brillante es naranja.
      expect(ColorService.nombreDeColor(30, 0.8, 0.9), 'naranja');
    });

    test('rosa', () {
      expect(ColorService.nombreDeColor(320, 0.8, 0.9), 'rosa');
    });

    test('morado', () {
      expect(ColorService.nombreDeColor(280, 0.8, 0.7), 'morado');
    });
  });
}
