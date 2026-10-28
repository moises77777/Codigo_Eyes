import 'package:flutter/material.dart';

/// Marco central para ayudar al usuario a colocar el objeto o documento.
class MarcoEnfoque extends StatelessWidget {
  const MarcoEnfoque({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFFFD600),
            width: 4,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Icon(
            Icons.center_focus_strong,
            color: Color(0xFFFFD600),
            size: 48,
          ),
        ),
      ),
    );
  }
}
