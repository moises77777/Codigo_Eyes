import { Router } from 'express';
import { baseDeDatos } from '../db.js';
import { esIdDispositivo, validarContacto } from '../validacion.js';

export const contactos = Router();

contactos.put('/:idDispositivo', async (req, res) => {
  const { idDispositivo } = req.params;
  if (!esIdDispositivo(idDispositivo)) {
    return res.status(400).json({ error: 'id_dispositivo inválido.' });
  }
  const lista = req.body?.contactos;
  if (!Array.isArray(lista)) {
    return res.status(400).json({ error: 'contactos debe ser una lista.' });
  }
  for (const c of lista) {
    const error = validarContacto(c);
    if (error) return res.status(400).json({ error });
  }
  const db = baseDeDatos();
  if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
  try {
    await db.collection('contactos_apoyo')
      .deleteMany({ id_dispositivo: idDispositivo });
    if (lista.length > 0) {
      await db.collection('contactos_apoyo').insertMany(
        lista.map((c) => ({
          id_dispositivo: idDispositivo,
          nombre: c.nombre.trim(),
          telefono: c.telefono.trim(),
          fecha_registro: new Date(),
        })),
      );
    }
    res.json({ ok: true, guardados: lista.length });
  } catch (e) {
    res.status(500).json({ error: 'No pude guardar los contactos.' });
  }
});

contactos.get('/:idDispositivo', async (req, res) => {
  const db = baseDeDatos();
  if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
  try {
    const docs = await db.collection('contactos_apoyo')
      .find({ id_dispositivo: req.params.idDispositivo })
      .toArray();
    res.json(docs.map(({ _id, ...resto }) => resto));
  } catch (e) {
    res.status(500).json({ error: 'No pude leer los contactos.' });
  }
});
