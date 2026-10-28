import 'package:flutter/material.dart';

import '../controllers/eyes_controller.dart';

/// Lista de objetos guardados por el usuario.
class GuardadosScreen extends StatelessWidget {
  final EyesController controller;

  const GuardadosScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardados'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final lista = controller.guardados;
          if (lista.isEmpty) {
            return const Center(
              child: Text(
                'No tienes objetos guardados.',
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final r = lista[index];
              return Dismissible(
                key: ValueKey(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white, size: 32),
                ),
                onDismissed: (_) => controller.eliminarGuardado(r.id),
                child: Card(
                  color: const Color(0xFF121212),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFFFD600)),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    button: true,
                    label: r.texto,
                    child: InkWell(
                      onTap: () => controller.hablar(r.texto, guardarRespuesta: false),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.fecha} ${r.hora}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              r.texto,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
