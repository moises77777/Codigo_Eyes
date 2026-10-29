import 'package:eyes_app/services/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('esAfirmativo', () {
    final afirmativos = [
      'si', 'sí', 'claro', 'correcto', 'afirmativo', 'dale', 'ok',
      'esta bien', 'adelante', 'confirmar', 'asi es', 'exacto',
      'sí claro', 'sí está bien', 'ok dale',
    ];
    for (final texto in afirmativos) {
      test('"$texto" es afirmativo', () {
        expect(CommandParser.esAfirmativo(texto), isTrue);
      });
    }
  });

  group('esNegativo', () {
    final negativos = [
      'no', 'nel', 'negativo', 'incorrecto', 'no gracias',
      'cancela', 'para nada', 'no está bien', 'no lo hagas',
    ];
    for (final texto in negativos) {
      test('"$texto" es negativo', () {
        expect(CommandParser.esNegativo(texto), isTrue);
      });
    }

    test('"no está bien" no es afirmativo', () {
      expect(CommandParser.esAfirmativo('no está bien'), isFalse);
    });

    test('"nombre" no es negativo', () {
      expect(CommandParser.esNegativo('nombre'), isFalse);
      expect(CommandParser.esAfirmativo('nombre'), isFalse);
    });

    test('"noche" no es negativo', () {
      expect(CommandParser.esNegativo('noche'), isFalse);
    });

    test('texto vacío no es ni afirmativo ni negativo', () {
      expect(CommandParser.esAfirmativo(''), isFalse);
      expect(CommandParser.esNegativo(''), isFalse);
    });
  });
}
