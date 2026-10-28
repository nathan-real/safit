package fr.ensc.safit.camera

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch

/**
 * Analyse chaque image de la caméra sur le GPU, sans la copier :
 * l'image arrive dans une texture, on ne dessine que la zone de détection (ROI)
 * dans une mini-image de 16×16 pixels en niveaux de gris, puis on en lit la
 * moyenne. Résultat : un seul nombre (la luminosité) par image, avec son
 * horodatage capteur.
 *
 * Dessine aussi un aperçu, à fréquence réduite, dans la surface affichée par Flutter.
 * Les coordonnées de la ROI sont celles de l'aperçu (portrait, 0..1, origine en haut
 * à gauche) : analyse et aperçu passent par la même conversion, donc le rectangle
 * dessiné à l'écran est exactement la zone analysée.
 */
class RoiAnalyzer(
    private val bufferWidth: Int,
    private val bufferHeight: Int,
    private val sensorOrientation: Int,
    private val onSample: (timestampNs: Long, luma: Float) -> Unit,
) {
    private val thread = HandlerThread("safit-gl", Process.THREAD_PRIORITY_URGENT_DISPLAY).apply { start() }
    private val handler = Handler(thread.looper)

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var config: EGLConfig? = null
    private var pbuffer: EGLSurface = EGL14.EGL_NO_SURFACE
    private var previewSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var previewWidth = 0
    private var previewHeight = 0

    private var oesTexture = 0
    private var program = 0
    private var framebuffer = 0
    private var framebufferTexture = 0
    private lateinit var surfaceTexture: SurfaceTexture

    /** Surface à donner à la caméra comme sortie. */
    lateinit var inputSurface: Surface
        private set

    private val texMatrix = FloatArray(16)
    private val readBuffer = ByteBuffer
        .allocateDirect(ANALYSIS_SIZE * ANALYSIS_SIZE * 4)
        .order(ByteOrder.nativeOrder())

    @Volatile
    private var roi = floatArrayOf(0.25f, 0.4f, 0.5f, 0.2f)
    private var frameIndex = 0L

    fun start() = runSync {
        setUpEgl()
        setUpGl()
        surfaceTexture = SurfaceTexture(oesTexture).apply {
            setDefaultBufferSize(bufferWidth, bufferHeight)
            setOnFrameAvailableListener({ onFrame() }, handler)
        }
        inputSurface = Surface(surfaceTexture)
    }

    fun setRoi(x: Float, y: Float, w: Float, h: Float) {
        roi = floatArrayOf(x, y, w, h)
    }

    /** Surface Flutter où dessiner l'aperçu (null pour l'arrêter). */
    fun setPreviewSurface(surface: Surface?, width: Int, height: Int) = runSync {
        if (previewSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
            EGL14.eglDestroySurface(display, previewSurface)
            previewSurface = EGL14.EGL_NO_SURFACE
        }
        if (surface != null && surface.isValid) {
            previewSurface = EGL14.eglCreateWindowSurface(
                display, config, surface, intArrayOf(EGL14.EGL_NONE), 0,
            )
            previewWidth = width
            previewHeight = height
        }
    }

    fun release() {
        runSync {
            if (::inputSurface.isInitialized) inputSurface.release()
            if (::surfaceTexture.isInitialized) surfaceTexture.release()
            if (previewSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, previewSurface)
            GLES20.glDeleteProgram(program)
            GLES20.glDeleteFramebuffers(1, intArrayOf(framebuffer), 0)
            GLES20.glDeleteTextures(2, intArrayOf(framebufferTexture, oesTexture), 0)
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(display, pbuffer)
            EGL14.eglDestroyContext(display, context)
            EGL14.eglTerminate(display)
        }
        thread.quitSafely()
    }

    // --- Boucle image par image (thread GL) ---

    private fun onFrame() {
        surfaceTexture.updateTexImage()
        val timestamp = surfaceTexture.timestamp
        surfaceTexture.getTransformMatrix(texMatrix)

        onSample(timestamp, measureRoiLuma())

        if (previewSurface != EGL14.EGL_NO_SURFACE && frameIndex % PREVIEW_EVERY == 0L) {
            drawPreview()
        }
        frameIndex++
    }

    private fun measureRoiLuma(): Float {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, framebuffer)
        GLES20.glViewport(0, 0, ANALYSIS_SIZE, ANALYSIS_SIZE)
        draw(roi, gray = true)
        readBuffer.rewind()
        GLES20.glReadPixels(
            0, 0, ANALYSIS_SIZE, ANALYSIS_SIZE,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, readBuffer,
        )
        var sum = 0L
        for (i in 0 until ANALYSIS_SIZE * ANALYSIS_SIZE) {
            sum += readBuffer.get(i * 4).toInt() and 0xFF
        }
        return sum / (ANALYSIS_SIZE * ANALYSIS_SIZE * 255f)
    }

    private fun drawPreview() {
        EGL14.eglMakeCurrent(display, previewSurface, previewSurface, context)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glViewport(0, 0, previewWidth, previewHeight)
        draw(FULL_FRAME, gray = false)
        EGL14.eglSwapBuffers(display, previewSurface)
        EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
    }

    private fun draw(region: FloatArray, gray: Boolean) {
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTexture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uTex"), 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "uTexMatrix"), 1, false, texMatrix, 0)
        GLES20.glUniform4fv(GLES20.glGetUniformLocation(program, "uRegion"), 1, region, 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uRotation"), sensorOrientation.toFloat())
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uGray"), if (gray) 1f else 0f)

        val position = GLES20.glGetAttribLocation(program, "aPos")
        GLES20.glEnableVertexAttribArray(position)
        GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 0, QUAD)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(position)
    }

    // --- Mise en place ---

    private fun setUpEgl() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize" }

        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        EGL14.eglChooseConfig(
            display,
            intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT or EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_NONE,
            ),
            0, configs, 0, 1, count, 0,
        )
        check(count[0] > 0) { "Aucune configuration EGL" }
        config = configs[0]

        context = EGL14.eglCreateContext(
            display, config, EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
        )
        pbuffer = EGL14.eglCreatePbufferSurface(
            display, config,
            intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
        )
        check(EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)) { "eglMakeCurrent" }
    }

    private fun setUpGl() {
        val textures = IntArray(2)
        GLES20.glGenTextures(2, textures, 0)
        oesTexture = textures[0]
        framebufferTexture = textures[1]

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTexture)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, framebufferTexture)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, ANALYSIS_SIZE, ANALYSIS_SIZE, 0,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null,
        )
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_NEAREST)

        val framebuffers = IntArray(1)
        GLES20.glGenFramebuffers(1, framebuffers, 0)
        framebuffer = framebuffers[0]
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, framebuffer)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D, framebufferTexture, 0,
        )
        check(GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER) == GLES20.GL_FRAMEBUFFER_COMPLETE) {
            "Framebuffer incomplet"
        }

        program = linkProgram(VERTEX_SHADER, FRAGMENT_SHADER)
    }

    private fun linkProgram(vertexSource: String, fragmentSource: String): Int {
        fun compile(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            val ok = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, ok, 0)
            check(ok[0] != 0) { "Shader : " + GLES20.glGetShaderInfoLog(shader) }
            return shader
        }
        val p = GLES20.glCreateProgram()
        GLES20.glAttachShader(p, compile(GLES20.GL_VERTEX_SHADER, vertexSource))
        GLES20.glAttachShader(p, compile(GLES20.GL_FRAGMENT_SHADER, fragmentSource))
        GLES20.glLinkProgram(p)
        val ok = IntArray(1)
        GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, ok, 0)
        check(ok[0] != 0) { "Programme : " + GLES20.glGetProgramInfoLog(p) }
        return p
    }

    /** Exécute [block] sur le thread GL et attend la fin (relance les erreurs). */
    private fun runSync(block: () -> Unit) {
        var error: Throwable? = null
        val done = CountDownLatch(1)
        handler.post {
            try {
                block()
            } catch (t: Throwable) {
                error = t
            } finally {
                done.countDown()
            }
        }
        done.await()
        error?.let { throw it }
    }

    companion object {
        /** Taille de la mini-image où l'on réduit la ROI avant d'en faire la moyenne. */
        private const val ANALYSIS_SIZE = 16

        /** On analyse toutes les images, mais on n'en affiche qu'une sur 4 (~60 i/s). */
        private const val PREVIEW_EVERY = 4L

        private val FULL_FRAME = floatArrayOf(0f, 0f, 1f, 1f)

        private val QUAD = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply { put(floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)).position(0) }

        // aPos : coin du quadrilatère dans [0,1]², origine en haut à gauche.
        // uRegion : zone de l'aperçu à dessiner (x, y, largeur, hauteur).
        // sensorUv() passe des coordonnées de l'aperçu portrait à celles du capteur.
        private const val VERTEX_SHADER = """
            attribute vec2 aPos;
            uniform mat4 uTexMatrix;
            uniform vec4 uRegion;
            uniform float uRotation;
            varying vec2 vTex;

            vec2 sensorUv(vec2 p) {
                if (uRotation > 45.0 && uRotation < 135.0) return vec2(p.y, p.x);
                if (uRotation > 135.0 && uRotation < 225.0) return vec2(1.0 - p.x, p.y);
                if (uRotation > 225.0) return vec2(1.0 - p.y, 1.0 - p.x);
                return vec2(p.x, 1.0 - p.y);
            }

            void main() {
                gl_Position = vec4(aPos.x * 2.0 - 1.0, 1.0 - aPos.y * 2.0, 0.0, 1.0);
                vec2 p = uRegion.xy + aPos * uRegion.zw;
                vTex = (uTexMatrix * vec4(sensorUv(p), 0.0, 1.0)).xy;
            }
        """

        private const val FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTex;
            uniform samplerExternalOES uTex;
            uniform float uGray;

            void main() {
                vec4 c = texture2D(uTex, vTex);
                float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
                gl_FragColor = mix(c, vec4(l, l, l, 1.0), uGray);
            }
        """
    }
}
