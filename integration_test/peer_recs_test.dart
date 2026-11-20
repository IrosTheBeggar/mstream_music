// Peer Recommendations journey (mStream docs/peer-recommendations-plan.md
// §2 items 14–18, §3.5 R1–R7; the phone build plan's piece N), on the
// device against an in-process server.
//
// A server whose ping advertises discovery, discoveryP2p, discoveryTaste 3
// and discoveryP2pPeers 1 gets a full-width Peer Recommendations card under
// Listen, on its own row after Discover. Tapping it fills the browser: ONE
// taste call with the page's own body (R1: network only, nothing pinned
// with nothing playing, the random seed walked) and one peers poll at once;
// the strip (All, the shelf's peers, then the "+" an admin may Add) over a
// 2-up grid of the leads. A tab asks once more, pinned to the batch's seeds
// with the peer as networkPeers; All again asks nothing. A card's tap opens
// the network-lead sheet and resolves nothing; a card's circle resolves
// once and plays the clip, the band reading the plug-in's attribution, and
// ✕ ends it. A page pushed over the page during a clip ends the clip and
// stops the poll; a theme set while it is up (as Settings sets one) applies
// once it pops, and the pop polls once, at once, then keeps the cadence.
// The start theme set the same way applies back. "+" posts the Add (202),
// the item reads Adding… while the polls hurry, and once the peer lands on
// the shelf the page asks again, once, pinned. Back returns to the home;
// opening the page again is a fresh visit, asking R1 again. On it, the app
// going to the background ends the sheet's clip and then the page's, with
// no framework error on the way, no poll while away and one on return.
// "No poll" is read off the poll's timer, not only from the polls counted:
// the idle cadence is 15 s, longer than any of these waits.
//
// The app is wrapped as main.dart's runApp wraps it (the theme stream, the
// root navigator and messenger keys, the route observer), not in the shared
// testApp(): without them a theme never applies and a pushed page never
// covers the page.
//
// The server's answers are the stage's (A's fixtures: the twelve leads, the
// Highway seed); the peers answer is the admin's view of the shelf with
// Lighthouse Tapes addable. The mock's GET /api/ is unmatched (404), so the
// app falls back to the ping — the flat shape the flags are read from.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/main.dart' show MStreamApp;
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/peer_recs_band.dart';
import 'package:mstream_music/screens/discovery/peer_recs_cards.dart';
import 'package:mstream_music/screens/discovery/peer_recs_listing.dart';
import 'package:mstream_music/screens/discovery/peer_recs_strip.dart';
import 'package:mstream_music/screens/discovery/peer_recs_view.dart';
import 'package:mstream_music/singletons/app_messenger.dart';
import 'package:mstream_music/singletons/app_route_observer.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';

import '../test/screens/discovery/peer_recs_fixtures.dart';
import 'helpers/test_helpers.dart';

/// The app's root as main.dart's runApp builds it: the theme, locale and
/// accent streams (a theme set in Settings applies), the root navigator and
/// messenger keys, and the route observer that tells the page a pushed
/// screen covers it. The shared testApp() has none of these.
Widget _liveApp() => StreamBuilder<(AppTheme, Locale?, int?)>(
      stream: Rx.combineLatest3(
        SettingsManager().themeStream,
        SettingsManager().localeStream,
        SettingsManager().accentColorStream,
        (AppTheme theme, Locale? locale, int? accent) =>
            (theme, locale, accent),
      ),
      initialData: (
        SettingsManager().appTheme,
        SettingsManager().localeOverride,
        SettingsManager().accentColor,
      ),
      builder: (context, snapshot) {
        final (theme, locale, accent) =
            snapshot.data ?? (AppTheme.dark, null, null);
        var palette = paletteFor(theme);
        if (accent != null) palette = palette.withAccent(Color(accent));
        VelvetColors.setActive(palette);
        return MaterialApp(
          title: 'mStream Music',
          scaffoldMessengerKey: rootMessengerKey,
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [appRouteObserver],
          home: MStreamApp(),
          theme: buildAppTheme(palette),
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          debugShowCheckedModeBanner: false,
        );
      },
    );

/// One shelf or catalogue row of the peers answer, as buildPeerView sends
/// it.
Map<String, dynamic> _row(String id, String monogram, int hue,
        {required bool online,
        required bool onShelf,
        bool pinned = false,
        int rowCount = 5,
        Map<String, dynamic>? add}) =>
    {
      'endpointId': id,
      'name': kStagePeers[id]!.name,
      'label': kStagePeers[id]!.label,
      'monogram': monogram,
      'hue': hue,
      'online': online,
      'onShelf': onShelf,
      'pinned': pinned,
      'rowCount': rowCount,
      'add': add,
    };

/// The admin's peers answer: the stage's shelf (Attic Tapes and mStream ·
/// 3f9a offline), then Lighthouse Tapes — addable until [lighthouse] says
/// otherwise: 'adding' once its Add runs, 'done' once it landed on the
/// shelf.
Map<String, dynamic> _peers(String? lighthouse) {
  final landed = lighthouse == 'done';
  final held = landed ? 5 : 4;
  return {
    'canAdd': true,
    'shelf': {'held': held, 'searchable': held, 'running': lighthouse == 'adding'},
    'peers': [
      _row(kBasement, 'BH', 210, online: true, onShelf: true, pinned: true),
      _row(kKitchen, 'KR', 25, online: true, onShelf: true, pinned: true),
      _row(kAttic, 'AT', 112, online: false, onShelf: true, rowCount: 2),
      _row(kMstream, 'mS', 140,
          online: false, onShelf: true, pinned: true, rowCount: 2),
      _row(kLighthouse, 'LT', 280,
          online: true,
          onShelf: landed,
          rowCount: 9400,
          add: lighthouse == null
              ? null
              : {
                  'state': lighthouse,
                  'code': null,
                  'at': '2026-11-19T10:00:00.000Z',
                }),
    ],
  };
}

/// What R1 sends with nothing playing (plan §3.5 R1): the network only, a
/// full batch of seeds, 32 leads, the random seed walked; no pin, no
/// networkPeers, no moods.
const Map<String, dynamic> _r1 = {
  'window': 30,
  'sources': ['network'],
  'limit': {'seeds': 12, 'network': 32},
  'newArtistsOnly': false,
  'networkOnRandomSeed': true,
};

/// A re-ask on the batch (R2/R4): pinned to its one seed, `limit.seeds` its
/// count, with the tab's peer when one is selected.
Map<String, dynamic> _pinned({String? peer}) => {
      'window': 30,
      'pin': [kSeedPath],
      'sources': ['network'],
      'limit': {'seeds': 1, 'network': 32},
      'newArtistsOnly': false,
      if (peer != null) 'networkPeers': [peer],
      'networkOnRandomSeed': true,
    };

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mockServer;

  // Every taste body, resolve body and Add body the app sent, oldest first;
  // the peers polls counted.
  final tasteBodies = <Map<String, dynamic>>[];
  final resolveBodies = <Map<String, dynamic>>[];
  final addBodies = <Map<String, dynamic>>[];
  var polls = 0;
  // Lighthouse Tapes' Add on the server: null (addable), 'adding', 'done'.
  String? lighthouse;
  var pollsWhileAdding = 0;

  // A 30 s silent clip, long enough to be on screen through the asserts.
  final clip = buildSilentWav(seconds: 30);

  Future<Map<String, dynamic>> body(HttpRequest req) async =>
      jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;

  Future<Object?> taste(HttpRequest req) async {
    final b = await body(req);
    tasteBodies.add(b);
    final peer = (b['networkPeers'] as List?)?.cast<String>().first;
    return tasteJson(leads: peer == null ? stageLeads : stageLeadsOf(peer));
  }

  Object? peers(HttpRequest req) {
    polls++;
    // The Add downloads across two polls, then lands on the shelf.
    if (lighthouse == 'adding' && ++pollsWhileAdding > 2) lighthouse = 'done';
    return _peers(lighthouse);
  }

  Future<Object?> add(HttpRequest req) async {
    final b = await body(req);
    addBodies.add(b);
    lighthouse = 'adding';
    pollsWhileAdding = 0;
    req.response.statusCode = 202;
    return {
      'endpointId': b['endpointId'],
      'state': 'adding',
      'code': null,
      'at': '2026-11-19T10:00:00.000Z',
    };
  }

  Future<Object?> resolve(HttpRequest req) async {
    final b = await body(req);
    resolveBodies.add(b);
    final rec = b['recommendation'] as Map<String, dynamic>;
    return {
      'plugin': 'deezer',
      'capabilities': ['preview'],
      'key': 'text:x',
      'recommendation': rec,
      'result': {
        'preview': {
          'provider': 'deezer',
          'url': '${mockServer!.url}/clip.wav',
          'seconds': 30,
          'title': rec['title'],
          'artist': rec['artist'],
          'album': rec['album'],
          'attribution': 'Preview from Deezer',
          'link': null,
          'artwork': null,
          'match': 1,
        },
      },
    };
  }

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(() async {
    await resetAppState();
    tasteBodies.clear();
    resolveBodies.clear();
    addBodies.clear();
    polls = 0;
    lighthouse = null;
    pollsWhileAdding = 0;
  });

  tearDown(() async {
    await mockServer?.close();
    mockServer = null;
    // The test's navigator goes without telling its observer.
    appRouteObserver.debugReset();
  });

  /// Pump frames until [done], failing after [timeout]. For the stretches
  /// pumpAndSettle cannot wait out: a clip playing, an Add's spinner.
  Future<void> pumpUntil(WidgetTester tester, bool Function() done,
      {Duration timeout = const Duration(seconds: 20),
      required String reason}) async {
    final end = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('timed out: $reason');
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pump frames for [d] of real time.
  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The app to the background (inactive, hidden, paused) for [away] and
  /// back (hidden, inactive, resumed), in the order the platform reports
  /// them. No frames run in the background, so the wait there is a plain
  /// delay; [whileAway] runs at its end, to note what the test checks once
  /// the app is back (a failed expect in the background would leave it
  /// there). Every framework error raised on the way, and in the 2 s after
  /// the return, is returned instead of reported.
  Future<List<String>> background(WidgetTester tester,
      {required void Function() whileAway}) async {
    final errors = <String>[];
    final reported = FlutterError.onError;
    FlutterError.onError =
        (d) => errors.add(d.exceptionAsString().split('\n').first);
    final b = tester.binding;
    try {
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(seconds: 3));
      whileAway();
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpFor(tester, const Duration(seconds: 2));
    } finally {
      FlutterError.onError = reported;
    }
    return errors;
  }

  PeerClipStatus? clipStatus() => PeerRecsListing().previews?.status;
  PreviewPhase enginePhase() => PreviewPlayer().state.value.phase;
  // The wait before the open visit's next poll, null while none is
  // scheduled. The polls counted in a few seconds cannot show a stopped
  // poll (its cadence is 15 s); this can.
  Duration? nextPoll() => PeerRecsListing().controller?.nextPollIn;

  Finder card(int i) => find.byKey(peerCardKey(i));
  // The card's open area, by its title (the circle sits on the tile).
  Finder openOf(int i) => find.descendant(
      of: find.descendant(of: card(i), matching: find.byKey(kPeerCardOpenKey)),
      matching: find.byType(Text)).first;
  Finder circleOf(int i) =>
      find.descendant(of: card(i), matching: find.byKey(kPeerCardPlayKey));
  Finder item(String? id) => find.byKey(ValueKey('peer-strip-${id ?? 'all'}'));
  // A home card by its label, in the browser (the player panel's Auto DJ
  // bar says "Auto DJ" too).
  Finder homeCard(String label) => find
      .ancestor(
          of: find.descendant(
              of: find.byType(Browser), matching: find.text(label)),
          matching: find.byType(Material))
      .first;

  Future<void> showHomeCard(WidgetTester tester, Finder label) async {
    if (label.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        label,
        find
            .ancestor(of: find.text('Albums'), matching: find.byType(Scrollable))
            .first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'the home Peer Recommendations card opens the page: R1, a tab, the '
    'sheet, a preview, an Add that lands, Back and a fresh visit',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/ping': (_) => {
              'vpaths': ['default'],
              'playlists': <String>[],
              'discovery': true,
              'discoveryP2p': true,
              'discoveryTaste': 3,
              'discoveryP2pPeers': 1,
              'discoveryPath': true,
              'discoveryPlugins': true,
              'stats': 2,
            },
        '/api/v1/discovery/taste': taste,
        '/api/v1/discovery/p2p/peers': peers,
        '/api/v1/admin/discovery/p2p/peer-dbs/add': add,
        '/api/v1/discovery/plugins': (_) => {
              'plugins': [
                {
                  'name': 'deezer',
                  'title': 'Preview on Deezer',
                  'capabilities': ['preview'],
                  'scopes': ['song'],
                  'available': true,
                },
              ],
              'jobs': {'allowed': false},
            },
        '/api/v1/discovery/plugins/deezer/resolve': resolve,
        '/api/v1/discovery/collection/destination': (_) => {
              'destination': {
                'vpath': 'default',
                'base': '',
                'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
                'source': 'default',
              },
              'saved': null,
              'libraries': [
                {'vpath': 'default', 'template': null},
              ],
              'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
              'variables': ['ARTIST', 'ALBUM', 'YEAR', 'ALBUMARTIST'],
            },
        '/api/v1/discovery/plugin-jobs': (_) => {
              'jobs': <Object>[],
              'runner': {'running': 0, 'active': true},
            },
        '/clip.wav': (_) => clip,
      });

      await seedServer(mockServer!.url);

      await tester.pumpWidget(_liveApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));
      // The theme the app starts in, put back however the test ends.
      final theme0 = SettingsManager().appTheme;
      addTearDown(() => SettingsManager().setAppTheme(theme0));

      // A fresh install shows the one-time welcome screen over the home.
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // ── the home: Auto DJ | Sonic path, then Discover, then Peer
      // Recommendations, each of the two on a row of its own.
      final label = find.text('Peer Recommendations');
      await showHomeCard(tester, label);
      expect(label, findsOneWidget);
      final dj = tester.getRect(homeCard('Auto DJ'));
      final path = tester.getRect(homeCard('Sonic path'));
      final discover = tester.getRect(homeCard('Discover'));
      final peer = tester.getRect(homeCard('Peer Recommendations'));
      expect(path.top, dj.top, reason: 'Auto DJ and Sonic path pair up');
      for (final wide in [discover, peer]) {
        expect(wide.left, moreOrLessEquals(dj.left));
        expect(wide.right, moreOrLessEquals(path.right),
            reason: 'full width: both pair cards and the gap');
      }
      expect(peer.top, greaterThan(discover.bottom),
          reason: 'Peer Recommendations under Discover, on its own row');
      expect(tasteBodies, isEmpty, reason: 'the home never fetches taste');
      expect(polls, 0, reason: 'nor the peers');
      // The window is Discover's, remembered on the phone: start from the
      // default.
      await SettingsManager().setDiscoverWindow(30);

      // ── open: exactly R1, and one poll at once.
      await tester.tap(label);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tasteBodies, [_r1], reason: 'R1, nothing playing: no pin');
      expect(polls, 1);
      // (The player panel's Auto DJ bar keeps its own "Auto DJ": the home's
      // Sonic path card stands for the home.)
      expect(find.text('Sonic path', skipOffstage: false), findsNothing,
          reason: 'in the browser, in place of the home');
      expect(find.text('Peer Recommendations'), findsOneWidget,
          reason: 'the toolbar names the page');
      expect(find.text('More options'), findsOneWidget, reason: 'the bar');
      expect(find.byType(PeerStripView), findsOneWidget);
      for (final id in [null, kBasement, kKitchen, kAttic, kMstream]) {
        expect(item(id), findsOneWidget, reason: 'strip item $id');
      }
      expect(card(11), findsOneWidget, reason: 'all twelve leads');
      expect(card(12), findsNothing);
      expect(find.text('Salt Road'), findsOneWidget, reason: 'rank order');
      expect(find.byType(PeerRecsBand), findsNothing, reason: 'no clip yet');
      expect(tester.takeException(), isNull);

      // ── a tab (R2): one call pinned to the batch's seed, with its peer;
      // its five leads.
      await tester.tap(item(kKitchen));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tasteBodies, hasLength(2));
      expect(tasteBodies.last, _pinned(peer: kKitchen));
      expect(card(4), findsOneWidget);
      expect(card(5), findsNothing, reason: "Kitchen Radio's five");
      expect(find.text('Salt Road'), findsNothing, reason: "Basement's");
      expect(find.text('Signal Fires'), findsOneWidget);
      // All again: its answer is kept, nothing is asked.
      await tester.tap(item(null));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tasteBodies, hasLength(2), reason: 'All: no call');
      expect(card(11), findsOneWidget);

      // ── a card's tap: the network-lead sheet, nothing resolved.
      const signal = 2; // Signal Fires, Kitchen Radio's, 92% to Highway.
      await tester.ensureVisible(card(signal));
      await tester.pumpAndSettle();
      await tester.tap(openOf(signal));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('From the network · Kitchen Radio'), findsOneWidget);
      expect(find.text('92% match to “Highway”'), findsOneWidget);
      expect(resolveBodies, isEmpty, reason: 'opening resolves nothing');
      expect(find.byType(PeerRecsBand), findsNothing, reason: 'nothing plays');
      // Closed on the barrier above it.
      await tester.tapAt(const Offset(210, 150));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('From the network · Kitchen Radio'), findsNothing);
      expect(tasteBodies, hasLength(2), reason: 'the list was held, no ask');

      // ── its circle: one resolve, the clip plays, the band attributes it.
      await tester.ensureVisible(card(signal));
      await tester.pumpAndSettle();
      await tester.tap(circleOf(signal));
      await pumpUntil(
          tester, () => find.text('Preview from Deezer').evaluate().isNotEmpty,
          reason: 'the band shows the attribution once the clip resolved');
      expect(resolveBodies, hasLength(1));
      final rec = resolveBodies.single['recommendation'] as Map;
      expect([rec['title'], rec['artist']], ['Signal Fires', 'Paper Lantern']);
      expect(find.byType(PeerRecsBand), findsOneWidget);
      expect(find.byKey(kPeerBandCloseKey), findsOneWidget);
      // ✕: the band goes.
      await tester.tap(find.byKey(kPeerBandCloseKey));
      await pumpUntil(
          tester, () => find.byType(PeerRecsBand).evaluate().isEmpty,
          reason: '✕ ends the clip');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(resolveBodies, hasLength(1));

      // The sheet again reads the shared answer: no second resolve.
      await tester.tap(openOf(signal));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('From the network · Kitchen Radio'), findsOneWidget);
      expect(resolveBodies, hasLength(1), reason: 'the answer is shared');
      await tester.tapAt(const Offset(210, 150));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ── a page pushed over the page during a clip (as Settings or a
      // drawer screen is): the app's route observer counts it, so the clip
      // ends and the poll stops. A theme set while it is up applies once it
      // pops, and the pop polls once, at once. Pumped by the clock, not
      // settled: a clip that kept playing would never settle.
      final flip = theme0 == AppTheme.light ? AppTheme.dark : AppTheme.light;
      expect(paletteFor(flip).textPrimary,
          isNot(paletteFor(theme0).textPrimary),
          reason: 'the two themes ink a title differently');
      // A card the clip is not on, so its title is in the theme's ink:
      // Harbor Lights, beside Signal Fires on the row ensureVisible keeps on
      // screen, whatever the screen's height.
      Color? harborInk() => tester
          .widget<Text>(find
              .descendant(
                  of: find.byKey(peerCardKey(3), skipOffstage: false),
                  matching: find.text('Harbor Lights', skipOffstage: false))
              .first)
          .style
          ?.color;
      expect(harborInk(), paletteFor(theme0).textPrimary);
      final nav = Navigator.of(tester.element(find.byType(PeerRecsView)));
      void pushPage() => unawaited(nav.push(MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('A page over it'))))));
      await tester.tap(circleOf(signal));
      await pumpUntil(tester, () => clipStatus() == PeerClipStatus.playing,
          reason: 'the circle plays its clip again');
      expect(resolveBodies, hasLength(1), reason: 'from the shared answer');
      await pumpUntil(tester, () => nextPoll() != null,
          timeout: const Duration(seconds: 5),
          reason: 'a poll is scheduled before the cover');
      expect(nextPoll(), kPeerPoll);
      final pollsAtCover = polls;
      pushPage();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('A page over it'), findsOneWidget);
      expect(appRouteObserver.pageRouteOverHome.value, isTrue,
          reason: "main.dart's route observer counts the pushed page");
      expect(nextPoll(), isNull, reason: 'the cover stops the poll');
      await pumpUntil(
          tester,
          () =>
              clipStatus() == PeerClipStatus.idle &&
              enginePhase() == PreviewPhase.idle,
          timeout: const Duration(seconds: 5),
          reason: 'a page over the page ends its clip');
      await pumpFor(tester, const Duration(seconds: 2));
      expect(polls, pollsAtCover, reason: 'no poll while it is covered');
      expect(nextPoll(), isNull, reason: 'none scheduled either');
      await SettingsManager().setAppTheme(flip);
      await pumpFor(tester, const Duration(milliseconds: 500));
      nav.pop();
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('A page over it'), findsNothing);
      expect(appRouteObserver.pageRouteOverHome.value, isFalse);
      expect(polls, pollsAtCover + 1, reason: 'one poll at once on return');
      await pumpUntil(tester, () => nextPoll() != null,
          timeout: const Duration(seconds: 5),
          reason: 'the poll keeps its cadence after the return');
      expect(nextPoll(), kPeerPoll);
      expect(clipStatus(), PeerClipStatus.idle, reason: 'nothing resumes');
      expect(find.byType(PeerRecsBand), findsNothing);
      expect(harborInk(), paletteFor(flip).textPrimary,
          reason: 'the theme set while covered applies');
      // The start theme back the same way, with nothing playing: the ink
      // follows it back.
      final pollsAtRestore = polls;
      pushPage();
      await pumpFor(tester, const Duration(seconds: 1));
      expect(nextPoll(), isNull, reason: 'the cover stops the poll');
      await SettingsManager().setAppTheme(theme0);
      await pumpFor(tester, const Duration(milliseconds: 500));
      nav.pop();
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('A page over it'), findsNothing);
      expect(polls, pollsAtRestore + 1, reason: 'one poll at once on return');
      expect(harborInk(), paletteFor(theme0).textPrimary,
          reason: 'the theme set while covered applies, back again');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      // ── "+ Lighthouse Tapes": the Add (202), Adding… while the polls
      // hurry, then it lands and the page asks once more, pinned. The page
      // back at its top first, where the strip is (jumped, not dragged: a
      // pull past the top would ask New seeds).
      tester
          .state<ScrollableState>(find
              .descendant(
                  of: find.byKey(const ValueKey('peer-recs-scroll')),
                  matching: find.byType(Scrollable))
              .first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final strip = find
          .descendant(
              of: find.byType(PeerStripView), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(item(kLighthouse), 60, scrollable: strip);
      await tester.pumpAndSettle();
      final asked = tasteBodies.length;
      await tester.tap(item(kLighthouse));
      await pumpUntil(tester, () => addBodies.isNotEmpty,
          reason: 'the Add is posted');
      expect(addBodies.single, {'endpointId': kLighthouse});
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.descendant(
              of: item(kLighthouse), matching: find.text('Adding…')),
          findsOneWidget);
      final pollsAtAdd = polls;
      await pumpUntil(tester, () => tasteBodies.length > asked,
          timeout: const Duration(seconds: 30),
          reason: 'the Add lands and the page asks again');
      expect(polls - pollsAtAdd, inInclusiveRange(3, 4),
          reason: 'polled every 3 s while adding, until it landed');
      expect(tasteBodies.last, _pinned(), reason: 'one pinned re-ask on All');
      await pumpFor(tester, const Duration(seconds: 4));
      expect(tasteBodies, hasLength(asked + 1), reason: 'only one');
      expect(find.text('Adding…'), findsNothing);
      expect(find.text('Lighthouse Tapes', skipOffstage: false), findsOneWidget,
          reason: 'a shelf peer now');
      expect(tester.takeException(), isNull);

      // ── Back returns to the home.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(PeerStripView), findsNothing);
      expect(find.text('Sonic path', skipOffstage: false), findsOneWidget);

      // ── and opening it again is a fresh visit: R1 again, a poll at once.
      final pollsAtBack = polls;
      final askedAtBack = tasteBodies.length;
      await showHomeCard(tester, label);
      await tester.tap(label);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tasteBodies, hasLength(askedAtBack + 1),
          reason: 'no earlier answer reused');
      expect(tasteBodies.last, _r1);
      expect(polls, pollsAtBack + 1);
      expect(item(kLighthouse), findsOneWidget);
      expect(card(11), findsOneWidget);

      // ── the sheet's clip and the app to the background: no page clip is
      // live, so the engine ends the clip itself, with no framework error;
      // no poll while away, one at once on return. This step guards the
      // device engine's own path. It passed on the old engine too, so it
      // does not show W1 is gone there; the host tests in
      // test/media/preview_player_test.dart ("the app port's lifecycle
      // watch") cover a listener disposed inside the binding's dispatch.
      await tester.ensureVisible(card(signal));
      await tester.pumpAndSettle();
      await tester.tap(openOf(signal));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('From the network · Kitchen Radio'), findsOneWidget);
      final sheetRow = find.byKey(const ValueKey('lead-preview-deezer'));
      await tester.ensureVisible(sheetRow);
      await tester.pumpAndSettle();
      await tester.tap(sheetRow);
      await pumpUntil(tester, () => enginePhase() == PreviewPhase.playing,
          reason: "the sheet's row plays its clip");
      expect(clipStatus(), PeerClipStatus.idle,
          reason: "the sheet's clip, not the page's");
      await pumpUntil(tester, () => nextPoll() != null,
          timeout: const Duration(seconds: 5),
          reason: 'a poll is scheduled, the sheet up (it is not a cover)');
      var pollsAtAway = polls;
      PreviewPhase? phaseAway;
      PeerClipStatus? statusAway;
      var pollsAway = -1;
      Duration? nextAway = Duration.zero;
      var errors = await background(tester, whileAway: () {
        phaseAway = enginePhase();
        pollsAway = polls - pollsAtAway;
        nextAway = nextPoll();
      });
      // The errors are checked first, so an error's text is not lost behind
      // a later mismatch it caused.
      expect(errors, isEmpty,
          reason: 'the background raises no framework error (sheet clip)');
      expect(phaseAway, PreviewPhase.idle,
          reason: 'the background ends the sheet clip');
      expect(nextAway, isNull, reason: 'the background stops the poll');
      expect(pollsAway, 0, reason: 'no poll in the background');
      expect(polls, pollsAtAway + 1, reason: 'one poll at once on return');
      expect(nextPoll(), kPeerPoll, reason: 'and its cadence again');
      expect(enginePhase(), PreviewPhase.idle, reason: 'nothing resumes');
      await tester.tapAt(const Offset(210, 150));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('From the network · Kitchen Radio'), findsNothing);

      // ── a page clip and the app to the background (plan §2 item 14): the
      // clip ends, no poll while away, one at once on return, and no
      // framework error on the way (the page ends its clip while the binding
      // is still telling its observers, the engine's own listener among
      // them).
      await tester.tap(circleOf(signal));
      await pumpUntil(
          tester, () => find.text('Preview from Deezer').evaluate().isNotEmpty,
          reason: 'the band shows the clip');
      await pumpUntil(tester, () => clipStatus() == PeerClipStatus.playing,
          reason: 'the circle plays its clip');
      await pumpUntil(tester, () => nextPoll() != null,
          timeout: const Duration(seconds: 5),
          reason: 'a poll is scheduled before the background');
      pollsAtAway = polls;
      pollsAway = -1;
      nextAway = Duration.zero;
      errors = await background(tester, whileAway: () {
        statusAway = clipStatus();
        phaseAway = enginePhase();
        pollsAway = polls - pollsAtAway;
        nextAway = nextPoll();
      });
      expect(errors, isEmpty,
          reason: 'the background raises no framework error (page clip)');
      expect(statusAway, PeerClipStatus.idle,
          reason: 'the background ends the page clip');
      expect(phaseAway, PreviewPhase.idle);
      expect(nextAway, isNull, reason: 'the background stops the poll');
      expect(pollsAway, 0, reason: 'no poll in the background');
      expect(polls, pollsAtAway + 1, reason: 'one poll at once on return');
      expect(nextPoll(), kPeerPoll, reason: 'and its cadence again');
      expect(clipStatus(), PeerClipStatus.idle, reason: 'nothing resumes');
      expect(find.byType(PeerRecsBand), findsNothing);
      expect(tester.takeException(), isNull);

      // Leave, so no poll outlives the test.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await SettingsManager().setDiscoverWindow(30);
    },
  );
}
