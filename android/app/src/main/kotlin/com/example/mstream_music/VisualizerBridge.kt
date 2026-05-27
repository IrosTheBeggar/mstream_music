// Kotlin half of the visualizer bridge. Owns the SurfaceTexture +
// render thread; defers actual EGL/projectM work to libvisualizer_bridge.so
// via JNI (see android/app/src/main/cpp/visualizer_bridge.cpp).
//
// Communicates with Dart over a single MethodChannel:
//   create({width, height})  -> returns textureId for Texture widget
//   addPcm({samples: Float32List})
//   dispose()
//
// Lifecycle: created once when the FlutterEngine attaches the plugin.
// `create` may be called multiple times if the user opens/closes the
// visualizer screen; each create tears down the previous render thread
// first to keep at most one active context.

package com.example.mstream_music

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.ConcurrentLinkedQueue

private const val TAG = "mstream/viz"
private const val CHANNEL = "mstream/visualizer"

class VisualizerBridge : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        init { System.loadLibrary("visualizer_bridge") }
    }

    // JNI methods — implemented in visualizer_bridge.cpp.
    private external fun nativeInit(surface: Surface, width: Int, height: Int): Long
    private external fun nativeRenderFrame(ctxPtr: Long)
    private external fun nativeAddPcm(ctxPtr: Long, samples: FloatArray)
    private external fun nativeDispose(ctxPtr: Long)

    private var channel: MethodChannel? = null
    private var registry: TextureRegistry? = null

    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var renderThread: RenderThread? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        registry = binding.textureRegistry
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        Log.i(TAG, "plugin attached")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        teardown()
        channel?.setMethodCallHandler(null)
        channel = null
        registry = null
        Log.i(TAG, "plugin detached")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> handleCreate(call, result)
            "addPcm" -> handleAddPcm(call, result)
            "dispose" -> {
                teardown()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleCreate(call: MethodCall, result: MethodChannel.Result) {
        val width = (call.argument<Int>("width") ?: 0).coerceAtLeast(1)
        val height = (call.argument<Int>("height") ?: 0).coerceAtLeast(1)
        val reg = registry
        if (reg == null) {
            result.error("not_attached", "TextureRegistry unavailable", null)
            return
        }

        teardown()

        val entry = reg.createSurfaceTexture()
        val st = entry.surfaceTexture()
        st.setDefaultBufferSize(width, height)
        val surface = Surface(st)

        val thread = RenderThread(
            surface = surface,
            width = width,
            height = height,
            initFn = ::nativeInit,
            renderFn = ::nativeRenderFrame,
            addPcmFn = ::nativeAddPcm,
            disposeFn = ::nativeDispose,
        ).also { it.start() }

        textureEntry = entry
        renderThread = thread

        result.success(entry.id())
        Log.i(TAG, "create: textureId=${entry.id()} ${width}x${height}")
    }

    private fun handleAddPcm(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<Any>("samples")
        val samples = when (raw) {
            is FloatArray -> raw
            is DoubleArray -> FloatArray(raw.size) { raw[it].toFloat() }
            else -> {
                result.success(null)
                return
            }
        }
        renderThread?.enqueuePcm(samples)
        result.success(null)
    }

    private fun teardown() {
        renderThread?.shutdown()
        renderThread = null
        textureEntry?.release()
        textureEntry = null
    }
}

/**
 * Dedicated render thread. Owns the EGL context (via the native side)
 * for its entire lifetime; all projectM calls happen on this thread.
 * PCM samples are enqueued from arbitrary threads (the MethodChannel
 * callback) and drained on the render thread between frames.
 */
private class RenderThread(
    private val surface: Surface,
    private val width: Int,
    private val height: Int,
    private val initFn: (Surface, Int, Int) -> Long,
    private val renderFn: (Long) -> Unit,
    private val addPcmFn: (Long, FloatArray) -> Unit,
    private val disposeFn: (Long) -> Unit,
) : Thread("mstream-visualizer-render") {

    @Volatile private var running = true
    private val pcmQueue = ConcurrentLinkedQueue<FloatArray>()
    private val frameNanos = 1_000_000_000L / 60L // ~16.67 ms

    fun enqueuePcm(samples: FloatArray) {
        pcmQueue.offer(samples)
        // Cap backlog so a paused render thread doesn't OOM.
        while (pcmQueue.size > 8) pcmQueue.poll()
    }

    fun shutdown() {
        running = false
        try {
            join(1000)
        } catch (e: InterruptedException) {
            Log.w(TAG, "join interrupted", e)
        }
    }

    override fun run() {
        val ctx = initFn(surface, width, height)
        if (ctx == 0L) {
            Log.e(TAG, "nativeInit returned 0 — render thread exiting")
            return
        }
        Log.i(TAG, "render thread started, ctx=$ctx")
        try {
            var lastFrame = System.nanoTime()
            while (running) {
                drainPcm(ctx)
                renderFn(ctx)
                lastFrame += frameNanos
                val sleep = lastFrame - System.nanoTime()
                if (sleep > 0) {
                    try {
                        sleep(sleep / 1_000_000L, (sleep % 1_000_000L).toInt())
                    } catch (_: InterruptedException) {
                        // wake — re-check `running`
                    }
                } else {
                    // Behind schedule; reset the baseline so we don't
                    // spin-render forever after a hiccup.
                    lastFrame = System.nanoTime()
                }
            }
        } finally {
            disposeFn(ctx)
            Log.i(TAG, "render thread exited")
        }
    }

    private fun drainPcm(ctx: Long) {
        var batch = pcmQueue.poll()
        while (batch != null) {
            addPcmFn(ctx, batch)
            batch = pcmQueue.poll()
        }
    }
}
