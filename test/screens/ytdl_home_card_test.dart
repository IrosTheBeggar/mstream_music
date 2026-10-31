// The home's "Add from YouTube" card (spec §2, the Main board): it sits in
// SERVER right after Add torrent (and before Copies) once the hub is wired
// in, and is hidden — never greyed — in a store build, on a peer, with
// uploads off, with audio conversion off and with no library; its label is
// the screen's title. Its second line (YtdlHomeLines) is live from the
// server's state, first count wins: "Adding {n}" in the primary's ink,
// "{n} failed" in the error tone (failures only: a "not sure" row is a
// guess), "Added {n}" in grey for an hour — gone on its own while it shows
// — else nothing, and the counts the screen has shown clear. In the
// browser the card opens
// YtdlScreen for its server, and at 360 dp (also at 200% text) the label
// wraps without overflowing.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/build_variant.dart';
import 'package:mstream_music/l10n/enum_labels.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/objects/ytdl_job.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/screens/ytdl/ytdl_home_lines.dart';
import 'package:mstream_music/screens/ytdl/ytdl_screen.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

import '../singletons/ytdl_fakes.dart';

const dir = '/Music/Daft Punk/Discovery/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late YtdlHarness h;
  late Server s;
  late Directory scratch;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('ytdl-home-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    h = YtdlHarness()..wire();
    s = ytdlServer();
    ServerManager().serverList
      ..clear()
      ..add(s);
    ServerManager().currentServer = s;
  });
  tearDown(() {
    h.unwire();
    BrowserManager.homeCopiesRow = BrowserManager.noCopiesRow;
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  });

  /// The SERVER group's cards, by slug.
  List<String?> serverCards() {
    BrowserManager().goToNavScreen();
    final list = BrowserManager().browserList;
    final i = list.indexWhere((e) => e.type == 'section' && e.name == 'Server');
    if (i < 0) return const [];
    return [
      for (final e in list.skip(i + 1))
        if (e.type == 'execAction') e.data,
    ];
  }

  group('the SERVER card', () {
    test('after Add torrent, before Copies, once the hub is wired in', () {
      expect(serverCards(), ['torrents'], reason: 'not installed: never');
      h.hub.install();
      expect(serverCards(), ['torrents', 'ytdl']);
      BrowserManager.homeCopiesRow = (_) => true;
      expect(serverCards(), ['torrents', 'ytdl', 'copies']);
      final card = BrowserManager().browserList.firstWhere((e) => e.data == 'ytdl');
      expect(card.name, 'Add from YouTube');
      expect(card.icon?.icon, Icons.smart_display_outlined);
      expect(identical(card.server, s), isTrue);
    });

    test('hidden, never greyed: uploads off, conversion off, no library, a '
        'store build', () {
      h.hub.install();
      s.noUpload = true;
      expect(serverCards(), ['torrents']);
      s.noUpload = false;
      s.transcodeAvailable = false;
      expect(serverCards(), ['torrents']);
      s.transcodeAvailable = null;
      s.autoDJPaths = {};
      expect(serverCards(), ['torrents']);
      s.autoDJPaths = {'Music': true};
      YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
          defined: null, play: true, release: true, platform: TargetPlatform.android);
      expect(serverCards(), ['torrents']);
      YtdlHub.buildShowsEntry = () => true;
      expect(serverCards(), ['torrents', 'ytdl']);
    });

    test('a peer has no SERVER group at all', () {
      h.hub.install();
      final peer = ytdlPeerOf(s);
      ServerManager().serverList.add(peer);
      ServerManager().currentServer = peer;
      expect(serverCards(), isEmpty);
    });

    test('its label is the screen\'s title', () {
      expect(browserChromeLabel(h.l, 'Add from YouTube'), 'Add from YouTube');
    });
  });

  group('the second line', () {
    Future<void> pumpLines(WidgetTester t, YtdlServerState st) async {
      await t.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(body: YtdlHomeLines(state: st)),
      ));
    }

    Map<String, dynamic> job(String id, String state,
        {Duration ago = const Duration(minutes: 5), int? pid, String url = kOneMoreTime}) {
      final at = h.clock.current.subtract(ago).millisecondsSinceEpoch;
      return {
        'id': id,
        'url': url,
        'directory': dir,
        'codec': 'mp3',
        'title': 'One More Time',
        'predictedName': 'One_More_Time.mp3',
        'createdAt': at,
        if (!YtdlJobState.parse(state)!.open) 'endedAt': at,
        'state': state,
        'pid': pid,
      };
    }

    Color colorOf(WidgetTester t) =>
        t.widget<Text>(find.byKey(const ValueKey('ytdl-home-lines'))).style!.color!;

    testWidgets('first count wins: Adding, then failed, then Added, else nothing', (t) async {
      h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
      s.ytdlJobs = [
        job('a1', 'adding', pid: 5000),
        job('f1', 'failed', url: kFeelGood),
        job('d1', 'added', url: kSweater),
        job('d2', 'added', url: 'https://www.youtube.com/watch?v=x'),
      ];
      final st = h.hub.stateFor(s);
      await pumpLines(t, st);
      expect(find.text('Adding 1'), findsOneWidget);
      expect(colorOf(t), keepInkOn(VelvetColors.card));

      st.hide(st.adding.single);
      await t.pump();
      expect(find.text('1 failed'), findsOneWidget);
      expect(colorOf(t), keepTone(VelvetColors.error));

      st.dismiss(st.needsLook.single);
      await t.pump();
      expect(find.text('Added 2'), findsOneWidget);
      expect(colorOf(t), VelvetColors.textSecondary);

      st.markSeen();
      await t.pump();
      expect(find.byKey(const ValueKey('ytdl-home-lines')), findsNothing);
    });

    testWidgets('"Added" lasts an hour', (t) async {
      s.ytdlJobs = [job('d1', 'added', ago: const Duration(minutes: 70))];
      await pumpLines(t, h.hub.stateFor(s));
      expect(find.byKey(const ValueKey('ytdl-home-lines')), findsNothing);
    });

    testWidgets('"Added" goes on its own once its hour is up, while it shows', (t) async {
      s.ytdlJobs = [
        job('d1', 'added', ago: const Duration(minutes: 50)),
        job('d2', 'added', ago: const Duration(minutes: 20), url: kSweater),
      ];
      final st = h.hub.stateFor(s);
      await pumpLines(t, st);
      expect(find.text('Added 2'), findsOneWidget);
      await t.runAsync(() => h.timers.elapse(const Duration(minutes: 11)));
      await t.pump();
      expect(find.text('Added 1'), findsOneWidget);
      await t.runAsync(() => h.timers.elapse(const Duration(minutes: 30)));
      await t.pump();
      expect(find.byKey(const ValueKey('ytdl-home-lines')), findsNothing);
      expect(h.timers.active, isEmpty, reason: 'nothing left to wake for');
    });

    testWidgets('"{n} failed" counts failures, not the rows that are only not sure', (t) async {
      s.ytdlJobs = [
        job('n1', 'notSureFinished'),
        job('n2', 'notSureStarted', url: kFeelGood),
        job('n3', 'notFound', url: kSweater),
        job('f1', 'failed', url: 'https://www.youtube.com/watch?v=f1'),
      ];
      final st = h.hub.stateFor(s);
      await pumpLines(t, st);
      expect(find.text('1 failed'), findsOneWidget);
      st.dismiss(st.jobs.firstWhere((j) => j.id == 'f1'));
      await t.pump();
      expect(st.needsLook, hasLength(3));
      expect(find.byKey(const ValueKey('ytdl-home-lines')), findsNothing);
    });

    testWidgets('live: an add that starts shows at once', (t) async {
      final st = h.hub.stateFor(s);
      await pumpLines(t, st);
      expect(find.byKey(const ValueKey('ytdl-home-lines')), findsNothing);
      await t.runAsync(() async {
        h.fake.folder(dir);
        await st.start(h.request());
        await ytdlSettle();
      });
      await t.pump();
      expect(find.text('Adding 1'), findsOneWidget);
    });
  });

  group('in the browser', () {
    Future<void> pumpHome(WidgetTester t, {double width = 390, double textScale = 1}) async {
      t.view.physicalSize = Size(width * 3, 800 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      h.hub.install();
      BrowserManager().goToNavScreen();
      final home = BrowserManager().browserList;
      // The SERVER group on its own (the LISTEN cards want the player).
      final i = home.indexWhere((e) => e.type == 'section' && e.name == 'Server');
      BrowserManager().addListToStack(home.sublist(i));
      await t.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const Scaffold(body: Browser()),
        ),
      ));
      await t.pump();
    }

    testWidgets('the card opens the screen for its server', (t) async {
      await pumpHome(t);
      expect(find.text('Add from YouTube'), findsOneWidget);
      await t.tap(find.text('Add from YouTube'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final screen = t.widget<YtdlScreen>(find.byType(YtdlScreen));
      expect(identical(screen.server, s), isTrue);
      expect(screen.openNeedsLook, isFalse);
    });

    testWidgets('360 dp: the label wraps to two lines, "Adding 1" fits on one', (t) async {
      h.fake.addEntry(url: kOneMoreTime, directory: dir, pid: 5000);
      s.ytdlJobs = [
        {
          'id': 'a1',
          'url': kOneMoreTime,
          'directory': dir,
          'codec': 'mp3',
          'title': 'One More Time',
          'createdAt': h.clock.current.millisecondsSinceEpoch,
          'state': 'adding',
          'pid': 5000,
        }
      ];
      await pumpHome(t, width: 360);
      expect(t.takeException(), isNull);
      final label = t.getSize(find.text('Add from YouTube'));
      final line = t.getSize(find.text('Adding 1'));
      expect(label.height, greaterThan(line.height * 1.5));
      expect(line.height, lessThan(20));
    });

    testWidgets('360 dp at 200% text: no overflow', (t) async {
      await pumpHome(t, width: 360, textScale: 2);
      expect(t.takeException(), isNull);
    });
  });
}
