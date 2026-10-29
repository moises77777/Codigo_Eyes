import 'dart:io';

import 'package:eyes_app/services/detector_service.dart';
import 'package:eyes_app/utils/traducciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsearEtiquetas', () {
    test('ignora comentarios y líneas vacías', () {
      final lista = DetectorService.parsearEtiquetas(
        '# comentario\npersona\n\n  # otro\nperro\n???\n',
      );
      expect(lista, ['persona', 'perro', '???']);
    });
  });

  group('cajaAPixeles', () {
    test('convierte caja normalizada a píxeles', () {
      final r = DetectorService.cajaAPixeles(0.1, 0.2, 0.5, 0.6, 1280, 720);
      expect(r.left, closeTo(256, 0.01));
      expect(r.top, closeTo(72, 0.01));
      expect(r.right, closeTo(768, 0.01));
      expect(r.bottom, closeTo(360, 0.01));
    });

    test('con rotación 90 ancho y alto van intercambiados', () {
      // Frame crudo 1280x720, sensor 90° → derecha es 720x1280.
      final r = DetectorService.cajaAPixeles(0.0, 0.0, 1.0, 1.0, 720, 1280);
      expect(r.width, 720);
      expect(r.height, 1280);
    });
  });

  group('traducciones COCO-80', () {
    test('toda etiqueta del preentrenado tiene traducción', () {
      final archivo = File('assets/modelos/preentrenado/etiquetas.txt');
      final lineas = DetectorService.parsearEtiquetas(
        archivo.readAsStringSync(),
      );
      // Mapa embebido del EfficientDet-Lite0 de MediaPipe: 90 entradas,
      // índice 0 = person (sin fondo al inicio).
      expect(lineas.length, 90);
      expect(lineas.first, 'person');
      for (final e in lineas) {
        if (e == '???') continue;
        expect(
          Traducciones.traducir(e),
          isNot('objeto'),
          reason: 'falta traducción para "$e"',
        );
      }
    });
  });
}
