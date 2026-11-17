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

    // mStream #1108: a body that carried Less like negatives gets an echo
    // whose `avoided` flags the songs like one of them, aligned with `songs`.
    test('the avoided flags of an aligned echo ride on their songs', () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), song('b'), song('c')],
        'sonic': {'similarities': [0.9, 0.8, 0.7]},
        'lessLike': {
          'used': 1,
          'ignored': 0,
          'threshold': 0.8,
          'avoided': [false, true, false],
        },
      });
      expect(got.map((c) => c.avoided), [false, true, false]);
    });

    test('no echo — a server that took no negatives — is all clean', () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), song('b')],
      });
      expect(got.map((c) => c.avoided), [false, false]);
    });

    test('a short avoided list leaves the songs past its end clean', () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), song('b'), song('c')],
        'lessLike': {
          'avoided': [true],
        },
      });
      expect(got.map((c) => c.avoided), [true, false, false]);
    });

    test('a junk echo or junk entries count as clean, not a crash', () {
      for (final echo in [
        'junk',
        {'avoided': 'junk'},
        {'avoided': null},
        {
          'avoided': [1, 'true', null],
        },
      ]) {
        final got = AudioPlayerHandler.scoredSongs({
          'songs': [song('a'), song('b'), song('c')],
          'lessLike': echo,
        });
        expect(got.map((c) => c.avoided), [false, false, false],
            reason: '$echo');
      }
    });

    test('a non-object row ahead of an avoided song: the flag is read by the '
        'song\'s own index in the answer, not its place in the output', () {
      final got = AudioPlayerHandler.scoredSongs({
        'songs': [song('a'), 'junk', song('c')],
        'lessLike': {
          'avoided': [false, false, true],
        },
      });
      expect(got.map((c) => c.song['filepath']), ['a', 'c']);
      expect(got.map((c) => c.avoided), [false, true]);
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

    // A merge across servers: a song a server flagged as like a Less like
    // row comes after every clean one, as it does in that server's answer.
    group('with avoided songs', () {
      final mixed = [
        ('clean-low', 0.40, false),
        ('avoided-high', 0.95, true),
        ('clean-high', 0.70, false),
        ('avoided-low', 0.50, true),
      ];

      test('every clean song ranks before every avoided one, then by '
          'similarity', () {
        final got = AudioPlayerHandler.bestBySimilarity(
            mixed, (i) => i.$2, 4,
            avoided: (i) => i.$3);
        expect(got.map((i) => i.$1),
            ['clean-high', 'clean-low', 'avoided-high', 'avoided-low']);
      });

      test('an avoided song fills a batch only when the clean ones run out',
          () {
        expect(
            AudioPlayerHandler.bestBySimilarity(mixed, (i) => i.$2, 2,
                    avoided: (i) => i.$3)
                .map((i) => i.$1),
            ['clean-high', 'clean-low']);
        expect(
            AudioPlayerHandler.bestBySimilarity(mixed, (i) => i.$2, 3,
                    avoided: (i) => i.$3)
                .map((i) => i.$1),
            ['clean-high', 'clean-low', 'avoided-high']);
      });

      test('ties keep their order on either side of the line', () {
        final tied = [
          ('a1', 0.9, true),
          ('c1', 0.5, false),
          ('a2', 0.9, true),
          ('c2', 0.5, false),
        ];
        expect(
            AudioPlayerHandler.bestBySimilarity(tied, (i) => i.$2, 4,
                    avoided: (i) => i.$3)
                .map((i) => i.$1),
            ['c1', 'c2', 'a1', 'a2']);
      });

      test('without the avoided key the ranking is by similarity alone', () {
        expect(
            AudioPlayerHandler.bestBySimilarity(mixed, (i) => i.$2, 4)
                .map((i) => i.$1),
            ['avoided-high', 'clean-high', 'avoided-low', 'clean-low']);
      });
    });
  });
}
