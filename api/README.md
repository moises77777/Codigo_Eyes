# EYES API — sincronización con MongoDB

API REST en Node.js + Express que respalda los datos de la app EYES
(ajustes, historial, objetos guardados, contactos de apoyo) en MongoDB,
agrupados por `id_dispositivo`.

## Instalar

```bash
cd EYES_api
npm install
```

## Configurar

Copia `.env.example` a `.env` y rellena:

```
MONGODB_URI=mongodb+srv://usuario:clave@cluster.mongodb.net/   (Atlas)
MONGODB_DB=eyes
PUERTO=3000
API_KEY=una-clave-cualquiera
```

Si `MONGODB_URI` está vacío la API arranca igual y `/api/salud` responde
`baseDatos: "sin conexión"`. Si `API_KEY` está vacío no se exige clave
(se avisa por consola); si tiene valor, todas las rutas piden el header
`x-api-key`.

## Correr

```bash
npm start          # producción
npm run dev        # con recarga automática
npm run semilla    # datos de ejemplo del dispositivo 'demo-0001'
npm test           # pruebas de validación (sin Mongo)
```

## Probar con curl

```bash
curl http://localhost:3000/api/salud
curl -X PUT http://localhost:3000/api/usuarios/demo-0001 \
  -H "x-api-key: TU_CLAVE" -H "content-type: application/json" \
  -d '{"nombre":"María","velocidad_voz":0.55}'
curl http://localhost:3000/api/historial/demo-0001?limite=5 \
  -H "x-api-key: TU_CLAVE"
```

## Exponer en la red local (teléfono ↔ laptop)

1. Deja corriendo `npm start` (escucha en `0.0.0.0:3000`).
2. Obtén la IP de la laptop: `ipconfig` → IPv4, p. ej. `192.168.1.10`.
3. En la app: Ajustes → Nube → URL del servidor =
   `http://192.168.1.10:3000` y la misma clave del `.env`.
4. Si no conecta, abre el puerto 3000 en el firewall de Windows.

## Alternativa gratuita: Render.com

1. Sube esta carpeta a un repo de GitHub.
2. En https://render.com → New → Web Service → conecta el repo.
3. Build Command: `npm install`; Start Command: `npm start`.
4. En Environment agrega `MONGODB_URI`, `MONGODB_DB` y `API_KEY`.
5. Render te da una URL `https://eyes-api.onrender.com`: úsala en la
   app como URL del servidor (con HTTPS no hace falta cleartext).
   Nota: el plan gratis se duerme tras 15 min sin uso; la primera
   petición tarda unos segundos en despertarlo.
