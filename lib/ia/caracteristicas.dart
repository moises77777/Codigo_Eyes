/// Características de una detección para el modelo de decisión.
///
/// Calcula las mismas 7 variables con las que se entrenó el árbol
/// (ver practicas/proyecto_eyes/p02_a_crear_dataset_eyes.py). Los
/// nombres deben coincidir con la lista VARIABLES de Python:
///
///   confianza, area_relativa, distancia_centro, frames_seguidos,
///   peso_prioridad, es_peligroso, brillo
///
/// No modifica nada existente: la integración se hace en la FASE B.
library;

import 'dart:math' show sqrt;
import 'dart:ui' show Size;

import '../services/detector_service.dart';
import '../utils/prioridades.dart';

/// Las 7 variables de una detección, listas para el modelo.
class CaracteristicasDeteccion {
  final double confianza;
  final double areaRelativa;
  final double distanciaCentro;
  final double framesSeguidos;
  final double pesoPrioridad;
  final double esPeligroso;
  final double brillo;

  const CaracteristicasDeteccion({
    required this.confianza,
    required this.areaRelativa,
    required this.distanciaCentro,
    required this.framesSeguidos,
    required this.pesoPrioridad,
    required this.esPeligroso,
    required this.brillo,
  });

  /// Construye las características a partir de una [Deteccion] y del
  /// tamaño del frame donde se detectó.
  ///
  /// - [d]            la detección del modelo de visión.
  /// - [tamanoFrame]  ancho/alto del frame analizado.
  /// - [framesSeguidos] cuántos frames lleva vista la misma etiqueta.
  /// - [brillo]       brillo medio del frame, 0 (oscuro) a 1 (claro).
  factory CaracteristicasDeteccion.de(
    Deteccion d, {
    required Size tamanoFrame,
    required int framesSeguidos,
    required double brillo,
  }) {
    final areaFrame = tamanoFrame.width * tamanoFrame.height;
    final areaRel = areaFrame > 0
        ? ((d.caja.width * d.caja.height) / areaFrame).clamp(0.0, 1.0)
        : 0.0;

    // Distancia del centro de la caja al centro del frame,
    // normalizada por la mitad de la diagonal (0 centrado .. 1 esquina).
    final cx = d.caja.center.dx - tamanoFrame.width / 2;
    final cy = d.caja.center.dy - tamanoFrame.height / 2;
    final mediaDiagonal = sqrt(
            tamanoFrame.width * tamanoFrame.width +
                tamanoFrame.height * tamanoFrame.height) /
        2;
    final distancia = mediaDiagonal > 0
        ? (sqrt(cx * cx + cy * cy) / mediaDiagonal).clamp(0.0, 1.0)
        : 0.0;

    return CaracteristicasDeteccion(
      confianza: d.confianza,
      areaRelativa: areaRel.toDouble(),
      distanciaCentro: distancia.toDouble(),
      framesSeguidos: framesSeguidos.toDouble(),
      pesoPrioridad: Prioridades.pesoDe(d.etiqueta),
      esPeligroso: Prioridades.esPeligroso(d.etiqueta) ? 1.0 : 0.0,
      brillo: brillo,
    );
  }
}
