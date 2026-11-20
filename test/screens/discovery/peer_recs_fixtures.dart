// Shared fixtures for the Peer Recommendations page's tests (owned by piece
// A of the phone build plan; every other piece imports this read-only).
//
// The wire shapes are the server's own (mStream
// docs/peer-recommendations-plan.md §3.2, §3.4): the peers answer is the
// literal buildPeerView gives over the stage's peers (test/stage/
// peer-recs-stage.mjs: admin, Static Garden adding, Rooftop FM failed
// offline), and the leads are the stage's twelve in its rank order, with
// the tiles the server's leadTile stamps on them (key, FNV-1a-32 hue,
// letter). Every builder returns a fresh, mutable map, so a test may change
// one without touching another's.

import 'dart:convert';

import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/peer_recs.dart';

// ── peers ────────────────────────────────────────────────────────────────

/// The stage's peer ids (64 hex; the head sets the hue).
const String kBasement =
    'ba5eaa206eb20c70adb0cf0ad30db63b8920232f5da363f97a63e83de67cbfa0';
const String kKitchen =
    'cafea9ed902dcc07c36cadfab1be6f48860e86c105e73497e890998d6305e2dc';
const String kAttic =
    'a771c019b58e7329697be5d4bc8d2b14ddd82e4738bb019bca19ae733f53d2a7';
const String kMstream =
    '3f9a1c7cbd00116d0312b285b279e969ca58077702b933169bdb017e0180a4c8';
const String kLighthouse =
    '11fe908bbf9c90af43356bae07fe59911a2e2fa2f9e620d429bb5fe36d05959c';
const String kStatic =
    '57a76a82389134bb7ecdb2db349e629901a5b586b0ae8794d56c4f208d18e557';
const String kRooftop =
    'f00f709723df9278bcb2b7f62724bb0dee17a42b362970ab516a14a51ba72cff';

/// Each stage peer's announced name and its strip label.
const Map<String, ({String name, String label})> kStagePeers = {
  kBasement: (name: 'Basement Hi-Fi', label: 'Basement Hi-Fi'),
  kKitchen: (name: 'Kitchen Radio', label: 'Kitchen Radio'),
  kAttic: (name: 'Attic Tapes', label: 'Attic Tapes'),
  kMstream: (name: 'mStream', label: 'mStream · 3f9a'),
  kLighthouse: (name: 'Lighthouse Tapes', label: 'Lighthouse Tapes'),
  kStatic: (name: 'Static Garden', label: 'Static Garden'),
  kRooftop: (name: 'Rooftop FM', label: 'Rooftop FM'),
};

// The server's buildPeerView over the stage's peers, as an admin sees it
// (server.md §1.1, literal).
const String _peersAdmin = '''
{"canAdd":true,"shelf":{"held":4,"searchable":4,"running":false},"peers":[
 {"endpointId":"ba5eaa206eb20c70adb0cf0ad30db63b8920232f5da363f97a63e83de67cbfa0","name":"Basement Hi-Fi","label":"Basement Hi-Fi","monogram":"BH","hue":210,"online":true,"onShelf":true,"pinned":true,"rowCount":5,"add":null},
 {"endpointId":"cafea9ed902dcc07c36cadfab1be6f48860e86c105e73497e890998d6305e2dc","name":"Kitchen Radio","label":"Kitchen Radio","monogram":"KR","hue":25,"online":true,"onShelf":true,"pinned":true,"rowCount":5,"add":null},
 {"endpointId":"a771c019b58e7329697be5d4bc8d2b14ddd82e4738bb019bca19ae733f53d2a7","name":"Attic Tapes","label":"Attic Tapes","monogram":"AT","hue":112,"online":false,"onShelf":true,"pinned":false,"rowCount":2,"add":null},
 {"endpointId":"3f9a1c7cbd00116d0312b285b279e969ca58077702b933169bdb017e0180a4c8","name":"mStream","label":"mStream · 3f9a","monogram":"mS","hue":140,"online":false,"onShelf":true,"pinned":true,"rowCount":2,"add":null},
 {"endpointId":"11fe908bbf9c90af43356bae07fe59911a2e2fa2f9e620d429bb5fe36d05959c","name":"Lighthouse Tapes","label":"Lighthouse Tapes","monogram":"LT","hue":280,"online":true,"onShelf":false,"pinned":false,"rowCount":9400,"add":null},
 {"endpointId":"57a76a82389134bb7ecdb2db349e629901a5b586b0ae8794d56c4f208d18e557","name":"Static Garden","label":"Static Garden","monogram":"SG","hue":330,"online":true,"onShelf":false,"pinned":false,"rowCount":7000,"add":{"state":"adding","code":null,"at":"2026-11-19T10:00:00.000Z"}},
 {"endpointId":"f00f709723df9278bcb2b7f62724bb0dee17a42b362970ab516a14a51ba72cff","name":"Rooftop FM","label":"Rooftop FM","monogram":"RF","hue":232,"online":true,"onShelf":false,"pinned":false,"rowCount":3100,"add":{"state":"failed","code":"offline","at":"2026-11-19T10:00:00.000Z"}}]}
''';

/// The admin's peers answer: 7 rows — the 4 shelf peers (Attic Tapes and
/// mStream · 3f9a offline), then Lighthouse Tapes ("+"), Static Garden
/// (adding) and Rooftop FM (failed, offline).
Map<String, dynamic> get peersAdminJson =>
    jsonDecode(_peersAdmin) as Map<String, dynamic>;

/// A member's peers answer: `canAdd` false, the same shelf, the first 4
/// rows only, every `add` null.
Map<String, dynamic> get peersMemberJson {
  final m = peersAdminJson;
  m['canAdd'] = false;
  m['peers'] = [
    for (final r in (m['peers'] as List).take(4))
      {...(r as Map<String, dynamic>), 'add': null},
  ];
  return m;
}

/// [json] as [PeerView.fromServerMap] reads it off the wire.
PeerView parsePeers(Map<String, dynamic> json) =>
    PeerView.fromServerMap(_wire(json))!;

// ── leads ────────────────────────────────────────────────────────────────

/// The seed the stage's leads sound like (stage-admin's played Highway).
const String kSeedHash = 'h-highway';
const String kSeedPath = 'testlib/Vosto/Highway.mp3';
const String kSeedTitle = 'Highway';

/// A [leadJson] without a tile key.
const Object kNoTile = _NoTile();

class _NoTile {
  const _NoTile();
}

/// One network lead as the taste route stamps it (stampNetworkRows):
/// `source` p2p, the seed it sounds like, the peer's endpoint id, name and
/// label, and — when given — its tile. [peer] is an endpoint id; [peerName]
/// and [label] default to the stage peer's. [tile] is sent as given (a
/// map, or anything hostile); [kNoTile] leaves the key out. A null [album]
/// is sent as null (Copper Dawn).
Map<String, dynamic> leadJson({
  String title = 'Signal Fires',
  String artist = 'Paper Lantern',
  String? album = 'Night Ferry',
  Object? exportId = 'x-42',
  String peer = kKitchen,
  String? peerName,
  String? label,
  Object? tile = kNoTile,
  String? seedHash = kSeedHash,
  double similarity = 0.9213,
  String? isrc,
  num? duration = 198,
}) =>
    {
      'artist': artist,
      'title': title,
      'album': album,
      'year': null,
      'isrc': isrc,
      'releaseGroupMbid': null,
      'duration': duration,
      'similarity': similarity,
      'recordingMbid': null,
      'exportId': exportId,
      'peer': {
        'endpointId': peer,
        'name': peerName ?? kStagePeers[peer]?.name ?? '',
        'label': label ?? kStagePeers[peer]?.label ?? '',
      },
      'source': 'p2p',
      'seedHash': seedHash,
      if (!identical(tile, kNoTile)) 'tile': tile,
    };

/// A tile as the server stamps it.
Map<String, dynamic> tileJson(String key, int hue, String letter) =>
    {'key': key, 'hue': hue, 'letter': letter};

// The stage's leads, in its rank order (DECISIONS §3, stage :147-160):
// [peer, artist, title, album, length in seconds, tile key, tile hue].
const List<(String, String, String, String?, int, String, int)> _stage = [
  (kBasement, 'Hollow Coast', 'Salt Road', 'Low Tide Hymns', 222, 'hollow coast|low tide hymns', 203),
  (kBasement, 'Hollow Coast', 'Breakwater', 'Low Tide Hymns', 245, 'hollow coast|low tide hymns', 203),
  (kKitchen, 'Paper Lantern', 'Signal Fires', 'Night Ferry', 198, 'paper lantern|night ferry', 39),
  (kKitchen, 'Paper Lantern', 'Harbor Lights', 'Night Ferry', 177, 'paper lantern|night ferry', 39),
  (kBasement, 'Tidewater', 'Glass Season', 'Undertow', 261, 'tidewater|undertow', 4),
  (kMstream, 'Tidewater', 'Quiet Engine', 'Undertow', 213, 'tidewater|undertow', 4),
  (kKitchen, 'Marlowe Fields', 'Long Exposure', 'Daylight Savings', 230, 'marlowe fields|daylight savings', 352),
  (kBasement, 'Juniper Static', 'Arcade Rain', 'Neon Psalms', 164, 'juniper static|neon psalms', 78),
  (kMstream, 'The Vesper Lines', 'Paper Moons', 'Small Hours', 192, 'the vesper lines|small hours', 154),
  (kKitchen, 'Okra Bloom', 'Sunday Wire', 'Porchlight', 248, 'okra bloom|porchlight', 353),
  (kBasement, 'Kestrel & Vine', 'Copper Dawn', null, 181, 'kestrel & vine', 53),
  (kKitchen, 'Ada Merrow', 'Field Notes', 'Cartography', 207, 'ada merrow|cartography', 81),
];

/// The stage's 12 leads (All's answer), in rank order, each with its tile;
/// Basement Hi-Fi 5, Kitchen Radio 5, mStream 2. Kitchen Radio's carry the
/// stage's ISRCs (Signal Fires 'QZPRS2600003'); Copper Dawn has no album.
/// Export ids are 'anon:01' … 'anon:12'; the match falls 1 point per rank
/// from Salt Road's 0.9413 (Signal Fires 0.9213).
List<Map<String, dynamic>> get stageLeads => [
      for (var i = 0; i < _stage.length; i++)
        leadJson(
          peer: _stage[i].$1,
          artist: _stage[i].$2,
          title: _stage[i].$3,
          album: _stage[i].$4,
          duration: _stage[i].$5,
          tile: tileJson(_stage[i].$6, _stage[i].$7, _stage[i].$2[0]),
          exportId: 'anon:${'${i + 1}'.padLeft(2, '0')}',
          similarity: double.parse((0.9413 - 0.01 * i).toStringAsFixed(4)),
          isrc: _stage[i].$1 == kKitchen
              ? 'QZPRS26${'${i + 1}'.padLeft(5, '0')}'
              : null,
        ),
    ];

/// The stage leads of one peer (a tab's answer), in rank order.
List<Map<String, dynamic>> stageLeadsOf(String peer) => [
      for (final l in stageLeads)
        if ((l['peer'] as Map)['endpointId'] == peer) l,
    ];

// ── taste answers ────────────────────────────────────────────────────────

/// One seed of a taste answer (TasteSeed): finished, analyzed, unpinned —
/// or the random pick's shape when [outcome] is null.
Map<String, dynamic> seedJson(String hash, String filepath, String title,
        {String artist = 'Vosto',
        String? outcome = 'completed',
        bool pinned = false,
        bool analyzed = true}) =>
    {
      'hash': hash,
      'filepath': filepath,
      'metadata': {'title': title, 'artist': artist, 'album': null},
      'outcome': outcome,
      'lastPlayed': outcome == null ? null : '2026-11-18T20:00:00.000Z',
      'plays': outcome == null ? null : 1,
      'pinned': pinned,
      'analyzed': analyzed,
    };

/// A page answer (`sources: ['network']`, so `library` and `peers` are
/// null): [seeds] (default: Highway), its [leads] (default: [stageLeads])
/// and the network's [reason]. A `random` [seedSource] is the fallback
/// answer (`fallback: true`). [networkNull] sends `network: null` (p2p off,
/// or a random seed without networkOnRandomSeed).
Map<String, dynamic> tasteJson({
  String seedSource = 'history',
  List<Map<String, dynamic>>? seeds,
  List<Map<String, dynamic>>? leads,
  String? reason,
  bool notAnalyzed = false,
  bool networkNull = false,
}) {
  final results = leads ?? stageLeads;
  return {
    'window': 30,
    'widenedFrom': null,
    'seedSource': seedSource,
    'fallback': seedSource == 'random',
    'seeds': seeds ?? [seedJson(kSeedHash, kSeedPath, kSeedTitle)],
    'excluded': [],
    'dropped': 0,
    'notAnalyzed': notAnalyzed,
    'model': {'id': 'test-fake', 'version': '1'},
    'library': null,
    'peers': null,
    'network': networkNull
        ? null
        : {
            'results': results,
            'searched': {'peers': 3, 'tracks': 14},
            'reason': reason,
          },
  };
}

/// [json] as [TasteResponse.fromServerMap] reads it off the wire.
TasteResponse parseTaste(Map<String, dynamic> json) =>
    TasteResponse.fromServerMap(_wire(json));

/// The leads of [json] (a [tasteJson]), parsed.
List<DiscoveryLead> parseLeads(Map<String, dynamic> json) =>
    parseTaste(json).network?.results ?? const [];

// ── previews ─────────────────────────────────────────────────────────────

/// A Deezer resolve's clip (deezer.js choose), matching Signal Fires on its
/// album: https clip, link and 250 px cover by default. Pass null for none.
PluginPreview deezerPreview({
  String? title = 'Signal Fires',
  String? album = 'Night Ferry',
  String? artist = 'Paper Lantern',
  String? artwork = 'https://e-cdns-images.dzcdn.example/cover/250x250.jpg',
  String url = 'https://cdns-preview.dzcdn.example/signal-fires.mp3',
  String? link = 'https://www.deezer.com/track/3',
  String? attribution = 'Preview from Deezer',
}) =>
    PluginPreview(
      provider: kDeezerPlugin,
      url: Uri.parse(url),
      title: title,
      artist: artist,
      album: album,
      attribution: attribution,
      link: link == null ? null : Uri.parse(link),
      artwork: artwork == null ? null : Uri.parse(artwork),
      match: 1,
    );

/// A JSON round trip: the types a decoded body has (ints stay ints, maps
/// are `Map<String, dynamic>`).
Map<String, dynamic> _wire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
