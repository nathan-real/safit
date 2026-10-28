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
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch

/**
 * Aperçu caméra pour l'écran Flutter. En mode 240 fps, la caméra n'envoie
 * à cette sortie qu'environ 30 images/s, ce qui suffit pour placer la zone de détection.
 *
 * L'image est redressée en portrait (selon [sensorOrientation]) et dessinée sans
 * attendre l'écran. Le rectangle de la ROI est dessiné par Flutter par-dessus,
 * dans les mêmes coordonnées que celles utilisées par [VideoPipeline].
 */
class PreviewRenderer(
    private val bufferWidth: Int,
    private val bufferHeight: Int,
    private val sensorOrientation: Int,
) {
    private val thread = HandlerThread("safit-preview").apply { start() }
    private val handler = Handler(thread.looper)

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var config: EGLConfig? = null
    private var pbuffer: EGLSurface = EGL14.EGL_NO_SURFACE
    private var windowSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var viewWidth = 0
    private var viewHeight = 0

    private var texture = 0
    private var program = 0
    private lateinit var surfaceTexture: SurfaceTexture
    private val texMatrix = FloatArray(16)

    /** Surface à donner à la caméra comme sortie « aperçu ». */
    lateinit var inputSurface: Surface
        private set

    fun start() = runSync {
        setUpEgl()
        texture = IntArray(1).also { GLES20.glGenTextures(1, it, 0) }[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        program = linkProgram()

        surfaceTexture = SurfaceTexture(texture).apply {
            setDefaultBufferSize(bufferWidth, bufferHeight)
            setOnFrameAvailableListener({ onFrame() }, handler)
        }
        inputSurface = Surface(surfaceTexture)
    }

    /** Surface Flutter où dessiner (null pour arrêter). */
    fun setOutput(surface: Surface?, width: Int, height: Int) = runSync {
        if (windowSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
            EGL14.eglDestroySurface(display, windowSurface)
            windowSurface = EGL14.EGL_NO_SURFACE
        }
        if (surface != null && surface.isValid) {
            windowSurface = EGL14.eglCreateWindowSurface(display, config, surface, intArrayOf(EGL14.EGL_NONE), 0)
            viewWidth = width
            viewHeight = height
            EGL14.eglMakeCurrent(display, windowSurface, windowSurface, context)
            // Ne jamais attendre l'écran : on ne doit pas freiner la caméra.
            EGL14.eglSwapInterval(display, 0)
            EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
        }
    }

    fun release() {
        runSync {
            if (::inputSurface.isInitialized) inputSurface.release()
            if (::surfaceTexture.isInitialized) surfaceTexture.release()
            if (windowSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, windowSurface)
            GLES20.glDeleteProgram(program)
            GLES20.glDeleteTextures(1, intArrayOf(texture), 0)
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(display, pbuffer)
            EGL14.eglDestroyContext(display, context)
            EGL14.eglTerminate(display)
        }
        thread.quitSafely()
    }

    private fun onFrame() {
        surfaceTexture.updateTexImage()
        if (windowSurface == EGL14.EGL_NO_SURFACE) return
        surfaceTexture.getTransformMatrix(texMatrix)

        EGL14.eglMakeCurrent(display, windowSurface, windowSurface, context)
        GLES20.glViewport(0, 0, viewWidth, viewHeight)
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uTex"), 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "uTexMatrix"), 1, false, texMatrix, 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uRotation"), sensorOrientation.toFloat())
        val position = GLES20.glGetAttribLocation(program, "aPos")
        GLES20.glEnableVertexAttribArray(position)
        GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 0, QUAD)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(position)
        EGL14.eglSwapBuffers(display, windowSurface)
        EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
    }

    private fun setUpEgl() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize" }
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        EGL14.eglChooseConfig(
            display,
            intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
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
            display, config, intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
        )
        check(EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)) { "eglMakeCurrent" }
    }

    private fun linkProgram(): Int {
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
        GLES20.glAttachShader(p, compile(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER))
        GLES20.glAttachShader(p, compile(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER))
        GLES20.glLinkProgram(p)
        return p
    }

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
        private val QUAD = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply { put(floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)).position(0) }

        // aPos : coin de l'écran dans [0,1]², origine en haut à gauche.
        // sensorUv() passe de l'aperçu portrait aux coordonnées du capteur
        // (même convention que VideoPipeline.toSensor).
        private const val VERTEX_SHADER = """
            attribute vec2 aPos;
            uniform mat4 uTexMatrix;
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
                vTex = (uTexMatrix * vec4(sensorUv(aPos), 0.0, 1.0)).xy;
            }
        """

        private const val FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTex;
            uniform samplerExternalOES uTex;

            void main() {
                gl_FragColor = texture2D(uTex, vTex);
            }
        """
    }
}
