package fr.ensc.safit

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.*
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.util.Range
import android.view.Surface
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File

class MainActivity : FlutterActivity() {
    private val W = 1280
    private val H = 720
    private val FPS = 240

    private val frameTimestamps = mutableListOf<Double>()

    private var engine: FlutterEngine? = null
    private var cameraDevice: CameraDevice? = null
    private var session: CameraConstrainedHighSpeedCaptureSession? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var outputFile: File? = null
    private var pendingOpen: MethodChannel.Result? = null

    // Encodage asynchrone
    private var encoder: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var trackIndex = -1
    private var muxerStarted = false
    private var encoderSurface: Surface? = null

    // Séparation stricte des threads avec priorité vidéo
    private val cameraThread = HandlerThread("cam", Process.THREAD_PRIORITY_VIDEO).apply { start() }
    private val cameraHandler = Handler(cameraThread.looper)

    private val encoderThread = HandlerThread("enc", Process.THREAD_PRIORITY_VIDEO).apply { start() }
    private val encoderHandler = Handler(encoderThread.looper)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engine = flutterEngine
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "highspeed")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                            == PackageManager.PERMISSION_GRANTED) {
                            openCamera(result)
                        } else {
                            pendingOpen = result
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 1)
                        }
                    }
                    "start" -> startRecording(result)
                    "stop" -> stopRecording(result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val r = pendingOpen ?: return
        pendingOpen = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) openCamera(r)
        else r.error("perm", "Permission caméra refusée", null)
    }

    @SuppressLint("MissingPermission")
    private fun openCamera(result: MethodChannel.Result) {
        val entry = engine!!.renderer.createSurfaceTexture()
        entry.surfaceTexture().setDefaultBufferSize(W, H)
        textureEntry = entry
        previewSurface = Surface(entry.surfaceTexture())

        val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        manager.openCamera("0", object : CameraDevice.StateCallback() {
            override fun onOpened(cam: CameraDevice) {
                cameraDevice = cam
                startSession(listOf(previewSurface!!)) {
                    runOnUiThread { result.success(entry.id().toInt()) }
                }
            }
            override fun onDisconnected(cam: CameraDevice) { cam.close() }
            override fun onError(cam: CameraDevice, error: Int) {
                cam.close()
                runOnUiThread { result.error("cam", "Erreur caméra $error", null) }
            }
        }, cameraHandler) // Utilisation du  handler
    }

    private fun startSession(surfaces: List<Surface>, onReady: () -> Unit) {
        val cam = cameraDevice ?: return
        val builder = cam.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
        builder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(FPS, FPS))

        builder.set(CaptureRequest.CONTROL_AE_LOCK, true)
        builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
        builder.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
        builder.set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CameraMetadata.LENS_OPTICAL_STABILIZATION_MODE_OFF)
        builder.set(CaptureRequest.NOISE_REDUCTION_MODE, CameraMetadata.NOISE_REDUCTION_MODE_OFF)
        builder.set(CaptureRequest.EDGE_MODE, CameraMetadata.EDGE_MODE_OFF)
        builder.set(CaptureRequest.COLOR_CORRECTION_ABERRATION_MODE, CameraMetadata.COLOR_CORRECTION_ABERRATION_MODE_OFF)

        surfaces.forEach { builder.addTarget(it) }
        cam.createConstrainedHighSpeedCaptureSession(surfaces,
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(s: CameraCaptureSession) {
                    val hs = s as CameraConstrainedHighSpeedCaptureSession
                    session = hs
                    val builder = cam.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                    builder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(FPS, FPS))
                    surfaces.forEach { builder.addTarget(it) }
                    
                    // Utilisation du  handler
                    hs.setRepeatingBurst(hs.createHighSpeedRequestList(builder.build()), null, cameraHandler)
                    onReady()
                }
                override fun onConfigureFailed(s: CameraCaptureSession) {
                    android.util.Log.e("HS", "Configuration de la session échouée")
                }
            }, cameraHandler) // Utilisation du  handler
    }

    private fun startRecording(result: MethodChannel.Result) {
        try {
            session?.close()
            session = null
            
            val dir = getExternalFilesDir(Environment.DIRECTORY_MOVIES)
            val file = File(dir, "hs_${System.currentTimeMillis()}.mp4")
            outputFile = file

            // Clear previous recordings
            frameTimestamps.clear()

            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, W, H).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            
            // 6 Mbps sont suffisants pour du tracking de contraste sur un volant d'inertie
            setInteger(MediaFormat.KEY_BIT_RATE, 6_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_OPERATING_RATE, FPS)

            //  : Forcer l'encodeur matériel en priorité temps réel maximale
            setInteger(MediaFormat.KEY_PRIORITY, 0)

            //  : Désactiver totalement les B-frames pour supprimer la latence de réagencement
            setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)

            //  : Forcer un bitrate constant (CBR) pour lisser l'écriture et éviter les pics de saturation sur la mémoire flash
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
        }
            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer?.setOrientationHint(90)
            muxerStarted = false

            encoder?.setCallback(object : MediaCodec.Callback() {
                override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {}
                
                override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
                    val encodedData = codec.getOutputBuffer(index) ?: return
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        info.size = 0
                    }
                    if (info.size != 0 && muxerStarted) {
                    encodedData.position(info.offset)
                    encodedData.limit(info.offset + info.size)
                    muxer?.writeSampleData(trackIndex, encodedData, info) 
                    
                    // Convert microseconds to seconds and store
                    frameTimestamps.add(info.presentationTimeUs / 1000000.0)
                }
                    codec.releaseOutputBuffer(index, false)
                }

                override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
                    trackIndex = muxer?.addTrack(format) ?: -1
                    muxer?.start()
                    muxerStarted = true
                }

                override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {}
            }, encoderHandler)

            encoder?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoderSurface = encoder?.createInputSurface()
            encoder?.start()

            startSession(listOf(encoderSurface!!)) {
                runOnUiThread { result.success(file.absolutePath) }
            }
        } catch (e: Exception) {
            result.error("start", e.message, null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        try { session?.stopRepeating(); session?.abortCaptures() } catch (_: Exception) {}
        
        try {
            encoder?.stop()
            encoder?.release()
        } catch (_: Exception) {}
        encoder = null
        
        try {
            if (muxerStarted) muxer?.stop()
            muxer?.release()
        } catch (_: Exception) {}
        muxer = null
        muxerStarted = false
        
        session?.close()
        session = null
        
        startSession(listOf(previewSurface!!)) {
            runOnUiThread { 
                // Send path and timestamps array back to Flutter
                val resultData = mapOf(
                    "path" to outputFile?.absolutePath,
                    "timestamps" to frameTimestamps.toList()
                )
                result.success(resultData) 
            }
        }
    }

    override fun onDestroy() {
        cameraDevice?.close()
        // Arrêt propre des threads pour éviter les fuites de mémoire
        cameraThread.quitSafely()
        encoderThread.quitSafely()
        super.onDestroy()
    }
}