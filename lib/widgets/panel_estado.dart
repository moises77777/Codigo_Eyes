import 'package:flutter/material.dart';

import '../controllers/eyes_controller.dart';

/// Panel que muestra el estado actual, el último comando escuchado
/// y el último resultado hablado por EYES.
class PanelEstado extends StatelessWidget {
  final EyesController controller;

  const PanelEstado({super.key, required this.controller});

  IconData _iconoEstado(EstadoEyes e) {
    switch (e) {
      case EstadoEyes.listo:
        return Icons.check_circle;
      case EstadoEyes.escuchando:
        return Icons.mic;
      case EstadoEyes.identificando:
        return Icons.camera_alt;
      case EstadoEyes.leyendo:
        return Icons.menu_book;
      case EstadoEyes.consultandoIA:
        return Icons.cloud;
      case EstadoEyes.sinConexionLocal:
        return Icons.cloud_off;
      case EstadoEyes.hablando:
        return Icons.record_voice_over;
      case EstadoEyes.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Semantics(
          liveRegion: true,
          label: 'Estado: ${controller.mensajeEstado}. '
              '${controller.ultimoResultado?.texto ?? ''}',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              border: Border.all(
                color: controller.estado == EstadoEyes.sinConexionLocal
                    ? Colors.orange
                    : const Color(0xFFFFD600),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _iconoEstado(controller.estado),
                      color: const Color(0xFFFFD600),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.mensajeEstado,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (controller.tiempoRealActivo)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.videocam, color: Colors.greenAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'DETECCIÓN EN TIEMPO REAL ACTIVA',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (controller.ultimoComandoEscuchado.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Escuché: "${controller.ultimoComandoEscuchado}"',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                if (controller.ultimoResultado != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      controller.ultimoResultado!.texto,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
