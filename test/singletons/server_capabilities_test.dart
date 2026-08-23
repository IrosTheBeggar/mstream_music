import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/server_capabilities.dart';

Server _server(String name, String? version) {
  final s = Server('http://$name', null, null, null, name);
  s.serverVersion = version;
  return s;
}

void main() {
  setUp(() {
    // Process-wide singleton — start each test clean.
    for (final n in ['old', 'new', 'fork', 'unknown']) {
      ServerCapabilities().forget(_server(n, null));
    }
  });

  group('parseNotAllowedKey', () {
    test('reads the key out of the real 6.22 rejection', () {
      // Verified against a live server:
      //   {"error":"\"totallyMadeUpParam\" is not allowed"}
      expect(
          parseNotAllowedKey('{"error":"\\"minSimilarity\\" is not allowed"}'),
          'minSimilarity');
    });

    test('works on the bare Joi sentence too', () {
      expect(parseNotAllowedKey('"bpmRanges" is not allowed'), 'bpmRanges');
    });

    // Anything that isn't a not-allowed rejection must return null, because
    // null is what stops the caller retrying. Retrying an auth failure with a
    // smaller body just fails again and buries the real cause.
    test('null for anything that is not a not-allowed rejection', () {
      for (final body in [
        null,
        '',
        '{"error":"Authentication Error"}',
        '{"error":"no songs are within the similarity range"}',
        '{"error":"\\"minRating\\" must be less than or equal to 10"}',
      ]) {
        expect(parseNotAllowedKey(body), isNull, reason: 'body: $body');
      }
    });
  });

  group('filter by version', () {
    test('an old upstream server loses the parameters it predates', () {
      final s = _server('old', '6.0.0'); // before genreMode/bpm (6.7.1)
      final r = ServerCapabilities().filter(s, {
        'ignoreList': [],
        'genreMode': 'whitelist',
        'bpmRanges': [1],
        'minSimilarity': 0.5,
      });
      expect(r.body.keys, ['ignoreList']);
      expect(r.dropped, containsAll(['genreMode', 'bpmRanges', 'minSimilarity']));
    });

    test('a current server keeps everything', () {
      final s = _server('new', '6.22.0');
      final r = ServerCapabilities().filter(s, {
        'genreMode': 'whitelist',
        'minSimilarity': 0.5,
      });
      expect(r.dropped, isEmpty);
      expect(r.body.length, 2);
    });

    // A fork's numbering is its own — velvet 6.14.7 predates upstream 6.7.1 —
    // so the table must not answer for it. Send and let the server decide.
    test('a fork is never pre-filtered, however its number compares', () {
      final s = _server('fork', '6.4.2-velvet');
      final r = ServerCapabilities().filter(s, {'minSimilarity': 0.5});
      expect(r.dropped, isEmpty,
          reason: 'fork numbering cannot be compared to upstream');
    });

    test('an unknown version is not pre-filtered either', () {
      final s = _server('unknown', null);
      final r = ServerCapabilities().filter(s, {'minSimilarity': 0.5});
      expect(r.dropped, isEmpty);
    });
  });

  group('search flags', () {
    // Only noLyrics (6.13.1) is young enough to matter. The other four date to
    // 4.7.0, below the support floor, so gating them would be dead weight.
    test('an old server loses only noLyrics', () {
      final s = _server('old', '6.10.0');
      final r = ServerCapabilities().filter(s, {
        'search': 'x',
        'noArtists': false,
        'noAlbums': false,
        'noTitles': false,
        'noFiles': false,
        'noLyrics': true,
      });
      expect(r.dropped, ['noLyrics']);
      expect(r.body.containsKey('noArtists'), isTrue);
      expect(r.body.containsKey('search'), isTrue);
    });

    test('6.13.1 and up keep it', () {
      final s = _server('new', '6.13.1');
      expect(ServerCapabilities().filter(s, {'noLyrics': true}).dropped,
          isEmpty);
    });
  });

  group('learning from rejections', () {
    test('a rejection sticks, so the same request cannot fail twice', () {
      final s = _server('new', '6.22.0');
      final caps = ServerCapabilities();
      // Version says fine, but this server disagrees — the server wins.
      expect(caps.filter(s, {'minSimilarity': 0.5}).dropped, isEmpty);
      expect(caps.noteRejection(s, '{"error":"\\"minSimilarity\\" is not allowed"}'),
          'minSimilarity');
      expect(caps.filter(s, {'minSimilarity': 0.5}).dropped, ['minSimilarity']);
    });

    test('a non-rejection teaches nothing', () {
      final s = _server('new', '6.22.0');
      final caps = ServerCapabilities();
      expect(caps.noteRejection(s, '{"error":"Authentication Error"}'), isNull);
      expect(caps.rejectedFor(s), isEmpty);
    });

    test('forget clears it — an upgrade invalidates old verdicts', () {
      final s = _server('new', '6.22.0');
      final caps = ServerCapabilities();
      caps.noteRejection(s, '"genres" is not allowed');
      expect(caps.rejectedFor(s), contains('genres'));
      caps.forget(s);
      expect(caps.rejectedFor(s), isEmpty);
    });

    test('verdicts do not leak between servers', () {
      final a = _server('old', '6.22.0');
      final b = _server('new', '6.22.0');
      final caps = ServerCapabilities();
      caps.noteRejection(a, '"genres" is not allowed');
      expect(caps.filter(b, {'genres': []}).dropped, isEmpty);
    });
  });

  group('suppression (valid key, server cannot act on it)', () {
    test('suppressed keys are dropped like rejected ones', () {
      final s = _server('new', '6.22.0');
      final caps = ServerCapabilities();
      caps.suppress(s, ['similarTo', 'minSimilarity'], 'not analyzed yet');
      final r = caps.filter(s, {
        'ignoreList': [],
        'similarTo': ['x'],
        'minSimilarity': 0.5,
      });
      expect(r.body.keys, ['ignoreList']);
      expect(r.dropped, containsAll(['similarTo', 'minSimilarity']));
    });

    test('allSuppressed only when every key is', () {
      final s = _server('new', '6.22.0');
      final caps = ServerCapabilities();
      expect(caps.allSuppressed(s, ['similarTo', 'minSimilarity']), isFalse);
      caps.suppress(s, ['similarTo'], 'partial');
      expect(caps.allSuppressed(s, ['similarTo', 'minSimilarity']), isFalse,
          reason: 'one of two is not all');
      caps.suppress(s, ['minSimilarity'], 'rest');
      expect(caps.allSuppressed(s, ['similarTo', 'minSimilarity']), isTrue);
    });

    test('forget lifts suppression — a finished scan should re-enable it', () {
      final s = _server('new', '6.22.0');
      final caps = ServerCapabilities();
      caps.suppress(s, ['similarTo'], 'not analyzed yet');
      caps.forget(s);
      expect(caps.allSuppressed(s, ['similarTo']), isFalse);
    });
  });
}
