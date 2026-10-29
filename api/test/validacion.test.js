import test from 'node:test';
import assert from 'node:assert/strict';
import {
  esCadena, esNumero, esBooleano, esIdDispositivo,
  validarElemento, validarContacto, validarParConfiguracion,
} from '../src/validacion.js';

test('esCadena y esIdDispositivo', () => {
  assert.equal(esCadena('hola'), true);
  assert.equal(esCadena(''), false);
  assert.equal(esCadena('', { vacia: true }), true);
  assert.equal(esIdDispositivo('demo-0001'), true);
  assert.equal(esIdDispositivo(''), false);
});

test('esNumero y esBooleano', () => {
  assert.equal(esNumero(0.7), true);
  assert.equal(esNumero('0.7'), false);
  assert.equal(esNumero(NaN), false);
  assert.equal(esBooleano(true), true);
  assert.equal(esBooleano('true'), false);
});

test('validarElemento acepta un elemento completo', () => {
  const error = validarElemento({
    id_local: 'abc', tipo: 'identificar', texto: 'Una taza',
    confianza: 0.8, uso_ia_nube: false, fecha_hora: new Date().toISOString(),
  });
  assert.equal(error, null);
});

test('validarElemento rechaza sin id_local', () => {
  assert.match(validarElemento({ tipo: 'x', texto: 'y' }), /id_local/);
});

test('validarElemento rechaza confianza no numérica', () => {
  assert.match(
    validarElemento({ id_local: 'a', tipo: 'x', texto: 'y', confianza: 'alta' }),
    /confianza/);
});

test('validarContacto', () => {
  assert.equal(validarContacto({ nombre: 'Ana', telefono: '55' }), null);
  assert.match(validarContacto({ telefono: '55' }), /nombre/);
  assert.match(validarContacto({ nombre: 'Ana' }), /teléfono/);
});

test('validarParConfiguracion', () => {
  assert.equal(validarParConfiguracion({ clave: 'velocidad', valor: '0.7' }), null);
  assert.match(validarParConfiguracion({ valor: '0.7' }), /clave/);
});
