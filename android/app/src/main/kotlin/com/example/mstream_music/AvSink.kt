package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaFormat
import java.nio.ByteBuffer

/**
 * Where [VisualizerTranscoder]'s encoded H.264 + AAC samples are written.
 * Implemented by [TsHlsSink], which writes live MPEG-TS/HLS segments to cast.
 *
 * Call order: [init] once, then [onVideoFormat]/[onAudioFormat] (each fires
 * before that stream's first sample), [writeVideo]/[writeAudio] as samples
 * arrive, and [finish] at the end. [finish] returns the playable output (the
 * `.m3u8` path for HLS).
 */
interface AvSink {
    /** [audioEnabled] = false → video-only output (no audio track). */
    fun init(audioEnabled: Boolean)
    fun onVideoFormat(format: MediaFormat)
    fun onAudioFormat(format: MediaFormat)
    fun writeVideo(buffer: ByteBuffer, info: MediaCodec.BufferInfo)
    fun writeAudio(buffer: ByteBuffer, info: MediaCodec.BufferInfo)
    fun finish(): String
}
