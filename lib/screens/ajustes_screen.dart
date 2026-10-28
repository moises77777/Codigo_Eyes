import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../controllers/eyes_controller.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';

/// Pantalla de ajustes: voz, IA, clave API, nombre.
class AjustesScreen extends StatefulWidget {
  final EyesController controller;

  const AjustesScreen({super.key, required this.controller});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  double _rate = AppConfig.defaultSpeechRate;
  double _pitch = AppConfig.defaultPitch;
  bool _escuchaContinua = true;
  bool _usarIa = false;
  final _apiKeyController = TextEditingController();
  final _modeloController = TextEditingController(text: AppConfig.defaultGeminiModel);
  final _nombreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarValores();
  }

  Future<void> _cargarValores() async {
    _rate = TtsService.rate;
    _pitch = TtsService.pitch;
    _escuchaContinua = widget.controller.escuchaContinua;
    _usarIa = widget.controller.usarIaNube;
    final key = await StorageService.getGeminiApiKey();
    _apiKeyController.text = _enmascarar(key);
    _modeloController.text = await StorageService.getGeminiModel();
    _nombreController.text = widget.controller.nombreUsuario;
    setState(() {});
  }

  String _enmascarar(String key) {
    if (key.length <= 8) return key;
    return '${key.substring(0, 4)}${'*' * (key.length - 8)}${key.substring(key.length - 4)}';
  }

  Future<void> _guardarApiKey() async {
    // Quitar espacios y saltos por si la clave se pegó con caracteres extra.
    final raw = _apiKeyController.text.replaceAll(RegExp(r'\s'), '');
    // Si el usuario escribió asteriscos, no borramos la clave existente.
    if (!raw.contains('*')) {
      await widget.controller.setApiKey(raw);
    }
    final modelo = _modeloController.text.trim();
    if (modelo.isNotEmpty) {
      await widget.controller.setGeminiModel(modelo);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración de IA guardada.')),
      );
    }
  }

  /// Llama a Gemini con la clave guardada y dice el resultado en voz alta,
  /// para saber si la clave y el modelo funcionan.
  Future<void> _probarConexion() async {
    await widget.controller.hablar('Probando conexión con Gemini…',
        guardarRespuesta: false);
    final resultado = await GeminiService.probarConexion();
    await widget.controller.hablar(resultado, guardarRespuesta: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado)),
      );
    }
  }

  Future<void> _cambiarNombre() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isNotEmpty) {
      await widget.controller.cambiarNombre(nombre);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nombre cambiado a $nombre.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Voz',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Velocidad: ${_rate.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Slider(
            value: _rate,
            min: AppConfig.minSpeechRate,
            max: AppConfig.maxSpeechRate,
            divisions: 7,
            label: _rate.toStringAsFixed(1),
            onChanged: (v) async {
              setState(() => _rate = v);
              await TtsService.setRate(v);
            },
          ),
          Text(
            'Tono: ${_pitch.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Slider(
            value: _pitch,
            min: AppConfig.minPitch,
            max: AppConfig.maxPitch,
            divisions: 10,
            label: _pitch.toStringAsFixed(1),
            onChanged: (v) async {
              setState(() => _pitch = v);
              await TtsService.setPitch(v);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text(
              'Escucha continua',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            subtitle: const Text(
              'EYES escucha automáticamente después de hablar.',
              style: TextStyle(color: Colors.white70),
            ),
            value: _escuchaContinua,
            onChanged: (v) async {
              setState(() => _escuchaContinua = v);
              await widget.controller.setEscuchaContinua(v);
            },
          ),
          SwitchListTile(
            title: const Text(
              'Usar IA en la nube',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            subtitle: const Text(
              'Envía fotos a Google Gemini para descripciones más completas.',
              style: TextStyle(color: Colors.white70),
            ),
            value: _usarIa,
            onChanged: (v) async {
              setState(() => _usarIa = v);
              await widget.controller.setUsarIaNube(v);
              if (v) {
                await widget.controller.setAceptoGemini(true);
              }
            },
          ),
          const Divider(),
          Text(
            'Inteligencia artificial',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Clave de API de Gemini',
              hintText: 'Pega aquí tu clave',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _modeloController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Modelo de Gemini',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _guardarApiKey,
            child: const Text('Guardar clave API'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _probarConexion,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Probar conexión con Gemini'),
          ),
          const Divider(),
          Text(
            'Perfil',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nombreController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Tu nombre',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _cambiarNombre,
            child: const Text('Cambiar nombre'),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => widget.controller.hablar(
              'Hola, soy EYES. Así suena mi voz.',
              guardarRespuesta: false,
            ),
            icon: const Icon(Icons.record_voice_over),
            label: const Text('Probar voz'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modeloController.dispose();
    _nombreController.dispose();
    super.dispose();
  }
}
