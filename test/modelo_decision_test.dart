// Test de PARIDAD: la función Dart generada desde el árbol de
// sklearn debe dar EXACTAMENTE la misma respuesta que el modelo
// Python para los mismos casos de prueba.
//
// Los casos los genera `proyecto_eyes/p03_modelo_propio_eyes.py`
// (predicciones reales del árbol sobre el conjunto de prueba).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:eyes_app/ia/modelo_decision.dart';

void main() {
  test('modelo_decision.dart == arbol sklearn en los mismos casos',
      () {
    final f = File('test/datos_modelo_decision.json');
    expect(f.existsSync(), isTrue,
        reason: 'Corre exportar_arbol_a_dart.py primero');
    final casos =
        (jsonDecode(f.readAsStringSync()) as List).cast<Map>();

    for (final c in casos) {
      final esperado = (c['prediccion_python'] as num) == 1;
      final obtenido = ModeloDecision.debeAnunciar(
        confianza: (c['confianza'] as num).toDouble(),
        areaRelativa: (c['area_relativa'] as num).toDouble(),
        distanciaCentro: (c['distancia_centro'] as num).toDouble(),
        framesSeguidos: (c['frames_seguidos'] as num).toDouble(),
        esPeligroso: (c['es_peligroso'] as num).toDouble(),
        brillo: (c['brillo'] as num).toDouble(),
      );
      expect(obtenido, esperado,
          reason: 'discrepancia en caso ${jsonEncode(c)}');
    }
  });
}
