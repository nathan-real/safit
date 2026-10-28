package fr.ensc.safit.camera

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraConstrainedHighSpeedCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.TotalCaptureResult
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.util.Range
import android.util.Size
import android.view.Surface
import java.util.concurrent.atomic.AtomicLong

/**
 * Pilote la caméra arrière, avec deux sorties (vidéo + aperçu) : session
 * « haute vitesse » (240 fps) si le téléphone la propose à une app tierce,
 * sinon session normale (≈30 fps), pour pouvoir quand même tester la chaîne
 * complète (émulateur, vieux téléphones). En haute vitesse, Android n'envoie
 * à l'aperçu qu'une image sur 8 (~30 i/s) ; la vidéo reçoit toutes les images.
 *
 * Tous les réglages sont regroupés dans [buildRequest] : ils sont réappliqués
 * à chaque (re)lancement de la capture.
 */
class HighSpeedCamera(context: Context) {

    data class Config(
        val cameraId: String,
        val size: Size,
        val fps: Int,
        val highSpeed: Boolean,
        val sensorOrientation: Int,
        /** Toutes les combinaisons haute vitesse proposées, ex. « 1280x720@240 ». */
        val highSpeedOptions: List<String>,
    )

    private val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val thread = HandlerThread("safit-camera", Process.THREAD_PRIORITY_VIDEO).apply { start() }
    private val handler = Handler(thread.looper)

    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var targets: List<Surface> = emptyList()
    private var config: Config? = null
    private var exposureLocked = false

    /** Nombre d'images sorties du capteur (pour savoir où se perdent les images). */
    val sensorFrames = AtomicLong(0)

    /** Choisit la caméra arrière et le meilleur mode disponible. */
    fun selectConfig(): Config {
        val backIds = manager.cameraIdList.filter {
            manager.getCameraCharacteristics(it)
                .get(CameraCharacteristics.LENS_FACING) == CameraMetadata.LENS_FACING_BACK
        }
        check(backIds.isNotEmpty()) { "Aucune caméra arrière" }

        for (id in backIds) {
            highSpeedConfig(id)?.let { return it }
        }
        return normalConfig(backIds.first())
    }

    private fun highSpeedConfig(id: String): Config? {
        val chars = manager.getCameraCharacteristics(id)
        val capabilities = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES) ?: return null
        if (CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_CONSTRAINED_HIGH_SPEED_VIDEO !in capabilities) {
            return null
        }
        val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return null

        // Couples (taille, fps fixe) proposés. On veut le fps le plus élevé,
        // puis la plus petite image (moins de travail par image).
        val options = map.highSpeedVideoSizes.flatMap { size ->
            map.getHighSpeedVideoFpsRangesFor(size)
                .filter { it.lower == it.upper }
                .map { size to it.upper }
        }.distinct()
        val best = options
            .sortedWith(compareByDescending<Pair<Size, Int>> { it.second }.thenBy { it.first.width * it.first.height })
            .firstOrNull() ?: return null

        return Config(
            cameraId = id,
            size = best.first,
            fps = best.second,
            highSpeed = true,
            sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90,
            highSpeedOptions = options.map { "${it.first.width}x${it.first.height}@${it.second}" },
        )
    }

    private fun normalConfig(id: String): Config {
        val chars = manager.getCameraCharacteristics(id)
        val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)!!
        val sizes = map.getOutputSizes(SurfaceTexture::class.java)
        // Taille proche de 1280×720, sans dépasser.
        val size = sizes.filter { it.width <= 1280 && it.height <= 720 }
            .maxByOrNull { it.width * it.height } ?: sizes.minBy { it.width * it.height }
        val fps = chars.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
            ?.maxOfOrNull { it.upper } ?: 30
        return Config(
            cameraId = id,
            size = size,
            fps = fps,
            highSpeed = false,
            sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90,
            highSpeedOptions = emptyList(),
        )
    }

    @SuppressLint("MissingPermission")
    fun open(config: Config, surfaces: List<Surface>, onReady: () -> Unit, onError: (String) -> Unit) {
        this.config = config
        targets = surfaces
        manager.openCamera(config.cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                device = camera
                createSession(camera, surfaces, onReady, onError)
            }

            override fun onDisconnected(camera: CameraDevice) {
                camera.close()
                device = null
            }

            override fun onError(camera: CameraDevice, error: Int) {
                camera.close()
                device = null
                onError("Erreur caméra $error")
            }
        }, handler)
    }

    @Suppress("DEPRECATION")
    private fun createSession(
        camera: CameraDevice,
        surfaces: List<Surface>,
        onReady: () -> Unit,
        onError: (String) -> Unit,
    ) {
        val callback = object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(s: CameraCaptureSession) {
                session = s
                try {
                    startRepeating()
                    onReady()
                } catch (e: Exception) {
                    onError("Lancement de la capture : ${e.message}")
                }
            }

            override fun onConfigureFailed(s: CameraCaptureSession) {
                onError("Configuration de la session refusée")
            }
        }
        if (config!!.highSpeed) {
            camera.createConstrainedHighSpeedCaptureSession(surfaces, callback, handler)
        } else {
            camera.createCaptureSession(surfaces, callback, handler)
        }
    }

    fun setExposureLocked(locked: Boolean) {
        exposureLocked = locked
        handler.post { runCatching { startRepeating() } }
    }

    private fun buildRequest(): CaptureRequest {
        val camera = device!!
        val cfg = config!!
        val template = CameraDevice.TEMPLATE_RECORD
        return camera.createCaptureRequest(template).apply {
            targets.forEach { addTarget(it) }
            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(cfg.fps, cfg.fps))
            set(CaptureRequest.CONTROL_AE_LOCK, exposureLocked)
            set(CaptureRequest.CONTROL_AWB_LOCK, exposureLocked)
            if (!cfg.highSpeed) {
                // En haute vitesse ces réglages ne sont pas modifiables ;
                // en mode normal on coupe tout ce qui retarde ou lisse l'image.
                set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
                set(CaptureRequest.NOISE_REDUCTION_MODE, CameraMetadata.NOISE_REDUCTION_MODE_OFF)
                set(CaptureRequest.EDGE_MODE, CameraMetadata.EDGE_MODE_OFF)
            }
        }.build()
    }

    private val captureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(
            session: CameraCaptureSession,
            request: CaptureRequest,
            result: TotalCaptureResult,
        ) {
            sensorFrames.incrementAndGet()
        }
    }

    private fun startRepeating() {
        val s = session ?: return
        val request = buildRequest()
        if (s is CameraConstrainedHighSpeedCaptureSession) {
            s.setRepeatingBurst(s.createHighSpeedRequestList(request), captureCallback, handler)
        } else {
            s.setRepeatingRequest(request, captureCallback, handler)
        }
    }

    fun close() {
        runCatching { session?.close() }
        runCatching { device?.close() }
        session = null
        device = null
        thread.quitSafely()
    }
}
