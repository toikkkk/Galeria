package com.galeria.galeria

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import android.opengl.Matrix
import android.os.Bundle
import android.os.Handler
import android.util.Log
import android.os.Looper
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import androidx.core.content.ContextCompat
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * AR "coba di ruangan": menempelkan lukisan pada BIDANG DINDING yang dideteksi ARCore,
 * dengan ukuran fisik asli (lebar x tinggi dalam cm). Render OpenGL ES 2.0 sendiri
 * (latar kamera + bidang terdeteksi + bingkai + lukisan), tanpa library 3D pihak ketiga.
 *
 * Batasan jujur: ukuran akurat hanya sejauh ARCore memperkirakan skala dunia (umumnya
 * beberapa persen); dinding polos tanpa tekstur sulit dideteksi.
 */
class ArArtworkFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        ArArtworkView(activity, messenger, viewId, args as? Map<*, *> ?: emptyMap<Any, Any>())
}

/** Cek dukungan ARCore (dipanggil dari Dart sebelum membuat view). */
object ArSupport {
    fun check(activity: Activity): String {
        return when (ArCoreApk.getInstance().checkAvailability(activity)) {
            ArCoreApk.Availability.SUPPORTED_INSTALLED -> "supported"
            ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
            ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED -> "needs_install"
            ArCoreApk.Availability.UNKNOWN_CHECKING,
            ArCoreApk.Availability.UNKNOWN_TIMED_OUT,
            ArCoreApk.Availability.UNKNOWN_ERROR -> "checking"
            else -> "unsupported"
        }
    }
}

private const val TAG = "GaleriaAR"

class ArArtworkView(
    private val activity: Activity,
    messenger: BinaryMessenger,
    viewId: Int,
    params: Map<*, *>,
) : PlatformView, GLSurfaceView.Renderer, MethodChannel.MethodCallHandler,
    Application.ActivityLifecycleCallbacks {

    private val channel = MethodChannel(messenger, "galeria/ar_artwork/$viewId")
    private val main = Handler(Looper.getMainLooper())
    private val glView = GLSurfaceView(activity)

    private var session: Session? = null
    private var resumed = false
    private var disposed = false

    // Karya
    private val artBitmap: Bitmap? =
        (params["image"] as? ByteArray)?.let { decode(it, 2048) }
    private val artW = ((params["lebarCm"] as? Number)?.toFloat() ?: 60f) / 100f // meter
    private val artH = ((params["tinggiCm"] as? Number)?.toFloat() ?: 80f) / 100f
    private val borderM = 0.03f

    // Interaksi (ditulis thread UI, dibaca thread GL)
    @Volatile private var pendingTap: FloatArray? = null
    @Volatile private var pendingReset = false
    @Volatile private var captureResult: MethodChannel.Result? = null
    // Terkunci = ketukan tidak memindahkan lukisan (mencegah lukisan 'bergeser sendiri' karena sentuhan tak sengaja)
    @Volatile private var locked = true
    @Volatile private var showDims = true
    private var smoothP: FloatArray? = null
    private var smoothN: FloatArray? = null
    private var lastJarakMs = 0L
    private var labelWTex = 0
    private var labelHTex = 0
    private var labelWAspect = 2.5f
    private var labelHAspect = 2.5f
    private var gradProg = 0

    // State GL
    private var cameraTex = 0
    private var artTex = 0
    private var bgProg = 0
    private var texProg = 0
    private var colProg = 0
    private var viewW = 1
    private var viewH = 1
    private var anchor: Anchor? = null
    private var fixedNormal: FloatArray? = null   // != null => ditempel via Instant Placement (tanpa bidang dinding)
    private var lastStatus = ""
    private var loggedDraw = false

    private val quadNdc = floatBufferOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
    private val quadUv = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()
    private val proj = FloatArray(16)
    private val viewM = FloatArray(16)
    private val vp = FloatArray(16)

    init {
        Log.i(TAG, "view dibuat: bitmap=${artBitmap?.width}x${artBitmap?.height} ukuran=${artW}m x ${artH}m")
        channel.setMethodCallHandler(this)
        glView.apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(this@ArArtworkView)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
            val taps = GestureDetector(activity, object : GestureDetector.SimpleOnGestureListener() {
                override fun onSingleTapUp(e: MotionEvent): Boolean {
                    pendingTap = floatArrayOf(e.x, e.y)
                    return true
                }
            })
            setOnTouchListener { _, ev -> taps.onTouchEvent(ev); true }
        }
        activity.application.registerActivityLifecycleCallbacks(this)
        startSession()
    }

    override fun getView(): View = glView

    override fun dispose() {
        disposed = true
        activity.application.unregisterActivityLifecycleCallbacks(this)
        channel.setMethodCallHandler(null)
        glView.onPause()
        anchor?.detach()
        session?.close()
        session = null
    }

    // ------------------------------------------------------------------ Dart -> native
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "reset" -> { pendingReset = true; result.success(null) }
            "kunci" -> { locked = (call.arguments as? Boolean) ?: true; result.success(null) }
            "ukuran" -> { showDims = (call.arguments as? Boolean) ?: true; result.success(null) }
            "ambilFoto" -> captureResult = result
            else -> result.notImplemented()
        }
    }

    private fun status(code: String) {
        if (code == lastStatus) return
        lastStatus = code
        main.post { if (!disposed) channel.invokeMethod("status", code) }
    }

    // ------------------------------------------------------------------ Session
    private fun startSession() {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) { status("izin"); return }
        try {
            val s = Session(activity)
            val config = Config(s).apply {
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                focusMode = Config.FocusMode.AUTO
                lightEstimationMode = Config.LightEstimationMode.DISABLED
                instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
            }
            s.configure(config)
            session = s
            resumeSession()
        } catch (e: Exception) {
            status("tidak_didukung")
        }
    }

    private fun resumeSession() {
        val s = session ?: return
        if (resumed) return
        try {
            s.resume()
            resumed = true
            glView.onResume()
            status("mencari")
        } catch (e: Exception) {
            status("kamera_gagal")
        }
    }

    private fun pauseSession() {
        if (!resumed) return
        resumed = false
        glView.onPause()
        session?.pause()
    }

    override fun onActivityResumed(a: Activity) { if (a === activity) resumeSession() }
    override fun onActivityPaused(a: Activity) { if (a === activity) pauseSession() }
    override fun onActivityCreated(a: Activity, b: Bundle?) {}
    override fun onActivityStarted(a: Activity) {}
    override fun onActivityStopped(a: Activity) {}
    override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
    override fun onActivityDestroyed(a: Activity) {}

    // ------------------------------------------------------------------ GL
    override fun onSurfaceCreated(gl: GL10?, c: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        val tex = IntArray(4)
        GLES20.glGenTextures(4, tex, 0)
        cameraTex = tex[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTex)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)

        artTex = tex[1]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, artTex)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        artBitmap?.let { GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, it, 0) }
        Log.i(TAG, "tekstur lukisan diunggah: ${artBitmap != null}, glError=${GLES20.glGetError()}")
        labelWTex = tex[2]; labelHTex = tex[3]
        labelWAspect = uploadLabel(labelWTex, "${fmtCm(artW * 100f)} cm")
        labelHAspect = uploadLabel(labelHTex, "${fmtCm(artH * 100f)} cm")

        bgProg = program(
            "attribute vec4 a_Pos; attribute vec2 a_UV; varying vec2 v_UV;" +
                "void main(){ gl_Position=a_Pos; v_UV=a_UV; }",
            "#extension GL_OES_EGL_image_external : require\n" +
                "precision mediump float; varying vec2 v_UV; uniform samplerExternalOES u_Tex;" +
                "void main(){ gl_FragColor=texture2D(u_Tex,v_UV); }",
        )
        texProg = program(
            "attribute vec3 a_Pos; attribute vec2 a_UV; uniform mat4 u_MVP; varying vec2 v_UV;" +
                "void main(){ gl_Position=u_MVP*vec4(a_Pos,1.0); v_UV=a_UV; }",
            "precision mediump float; varying vec2 v_UV; uniform sampler2D u_Tex;" +
                "void main(){ gl_FragColor=texture2D(u_Tex,v_UV); }",
        )
        gradProg = program(
            "attribute vec3 a_Pos; attribute vec4 a_Col; uniform mat4 u_MVP; varying vec4 v_Col;" +
                "void main(){ gl_Position=u_MVP*vec4(a_Pos,1.0); v_Col=a_Col; }",
            "precision mediump float; varying vec4 v_Col; void main(){ gl_FragColor=v_Col; }",
        )
        colProg = program(
            "attribute vec3 a_Pos; uniform mat4 u_MVP;" +
                "void main(){ gl_Position=u_MVP*vec4(a_Pos,1.0); }",
            "precision mediump float; uniform vec4 u_Color;" +
                "void main(){ gl_FragColor=u_Color; }",
        )
        session?.setCameraTextureName(cameraTex)
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        viewW = w; viewH = h
        GLES20.glViewport(0, 0, w, h)
        @Suppress("DEPRECATION")
        val rotation = activity.windowManager.defaultDisplay.rotation
        session?.setDisplayGeometry(rotation, w, h)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return
        if (!resumed) return
        s.setCameraTextureName(cameraTex)

        val frame = try { s.update() } catch (e: Exception) { return }
        if (frame.hasDisplayGeometryChanged()) {
            quadNdc.position(0); quadUv.position(0)
            frame.transformCoordinates2d(
                Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, quadNdc,
                Coordinates2d.TEXTURE_NORMALIZED, quadUv,
            )
        }
        drawBackground()

        val camera = frame.camera
        if (camera.trackingState != TrackingState.TRACKING) {
            status(
                when (camera.trackingFailureReason) {
                    TrackingFailureReason.INSUFFICIENT_FEATURES -> "kurang_fitur"
                    TrackingFailureReason.EXCESSIVE_MOTION -> "terlalu_cepat"
                    TrackingFailureReason.INSUFFICIENT_LIGHT -> "kurang_cahaya"
                    else -> if (anchor != null) "terpasang" else "mencari"
                },
            )
            finishCapture()
            return
        }
        camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        camera.getViewMatrix(viewM, 0)
        Matrix.multiplyMM(vp, 0, proj, 0, viewM, 0)

        if (pendingReset) {
            pendingReset = false
            anchor?.detach(); anchor = null; fixedNormal = null; loggedDraw = false; smoothP = null; smoothN = null
        }

        val verticalPlanes = s.getAllTrackables(Plane::class.java).filter {
            it.trackingState == TrackingState.TRACKING && it.subsumedBy == null &&
                it.type == Plane.Type.VERTICAL
        }

        pendingTap?.let { tap ->
            pendingTap = null
            if (anchor != null && locked) return@let
            Log.i(TAG, "tap (${tap[0]}, ${tap[1]}) bidangVertikal=${verticalPlanes.size}")
            val hit = frame.hitTest(tap[0], tap[1]).firstOrNull {
                val tr = it.trackable
                tr is Plane && tr.type == Plane.Type.VERTICAL && tr.isPoseInPolygon(it.hitPose)
            }
            if (hit != null) {
                Log.i(TAG, "hit bidang dinding -> anchor dibuat")
                anchor?.detach()
                anchor = hit.createAnchor()
                fixedNormal = null
                smoothP = null; smoothN = null
            } else {
                // Cadangan: dinding polos sering tak terdeteksi -> tempel via Instant Placement
                // (jarak awal ~2 m, tegak, menghadap pengguna; ARCore menyempurnakan jaraknya).
                val inst = frame.hitTestInstantPlacement(tap[0], tap[1], 2.0f).firstOrNull()
                Log.i(TAG, "instant placement hit=${inst != null}")
                if (inst != null) {
                    val back = camera.pose.getTransformedAxis(2, 1f)
                    val nh = floatArrayOf(back[0], 0f, back[2])
                    anchor?.detach()
                    anchor = inst.createAnchor()
                    smoothP = null; smoothN = null
                    fixedNormal = if (len(nh) > 1e-3f) norm(nh) else floatArrayOf(0f, 0f, 1f)
                } else {
                    status("tak_kena")
                    lastStatus = "" // supaya status berikutnya tetap terkirim
                }
            }
        }

        val a = anchor
        if (a != null && a.trackingState == TrackingState.TRACKING) {
            if (!loggedDraw) { loggedDraw = true; Log.i(TAG, "menggambar lukisan, pos=${a.pose.translation.toList()} normalTetap=${fixedNormal != null}") }
            drawArtwork(a, camera.pose.translation)
            val ge = GLES20.glGetError()
            if (ge != 0) Log.w(TAG, "glError setelah gambar lukisan: $ge")
            status(if (fixedNormal != null) "terpasang_instan" else "terpasang")
        } else {
            if (a != null) Log.w(TAG, "anchor ada tapi trackingState=${a.trackingState}")
            drawPlanes(verticalPlanes)
            status(if (verticalPlanes.isNotEmpty()) "dinding" else "siap_instan")
        }
        finishCapture()
    }

    private fun drawBackground() {
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(bgProg)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTex)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(bgProg, "u_Tex"), 0)
        val pos = GLES20.glGetAttribLocation(bgProg, "a_Pos")
        val uv = GLES20.glGetAttribLocation(bgProg, "a_UV")
        quadNdc.position(0); quadUv.position(0)
        GLES20.glEnableVertexAttribArray(pos); GLES20.glEnableVertexAttribArray(uv)
        GLES20.glVertexAttribPointer(pos, 2, GLES20.GL_FLOAT, false, 0, quadNdc)
        GLES20.glVertexAttribPointer(uv, 2, GLES20.GL_FLOAT, false, 0, quadUv)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(pos); GLES20.glDisableVertexAttribArray(uv)
    }

    /** Bidang dinding yang terdeteksi, digambar transparan agar pengguna tahu di mana bisa menempel. */
    private fun drawPlanes(planes: List<Plane>) {
        if (planes.isEmpty()) return
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        for (p in planes) {
            val poly = p.polygon
            val n = poly.limit() / 2
            if (n < 3) continue
            val verts = FloatArray((n + 2) * 3)
            val c = p.centerPose.translation
            verts[0] = c[0]; verts[1] = c[1]; verts[2] = c[2]
            for (i in 0..n) {
                val k = i % n
                val w = p.centerPose.transformPoint(floatArrayOf(poly.get(k * 2), 0f, poly.get(k * 2 + 1)))
                verts[(i + 1) * 3] = w[0]; verts[(i + 1) * 3 + 1] = w[1]; verts[(i + 1) * 3 + 2] = w[2]
            }
            drawSolid(verts, GLES20.GL_TRIANGLE_FAN, floatArrayOf(0.35f, 0.75f, 1f, 0.28f))
        }
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    private fun drawArtwork(a: Anchor, camPos: FloatArray) {
        val pose = a.pose
        val pr = pose.translation
        var nr = fixedNormal ?: pose.getTransformedAxis(1, 1f) // sumbu Y bidang = normal dinding
        if (fixedNormal == null) {
            val toCam = floatArrayOf(camPos[0] - pr[0], camPos[1] - pr[1], camPos[2] - pr[2])
            if (dot(nr, toCam) < 0) nr = floatArrayOf(-nr[0], -nr[1], -nr[2])
        }
        // Penghalusan: ARCore terus menyempurnakan pose anchor (terutama Instant Placement). Tanpa filter,
        // koreksi kecil itu tampak sebagai lukisan yang "bergerak sendiri". Filter low-pass membuatnya mulus.
        val sp = smoothP; val sn = smoothN
        val k = 0.12f
        val p = if (sp == null) pr.copyOf() else floatArrayOf(
            sp[0] + (pr[0] - sp[0]) * k, sp[1] + (pr[1] - sp[1]) * k, sp[2] + (pr[2] - sp[2]) * k)
        val n = if (sn == null) norm(nr) else norm(floatArrayOf(
            sn[0] + (nr[0] - sn[0]) * k, sn[1] + (nr[1] - sn[1]) * k, sn[2] + (nr[2] - sn[2]) * k))
        smoothP = p; smoothN = n

        val up = floatArrayOf(0f, 1f, 0f)
        var r = cross(up, n)
        if (len(r) < 1e-4f) r = floatArrayOf(1f, 0f, 0f)
        r = norm(r)
        val u = norm(cross(n, r))

        // titik pada bidang lukisan: x ke kanan, y ke atas (meter dari pusat), off = jarak keluar dari dinding
        fun pt(x: Float, y: Float, off: Float) = floatArrayOf(
            p[0] + r[0] * x + u[0] * y + n[0] * off,
            p[1] + r[1] * x + u[1] * y + n[1] * off,
            p[2] + r[2] * x + u[2] * y + n[2] * off,
        )
        // urutan TRIANGLE_STRIP: kiri-atas, kanan-atas, kiri-bawah, kanan-bawah
        fun rect(hw: Float, hh: Float, off: Float) = pt(-hw, hh, off) + pt(hw, hh, off) + pt(-hw, -hh, off) + pt(hw, -hh, off)
        fun rectAt(cx: Float, cy: Float, hw: Float, hh: Float, off: Float) =
            pt(cx - hw, cy + hh, off) + pt(cx + hw, cy + hh, off) + pt(cx - hw, cy - hh, off) + pt(cx + hw, cy - hh, off)
        fun seg(x1: Float, y1: Float, x2: Float, y2: Float, th: Float, off: Float): FloatArray {
            val dx = x2 - x1; val dy = y2 - y1
            val l = sqrt(dx * dx + dy * dy).coerceAtLeast(1e-6f)
            val mx = -dy / l * th / 2; val my = dx / l * th / 2
            return pt(x1 + mx, y1 + my, off) + pt(x1 - mx, y1 - my, off) + pt(x2 + mx, y2 + my, off) + pt(x2 - mx, y2 - my, off)
        }

        val hw = artW / 2; val hh = artH / 2
        // Bingkai, bayangan, garis ukuran & label dibuat PROPORSIONAL terhadap ukuran lukisan. Dulu konstan
        // (bingkai 5,6 cm per sisi, label 4-8 cm): pada lukisan kecil (mis. 40 cm) bingkai saja menambah ~28% lebar
        // dan anotasinya tampak jauh lebih besar daripada lukisannya. Sisi terkecil dipakai sebagai acuan.
        val minDim = min(artW, artH)
        val mat = (minDim * 0.022f).coerceIn(0.006f, 0.014f)
        val trim = (minDim * 0.008f).coerceIn(0.003f, 0.006f)
        val wood = (minDim * 0.045f).coerceIn(0.012f, 0.030f)
        val extra = mat + trim + wood

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

        // bayangan lembut di dinding (bergeser sedikit ke bawah-kanan) supaya bingkai terasa menempel & bervolume
        run {
            val sh = (minDim * 0.1f).coerceIn(0.03f, 0.07f) // sebaran bayangan
            val sx = hw + extra + sh; val sy = hh + extra + sh
            val ox = sh * 0.12f; val oy = -sh * 0.19f
            val e = 0.0004f
            val v = pt(ox, oy, e) + pt(-sx + ox, sy + oy, e) + pt(sx + ox, sy + oy, e) +
                pt(sx + ox, -sy + oy, e) + pt(-sx + ox, -sy + oy, e) + pt(-sx + ox, sy + oy, e)
            val c = floatArrayOf(0f, 0f, 0f, 0.55f) +
                floatArrayOf(0f, 0f, 0f, 0f) + floatArrayOf(0f, 0f, 0f, 0f) + floatArrayOf(0f, 0f, 0f, 0f) +
                floatArrayOf(0f, 0f, 0f, 0f) + floatArrayOf(0f, 0f, 0f, 0f)
            drawGradient(v, c, GLES20.GL_TRIANGLE_FAN)
        }
        // bingkai kayu: rim terang -> badan gelap -> list emas -> passe-partout krem -> lukisan
        drawSolid(rect(hw + extra, hh + extra, 0.0008f), GLES20.GL_TRIANGLE_STRIP, floatArrayOf(0.37f, 0.24f, 0.15f, 1f))
        drawSolid(rect(hw + extra - 0.006f, hh + extra - 0.006f, 0.0010f), GLES20.GL_TRIANGLE_STRIP, floatArrayOf(0.24f, 0.15f, 0.10f, 1f))
        drawSolid(rect(hw + mat + trim, hh + mat + trim, 0.0012f), GLES20.GL_TRIANGLE_STRIP, floatArrayOf(0.86f, 0.63f, 0.17f, 1f))
        drawSolid(rect(hw + mat, hh + mat, 0.0016f), GLES20.GL_TRIANGLE_STRIP, floatArrayOf(0.96f, 0.94f, 0.89f, 1f))
        drawSolid(rect(hw + 0.003f, hh + 0.003f, 0.0018f), GLES20.GL_TRIANGLE_STRIP, floatArrayOf(0f, 0f, 0f, 0.35f)) // bayangan dalam passe-partout
        drawTextured(rect(hw, hh, 0.0022f), artTex)
        // kilau tipis di pojok kiri-atas (kaca bingkai)
        drawGradient(rect(hw, hh, 0.0026f),
            floatArrayOf(1f, 1f, 1f, 0.16f, 1f, 1f, 1f, 0f, 1f, 1f, 1f, 0f, 1f, 1f, 1f, 0f), GLES20.GL_TRIANGLE_STRIP)

        if (showDims) {
            val gold = floatArrayOf(0.99f, 0.78f, 0.25f, 1f)
            val fy = hh + extra; val fx = hw + extra
            val gap = (minDim * 0.06f).coerceIn(0.03f, 0.05f)
            val th = (minDim * 0.006f).coerceIn(0.002f, 0.003f)
            val o = 0.0030f
            val ext = gap * 0.3f // garis bantu melewati garis ukuran sedikit
            val yL = -(fy + gap); val xL = fx + gap
            // garis ukuran lebar (di bawah) + garis bantu dari tepi lukisan
            drawSolid(seg(-hw, yL, hw, yL, th, o), GLES20.GL_TRIANGLE_STRIP, gold)
            drawSolid(seg(-hw, -fy, -hw, yL - ext, th * 0.7f, o), GLES20.GL_TRIANGLE_STRIP, gold)
            drawSolid(seg(hw, -fy, hw, yL - ext, th * 0.7f, o), GLES20.GL_TRIANGLE_STRIP, gold)
            // garis ukuran tinggi (di kanan)
            drawSolid(seg(xL, -hh, xL, hh, th, o), GLES20.GL_TRIANGLE_STRIP, gold)
            drawSolid(seg(fx, -hh, xL + ext, -hh, th * 0.7f, o), GLES20.GL_TRIANGLE_STRIP, gold)
            drawSolid(seg(fx, hh, xL + ext, hh, th * 0.7f, o), GLES20.GL_TRIANGLE_STRIP, gold)
            // label angka (sejajar dinding, menghadap depan); tingginya ikut ukuran lukisan
            val lh = (minDim * 0.1f).coerceIn(0.03f, 0.055f)
            drawTextured(rectAt(0f, yL, lh / 2 * labelWAspect, lh / 2, 0.0036f), labelWTex)
            drawTextured(rectAt(xL, 0f, lh / 2 * labelHAspect, lh / 2, 0.0036f), labelHTex)
        }
        GLES20.glDisable(GLES20.GL_BLEND)

        // jarak kamera -> lukisan (untuk panel ukuran di Flutter), dikirim ~3x per detik
        val now = System.currentTimeMillis()
        if (now - lastJarakMs > 330) {
            lastJarakMs = now
            val dx = camPos[0] - p[0]; val dy = camPos[1] - p[1]; val dz = camPos[2] - p[2]
            val d = sqrt(dx * dx + dy * dy + dz * dz).toDouble()
            main.post { if (!disposed) channel.invokeMethod("jarak", d) }
        }
    }

    private fun fmtCm(v: Float): String {
        val bulat = v.roundToInt().toFloat()
        return if (kotlin.math.abs(v - bulat) < 0.05f) bulat.toInt().toString() else String.format(java.util.Locale("id"), "%.1f", v)
    }

    /** Lencana angka ukuran (cokelat tua + garis emas) -> tekstur. Mengembalikan rasio lebar/tinggi. */
    private fun uploadLabel(tex: Int, text: String): Float {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE; textSize = 56f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.CENTER
        }
        val h = 96
        val w = (paint.measureText(text) + 72f).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), h / 2f, h / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(235, 62, 37, 30) })
        c.drawRoundRect(RectF(3f, 3f, w - 3f, h - 3f), h / 2f - 3f, h / 2f - 3f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = 5f; color = Color.rgb(219, 161, 44)
        })
        c.drawText(text, w / 2f, h / 2f + paint.textSize * 0.35f, paint)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
        val aspect = w.toFloat() / h
        bmp.recycle()
        return aspect
    }

    private fun drawGradient(verts: FloatArray, cols: FloatArray, mode: Int) {
        GLES20.glUseProgram(gradProg)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(gradProg, "u_MVP"), 1, false, vp, 0)
        val pos = GLES20.glGetAttribLocation(gradProg, "a_Pos")
        val col = GLES20.glGetAttribLocation(gradProg, "a_Col")
        GLES20.glEnableVertexAttribArray(pos); GLES20.glEnableVertexAttribArray(col)
        GLES20.glVertexAttribPointer(pos, 3, GLES20.GL_FLOAT, false, 0, floatBufferOf(*verts))
        GLES20.glVertexAttribPointer(col, 4, GLES20.GL_FLOAT, false, 0, floatBufferOf(*cols))
        GLES20.glDrawArrays(mode, 0, verts.size / 3)
        GLES20.glDisableVertexAttribArray(pos); GLES20.glDisableVertexAttribArray(col)
    }

    private fun drawSolid(verts: FloatArray, mode: Int, color: FloatArray) {
        GLES20.glUseProgram(colProg)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(colProg, "u_MVP"), 1, false, vp, 0)
        GLES20.glUniform4fv(GLES20.glGetUniformLocation(colProg, "u_Color"), 1, color, 0)
        val pos = GLES20.glGetAttribLocation(colProg, "a_Pos")
        val fb = floatBufferOf(*verts)
        GLES20.glEnableVertexAttribArray(pos)
        GLES20.glVertexAttribPointer(pos, 3, GLES20.GL_FLOAT, false, 0, fb)
        GLES20.glDrawArrays(mode, 0, verts.size / 3)
        GLES20.glDisableVertexAttribArray(pos)
    }

    private fun drawTextured(verts: FloatArray, texId: Int) {
        GLES20.glUseProgram(texProg)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(texProg, "u_MVP"), 1, false, vp, 0)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(texProg, "u_Tex"), 0)
        val pos = GLES20.glGetAttribLocation(texProg, "a_Pos")
        val uv = GLES20.glGetAttribLocation(texProg, "a_UV")
        val fbPos = floatBufferOf(*verts)
        // bitmap diunggah dgn baris atas di t=0 -> kiri-atas (0,0)
        val fbUv = floatBufferOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)
        GLES20.glEnableVertexAttribArray(pos); GLES20.glEnableVertexAttribArray(uv)
        GLES20.glVertexAttribPointer(pos, 3, GLES20.GL_FLOAT, false, 0, fbPos)
        GLES20.glVertexAttribPointer(uv, 2, GLES20.GL_FLOAT, false, 0, fbUv)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(pos); GLES20.glDisableVertexAttribArray(uv)
    }

    // ------------------------------------------------------------------ Ambil foto
    private fun finishCapture() {
        val res = captureResult ?: return
        captureResult = null
        try {
            val buf = ByteBuffer.allocateDirect(viewW * viewH * 4).order(ByteOrder.nativeOrder())
            GLES20.glReadPixels(0, 0, viewW, viewH, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf)
            val raw = Bitmap.createBitmap(viewW, viewH, Bitmap.Config.ARGB_8888)
            raw.copyPixelsFromBuffer(buf)
            val m = android.graphics.Matrix().apply { preScale(1f, -1f) }
            val flipped = Bitmap.createBitmap(raw, 0, 0, viewW, viewH, m, false)
            val file = File(activity.cacheDir, "galeria_ar_${System.currentTimeMillis()}.jpg")
            file.outputStream().use { flipped.compress(Bitmap.CompressFormat.JPEG, 92, it) }
            main.post { res.success(file.absolutePath) }
        } catch (e: Exception) {
            main.post { res.error("FOTO_GAGAL", e.message, null) }
        }
    }

    // ------------------------------------------------------------------ util
    private fun program(vs: String, fs: String): Int {
        fun sh(type: Int, src: String): Int {
            val id = GLES20.glCreateShader(type)
            GLES20.glShaderSource(id, src); GLES20.glCompileShader(id)
            return id
        }
        val p = GLES20.glCreateProgram()
        GLES20.glAttachShader(p, sh(GLES20.GL_VERTEX_SHADER, vs))
        GLES20.glAttachShader(p, sh(GLES20.GL_FRAGMENT_SHADER, fs))
        GLES20.glLinkProgram(p)
        return p
    }

    private fun decode(bytes: ByteArray, maxSide: Int): Bitmap? {
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, o)
        var sample = 1
        while (max(o.outWidth, o.outHeight) / sample > maxSide) sample *= 2
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
            BitmapFactory.Options().apply { inSampleSize = sample })
    }

    private fun floatBufferOf(vararg v: Float): FloatBuffer =
        ByteBuffer.allocateDirect(v.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()
            .apply { put(v); position(0) }

    private fun dot(a: FloatArray, b: FloatArray) = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
    private fun cross(a: FloatArray, b: FloatArray) = floatArrayOf(
        a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
    private fun len(a: FloatArray) = sqrt(dot(a, a))
    private fun norm(a: FloatArray): FloatArray { val l = len(a); return floatArrayOf(a[0] / l, a[1] / l, a[2] / l) }
}
