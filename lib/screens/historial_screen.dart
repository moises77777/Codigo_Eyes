import 'package:flutter/material.dart';

import '../controllers/eyes_controller.dart';
import '../models/resultado.dart';

/// Muestra los últimos 30 resultados guardados en historial.
class HistorialScreen extends StatelessWidget {
  final EyesController controller;

  const HistorialScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Borrar historial',
            onPressed: () async {
              await controller.hablar(
                'Voy a borrar el historial. ¿Confirmas?',
                guardarRespuesta: false,
              );
              if (context.mounted) {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.black,
                    title: const Text(
                      'Borrar historial',
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    content: const Text(
                      '¿Estás seguro de que quieres borrar todo el historial?',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Color(0xFFFFD600), fontSize: 18),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Borrar',
                          style: TextStyle(color: Color(0xFFFFD600), fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  await controller.borrarHistorial();
                } else {
                  await controller.hablar('Borrado cancelado.', guardarRespuesta: false);
                }
              }
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final lista = controller.historial;
          if (lista.isEmpty) {
            return const Center(
              child: Text(
                'No hay historial todavía.',
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final r = lista[index];
              return _TarjetaResultado(
                resultado: r,
                onTap: () => controller.hablar(r.texto, guardarRespuesta: false),
              );
            },
          );
        },
      ),
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  final Resultado resultado;
  final VoidCallback onTap;

  const _TarjetaResultado({required this.resultado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${resultado.tipo}: ${resultado.texto}',
      child: Card(
        color: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFFD600)),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(
                        resultado.tipo.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: const Color(0xFFFFD600),
                    ),
                    Text(
                      '${resultado.fecha} ${resultado.hora}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  resultado.texto,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
