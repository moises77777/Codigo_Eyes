import 'dart:convert';

import 'package:eyes_app/services/ia_nube_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  /// Configura el servicio con un MockClient que responde [status]
  /// con [cuerpo], o que tarda más que el timeout de prueba.
  void configurar({
    int status = 200,
    String? cuerpo,
    bool tardar = false,
  }) {
    IaNubeService.conexionParaPruebas = true;
    IaNubeService.apiKeyParaPruebas = 'clave-de-prueba';
    IaNubeService.modeloParaPruebas = 'modelo-de-prueba';
    IaNubeService.timeoutParaPruebas = const Duration(milliseconds: 300);
    IaNubeService.clientParaPruebas = MockClient((request) async {
      if (tardar) {
        await Future.delayed(const Duration(seconds: 2));
      }
      return http.Response(
        cuerpo ??
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'Respuesta de prueba'},
              ],
            }),
        status,
      );
    });
  }

  tearDown(() {
    IaNubeService.clientParaPruebas = null;
    IaNubeService.timeoutParaPruebas = null;
    IaNubeService.apiKeyParaPruebas = null;
    IaNubeService.modeloParaPruebas = null;
    IaNubeService.conexionParaPruebas = null;
  });

  test('respuesta 200 devuelve el texto del contenido', () async {
    configurar();
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isTrue);
    expect(r.texto, 'Respuesta de prueba');
  });

  test('concatena varias partes de texto', () async {
    configurar(
      cuerpo: jsonEncode({
        'content': [
          {'type': 'text', 'text': 'Primera parte.'},
          {'type': 'text', 'text': 'Segunda parte.'},
        ],
      }),
    );
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isTrue);
    expect(r.texto, 'Primera parte. Segunda parte.');
  });

  test('401 devuelve mensaje de clave inválida', () async {
    configurar(status: 401, cuerpo: '{"error":{}}');
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isFalse);
    expect(r.error, contains('no es válida'));
  });

  test('429 devuelve mensaje de límite', () async {
    configurar(status: 429, cuerpo: '{"error":{}}');
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isFalse);
    expect(r.error, contains('límite'));
  });

  test('timeout devuelve mensaje de demora', () async {
    configurar(tardar: true);
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isFalse);
    expect(r.error, contains('tardó demasiado'));
  });

  test('sin clave devuelve mensaje de configurar', () async {
    configurar();
    IaNubeService.apiKeyParaPruebas = '';
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isFalse);
    expect(r.error, contains('No hay clave'));
  });

  test('sin conexión devuelve mensaje local', () async {
    configurar();
    IaNubeService.conexionParaPruebas = false;
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isFalse);
    expect(r.error, contains('No hay conexión'));
  });

  test('402 por saldo devuelve mensaje de billing', () async {
    configurar(status: 402, cuerpo: '{"error":{"type":"billing_error"}}');
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isFalse);
    expect(r.error, contains('saldo'));
  });

  test('404 devuelve mensaje de modelo inexistente', () async {
    configurar(status: 404, cuerpo: '{"error":{"type":"not_found"}}');
    final r = await IaNubeService.conversar('hola');
    expect(r.ok, isFalse);
    expect(r.error, contains('modelo'));
  });
}
