import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../controllers/eyes_controller.dart';
import '../models/contacto_apoyo.dart';
import '../services/ia_nube_service.dart';
import '../services/sincronizacion_service.dart';
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
  double _volume = 1.0;
  bool _escuchaContinua = true;
  bool _vibracion = true;
  bool _usarIa = false;
  bool _modeloPropio = false;
  double _umbral = 0.70;
  final _urlController = TextEditingController();
  final _claveNubeController = TextEditingController();
  String _textoSincronizacion = 'Última sincronización: todavía no. Pendientes: 0.';
  final _apiKeyController = TextEditingController();
  final _modeloController = TextEditingController(text: AppConfig.defaultIaModel);
  final _nombreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarValores();
  }

  Future<void> _cargarValores() async {
    _rate = TtsService.rate;
    _pitch = TtsService.pitch;
    _volume = TtsService.volume;
    _escuchaContinua = widget.controller.escuchaContinua;
    _vibracion = widget.controller.vibracionActivada;
    _usarIa = widget.controller.usarIaNube;
    _modeloPropio = await StorageService.getModeloPropio();
    _umbral = await StorageService.getUmbralConfianza();
    _urlController.text = await StorageService.getApiUrl();
    final claveNube = await StorageService.getApiKey();
    _claveNubeController.text = _enmascarar(claveNube);
    final key = await StorageService.getIaApiKey();
    _apiKeyController.text = _enmascarar(key);
    final modelo = await StorageService.getIaModel();
    _modeloController.text =
        modelo.isNotEmpty ? modelo : AppConfig.defaultIaModel;
    _nombreController.text = widget.controller.nombreUsuario;
    SincronizacionService.onCambio = _actualizarTextoSync;
    setState(() {});
    await _actualizarTextoSync();
  }

  /// Actualiza el texto de última sincronización y pendientes.
  Future<void> _actualizarTextoSync() async {
    final pendientes = await SincronizacionService.pendientes();
    final ultima = SincronizacionService.ultimaSincronizacion;
    final ultimaTexto = ultima == null
        ? 'todavía no'
        : '${ultima.day}/${ultima.month} ${ultima.hour}:${ultima.minute.toString().padLeft(2, '0')}';
    if (mounted) {
      setState(() {
        _textoSincronizacion =
            'Última sincronización: $ultimaTexto. Pendientes: $pendientes.';
      });
    }
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
      await widget.controller.setIaModel(modelo);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración de IA guardada.')),
      );
    }
  }

  /// Llama a la IA en la nube con la clave guardada y dice el resultado
  /// en voz alta, para saber si la clave y el modelo funcionan.
  Future<void> _probarConexion() async {
    await widget.controller.hablar('Probando conexión con la IA…',
        guardarRespuesta: false);
    final resultado = await IaNubeService.probarConexion();
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

  /// Diálogo visual de respaldo para agregar un contacto
  /// (la vía principal es por voz con "agregar contacto").
  Future<void> _dialogoAgregarContacto() async {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Nombre del contacto',
              textField: true,
              child: TextField(
                controller: nombreCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Número de teléfono del contacto',
              textField: true,
              child: TextField(
                controller: telefonoCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          Semantics(
            label: 'Guardar contacto',
            button: true,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );

    if (guardado == true) {
      final nombre = nombreCtrl.text.trim();
      final telefono = ContactoApoyo.normalizarTelefono(telefonoCtrl.text);
      if (nombre.isNotEmpty && telefono.length >= 7) {
        await widget.controller.agregarContacto(nombre, telefono);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Contacto $nombre guardado.')),
          );
        }
      }
    }
    nombreCtrl.dispose();
    telefonoCtrl.dispose();
  }

  /// Confirmación visual antes de eliminar un contacto.
  Future<void> _confirmarEliminarContacto(ContactoApoyo contacto) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content: Text('¿Eliminar a ${contacto.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          Semantics(
            label: 'Confirmar eliminación de ${contacto.nombre}',
            button: true,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ),
        ],
      ),
    );
    if (confirma == true) {
      await widget.controller.eliminarContacto(contacto.nombre);
      if (mounted) setState(() {});
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
              await StorageService.setConfigPendiente(true);
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
              await StorageService.setConfigPendiente(true);
            },
          ),
          Text(
            'Volumen: ${(_volume * 100).round()} por ciento',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Semantics(
            label: 'Volumen de la voz',
            child: Slider(
              value: _volume,
              min: 0.2,
              max: 1.0,
              divisions: 4,
              label: '${(_volume * 100).round()}%',
              onChanged: (v) async {
                setState(() => _volume = v);
                await TtsService.setVolume(v);
                await StorageService.setConfigPendiente(true);
              },
            ),
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
          Semantics(
            label: 'Vibración de apoyo',
            child: SwitchListTile(
              title: const Text(
                'Vibración',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              subtitle: const Text(
                'Vibra para avisar que el micrófono está abierto y guiar el encuadre.',
                style: TextStyle(color: Colors.white70),
              ),
              value: _vibracion,
              onChanged: (v) async {
                setState(() => _vibracion = v);
                await widget.controller.setVibracion(v);
              },
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Usar IA en la nube',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            subtitle: const Text(
              'Envía fotos a una inteligencia artificial en la nube para descripciones más completas.',
              style: TextStyle(color: Colors.white70),
            ),
            value: _usarIa,
            onChanged: (v) async {
              setState(() => _usarIa = v);
              await widget.controller.setUsarIaNube(v);
              if (v) {
                await widget.controller.setAceptoIaNube(true);
              }
            },
          ),
          const Divider(),
          Text(
            'Nube',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Semantics(
            label: 'URL del servidor de sincronización',
            child: TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'URL del servidor',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'http://192.168.1.10:3000',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              keyboardType: TextInputType.url,
            ),
          ),
          Semantics(
            label: 'Clave del servidor de sincronización',
            child: TextField(
              controller: _claveNubeController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Clave del servidor',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              obscureText: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Guardar configuración de la nube',
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await StorageService.setApiUrl(_urlController.text);
                      if (_claveNubeController.text.isNotEmpty) {
                        await StorageService.setApiKey(
                            _claveNubeController.text);
                        _claveNubeController.text =
                            _enmascarar(_claveNubeController.text);
                      }
                      await widget.controller.hablar(
                        'Servidor de la nube guardado.',
                        guardarRespuesta: false,
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar servidor'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Sincronizar los datos ahora',
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await widget.controller.sincronizarAhora();
                      setState(() {});
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Sincronizar ahora'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _textoSincronizacion,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const Divider(),
          Text(
            'Detección de objetos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Semantics(
            label: 'Usar modelo propio de detección',
            child: SwitchListTile(
              title: const Text(
                'Usar modelo propio',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              subtitle: const Text(
                'Usa el modelo entrenado por ti en assets/modelos/propio.',
                style: TextStyle(color: Colors.white70),
              ),
              value: _modeloPropio,
              onChanged: (v) async {
                setState(() => _modeloPropio = v);
                await widget.controller.setModeloPropio(v);
              },
            ),
          ),
          Text(
            'Confianza mínima para anunciar: ${(_umbral * 100).round()}%',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Semantics(
            label: 'Confianza mínima para anunciar objetos',
            child: Slider(
              value: _umbral,
              min: 0.50,
              max: 0.90,
              divisions: 8,
              label: '${(_umbral * 100).round()}%',
              onChanged: (v) async {
                setState(() => _umbral = v);
                await widget.controller.setUmbralConfianza(v);
              },
            ),
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
              labelText: 'Clave de la IA en la nube (Anthropic)',
              hintText: 'Pega aquí tu clave',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _modeloController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Modelo',
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
            label: const Text('Probar conexión con la IA'),
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
          const Divider(),
          Text(
            'Contactos de apoyo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (widget.controller.contactos.isEmpty)
            const Text(
              'Sin contactos. También puedes decir "agregar contacto" por voz.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          for (final contacto in widget.controller.contactos)
            Semantics(
              label:
                  'Contacto ${contacto.nombre}, teléfono ${contacto.telefono}',
              child: ListTile(
                title: Text(
                  contacto.nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                subtitle: Text(
                  contacto.telefono,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Semantics(
                  label: 'Eliminar a ${contacto.nombre}',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Eliminar a ${contacto.nombre}',
                    onPressed: () => _confirmarEliminarContacto(contacto),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _dialogoAgregarContacto,
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar contacto'),
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
    _urlController.dispose();
    _claveNubeController.dispose();
    SincronizacionService.onCambio = null;
    super.dispose();
  }
}
