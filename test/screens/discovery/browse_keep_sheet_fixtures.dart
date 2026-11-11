// Shared fixtures for the Keep a copy sheet entered while browsing a
// connected server (the phone spec's §6, its §2 sample): the user's server
// "home" (libraries copies and music; files go to copies by Artist /
// Album), Stage Peer B with Boukmanflow's three albums, the compilation he
// appears on, the Split Series whose credits disagree and the folders of
// /music/Boukmanflow, Stage Peer C; a host page that opens the sheet, the
// plug-in fake behind the shared CopiesHub, manual timers, and every read
// the sheet makes scripted and recorded (album-songs and artists-albums,
// one file's tags, a folder's recursive listing and its tags, the user's
// own folders). Toasts and the routes the sheet hands off to are caught.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/browse_copy_marks.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/destination_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/screens/discovery/peer_sheets.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';

import '../discovery_fixtures.dart';
import '../discovery_keep_fixtures.dart' show KeepHarness;
import '../discovery_plugin_fakes.dart';

export '../discovery_keep_fixtures.dart' show KeepHarness, peerB, peerC;
export '../discovery_plugin_fakes.dart';

const jobsPath = '/plugins/federation-copy/jobs';

/// One of a peer's songs as album-songs answers it.
Map<String, dynamic> peerSong(
  String path,
  String title,
  String artist,
  String album,
  int seconds, {
  int year = 2019,
  String? albumArtist,
}) => {
  'filepath': path,
  'metadata': {
    'title': title,
    'artist': artist,
    'album': album,
    'year': year,
    'duration': seconds,
    'album-artist': ?albumArtist,
  },
};

const tapesDir = 'music/Boukmanflow/Borrowed Tapes';
const tapesFiles = [
  '$tapesDir/01 - Rooftop Cypher.mp3',
  '$tapesDir/02 - Late Train Verse.mp3',
  '$tapesDir/03 - Corner Store Loop.mp3',
];

/// /music/Boukmanflow: its three albums' songs, 9 in all.
const boukFiles = [
  ...tapesFiles,
  'music/Boukmanflow/Harbour Lights/01 - Tide.mp3',
  'music/Boukmanflow/Harbour Lights/02 - Pier.mp3',
  'music/Boukmanflow/Harbour Lights/03 - Gulls.mp3',
  'music/Boukmanflow/Second Shift/01 - Clock In.mp3',
  'music/Boukmanflow/Second Shift/02 - Break Room.mp3',
  'music/Boukmanflow/Second Shift/03 - Clock Out.mp3',
];

/// Every read the sheet makes, scripted: through the peer (its virtual
/// Server) or on the user's own server; each recorded.
class BrowseFacts {
  final List<String> asked = [];

  /// The peer does not answer.
  bool peerDown = false;

  /// Held until the test completes it (null: answered at once).
  Completer<void>? countGate;
  Completer<void>? trackGate;
  Completer<void>? ownGate;

  /// One file's tags on the peer, by path (no leading slash).
  final Map<String, Map<String, dynamic>> trackTags = {
    '$tapesDir/02 - Late Train Verse.mp3': {
      'title': 'Late Train Verse',
      'artist': 'Boukmanflow',
      'album': 'Borrowed Tapes',
      'year': 2019,
      'duration': 8,
      'album-artist': 'Boukmanflow',
    },
  };

  /// Folder listings, by directory as asked.
  final Map<String, List<String>> folders = {
    '/$tapesDir': tapesFiles,
    '/music/Boukmanflow': boukFiles,
    '/music/Night Owl Radio Archive': [
      for (var i = 0; i < 1240; i++)
        'music/Night Owl Radio Archive/Show ${i ~/ 23}/Part $i.mp3',
    ],
  };

  /// The user's own folders, by directory; a directory not here does not
  /// exist (it throws).
  final Map<String, List<String>> own = {
    '/copies': ['Boukmanflow', 'Color Out', 'From Sam'],
    '/copies/From Sam': [],
    '/copies/Boukmanflow': ['Harbour Lights'],
    '/music': [
      for (final n in const [
        'Archive',
        'Boukmanflow',
        'Color Out',
        'Field Recordings',
        'Live Sets',
        'Mixtapes',
        'Night Owl Radio',
        'Podcasts',
        'Radio',
        'Rehearsals',
        'Samples',
        'Soundtracks',
        'Stems',
        'Voice Memos',
      ])
        n,
    ],
  };

  /// The tags a folder's songs carry (By your layout), by path.
  Map<String, MusicMetadata> folderTags = {
    for (final (i, t) in const [
      'Rooftop Cypher',
      'Late Train Verse',
      'Corner Store Loop',
    ].indexed)
      tapesFiles[i]: MusicMetadata.fromServerMap({
        'title': t,
        'artist': 'Boukmanflow',
        'album': 'Borrowed Tapes',
        'year': 2019,
        'album-artist': 'Boukmanflow',
      }),
  };

  /// The peer's artists-albums answers, by artist (lower case).
  Map<String, List<Map<String, dynamic>>> peerAlbums = {
    'boukmanflow': [
      {
        'name': 'Borrowed Tapes',
        'year': 2019,
        'album_artist': 'Boukmanflow',
        'artists': ['Boukmanflow'],
        'compilation': false,
        'track_count': 3,
      },
      {
        'name': 'Harbour Lights',
        'year': 2021,
        'album_artist': 'Boukmanflow',
        'artists': ['Boukmanflow'],
        'compilation': false,
        'track_count': 3,
      },
      {
        'name': 'Second Shift',
        'year': 2023,
        'album_artist': 'Boukmanflow',
        'artists': ['Boukmanflow'],
        'compilation': false,
        'track_count': 3,
      },
      {
        'name': 'Night Market Sampler',
        'year': 2024,
        'album_artist': 'Various Artists',
        'artists': ['Color Out', 'Boukmanflow', 'ALM'],
        'compilation': true,
        'track_count': 3,
      },
      {'name': null, 'year': null},
    ],
    'lantern choir': [
      {
        'name': 'Night Market Sampler',
        'year': 2024,
        'album_artist': 'Various Artists',
        'artists': ['Color Out', 'Lantern Choir', 'ALM'],
        'compilation': true,
        'track_count': 3,
      },
    ],
  };

  /// The library's albums, by artist (lower case).
  Map<String, List<String>> libraryAlbums = {
    'boukmanflow': ['Harbour Lights'],
  };

  Future<dynamic> call(
    Server server,
    String location,
    Map<String, dynamic> body,
  ) async {
    asked.add('${server.localname} $location ${jsonEncode(body)}');
    if (server.isFederated && peerDown) throw Exception('502');
    final artist = '${body['artist'] ?? body['album_artist'] ?? ''}'
        .toLowerCase();
    if (location.endsWith('/db/album-songs')) {
      final album = body['album'];
      if (album == 'Borrowed Tapes') {
        return [
          for (final (i, t) in const [
            ('Rooftop Cypher', 12),
            ('Late Train Verse', 8),
            ('Corner Store Loop', 9),
          ].indexed)
            peerSong(tapesFiles[i], t.$1, 'Boukmanflow', 'Borrowed Tapes', t.$2),
        ];
      }
      if (album == 'Night Market Sampler') {
        // Asked by one track artist, only that artist's song of it.
        final all = [
          for (final (i, a) in const [
            'Color Out',
            'Boukmanflow',
            'ALM',
          ].indexed)
            peerSong(
              'music/Various Artists/Night Market Sampler/0${i + 1}.mp3',
              'Track ${i + 1}',
              a,
              'Night Market Sampler',
              10,
              year: 2024,
            ),
        ];
        if (body['album_artist'] == 'Various Artists') return all;
        return [
          for (final s in all)
            if ((s['metadata'] as Map)['artist'].toString().toLowerCase() ==
                artist)
              s,
        ];
      }
      return [];
    }
    if (location.endsWith('/db/artists-albums')) {
      if (server.isFederated) {
        return {'albums': peerAlbums[artist] ?? const []};
      }
      return {
        'albums': [
          for (final n in libraryAlbums[artist] ?? const <String>[])
            {'name': n, 'year': 2021},
        ],
      };
    }
    throw Exception('no route $location');
  }

  Future<MusicMetadata?> track(Server server, String filepath) async {
    asked.add('${server.localname} track $filepath');
    if (trackGate != null) await trackGate!.future;
    if (peerDown) return null;
    final m = trackTags[filepath.replaceFirst(RegExp(r'^/+'), '')];
    return m == null ? null : MusicMetadata.fromServerMap(m);
  }

  Future<List<String>> list(Server server, String directory) async {
    asked.add('${server.localname} recursive $directory');
    if (countGate != null) await countGate!.future;
    if (peerDown) throw Exception('502');
    final out = folders[directory];
    if (out == null) throw Exception('404');
    return out;
  }

  Future<Map<String, MusicMetadata>> tags(
    Server server,
    List<String> filepaths,
  ) async {
    asked.add('${server.localname} tags ${filepaths.length}');
    if (peerDown) return const {};
    return {
      for (final p in filepaths)
        if (folderTags[p] != null) p: folderTags[p]!,
    };
  }

  Future<List<String>> ownFolders(Server server, String directory) async {
    asked.add('${server.localname} folders $directory');
    if (ownGate != null) await ownGate!.future;
    final out = own[directory];
    if (out == null) throw Exception('404');
    return out;
  }

  int count(String what) => asked.where((a) => a.contains(what)).length;
}

/// Everything a browse-sheet test needs: the servers, the plug-in fake
/// behind the shared hub, the scripted reads, the caught toasts and routes,
/// and a host page to open the sheet from.
class BrowseSheetHarness {
  late Server home;
  late Server peer;
  late Server peerOther;
  late FakePluginServer fake;
  late FakeTimers timers;
  late BrowseFacts facts;
  late BrowseCopyMarks marks;
  BuildContext? host;

  final List<String> toasts = [];
  final List<(String, String, VoidCallback)> toastActions = [];
  final List<String> opened = [];
  final List<DestinationPreviewFolder> folderPreviews = [];
  final List<String> destinationSongs = [];
  final List<String> shownInLibrary = [];

  /// Whether "Show in your library" opens the explorer there (false: the
  /// own server did not list the folder).
  bool showInLibraryOpens = true;

  DiscoveryJobsController get jobs => CopiesHub().jobsFor(peer);

  Server _peer(int id, String name) =>
      Server('federated://home/$id', null, null, null, 'peer-$id')
        ..federationParent = 'home'
        ..federationPeerId = id
        ..federationPeerName = name
        ..parentServer = home;

  void setUp() {
    toasts.clear();
    toastActions.clear();
    opened.clear();
    folderPreviews.clear();
    destinationSongs.clear();
    shownInLibrary.clear();
    showInLibraryOpens = true;
    ServerManager().serverList.clear();
    home = discoveryServer()
      ..discoveryPluginsAvailable = true
      ..noUpload = false;
    peer = _peer(1, 'Stage Peer B');
    peerOther = _peer(4, 'Stage Peer C');
    ServerManager().serverList.addAll([home, peer, peerOther]);
    fake = FakePluginServer();
    fake.listing = {
      ...fake.listing,
      'jobs': {'allowed': true, 'maxFolderSongs': 1000},
    };
    fake.destination = {
      ...fake.destination,
      'libraries': [
        {'vpath': 'copies', 'template': null},
        {'vpath': 'music', 'template': null},
      ],
    };
    timers = FakeTimers();
    facts = BrowseFacts();
    CopiesHub().reset();
    CopiesHub().makeJobs = (s) => DiscoveryJobsController(
      server: s,
      api: fake.api(s),
      timer: timers.call,
      watchLifecycle: false,
    );
    KeepToast.debugSink = (m, {success = false}) => toasts.add(m);
    KeepToast.debugActionSink = (m, a, f) => toastActions.add((m, a, f));
    DiscoveryKeepRoutes.openCopies = (_, _) => opened.add('copies');
    DiscoveryKeepRoutes.changeDestination = (_, _, song, _) {
      opened.add('destination');
      destinationSongs.add(song?.title ?? '');
    };
    DiscoveryKeepRoutes.changeFolderDestination = (_, _, folder, _) {
      opened.add('folder destination');
      folderPreviews.add(folder);
    };
    DiscoveryKeepRoutes.showInLibrary = (own, dir) async {
      shownInLibrary.add('${own.localname} $dir');
      return showInLibraryOpens;
    };
  }

  void tearDown() {
    CopiesHub().reset();
    BrowseKeepSheet.resetVerbs();
    KeepToast.debugSink = null;
    KeepToast.debugActionSink = null;
    DiscoveryKeepRoutes.reset();
    ServerManager().serverList.clear();
    VelvetColors.setActive(paletteFor(AppTheme.dark));
  }

  /// The host page at [width]×[height] (logical px), the hub's copies read.
  Future<void> pumpHost(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double textScale = 1,
    bool accessible = false,
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            accessibleNavigation: accessible,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    marks = BrowseCopyMarks(
      jobs: jobs,
      peer: peer,
      timer: timers.call,
      watchLifecycle: false,
    );
    addTearDown(marks.dispose);
    unawaited(jobs.activate());
    await frames(tester);
  }

  /// Open [request]'s sheet over the host page.
  Future<void> open(WidgetTester tester, BrowseKeepRequest request) async {
    unawaited(
      showBrowseKeepSheet(
        host!,
        request,
        marks: marks,
        fetch: facts.call,
        track: facts.track,
        folderList: facts.list,
        folderTags: facts.tags,
        ownFolders: facts.ownFolders,
      ),
    );
    await frames(tester, 10);
  }

  static Future<void> frames(WidgetTester tester, [int n = 6]) =>
      KeepHarness.pumpFor(tester, n);

  // ── the stage's things ───────────────────────────────────────────────

  DisplayItem album(
    String name, {
    String? credit = 'Boukmanflow',
    int year = 2019,
    bool? compilation,
    List<String> artists = const ['Boukmanflow'],
    Server? on,
  }) {
    final a = DisplayItem(
      on ?? peer,
      name,
      'album',
      name,
      Icon(Icons.album, color: VelvetColors.textSecondary),
      credit,
    );
    a.albumArtist = credit;
    a.creditState = credit == null ? AlbumCredit.disagree : AlbumCredit.known;
    a.year = year;
    a.compilation = compilation;
    a.artists = artists;
    return a;
  }

  /// Late Train Verse's row on the album page (its tags, the page credit).
  DisplayItem song({
    String title = 'Late Train Verse',
    String file = '02 - Late Train Verse.mp3',
    String artist = 'Boukmanflow',
    String album = 'Borrowed Tapes',
    String dir = tapesDir,
    bool tagged = true,
    String? albumArtist,
    int seconds = 8,
    int year = 2019,
  }) {
    final row = DisplayItem(
      peer,
      tagged ? title : file,
      'file',
      '/$dir/$file',
      Icon(Icons.music_note, color: VelvetColors.accent),
      null,
    );
    if (tagged) {
      row.metadata = MusicMetadata.fromServerMap({
        'title': title,
        'artist': artist,
        'album': album,
        'year': year,
        'duration': seconds,
        'album-artist': ?albumArtist,
      });
    }
    return row;
  }

  BrowseKeepRequest albumPage([DisplayItem? a]) =>
      BrowseKeepRequest.album(a ?? album('Borrowed Tapes'),
          variant: KeepVariant.page)!;

  BrowseKeepRequest albumCard([DisplayItem? a]) =>
      BrowseKeepRequest.album(a ?? album('Borrowed Tapes'),
          variant: KeepVariant.item)!;

  BrowseKeepRequest artistPage([String name = 'Boukmanflow']) =>
      BrowseKeepRequest.artistPage(ArtistContext(
        server: peer,
        name: name,
        albums: facts.peerAlbums[name.toLowerCase()] ?? const [],
      ))!;

  BrowseKeepRequest folder(String path,
          {KeepVariant variant = KeepVariant.page}) =>
      BrowseKeepRequest.ofFolder(FolderRef.of(path)!, peer, variant: variant)!;

  /// The last start's body.
  Map<String, dynamic> lastStart() =>
      jsonDecode(fake.calls('POST', jobsPath).last.body) as Map<String, dynamic>;
}

/// A line as read, its no-break spaces read as spaces.
Finder line(String text) => find.byWidgetPredicate(
  (w) =>
      w is RichText && w.text.toPlainText().replaceAll('\u00A0', ' ') == text,
);

/// A line containing [text], its no-break spaces read as spaces.
Finder lineWith(String text) => find.byWidgetPredicate(
  (w) =>
      w is RichText &&
      w.text.toPlainText().replaceAll('\u00A0', ' ').contains(text),
);
