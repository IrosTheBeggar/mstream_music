package com.example.mstream_music

import io.flutter.plugin.common.BinaryMessenger
import javax.net.ssl.HttpsURLConnection

// PLAY flavor: intentionally a no-op.
//
// The Play build never enables insecure TLS — the Dart side gates on
// isPlayBuild and never invokes the channel — and we keep ALL trust-all TLS
// code out of the Play binary so Google Play's security scan (which flags
// non-validating X509TrustManagers statically, even if unused) has nothing to
// catch. The real implementation lives in the `full` source set.
object InsecureTls {
    fun register(messenger: BinaryMessenger) {
        // No channel registered: the Play build has no insecure-TLS capability.
    }

    // The play build validates all TLS — including the album-art provider's
    // downloads — so this is a no-op, and no trust-all code enters the play
    // binary. The real implementation lives in the `full` source set.
    fun applyArtTls(conn: HttpsURLConnection) {
        // Intentionally empty: play always validates.
    }
}
