package fr.ensc.safit.camera

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.util.Log
import android.view.Surface
import java.io.File
import java.util.ArrayDeque
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max
import kotlin.math.min

/**
 * Chaîne vidéo : la caméra écrit dans un encodeur H.264 (seule sortie qui suit
 * vraiment les 240 fps sur le S23, cf. PFE-13 de Nathan). Chaque image encodée :
 * - est écrite dans un fichier MP4 si un enregistrement est en cours ;
 * - est aussi envoyée à un décodeur, qui rend l'image et dont on lit la luminosité
 *   moyenne de la zone de détection (ROI), directement dans le plan Y.
 *
 * Aucune image n'est jetée : si le décodeur prend du retard, les images
 * attendent leur tour, et l'analyse se termine juste après la fin du test.
 */
class VideoPipeline(
    private val width: Int,
    private val height: Int,
    private val fps: Int,
    private val sensorOrientation: Int,
    private val onSample: (timestampNs: Long, luma: Float) -> Unit,
) {
    private class Packet(val data: ByteArray, val ptsUs: Long, val endOfStream: Boolean)

    private val encoderThread = HandlerThread("safit-encoder", Process.THREAD_PRIORITY_VIDEO).apply { start() }
    private val encoderHandler = Handler(encoderThread.looper)
    private val decoderThread = HandlerThread("safit-decoder", Process.THREAD_PRIORITY_VIDEO).apply { start() }
    private val decoderHandler = Handler(decoderThread.looper)

    private val encoder = MediaCodec.createEncoderByType(MIME)
    private var decoder: MediaCodec? = null

    /** Surface à donner à la caméra comme sortie « vidéo ». */
    lateinit var inputSurface: Surface
        private set

    @Volatile
    private var roi = floatArrayOf(0.2f, 0.4f, 0.6f, 0.15f)

    /** Images sorties de l'encodeur. */
    val encodedFrames = AtomicLong(0)

    /** Horodatage (ns) de la dernière image encodée, pour mesurer le retard de l'analyse. */
    @Volatile
    var lastEncodedNs = -1L
        private set

    // Enregistrement MP4 (thread encodeur).
    private var outputFormat: MediaFormat? = null
    private var muxer: MediaMuxer? = null
    private var track = -1
    @Volatile
    private var pendingRecording: File? = null
    private var currentRecording: File? = null

    // Alimentation du décodeur (thread décodeur).
    private val packets = ArrayDeque<Packet>()
    private val freeInputs = ArrayDeque<Int>()
    private val decoderDone = CountDownLatch(1)

    fun start() {
        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_OPERATING_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // Priorité temps réel et pas d'images B : moins de latence (réglages de Nathan).
            setInteger(MediaFormat.KEY_PRIORITY, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
        }
        encoder.setCallback(encoderCallback, encoderHandler)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = encoder.createInputSurface()
        encoder.start()
    }

    fun setRoi(x: Float, y: Float, w: Float, h: Float) {
        roi = floatArrayOf(x, y, w, h)
    }

    /** Commence à écrire la vidéo dans [file] dès la prochaine image clé. */
    fun startRecording(file: File) {
        pendingRecording = file
        runCatching {
            encoder.setParameters(Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0) })
        }
    }

    /** Termine le fichier MP4 et renvoie son chemin (null s'il n'avait pas commencé). */
    fun stopRecording(): String? {
        var path: String? = null
        runSync(encoderHandler) {
            pendingRecording = null
            path = currentRecording?.absolutePath
            closeMuxer()
        }
        return path
    }

    /**
     * Fin de la capture (caméra déjà arrêtée) : vide l'encodeur puis le décodeur
     * pour analyser jusqu'à la dernière image, au plus [timeoutMs].
     */
    fun finish(timeoutMs: Long) {
        runCatching { encoder.signalEndOfInputStream() }
        decoderDone.await(timeoutMs, TimeUnit.MILLISECONDS)
        runSync(encoderHandler) { closeMuxer() }
        runCatching { encoder.stop() }
        encoder.release()
        runSync(decoderHandler) {
            decoder?.let {
                runCatching { it.stop() }
                it.release()
            }
            decoder = null
        }
        inputSurface.release()
        encoderThread.quitSafely()
        decoderThread.quitSafely()
    }

    // --- Encodeur (thread encodeur) ---

    private val encoderCallback = object : MediaCodec.Callback() {
        override fun onInputBufferAvailable(codec: MediaCodec, index: Int) = Unit

        override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
            outputFormat = format
            decoderHandler.post { startDecoder(format) }
        }

        override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
            val buffer = codec.getOutputBuffer(index)
            val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
            val isEnd = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0

            if (buffer != null && info.size > 0 && !isConfig) {
                encodedFrames.incrementAndGet()
                lastEncodedNs = info.presentationTimeUs * 1000

                buffer.position(info.offset)
                buffer.limit(info.offset + info.size)
                writeToFile(buffer, info)

                val bytes = ByteArray(info.size)
                buffer.position(info.offset)
                buffer.get(bytes)
                val packet = Packet(bytes, info.presentationTimeUs, endOfStream = false)
                decoderHandler.post {
                    packets.add(packet)
                    feedDecoder()
                }
            }
            codec.releaseOutputBuffer(index, false)

            if (isEnd) {
                decoderHandler.post {
                    packets.add(Packet(ByteArray(0), 0, endOfStream = true))
                    feedDecoder()
                }
            }
        }

        override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
            Log.e(TAG, "Encodeur", e)
        }
    }

    private fun writeToFile(buffer: java.nio.ByteBuffer, info: MediaCodec.BufferInfo) {
        val pending = pendingRecording
        val isKey = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
        // Un MP4 doit commencer par une image clé.
        if (pending != null && muxer == null && isKey) {
            val format = outputFormat ?: return
            muxer = MediaMuxer(pending.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4).apply {
                setOrientationHint(sensorOrientation)
                track = addTrack(format)
                start()
            }
            currentRecording = pending
            pendingRecording = null
        }
        muxer?.writeSampleData(track, buffer, info)
    }

    private fun closeMuxer() {
        muxer?.let {
            runCatching { it.stop() }
            it.release()
        }
        muxer = null
        currentRecording = null
    }

    // --- Décodeur + analyse (thread décodeur) ---

    private fun startDecoder(encoded: MediaFormat) {
        if (decoder != null) return
        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            encoded.getByteBuffer("csd-0")?.let { setByteBuffer("csd-0", it) }
            encoded.getByteBuffer("csd-1")?.let { setByteBuffer("csd-1", it) }
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_PRIORITY, 0)
            setInteger(MediaFormat.KEY_OPERATING_RATE, fps)
        }
        decoder = MediaCodec.createDecoderByType(MIME).apply {
            setCallback(decoderCallback, decoderHandler)
            configure(format, null, null, 0)
            start()
        }
    }

    private fun feedDecoder() {
        val d = decoder ?: return
        while (packets.isNotEmpty() && freeInputs.isNotEmpty()) {
            val packet = packets.removeFirst()
            val index = freeInputs.removeFirst()
            if (packet.endOfStream) {
                d.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                continue
            }
            val input = d.getInputBuffer(index) ?: continue
            input.clear()
            input.put(packet.data)
            d.queueInputBuffer(index, 0, packet.data.size, packet.ptsUs, 0)
        }
    }

    private val decoderCallback = object : MediaCodec.Callback() {
        override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {
            freeInputs.add(index)
            feedDecoder()
        }

        override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
            if (info.size > 0) {
                val image = codec.getOutputImage(index)
                if (image != null) {
                    try {
                        onSample(info.presentationTimeUs * 1000, roiLuma(image))
                    } finally {
                        image.close()
                    }
                }
            }
            codec.releaseOutputBuffer(index, false)
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) decoderDone.countDown()
        }

        override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) = Unit

        override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
            Log.e(TAG, "Décodeur", e)
            decoderDone.countDown()
        }
    }

    /**
     * Luminosité moyenne de la ROI, lue dans le plan Y (luminance) de l'image décodée.
     * La ROI est donnée dans l'aperçu portrait ; l'image vidéo est dans le sens du
     * capteur, d'où la conversion selon [sensorOrientation].
     */
    private fun roiLuma(image: Image): Float {
        val crop = image.cropRect
        val plane = image.planes[0]
        val data = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride

        val r = roi
        val (c0, r0) = toSensor(r[0], r[1])
        val (c1, r1) = toSensor(r[0] + r[2], r[1] + r[3])
        val left = crop.left + (min(c0, c1) * crop.width()).toInt()
        val right = crop.left + (max(c0, c1) * crop.width()).toInt()
        val top = crop.top + (min(r0, r1) * crop.height()).toInt()
        val bottom = crop.top + (max(r0, r1) * crop.height()).toInt()

        // Au plus ~32×32 points échantillonnés : largement assez pour une moyenne.
        val stepX = max(1, (right - left) / SAMPLES_PER_SIDE)
        val stepY = max(1, (bottom - top) / SAMPLES_PER_SIDE)
        var sum = 0L
        var count = 0
        var y = top
        while (y < bottom) {
            var x = left
            val row = y * rowStride
            while (x < right) {
                sum += data.get(row + x * pixelStride).toInt() and 0xFF
                count++
                x += stepX
            }
            y += stepY
        }
        return if (count == 0) 0f else sum / (count * 255f)
    }

    /** Point de l'aperçu portrait (0..1) → (colonne, ligne) dans l'image du capteur (0..1). */
    private fun toSensor(x: Float, y: Float): Pair<Float, Float> = when (sensorOrientation) {
        90 -> y to 1 - x
        180 -> 1 - x to 1 - y
        270 -> 1 - y to x
        else -> x to y
    }

    private fun runSync(handler: Handler, block: () -> Unit) {
        val done = CountDownLatch(1)
        if (!handler.post {
                try {
                    block()
                } finally {
                    done.countDown()
                }
            }
        ) {
            return
        }
        done.await(2, TimeUnit.SECONDS)
    }

    companion object {
        private const val TAG = "SafitVideo"
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC

        /** 12 Mbit/s : assez pour garder des traits nets (Nathan était à 6). */
        private const val BIT_RATE = 12_000_000
        private const val SAMPLES_PER_SIDE = 32
    }
}
