import 'package:flutter/material.dart';

/// Botón grande accesible usado en la pantalla principal.
class BotonGrande extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback? onPressed;

  const BotonGrande({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
