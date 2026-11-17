// The Auto DJ's Seeds page (screens/auto_dj_seeds.dart, design E): Drift |
// Stay close with the line that says what each does, then the More like and
// Less like cards, then a card of its own with the checkbox "Clear pins when
// the queue is cleared". Each row has a pin toggle and a ⋮ menu (move to the
// other list, Remove), each card ends in Add song. Stay close shows every row
// pinned with its pin locked but still amber, and leaves the ⋮ working.
// While no server in scope takes Less like songs, the Less like card says why
// and dims only its inert parts: each row's art, names and pin, and Add song;
// its rows' ⋮ stays at full strength and works, and More like's "Less like
// this" is off. A list of eight rows that all show pinned takes no more: Add
// song and the move into it are off. So are they for a list that can use no
// server's songs, and a move for a song from a server the other list can't
// use. Less like's Add song sheet has a Skipped section: the song playing now,
// then the songs skipped lately.
//
// AutoDjSeedsView is driven through its callbacks. The live page around it
// is checked against a stand-in audio handler: it draws the handler's seeds,
// follows the mode, the flags and the servers each list can use (asked again
// when Add song or a move is tapped, since the answer can change after the
// page's last build), hands every edit back, and keeps the checkbox in
// AutoDJManager.

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
import 'package:mstream_music/screens/auto_dj_seeds.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/play_history.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';
import 'package:mstream_music/widgets/federation_widgets.dart' show FedCard;
import 'package:mstream_music/widgets/seed_art.dart';
import 'package:rxdart/rxdart.dart';

final _t0 = DateTime.utc(2026, 11, 17, 12);

AutoDjSeed _seed(String path,
        {String server = 'home', bool pinned = false, String? artist}) =>
    AutoDjSeed(
      song: TrackFacts(
          server: server,
          path: path,
          title: path.split('/').last,
          artist: artist ?? 'Artist'),
      pinned: pinned,
      origin: pinned ? SeedOrigin.manual : SeedOrigin.pick,
      addedAt: _t0,
    );

AutoDjSeeds _lists(
        {List<AutoDjSeed> more = const [],
        List<AutoDjSeed> less = const [],
        bool frozen = false}) =>
    AutoDjSeeds(
        moreLike: more,
        lessLike: less,
        frozen: frozen,
        frozenAt: frozen ? _t0 : null);

Finder _row(SeedList list, String path, {String server = 'home'}) =>
    find.byKey(ValueKey('auto-dj-seed-${list.name}-${seedKey(server, path)}'));
Finder _pin(Finder row) => find.descendant(
    of: row, matching: find.byKey(const ValueKey('auto-dj-seed-pin')));
Finder _menu(Finder row) => find.descendant(
    of: row, matching: find.byKey(const ValueKey('auto-dj-seed-menu')));
Finder _art(Finder row) =>
    find.descendant(of: row, matching: find.byType(SeedArt));
Finder _names(Finder row) => find.descendant(
    of: row, matching: find.byKey(const ValueKey('auto-dj-seed-names')));
Finder _add(SeedList list) =>
    find.byKey(ValueKey('auto-dj-seeds-add-${list.name}'));
Finder _card(SeedList list) =>
    find.byKey(ValueKey('auto-dj-seeds-list-${list.name}'));
final _hint = find.byKey(const ValueKey('auto-dj-seeds-hint'));
final _reason = find.byKey(const ValueKey('auto-dj-seeds-less-reason'));
final _move = find.byKey(const ValueKey('auto-dj-seed-move'));
final _remove = find.byKey(const ValueKey('auto-dj-seed-remove'));
final _clearPins = find.byKey(const ValueKey('auto-dj-seeds-clear-pins'));
final _clearPinsBox =
    find.byKey(const ValueKey('auto-dj-seeds-clear-pins-box'));
final _clearPinsCard =
    find.byKey(const ValueKey('auto-dj-seeds-clear-pins-card'));

const _driftHint =
    'Songs are rotated out regularly. Pin a song to keep it from being removed.';
const _stayHint = 'All songs are now pinned. No new songs will be added.';
const _clearPinsLabel = 'Clear pins when the queue is cleared';

/// The pin's icon as drawn: which glyph, in which colour.
Icon _pinIcon(WidgetTester tester, Finder row) =>
    tester.widget<IconButton>(_pin(row)).icon as Icon;
bool _pinTappable(WidgetTester tester, Finder row) =>
    tester.widget<IconButton>(_pin(row)).onPressed != null;
bool _addTappable(WidgetTester tester, SeedList list) => tester
        .widget<InkWell>(
            find.descendant(of: _add(list), matching: find.byType(InkWell)))
        .onTap !=
    null;

/// How strongly [f] is drawn: every Opacity above it, multiplied.
double _opacity(WidgetTester tester, Finder f) => tester
    .widgetList<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)))
    .fold(1.0, (o, w) => o * w.opacity);

/// How strongly [list]'s Add song is drawn.
double _addOpacity(WidgetTester tester, SeedList list) => _opacity(tester,
    find.descendant(of: _add(list), matching: find.text('Add song')));

/// [row] as an inert card draws it ([dim]): its art, its names and its pin
/// under one 0.38 layer each, or none. Its ⋮ is never dimmed.
void _expectRowDim(WidgetTester tester, Finder row, {required bool dim}) {
  final layer = dim ? 0.38 : 1.0;
  expect(_opacity(tester, _art(row)), closeTo(layer, 1e-9),
      reason: 'the art');
  expect(_opacity(tester, _names(row)), closeTo(layer, 1e-9),
      reason: 'the title and artist');
  expect(_opacity(tester, _pin(row)), closeTo(layer, 1e-9),
      reason: 'the pin');
  expect(_opacity(tester, _menu(row)), 1.0,
      reason: 'the ⋮ at full strength');
}

/// The item [f] in the open ⋮ menu, as built.
PopupMenuItem<Object?> _item(WidgetTester tester, Finder f) =>
    tester.widget<PopupMenuItem<Object?>>(f);

/// A tall view, so both cards are built however many rows they hold.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The audio handler's seeds surface and nothing more: the page's reads
/// come from these fields, and its edits are written down in [calls].
class _FakeHandler implements AudioPlayerHandler {
  final BehaviorSubject<AutoDjSeeds> seedsSubject =
      BehaviorSubject.seeded(AutoDjSeeds.empty);
  @override
  ValueStream<AutoDjSeeds> get seedsStream => seedsSubject.stream;
  @override
  final BehaviorSubject<dynamic> customState = BehaviorSubject.seeded(null);
  @override
  final BehaviorSubject<List<MediaItem>> queue =
      BehaviorSubject.seeded(const []);
  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject.seeded(PlaybackState());
  @override
  bool seedsTakeNegatives = true;

  List<Server> servers = const [];
  @override
  List<Server> seedServers() => servers;

  /// What seedAddServers answers for a list; a list not in it gets
  /// [servers], as with the DJ off.
  final Map<SeedList, List<Server>> addServers = {};
  @override
  List<Server> seedAddServers(SeedList list) => addServers[list] ?? servers;

  final List<String> calls = [];
  @override
  void seedAdd(SeedList list, TrackFacts song) =>
      calls.add('add ${list.name} ${song.server}:${song.path}');
  @override
  void seedRemove(SeedList list, String key) =>
      calls.add('remove ${list.name} $key');
  @override
  void seedMove(String key) => calls.add('move $key');
  @override
  void seedPin(SeedList list, String key, bool pinned) =>
      calls.add('pin ${list.name} $key $pinned');
  @override
  Future<void> setSeedMode(SonicAnchorMode mode) async =>
      calls.add('mode ${mode.name}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One play in the history the Add song sheets read: [title] on [server],
/// [minutesAgo] before [_t0], ended by [outcome] [heardMs] in.
PlayEvent _event(String server, String path, String title,
        {required int minutesAgo,
        required PlayOutcome outcome,
        int heardMs = 5000}) =>
    PlayEvent(
      id: 'ev-$server-$path',
      startedAt: _t0.subtract(Duration(minutes: minutesAgo)),
      endedAt: _t0.subtract(Duration(minutes: minutesAgo - 1)),
      track: TrackFacts(server: server, path: path, title: title),
      playedMs: heardMs,
      outcome: outcome,
      source: PlaySource.autodj,
      counted: countsAsPlay(playedMs: heardMs, durationMs: 200000),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mgr = AutoDJManager();
  late Directory scratch;

  File savedFile() => File('${scratch.path}/auto_dj.json');

  setUpAll(() async {
    // The manager's setters and the play history write and read files; both
    // go to a scratch folder. The history is read and filled here, on the
    // real clock, so Add song finds it in memory under the test's fake one.
    // Its songs are on 'lab' and 'far', servers only the Skipped tests let
    // in.
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-seeds-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
    PlayHistory.storageDirectory = () async => scratch;
    await PlayHistory().events();
    for (final e in [
      _event('lab', '/old-skip.mp3', 'Old skip',
          minutesAgo: 180, outcome: PlayOutcome.skipped),
      _event('lab', '/played.mp3', 'Played',
          minutesAgo: 120, outcome: PlayOutcome.completed, heardMs: 200000),
      _event('lab', '/new-skip.mp3', 'New skip',
          minutesAgo: 60, outcome: PlayOutcome.skipped),
      // Moved past at once: no verdict on the song.
      _event('lab', '/instant.mp3', 'Instant',
          minutesAgo: 50, outcome: PlayOutcome.skipped, heardMs: 0),
      // Less like holds it in the Skipped tests.
      _event('lab', '/in-less.mp3', 'In less',
          minutesAgo: 40, outcome: PlayOutcome.skipped),
      // A server Less like can't use in the Skipped tests.
      _event('far', '/far-skip.mp3', 'Far skip',
          minutesAgo: 30, outcome: PlayOutcome.skipped),
      _event('far', '/far-played.mp3', 'Far played',
          minutesAgo: 20, outcome: PlayOutcome.completed, heardMs: 200000),
    ]) {
      await PlayHistory().record(e);
    }
    await PlayHistory().flush();
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
      ..sonicAnchorMode = SonicAnchorMode.rolling
      ..clearPinsOnQueueClear = false;
  });

  group('AutoDjSeedsView', () {
    late List<SonicAnchorMode> modes;
    late List<String> pins;
    late List<String> moves;
    late List<String> removes;
    late List<SeedList> adds;
    late List<bool> clears;

    setUp(() {
      modes = [];
      pins = [];
      moves = [];
      removes = [];
      adds = [];
      clears = [];
    });

    Future<void> show(WidgetTester tester, AutoDjSeeds seeds,
        {SonicAnchorMode mode = SonicAnchorMode.rolling,
        bool takesNegatives = true,
        Map<SeedList, Set<String>>? addServers,
        bool clearPins = false,
        double textScale = 1}) async {
      _tall(tester);
      // A fresh page each time, never the last one's updated in place.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: AutoDjSeedsView(
          seeds: seeds,
          mode: mode,
          takesNegatives: takesNegatives,
          addServers: addServers,
          clearPinsOnQueueClear: clearPins,
          onMode: modes.add,
          onPin: (list, key, pinned) =>
              pins.add('${list.name} $key $pinned'),
          onMove: moves.add,
          onRemove: (list, key) => removes.add('${list.name} $key'),
          onAdd: adds.add,
          onClearPinsOnQueueClear: clears.add,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester, Finder row) async {
      await tester.tap(_menu(row));
      await tester.pumpAndSettle();
    }

    Future<void> closeMenu(WidgetTester tester) async {
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    testWidgets('Drift: its line, the rows newest first, and each pin as the '
        'user left it', (tester) async {
      await show(
          tester,
          _lists(more: [
            _seed('/a.mp3', pinned: true),
            _seed('b.mp3'),
            _seed('/c.mp3'),
          ], less: [
            _seed('/x.mp3'),
          ]));
      expect(find.text('Seeds'), findsOneWidget);
      expect(find.text(_driftHint), findsOneWidget);
      expect(find.text(_stayHint), findsNothing);
      expect(
          tester
              .widget<SegmentedButton<SonicAnchorMode>>(
                  find.byKey(const ValueKey('auto-dj-seeds-mode')))
              .selected,
          {SonicAnchorMode.rolling});
      expect(find.text('More like'), findsOneWidget);
      expect(find.text('Less like'), findsOneWidget);
      expect(_reason, findsNothing);
      _expectRowDim(tester, _row(SeedList.lessLike, '/x.mp3'), dim: false);
      expect(_addOpacity(tester, SeedList.lessLike), 1.0);

      // Newest first, as the Seeds rows' art tiles are.
      final tops = [
        for (final p in ['/c.mp3', 'b.mp3', '/a.mp3'])
          tester.getTopLeft(_row(SeedList.moreLike, p)).dy,
      ];
      expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue);
      expect(find.descendant(
              of: _row(SeedList.moreLike, '/a.mp3'),
              matching: find.text('Artist')),
          findsOneWidget);

      final pinned = _pinIcon(tester, _row(SeedList.moreLike, '/a.mp3'));
      expect(pinned.icon, Icons.push_pin);
      expect(pinned.color, VelvetColors.primary);
      final loose = _pinIcon(tester, _row(SeedList.moreLike, 'b.mp3'));
      expect(loose.icon, Icons.push_pin_outlined);
      expect(loose.color, VelvetColors.textSecondary);
      expect(_pinTappable(tester, _row(SeedList.moreLike, 'b.mp3')), isTrue);
      expect(_pinTappable(tester, _row(SeedList.lessLike, '/x.mp3')), isTrue);
      expect(_addTappable(tester, SeedList.moreLike), isTrue);
      expect(_addTappable(tester, SeedList.lessLike), isTrue);
    });

    testWidgets('Drift: the pin toggles, the ⋮ moves or removes, Add song and '
        'Stay close report', (tester) async {
      await show(
          tester,
          _lists(
              more: [_seed('/a.mp3', pinned: true), _seed('b.mp3')],
              less: [_seed('/x.mp3')]));
      final a = _row(SeedList.moreLike, '/a.mp3');
      final b = _row(SeedList.moreLike, 'b.mp3');
      final x = _row(SeedList.lessLike, '/x.mp3');

      await tester.tap(_pin(b));
      await tester.tap(_pin(a));
      expect(pins, [
        'moreLike ${seedKey('home', 'b.mp3')} true',
        'moreLike ${seedKey('home', 'a.mp3')} false',
      ]);

      // A More like row moves to Less like; a Less like row the other way.
      await openMenu(tester, b);
      expect(find.text('Less like this'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(_item(tester, _move).enabled, isTrue);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      await openMenu(tester, x);
      expect(find.text('More like this'), findsOneWidget);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      expect(moves, [seedKey('home', 'b.mp3'), seedKey('home', '/x.mp3')]);

      await openMenu(tester, a);
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(removes, ['moreLike ${seedKey('home', 'a.mp3')}']);

      await tester.tap(_add(SeedList.lessLike));
      await tester.tap(_add(SeedList.moreLike));
      expect(adds, [SeedList.lessLike, SeedList.moreLike]);

      await tester.tap(find.text('Stay close'));
      await tester.pumpAndSettle();
      expect(modes, [SonicAnchorMode.locked]);
      // The chosen one again changes nothing.
      await tester.tap(find.text('Drift'));
      await tester.pumpAndSettle();
      expect(modes, [SonicAnchorMode.locked]);
    });

    testWidgets("the ⋮ menu's items lead with design B's icons",
        (tester) async {
      await show(tester,
          _lists(more: [_seed('/a.mp3')], less: [_seed('/x.mp3')]),
          takesNegatives: false);
      Finder icon(Finder item, IconData glyph) =>
          find.descendant(of: item, matching: find.byIcon(glyph));
      // The colour a glyph is painted in: the icon's own, under whatever
      // dimming the menu lays over it.
      Color? painted(Finder icon) => tester
          .widget<RichText>(
              find.descendant(of: icon, matching: find.byType(RichText)))
          .text
          .style
          ?.color;

      // More like's "Less like this", off while no server takes Less like
      // songs: the thumb down, dimmed along with its label; then Remove's ×.
      await openMenu(tester, _row(SeedList.moreLike, '/a.mp3'));
      final down = icon(_move, Icons.thumb_down);
      expect(down, findsOneWidget);
      expect(tester.widget<Icon>(down).size, 20);
      expect(painted(down)!.a, lessThan(1),
          reason: 'an item that is off dims its icon');
      final close = icon(_remove, Icons.close);
      expect(close, findsOneWidget);
      expect(painted(close), VelvetColors.textSecondary);
      expect(tester.widget<Text>(find.text('Less like this')).style!.fontSize,
          15);
      expect(tester.widget<Text>(find.text('Remove')).style!.fontSize, 15);
      await closeMenu(tester);

      // Less like's "More like this": the thumb up.
      await openMenu(tester, _row(SeedList.lessLike, '/x.mp3'));
      final up = icon(_move, Icons.thumb_up);
      expect(up, findsOneWidget);
      expect(painted(up), VelvetColors.textSecondary);
      expect(icon(_remove, Icons.close), findsOneWidget);
    });

    testWidgets('Stay close: its line, every row pinned and locked in amber, '
        'the ⋮ still working', (tester) async {
      await show(
          tester,
          _lists(
              more: [_seed('/a.mp3', pinned: true), _seed('b.mp3')],
              less: [_seed('/x.mp3')],
              frozen: true),
          mode: SonicAnchorMode.locked);
      expect(find.text(_stayHint), findsOneWidget);
      expect(find.text(_driftHint), findsNothing);
      expect(
          tester
              .widget<SegmentedButton<SonicAnchorMode>>(
                  find.byKey(const ValueKey('auto-dj-seeds-mode')))
              .selected,
          {SonicAnchorMode.locked});

      for (final row in [
        _row(SeedList.moreLike, '/a.mp3'),
        _row(SeedList.moreLike, 'b.mp3'),
        _row(SeedList.lessLike, '/x.mp3'),
      ]) {
        final icon = _pinIcon(tester, row);
        expect(icon.icon, Icons.push_pin);
        expect(icon.color, VelvetColors.primary,
            reason: "locked, not the theme's disabled grey");
        expect(_pinTappable(tester, row), isFalse);
        _expectRowDim(tester, row, dim: false);
      }
      await tester.tap(_pin(_row(SeedList.moreLike, 'b.mp3')));
      expect(pins, isEmpty);

      // The user's own edits still work while the lists hold still.
      await openMenu(tester, _row(SeedList.moreLike, 'b.mp3'));
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(removes, ['moreLike ${seedKey('home', 'b.mp3')}']);
      expect(_addTappable(tester, SeedList.moreLike), isTrue);
      await tester.tap(_add(SeedList.moreLike));
      expect(adds, [SeedList.moreLike]);

      await tester.tap(find.text('Drift'));
      await tester.pumpAndSettle();
      expect(modes, [SonicAnchorMode.rolling]);
    });

    testWidgets('Stay close shows every row pinned even before the lists '
        'report frozen', (tester) async {
      // The mode is the manager's and the lists freeze with it; the page
      // reads both, so a row never shows loose under Stay close.
      await show(tester, _lists(more: [_seed('b.mp3')]),
          mode: SonicAnchorMode.locked);
      final row = _row(SeedList.moreLike, 'b.mp3');
      expect(_pinIcon(tester, row).icon, Icons.push_pin);
      expect(_pinTappable(tester, row), isFalse);
    });

    testWidgets('the pin is one toggle, named for its song; the mode choice '
        'is a named group; the line is a live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester,
          _lists(more: [_seed('/a.mp3', pinned: true), _seed('b.mp3')]));
      expect(
          tester.getSemantics(_pin(_row(SeedList.moreLike, '/a.mp3'))),
          isSemantics(
              label: 'Pin a.mp3',
              isButton: true,
              hasToggledState: true,
              isToggled: true,
              isEnabled: true));
      expect(
          tester.getSemantics(_pin(_row(SeedList.moreLike, 'b.mp3'))),
          isSemantics(
              label: 'Pin b.mp3', hasToggledState: true, isToggled: false));
      expect(find.byTooltip('b.mp3 options'), findsOneWidget);
      expect(
          tester.getSemantics(find.byKey(const ValueKey('auto-dj-seeds-mode'))),
          isSemantics(label: 'Drift or stay close'));
      expect(tester.getSemantics(_hint),
          isSemantics(label: _driftHint, isLiveRegion: true));

      // Locked in Stay close: still on, now disabled.
      await show(
          tester,
          _lists(more: [_seed('b.mp3')], frozen: true),
          mode: SonicAnchorMode.locked);
      expect(
          tester.getSemantics(_pin(_row(SeedList.moreLike, 'b.mp3'))),
          isSemantics(
              label: 'Pin b.mp3',
              hasToggledState: true,
              isToggled: true,
              hasEnabledState: true,
              isEnabled: false));
      semantics.dispose();
    });

    testWidgets('no server takes Less like songs: the reason, and only that '
        "card's inert parts dimmed, its rows' ⋮ at full strength and working",
        (tester) async {
      await show(
          tester,
          _lists(
              more: [_seed('/a.mp3')],
              less: [_seed('/x.mp3', pinned: true), _seed('y.mp3')]),
          takesNegatives: false);
      expect(_reason, findsOneWidget);
      expect(find.text('Needs a newer server'), findsOneWidget);
      expect(_opacity(tester, _reason), 1.0, reason: 'the reason reads plain');

      // No layer over the whole card: each row's art, names and pin are
      // dimmed one layer each, and so is Add song, which is off.
      expect(_opacity(tester, _card(SeedList.lessLike)), 1.0);
      final x = _row(SeedList.lessLike, '/x.mp3');
      final y = _row(SeedList.lessLike, 'y.mp3');
      for (final row in [x, y]) {
        _expectRowDim(tester, row, dim: true);
      }
      expect(_addOpacity(tester, SeedList.lessLike), closeTo(0.38, 1e-9));
      expect(_addTappable(tester, SeedList.lessLike), isFalse);
      await tester.tap(_add(SeedList.lessLike));
      expect(adds, isEmpty);

      // The pins keep their look under their dimming, and do nothing.
      expect(_pinIcon(tester, x).icon, Icons.push_pin);
      expect(_pinIcon(tester, y).icon, Icons.push_pin_outlined);
      expect(_pinTappable(tester, x), isFalse);
      expect(_pinTappable(tester, y), isFalse);
      await tester.tap(_pin(y));
      expect(pins, isEmpty);

      // More like is untouched.
      _expectRowDim(tester, _row(SeedList.moreLike, '/a.mp3'), dim: false);
      expect(_addOpacity(tester, SeedList.moreLike), 1.0);
      expect(_pinTappable(tester, _row(SeedList.moreLike, '/a.mp3')), isTrue);
      expect(_addTappable(tester, SeedList.moreLike), isTrue);

      // The ⋮ is drawn in its own colour, opens, and its items fire, so rows
      // that got in earlier can still be moved out or removed.
      expect(
          tester
              .widget<Icon>(find.descendant(
                  of: _menu(y), matching: find.byIcon(Icons.more_vert)))
              .color,
          VelvetColors.textSecondary);
      await openMenu(tester, y);
      expect(find.text('More like this'), findsOneWidget);
      expect(_item(tester, _move).enabled, isTrue);
      expect(_item(tester, _remove).enabled, isTrue);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      await openMenu(tester, x);
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(moves, [seedKey('home', 'y.mp3')]);
      expect(removes, ['lessLike ${seedKey('home', 'x.mp3')}']);

      // And nothing new goes in from More like.
      await openMenu(tester, _row(SeedList.moreLike, '/a.mp3'));
      expect(_item(tester, _move).enabled, isFalse);
      await tester.tap(_move, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(moves, [seedKey('home', 'y.mp3')]);
    });

    testWidgets('a list of eight rows all shown pinned takes no more: its Add '
        'song and the moves into it are off', (tester) async {
      final full = [for (var i = 0; i < 8; i++) _seed('/m$i.mp3', pinned: true)];
      await show(tester, _lists(more: full, less: [_seed('/x.mp3')]));
      expect(_addTappable(tester, SeedList.moreLike), isFalse);
      await tester.tap(_add(SeedList.moreLike));
      expect(adds, isEmpty);
      expect(_addOpacity(tester, SeedList.moreLike), closeTo(0.38, 1e-9),
          reason: 'the full list dims its own Add song row');
      expect(_addTappable(tester, SeedList.lessLike), isTrue);
      await openMenu(tester, _row(SeedList.lessLike, '/x.mp3'));
      expect(_item(tester, _move).enabled, isFalse);
      // Remove is always there.
      expect(_item(tester, _remove).enabled, isTrue);
      await closeMenu(tester);

      // One row the user let go of can make way, so the list takes one more.
      await show(tester,
          _lists(more: [...full.take(7), _seed('/loose.mp3')], less: [
            _seed('/x.mp3'),
          ]));
      expect(_addTappable(tester, SeedList.moreLike), isTrue);
      await openMenu(tester, _row(SeedList.lessLike, '/x.mp3'));
      expect(_item(tester, _move).enabled, isTrue);
    });

    testWidgets('Stay close: eight rows fill a list, whatever their own pins',
        (tester) async {
      await show(
          tester,
          _lists(
              more: [for (var i = 0; i < 8; i++) _seed('/m$i.mp3')],
              frozen: true),
          mode: SonicAnchorMode.locked);
      expect(_addTappable(tester, SeedList.moreLike), isFalse);
      expect(_addTappable(tester, SeedList.lessLike), isTrue);
    });

    testWidgets('Add song and the moves follow the servers each list can '
        'use; Remove always works', (tester) async {
      final seeds = _lists(more: [
        _seed('/a.mp3'),
        _seed('/b.mp3', server: 'office'),
      ], less: [
        _seed('/x.mp3'),
        _seed('/y.mp3', server: 'office'),
      ]);
      // More like can use home's songs, Less like office's.
      await show(tester, seeds,
          addServers: {
            SeedList.moreLike: {'home'},
            SeedList.lessLike: {'office'},
          });
      expect(_addTappable(tester, SeedList.moreLike), isTrue);
      expect(_addTappable(tester, SeedList.lessLike), isTrue);

      // A move goes only where the song's server is one the other list can
      // use.
      Future<void> expectMove(Finder row, {required bool enabled}) async {
        await openMenu(tester, row);
        expect(_item(tester, _move).enabled, enabled);
        expect(_item(tester, _remove).enabled, isTrue);
        await closeMenu(tester);
      }

      await expectMove(_row(SeedList.moreLike, '/a.mp3'), enabled: false);
      await expectMove(_row(SeedList.moreLike, '/b.mp3', server: 'office'),
          enabled: true);
      await expectMove(_row(SeedList.lessLike, '/x.mp3'), enabled: true);
      await expectMove(_row(SeedList.lessLike, '/y.mp3', server: 'office'),
          enabled: false);

      // A move that is off does nothing; Remove still does.
      await openMenu(tester, _row(SeedList.moreLike, '/a.mp3'));
      await tester.tap(_move, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(moves, isEmpty);
      await openMenu(tester, _row(SeedList.moreLike, '/a.mp3'));
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(removes, ['moreLike ${seedKey('home', 'a.mp3')}']);

      // A list that can use no server's songs, or isn't named at all, takes
      // no song: its Add song is off and dimmed, and no move goes into it.
      await show(tester, seeds,
          addServers: {SeedList.moreLike: {}, SeedList.lessLike: {'office'}});
      expect(_addTappable(tester, SeedList.moreLike), isFalse);
      expect(_addOpacity(tester, SeedList.moreLike), closeTo(0.38, 1e-9));
      await tester.tap(_add(SeedList.moreLike));
      expect(adds, isEmpty);
      expect(_addTappable(tester, SeedList.lessLike), isTrue);
      await expectMove(_row(SeedList.lessLike, '/x.mp3'), enabled: false);
      await show(tester, seeds, addServers: {SeedList.moreLike: {'home'}});
      expect(_addTappable(tester, SeedList.moreLike), isTrue);
      expect(_addTappable(tester, SeedList.lessLike), isFalse);
      await expectMove(_row(SeedList.moreLike, '/a.mp3'), enabled: false);
    });

    testWidgets('empty lists: only the Add song rows, and the checkbox',
        (tester) async {
      await show(tester, AutoDjSeeds.empty);
      expect(find.byKey(const ValueKey('auto-dj-seed-pin')), findsNothing);
      expect(find.text('Add song'), findsNWidgets(2));
      expect(find.text(_clearPinsLabel), findsOneWidget);
      await tester.tap(_add(SeedList.moreLike));
      expect(adds, [SeedList.moreLike]);
    });

    testWidgets('the checkbox comes last, in a card of its own; the whole '
        'row flips it', (tester) async {
      await show(tester,
          _lists(more: [_seed('/a.mp3')], less: [_seed('/x.mp3')]));
      // Under the Less like card, as wide as it, a card of its own.
      final less = tester.getRect(_card(SeedList.lessLike));
      final card = tester.getRect(_clearPinsCard);
      expect(card.top, greaterThan(less.bottom));
      expect(card.left, less.left);
      expect(card.right, less.right);
      expect(tester.widget(_clearPinsCard), isA<FedCard>());
      expect(
          find.descendant(of: _clearPinsCard, matching: _clearPins),
          findsOneWidget);
      expect(find.descendant(of: _card(SeedList.lessLike), matching: _clearPins),
          findsNothing);
      // Nothing comes after it.
      final page = tester.widget<ListView>(find.byType(ListView));
      expect((page.childrenDelegate as SliverChildListDelegate).children.last,
          same(tester.widget(_clearPinsCard)));

      expect(tester.getSize(_clearPins).height, greaterThanOrEqualTo(52));
      final label = tester.widget<Text>(find.text(_clearPinsLabel));
      expect(label.style?.fontSize, 15);
      expect(label.style?.color, VelvetColors.textPrimary);
      final box = tester.widget<Checkbox>(_clearPinsBox);
      expect(box.value, isFalse);
      expect(box.activeColor, VelvetColors.primary,
          reason: 'ticked, it is drawn in amber');
      expect(box.side, BorderSide(color: VelvetColors.textSecondary, width: 2),
          reason: 'cleared, in the outline the app gives its checkboxes');

      // The label, the far end of the row and the box itself all flip it.
      await tester.tap(find.text(_clearPinsLabel));
      final row = tester.getRect(_clearPins);
      await tester.tapAt(Offset(row.right - 8, row.center.dy));
      await tester.tap(_clearPinsBox);
      expect(clears, [true, true, true]);

      // Ticked, a tap clears it.
      await show(tester, AutoDjSeeds.empty, clearPins: true);
      expect(tester.widget<Checkbox>(_clearPinsBox).value, isTrue);
      await tester.tap(find.text(_clearPinsLabel));
      expect(clears.last, isFalse);
    });

    testWidgets('the checkbox reads as one node: its name and whether it is '
        'ticked; one keyboard stop', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, AutoDjSeeds.empty);
      expect(
          tester.getSemantics(_clearPins),
          isSemantics(
              label: _clearPinsLabel,
              hasCheckedState: true,
              isChecked: false,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true));
      // The box takes the keyboard's focus; the row around it does not as
      // well.
      final row = tester.element(_clearPins);
      final stops =
          FocusManager.instance.rootScope.traversalDescendants.where((n) {
        var inRow = false;
        n.context?.visitAncestorElements((e) => !(inRow = identical(e, row)));
        return inRow;
      });
      expect(stops, hasLength(1));
      await show(tester, AutoDjSeeds.empty, clearPins: true);
      expect(
          tester.getSemantics(_clearPins),
          isSemantics(
              label: _clearPinsLabel,
              hasCheckedState: true,
              isChecked: true,
              hasTapAction: true));
      semantics.dispose();
    });

    testWidgets('the checkbox works in Stay close and while no server takes '
        'Less like songs, never dimmed', (tester) async {
      await show(tester, _lists(less: [_seed('/x.mp3')], frozen: true),
          mode: SonicAnchorMode.locked, takesNegatives: false);
      expect(_reason, findsOneWidget);
      expect(_opacity(tester, _clearPins), 1.0);
      expect(_opacity(tester, _clearPinsBox), 1.0);
      expect(tester.widget<Checkbox>(_clearPinsBox).onChanged, isNotNull);
      await tester.tap(find.text(_clearPinsLabel));
      expect(clears, [true]);
    });

    testWidgets('a narrow phone at twice the text size: long names cut short, '
        'nothing spills', (tester) async {
      final long = 'A very long song title that runs past any phone screen';
      await show(
          tester,
          _lists(more: [
            AutoDjSeed(
                song: TrackFacts(
                    server: 'home',
                    path: '/long.mp3',
                    title: long,
                    artist: 'An artist whose name is just as long as the title'),
                origin: SeedOrigin.pick,
                addedAt: _t0),
          ], less: [
            _seed('/x.mp3', pinned: true),
          ]),
          takesNegatives: false,
          textScale: 2);
      tester.view.physicalSize = const Size(320, 1400);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The row grew with its text, the hint's two lines with theirs.
      expect(tester.getSize(_row(SeedList.moreLike, '/long.mp3')).height,
          greaterThanOrEqualTo(56));
      expect(tester.getSize(_hint).height, greaterThanOrEqualTo(2 * 34));
      // The checkbox's label wraps rather than spilling.
      await tester.scrollUntilVisible(_clearPins, 200);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_clearPins).height, greaterThan(52));
    });
  });

  group('AutoDjSeedsScreen', () {
    late _FakeHandler handler;
    final home = Server('https://home.example.com', 'u', 'p', 'JWT', 'home');
    final office =
        Server('https://office.example.com', 'u', 'p', 'JWT', 'office');
    final lab = Server('https://lab.example.com', 'u', 'p', 'JWT', 'lab');
    final far = Server('https://far.example.com', 'u', 'p', 'JWT', 'far');

    setUp(() {
      handler = _FakeHandler();
      MediaManager().audioHandler = handler;
    });

    Future<void> show(WidgetTester tester) async {
      _tall(tester);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const AutoDjSeedsScreen(),
      ));
      await tester.pumpAndSettle();
    }

    MediaItem item(String server, String path, {String? title}) => MediaItem(
          id: 'https://$server/$path',
          title: title ?? path.split('/').last,
          extras: <String, dynamic>{'server': server, 'path': path},
        );
    // The Add song sheet's own rows, not the page's under it.
    Finder inSheet(Finder f) => find.descendant(
        of: find.byType(DraggableScrollableSheet), matching: f);
    // The titles in one of the sheet's sections, top to bottom.
    List<String> section(WidgetTester tester, String name) => [
          for (var i = 0;
              find
                  .byKey(ValueKey('auto-dj-add-song-$name-$i'))
                  .evaluate()
                  .isNotEmpty;
              i++)
            tester
                .widgetList<Text>(find.descendant(
                    of: find.byKey(ValueKey('auto-dj-add-song-$name-$i')),
                    matching: find.byType(Text)))
                .first
                .data!,
        ];
    // The server the open sheet's field searches.
    Server searched(WidgetTester tester) => (tester.widget(find
            .byWidgetPredicate((w) => '${w.runtimeType}' == '_AddSongSheet'))
        as dynamic).searchServer as Server;
    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('auto-dj-add-song-close')));
      await tester.pumpAndSettle();
    }

    testWidgets("draws the handler's seeds and follows every new value",
        (tester) async {
      handler.seedsSubject.add(_lists(more: [_seed('/a.mp3')]));
      await show(tester);
      expect(_row(SeedList.moreLike, '/a.mp3'), findsOneWidget);
      expect(find.text(_driftHint), findsOneWidget);

      handler.seedsSubject
          .add(_lists(more: [_seed('/a.mp3'), _seed('/b.mp3')]));
      await tester.pumpAndSettle();
      expect(_row(SeedList.moreLike, '/b.mp3'), findsOneWidget);
    });

    testWidgets('the mode is the manager\'s and the reason the handler\'s; '
        'it redraws on the DJ\'s state', (tester) async {
      handler
        ..servers = [home]
        ..seedsSubject.add(_lists(less: [_seed('/x.mp3')]));
      await show(tester);
      expect(_reason, findsNothing);
      final x = _row(SeedList.lessLike, '/x.mp3');
      _expectRowDim(tester, x, dim: false);

      mgr.sonicAnchorMode = SonicAnchorMode.locked;
      handler.seedsTakeNegatives = false;
      handler.customState.add(null);
      await tester.pumpAndSettle();
      expect(find.text(_stayHint), findsOneWidget);
      expect(_reason, findsOneWidget);
      _expectRowDim(tester, x, dim: true);
      expect(_addOpacity(tester, SeedList.lessLike), closeTo(0.38, 1e-9));
      expect(_addTappable(tester, SeedList.lessLike), isFalse);

      // Its ⋮ still opens, and its items reach the handler.
      await tester.tap(_menu(x));
      await tester.pumpAndSettle();
      expect(_item(tester, _move).enabled, isTrue);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      await tester.tap(_menu(x));
      await tester.pumpAndSettle();
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(handler.calls, [
        'move ${seedKey('home', 'x.mp3')}',
        'remove lessLike ${seedKey('home', 'x.mp3')}',
      ]);
    });

    testWidgets('every edit goes to the handler', (tester) async {
      handler
        ..servers = [home]
        ..seedsSubject.add(_lists(more: [_seed('/a.mp3')]));
      await show(tester);
      final a = _row(SeedList.moreLike, '/a.mp3');
      final key = seedKey('home', 'a.mp3');

      await tester.tap(_pin(a));
      await tester.tap(_menu(a));
      await tester.pumpAndSettle();
      await tester.tap(_move);
      await tester.pumpAndSettle();
      await tester.tap(_menu(a));
      await tester.pumpAndSettle();
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay close'));
      await tester.pumpAndSettle();
      expect(handler.calls, [
        'pin moreLike $key true',
        'move $key',
        'remove moreLike $key',
        'mode locked',
      ]);
    });

    testWidgets("Add song offers the session's coming songs, not the list's "
        'own, and adds the one picked', (tester) async {
      handler
        ..servers = [home]
        ..seedsSubject.add(_lists(more: [_seed('/taken.mp3')]))
        ..queue.add([
          item('home', 'now.mp3'),
          item('home', 'next.mp3', title: 'Next One'),
          item('office', 'elsewhere.mp3'),
          item('home', '/taken.mp3'),
        ])
        ..playbackState.add(PlaybackState(queueIndex: 0));
      await show(tester);

      await tester.tap(_add(SeedList.moreLike));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Up next')), findsOneWidget);
      expect(inSheet(find.text('Next One')), findsOneWidget);
      expect(inSheet(find.text('now.mp3')), findsNothing,
          reason: 'the playing row is not still to come');
      expect(inSheet(find.text('elsewhere.mp3')), findsNothing,
          reason: "office isn't one of the session's servers");
      expect(inSheet(find.text('taken.mp3')), findsNothing,
          reason: 'More like has it already');

      await tester.tap(inSheet(find.text('Next One')));
      await tester.pumpAndSettle();
      expect(handler.calls, ['add moreLike home:next.mp3']);

      // A song More like holds is still on offer for Less like, which it
      // would move to; and in a session across servers each server's songs
      // are.
      handler.servers = [home, office];
      await tester.tap(_add(SeedList.lessLike));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('taken.mp3')), findsOneWidget);
      expect(inSheet(find.text('elsewhere.mp3')), findsOneWidget);
      await tester.tap(inSheet(find.text('elsewhere.mp3')));
      await tester.pumpAndSettle();
      expect(handler.calls.last, 'add lessLike office:elsewhere.mp3');
    });

    testWidgets('Add song with no server to draw from is off and opens '
        'nothing', (tester) async {
      await show(tester);
      expect(_addTappable(tester, SeedList.moreLike), isFalse);
      expect(_addTappable(tester, SeedList.lessLike), isFalse);
      await tester.tap(_add(SeedList.moreLike));
      await tester.pumpAndSettle();
      expect(find.text('Up next'), findsNothing);
      expect(find.byKey(const ValueKey('auto-dj-add-song-search')),
          findsNothing);
    });

    testWidgets("the servers each list can use are the handler's, asked at "
        'every build: Add song and the moves follow them', (tester) async {
      handler
        ..servers = [home, office]
        ..addServers[SeedList.moreLike] = [home]
        ..addServers[SeedList.lessLike] = []
        ..seedsSubject.add(_lists(
            more: [_seed('/a.mp3'), _seed('/b.mp3', server: 'office')],
            less: [_seed('/x.mp3', server: 'office')]));
      await show(tester);
      expect(_addTappable(tester, SeedList.moreLike), isTrue);
      expect(_addTappable(tester, SeedList.lessLike), isFalse,
          reason: 'Less like can use no server right now');
      Future<bool> moveEnabled(Finder row) async {
        await tester.tap(_menu(row));
        await tester.pumpAndSettle();
        final on = _item(tester, _move).enabled;
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        return on;
      }

      expect(await moveEnabled(_row(SeedList.moreLike, '/a.mp3')), isFalse);
      expect(
          await moveEnabled(_row(SeedList.lessLike, '/x.mp3', server: 'office')),
          isFalse,
          reason: "More like can't use office's songs");

      // The fan-out takes office in: the page hears of it with the DJ's
      // state, and asks again.
      handler
        ..addServers[SeedList.moreLike] = [home, office]
        ..addServers[SeedList.lessLike] = [office];
      handler.customState.add(null);
      await tester.pumpAndSettle();
      expect(_addTappable(tester, SeedList.lessLike), isTrue);
      expect(await moveEnabled(_row(SeedList.moreLike, '/a.mp3')), isFalse,
          reason: "Less like can't use home's songs");
      expect(
          await moveEnabled(_row(SeedList.moreLike, '/b.mp3', server: 'office')),
          isTrue);
      expect(
          await moveEnabled(_row(SeedList.lessLike, '/x.mp3', server: 'office')),
          isTrue);
    });

    testWidgets('Add song asks again at the tap: once the list can use no '
        'server it opens nothing and is drawn off', (tester) async {
      handler
        ..servers = [home]
        ..queue.add([item('home', 'now.mp3'), item('home', 'next.mp3')])
        ..playbackState.add(PlaybackState(queueIndex: 0));
      await show(tester);
      expect(_addTappable(tester, SeedList.lessLike), isTrue);
      // Less like can use no server any more, and the page is told nothing.
      handler.addServers[SeedList.lessLike] = [];
      await tester.tap(_add(SeedList.lessLike));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auto-dj-add-song-search')),
          findsNothing);
      // The tap drew the page again from the new answer: Add song is off
      // now, not left live while it opens nothing.
      expect(_addTappable(tester, SeedList.lessLike), isFalse);
      expect(_addOpacity(tester, SeedList.lessLike), closeTo(0.38, 1e-9));
      // More like still opens.
      await tester.tap(_add(SeedList.moreLike));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('next.mp3')), findsOneWidget);
    });

    testWidgets("a row's move asks again at the tap: once the other list "
        "can't use the row's server it moves nothing and is drawn off",
        (tester) async {
      handler
        ..servers = [home]
        ..seedsSubject
            .add(_lists(more: [_seed('/a.mp3')], less: [_seed('/x.mp3')]));
      await show(tester);
      final a = _row(SeedList.moreLike, '/a.mp3');
      final x = _row(SeedList.lessLike, '/x.mp3');
      // Opens [row]'s ⋮ and says whether its move is drawn on.
      Future<bool> openMenu(Finder row) async {
        await tester.tap(_menu(row));
        await tester.pumpAndSettle();
        return _item(tester, _move).enabled;
      }

      Future<void> closeMenu() async {
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
      }

      // Less like can no longer use home's songs, and the page is told
      // nothing: "Less like this" is still drawn on, and a tap moves nothing.
      handler.addServers[SeedList.lessLike] = [];
      expect(await openMenu(a), isTrue);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      expect(handler.calls, isEmpty);
      // The tap drew the page again from the new answers: the move is off
      // now, and so is Less like's Add song.
      expect(await openMenu(a), isFalse);
      await closeMenu();
      expect(_addTappable(tester, SeedList.lessLike), isFalse);

      // The same the other way, once More like can't use home's songs.
      handler.addServers[SeedList.moreLike] = [];
      expect(await openMenu(x), isTrue);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      expect(handler.calls, isEmpty);
      expect(await openMenu(x), isFalse);
      await closeMenu();

      // Both lists can use home's songs again, and the page hears of it.
      // Then no server takes Less like songs, unheard: a move into Less like
      // asks that again too, and the card is drawn inert.
      handler
        ..addServers.clear()
        ..customState.add(null);
      await tester.pumpAndSettle();
      handler.seedsTakeNegatives = false;
      expect(await openMenu(a), isTrue);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      expect(handler.calls, isEmpty);
      expect(_reason, findsOneWidget);
      expect(await openMenu(a), isFalse);
      await closeMenu();

      // A move the other list can still use goes through.
      expect(await openMenu(x), isTrue);
      await tester.tap(_move);
      await tester.pumpAndSettle();
      expect(handler.calls, ['move ${seedKey('home', 'x.mp3')}']);
    });

    testWidgets("Less like's Add song: Skipped opens with the song playing "
        'now, then the songs skipped lately; every section and the search '
        "only on the servers Less like can use", (tester) async {
      handler
        ..servers = [home, lab, far]
        ..addServers[SeedList.lessLike] = [lab, home]
        ..addServers[SeedList.moreLike] = [home]
        ..seedsSubject.add(_lists(less: [_seed('/in-less.mp3', server: 'lab')]))
        ..queue.add([
          item('home', 'before.mp3'),
          item('lab', '/now.mp3', title: 'Now'),
          item('home', '/next.mp3', title: 'Next'),
          item('far', '/far-next.mp3', title: 'Far next'),
        ])
        ..playbackState.add(PlaybackState(queueIndex: 1));
      await show(tester);

      await tester.tap(_add(SeedList.lessLike));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Skipped')), findsOneWidget);
      expect(section(tester, 'upnext'), ['Next'],
          reason: "far isn't a server Less like can use");
      expect(section(tester, 'skipped'), ['Now', 'New skip', 'Old skip'],
          reason: 'the song playing now, then the skips heard a second or '
              'more, newest first; not the one Less like has, nor far’s');
      expect(section(tester, 'recent'), ['Played']);
      double top(String text) => tester.getTopLeft(inSheet(find.text(text))).dy;
      expect(top('Up next'), lessThan(top('Skipped')));
      expect(top('Skipped'), lessThan(top('Recently played')));
      expect(searched(tester).localname, 'lab',
          reason: 'the first server Less like can use');

      // The playing row is in the queue now: picked as it is.
      await tester.tap(inSheet(find.text('Now')));
      await tester.pumpAndSettle();
      expect(handler.calls, ['add lessLike lab:/now.mp3']);

      // More like's sheet has no Skipped, and offers only home's songs.
      await tester.tap(_add(SeedList.moreLike));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Skipped')), findsNothing);
      expect(section(tester, 'skipped'), isEmpty);
      expect(section(tester, 'upnext'), ['Next']);
      expect(section(tester, 'recent'), isEmpty);
      expect(searched(tester).localname, 'home');
      await closeSheet(tester);
    });

    testWidgets("Skipped leaves out a playing song Less like holds, or one "
        "on a server it can't use", (tester) async {
      // Less like holds one of the skips throughout, which stays out.
      final inLess = _seed('/in-less.mp3', server: 'lab');
      handler
        ..servers = [home, lab]
        ..addServers[SeedList.lessLike] = [lab]
        ..queue.add([item('lab', '/now.mp3', title: 'Now')])
        ..playbackState.add(PlaybackState(queueIndex: 0));

      // Less like holds it, in the other path form.
      handler.seedsSubject.add(
          _lists(less: [inLess, _seed('now.mp3', server: 'lab')]));
      await show(tester);
      await tester.tap(_add(SeedList.lessLike));
      await tester.pumpAndSettle();
      expect(section(tester, 'skipped'), ['New skip', 'Old skip']);
      await closeSheet(tester);

      // More like holds it: still on offer for Less like, which it would
      // move to.
      handler.seedsSubject.add(
          _lists(more: [_seed('now.mp3', server: 'lab')], less: [inLess]));
      await tester.pumpAndSettle();
      await tester.tap(_add(SeedList.lessLike));
      await tester.pumpAndSettle();
      expect(section(tester, 'skipped'), ['Now', 'New skip', 'Old skip']);
      await closeSheet(tester);

      // A server Less like can't use: neither it nor its skips.
      handler
        ..addServers[SeedList.lessLike] = [home]
        ..seedsSubject.add(_lists(less: [inLess]));
      await tester.pumpAndSettle();
      await tester.tap(_add(SeedList.lessLike));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Skipped')), findsNothing);
      expect(section(tester, 'skipped'), isEmpty);
      await closeSheet(tester);

      // A local file playing is no seed.
      handler
        ..addServers[SeedList.lessLike] = [lab]
        ..queue.add([
          MediaItem(
              id: '/storage/song.mp3',
              title: 'Local',
              extras: <String, dynamic>{'path': '/storage/song.mp3'}),
        ]);
      await tester.tap(_add(SeedList.lessLike));
      await tester.pumpAndSettle();
      expect(section(tester, 'skipped'), ['New skip', 'Old skip']);
      await closeSheet(tester);
    });

    testWidgets("the checkbox is the manager's: drawn from it, and a tap "
        'saves it', (tester) async {
      Future<void> tapAndSave(Object value) async {
        await tester.runAsync(() async {
          await tester.tap(_clearPins);
          for (var i = 0; i < 400; i++) {
            try {
              final saved = jsonDecode(savedFile().readAsStringSync()) as Map;
              if (saved['clearPinsOnQueueClear'] == value) break;
            } catch (_) {
              // Not written yet, or caught mid-write.
            }
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await tester.pumpAndSettle();
      }

      await show(tester);
      expect(tester.widget<Checkbox>(_clearPinsBox).value, isFalse);

      await tapAndSave(true);
      expect(mgr.clearPinsOnQueueClear, isTrue);
      expect(
          (jsonDecode(savedFile().readAsStringSync())
              as Map)['clearPinsOnQueueClear'],
          isTrue);
      expect(tester.widget<Checkbox>(_clearPinsBox).value, isTrue,
          reason: "redrawn on the manager's change");

      await tapAndSave(false);
      expect(mgr.clearPinsOnQueueClear, isFalse);
      expect(tester.widget<Checkbox>(_clearPinsBox).value, isFalse);
    });
  });
}
