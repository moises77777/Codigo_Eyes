import { MongoClient } from 'mongodb';

let cliente = null;
let db = null;

/// Conecta a MongoDB solo si hay URI; si no, arranca igual
/// y las rutas responden con error legible en español.
export async function conectar() {
  const uri = process.env.MONGODB_URI || '';
  const nombre = process.env.MONGODB_DB || 'eyes';
  if (!uri.trim()) {
    console.log('[EYES api] MONGODB_URI vacío: arranco sin base de datos.');
    return null;
  }
  cliente = new MongoClient(uri, { serverSelectionTimeoutMS: 8000 });
  await cliente.connect();
  db = cliente.db(nombre);
  await crearIndices(db);
  console.log(`[EYES api] Conectado a MongoDB, base '${nombre}'.`);
  return db;
}

export function baseDeDatos() {
  return db;
}

/// Índices y unicidad de cada colección.
async function crearIndices(db) {
  await db.collection('usuarios').createIndex({ id_dispositivo: 1 }, { unique: true });
  await db.collection('historial').createIndex(
    { id_dispositivo: 1, id_local: 1 }, { unique: true });
  await db.collection('historial').createIndex({ id_dispositivo: 1, fecha_hora: -1 });
  await db.collection('objetos_guardados').createIndex(
    { id_dispositivo: 1, id_local: 1 }, { unique: true });
  await db.collection('contactos_apoyo').createIndex(
    { id_dispositivo: 1, nombre: 1 }, { unique: true });
  await db.collection('configuracion').createIndex(
    { id_dispositivo: 1, clave: 1 }, { unique: true });
}
