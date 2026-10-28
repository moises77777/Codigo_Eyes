import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'controllers/eyes_controller.dart';
import 'screens/ajustes_screen.dart';
import 'screens/bienvenida_screen.dart';
import 'screens/guardados_screen.dart';
import 'screens/historial_screen.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

/// Aplicación EYES con tema, orientación vertical y rutas.
class EyesApp extends StatefulWidget {
  const EyesApp({super.key});

  @override
  State<EyesApp> createState() => _EyesAppState();
}

class _EyesAppState extends State<EyesApp> {
  late final EyesController _controller;
  bool _cargando = true;
  bool _primerUso = true;

  @override
  void initState() {
    super.initState();
    _controller = EyesController();
    _init();
  }

  Future<void> _init() async {
    // Bloquear orientación vertical.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await _controller.init();
    _primerUso = !(await StorageService.getPrimerUsoCompletado());
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFFFD600)),
                const SizedBox(height: 16),
                Text(
                  'Iniciando EYES…',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: EyesController.navigatorKey,
        title: 'EYES',
        theme: EyesTheme.darkTheme,
        initialRoute: _primerUso ? '/bienvenida' : '/home',
        routes: {
          '/bienvenida': (_) => BienvenidaScreen(controller: _controller),
          '/home': (_) => HomeScreen(controller: _controller),
          '/historial': (_) => HistorialScreen(controller: _controller),
          '/guardados': (_) => GuardadosScreen(controller: _controller),
          '/ajustes': (_) => AjustesScreen(controller: _controller),
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
