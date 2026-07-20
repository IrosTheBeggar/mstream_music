import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';

// Fixtures mirror the exact wire shapes of mStream's discovery API
// (src/api/discovery.js, discovery-p2p.js, discovery-federation.js):
// lite metadata uses kebab-case keys, genreTags are model predictions in
// "Parent---Leaf" form, similarity is a 0..1 float.

void main() {
  group('DiscoverySimilarTracks.fromServerMap', () {
    test('parses a typical /local/similar/tracks response', () {
      final r = DiscoverySimilarTracks.fromServerMap({
        'seed': {
          'filepath': 'music/seed.mp3',
          'metadata': {'title': 'Seed', 'artist': 'Seeder'},
          'genreTags': ['Electronic---House'],
        },
        'model': {'id': 'effnet-discogs', 'version': '1'},
        'notAnalyzed': false,
        'results': [
          {
            'filepath': 'music/similar-a.flac',
            'similarity': 0.9713,
            'metadata': {
              'title': 'Track A',
              'artist': 'Artist A',
              'album': 'Album A',
              'album-art': 'aa.jpg',
              'duration': 215.4,
              'track': 2,
              'disk': 1,
              'year': 2020,
              'bpm': 128,
              'musical-key': '8A',
              'genres': ['House'],
              'has-lyrics': false,
            },
            'genreTags': ['Electronic---House', 'Electronic---Techno'],
          },
          {
            // Sparse row: no metadata block, null genreTags.
            'filepath': 'music/similar-b.mp3',
            'similarity': 0.8004,
            'metadata': null,
            'genreTags': null,
          },
        ],
      });

      expect(r.notAnalyzed, isFalse);
      expect(r.results, hasLength(2));

      final a = r.results[0];
      expect(a.filepath, 'music/similar-a.flac');
      expect(a.similarity, closeTo(0.9713, 1e-9));
      expect(a.metadata?.title, 'Track A');
      expect(a.metadata?.artist, 'Artist A');
      // Kebab-case lite-metadata keys must flow through fromServerMap.
      expect(a.metadata?.albumArt, 'aa.jpg');
      expect(a.metadata?.musicalKey, '8A');
      expect(a.metadata?.durationSeconds, closeTo(215.4, 1e-9));
      expect(a.genreTags, ['Electronic---House', 'Electronic---Techno']);
      expect(a.displayTitle, 'Track A');

      final b = r.results[1];
      expect(b.metadata, isNull);
      expect(b.genreTags, isEmpty);
      // No metadata → the filename is the display title.
      expect(b.displayTitle, 'similar-b.mp3');
    });

    test('flags a not-yet-analyzed seed', () {
      final r = DiscoverySimilarTracks.fromServerMap({
        'notAnalyzed': true,
        'results': [],
      });
      expect(r.notAnalyzed, isTrue);
      expect(r.results, isEmpty);
    });

    test('drops malformed rows and tolerates a missing results key', () {
      final r = DiscoverySimilarTracks.fromServerMap({
        'results': [
          {'similarity': 0.9}, // no filepath → dropped
          'garbage',
          {'filepath': 'music/ok.mp3', 'similarity': 0.5},
        ],
      });
      expect(r.results, hasLength(1));
      expect(r.results.single.filepath, 'music/ok.mp3');

      expect(DiscoverySimilarTracks.fromServerMap({}).results, isEmpty);
    });

    test('coerces and clamps similarity', () {
      final r = DiscoverySimilarTracks.fromServerMap({
        'results': [
          {'filepath': 'a', 'similarity': '0.75'},
          {'filepath': 'b', 'similarity': 1.7},
          {'filepath': 'c', 'similarity': null},
        ],
      });
      expect(r.results[0].similarity, closeTo(0.75, 1e-9));
      expect(r.results[1].similarity, 1.0);
      expect(r.results[2].similarity, 0.0);
    });
  });

  group('DiscoverySimilarArtists.fromServerMap', () {
    test('parses artists with playable entry points', () {
      final r = DiscoverySimilarArtists.fromServerMap({
        'seed': {'artist': 'Seeder', 'trackCount': 40, 'analyzedCount': 38},
        'model': {'id': 'effnet-discogs', 'version': '1'},
        'notAnalyzed': false,
        'results': [
          {
            'artist': 'Artist B',
            'similarity': 0.91,
            'analyzedCount': 14,
            'genreTags': ['Rock---Shoegaze'],
            'entryPoints': [
              {
                'filepath': 'music/b1.mp3',
                'metadata': {'title': 'B1', 'artist': 'Artist B'},
              },
              {
                'filepath': 'music/b2.mp3',
                'metadata': {'title': 'B2', 'artist': 'Artist B'},
              },
            ],
          },
        ],
      });

      expect(r.notAnalyzed, isFalse);
      final b = r.results.single;
      expect(b.artist, 'Artist B');
      expect(b.similarity, closeTo(0.91, 1e-9));
      expect(b.genreTags, ['Rock---Shoegaze']);
      expect(b.entryPoints, hasLength(2));
      expect(b.entryPoints.first.filepath, 'music/b1.mp3');
      expect(b.entryPoints.first.metadata?.title, 'B1');
      // Entry points carry no similarity on the wire.
      expect(b.entryPoints.first.similarity, 0.0);
    });

    test('drops artist rows without a name; tolerates missing entryPoints',
        () {
      final r = DiscoverySimilarArtists.fromServerMap({
        'results': [
          {'similarity': 0.5},
          {'artist': 'Solo', 'similarity': 0.4},
        ],
      });
      expect(r.results, hasLength(1));
      expect(r.results.single.artist, 'Solo');
      expect(r.results.single.entryPoints, isEmpty);
    });
  });

  group('DiscoveryLeads.fromServerMap', () {
    test('parses a P2P response (metadata-only leads)', () {
      final r = DiscoveryLeads.fromServerMap({
        'query': {'filePath': 'music/seed.mp3', 'modelId': 'effnet-discogs'},
        'searched': {'peers': 3, 'tracks': 5000},
        'results': [
          {
            'artist': 'Net Artist',
            'title': 'Net Song',
            'duration': 200.5,
            'similarity': 0.87,
            'recordingMbid': 'f4b0-mbid',
            'exportId': 'x1',
            'peer': {'endpointId': 'ep1', 'name': 'peer-name'},
          },
        ],
      });

      expect(r.searchedPeers, 3);
      expect(r.unreachablePeers, 0);
      final lead = r.results.single;
      expect(lead.artist, 'Net Artist');
      expect(lead.title, 'Net Song');
      expect(lead.durationSeconds, closeTo(200.5, 1e-9));
      expect(lead.similarity, closeTo(0.87, 1e-9));
      expect(lead.recordingMbid, 'f4b0-mbid');
      expect(lead.genreTags, isEmpty); // P2P rows carry no genreTags
      expect(lead.peerName, 'peer-name');
      expect(lead.copyText, 'Net Artist - Net Song');
    });

    test('parses a federation response (genreTags + peer id/name)', () {
      final r = DiscoveryLeads.fromServerMap({
        'query': {'filePath': 'music/seed.mp3', 'modelId': 'effnet-discogs'},
        'searched': {'peers': 2, 'unreachable': 2, 'mismatched': 0},
        'results': [
          {
            'artist': 'Fed Artist',
            'title': 'Fed Song',
            'duration': 180,
            'similarity': 0.79,
            'genreTags': ['Jazz---Fusion'],
            'recordingMbid': null,
            'filepath': 'peer-vpath/song.mp3',
            'peer': {'id': 'peer-1', 'name': 'Friend'},
          },
        ],
      });

      expect(r.searchedPeers, 2);
      expect(r.unreachablePeers, 2);
      final lead = r.results.single;
      expect(lead.genreTags, ['Jazz---Fusion']);
      expect(lead.recordingMbid, isNull);
      expect(lead.peerName, 'Friend');
    });

    test('drops rows without a title; artist-less copyText is title only',
        () {
      final r = DiscoveryLeads.fromServerMap({
        'searched': {'peers': 1},
        'results': [
          {'artist': 'X', 'similarity': 0.5}, // no title → dropped
          {'title': 'Orphan Song', 'similarity': 0.5},
        ],
      });
      expect(r.results, hasLength(1));
      expect(r.results.single.artist, isEmpty);
      expect(r.results.single.copyText, 'Orphan Song');
    });
  });

  group('genreTagLabel', () {
    test('keeps the leaf of the hierarchy, capped at max, dot-joined', () {
      expect(
        genreTagLabel(
            ['Electronic---Synthwave', 'Electronic---House', 'Rock---Indie']),
        'Synthwave · House',
      );
      expect(genreTagLabel(['Rock---Shoegaze'], max: 1), 'Shoegaze');
      expect(genreTagLabel(['Ambient']), 'Ambient'); // no hierarchy separator
      expect(genreTagLabel([]), isNull);
    });
  });
}
