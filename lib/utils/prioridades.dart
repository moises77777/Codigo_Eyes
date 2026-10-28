/// Heurística de prioridad para los objetos detectados en tiempo real.
///
/// Es el mismo principio que A*: cada objeto es un "nodo" y su peso es la
/// heurística h(n) = qué tan importante es para la seguridad del usuario.
/// Un cuchillo o una escalera se anuncian antes que una pared.
class Prioridades {
  Prioridades._();

  /// Peso de relevancia por etiqueta ya traducida al español.
  /// 1.0 = normal; mayor = se anuncia antes.
  static final Map<String, double> _peso = {
    // Peligrosos: prioridad máxima.
    'cuchillo': 3.0,
    'tijeras': 3.0,
    'tenedor': 2.0,
    'herramienta': 2.0,
    'escaleras': 2.5,
    'auto': 2.2,
    'camión': 2.2,
    'motocicleta': 2.2,
    'autobús': 2.0,
    'semáforo': 1.8,
    // Personas: muy relevante para un usuario ciego.
    'persona': 1.9,
    'gente': 1.9,
    'hombre': 1.9,
    'mujer': 1.9,
    'niño': 1.9,
    'niña': 1.9,
    'bebé': 1.9,
    'multitud': 1.5,
    'rostro': 1.6,
    'retrato': 1.4,
    // Animales.
    'perro': 1.6,
    'gato': 1.2,
    'animal': 1.1,
    // Objetos cotidianos útiles.
    'botella': 1.2,
    'taza': 1.2,
    'celular': 1.2,
    'llaves': 1.2,
    'puerta': 1.3,
    'silla': 1.1,
    'mesa': 1.1,
    // Ambiente genérico: baja prioridad.
    'pared': 0.5,
    'piso': 0.5,
    'techo': 0.5,
    'cielo': 0.5,
    'interior': 0.4,
    'exterior': 0.4,
    'naturaleza': 0.4,
    'ventana': 0.7,
  };

  /// Etiquetas que merecen aviso de precaución.
  static const _peligrosos = {
    'cuchillo',
    'tijeras',
    'tenedor',
    'herramienta',
    'escaleras',
    'auto',
    'camión',
    'motocicleta',
    'autobús',
    'perro',
  };

  /// Peso heurístico de la etiqueta (1.0 si no está en el mapa).
  static double pesoDe(String etiquetaEs) {
    return _peso[etiquetaEs.toLowerCase().trim()] ?? 1.0;
  }

  /// True si el objeto es potencialmente peligroso y conviene avisar.
  static bool esPeligroso(String etiquetaEs) {
    return _peligrosos.contains(etiquetaEs.toLowerCase().trim());
  }

  /// Puntaje final: confianza × peso heurístico.
  /// Es la f(n) de A* trasladada a objetos detectados.
  static double puntaje(String etiquetaEs, double confianza) {
    return confianza * pesoDe(etiquetaEs);
  }
}
