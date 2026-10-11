// Widget tests for the Discover page (the Phone / PhoneSeeds / PhoneLibrary
// / PhoneStates canvas boards, as the plan amends them): the configuration
// bar (window + "More options"), the three sources, the nothing-finished
// card, the scan-pending card, the seeds sheet, and "See all" pushing the
// one-source list.
//
// The page gets an injected controller whose taste route answers at once,
// so every load is microtasks — no network, no audio service (the page's
// now-playing read tolerates the unstarted MediaManager).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/discovery_page_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_source_list.dart';
import 'package:mstream_music/screens/discovery/discovery_widgets.dart';
import 'package:mstream_music/screens/discovery_page.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

import 'discovery_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DiscoveryPageController.clearCache();
    ServerManager().serverList.clear();
  });
  tearDown(() {
    DiscoveryPageController.clearCache();
    ServerManager().serverList.clear();
  });

  DiscoveryPageController controllerFor(
    Server server,
    DiscoveryFetchResult<TasteResponse> Function(TasteRequest) answer, {
    Future<DiscoveryFetchResult<TastePrefs>> Function(Server)? fetchPrefs,
  }) =>
      DiscoveryPageController(
        server: server,
        fetch: (_, r) async => answer(r),
        fetchPrefs: fetchPrefs ??
            (_) async => const DiscoveryFetchResult.ok(TastePrefs()),
        savePrefs: (_, p) async => DiscoveryFetchResult.ok(p),
        reping: (_) async {},
        randomPick: (_) async => null,
        newArtistsOnly: () => false,
        now: () => DateTime.utc(2026, 10, 5, 12),
      );

  Future<DiscoveryPageController> pumpPage(
    WidgetTester tester,
    DiscoveryFetchResult<TasteResponse> Function(TasteRequest) answer, {
    Server? server,
    Locale? locale,
    Future<DiscoveryFetchResult<TastePrefs>> Function(Server)? fetchPrefs,
    double width = 390,
    double textScale = 1,
  }) async {
    // The design's 390 px width (where a row would overflow) and tall enough
    // that the lazy ListView builds every section.
    tester.view.physicalSize = Size(width * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = server ?? discoveryServer();
    final c = controllerFor(s, answer, fetchPrefs: fetchPrefs);
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: textScale == 1
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
      home: DiscoveryPage(server: s, controller: c),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  DiscoveryFetchResult<TasteResponse> usual(TasteRequest r) =>
      DiscoveryFetchResult.ok(
          parse(isPeersCall(r) ? peersPayload() : mainPayload()));

  /// The pinned configuration bar under the app bar.
  final bar = find.byKey(const ValueKey('discovery-config-bar'));
  Finder inBar(Finder f) => find.descendant(of: bar, matching: f);

  /// The seed titles of [mainPayload]: the sheet's to show, never the body's.
  const seedTitles = ['Manor', 'Roygbiv', 'Xtal', 'Kerala', 'Awake'];

  TextButton moreOptions(WidgetTester tester) =>
      tester.widget<TextButton>(find.byKey(const ValueKey('discovery-more-options')));
  PopupMenuButton<int> windowChooser(WidgetTester tester) =>
      tester.widget<PopupMenuButton<int>>(
          find.byKey(const ValueKey('discovery-window')));

  /// One choice in the open window menu.
  Finder menuItem(String label) => find.ancestor(
      of: find.text(label), matching: find.byType(CheckedPopupMenuItem<int>));

  testWidgets('the configuration bar, then the library, network and peers '
      'sections', (tester) async {
    await pumpPage(tester, usual);
    expect(tester.takeException(), isNull, reason: 'no overflow at 390 px');

    // App bar: the page title (not the per-song lens's) and what it is
    // seeded from.
    expect(find.text('Discover'), findsOneWidget);
    // No window there: the bar is its one home.
    expect(find.text('based on 5 songs you finished'), findsOneWidget);

    // The bar: the window form and the link to the seeds — nothing else.
    expect(inBar(find.text('Based on the last')), findsOneWidget);
    expect(inBar(find.text('30 days')), findsOneWidget);
    expect(inBar(find.text('More options')), findsOneWidget);
    // Pinned: not part of the scrolling body.
    expect(find.ancestor(of: bar, matching: find.byType(ListView)),
        findsNothing);

    // The seeds stay behind "More options": no chip strip in the body, so
    // nothing up top reads as a song to tap and play.
    // Whatever the format: no seed title anywhere on the page.
    for (final t in seedTitles) {
      expect(find.textContaining(t), findsNothing, reason: t);
    }
    expect(find.text('BASED ON'), findsNothing);
    expect(find.textContaining('+ 2'), findsNothing);
    expect(find.text('Edit'), findsNothing);

    // From your library: album cards with their play facts, the first four
    // songs, and the queue pills over all five.
    expect(find.text('FROM YOUR LIBRARY'), findsOneWidget);
    expect(find.text('Dive'), findsOneWidget);
    expect(find.text('Immunity'), findsOneWidget);
    expect(find.text('2 of 12 played'), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    expect(find.text('Dawn Chorus'), findsOneWidget);
    expect(find.text('Weightless'), findsOneWidget);
    expect(find.text('Teardrop'), findsNothing, reason: 'the fifth: See all');
    expect(find.textContaining('· never played'), findsNWidgets(3));
    expect(find.textContaining('last played 8 months ago'), findsOneWidget);
    expect(find.text('Play all 5'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Add to queue'), findsOneWidget);

    // From the network: DiscoverScreen's lead row.
    expect(find.text('FROM THE NETWORK'), findsOneWidget);
    expect(find.text('3 servers searched'), findsOneWidget);
    expect(find.text('Says'), findsOneWidget);

    // From your peers: grouped, online and offline.
    expect(find.text('FROM YOUR PEERS'), findsOneWidget);
    expect(find.text('1 of 2 online'), findsOneWidget);
    expect(find.text("Sam's server"), findsOneWidget);
    expect(find.text('Blurred EP'), findsOneWidget);
    expect(find.text("Lee's server"), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    // The peers cap is per group and no group exceeds it, as the network's
    // one lead does not: "See all" is the library's alone.
    expect(find.text('See all'), findsOneWidget);

    // Nothing-finished and scan-pending cards are absent.
    expect(find.textContaining('Finish a few songs'), findsNothing);
    expect(find.text('Nothing analyzed yet'), findsNothing);
  });

  testWidgets('nothing finished yet: the random-pick card, no network or '
      'peers sections', (tester) async {
    await pumpPage(
      tester,
      (r) => DiscoveryFetchResult.ok(parse(isPeersCall(r)
          ? {'peers': null}
          : mainPayload(
              seedSource: 'random',
              fallback: true,
              network: false,
              seeds: [seedRow('hr', 'Pick', 'Someone')]))),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('nothing finished yet · a random pick instead'),
        findsOneWidget);
    expect(find.text('Finish a few songs and this page learns your taste'),
        findsOneWidget);
    expect(find.text('Another pick'), findsOneWidget);
    expect(find.text('Choose a song…'), findsOneWidget);
    // The random seed is the sheet's to show, not a chip in the body; the
    // bar is there as in every state.
    expect(find.textContaining('Pick'), findsNothing);
    expect(find.textContaining('Someone'), findsNothing);
    expect(inBar(find.text('More options')), findsOneWidget);
    // ... where it is filed as what it is, not as a song you finished.
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.text('RANDOM PICK'), findsOneWidget);
    expect(find.text('FINISHED RECENTLY'), findsNothing);
    expect(find.text('Pick'), findsOneWidget);
    expect(find.text('FROM YOUR LIBRARY'), findsOneWidget);
    expect(find.text('FROM THE NETWORK'), findsNothing);
    expect(find.text('FROM YOUR PEERS'), findsNothing);
  });

  testWidgets('a source with nothing gets one line', (tester) async {
    await pumpPage(
      tester,
      (r) => DiscoveryFetchResult.ok(parse(isPeersCall(r)
          ? {
              'peers': {'peers': [], 'searched': {'peers': 0}}
            }
          : {
              ...mainPayload(tracks: []),
              'library': {'filter': 'fresh', 'tracks': [], 'albums': []},
              'network': {
                'results': [],
                'searched': {'peers': 0, 'tracks': 0}
              },
            })),
    );
    expect(tester.takeException(), isNull);
    expect(
        find.text(
            'Nothing in your library matches these songs with this filter.'),
        findsOneWidget);
    expect(find.textContaining('No network data yet'), findsOneWidget,
        reason: 'nothing searched yet is the shelf filling up');
    expect(find.textContaining('No peers to ask yet'), findsOneWidget);
    expect(find.text('Play all 0'), findsNothing);
  });

  testWidgets('a 403 whose flags survive the re-ping is scan pending',
      (tester) async {
    await pumpPage(tester, (_) => const DiscoveryFetchResult.disabled());
    expect(find.text('Nothing analyzed yet'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(inBar(find.text('More options')), findsOneWidget,
        reason: 'the page is available: its configuration is too');
    // ... but under the 403 latch nothing would be asked: both controls off,
    // "Check again" is the way out.
    expect(moreOptions(tester).onPressed, isNull);
    expect(windowChooser(tester).enabled, isFalse);
  });

  testWidgets('a first call that failed: the retry card under the bar, the '
      'window still choosable, no seeds to show', (tester) async {
    await pumpPage(
        tester, (_) => const DiscoveryFetchResult<TasteResponse>.error());
    expect(find.text('Try again'), findsOneWidget);
    expect(bar, findsOneWidget);
    expect(windowChooser(tester).enabled, isTrue,
        reason: 'a window change is a retry over it');
    expect(moreOptions(tester).onPressed, isNull,
        reason: 'no answer yet: the sheet would read "0 of 0 on"');
  });

  testWidgets('a widened answer: the bar keeps the window asked for, the '
      'body says why the seeds are older, nothing names two windows',
      (tester) async {
    await pumpPage(
      tester,
      (r) => DiscoveryFetchResult.ok(parse(isPeersCall(r)
          ? peersPayload()
          : {...mainPayload(window: 0), 'widenedFrom': 30})),
    );
    expect(tester.takeException(), isNull);
    expect(inBar(find.text('Based on the last')), findsOneWidget);
    expect(inBar(find.text('30 days')), findsOneWidget);
    expect(find.text('based on 5 songs you finished'), findsOneWidget);
    expect(find.textContaining('All time'), findsNothing);
    expect(
        find.text(
            'Nothing in the last 30 days, so these come from further back.'),
        findsOneWidget);
  });

  testWidgets('all time reads "Based on [All time]", not "the last"',
      (tester) async {
    await pumpPage(
      tester,
      (r) => DiscoveryFetchResult.ok(
          parse(isPeersCall(r) ? peersPayload() : mainPayload(window: 0))),
    );
    expect(inBar(find.text('Based on')), findsOneWidget);
    expect(inBar(find.text('All time')), findsOneWidget);
    expect(find.text('Based on the last'), findsNothing);
    expect(find.textContaining('further back'), findsNothing,
        reason: 'not widened');
  });

  testWidgets('a re-ping that switched discovery off says so in one line',
      (tester) async {
    final s = discoveryServer();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = DiscoveryPageController(
      server: s,
      fetch: (_, _) async => const DiscoveryFetchResult.disabled(),
      reping: (srv) async => srv.discoveryTasteAvailable = false,
      now: () => DateTime.utc(2026, 10, 5, 12),
      newArtistsOnly: () => false,
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: DiscoveryPage(server: s, controller: c),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sonic discovery has been switched off on this server.'),
        findsOneWidget);
    expect(bar, findsNothing, reason: 'nothing left to configure');
  });

  testWidgets('More options opens the seeds sheet: a switch per seed, no '
      'window (the bar is its one home)', (tester) async {
    await pumpPage(tester, usual);
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Based on'), findsOneWidget);
    expect(find.text('songs you played to the end · skips never count'),
        findsOneWidget);
    expect(find.text('7 days'), findsNothing);
    expect(find.text('90 days'), findsNothing);
    expect(find.text('All time'), findsNothing);
    expect(find.text('30 days'), findsOneWidget, reason: "the bar's, behind");
    expect(find.text('5 of 6 on'), findsOneWidget,
        reason: 'five history seeds on, one remembered drop off');
    expect(find.text('Kids Song'), findsOneWidget);
    expect(find.text('Pick a song…'), findsOneWidget);
    expect(find.text('Use these 5'), findsOneWidget);
    // The per-seed lens the old chips opened: on every seed row, not on a
    // dropped one.
    expect(find.byTooltip('Find similar'), findsNWidgets(5));

    // Switching a seed off counts down.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Use these 4'), findsOneWidget);
  });

  testWidgets('See all pushes the one-source list with its filter chips',
      (tester) async {
    await pumpPage(tester, usual);
    await tester.tap(find.text('See all').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DiscoverySourceList), findsOneWidget);
    expect(find.text('From your library'), findsOneWidget);
    expect(find.text('2 albums · 5 songs · Matched by sound'), findsOneWidget);
    expect(find.text('Never played'), findsOneWidget);
    expect(find.text('Not in 90 days'), findsOneWidget);
    expect(find.text('Everything'), findsOneWidget);
    expect(find.text('ALBUMS'), findsOneWidget);
    expect(find.text('SONGS'), findsOneWidget);
    expect(find.text('Teardrop'), findsOneWidget,
        reason: 'every row the visit fetched');
  });

  testWidgets('every control the page adds clears the 44 px tap floor',
      (tester) async {
    await pumpPage(tester, usual);
    double h(Finder f) => tester.getSize(f).height;
    // Pills keep their canvas height but hit in a 44 px band — the bar's
    // window chooser too, whose menu button wraps the whole band.
    final band = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.minHeight == 44);
    final pill = find.ancestor(of: find.text('Shuffle'), matching: band);
    expect(h(pill.first), greaterThanOrEqualTo(44));
    expect(h(find.byKey(const ValueKey('discovery-window'))),
        greaterThanOrEqualTo(44));
    final more = find.ancestor(
        of: find.text('More options'), matching: find.byType(TextButton));
    expect(h(more), greaterThanOrEqualTo(44));
    // Library rows carry the inline next / queue verbs (plan §1).
    expect(find.byTooltip('Add next'), findsNWidgets(4));
    expect(find.byTooltip('Add to end of queue'), findsNWidgets(4));
    expect(tester.getSize(find.byTooltip('Add next').first).height,
        greaterThanOrEqualTo(44));
  });

  testWidgets('a peer the app has not mirrored is drawn quiet and says why',
      (tester) async {
    await pumpPage(tester, usual);
    final play = find.byTooltip('Listen');
    expect(play, findsOneWidget);
    final icon = tester.widget<Icon>(
        find.descendant(of: play, matching: find.byType(Icon)));
    expect(icon.color, isNot(VelvetColors.primary),
        reason: 'not drawn as a row that plays');
    expect(find.byTooltip('Add to end of queue'), findsNWidgets(4),
        reason: 'the library rows only: an unplayable peer row has no queue');
    await tester.tap(play);
    await tester.pump();
    expect(find.textContaining("isn't in your server list yet"),
        findsOneWidget);
  });

  testWidgets('a mirrored peer row plays and queues inline', (tester) async {
    final s = discoveryServer();
    ServerManager().serverList.addAll([
      s,
      Server('federated://home/7', null, null, null, 'peer-7')
        ..federationParent = 'home'
        ..federationPeerId = 7
        ..parentServer = s,
    ]);
    await pumpPage(tester, usual, server: s);
    final icon = tester.widget<Icon>(find.descendant(
        of: find.byTooltip('Listen'), matching: find.byType(Icon)));
    expect(icon.color, VelvetColors.primary);
    expect(find.byTooltip('Add to end of queue'), findsNWidgets(5),
        reason: 'four library rows and the peer row');
  });

  testWidgets('scan pending: every source names the scan, not its own empty '
      'state', (tester) async {
    await pumpPage(
      tester,
      (r) => DiscoveryFetchResult.ok(parse(isPeersCall(r)
          ? {
              'notAnalyzed': true,
              'peers': {'peers': [], 'searched': {'peers': 0}}
            }
          : {
              ...mainPayload(),
              'notAnalyzed': true,
              'library': {'filter': 'fresh', 'tracks': [], 'albums': []},
              'network': {
                'results': [],
                'searched': {'peers': 0, 'tracks': 0}
              },
            })),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Nothing analyzed yet'), findsOneWidget);
    expect(
        find.text('Shows up once the discovery scan has analyzed these songs.'),
        findsNWidgets(3));
    expect(find.textContaining('No network data yet'), findsNothing);
    expect(find.textContaining('No peers to ask yet'), findsNothing);
    expect(find.text('0 servers searched'), findsNothing);
  });

  testWidgets('"Use these N" sends the dropped seed, remembered',
      (tester) async {
    final requests = <TasteRequest>[];
    await pumpPage(tester, (r) {
      requests.add(r);
      return usual(r);
    });
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    requests.clear();
    await tester.tap(find.text('Use these 4'));
    await tester.pumpAndSettle();
    expect(find.text('Use these 4'), findsNothing, reason: 'the sheet closed');
    final main = requests.where((r) => !isPeersCall(r)).single.toJson();
    expect(main['exclude'], ['h1'], reason: 'the first history seed');
    expect(main['remember'], isTrue);
    expect(main.containsKey('window'), isFalse,
        reason: 'the sheet sends the window in force, unchanged');
  });

  testWidgets('a restore the prefs route could not save says so',
      (tester) async {
    await pumpPage(tester, usual,
        fetchPrefs: (_) async => const DiscoveryFetchResult.error());
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    // The remembered drop is the last switch; turn it back on.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use these 6'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't bring those songs back. Try again."),
        findsOneWidget);
  });

  testWidgets('the bar and the seeds sheet fit a long locale at 390 px',
      (tester) async {
    await pumpPage(tester, usual, locale: const Locale('de'));
    expect(tester.takeException(), isNull);
    expect(inBar(find.text('Basierend auf den letzten')), findsOneWidget);
    expect(inBar(find.text('30 Tage')), findsOneWidget);
    await tester.tap(inBar(find.text('Weitere Optionen')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Basierend auf'), findsOneWidget);
    expect(find.text('Gesamt'), findsNothing, reason: 'no window in the sheet');
  });

  for (final (locale, width, scale) in [
    ('de', 390.0, 1.3),
    ('ru', 390.0, 1.3),
    ('fr', 390.0, 1.3),
    ('de', 360.0, 1.3),
    ('ru', 360.0, 1.3),
    ('de', 360.0, 1.0),
    ('fr', 320.0, 1.0),
    ('pl', 320.0, 1.0),
    ('es', 320.0, 1.0),
    ('en', 320.0, 2.0),
  ]) {
    testWidgets('the bar wraps rather than overflows: $locale at $width px, '
        '${scale}x text', (tester) async {
      await pumpPage(tester, usual,
          locale: Locale(locale), width: width, textScale: scale);
      expect(tester.takeException(), isNull);
      final pill = find.byKey(const ValueKey('discovery-window'));
      final more = find.byKey(const ValueKey('discovery-more-options'));
      expect(pill, findsOneWidget);
      expect(more, findsOneWidget);
      // Both stay inside the bar, whichever line "More options" lands on.
      final b = tester.getRect(bar);
      for (final f in [pill, more]) {
        final r = tester.getRect(f);
        expect(r.left >= b.left && r.right <= b.right, isTrue,
            reason: '$r in $b');
      }
    });
  }

  testWidgets('choosing a window in the bar re-asks with the same seeds',
      (tester) async {
    final requests = <TasteRequest>[];
    await pumpPage(tester, (r) {
      requests.add(r);
      return usual(r);
    });
    // A drop first, so the re-ask can be seen to keep it.
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use these 4'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('discovery-window')));
    await tester.pumpAndSettle();
    // The menu: every window, the one in force checked.
    expect(find.byType(CheckedPopupMenuItem<int>), findsNWidgets(4));
    final checked = tester
        .widgetList<CheckedPopupMenuItem<int>>(
            find.byType(CheckedPopupMenuItem<int>))
        .where((i) => i.checked)
        .single;
    expect(checked.value, 30);

    requests.clear();
    await tester.tap(menuItem('90 days'));
    await tester.pumpAndSettle();
    final main = requests.where((r) => !isPeersCall(r)).single.toJson();
    expect(main['window'], 90);
    expect(main['exclude'], ['h1'], reason: 'the drop is kept');
    expect(main['remember'], isTrue);
    expect(requests.where(isPeersCall).single.toJson()['window'], 90);
    expect(inBar(find.text('90 days')), findsOneWidget);
    expect(inBar(find.text('30 days')), findsNothing);
  });

  testWidgets('a failed window change keeps its rows and the old window',
      (tester) async {
    var fail = false;
    await pumpPage(tester, (r) => fail && !isPeersCall(r)
        ? const DiscoveryFetchResult<TasteResponse>.error()
        : usual(r));
    fail = true;
    await tester.tap(find.byKey(const ValueKey('discovery-window')));
    await tester.pumpAndSettle();
    await tester.tap(menuItem('All time'));
    await tester.pumpAndSettle();
    expect(find.text("Discover couldn't load. Check the connection and try "
        'again.'), findsOneWidget);
    expect(inBar(find.text('30 days')), findsOneWidget);
    expect(find.text('Dawn Chorus'), findsOneWidget, reason: 'rows kept');
  });

  testWidgets('a failed window change puts the peers rows back too',
      (tester) async {
    var fail = false;
    await pumpPage(tester, (r) {
      if (!fail) return usual(r);
      if (!isPeersCall(r)) {
        return const DiscoveryFetchResult<TasteResponse>.error();
      }
      // The peers call answers over the new window's seeds.
      return DiscoveryFetchResult.ok(parse({
        'peers': {
          'peers': [
            {
              'id': 11,
              'name': 'New window peer',
              'reachable': true,
              'mismatched': false,
              'results': [
                {
                  'artist': 'Someone',
                  'title': 'New window song',
                  'similarity': 0.7,
                  'filepath': 'x/y.flac',
                  'source': 'federation',
                  'seedHash': null,
                },
              ],
            }
          ],
          'searched': {'peers': 1}
        }
      }));
    });
    expect(find.text("Sam's server"), findsOneWidget);
    fail = true;
    await tester.tap(find.byKey(const ValueKey('discovery-window')));
    await tester.pumpAndSettle();
    await tester.tap(menuItem('90 days'));
    await tester.pumpAndSettle();
    expect(inBar(find.text('30 days')), findsOneWidget);
    expect(find.text("Sam's server"), findsOneWidget,
        reason: 'the peers rows of the window the bar names');
    expect(find.text('New window peer'), findsNothing);
    expect(find.text('New window song'), findsNothing);
  });

  testWidgets('the bar is quiet while a call is in flight', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = discoveryServer();
    final gate = Completer<void>();
    final c = DiscoveryPageController(
      server: s,
      fetch: (_, r) async {
        await gate.future;
        return usual(r);
      },
      reping: (_) async {},
      newArtistsOnly: () => false,
      now: () => DateTime.utc(2026, 10, 5, 12),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: DiscoveryPage(server: s, controller: c),
    ));
    await tester.pump();
    TextButton more() => tester.widget<TextButton>(find.ancestor(
        of: find.text('More options'), matching: find.byType(TextButton)));
    PopupMenuButton<int> window() => tester.widget<PopupMenuButton<int>>(
        find.byKey(const ValueKey('discovery-window')));
    expect(more().onPressed, isNull);
    expect(window().enabled, isFalse);

    gate.complete();
    await tester.pumpAndSettle();
    expect(more().onPressed, isNotNull);
    expect(window().enabled, isTrue);
  });

  testWidgets('a filter chip refetches; a failed one keeps its rows and says '
      'so', (tester) async {
    final requests = <TasteRequest>[];
    var fail = false;
    await pumpPage(tester, (r) {
      requests.add(r);
      return fail && !isPeersCall(r)
          ? const DiscoveryFetchResult<TasteResponse>.error()
          : usual(r);
    });
    await tester.tap(find.text('See all').first);
    await tester.pumpAndSettle();

    requests.clear();
    await tester.ensureVisible(find.text('Everything'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everything'));
    await tester.pumpAndSettle();
    expect(requests.single.toJson()['filter'], 'all');
    expect(requests.single.toJson()['remember'], isTrue);

    fail = true;
    await tester.ensureVisible(find.text('Never played'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never played'));
    await tester.pumpAndSettle();
    expect(find.text("Discover couldn't load. Check the connection and try "
        'again.'), findsOneWidget);
    bool selected(String label) => tester
        .widget<DiscoveryChoicePill>(find.ancestor(
            of: find.text(label), matching: find.byType(DiscoveryChoicePill)))
        .selected;
    expect(selected('Never played'), isFalse,
        reason: 'the rows are not the never-played ones');
    expect(selected('Everything'), isTrue);
    expect(find.text('Teardrop'), findsOneWidget, reason: 'rows kept');
  });
}
