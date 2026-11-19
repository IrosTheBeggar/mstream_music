// The network-lead sheet in German on a small phone with the largest text
// (360 dp, 200 %), drawn with the real Roboto rather than the test font's
// 1 em squares, so its line breaks and widths are a phone's: the pinned
// header, both 30-SECOND PREVIEW rows playing in turn, the YouTube card
// with its five uploads opened, a failed add with Choose another and
// Retry, and an add waiting and running with Cancel. Nothing may overflow,
// and no label that names a verb or a match may be cut short. Then the
// match tags in every language, where Polish and Russian say "match 96%"
// in the most letters.
//
// Roboto covers Latin and Cyrillic. What it lacks falls back to the test
// font's squares, wider than a phone draws them, so only ever on the safe
// side: Japanese and Chinese (a square is about a CJK glyph's width), the
// monospaced raw error, and the two text buttons that set no family of
// their own (the uploads' More / Fewer, Details).
//
// The plug-in API is the scripted fake behind the real DiscoveryPluginsApi;
// the preview player is the fake one (media/preview_fakes.dart).

import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/discovery_sheet_parts.dart'
    show DiscoverySheetGrabHandle;
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/screens/discovery/network_lead_sheet.dart';
import 'package:mstream_music/screens/discovery/network_preview_rows.dart';
import 'package:mstream_music/screens/discovery/youtube_pick_card.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

import '../../media/preview_fakes.dart';
import '../discovery_fixtures.dart';
import '../discovery_plugin_fakes.dart';

/// The Flutter SDK's Roboto files (bin/cache/artifacts/material_fonts):
/// from FLUTTER_ROOT, else from the flutter_tester running this test,
/// which lives under the same bin/cache/artifacts.
Directory _materialFonts() {
  final candidates = <Directory>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      Directory('$root/bin/cache/artifacts/material_fonts'),
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    candidates.add(Directory('${dir.path}/material_fonts'));
    dir = dir.parent;
  }
  for (final d in candidates) {
    if (File('${d.path}/Roboto-Regular.ttf').existsSync()) return d;
  }
  throw StateError(
    "No Roboto found (looked for the Flutter SDK's material_fonts); these "
    'tests measure real text and cannot run with the test font.',
  );
}

/// Registers the real Roboto — the family the theme's text styles name on
/// Android — in every upright weight.
Future<void> _loadRoboto() async {
  final dir = _materialFonts();
  final loader = FontLoader('Roboto');
  for (final weight in ['Thin', 'Light', 'Regular', 'Medium', 'Bold']) {
    final bytes = File('${dir.path}/Roboto-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// The canvas's lead: a per-song P2P row as the route hands it out.
Map<String, dynamic> _netRow() => {
  'artist': 'The Quiet Assembly',
  'title': 'Paper Satellites',
  'album': 'Static Bloom',
  'year': 2011,
  'duration': 238,
  'similarity': 0.88,
  'recordingMbid': '0f3e9b1c-7a2d-4c55-9e11-2b6f0d8a4c11',
  'isrc': 'US-RC1-76-07839',
  'peer': {'endpointId': 'ab' * 32, 'name': 'Vinyl Vault'},
};

String _watch(String id) => 'https://www.youtube.com/watch?v=$id';

/// The canvas's five uploads, best first; the last is under the bar (a
/// loose match).
List<Map<String, dynamic>> _fiveUploads() => [
  {
    'id': 'aaaaaaaaaa1',
    'url': _watch('aaaaaaaaaa1'),
    'title': 'Paper Satellites',
    'channel': 'The Quiet Assembly - Topic',
    'durationSec': 238,
    'topic': true,
    'score': 0.96,
  },
  {
    'id': 'bbbbbbbbbb2',
    'url': _watch('bbbbbbbbbb2'),
    'title': 'The Quiet Assembly - Paper Satellites (Official Video)',
    'channel': 'The Quiet Assembly',
    'durationSec': 261,
    'score': 0.89,
  },
  {
    'id': 'cccccccccc3',
    'url': _watch('cccccccccc3'),
    'title': 'Paper Satellites (2011 Remaster)',
    'score': 0.81,
  },
  {
    'id': 'dddddddddd4',
    'url': _watch('dddddddddd4'),
    'title': 'the quiet assembly - paper satellites [HQ]',
    'score': 0.70,
  },
  {
    'id': 'eeeeeeeeee5',
    'url': _watch('eeeeeeeeee5'),
    'title': 'Paper Satellites - The Quiet Assembly (1080p)',
    'channel': 'tapeloop_archive',
    'score': 0.55,
  },
];

Map<String, dynamic> _clip(String provider) => {
  'provider': provider,
  'url': 'https://cdn.example/$provider/paper-satellites.mp3',
  'seconds': 30,
  'title': 'Paper Satellites',
  'artist': 'The Quiet Assembly',
  'attribution': provider == 'deezer'
      ? 'Preview from Deezer'
      : 'Provided courtesy of iTunes',
  'link': 'https://store.example/$provider/31415',
  'match': provider == 'deezer' ? 0.97 : 0.9,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadRoboto);

  late Server server;
  late FakePluginServer fake;
  late DiscoveryJobsController jobs;
  late FakePreviewPlayer preview;

  setUp(() {
    server = discoveryServer()
      ..discoveryPluginsAvailable = true
      ..noUpload = false;
    fake = FakePluginServer()..listLeadPlugins();
    fake.youtubeCandidates = _fiveUploads();
    // A layout naming GENRE: the note under the path has its say too.
    fake.destination = {
      ...fake.destination,
      'destination': {
        'vpath': 'copies',
        'base': '',
        'layout': '{{GENRE}}/{{ALBUMARTIST}}/{{ALBUM}}',
        'source': 'user',
      },
    };
    fake.previews['deezer'] = _clip('deezer');
    fake.previews['itunes'] = _clip('itunes');
    preview = FakePreviewPlayer.install();
    KeepToast.debugSink = (_, {success = false}) {};
  });

  tearDown(() {
    KeepToast.debugSink = null;
    YoutubeKeepBlock.reset();
    DiscoveryKeepRoutes.reset();
    NetworkLeadSheet.keepBlock = null;
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The sheet for the canvas lead over a page, in [locale] at 360 ×
  /// [height] with text at [textScale], drawn in the app's theme; dragged
  /// up to its full height so the most of it shows (unless not [grow]).
  Future<void> pumpSheet(
    WidgetTester tester, {
    Locale locale = const Locale('de'),
    double textScale = 2,
    double height = 780,
    bool grow = true,
  }) async {
    tester.view.physicalSize = Size(360 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    jobs = DiscoveryJobsController(
      server: server,
      api: fake.api(server),
      timer: FakeTimers().call,
      watchLifecycle: false,
      youtubeShown: () => true,
    );
    final lead = DiscoveryLead.fromServerMap(_netRow())!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVelvetTheme(),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => unawaited(
                  showNetworkLeadSheet(
                    context,
                    jobs: jobs,
                    lead: lead,
                    seedTitle: 'Tidewater',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    unawaited(jobs.activate());
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('open')));
    await frames(tester, 8);
    if (!grow) return;
    await tester.drag(
      find.byKey(const ValueKey('network-lead-sheet')),
      const Offset(0, -400),
    );
    await frames(tester, 8);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f, warnIfMissed: false);
    await frames(tester);
  }

  /// The text of every paragraph under [of] that is cut short (an ellipsis
  /// or lines dropped).
  List<String> cutUnder(Finder of) => [
    for (final e
        in find.descendant(of: of, matching: find.byType(RichText)).evaluate())
      if ((e.renderObject! as RenderParagraph).didExceedMaxLines)
        (e.renderObject! as RenderParagraph).text.toPlainText(),
  ];

  /// What must read in full: the match tags and the pills' verbs.
  List<String> cutLabels() => [
    ...cutUnder(find.byType(LeadMatchTag)),
    ...cutUnder(find.byType(KeepPill)),
  ];

  /// [key]'s text as read: its no-break spaces as spaces, no word joiners.
  String plain(WidgetTester tester, String key) {
    final text = tester.widget<Text>(find.byKey(ValueKey(key)));
    return (text.data ?? text.textSpan!.toPlainText())
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2060', '');
  }

  group('German, 360 dp, 200 % text', () {
    testWidgets('the header, and each preview playing in turn: nothing '
        'overflows, the match tags read in full', (tester) async {
      await pumpSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Paper Satellites'), findsOneWidget);
      expect(find.text('Aus dem Netzwerk · Vinyl Vault'), findsOneWidget);
      expect(
        find.text('88\u00A0% Übereinstimmung mit „Tidewater“'),
        findsOneWidget,
      );
      expect(cutUnder(find.byKey(const ValueKey('network-lead-header'))), [
        // Two lines at most: at 200 % the byline gives way first.
        'The Quiet Assembly · Static Bloom · 2011 · 3:58',
      ]);
      expect(find.text('30-SEKUNDEN-HÖRPROBE'), findsOneWidget);

      await tapKey(tester, 'lead-preview-deezer');
      preview.emit(
        const PreviewClipState(
          provider: 'deezer',
          phase: PreviewPhase.playing,
          position: Duration(seconds: 12),
          duration: Duration(seconds: 30),
        ),
      );
      await frames(tester, 2);
      expect(tester.takeException(), isNull);
      expect(
        plain(tester, 'lead-preview-line-deezer'),
        '0:12 von 0:30 · Paper Satellites · The Quiet Assembly',
      );
      expect(find.text('Treffer 97\u00A0%'), findsOneWidget);
      expect(find.text('Preview from Deezer'), findsOneWidget);
      expect(find.byTooltip('In Deezer öffnen'), findsOneWidget);
      expect(cutUnder(find.byKey(const ValueKey('lead-previews'))), isEmpty);

      // The other row plays; the first keeps what it matched.
      await tapKey(tester, 'lead-preview-itunes');
      preview.emit(
        const PreviewClipState(
          provider: 'itunes',
          phase: PreviewPhase.playing,
          position: Duration(seconds: 27),
          duration: Duration(seconds: 30),
        ),
      );
      await frames(tester, 2);
      expect(tester.takeException(), isNull);
      expect(
        plain(tester, 'lead-preview-line-itunes'),
        '0:27 von 0:30 · Paper Satellites · The Quiet Assembly',
      );
      expect(
        plain(tester, 'lead-preview-line-deezer'),
        'Paper Satellites · The Quiet Assembly',
      );
      expect(find.text('Treffer 90\u00A0%'), findsOneWidget);
      expect(find.text('Provided courtesy of iTunes'), findsOneWidget);
      expect(find.byTooltip('In Apple Music öffnen'), findsOneWidget);
      expect(cutUnder(find.byKey(const ValueKey('lead-previews'))), isEmpty);
      expect(cutLabels(), isEmpty);
    });

    testWidgets('the YouTube card with its five uploads opened (one loose), '
        'Add this one under them: nothing overflows, every tag and verb '
        'reads in full', (tester) async {
      await pumpSheet(tester);
      expect(
        plain(tester, 'yt-destination-path'),
        'Dateien landen in copies › The Quiet Assembly › Static Bloom',
      );
      expect(find.byKey(const ValueKey('yt-never-note')), findsOneWidget);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-more');
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('yt-candidate-$i')), findsOneWidget);
      }
      expect(find.text('5 Videos gefunden · wähl eins'), findsOneWidget);
      expect(find.text('Treffer 96\u00A0%'), findsOneWidget);
      expect(find.text('ungenau 55\u00A0%'), findsOneWidget);
      expect(find.text('Weniger'), findsOneWidget);
      expect(find.text('Dieses hinzufügen'), findsOneWidget);
      expect(cutLabels(), isEmpty);
      // The upload rows themselves: thumbnail, title, Open on YouTube side
      // by side however large the text.
      for (var i = 0; i < 5; i++) {
        final row = tester.getRect(find.byKey(ValueKey('yt-candidate-$i')));
        final open = tester.getRect(find.byKey(ValueKey('yt-open-$i')));
        expect(open.right, lessThanOrEqualTo(row.right + 0.5), reason: '$i');
      }

      // A refused add says why under the button.
      fake.refuse['/plugins/youtube/jobs'] = (409, 'already running');
      await tapKey(tester, 'yt-add');
      expect(find.byKey(const ValueKey('yt-refusal')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a failed add: \"Couldn't add\", why, Details open, Choose "
        'another and Retry — nothing overflows, the verbs read in full', (
      tester,
    ) async {
      fake.addJob(
        sendableRecommendation(_netRow(), network: true)!,
        plugin: 'youtube',
        state: 'failed',
        choice: {'url': _watch('aaaaaaaaaa1')},
        error: 'Nothing matched closely enough (best score 0.48, needs 0.62)',
      );
      await pumpSheet(tester);
      expect(find.text('Hinzufügen fehlgeschlagen'), findsOneWidget);
      expect(
        find.text(
          'Nichts auf YouTube kam nah genug heran (bester Treffer 48\u00A0%).',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'yt-details');
      expect(find.byKey(const ValueKey('yt-error-raw')), findsOneWidget);
      expect(find.text('Anderes wählen'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(cutLabels(), isEmpty);
      // Both verbs inside the card.
      final card = tester.getRect(find.byKey(const ValueKey('yt-block')));
      for (final key in ['yt-choose-another', 'yt-retry']) {
        final pill = tester.getRect(find.byKey(ValueKey(key)));
        expect(pill.right, lessThanOrEqualTo(card.right + 0.5), reason: key);
      }
    });

    testWidgets('an add waiting, then fetching at 42 %: Cancel beside its '
        'line, inside the card', (tester) async {
      final job = fake.addJob(
        sendableRecommendation(_netRow(), network: true)!,
        plugin: 'youtube',
        choice: {'url': _watch('aaaaaaaaaa1')},
      );
      await pumpSheet(tester);
      expect(find.text('Wartet auf einen freien Platz'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(cutLabels(), isEmpty);

      job['state'] = 'running';
      job['progress'] = 0.42;
      job['statusText'] = '42% of “Paper Satellites”';
      job['updatedAt'] = 2;
      await jobs.refreshJobs();
      await frames(tester);
      expect(find.text('Wird von YouTube geholt · 42\u00A0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(cutLabels(), isEmpty);
      final card = tester.getRect(find.byKey(const ValueKey('yt-block')));
      final cancel = tester.getRect(find.byKey(const ValueKey('yt-cancel')));
      expect(cancel.right, lessThanOrEqualTo(card.right + 0.5));
    });
  });

  group('the header', () {
    testWidgets('360 × 640 at 200 %: it scrolls away with the sections (the '
        'grab handle stays), never leaving them a sliver of the sheet', (
      tester,
    ) async {
      await pumpSheet(tester, height: 640);
      expect(tester.takeException(), isNull);
      final sheet = find.byKey(const ValueKey('network-lead-sheet'));
      final header = find.byKey(const ValueKey('network-lead-header'));
      final top = tester.getTopLeft(sheet).dy;
      expect(tester.getTopLeft(header).dy, closeTo(top + 22, 1));
      await tester.dragFrom(const Offset(180, 560), const Offset(0, -400));
      await frames(tester, 8);
      expect(tester.getTopLeft(sheet).dy, top, reason: 'it scrolled');
      expect(header, findsNothing, reason: 'scrolled off');
      expect(
        tester
            .getBottomLeft(
              find.byKey(
                const ValueKey('network-lead-header'),
                skipOffstage: false,
              ),
            )
            .dy,
        lessThan(top),
      );
      // The handle to drag it by stays on top.
      final grab = find.byType(DiscoverySheetGrabHandle);
      expect(tester.getTopLeft(grab).dy, closeTo(top, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('360 × 640 at 100 % in English: the byline keeps the '
        "lead's length", (tester) async {
      await pumpSheet(
        tester,
        locale: const Locale('en'),
        textScale: 1,
        height: 640,
        grow: false,
      );
      expect(
        find.text('The Quiet Assembly · Static Bloom · 2011 · 3:58'),
        findsOneWidget,
      );
      expect(
        cutUnder(find.byKey(const ValueKey('network-lead-header'))),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the match tags in every language', () {
    for (final locale in appSupportedLocales) {
      testWidgets('${locale.languageCode}: the uploads opened at 360 dp and '
          '200 %, no tag cut short', (tester) async {
        await pumpSheet(tester, locale: locale);
        await tapKey(tester, 'yt-search');
        await tapKey(tester, 'yt-more');
        expect(tester.takeException(), isNull);
        final l = lookupAppLocalizations(locale);
        expect(find.text(l.discoverLeadMatchPill(96)), findsOneWidget);
        expect(find.text(l.discoverLeadLooseMatchPill(55)), findsOneWidget);
        expect(cutUnder(find.byType(LeadMatchTag)), isEmpty);
      });
    }
  });
}
