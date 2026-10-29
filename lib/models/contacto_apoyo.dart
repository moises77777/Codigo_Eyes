/// Contacto de apoyo al que EYES puede llamar por voz.
class ContactoApoyo {
  final String nombre;
  final String telefono;

  const ContactoApoyo({required this.nombre, required this.telefono});

  factory ContactoApoyo.fromJson(Map<String, dynamic> json) {
    return ContactoApoyo(
      nombre: json['nombre'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'nombre': nombre, 'telefono': telefono};

  /// Convierte un número dictado por voz a solo dígitos: acepta tanto
  /// dígitos escritos ('55-1234-5678') como palabras ('cinco cinco uno...').
  static String normalizarTelefono(String texto) {
    const palabras = {
      'cero': '0',
      'uno': '1',
      'dos': '2',
      'tres': '3',
      'cuatro': '4',
      'cinco': '5',
      'seis': '6',
      'siete': '7',
      'ocho': '8',
      'nueve': '9',
    };
    final buffer = StringBuffer();
    for (var token in texto.toLowerCase().split(RegExp(r'\s+'))) {
      token = token.trim();
      if (token.isEmpty) continue;
      if (palabras.containsKey(token)) {
        buffer.write(palabras[token]);
      } else {
        // Token con dígitos y/o signos: conserva solo los dígitos.
        for (final c in token.split('')) {
          final code = c.codeUnitAt(0);
          if (code >= 48 && code <= 57) buffer.write(c);
        }
      }
    }
    return buffer.toString();
  }
}
