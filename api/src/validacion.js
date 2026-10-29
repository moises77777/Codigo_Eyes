/// Funciones puras de validación (testeables sin Mongo).

export function esCadena(v, { vacia = false } = {}) {
  return typeof v === 'string' && (vacia || v.trim().length > 0);
}

export function esNumero(v) {
  return typeof v === 'number' && Number.isFinite(v);
}

export function esBooleano(v) {
  return typeof v === 'boolean';
}

export function esIdDispositivo(v) {
  return esCadena(v) && v.length <= 128;
}

/// Valida un elemento del historial / objetos guardados.
export function validarElemento(el) {
  if (typeof el !== 'object' || el === null) {
    return 'Cada elemento debe ser un objeto.';
  }
  if (!esCadena(el.id_local)) return 'Falta id_local (texto no vacío).';
  if (!esCadena(el.tipo)) return 'Falta tipo (texto no vacío).';
  if (!esCadena(el.texto)) return 'Falta texto (texto no vacío).';
  if (el.confianza != null && !esNumero(el.confianza)) {
    return 'confianza debe ser número o null.';
  }
  if (el.uso_ia_nube != null && !esBooleano(el.uso_ia_nube)) {
    return 'uso_ia_nube debe ser booleano.';
  }
  if (el.fecha_hora != null && isNaN(Date.parse(el.fecha_hora))) {
    return 'fecha_hora debe ser una fecha válida.';
  }
  return null;
}

export function validarContacto(c) {
  if (typeof c !== 'object' || c === null) return 'Cada contacto debe ser un objeto.';
  if (!esCadena(c.nombre)) return 'El nombre del contacto es obligatorio.';
  if (!esCadena(c.telefono)) return 'El teléfono del contacto es obligatorio.';
  return null;
}

export function validarParConfiguracion(p) {
  if (typeof p !== 'object' || p === null) return 'Cada configuración debe ser un objeto.';
  if (!esCadena(p.clave)) return 'La clave de configuración es obligatoria.';
  if (!esCadena(p.valor, { vacia: true })) return 'El valor de configuración debe ser texto.';
  return null;
}
