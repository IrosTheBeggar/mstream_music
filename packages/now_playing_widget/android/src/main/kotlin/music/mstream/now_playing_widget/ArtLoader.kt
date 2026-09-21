package music.mstream.now_playing_widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

/**
 * Album art for the widget: fetched through the app's own ArtContentProvider
 * (`content://<applicationId>.art/art?u=<remote>`), which already handles the
 * download, the on-disk cache, the configured-host check and the full
 * flavor's self-signed trust — so the widget never re-implements a fetch.
 * The decoded cover is capped at [MAX_PX] and filed under the snapshot's
 * art key, so a re-render after process death (launcher restart, reboot)
 * loads it from disk without Dart, and a token rotation is a cache hit.
 */
object ArtLoader {
    private const val TAG = "NowPlayingWidget"
    /** Big enough for the tall layout's cover at xxxhdpi, small enough to keep
     *  every RemoteViews update well under the launcher's bitmap budget. */
    const val MAX_PX = 512
    private const val DIR = "now_playing_widget"
    /** Covers kept on disk (the latest plus a few for a back-and-forth skip). */
    private const val KEEP = 6

    fun cached(context: Context, key: String): File? =
        if (key.isEmpty()) null else File(dir(context), "$key.jpg").takeIf { it.length() > 0 }

    /** Blocking: fetch + decode + file [url] under its key. Null when the art is unavailable. */
    fun fetch(context: Context, url: String): File? {
        val key = NowPlayingSnapshot.keyFor(url)
        cached(context, key)?.let { return it }
        val bitmap = try {
            decode(context, url)
        } catch (e: Exception) {
            // Scheme + host only: the query carries the session token.
            val u = Uri.parse(url)
            Log.w(TAG, "art fetch failed for ${u.scheme}://${u.host}: ${e.javaClass.simpleName}")
            null
        } ?: return null
        val dest = File(dir(context), "$key.jpg")
        val tmp = File.createTempFile("art", ".tmp", dest.parentFile)
        try {
            FileOutputStream(tmp).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 88, it) }
            if (!dest.exists()) tmp.renameTo(dest)
        } finally {
            if (tmp.exists()) tmp.delete()
            bitmap.recycle()
        }
        prune(context, keep = dest)
        return dest.takeIf { it.length() > 0 }
    }

    /** The cover on disk as a bitmap with rounded corners, or null. */
    fun load(file: File, cornerRadiusPx: Float): Bitmap? {
        val raw = BitmapFactory.decodeFile(file.path) ?: return null
        return try {
            rounded(raw, cornerRadiusPx)
        } finally {
            raw.recycle()
        }
    }

    private fun decode(context: Context, url: String): Bitmap? {
        // Bounds pass, then a sampled decode: covers can be full-size scans.
        // (A bounds-only decode returns no bitmap by design — only the stream
        // itself decides whether there is anything to decode.)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        val probe = open(context, url) ?: return null
        probe.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= MAX_PX && bounds.outHeight / (sample * 2) >= MAX_PX) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap = open(context, url)?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
        if (bitmap.width <= MAX_PX && bitmap.height <= MAX_PX) return bitmap
        val scale = MAX_PX.toFloat() / maxOf(bitmap.width, bitmap.height)
        val scaled = Bitmap.createScaledBitmap(
            bitmap, (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1), true,
        )
        if (scaled !== bitmap) bitmap.recycle()
        return scaled
    }

    private fun open(context: Context, url: String): InputStream? {
        val uri = Uri.parse(url)
        return when (uri.scheme?.lowercase()) {
            "content" -> context.contentResolver.openInputStream(uri)
            "file" -> uri.path?.let { File(it).takeIf(File::exists)?.inputStream() }
            "http", "https" -> {
                // The app's ArtContentProvider: same process, so this is a
                // plain (blocking) call into its openFile.
                val wrapped = Uri.Builder()
                    .scheme("content")
                    .authority("${context.packageName}.art")
                    .path("art")
                    .appendQueryParameter("u", url)
                    .build()
                context.contentResolver.openInputStream(wrapped)
            }
            else -> null
        }
    }

    private fun rounded(src: Bitmap, radius: Float): Bitmap {
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        Canvas(out).drawRoundRect(
            RectF(0f, 0f, src.width.toFloat(), src.height.toFloat()), radius, radius, paint,
        )
        return out
    }

    private fun dir(context: Context): File = File(context.cacheDir, DIR).apply { mkdirs() }

    private fun prune(context: Context, keep: File) {
        val files = dir(context).listFiles { f -> f.name.endsWith(".jpg") } ?: return
        files.filter { it != keep }
            .sortedByDescending { it.lastModified() }
            .drop(KEEP - 1)
            .forEach { it.delete() }
    }
}
