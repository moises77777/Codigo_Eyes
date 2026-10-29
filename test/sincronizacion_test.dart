import 'package:eyes_app/models/resultado.dart';
import 'package:eyes_app/services/sincronizacion_service.dart';
import 'package:eyes_app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Reinicia el servicio y las preferencias entre pruebas.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    SincronizacionService.clientParaPruebas = null;
    SincronizacionService.conexionParaPruebas = true;
    SincronizacionService.esperasParaPruebas =
        const [Duration(milliseconds: 1), Duration(milliseconds: 1)];
    SincronizacionService.ultimaSincronizacion = null;
    SincronizacionService.ultimoError = null;
  });

  tearDown(() {
    SincronizacionService.clientParaPruebas = null;
    SincronizacionService.conexionParaPruebas = null;
    SincronizacionService.esperasParaPruebas = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];
  });

  test('sin URL no hace peticiones y los pendientes se mantienen', () async {
    var llamadas = 0;
    SincronizacionService.clientParaPruebas = MockClient((req) async {
      llamadas++;
      return http.Response('{"ok":true}', 200);
    });
    await StorageService.agregarHistorial(
      Resultado.ahora(tipo: 'identificar', texto: 'Una taza'),
    );
    final ok = await SincronizacionService.sincronizarPendientes();
    expect(ok, isFalse);
    expect(llamadas, 0);
    expect(await SincronizacionService.pendientes(), 1);
  });

  test('con URL y 200 marca sincronizado y pendientes 0', () async {
    SincronizacionService.clientParaPruebas = MockClient((req) async {
      return http.Response('{"ok":true}', 200);
    });
    await StorageService.setApiUrl('http://servidor.local:3000');
    await StorageService.agregarHistorial(
      Resultado.ahora(tipo: 'color', texto: 'Es azul.'),
    );
    final ok = await SincronizacionService.sincronizarPendientes();
    expect(ok, isTrue);
    expect(await SincronizacionService.pendientes(), 0);
    expect(SincronizacionService.ultimaSincronizacion, isNotNull);
    expect(
      (await StorageService.getHistorial()).first.sincronizado,
      isTrue,
    );
  });

  test('con 500 reintenta y queda pendiente con error', () async {
    var llamadas = 0;
    SincronizacionService.clientParaPruebas = MockClient((req) async {
      llamadas++;
      return http.Response('{"error":"fallo"}', 500);
    });
    await StorageService.setApiUrl('http://servidor.local:3000');
    await StorageService.agregarHistorial(
      Resultado.ahora(tipo: 'ocr', texto: 'Texto leído'),
    );
    final ok = await SincronizacionService.sincronizarPendientes();
    expect(ok, isFalse);
    expect(llamadas, greaterThanOrEqualTo(2)); // reintentos
    expect(SincronizacionService.ultimoError, isNotNull);
    expect(await SincronizacionService.pendientes(), greaterThan(0));
  });

  test('idDispositivo es estable entre llamadas', () async {
    final a = await StorageService.getIdDispositivo();
    final b = await StorageService.getIdDispositivo();
    expect(a, b);
    expect(a.length, 36); // formato uuid v4
  });

  test('Resultado viejo sin idLocal se carga con uno generado', () {
    final r = Resultado.fromJson({
      'id': '123',
      'tipo': 'identificar',
      'texto': 'Taza',
      'fecha': '01/01/2025',
      'hora': '10:00',
      'confianza': 0.8,
      'usoIaNube': false,
    });
    expect(r.idLocal.length, 36);
    expect(r.sincronizado, isFalse);
    final idaYVuelta = Resultado.fromJson(r.toJson());
    expect(idaYVuelta.idLocal, r.idLocal);
  });
}
