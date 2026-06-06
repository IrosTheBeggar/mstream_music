package com.example.mstream_music

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

// FULL (sideload) flavor ONLY.
//
// just_audio streams through ExoPlayer, which uses the native
// HttpsURLConnection TLS stack — NOT Dart's HttpClient — so a Dart-side
// badCertificateCallback can't make self-signed *streaming* work. This installs
// a trust-all default SSLSocketFactory + hostname verifier so ExoPlayer will
// stream from a server with a self-signed cert.
//
// It's OFF unless the user enables "Allow self-signed" for a server: the Dart
// side toggles it via the `mstream/insecure_tls` channel. It is deliberately
// absent from the `play` source set — a trust-all X509TrustManager in the
// binary trips Google Play's unsafe-TLS scan even when unused, which is the
// whole reason this lives behind the flavor split.
object InsecureTls {
    private var originalFactory: SSLSocketFactory? = null
    private var originalVerifier: HostnameVerifier? = null
    private var enabled = false

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "mstream/insecure_tls")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        setEnabled(call.argument<Boolean>("enabled") == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Synchronized
    private fun setEnabled(on: Boolean) {
        if (on == enabled) return
        if (on) {
            if (originalFactory == null) {
                originalFactory = HttpsURLConnection.getDefaultSSLSocketFactory()
                originalVerifier = HttpsURLConnection.getDefaultHostnameVerifier()
            }
            val trustAll = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(c: Array<X509Certificate>?, a: String?) {}
                override fun checkServerTrusted(c: Array<X509Certificate>?, a: String?) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            })
            val ctx = SSLContext.getInstance("TLS")
            ctx.init(null, trustAll, SecureRandom())
            HttpsURLConnection.setDefaultSSLSocketFactory(ctx.socketFactory)
            HttpsURLConnection.setDefaultHostnameVerifier(HostnameVerifier { _, _ -> true })
        } else {
            originalFactory?.let { HttpsURLConnection.setDefaultSSLSocketFactory(it) }
            originalVerifier?.let { HttpsURLConnection.setDefaultHostnameVerifier(it) }
        }
        enabled = on
    }
}
