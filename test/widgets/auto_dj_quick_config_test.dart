// Auto DJ's split button and quick config (widgets/auto_dj_quick_config.dart):
// the label toggles the DJ, the chevron opens a popover against its bar; the
// popover's Play from (a checklist in place up to four servers, a page of
// its own past that), Sonic similarity and Smart filters apply each change
// at once, and the match slider once a drag lets go. While sonic similarity
// runs, a Seeds row shows the newest seeds' art and opens the Seeds page.
// The changes go out through the widget's callbacks here — the real ones
// reach MediaManager().audioHandler, which a VM test has not got.

import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart'
    show FanOutSitOut, SonicDrop;
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/objects/play_event.dart' show TrackFacts;
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/auto_dj_sheets.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/widgets/auto_dj_quick_config.dart';
import 'package:mstream_music/widgets/seed_art.dart' show SeedTiles;

Server _server(String name, {bool? discovery = true, bool? moods = true}) =>
    Server('https://$name.example.com', 'u', 'p', 'JWT', name)
      ..serverVersion = '6.26.0'
      ..discoveryEnabled = discovery
      ..moodFiltersAvailable = moods;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mgr = AutoDJManager();
  late Directory scratch;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-quick-config-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    mgr
      ..sonicSimilarityEnabled = true
      ..sonicMinSimilarity = 0.55
      ..sonicAnchorMode = SonicAnchorMode.rolling
      ..learnFromSkips = false
      ..moodFilterEnabled = false
      ..moodFilter = MoodFilter.empty;
  });

  group('AutoDjQuickConfig', () {
    late List<List<String>> playFrom;
    late List<bool> sonic;
    late List<double> matches;
    late List<MoodFilter> moods;
    late int settings;
    late int seeds;

    setUp(() {
      playFrom = [];
      sonic = [];
      matches = [];
      moods = [];
      settings = 0;
      seeds = 0;
    });

    Finder server(String name) =>
        find.byKey(ValueKey('quick-config-server-$name'));
    bool checked(Finder row) => find
        .descendant(of: row, matching: find.byIcon(Icons.check))
        .evaluate()
        .isNotEmpty;
    bool tappable(WidgetTester tester, Finder row) => tester
        .widget<InkWell>(find.descendant(of: row, matching: find.byType(InkWell)))
        .onTap != null;
    Finder within(Finder row, Finder what) =>
        find.descendant(of: row, matching: what);

    /// Quick config over [servers], [chosen] ticked (the first if not
    /// given), in a box the size the popover gets.
    Future<void> show(WidgetTester tester, List<Server> servers,
        {List<Server>? chosen,
        Server? home,
        Map<String, FanOutSitOut> sitOut = const {},
        Set<String> connecting = const {},
        SonicDrop? drop,
        List<TrackFacts> tiles = const [],
        double textScale = 1,
        bool settle = true}) async {
      final picked = chosen ?? [servers.first];
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 318,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: AutoDjQuickConfig(
                  // Each show() a fresh one, on its main page.
                  key: UniqueKey(),
                  servers: servers,
                  chosen: picked,
                  home: home ?? picked.first,
                  sitOut: (s) => sitOut[s.localname],
                  connecting: (s) => connecting.contains(s.localname),
                  sonicDrop: drop,
                  seedTiles: tiles,
                  onPlayFrom: (set) async =>
                      playFrom.add([for (final s in set) s.localname]),
                  onSonic: ({required bool on}) async => sonic.add(on),
                  onMatch: (m) async => matches.add(m),
                  onMood: (m) async => moods.add(m),
                  onOpenSettings: () => settings++,
                  onOpenSeeds: () => seeds++,
                ),
              ),
            ),
          ),
        ),
      ));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    testWidgets('up to four servers, Play from is a checklist in place',
        (tester) async {
      final home = _server('home');
      final office = _server('office');
      final lab = _server('lab');
      await show(tester, [home, office, lab], chosen: [home, office]);
      expect(find.text('PLAY FROM'), findsOneWidget);
      expect(find.text('2 servers'), findsOneWidget);
      expect(checked(server('home')), isTrue);
      expect(checked(server('office')), isTrue);
      expect(checked(server('lab')), isFalse);
      expect(find.byKey(const ValueKey('quick-config-play-from')), findsNothing);

      await tester.tap(server('lab'));
      await tester.pump();
      expect(playFrom.last, ['home', 'office', 'lab'],
          reason: 'applied at once, in the list’s order');
      expect(checked(server('lab')), isTrue);
      expect(find.text('All servers'), findsOneWidget,
          reason: 'every one ticked is All servers');

      await tester.tap(server('office'));
      await tester.pump();
      expect(playFrom.last, ['home', 'lab']);
    });

    testWidgets('the last server ticked stays ticked', (tester) async {
      final home = _server('home');
      final office = _server('office');
      await show(tester, [home, office]);
      expect(find.text('1 server'), findsOneWidget);
      expect(tappable(tester, server('home')), isFalse);
      await tester.tap(server('home'));
      await tester.pump();
      expect(playFrom, isEmpty);
      expect(checked(server('home')), isTrue);
    });

    testWidgets('past four servers, Play from has a page of its own',
        (tester) async {
      final servers = [
        for (final n in ['home', 'office', 'lab', 'den', 'attic', 'shed'])
          _server(n),
      ];
      await show(tester, servers, chosen: [servers[0], servers[1]]);
      expect(server('home'), findsNothing, reason: 'not on the main page');
      final row = find.byKey(const ValueKey('quick-config-play-from'));
      expect(within(row, find.text('home.example.com · office.example.com')),
          findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('2 servers'), findsOneWidget);
      expect(server('home'), findsOneWidget);
      final all = find.byKey(const ValueKey('quick-config-all'));
      expect(checked(all), isFalse);

      await tester.tap(all);
      await tester.pump();
      expect(playFrom.last, ['home', 'office', 'lab', 'den', 'attic', 'shed']);
      expect(checked(all), isTrue);
      expect(find.text('All servers'), findsWidgets);

      // Again: back to the server the session runs on.
      await tester.tap(all);
      await tester.pump();
      expect(playFrom.last, ['home']);

      await tester.tap(find.byKey(const ValueKey('quick-config-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quick-config-play-from')),
          findsOneWidget);
    });

    testWidgets('past four servers, the row warns when some sit out',
        (tester) async {
      final servers = [
        for (final n in ['home', 'office', 'lab', 'den', 'attic']) _server(n),
      ];
      await show(tester, servers,
          chosen: [servers[0], servers[1], servers[2]],
          sitOut: {'lab': FanOutSitOut.scanning});
      final row = find.byKey(const ValueKey('quick-config-play-from'));
      expect(within(row, find.text('2 of 3')), findsOneWidget);
      expect(within(row, find.byIcon(Icons.warning_amber_rounded)),
          findsOneWidget);
    });

    testWidgets('a row says why a server would sit out, or spins while it '
        'connects', (tester) async {
      final home = _server('home');
      final office = _server('office');
      final lab = _server('lab');
      await show(tester, [home, office, lab],
          chosen: [home, office],
          sitOut: {
            'office': FanOutSitOut.scanning,
            'lab': FanOutSitOut.discoveryOff,
          },
          connecting: {'home'},
          settle: false);
      expect(within(server('office'), find.text('Still scanning')),
          findsOneWidget);
      expect(
          within(server('office'), find.byIcon(Icons.warning_amber_rounded)),
          findsOneWidget,
          reason: 'ticked with others: amber');
      expect(within(server('lab'), find.text('Discovery off')), findsOneWidget);
      expect(within(server('lab'), find.byIcon(Icons.warning_amber_rounded)),
          findsNothing,
          reason: 'not ticked: said plainly');
      expect(within(server('home'), find.byType(CircularProgressIndicator)),
          findsOneWidget);
    });

    testWidgets('one server: no Play from to choose', (tester) async {
      await show(tester, [_server('home')]);
      expect(find.text('PLAY FROM'), findsNothing);
      expect(find.byKey(const ValueKey('quick-config-play-from')),
          findsNothing);
    });

    final match = find.byKey(const ValueKey('quick-config-match'));
    final seedsRow = find.byKey(const ValueKey('quick-config-seeds'));

    testWidgets('Sonic similarity: the switch, and no Drift | Stay close',
        (tester) async {
      await show(tester, [_server('home')]);
      expect(find.text('55%'), findsOneWidget);
      expect(find.byType(SegmentedButton<SonicAnchorMode>), findsNothing,
          reason: 'the Seeds page has it now');

      await tester.tap(find.byKey(const ValueKey('quick-config-sonic')));
      await tester.pump();
      expect(sonic, [false]);
      expect(matches, isEmpty);
    });

    testWidgets('the match slider follows a drag and applies once it lets go',
        (tester) async {
      await show(tester, [_server('home')]);
      final drag = await tester.startGesture(tester.getCenter(match));
      await drag.moveBy(const Offset(2000, 0));
      await tester.pump();
      expect(find.text('80%'), findsOneWidget, reason: 'the line follows');
      expect(matches, isEmpty, reason: 'nothing applied mid-drag');
      await drag.up();
      await tester.pump();
      expect(matches, [closeTo(0.80, 1e-9)]);
      expect(find.text('80%'), findsOneWidget);

      await tester.drag(match, const Offset(-2000, 0));
      await tester.pump();
      expect(matches, [closeTo(0.80, 1e-9), closeTo(0.30, 1e-9)],
          reason: 'one apply per drag, at its end');
      expect(find.text('30%'), findsOneWidget);
      expect(sonic, isEmpty, reason: 'the switch is left as it is');
    });

    testWidgets('the match slider has a name of its own', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, [_server('home')]);
      expect(tester.getSemantics(match),
          isSemantics(label: 'Sonic similarity match', value: '55%'));
      semantics.dispose();
    });

    testWidgets('Seeds opens the Seeds page', (tester) async {
      await show(tester, [_server('home')]);
      await tester.tap(seedsRow);
      expect(seeds, 1);
    });

    testWidgets('the Seeds row shows the newest seeds’ art, none while there '
        'are none', (tester) async {
      await show(tester, [_server('home')]);
      expect(find.descendant(of: seedsRow, matching: find.byType(SeedTiles)),
          findsNothing);

      await show(tester, [_server('home')], tiles: const [
        TrackFacts(server: 'home', path: '/c.mp3', title: 'C'),
        TrackFacts(server: 'home', path: '/b.mp3', title: 'B'),
        TrackFacts(server: 'home', path: '/a.mp3', title: 'A'),
      ]);
      final tiles = tester.widget<SeedTiles>(
          find.descendant(of: seedsRow, matching: find.byType(SeedTiles)));
      expect(tiles.songs.map((s) => s.title), ['C', 'B', 'A']);
      expect(tiles.size, 24);
      expect(tiles.ring, VelvetColors.raised,
          reason: 'ringed in the popover’s own colour');
      // These songs have no art, so each tile shows the placeholder. Its
      // usual fill is the raised colour too, which would leave a bare note
      // on the popover with no tile around it.
      final fills = tester
          .widgetList<Container>(find.descendant(
              of: find.byWidget(tiles), matching: find.byType(Container)))
          .map((c) => c.color)
          .whereType<Color>()
          .toList();
      expect(fills, hasLength(3));
      expect(fills, everyElement(VelvetColors.border),
          reason: 'a placeholder stands out from the ring around it');
    });

    testWidgets('the Seeds row is 48 high as drawn, and grows with the text '
        'instead of clipping it', (tester) async {
      await show(tester, [_server('home')]);
      expect(tester.getSize(seedsRow).height, 48);

      // Three times the text, about the largest iOS accessibility size.
      await show(tester, [_server('home')], textScale: 3);
      final label = tester.renderObject<RenderParagraph>(
          find.descendant(of: seedsRow, matching: find.text('Seeds')));
      expect(label.size.height,
          greaterThanOrEqualTo(label.getMaxIntrinsicHeight(label.size.width)),
          reason: 'the whole line shows');
      expect(tester.getSize(seedsRow).height, greaterThan(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sonic similarity off: Off, and no match or Seeds',
        (tester) async {
      mgr.sonicSimilarityEnabled = false;
      await show(tester, [_server('home')]);
      expect(find.text('Off'), findsOneWidget);
      expect(match, findsNothing);
      expect(seedsRow, findsNothing);

      await tester.tap(find.byKey(const ValueKey('quick-config-sonic')));
      await tester.pump();
      expect(sonic, [true]);
    });

    testWidgets('where sonic can’t run, the reason, and no switch to flip',
        (tester) async {
      await show(tester, [_server('home', discovery: false)]);
      expect(find.text('Discovery off'), findsOneWidget);
      final toggle = tester.widget<Switch>(
          find.byKey(const ValueKey('quick-config-sonic')));
      expect(toggle.onChanged, isNull);
      expect(toggle.value, isFalse);
      expect(match, findsNothing, reason: 'blocked counts as off');
      expect(seedsRow, findsNothing);
    });

    testWidgets('a session that dropped sonic says why, in amber',
        (tester) async {
      await show(tester, [_server('home')], drop: SonicDrop.tooStrict);
      expect(find.text('Too strict'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Smart filters: its page applies each choice at once; Clear',
        (tester) async {
      await show(tester, [_server('home')]);
      final row = find.byKey(const ValueKey('quick-config-mood'));
      expect(within(row, find.text('Any')), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mood-valence')), findsOneWidget);
      final clear = find.byKey(const ValueKey('quick-config-mood-clear'));
      expect(tester.widget<TextButton>(clear).onPressed, isNull,
          reason: 'nothing to clear');

      await tester.tap(find.text('Happy'));
      await tester.pump();
      expect(moods.last.valueOf(MoodScale.valence), 'happy');

      // As the manager would have it once applied.
      mgr
        ..moodFilter = moods.last
        ..moodFilterEnabled = true;
      await show(tester, [_server('home')]);
      expect(within(find.byKey(const ValueKey('quick-config-mood')),
          find.text('Happy')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quick-config-mood')));
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pump();
      expect(moods.last, MoodFilter.empty);
    });

    testWidgets('where no server can filter by mood, the row says so and '
        'stays shut', (tester) async {
      await show(tester, [_server('home', moods: false)]);
      final row = find.byKey(const ValueKey('quick-config-mood'));
      expect(within(row, find.text('No mood data')), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mood-valence')), findsNothing);
    });

    testWidgets('All Auto DJ settings opens the whole screen', (tester) async {
      await show(tester, [_server('home')]);
      await tester.tap(find.text('All Auto DJ settings'));
      expect(settings, 1);
    });
  });

  group('AutoDjSplitButton', () {
    Future<void> button(WidgetTester tester,
        {required bool above,
        required VoidCallback onToggle,
        required QuickConfigOpener onOpen}) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AutoDjAnchorBar(
              child: Container(
                key: const ValueKey('bar'),
                height: 100,
                color: Colors.black,
                alignment: Alignment.centerRight,
                child: AutoDjSplitButton(
                  menuAbove: above,
                  on: Stream.value(true),
                  onToggle: onToggle,
                  onOpen: onOpen,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('the label toggles; the chevron opens quick config against '
        'the bar, and flips while it is open', (tester) async {
      var toggles = 0;
      ({Rect button, Rect bar, bool above})? opened;
      final closed = Completer<void>();
      await button(tester,
          above: true,
          onToggle: () => toggles++,
          onOpen: (context,
              {required button, required bar, required above}) {
            opened = (button: button, bar: bar, above: above);
            return closed.future;
          });
      expect(find.byIcon(Icons.expand_less), findsOneWidget,
          reason: 'it opens above');

      await tester.tap(find.byKey(const ValueKey('auto-dj-split-toggle')));
      expect(toggles, 1);
      expect(opened, isNull);

      await tester.tap(find.byKey(const ValueKey('auto-dj-split-chevron')));
      await tester.pump();
      expect(opened!.above, isTrue);
      expect(opened!.bar, tester.getRect(find.byKey(const ValueKey('bar'))));
      expect(opened!.button, tester.getRect(find.byType(AutoDjSplitButton)));
      expect(find.byIcon(Icons.expand_more), findsOneWidget,
          reason: 'flipped while open');

      closed.complete();
      await tester.pump();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(toggles, 1, reason: 'opening never toggles');
    });

    testWidgets('in the queue header it points down and opens below',
        (tester) async {
      bool? opensAbove;
      await button(tester,
          above: false,
          onToggle: () {},
          onOpen: (context,
              {required button, required bar, required above}) async {
            opensAbove = above;
          });
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('auto-dj-split-chevron')));
      await tester.pump();
      expect(opensAbove, isFalse);
    });
  });

  group('the shared reasons', () {
    late AppLocalizations l;
    setUpAll(() => l = lookupAppLocalizations(const Locale('en')));

    test('sonic: too old, still scanning, discovery off, or nothing', () {
      expect(autoDjSonicBlocked(l, _server('a')), isNull);
      expect(autoDjSonicBlocked(l, _server('a', discovery: false)),
          'Discovery off');
      expect(
          autoDjSonicBlocked(l, _server('a')..discoveryReady = false),
          'Still scanning');
      expect(autoDjSonicBlocked(l, _server('a')..serverVersion = '6.10.0'),
          startsWith('Needs server'));
      expect(autoDjSonicBlocked(l, null), 'Discovery off');
    });

    test('mood: a lone peer, no server that can filter, or nothing', () {
      final a = _server('a');
      final b = _server('b', moods: false);
      expect(autoDjMoodBlocked(l, home: a, set: [a]), isNull);
      expect(autoDjMoodBlocked(l, home: b, set: [b]), 'No mood data');
      expect(autoDjMoodBlocked(l, home: b, set: [b, a]), isNull,
          reason: 'one taking part can filter');
      final peer = Server('federated://home/3', null, null, null, 'peer')
        ..federationParent = 'home'
        ..federationPeerId = 3;
      expect(autoDjMoodBlocked(l, home: peer, set: [peer]), 'Not on peers');
    });

    test('learning from skips: a server that takes negatives, or why not',
        () {
      Server learns(String n) => _server(n)
        ..discoveryReady = true
        ..autoDjGeneration = 1;
      final a = learns('a');
      final old = _server('old')..discoveryReady = true;
      final unready = learns('unready')..discoveryReady = null;
      expect(autoDjLearnBlocked(l, home: a, set: [a]), isNull);
      expect(autoDjLearnBlocked(l, home: old, set: [old]),
          'Needs a newer server');
      expect(autoDjLearnBlocked(l, home: unready, set: [unready]),
          'Needs a newer server',
          reason: 'readiness it can’t report counts against it');
      expect(autoDjLearnBlocked(l, home: old, set: [old, a]), isNull,
          reason: 'one taking part takes them');
      expect(autoDjLearnBlocked(l, home: a, set: [old, unready]),
          'Needs a newer server',
          reason: 'with several, the set decides, not the home');
      expect(autoDjLearnBlocked(l, home: null, set: const []),
          'Needs a newer server');
    });
  });
}
