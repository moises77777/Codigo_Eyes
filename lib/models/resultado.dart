import 'dart:math';

/// Representa un resultado que EYES mostrará o guardará en historial.
class Resultado {
  final String id;
  final String idLocal;
  final String tipo;
  final String texto;
  final String fecha;
  final String hora;
  final double confianza;
  final bool usoIaNube;
  bool sincronizado;

  Resultado({
    required this.id,
    String? idLocal,
    required this.tipo,
    required this.texto,
    required this.fecha,
    required this.hora,
    this.confianza = 0,
    this.usoIaNube = false,
    this.sincronizado = false,
  }) : idLocal = idLocal ?? generarIdLocal();

  /// Genera un uuid v4 local con Random.secure (sin paquetes nuevos).
  static String generarIdLocal() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // versión 4
    b[8] = (b[8] & 0x3f) | 0x80; // variante RFC
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-'
        '${h(6)}${h(7)}-${h(8)}${h(9)}-'
        '${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  /// Crea un resultado con la fecha y hora actuales.
  factory Resultado.ahora({
    required String tipo,
    required String texto,
    double confianza = 0,
    bool usoIaNube = false,
  }) {
    final ahora = DateTime.now();
    final id = '${ahora.microsecondsSinceEpoch}';
    return Resultado(
      id: id,
      tipo: tipo,
      texto: texto,
      fecha: _formatearFecha(ahora),
      hora: _formatearHora(ahora),
      confianza: confianza,
      usoIaNube: usoIaNube,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idLocal': idLocal,
      'tipo': tipo,
      'texto': texto,
      'fecha': fecha,
      'hora': hora,
      'confianza': confianza,
      'usoIaNube': usoIaNube,
      'sincronizado': sincronizado,
    };
  }

  factory Resultado.fromJson(Map<String, dynamic> json) {
    return Resultado(
      id: json['id'] as String? ?? '',
      // Los JSON viejos no traían idLocal: se genera uno al leerlos.
      idLocal: json['idLocal'] as String?,
      tipo: json['tipo'] as String? ?? '',
      texto: json['texto'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      hora: json['hora'] as String? ?? '',
      confianza: (json['confianza'] as num?)?.toDouble() ?? 0,
      usoIaNube: json['usoIaNube'] as bool? ?? false,
      sincronizado: json['sincronizado'] as bool? ?? false,
    );
  }

  static String _formatearFecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  static String _formatearHora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  String toString() {
    return 'Resultado(tipo: $tipo, texto: $texto, fecha: $fecha, hora: $hora)';
  }

  Resultado copyWith({
    String? id,
    String? idLocal,
    String? tipo,
    String? texto,
    String? fecha,
    String? hora,
    double? confianza,
    bool? usoIaNube,
  }) {
    return Resultado(
      id: id ?? this.id,
      idLocal: idLocal ?? this.idLocal,
      tipo: tipo ?? this.tipo,
      texto: texto ?? this.texto,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      confianza: confianza ?? this.confianza,
      usoIaNube: usoIaNube ?? this.usoIaNube,
      sincronizado: sincronizado,
    );
  }
}
