import { Router } from 'express';
import { baseDeDatos } from '../db.js';
import { esCadena, esNumero, esBooleano, esIdDispositivo } from '../validacion.js';

export const usuarios = Router();

const CAMPOS = {
  nombre: esCadena,
  velocidad_voz: esNumero,
  tono: esNumero,
  volumen: esNumero,
  vibracion: esBooleano,
  usar_ia_nube: esBooleano,
  acepto_ia_nube: esBooleano,
  modelo_propio: esBooleano,
  umbral_confianza: esNumero,
};

function docSinId(doc) {
  if (!doc) return null;
  const { _id, ...resto } = doc;
  return resto;
}

usuarios.put('/:idDispositivo', async (req, res) => {
  const { idDispositivo } = req.params;
  if (!esIdDispositivo(idDispositivo)) {
    return res.status(400).json({ error: 'id_dispositivo inválido.' });
  }
  const cuerpo = req.body || {};
  const datos = { id_dispositivo: idDispositivo };
  for (const [campo, valida] of Object.entries(CAMPOS)) {
    if (cuerpo[campo] != null) {
      if (!valida(cuerpo[campo])) {
        return res.status(400).json({ error: `Campo ${campo} inválido.` });
      }
      datos[campo] = cuerpo[campo];
    }
  }
  const db = baseDeDatos();
  if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
  try {
    await db.collection('usuarios').updateOne(
      { id_dispositivo: idDispositivo },
      {
        $set: { ...datos, fecha_actualizacion: new Date() },
        $setOnInsert: { fecha_registro: new Date() },
      },
      { upsert: true },
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'No pude guardar el usuario.' });
  }
});

usuarios.get('/:idDispositivo', async (req, res) => {
  const db = baseDeDatos();
  if (!db) return res.status(503).json({ error: 'Sin conexión a la base de datos.' });
  try {
    const doc = await db.collection('usuarios')
      .findOne({ id_dispositivo: req.params.idDispositivo });
    res.json(docSinId(doc) || {});
  } catch (e) {
    res.status(500).json({ error: 'No pude leer el usuario.' });
  }
});
