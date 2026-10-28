import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../controllers/eyes_controller.dart';
import '../widgets/boton_microfono.dart';
import '../widgets/marco_enfoque.dart';
import '../widgets/panel_estado.dart';

/// Pantalla principal: cámara grande, detección en tiempo real y
/// control 100 % por voz. Tocar la cámara activa el micrófono;
/// mantener pulsado repite el último resultado.
class HomeScreen extends StatefulWidget {
  final EyesController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _errorCamara;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.autoEscucha = true;
    _initCamara();
    _saludar();
  }

  Future<void> _saludar() async {
    final nombre = widget.controller.nombreUsuario;
    if (nombre.isNotEmpty) {
      await widget.controller.hablar(
        'Hola $nombre, listo para ayudarte. Di ayuda para conocer los comandos.',
        guardarRespuesta: false,
      );
    }
    // Iniciar escucha continua si está activada.
    if (widget.controller.escuchaContinua) {
      await widget.controller.iniciarEscucha();
    }
  }

  Future<void> _initCamara() async {
    final ok = await widget.controller.iniciarCamara();
    if (!mounted) return;
    if (ok) {
      setState(() => _errorCamara = null);
      // La detección en tiempo real arranca sola al abrir la cámara.
      await widget.controller.activarDeteccionContinua();
    } else {
      setState(() {
        _errorCamara = 'No se pudo iniciar la cámara. Revisa los permisos.';
      });
      await widget.controller.hablar(_errorCamara!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      widget.controller.pausarCamara();
    } else if (state == AppLifecycleState.resumed) {
      widget.controller.reanudarCamara().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget.controller.autoEscucha = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.controller.nombreUsuario.isEmpty
              ? 'EYES'
              : 'EYES - ${widget.controller.nombreUsuario}',
        ),
        actions: [
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bookmark),
                    tooltip: 'Guardados',
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/guardados'),
                  ),
                  if (widget.controller.guardados.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFFFFD600),
                        child: Text(
                          '${widget.controller.guardados.length}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.of(context).pushNamed('/historial'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).pushNamed('/ajustes'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(child: _vistaCamara()),
              const SizedBox(height: 12),
              PanelEstado(controller: widget.controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vistaCamara() {
    final controller = widget.controller.cameraService.controller;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => widget.controller.iniciarEscucha(),
        onLongPress: () => widget.controller.repetirUltimo(),
        child: Container(
          color: Colors.black,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null && controller.value.isInitialized)
                CameraPreview(controller)
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off,
                          color: Colors.white54, size: 64),
                      const SizedBox(height: 12),
                      Text(
                        _errorCamara ?? 'Iniciando cámara…',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_errorCamara != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ElevatedButton(
                            onPressed: _initCamara,
                            child: const Text('Reintentar'),
                          ),
                        ),
                    ],
                  ),
                ),
              const MarcoEnfoque(),
              Positioned(
                bottom: 12,
                right: 12,
                child: BotonMicrofono(
                  escuchando:
                      widget.controller.estado == EstadoEyes.escuchando,
                  onPressed: () {
                    if (widget.controller.estado == EstadoEyes.escuchando) {
                      widget.controller.detenerEscucha();
                    } else {
                      widget.controller.iniciarEscucha();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
