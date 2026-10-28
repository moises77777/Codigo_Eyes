import 'package:flutter/material.dart';

/// Botón circular grande para activar el micrófono.
class BotonMicrofono extends StatelessWidget {
  final bool escuchando;
  final VoidCallback? onPressed;

  const BotonMicrofono({
    super.key,
    required this.escuchando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: escuchando ? 'Escuchando' : 'Activar micrófono',
      hint: 'Toca para hablar un comando de voz',
      button: true,
      child: Material(
        color: escuchando ? Colors.redAccent : const Color(0xFFFFD600),
        shape: const CircleBorder(),
        elevation: 8,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 104,
            height: 104,
            child: Icon(
              escuchando ? Icons.mic : Icons.mic_none,
              color: Colors.black,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }
}
