// What the Add from YouTube widget tests share on top of the scripted
// server in ytdl_fakes: the app around a screen or a folder sheet (390×844
// by default, any size and text scale), the destination sheets swapped
// for recorders, the waits that let the fake answer, and text helpers
// that read a path without its Unicode isolates.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/ytdl/ytdl_card_parts.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/screens/ytdl/ytdl_folder_sheet.dart';
import 'package:mstream_music/screens/ytdl/ytdl_screen.dart';
import 'package:mstream_music/singletons/server_list.dart';

import '../singletons/ytdl_fakes.dart';

/// The destination sheets (phase C3's) as recorders: each call is kept, and
/// "Choose a folder" answers [chooseAnswer].
class SheetCalls {
  final List<YtdlDraft> where = [];
  final List<YtdlDraft> choose = [];
  String? chooseAnswer;

  void wire() {
    YtdlSheets.where = (context, draft) async => where.add(draft);
    YtdlSheets.chooseFolder = (context, draft) async {
      choose.add(draft);
      return chooseAnswer;
    };
  }

  void unwire() => YtdlSheets.reset();
}

/// Everything a UI test sets up and tears down (a fresh harness each time).
class YtdlUi {
  late YtdlHarness h;
  late SheetCalls sheets;

  void setUp() {
    h = YtdlHarness()..wire();
    sheets = SheetCalls()..wire();
  }

  void tearDown() {
    h.unwire();
    sheets.unwire();
    ServerManager().serverList.clear();
    debugDefaultTargetPlatformOverride = null;
  }

  /// Let the fake answer: [d] passes on the hub's clock (timers due fire),
  /// then whatever those answers started settles too.
  Future<void> settle(WidgetTester t, [Duration d = Duration.zero]) async {
    await t.runAsync(() => h.timers.elapse(d));
    await t.runAsync(() => h.timers.elapse(Duration.zero));
    await t.pump();
  }

  /// The view as a phone: [size] logical px, [textScale], and a keyboard
  /// [keyboard] px tall (0 = down).
  void phone(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double keyboard = 0,
  }) {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    t.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
    addTearDown(t.view.reset);
  }

  Widget app(Widget home, {double textScale = 1}) => MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      );

  /// The screen for [s], pushed over a home page (so it can pop), with
  /// the hub's first answers in.
  Future<YtdlDraft> pumpScreen(
    WidgetTester t,
    Server s, {
    Size size = const Size(390, 844),
    double textScale = 1,
    double keyboard = 0,
    bool openNeedsLook = false,
  }) async {
    phone(t, size: size, keyboard: keyboard);
    await t.pumpWidget(app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('test-open'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    YtdlScreen(server: s, openNeedsLook: openNeedsLook),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      textScale: textScale,
    ));
    await t.tap(find.byKey(const ValueKey('test-open')));
    await t.pumpAndSettle();
    await settle(t);
    return h.hub.stateFor(s).screenDraft;
  }

  /// The explorer's folder sheet for [s] at [path], opened over a page.
  Future<YtdlDraft> pumpSheet(
    WidgetTester t,
    Server s,
    String path, {
    Size size = const Size(390, 844),
    double textScale = 1,
    double keyboard = 0,
  }) async {
    phone(t, size: size, keyboard: keyboard);
    late BuildContext host;
    await t.pumpWidget(app(
      Builder(builder: (context) {
        host = context;
        return const Scaffold(body: SizedBox.expand());
      }),
      textScale: textScale,
    ));
    unawaited(showYtdlFolderSheet(host, s, path));
    await t.pumpAndSettle();
    await settle(t);
    return h.hub.stateFor(s).folderDraft(path);
  }

  /// [link] typed into [d], looked up, and its path checked.
  Future<void> paste(WidgetTester t, YtdlDraft d, String link) async {
    d.link.text = link;
    await settle(t, YtdlDraft.kLookupDebounce);
    await settle(t, YtdlDraft.kCheckAfter);
  }
}

/// [s] without the Unicode isolates paths wrap their crumbs in.
String plain(String s) => s.replaceAll(RegExp(r'[\u2066-\u2069]'), '');

/// Every Text and RichText on screen, as plain strings.
List<String> shownTexts(WidgetTester t) => [
      for (final w in t.widgetList<RichText>(find.byType(RichText)))
        plain(w.text.toPlainText()),
    ];

/// Some text on screen contains [part] (isolates ignored).
bool shows(WidgetTester t, String part) =>
    shownTexts(t).any((s) => s.contains(plain(part)));

/// Scroll [f] into view, let the list lay out, and tap it.
Future<void> tapIn(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
}

/// The finder for the widget keyed `ytdl-…`.
Finder byKey(String key) => find.byKey(ValueKey(key));
