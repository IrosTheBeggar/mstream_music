// The configuration bar's thin line on the Peer Recommendations page, drawn
// by the real Browser and toolbar (mStream docs/peer-recommendations-plan.md
// §4.2: Discover's bar over the page's controller). Every ask that starts a
// new batch lets go of the batch at once while the old answer stays on
// screen, so the line must follow the answer on screen, not the seeds: the
// toolbar's New seeds, a window pick, the seeds sheet's Use these N, "Nothing
// new"'s New seeds and Check again after a refusal each show it over the old
// rows until the answer lands. The first ask has no rows yet and shows none.
//
// The page's routes are FakePeerRecs (every taste call held until the test
// answers it); the server has no plug-ins, so no clip is ever asked.

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/discovery_seeds_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_widgets.dart';
import 'package:mstream_music/screens/discovery/peer_recs_cards.dart';
import 'package:mstream_music/screens/discovery/peer_recs_controller.dart';
import 'package:mstream_music/screens/discovery/peer_recs_listing.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';
import 'package:rxdart/rxdart.dart';

import '../../media/preview_fakes.dart';
import 'peer_recs_fakes.dart';
import 'peer_recs_fixtures.dart';

/// The player with nothing playing (the browser's home reads it).
class _NothingPlaying implements AudioPlayerHandler {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A batch of three history seeds, so the seeds sheet reads "Use these 3".
final List<Map<String, dynamic>> _threeSeeds = [
  seedJson('h1', 'music/S/0.flac', 'Zero'),
  seedJson('h2', 'music/S/1.flac', 'One'),
  seedJson('h3', 'music/S/2.flac', 'Two'),
];

DiscoveryFetchResult<TasteResponse> _leads() =>
    tasteOk(tasteJson(seeds: _threeSeeds, leads: stageLeads));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Server s;
  late FakePeerRecs f;

  setUp(() {
    FakePreviewPlayer.install();
    MediaManager().audioHandler = _NothingPlaying();
    s = peerRecsServer();
    ServerManager().serverList
      ..clear()
      ..add(s);
    ServerManager().currentServer = s;
    BrowserManager().goToNavScreen();
    f = FakePeerRecs(server: s)
      ..peersAuto = (() => peersOk(peersMemberJson))
      ..repingPeerRecs = true;
  });

  tearDown(() {
    // Off the stack, so the visit lets go of its controller.
    while (BrowserManager().browserCache.length > 1) {
      BrowserManager().popBrowser();
    }
    BrowserManager().goToNavScreen();
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  });

  /// Fixed pumps, never pumpAndSettle: the line animates for as long as it
  /// shows.
  Future<void> frames(WidgetTester t,
      [Duration d = const Duration(milliseconds: 400)]) async {
    await t.pump();
    await t.pump(d);
  }

  /// The real Browser with the toolbar, and the page opened over the home
  /// with every taste call held.
  Future<PeerRecsController> pumpPage(WidgetTester t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: const Scaffold(appBar: BrowserToolbar(), body: Browser()),
    ));
    await t.pump();
    final c = f.makeController();
    PeerRecsListing().open(s, controller: c);
    await frames(t);
    return c;
  }

  final line = find.descendant(
      of: find.byType(DiscoveryConfigBar),
      matching: find.byType(LinearProgressIndicator));
  final grid = find.byType(PeerLeadGrid);
  final newSeeds = find.byKey(const ValueKey('discovery-new-seeds'));

  /// Answer the held call, and the page draws it.
  Future<void> answer(
      WidgetTester t, DiscoveryFetchResult<TasteResponse> r) async {
    f.answerTaste(r);
    await frames(t);
  }

  /// A page ready with leads, the line gone.
  Future<PeerRecsController> ready(WidgetTester t) async {
    final c = await pumpPage(t);
    expect(c.state, PeerRecsState.loading);
    expect(line, findsNothing, reason: 'the first ask: no rows, no line');
    await answer(t, _leads());
    expect(c.state, PeerRecsState.ready);
    expect(grid, findsOneWidget);
    expect(line, findsNothing);
    return c;
  }

  /// An ask is out over the rows on screen: the line shows, the old grid
  /// stays; once it answers, the line goes.
  Future<void> lineUntilAnswered(
      WidgetTester t, PeerRecsController c, String name) async {
    expect(c.loading, isTrue, reason: name);
    expect(c.seeded, isNull, reason: '$name: a new batch, no seeds yet');
    expect(line, findsOneWidget, reason: '$name: a call is out');
    expect(grid, findsOneWidget, reason: '$name: the old rows stay up');
    await answer(t, _leads());
    expect(c.loading, isFalse, reason: name);
    expect(line, findsNothing, reason: '$name: answered');
    expect(t.takeException(), isNull, reason: name);
  }

  testWidgets("the toolbar's New seeds shows the line over the rows",
      (t) async {
    final c = await ready(t);
    await t.tap(newSeeds);
    await frames(t);
    expect(f.requests, hasLength(2));
    await lineUntilAnswered(t, c, 'New seeds');
  });

  testWidgets('a window pick shows the line over the rows', (t) async {
    final c = await ready(t);
    await t.tap(find.byKey(const ValueKey('discovery-window')));
    await frames(t);
    await t.tap(find.widgetWithText(CheckedPopupMenuItem<int>, '7 days'));
    await frames(t);
    expect(f.bodies.last['window'], 7);
    await lineUntilAnswered(t, c, 'the window');
    expect(c.window, 7);
  });

  testWidgets("the seeds sheet's Use these N shows the line over the rows",
      (t) async {
    final c = await ready(t);
    await t.tap(find.byKey(const ValueKey('discovery-more-options')));
    await frames(t);
    expect(find.byType(DiscoverySeedsSheet), findsOneWidget);
    await t.tap(find.text('Use these 3'));
    await frames(t);
    expect(find.byType(DiscoverySeedsSheet), findsNothing);
    expect(f.requests, hasLength(2));
    await lineUntilAnswered(t, c, 'Use these N');
  });

  testWidgets('"Nothing new"\'s New seeds shows the line; a second tap while '
      'it is out asks nothing', (t) async {
    final c = await pumpPage(t);
    await answer(t, tasteOk(tasteJson(leads: const [])));
    expect(c.state, PeerRecsState.nothingNew);
    final pill = find.descendant(
        of: find.byType(PeerRecsStateView), matching: find.text('New seeds'));
    expect(pill, findsOneWidget);

    await t.tap(pill);
    await frames(t);
    expect(f.requests, hasLength(2));
    expect(c.state, PeerRecsState.nothingNew, reason: 'the card stays up');
    expect(line, findsOneWidget, reason: 'the tap shows it is asking');
    await t.tap(pill);
    await frames(t);
    expect(f.requests, hasLength(2), reason: 'the same ask, not sent twice');

    await answer(t, _leads());
    expect(c.state, PeerRecsState.ready);
    expect(line, findsNothing);
  });

  testWidgets('Check again after a refusal over the rows shows the line',
      (t) async {
    final c = await ready(t);
    await t.tap(newSeeds);
    await frames(t);
    await answer(t, tasteRefused);
    expect(c.disabled, isTrue);
    expect(c.state, PeerRecsState.scanPending);
    expect(line, findsNothing, reason: 'the latch: no call out');

    await t.tap(find.text('Check again'));
    await frames(t);
    expect(c.disabled, isFalse);
    expect(f.requests, hasLength(3));
    expect(c.state, PeerRecsState.ready, reason: 'the old rows come back');
    await lineUntilAnswered(t, c, 'Check again');
  });
}
