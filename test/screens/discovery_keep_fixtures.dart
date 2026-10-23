// Shared fixtures for the Keep a copy surfaces' widget tests: the stage's
// sample (Stage Peer B holds Boukmanflow's "Borrowed Tapes" and Color Out's
// "Peer Sessions", Stage Peer C only "Rooftop Cypher"; the library has three
// other Boukmanflow albums), a compilation, the browser harness with the
// real Browser screen, and a scripted facts fetch (album-songs and
// artists-albums through the peer and on the user's own server).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/discovery_listing.dart';
import 'package:mstream_music/screens/discovery/discovery_page_controller.dart';
import 'package:mstream_music/screens/discovery/keep_copy_facts.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';

import 'discovery_fixtures.dart';
import 'discovery_plugin_fakes.dart';

const peerB = {'id': 1, 'name': 'Stage Peer B'};
const peerC = {'id': 4, 'name': 'Stage Peer C'};

/// A taste peers row on [peer] (the route's shape).
Map<String, dynamic> keepRow(
  String title, {
  String artist = 'Boukmanflow',
  String? album = 'Borrowed Tapes',
  String? albumArtist,
  int year = 2019,
  int duration = 8,
  String? track,
  double similarity = 0.8,
  Map<String, Object> peer = peerB,
}) => {
  'artist': artist,
  'title': title,
  'album': ?album,
  'albumArtist': ?albumArtist,
  'year': year,
  'duration': duration,
  'similarity': similarity,
  'genreTags': null,
  'seedHash': null,
  'filepath': 'peerlib/$artist/${album ?? 'singles'}/${track ?? ''}$title.mp3',
  'source': 'federation',
  'peer': {'id': peer['id'], 'name': peer['name']},
};

/// The peers answer: Stage Peer B with Boukmanflow and Color Out, Stage
/// Peer C with Rooftop Cypher; [extraB] are more rows of B's.
Map<String, dynamic> keepPeersPayload({
  List<Map<String, dynamic>> extraB = const [],
  bool withC = true,
}) => {
  'window': 30,
  'seedSource': 'history',
  'seeds': [],
  'library': null,
  'network': null,
  'peers': {
    'peers': [
      {
        'id': 1,
        'name': 'Stage Peer B',
        'reachable': true,
        'mismatched': false,
        'results': [
          keepRow('Late Train Verse', track: '02 - ', similarity: 0.95),
          keepRow(
            'Afterimage',
            artist: 'Color Out',
            album: 'Peer Sessions',
            duration: 11,
            similarity: 0.9,
          ),
          keepRow(
            'Corner Store Loop',
            track: '03 - ',
            duration: 9,
            similarity: 0.7,
          ),
          ...extraB,
        ],
      },
      if (withC)
        {
          'id': 4,
          'name': 'Stage Peer C',
          'reachable': true,
          'mismatched': false,
          'results': [
            keepRow(
              'Rooftop Cypher',
              track: '01 - ',
              duration: 12,
              similarity: 0.6,
              peer: peerC,
            ),
          ],
        },
    ],
    'searched': {'peers': 2, 'unreachable': 0, 'mismatched': 0},
  },
};

/// A compilation's rows on Stage Peer B: one album credited to "Various
/// Artists", two track artists.
List<Map<String, dynamic>> compilationRows() => [
  keepRow(
    'Block Rocker',
    artist: 'Peer Kim',
    album: 'Block Party Comp',
    albumArtist: 'Various Artists',
    year: 2021,
    similarity: 0.85,
  ),
  keepRow(
    'Night Ferry',
    artist: 'Nova',
    album: 'Block Party Comp',
    albumArtist: 'Various Artists',
    year: 2021,
    similarity: 0.5,
  ),
];

/// One song of an album-songs answer ([genres] the library's split of its
/// genre tag; [artistDisplay] its ARTIST tag as written).
Map<String, dynamic> songOf(
  String path,
  String title,
  String artist,
  String album,
  int seconds, {
  int? year = 2019,
  List<String> genres = const [],
  String? artistDisplay,
}) => {
  'filepath': path,
  'metadata': {
    'title': title,
    'artist': artist,
    'artist-display': ?artistDisplay,
    'album': album,
    'year': year,
    'duration': seconds,
    'genres': genres,
  },
};

/// The stage's compilation on Stage Peer B (found live 2026-10-22): "Night
/// Market Sampler", credited to Various Artists, its songs by Color Out,
/// Boukmanflow and ALM — an album copy files each song under its own
/// artist. Discover shows Boukmanflow's song of it.
List<Map<String, dynamic>> nightMarketRows() => [
  keepRow(
    'Lantern Row',
    album: 'Night Market Sampler',
    albumArtist: 'Various Artists',
    year: 2020,
    track: '02 - ',
    similarity: 0.85,
  ),
];

/// Its album-songs answer.
List<Map<String, dynamic>> nightMarketSongs() => [
  for (final (i, (title, artist)) in const [
    ('Neon Stalls', 'Color Out'),
    ('Lantern Row', 'Boukmanflow'),
    ('Last Ferry', 'ALM'),
  ].indexed)
    songOf(
      'peerlib/$artist/Night Market Sampler/0${i + 1} - $title.mp3',
      title,
      artist,
      'Night Market Sampler',
      60,
      year: 2020,
    ),
];

/// Borrowed Tapes as the peer lists it, the ARTIST tag of [guestOn] naming
/// a guest ("Boukmanflow feat. ALM": a copy of it files there, not under the
/// row's Boukmanflow); [genres] the library's split of each one's genre tag,
/// by title.
List<Map<String, dynamic>> featuredTapes({
  String guestOn = 'Late Train Verse',
  Map<String, List<String>> genres = const {},
}) => [
  for (final (i, title) in const [
    'Rooftop Cypher',
    'Late Train Verse',
    'Corner Store Loop',
  ].indexed)
    songOf(
      'peerlib/Boukmanflow/Borrowed Tapes/0${i + 1} - $title.mp3',
      title,
      'Boukmanflow',
      'Borrowed Tapes',
      9,
      artistDisplay: title == guestOn ? 'Boukmanflow feat. ALM' : null,
      genres: genres[title] ?? const [],
    ),
];

/// The facts the sheets ask: album-songs and artists-albums, through a
/// peer (its virtual Server) or on the user's own server; every request
/// recorded. [peerDown] makes the peer's calls fail.
class FakeFacts {
  final List<(String server, String location, Map body)> asked = [];
  bool peerDown = false;
  Completer<void>? gate;

  /// Albums answered as given, by name (before the stage's own).
  Map<String, List<Map<String, dynamic>>> albums = {};

  /// Borrowed Tapes' songs' genres, by title (none by default).
  Map<String, List<String>> genres = {};

  /// The year artists-albums gives an album, by name (2019 by default).
  Map<String, int> albumYears = {};

  /// Albums by artist, per side.
  Map<String, List<String>> peerAlbums = {
    'boukmanflow': ['Borrowed Tapes'],
    'color out': ['Peer Sessions'],
  };
  Map<String, List<String>> libraryAlbums = {
    'boukmanflow': ['Forget Yesterday', 'Night Market', 'Old Gold'],
    'color out': [
      'Forget Yesterday EP',
      'Perspectives EP',
      'Color Out EP',
      'Peer Sessions',
    ],
  };

  Future<dynamic> call(
    Server server,
    String location,
    Map<String, dynamic> body,
  ) async {
    asked.add((server.localname, location, body));
    if (gate != null) await gate!.future;
    if (server.isFederated && peerDown) throw Exception('502');
    final artist = '${body['artist'] ?? ''}'.toLowerCase();
    if (location.endsWith('/db/album-songs')) {
      final given = albums[body['album']];
      if (given != null) return given;
      if (body['album'] == 'Night Market Sampler') return nightMarketSongs();
      if (body['album'] == 'Borrowed Tapes') {
        return [
          songOf(
            'peerlib/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3',
            'Rooftop Cypher',
            'Boukmanflow',
            'Borrowed Tapes',
            12,
            genres: genres['Rooftop Cypher'] ?? const [],
          ),
          songOf(
            'peerlib/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
            'Late Train Verse',
            'Boukmanflow',
            'Borrowed Tapes',
            8,
            genres: genres['Late Train Verse'] ?? const [],
          ),
          songOf(
            'peerlib/Boukmanflow/Borrowed Tapes/03 - Corner Store Loop.mp3',
            'Corner Store Loop',
            'Boukmanflow',
            'Borrowed Tapes',
            9,
            genres: genres['Corner Store Loop'] ?? const [],
          ),
        ];
      }
      if (body['album'] == 'Block Party Comp') {
        return [
          for (final (i, a) in ['Peer Kim', 'Nova', 'Ola', 'Ivo'].indexed)
            songOf(
              'peerlib/comp/$i.mp3',
              'Track $i',
              a,
              'Block Party Comp',
              100,
              year: 2021,
            ),
        ];
      }
      return [];
    }
    if (location.endsWith('/db/artists-albums')) {
      final names = server.isFederated
          ? (peerAlbums[artist] ?? const [])
          : (libraryAlbums[artist] ?? const []);
      return {
        'albums': [
          for (final n in names) {'name': n, 'year': albumYears[n] ?? 2019},
          {'name': null, 'year': null},
        ],
      };
    }
    throw Exception('no route $location');
  }
}

/// Everything a Discover widget test needs: the user's server, its two
/// connected servers mirrored, the scripted plug-in API, timers and facts,
/// and the page controller (its jobs controller injected).
class KeepHarness {
  late Server server;
  late FakePluginServer fake;
  late FakeTimers timers;
  late FakeFacts facts;
  late DiscoveryJobsController jobs;
  late DiscoveryPageController page;
  Map<String, dynamic> Function() peersAnswer = keepPeersPayload;
  final List<String> openedCopies = [];
  final List<String> openedElsewhere = [];
  final List<String> openedDestination = [];

  /// The song each destination picker opened to preview.
  final List<String?> destinationSongs = [];

  Server peer(int id, String name) =>
      Server('federated://home/$id', null, null, null, 'peer-$id')
        ..federationParent = 'home'
        ..federationPeerId = id
        ..federationPeerName = name
        ..parentServer = server;

  void setUp({bool plugins = true, bool? noUpload = false}) {
    ServerManager().serverList.clear();
    server = discoveryServer()
      ..discoveryPluginsAvailable = plugins
      ..noUpload = noUpload;
    ServerManager().serverList.addAll([
      server,
      peer(1, 'Stage Peer B'),
      peer(4, 'Stage Peer C'),
    ]);
    fake = FakePluginServer();
    timers = FakeTimers();
    facts = FakeFacts();
    keepFactsFetch = facts.call;
    DiscoveryKeepRoutes.openCopies = (_, _) => openedCopies.add('copies');
    DiscoveryKeepRoutes.openElsewhere = (_, _, lead) =>
        openedElsewhere.add(lead.title);
    DiscoveryKeepRoutes.changeDestination = (_, _, song, _) {
      openedDestination.add('change');
      destinationSongs.add(song?.title);
    };
  }

  void tearDown() {
    keepFactsFetch = keepFactsPost;
    DiscoveryKeepRoutes.reset();
    ServerManager().serverList.clear();
  }

  DiscoveryPageController makePage() {
    jobs = DiscoveryJobsController(
      server: server,
      api: fake.api(server),
      timer: timers.call,
      watchLifecycle: false,
    );
    page = DiscoveryPageController(
      server: server,
      fetch: (_, r) async => DiscoveryFetchResult.ok(
        parse(isPeersCall(r) ? peersAnswer() : mainPayload()),
      ),
      reping: (_) async {},
      readWindow: () => kTasteDefaultWindow,
      saveWindow: (_) {},
      now: () => DateTime.utc(2026, 10, 19, 12),
      jobs: jobs,
    );
    return page;
  }

  /// The real Browser on Discover at [width]×[height] (logical px), the
  /// connected servers answered and looked up.
  Future<void> pumpDiscover(
    WidgetTester tester, {
    double width = 390,
    double height = 2600,
    double textScale = 1,
    Locale? locale,
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ServerManager().currentServer = server;
    BrowserManager().goToNavScreen();
    final c = makePage();
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: Browser()),
      ),
    );
    DiscoveryListing().open(server, controller: c);
    await pumpFor(tester);
  }

  /// Let the fakes answer and the frames land (no settle: a copy's
  /// sliding bar never settles).
  static Future<void> pumpFor(WidgetTester tester, [int frames = 6]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The lead of [title]'s connected-server row.
  DiscoveryLead lead(String title) =>
      discoveryLeadOf(page.peerRows.firstWhere((r) => r.name == title))!;
}

/// The path_provider the browser asks for download badges, answered.
void mockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => '/nonexistent-keep-test-dir',
      );
}

/// One Keep card state: a row of its own (its own song / album / artist
/// keys) and the caller's job for it in that state.
class KeepState {
  final String name;
  final Map<String, dynamic> row;

  /// The choice the card shows (song / album / artist).
  final String choice;
  KeepState(this.name, this.row, this.choice);
}

/// Every job state the Keep card draws (the PhoneKeepStates board), each
/// on its own row, the jobs added to [fake].
List<KeepState> keepStates(FakePluginServer fake) {
  final out = <KeepState>[];
  var n = 0;
  KeepState add(
    String name,
    String choice,
    String state, {
    Map<String, dynamic>? result,
    double? progress,
    String? statusText,
    String? error,
    bool cancelRequested = false,
    Map<String, Object> peer = peerB,
  }) {
    n += 1;
    // Each state its own song, album and artist, so no key is shared.
    final row = keepRow(
      'Song $n',
      artist: 'Artist $n',
      album: 'Album $n',
      track: '0$n - ',
      peer: peer,
    );
    final job = fake.addJob(
      row,
      scope: choice == 'song' ? null : choice,
      state: state,
      result: result,
      progress: progress,
      statusText: statusText,
    );
    job['error'] = error;
    job['cancelRequested'] = cancelRequested;
    // Another server's copy is shown on THIS server's row of the album.
    final shown = peer == peerB
        ? row
        : {
            ...row,
            'peer': {'id': peerB['id'], 'name': peerB['name']},
          };
    final s = KeepState(name, shown, choice);
    out.add(s);
    return s;
  }

  Map<String, dynamic> many({
    int copied = 0,
    int skipped = 0,
    int failed = 0,
    String? stopped,
    List<Map<String, dynamic>> albums = const [],
    List<Map<String, dynamic>> skippedAlbums = const [],
  }) => {
    'scope': 'album',
    'songs': {
      'total': copied + skipped + failed,
      'copied': [],
      'skipped': [],
      'failed': [],
    },
    'counts': {
      'total': copied + skipped + failed,
      'copied': copied,
      'skipped': skipped,
      'failed': failed,
    },
    'albums': albums,
    'skippedAlbums': skippedAlbums,
    'stopped': stopped,
    'peer': peerB,
  };

  add('queued', 'album', 'queued');
  add(
    'running',
    'album',
    'running',
    progress: 0.45,
    statusText: '1 of 3 songs · 7.4 MB · Late Train Verse',
  );
  add(
    'stopping',
    'album',
    'running',
    progress: 0.45,
    statusText: '1 of 3 songs · 7.4 MB · Late Train Verse',
    cancelRequested: true,
  );
  add(
    'done one song',
    'song',
    'done',
    result: {
      'copied': {
        'vpath': 'copies',
        'filepath':
            'copies/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
        'bytes': 1234,
      },
    },
  );
  add(
    'done many',
    'artist',
    'done',
    result: many(
      copied: 1,
      skipped: 1,
      failed: 1,
      albums: [
        {'name': 'Album 5', 'songs': {}},
      ],
      skippedAlbums: [
        {'name': 'Other', 'why': 'owned'},
        {'name': 'Guest', 'why': 'appearance'},
      ],
    ),
  );
  add(
    'already yours',
    'song',
    'done',
    result: {
      'skipped': 'owned',
      'existing': {
        'filepath':
            'copies/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
      },
    },
  );
  add(
    'skipped exists',
    'song',
    'done',
    result: {
      'skipped': 'exists',
      'filepath': 'copies/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
    },
  );
  add(
    'stopped quota',
    'album',
    'done',
    result: many(copied: 1, stopped: 'quota'),
  );
  add(
    'stopped busy',
    'album',
    'done',
    result: many(copied: 1, skipped: 1, stopped: 'busy'),
  );
  add(
    'stopped peer',
    'album',
    'done',
    result: many(copied: 1, failed: 1, stopped: 'peer'),
  );
  add('stopped refused', 'album', 'done', result: many(stopped: 'refused'));
  add(
    'failed',
    'song',
    'failed',
    error: 'Stage Peer B no longer has this file',
  );
  add('failed nothing copied', 'album', 'done', result: many(failed: 3));
  add(
    'failed re-paired',
    'song',
    'failed',
    error: 'this server is no longer paired with that peer',
  );
  add('cancelled nothing', 'song', 'cancelled');
  add('cancelled some', 'album', 'cancelled', result: many(copied: 2));
  add('nothing to copy', 'album', 'done', result: many());
  add(
    'only a guest',
    'artist',
    'done',
    result: {
      ...many(),
      'skippedAlbums': [
        {'name': 'Guest', 'why': 'appearance'},
      ],
    },
  );
  add(
    'from another server',
    'album',
    'running',
    progress: 0.6,
    statusText: '1 of 1 songs · Rooftop Cypher',
    peer: peerC,
  );
  return out;
}
