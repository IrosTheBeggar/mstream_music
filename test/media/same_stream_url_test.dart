import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  group('AudioPlayerHandler.sameStreamUrl', () {
    // buildServerStreamUrl stamps a fresh app_uuid per call; the rebuild paths
    // must treat two URLs differing ONLY in that cache-buster as the same
    // stream, or every tunnel reconnect reloads the whole queue.

    test('identical except app_uuid → same', () {
      expect(
        AudioPlayerHandler.sameStreamUrl(
          'http://127.0.0.1:41234/media/a/b.mp3?app_uuid=1111&token=t&__lt=x',
          'http://127.0.0.1:41234/media/a/b.mp3?app_uuid=2222&token=t&__lt=x',
        ),
        isTrue,
      );
    });

    test('different port (tunnel rotated) → different', () {
      expect(
        AudioPlayerHandler.sameStreamUrl(
          'http://127.0.0.1:41234/media/a.mp3?app_uuid=1&token=t',
          'http://127.0.0.1:52345/media/a.mp3?app_uuid=2&token=t',
        ),
        isFalse,
      );
    });

    test('different token → different', () {
      expect(
        AudioPlayerHandler.sameStreamUrl(
          'https://demo.mstream.io/media/a.mp3?app_uuid=1&token=old',
          'https://demo.mstream.io/media/a.mp3?app_uuid=2&token=new',
        ),
        isFalse,
      );
    });

    test('endpoint change (media → transcode) → different', () {
      expect(
        AudioPlayerHandler.sameStreamUrl(
          'https://s/media/a.mp3?app_uuid=1&token=t',
          'https://s/transcode/a.mp3?app_uuid=2&token=t&codec=opus',
        ),
        isFalse,
      );
    });

    test('added transcode params → different', () {
      expect(
        AudioPlayerHandler.sameStreamUrl(
          'https://s/transcode/a.mp3?app_uuid=1&token=t',
          'https://s/transcode/a.mp3?app_uuid=2&token=t&bitrate=192k',
        ),
        isFalse,
      );
    });

    test('exact same string → same (fast path)', () {
      const u = 'https://s/media/a.mp3?app_uuid=1&token=t';
      expect(AudioPlayerHandler.sameStreamUrl(u, u), isTrue);
    });

    test('non-URL ids compare as plain strings', () {
      expect(AudioPlayerHandler.sameStreamUrl('abc', 'abc'), isTrue);
      // Uuid-style local ids parse as URIs with only a path — path differs.
      expect(AudioPlayerHandler.sameStreamUrl('abc', 'def'), isFalse);
    });
  });
}
