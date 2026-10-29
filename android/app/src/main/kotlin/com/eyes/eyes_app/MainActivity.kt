package com.eyes.eyes_app

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService

/// Motor de reconocimiento de voz con Vosk (español, sin conexión).
///
/// Se usa en lugar del SpeechRecognizer de Google porque en este teléfono
/// falta el paquete offline de es-MX y el reconocedor de red no devuelve
/// resultados. El modelo se desempaqueta de assets una sola vez y trabaja
/// 100 % en el dispositivo.
class MainActivity : FlutterActivity() {
    private val etiqueta = "EYES voz"
    private val nombreModelo = "vosk-model-small-es-0.42"
    private val muestreo = 16000.0f

    private val manejador = Handler(Looper.getMainLooper())
    private var modelo: Model? = null
    private var reconocedor: Recognizer? = null
    private var servicio: SpeechService? = null
    private var escuchando = false
    private var cargandoModelo = false
    private var eventSink: EventChannel.EventSink? = null

    private val oyente = object : RecognitionListener {
        override fun onPartialResult(hypothesis: String?) {
            emitir("parcial", crudo = hypothesis)
        }

        override fun onResult(hypothesis: String?) {
            emitir("resultado", crudo = hypothesis)
        }

        override fun onFinalResult(hypothesis: String?) {
            escuchando = false
            emitir("final", crudo = hypothesis)
        }

        override fun onError(exception: Exception?) {
            escuchando = false
            Log.e(etiqueta, "error nativo", exception)
            emitir("error", error = exception?.message ?: "Error de reconocimiento")
        }

        override fun onTimeout() {
            escuchando = false
            emitir("timeout")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eyes/voz")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "inicializar" -> inicializar(result)
                    "escuchar" -> {
                        val timeoutMs = (call.argument<Number>("timeoutMs") ?: 10000).toInt()
                        escuchar(result, timeoutMs)
                    }
                    "parar" -> parar(result)
                    "cancelar" -> cancelar(result)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "eyes/voz/eventos")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /// Envia un evento a Dart en el hilo principal. [crudo] es el JSON que
    /// entrega Vosk ({"partial": "..."} o {"text": "..."}); Dart lo parsea.
    private fun emitir(tipo: String, crudo: String? = null, error: String? = null) {
        manejador.post {
            val mapa = mutableMapOf<String, Any?>("tipo" to tipo)
            if (crudo != null) mapa["crudo"] = crudo
            if (error != null) mapa["error"] = error
            try {
                eventSink?.success(mapa)
            } catch (e: Exception) {
                Log.w(etiqueta, "sin oyente de eventos: ${e.message}")
            }
        }
    }

    /// Desempaqueta el modelo de assets y lo carga (solo la primera vez).
    /// Puede tardar varios segundos la primera vez que abre la app.
    private fun inicializar(result: MethodChannel.Result) {
        if (modelo != null) {
            result.success(true)
            return
        }
        if (cargandoModelo) {
            result.success(false)
            return
        }
        cargandoModelo = true
        StorageService.unpack(
            applicationContext,
            nombreModelo,
            nombreModelo,
            { m ->
                modelo = m
                cargandoModelo = false
                Log.i(etiqueta, "modelo Vosk cargado")
                manejador.post { result.success(true) }
            },
            { e ->
                cargandoModelo = false
                Log.e(etiqueta, "no se pudo cargar el modelo", e)
                manejador.post {
                    result.error("VOSK", "No se pudo cargar el modelo: ${e.message}", null)
                }
            }
        )
    }

    /// Abre el microfono y empieza a reconocer. [timeoutMs] es el tope
    /// duro de la sesion; el silencio lo controla Dart con los parciales.
    private fun escuchar(result: MethodChannel.Result, timeoutMs: Int) {
        val m = modelo
        if (m == null) {
            result.error("VOSK", "El modelo de voz aun no esta listo.", null)
            return
        }
        if (escuchando) {
            result.success(false)
            return
        }
        try {
            reconocedor?.close()
            reconocedor = Recognizer(m, muestreo)
            servicio = SpeechService(reconocedor, muestreo)
            servicio?.startListening(oyente, timeoutMs)
            escuchando = true
            Log.i(etiqueta, "microfono abierto (tope ${timeoutMs} ms)")
            result.success(true)
        } catch (e: Exception) {
            escuchando = false
            Log.e(etiqueta, "no se pudo abrir el microfono", e)
            result.error("VOSK", "No se pudo abrir el microfono: ${e.message}", null)
        }
    }

    /// Cierra la escucha pidiendo el resultado final; Vosk lo entrega
    /// como evento 'resultado' por el canal de eventos.
    private fun parar(result: MethodChannel.Result) {
        try {
            servicio?.stop()
        } catch (e: Exception) {
            Log.w(etiqueta, "parar: ${e.message}")
        }
        result.success(null)
    }

    /// Cierra la escucha descartando el resultado; no emite nada mas.
    private fun cancelar(result: MethodChannel.Result) {
        try {
            servicio?.cancel()
        } catch (e: Exception) {
            Log.w(etiqueta, "cancelar: ${e.message}")
        }
        escuchando = false
        result.success(null)
    }

    override fun onDestroy() {
        try {
            servicio?.shutdown()
            servicio = null
            reconocedor?.close()
            reconocedor = null
            modelo?.close()
            modelo = null
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
