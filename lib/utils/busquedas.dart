/// Algoritmos de búsqueda heurística portados de las prácticas en Python:
/// búsqueda de costo uniforme (UCS) y búsqueda A*.
///
/// Funcionan igual que el heapq de Python: la "cola de prioridad" es una
/// lista que se ordena por prioridad cada vez que se extrae un nodo.
/// Se usan para la demo por voz y como ejemplo de la misma lógica que
/// prioriza objetos en la detección en tiempo real.
library;

/// Resultado de una búsqueda: orden de exploración, mejor ruta y costo.
class ResultadoBusqueda {
  final List<String> orden;
  final List<String> camino;
  final int costoTotal;

  const ResultadoBusqueda({
    required this.orden,
    required this.camino,
    required this.costoTotal,
  });
}

/// Nodo pendiente en la cola de prioridad.
class _Pendiente implements Comparable<_Pendiente> {
  final int prioridad; // f = g + h en A*, g en UCS
  final int g;
  final String nodo;
  final List<String> camino;

  const _Pendiente(this.prioridad, this.g, this.nodo, this.camino);

  @override
  int compareTo(_Pendiente otro) {
    if (prioridad != otro.prioridad) return prioridad.compareTo(otro.prioridad);
    return nodo.compareTo(otro.nodo); // desempate alfabético, como heapq
  }
}

/// Búsquedas sobre los árboles de la práctica de heurística.
class Busquedas {
  Busquedas._();

  // --- Árbol y costos de la práctica de costo uniforme ---
  static const _arbolUcs = {
    'A': ['B', 'C'], 'B': ['D', 'E'], 'C': ['F', 'G'],
    'D': ['H'], 'E': ['I'], 'F': ['J'],
    'G': <String>[], 'H': <String>[], 'I': <String>[], 'J': <String>[],
  };
  static const _costo = {
    'A': 0, 'B': 2, 'C': 5, 'D': 4, 'E': 1,
    'F': 2, 'G': 8, 'H': 3, 'I': 2, 'J': 3,
  };

  // --- Árbol y heurística de la práctica de A* ---
  static const _arbolA = {
    'A': ['B', 'C'], 'B': ['D', 'E'], 'C': ['F', 'G'],
    'D': ['H'], 'E': <String>[], 'F': ['I'], 'G': <String>[],
    'H': <String>[], 'I': ['J'], 'J': <String>[],
  };
  static const _h = {
    'A': 7, 'B': 6, 'C': 4, 'D': 7, 'E': 5,
    'F': 3, 'G': 6, 'H': 8, 'I': 1, 'J': 0,
  };
  static const _costoPaso = 1;

  /// Búsqueda de costo uniforme: expande siempre el nodo con menor
  /// costo acumulado g(n), igual que heuristica copy.py.
  static ResultadoBusqueda costoUniforme(String inicio, String meta) {
    final pendientes = <_Pendiente>[_Pendiente(0, 0, inicio, [inicio])];
    final orden = <String>[];

    while (pendientes.isNotEmpty) {
      pendientes.sort();
      final actual = pendientes.removeAt(0);
      orden.add(actual.nodo);
      if (actual.nodo == meta) {
        return ResultadoBusqueda(
          orden: orden,
          camino: actual.camino,
          costoTotal: actual.g,
        );
      }
      for (final hijo in _arbolUcs[actual.nodo] ?? const <String>[]) {
        final g = actual.g + (_costo[hijo] ?? 0);
        pendientes.add(_Pendiente(g, g, hijo, [...actual.camino, hijo]));
      }
    }
    return const ResultadoBusqueda(orden: [], camino: [], costoTotal: -1);
  }

  /// Búsqueda A*: expande el nodo con menor f(n) = g(n) + h(n),
  /// igual que heuristica.py.
  static ResultadoBusqueda aEstrella(String inicio, String meta) {
    final pendientes = <_Pendiente>[
      _Pendiente(_h[inicio] ?? 0, 0, inicio, [inicio])
    ];
    final orden = <String>[];

    while (pendientes.isNotEmpty) {
      pendientes.sort();
      final actual = pendientes.removeAt(0);
      orden.add(actual.nodo);
      if (actual.nodo == meta) {
        // Igual que la práctica: el "costo total" mostrado es la suma
        // de las heurísticas del camino.
        final total = actual.camino
            .fold<int>(0, (suma, n) => suma + (_h[n] ?? 0));
        return ResultadoBusqueda(
          orden: orden,
          camino: actual.camino,
          costoTotal: total,
        );
      }
      for (final hijo in _arbolA[actual.nodo] ?? const <String>[]) {
        final g = actual.g + _costoPaso;
        pendientes.add(
          _Pendiente(g + (_h[hijo] ?? 0), g, hijo, [...actual.camino, hijo]),
        );
      }
    }
    return const ResultadoBusqueda(orden: [], camino: [], costoTotal: -1);
  }
}
