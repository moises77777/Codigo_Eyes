/// Interpretación PROPIA del texto leído (port de
/// ml/ocr/decodificar.py): extrae caducidad, precio/total y fecha
/// límite del texto que devuelve ML Kit. Es nuestra lógica; la
/// lectura en sí la hace ML Kit.
class DatosTexto {
  static final _reFecha = RegExp(
      r'(cad(?:ucidad)?|exp(?:ira)?|vence|lote|límite|limite|pagar antes de|vence el)?\s*'
      r'(\d{1,2}[/-](?:\d{1,2}[/-])?\d{2,4})',
      caseSensitive: false);
  static final _rePrecio = RegExp(
      r'(total|importe|precio|\$)\s*[:$]?\s*(\d[\d,.]*\d)',
      caseSensitive: false);
  static final _reTotal = RegExp(r'total\D{0,10}\$?\s*([\d,.]+)',
      caseSensitive: false);

  /// 'CAD 03/2027' → 'caduca el 03/2027'; '$125.50' → 'el precio es…'
  static Map<String, String> extraer(String texto) {
    final datos = <String, String>{'texto': texto};
    final mF = _reFecha.firstMatch(texto);
    if (mF != null && (mF.group(1) ?? '').isNotEmpty) {
      datos['fecha'] = mF.group(2)!;
      datos['tipo_fecha'] = mF.group(1)!;
    }
    final mP = _rePrecio.firstMatch(texto);
    if (mP != null) datos['precio'] = mP.group(2)!;
    final mT = _reTotal.firstMatch(texto);
    if (mT != null) datos['total'] = mT.group(1)!;
    return datos;
  }

  /// Resumen hablado de solo lo importante (modo "dato clave").
  static String resumenClave(String texto) {
    final d = extraer(texto);
    final partes = <String>[];
    if (d['total'] != null) partes.add('total ${d['total']} pesos');
    if (d['precio'] != null) partes.add('precio ${d['precio']} pesos');
    if (d['fecha'] != null) {
      partes.add('fecha ${d['fecha']} (${d['tipo_fecha']})');
    }
    return partes.isEmpty
        ? 'Leí texto pero sin datos clave.'
        : 'Lo importante: ${partes.join('; ')}.';
  }
}
