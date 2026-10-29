import { Router } from 'express';
import { baseDeDatos } from '../db.js';
import { esIdDispositivo, validarElemento } from '../validacion.js';

/// Fábrica de rutas tipo lote para historial y objetos_guardados
/// (misma forma de documento).
export function rutasLote(nombreColeccion) {
  const router = Router();

  // POST / — bulk upsert por (id_dispositivo, id_local)
  router.post('/', async (req, res) => {
    const { id_dispositivo, elementos } = req.body || {};
    if (!esIdDispositivo(id_dispositivo)) {
      return res.status(400).json({ error: 'id_dispositivo inválido.' });
    }
    if (!Array.isArray(elementos)) {
      return res.status(400).json({ error: 'elementos debe ser una lista.' });
    }
    for (const el of elementos) {
      const error = validarElemento(el);
      if (error) return res.status(400).json({ error });
    }
    const db = baseDeDatos();
    if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
    try {
      const ops = elementos.map((el) => ({
        updateOne: {
          filter: { id_dispositivo, id_local: el.id_local },
          update: {
            $set: {
              id_dispositivo,
              id_local: el.id_local,
              tipo: el.tipo,
              texto: el.texto,
              confianza: el.confianza ?? null,
              uso_ia_nube: el.uso_ia_nube ?? false,
              fecha_hora: el.fecha_hora ? new Date(el.fecha_hora) : new Date(),
              fecha_sincronizacion: new Date(),
            },
          },
          upsert: true,
        },
      }));
      const r = await db.collection(nombreColeccion).bulkWrite(ops);
      res.json({
        recibidos: elementos.length,
        insertados: r.upsertedCount,
        actualizados: r.modifiedCount,
      });
    } catch (e) {
      res.status(500).json({ error: 'No pude guardar los elementos.' });
    }
  });

  // GET /:idDispositivo?limite=30
  router.get('/:idDispositivo', async (req, res) => {
    const db = baseDeDatos();
    if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
    const limite = Math.min(parseInt(req.query.limite, 10) || 30, 500);
    try {
      const docs = await db.collection(nombreColeccion)
        .find({ id_dispositivo: req.params.idDispositivo })
        .sort({ fecha_hora: -1 })
        .limit(limite)
        .toArray();
      res.json(docs.map(({ _id, ...resto }) => resto));
    } catch (e) {
      res.status(500).json({ error: 'No pude leer los elementos.' });
    }
  });

  // DELETE /:idDispositivo — borra todo el historial del dispositivo.
  router.delete('/:idDispositivo', async (req, res) => {
    const db = baseDeDatos();
    if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
    try {
      const r = await db.collection(nombreColeccion)
        .deleteMany({ id_dispositivo: req.params.idDispositivo });
      res.json({ borrados: r.deletedCount });
    } catch (e) {
      res.status(500).json({ error: 'No pude borrar los elementos.' });
    }
  });

  return router;
}

/// Router de objetos_guardados con DELETE por id_local además.
export const objetosGuardados = (() => {
  const router = rutasLote('objetos_guardados');
  router.delete('/:idDispositivo/:idLocal', async (req, res) => {
    const db = baseDeDatos();
    if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
    try {
      const r = await db.collection('objetos_guardados').deleteOne({
        id_dispositivo: req.params.idDispositivo,
        id_local: req.params.idLocal,
      });
      res.json({ borrados: r.deletedCount });
    } catch (e) {
      res.status(500).json({ error: 'No pude borrar el objeto.' });
    }
  });
  return router;
})();
