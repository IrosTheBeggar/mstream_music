import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/stream_url.dart';

void main() {
  group('needsIosTranscodeFallback', () {
    // AVPlayer can't decode ogg/opus & co: on iOS those paths must stream
    // through /transcode even with the user's transcode setting off.

    test('ogg/opus/wma need the fallback on iOS', () {
      for (final p in [
        '/Music/a.ogg',
        '/Music/b.OGG', // case-insensitive
        '/Music/c.opus',
        '/Music/d.oga',
        '/x/e.wma',
        '/x/f.ape',
        '/x/g.dsf',
      ]) {
        expect(
            needsIosTranscodeFallback(p, isIOS: true, transcodeAvailable: null),
            isTrue,
            reason: p);
      }
    });

    test('AVPlayer-native formats never trigger it', () {
      for (final p in [
        '/Music/a.mp3',
        '/Music/b.flac',
        '/Music/c.m4a',
        '/Music/d.wav',
        '/Music/e.aac',
        '/Music/f.aiff',
        '/Music/noext',
      ]) {
        expect(
            needsIosTranscodeFallback(p, isIOS: true, transcodeAvailable: true),
            isFalse,
            reason: p);
      }
    });

    test('gated hard on iOS: other platforms never fall back', () {
      expect(
          needsIosTranscodeFallback('/a.ogg',
              isIOS: false, transcodeAvailable: true),
          isFalse);
    });

    test('a server confirmed without ffmpeg opts out; unknown is optimistic',
        () {
      expect(
          needsIosTranscodeFallback('/a.ogg',
              isIOS: true, transcodeAvailable: false),
          isFalse);
      expect(
          needsIosTranscodeFallback('/a.ogg',
              isIOS: true, transcodeAvailable: null),
          isTrue);
    });

    test('dotted directory names do not confuse the extension check', () {
      expect(
          needsIosTranscodeFallback('/My.Ogg.Rips/track.mp3',
              isIOS: true, transcodeAvailable: true),
          isFalse);
    });
  });

  group('effectiveTranscodeCodec', () {
    // iOS pins everything except aac to mp3: AVPlayer can't decode opus, so
    // an explicit opus choice — or a null that lets an opus-defaulting server
    // pick — would swap one unplayable stream for another.

    test('iOS pins opus and null to mp3, keeps aac and mp3', () {
      expect(effectiveTranscodeCodec('opus', isIOS: true), 'mp3');
      expect(effectiveTranscodeCodec(null, isIOS: true), 'mp3');
      expect(effectiveTranscodeCodec('aac', isIOS: true), 'aac');
      expect(effectiveTranscodeCodec('mp3', isIOS: true), 'mp3');
    });

    test('other platforms pass the user choice through, including null', () {
      expect(effectiveTranscodeCodec('opus', isIOS: false), 'opus');
      expect(effectiveTranscodeCodec(null, isIOS: false), isNull);
      expect(effectiveTranscodeCodec('aac', isIOS: false), 'aac');
    });
  });
}
