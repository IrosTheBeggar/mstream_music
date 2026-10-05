// Shared fixtures for the Discover page tests: a server with the page's
// flags, and taste payloads in the plan §3.1 wire shape (lite kebab-case
// metadata, vpath-form paths WITHOUT the leading slash, ISO timestamps).

import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';

Server discoveryServer({bool peers = true}) =>
    Server('http://music.example', null, null, 'JWT', 'home')
      ..discoveryAvailable = true
      ..discoveryTasteAvailable = true
      ..discoveryP2pAvailable = true
      ..federationDiscoveryAvailable = peers;

Map<String, dynamic> seedRow(String hash, String title, String artist,
        {String outcome = 'completed',
        bool pinned = false,
        int plays = 1,
        String lastPlayed = '2026-10-04T21:10:00.000Z'}) =>
    {
      'hash': hash,
      'filepath': 'music/$artist/$title.flac',
      'metadata': {'title': title, 'artist': artist},
      'outcome': pinned ? null : outcome,
      'lastPlayed': pinned ? null : lastPlayed,
      'plays': plays,
      'pinned': pinned,
      'analyzed': true,
    };

Map<String, dynamic> trackRow(String title, String artist, double sim,
        {int? playCount = 0, String? lastPlayed}) =>
    {
      'filepath': 'music/$artist/$title.mp3',
      'similarity': sim,
      'seedHash': 'h1',
      'metadata': {'title': title, 'artist': artist},
      'genreTags': ['Electronic---Ambient'],
      'playCount': playCount,
      'lastPlayed': lastPlayed,
    };

/// A history-seeded library + network answer.
Map<String, dynamic> mainPayload({
  String seedSource = 'history',
  bool fallback = false,
  List<Map<String, dynamic>>? seeds,
  List<Map<String, dynamic>>? tracks,
  bool network = true,
  String filter = 'fresh',
  int window = 30,
}) =>
    {
      'window': window,
      'widenedFrom': null,
      'seedSource': seedSource,
      'fallback': fallback,
      'seeds': seeds ??
          [
            seedRow('h1', 'Manor', 'ALM', plays: 3),
            seedRow('h2', 'Roygbiv', 'Boards of Canada'),
            seedRow('h3', 'Xtal', 'Aphex Twin'),
            seedRow('h4', 'Kerala', 'Bonobo'),
            seedRow('h5', 'Awake', 'Tycho'),
          ],
      'excluded': [
        {
          'hash': 'h-dropped',
          'filepath': 'music/Kids/Song.mp3',
          'metadata': {'title': 'Kids Song', 'artist': 'Someone'},
        },
      ],
      'dropped': 0,
      'notAnalyzed': false,
      'model': {'id': 'effnet-discogs', 'version': '1'},
      'library': {
        'filter': filter,
        'tracks': tracks ??
            [
              trackRow('Dawn Chorus', 'Moderat', 0.83),
              trackRow('Cirrus', 'Bonobo', 0.80,
                  playCount: 2, lastPlayed: '2026-02-01T10:00:00.000Z'),
              trackRow('Open Eye Signal', 'Jon Hopkins', 0.78),
              trackRow('Weightless', 'Marconi Union', 0.75),
              trackRow('Teardrop', 'Massive Attack', 0.72),
            ],
        'albums': [
          {
            'name': 'Dive',
            'year': 2011,
            'album_art_file': null,
            'album_artist': 'Tycho',
            'artists': ['Tycho'],
            'track_count': 10,
            'similarity': 0.84,
            'scopedTracks': 10,
            'playedTracks': 0,
            'lastPlayed': null,
            'tracks': ['music/Tycho/Dive/01.flac'],
          },
          {
            'name': 'Immunity',
            'year': 2013,
            'album_art_file': null,
            'album_artist': 'Jon Hopkins',
            'artists': ['Jon Hopkins'],
            'track_count': 12,
            'similarity': 0.77,
            'scopedTracks': 12,
            'playedTracks': 2,
            'lastPlayed': '2026-05-01T10:00:00.000Z',
            'tracks': [],
          },
        ],
        'capped': false,
      },
      'network': network
          ? {
              'results': [
                {
                  'artist': 'Nils Frahm',
                  'title': 'Says',
                  'similarity': 0.81,
                  'duration': 500,
                  'recordingMbid': null,
                  'peer': {'name': 'far-away'},
                  'source': 'p2p',
                  'seedHash': 'h1',
                },
              ],
              'searched': {'peers': 3, 'tracks': 7421},
            }
          : null,
      'peers': null,
    };

/// The peers call's answer: one online peer with a row, one offline.
Map<String, dynamic> peersPayload() => {
      'window': 30,
      'seedSource': 'history',
      'seeds': [],
      'library': null,
      'network': null,
      'peers': {
        'peers': [
          {
            'id': 7,
            'name': "Sam's server",
            'reachable': true,
            'mismatched': false,
            'lastSeen': '2026-10-05T08:00:00.000Z',
            'results': [
              {
                'artist': 'Kiasmos',
                'title': 'Blurred EP',
                'similarity': 0.79,
                'filepath': 'sam/Kiasmos/Blurred.flac',
                'source': 'federation',
                'seedHash': null,
              },
            ],
          },
          {
            'id': 9,
            'name': "Lee's server",
            'reachable': false,
            'mismatched': false,
            'results': [],
          },
        ],
        'searched': {'peers': 2, 'unreachable': 1, 'mismatched': 0},
      },
    };

TasteResponse parse(Map<String, dynamic> m) => TasteResponse.fromServerMap(m);

/// Whether a request asked for the peers source only.
bool isPeersCall(TasteRequest r) =>
    r.sources != null &&
    r.sources!.length == 1 &&
    r.sources!.contains(TasteSource.peers);
