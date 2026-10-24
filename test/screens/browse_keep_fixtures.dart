// Shared fixtures for the browse screens' Keep a copy tests (the phone
// spec's §2 sample): the user's own server ("home", libraries copies and
// music) with two connected servers mirrored — Stage Peer B (id 1, one
// library "music") and Stage Peer C (id 4) — the scripted plug-in API behind
// the hub's controllers, the Keep sheet's door replaced by a recorder (the
// sheet itself is the Keep-sheet tests'), toasts caught, an audio handler
// with nothing playing, and the connected server's browse routes answered.

import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/widgets/browse_keep_entry.dart';
import 'package:rxdart/rxdart.dart';

import 'discovery_plugin_fakes.dart';

/// The player with nothing playing: the streams the browse screens and the
/// queue read, and nothing else.
class FakeAudioHandler implements AudioPlayerHandler {
  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(null);
  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject.seeded(PlaybackState());
  @override
  final BehaviorSubject<List<MediaItem>> queue =
      BehaviorSubject.seeded(const []);
  @override
  final BehaviorSubject<dynamic> customState = BehaviorSubject.seeded(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One handler for the whole run: the queue's active-row stream subscribes
/// to the first one it meets.
final FakeAudioHandler fakeAudio = FakeAudioHandler();

const browsePeerB = {'id': 1, 'name': 'Stage Peer B'};
const browsePeerC = {'id': 4, 'name': 'Stage Peer C'};

class BrowseHarness {
  late Server home;
  late Server peerB;
  late Server peerC;
  late FakePluginServer fake;
  late FakeTimers timers;

  /// Every Keep sheet a way in opened, in order.
  final List<BrowseKeepRequest> opened = [];

  /// Holds each opened sheet "open" until completed (focus return).
  Completer<void>? sheetOpen;
  final List<String> toasts = [];

  /// What the connected server's browse routes answer, by path suffix.
  final Map<String, Object> routes = {};
  final List<http.Request> browseCalls = [];

  Server peer(int id, String name) =>
      Server('federated://home/$id', null, null, null, 'peer-$id')
        ..federationParent = 'home'
        ..federationPeerId = id
        ..federationPeerName = name
        ..parentServer = home;

  void setUp({bool plugins = true, bool? noUpload = false}) {
    fake = FakePluginServer();
    timers = FakeTimers();
    home = Server('http://home.local:3000', null, null, 'JWT', 'home')
      ..discoveryPluginsAvailable = plugins
      ..noUpload = noUpload;
    peerB = peer(1, 'Stage Peer B')..autoDJPaths = {'music': true};
    peerC = peer(4, 'Stage Peer C')
      ..autoDJPaths = {'live sets': true, 'music': true};
    ServerManager().serverList
      ..clear()
      ..addAll([home, peerB, peerC]);
    ServerManager().currentServer = peerB;
    CopiesHub().makeJobs = (s) => DiscoveryJobsController(
        server: s, api: fake.api(s), timer: timers.call, watchLifecycle: false);
    opened.clear();
    toasts.clear();
    routes.clear();
    browseCalls.clear();
    sheetOpen = null;
    BrowseKeepEntry.opener = (context, request, {marks}) async {
      opened.add(request);
      final hold = sheetOpen;
      if (hold != null) await hold.future;
    };
    KeepToast.debugSink = (m, {success = false}) => toasts.add(m);
    MediaManager().audioHandler = fakeAudio;
    fakeAudio.queue.add(const []);
    SettingsManager().keepBrowseHintShown = true;
    SettingsManager().albumGrid = true;
  }

  void tearDown() {
    CopiesHub().reset();
    BrowseKeepEntry.reset();
    KeepToast.debugSink = null;
    BrowserManager().goToNavScreen();
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  }

  /// Read the own server's gate (the listing, the destination, the jobs) —
  /// what moving onto the connected server does.
  Future<void> openGate() async {
    await CopiesHub().ensureGate(peerB);
  }

  http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body), status,
      headers: {'content-type': 'application/json'});

  /// The connected server's browse routes, from [routes].
  MockClient get client => MockClient((req) async {
        browseCalls.add(req);
        for (final e in routes.entries) {
          if (req.url.path.endsWith(e.key)) return _json(e.value);
        }
        return _json({'error': 'no route ${req.url.path}'}, 404);
      });

  /// Run [body] with the browse routes answering.
  Future<T> withRoutes<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => client);

  /// [child] in an app with the app's words, at [width]×[height] and
  /// [textScale] ([accessible]: a screen reader navigating).
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 390,
    double height = 844,
    double textScale = 1,
    bool accessible = false,
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            accessibleNavigation: accessible),
        child: c!,
      ),
      home: Scaffold(body: child),
    ));
  }

  /// Let the fakes answer and the frames land (no settle: a copy's bar
  /// never settles).
  static Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

/// A song of an album-songs answer on Stage Peer B ([albumArtist]: its own
/// `album-artist` tag).
Map<String, dynamic> peerSong(
  String path,
  String title, {
  String artist = 'Boukmanflow',
  String album = 'Borrowed Tapes',
  String? albumArtist,
  int track = 1,
  int seconds = 9,
  int year = 2019,
}) =>
    {
      'filepath': path,
      'metadata': {
        'title': title,
        'artist': artist,
        'album': album,
        'album-artist': ?albumArtist,
        'track': track,
        'year': year,
        'duration': seconds,
        'format': 'mp3',
      },
    };

/// Borrowed Tapes' three songs: 0:12, 0:08, 0:09 — 0:29 in all.
List<Map<String, dynamic>> borrowedTapes({String? albumArtist}) => [
      peerSong('music/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3',
          'Rooftop Cypher',
          track: 1, seconds: 12, albumArtist: albumArtist),
      peerSong('music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
          'Late Train Verse',
          track: 2, seconds: 8, albumArtist: albumArtist),
      peerSong('music/Boukmanflow/Borrowed Tapes/03 - Corner Store Loop.mp3',
          'Corner Store Loop',
          track: 3, seconds: 9, albumArtist: albumArtist),
    ];

/// The recommendation Discover's rows and the album page send for one of
/// Borrowed Tapes' songs.
Map<String, dynamic> tapesSongRec(String file, String title,
        {int seconds = 9, String? credit, Map<String, Object> peer = browsePeerB}) =>
    {
      'source': 'federation',
      'peer': peer,
      'filepath': 'music/Boukmanflow/Borrowed Tapes/$file',
      'title': title,
      'artist': 'Boukmanflow',
      'album': 'Borrowed Tapes',
      'albumArtist': ?credit,
      'year': 2019,
      'duration': seconds,
    };

/// Borrowed Tapes' album recommendation.
Map<String, dynamic> tapesAlbumRec({Map<String, Object> peer = browsePeerB}) => {
      'source': 'federation',
      'peer': peer,
      'album': 'Borrowed Tapes',
      'albumArtist': 'Boukmanflow',
      'artist': 'Boukmanflow',
      'year': 2019,
    };

/// A finished album copy's result: [copied] / [failed] / [owned] by file
/// name.
Map<String, dynamic> tapesAlbumResult({
  List<String> copied = const [],
  List<String> failed = const [],
  List<String> owned = const [],
}) {
  String from(String f) => 'music/Boukmanflow/Borrowed Tapes/$f';
  final n = copied.length + failed.length + owned.length;
  return {
    'scope': 'album',
    'songs': {
      'total': n,
      'copied': [
        for (final f in copied)
          {'from': from(f), 'filepath': 'copies/Boukmanflow/Borrowed Tapes/$f'}
      ],
      'skipped': [
        for (final f in owned) {'from': from(f), 'why': 'owned', 'at': 'music/x/$f'}
      ],
      'failed': [
        for (final f in failed) {'from': from(f), 'error': 'boom'}
      ],
    },
    'counts': {
      'total': n,
      'copied': copied.length,
      'skipped': owned.length,
      'failed': failed.length,
    },
    'stopped': null,
    'peer': browsePeerB,
  };
}
