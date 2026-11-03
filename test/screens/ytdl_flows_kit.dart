// What the cross-slice Add from YouTube flows share (ytdl_flows_test): the
// real composite — Browser + BrowserToolbar, YtdlScreen and its lists, the
// real Where, folder and "Choose a folder" sheets, the explorer strip — on
// YtdlHarness and the scripted server, with no sheet recorders. The home's
// SERVER group or a File Explorer frame pumped as the app shows them, the
// waits that let the fake answer and the routes animate, typing a link,
// and a watcher for every FlutterError on top of takeException.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/ytdl/ytdl_card_parts.dart';
import 'package:mstream_music/screens/ytdl/ytdl_folder_sheet.dart';
import 'package:mstream_music/screens/ytdl/ytdl_folder_strip.dart';
import 'package:mstream_music/screens/ytdl/ytdl_lists.dart';
import 'package:mstream_music/screens/ytdl/ytdl_screen.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';

import '../singletons/ytdl_fakes.dart';

export '../singletons/ytdl_fakes.dart';
export 'ytdl_ui_fixtures.dart' show plain, shownTexts, shows, tapIn, byKey;

const daftPunk = '/Music/Daft Punk/';
const discovery = '/Music/Daft Punk/Discovery/';
const homework = '/Music/Daft Punk/Homework/';

Directory? _scratch;

/// setUpAll: path_provider into a temp dir (the browser's caches).
void flowsSetUpAll() {
  _scratch = Directory.systemTemp.createTempSync('ytdl-flows-');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => _scratch!.path);
}

void flowsTearDownAll() {
  try {
    _scratch?.deleteSync(recursive: true);
  } catch (_) {}
}

class Flows {
  late YtdlHarness h;
  late Server s;

  /// FlutterErrors seen (setState during build etc.), beyond takeException.
  final List<FlutterErrorDetails> errors = [];

  void setUp({Server? server}) {
    h = YtdlHarness()..wire();
    s = server ?? ytdlServer(formats: const ['mp3', 'm4a', 'opus']);
    ServerManager().serverList
      ..clear()
      ..add(s);
    ServerManager().currentServer = s;
    h.hub.install();
    errors.clear();
  }

  void tearDown() {
    h.unwire();
    YtdlSheets.reset();
    YtdlListActions.reset();
    YtdlScreen.resetListsBuilder();
    YtdlRowHighlight.reset();
    BrowserToolbar.openYtdlFolderSheet = showYtdlFolderSheet;
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
    debugDefaultTargetPlatformOverride = null;
  }

  void phone(WidgetTester t, {Size size = const Size(390, 844)}) {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  /// Record every FlutterError for the rest of the test (the binding's own
  /// handler still sees them too, via takeException).
  void watchErrors() {
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d);
      previous?.call(d);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  Widget app(Widget home) => MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: home,
      );

  /// The home's SERVER group as the browser shows it.
  Future<void> pumpHome(WidgetTester t) async {
    phone(t);
    BrowserManager().goToNavScreen();
    final home = BrowserManager().browserList;
    final i = home.indexWhere((e) => e.type == 'section' && e.name == 'Server');
    BrowserManager().addListToStack(home.sublist(i));
    await t.pumpWidget(
        app(const Scaffold(appBar: BrowserToolbar(), body: Browser())));
    await t.pump();
  }

  DisplayItem folderRow(String path, String name, {Server? on}) => DisplayItem(
      on ?? s, name, 'directory', '$path$name',
      Icon(Icons.folder, color: VelvetColors.warning), null);
  DisplayItem fileRow(String path, String name, {Server? on}) => DisplayItem(
      on ?? s, name, 'file', '$path$name',
      Icon(Icons.music_note, color: VelvetColors.accent), null);

  /// [rows] pushed as the File Explorer at [path] and the browser pumped.
  Future<void> pumpExplorer(
      WidgetTester t, String path, List<DisplayItem> rows) async {
    phone(t);
    BrowserManager().goToNavScreen();
    BrowserManager().setBrowserLabel('File Explorer');
    BrowserManager().addListToStack(rows, alphabetical: true, path: path);
    await t.pumpWidget(
        app(const Scaffold(appBar: BrowserToolbar(), body: Browser())));
    await t.pump();
  }

  /// Let the fake answer and the hub's timers due within [d] fire.
  Future<void> settle(WidgetTester t, [Duration d = Duration.zero]) async {
    await t.runAsync(() => h.timers.elapse(d));
    await t.runAsync(() => h.timers.elapse(Duration.zero));
    await t.pump();
  }

  /// Pump frames (animations, routes) and the fake's answers in turn.
  Future<void> drain(WidgetTester t, {int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await settle(t);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 400));
    }
  }

  /// A second of ordinary frames (50 ms): routes leaving together finish
  /// their exits in the frames they would on a phone, not in one long one.
  Future<void> frames(WidgetTester t) async {
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  /// Type [link] into the link field and let the lookup and check answer.
  Future<void> typeLink(WidgetTester t, String link) async {
    await t.enterText(find.byKey(const ValueKey('ytdl-link')), link);
    await t.pump();
    await settle(t, const Duration(milliseconds: 400));
    await settle(t, const Duration(milliseconds: 600));
    await settle(t);
  }

  /// The home card's "Add from YouTube" → the screen.
  Future<void> openFromHome(WidgetTester t) async {
    await t.tap(find.text('Add from YouTube'));
    await drain(t);
    expect(find.byType(YtdlScreen), findsOneWidget);
  }

  /// The top route popped (the screen, back to the browser).
  Future<void> back(WidgetTester t) async {
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await drain(t);
  }

  /// Nothing went wrong along the way: no exception, no FlutterError.
  void clean(WidgetTester t) {
    expect(t.takeException(), isNull);
    expect(errors, isEmpty);
  }
}
