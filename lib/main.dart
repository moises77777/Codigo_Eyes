import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Captura errores no controlados para evitar que la app se cierre.
  runZonedGuarded(
    () => runApp(const EyesApp()),
    (error, stack) {
      debugPrint('Error no controlado: $error\n$stack');
    },
  );
}
