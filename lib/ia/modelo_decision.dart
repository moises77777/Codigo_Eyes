/// MODELO DE DECISION PROPIO - generado automaticamente.
///
/// Arbol de decision entrenado con sklearn (DecisionTreeClassifier,
/// max_depth=4, random_state=42) sobre el dataset ficticio de
/// detecciones EYES (practicas/proyecto_eyes/p02_a_crear_dataset_eyes.py).
///
/// Entrenado: 2026-11-10
/// Muestras: 280 entrenamiento / 120 prueba
/// Metricas en prueba:
///   regla fija  -> accuracy 0.925, F1 0.866
///   este arbol  -> accuracy 0.975, F1 0.960
///   recall 'anunciar' del arbol: 0.947
///
/// Para regenerarlo: python proyecto_eyes/exportar_arbol_a_dart.py
/// (los casos de prueba estan en test/datos_modelo_decision.json).
library;

/// Arbol de decision exportado: decide si una deteccion se anuncia
/// por voz (true) o se espera (false).
class ModeloDecision {
  ModeloDecision._();

  /// True = anunciar. Variables identicas a las del entrenamiento.
  static bool debeAnunciar({
    required double confianza,
    required double areaRelativa,
    required double distanciaCentro,
    required double framesSeguidos,
    required double pesoPrioridad,
    required double esPeligroso,
    required double brillo,
  }) {
        if (confianza <= 0.681500) {
            if (pesoPrioridad <= 2.500000) {
                if (confianza <= 0.669000) {
                    return false;
                } else {
                    if (areaRelativa <= 0.450000) {
                        return false;
                    } else {
                        return true;
                    }
                }
            } else {
                if (confianza <= 0.542000) {
                    return false;
                } else {
                    if (framesSeguidos <= 2.500000) {
                        return false;
                    } else {
                        return true;
                    }
                }
            }
        } else {
            if (framesSeguidos <= 2.500000) {
                if (confianza <= 0.845500) {
                    return false;
                } else {
                    if (framesSeguidos <= 1.500000) {
                        return false;
                    } else {
                        return true;
                    }
                }
            } else {
                if (brillo <= 0.142500) {
                    return false;
                } else {
                    return true;
                }
            }
        }
  }
}
