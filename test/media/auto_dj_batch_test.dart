import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

// Batch picks (mStream #966): a random-songs answer may carry several songs,
// each with its own cosine. The pure helpers behind the multi-server pick's
// per-song scoring and its top-N selection.
void main() {
  Map<String, dynamic> song(String path) => {'filepath': path, 'metadata': {}};

  group('AudioPlayerHandler.scoredSongs', () {
    test('a batch answer pairs every song with its own similarity', () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), song('b'), song('c')],
        'sonic': {
          'similarity': 0.9,
          'similarities': [0.9, 0.7, 0.8],
          'poolSize': 3,
        },
      });
      expect(got.map((c) => c.song['filepath']), ['a', 'b', 'c']);
      expect(got.map((c) => c.similarity), [0.9, 0.7, 0.8]);
    });

    test('a pre-batch server scores only its first song; the rest compete '
        'unscored', () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), song('b')],
        'sonic': {'similarity': 0.6},
      });
      expect(got.map((c) => c.similarity), [0.6, -1.0]);
    });

    test('no sonic block — a plain pick — scores nothing', () {
      final got = AudioPlayerHandler.scoredSongs({'songs': [song('a')]});
      expect(got.single.similarity, -1.0);
      expect(AudioPlayerHandler.scoredSongs({'songs': []}), isEmpty);
      expect(AudioPlayerHandler.scoredSongs({}), isEmpty);
    });

    test('a null similarity (a song with no vector) is unscored, not a crash',
        () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), song('b')],
        'sonic': {'similarity': 0.5, 'similarities': [0.5, null]},
      });
      expect(got.map((c) => c.similarity), [0.5, -1.0]);
    });

    test('a row that is not an object is skipped, the rest keep their scores',
        () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), 'junk', song('c')],
        'sonic': {'similarities': [0.9, 0.8, 0.7]},
      });
      expect(got.map((c) => c.song['filepath']), ['a', 'c']);
      expect(got.map((c) => c.similarity), [0.9, 0.7]);
    });
  });

  group('AudioPlayerHandler.bestBySimilarity', () {
    final items = [('l1', 0.80), ('l2', 0.60), ('p2', 0.91), ('p3', 0.85)];

    test('the n best, best first', () {
      final got = AudioPlayerHandler.bestBySimilarity(items, (i) => i.$2, 3);
      expect(got.map((i) => i.$1), ['p2', 'p3', 'l1']);
    });

    test('asking for more than there is returns everything, still ordered',
        () {
      final got = AudioPlayerHandler.bestBySimilarity(items, (i) => i.$2, 10);
      expect(got.map((i) => i.$1), ['p2', 'p3', 'l1', 'l2']);
    });

    test('ties keep their order, so the server asked first wins them', () {
      final tied = [('peer', 0.9), ('local', 0.9), ('other', 0.9)];
      expect(
          AudioPlayerHandler.bestBySimilarity(tied, (i) => i.$2, 3)
              .map((i) => i.$1),
          ['peer', 'local', 'other']);
      // Unscored answers (-1) sort last, and keep their order among
      // themselves.
      final mixed = [('u1', -1.0), ('s', 0.2), ('u2', -1.0)];
      expect(
          AudioPlayerHandler.bestBySimilarity(mixed, (i) => i.$2, 3)
              .map((i) => i.$1),
          ['s', 'u1', 'u2']);
    });

    test('n below one still yields one', () {
      expect(
          AudioPlayerHandler.bestBySimilarity(items, (i) => i.$2, 0).length,
          1);
    });

    test('the input list is left alone', () {
      final copy = List.of(items);
      AudioPlayerHandler.bestBySimilarity(items, (i) => i.$2, 2);
      expect(items, copy);
    });
  });
}
