package com.example.mstream_music

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.net.Socket
import java.security.KeyStore
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLEngine
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManager
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509ExtendedTrustManager
import javax.net.ssl.X509TrustManager

// FULL (sideload) flavor ONLY.
//
// just_audio streams through ExoPlayer, which uses the native
// HttpsURLConnection TLS stack — NOT Dart's HttpClient — so a Dart-side
// badCertificateCallback can't make self-signed *streaming* work. The only
// hook into that stack is the process-default SSLSocketFactory / hostname
// verifier, but swapping in a blanket trust-all there would also disable
// validation for every OTHER host (other servers with valid certs, and
// background_downloader transfers, which use the same stack).
//
// So the swap installs a DELEGATING trust manager + verifier scoped to the
// hosts the user explicitly opted into via "Allow self-signed" (synced from
// the Dart side over the `mstream/insecure_tls` channel): those hosts skip
// validation, every other host is handed to the untouched platform trust
// manager / verifier. Handshakes with no resolvable peer host fail closed
// (platform validation). With no opted-in hosts the platform defaults are
// restored untouched.
//
// This is deliberately absent from the `play` source set — a non-validating
// X509TrustManager in the binary trips Google Play's unsafe-TLS scan even
// when unused, which is the whole reason this lives behind the flavor split.
object InsecureTls {
    private var originalFactory: SSLSocketFactory? = null
    private var originalVerifier: HostnameVerifier? = null
    private var installed = false

    // Hosts (lowercased) whose self-signed certs the user accepted. Read from
    // TLS handshake threads, replaced wholesale from the channel handler.
    @Volatile
    private var allowedHosts: Set<String> = emptySet()

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "mstream/insecure_tls")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAllowedHosts" -> {
                        setAllowedHosts(
                            call.argument<List<String>>("hosts") ?: emptyList())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isAllowed(host: String?): Boolean =
        host != null && allowedHosts.contains(host.lowercase())

    // The untouched platform trust manager — every host NOT opted in is
    // validated by exactly what the system would have used.
    private val platformTrustManager: X509TrustManager by lazy {
        val tmf =
            TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
        tmf.init(null as KeyStore?)
        tmf.trustManagers.filterIsInstance<X509TrustManager>().first()
    }

    // Accepts any chain for opted-in hosts; delegates everything else to the
    // platform trust manager. The host comes from the in-flight handshake
    // (socket / engine peer host); overloads with no host context validate
    // normally, so unknown callers fail closed rather than open.
    private val scopedTrustManager: X509ExtendedTrustManager by lazy {
        object : X509ExtendedTrustManager() {
            private val ext get() = platformTrustManager as? X509ExtendedTrustManager

            override fun checkServerTrusted(
                chain: Array<X509Certificate>?, authType: String?, socket: Socket?
            ) {
                if (isAllowed((socket as? SSLSocket)?.handshakeSession?.peerHost)) return
                ext?.checkServerTrusted(chain, authType, socket)
                    ?: platformTrustManager.checkServerTrusted(chain, authType)
            }

            override fun checkServerTrusted(
                chain: Array<X509Certificate>?, authType: String?, engine: SSLEngine?
            ) {
                if (isAllowed(engine?.peerHost)) return
                ext?.checkServerTrusted(chain, authType, engine)
                    ?: platformTrustManager.checkServerTrusted(chain, authType)
            }

            override fun checkServerTrusted(
                chain: Array<X509Certificate>?, authType: String?
            ) {
                platformTrustManager.checkServerTrusted(chain, authType)
            }

            override fun checkClientTrusted(
                chain: Array<X509Certificate>?, authType: String?, socket: Socket?
            ) {
                ext?.checkClientTrusted(chain, authType, socket)
                    ?: platformTrustManager.checkClientTrusted(chain, authType)
            }

            override fun checkClientTrusted(
                chain: Array<X509Certificate>?, authType: String?, engine: SSLEngine?
            ) {
                ext?.checkClientTrusted(chain, authType, engine)
                    ?: platformTrustManager.checkClientTrusted(chain, authType)
            }

            override fun checkClientTrusted(
                chain: Array<X509Certificate>?, authType: String?
            ) {
                platformTrustManager.checkClientTrusted(chain, authType)
            }

            override fun getAcceptedIssuers(): Array<X509Certificate> =
                platformTrustManager.acceptedIssuers
        }
    }

    @Synchronized
    private fun setAllowedHosts(hosts: List<String>) {
        allowedHosts = hosts.map { it.lowercase() }.toSet()
        if (allowedHosts.isEmpty()) {
            // Nothing opted in — put the platform defaults back untouched.
            if (installed) {
                originalFactory?.let { HttpsURLConnection.setDefaultSSLSocketFactory(it) }
                originalVerifier?.let { HttpsURLConnection.setDefaultHostnameVerifier(it) }
                installed = false
            }
            return
        }
        if (installed) return // delegators already in place; the new set is live

        originalFactory = HttpsURLConnection.getDefaultSSLSocketFactory()
        originalVerifier = HttpsURLConnection.getDefaultHostnameVerifier()

        val ctx = SSLContext.getInstance("TLS")
        ctx.init(null, arrayOf<TrustManager>(scopedTrustManager), SecureRandom())
        HttpsURLConnection.setDefaultSSLSocketFactory(ctx.socketFactory)

        val fallback = originalVerifier
        HttpsURLConnection.setDefaultHostnameVerifier(
            HostnameVerifier { hostname, session ->
                isAllowed(hostname) || (fallback?.verify(hostname, session) ?: false)
            })
        installed = true
    }

    // ── Album-art ContentProvider TLS ──
    // The art provider runs headless on the Android Auto cold-bind, where
    // MainActivity never installed the delegating swap above, so it can't
    // rely on it. applyArtTls trusts a SINGLE provider connection so a
    // self-signed server's browse art loads; the provider calls it only for
    // hosts the user marked "allow self-signed", so valid-cert servers (and the
    // token in their art URL) keep a validated connection. All the permissive
    // TLS lives here in the full source set (the play stub is a no-op), so the
    // play binary stays clean for Google Play's unsafe-TLS scan.
    private val artFactory: SSLSocketFactory by lazy {
        val trustAll = arrayOf<TrustManager>(object : X509TrustManager {
            override fun checkClientTrusted(c: Array<X509Certificate>?, a: String?) {}
            override fun checkServerTrusted(c: Array<X509Certificate>?, a: String?) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        })
        val ctx = SSLContext.getInstance("TLS")
        ctx.init(null, trustAll, SecureRandom())
        ctx.socketFactory
    }

    fun applyArtTls(conn: HttpsURLConnection) {
        conn.sslSocketFactory = artFactory
        conn.hostnameVerifier = HostnameVerifier { _, _ -> true }
    }
}
