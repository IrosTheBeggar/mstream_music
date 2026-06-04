package com.example.mstream_music

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayOutputStream

/**
 * Pure-JVM unit tests for the hand-written MPEG-TS / PES / ADTS / PSI byte
 * encoding in [TsHlsSink]. Android has no live TS muxer, so this code is written
 * from scratch — these tests are its safety net for spec-compliance.
 *
 * They exercise only the bit-level packing, which has no Android dependencies
 * (no MediaCodec/MediaFormat), so they run under plain `testDebugUnitTest` with
 * just JUnit on the classpath. Each PSI section's CRC and each timestamp field
 * is checked against an independent reference implementation, so a transcription
 * slip in the production encoder can't pass by matching itself.
 */
class TsHlsSinkTest {
    @get:Rule
    val tmp = TemporaryFolder()

    // A real (empty) temp dir is enough for init() — it only touches java.io.File.
    private fun newSink(audioEnabled: Boolean = true): TsHlsSink {
        val sink = TsHlsSink(tmp.newFolder().absolutePath)
        sink.init(audioEnabled)
        return sink
    }

    private fun u(b: Byte): Int = b.toInt() and 0xFF

    // Reference MPEG CRC-32 (bit-at-a-time; poly 0x04C11DB7, init 0xFFFFFFFF,
    // MSB-first, no final XOR) — an independent take on the table-driven one.
    private fun refCrc(data: ByteArray): Int {
        var crc = -1 // 0xFFFFFFFF
        for (byte in data) {
            crc = crc xor (u(byte) shl 24)
            repeat(8) {
                crc = if (crc and 0x80000000.toInt() != 0) (crc shl 1) xor 0x04C11DB7
                else crc shl 1
            }
        }
        return crc
    }

    // The trailing 4 bytes of a PSI section are the MPEG CRC-32 over everything
    // before them — verify with the independent reference.
    private fun assertCrcTrailer(section: ByteArray) {
        val body = section.copyOfRange(0, section.size - 4)
        val stored = (u(section[section.size - 4]) shl 24) or
            (u(section[section.size - 3]) shl 16) or
            (u(section[section.size - 2]) shl 8) or
            u(section[section.size - 1])
        assertEquals(refCrc(body), stored)
    }

    @Test
    fun crc32MatchesIndependentImplementation() {
        val samples = listOf(
            byteArrayOf(0x00, 0x01, 0xC1.toByte(), 0x00, 0x00),
            "the quick brown fox".toByteArray(),
            ByteArray(0),
            ByteArray(256) { it.toByte() },
        )
        for (s in samples) {
            assertEquals(refCrc(s), Crc32Mpeg.compute(s, 0, s.size))
        }
    }

    @Test
    fun encodeTsRoundTrips() {
        val sink = newSink()
        val pts = 5_000_000_000L // exercises the top (33rd) bit
        val b = sink.encodeTs(pts, 0x2)
        assertEquals(5, b.size)
        assertEquals(0x2, u(b[0]) ushr 4)        // prefix nibble
        assertEquals(1, u(b[0]) and 1)           // marker bits on bytes 0, 2, 4
        assertEquals(1, u(b[2]) and 1)
        assertEquals(1, u(b[4]) and 1)
        val hi = ((u(b[0]) ushr 1) and 0x7).toLong()
        val b29 = u(b[1]).toLong()
        val b21 = ((u(b[2]) ushr 1) and 0x7F).toLong()
        val b14 = u(b[3]).toLong()
        val b6 = ((u(b[4]) ushr 1) and 0x7F).toLong()
        val decoded = (hi shl 30) or (b29 shl 22) or (b21 shl 15) or (b14 shl 7) or b6
        assertEquals(pts, decoded)
    }

    @Test
    fun audioPesHeaderIsWellFormed() {
        val sink = newSink()
        val payload = ByteArray(20) { (it + 1).toByte() }
        val len = sink.buildPesInto(0xC0, 90_000L, null, payload)
        val pes = sink.pesBuf.copyOf(len)
        assertEquals(0x00, u(pes[0])); assertEquals(0x00, u(pes[1])); assertEquals(0x01, u(pes[2]))
        assertEquals(0xC0, u(pes[3]))                          // audio stream id
        val pesLen = (u(pes[4]) shl 8) or u(pes[5])
        assertEquals(3 + 5 + payload.size, pesLen)             // flags+hdrlen + PTS + ES
        assertEquals(0x80, u(pes[6]))                          // '10' marker
        assertEquals(0x80, u(pes[7]))                          // PTS-only flag
        assertEquals(5, u(pes[8]))                             // PES_header_data_length
        assertArrayEquals(payload, pes.copyOfRange(9 + 5, pes.size))
    }

    @Test
    fun videoPesUsesUnboundedLengthAndDts() {
        val sink = newSink()
        val es = ByteArray(10) { it.toByte() }
        val len = sink.buildPesInto(0xE0, 90_000L, 90_000L, es)
        val pes = sink.pesBuf.copyOf(len)
        assertEquals(0xE0, u(pes[3]))
        assertEquals(0, (u(pes[4]) shl 8) or u(pes[5]))        // unbounded for video
        assertEquals(0xC0, u(pes[7]))                          // PTS+DTS flag
        assertEquals(10, u(pes[8]))                            // header_data_length = 2×5
    }

    @Test
    fun writePesEmitsValid188BytePacketsWithContinuity() {
        val sink = newSink()
        val pes = ByteArray(500) { (it and 0xFF).toByte() } // spans several packets
        val out = ByteArrayOutputStream()
        val cc = intArrayOf(0)
        sink.writePes(out, 0x0100, cc, pes, pes.size, null)
        val ts = out.toByteArray()
        assertEquals(0, ts.size % 188)                        // whole 188-byte packets
        val packets = ts.size / 188
        assertTrue(packets >= 3)
        for (p in 0 until packets) {
            val off = p * 188
            assertEquals(0x47, u(ts[off]))                    // sync byte
            assertEquals(p == 0, (u(ts[off + 1]) and 0x40) != 0) // PUSI only on first
            val pid = ((u(ts[off + 1]) and 0x1F) shl 8) or u(ts[off + 2])
            assertEquals(0x0100, pid)
            assertEquals(p and 0x0F, u(ts[off + 3]) and 0x0F) // continuity counter
        }
        assertEquals(packets and 0x0F, cc[0])                 // counter advanced per packet
    }

    @Test
    fun writePesFirstPacketCarriesPcr() {
        val sink = newSink()
        val pcr = 1_234_567L
        val out = ByteArrayOutputStream()
        sink.writePes(out, 0x0100, intArrayOf(0), ByteArray(50), 50, pcr)
        val ts = out.toByteArray()
        assertEquals(0x3, (u(ts[3]) ushr 4) and 0x3)          // adaptation field + payload
        assertTrue(u(ts[4]) >= 7)                             // af_len ≥ flags(1)+PCR(6)
        assertTrue((u(ts[5]) and 0x10) != 0)                  // PCR_flag
        val base = (u(ts[6]).toLong() shl 25) or
            (u(ts[7]).toLong() shl 17) or
            (u(ts[8]).toLong() shl 9) or
            (u(ts[9]).toLong() shl 1) or
            ((u(ts[10]).toLong() ushr 7) and 0x1)
        assertEquals(pcr, base)
    }

    @Test
    fun patSectionHasValidCrc() {
        val pat = newSink().buildPat()
        assertEquals(0x00, u(pat[0]))                         // table_id = PAT
        assertTrue((u(pat[1]) and 0x80) != 0)                 // section_syntax_indicator
        val sectionLength = ((u(pat[1]) and 0x0F) shl 8) or u(pat[2])
        assertEquals(pat.size - 3, sectionLength)             // counts bytes after the length field
        assertCrcTrailer(pat)
    }

    @Test
    fun pmtIncludesAudioOnlyWhenEnabled() {
        val withAudio = newSink(audioEnabled = true).buildPmt()
        val videoOnly = newSink(audioEnabled = false).buildPmt()
        assertEquals(0x02, u(withAudio[0]))                   // table_id = PMT
        assertCrcTrailer(withAudio)
        assertCrcTrailer(videoOnly)
        // The audio ES entry (stream_type + 4 descriptor bytes) is exactly 5 bytes.
        assertEquals(videoOnly.size + 5, withAudio.size)
    }

    @Test
    fun adtsHeaderEncodesSyncwordRateAndLength() {
        val sink = newSink()                                  // defaults: 44100 Hz, stereo
        val frameLen = 200
        val h = sink.adtsHeader(frameLen)
        assertEquals(7, h.size)
        assertEquals(0xFF, u(h[0]))                           // syncword high byte
        assertEquals(0xF0, u(h[1]) and 0xF0)                  // syncword low nibble
        assertEquals(4, (u(h[2]) ushr 2) and 0x0F)           // 44100 → freq index 4
        val chan = ((u(h[2]) and 0x1) shl 2) or ((u(h[3]) ushr 6) and 0x3)
        assertEquals(2, chan)                                 // stereo
        val full = ((u(h[3]) and 0x3) shl 11) or (u(h[4]) shl 3) or ((u(h[5]) ushr 5) and 0x7)
        assertEquals(frameLen + 7, full)                      // frame length includes the 7-byte header
    }

    @Test
    fun freqIndexMapsKnownRatesAndFallsBack() {
        val sink = newSink()
        assertEquals(3, sink.freqIndex(48000))
        assertEquals(4, sink.freqIndex(44100))
        assertEquals(8, sink.freqIndex(16000))
        assertEquals(4, sink.freqIndex(12345))                // unknown rate → 44100 default
    }

    @Test
    fun crc32MatchesCanonicalMpeg2CheckVector() {
        // The published CRC-32/MPEG-2 check value for ASCII "123456789" is
        // 0x0376E6E7. Pins the table-driven impl to a constant, not just to our
        // own reference encoder (which could share a transcription slip).
        val data = "123456789".toByteArray(Charsets.US_ASCII)
        assertEquals(0x0376E6E7, Crc32Mpeg.compute(data, 0, data.size))
    }

    @Test
    fun pesBufReuseAcrossLargeThenSmallFrameLeavesNoStaleBytes() {
        // pesBuf is grown to the largest frame seen and reused. A large frame
        // (forcing growth past the 64 KiB initial size) followed by a small one
        // must produce a correct small PES in [0, len) — none of the large
        // frame's bytes bleeding into the region callers actually read.
        val sink = newSink()
        val big = ByteArray(96 * 1024) { (it and 0xFF).toByte() }
        val bigLen = sink.buildPesInto(0xE0, 90_000L, 90_000L, big)
        assertTrue(bigLen > 64 * 1024)
        assertTrue(sink.pesBuf.size >= bigLen)                 // buffer grew + retained

        val small = ByteArray(8) { (0xA0 + it).toByte() }
        val smallLen = sink.buildPesInto(0xC0, 180_000L, null, small)
        val pes = sink.pesBuf.copyOf(smallLen)
        assertEquals(9 + 5 + small.size, smallLen)             // audio PES header + ES only
        assertEquals(0xC0, u(pes[3]))                          // audio stream id
        assertEquals(5, u(pes[8]))                             // PTS-only header_data_length
        assertArrayEquals(small, pes.copyOfRange(9 + 5, smallLen)) // ES is `small`, not `big`
    }
}
