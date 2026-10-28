import 'package:eyes_app/utils/busquedas.dart';
import 'package:eyes_app/utils/prioridades.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Costo uniforme encuentra la ruta A C F J con costo 10', () {
    final r = Busquedas.costoUniforme('A', 'J');
    expect(r.camino, ['A', 'C', 'F', 'J']);
    expect(r.costoTotal, 10);
    expect(r.orden.first, 'A');
    expect(r.orden.last, 'J');
  });

  test('A estrella encuentra la ruta A C F I J', () {
    final r = Busquedas.aEstrella('A', 'J');
    expect(r.camino, ['A', 'C', 'F', 'I', 'J']);
    // La práctica suma las heurísticas del camino: 7+4+3+1+0 = 15.
    expect(r.costoTotal, 15);
    expect(r.orden.last, 'J');
  });

  test('Prioridades: un cuchillo vale más que una pared', () {
    expect(Prioridades.pesoDe('cuchillo') > Prioridades.pesoDe('pared'), isTrue);
    expect(Prioridades.esPeligroso('cuchillo'), isTrue);
    expect(Prioridades.esPeligroso('pared'), isFalse);
    // El puntaje favorece a lo relevante aunque la confianza sea menor.
    expect(
      Prioridades.puntaje('cuchillo', 0.5) > Prioridades.puntaje('pared', 0.9),
      isTrue,
    );
  });
}
