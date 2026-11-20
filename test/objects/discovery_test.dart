import 'dart:convert';
import 'dart:io';

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

  group('DiscoveryPath.fromServerMap', () {
    test('parses an ordered journey with seeds included', () {
      final p = DiscoveryPath.fromServerMap({
        'start': {'filepath': 'music/a.mp3'},
        'end': {'filepath': 'music/z.mp3'},
        'model': {'id': 'effnet-discogs', 'version': '1'},
        'notAnalyzed': {'start': false, 'end': false},
        'results': [
          {
            'filepath': 'music/a.mp3',
            'similarity': 1,
            't': 0,
            'metadata': {'title': 'Start', 'artist': 'A'},
            'genreTags': null,
          },
          {
            'filepath': 'music/way.mp3',
            'similarity': 0.9912,
            't': 0.5,
            'metadata': {'title': 'Waypoint', 'artist': 'W'},
            'genreTags': ['Rock---Indie'],
          },
          {
            'filepath': 'music/z.mp3',
            'similarity': 1,
            't': 1,
            'metadata': {'title': 'End', 'artist': 'Z'},
            'genreTags': null,
          },
        ],
      });
      expect(p.notAnalyzed, isFalse);
      expect(p.results, hasLength(3));
      expect(p.results.map((t) => t.filepath),
          ['music/a.mp3', 'music/way.mp3', 'music/z.mp3']);
      expect(p.results[1].similarity, closeTo(0.9912, 1e-9));
      expect(p.results[1].genreTags, ['Rock---Indie']);
      // The wire's `t` is implied by order — DiscoveryTrack ignores it.
      expect(p.results.first.metadata?.title, 'Start');
    });

    test('flags which end is unanalyzed; tolerates missing keys', () {
      final p = DiscoveryPath.fromServerMap({
        'notAnalyzed': {'start': true, 'end': false},
        'results': [],
      });
      expect(p.notAnalyzedStart, isTrue);
      expect(p.notAnalyzedEnd, isFalse);
      expect(p.notAnalyzed, isTrue);
      expect(p.results, isEmpty);

      final empty = DiscoveryPath.fromServerMap({});
      expect(empty.notAnalyzed, isFalse);
      expect(empty.results, isEmpty);
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

  group('a network row made sendable (sendableRecommendation)', () {
    /// A per-song P2P row exactly as discovery-p2p.js builds it: the shelf's
    /// catalogue columns as the peer's snapshot spelled them, no source.
    Map<String, dynamic> p2pRow([Map<String, dynamic> over = const {}]) => {
          'artist': 'Static Bloom',
          'title': 'Paper Satellites',
          'album': 'Tidewater',
          'year': 2011,
          'isrc': 'US-RC1-76-07839',
          'releaseGroupMbid': null,
          'duration': 238.4,
          'similarity': 0.88,
          'recordingMbid': null,
          'exportId': 'x1',
          'peer': {'endpointId': 'ep1', 'name': 'Vinyl Vault'},
          'seedIndex': 0,
          ...over,
        };

    test('a valid row passes: source p2p added, unknown keys kept, read-only', () {
      final rec = sendableRecommendation(p2pRow({'isrc': 'USRC17607839'}), network: true)!;
      expect(rec, {...p2pRow({'isrc': 'USRC17607839'}), 'source': 'p2p'});
      expect([rec['similarity'], rec['seedIndex']], [0.88, 0], reason: 'the route strips what it does not know');
      expect(() => rec['title'] = 'x', throwsUnsupportedError);
      // Not a network row: no source is stamped (the schema's default
      // applies); one it names stays.
      expect(sendableRecommendation(p2pRow({'isrc': null}))!.containsKey('source'), isFalse);
      expect(sendableRecommendation(p2pRow({'source': 'federation'}), network: true)!['source'], 'federation');
      expect(sendableRecommendation(p2pRow({'source': 'local'}))!['source'], 'local');
    });

    test("a tag's ISRC is spelled the schema's way; one that is no ISRC is nulled", () {
      String? isrc(Object? v) => sendableRecommendation(p2pRow({'isrc': v}), network: true)!['isrc'] as String?;
      expect(isrc('US-RC1-76-07839'), 'USRC17607839');
      expect(isrc(' usrc1 7607839 '), 'USRC17607839');
      expect(isrc('USRC17607839'), 'USRC17607839');
      expect(isrc('BAD'), isNull);
      expect(isrc('USRC176078390'), isNull, reason: 'thirteen');
      expect(isrc('US_RC17607839'), isNull);
      expect(isrc(12345), isNull);
      expect(isrc(''), isNull);
      expect(isrc(null), isNull);
      expect(sendableRecommendation({'title': 't'})!.containsKey('isrc'), isFalse, reason: 'an absent fact stays absent');
    });

    test('a year outside 1000–9999 or no number is nulled, a numeric one made a number; a negative length nulled', () {
      Object? year(Object? v) => sendableRecommendation(p2pRow({'year': v}))!['year'];
      expect([year(0), year(10000), year(999), year('abc'), year(2011.5), year(true), year(null)], [null, null, null, null, null, null, null]);
      expect([year('2011'), year(' 1999 '), year(2011.0), year(1000), year(9999)], [2011, 1999, 2011, 1000, 9999]);
      Object? length(Object? v) => sendableRecommendation(p2pRow({'duration': v}))!['duration'];
      expect([length(-1), length('long'), length(double.nan), length(double.infinity)], [null, null, null, null]);
      expect([length(0), length(238.4), length('238.4'), length(240)], [0, 238.4, 238.4, 240]);
    });

    test('an MBID past 64 or an album past 512 (after a trim) is nulled; so is one that is no text', () {
      final mbid65 = 'a' * 65;
      final rec = sendableRecommendation(p2pRow({
        'recordingMbid': mbid65,
        'releaseGroupMbid': 7,
        'album': 'x' * 513,
        'albumArtist': ['Various'],
      }))!;
      expect([rec['recordingMbid'], rec['releaseGroupMbid'], rec['album'], rec['albumArtist']], [null, null, null, null]);
      final kept = sendableRecommendation(p2pRow({
        'recordingMbid': 'a' * 64,
        'album': '  ${'x' * 512}  ',
        'albumArtist': '',
      }))!;
      expect([kept['recordingMbid'], kept['album'], kept['albumArtist']], ['a' * 64, '  ${'x' * 512}  ', ''],
          reason: 'measured after the trim the schema makes; kept as sent');
    });

    test('what a row IS, its handle and its provenance are never nulled: the row cannot be sent', () {
      for (final (why, over) in <(String, Map<String, dynamic>)>[
        ('artist of 513', {'artist': 'a' * 513}),
        ('artist as a number', {'artist': 42}),
        ('title as a list', {'title': ['x']}),
        ('exportId of 257', {'exportId': 'e' * 257}),
        ('exportId as a number', {'exportId': 7}),
        ('filepath of 2049', {'filepath': 'f' * 2049}),
        ('peer.name of 129', {'peer': {'endpointId': 'ep1', 'name': 'n' * 129}}),
        ('peer.endpointId of 129', {'peer': {'endpointId': 'e' * 129, 'name': 'Vinyl Vault'}}),
        ('peer.id fractional', {'peer': {'id': 1.5}}),
        ('peer.id empty', {'peer': {'id': ''}}),
        ('peer.id a map', {'peer': {'id': {}}}),
        ('peer not an object', {'peer': 'Vinyl Vault'}),
        ('source x', {'source': 'x'}),
        ('source empty', {'source': ''}),
        ('source a number', {'source': 1}),
      ]) {
        expect(sendableRecommendation(p2pRow(over), network: true), isNull, reason: why);
      }
      // Their limits themselves are fine.
      expect(sendableRecommendation(p2pRow({'artist': '${'a' * 512}  ', 'exportId': 'e' * 256, 'peer': {'endpointId': 'e' * 128, 'name': null, 'id': 4}})), isNotNull);
      expect(sendableRecommendation(p2pRow({'peer': {'id': 'peer-1', 'extra': true}})), isNotNull, reason: "the peer's own unknown keys ride along");
      expect(sendableRecommendation(p2pRow({'peer': null})), isNotNull);
    });

    test('a null source is left out (the schema would refuse it); a network row then says p2p', () {
      expect(sendableRecommendation(p2pRow({'source': null}), network: true)!['source'], 'p2p');
      expect(sendableRecommendation(p2pRow({'source': null}))!.containsKey('source'), isFalse);
    });
  });

  group("sendableRecommendation against the server's own schema", () {
    // test/util/fixtures/recommendation_repair_gold.json, made by
    // recommendation_repair_gold.mjs from an mStream checkout: for each row,
    // whether repairRecommendation could make it one the schema takes, the
    // facts it nulled, and normalizeRecommendation's reading of the result.
    final gold = jsonDecode(File('test/util/fixtures/recommendation_repair_gold.json').readAsStringSync()) as Map;
    final cases = (gold['cases'] as List).cast<Map>();

    /// Where the phone is deliberately kinder than the server: a null source
    /// is left out (the schema's default then applies) rather than making
    /// the row unsendable.
    const kinder = {'source null'};

    Object? read(Object? v) {
      if (v is! String) return v;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    test('the facts the server may null are the ones the port nulls', () {
      expect(gold['nullableFacts'], ['album', 'albumArtist', 'year', 'isrc', 'releaseGroupMbid', 'recordingMbid', 'duration']);
      expect(cases.length, greaterThan(40));
    });

    test('the same rows are sendable, the same facts nulled — an ISRC the server nulls only when it is none', () {
      final facts = (gold['nullableFacts'] as List).cast<String>();
      for (final c in cases) {
        final name = c['name'] as String;
        final input = (c['input'] as Map).cast<String, dynamic>();
        final mine = sendableRecommendation(input);
        if (kinder.contains(name)) {
          expect([c['repaired'], mine?.containsKey('source')], [false, false], reason: name);
          continue;
        }
        expect(mine != null, c['repaired'], reason: name);
        if (mine == null) continue;
        final nulled = (c['nulled'] as List).cast<String>().toSet();
        final normalized = c['normalized'] as Map;
        for (final f in facts) {
          if (!nulled.contains(f)) {
            expect(f == 'isrc' ? (read(mine[f]) as String?)?.toUpperCase() : read(mine[f]), normalized[f], reason: '$name $f');
          } else if (f == 'isrc' && mine[f] != null) {
            // The server nulls a tag's spelling; the port spells it the
            // schema's way — only when that is twelve letters and digits.
            final raw = '${input['isrc']}'.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
            expect(mine[f], allOf(raw, matches(RegExp(r'^[A-Z0-9]{12}$'))), reason: '$name $f');
          } else {
            expect(mine[f], isNull, reason: '$name $f');
          }
        }
        for (final k in ['artist', 'title', 'exportId', 'filepath', 'source']) {
          expect(read(mine[k]) ?? (k == 'source' ? 'p2p' : null), normalized[k], reason: '$name $k');
        }
      }
    });
  });

  group('DiscoveryLead: the network facts, isNetwork, the recommendation, withRaw', () {
    final perSong = DiscoveryLeads.fromServerMap({
      'searched': {'peers': 3, 'tracks': 5000},
      'results': [
        {
          'artist': 'Net Artist',
          'title': 'Net Song',
          'album': 'Net Album',
          'year': 0,
          'isrc': 'US-RC1-76-07839',
          'releaseGroupMbid': 'rg-1',
          'duration': 200.5,
          'similarity': 0.87,
          'recordingMbid': 'f4b0-mbid',
          'exportId': 'x1',
          'peer': {'endpointId': 'ep1', 'name': 'peer-name'},
        },
      ],
    }).results.single;
    final federation = DiscoveryLeads.fromServerMap({
      'results': [
        {
          'artist': 'Fed Artist',
          'title': 'Fed Song',
          'similarity': 0.79,
          'filepath': 'peer-vpath/song.mp3',
          'peer': {'id': 1, 'name': 'Friend'},
          'source': 'federation',
        },
      ],
    }).results.single;

    test("the facts a network row carries: the ISRC as the schema spells it, the release group, the export id, the peer's endpoint", () {
      expect([perSong.isrc, perSong.releaseGroupMbid, perSong.exportId, perSong.endpointId], ['USRC17607839', 'rg-1', 'x1', 'ep1']);
      expect([federation.isrc, federation.endpointId], [null, null]);
    });

    test('a per-song P2P row is a network row (no source, a network peer); a federation row is not; a taste p2p row is', () {
      expect(perSong.isNetwork, isTrue);
      expect(federation.isNetwork, isFalse);
      final taste = DiscoveryLead.fromServerMap({'title': 't', 'source': 'p2p', 'peer': {'name': 'x'}})!;
      expect(taste.isNetwork, isTrue);
      expect(DiscoveryLead.fromServerMap({'title': 't'})!.isNetwork, isFalse);
    });

    test('the recommendation: the raw row repaired, stamped p2p; null when it cannot be made one', () {
      final rec = perSong.recommendation!;
      expect([rec['isrc'], rec['year'], rec['source'], rec['exportId']], ['USRC17607839', null, 'p2p', 'x1']);
      expect(perSong.raw['isrc'], 'US-RC1-76-07839', reason: 'raw stays as sent');
      expect(federation.recommendation!['source'], 'federation');
      final broken = DiscoveryLead.fromServerMap({'title': 'ok', 'artist': 42, 'peer': {'endpointId': 'ep1'}})!;
      expect(broken.recommendation, isNull);
    });

    test('withRaw keeps the parsed fields, takes the new raw (read-only), and the facts a repair remakes from it', () {
      final rec = perSong.recommendation!;
      final l = perSong.withRaw(rec);
      expect(perSong.year, 0, reason: 'parsed as the peer tagged it');
      expect([l.artist, l.title, l.similarity, l.durationSeconds, l.recordingMbid, l.peerName, l.album, l.year],
          ['Net Artist', 'Net Song', 0.87, 200.5, 'f4b0-mbid', 'peer-name', 'Net Album', null],
          reason: 'a year of 0 is no year once repaired');
      // What the repair nulls or remakes is what the lead then says.
      final odd = DiscoveryLead.fromServerMap({
        'artist': 'A',
        'title': 'T',
        'album': 'x' * 600,
        'albumArtist': 'Various Artists',
        'year': '2011',
        'duration': '238',
        'peer': {'endpointId': 'ep1'},
      })!;
      expect([odd.album, odd.year, odd.durationSeconds], [null, 2011, null]);
      final fixed = odd.withRaw(odd.recommendation!);
      expect([fixed.album, fixed.albumArtist, fixed.year, fixed.durationSeconds], [null, 'Various Artists', 2011, 238.0]);
      final tooLong = DiscoveryLead.fromServerMap({'title': 'T', 'duration': 1e20, 'peer': {'endpointId': 'ep1'}})!;
      expect(tooLong.withRaw(tooLong.recommendation!).durationSeconds, isNull);
      // A raw without them keeps what was parsed.
      expect(perSong.withRaw(const {'title': 'Net Song'}).year, 0);
      expect([l.isrc, l.releaseGroupMbid, l.exportId, l.endpointId, l.isNetwork, l.source], ['USRC17607839', 'rg-1', 'x1', 'ep1', true, null]);
      expect(l.raw, rec);
      expect(() => l.raw['x'] = 1, throwsUnsupportedError);
      expect(l.recommendation, rec, reason: 'a repaired row repairs to itself');
      final fed = federation.withRaw({...federation.raw, 'extra': 1});
      expect([fed.peerId, fed.filepath, fed.genreTags, fed.raw['extra']], [1, 'peer-vpath/song.mp3', isEmpty, 1]);
    });

    // A Peer Recommendations lead opened in the network-lead sheet goes
    // through _sendable → withRaw (network_lead_sheet.dart): the strip's
    // label and the generated tile must survive it (taste generation 3).
    test('withRaw keeps peerLabel and tile', () {
      final lead = DiscoveryLead.fromServerMap({
        'artist': 'Paper Lantern',
        'title': 'Signal Fires',
        'album': 'Night Ferry',
        'year': 0,
        'source': 'p2p',
        'exportId': 'x1',
        'peer': {'endpointId': 'ep1', 'name': '', 'label': 'mStream · 3f9a'},
        'tile': {'key': 'paper lantern|night ferry', 'hue': 39, 'letter': 'P'},
      })!;
      expect([lead.peerLabel, lead.tile], ['mStream · 3f9a', const LeadTile('paper lantern|night ferry', 39, 'P')]);
      final rec = lead.recommendation!;
      final l = lead.withRaw(rec);
      expect([l.peerLabel, l.tile, l.year], ['mStream · 3f9a', lead.tile, null]);
      // A raw without them keeps what was parsed: they are not re-read from it.
      final bare = lead.withRaw(const {'title': 'Signal Fires'});
      expect([bare.peerLabel, bare.tile], [lead.peerLabel, lead.tile]);
      expect(bare.raw, {'title': 'Signal Fires'});
      // A lead without them stays without them.
      final plain = perSong.withRaw(perSong.recommendation!);
      expect([plain.peerLabel, plain.tile], [null, null]);
    });
  });
}
