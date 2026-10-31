// The Add from YouTube screen's lists (YtdlLists, the Downloads board), on
// the scripted server in ytdl_fakes: ADDING ("Adding · 2 min · MP3" with
// the ring, Starting…, the server not answering yet, Waiting for
// connection, ⋮ Hide from this list and its toast), NEEDS A LOOK (the name
// clash with Change format and retry — hidden with one format — Show folder
// and Dismiss; the no-reason failure in its 6.30 and older words; Not sure
// it finished; Not sure it started → Check again → Not found → Add again;
// every start failure in the screen's words, with Try again only where a
// second try can change something; a busy button), ADDED ("MP3 · 8.4 MB ·
// 3 min ago", yesterday, File missing greyed; tap plays the song with a
// leading '/', ⋮ Add to queue / Show in folder, no play for a file the
// phone can't name; Show earlier, also before any YouTube row is read),
// the empty state (not while ADDED's first read is out), the NEEDS A LOOK
// anchor, the spoken labels (a section's note read with its header; an
// ADDED row one button named by its words, no "Cover" in it), the keys,
// the library's art on ADDED rows (one batched metadata read), a folder
// that couldn't be made → Choose a folder… / Top of the library adding the
// song into a folder that is there, the ⋮ answering taps across its whole
// 48 px, and 360 dp at 200% text with no overflow.

import 'dart:async';
import 'dart:io' show SocketException;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/objects/ytdl_job.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/screens/ytdl/ytdl_lists.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/util/stream_url.dart';
import 'package:mstream_music/util/ytdl_api.dart';

import '../singletons/ytdl_fakes.dart';

const dir = '/Music/Daft Punk/Discovery/';

void main() {
  late YtdlHarness h;
  late Server s;
  late List<DisplayItem> played;
  late List<DisplayItem> queued;
  late List<String> folders;
  late List<List<String>> artAsked;
  late Map<String, String> artFound;

  setUp(() {
    h = YtdlHarness()..wire();
    s = ytdlServer(formats: const ['mp3', 'm4a', 'opus', 'flac']);
    h.fake.folder(dir);
    played = [];
    queued = [];
    folders = [];
    artAsked = [];
    artFound = {};
    YtdlListActions.play = (song) async => played.add(song);
    YtdlListActions.queue = (song) async => queued.add(song);
    YtdlListActions.showFolder = (_, server, directory) {
      expect(identical(server, s), isTrue, reason: "the row's own server");
      folders.add(directory);
    };
    YtdlListActions.albumArt = (state, paths) async {
      artAsked.add(paths);
      return {for (final p in paths) p: ?artFound[p]};
    };
  });
  tearDown(() {
    h.unwire();
    YtdlListActions.reset();
  });

  /// A job as the hub persists it, [ago] before the phone's clock.
  Map<String, dynamic> job(
    String id,
    String state, {
    String title = 'One More Time',
    String directory = dir,
    String url = kOneMoreTime,
    String codec = 'mp3',
    Duration ago = const Duration(minutes: 2),
    int? pid,
    String? problem,
    String? detail,
    String? filepath,
    String? mkdir,
  }) {
    final at = h.clock.current.subtract(ago).millisecondsSinceEpoch;
    return {
      'id': id,
      'url': url,
      'directory': directory,
      'codec': codec,
      'title': title,
      'predictedName': '${title.replaceAll(' ', '_')}.$codec',
      'createdAt': at,
      if (!YtdlJobState.parse(state)!.open) 'endedAt': at,
      'state': state,
      'pid': pid,
      'problem': problem,
      'problemDetail': detail,
      'filepath': filepath,
      'mkdir': mkdir,
    };
  }

  /// Let the fake server answer what the UI asked in the test's zone.
  Future<void> drain(WidgetTester t) async {
    for (var i = 0; i < 30; i++) {
      await t.pump();
    }
  }

  /// [jobs] persisted, the state made (it polls the open ones) and the
  /// version probed — all on the real event loop.
  Future<YtdlServerState> seed(WidgetTester t,
      [List<Map<String, dynamic>> jobs = const []]) async {
    s.ytdlJobs = jobs;
    final st = h.hub.stateFor(s);
    await t.runAsync(() async {
      await st.probeTier();
      await ytdlSettle();
    });
    return st;
  }

  Future<void> pump(WidgetTester t, YtdlServerState st,
      {GlobalKey? anchor, bool showEmpty = true, double textScale = 1}) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              YtdlLists(state: st, needsLookAnchor: anchor, showEmpty: showEmpty),
            ],
          ),
        ),
      ),
    ));
    await t.pump();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  /// A menu's open or close animation (the rings never settle).
  Future<void> frames(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  group('ADDING', () {
    testWidgets('a job the server took: "Adding · 2 min · MP3", the ring, the '
        'folder read aloud; the minutes count on', (t) async {
      h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
      final st = await seed(t, [job('a1', 'adding', pid: 5000)]);
      await pump(t, st);
      expect(find.text('ADDING'), findsOneWidget);
      expect(find.text("Runs on the server · can't be stopped from the app"), findsOneWidget);
      expect(find.text('One More Time'), findsOneWidget);
      expect(find.text('Adding · 2 min · MP3'), findsOneWidget);
      expect(find.bySemanticsLabel('Adding'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Music, then Daft Punk, then Discovery')),
          findsOneWidget);
      expect(find.byTooltip('More for One More Time'), findsOneWidget);

      h.clock.advance(const Duration(minutes: 3));
      await t.runAsync(() => h.timers.elapse(YtdlLists.kMinuteTick));
      await t.pump();
      expect(find.text('Adding · 5 min · MP3'), findsOneWidget);
    });

    testWidgets('⋮ → Hide from this list: the row goes, the server keeps going', (t) async {
      h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
      final st = await seed(t, [job('a1', 'adding', pid: 5000)]);
      await pump(t, st);
      await t.tap(key('ytdl-row-more-a1'));
      await frames(t);
      await t.tap(key('ytdl-row-hide'));
      await frames(t);
      expect(st.jobs.single.hidden, isTrue);
      expect(st.jobs.single.open, isTrue);
      expect(h.toastTexts, ['Hidden. The server keeps going.']);
      expect(key('ytdl-row-a1'), findsNothing);
    });

    testWidgets('the ⋮ sits inside the row: a tap at its far edge opens it', (t) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
      final st = await seed(t, [job('a1', 'adding', pid: 5000)]);
      await pump(t, st);
      final more = t.getRect(key('ytdl-row-more-a1'));
      expect(more.width, greaterThanOrEqualTo(48));
      expect(more.right, lessThanOrEqualTo(390 - 16), reason: 'not in the gutter, where taps are lost');
      await t.tapAt(Offset(more.right - 2, more.center.dy));
      await frames(t);
      expect(key('ytdl-row-hide'), findsOneWidget);
    });

    testWidgets('still starting, or not answered yet: the ring, no ⋮', (t) async {
      final st = await seed(t, [
        job('u1', 'startUnsure', title: 'Sweater Weather', url: kSweater,
            directory: '/Music/TheNeighbourhood/', ago: const Duration(seconds: 40)),
      ]);
      h.fake.addGate = Completer<void>();
      unawaited(st.start(h.request()));
      await pump(t, st);
      expect(find.text('Starting…'), findsOneWidget);
      expect(find.text("Starting… the server hasn't answered yet"), findsOneWidget);
      expect(find.bySemanticsLabel('Adding'), findsNWidgets(2));
      expect(find.byIcon(Icons.more_vert), findsNothing);
      h.fake.addGate!.complete();
      await drain(t);
    });

    testWidgets('no answer from the server: "Waiting for connection"', (t) async {
      h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
      h.fake.jobsThrows = const SocketException('Network is unreachable');
      final st = await seed(t, [job('a1', 'adding', pid: 5000)]);
      expect(st.offline, isTrue);
      await pump(t, st);
      expect(find.text('Waiting for connection'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });

  group('NEEDS A LOOK', () {
    testWidgets('a name clash: Change format and retry adds again in the format '
        'picked; Show folder; Dismiss', (t) async {
      final st = await seed(t, [job('c1', 'failedClash', title: 'Feel Good Inc.', url: kFeelGood)]);
      await pump(t, st);
      expect(find.text('NEEDS A LOOK'), findsOneWidget);
      expect(
          find.text('Failed · a file with this name looks to be there already. Nothing was replaced.'),
          findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      await t.tap(key('ytdl-row-show-folder-c1'));
      expect(folders, [dir]);

      await t.tap(key('ytdl-row-change-format-c1'));
      await frames(t);
      expect(find.text('Best audio the video has, saved as'), findsOneWidget);
      expect(key('ytdl-row-format-mp3'), findsNothing, reason: 'the format that clashed');
      expect(find.text('Usually YouTube\'s own audio, no re-encode'), findsOneWidget);
      await t.tap(key('ytdl-row-format-flac'));
      await frames(t);
      await drain(t);
      expect(h.fake.bodies('POST', '/api/v1/ytdl/').single['outputCodec'], 'flac');
      expect(st.jobs.single.codec, 'flac');
      expect(st.jobs.single.predictedName, 'Feel_Good_Inc..flac');
    });

    testWidgets('Dismiss takes the row away', (t) async {
      final st = await seed(t, [job('c1', 'failedClash', title: 'Feel Good Inc.', url: kFeelGood)]);
      await pump(t, st);
      await t.tap(key('ytdl-row-dismiss-c1'));
      await t.pump();
      expect(st.jobs, isEmpty);
      expect(key('ytdl-row-c1'), findsNothing);
    });

    testWidgets('a server with one format has nothing to change to', (t) async {
      s.supportedAudioFormats = const ['mp3'];
      final st = await seed(t, [job('c1', 'failedClash', url: kFeelGood)]);
      await pump(t, st);
      expect(key('ytdl-row-change-format-c1'), findsNothing);
      expect(key('ytdl-row-show-folder-c1'), findsOneWidget);
    });

    testWidgets('no reason given: the 6.30 words, and Try again posts once more', (t) async {
      final st = await seed(t, [job('f1', 'failed', title: 'Around the World')]);
      await pump(t, st);
      expect(
          find.text('Failed · the server didn\'t say why. Common causes: a live stream, '
              'YouTube refusing the server, 500 MB, or an hour.'),
          findsOneWidget);
      await t.tap(key('ytdl-row-retry-f1'));
      await drain(t);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
      expect(st.adding.single.title, 'Around the World');
    });

    testWidgets('no reason given on a server before 6.30', (t) async {
      h.fake.hasRecords = false;
      final st = await seed(t, [job('f1', 'failed')]);
      expect(st.tier, YtdlServerTier.older);
      await pump(t, st);
      expect(find.text("Failed · the server didn't say why. YouTube may have refused the server."),
          findsOneWidget);
    });

    testWidgets('not sure it finished: Show folder (outlined) and Dismiss', (t) async {
      final st = await seed(t, [job('n1', 'notSureFinished', title: 'Robot Rock')]);
      await pump(t, st);
      expect(
          find.text('Not sure it finished · it ended while the app was away and the server '
              'has no record of it'),
          findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      await t.tap(key('ytdl-row-show-folder-n1'));
      expect(folders, [dir]);
    });

    testWidgets('not sure it started → Check again (busy while it looks) → not '
        'found → Add again', (t) async {
      final st = await seed(t, [job('s1', 'notSureStarted', title: 'Digital Love')]);
      await pump(t, st);
      expect(find.text('Not sure it started'), findsOneWidget);

      h.fake.listGate = Completer<void>();
      await t.tap(key('ytdl-row-check-again-s1'));
      await drain(t);
      expect(st.busy(st.jobs.single), isTrue);
      expect(
          find.descendant(
              of: key('ytdl-row-check-again-s1'), matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      h.fake.listGate!.complete();
      h.fake.listGate = null;
      await drain(t);
      expect(h.fake.count('GET', '/api/v1/ytdl/downloads'), greaterThanOrEqualTo(1));
      expect(find.text('Not found on the server'), findsOneWidget);

      await t.tap(key('ytdl-row-add-again-s1'));
      await drain(t);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
      expect(st.adding, hasLength(1));
    });

    final starts = <String, (String problem, String? detail, String codec, String words, bool retry)>{
      'ffmpeg': ('ffmpegNotReady', null, 'mp3',
          "The server can't convert audio right now. Try again later, or ask its admin.", true),
      'uploads off': ('uploadsOff', null, 'mp3', "Your account can't add files to this server.", false),
      'mkdir failed': ('mkdirFailed', 'Discovery', 'mp3', "Couldn't make the folder “Discovery”.", true),
      'library gone': ('libraryGone', null, 'mp3', "You can't add files to “Music” any more.", false),
      'no route': ('noRoute', null, 'mp3', "This server doesn't offer YouTube downloads.", false),
      'bad request': ('badRequest', null, 'mp3',
          "Something about this link didn't suit the server. Try again.", true),
      'server error': ('serverError', null, 'mp3', 'Something went wrong on the server.', true),
      'other words': ('other', 'Not A Directory', 'mp3', 'The server said: “Not A Directory”', true),
      'other, no words': ('other', 'HTTP 502', 'mp3', 'Something went wrong on the server.', true),
      'offline': ('offline', null, 'mp3', "Didn't start · the phone couldn't reach the server", true),
      'yt-dlp missing': ('ytdlpMissing', null, 'mp3',
          "This server can't download from YouTube yet. Ask its admin to set up yt-dlp.", true),
    };
    for (final e in starts.entries) {
      testWidgets('a start failure in the screen\'s words: ${e.key}', (t) async {
        final (problem, detail, codec, words, retry) = e.value;
        final st = await seed(t, [
          job('x1', 'startFailed', problem: problem, detail: detail, codec: codec),
        ]);
        await pump(t, st);
        expect(find.text(words), findsOneWidget);
        expect(key('ytdl-row-retry-x1'), retry ? findsOneWidget : findsNothing);
        expect(key('ytdl-row-dismiss-x1'), findsOneWidget);
      });
    }

    testWidgets('a format the server turned off: Change format and retry, '
        'without that format', (t) async {
      final st = await seed(t, [job('x1', 'startFailed', problem: 'badFormat', codec: 'opus')]);
      await pump(t, st);
      expect(find.text("This server doesn't save Opus any more"), findsOneWidget);
      expect(key('ytdl-row-retry-x1'), findsNothing);
      await t.tap(key('ytdl-row-change-format-x1'));
      await frames(t);
      expect(key('ytdl-row-format-opus'), findsNothing);
      expect(key('ytdl-row-format-mp3'), findsOneWidget);
    });

    testWidgets('a folder that couldn\'t be made: Try again, and Choose a folder… '
        'adds the song into the folder picked, in its library, making nothing', (t) async {
      s = ytdlServer(libraries: const ['Music', 'Podcasts'], formats: const ['mp3', 'm4a']);
      h.fake.folder('/Podcasts/Shows/');
      YtdlDraft? asked;
      String? askedStart;
      YtdlListActions.chooseFolder = (_, draft, {String? startAt}) async {
        asked = draft;
        askedStart = startAt;
        return '/Podcasts/Shows/';
      };
      final st = await seed(t, [
        job('x1', 'startFailed',
            problem: 'mkdirFailed',
            detail: 'Interviews',
            directory: '/Podcasts/Shows/Interviews/',
            mkdir: '/Podcasts/Shows/Interviews/'),
      ]);
      await pump(t, st);
      expect(find.text("Couldn't make the folder “Interviews”."), findsOneWidget);
      expect(key('ytdl-row-retry-x1'), findsOneWidget);
      expect(key('ytdl-row-dismiss-x1'), findsOneWidget);
      expect(t.getSize(key('ytdl-row-choose-folder-x1')).height, greaterThanOrEqualTo(48));

      await t.tap(key('ytdl-row-choose-folder-x1'));
      await drain(t);
      expect(identical(asked!.owner, st), isTrue);
      expect(asked!.choice.library, 'Podcasts', reason: "the row's library, not the remembered one");
      expect(askedStart, '/Podcasts/Shows/', reason: 'above the folder that could not be made');
      expect(h.fake.count('POST', '/api/v1/file-explorer/mkdir'), 0);
      final sent = h.fake.bodies('POST', '/api/v1/ytdl/').single;
      expect(sent['directory'], '/Podcasts/Shows/');
      expect(sent['url'], kOneMoreTime);
      expect(st.jobs.where((j) => j.id == 'x1'), isEmpty, reason: 'in place of the row');
      expect(st.adding.single.directory, '/Podcasts/Shows/');
      expect(key('ytdl-row-x1'), findsNothing);
    });

    testWidgets('Choose a folder… closed without a folder: the row stays', (t) async {
      YtdlListActions.chooseFolder = (_, _, {startAt}) async => null;
      final st = await seed(t, [
        job('x1', 'startFailed', problem: 'mkdirFailed', detail: 'Discovery', mkdir: dir),
      ]);
      await pump(t, st);
      await t.tap(key('ytdl-row-choose-folder-x1'));
      await drain(t);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0);
      expect(key('ytdl-row-x1'), findsOneWidget);
    });

    testWidgets('an account that can\'t make folders: Top of the library adds into '
        'the library\'s top; Choose a folder…; no Try again', (t) async {
      YtdlListActions.chooseFolder = (_, _, {startAt}) async => '/Music/Daft Punk/';
      final st = await seed(t, [
        job('x1', 'startFailed', problem: 'mkdirOff', mkdir: dir),
        job('x2', 'startFailed', problem: 'mkdirOff', mkdir: dir, url: kFeelGood, title: 'Feel Good Inc.'),
      ]);
      await pump(t, st);
      expect(find.text("“Discovery” doesn't exist yet and your account can't make folders."),
          findsNWidgets(2));
      expect(key('ytdl-row-retry-x1'), findsNothing);
      expect(key('ytdl-row-choose-folder-x1'), findsOneWidget);
      expect(find.descendant(of: key('ytdl-row-top-x1'), matching: find.text('Top of the library')),
          findsOneWidget);

      await t.tap(key('ytdl-row-top-x1'));
      await drain(t);
      await t.tap(key('ytdl-row-choose-folder-x2'));
      await drain(t);
      expect(h.fake.count('POST', '/api/v1/file-explorer/mkdir'), 0);
      expect([for (final b in h.fake.bodies('POST', '/api/v1/ytdl/')) b['directory']],
          ['/Music/', '/Music/Daft Punk/']);
      expect(key('ytdl-row-x1'), findsNothing);
      expect(key('ytdl-row-x2'), findsNothing);
    });

    testWidgets('the anchor sits on the NEEDS A LOOK header', (t) async {
      h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
      final st = await seed(t, [
        job('a1', 'adding', pid: 5000),
        job('f1', 'failed', url: kFeelGood),
      ]);
      final anchor = GlobalKey();
      await pump(t, st, anchor: anchor);
      expect(anchor.currentContext, isNotNull);
      expect(
          find.descendant(of: find.byKey(anchor), matching: find.text('NEEDS A LOOK')),
          findsOneWidget);
    });
  });

  group('ADDED', () {
    /// Four download records, newest first: one present 3 minutes ago, one
    /// yesterday, one gone from the library.
    void records() {
      int at(Duration d) => h.clock.current.subtract(d).millisecondsSinceEpoch;
      h.fake.addRecord(
          relativePath: 'Blur/Song_2.mp3',
          title: 'Song 2',
          present: false,
          downloadedAt: DateTime(2026, 10, 12, 9).millisecondsSinceEpoch,
          origin: 'https://www.youtube.com/watch?v=s2');
      h.fake.addRecord(
          relativePath: 'Queen/Bohemian_Rhapsody.mp3',
          title: 'Bohemian Rhapsody',
          bytes: 13600000,
          downloadedAt: at(const Duration(days: 2)),
          origin: 'https://www.youtube.com/watch?v=br');
      h.fake.addRecord(
          relativePath: 'Gorillaz/Gorillaz/Clint_Eastwood.m4a',
          title: 'Clint Eastwood',
          bytes: 5200000,
          downloadedAt: at(const Duration(hours: 20)),
          origin: 'https://www.youtube.com/watch?v=ce');
      h.fake.addRecord(
          relativePath: 'Daft Punk/Random Access Memories/Instant_Crush.mp3',
          title: 'Instant Crush',
          bytes: 8400000,
          downloadedAt: at(const Duration(minutes: 3)),
          origin: 'https://www.youtube.com/watch?v=ic');
    }

    const instantCrush = 'Music/Daft Punk/Random Access Memories/Instant_Crush.mp3';

    /// The network images drawn, by URL.
    List<String> images(WidgetTester t) => [
          for (final i in t.widgetList<Image>(find.byType(Image)))
            if ((i.image is ResizeImage ? (i.image as ResizeImage).imageProvider : i.image)
                case NetworkImage(:final url))
              url,
        ];

    testWidgets('rows read the format, size and when; a missing file is greyed '
        'with nothing to tap', (t) async {
      records();
      final st = await seed(t);
      await pump(t, st);
      expect(find.text('ADDED'), findsOneWidget);
      // Decimal megabytes to one place, as the board reads them.
      expect(find.text('MP3 · 8.4 MB · 3 min ago'), findsOneWidget);
      expect(find.text('M4A · 5.2 MB · yesterday'), findsOneWidget);
      expect(find.text('MP3 · 13.6 MB · 2 days ago'), findsOneWidget);
      expect(find.text('File missing · Oct 12'), findsOneWidget);
      expect(find.byIcon(Icons.music_off_outlined), findsOneWidget);
      expect(find.byTooltip('More for Song 2'), findsNothing);
      await t.tap(find.text('Song 2'));
      expect(played, isEmpty);
    });

    testWidgets('tap plays the song (with a leading slash); ⋮ adds it to the '
        'queue or shows its folder', (t) async {
      records();
      final st = await seed(t);
      await pump(t, st);
      await t.tap(find.text('Instant Crush'));
      await t.pump();
      expect(played.single.data, '/Music/Daft Punk/Random Access Memories/Instant_Crush.mp3');
      expect(played.single.type, 'file');
      expect(identical(played.single.server, s), isTrue);

      final more = find.byTooltip('More for Instant Crush');
      await t.tap(more);
      await frames(t);
      await t.tap(key('ytdl-added-queue'));
      await frames(t);
      expect(queued.single.data, '/Music/Daft Punk/Random Access Memories/Instant_Crush.mp3');

      await t.tap(more);
      await frames(t);
      await t.tap(key('ytdl-added-show-in-folder'));
      await frames(t);
      expect(folders, ['/Music/Daft Punk/Random Access Memories/']);
    });

    testWidgets('the library\'s art: one batched read for the songs it can name, '
        'drawn on their rows, asked once', (t) async {
      records();
      artFound = {instantCrush: 'ab12cd.jpg'};
      final st = await seed(t);
      await pump(t, st);
      await t.pump();
      expect(artAsked, hasLength(1));
      expect(artAsked.single.toSet(), {
        instantCrush,
        'Music/Gorillaz/Gorillaz/Clint_Eastwood.m4a',
        'Music/Queen/Bohemian_Rhapsody.mp3',
      }, reason: 'not the song gone from the library');
      expect(images(t), [buildAlbumArtUrl(s, 'ab12cd.jpg')], reason: 'the others keep the note');

      await t.runAsync(() => st.refreshAdded());
      await t.pump();
      expect(artAsked, hasLength(1));
    });

    test('ytdlAlbumArt: the paths as one bare array on the hub\'s client; each '
        'song\'s art file back, none for one without', () async {
      final asked = <http.Request>[];
      h.hub.makeApi = (server) => YtdlApi(server, client: MockClient((req) async {
            asked.add(req);
            return http.Response(
                jsonEncode({
                  'Music/A/One.mp3': {
                    'filepath': 'Music/A/One.mp3',
                    'metadata': {'album-art': 'one.jpg', 'title': 'One'},
                  },
                  'Music/A/Two.mp3': {
                    'filepath': 'Music/A/Two.mp3',
                    'metadata': {'album-art': null},
                  },
                  'Music/A/Gone.mp3': {'filepath': 'Music/A/Gone.mp3', 'metadata': null},
                }),
                200);
          }));
      final paths = ['Music/A/One.mp3', 'Music/A/Two.mp3', 'Music/A/Gone.mp3'];
      expect(await ytdlAlbumArt(h.hub.stateFor(s), paths), {'Music/A/One.mp3': 'one.jpg'});
      expect(asked.single.method, 'POST');
      expect(asked.single.url.toString(), 'http://music.example/api/v1/db/metadata/batch');
      expect(asked.single.headers['x-access-token'], 'JWT');
      expect(jsonDecode(asked.single.body), paths);
    });

    test('ytdlAlbumArt: a server without the route has no art', () async {
      expect(await ytdlAlbumArt(h.hub.stateFor(s), ['Music/A/One.mp3']), isEmpty);
      expect(h.fake.count('POST', '/api/v1/db/metadata/batch'), 1);
    });

    testWidgets('390 dp: the words run up to the ⋮, whose whole 48 px is inside '
        'the row and answers a tap at its far edge', (t) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      records();
      final st = await seed(t);
      await pump(t, st);
      final more = t.getRect(find.ancestor(
          of: find.byTooltip('More for Instant Crush'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuButton)));
      final play = t.getRect(find.ancestor(
          of: find.text('Instant Crush'),
          matching: find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('ytdl-added-play-'))));
      expect(more.width, greaterThanOrEqualTo(48));
      expect(more.right, lessThanOrEqualTo(390 - 16));
      expect(play.right, more.left, reason: 'no gap: the button\'s own padding is the gap');
      // cover 48 + 12: the words get the board's ~254 px less the 4 px the
      // 48 px button takes over the board's 44.
      expect(play.width - 60, greaterThanOrEqualTo(250));
      await t.tapAt(Offset(more.right - 2, more.center.dy));
      await frames(t);
      expect(key('ytdl-added-show-in-folder'), findsOneWidget);
    });

    testWidgets('a file the phone can\'t name: no play and no Add to queue', (t) async {
      h.fake.hasRecords = false;
      final st = await seed(t, [job('d1', 'added')]);
      expect(st.added.single.filepath, isNull);
      await pump(t, st);
      expect(find.text('MP3 · 2 min ago'), findsOneWidget);
      await t.tap(find.text('One More Time'));
      expect(played, isEmpty);
      await t.tap(find.byTooltip('More for One More Time'));
      await frames(t);
      expect(key('ytdl-added-queue'), findsNothing);
      expect(key('ytdl-added-show-in-folder'), findsOneWidget);
    });

    testWidgets('Show earlier asks before the oldest row read, until the record ends', (t) async {
      for (var i = 0; i < 25; i++) {
        h.fake.addRecord(relativePath: 'Daft Punk/Song_$i.mp3', title: 'Song $i');
      }
      final st = await seed(t);
      await pump(t, st);
      expect(find.text('Song 24'), findsOneWidget);
      final asked = h.fake.count('GET', '/api/v1/discovery/downloads');
      await t.ensureVisible(key('ytdl-show-earlier'));
      await t.pump();
      await t.tap(key('ytdl-show-earlier'));
      await drain(t);
      expect(h.fake.count('GET', '/api/v1/discovery/downloads'), greaterThan(asked));
      expect(st.added, hasLength(25));
      expect(find.text('Song 0'), findsOneWidget);
      expect(st.canShowEarlier, isFalse);
      expect(key('ytdl-show-earlier'), findsNothing);
    });

    testWidgets('the whole record on its first page: no Show earlier', (t) async {
      for (var i = 0; i < 3; i++) {
        h.fake.addRecord(relativePath: 'Daft Punk/Song_$i.mp3', title: 'Song $i');
      }
      final st = await seed(t);
      await pump(t, st);
      expect(find.text('Song 0'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
      expect(key('ytdl-show-earlier'), findsNothing);
    });

    testWidgets('Show earlier shows before any YouTube row was read', (t) async {
      for (var i = 0; i < 120; i++) {
        h.fake.addRecord(plugin: 'youtube', relativePath: 'Discover/Song_$i.mp3');
      }
      final st = await seed(t);
      expect(st.added, isEmpty);
      expect(st.canShowEarlier, isTrue);
      await pump(t, st);
      expect(find.text('ADDED'), findsOneWidget);
      expect(key('ytdl-show-earlier'), findsOneWidget);
      expect(key('ytdl-lists-empty'), findsNothing);
    });
  });

  group('the empty state', () {
    testWidgets('nothing yet: what to do, and on 6.30 the web-app line', (t) async {
      final st = await seed(t);
      await pump(t, st);
      expect(key('ytdl-lists-empty'), findsOneWidget);
      expect(find.text('Paste a link to add a song to your library.'), findsOneWidget);
      expect(find.text('Songs added from the web app show up here too.'), findsOneWidget);
    });

    testWidgets('a server before 6.30 has no web-app line', (t) async {
      h.fake.hasRecords = false;
      final st = await seed(t);
      await pump(t, st);
      expect(find.text('Paste a link to add a song to your library.'), findsOneWidget);
      expect(find.text('Songs added from the web app show up here too.'), findsNothing);
    });

    testWidgets('not while ADDED\'s first read is out: the rows come, never the '
        'empty state before them', (t) async {
      h.fake.addRecord(
          relativePath: 'Daft Punk/Random Access Memories/Instant_Crush.mp3',
          title: 'Instant Crush',
          origin: 'https://www.youtube.com/watch?v=ic');
      h.fake.recordsGate = Completer<void>();
      final st = h.hub.stateFor(s);
      unawaited(st.probeTier());
      await pump(t, st);
      expect(st.addedLoading, isTrue);
      expect(key('ytdl-lists-empty'), findsNothing);
      h.fake.recordsGate!.complete();
      h.fake.recordsGate = null;
      await drain(t);
      expect(st.addedLoading, isFalse);
      expect(find.text('Instant Crush'), findsOneWidget);
      expect(key('ytdl-lists-empty'), findsNothing);
    });

    testWidgets('a first read that fails: the empty state once it gives up', (t) async {
      h.fake.recordsGate = Completer<void>();
      h.fake.recordsThrows = const SocketException('Network is unreachable');
      final st = h.hub.stateFor(s);
      unawaited(st.probeTier());
      await pump(t, st);
      expect(key('ytdl-lists-empty'), findsNothing);
      h.fake.recordsGate!.complete();
      h.fake.recordsGate = null;
      await drain(t);
      expect(st.tier, YtdlServerTier.unknown);
      expect(key('ytdl-lists-empty'), findsOneWidget);
    });

    testWidgets('off while the screen shows a card', (t) async {
      final st = await seed(t);
      await pump(t, st, showEmpty: false);
      expect(key('ytdl-lists-empty'), findsNothing);
    });
  });

  testWidgets('every state at 360 dp and 200% text: rows grow, nothing overflows', (t) async {
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
    h.fake.addRecord(
        relativePath: 'Daft Punk/Random Access Memories/Instant_Crush.mp3',
        title: 'Instant Crush',
        origin: 'https://www.youtube.com/watch?v=ic');
    h.fake.addRecord(relativePath: 'Blur/Song_2.mp3', title: 'Song 2', present: false, origin: 'x');
    final st = await seed(t, [
      job('a1', 'adding', pid: 5000),
      job('u1', 'startUnsure', url: kSweater, title: 'Sweater Weather', ago: const Duration(seconds: 30)),
      job('c1', 'failedClash', url: kFeelGood, title: 'Feel Good Inc.', directory: '/Music/Gorillaz/'),
      job('f1', 'failed', title: 'Around the World', directory: '/Music/Daft Punk/Homework/'),
      job('n1', 'notSureFinished', title: 'Robot Rock'),
      job('s1', 'notSureStarted', title: 'Digital Love'),
      job('x1', 'startFailed', problem: 'mkdirFailed', detail: 'Discovery'),
    ]);
    await pump(t, st, textScale: 2);
    expect(t.takeException(), isNull);
    // The row's reason wraps under its text, never past the edge.
    final reason = t.getRect(find.textContaining('Common causes'));
    expect(reason.right, lessThanOrEqualTo(360 - 16 + 0.5));
    expect(reason.height, greaterThan(60));
    await t.drag(find.byType(ListView), const Offset(0, -3000));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('read aloud: a section\'s note with its header; an ADDED row is one '
      'button named by its words, with no "Cover" image in it', (t) async {
    final handle = t.ensureSemantics();
    h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
    h.fake.addRecord(
        relativePath: 'Daft Punk/Random Access Memories/Instant_Crush.mp3',
        title: 'Instant Crush',
        bytes: 8400000,
        downloadedAt: h.clock.current.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
        origin: 'https://www.youtube.com/watch?v=ic');
    final st = await seed(t, [job('a1', 'adding', pid: 5000)]);
    await pump(t, st);
    expect(
        t.getSemantics(find.text('ADDING')),
        isSemantics(
            label: "ADDING\nRuns on the server · can't be stopped from the app", isHeader: true));
    expect(find.bySemanticsLabel("Runs on the server · can't be stopped from the app"), findsNothing,
        reason: 'the note is no other node\'s label');
    final row = t.getSemantics(find.text('Instant Crush'));
    final spoken = row.getSemanticsData().label;
    expect(spoken, startsWith('Instant Crush'));
    expect(spoken, contains('Music, then Daft Punk, then Random Access Memories'));
    expect(spoken, contains('MP3 · 8.4 MB · 3 min ago'));
    expect(spoken, isNot(contains('Cover')));
    expect(row, isSemantics(isButton: true, hasTapAction: true, isImage: false));
    handle.dispose();
  });

  testWidgets('touch targets are at least 48 px', (t) async {
    final st = await seed(t, [job('c1', 'failedClash', url: kFeelGood)]);
    await pump(t, st);
    for (final k in ['ytdl-row-change-format-c1', 'ytdl-row-show-folder-c1', 'ytdl-row-dismiss-c1']) {
      expect(t.getSize(key(k)).height, greaterThanOrEqualTo(48), reason: k);
    }
  });
}
