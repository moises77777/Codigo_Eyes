import 'package:eyes_app/utils/traducciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Traducciones', () {
    test('traduce etiquetas comunes de ML Kit', () {
      expect(Traducciones.traducir('person'), 'persona');
      expect(Traducciones.traducir('bottle'), 'botella');
      expect(Traducciones.traducir('cup'), 'taza');
      expect(Traducciones.traducir('chair'), 'silla');
      expect(Traducciones.traducir('potted plant'), 'planta');
    });

    test('respeta mayúsculas y espacios', () {
      expect(Traducciones.traducir('  Bottle '), 'botella');
      expect(Traducciones.traducir('PERSON'), 'persona');
    });

    test('devuelve objeto si la etiqueta no existe', () {
      expect(Traducciones.traducir('car'), 'auto');
      expect(Traducciones.traducir('unknown thing'), 'objeto');
    });

    test('traduce las etiquetas gruesas del ObjectDetector', () {
      expect(Traducciones.traducir('Home good'), 'artículo del hogar');
      expect(Traducciones.traducir('Fashion good'), 'prenda o accesorio');
      expect(Traducciones.traducir('Food'), 'comida');
      expect(Traducciones.traducir('Place'), 'lugar');
      expect(Traducciones.traducir('Plant'), 'planta');
      expect(Traducciones.traducir('Good'), 'objeto');
    });

    test('contiene revisa el diccionario', () {
      expect(Traducciones.contiene('person'), isTrue);
      expect(Traducciones.contiene('xyz'), isFalse);
    });
  });
}
