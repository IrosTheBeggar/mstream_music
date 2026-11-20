// PeerRecsView (lib/screens/discovery/peer_recs_view.dart; mStream
// docs/peer-recommendations-plan.md §2 items 14–15, §4.2 "Drawing"; the
// phone boards Main, States and Variants; the phone build plan's piece L)
// drawn by the real Browser (and toolbar): the configuration bar, the peer
// strip, the 2-up grid and its footer or a state, the band docked as the
// browser body's last child; a card's tap (#237's lead sheet with the
// visit's answers, or the copy), its circle (one resolve, the band), the
// shared answers muting a circle, the plug-in-less variant; Copy list and
// every toast floating over the band, live, in the real overlay; pull to
// refresh; sizes, text scales and themes; a pushed page route as a cover,
// straight over the home or over a sheet; R7 held under the seeds sheet;
// and the scroll offset kept under a frame pushed over the page, the strip
// drawn again at All, and no other scrollable in the page sharing that
// offset's page-storage entry.
//
// The page's routes are FakePeerRecs, the plug-in routes FakePluginServer
// (CopiesHub().makeJobs), the engine FakePreviewPlayer, and the lead sheet
// a stub of DiscoveryKeepRoutes.openPeerLead.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/discovery_seeds_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_widgets.dart';
import 'package:mstream_music/screens/discovery/elsewhere_sheet.dart'
    show elsewhereLaunch;
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/screens/discovery/peer_recs_band.dart';
import 'package:mstream_music/screens/discovery/peer_recs_cards.dart';
import 'package:mstream_music/screens/discovery/peer_recs_controller.dart';
import 'package:mstream_music/screens/discovery/peer_recs_listing.dart';
import 'package:mstream_music/screens/discovery/peer_recs_strip.dart';
import 'package:mstream_music/screens/discovery/peer_recs_view.dart';
import 'package:mstream_music/screens/discovery/preview_answers.dart';
import 'package:mstream_music/singletons/app_messenger.dart';
import 'package:mstream_music/singletons/app_route_observer.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';
import 'package:mstream_music/widgets/mood_filter_sheet.dart';
import 'package:mstream_music/widgets/player_panel.dart';
import 'package:rxdart/rxdart.dart';

import '../../media/preview_fakes.dart';
import '../discovery_plugin_fakes.dart';
import 'peer_recs_fakes.dart';
import 'peer_recs_fixtures.dart';

/// The stage's answers: All's twelve leads, or a tab's own.
DiscoveryFetchResult<TasteResponse> stage(TasteRequest r) {
  final p = (r.toJson()['networkPeers'] as List?)?.cast<String>().first;
  return tasteOk(tasteJson(leads: p == null ? stageLeads : stageLeadsOf(p)));
}

/// A deezer resolve's clip as the server answers it (wire map).
Map<String, dynamic> deezerWire() => {
      'provider': 'deezer',
      'url': 'https://cdns-preview.dzcdn.example/signal-fires.mp3',
      'seconds': 30,
      'title': 'Signal Fires',
      'artist': 'Paper Lantern',
      'album': 'Night Ferry',
      'attribution': 'Preview from Deezer',
      'link': 'https://www.deezer.com/track/3',
      'artwork': 'https://e-cdns-images.dzcdn.example/cover/250x250.jpg',
      'match': 1,
    };

/// Nothing playing: what the home's rows read once R7 draws the home again.
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

/// One stubbed lead sheet: what it was opened with, and how many page ends
/// the engine had seen by then.
typedef _Opened = ({
  DiscoveryJobsController jobs,
  DiscoveryLead lead,
  String? seedTitle,
  LeadPreviewAnswers? answers,
  List<PreviewEnd> endsAtOpen,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/nonexistent-peer-recs-view-dir');
  });

  late FakePeerRecs f;
  late Server server;
  late FakePreviewPlayer engine;
  late FakePluginServer plugins;
  late FakeTimers jobTimers;
  late List<String> toasts;
  late List<double> lifts;
  late List<_Opened> opened;
  // Each stubbed sheet's close, made in the test's own zone.
  late List<Completer<void>> sheets;
  String? clipboard;

  setUp(() {
    ServerManager().serverList.clear();
    f = FakePeerRecs();
    server = f.server..discoveryPluginsAvailable = true;
    f.auto = stage;
    f.peersAuto = () => peersOk(peersMemberJson);
    ServerManager().serverList.add(server);
    ServerManager().currentServer = server;
    BrowserManager().goToNavScreen();
    engine = FakePreviewPlayer.install();
    plugins = FakePluginServer()..listLeadPlugins(youtube: false);
    plugins.previews['deezer'] = deezerWire();
    jobTimers = FakeTimers();
    CopiesHub().makeJobs = (s) => DiscoveryJobsController(
        server: s,
        api: plugins.api(s),
        timer: jobTimers.call,
        watchLifecycle: false);
    toasts = [];
    lifts = [];
    KeepToast.debugSink = (m, {success = false}) {
      toasts.add(m);
      lifts.add(KeepToast.dockLift.value);
    };
    opened = [];
    sheets = [];
    DiscoveryKeepRoutes.openPeerLead =
        (context, jobs, lead, {seedTitle, answers}) {
      opened.add((
        jobs: jobs,
        lead: lead,
        seedTitle: seedTitle,
        answers: answers,
        endsAtOpen: List.of(engine.ends),
      ));
      final closed = Completer<void>();
      sheets.add(closed);
      return closed.future;
    };
    clipboard = null;
    nowPlayingExpanded.value = false;
    appDrawerOpen.value = false;
    appRouteObserver.debugReset();
    KeepToast.dockLift.value = 0;
  });

  tearDown(() async {
    KeepToast.debugSink = null;
    KeepToast.dismiss();
    KeepToast.dockLift.value = 0;
    DiscoveryKeepRoutes.reset();
    BrowserManager().goToNavScreen();
    await settle();
    CopiesHub().reset();
    nowPlayingExpanded.value = false;
    appDrawerOpen.value = false;
    appRouteObserver.debugReset();
    ServerManager().currentServer = null;
    ServerManager().serverList.clear();
  });

  /// The Discover listing test's pumpBrowser (a closure there, so copied):
  /// the real Browser under a Scaffold, with the toolbar when [toolbar];
  /// then the page opened over the home. [observe] puts the app's route
  /// observer on the navigator, as main.dart does. [app] lays the browser
  /// out as main.dart does too: the app's root navigator key (a toast with
  /// no context finds its overlay), and the browser body ending at the mini
  /// player's top.
  Future<PeerRecsController> pumpBrowser(
    WidgetTester tester, {
    bool toolbar = false,
    bool observe = false,
    bool app = false,
    double width = 390,
    double height = 844,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final c = f.makeController();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: app ? rootNavigatorKey : null,
      navigatorObservers: observe ? [appRouteObserver] : const [],
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
          appBar: toolbar ? const BrowserToolbar() : null,
          body: app
              ? Builder(
                  builder: (context) => Padding(
                        padding: EdgeInsets.only(
                            bottom: PlayerPanel.kCollapsedHeight +
                                MediaQuery.viewPaddingOf(context).bottom),
                        child: const Browser(),
                      ))
              : const Browser()),
    ));
    PeerRecsListing().open(server, controller: c);
    await tester.pumpAndSettle();
    return c;
  }

  Finder card(int i) => find.byKey(peerCardKey(i));
  Finder openOf(int i) =>
      find.descendant(of: card(i), matching: find.byKey(kPeerCardOpenKey));
  Finder circleOf(int i) =>
      find.descendant(of: card(i), matching: find.byKey(kPeerCardPlayKey));
  int indexOf(PeerRecsController c, String title) =>
      c.leads.indexWhere((l) => l.title == title);

  /// Press [title]'s circle and let the clip come. Its card is brought to
  /// the middle of the list first, so its row stays in view.
  Future<void> play(
      WidgetTester tester, PeerRecsController c, String title) async {
    final i = indexOf(c, title);
    await Scrollable.ensureVisible(tester.element(card(i)), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(circleOf(i));
    await tester.pumpAndSettle();
  }

  group('layout', () {
    testWidgets(
        '390×844: bar, strip, 2-up grid of 175, footer; the toolbar shows '
        'back, title, New seeds and no Filters', (tester) async {
      server.moodFiltersAvailable = true;
      final c = await pumpBrowser(tester, toolbar: true);
      expect(c.state, PeerRecsState.ready);
      expect(find.byType(PeerRecsView), findsOneWidget);

      final bar = tester.getRect(find.byType(DiscoveryConfigBar));
      final strip = tester.getRect(find.byType(PeerStripView));
      expect(bar.width, 390);
      expect(strip.top, bar.bottom, reason: 'the strip under the bar');
      expect(strip.width, 390);

      final first = tester.getRect(card(0));
      final second = tester.getRect(card(1));
      final third = tester.getRect(card(2));
      expect(first.width, 175);
      expect(first.left, 14);
      expect(second.left, first.right + 12, reason: 'two columns, 12 apart');
      expect(second.top, first.top);
      expect(third.left, 14);
      expect(third.top, greaterThan(first.bottom), reason: 'rows of two');
      expect(first.top, strip.bottom, reason: 'the grid under the strip');

      await tester.scrollUntilVisible(find.byKey(kPeerCopyListKey), 200,
          scrollable: find.descendant(
              of: find.byKey(const ValueKey('peer-recs-scroll')),
              matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      expect(find.byKey(kPeerPreviewAllKey), findsOneWidget);
      expect(find.byKey(kPeerCopyListKey), findsOneWidget);
      final last = tester.getRect(card(11));
      final foot = tester.getRect(find.byKey(kPeerCopyListKey));
      expect(foot.top, greaterThan(last.bottom), reason: 'the footer last');

      // The toolbar (BrowserToolbar's page branch).
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Peer Recommendations'), findsOneWidget);
      expect(find.byKey(const ValueKey('discovery-new-seeds')), findsOneWidget);
      expect(find.byType(MoodFilterButton), findsNothing,
          reason: 'the page never sends moods');
      expect(find.byIcon(Icons.search), findsNothing);
      expect(find.byType(PeerRecsBand), findsNothing, reason: 'no clip yet');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        "the band is the browser body's last child, flush with its bottom; "
        'the list ends above it', (tester) async {
      final c = await pumpBrowser(tester);
      await play(tester, c, 'Signal Fires');
      expect(find.byType(PeerRecsBand), findsOneWidget);
      final band = tester.getRect(find.byType(PeerRecsBand));
      final body = tester.getRect(find.byType(Browser));
      final list = tester.getRect(find.byKey(const ValueKey('peer-recs-scroll')));
      expect(band.height, 64);
      expect(band.width, 390);
      expect(band.bottom, body.bottom,
          reason: 'its bottom is the mini player top in the app');
      expect(list.bottom, band.top, reason: 'the list shrinks above it');
      expect(find.text('Preview from Deezer'), findsOneWidget);

      // ✕: the band goes and the list takes the room back.
      await tester.tap(find.byKey(kPeerBandCloseKey));
      await tester.pumpAndSettle();
      expect(find.byType(PeerRecsBand), findsNothing);
      expect(engine.ends, [PreviewEnd.stopped]);
      expect(
          tester.getRect(find.byKey(const ValueKey('peer-recs-scroll'))).bottom,
          body.bottom);
    });

    testWidgets('every state draws under the bar and strip', (tester) async {
      Future<void> check(String name, Finder what) async {
        final bar = tester.getRect(find.byType(DiscoveryConfigBar));
        final strip = tester.getRect(find.byType(PeerStripView));
        expect(strip.top, bar.bottom, reason: name);
        expect(what, findsWidgets, reason: name);
        expect(tester.getRect(what.first).top,
            greaterThanOrEqualTo(strip.bottom),
            reason: name);
        expect(find.byType(PeerLeadGrid), findsNothing, reason: name);
        expect(find.byType(PeerRecsFooter), findsNothing, reason: name);
        expect(tester.takeException(), isNull, reason: name);
      }

      // Each state is a fresh visit opened over the last (the home's own
      // rows need the audio service, so it is never drawn here).

      // Loading: the first answer is held.
      f.auto = null;
      var c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.loading);
      await check('loading', find.byKey(kPeerSkeletonCardKey));

      f.auto = (_) => tasteOk(tasteJson(leads: const [], reason: 'empty-shelf'));
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.noPeers);
      await check('noPeers', find.text('No peers yet'));

      f.auto = (_) => tasteOk(tasteJson(leads: const []));
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.nothingNew);
      await check('nothingNew', find.text('Nothing new'));

      f.auto = (_) => tasteFailed;
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.failed);
      await check('failed', find.text('Try again'));

      // A taste refusal with the flags still on: Discover's card.
      f.auto = (_) => tasteRefused;
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.scanPending);
      await check('scanPending', find.byType(DiscoveryScanPendingCard));
    });
  });

  group('card taps', () {
    testWidgets(
        "a card tap calls openPeerLead with the lead, the seed title and the "
        "visit's answers; no resolve", (tester) async {
      final c = await pumpBrowser(tester);
      final i = indexOf(c, 'Signal Fires');
      await tester.tap(openOf(i));
      await tester.pump();
      expect(opened, hasLength(1));
      final o = opened.single;
      expect(o.lead, same(c.leads[i]));
      expect(o.jobs, same(PeerRecsListing().jobs));
      expect(o.seedTitle, kSeedTitle);
      expect(o.answers?.store, same(PeerRecsListing().previews!.answers));
      expect(o.answers?.leadKey, peerLeadKey(c.leads[i]));
      expect(PeerRecsListing().sheetOpen, isTrue);
      expect(c.holding, isTrue, reason: 'the list holds under the sheet');
      expect(plugins.resolves('deezer'), isEmpty, reason: 'nothing resolved');
      expect(engine.plays, isEmpty, reason: 'nothing plays on open');

      sheets.last.complete();
      await tester.pumpAndSettle();
      expect(PeerRecsListing().sheetOpen, isFalse);
      expect(c.holding, isFalse);
    });

    testWidgets(
        'a card tap while a clip plays ends it (stopped) before the sheet '
        'opens; More options does the same', (tester) async {
      final c = await pumpBrowser(tester);
      await play(tester, c, 'Signal Fires');
      expect(find.byType(PeerRecsBand), findsOneWidget);
      await tester.tap(openOf(indexOf(c, 'Harbor Lights')));
      await tester.pump();
      expect(opened.single.endsAtOpen, [PreviewEnd.stopped],
          reason: 'ended as the sheet rises');
      await tester.pumpAndSettle();
      expect(find.byType(PeerRecsBand), findsNothing);
      sheets.last.complete();
      await tester.pumpAndSettle();

      await play(tester, c, 'Signal Fires');
      expect(find.byType(PeerRecsBand), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('discovery-more-options')), -200,
          scrollable: find.descendant(
              of: find.byKey(const ValueKey('peer-recs-scroll')),
              matching: find.byType(Scrollable)).first);
      await tester.tap(find.byKey(const ValueKey('discovery-more-options')));
      await tester.pumpAndSettle();
      expect(engine.ends, [PreviewEnd.stopped, PreviewEnd.stopped]);
      expect(find.byType(PeerRecsBand), findsNothing);
      // The seeds sheet is up over the page (not a cover: the poll goes on).
      expect(PeerRecsListing().covered, isFalse);
      Navigator.of(tester.element(find.byType(Browser))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('with the gate closed a card tap copies: clipboard Artist - '
        'Title, toast Copied', (tester) async {
      // The own server's plug-ins answer, but offer nothing for a lead.
      plugins.listing = {
        'plugins': <dynamic>[],
        'jobs': {'allowed': true},
      };
      final c = await pumpBrowser(tester);
      expect(PeerRecsListing().jobs?.listing, isNotNull);
      await tester.tap(openOf(indexOf(c, 'Signal Fires')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(clipboard, 'Paper Lantern - Signal Fires');
      expect(toasts, ['Copied']);
      expect(lifts, [0]);
    });

    testWidgets("plug-ins off: a card tap copies; no circles", (tester) async {
      server.discoveryPluginsAvailable = false;
      final c = await pumpBrowser(tester);
      expect(PeerRecsListing().jobs, isNull);
      expect(find.byKey(kPeerCardPlayKey), findsNothing);
      await tester.tap(openOf(indexOf(c, 'Salt Road')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(clipboard, 'Hollow Coast - Salt Road');
      expect(toasts, ['Copied']);
    });
  });

  group('circles and previews', () {
    testWidgets('the circle resolves and the band shows Preview from Deezer',
        (tester) async {
      final c = await pumpBrowser(tester);
      expect(find.byKey(kPeerCardPlayKey), findsWidgets);
      await play(tester, c, 'Signal Fires');
      final asked = plugins.resolves('deezer');
      expect(asked, hasLength(1), reason: 'one resolve, on the press');
      expect((asked.single['recommendation'] as Map)['title'], 'Signal Fires');
      expect(engine.plays.single.provider, 'deezer');
      expect(engine.plays.single.owner, same(PeerRecsListing().previews));
      final band = find.byType(PeerRecsBand);
      expect(band, findsOneWidget);
      expect(find.descendant(of: band, matching: find.text('Signal Fires')),
          findsOneWidget);
      expect(find.text('Preview from Deezer'), findsOneWidget);
      expect(c.holding, isTrue, reason: 'a live clip holds the list');

      // A second press on the same circle pauses it.
      await tester.tap(circleOf(indexOf(c, 'Signal Fires')));
      await tester.pumpAndSettle();
      expect(engine.pauses, 1);
      expect(PeerRecsListing().previews!.status, PeerClipStatus.paused);
    });

    testWidgets(
        'a none written into the store (as the sheet would) mutes the circle '
        'on the next frame', (tester) async {
      final c = await pumpBrowser(tester);
      final i = indexOf(c, 'Harbor Lights');
      Semantics circle() => tester.widget<Semantics>(circleOf(i));
      expect(circle().properties.enabled, isTrue);
      PeerRecsListing()
          .previews!
          .answers
          .put(peerLeadKey(c.leads[i]), 'deezer', null);
      await tester.pump();
      expect(circle().properties.enabled, isFalse, reason: 'muted');
      expect(
          find.descendant(of: circleOf(i), matching: find.byType(AbsorbPointer)),
          findsOneWidget);
      await tester.tap(circleOf(i), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(plugins.resolves('deezer'), isEmpty, reason: 'no second resolve');
      expect(opened, isEmpty, reason: 'a muted circle never opens the card');
    });

    testWidgets(
        'the No preview plug-in variant: no circles, no Preview all, Copy '
        'list alone', (tester) async {
      plugins.listing = {
        ...plugins.listing,
        'plugins': [
          for (final e in plugins.listing['plugins'] as List)
            if ((e as Map)['name'] != 'deezer' && e['name'] != 'itunes') e,
        ],
      };
      final c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.ready);
      expect(PeerRecsListing().previews!.providerPlugin, isNull);
      expect(find.byKey(kPeerCardPlayKey), findsNothing);
      await tester.scrollUntilVisible(find.byKey(kPeerCopyListKey), 200,
          scrollable: find.descendant(
              of: find.byKey(const ValueKey('peer-recs-scroll')),
              matching: find.byType(Scrollable)).first);
      expect(find.byKey(kPeerPreviewAllKey), findsNothing);
      expect(find.byKey(kPeerCopyListKey), findsOneWidget);
      // The links plug-in still opens the sheet.
      await tester.tap(openOf(indexOf(c, 'Field Notes')));
      await tester.pump();
      expect(opened, hasLength(1));
      sheets.last.complete();
      await tester.pumpAndSettle();
    });
  });

  group('copy, toasts and refresh', () {
    Future<void> copyList(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.byKey(kPeerCopyListKey), 200,
          scrollable: find.descendant(
              of: find.byKey(const ValueKey('peer-recs-scroll')),
              matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kPeerCopyListKey));
      await tester.pumpAndSettle();
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets(
          "Copy list copies the tab's leads; with the band up every page "
          "toast is lifted by the band's height (64 at 1.0, its laid-out "
          'height at 1.3), and by 0 without it (text $scale)', (tester) async {
        final c = await pumpBrowser(tester, textScale: scale);
        await copyList(tester);
        expect(clipboard, peerCopyListText(c.leads));
        expect(clipboard!.split('\n'), hasLength(12));
        expect(clipboard!.split('\n').first, 'Hollow Coast - Salt Road');
        expect(toasts, ['Copied']);
        expect(lifts, [0], reason: 'no band, no lift');

        // Preview all: the band comes up over the mini player.
        await tester.tap(find.byKey(kPeerPreviewAllKey));
        await tester.pumpAndSettle();
        final band = find.byType(PeerRecsBand);
        expect(band, findsOneWidget);
        final h = tester.getSize(band).height;
        if (scale == 1.0) {
          expect(h, 64);
        } else {
          expect(h, greaterThanOrEqualTo(78));
        }
        await copyList(tester);
        expect(toasts, ['Copied', 'Copied']);
        expect(lifts.last, h, reason: "lifted by the band's laid-out height");

        // ✕: the band goes, and so does the lift.
        await tester.tap(find.byKey(kPeerBandCloseKey));
        await tester.pumpAndSettle();
        expect(find.byType(PeerRecsBand), findsNothing);
        await copyList(tester);
        expect(lifts.last, 0, reason: 'no band, no lift');
      });
    }

    testWidgets(
        'in the real overlay the lift is live: a toast shown before the band '
        'rose moves up over it, a hub toast floats over it too, the band\'s ✕ '
        'stays reachable, and the toast drops back once the band goes',
        (tester) async {
      await pumpBrowser(tester, app: true);
      KeepToast.debugSink = null;
      final toast = find.byKey(const ValueKey('keep-toast'));
      // The browser body ends at the mini player's top; the standard slot
      // is 8 above it.
      final body = tester.getRect(find.byType(Browser));

      await copyList(tester);
      expect(KeepToast.showing, isTrue);
      expect(find.text('Copied'), findsOneWidget);
      expect(tester.getRect(toast).bottom, body.bottom - 8,
          reason: 'no band: the standard slot');

      // Preview all within the toast's 4 s: the band rises under it.
      await tester.tap(find.byKey(kPeerPreviewAllKey));
      await tester.pumpAndSettle();
      final band = tester.getRect(find.byType(PeerRecsBand));
      expect(band.bottom, body.bottom);
      expect(KeepToast.showing, isTrue, reason: 'still within its 4 s');
      expect(tester.getRect(toast).bottom, band.top - 8,
          reason: 'the toast moved up over the band');

      // A CopiesHub job toast has no context and passes no lift.
      KeepToast.show(null, 'Added');
      await tester.pumpAndSettle();
      expect(find.text('Added'), findsOneWidget);
      expect(tester.getRect(toast).bottom, band.top - 8,
          reason: 'a hub toast floats over the band too');

      // The band's ✕ is the band's, not the toast's.
      await tester.tap(find.byKey(kPeerBandCloseKey));
      await tester.pumpAndSettle();
      expect(find.byType(PeerRecsBand), findsNothing);
      expect(engine.ends, [PreviewEnd.stopped]);
      expect(KeepToast.showing, isTrue, reason: 'the tap was not the toast');
      expect(tester.getRect(toast).bottom, body.bottom - 8,
          reason: 'back at the standard slot once the band goes');
      KeepToast.dismiss();
    });

    testWidgets("the band's link that does not open says so; the song comes "
        'back', (tester) async {
      final prev = elsewhereLaunch;
      addTearDown(() => elsewhereLaunch = prev);
      final launched = <Uri>[];
      elsewhereLaunch = (uri) async {
        launched.add(uri);
        return false;
      };
      final c = await pumpBrowser(tester);
      await play(tester, c, 'Signal Fires');
      await tester.tap(find.byKey(kPeerBandLinkKey));
      await tester.pumpAndSettle();
      expect(launched, [Uri.parse('https://www.deezer.com/track/3')]);
      expect(engine.ends, [PreviewEnd.leftApp],
          reason: 'ended as it leaves the app');
      expect(engine.resumed, hasLength(1), reason: 'it never left');
      expect(toasts, ["Couldn't open that link"]);
      expect(find.byType(PeerRecsBand), findsNothing);
    });

    testWidgets('pull to refresh asks New seeds', (tester) async {
      final c = await pumpBrowser(tester);
      final asks = f.requests.length;
      await tester.fling(
          find.byKey(const ValueKey('peer-recs-scroll')),
          const Offset(0, 400),
          1000);
      await tester.pumpAndSettle();
      expect(f.requests.length, asks + 1, reason: 'one ask: a new batch');
      expect(c.state, PeerRecsState.ready);
    });
  });

  group('sizes and themes', () {
    testWidgets('360×780 and 375×667, text 1.0/1.3, dark/light: no overflow',
        (tester) async {
      final dark = paletteFor(AppTheme.dark);
      final light = paletteFor(AppTheme.light);
      addTearDown(() => VelvetColors.setActive(dark));
      for (final palette in [dark, light]) {
        VelvetColors.setActive(palette);
        for (final size in const [Size(360, 780), Size(375, 667)]) {
          for (final scale in [1.0, 1.3]) {
            final what = '${palette.brightness.name} '
                '${size.width.toInt()}×${size.height.toInt()} @$scale';
            final c = await pumpBrowser(tester,
                width: size.width, height: size.height, textScale: scale);
            expect(tester.takeException(), isNull, reason: what);
            final w = tester.getSize(card(0)).width;
            expect(w, peerCardWidth(size.width), reason: what);
            await play(tester, c, 'Signal Fires');
            expect(find.byType(PeerRecsBand), findsOneWidget, reason: what);
            expect(tester.takeException(), isNull, reason: what);
            await tester.tap(find.byKey(kPeerBandCloseKey));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: what);
          }
        }
      }
    });
  });

  group('RouteObserver', () {
    testWidgets(
        'a pushed page route covers (with an app-like '
        'MaterialApp(navigatorObservers: [appRouteObserver]))',
        (tester) async {
      final c = await pumpBrowser(tester, observe: true);
      await play(tester, c, 'Signal Fires');
      final polls = f.polls;
      expect(c.nextPollIn, isNotNull);

      // A modal bottom sheet is no page route: nothing is covered.
      final nav = Navigator.of(tester.element(find.byType(Browser)));
      unawaited(showModalBottomSheet<void>(
          context: tester.element(find.byType(Browser)),
          builder: (_) => const SizedBox(height: 200)));
      await tester.pumpAndSettle();
      expect(PeerRecsListing().covered, isFalse);
      expect(engine.ends, isEmpty, reason: 'the clip goes on under a sheet');
      expect(c.nextPollIn, isNotNull);
      nav.pop();
      await tester.pumpAndSettle();

      // A page route over the home (settings, Auto DJ, Find similar).
      unawaited(nav.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('elsewhere')))));
      await tester.pumpAndSettle();
      expect(PeerRecsListing().covered, isTrue);
      expect(engine.ends, [PreviewEnd.stopped]);
      expect(c.nextPollIn, isNull, reason: 'no poll while covered');
      expect(f.polls, polls);

      nav.pop();
      await tester.pumpAndSettle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, polls + 1, reason: 'one poll at once on return');
      expect(c.nextPollIn, isNotNull);
    });

    testWidgets(
        'a page route pushed over a sheet covers too (Find similar from the '
        'seeds sheet); back on the sheet, one poll at once', (tester) async {
      final c = await pumpBrowser(tester, observe: true);
      await play(tester, c, 'Signal Fires');
      final polls = f.polls;

      late BuildContext sheet;
      unawaited(showModalBottomSheet<void>(
          context: tester.element(find.byType(Browser)),
          builder: (context) {
            sheet = context;
            return const SizedBox(height: 200);
          }));
      await tester.pumpAndSettle();
      expect(PeerRecsListing().covered, isFalse, reason: 'a sheet is no cover');
      expect(engine.ends, isEmpty);

      // Pushed from the sheet's context, as the seeds sheet's Find similar
      // pushes More like this: the route under it is the sheet's.
      unawaited(Navigator.of(sheet).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('More like this')))));
      await tester.pumpAndSettle();
      expect(PeerRecsListing().covered, isTrue);
      expect(engine.ends, [PreviewEnd.stopped]);
      expect(c.nextPollIn, isNull, reason: 'no poll while covered');
      expect(f.polls, polls);

      Navigator.of(tester.element(find.text('More like this'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('More like this'), findsNothing);
      expect(PeerRecsListing().covered, isFalse,
          reason: 'the sheet is up again, and it is no cover');
      expect(f.polls, polls + 1, reason: 'one poll at once on return');
      expect(c.nextPollIn, isNotNull);

      Navigator.of(sheet).pop();
      await tester.pumpAndSettle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, polls + 1);
    });
  });

  group('off (R7)', () {
    testWidgets(
        'R7 off with the seeds sheet up: the frame and its visit stay until '
        'the sheet closes, then the frame pops', (tester) async {
      MediaManager().audioHandler = _NothingPlaying();
      final c = await pumpBrowser(tester);
      await tester.tap(find.byKey(const ValueKey('discovery-more-options')));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverySeedsSheet), findsOneWidget);

      f.repingPeerRecs = false;
      await c.offCheck(PeerRecsOffSource.peers);
      await tester.pumpAndSettle();
      expect(c.off, isTrue);
      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'the frame never changes under a sheet');
      expect(PeerRecsListing().controller, same(c),
          reason: "the sheet's Use these N still has its visit");
      expect(find.byType(DiscoverySeedsSheet), findsOneWidget);

      Navigator.of(tester.element(find.byType(DiscoverySeedsSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverySeedsSheet), findsNothing);
      expect(BrowserManager().browserCache, hasLength(1));
      expect(BrowserManager.isHomeList(BrowserManager().browserList), isTrue);
      expect(PeerRecsListing().controller, isNull);
    });
  });

  group('scroll', () {
    List<DisplayItem> folder() =>
        [DisplayItem(server, 'Music', 'directory', '/Music', null, null)];

    /// The admin's peers answer and six more addable peers: a strip of 14
    /// items at 390 wide, which scrolls further sideways than the page's
    /// 400 px offset. Static Garden's Add is no longer running: its ring
    /// spinner would never let the page settle.
    Map<String, dynamic> widePeers() {
      final m = peersAdminJson;
      final rows = (m['peers'] as List).cast<Map<String, dynamic>>();
      for (final r in rows) {
        if ((r['add'] as Map?)?['state'] == 'adding') r['add'] = null;
      }
      rows.addAll([
        for (var i = 0; i < 6; i++)
          {
            'endpointId': 'd$i' * 32,
            'name': 'Extra $i',
            'label': 'Extra $i',
            'monogram': 'E$i',
            'hue': 40 * i,
            'online': true,
            'onShelf': false,
            'pinned': false,
            'rowCount': 100,
            'add': null,
          },
      ]);
      return m;
    }

    /// The strip's sideways scroll position, as its scrollable holds it now
    /// (scrolled out of the page's view too).
    ScrollPosition stripAt(WidgetTester tester) => tester
        .state<ScrollableState>(find.descendant(
            of: find.byType(PeerStripView, skipOffstage: false),
            matching: find.byType(Scrollable, skipOffstage: false),
            skipOffstage: false))
        .position;

    testWidgets(
        'Back from a frame pushed over the page draws it at the offset it '
        'had, in its first frame, with the strip at All; a fresh visit '
        'starts at the top', (tester) async {
      f.peersAuto = () => peersOk(widePeers());
      await pumpBrowser(tester);
      final sc = BrowserManager().sc;
      expect(stripAt(tester).maxScrollExtent, greaterThan(400),
          reason: 'a strip that could take the page offset as its own');

      // The user scrolls the strip, then the page. The strip keeps its own
      // offset while the page is up.
      await tester.drag(find.byType(PeerStripView), const Offset(-150, 0));
      await tester.pumpAndSettle();
      final sideways = stripAt(tester).pixels;
      expect(sideways, greaterThan(0));
      sc.jumpTo(400);
      await tester.pumpAndSettle();
      expect(sc.offset, 400);
      expect(stripAt(tester).pixels, sideways);
      final before = tester.getRect(card(4));

      // A frame over the page (the Copies sheet's Show in library).
      BrowserManager().addListToStack(folder(), path: '/');
      await tester.pumpAndSettle();
      expect(find.byType(PeerRecsView), findsNothing);
      expect(PeerRecsListing().covered, isTrue);

      BrowserManager().popBrowser();
      await tester.pump(Duration.zero);
      expect(find.byType(PeerRecsView), findsOneWidget);
      expect(sc.offset, 400);
      expect(tester.getRect(card(4)), before,
          reason: 'drawn in place in its first frame, with no jump after');
      expect(stripAt(tester).pixels, 0,
          reason: 'the strip is drawn afresh at All, never at the page '
              "offset nor at the strip's old one");
      await tester.pumpAndSettle();
      expect(sc.offset, 400);
      expect(stripAt(tester).pixels, 0);

      // The page back at the top: All and the first peers in view.
      sc.jumpTo(0);
      await tester.pumpAndSettle();
      expect(stripAt(tester).pixels, 0);
      expect(tester.getRect(find.byKey(const ValueKey('peer-strip-all'))).left,
          14);
      expect(
          tester.getRect(find.byKey(ValueKey('peer-strip-$kBasement'))).right,
          lessThan(390));

      // Covered again, then the stack reset and a fresh visit opened.
      BrowserManager().addListToStack(folder(), path: '/');
      await tester.pumpAndSettle();
      BrowserManager().goToNavScreen();
      PeerRecsListing().open(server, controller: f.makeController());
      await tester.pumpAndSettle();
      expect(find.byType(PeerRecsView), findsOneWidget);
      expect(sc.offset, 0, reason: 'a fresh visit starts at the top');
      expect(stripAt(tester).pixels, 0);
    });

    testWidgets(
        "no other scrollable in the page shares its scroller's page-storage "
        'entry, in any state', (tester) async {
      /// Where the scrollable [e] files its offset: the nearest PageStorage's
      /// bucket and the PageStorageKeys from [e] up to it, as
      /// PageStorageBucket computes them. Null when it keeps none.
      String? entryOf(Element e) {
        final s = (e as StatefulElement).state as ScrollableState;
        if (!s.position.keepScrollOffset) return null;
        final keys = <String>[];
        Object? bucket;
        bool visit(Element el) {
          final w = el.widget;
          if (w.key is PageStorageKey) keys.add('${w.key}');
          if (w is PageStorage) {
            bucket = w.bucket;
            return false;
          }
          return true;
        }

        if (visit(e)) e.visitAncestorElements(visit);
        return '${identityHashCode(bucket)} ${keys.join(' < ')}';
      }

      void check(String name) {
        final scroller = entryOf(tester.element(find
            .descendant(
                of: find.byKey(const ValueKey('peer-recs-scroll')),
                matching: find.byType(Scrollable))
            .first));
        expect(scroller, isNotNull,
            reason: '$name: the page keeps its own offset');
        final all = find.descendant(
            of: find.byType(PeerRecsView),
            matching: find.byType(Scrollable, skipOffstage: false),
            skipOffstage: false);
        expect(all, findsAtLeastNWidgets(2),
            reason: '$name: the scroller and the strip');
        final entries = [for (final e in all.evaluate()) entryOf(e)].nonNulls;
        expect(entries.where((x) => x == scroller), hasLength(1),
            reason: "$name: the scroller's entry is its own");
        expect(entries.toSet(), hasLength(entries.length), reason: name);
      }

      f.peersAuto = () => peersOk(widePeers());
      var c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.ready);
      check('ready');
      await play(tester, c, 'Signal Fires');
      expect(find.byType(PeerRecsBand), findsOneWidget);
      check('ready, the band up');

      // Each other state a fresh visit, as 'every state draws under the bar
      // and strip' opens them.
      f.auto = null;
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.loading);
      check('loading');

      f.auto = (_) => tasteOk(tasteJson(leads: const [], reason: 'empty-shelf'));
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.noPeers);
      check('noPeers');

      f.auto = (_) => tasteOk(tasteJson(leads: const []));
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.nothingNew);
      check('nothingNew');

      f.auto = (_) => tasteFailed;
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.failed);
      check('failed');

      f.auto = (_) => tasteRefused;
      c = await pumpBrowser(tester);
      expect(c.state, PeerRecsState.scanPending);
      check('scanPending');
    });
  });
}
