/// Búsqueda en anchura (BFS) portada de la práctica p01BFS.py.
///
/// A diferencia de UCS/A* de `busquedas.dart` (cola de prioridad),
/// BFS usa una cola FIFO: el primer camino que entra es el primero
/// que se explora. Encuentra la ruta con MENOS PASOS, no la de
/// menor costo.
///
/// Corre sobre el mismo árbol de `busquedas.dart` para comparar
/// cuántos nodos explora cada algoritmo en la demo por voz.
library;

import 'dart:collection' show Queue;

import 'busquedas.dart' show ResultadoBusqueda;

/// BFS sobre árboles y grafos.
class BusquedaBfs {
  BusquedaBfs._();

  /// El mismo árbol que usa `Busquedas.costoUniforme`.
  static const arbolUcs = {
    'A': ['B', 'C'], 'B': ['D', 'E'], 'C': ['F', 'G'],
    'D': ['H'], 'E': ['I'], 'F': ['J'],
    'G': <String>[], 'H': <String>[], 'I': <String>[], 'J': <String>[],
  };

  /// El mismo árbol que usa `Busquedas.aEstrella`.
  static const arbolA = {
    'A': ['B', 'C'], 'B': ['D', 'E'], 'C': ['F', 'G'],
    'D': ['H'], 'E': <String>[], 'F': ['I'], 'G': <String>[],
    'H': <String>[], 'I': ['J'], 'J': <String>[],
  };

  /// Grafo de pantallas de la app (guía por voz).
  static const pantallas = {
    'bienvenida': ['home'],
    'home': ['historial', 'guardados', 'ajustes', 'camara'],
    'historial': ['home'],
    'guardados': ['home'],
    'ajustes': ['home'],
    'camara': ['home'],
  };

  /// BFS con cola FIFO sobre [grafo], de [inicio] a [meta].
  ///
  /// Devuelve un [ResultadoBusqueda] con el orden de exploración
  /// y el camino con menos pasos. [costoTotal] es el número de
  /// aristas del camino (BFS no pondera costos).
  static ResultadoBusqueda buscar(
    Map<String, List<String>> grafo,
    String inicio,
    String meta,
  ) {
    final cola = Queue<List<String>>()..add([inicio]); // FIFO
    final visitados = <String>{inicio};
    final orden = <String>[];

    while (cola.isNotEmpty) {
      final camino = cola.removeFirst(); // sale el primero que entró
      final nodo = camino.last;
      orden.add(nodo);
      if (nodo == meta) {
        return ResultadoBusqueda(
          orden: orden,
          camino: camino,
          costoTotal: camino.length - 1,
        );
      }
      for (final vecino in grafo[nodo] ?? const <String>[]) {
        if (!visitados.contains(vecino)) {
          visitados.add(vecino);
          cola.add([...camino, vecino]); // entra al final
        }
      }
    }
    return const ResultadoBusqueda(orden: [], camino: [], costoTotal: -1);
  }

  /// Atajo sobre el árbol de UCS (comparativa de la demo).
  static ResultadoBusqueda enArbolUcs(String inicio, String meta) =>
      buscar(arbolUcs, inicio, meta);
}
