# EYES — Asistente visual con Flutter

EYES es una aplicación Android pensada para personas con discapacidad visual. Permite identificar objetos, leer texto en voz alta, describir escenas y responder preguntas sobre lo que ve la cámara, todo controlado por voz y con una interfaz de alto contraste.

## Instalar el APK (para probar sin compilar)

1. Descarga `app-release.apk` desde la sección **Releases** de este repositorio
   (el archivo pesa ~187 MB porque incluye el modelo de voz en español sin conexión).
2. En el teléfono Android: Ajustes → Seguridad → permitir **instalar apps de origen desconocido**.
3. Abre el APK e instala. Al primer arranque concede permisos de **cámara** y **micrófono**.
4. La app funciona sin internet (voz, objetos, texto, colores, billetes). Con internet
   además describe escenas con IA y sincroniza el historial.

## Características

- Identificación de objetos en tiempo real con TensorFlow Lite (EfficientDet-Lite0, 90 clases COCO), 100 % en el teléfono.
- Reconocimiento de voz en español **sin conexión** con Vosk (no depende de los servicios de Google).
- OCR local para leer documentos y etiquetas.
- Descripción de escenas y preguntas sobre la imagen con una IA en la nube (API de mensajes de Anthropic, modo híbrido).
- Identificación de billetes mexicanos y color dominante.
- Control total por voz con escucha continua y comandos en español de México.
- Historial de resultados y lista de objetos guardados, con sincronización a MongoDB Atlas vía la API de `api/`.
- Tema oscuro de alto contraste compatible con TalkBack.
- Ajustes de velocidad y tono de voz, escucha continua, IA en la nube y clave API.

## Tecnologías

- Flutter 3.47+ / Dart 3.13+
- `camera` — vista previa, stream de frames y captura.
- `tflite_flutter` — detector EfficientDet-Lite0 (`assets/modelos/preentrenado`).
- Vosk Android (`com.alphacephei:vosk-android`) — reconocimiento de voz offline (`android/app/src/main/assets/vosk-model-small-es-0.42`).
- `google_mlkit_text_recognition` — OCR.
- `flutter_tts` — síntesis de voz.
- `permission_handler` — permisos de cámara y micrófono.
- `shared_preferences` — datos persistentes.
- `http` — llamadas REST a la API de Anthropic.
- `connectivity_plus` — estado de la conexión.
- `provider` — gestión de estado.

## Estructura

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── app_config.dart
│   └── theme.dart
├── models/
│   └── resultado.dart
├── services/
│   ├── camera_service.dart
│   ├── vision_service.dart
│   ├── ocr_service.dart
│   ├── ia_nube_service.dart
│   ├── billetes_service.dart
│   ├── color_service.dart
│   ├── voice_input_service.dart
│   ├── tts_service.dart
│   ├── storage_service.dart
│   ├── command_parser.dart
│   └── permission_service.dart
├── controllers/
│   └── eyes_controller.dart
├── utils/
│   └── traducciones.dart
├── screens/
│   ├── bienvenida_screen.dart
│   ├── home_screen.dart
│   ├── historial_screen.dart
│   ├── guardados_screen.dart
│   └── ajustes_screen.dart
└── widgets/
    ├── boton_grande.dart
    ├── panel_estado.dart
    ├── marco_enfoque.dart
    └── boton_microfono.dart
```

## Obtener la API key de Anthropic

1. Entra a https://console.anthropic.com/
2. Inicia sesión con tu cuenta.
3. Crea una nueva API key y cópiala.

La clave se puede proporcionar de dos formas:

- **En tiempo de compilación** con un archivo de defines (recomendado):
  ```json
  // dart_defines.json (está en .gitignore, no se sube al repo)
  {
    "ANTHROPIC_API_KEY": "TU_CLAVE",
    "ANTHROPIC_MODEL": "claude-sonnet-5-5"
  }
  ```
  ```bash
  flutter run --dart-define-from-file=dart_defines.json
  flutter build apk --release --dart-define-from-file=dart_defines.json
  ```
- **En la app**: ve a Ajustes → Clave de la IA en la nube, pega la clave y guarda. Esta opción tiene prioridad sobre la de compilación.

## Ejecutar en desarrollo

```bash
flutter pub get
cp dart_defines.example.json dart_defines.json   # y llena las claves
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` no se sube al repositorio (contiene claves). Sin claves la app
funciona igual en modo sin conexión; solo se desactivan la IA en la nube y la sincronización.

## Compilar APK de producción

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
```

El APK queda en:

```
build/app/outputs/flutter-apk/app-release.apk
```

## Nube (MongoDB)

La app puede respaldar ajustes, historial, objetos guardados y contactos
en la API de la carpeta `api/` (Node.js + Express + MongoDB Atlas).
Para levantarla: `cd api && cp .env.example .env` (llena `MONGODB_URI` y `API_KEY`),
`npm install && npm start`.

- **Variables de compilación** en `dart_defines.json` (sin valores reales):
  ```json
  { "EYES_API_URL": "http://192.168.1.10:3000", "EYES_API_KEY": "tu-clave" }
  ```
- **En la app**: Ajustes → Nube → URL del servidor y clave (tienen
  prioridad sobre las variables de compilación). El botón
  'Sincronizar ahora' o decir **"sincronizar"** sube lo pendiente.
- Para probar en local, corre la API en la laptop y usa la IP de la red
  (p. ej. `http://192.168.1.10:3000`); el manifest permite HTTP plano
  solo para esta demo en red local.
- Más detalles en [api/README.md](api/README.md).

## Modelo propio de detección

Para entrenar un detector con tus propias clases, sigue
[README_MODELO_PROPIO.md](README_MODELO_PROPIO.md).

## Comandos de voz

| Comando | Acción |
|---|---|
| "qué es esto", "identifica", "qué tengo enfrente" | Identifica el objeto |
| "describe", "describe la escena", "dónde estoy" | Describe la escena (IA en la nube) |
| "lee el texto", "lee", "qué dice" | Lee texto con OCR |
| "resume" | Lee y resume un texto largo (IA en la nube) |
| "pregunta …", "cuánto…", "de qué color…" | Pregunta sobre la imagen (IA en la nube) |
| "guarda esto" | Guarda el último resultado |
| "repetir", "repite" | Repite el último resultado |
| "historial" | Abre y lee el historial |
| "guardados", "mis cosas" | Abre y lee los guardados |
| "borrar historial" | Pide confirmación y borra |
| "detección continua", "modo automático" | Activa detección cada 5 s |
| "detener", "para", "alto" | Detiene todo |
| "más rápido" / "más lento" | Ajusta velocidad de voz |
| "mi nombre es X" / "llámame X" | Cambia el nombre |
| "hora" / "qué hora es" | Dice fecha y hora |
| "ayuda" | Explica los comandos |
| "regresar", "inicio" | Vuelve a la pantalla principal |
| "deja de escuchar" | Desactiva la escucha continua |

## Notas de privacidad

- Las fotos solo se envían a la IA en la nube si el usuario activa "Usar IA en la nube" y acepta el aviso en la bienvenida.
- Las imágenes no se guardan en el dispositivo ni en ningún servidor por parte de EYES.
- Sin conexión a internet o sin clave, la app funciona por completo con ML Kit local.
