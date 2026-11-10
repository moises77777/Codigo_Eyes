// Tests del BFS portado a Dart: mismo árbol que `busquedas.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:eyes_app/utils/busqueda_bfs.dart';

void main() {
  group('BusquedaBfs', () {
    test('encuentra la ruta con menos pasos en el árbol UCS', () {
      final r = BusquedaBfs.enArbolUcs('A', 'J');
      // BFS: el camino más corto en aristas es A -> C -> F -> J.
      expect(r.camino, ['A', 'C', 'F', 'J']);
      expect(r.costoTotal, 3);
      expect(r.orden.first, 'A');
      expect(r.orden.last, 'J');
    });

    test('explora por niveles (FIFO), no por costo', () {
      final r = BusquedaBfs.enArbolUcs('A', 'E');
      // Los hijos de A (B, C) se exploran antes que los nietos.
      expect(r.orden.sublist(0, 3), ['A', 'B', 'C']);
      expect(r.camino, ['A', 'B', 'E']);
    });

    test('devuelve vacío si no hay ruta', () {
      final r = BusquedaBfs.buscar(
          {'A': ['B'], 'B': []}, 'A', 'Z');
      expect(r.camino, isEmpty);
      expect(r.costoTotal, -1);
    });

    test('grafo de pantallas: bienvenida a ajustes', () {
      final r =
          BusquedaBfs.buscar(BusquedaBfs.pantallas, 'bienvenida', 'ajustes');
      expect(r.camino, ['bienvenida', 'home', 'ajustes']);
      expect(r.costoTotal, 2);
    });
  });
}
