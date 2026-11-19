// More like this's wiring to the network-lead sheet (the design canvas's
// Main board): which song a refresh asks for once a lead action pinned it
// (Check again and the new-artists-only switch included), the Copies door
// in the app bar (when it shows, its count, its dot, its words), and the
// screen itself — the user's OWN server's jobs controller held while it is
// open (the plug-in gate read there, never on a connected server's virtual
// Server; the poll beat taken, released, and handed over when the seed
// moves to another server), a network row's tap (the sheet, or the copy),
// and the push pin.
//
// The leads come from the screen's fetch seam; the plug-in API is the
// scripted fake behind the hub's controllers; the player is the browse
// tests' fake handler; the sheets the screen opens are the test's.

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discover_screen.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/util/discover_jobs.dart' show TraySummary;
import 'package:mstream_music/util/network_sheet_gate.dart';

import 'browse_keep_fixtures.dart' show fakeAudio;
import 'discovery_plugin_fakes.dart';

const _tidewater = '/music/Mara Quell/Tidewater.flac';
const _lighthouse = '/music/Mara Quell/Lighthouse.flac';

/// The canvas's lead, as the per-song P2P route hands it out.
Map<String, dynamic> paperRow() => {
  'artist': 'The Quiet Assembly',
  'title': 'Paper Satellites',
  'album': 'Static Bloom',
  'year': 2011,
  'duration': 238,
  'similarity': 0.88,
  'recordingMbid': '0f3e9b1c-7a2d-4c55-9e11-2b6f0d8a4c11',
  'isrc': 'US-RC1-76-07839',
  'exportId': 'vv-0042',
  'peer': {'endpointId': 'ab' * 32, 'name': 'Vinyl Vault'},
};

/// A row the plug-in routes would refuse (its artist no text): it can never
/// be a recommendation, so its tap keeps copying.
Map<String, dynamic> brokenRow() => {
  'artist': 42,
  'title': 'Glass Hours',
  'similarity': 0.71,
  'peer': {'endpointId': 'cd' * 32, 'name': 'Vinyl Vault'},
};

MediaItem playing(String path, String title, {String server = 'home'}) =>
    MediaItem(
      id: 'stream:$path',
      title: title,
      artist: 'Mara Quell',
      extras: {'path': path, 'server': server},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which song a refresh asks for', () {
    final shown = DiscoverSeed(
      server: Server('http://home.local:3000', null, null, 'JWT', 'home'),
      path: _tidewater,
      title: 'Tidewater',
      artist: 'Mara Quell',
    );
    final now = DiscoverSeed(
      server: shown.server,
      path: _lighthouse,
      title: 'Lighthouse',
    );

    test('following playback: the song playing now — a full refresh shows '
        'it, the new-artists switch asks only its leads', () {
      for (final leadsOnly in [false, true]) {
        final plan = discoverRefreshSeed(
          pinned: false,
          shown: shown,
          playing: () => now,
          leadsOnly: leadsOnly,
        );
        expect(identical(plan.fetch, now), isTrue);
        expect(plan.show, !leadsOnly);
      }
    });

    test('pinned by a lead action: the song on screen, for Check again and '
        'the switch alike — playback is not even read', () {
      for (final leadsOnly in [false, true]) {
        final plan = discoverRefreshSeed(
          pinned: true,
          shown: shown,
          playing: () => fail('read the playing song'),
          leadsOnly: leadsOnly,
        );
        expect(identical(plan.fetch, shown), isTrue, reason: '$leadsOnly');
        expect(plan.show, isFalse);
      }
    });

    test('opened on a song: always that one', () {
      for (final pinned in [false, true]) {
        final plan = discoverRefreshSeed(
          explicit: now,
          pinned: pinned,
          shown: shown,
          playing: () => fail('read the playing song'),
          leadsOnly: false,
        );
        expect(identical(plan.fetch, now), isTrue);
        expect(plan.show, isTrue);
      }
    });
  });

  group('the Copies door', () {
    test('shows where Copies can exist, once the YouTube add can start or '
        'something runs or failed — hidden otherwise', () {
      const none = TraySummary();
      const live = TraySummary(total: 1, running: 1);
      const failed = TraySummary(total: 1, failed: 1);
      for (final (visible, youtube, summary, shows) in [
        (true, YoutubeBlock.ready, none, true),
        (true, YoutubeBlock.unknown, none, false),
        (true, YoutubeBlock.hidden, none, false),
        (true, YoutubeBlock.hidden, live, true),
        (true, YoutubeBlock.hidden, failed, true),
        (false, YoutubeBlock.ready, live, false),
      ]) {
        expect(
          copiesDoorShown(
            copiesVisible: visible,
            youtube: youtube,
            summary: summary,
          ),
          shows,
          reason: '$visible $youtube ${summary.running}/${summary.failed}',
        );
      }
    });

    test('its words: "Copies" with nothing to count, else the strip\'s '
        'counts', () {
      final l = lookupAppLocalizations(const Locale('en'));
      expect(copiesDoorLabel(l, const TraySummary()), 'Copies');
      expect(
        copiesDoorLabel(l, const TraySummary(total: 3, running: 2, failed: 1)),
        'Copies: Copying 2, 1 failed',
      );
      expect(
        copiesDoorLabel(l, const TraySummary(total: 1, failed: 1)),
        'Copies: 1 failed',
      );
    });

    Future<void> pumpDoor(
      WidgetTester tester,
      TraySummary summary,
      VoidCallback onPressed,
    ) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              DiscoverCopiesDoor(summary: summary, onPressed: onPressed),
            ],
          ),
        ),
      ),
    );

    testWidgets('a count while some run or wait; a red dot when none run '
        'and some failed; the glyph alone otherwise', (tester) async {
      var taps = 0;
      await pumpDoor(
        tester,
        const TraySummary(total: 3, running: 2, failed: 1),
        () => taps++,
      );
      expect(
        find.byKey(const ValueKey('discover-copies-count')),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip('Copies: Copying 2, 1 failed'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.library_add_outlined));
      expect(taps, 1);

      await pumpDoor(tester, const TraySummary(total: 1, failed: 1), () {});
      final dot = tester.widget<Badge>(
        find.byKey(const ValueKey('discover-copies-dot')),
      );
      expect(dot.isLabelVisible, isTrue);
      expect(dot.label, isNull);
      expect(dot.smallSize, 8);
      expect(find.text('1'), findsNothing);

      await pumpDoor(tester, const TraySummary(), () {});
      final plain = tester.widget<Badge>(
        find.byKey(const ValueKey('discover-copies-plain')),
      );
      expect(plain.isLabelVisible, isFalse);
      expect(find.byTooltip('Copies'), findsOneWidget);
    });

    testWidgets('a screen reader hears its words once, not the badge', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDoor(tester, const TraySummary(total: 2, running: 2), () {});
      final node = tester.getSemantics(
        find.byKey(const ValueKey('discover-copies-door')),
      );
      expect(node, isSemantics(isButton: true, tooltip: 'Copies: Copying 2'));
      expect(node.label, isNot(contains('2')));
      handle.dispose();
    });
  });

  group('the screen', () {
    final defaultFetch = DiscoverScreen.fetchNetworkLeads;
    late Directory docs;
    late Server home;
    late FakePluginServer fake;
    late FakeTimers timers;

    /// What the network fetch was asked: the server, the path, the switch.
    late List<(String, String, bool)> fetched;
    late Map<String, List<Map<String, dynamic>>> rowsFor;
    late List<
      ({
        DiscoveryJobsController jobs,
        DiscoveryLead lead,
        String? seedTitle,
        bool autoSearch,
        VoidCallback? onLeadAction,
      })
    >
    opened;
    late List<DiscoveryJobsController> copiesOpened;
    String? clipboard;

    setUpAll(() {
      docs = Directory.systemTemp.createTempSync('discover_screen_test');
    });
    tearDownAll(() {
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => docs.path,
          );
      home = Server('http://home.local:3000', null, null, 'JWT', 'home')
        ..discoveryAvailable = false
        ..discoveryP2pAvailable = true
        ..federationDiscoveryAvailable = false
        ..discoveryPluginsAvailable = true
        ..noUpload = false;
      ServerManager().serverList
        ..clear()
        ..add(home);
      fake = FakePluginServer()..listLeadPlugins();
      timers = FakeTimers();
      CopiesHub().makeJobs = (s) => DiscoveryJobsController(
        server: s,
        api: fake.api(s),
        timer: timers.call,
        watchLifecycle: false,
        youtubeShown: () => true,
      );
      fetched = [];
      rowsFor = {
        _tidewater: [paperRow(), brokenRow()],
        _lighthouse: [
          {...paperRow(), 'title': 'Low Orbit', 'exportId': 'vv-0043'},
        ],
      };
      DiscoverScreen.fetchNetworkLeads =
          (server, path, {required limit, required newArtistsOnly}) async {
            fetched.add((server.localname, path, newArtistsOnly));
            return DiscoveryFetchResult.ok(
              DiscoveryLeads.fromServerMap({
                'searched': {'peers': 3},
                'results': rowsFor[path] ?? const [],
              }),
            );
          };
      opened = [];
      DiscoveryKeepRoutes.openNetworkLead =
          (
            context,
            jobs,
            lead, {
            String? seedTitle,
            bool autoSearch = false,
            VoidCallback? onLeadAction,
          }) => opened.add((
            jobs: jobs,
            lead: lead,
            seedTitle: seedTitle,
            autoSearch: autoSearch,
            onLeadAction: onLeadAction,
          ));
      copiesOpened = [];
      DiscoveryKeepRoutes.openCopies = (_, jobs) => copiesOpened.add(jobs);
      KeepToast.debugSink = (m, {success = false}) {};
      clipboard = null;
      MediaManager().audioHandler = fakeAudio;
      fakeAudio.mediaItem.add(playing(_tidewater, 'Tidewater'));
      SettingsManager().discoverNewArtistsOnly = false;
    });

    tearDown(() {
      DiscoverScreen.fetchNetworkLeads = defaultFetch;
      DiscoveryKeepRoutes.reset();
      CopiesHub().reset();
      KeepToast.debugSink = null;
      fakeAudio.mediaItem.add(null);
      ServerManager().serverList.clear();
      SettingsManager().discoverNewArtistsOnly = false;
    });

    Future<void> frames(WidgetTester tester, [int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
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
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const DiscoverScreen(),
        ),
      );
      await frames(tester);
    }

    /// The settings file the switch writes is real I/O: let it land.
    Future<void> settleIo(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Finder row(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(ListTile));

    testWidgets('a network row the plug-ins can help opens its sheet, the '
        'seed named for its match line; one they cannot copies — and '
        'opening the screen asks no catalogue', (tester) async {
      await pumpScreen(tester);
      expect(fetched, [('home', _tidewater, false)]);
      expect(
        find.descendant(
          of: row('Paper Satellites'),
          matching: find.byIcon(Icons.public),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row('Paper Satellites'),
          matching: find.byTooltip('Open on MusicBrainz'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: row('Glass Hours'),
          matching: find.byIcon(Icons.travel_explore),
        ),
        findsOneWidget,
      );
      expect(fake.count('POST', '/resolve'), 0);

      await tester.tap(find.text('Paper Satellites'));
      await frames(tester);
      final o = opened.single;
      expect(identical(o.jobs, CopiesHub().jobsFor(home)), isTrue);
      expect(o.lead.title, 'Paper Satellites');
      expect(o.seedTitle, 'Tidewater');
      expect(o.autoSearch, isFalse);
      expect(o.onLeadAction, isNotNull);
      expect(clipboard, isNull);

      await tester.tap(find.text('Glass Hours'));
      await frames(tester);
      expect(opened, hasLength(1));
      expect(clipboard, 'Glass Hours');
      expect(find.text('Copied — go find it!'), findsOneWidget);
    });

    testWidgets('plug-ins off on the user\'s own server: today\'s rows, no '
        'door, nothing asked of the plug-in routes', (tester) async {
      home.discoveryPluginsAvailable = false;
      await pumpScreen(tester);
      expect(find.byIcon(Icons.public), findsNothing);
      expect(find.byIcon(Icons.travel_explore), findsNWidgets(2));
      expect(find.byTooltip('Open on MusicBrainz'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover-copies-door')), findsNothing);
      expect(fake.requests, isEmpty);
      await tester.tap(find.text('Paper Satellites'));
      await frames(tester);
      expect(opened, isEmpty);
      expect(clipboard, 'The Quiet Assembly - Paper Satellites');
    });

    testWidgets('a seed on a connected server: the gate is its own server\'s '
        '(the parent\'s), whatever the virtual Server says', (tester) async {
      final peer = Server('federated://home/1', null, null, null, 'peer-1')
        ..federationParent = 'home'
        ..federationPeerId = 1
        ..federationPeerName = 'Stage Peer B'
        ..parentServer = home
        ..discoveryP2pAvailable = true;
      ServerManager().serverList.add(peer);
      fakeAudio.mediaItem.add(
        playing(_tidewater, 'Tidewater', server: 'peer-1'),
      );
      expect(peer.discoveryPluginsAvailable, isNull);
      await pumpScreen(tester);
      expect(fetched.single.$1, 'peer-1', reason: 'the leads stay the seed\'s');
      await tester.tap(find.text('Paper Satellites'));
      await frames(tester);
      expect(identical(opened.single.jobs.server, home), isTrue);
      expect(identical(opened.single.jobs, CopiesHub().jobsFor(home)), isTrue);
    });

    testWidgets('a lead action pins the seed: a push pin, playback no longer '
        'followed, and the new-artists switch asks for the pinned song', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byKey(const ValueKey('discover-seed-pinned')), findsNothing);
      await tester.tap(find.text('Paper Satellites'));
      await frames(tester);
      opened.single.onLeadAction!();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('discover-seed-pinned')),
        findsOneWidget,
      );
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('Staying on this song')),
        findsOneWidget,
      );
      handle.dispose();

      fakeAudio.mediaItem.add(playing(_lighthouse, 'Lighthouse'));
      await tester.pump(const Duration(milliseconds: 600));
      await frames(tester);
      expect(fetched, hasLength(1), reason: 'the track change is not followed');
      expect(find.text('Tidewater · Mara Quell'), findsOneWidget);
      expect(find.text('Paper Satellites'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await settleIo(tester);
      expect(fetched, [
        ('home', _tidewater, false),
        ('home', _tidewater, true),
      ]);
      expect(find.text('Paper Satellites'), findsOneWidget);
      expect(find.text('Low Orbit'), findsNothing);
    });

    testWidgets('…a refresh a track change had already armed does not fire '
        'once pinned', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Paper Satellites'));
      await frames(tester);
      fakeAudio.mediaItem.add(playing(_lighthouse, 'Lighthouse'));
      await tester.pump(const Duration(milliseconds: 100));
      opened.single.onLeadAction!();
      await tester.pump(const Duration(milliseconds: 600));
      await frames(tester);
      expect(fetched, hasLength(1));
      expect(find.text('Tidewater · Mara Quell'), findsOneWidget);
    });

    testWidgets('unpinned, it follows the track as before', (tester) async {
      await pumpScreen(tester);
      fakeAudio.mediaItem.add(playing(_lighthouse, 'Lighthouse'));
      await tester.pump(const Duration(milliseconds: 600));
      await frames(tester);
      expect(fetched.last, ('home', _lighthouse, false));
      expect(find.text('Lighthouse · Mara Quell'), findsOneWidget);
      expect(find.text('Low Orbit'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover-seed-pinned')), findsNothing);
    });

    testWidgets('the Copies door: the count of what runs on the user\'s own '
        'server, and the Copies sheet behind it', (tester) async {
      for (final title in ['Low Orbit', 'Paper Satellites']) {
        fake.addJob(
          {...paperRow(), 'title': title, 'source': 'p2p'},
          plugin: 'youtube',
          state: 'running',
          choice: {'url': 'https://www.youtube.com/watch?v=abcdefghijk'},
        );
      }
      await pumpScreen(tester);
      expect(
        find.byKey(const ValueKey('discover-copies-count')),
        findsOneWidget,
      );
      expect(find.byTooltip('Copies: Copying 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover-copies-door')));
      await frames(tester);
      expect(copiesOpened.single, same(CopiesHub().jobsFor(home)));
    });

    testWidgets('…with nothing running, there while the YouTube add can '
        'start; gone where it cannot', (tester) async {
      await pumpScreen(tester);
      expect(
        find.byKey(const ValueKey('discover-copies-door')),
        findsOneWidget,
      );
      expect(find.byTooltip('Copies'), findsOneWidget);
      home.noUpload = true;
      await CopiesHub().jobsFor(home).regate();
      await frames(tester);
      expect(find.byKey(const ValueKey('discover-copies-door')), findsNothing);
    });

    testWidgets('its poll keeps the 4 s beat while open, lets go when it '
        'closes, and moves with the seed to another server', (tester) async {
      final away = Server('http://away.local:3000', null, null, 'JWT', 'away')
        ..discoveryP2pAvailable = true
        ..discoveryPluginsAvailable = true
        ..noUpload = false;
      ServerManager().serverList.add(away);
      fake.addJob(paperRow(), plugin: 'youtube', state: 'running');
      // Off the home (the hub's own beat stopped), as when More like this
      // is pushed over the player.
      final homeJobs = CopiesHub().jobsFor(home)..discoverVisible = false;
      final awayJobs = CopiesHub().jobsFor(away)..discoverVisible = false;
      await pumpScreen(tester);
      expect(homeJobs.anyLive, isTrue);
      expect(homeJobs.pollBeat, DiscoveryJobsController.kDiscoverBeat);
      expect(awayJobs.pollBeat, isNull);

      fakeAudio.mediaItem.add(
        playing(_lighthouse, 'Lighthouse', server: 'away'),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await frames(tester);
      expect(fetched.last, ('away', _lighthouse, false));
      expect(homeJobs.pollBeat, isNull, reason: 'the old hold let go');
      expect(awayJobs.anyLive, isTrue);
      expect(awayJobs.pollBeat, DiscoveryJobsController.kDiscoverBeat);

      await tester.pumpWidget(const SizedBox());
      expect(awayJobs.pollBeat, isNull);
      expect(homeJobs.pollBeat, isNull);
    });
  });
}
