// The action bar and the format menu (spec §5, §6, §8; the FormatMenu and
// ServerStates boards) against the scripted server: the menu anchored
// above the chip with only the formats the server has on, in order, each
// with its helper and a tick on the chosen one, and the pick remembered
// for the server (dismissing changes nothing; AAC only without M4A); every
// refused add's line above the button — FFmpeg not ready (the button reads
// Try again and adds again), uploads off, a lost library, no route, a
// format turned off (its "pick another" opens the menu), a bare 500, the
// server's own words, a folder that could not be made (Try again, Choose
// a folder…), no connection (offline, or the server named when the phone
// is online) — and "Already adding to this folder"; the button gone while
// conversion is off, the line saying why (also after a re-ping that says
// not ready); the bar stacking at 200% text.

import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/ytdl/ytdl_action_bar.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';

import '../singletons/ytdl_fakes.dart';
import 'ytdl_ui_fixtures.dart';

void main() {
  final ui = YtdlUi();
  late Server s;

  setUp(() {
    ui.setUp();
    s = ytdlServer(formats: const ['mp3', 'm4a', 'opus', 'flac']);
  });
  tearDown(ui.tearDown);

  YtdlHarness h() => ui.h;

  /// A found card whose folder is there, ready to add.
  Future<YtdlDraft> ready(WidgetTester t, {double textScale = 1}) async {
    h().fake.folder('/Music/Daft Punk/Discovery/');
    final d = await ui.pumpScreen(t, s, textScale: textScale);
    await ui.paste(t, d, kOneMoreTime);
    return d;
  }

  /// Tap Add with the server answering [refusal].
  Future<void> addRefused(WidgetTester t, YtdlRefusal refusal) async {
    h().fake.addRefusal = refusal;
    await t.tap(byKey('ytdl-add'));
    await ui.settle(t);
    await ui.settle(t);
  }

  /// The refusal's words (its icon and links' Text in order; no glyphs).
  String errorLine(WidgetTester t) => t
      .widgetList<Text>(find.descendant(
          of: byKey('ytdl-add-error'), matching: find.byType(Text)))
      .map((w) => w.data ?? '')
      .join();

  bool addEnabled(WidgetTester t) => t
          .widget<InkWell>(find.descendant(
              of: byKey('ytdl-add'), matching: find.byType(InkWell)))
          .onTap !=
      null;

  String addLabel(WidgetTester t) => t
      .widget<Text>(
          find.descendant(of: byKey('ytdl-add'), matching: find.byType(Text)))
      .data!;

  group('the format menu (FormatMenu)', () {
    testWidgets('anchored above the chip: header, the server\'s formats, footer',
        (t) async {
      await ready(t);
      await t.tap(byKey('ytdl-format'));
      await t.pumpAndSettle();
      final l = h().l;
      expect(find.text(l.ytdlFormatMenuTitle), findsOneWidget);
      expect(find.text(l.ytdlFormatRemembered('music.example')),
          findsOneWidget);
      final names = [
        for (final codec in ['mp3', 'm4a', 'opus', 'flac'])
          t.getRect(byKey('ytdl-format-$codec')).top,
      ];
      expect(names, orderedEquals([...names]..sort()));
      expect(byKey('ytdl-format-ogg'), findsNothing);
      expect(byKey('ytdl-format-wav'), findsNothing);
      expect(find.text(l.ytdlFormatOpusHelp), findsOneWidget);
      expect(
          find.descendant(
              of: byKey('ytdl-format-mp3'), matching: find.byIcon(Icons.check)),
          findsOneWidget);
      final menu = t.getRect(byKey('ytdl-format-menu'));
      final chip = t.getRect(byKey('ytdl-format'));
      expect(menu.bottom <= chip.top, isTrue);
    });

    testWidgets('a pick is remembered for the server; the name follows it',
        (t) async {
      final d = await ready(t);
      await t.tap(byKey('ytdl-format'));
      await t.pumpAndSettle();
      await t.tap(byKey('ytdl-format-opus'));
      await t.pumpAndSettle();
      expect(s.ytdlFormat, 'opus');
      expect(h().persisted, contains(s));
      expect(d.predictedName, 'One_More_Time.opus');
      expect(find.text('Opus'), findsOneWidget);
    });

    testWidgets('dismissed: nothing changes', (t) async {
      await ready(t);
      await t.tap(byKey('ytdl-format'));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(380, 60));
      await t.pumpAndSettle();
      expect(byKey('ytdl-format-menu'), findsNothing);
      expect(s.ytdlFormat, isNull);
    });

    testWidgets('AAC only while M4A is off', (t) async {
      s = ytdlServer(formats: const ['mp3', 'aac', 'm4b']);
      await ready(t);
      await t.tap(byKey('ytdl-format'));
      await t.pumpAndSettle();
      expect(byKey('ytdl-format-aac'), findsOneWidget);
      expect(byKey('ytdl-format-m4b'), findsNothing);
    });
  });

  group('server states (ServerStates)', () {
    testWidgets('FFmpeg not ready: the line, and the button tries again',
        (t) async {
      await ready(t);
      await addRefused(t, (500, 'FFmpeg is not available yet'));
      expect(errorLine(t), h().l.ytdlErrFfmpeg);
      expect(addLabel(t), h().l.discoverPageRetry);
      expect(addEnabled(t), isTrue);
      expect(h().repings, contains(s));
      h().fake.addRefusal = null;
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      expect(h().fake.count('POST', '/api/v1/ytdl/'), 2);
    });

    testWidgets('FFmpeg not ready and the re-ping says not ready: the button '
        'goes, the line stays (spec §8)', (t) async {
      h().hub.reping = (server) async => server.transcodeAvailable = false;
      await ready(t);
      await addRefused(t, (500, 'FFmpeg is not available yet'));
      await ui.settle(t);
      expect(byKey('ytdl-add'), findsNothing);
      expect(byKey('ytdl-format'), findsOneWidget);
      expect(errorLine(t), h().l.ytdlErrFfmpeg);
    });

    testWidgets('uploads off (403): the line, Add off', (t) async {
      await ready(t);
      await addRefused(t, (403, 'Uploading Disabled'));
      expect(errorLine(t), h().l.ytdlErrUploadsOff);
      expect(addEnabled(t), isFalse);
    });

    testWidgets('a 404 naming the library: Pick another library', (t) async {
      await ready(t);
      await addRefused(t, (404, "Library 'Music' not found"));
      expect(errorLine(t), h().l.ytdlErrLibraryGone('Music'));
    });

    testWidgets('a 404 with no JSON body: no YouTube downloads', (t) async {
      await ready(t);
      await addRefused(t, (404, null));
      expect(errorLine(t), h().l.ytdlErrNoRoute);
    });

    testWidgets('a format turned off: its name, and pick another opens the menu',
        (t) async {
      s.ytdlFormat = 'opus';
      await ready(t);
      await addRefused(t, (400, '"outputCodec" must be one of [mp3, flac]'));
      expect(errorLine(t),
          '${h().l.ytdlErrFormatOff('Opus')} · ${h().l.ytdlErrPickAnother}');
      expect(s.ytdlFormat, isNull);
      await t.tap(byKey('ytdl-pick-another'));
      await t.pumpAndSettle();
      expect(byKey('ytdl-format-menu'), findsOneWidget);
    });

    testWidgets('another validation 400: never the raw text', (t) async {
      await ready(t);
      await addRefused(t, (400, '"url" must be a valid uri'));
      expect(errorLine(t), h().l.ytdlErrBadRequest);
    });

    testWidgets('a bare 500', (t) async {
      await ready(t);
      await addRefused(t, (500, 'Server Error'));
      expect(errorLine(t), h().l.ytdlErrServer);
    });

    testWidgets('the server\'s own words', (t) async {
      await ready(t);
      await addRefused(t, (500, 'Not A Directory'));
      expect(errorLine(t), h().l.ytdlErrOther('Not A Directory'));
    });

    testWidgets('a folder that could not be made: Try again, Choose a folder…',
        (t) async {
      h().fake.mkdirRefusal = (500, 'EACCES');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      expect(errorLine(t), startsWith(h().l.ytdlErrMkdir('Daft Punk')));
      h().fake.mkdirRefusal = null;
      await t.tap(byKey('ytdl-mkdir-retry'));
      await ui.settle(t);
      await ui.settle(t);
      expect(h().fake.count('POST', '/file-explorer/mkdir'), 2);
      expect(h().fake.count('POST', '/api/v1/ytdl/'), 1);
    });

    testWidgets('a folder that could not be made: Choose a folder… applies one',
        (t) async {
      h().fake.mkdirRefusal = (500, 'EACCES');
      h().fake.folder('/Music/Singles/');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      ui.sheets.chooseAnswer = '/Music/Singles/';
      await t.tap(byKey('ytdl-mkdir-choose'));
      await ui.settle(t);
      expect(ui.sheets.choose, [d]);
      expect(d.target.directory, '/Music/Singles/');
      expect(byKey('ytdl-add-error'), findsNothing);
    });

    testWidgets('no connection for the add, the phone offline: its own line',
        (t) async {
      await ready(t);
      h().network = false;
      h().fake.addThrows = const SocketException('Network is unreachable');
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      expect(errorLine(t), h().l.ytdlErrAddOffline);
    });

    testWidgets('the add refused with the phone online: the server named',
        (t) async {
      await ready(t);
      h().fake.addThrows = const SocketException('Connection refused');
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      expect(errorLine(t), h().l.ytdlErrAddUnreachable('music.example'));
      expect(addEnabled(t), isTrue);
    });

    testWidgets('a mkdir refused with the phone online: the server named, not '
        'the folder', (t) async {
      h().fake.mkdirThrows = const SocketException('Connection refused');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      expect(errorLine(t), h().l.ytdlErrAddUnreachable('music.example'));
      expect(byKey('ytdl-mkdir-choose'), findsNothing);
      expect(h().fake.count('POST', '/api/v1/ytdl/'), 0);
    });

    testWidgets('the same link to the same folder: "Already adding", Add off',
        (t) async {
      final d = await ready(t);
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      await ui.paste(t, d, kOneMoreTime);
      expect(byKey('ytdl-already-adding'), findsOneWidget);
      expect(find.text(h().l.ytdlAlreadyAdding), findsOneWidget);
      expect(addEnabled(t), isFalse);
    });
  });

  testWidgets('conversion off: the button goes, the chip stays', (t) async {
    final s = ytdlServer(transcode: false);
    final d = ui.h.hub.stateFor(s).screenDraft;
    d.link.text = kOneMoreTime;
    ui.phone(t);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: YtdlActionBar(
            draft: d,
            formatKey: GlobalKey<YtdlFormatChipState>(),
            onAdd: () {},
          ),
        ),
      ),
    ));
    expect(d.block, YtdlBlock.convertOff);
    expect(byKey('ytdl-add'), findsNothing);
    expect(byKey('ytdl-format'), findsOneWidget);
    // Spec §8: why it went, whatever turned it off.
    expect(errorLine(t), h().l.ytdlErrFfmpeg);
  });

  group('large text (Narrow360 e)', () {
    testWidgets('100%: the chip and the button share a row', (t) async {
      await ready(t);
      final chip = t.getRect(byKey('ytdl-format'));
      final add = t.getRect(byKey('ytdl-add'));
      expect((chip.center.dy - add.center.dy).abs() < 2, isTrue);
    });

    testWidgets('200%: the chip above a full-width button', (t) async {
      await ready(t, textScale: 2);
      final chip = t.getRect(byKey('ytdl-format'));
      final add = t.getRect(byKey('ytdl-add'));
      expect(chip.bottom <= add.top, isTrue);
      expect(add.width, greaterThan(300));
      expect(t.takeException(), isNull);
    });
  });
}
