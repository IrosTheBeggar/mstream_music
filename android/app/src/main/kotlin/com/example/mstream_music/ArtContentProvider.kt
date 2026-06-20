package com.example.mstream_music

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

// Serves remote album art to Android Auto as a content:// URI.
//
// Android Auto's media browser cannot load a remote https artUri for browse
// items (it logs "Invalid album art uri"); it only loads local content:// /
// android.resource:// URIs. So browse MediaItems carry
//   content://<applicationId>.art/art?u=<url-encoded remote art URL>
// and this provider downloads + caches the bytes locally in openFile(), which
// the Auto process (gearhead, a separate uid) opens via ContentResolver. The
// provider is exported so that cross-process open is allowed — the
// MediaBrowserService framework does NOT auto-grant browse-item icon URI
// permission — and openFile is scheme-guarded to http(s) so an exported,
// arbitrary-URL fetcher can't be abused. Mirrors Google's UAMP
// AlbumArtContentProvider (which embeds the URL the same way).
//
// Self-signed-cert servers (full flavor) won't load here — the download uses a
// validating HttpURLConnection — but those items simply stay art-less (they
// already had no browse art), so it's no regression. Valid-cert servers get art.
class ArtContentProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        val remote = uri.getQueryParameter("u") ?: return null
        // This provider is exported (Android Auto runs in a separate process),
        // so any app can call it. Only ever fetch the mStream album-art endpoint
        // over http(s) — refusing other schemes/paths stops it being used as a
        // file:// local-read or a general SSRF / open-proxy gadget.
        val r = Uri.parse(remote)
        val scheme = r.scheme?.lowercase()
        if ((scheme != "http" && scheme != "https") ||
            r.path?.contains("/album-art/") != true) {
            return null
        }
        val cacheFile = cacheFileFor(remote)
        if (!cacheFile.exists() || cacheFile.length() == 0L) {
            try {
                download(remote, cacheFile)
            } catch (e: Exception) {
                // Leave the file absent; a missing art uri is handled by Auto.
            }
        }
        if (!cacheFile.exists() || cacheFile.length() == 0L) return null
        return ParcelFileDescriptor.open(
            cacheFile, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    // Cache key is the STABLE part of the URL (host + path + the compress size),
    // ignoring the per-request token / app_uuid, so rotating tokens don't keep
    // re-downloading the same cover.
    private fun cacheFileFor(remote: String): File {
        val u = Uri.parse(remote)
        val key = (u.host ?: "") + (u.path ?: "") +
            "?compress=" + (u.getQueryParameter("compress") ?: "")
        val dir = File(context!!.cacheDir, "auto_art").apply { mkdirs() }
        return File(dir, md5(key) + ".img")
    }

    private fun download(remote: String, dest: File) {
        val conn = (URL(remote).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 15000
            instanceFollowRedirects = true
        }
        try {
            if (conn.responseCode !in 200..299) return
            val tmp = File.createTempFile("art", ".tmp", dest.parentFile)
            try {
                conn.inputStream.use { input ->
                    FileOutputStream(tmp).use { out -> input.copyTo(out) }
                }
                // Another thread may have finished first; only the first wins.
                if (!dest.exists()) tmp.renameTo(dest)
            } finally {
                if (tmp.exists()) tmp.delete()
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun md5(s: String): String =
        MessageDigest.getInstance("MD5").digest(s.toByteArray())
            .joinToString("") { "%02x".format(it) }

    // openFile is the only entry point this provider serves.
    override fun getType(uri: Uri): String = "image/jpeg"

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(
        uri: Uri, selection: String?, selectionArgs: Array<out String>?
    ): Int = 0

    override fun update(
        uri: Uri, values: ContentValues?, selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0
}
