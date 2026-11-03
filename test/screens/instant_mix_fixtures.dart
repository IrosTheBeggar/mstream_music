// Shared fixtures for the Instant mix page tests: a server that can make a
// mix, answers in the route's wire shape (lite kebab-case metadata, paths
// WITHOUT the leading slash; the demo library's Dolo mixes), and filter
// states for the re-asks.

import 'dart:async';

import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/instant_mix.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/mix_filters.dart';
import 'package:mstream_music/objects/server.dart';

/// A scripted mix route: records every body and answers each through a
/// completer the test resolves (or [auto] answers at once).
class FakeMix {
  final List<Map<String, dynamic>> bodies = [];
  final List<Completer<DiscoveryFetchResult<MixAnswer>>> pending = [];
  DiscoveryFetchResult<MixAnswer> Function(Map<String, dynamic>)? auto;

  Future<DiscoveryFetchResult<MixAnswer>> call(
      Server s, Map<String, dynamic> body) {
    bodies.add(body);
    if (auto != null) return Future.value(auto!(body));
    final c = Completer<DiscoveryFetchResult<MixAnswer>>();
    pending.add(c);
    return c.future;
  }
}

/// Dolo, the demo library's seed song, as a browsed row on [server].
DisplayItem doloRow(Server server) => DisplayItem(
    server,
    '/demo/Boukmanflow/Dolo.mp3',
    'file',
    '/demo/Boukmanflow/Dolo.mp3',
    null,
    null)
  ..metadata = MusicMetadata('Boukmanflow', 'Stim Pack Volume one', 'Dolo',
      null, null, null, 'h1', null, null,
      bpm: 87, musicalKey: 'Bb minor');

/// A server with Instant mix (generation 1) and a ready sonic index.
Server mixServer() => Server('http://music.example', null, null, 'JWT', 'home')
  ..discoveryAvailable = true
  ..discoveryEnabled = true
  ..discoveryReady = true
  ..instantMixGeneration = 1;

/// One answer row. No album art: a test has no image server.
Map<String, dynamic> mixSong(String path, String title, String artist,
        {double similarity = 0.8, String? album}) =>
    {
      'filepath': path,
      'similarity': similarity,
      'metadata': {
        'title': title,
        'artist': artist,
        'album': ?album,
      },
      'genreTags': ['Hip Hop---Instrumental'],
    };

/// Dolo's mix with no filters: the seed leads.
Map<String, dynamic> doloMix() => {
      'model': {'id': 'effnet-discogs', 'version': '1'},
      'seed': {'kind': 'song', 'members': 1, 'analyzed': 1},
      'notAnalyzed': false,
      'songs': [
        mixSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow',
            similarity: 1, album: 'Stim Pack Volume one'),
        mixSong('demo/ALM/Elevation.mp3', 'Elevation', 'ALM'),
        mixSong('demo/Boukmanflow/TopRanking.mp3', 'TopRanking', 'Boukmanflow'),
        mixSong('demo/ALM/Enfance.mp3', 'Enfance', 'ALM'),
      ],
      'short': true,
      'capped': false,
      'relaxed': const [],
      'floor': 0.4,
      'filteredOut': false,
      'moods': const {},
    };

/// Dolo's mix under a filter: another list.
Map<String, dynamic> relaxedMix() => {
      'notAnalyzed': false,
      'songs': [
        mixSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow',
            similarity: 1),
        mixSong('demo/ALM/Enfance.mp3', 'Enfance', 'ALM'),
        mixSong('demo/Boukmanflow/The Hangout.mp3', 'The Hangout',
            'Boukmanflow'),
      ],
      'filteredOut': false,
      'moods': {'energy': 'relaxed'},
    };

/// Filter states for the re-asks: one choice each, sent beside `from` and
/// `limit` whatever the server's flags and the seed — words to skip.
const MixFilters skipLive = MixFilters(skipWords: ['live']);
const MixFilters skipRemix = MixFilters(skipWords: ['remix']);
