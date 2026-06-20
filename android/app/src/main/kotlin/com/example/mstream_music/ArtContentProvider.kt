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
// permission. openFile only fetches the http(s) /album-art/ endpoint of a host
// the user has actually configured (checked against servers.json), so the
// exported provider can't be turned into an arbitrary-URL fetch / SSRF gadget.
// Mirrors Google's UAMP AlbumArtContentProvider (which embeds the URL the same
// way).
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
            // The provider is exported, so only ever fetch a host the user has
            // actually configured — refuse an arbitrary attacker-chosen host
            // (defense-in-depth: a legit art URL's host always equals one of the
            // user's server origins). A non-configured host is never downloaded
            // and so can never be cached; a cache hit below was already allowed.
            val match = lookupArtHost(r.host)
            if (!match.configured) return null
            try {
                download(remote, cacheFile, match.selfSigned)
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

    private fun download(remote: String, dest: File, selfSigned: Boolean) {
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
        // host is a server the user marked "allow self-signed" (selfSigned), so a
        // valid-cert server's art (and the token in its URL) keeps a validated
        // connection. No-op in the play flavor.
        if (conn is HttpsURLConnection && selfSigned) {
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

    // Whether [host] belongs to a configured mStream server, and if so whether
    // the user marked any server on that host "allow self-signed". Read once from
    // the app's persisted servers.json (app_flutter == context.getDir("flutter")).
    // `configured` gates the exported provider to the user's own server origins;
    // `selfSigned` gates the per-connection trust-all to opted-in hosts. Host-only
    // match (port-blind), matching the app's self-signed model. Best-effort: a
    // read/parse error → (false, false), i.e. refuse + validate (fail closed).
    private data class ArtHost(val configured: Boolean, val selfSigned: Boolean)

    private fun lookupArtHost(host: String?): ArtHost {
        if (host.isNullOrEmpty()) return ArtHost(false, false)
        return try {
            val dir = context!!.getDir("flutter", Context.MODE_PRIVATE)
            val file = File(dir, "servers.json")
            if (!file.exists()) return ArtHost(false, false)
            val servers = JSONArray(file.readText())
            var configured = false
            var selfSigned = false
            for (i in 0 until servers.length()) {
                val s = servers.optJSONObject(i) ?: continue
                if (Uri.parse(s.optString("url", "")).host
                        .equals(host, ignoreCase = true)) {
                    configured = true
                    if (s.optBoolean("allowSelfSigned", false)) selfSigned = true
                }
            }
            ArtHost(configured, selfSigned)
        } catch (e: Exception) {
            ArtHost(false, false)
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
