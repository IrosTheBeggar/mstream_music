import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';

// Fixtures follow the Discover page contract (mStream
// docs/discovery-page-plan.md §3.1–§3.2): POST /api/v1/discovery/taste and
// GET/PUT /api/v1/discovery/taste/prefs. Lite metadata is kebab-case, paths
// are vpath-form WITHOUT a leading slash, timestamps are ISO (`toIso`), and
// every network / peers row carries the `source` the server stamps on it.

Map<String, dynamic> _fullPayload() => {
      'window': 30,
      'widenedFrom': null,
      'seedSource': 'history',
      'fallback': false,
      'seeds': [
        {
          'hash': 'h-seed-1',
          'filepath': 'music/Boards/Roygbiv.flac',
          'metadata': {
            'title': 'Roygbiv',
            'artist': 'Boards of Canada',
            'album': 'Music Has the Right to Children',
            'album-art': 'boc.jpg',
            'year': 1998,
            'track': 5,
            'disk': 1,
            'duration': 151.2,
          },
          'outcome': 'completed',
          'lastPlayed': '2026-10-04T21:10:00.000Z',
          'plays': 3,
          'pinned': false,
          'analyzed': true,
        },
        {
          'hash': 'h-seed-2',
          'filepath': 'music/Aphex/Xtal.mp3',
          'metadata': {'title': 'Xtal', 'artist': 'Aphex Twin'},
          'outcome': 'stopped',
          'lastPlayed': '2026-10-01T08:00:00.000Z',
          'plays': 1,
          'pinned': false,
          'analyzed': false,
        },
        {
          'hash': 'h-pin',
          'filepath': 'music/Pinned.mp3',
          'metadata': null,
          'outcome': null,
          'lastPlayed': null,
          'plays': 0,
          'pinned': true,
          'analyzed': true,
        },
      ],
      'excluded': [
        {
          'hash': 'h-dropped',
          'filepath': 'music/Dropped.mp3',
          'metadata': {'title': 'Dropped', 'artist': 'Someone'},
        },
      ],
      'dropped': 1,
      'notAnalyzed': false,
      'model': {'id': 'effnet-discogs', 'version': '1.0'},
      'library': {
        'filter': 'fresh',
        'tracks': [
          {
            'filepath': 'music/Tycho/Awake.flac',
            'similarity': 0.83,
            'seedHash': 'h-seed-1',
            'metadata': {
              'title': 'Awake',
              'artist': 'Tycho',
              'album': 'Awake',
              'album-art': 'tycho.jpg',
              'duration': 284.0,
              'genres': ['Electronic'],
            },
            'genreTags': ['Electronic---Downtempo', 'Electronic---Ambient'],
            'playCount': 0,
            'lastPlayed': null,
          },
          {
            'filepath': 'music/Bonobo/Kerala.mp3',
            'similarity': 0.79,
            'seedHash': 'h-seed-2',
            'metadata': {'title': 'Kerala', 'artist': 'Bonobo'},
            'genreTags': [],
            'playCount': 2,
            'lastPlayed': '2026-01-12T10:00:00.000Z',
          },
        ],
        'albums': [
          {
            'name': 'Dive',
            'year': 2011,
            'album_art_file': 'dive.jpg',
            'album_artist': 'Tycho',
            'artists': ['Tycho'],
            'compilation': false,
            'year_min': 2011,
            'year_max': 2011,
            'track_count': 10,
            'duration': 3000,
            'similarity': 0.84,
            'scopedTracks': 10,
            'playedTracks': 0,
            'lastPlayed': null,
            'tracks': ['music/Tycho/Dive/01.flac', 'music/Tycho/Dive/02.flac'],
          },
          {
            'name': 'Late Night Tales',
            'year': 2006,
            'album_art_file': null,
            'album_artist': null, // a compilation: the rows disagree
            'artists': ['Various', 'Artists'],
            'track_count': 20,
            'similarity': 0.71,
            'scopedTracks': 18,
            'playedTracks': 4,
            'lastPlayed': '2025-03-01T12:00:00.000Z',
            'tracks': [],
          },
        ],
        'capped': false,
      },
      'network': {
        'results': [
          {
            'artist': 'Helios',
            'title': 'Halving the Compass',
            'album': 'Eingya',
            'year': 2006,
            'isrc': null,
            'releaseGroupMbid': null,
            'duration': 301.5,
            'similarity': 0.81,
            'recordingMbid': '9b7c-mbid',
            'exportId': 'x-42',
            'peer': {'endpointId': 'ep-abc', 'name': 'Riverside'},
            'source': 'p2p',
            'seedHash': 'h-seed-1',
          },
        ],
        'searched': {'peers': 3, 'tracks': 7421},
      },
      'peers': {
        'peers': [
          {
            'id': 1,
            'name': "Sam's server",
            'reachable': true,
            'mismatched': false,
            'lastSeen': '2026-10-05T09:00:00.000Z',
            'results': [
              {
                'artist': 'Nils Frahm',
                'title': 'Says',
                'album': 'Spaces',
                'year': 2013,
                'duration': 497,
                'similarity': 0.77,
                'genreTags': ['Electronic---Ambient'],
                'recordingMbid': null,
                'filepath': 'sams/Nils Frahm/Says.flac',
                'peer': {'id': 1, 'name': "Sam's server"},
                'source': 'federation',
                'seedHash': null,
              },
            ],
          },
          {
            'id': 2,
            'name': 'Basement',
            'reachable': false,
            'mismatched': false,
            'lastSeen': '2026-09-01 10:00:00',
            'results': [],
          },
        ],
        'searched': {'peers': 3, 'unreachable': 1, 'mismatched': 0},
      },
    };

void main() {
  group('TasteResponse.fromServerMap — full payload', () {
    final r = TasteResponse.fromServerMap(_fullPayload());

    test('top-level facts', () {
      expect(r.window, 30);
      expect(r.widenedFrom, isNull);
      expect(r.seedSource, TasteSeedSource.history);
      expect(r.fallback, isFalse);
      expect(r.dropped, 1);
      expect(r.notAnalyzed, isFalse);
      expect(r.model?.id, 'effnet-discogs');
      expect(r.model?.version, '1.0');
    });

    test('seeds keep their outcome, play facts and pin', () {
      expect(r.seeds, hasLength(3));
      final a = r.seeds[0];
      expect(a.hash, 'h-seed-1');
      expect(a.filepath, 'music/Boards/Roygbiv.flac',
          reason: 'vpath-form, no leading slash — as the wire sends it');
      expect(a.metadata?.title, 'Roygbiv');
      expect(a.metadata?.albumArt, 'boc.jpg');
      expect(a.metadata?.year, 1998);
      expect(a.outcome, 'completed');
      expect(a.finished, isTrue);
      expect(a.lastPlayed, DateTime.utc(2026, 10, 4, 21, 10));
      expect(a.lastPlayed!.isUtc, isTrue);
      expect(a.plays, 3);
      expect(a.pinned, isFalse);
      expect(a.analyzed, isTrue);
      expect(a.displayTitle, 'Roygbiv');

      final b = r.seeds[1];
      expect(b.outcome, 'stopped');
      expect(b.finished, isFalse, reason: '"listened to", not "finished"');
      expect(b.analyzed, isFalse);

      final pin = r.seeds[2];
      expect(pin.pinned, isTrue);
      expect(pin.outcome, isNull);
      expect(pin.lastPlayed, isNull);
      expect(pin.metadata, isNull);
      expect(pin.displayTitle, 'Pinned.mp3');
    });

    test('excluded seeds list for the seeds sheet', () {
      expect(r.excluded, hasLength(1));
      expect(r.excluded.single.hash, 'h-dropped');
      expect(r.excluded.single.filepath, 'music/Dropped.mp3');
      expect(r.excluded.single.displayTitle, 'Dropped');
    });

    test('library tracks are DiscoveryTracks with play facts', () {
      final lib = r.library!;
      expect(lib.filter, TasteFilter.fresh);
      expect(lib.capped, isFalse);
      expect(lib.tracks, hasLength(2));
      final t = lib.tracks[0];
      expect(t, isA<DiscoveryTrack>(),
          reason: 'the similar-tracks row helpers take it as-is');
      expect(t.filepath, 'music/Tycho/Awake.flac');
      expect(t.similarity, closeTo(0.83, 1e-9));
      expect(t.seedHash, 'h-seed-1');
      expect(t.metadata?.title, 'Awake');
      expect(t.metadata?.durationSeconds, closeTo(284.0, 1e-9));
      expect(t.genreTags, ['Electronic---Downtempo', 'Electronic---Ambient']);
      expect(t.playCount, 0);
      expect(t.lastPlayed, isNull);
      final played = lib.tracks[1];
      expect(played.playCount, 2);
      expect(played.lastPlayed, DateTime.utc(2026, 1, 12, 10));
    });

    test('album cards carry the /db/albums identity and play facts', () {
      final albums = r.library!.albums;
      expect(albums, hasLength(2));
      final dive = albums[0];
      expect(dive.name, 'Dive');
      expect(dive.year, 2011);
      expect(dive.albumArtFile, 'dive.jpg');
      expect(dive.albumArtist, 'Tycho');
      expect(dive.artists, ['Tycho']);
      expect(dive.trackCount, 10);
      expect(dive.similarity, closeTo(0.84, 1e-9));
      expect(dive.scopedTracks, 10);
      expect(dive.playedTracks, 0);
      expect(dive.unplayed, isTrue);
      expect(dive.lastPlayed, isNull);
      expect(dive.tracks,
          ['music/Tycho/Dive/01.flac', 'music/Tycho/Dive/02.flac']);

      final lnt = albums[1];
      expect(lnt.albumArtFile, isNull);
      expect(lnt.albumArtist, isNull);
      expect(lnt.artists, ['Various', 'Artists']);
      expect(lnt.unplayed, isFalse);
      expect(lnt.lastPlayed, DateTime.utc(2025, 3, 1, 12));
      expect(lnt.tracks, isEmpty);
    });

    test('network leads keep provenance and the raw row', () {
      final net = r.network!;
      expect(net.searchedPeers, 3);
      expect(net.searchedTracks, 7421);
      final lead = net.results.single;
      expect(lead.artist, 'Helios');
      expect(lead.title, 'Halving the Compass');
      expect(lead.album, 'Eingya');
      expect(lead.year, 2006);
      expect(lead.durationSeconds, closeTo(301.5, 1e-9));
      expect(lead.recordingMbid, '9b7c-mbid');
      expect(lead.peerName, 'Riverside');
      expect(lead.peerId, isNull, reason: 'p2p peers have an endpoint, no id');
      expect(lead.source, 'p2p');
      expect(lead.seedHash, 'h-seed-1');
      expect(lead.copyText, 'Helios - Halving the Compass');
      // Forwarded unchanged to resolve / jobs / lookup later.
      expect(lead.raw['exportId'], 'x-42');
      expect(lead.raw['peer'], {'endpointId': 'ep-abc', 'name': 'Riverside'});
      expect(lead.raw['source'], 'p2p');
      expect(() => lead.raw['x'] = 1, throwsUnsupportedError);
    });

    test('peers are grouped, with state and playable rows', () {
      final peers = r.peers!;
      expect(peers.searchedPeers, 3);
      expect(peers.unreachablePeers, 1);
      expect(peers.mismatchedPeers, 0);
      expect(peers.peers, hasLength(2));
      final sam = peers.peers[0];
      expect(sam.id, 1);
      expect(sam.name, "Sam's server");
      expect(sam.reachable, isTrue);
      expect(sam.mismatched, isFalse);
      expect(sam.lastSeen, DateTime.utc(2026, 10, 5, 9));
      final row = sam.results.single;
      expect(row.filepath, 'sams/Nils Frahm/Says.flac',
          reason: "the PEER's path — what the stream proxy plays");
      expect(row.peerId, 1);
      expect(row.peerName, "Sam's server");
      expect(row.source, 'federation');
      expect(row.seedHash, isNull);
      expect(row.genreTags, ['Electronic---Ambient']);

      final basement = peers.peers[1];
      expect(basement.reachable, isFalse);
      expect(basement.results, isEmpty);
      // SQLite text (federation_peers) reads as UTC too.
      expect(basement.lastSeen, DateTime.utc(2026, 9, 1, 10));
      expect(peers.allResults, [row]);
    });
  });

  group('TasteResponse.fromServerMap — minimal payloads', () {
    test('an empty object parses to an empty answer', () {
      final r = TasteResponse.fromServerMap({});
      expect(r.window, isNull);
      expect(r.seedSource, isNull);
      expect(r.fallback, isFalse);
      expect(r.seeds, isEmpty);
      expect(r.excluded, isEmpty);
      expect(r.dropped, 0);
      expect(r.notAnalyzed, isFalse);
      expect(r.model, isNull);
      expect(r.library, isNull);
      expect(r.network, isNull);
      expect(r.peers, isNull);
    });

    test('the random fallback: one seed, no fan-outs, widened', () {
      final r = TasteResponse.fromServerMap({
        'window': 30,
        'widenedFrom': 30,
        'seedSource': 'random',
        'fallback': true,
        'seeds': [
          {'hash': 'h', 'filepath': 'music/a.mp3'},
        ],
        'library': {'filter': 'unplayed', 'tracks': [], 'albums': []},
        'network': null,
        'peers': null,
      });
      expect(r.widenedFrom, 30);
      expect(r.seedSource, TasteSeedSource.random);
      expect(r.fallback, isTrue);
      final seed = r.seeds.single;
      expect(seed.plays, 0);
      expect(seed.pinned, isFalse);
      expect(seed.analyzed, isTrue, reason: 'absent reads as analyzed');
      expect(seed.outcome, isNull);
      expect(r.library!.filter, TasteFilter.unplayed);
      expect(r.library!.tracks, isEmpty);
      expect(r.library!.capped, isFalse);
      expect(r.network, isNull);
      expect(r.peers, isNull);
    });

    test('a peers-only call answers no library', () {
      final r = TasteResponse.fromServerMap({
        'seedSource': 'counters',
        'peers': {'peers': [], 'searched': {}},
      });
      expect(r.seedSource, TasteSeedSource.counters);
      expect(r.library, isNull);
      expect(r.peers!.peers, isEmpty);
      expect(r.peers!.searchedPeers, 0);
    });

    test('scan pending is reported, seeds still listed', () {
      final r = TasteResponse.fromServerMap({
        'notAnalyzed': true,
        'seedSource': 'pinned',
        'seeds': [
          {'hash': 'h', 'filepath': 'music/a.mp3', 'analyzed': false},
        ],
      });
      expect(r.notAnalyzed, isTrue);
      expect(r.seedSource, TasteSeedSource.pinned);
      expect(r.seeds.single.analyzed, isFalse);
    });
  });

  group('TasteResponse.fromServerMap — hostile types', () {
    test('wrong-typed top-level fields fall back instead of throwing', () {
      final r = TasteResponse.fromServerMap({
        'window': 'thirty',
        'widenedFrom': -7,
        'seedSource': 'vibes',
        'fallback': 'true',
        'seeds': 'none',
        'excluded': {'h': 1},
        'dropped': -3,
        'notAnalyzed': 1,
        'model': 'effnet',
        'library': [],
        'network': 'off',
        'peers': 42,
      });
      expect(r.window, isNull);
      expect(r.widenedFrom, isNull);
      expect(r.seedSource, isNull);
      expect(r.fallback, isFalse);
      expect(r.seeds, isEmpty);
      expect(r.excluded, isEmpty);
      expect(r.dropped, 0);
      expect(r.notAnalyzed, isFalse);
      expect(r.model, isNull);
      expect(r.library, isNull);
      expect(r.network, isNull);
      expect(r.peers, isNull);
    });

    test('malformed rows are dropped, good ones kept', () {
      final r = TasteResponse.fromServerMap({
        'seeds': [
          null,
          'music/a.mp3',
          {'filepath': 'music/no-hash.mp3'},
          {'hash': 'h-no-path'},
          {'hash': 12, 'filepath': 'music/x.mp3'},
          {'hash': 'h' * 129, 'filepath': 'music/x.mp3'},
          {'hash': 'h', 'filepath': 'm/${'x' * 2048}'},
          {'hash': '   ', 'filepath': 'music/x.mp3'},
          {'hash': 'ok', 'filepath': 'music/ok.mp3'},
        ],
        'library': {
          'filter': 7,
          'capped': 'yes',
          'tracks': [
            {'similarity': 0.9},
            {'filepath': 42},
            {'filepath': 'music/t.mp3', 'similarity': 'high'},
          ],
          'albums': [
            {'year': 2000},
            {'name': ''},
            {'name': 'x' * 513},
            {'name': 'Kept'},
          ],
        },
        'network': {
          'results': [
            {'artist': 'No title'},
            {'title': 5},
            {'title': 'Kept lead'},
          ],
        },
        'peers': {
          'peers': [
            'peer',
            {'id': 'seven', 'name': 9},
          ],
        },
      });
      expect(r.seeds.map((s) => s.hash), ['ok']);
      expect(r.library!.filter, isNull);
      expect(r.library!.capped, isFalse);
      final t = r.library!.tracks.single;
      expect(t.filepath, 'music/t.mp3');
      expect(t.similarity, 0);
      expect(t.metadata, isNull);
      expect(t.playCount, isNull);
      expect(r.library!.albums.map((a) => a.name), ['Kept']);
      expect(r.network!.results.single.title, 'Kept lead');
      expect(r.network!.results.single.artist, '');
      // A group with a junk id and name still reports, without identity.
      final g = r.peers!.peers.single;
      expect(g.id, isNull);
      expect(g.name, '');
      expect(g.reachable, isFalse, reason: 'no state and no rows');
    });

    test('hostile metadata never throws out of the row', () {
      // MusicMetadata.fromServerMap hands these keys straight to typed
      // slots; the taste parser checks them first.
      final r = TasteResponse.fromServerMap({
        'library': {
          'tracks': [
            {
              'filepath': 'music/t.mp3',
              'metadata': {
                'title': 99,
                'artist': ['a'],
                'album': 'x' * 600,
                'album-art': {'f': 1},
                'year': '1999',
                'track': 3.7,
                'disk': 'one',
                'bpm': 120.4,
                'musical-key': false,
                'hash': 7,
                'duration': 'long',
                'rating': 'five',
                'genres': 'Rock',
              },
              'seedHash': 5,
              'playCount': -2,
              'lastPlayed': 'yesterday',
              'genreTags': [1, 'Rock---Indie', ''],
            },
          ],
        },
      });
      final t = r.library!.tracks.single;
      final md = t.metadata!;
      expect(md.title, isNull);
      expect(md.artist, isNull);
      expect(md.album, isNull, reason: 'over the 512 cap reads as absent');
      expect(md.albumArt, isNull);
      expect(md.year, 1999, reason: 'a numeric string is still a year');
      expect(md.track, 4);
      expect(md.disc, isNull);
      expect(md.bpm, 120);
      expect(md.musicalKey, isNull);
      expect(md.hash, '');
      expect(md.durationSeconds, isNull);
      expect(md.rating, isNull);
      expect(md.genres, ['Rock']);
      expect(t.displayTitle, 't.mp3');
      expect(t.seedHash, isNull);
      expect(t.playCount, isNull);
      expect(t.lastPlayed, isNull);
      expect(t.genreTags, ['Rock---Indie']);
    });

    test('similarity is clamped to 0..1', () {
      final r = TasteResponse.fromServerMap({
        'library': {
          'tracks': [
            {'filepath': 'a', 'similarity': 7},
            {'filepath': 'b', 'similarity': -1},
            {'filepath': 'c', 'similarity': '0.5'},
          ],
          'albums': [
            {'name': 'A', 'similarity': double.nan},
          ],
        },
      });
      expect(r.library!.tracks.map((t) => t.similarity), [1.0, 0.0, 0.5]);
      expect(r.library!.albums.single.similarity, 0);
    });

    test('a peers row without its own peer takes the group\'s', () {
      final r = TasteResponse.fromServerMap({
        'peers': {
          'peers': [
            {
              'id': 4,
              'name': 'Attic',
              'results': [
                {'title': 'Song', 'filepath': 'attic/song.mp3'},
              ],
            },
          ],
        },
      });
      final row = r.peers!.peers.single.results.single;
      expect(row.peerId, 4);
      expect(row.peerName, 'Attic');
      expect(r.peers!.peers.single.reachable, isTrue,
          reason: 'no state, but it answered rows');
    });
  });

  group('ISO dates', () {
    DateTime? seedDate(Object? v) => TasteResponse.fromServerMap({
          'seeds': [
            {'hash': 'h', 'filepath': 'f', 'lastPlayed': v},
          ],
        }).seeds.single.lastPlayed;

    test('every accepted form reads as the same UTC instant', () {
      final want = DateTime.utc(2026, 10, 4, 21, 10);
      expect(seedDate('2026-10-04T21:10:00.000Z'), want);
      expect(seedDate('2026-10-04T23:10:00+02:00'), want);
      expect(seedDate('2026-10-04T21:10:00'), want,
          reason: 'no zone = UTC, as the server writes');
      expect(seedDate('2026-10-04 21:10:00.000'), want);
    });

    test('anything else is absent', () {
      expect(seedDate(null), isNull);
      expect(seedDate(''), isNull);
      expect(seedDate('soon'), isNull);
      expect(seedDate(1759612200000), isNull,
          reason: 'epoch numbers are not the contract');
    });
  });

  group('TasteRequest.toJson', () {
    test('an empty request sends nothing, so saved prefs apply', () {
      expect(const TasteRequest().toJson(), isEmpty);
    });

    test('sends only the set fields, in wire form', () {
      final j = const TasteRequest(
        window: 90,
        pin: ['/music/now playing.mp3', 'music/picked.flac'],
        exclude: ['h1', 'h2'],
        remember: true,
        filter: TasteFilter.unplayed,
        staleDays: 120,
        sources: {TasteSource.peers, TasteSource.library},
        limit: TasteLimits(seeds: 6, tracks: 24),
        newArtistsOnly: false,
        ignoreVPaths: ['podcasts'],
      ).toJson();
      expect(j, {
        'window': 90,
        'pin': ['music/now playing.mp3', 'music/picked.flac'],
        'exclude': ['h1', 'h2'],
        'remember': true,
        'filter': 'unplayed',
        'staleDays': 120,
        'sources': ['library', 'peers'],
        'limit': {'seeds': 6, 'tracks': 24},
        'newArtistsOnly': false,
        'ignoreVPaths': ['podcasts'],
      });
    });

    test('all time is window 0', () {
      expect(const TasteRequest(window: 0).toJson(), {'window': 0});
    });

    test('values the route would 400 on are clamped or left out', () {
      final j = TasteRequest(
        window: 14, // not a window the route takes → the saved pref
        pin: ['/a', '/', ...List.generate(10, (i) => 'p$i')],
        exclude: ['', 'x' * 129, ...List.generate(205, (i) => 'h$i')],
        staleDays: 99999,
        sources: const {},
        limit: const TasteLimits(
            seeds: 99, tracks: 0, albums: 99, network: 99, peers: 99),
        ignoreVPaths: const [],
      ).toJson();
      expect(j.containsKey('window'), isFalse);
      expect(j['pin'], ['a', 'p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
          reason: '≤ 8 pins, slashes stripped, empty paths dropped');
      final ex = j['exclude'] as List;
      expect(ex, hasLength(200));
      expect(ex.first, 'h5', reason: 'the newest 200 are kept');
      expect(ex.last, 'h204');
      expect(j['staleDays'], 3650);
      expect(j.containsKey('sources'), isFalse);
      expect(j['limit'],
          {'seeds': 12, 'tracks': 1, 'albums': 24, 'network': 50, 'peers': 25});
      expect(j.containsKey('ignoreVPaths'), isFalse);
    });
  });

  group('TastePrefs', () {
    test('parses the saved prefs', () {
      final p = TastePrefs.fromServerMap({
        'window': 7,
        'exclude': ['h1', 'h2'],
        'filter': 'all',
        'staleDays': 30,
      });
      expect(p.window, 7);
      expect(p.exclude, ['h1', 'h2']);
      expect(p.filter, TasteFilter.all);
      expect(p.staleDays, 30);
    });

    test('accepts a {prefs: …} envelope', () {
      final p = TastePrefs.fromServerMap({
        'prefs': {'window': 0, 'filter': 'fresh'}
      });
      expect(p.window, 0);
      expect(p.filter, TasteFilter.fresh);
    });

    test('nothing saved, or junk, reads as unset', () {
      final empty = TastePrefs.fromServerMap({});
      expect(empty.window, isNull);
      expect(empty.exclude, isNull);
      expect(empty.filter, isNull);
      expect(empty.staleDays, isNull);
      final junk = TastePrefs.fromServerMap({
        'window': 45,
        'exclude': ['ok', 3, null, ''],
        'filter': 'recent',
        'staleDays': 0,
      });
      expect(junk.window, isNull);
      expect(junk.exclude, ['ok']);
      expect(junk.filter, isNull);
      expect(junk.staleDays, isNull);
    });

    test('a patch sends only what it sets', () {
      expect(const TastePrefs().toJson(), isEmpty);
      expect(const TastePrefs(window: 90).toJson(), {'window': 90});
      expect(
          TastePrefs(
                  exclude: List.generate(201, (i) => 'h$i'),
                  filter: TasteFilter.fresh,
                  staleDays: 0)
              .toJson(),
          {
            'exclude': List.generate(200, (i) => 'h${i + 1}'),
            'filter': 'fresh',
            'staleDays': 1,
          });
      expect(const TastePrefs(exclude: []).toJson(), {'exclude': []},
          reason: 'an empty list clears the saved exclusions');
    });
  });

  group('DiscoveryLead on the per-song routes', () {
    test('a plain /federation/similar row still parses, now with its path',
        () {
      final lead = DiscoveryLead.fromServerMap({
        'artist': 'A',
        'title': 'T',
        'similarity': 0.5,
        'duration': 200,
        'filepath': 'peer/a.mp3',
        'peer': {'id': 3, 'name': 'P'},
      })!;
      expect(lead.peerName, 'P');
      expect(lead.peerId, 3);
      expect(lead.filepath, 'peer/a.mp3');
      expect(lead.source, isNull, reason: 'only taste rows are stamped');
      expect(lead.raw['filepath'], 'peer/a.mp3');
    });
  });
}
