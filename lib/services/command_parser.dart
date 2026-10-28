/// Comandos de voz reconocidos por EYES.
enum Comando {
  identificar,
  describir,
  ocr,
  resumir,
  guardar,
  repetir,
  historial,
  guardados,
  borrarHistorial,
  deteccionContinua,
  detener,
  masRapido,
  masLento,
  cambiarNombre,
  hora,
  ayuda,
  regresar,
  dejaDeEscuchar,
  algoritmos,
  si,
  no,
  preguntaImagen,
  conversar,
  ninguno,
}

/// Resultado del análisis de un comando de voz.
class ComandoVoz {
  final Comando comando;
  final String? argumento;
  final String textoOriginal;
  final double confianza;

  ComandoVoz({
    required this.comando,
    this.argumento,
    required this.textoOriginal,
    required this.confianza,
  });

  @override
  String toString() {
    return 'ComandoVoz($comando, arg: $argumento, conf: $confianza)';
  }
}

/// Interpreta frases de voz en comandos concretos de la app.
class CommandParser {
  CommandParser._();

  static const double _umbral = 0.45;

  /// Palabras que se ignoran al normalizar.
  static final Set<String> _ruido = {
    'eyes',
    'por favor',
    'oye',
    'favor',
    'ey',
    'eyye',
    'app',
  };

  static final Map<Comando, List<String>> _variaciones = {
    Comando.identificar: [
      'que es esto',
      'que es eso',
      'que es',
      'identificar',
      'identifica',
      'que hay',
      'que tengo',
      'dime que es',
      'es esto',
      'que ves',
      'que tengo enfrente',
      'que hay enfrente',
    ],
    Comando.describir: [
      'describe',
      'describe la escena',
      'donde estoy',
      'que hay alrededor',
      'como es el lugar',
    ],
    Comando.ocr: [
      'lee el texto',
      'lee',
      'que dice',
      'lee esto',
      'lee lo que dice',
    ],
    Comando.resumir: [
      'resume',
      'resumir',
      'resumen',
    ],
    Comando.guardar: [
      'guardar esto',
      'guarda',
      'guardalo',
      'guarda esto',
      'recuerda esto',
      'guardar',
    ],
    Comando.repetir: [
      'repetir',
      'repite',
      'otra vez',
      'de nuevo',
      'que dijiste',
      'no escuche',
    ],
    Comando.historial: [
      'historial',
      'que identifique',
      'ultimas cosas',
      'que he visto',
      'ultimas identificaciones',
    ],
    Comando.guardados: [
      'guardados',
      'mis cosas',
      'que tengo guardado',
      'mis objetos',
      'objetos guardados',
    ],
    Comando.borrarHistorial: [
      'borrar historial',
      'eliminar historial',
      'limpia historial',
      'vaciar historial',
    ],
    Comando.deteccionContinua: [
      'deteccion continua',
      'modo automatico',
      'automatico',
      'modo continuo',
      'detecta solo',
    ],
    Comando.detener: [
      'detener',
      'deten',
      'detente',
      'para',
      'parar',
      'cancelar',
      'stop',
      'alto',
      'silencio',
      'callate',
    ],
    Comando.masRapido: [
      'mas rapido',
      'rapido',
      'acelera',
      'habla mas rapido',
      'aumenta velocidad',
    ],
    Comando.masLento: [
      'mas lento',
      'lento',
      'mas despacio',
      'despacio',
      'habla mas lento',
      'reduce velocidad',
    ],
    Comando.cambiarNombre: [
      'mi nombre es',
      'llamame',
      'me llamo',
      'yo soy',
      'cambiame el nombre',
    ],
    Comando.hora: [
      'hora',
      'que hora es',
      'que hora son',
      'dime la hora',
      'dime la fecha',
      'que dia es hoy',
    ],
    Comando.ayuda: [
      'ayuda',
      'ayudame',
      'comandos',
      'que puedo decir',
      'que haces',
    ],
    Comando.regresar: [
      'regresar',
      'inicio',
      'volver',
      'ir a inicio',
      'pagina principal',
    ],
    Comando.dejaDeEscuchar: [
      'deja de escuchar',
      'apaga escucha',
      'pausa escucha',
      'no escuches',
      'desactiva escucha continua',
    ],
    Comando.algoritmos: [
      'algoritmos',
      'demo',
      'demostracion',
      'a estrella',
      'costo uniforme',
      'busqueda',
      'heuristica',
      'explica algoritmos',
      'practica',
    ],
    Comando.si: [
      'si',
      'correcto',
      'claro',
      'dale',
      'ok',
      'esta bien',
      'confirmar',
      'confirmo',
      'adelante',
    ],
    Comando.no: [
      'no',
      'negativo',
      'no gracias',
      'cancela',
      'no lo hagas',
    ],
  };

  /// Analiza [texto] y devuelve el comando detectado.
  static ComandoVoz interpretar(String texto) {
    final original = texto.trim();
    final normalizado = _normalizar(original);
    if (normalizado.isEmpty) {
      return ComandoVoz(
        comando: Comando.ninguno,
        textoOriginal: original,
        confianza: 0,
      );
    }

    // Preguntas directas sobre la imagen.
    if (_esPreguntaSobreImagen(normalizado)) {
      return ComandoVoz(
        comando: Comando.preguntaImagen,
        argumento: _extraerPregunta(normalizado),
        textoOriginal: original,
        confianza: 0.9,
      );
    }

    Comando? mejorComando;
    String? mejorArgumento;
    var mejorConfianza = 0.0;

    for (final entry in _variaciones.entries) {
      for (final variacion in entry.value) {
        final confianza = _calcularCoincidencia(normalizado, _normalizar(variacion));
        if (confianza > mejorConfianza) {
          mejorConfianza = confianza;
          mejorComando = entry.key;
          if (entry.key == Comando.cambiarNombre) {
            mejorArgumento = _extraerArgumento(normalizado, _normalizar(variacion));
          }
        }
      }
    }

    if (mejorComando == null || mejorConfianza < _umbral) {
      // Respaldo heurístico: distancia de Levenshtein contra todas las
      // variaciones. Permite entender comandos dichos con errores leves
      // ("identivicar", "leeelo") como en una búsqueda aproximada.
      final fuzzy = _busquedaAproximada(normalizado);
      if (fuzzy != null) return fuzzy;
      return ComandoVoz(
        comando: Comando.ninguno,
        textoOriginal: original,
        confianza: mejorConfianza,
      );
    }

    return ComandoVoz(
      comando: mejorComando,
      argumento: mejorArgumento,
      textoOriginal: original,
      confianza: mejorConfianza,
    );
  }

  /// Umbral mínimo de similitud Levenshtein para aceptar un comando
  /// mal pronunciado o mal reconocido.
  static const double _umbralFuzzy = 0.62;

  /// Busca la variación más parecida por distancia de edición.
  /// Devuelve el comando si la similitud supera [_umbralFuzzy].
  static ComandoVoz? _busquedaAproximada(String texto) {
    Comando? mejor;
    String? mejorVariacion;
    var mejorSimilitud = 0.0;

    for (final entry in _variaciones.entries) {
      for (final variacion in entry.value) {
        final sim = _similitud(texto, _normalizar(variacion));
        if (sim > mejorSimilitud) {
          mejorSimilitud = sim;
          mejor = entry.key;
          mejorVariacion = variacion;
        }
      }
    }

    if (mejor == null || mejorSimilitud < _umbralFuzzy) return null;

    return ComandoVoz(
      comando: mejor,
      argumento: mejor == Comando.cambiarNombre
          ? _extraerArgumento(texto, _normalizar(mejorVariacion!))
          : null,
      textoOriginal: texto,
      confianza: mejorSimilitud * 0.8,
    );
  }

  /// Similitud entre dos textos: 1 - (distancia / largo mayor).
  static double _similitud(String a, String b) {
    if (a == b) return 1.0;
    final mayor = a.length > b.length ? a.length : b.length;
    if (mayor == 0) return 0;
    return 1.0 - _levenshtein(a, b) / mayor;
  }

  /// Distancia de edición de Levenshtein (programación dinámica).
  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    var anterior = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      final actual = List<int>.filled(n + 1, 0);
      actual[0] = i;
      for (var j = 1; j <= n; j++) {
        final costo = a[i - 1] == b[j - 1] ? 0 : 1;
        var min = anterior[j] + 1;
        if (actual[j - 1] + 1 < min) min = actual[j - 1] + 1;
        if (anterior[j - 1] + costo < min) min = anterior[j - 1] + costo;
        actual[j] = min;
      }
      anterior = actual;
    }
    return anterior[n];
  }

  /// Normaliza el texto: minúsculas, sin acentos, sin signos y sin palabras de relleno.
  static String _normalizar(String texto) {
    var t = texto.toLowerCase().trim();

    // Eliminar acentos manualmente para no depender de Unicodes internos.
    const conAcentos = 'áéíóúüñ';
    const sinAcentos = 'aeiouun';
    final buffer = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      final idx = conAcentos.indexOf(ch);
      buffer.write(idx >= 0 ? sinAcentos[idx] : ch);
    }
    t = buffer.toString();

    // Conservar solo letras, números y espacios.
    t = t.split('').map((c) {
      final code = c.codeUnitAt(0);
      final letra = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
      return letra ? c : ' ';
    }).join();

    // Quitar palabras de ruido.
    for (final r in _ruido) {
      t = t.replaceAll(' $r ', ' ').replaceAll(RegExp('^$r\\s+'), '').replaceAll(RegExp('\\s+$r\$'), '');
    }

    // Colapsar espacios.
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _esPreguntaSobreImagen(String texto) {
    final inicios = [
      'pregunta',
      'cuanto',
      'cuantos',
      'cuanta',
      'cuantas',
      'de que color',
      'es',
      'hay',
      'cual',
      'cuales',
      'que color',
      'donde',
      'quien',
      'por que',
      'para que',
      'como',
      'cuando',
    ];
    return inicios.any((ini) => _empiezaConPalabra(texto, ini));
  }

  static bool _empiezaConPalabra(String texto, String palabra) {
    return texto == palabra || texto.startsWith('$palabra ');
  }

  static String _extraerPregunta(String texto) {
    if (_empiezaConPalabra(texto, 'pregunta')) {
      return texto.substring('pregunta'.length).trim();
    }
    return texto;
  }

  static double _calcularCoincidencia(String texto, String variacion) {
    if (texto == variacion) return 1.0;
    if (texto.startsWith(variacion)) return 0.9;
    if (variacion.startsWith(texto)) return 0.8;
    if (texto.contains(variacion)) {
      final ratio = variacion.length / texto.length;
      return (ratio * 0.8).clamp(0.5, 1.0).toDouble();
    }
    final palabrasTexto = texto.split(' ').toSet();
    final palabrasVar = variacion.split(' ').toSet();
    if (palabrasVar.isEmpty) return 0;
    final comunes = palabrasTexto.intersection(palabrasVar);
    return (comunes.length / palabrasVar.length) * 0.6;
  }

  static String _extraerArgumento(String texto, String variacion) {
    if (texto.startsWith(variacion)) {
      return texto.substring(variacion.length).trim();
    }
    // Busca la variación más larga que esté contenida.
    final idx = texto.indexOf(variacion);
    if (idx >= 0) {
      return texto.substring(idx + variacion.length).trim();
    }
    return texto;
  }
}
