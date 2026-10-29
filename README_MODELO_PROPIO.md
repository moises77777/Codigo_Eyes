# Entrenar un modelo propio para EYES

EYES puede usar un detector de objetos entrenado con tus propias fotos
(arquitectura EfficientDet-Lite0 en formato `.tflite`). Pasos:

## 1. Reunir fotos

- Formato JPG o PNG, mínimo 640 px de lado.
- 50–100 fotos por clase, con variedad de fondos, distancias y luz.
- Las fotos no necesitan ser perfectas; la variedad importa más.

## 2. Etiquetar

Usa LabelImg, Roboflow o Label Studio:

- Dibuja una caja por objeto y asígnale su clase.
- Exporta las anotaciones en formato Pascal VOC (XML) o CSV.

## 3. Entrenar con MediaPipe Model Maker

```python
# pip install mediapipe-model-maker
from mediapipe_model_maker import object_detector

train_data = object_detector.Dataset.from_pascal_voc(
    'datos/train', 'datos/train/Annotations', 'datos/train/ImageSets/Main/train.txt')
val_data = object_detector.Dataset.from_pascal_voc(
    'datos/val', 'datos/val/Annotations', 'datos/val/ImageSets/Main/val.txt')

spec = object_detector.SupportedModels.EFFICIENTDET_LITE0
hparams = object_detector.HParams(epochs=30, batch_size=8, export_dir='salida')
options = object_detector.ObjectDetectorOptions(
    supported_model=spec, hparams=hparams)

model = object_detector.ObjectDetector.create(
    train_data=train_data, validation_data=val_data, options=options)
model.export_model('modelo.tflite')
```

## 4. Instalar el modelo en la app

1. Copia `modelo.tflite` a `assets/modelos/propio/modelo.tflite`
   (reemplazando el marcador que viene de fábrica).
2. Escribe `assets/modelos/propio/etiquetas.txt`: **una etiqueta por
   línea, en español, en el mismo orden de clases del modelo**
   (reemplaza el marcador; las líneas que empiezan con `#` son
   comentarios). Los huecos del mapa COCO pueden quedar como `???`.
3. Compila: `flutter build apk --release --dart-define-from-file=dart_defines.json`.
4. En la app: Ajustes → activa **Usar modelo propio** y sube o baja la
   **Confianza mínima para anunciar** (0.50–0.90).

Si el modelo propio no carga o las etiquetas siguen siendo el marcador,
la app cae sola al preentrenado y lo dice por voz.
