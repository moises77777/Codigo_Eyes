import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/resultado.dart';
import 'storage_service.dart';

/// Sincroniza los datos locales con la API de EYES (MongoDB):
/// ajustes, historial, objetos guardados, contactos y borrados
/// pendientes. Todo corre en segundo plano; si no hay internet o el
/// servidor falla, los datos quedan pendientes para la próxima vez.
class SincronizacionService {
  SincronizacionService._();

  /// Inyectables para pruebas (MockClient, esperas cortas).
  @visibleForTesting
  static http.Client? clientParaPruebas;
  @visibleForTesting
  static List<Duration> esperasParaPruebas = const [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  @visibleForTesting
  static bool? conexionParaPruebas;

  static DateTime? ultimaSincronizacion;
  static String? ultimoError;

  /// Callback para que Ajustes muestre cambios (pendientes, última sync).
  static void Function()? onCambio;

  static http.Client get _client => clientParaPruebas ?? http.Client();

  static bool _enEjecucion = false;

  static Future<String> _baseUrl() async {
    final guardada = await StorageService.getApiUrl();
    if (guardada.isNotEmpty) return guardada;
    return const String.fromEnvironment('EYES_API_URL').trim();
  }

  static Future<String> _apiKey() async {
    final guardada = await StorageService.getApiKey();
    if (guardada.isNotEmpty) return guardada;
    return const String.fromEnvironment('EYES_API_KEY').trim();
  }

  static Future<bool> _hayConexion() async {
    if (conexionParaPruebas != null) return conexionParaPruebas!;
    final r = await Connectivity().checkConnectivity();
    return r.isNotEmpty && !r.contains(ConnectivityResult.none);
  }

  /// URL del servidor configurada (vacía si no hay).
  static Future<String> urlConfigurada() => _baseUrl();

  /// Cuenta de elementos pendientes de subir.
  static Future<int> pendientes() async {
    final historial = (await StorageService.getHistorial())
        .where((r) => !r.sincronizado)
        .length;
    final guardados = (await StorageService.getGuardados())
        .where((r) => !r.sincronizado)
        .length;
    final borrados = (await StorageService.getBorradosPendientes()).length;
    final extras = (await StorageService.getContactosPendientes() ? 1 : 0) +
        (await StorageService.getConfigPendiente() ? 1 : 0);
    return historial + guardados + borrados + extras;
  }

  /// Sincroniza todo lo pendiente. Devuelve true si quedó todo subido.
  /// Reintenta hasta 3 veces con esperas de 2, 4 y 8 s.
  static Future<bool> sincronizarPendientes() async {
    if (_enEjecucion) return false;
    _enEjecucion = true;
    try {
      final base = await _baseUrl();
      if (base.isEmpty) {
        ultimoError = 'sin servidor configurado';
        _avisar();
        return false;
      }
      if (!await _hayConexion()) {
        ultimoError = 'sin conexión a internet';
        _avisar();
        return false;
      }

      for (var intento = 0; intento < esperasParaPruebas.length; intento++) {
        try {
          await _sincronizarTodo(base);
          ultimaSincronizacion = DateTime.now();
          ultimoError = null;
          _avisar();
          return true;
        } catch (e) {
          debugPrint('[EYES nube] intento ${intento + 1} falló: $e');
          ultimoError = _mensajeDeError(e);
          if (intento < esperasParaPruebas.length - 1) {
            await Future.delayed(esperasParaPruebas[intento]);
          }
        }
      }
      _avisar();
      return false;
    } finally {
      _enEjecucion = false;
    }
  }

  static void _avisar() {
    try {
      onCambio?.call();
    } catch (_) {
      // El listener de Ajustes pudo haberse desmontado; no pasa nada.
    }
  }

  static String _mensajeDeError(Object e) {
    if (e is TimeoutException) return 'el servidor tardó demasiado';
    if (e is SocketException) return 'no llegué al servidor';
    if (e is EstadoHttpException) return e.message;
    return 'error al sincronizar';
  }

  /// Una ejecución completa de sincronización.
  static Future<void> _sincronizarTodo(String base) async {
    final id = await StorageService.getIdDispositivo();
    final headers = {
      'content-type': 'application/json',
      'x-api-key': await _apiKey(),
    };

    Future<String> peticion(String metodo, String ruta,
        {Object? cuerpo}) async {
      final uri = Uri.parse('$base$ruta');
      final resp = await switch (metodo) {
        'put' => _client.put(uri, headers: headers, body: jsonEncode(cuerpo)),
        'post' => _client.post(uri, headers: headers, body: jsonEncode(cuerpo)),
        'delete' => _client.delete(uri, headers: headers),
        _ => throw StateError('método no soportado'),
      }.timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 400) {
        throw EstadoHttpException(
          'el servidor respondió ${resp.statusCode}',
        );
      }
      return resp.body;
    }

    // (a) Usuario con los ajustes actuales.
    await peticion('put', '/api/usuarios/$id', cuerpo: {
      'nombre': await StorageService.getNombre(),
      'velocidad_voz': await StorageService.getSpeechRate(),
      'tono': await StorageService.getPitch(),
      'volumen': await StorageService.getVolume(),
      'vibracion': await StorageService.getVibracion(),
      'usar_ia_nube': await StorageService.getUsarIaNube(),
      'acepto_ia_nube': await StorageService.getAceptoIaNube(),
      'modelo_propio': await StorageService.getModeloPropio(),
      'umbral_confianza': await StorageService.getUmbralConfianza(),
    });

    // (b)+(c) Historial y guardados pendientes.
    await _subirColeccion(
      peticion,
      id,
      '/api/historial',
      await StorageService.getHistorial(),
      StorageService.marcarHistorialSincronizado,
    );
    await _subirColeccion(
      peticion,
      id,
      '/api/objetos_guardados',
      await StorageService.getGuardados(),
      StorageService.marcarGuardadosSincronizado,
    );

    // (d) Contactos, solo si cambiaron.
    if (await StorageService.getContactosPendientes()) {
      final lista = (await StorageService.getContactos())
          .map((c) => {'nombre': c.nombre, 'telefono': c.telefono})
          .toList();
      await peticion('put', '/api/contactos_apoyo/$id',
          cuerpo: {'contactos': lista});
      await StorageService.setContactosPendientes(false);
    }

    // (e) Configuración pendiente.
    if (await StorageService.getConfigPendiente()) {
      await peticion('post', '/api/configuracion', cuerpo: {
        'id_dispositivo': id,
        'elementos': [
          {'clave': 'velocidad_voz', 'valor': '${await StorageService.getSpeechRate()}'},
          {'clave': 'tono', 'valor': '${await StorageService.getPitch()}'},
          {'clave': 'volumen', 'valor': '${await StorageService.getVolume()}'},
          {'clave': 'vibracion', 'valor': '${await StorageService.getVibracion()}'},
          {'clave': 'usar_ia_nube', 'valor': '${await StorageService.getUsarIaNube()}'},
          {'clave': 'modelo_propio', 'valor': '${await StorageService.getModeloPropio()}'},
          {'clave': 'umbral_confianza', 'valor': '${await StorageService.getUmbralConfianza()}'},
        ],
      });
      await StorageService.setConfigPendiente(false);
    }

    // (f) Cola de borrados pendientes.
    for (final clave in await StorageService.getBorradosPendientes()) {
      if (clave == 'historial:*') {
        await peticion('delete', '/api/historial/$id');
      } else if (clave.startsWith('guardado:')) {
        await peticion(
          'delete',
          '/api/objetos_guardados/$id/${clave.substring(9)}',
        );
      } else {
        // Clave desconocida: se retira para no bloquear la cola.
      }
      await StorageService.quitarBorrado(clave);
    }
  }

  /// Sube los elementos con sincronizado=false y los marca al éxito.
  static Future<void> _subirColeccion(
    Future<String> Function(String, String, {Object? cuerpo}) peticion,
    String idDispositivo,
    String ruta,
    List<Resultado> todos,
    Future<void> Function(List<String>) marcar,
  ) async {
    final pendientes =
        todos.where((r) => !r.sincronizado).toList();
    if (pendientes.isEmpty) return;
    await peticion('post', ruta, cuerpo: {
      'id_dispositivo': idDispositivo,
      'elementos': pendientes
          .map((r) => {
                'id_local': r.idLocal,
                'tipo': r.tipo,
                'texto': r.texto,
                'confianza': r.confianza == 0 ? null : r.confianza,
                'uso_ia_nube': r.usoIaNube,
                'fecha_hora': DateTime.now().toIso8601String(),
              })
          .toList(),
    });
    await marcar(pendientes.map((r) => r.idLocal).toList());
  }
}

/// Error HTTP del servidor con mensaje hablable.
class EstadoHttpException implements Exception {
  final String message;
  EstadoHttpException(this.message);
  @override
  String toString() => message;
}
