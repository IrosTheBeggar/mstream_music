package com.example.mstream_music

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import javax.net.ssl.HttpsURLConnection
import org.json.JSONArray

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
// Self-signed-cert servers (full flavor) are supported: download() trusts a
// single art connection when its host is a server the user marked "allow
// self-signed" (read from servers.json), so a valid-cert server's art — and the
// session token in its URL — still goes over a validated connection. The play
// flavor always validates (InsecureTls.applyArtTls is a no-op there).
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
            // No redirects: the mStream /album-art endpoint serves the image
            // directly, and following a redirect on this exported, URL-driven
            // fetch would let a chosen endpoint bounce the request onward. A 3xx
            // then falls through the responseCode check below as "no art".
            instanceFollowRedirects = false
        }
        // Self-signed servers (full flavor): the headless Auto provider has no
        // access to the app's global trust-all swap (MainActivity never ran on a
        // cold service bind), so trust this ONE connection — but only when the
        // host is a server the user marked "allow self-signed", so a valid-cert
        // server's art (and the token in its URL) keeps a validated connection.
        // No-op in the play flavor.
        if (conn is HttpsURLConnection &&
            isSelfSignedArtHost(Uri.parse(remote).host)) {
            InsecureTls.applyArtTls(conn)
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

    // True when the art URL's host belongs to a configured server the user
    // marked "allow self-signed". Read from the app's persisted servers.json
    // (app_flutter == context.getDir("flutter")) so the headless provider gates
    // the per-connection trust-all to exactly the opted-in hosts. Best-effort:
    // any read/parse error → false (validate).
    private fun isSelfSignedArtHost(host: String?): Boolean {
        if (host.isNullOrEmpty()) return false
        return try {
            val dir = context!!.getDir("flutter", Context.MODE_PRIVATE)
            val file = File(dir, "servers.json")
            if (!file.exists()) return false
            val servers = JSONArray(file.readText())
            (0 until servers.length()).any { i ->
                val s = servers.optJSONObject(i)
                s != null && s.optBoolean("allowSelfSigned", false) &&
                    Uri.parse(s.optString("url", "")).host
                        .equals(host, ignoreCase = true)
            }
        } catch (e: Exception) {
            false
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
