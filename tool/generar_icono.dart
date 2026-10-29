// Herramienta para generar los íconos de EYES.
// Uso: dart run tool/generar_icono.dart
// Genera assets/icon/icon.png (1024x1024, fondo negro, ojo amarillo)
// y assets/icon/icon_foreground.png (ojo al 60 %, fondo transparente).

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const amarillo = (255, 214, 0);
  const negro = (0, 0, 0);

  img.Image dibujarIcono(int tam, int tamOjo, {required bool transparente}) {
    final imagen = img.Image(width: tam, height: tam, numChannels: 4);
    // Fondo: negro sólido o transparente según el uso.
    img.fill(
      imagen,
      color: transparente
          ? img.ColorRgba8(0, 0, 0, 0)
          : img.ColorRgba8(negro.$1, negro.$2, negro.$3, 255),
    );

    final centro = tam / 2;
    // Forma de ojo: intersección de dos círculos grandes (almendra).
    // Cada círculo tiene radio = ancho del ojo; sus centros están
    // desplazados verticalmente para recortar la almendra.
    final anchoOjo = tamOjo.toDouble();
    final radio = anchoOjo;
    final desplazamiento = anchoOjo * 0.62;
    final altoOjo = 2 * math.sqrt(radio * radio - desplazamiento * desplazamiento);
    final radioIris = anchoOjo * 0.28;
    final radioPupila = anchoOjo * 0.11;
    final radioBrillo = anchoOjo * 0.045;
    // El brillo va arriba a la izquierda del iris.
    final brilloX = centro - radioIris * 0.45;
    final brilloY = centro - radioIris * 0.45;

    for (var y = 0; y < tam; y++) {
      for (var x = 0; x < tam; x++) {
        final dx = x - centro;
        final dy = y - centro;

        // Dentro de la almendra = dentro de ambos círculos desplazados.
        final enCirculoSup = dx * dx + (dy + desplazamiento) * (dy + desplazamiento) < radio * radio;
        final enCirculoInf = dx * dx + (dy - desplazamiento) * (dy - desplazamiento) < radio * radio;
        if (!(enCirculoSup && enCirculoInf)) continue;
        // Recorte vertical extra para que la almendra no sea demasiado alta.
        if (dy.abs() > altoOjo / 2) continue;

        final dCentro = math.sqrt(dx * dx + dy * dy);
        if (dCentro <= radioBrillo + 1) {
          imagen.setPixelRgba(x, y, 255, 255, 255, 255);
        } else if (math.sqrt((x - brilloX) * (x - brilloX) + (y - brilloY) * (y - brilloY)) <=
            radioBrillo) {
          imagen.setPixelRgba(x, y, 255, 255, 255, 255);
        } else if (dCentro <= radioPupila) {
          imagen.setPixelRgba(x, y, amarillo.$1, amarillo.$2, amarillo.$3, 255);
        } else if (dCentro <= radioIris) {
          imagen.setPixelRgba(x, y, negro.$1, negro.$2, negro.$3, 255);
        } else {
          imagen.setPixelRgba(x, y, amarillo.$1, amarillo.$2, amarillo.$3, 255);
        }
      }
    }
    return imagen;
  }

  Directory('assets/icon').createSync(recursive: true);

  final icono = dibujarIcono(1024, 880, transparente: false);
  File('assets/icon/icon.png')
      .writeAsBytesSync(img.encodePng(icono));
  stdout.writeln('Escrito assets/icon/icon.png');

  // Foreground del adaptive icon: el ojo al 60 % del lienzo, centrado,
  // para que quede dentro de la zona segura circular.
  final frente = dibujarIcono(1024, 615, transparente: true);
  File('assets/icon/icon_foreground.png')
      .writeAsBytesSync(img.encodePng(frente));
  stdout.writeln('Escrito assets/icon/icon_foreground.png');
}
