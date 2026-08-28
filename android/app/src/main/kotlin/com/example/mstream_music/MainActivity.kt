package com.example.mstream_music

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.StatFs
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Extends AudioServiceActivity (from the audio_service pub package) so
// the media session / foreground notification plumbing still works,
// while giving us a place to register our in-app native plugins.
//
// The manifest must point at this class instead of
// com.ryanheise.audioservice.AudioServiceActivity directly.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the app Context with the iroh native lib (ndk_context) before
        // any tunnel call. Guarded so a missing/unloadable .so never blocks boot
        // (the feature just stays unavailable).
        try {
            IrohNative.ensureInit(this)
        } catch (e: Throwable) {
            android.util.Log.w("IrohNative", "iroh native init failed: ${e.message}")
        }

        flutterEngine.plugins.add(VisualizerBridge())

        // Flavor-specific: full installs the self-signed/insecure-TLS bridge for
        // ExoPlayer streaming; play provides a no-op (see src/<flavor>/kotlin).
        InsecureTls.register(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mstream/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Free bytes on the volume holding `path`, for the
                    // storage-migration pre-check (no pure-Dart API).
                    "freeBytes" -> {
                        val p = call.argument<String>("path")
                        try {
                            result.success(StatFs(p).availableBytes)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    // Start/stop a foreground service that keeps the process
                    // alive while a background file move runs (so it survives
                    // the app being backgrounded). Failures are non-fatal —
                    // the move proceeds regardless.
                    "startMove" -> {
                        try {
                            val i = Intent(this, MigrationService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(i)
                            } else {
                                startService(i)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stopMove" -> {
                        try {
                            stopService(Intent(this, MigrationService::class.java))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mstream/torrent")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Hand a picked .torrent off to another app instead of
                    // adding it to an mStream server. Returns which chooser was
                    // shown so Dart can say something useful: "view" (a real
                    // torrent client is installed), "send" (none is, so the
                    // share sheet), or "none" (nothing at all can take it).
                    "openWith" -> {
                        try {
                            result.success(
                                passOffTorrent(
                                    call.argument<ByteArray>("bytes"),
                                    call.argument<String>("filename")
                                )
                            )
                        } catch (e: Exception) {
                            android.util.Log.w("torrent", "pass-off failed", e)
                            result.success("error")
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun passOffTorrent(bytes: ByteArray?, filename: String?): String {
        if (bytes == null || bytes.isEmpty()) return "error"

        val dir = File(cacheDir, "torrents").apply { mkdirs() }
        // Keep exactly one staged file. The previous hand-off is done with, and
        // a torrent the user never opened has no business lingering in a
        // directory we hand read grants on.
        dir.listFiles()?.forEach { it.delete() }

        // The name reaches the receiving app, and it lands on a filesystem —
        // strip anything that could traverse or confuse either.
        val cleaned = (filename ?: "download.torrent")
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .takeLast(120)
            .trimStart('.')
        val safe = if (cleaned.endsWith(".torrent")) cleaned else "$cleaned.torrent"
        val file = File(dir, if (safe == ".torrent") "download.torrent" else safe)
        file.writeBytes(bytes)

        val uri = FileProvider.getUriForFile(this, "$packageName.torrents", file)
        val self = ComponentName(this, MainActivity::class.java)

        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, TORRENT_MIME)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        // Anyone but us who claims ACTION_VIEW on a torrent — i.e. an actual
        // torrent client. Needs the <queries> manifest block on API 30+.
        val viewers = packageManager.queryIntentActivities(view, 0)
            .filter { it.activityInfo.packageName != packageName }

        val send = Intent(Intent.ACTION_SEND)
            .setType(TORRENT_MIME)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        val outcome: String
        val target: Intent
        if (viewers.isNotEmpty()) {
            outcome = "view"
            target = view
        } else {
            val senders = packageManager.queryIntentActivities(send, 0)
                .filter { it.activityInfo.packageName != packageName }
            if (senders.isEmpty()) return "none"
            outcome = "send"
            target = send
        }

        startActivity(
            Intent.createChooser(target, null).apply {
                // Keep ourselves out of our own chooser — the user is here
                // precisely because they don't want mStream to take it.
                putExtra(Intent.EXTRA_EXCLUDE_COMPONENTS, arrayOf(self))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        )
        return outcome
    }

    private companion object {
        const val TORRENT_MIME = "application/x-bittorrent"
    }
}
