import { Router } from 'express';
import { baseDeDatos } from '../db.js';
import { esIdDispositivo, validarParConfiguracion } from '../validacion.js';

export const configuracion = Router();

configuracion.post('/', async (req, res) => {
  const { id_dispositivo, elementos } = req.body || {};
  if (!esIdDispositivo(id_dispositivo)) {
    return res.status(400).json({ error: 'id_dispositivo inválido.' });
  }
  if (!Array.isArray(elementos)) {
    return res.status(400).json({ error: 'elementos debe ser una lista.' });
  }
  for (const p of elementos) {
    const error = validarParConfiguracion(p);
    if (error) return res.status(400).json({ error });
  }
  const db = baseDeDatos();
  if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
  try {
    const ops = elementos.map((p) => ({
      updateOne: {
        filter: { id_dispositivo, clave: p.clave },
        update: {
          $set: {
            id_dispositivo,
            clave: p.clave,
            valor: p.valor,
            fecha_actualizacion: new Date(),
          },
        },
        upsert: true,
      },
    }));
    const r = await db.collection('configuracion').bulkWrite(ops);
    res.json({
      recibidos: elementos.length,
      insertados: r.upsertedCount,
      actualizados: r.modifiedCount,
    });
  } catch (e) {
    res.status(500).json({ error: 'No pude guardar la configuración.' });
  }
});

configuracion.get('/:idDispositivo', async (req, res) => {
  const db = baseDeDatos();
  if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
  try {
    const docs = await db.collection('configuracion')
      .find({ id_dispositivo: req.params.idDispositivo })
      .toArray();
    res.json(docs.map(({ _id, ...resto }) => resto));
  } catch (e) {
    res.status(500).json({ error: 'No pude leer la configuración.' });
  }
});
