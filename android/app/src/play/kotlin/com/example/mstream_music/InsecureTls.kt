package com.example.mstream_music

import io.flutter.plugin.common.BinaryMessenger

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
}
