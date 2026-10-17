// Shared fixtures for the Discover page tests: a server with the page's
// flags, and taste payloads in the plan §3.1 wire shape (lite kebab-case
// metadata, vpath-form paths WITHOUT the leading slash, ISO timestamps).

import 'package:flutter/widgets.dart';
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

/// The request's `exclude` hashes (none when it sent none) — what a fake
/// route echoes back as the answer's `excluded` rows.
List<String> excludeOf(TasteRequest r) =>
    (r.toJson()['exclude'] as List?)?.cast<String>() ?? const [];

/// A history-seeded library + network answer. [exclude] is the request's
/// exclusions: the stateless route lists a row for each one that resolves,
/// and none on a call that sent none.
Map<String, dynamic> mainPayload({
  String seedSource = 'history',
  bool fallback = false,
  List<Map<String, dynamic>>? seeds,
  List<Map<String, dynamic>>? tracks,
  bool network = true,
  int window = 30,
  List<String> exclude = const [],
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
        for (final h in exclude)
          {
            'hash': h,
            'filepath': 'music/Left/$h.mp3',
            'metadata': {'title': 'Left $h', 'artist': 'Someone'},
          },
      ],
      'dropped': 0,
      'notAnalyzed': false,
      'model': {'id': 'effnet-discogs', 'version': '1'},
      'library': {
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

/// The URL a DisplayItem's art widget loads — getImage()'s Image.network,
/// or getAlbumThumb()'s clipped, cache-sized one — or null when it draws
/// the note / placeholder tile instead.
String? artUrlOf(Widget? w) {
  Widget? cur = w;
  if (cur is ClipRRect) cur = cur.child;
  if (cur is! Image) return null;
  var p = cur.image;
  if (p is ResizeImage) p = p.imageProvider;
  return p is NetworkImage ? p.url : null;
}

/// A federation row in a peers answer. [art] is its `albumArt` — the
/// peer's cached cover name (mStream plan §3.1, "Peer covers").
Map<String, dynamic> peerRow(String title, String artist, double sim,
        {String? album, String? path, String? art}) =>
    {
      'artist': artist,
      'title': title,
      'similarity': sim,
      'filepath': ?path,
      'album': ?album,
      'albumArt': ?art,
      'source': 'federation',
      'seedHash': null,
    };

/// The peers call's answer from five connected servers: Sam and Lee
/// answered (both mirrored in the tests that use this), Kim answered but is
/// not mirrored, Ola is offline, Ivo runs another sound model.
Map<String, dynamic> manyPeersPayload() => {
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
            'results': [
              peerRow('Alpha', 'Kiasmos', 0.70,
                  album: 'Blurred', path: 'sam/a.flac', art: 'blurred.jpg'),
              peerRow('Bravo', 'Kiasmos', 0.90,
                  album: 'Blurred', path: 'sam/b.flac'),
              peerRow('Charlie', 'Ólafur Arnalds', 0.60, path: 'sam/c.flac'),
            ],
          },
          {
            'id': 8,
            'name': "Lee's server",
            'reachable': true,
            'mismatched': false,
            'results': [
              peerRow('Delta', 'Rival Consoles', 0.80,
                  album: 'Persona', path: 'lee/d.flac'),
              // No path: nothing to stream.
              peerRow('Echo', 'Rival Consoles', 0.75, album: 'Persona'),
            ],
          },
          {
            'id': 9,
            'name': "Kim's server",
            'reachable': true,
            'mismatched': false,
            'results': [
              peerRow('Foxtrot', 'Jon Hopkins', 0.95, path: 'kim/f.flac'),
            ],
          },
          {
            'id': 10,
            'name': "Ola's server",
            'reachable': false,
            'mismatched': false,
            'results': [
              peerRow('Golf', 'Tycho', 0.99, path: 'ola/g.flac'),
            ],
          },
          {
            'id': 11,
            'name': "Ivo's server",
            'reachable': true,
            'mismatched': true,
            'results': [
              peerRow('Hotel', 'Bonobo', 0.97, path: 'ivo/h.flac'),
            ],
          },
        ],
        'searched': {'peers': 5, 'unreachable': 1, 'mismatched': 1},
      },
    };

TasteResponse parse(Map<String, dynamic> m) => TasteResponse.fromServerMap(m);

/// Whether a request asked for the peers source only.
bool isPeersCall(TasteRequest r) =>
    r.sources != null &&
    r.sources!.length == 1 &&
    r.sources!.contains(TasteSource.peers);
