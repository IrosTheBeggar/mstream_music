// The Auto DJ screen (screens/auto_dj.dart): Start, the session card, then
// Filters and Match. Under Sonic similarity sit Learn from skips and Seeds,
// lit while sonic picks run; while they don't — switched off, or the server
// can't — both are dimmed together, take no taps and read as disabled. Seeds
// opens the Seeds page. Learn from skips also dims alone, saying why, where
// no server takes the negatives it would teach.
//
// A fake audio handler stands in for the player: nothing playing, the DJ off,
// the seeds surface the Seeds page reads, and a record of the custom actions
// sent to it. Anything else it is asked throws, as in browse_keep_fixtures.
//
// The setters save auto_dj.json through path_provider — real file IO, which
// never finishes on the fake clock — so a tap that saves runs under runAsync
// and waits for the file.

import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/auto_dj.dart';
import 'package:mstream_music/screens/auto_dj_seeds.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';
import 'package:mstream_music/widgets/federation_widgets.dart' show FedCard;
import 'package:mstream_music/widgets/seed_art.dart';
import 'package:rxdart/rxdart.dart';

/// The player as the Auto DJ screen and the Seeds page see it: nothing
/// playing, the DJ off, the session's [seeds], and every custom action sent
/// to it in [actions].
class _FakeHandler implements AudioPlayerHandler {
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
  SonicDrop? sonicDrop;
  @override
  Server? autoDJServer;
  @override
  FanOutSitOut? multiServerSitOut(Server s) => null;

  /// The names of the custom actions sent, in order.
  final List<String> actions = [];
  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    actions.add(name);
  }

  // The seeds surface, whole: the Seeds page the Seeds row opens reads it.
  final BehaviorSubject<AutoDjSeeds> seedsSubject =
      BehaviorSubject.seeded(AutoDjSeeds.empty);
  @override
  ValueStream<AutoDjSeeds> get seedsStream => seedsSubject.stream;
  @override
  AutoDjSeeds get seeds => seedsSubject.value;
  @override
  void seedAdd(SeedList list, TrackFacts song) {}
  @override
  void seedRemove(SeedList list, String key) {}
  @override
  void seedMove(String key) {}
  @override
  void seedPin(SeedList list, String key, bool pinned) {}
  @override
  Future<void> setSeedMode(SonicAnchorMode mode) async {}
  List<Server> servers = const [];
  @override
  List<Server> seedServers() => servers;
  // Every one of them, for either list, as with the DJ off.
  @override
  List<Server> seedAddServers(SeedList list) => servers;
  @override
  bool seedsTakeNegatives = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _learn = find.byKey(const ValueKey('auto-dj-row-learn-skips'));
final _learnSwitch = find.byKey(const ValueKey('auto-dj-learn-skips-switch'));
final _seeds = find.byKey(const ValueKey('auto-dj-row-seeds'));

const _hint = 'Skipping a song will prevent similar songs from being selected';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mgr = AutoDJManager();
  final fake = _FakeHandler();
  late Directory scratch;
  late Server home;

  File savedFile() => File('${scratch.path}/auto_dj.json');

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-screen-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
    MediaManager().audioHandler = fake;
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
    // One server that runs sonic similarity and takes negatives.
    home = Server('https://home.example.com', 'u', 'p', 'JWT', 'home')
      ..serverVersion = '6.33.0'
      ..discoveryEnabled = true
      ..discoveryReady = true
      ..moodFiltersAvailable = true
      ..autoDjGeneration = 1;
    ServerManager().serverList
      ..clear()
      ..add(home);
    ServerManager().currentServer = home;
    fake
      ..sonicDrop = null
      ..autoDJServer = null
      ..servers = [home]
      ..seedsTakeNegatives = true
      ..actions.clear();
    fake.customState.add(null);
    fake.seedsSubject.add(AutoDjSeeds.empty);
    mgr
      ..sonicSimilarityEnabled = true
      ..sonicMinSimilarity = 0.55
      ..sonicAnchorMode = SonicAnchorMode.rolling
      ..learnFromSkips = false
      ..harmonicMixingEnabled = false
      ..bpmContinuityEnabled = false
      ..keywordFilterEnabled = false
      ..moodFilterEnabled = false
      ..durationFilterEnabled = false
      ..playFromServer = null
      ..playFromAll = false
      ..playFromServers = const [];
    try {
      savedFile().deleteSync();
    } catch (_) {}
  });
  tearDown(() {
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  });

  /// The screen on a phone tall enough that the list builds every card;
  /// [firstFrame] stops at the frame it opens with, before any stream's
  /// replay lands.
  Future<void> pumpScreen(WidgetTester tester, {bool firstFrame = false}) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: const AutoDJScreen(),
    ));
    if (!firstFrame) await tester.pump();
  }

  /// How strongly [f] is drawn: every Opacity above it, multiplied.
  double opacity(WidgetTester tester, Finder f) => tester
      .widgetList<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)))
      .fold(1.0, (o, w) => o * w.opacity);

  /// Whether a tap on [row] would reach it: a hit test at its InkWell's
  /// centre finds the InkWell.
  bool reachable(WidgetTester tester, Finder row) {
    final ink = find.descendant(of: row, matching: find.byType(InkWell)).first;
    final target = tester.renderObject(ink);
    return tester
        .hitTestOnBinding(tester.getCenter(ink))
        .path
        .any((e) => e.target == target);
  }

  /// Runs a tap on [f] that saves, until auto_dj.json says [key] is [value].
  Future<void> tapAndSave(WidgetTester tester, Finder f,
      {required String key, required Object value}) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      for (var i = 0; i < 400; i++) {
        try {
          final saved = jsonDecode(savedFile().readAsStringSync()) as Map;
          if (saved[key] == value) break;
        } catch (_) {
          // Not written yet, or caught mid-write.
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
  }

  testWidgets('Filters, then Match: each card holds its own rows, in order',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Must match'), findsNothing);
    expect(find.text('Prefer'), findsNothing);

    final cards = find.byType(FedCard);
    expect(cards, findsNWidgets(3));
    final filters = cards.at(1);
    final match = cards.at(2);
    const filterRows = ['mood', 'genres', 'rating', 'length', 'skip-words'];
    const matchRows = [
      'sonic', 'learn-skips', 'seeds', 'tempo', 'harmonic', //
    ];
    for (final name in filterRows) {
      expect(
          find.descendant(
              of: filters, matching: find.byKey(ValueKey('auto-dj-row-$name'))),
          findsOneWidget,
          reason: '$name under Filters');
    }
    for (final name in matchRows) {
      expect(
          find.descendant(
              of: match, matching: find.byKey(ValueKey('auto-dj-row-$name'))),
          findsOneWidget,
          reason: '$name under Match');
    }

    // Top to bottom: each header over its card, the rows in the board's
    // order.
    double top(Finder f) => tester.getTopLeft(f).dy;
    final order = [
      find.text('Filters'),
      for (final name in filterRows) find.byKey(ValueKey('auto-dj-row-$name')),
      find.text('Match'),
      for (final name in matchRows) find.byKey(ValueKey('auto-dj-row-$name')),
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i]), greaterThan(top(order[i - 1])),
          reason: '${order[i]} below ${order[i - 1]}');
    }

    // The two rows under Sonic similarity are set in by 30, past the 14 of
    // the others.
    double textLeft(String text) => tester.getTopLeft(find.text(text)).dx;
    final indent = textLeft('Learn from skips') - textLeft('Sonic similarity');
    expect(indent, closeTo(16, 0.5));
    expect(textLeft('Seeds'), textLeft('Learn from skips'));
  });

  testWidgets('with sonic on, Learn from skips and Seeds are lit and work',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    expect(opacity(tester, _learn), 1.0);
    expect(opacity(tester, _seeds), 1.0);
    expect(reachable(tester, _learn), isTrue);
    expect(reachable(tester, _seeds), isTrue);
    expect(find.descendant(of: _learn, matching: find.text(_hint)),
        findsOneWidget);
    expect(
        tester.getSemantics(_learn),
        isSemantics(
            label: 'Learn from skips\n$_hint',
            hasToggledState: true,
            isToggled: false,
            hasTapAction: true));
    expect(tester.getSemantics(_seeds),
        isSemantics(label: 'Seeds', isButton: true, hasTapAction: true));
    semantics.dispose();

    // Seeds opens the Seeds page.
    await tester.tap(_seeds);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AutoDjSeedsScreen), findsOneWidget);
  });

  testWidgets('Learn from skips flips at a tap and is saved', (tester) async {
    await pumpScreen(tester);
    expect(tester.widget<Switch>(_learnSwitch).value, isFalse);

    await tapAndSave(tester, _learn, key: 'learnFromSkips', value: true);
    expect(mgr.learnFromSkips, isTrue);
    final saved = jsonDecode(savedFile().readAsStringSync()) as Map;
    expect(saved['learnFromSkips'], isTrue);
    expect(tester.widget<Switch>(_learnSwitch).value, isTrue);

    // And back, from the switch itself.
    await tapAndSave(tester, _learnSwitch, key: 'learnFromSkips', value: false);
    expect(mgr.learnFromSkips, isFalse);
    expect(tester.widget<Switch>(_learnSwitch).value, isFalse);
  });

  testWidgets('with sonic off, both are dimmed together, inert and read as '
      'disabled, drawn as they are', (tester) async {
    mgr.sonicSimilarityEnabled = false;
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);

    // One layer over both, never dimmed twice.
    expect(opacity(tester, _learn), closeTo(0.38, 1e-9));
    expect(opacity(tester, _seeds), closeTo(0.38, 1e-9));
    // Under it, the rows' own enabled look: the title in the primary ink,
    // the switch in its usual palette, the chevron kept.
    expect(tester.widget<Text>(find.text('Learn from skips')).style?.color,
        VelvetColors.textPrimary);
    expect(tester.widget<Switch>(_learnSwitch).onChanged, isNotNull);
    expect(find.descendant(of: _seeds, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget);
    expect(find.descendant(of: _learn, matching: find.text(_hint)),
        findsOneWidget);

    expect(reachable(tester, _learn), isFalse);
    expect(reachable(tester, _seeds), isFalse);
    expect(
        tester.getSemantics(_learn),
        isSemantics(
            label: 'Learn from skips\n$_hint',
            hasEnabledState: true,
            isEnabled: false,
            hasToggledState: true,
            isToggled: false,
            hasTapAction: false));
    expect(
        tester.getSemantics(_seeds),
        isSemantics(
            label: 'Seeds',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false));
    semantics.dispose();

    await tester.tap(_learn, warnIfMissed: false);
    await tester.tap(_learnSwitch, warnIfMissed: false);
    await tester.tap(_seeds, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(mgr.learnFromSkips, isFalse);
    expect(find.byType(AutoDjSeedsScreen), findsNothing);
  });

  testWidgets('a server that can’t run sonic dims them as off does',
      (tester) async {
    // The flag is on, but the scan has not produced vectors yet.
    home.discoveryReady = false;
    await pumpScreen(tester);
    expect(find.text('Still scanning'), findsOneWidget);
    expect(opacity(tester, _learn), closeTo(0.38, 1e-9));
    expect(opacity(tester, _seeds), closeTo(0.38, 1e-9));
    expect(reachable(tester, _learn), isFalse);
    expect(reachable(tester, _seeds), isFalse);
    // The Sonic similarity row says why; Learn from skips keeps its line.
    expect(find.descendant(of: _learn, matching: find.text(_hint)),
        findsOneWidget);
  });

  testWidgets('where no server takes negatives, Learn from skips dims alone '
      'and says why', (tester) async {
    home.autoDjGeneration = null;
    // As the handler would have it for this server.
    fake.seedsTakeNegatives = false;
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    expect(find.descendant(of: _learn, matching: find.text('Needs a newer server')),
        findsOneWidget);
    expect(opacity(tester, _learn), closeTo(0.38, 1e-9));
    expect(reachable(tester, _learn), isFalse);
    expect(tester.getSemantics(_learn),
        isSemantics(label: 'Learn from skips\nNeeds a newer server',
            isEnabled: false));
    semantics.dispose();
    // Seeds still works there.
    expect(opacity(tester, _seeds), 1.0);
    expect(reachable(tester, _seeds), isTrue);

    await tester.tap(_learn, warnIfMissed: false);
    await tester.pump();
    expect(mgr.learnFromSkips, isFalse);

    // Seeds still opens its page, built on a handler whose servers take no
    // negatives.
    await tester.tap(_seeds);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AutoDjSeedsScreen), findsOneWidget);
  });

  testWidgets('the Seeds row shows the newest More like seeds’ art, none '
      'while there are none', (tester) async {
    await pumpScreen(tester);
    expect(find.descendant(of: _seeds, matching: find.byType(SeedTiles)),
        findsNothing);

    final now = DateTime(2026, 11, 17, 12);
    var seeds = AutoDjSeeds.fresh(frozen: false, now: now);
    for (final t in ['A', 'B', 'C', 'D']) {
      seeds = seeds.pushPick(
          TrackFacts(server: 'home', path: '/$t.mp3', title: t),
          now: now);
    }
    seeds = seeds.addManual(SeedList.lessLike,
        const TrackFacts(server: 'home', path: '/x.mp3', title: 'X'),
        now: now);
    // The subject tells the screen on a microtask, and the frame its
    // setState asks for is the next pump's.
    fake.seedsSubject.add(seeds);
    await tester.pump();
    await tester.pump();

    final tiles = tester.widget<SeedTiles>(
        find.descendant(of: _seeds, matching: find.byType(SeedTiles)));
    expect(tiles.songs.map((s) => s.title), ['D', 'C', 'B'],
        reason: 'More like only, newest first, three at most');
    expect(tiles.size, 26);
    expect(tiles.ring, VelvetColors.card,
        reason: 'ringed in the card’s own colour');

    // Opened afresh, the screen draws them in its very first frame.
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, firstFrame: true);
    expect(find.descendant(of: _seeds, matching: find.byType(SeedTiles)),
        findsOneWidget);
  });

  testWidgets('switching Sonic similarity off keeps the seeds: no '
      'clearSonicSession', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('auto-dj-row-sonic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auto-dj-sonic-switch')));
    await tester.pump();

    // Done saves, then asks the DJ again: real IO, off the fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('auto-dj-sheet-done')));
      for (var i = 0; i < 400 && !fake.actions.contains('retrySonic'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(mgr.sonicSimilarityEnabled, isFalse);
    expect(fake.actions, contains('retrySonic'));
    expect(fake.actions, isNot(contains('clearSonicSession')));
    // And the rows under it dim at once.
    expect(opacity(tester, _seeds), closeTo(0.38, 1e-9));
  });

  testWidgets('Harmonic mixing keeps its switch row: one node, flips at a tap',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    final row = find.byKey(const ValueKey('auto-dj-row-harmonic'));
    expect(
        tester.getSemantics(row),
        isSemantics(
            label: 'Harmonic mixing\nNext song in a key that mixes well',
            hasToggledState: true,
            isToggled: false,
            hasTapAction: true));
    semantics.dispose();

    await tapAndSave(tester, row, key: 'harmonicMixingEnabled', value: true);
    expect(mgr.harmonicMixingEnabled, isTrue);
    expect(
        tester
            .widget<Switch>(
                find.byKey(const ValueKey('auto-dj-harmonic-switch')))
            .value,
        isTrue);
  });
}
