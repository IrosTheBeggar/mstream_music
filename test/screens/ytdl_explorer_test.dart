// Add from YouTube in the File Explorer (spec §7, the ExplorerBars and
// ExplorerAfter boards). The entry: an icon button before search in a
// folder without songs, the first ⋮ item over a divider in a folder with
// songs, both opening the folder sheet for the folder on screen; hidden at
// '/', in Local Files, in an m3u, on a peer, with uploads off, in a store
// build and before the hub is wired in; and taken away when a re-ping says
// uploads are off. The strip: "Adding “One More Time”… · See all",
// "Adding 2 videos… · See all", "Couldn't add “…” · Details" — only in the
// target folder and its parents — opening the screen (at NEEDS A LOOK for
// Details). The re-list when a job settles in the folder on screen or
// below: the frame replaced in place (the scroll offset kept), the new
// subfolder or file tinted for 2 s with its row's height unchanged, nothing
// for another folder or once the user has left.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/build_variant.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/ytdl/ytdl_folder_strip.dart';
import 'package:mstream_music/screens/ytdl/ytdl_screen.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';

import '../singletons/ytdl_fakes.dart';

const daftPunk = '/Music/Daft Punk/';
const discovery = '/Music/Daft Punk/Discovery/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late YtdlHarness h;
  late Server s;
  late Directory scratch;
  late List<(Server, String)> sheets;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('ytdl-explorer-test-');
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
    h.hub.install();
    BrowserManager().goToNavScreen();
    sheets = [];
    BrowserToolbar.openYtdlFolderSheet =
        (_, server, path) async => sheets.add((server, path));
  });
  tearDown(() {
    h.unwire();
    YtdlRowHighlight.reset();
    BrowserToolbar.openYtdlFolderSheet = (_, _, _) async {};
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  });

  DisplayItem folder(String path, String name, {Server? on}) => DisplayItem(on ?? s,
      name, 'directory', '$path$name', Icon(Icons.folder, color: VelvetColors.warning), null);
  DisplayItem file(String path, String name, {Server? on}) => DisplayItem(on ?? s,
      name, 'file', '$path$name', Icon(Icons.music_note, color: VelvetColors.accent), null);

  /// [rows] pushed as the File Explorer at [path].
  void open(String path, List<DisplayItem> rows) {
    BrowserManager().setBrowserLabel('File Explorer');
    BrowserManager().addListToStack(rows, alphabetical: true, path: path);
  }

  List<DisplayItem> daftPunkRows() => [
        folder(daftPunk, 'Homework'),
        folder(daftPunk, 'Human After All'),
        folder(daftPunk, 'Random Access Memories'),
      ];

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: const Scaffold(appBar: BrowserToolbar(), body: Browser()),
    ));
    await t.pump();
  }

  Future<void> drain(WidgetTester t) async {
    for (var i = 0; i < 30; i++) {
      await t.pump();
    }
  }

  final button = find.byKey(const ValueKey('ytdl-explorer-button'));

  group('the entry', () {
    testWidgets('a folder without songs: an icon before search, opening the '
        'sheet for the folder on screen', (t) async {
      open(daftPunk, daftPunkRows());
      await pump(t);
      expect(button, findsOneWidget);
      expect(find.byTooltip('Add from YouTube here'), findsOneWidget);
      expect(t.getRect(button).right, lessThanOrEqualTo(t.getRect(find.byIcon(Icons.search)).left));
      expect(t.getSize(button).height, greaterThanOrEqualTo(44));
      await t.tap(button);
      expect(sheets.single.$2, daftPunk);
      expect(identical(sheets.single.$1, s), isTrue);
    });

    testWidgets('a folder with songs: the first ⋮ item, over a divider', (t) async {
      const homework = '/Music/Daft Punk/Homework/';
      open(homework, [file(homework, 'Da Funk.mp3'), file(homework, 'Revolution 909.mp3')]);
      await pump(t);
      expect(button, findsNothing);
      await t.tap(find.byIcon(Icons.more_vert));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final item = find.byKey(const ValueKey('ytdl-explorer-menu-item'));
      expect(item, findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      expect(t.getRect(item).top, lessThan(t.getRect(find.text('Search list')).top));
      expect(t.getRect(find.byType(PopupMenuDivider)).top,
          lessThan(t.getRect(find.text('Search list')).top));
      await t.tap(find.text('Add from YouTube here'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(sheets.single.$2, homework);
    });

    final hidden = <String, void Function(Server s, Server peer)>{
      'at the root': (s, _) => BrowserManager()
          .addListToStack([DisplayItem(s, 'Music', 'directory', '/Music', null, null)], path: '/'),
      'in Local Files': (s, _) => BrowserManager()
          .addListToStack([DisplayItem(s, 'Album', 'localDirectory', 'Album', null, null)], path: ''),
      'in an m3u': (s, _) => BrowserManager().addListToStack(
          [DisplayItem(s, 'x.mp3', 'file', '/Music/x.mp3', null, null)], path: '/Music/mix.m3u'),
      'on a peer': (_, peer) => BrowserManager().addListToStack(
          [DisplayItem(peer, 'Shared', 'directory', '/Shared/A', null, null)], path: '/Shared/'),
      'with uploads off': (s, _) {
        s.noUpload = true;
        BrowserManager().addListToStack([folder(daftPunk, 'Homework')], path: daftPunk);
      },
      'in a store build': (s, _) {
        YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
            defined: null, play: false, release: true, platform: TargetPlatform.iOS);
        BrowserManager().addListToStack([folder(daftPunk, 'Homework')], path: daftPunk);
      },
      'before the hub is wired in': (s, _) {
        h.hub.reset();
        h.wire();
        BrowserManager().addListToStack([folder(daftPunk, 'Homework')], path: daftPunk);
      },
    };
    for (final e in hidden.entries) {
      testWidgets('hidden ${e.key}', (t) async {
        e.value(s, ytdlPeerOf(s));
        await pump(t);
        expect(button, findsNothing);
        final more = find.byIcon(Icons.more_vert);
        if (more.evaluate().isNotEmpty) {
          await t.tap(more);
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          expect(find.byKey(const ValueKey('ytdl-explorer-menu-item')), findsNothing);
        }
      });
    }

    testWidgets('a re-ping that says uploads are off takes it away', (t) async {
      h.hub.reping = (server) async => server.noUpload = true;
      open(daftPunk, daftPunkRows());
      await pump(t);
      expect(button, findsOneWidget);
      h.fake.addRefusal = (403, 'Uploading Disabled');
      await t.runAsync(() async {
        await h.hub.stateFor(s).start(h.request());
        await ytdlSettle();
      });
      await t.pump();
      expect(button, findsNothing);
    });
  });

  group('the strip', () {
    final strip = find.byKey(const ValueKey('ytdl-strip'));
    final failed = find.byKey(const ValueKey('ytdl-strip-failed'));

    Future<void> start(WidgetTester t,
        {String url = kOneMoreTime,
        String directory = discovery,
        String title = 'One More Time',
        String? predictedName}) async {
      await t.runAsync(() async {
        h.fake.folder(directory);
        await h.hub.stateFor(s).start(h.request(
            url: url,
            directory: directory,
            title: title,
            predictedName: predictedName ?? '${title.replaceAll(' ', '_')}.mp3'));
        await ytdlSettle();
      });
      await t.pump();
    }

    testWidgets('one add in a subfolder: "Adding “One More Time”…", See all '
        'opens the screen', (t) async {
      open(daftPunk, daftPunkRows());
      await pump(t);
      expect(strip, findsNothing);
      await start(t);
      expect(find.text('Adding “One More Time”…'), findsOneWidget);
      expect(t.getSize(find.byKey(const ValueKey('ytdl-strip-see-all'))).height,
          greaterThanOrEqualTo(48));
      await t.tap(find.text('See all'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final screen = t.widget<YtdlScreen>(find.byType(YtdlScreen));
      expect(identical(screen.server, s), isTrue);
      expect(screen.openNeedsLook, isFalse);
    });

    testWidgets('two adds: "Adding 2 videos…"', (t) async {
      open(daftPunk, daftPunkRows());
      await pump(t);
      await start(t);
      await start(t, url: kFeelGood, title: 'Feel Good Inc.');
      expect(find.text('Adding 2 videos…'), findsOneWidget);
    });

    testWidgets('only in the target folder and its parents', (t) async {
      open('/Music/Gorillaz/', [folder('/Music/Gorillaz/', 'Demon Days')]);
      await pump(t);
      await start(t);
      expect(strip, findsNothing);
      open(discovery, [file(discovery, 'Aerodynamic.mp3')]);
      await drain(t);
      expect(strip, findsOneWidget);
      open('/Music/', [folder('/Music/', 'Daft Punk')]);
      await drain(t);
      expect(strip, findsOneWidget);
    });

    testWidgets('a failure: "Couldn\'t add “Around the World”", Details opens '
        'the screen at NEEDS A LOOK', (t) async {
      const homework = '/Music/Daft Punk/Homework/';
      open(homework, [file(homework, 'Da Funk.mp3')]);
      await pump(t);
      await start(t,
          url: 'https://www.youtube.com/watch?v=atw', directory: homework, title: 'Around the World');
      await t.runAsync(() async {
        h.fake.fail(h.fake.tracker.last['pid'] as int);
        await h.timers.elapse(YtdlServerState.kPollBeat);
      });
      await drain(t);
      expect(strip, findsNothing);
      expect(failed, findsOneWidget);
      expect(find.text("Couldn't add “Around the World”"), findsOneWidget);
      await t.tap(find.text('Details'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(t.widget<YtdlScreen>(find.byType(YtdlScreen)).openNeedsLook, isTrue);
    });
  });

  group('the re-list', () {
    Future<void> finishAll(WidgetTester t) async {
      await t.runAsync(() async {
        for (final e in [...h.fake.tracker]) {
          h.fake.finish(e['pid'] as int);
        }
        await h.timers.elapse(YtdlServerState.kPollBeat);
      });
      await drain(t);
    }

    Future<void> startIn(WidgetTester t, String directory) async {
      await t.runAsync(() async {
        h.fake.folder(directory);
        await h.hub.stateFor(s).start(h.request(directory: directory));
        await ytdlSettle();
      });
      await t.pump();
    }

    List<Map<String, dynamic>> listings(String directory) => [
          for (final b in h.fake.bodies('POST', '/api/v1/file-explorer'))
            if (b['directory'] == directory) b
        ];

    ListTile tile(WidgetTester t, String name) =>
        t.widget<ListTile>(find.ancestor(of: find.text(name), matching: find.byType(ListTile)));

    testWidgets('into a new subfolder: the folder lists again in place, '
        '"Discovery" tinted for 2 s at the height of its neighbours', (t) async {
      for (final r in daftPunkRows()) {
        h.fake.folder('$daftPunk${r.name}/');
      }
      open(daftPunk, daftPunkRows());
      final frames = BrowserManager().browserCache.length;
      await pump(t);
      await startIn(t, discovery);
      await finishAll(t);
      expect(listings(daftPunk), hasLength(1));
      expect(BrowserManager().browserCache.length, frames, reason: 'replaced, not pushed');
      expect(find.text('Discovery'), findsOneWidget);
      expect(tile(t, 'Discovery').tileColor, VelvetColors.primaryDim);
      expect(tile(t, 'Homework').tileColor, isNull);
      final row = find.ancestor(of: find.text('Discovery'), matching: find.byType(ListTile));
      final other = find.ancestor(of: find.text('Homework'), matching: find.byType(ListTile));
      expect(t.getSize(row).height, t.getSize(other).height);

      await t.runAsync(() => h.timers.elapse(YtdlRowHighlight.kFor));
      await t.pump();
      expect(tile(t, 'Discovery').tileColor, isNull);
    });

    testWidgets('right here: the file row the record names is tinted', (t) async {
      h.fake.folder(discovery, files: ['Aerodynamic.mp3']);
      open(discovery, [file(discovery, 'Aerodynamic.mp3')]);
      await pump(t);
      await startIn(t, discovery);
      await finishAll(t);
      final lit = find.ancestor(of: find.text('One_More_Time.mp3'), matching: find.byType(Material)).first;
      expect(t.widget<Material>(lit).color,
          Color.alphaBlend(VelvetColors.primaryDim, VelvetColors.bg));
      final plain = find.ancestor(of: find.text('Aerodynamic.mp3'), matching: find.byType(Material)).first;
      expect(t.widget<Material>(plain).color, VelvetColors.bg);
    });

    testWidgets('the scroll offset stays where the user left it', (t) async {
      final many = [for (var i = 0; i < 40; i++) folder(daftPunk, 'Album ${i.toString().padLeft(2, '0')}')];
      for (final r in many) {
        h.fake.folder('$daftPunk${r.name}/');
      }
      open(daftPunk, many);
      await pump(t);
      BrowserManager().sc.jumpTo(300);
      await t.pump();
      await startIn(t, discovery);
      await finishAll(t);
      expect(listings(daftPunk), hasLength(1));
      expect(BrowserManager().sc.offset, 300);
    });

    testWidgets('another folder, or a folder the user left, is not listed again', (t) async {
      open('/Music/Gorillaz/', [folder('/Music/Gorillaz/', 'Demon Days')]);
      await pump(t);
      await startIn(t, discovery);
      await finishAll(t);
      expect(listings('/Music/Gorillaz/'), isEmpty);

      open(daftPunk, daftPunkRows());
      await t.pump();
      await startIn(t, discovery);
      BrowserManager().popBrowser();
      await t.pump();
      await finishAll(t);
      expect(listings(daftPunk), isEmpty);
    });

    testWidgets('a failure lists again (a folder may have been made) but tints nothing',
        (t) async {
      open(daftPunk, daftPunkRows());
      await pump(t);
      await startIn(t, discovery);
      await t.runAsync(() async {
        h.fake.fail(h.fake.tracker.last['pid'] as int);
        await h.timers.elapse(YtdlServerState.kPollBeat);
      });
      await drain(t);
      expect(listings(daftPunk), hasLength(1));
      expect(tile(t, 'Discovery').tileColor, isNull);
    });
  });
}
