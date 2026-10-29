import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import { conectar, baseDeDatos } from './db.js';
import { usuarios } from './rutas/usuarios.js';
import { rutasLote, objetosGuardados } from './rutas/lotes.js';
import { contactos } from './rutas/contactos.js';
import { configuracion } from './rutas/configuracion.js';

const app = express();
const PUERTO = parseInt(process.env.PUERTO, 10) || 3000;
const API_KEY = process.env.API_KEY || '';

app.use(cors());
app.use(express.json({ limit: '2mb' }));

// Si API_KEY está configurada se exige el header x-api-key; si está
// vacía, todo pasa y se avisa una vez por consola.
if (!API_KEY) {
  console.log('[EYES api] AVISO: API_KEY vacía, la API queda abierta.');
}
app.use('/api', (req, res, next) => {
  if (!API_KEY) return next();
  if (req.headers['x-api-key'] !== API_KEY) {
    return res.status(401).json({ error: 'Clave de API incorrecta.' });
  }
  next();
});

app.get('/api/salud', (req, res) => {
  res.json({ ok: true, baseDatos: baseDeDatos() ? 'conectada' : 'sin conexión' });
});

app.use('/api/usuarios', usuarios);
app.use('/api/historial', rutasLote('historial'));
app.use('/api/objetos_guardados', objetosGuardados);
app.use('/api/contactos_apoyo', contactos);
app.use('/api/configuracion', configuracion);

app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada.' });
});

app.use((err, req, res, next) => {
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'El cuerpo excede 2 MB.' });
  }
  if (err instanceof SyntaxError) {
    return res.status(400).json({ error: 'JSON inválido.' });
  }
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor.' });
});

try {
  await conectar();
} catch (e) {
  console.error('[EYES api] No conectó a MongoDB:', e.message);
  console.log('[EYES api] Sigo arrancando sin base de datos.');
}

app.listen(PUERTO, () => {
  console.log(`[EYES api] Escuchando en http://0.0.0.0:${PUERTO}`);
});
