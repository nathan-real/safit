package fr.ensc.safit.camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Pont avec Flutter.
 *
 * - `safit/highspeed` (méthodes) : start, stop, setRoi, setExposureLocked, outputDirectory.
 * - `safit/highspeed/samples` (flux) : toutes les ~50 ms, un lot
 *   `{t: horodatages ns, y: luminosités 0..1, sensorFrames: images sorties du capteur}`.
 */
class HighSpeedCameraPlugin(private val activity: Activity, engine: FlutterEngine) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val textures = engine.renderer
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private var camera: HighSpeedCamera? = null
    private var analyzer: RoiAnalyzer? = null
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var pendingStart: Pair<MethodCall, MethodChannel.Result>? = null

    // Échantillons en attente d'envoi (écrits par le thread GL, lus par le thread principal).
    private val lock = Any()
    private var times = LongArray(1024)
    private var lumas = FloatArray(1024)
    private var count = 0

    private val flushTask = object : Runnable {
        override fun run() {
            flush()
            mainHandler.postDelayed(this, FLUSH_INTERVAL_MS)
        }
    }

    init {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "safit/highspeed").setMethodCallHandler(this)
        EventChannel(messenger, "safit/highspeed/samples").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                if (activity.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                    start(call, result)
                } else {
                    pendingStart = call to result
                    activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), PERMISSION_REQUEST)
                }
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            "setRoi" -> {
                val r = call.arguments<List<Double>>()!!
                analyzer?.setRoi(r[0].toFloat(), r[1].toFloat(), r[2].toFloat(), r[3].toFloat())
                result.success(null)
            }
            "setExposureLocked" -> {
                camera?.setExposureLocked(call.arguments<Boolean>() == true)
                result.success(null)
            }
            "outputDirectory" -> result.success(activity.getExternalFilesDir(null)?.absolutePath)
            else -> result.notImplemented()
        }
    }

    /** À appeler depuis MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        val (call, result) = pendingStart ?: return
        pendingStart = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            start(call, result)
        } else {
            result.error("permission", "Permission caméra refusée", null)
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        stop()
        var answered = false
        fun fail(message: String) = mainHandler.post {
            stop()
            if (!answered) {
                answered = true
                result.error("camera", message, null)
            } else {
                sink?.error("camera", message, null)
            }
        }

        try {
            val cam = HighSpeedCamera(activity)
            val config = cam.selectConfig()

            // L'aperçu est affiché en portrait : on échange largeur et hauteur si le
            // capteur est tourné, et on le réduit (côté long = 640 px).
            val rotated = config.sensorOrientation % 180 != 0
            val w = if (rotated) config.size.height else config.size.width
            val h = if (rotated) config.size.width else config.size.height
            val scale = PREVIEW_LONG_SIDE.toFloat() / max(w, h)
            val previewW = (w * scale).roundToInt()
            val previewH = (h * scale).roundToInt()

            val an = RoiAnalyzer(config.size.width, config.size.height, config.sensorOrientation, ::addSample)
            an.start()
            call.argument<List<Double>>("roi")?.let {
                an.setRoi(it[0].toFloat(), it[1].toFloat(), it[2].toFloat(), it[3].toFloat())
            }

            val prod = textures.createSurfaceProducer()
            prod.setSize(previewW, previewH)
            prod.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
                override fun onSurfaceAvailable() = an.setPreviewSurface(prod.surface, previewW, previewH)
                override fun onSurfaceCleanup() = an.setPreviewSurface(null, 0, 0)
            })
            an.setPreviewSurface(prod.surface, previewW, previewH)

            camera = cam
            analyzer = an
            producer = prod
            synchronized(lock) { count = 0 }

            cam.open(config, an.inputSurface, onReady = {
                mainHandler.post {
                    mainHandler.post(flushTask)
                    if (!answered) {
                        answered = true
                        result.success(
                            mapOf(
                                "textureId" to prod.id(),
                                "previewWidth" to previewW,
                                "previewHeight" to previewH,
                                "captureWidth" to config.size.width,
                                "captureHeight" to config.size.height,
                                "fps" to config.fps,
                                "highSpeed" to config.highSpeed,
                                "cameraId" to config.cameraId,
                                "sensorOrientation" to config.sensorOrientation,
                                "highSpeedOptions" to config.highSpeedOptions,
                            ),
                        )
                    }
                }
            }, onError = { fail(it) })
        } catch (e: Exception) {
            fail(e.message ?: e.toString())
        }
    }

    fun stop() {
        mainHandler.removeCallbacks(flushTask)
        camera?.close()
        camera = null
        analyzer?.release()
        analyzer = null
        producer?.release()
        producer = null
    }

    private fun addSample(timestampNs: Long, luma: Float) {
        synchronized(lock) {
            if (count == times.size) {
                times = times.copyOf(count * 2)
                lumas = lumas.copyOf(count * 2)
            }
            times[count] = timestampNs
            lumas[count] = luma
            count++
        }
    }

    private fun flush() {
        val t: LongArray
        val y: FloatArray
        synchronized(lock) {
            t = times.copyOf(count)
            y = lumas.copyOf(count)
            count = 0
        }
        if (t.isEmpty()) return
        sink?.success(
            mapOf("t" to t, "y" to y, "sensorFrames" to (camera?.sensorFrames?.get() ?: 0L)),
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    companion object {
        private const val PERMISSION_REQUEST = 4201
        private const val FLUSH_INTERVAL_MS = 50L
        private const val PREVIEW_LONG_SIDE = 640
    }
}
