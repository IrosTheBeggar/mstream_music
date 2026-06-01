package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaFormat
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.util.Locale
import kotlin.math.ceil

/**
 * [AvSink] that writes the H.264 + AAC streams as **MPEG-TS / HLS**: a series of
 * `.ts` segments (each starting at a keyframe with PAT/PMT) plus an `index.m3u8`
 * playlist in [dir]. Hand-written because Android has no live TS muxer.
 *
 * This first cut writes a complete VOD playlist (ENDLIST on [finish]); the
 * transcoder runs to completion before the playlist is cast. Making it a *live*
 * (incrementally-written, cast-while-growing) playlist is a follow-up — this
 * step exists to validate the muxer + Chromecast HLS playback.
 *
 * Assumes the video has no B-frames (PTS == DTS), which holds for our encoder.
 */
class TsHlsSink(private val dir: String) : AvSink {

    private var audioEnabled = false
    private var spsPps: ByteArray? = null // SPS+PPS in Annex-B, from video csd-0
    private var adtsFreqIndex = 4 // 44100
    private var adtsChannelConfig = 2

    // Continuity counters are per-PID (4-bit, wrapping). Single-element arrays so
    // the packet writer can mutate them by reference.
    private val patCc = intArrayOf(0)
    private val pmtCc = intArrayOf(0)
    private val videoCc = intArrayOf(0)
    private val audioCc = intArrayOf(0)

    private var patSection: ByteArray = ByteArray(0)
    private var pmtSection: ByteArray = ByteArray(0)

    private var seg: OutputStream? = null
    private var segName: String? = null
    private var segIndex = 0
    private var segStartUs = 0L
    private var lastVideoUs = 0L
    private val segments = ArrayList<Pair<String, Double>>() // name, duration (s)
    // Audio (pts90, ADTS+AAC) produced before the first segment opens; flushed
    // into it so audio and video both start near PTS 0.
    private val pendingAudio = ArrayList<Pair<Long, ByteArray>>()
    // H.264 Access Unit Delimiter (NAL type 9). The Cast receiver's TS
    // transmuxer (mux.js) uses AUDs to find access-unit boundaries; MediaCodec
    // doesn't emit them, so prepend one to every frame.
    private val audNal = byteArrayOf(0, 0, 0, 1, 9, 0xF0.toByte())
    // Scratch buffer for one 188-byte TS packet, reused across writePes calls
    // (the muxer runs on a single thread) — at 1080p this avoids ~6k packet
    // allocations/sec (~16k at 4K). Every byte is overwritten per packet.
    private val tsPacket = ByteArray(188)

    override fun init(audioEnabled: Boolean) {
        this.audioEnabled = audioEnabled
        val d = File(dir)
        d.mkdirs()
        // Clear leftovers from a previous run: a shorter new track would
        // otherwise leave the old track's higher-index segments on disk (unused
        // but wasting space). Only our own outputs, never anything else here.
        d.listFiles()?.forEach { f ->
            val n = f.name
            if (n.endsWith(".ts") || n == PLAYLIST || n == "$PLAYLIST.tmp") {
                try { f.delete() } catch (_: Throwable) {}
            }
        }
        patSection = buildPat()
        pmtSection = buildPmt()
    }

    override fun onVideoFormat(format: MediaFormat) {
        // For AVC, MediaCodec splits the codec config across csd-0 (SPS) and
        // csd-1 (PPS) — both Annex-B with start codes. Concatenate BOTH; missing
        // the PPS leaves the decoder unable to decode (symptom: the receiver
        // fetches every segment but never starts playback).
        val out = ByteArrayOutputStream()
        for (key in arrayOf("csd-0", "csd-1")) {
            val buf = format.getByteBuffer(key) ?: continue
            val a = ByteArray(buf.remaining())
            buf.get(a)
            out.write(a)
        }
        if (out.size() > 0) spsPps = out.toByteArray()
    }

    override fun onAudioFormat(format: MediaFormat) {
        if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            adtsFreqIndex = freqIndex(format.getInteger(MediaFormat.KEY_SAMPLE_RATE))
        }
        if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            adtsChannelConfig = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        }
    }

    override fun writeVideo(buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (info.size <= 0) return
        val keyframe = (info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
        val ptsUs = info.presentationTimeUs
        if (keyframe && (seg == null || ptsUs - segStartUs >= TARGET_SEG_US)) {
            rotate(ptsUs)
        }
        val s = seg ?: return // wait for the first keyframe to open a segment
        val frame = bytesOf(buffer, info)
        val pts90 = ptsUs * 9 / 100 // µs → 90 kHz
        // Access unit = [AUD][SPS][PPS][IDR] on keyframes / [AUD][slice] otherwise.
        // AUD lets the receiver's transmuxer find AU boundaries; SPS/PPS on every
        // keyframe keeps each segment independently decodable (decoders tolerate
        // repeats). Passed as parts so we don't allocate a combined frame array.
        val sps = if (keyframe) spsPps else null
        val pes = if (sps != null) buildPes(0xE0, pts90, pts90, audNal, sps, frame)
        else buildPes(0xE0, pts90, pts90, audNal, frame)
        writePes(s, VIDEO_PID, videoCc, pes, pts90)
        lastVideoUs = ptsUs
    }

    override fun writeAudio(buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (info.size <= 0) return
        val raw = bytesOf(buffer, info)
        val es = adtsHeader(raw.size) + raw
        val pts90 = info.presentationTimeUs * 9 / 100
        val s = seg
        if (s == null) {
            // The video encoder has more latency than the audio encoder, so
            // audio is ready before the first keyframe opens a segment. Buffer
            // it instead of dropping it, so the first segment's audio and video
            // both start near PTS 0 (else the receiver stalls on misaligned A/V).
            pendingAudio.add(Pair(pts90, es))
            // Defensive: if no keyframe ever opens a segment (video wedged), don't
            // grow without bound — keep only the most recent frames.
            while (pendingAudio.size > MAX_PENDING_AUDIO) pendingAudio.removeAt(0)
            return
        }
        writePes(s, AUDIO_PID, audioCc, buildPes(0xC0, pts90, null, es), null)
    }

    override fun finish(): String {
        closeSegment(lastVideoUs)
        writePlaylist(ended = true)
        return File(dir, PLAYLIST).absolutePath
    }

    // Rewrite the playlist with the segments so far. Written incrementally (per
    // segment) as an EVENT playlist — append-only, the player starts at the
    // first segment and re-reads for new ones until ENDLIST. This is what makes
    // it live: the receiver can start while the transcode is still running.
    private fun writePlaylist(ended: Boolean) {
        val target = ceil(segments.maxOfOrNull { it.second } ?: 3.0).toInt().coerceAtLeast(1)
        val sb = StringBuilder()
        sb.append("#EXTM3U\n")
        sb.append("#EXT-X-VERSION:3\n")
        sb.append("#EXT-X-TARGETDURATION:$target\n")
        sb.append("#EXT-X-MEDIA-SEQUENCE:0\n")
        sb.append("#EXT-X-PLAYLIST-TYPE:EVENT\n")
        for ((name, dur) in segments) {
            sb.append(String.format(Locale.US, "#EXTINF:%.3f,\n", dur))
            sb.append(name).append('\n')
        }
        if (ended) sb.append("#EXT-X-ENDLIST\n")
        // Write to a temp file then rename so a polling reader never sees a
        // half-written playlist.
        val tmp = File(dir, "$PLAYLIST.tmp")
        tmp.writeText(sb.toString())
        tmp.renameTo(File(dir, PLAYLIST))
    }

    // ── segmenting ──

    private fun rotate(ptsUs: Long) {
        closeSegment(ptsUs)
        val name = "seg$segIndex.ts"
        segIndex++
        val s = BufferedOutputStream(FileOutputStream(File(dir, name)))
        // PAT + PMT at the head of every segment so it's independently playable.
        writeSection(s, PAT_PID, patCc, patSection)
        writeSection(s, PMT_PID, pmtCc, pmtSection)
        seg = s
        segName = name
        segStartUs = ptsUs
        // Flush audio that arrived before this (first) segment opened.
        if (pendingAudio.isNotEmpty()) {
            for ((pts90, es) in pendingAudio) {
                writePes(s, AUDIO_PID, audioCc, buildPes(0xC0, pts90, null, es), null)
            }
            pendingAudio.clear()
        }
    }

    private fun closeSegment(endUs: Long) {
        val s = seg ?: return
        try { s.flush(); s.close() } catch (_: Throwable) {}
        val dur = (endUs - segStartUs) / 1_000_000.0
        segments.add(Pair(segName!!, if (dur > 0.05) dur else 2.0))
        seg = null
        writePlaylist(ended = false) // publish the just-completed segment
    }

    // ── PES / TS packetization ──

    // [esParts] are concatenated as the PES payload — passed as parts (e.g.
    // AUD + SPS/PPS + frame) so callers don't allocate a combined ES array.
    private fun buildPes(streamId: Int, pts90: Long, dts90: Long?, vararg esParts: ByteArray): ByteArray {
        var esLen = 0
        for (p in esParts) esLen += p.size
        val out = ByteArrayOutputStream(esLen + 19)
        out.write(0x00); out.write(0x00); out.write(0x01) // start code prefix
        out.write(streamId)
        val ptsDtsBytes = if (dts90 != null) 10 else 5
        // PES_packet_length: video uses 0 (unbounded — frames can exceed 64 KB);
        // audio carries its real length.
        val pesLen = if (streamId == 0xE0) 0 else (3 + ptsDtsBytes + esLen)
        out.write((pesLen ushr 8) and 0xFF); out.write(pesLen and 0xFF)
        out.write(0x80) // '10' marker, no scrambling/priority flags
        out.write(if (dts90 != null) 0xC0 else 0x80) // PTS+DTS or PTS-only flag
        out.write(ptsDtsBytes) // PES_header_data_length
        if (dts90 != null) {
            out.write(encodeTs(pts90, 0x3))
            out.write(encodeTs(dts90, 0x1))
        } else {
            out.write(encodeTs(pts90, 0x2))
        }
        for (p in esParts) out.write(p)
        return out.toByteArray()
    }

    // 5-byte PTS/DTS field with the given 4-bit prefix nibble.
    private fun encodeTs(value: Long, prefix: Int): ByteArray {
        val v = value and 0x1FFFFFFFFL
        return byteArrayOf(
            (((prefix and 0xF) shl 4) or (((v ushr 30).toInt() and 0x7) shl 1) or 1).toByte(),
            ((v ushr 22) and 0xFF).toByte(),
            ((((v ushr 15) and 0x7F) shl 1) or 1).toByte(),
            ((v ushr 7) and 0xFF).toByte(),
            (((v and 0x7F) shl 1) or 1).toByte(),
        )
    }

    // Emit [pes] as 188-byte TS packets on [pid]. The first packet sets PUSI; if
    // [pcr90] != null it carries a PCR in its adaptation field; the last packet
    // is padded with an adaptation-field stuffing region to fill 188.
    private fun writePes(out: OutputStream, pid: Int, cc: IntArray, pes: ByteArray, pcr90: Long?) {
        var pos = 0
        var first = true
        val pkt = tsPacket // reused; every byte below is overwritten per packet
        while (pos < pes.size) {
            pkt[0] = 0x47
            pkt[1] = (((if (first) 0x40 else 0x00)) or ((pid ushr 8) and 0x1F)).toByte()
            pkt[2] = (pid and 0xFF).toByte()
            val counter = cc[0] and 0x0F
            cc[0] = (cc[0] + 1) and 0x0F

            val remaining = pes.size - pos
            val wantPcr = first && pcr90 != null
            val afControl: Int
            if (!wantPcr && remaining >= 184) {
                afControl = 0x1 // payload only
                System.arraycopy(pes, pos, pkt, 4, 184)
                pos += 184
            } else {
                afControl = 0x3 // adaptation field + payload
                val pcrBytes = if (wantPcr) 6 else 0
                val maxPayload = 184 - (2 + pcrBytes) // after af_length + flags + pcr
                val payload = minOf(remaining, maxPayload)
                val stuffing = maxPayload - payload
                var i = 4
                pkt[i++] = (1 + pcrBytes + stuffing).toByte() // adaptation_field_length
                var flags = 0
                if (wantPcr) flags = flags or 0x50 // PCR_flag(0x10) + random_access(0x40)
                pkt[i++] = flags.toByte()
                if (wantPcr) {
                    val base = pcr90!! and 0x1FFFFFFFFL
                    pkt[i++] = ((base ushr 25) and 0xFF).toByte()
                    pkt[i++] = ((base ushr 17) and 0xFF).toByte()
                    pkt[i++] = ((base ushr 9) and 0xFF).toByte()
                    pkt[i++] = ((base ushr 1) and 0xFF).toByte()
                    pkt[i++] = (((base and 0x1L) shl 7) or 0x7E).toByte() // +reserved, ext hi=0
                    pkt[i++] = 0x00 // PCR ext low
                }
                repeat(stuffing) { pkt[i++] = 0xFF.toByte() } // stuffing bytes
                System.arraycopy(pes, pos, pkt, i, payload)
                pos += payload
            }
            pkt[3] = (((afControl and 0x3) shl 4) or counter).toByte()
            out.write(pkt) // BufferedOutputStream copies immediately, so reuse is safe
            first = false
        }
    }

    // Write a PSI section (PAT/PMT) as a single TS packet (small enough to fit).
    private fun writeSection(out: OutputStream, pid: Int, cc: IntArray, section: ByteArray) {
        val pkt = ByteArray(188) { 0xFF.toByte() }
        pkt[0] = 0x47
        pkt[1] = (0x40 or ((pid ushr 8) and 0x1F)).toByte() // PUSI=1
        pkt[2] = (pid and 0xFF).toByte()
        pkt[3] = (0x10 or (cc[0] and 0x0F)).toByte() // payload only
        cc[0] = (cc[0] + 1) and 0x0F
        pkt[4] = 0x00 // pointer_field
        System.arraycopy(section, 0, pkt, 5, section.size)
        out.write(pkt)
    }

    // ── PSI tables ──

    private fun buildPat(): ByteArray {
        val body = ByteArrayOutputStream()
        body.write(0x00); body.write(0x01) // transport_stream_id = 1
        body.write(0xC1) // reserved(11) + version(0) + current_next(1)
        body.write(0x00); body.write(0x00) // section_number, last_section_number
        body.write(0x00); body.write(0x01) // program_number = 1
        body.write(0xE0 or ((PMT_PID ushr 8) and 0x1F)) // reserved(111) + PMT PID hi
        body.write(PMT_PID and 0xFF)
        return wrapSection(0x00, body.toByteArray())
    }

    private fun buildPmt(): ByteArray {
        val body = ByteArrayOutputStream()
        body.write(0x00); body.write(0x01) // program_number = 1
        body.write(0xC1)
        body.write(0x00); body.write(0x00)
        body.write(0xE0 or ((VIDEO_PID ushr 8) and 0x1F)) // PCR_PID = video
        body.write(VIDEO_PID and 0xFF)
        body.write(0xF0); body.write(0x00) // program_info_length = 0
        // video ES: stream_type 0x1B (AVC)
        body.write(0x1B)
        body.write(0xE0 or ((VIDEO_PID ushr 8) and 0x1F)); body.write(VIDEO_PID and 0xFF)
        body.write(0xF0); body.write(0x00)
        if (audioEnabled) {
            // audio ES: stream_type 0x0F (AAC ADTS)
            body.write(0x0F)
            body.write(0xE0 or ((AUDIO_PID ushr 8) and 0x1F)); body.write(AUDIO_PID and 0xFF)
            body.write(0xF0); body.write(0x00)
        }
        return wrapSection(0x02, body.toByteArray())
    }

    // Prepend table_id + section_length header and append the MPEG CRC-32.
    private fun wrapSection(tableId: Int, body: ByteArray): ByteArray {
        val sectionLength = body.size + 4 // + CRC
        val head = ByteArrayOutputStream()
        head.write(tableId)
        head.write(0xB0 or ((sectionLength ushr 8) and 0x0F)) // syntax(1)+0+reserved(11)+len hi
        head.write(sectionLength and 0xFF)
        head.write(body)
        val arr = head.toByteArray()
        val crc = Crc32Mpeg.compute(arr, 0, arr.size)
        val out = ByteArrayOutputStream()
        out.write(arr)
        out.write((crc ushr 24) and 0xFF); out.write((crc ushr 16) and 0xFF)
        out.write((crc ushr 8) and 0xFF); out.write(crc and 0xFF)
        return out.toByteArray()
    }

    // ── ADTS ──

    private fun adtsHeader(frameLen: Int): ByteArray {
        val full = frameLen + 7
        val profile = 1 // AAC-LC (audio object type 2 → ADTS profile 1)
        return byteArrayOf(
            0xFF.toByte(),
            0xF1.toByte(), // MPEG-4, layer 0, protection_absent = 1
            (((profile and 0x3) shl 6) or ((adtsFreqIndex and 0xF) shl 2) or
                ((adtsChannelConfig ushr 2) and 0x1)).toByte(),
            ((((adtsChannelConfig and 0x3) shl 6)) or ((full ushr 11) and 0x3)).toByte(),
            ((full ushr 3) and 0xFF).toByte(),
            (((full and 0x7) shl 5) or 0x1F).toByte(),
            0xFC.toByte(),
        )
    }

    private fun bytesOf(buf: ByteBuffer, info: MediaCodec.BufferInfo): ByteArray {
        val b = ByteArray(info.size)
        buf.position(info.offset)
        buf.get(b, 0, info.size)
        return b
    }

    private fun freqIndex(rate: Int): Int = when (rate) {
        96000 -> 0; 88200 -> 1; 64000 -> 2; 48000 -> 3; 44100 -> 4; 32000 -> 5
        24000 -> 6; 22050 -> 7; 16000 -> 8; 12000 -> 9; 11025 -> 10; 8000 -> 11
        7350 -> 12; else -> 4
    }

    companion object {
        private const val PAT_PID = 0x0000
        private const val PMT_PID = 0x1000
        private const val VIDEO_PID = 0x0100
        private const val AUDIO_PID = 0x0101
        private const val TARGET_SEG_US = 2_000_000L
        private const val PLAYLIST = "index.m3u8"
        // Cap pre-first-segment audio buffering (~256 AAC frames ≈ 6 s) so a
        // wedged video encoder can't grow it without bound.
        private const val MAX_PENDING_AUDIO = 256
    }
}

/** MPEG CRC-32 (poly 0x04C11DB7, init 0xFFFFFFFF, MSB-first) for PSI sections. */
private object Crc32Mpeg {
    private val table = IntArray(256)

    init {
        for (i in 0 until 256) {
            var c = i shl 24
            for (j in 0 until 8) {
                c = if ((c and 0x80000000.toInt()) != 0) (c shl 1) xor 0x04C11DB7 else c shl 1
            }
            table[i] = c
        }
    }

    fun compute(data: ByteArray, start: Int, end: Int): Int {
        var crc = -1 // 0xFFFFFFFF
        for (i in start until end) {
            crc = (crc shl 8) xor table[((crc ushr 24) xor (data[i].toInt() and 0xFF)) and 0xFF]
        }
        return crc
    }
}
