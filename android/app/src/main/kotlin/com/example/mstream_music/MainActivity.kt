package com.example.mstream_music

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.StatFs
import android.provider.OpenableColumns
import android.provider.Settings
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
    // A torrent that arrived by intent and hasn't been handed to Dart yet.
    // Always staged here rather than pushed: on a cold start Dart isn't
    // listening yet, and staging + an explicit drain means one delivery in
    // both cases instead of a race between a push and a pull.
    private var pendingTorrent: Map<String, Any?>? = null
    private var torrentChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureTorrentIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Keep getIntent() current — anything later that re-reads it should see
        // the intent that actually brought us forward.
        setIntent(intent)
        if (captureTorrentIntent(intent)) {
            // Warm start: Dart is already up, so tell it to come and drain.
            torrentChannel?.invokeMethod("torrentWaiting", null)
        }
    }

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

        torrentChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mstream/torrent")
        torrentChannel!!
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Open Android's own "open by default" screen for us.
                    // We can't set the default ourselves — only the user can —
                    // so the most an app may do is take them there.
                    "openDefaultSettings" -> result.success(openDefaultSettings())
                    // Drain whatever arrived by intent. Returns null when
                    // nothing is waiting, which is the normal launch case.
                    "getInitialTorrent" -> {
                        result.success(pendingTorrent)
                        pendingTorrent = null
                    }
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

    private fun openDefaultSettings(): Boolean {
        val uri = Uri.fromParts("package", packageName, null)
        val candidates = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            candidates.add(Intent(Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS, uri))
        }
        // Every device has the app-details page and it carries the same
        // controls one step deeper — the fallback for pre-12, and for OEM
        // builds (Samsung among them) where the direct screen doesn't resolve.
        candidates.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri))
        for (intent in candidates) {
            try {
                startActivity(intent)
                return true
            } catch (e: Exception) {
                android.util.Log.w("torrent", "settings screen unavailable: ${'$'}{intent.action}")
            }
        }
        return false
    }

    /// Pull a torrent out of an incoming intent, if it carries one. Returns
    /// true when something was staged.
    ///
    /// Marks the intent consumed rather than trusting that onCreate and
    /// onNewIntent can never see the same one — a re-delivered intent adding
    /// the same torrent twice is the failure mode worth spending an extra to
    /// rule out.
    private fun captureTorrentIntent(intent: Intent?): Boolean {
        if (intent == null || intent.getBooleanExtra(CONSUMED, false)) return false
        intent.putExtra(CONSUMED, true)

        val payload: Map<String, Any?>? = when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return false
                if (uri.scheme.equals("magnet", ignoreCase = true)) {
                    mapOf("magnet" to uri.toString())
                } else {
                    readTorrent(uri)
                }
            }
            Intent.ACTION_SEND -> {
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                }
                // A shared magnet arrives as text, not a stream.
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
                when {
                    uri != null -> readTorrent(uri)
                    text != null && text.startsWith("magnet:", ignoreCase = true) ->
                        mapOf("magnet" to text)
                    else -> null
                }
            }
            else -> null
        }

        if (payload == null) return false
        pendingTorrent = payload
        return true
    }

    /// Read a .torrent's bytes plus its display name. Null on anything we
    /// can't read or that is too big to be a torrent — a torrent is tens of
    /// KB, so a large file here is a mistake or an attack, not a torrent, and
    /// it would cross the method channel into Dart's heap.
    private fun readTorrent(uri: Uri): Map<String, Any?>? = try {
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
        when {
            bytes == null || bytes.isEmpty() -> null
            bytes.size > MAX_TORRENT_BYTES -> {
                android.util.Log.w("torrent", "ignoring ${bytes.size}-byte intent payload")
                null
            }
            else -> mapOf("bytes" to bytes, "filename" to displayName(uri))
        }
    } catch (e: Exception) {
        android.util.Log.w("torrent", "unreadable intent uri", e)
        null
    }

    private fun displayName(uri: Uri): String? {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c ->
                    if (c.moveToFirst() && !c.isNull(0)) return c.getString(0)
                }
        } catch (e: Exception) {
            // Providers are allowed to refuse the query; the path is a fine
            // fallback and the user can rename the destination anyway.
        }
        return uri.lastPathSegment?.substringAfterLast('/')
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
        const val CONSUMED = "mstream.torrentConsumed"

        // Torrents are tens of KB. 8 MB is far past any real one and still
        // safe to hold twice (here and across the channel).
        const val MAX_TORRENT_BYTES = 8 * 1024 * 1024
    }
}
