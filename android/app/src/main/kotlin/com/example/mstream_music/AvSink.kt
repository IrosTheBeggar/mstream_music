package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import java.nio.ByteBuffer

/**
 * Where [VisualizerTranscoder]'s encoded H.264 + AAC samples are written.
 *
 * Two implementations: [Mp4Sink] (one MP4 via MediaMuxer — the on-phone spike)
 * and [TsHlsSink] (live MPEG-TS/HLS segments — for casting to a renderer).
 *
 * Call order: [init] once, then [onVideoFormat]/[onAudioFormat] (each fires
 * before that stream's first sample), [writeVideo]/[writeAudio] as samples
 * arrive, and [finish] at the end. [finish] returns the playable output (a file
 * path for MP4, the `.m3u8` path for HLS).
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

/**
 * MediaMuxer → single MP4. MediaMuxer can't start until every track's format is
 * known, so samples produced before then are buffered and flushed on start.
 * (Behaviourally identical to the inline muxing the transcoder used before the
 * AvSink refactor.)
 */
class Mp4Sink(private val outputPath: String) : AvSink {
    private val muxer =
        MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var audioEnabled = false
    private var videoTrack = -1
    private var audioTrack = -1
    private var videoFormat: MediaFormat? = null
    private var audioFormat: MediaFormat? = null
    private var started = false
    private val pending = ArrayList<Sample>()

    private class Sample(
        val isVideo: Boolean,
        val bytes: ByteArray,
        val ptsUs: Long,
        val flags: Int,
    )

    override fun init(audioEnabled: Boolean) {
        this.audioEnabled = audioEnabled
    }

    override fun onVideoFormat(format: MediaFormat) {
        videoFormat = format
        maybeStart()
    }

    override fun onAudioFormat(format: MediaFormat) {
        audioFormat = format
        maybeStart()
    }

    private fun maybeStart() {
        if (started) return
        val vf = videoFormat ?: return
        if (audioEnabled && audioFormat == null) return
        videoTrack = muxer.addTrack(vf)
        audioFormat?.let { audioTrack = muxer.addTrack(it) }
        muxer.start()
        started = true
        flushPending()
    }

    override fun writeVideo(buffer: ByteBuffer, info: MediaCodec.BufferInfo) =
        write(true, buffer, info)

    override fun writeAudio(buffer: ByteBuffer, info: MediaCodec.BufferInfo) =
        write(false, buffer, info)

    private fun write(isVideo: Boolean, buf: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (info.size <= 0) return
        if (started) {
            val track = if (isVideo) videoTrack else audioTrack
            if (track >= 0) muxer.writeSampleData(track, buf, info)
        } else {
            val bytes = ByteArray(info.size)
            buf.position(info.offset)
            buf.get(bytes, 0, info.size)
            pending.add(Sample(isVideo, bytes, info.presentationTimeUs, info.flags))
        }
    }

    private fun flushPending() {
        val info = MediaCodec.BufferInfo()
        for (s in pending) {
            val track = if (s.isVideo) videoTrack else audioTrack
            if (track < 0) continue
            info.set(0, s.bytes.size, s.ptsUs, s.flags)
            muxer.writeSampleData(track, ByteBuffer.wrap(s.bytes), info)
        }
        pending.clear()
    }

    override fun finish(): String {
        maybeStart()
        flushPending()
        if (started) {
            try { muxer.stop() } catch (_: Throwable) {}
        }
        try { muxer.release() } catch (_: Throwable) {}
        return outputPath
    }
}
