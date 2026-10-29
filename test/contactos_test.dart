import 'package:eyes_app/models/contacto_apoyo.dart';
import 'package:eyes_app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('normalizarTelefono', () {
    test('convierte palabras a dígitos', () {
      expect(
        ContactoApoyo.normalizarTelefono(
          'cinco cinco uno dos tres cuatro cinco seis siete ocho',
        ),
        '5512345678',
      );
    });

    test('quita guiones y signos', () {
      expect(ContactoApoyo.normalizarTelefono('55-1234-5678'), '5512345678');
      expect(ContactoApoyo.normalizarTelefono('(55) 1234 5678'), '5512345678');
    });

    test('mezcla dígitos y palabras', () {
      expect(
        ContactoApoyo.normalizarTelefono('55 cinco dos 34'),
        '555234',
      );
    });

    test('texto sin dígitos devuelve vacío', () {
      expect(ContactoApoyo.normalizarTelefono('hola'), '');
    });
  });

  group('ContactoApoyo json', () {
    test('toJson y fromJson conservan los datos', () {
      const c = ContactoApoyo(nombre: 'Mamá', telefono: '5512345678');
      final copia = ContactoApoyo.fromJson(c.toJson());
      expect(copia.nombre, 'Mamá');
      expect(copia.telefono, '5512345678');
    });
  });

  group('StorageService contactos', () {
    test('guarda y lee la lista de contactos', () async {
      SharedPreferences.setMockInitialValues({});
      const contactos = [
        ContactoApoyo(nombre: 'Mamá', telefono: '5512345678'),
        ContactoApoyo(nombre: 'Juan', telefono: '5587654321'),
      ];
      await StorageService.setContactos(contactos);
      final leidos = await StorageService.getContactos();
      expect(leidos.length, 2);
      expect(leidos[0].nombre, 'Mamá');
      expect(leidos[1].telefono, '5587654321');
    });

    test('sin contactos devuelve lista vacía', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StorageService.getContactos(), isEmpty);
    });
  });
}
