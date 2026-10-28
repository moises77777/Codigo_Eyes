import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Maneja los permisos de cámara y micrófono, incluyendo el caso
/// en que el usuario los haya denegado permanentemente.
class PermissionService {
  PermissionService._();

  /// Solicita cámara y micrófono. Devuelve true si ambos están concedidos.
  static Future<bool> requestCameraAndMic() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    return camera.isGranted && mic.isGranted;
  }

  /// Verifica si ambos permisos ya están concedidos.
  static Future<bool> haveCameraAndMic() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    return camera.isGranted && mic.isGranted;
  }

  /// True si alguno de los permisos está permanentemente denegado.
  static Future<bool> permanentlyDenied() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    return camera.isPermanentlyDenied || mic.isPermanentlyDenied;
  }

  /// Abre la pantalla de ajustes del sistema para que el usuario habilite permisos.
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Diálogo explicativo antes de redirigir a ajustes.
  static Future<void> showRationale(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Permisos necesarios',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        content: const Text(
          'EYES necesita la cámara para ver lo que tienes enfrente y el micrófono '
          'para escuchar tus comandos de voz.',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFFFFD600), fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openSettings();
            },
            child: const Text(
              'Abrir ajustes',
              style: TextStyle(color: Color(0xFFFFD600), fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
