/// Representa un resultado que EYES mostrará o guardará en historial.
class Resultado {
  final String id;
  final String tipo;
  final String texto;
  final String fecha;
  final String hora;
  final double confianza;
  final bool usoIaNube;

  Resultado({
    required this.id,
    required this.tipo,
    required this.texto,
    required this.fecha,
    required this.hora,
    this.confianza = 0,
    this.usoIaNube = false,
  });

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
      'tipo': tipo,
      'texto': texto,
      'fecha': fecha,
      'hora': hora,
      'confianza': confianza,
      'usoIaNube': usoIaNube,
    };
  }

  factory Resultado.fromJson(Map<String, dynamic> json) {
    return Resultado(
      id: json['id'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      texto: json['texto'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      hora: json['hora'] as String? ?? '',
      confianza: (json['confianza'] as num?)?.toDouble() ?? 0,
      usoIaNube: json['usoIaNube'] as bool? ?? false,
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
    String? tipo,
    String? texto,
    String? fecha,
    String? hora,
    double? confianza,
    bool? usoIaNube,
  }) {
    return Resultado(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      texto: texto ?? this.texto,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      confianza: confianza ?? this.confianza,
      usoIaNube: usoIaNube ?? this.usoIaNube,
    );
  }
}
