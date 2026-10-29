package fr.ensc.safit.camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Pont avec Flutter.
 *
 * - `safit/highspeed` (méthodes) : start, stop, setRoi, setExposureLocked, describe,
 *   loadRoi, saveRoi (zone de détection mémorisée sur le téléphone),
 *   startRecording, stopRecording, outputDirectory.
 * - `safit/highspeed/samples` (flux) : toutes les ~50 ms, un lot
 *   `{t: horodatages ns, y: luminosités 0..1, sensorFrames: images sorties du capteur,
 *   encodedFrames: images vidéo encodées, lastEncodedNs: heure de la dernière image vidéo}`.
 */
class HighSpeedCameraPlugin(private val activity: Activity, engine: FlutterEngine) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val textures = engine.renderer
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private var camera: HighSpeedCamera? = null
    private var pipeline: VideoPipeline? = null
    private var previewTexture: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var pendingStart: Pair<MethodCall, MethodChannel.Result>? = null

    // Échantillons en attente d'envoi (écrits par le thread décodeur, lus par le thread principal).
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
            "stop" -> stop { result.success(null) }
            "setRoi" -> {
                val r = call.arguments<List<Double>>()!!
                pipeline?.setRoi(r[0].toFloat(), r[1].toFloat(), r[2].toFloat(), r[3].toFloat())
                result.success(null)
            }
            "setExposureLocked" -> {
                camera?.setExposureLocked(call.arguments<Boolean>() == true)
                result.success(null)
            }
            "startRecording" -> {
                val p = pipeline
                val dir = activity.getExternalFilesDir(null)
                if (p == null || dir == null) {
                    result.error("recording", "Caméra non démarrée", null)
                } else {
                    val stamp = SimpleDateFormat("yyyy-MM-dd'T'HH-mm-ss", Locale.ROOT).format(Date())
                    val file = File(dir, "safit_video_$stamp.mp4")
                    p.startRecording(file)
                    result.success(file.absolutePath)
                }
            }
            "stopRecording" -> {
                val p = pipeline
                if (p == null) {
                    result.success(null)
                } else {
                    Thread { p.stopRecording().let { mainHandler.post { result.success(it) } } }.start()
                }
            }
            "outputDirectory" -> result.success(activity.getExternalFilesDir(null)?.absolutePath)
            "describe" -> describe(result)
            "loadRoi" -> {
                val prefs = activity.getSharedPreferences(PREFS, Activity.MODE_PRIVATE)
                result.success(
                    prefs.getString(KEY_ROI, null)?.split(',')?.mapNotNull { it.toDoubleOrNull() }
                        ?.takeIf { it.size == 4 },
                )
            }
            "saveRoi" -> {
                val r = call.arguments<List<Double>>()!!
                activity.getSharedPreferences(PREFS, Activity.MODE_PRIVATE).edit()
                    .putString(KEY_ROI, r.joinToString(","))
                    .apply()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Ce que la caméra permet, sans l'allumer (pas besoin de permission). */
    private fun describe(result: MethodChannel.Result) {
        val cam = HighSpeedCamera(activity)
        try {
            val config = cam.selectConfig()
            result.success(
                mapOf(
                    "available" to true,
                    "highSpeed" to config.highSpeed,
                    "fps" to config.fps,
                    "captureWidth" to config.size.width,
                    "captureHeight" to config.size.height,
                ),
            )
        } catch (e: Exception) {
            result.success(mapOf("available" to false, "error" to (e.message ?: e.toString())))
        } finally {
            cam.close()
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
        releaseNow()
        var answered = false
        fun fail(message: String) = mainHandler.post {
            releaseNow()
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
            val w = config.size.width
            val h = config.size.height

            val video = VideoPipeline(w, h, config.fps, config.sensorOrientation, ::addSample)
            video.start()
            call.argument<List<Double>>("roi")?.let {
                video.setRoi(it[0].toFloat(), it[1].toFloat(), it[2].toFloat(), it[3].toFloat())
            }

            // Aperçu : la caméra écrit directement dans une texture Flutter (méthode
            // de Nathan, PFE-13). Android redresse lui-même l'image selon l'orientation
            // du capteur ; on ne la tourne pas nous-mêmes. Affichée en portrait.
            val rotated = config.sensorOrientation % 180 != 0
            val previewW = if (rotated) h else w
            val previewH = if (rotated) w else h
            val entry = textures.createSurfaceTexture()
            entry.surfaceTexture().setDefaultBufferSize(w, h)
            val surface = Surface(entry.surfaceTexture())

            camera = cam
            pipeline = video
            previewTexture = entry
            previewSurface = surface
            synchronized(lock) { count = 0 }

            cam.open(config, listOf(video.inputSurface, surface), onReady = {
                mainHandler.post {
                    mainHandler.post(flushTask)
                    if (!answered) {
                        answered = true
                        result.success(
                            mapOf(
                                "textureId" to entry.id(),
                                "previewWidth" to previewW,
                                "previewHeight" to previewH,
                                "captureWidth" to w,
                                "captureHeight" to h,
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

    /**
     * Arrêt propre : on coupe la caméra, puis on laisse le décodeur finir
     * d'analyser les images déjà filmées avant de tout libérer.
     */
    private fun stop(onDone: () -> Unit) {
        val cam = camera
        val video = pipeline
        camera = null
        pipeline = null
        Thread {
            cam?.close()
            video?.finish(FINISH_TIMEOUT_MS)
            mainHandler.post {
                mainHandler.removeCallbacks(flushTask)
                flush(video)
                releasePreview()
                onDone()
            }
        }.start()
    }

    /** Libération immédiate, sans attendre l'analyse (redémarrage, fermeture de l'app). */
    fun releaseNow() {
        mainHandler.removeCallbacks(flushTask)
        camera?.close()
        camera = null
        pipeline?.finish(0)
        pipeline = null
        releasePreview()
    }

    private fun releasePreview() {
        previewSurface?.release()
        previewSurface = null
        previewTexture?.release()
        previewTexture = null
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

    private fun flush(video: VideoPipeline? = pipeline) {
        val t: LongArray
        val y: FloatArray
        synchronized(lock) {
            t = times.copyOf(count)
            y = lumas.copyOf(count)
            count = 0
        }
        sink?.success(
            mapOf(
                "t" to t,
                "y" to y,
                "sensorFrames" to (camera?.sensorFrames?.get() ?: -1L),
                "encodedFrames" to (video?.encodedFrames?.get() ?: -1L),
                "lastEncodedNs" to (video?.lastEncodedNs ?: -1L),
            ),
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
        private const val PREFS = "safit_camera"
        private const val KEY_ROI = "roi"
        private const val FLUSH_INTERVAL_MS = 50L

        /** Temps laissé au décodeur pour finir l'analyse après l'arrêt. */
        private const val FINISH_TIMEOUT_MS = 30_000L
    }
}
