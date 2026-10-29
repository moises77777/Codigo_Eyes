import 'dotenv/config';
import { MongoClient } from 'mongodb';

const uri = process.env.MONGODB_URI;
if (!uri) {
  console.log('Define MONGODB_URI en .env para correr la semilla.');
  process.exit(1);
}

const cliente = new MongoClient(uri);
await cliente.connect();
const db = cliente.db(process.env.MONGODB_DB || 'eyes');
const ID = 'demo-0001';
const ahora = new Date();

await db.collection('usuarios').updateOne(
  { id_dispositivo: ID },
  {
    $set: {
      nombre: 'María', velocidad_voz: 0.55, tono: 1.0, volumen: 0.8,
      vibracion: true, usar_ia_nube: true, acepto_ia_nube: true,
      modelo_propio: false, umbral_confianza: 0.7,
      fecha_actualizacion: ahora,
    },
    $setOnInsert: { id_dispositivo: ID, fecha_registro: ahora },
  },
  { upsert: true },
);

const historial = [
  { tipo: 'identificar', texto: 'Es una taza, con 82 por ciento de confianza.', confianza: 0.82 },
  { tipo: 'ocr', texto: 'El texto dice: lácteos, leche entera, un litro.', confianza: null },
  { tipo: 'describir', texto: 'Una cocina con mesa, sillas y una ventana.', confianza: null, uso_ia_nube: true },
  { tipo: 'pregunta', texto: 'Hay dos personas en la foto.', confianza: null, uso_ia_nube: true },
  { tipo: 'billete', texto: 'Es un billete de 100 pesos.', confianza: null },
  { tipo: 'color', texto: 'El color principal es azul.', confianza: null },
  { tipo: 'tiempo_real', texto: 'silla, 78 por ciento.', confianza: 0.78 },
  { tipo: 'conversar', texto: 'Hoy es martes por la mañana.', confianza: null, uso_ia_nube: true },
];
for (const [i, h] of historial.entries()) {
  await db.collection('historial').updateOne(
    { id_dispositivo: ID, id_local: `semilla-hist-${i}` },
    {
      $set: {
        tipo: h.tipo, texto: h.texto, confianza: h.confianza,
        uso_ia_nube: h.uso_ia_nube ?? false,
        fecha_hora: new Date(ahora.getTime() - i * 60000),
        fecha_sincronizacion: ahora,
      },
    },
    { upsert: true },
  );
}

const guardados = [
  { id: 'semilla-gua-1', tipo: 'identificar', texto: 'Es una botella, con 90 por ciento de confianza.', confianza: 0.9 },
  { id: 'semilla-gua-2', tipo: 'color', texto: 'El color principal es verde.', confianza: null },
  { id: 'semilla-gua-3', tipo: 'billete', texto: 'Es un billete de 50 pesos.', confianza: null },
];
for (const g of guardados) {
  await db.collection('objetos_guardados').updateOne(
    { id_dispositivo: ID, id_local: g.id },
    {
      $set: {
        tipo: g.tipo, texto: g.texto, confianza: g.confianza,
        uso_ia_nube: false, fecha_hora: ahora, fecha_sincronizacion: ahora,
      },
    },
    { upsert: true },
  );
}

for (const c of [
  { nombre: 'Juan', telefono: '5512345678' },
  { nombre: 'Ana', telefono: '5522334455' },
]) {
  await db.collection('contactos_apoyo').updateOne(
    { id_dispositivo: ID, nombre: c.nombre },
    { $set: { telefono: c.telefono }, $setOnInsert: { fecha_registro: ahora } },
    { upsert: true },
  );
}

for (const p of [
  { clave: 'velocidad_voz', valor: '0.55' },
  { clave: 'volumen', valor: '0.8' },
  { clave: 'vibracion', valor: 'true' },
  { clave: 'umbral_confianza', valor: '0.7' },
]) {
  await db.collection('configuracion').updateOne(
    { id_dispositivo: ID, clave: p.clave },
    { $set: { valor: p.valor, fecha_actualizacion: ahora } },
    { upsert: true },
  );
}

for (const col of ['usuarios', 'historial', 'objetos_guardados', 'contactos_apoyo', 'configuracion']) {
  const n = await db.collection(col).countDocuments({ id_dispositivo: ID });
  console.log(`${col}: ${n} documentos de '${ID}'`);
}
await cliente.close();
console.log('Semilla lista.');
