import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

// AudioPlayerHandler.filterSonicCandidates — the pure constraint filter
// behind Auto DJ's sonic-similarity mode. Rows mirror the raw wire shape of
// POST /api/v1/discovery/local/similar/tracks results.

Map<String, dynamic> row(
  String filepath, {
  String? artist,
  num? rating,
  num? bpm,
  String? key,
  List<String>? genres,
  String? title,
}) =>
    {
      'filepath': filepath,
      'similarity': 0.9,
      'metadata': {
        'artist': ?artist,
        'rating': ?rating,
        'bpm': ?bpm,
        'musical-key': ?key,
        'genres': ?genres,
        'title': ?title,
      },
      'genreTags': null,
    };

List<String> paths(List<Map<String, dynamic>> rows) =>
    rows.map((r) => r['filepath'] as String).toList();

void main() {
  group('AudioPlayerHandler.filterSonicCandidates', () {
    test('drops queued tracks and ignored vpaths, keeps incoming order', () {
      final out = AudioPlayerHandler.filterSonicCandidates(
        [
          row('music/a.mp3'),
          row('music/b.mp3'), // already in the queue
          row('podcasts/c.mp3'), // vpath toggled off
          row('music/d.mp3'),
          'garbage', // malformed row
          {'similarity': 0.5}, // no filepath
        ],
        queuePaths: {'music/b.mp3'},
        ignoreVPaths: ['podcasts'],
      );
      expect(paths(out), ['music/a.mp3', 'music/d.mp3']);
    });

    test('minRating mirrors random-songs: unrated tracks never qualify', () {
      final out = AudioPlayerHandler.filterSonicCandidates(
        [
          row('music/unrated.mp3'),
          row('music/low.mp3', rating: 4),
          row('music/exact.mp3', rating: 6),
          row('music/high.mp3', rating: 10),
        ],
        queuePaths: const {},
        minRating: 6,
      );
      expect(paths(out), ['music/exact.mp3', 'music/high.mp3']);
    });

    test('applies the client-side keyword callback', () {
      final out = AudioPlayerHandler.filterSonicCandidates(
        [
          row('music/live-set.mp3', title: 'Anthem (Live)'),
          row('music/studio.mp3', title: 'Anthem'),
        ],
        queuePaths: const {},
        isBlocked: (r) => ((r['metadata'] as Map?) ?? const {})['title']
            .toString()
            .toLowerCase()
            .contains('live'),
      );
      expect(paths(out), ['music/studio.mp3']);
    });

    test('genre whitelist and blacklist match case-insensitively', () {
      final rows = [
        row('music/rock.mp3', genres: ['Rock']),
        row('music/jazz.mp3', genres: ['Jazz', 'Fusion']),
        row('music/untagged.mp3'),
      ];
      final white = AudioPlayerHandler.filterSonicCandidates(
        rows,
        queuePaths: const {},
        genreValues: ['rock'],
      );
      expect(paths(white), ['music/rock.mp3']);

      final black = AudioPlayerHandler.filterSonicCandidates(
        rows,
        queuePaths: const {},
        genreValues: ['ROCK'],
        genreMode: 'blacklist',
      );
      // Blacklist keeps untagged tracks; whitelist (above) drops them.
      expect(paths(black), ['music/jazz.mp3', 'music/untagged.mp3']);
    });

    test('BPM windows require a tagged, in-window tempo', () {
      final out = AudioPlayerHandler.filterSonicCandidates(
        [
          row('music/in.mp3', bpm: 124),
          row('music/half.mp3', bpm: 62),
          row('music/out.mp3', bpm: 90),
          row('music/untagged.mp3'),
        ],
        queuePaths: const {},
        bpmWindows: [
          {'min': 112, 'max': 128},
          {'min': 52, 'max': 68},
          {'min': 232, 'max': 248},
        ],
      );
      expect(paths(out), ['music/in.mp3', 'music/half.mp3']);
    });

    test('harmonic filter keeps only keys in the allowed Camelot set', () {
      final out = AudioPlayerHandler.filterSonicCandidates(
        [
          row('music/anchor.mp3', key: '8A'),
          row('music/named.mp3', key: 'C major'), // 8B — allowed neighbour
          row('music/far.mp3', key: '3A'),
          row('music/unkeyed.mp3'),
        ],
        queuePaths: const {},
        allowedKeys: {'8A', '7A', '9A', '8B', '7B', '9B'},
      );
      expect(paths(out), ['music/anchor.mp3', 'music/named.mp3']);
    });

    test('avoidArtist is a soft preference, never a starving filter', () {
      final mixed = AudioPlayerHandler.filterSonicCandidates(
        [
          row('music/same1.mp3', artist: 'Seeder'),
          row('music/other.mp3', artist: 'Someone Else'),
          row('music/same2.mp3', artist: 'Seeder'),
        ],
        queuePaths: const {},
        avoidArtist: 'Seeder',
      );
      expect(paths(mixed), ['music/other.mp3']);

      final allSame = AudioPlayerHandler.filterSonicCandidates(
        [
          row('music/same1.mp3', artist: 'Seeder'),
          row('music/same2.mp3', artist: 'Seeder'),
        ],
        queuePaths: const {},
        avoidArtist: 'Seeder',
      );
      expect(paths(allSame), ['music/same1.mp3', 'music/same2.mp3']);
    });

    test('tolerates a leading slash on result filepaths', () {
      final out = AudioPlayerHandler.filterSonicCandidates(
        [row('/music/a.mp3'), row('/music/queued.mp3')],
        queuePaths: {'music/queued.mp3'},
        ignoreVPaths: ['podcasts'],
      );
      expect(paths(out), ['/music/a.mp3']);
    });
  });
}
