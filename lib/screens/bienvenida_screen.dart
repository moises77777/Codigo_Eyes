import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/eyes_controller.dart';
import '../services/permission_service.dart';

/// Bienvenida 100 % por voz: pide el nombre, los permisos y el
/// consentimiento de la IA en la nube sin necesidad de ver la pantalla.
/// El campo de texto solo queda como respaldo por si el micrófono falla.
class BienvenidaScreen extends StatefulWidget {
  final EyesController controller;

  const BienvenidaScreen({super.key, required this.controller});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  final _nombreController = TextEditingController();
  int _paso = 0;
  bool _escuchando = false;
  String _nombreVoz = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncEscuchando);
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  /// El ícono del micrófono refleja el estado real del controlador.
  void _syncEscuchando() {
    final esc = widget.controller.estado == EstadoEyes.escuchando;
    if (esc != _escuchando && mounted) {
      setState(() => _escuchando = esc);
    }
  }

  // ---------- Flujo por voz ----------

  Future<void> _iniciar() async {
    // 1. Micrófono primero, porque todo lo demás depende de la voz.
    await widget.controller.hablar(
      'Hola, soy EYES. Para escucharte necesito el permiso de micrófono. '
      'Cuando aparezca el aviso, toca el botón permitir.',
      guardarRespuesta: false,
    );
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mic.isPermanentlyDenied && mounted) {
        await PermissionService.showRationale(context);
      }
      // Igual dejamos continuar: el campo de texto es el respaldo.
    }
    setState(() => _paso = 0);
    await _pedirNombre();
  }

  Future<void> _pedirNombre() async {
    final texto = await widget.controller.pedirRespuesta(
      '¿Cómo te llamas?',
      mensajeReintento: 'No escuché tu nombre. Dímelo otra vez.',
    );
    if (!mounted) return;

    final nombre = _limpiarNombre(texto ?? '');
    if (nombre.isEmpty) {
      await widget.controller.hablar(
        'No te escuché bien. Escribe tu nombre en el campo de texto y toca continuar.',
        guardarRespuesta: false,
      );
      return;
    }

    _nombreVoz = nombre;
    _nombreController.text = nombre;

    final confirmacion = await widget.controller.pedirConfirmacion(
      'Te llamaré $nombre. ¿Es correcto? Di sí o no.',
    );
    if (!mounted) return;

    if (confirmacion == true) {
      _pasoPermisos();
    } else if (confirmacion == false) {
      _nombreVoz = '';
      _nombreController.clear();
      await widget.controller.hablar(
        'De acuerdo, intentemos de nuevo.',
        guardarRespuesta: false,
      );
      _pedirNombre();
    } else {
      await widget.controller.hablar(
        'No te escuché bien. Escribe tu nombre en el campo de texto y toca continuar.',
        guardarRespuesta: false,
      );
    }
  }

  Future<void> _pasoPermisos() async {
    setState(() => _paso = 1);
    await widget.controller.hablar(
      'Ahora necesito la cámara para ver lo que tienes enfrente. '
      'Cuando aparezca el aviso, toca permitir.',
      guardarRespuesta: false,
    );
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (cam.isPermanentlyDenied && mounted) {
        await PermissionService.showRationale(context);
      }
      await widget.controller.hablar(
        'Sin la cámara no puedo identificar objetos. '
        'Continúo igual, pero puedes activarla después en ajustes.',
        guardarRespuesta: false,
      );
    }
    await _pasoIaNube();
  }

  Future<void> _pasoIaNube() async {
    setState(() => _paso = 2);
    final acepta = await widget.controller.pedirConfirmacion(
      'Para descripciones más completas puedo enviar fotos a una inteligencia artificial en la nube. '
      'Las imágenes no se guardan en ningún lado. ¿Lo permites? Di sí o no.',
    );
    if (!mounted) return;

    if (acepta == null) {
      await widget.controller.hablar(
        'No te escuché. Uso los botones de la pantalla. '
        'Toca sí para permitir o no para rechazar.',
        guardarRespuesta: false,
      );
      return;
    }

    await _finalizar(acepta);
  }

  Future<void> _finalizar(bool aceptaIaNube) async {
    final nombre = _nombreVoz.isNotEmpty
        ? _nombreVoz
        : _nombreController.text.trim();
    if (nombre.isEmpty) {
      await widget.controller.hablar(
        'Primero dime tu nombre.',
        guardarRespuesta: false,
      );
      return;
    }
    await widget.controller.finalizarBienvenida(nombre, aceptaIaNube);
    await widget.controller.hablar(
      'Perfecto, $nombre. EYES está listo. Te espero en la pantalla principal.',
      guardarRespuesta: false,
    );
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  // ---------- Utilidades ----------

  String _limpiarNombre(String texto) {
    final prefijos = [
      'me llamo ', 'mi nombre es ', 'soy ', 'yo soy ',
      'me dicen ', 'dime ', 'llamame ', 'llámame ',
      'puedes decirme ', 'mi nombre ', 'nombre ',
    ];
    var t = texto.toLowerCase().trim();
    for (final p in prefijos) {
      if (t.startsWith(p)) {
        t = t.substring(p.length).trim();
        break;
      }
    }
    if (t.isEmpty) return '';
    return t
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  // ---------- UI (respaldo visual mínimo) ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenida a EYES')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _escuchando ? Icons.mic : Icons.face,
                size: 80,
                color: const Color(0xFFFFD600),
              ),
              const SizedBox(height: 24),
              Text(
                _textoPaso(),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _escuchando
                    ? 'Escuchando… habla cerca del micrófono'
                    : 'Todo se hace por voz. El campo de abajo es solo de respaldo.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Respaldo visual: campo de texto para el nombre.
              if (_paso == 0) ...[
                TextField(
                  controller: _nombreController,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'O escribe tu nombre aquí',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_nombreController.text.trim().isNotEmpty) {
                      _nombreVoz = _limpiarNombre(_nombreController.text);
                      _pasoPermisos();
                    }
                  },
                  child: const Text('Continuar'),
                ),
              ],
              // Respaldo visual: botones para el consentimiento de la IA.
              if (_paso == 2) ...[
                ElevatedButton(
                  onPressed: () => _finalizar(true),
                  child: const Text('Sí, permitir IA en la nube'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _finalizar(false),
                  child: const Text('No, gracias'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _textoPaso() {
    switch (_paso) {
      case 0:
        return '¿Cómo te llamas?';
      case 1:
        return 'Permisos de cámara';
      case 2:
        return '¿Usar IA en la nube?';
      default:
        return 'Listo';
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncEscuchando);
    _nombreController.dispose();
    super.dispose();
  }
}
