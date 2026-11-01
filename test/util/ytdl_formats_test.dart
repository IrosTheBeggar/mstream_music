// lib/util/ytdl_formats.dart — the formats the format menu offers, from the
// server's supportedAudioFiles `true` keys (spec §5): the fixed order, AAC
// only in M4A's place, never m4b or m3u, MP3 when the map is missing or
// useless, and a remembered format falling back once the server drops it.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/ytdl_formats.dart';

/// The server's default map, `true` keys only (src/state/config.js).
const serverDefault = ['mp3', 'flac', 'wav', 'ogg', 'aac', 'm4a', 'm4b', 'opus'];

void main() {
  group('ytdlFormatOptions', () {
    test('the server default: kYtdlFormatOrder, no aac (m4a is on), no m4b', () {
      expect(ytdlFormatOptions(serverDefault), ['mp3', 'm4a', 'opus', 'ogg', 'flac', 'wav']);
      expect(ytdlFormatOptions(serverDefault), kYtdlFormatOrder);
    });

    test('the order is the menu\'s, whatever order the map came in', () {
      expect(ytdlFormatOptions(['wav', 'opus', 'mp3']), ['mp3', 'opus', 'wav']);
    });

    test('aac takes m4a\'s slot only when m4a is off', () {
      expect(ytdlFormatOptions(['flac', 'aac', 'mp3']), ['mp3', 'aac', 'flac']);
      expect(ytdlFormatOptions(['aac', 'm4a']), ['m4a']);
      expect(ytdlFormatOptions(['aac']), ['aac']);
    });

    test('m4b and m3u never appear; unknown keys are ignored', () {
      expect(ytdlFormatOptions(['m4b', 'mp3', 'm3u', 'wma']), ['mp3']);
    });

    test('unknown, malformed or nothing usable → mp3', () {
      expect(ytdlFormatOptions(null), ['mp3']);
      expect(ytdlFormatOptions([]), ['mp3']);
      expect(ytdlFormatOptions(['m4b', 'm3u']), ['mp3']);
    });
  });

  group('ytdlDefaultFormat', () {
    test('mp3 when the server has it on', () {
      expect(ytdlDefaultFormat(serverDefault), 'mp3');
      expect(ytdlDefaultFormat(['wav', 'mp3']), 'mp3');
    });

    test('otherwise the first option in the menu\'s order', () {
      expect(ytdlDefaultFormat(['wav', 'flac', 'opus']), 'opus');
      expect(ytdlDefaultFormat(['aac', 'wav']), 'aac');
    });

    test('a fixed mp3 only when the map is missing or malformed', () {
      expect(ytdlDefaultFormat(null), 'mp3');
      expect(ytdlDefaultFormat(['m3u']), 'mp3');
    });
  });

  group('ytdlEffectiveFormat', () {
    test('a remembered format the server still offers is kept', () {
      expect(ytdlEffectiveFormat('opus', serverDefault), 'opus');
      expect(ytdlEffectiveFormat('aac', ['aac', 'mp3']), 'aac');
    });

    test('a remembered format the server has since turned off falls back to the default', () {
      expect(ytdlEffectiveFormat('opus', ['mp3', 'flac']), 'mp3');
      expect(ytdlEffectiveFormat('opus', ['wav', 'flac']), 'flac');
      // aac while m4a is on is not an option either.
      expect(ytdlEffectiveFormat('aac', serverDefault), 'mp3');
      expect(ytdlEffectiveFormat('m4b', serverDefault), 'mp3');
    });

    test('nothing remembered is the default', () {
      expect(ytdlEffectiveFormat(null, serverDefault), 'mp3');
      expect(ytdlEffectiveFormat(null, ['ogg', 'wav']), 'ogg');
      expect(ytdlEffectiveFormat(null, null), 'mp3');
    });
  });
}
