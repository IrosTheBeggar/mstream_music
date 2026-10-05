// Widget tests for the Discover page (the Phone / PhoneSeeds / PhoneLibrary
// / PhoneStates canvas boards, as the plan amends them): the seed chips,
// the three sources, the nothing-finished card, the scan-pending card, the
// seeds sheet, and "See all" pushing the one-source list.
//
// The page gets an injected controller whose taste route answers at once,
// so every load is microtasks — no network, no audio service (the page's
// now-playing read tolerates the unstarted MediaManager).

import 'package:flutter/rendering.dart' show RenderParagraph;
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
  }) async {
    // The design's 390 px width (where a row would overflow) and tall enough
    // that the lazy ListView builds every section.
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
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
      home: DiscoveryPage(server: s, controller: c),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  DiscoveryFetchResult<TasteResponse> usual(TasteRequest r) =>
      DiscoveryFetchResult.ok(
          parse(isPeersCall(r) ? peersPayload() : mainPayload()));

  testWidgets('seed chips, then the library, network and peers sections',
      (tester) async {
    await pumpPage(tester, usual);
    expect(tester.takeException(), isNull, reason: 'no overflow at 390 px');

    // App bar: the page title (not the per-song lens's) and what it is
    // seeded from.
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('based on 5 songs you finished · 30 days'),
        findsOneWidget);

    // Based on: three chips and "+ 2" for the rest.
    expect(find.text('BASED ON'), findsOneWidget);
    expect(find.text('Manor · ALM'), findsOneWidget);
    expect(find.text('Roygbiv · Boards of Canada'), findsOneWidget);
    expect(find.text('Xtal · Aphex Twin'), findsOneWidget);
    expect(find.text('Kerala · Bonobo'), findsNothing);
    expect(find.text('+ 2'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

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
    expect(find.text('Pick · Someone'), findsOneWidget);
    expect(find.text('random'), findsOneWidget);
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
  });

  testWidgets('Edit opens the seeds sheet with the window and a switch per '
      'seed', (tester) async {
    await pumpPage(tester, usual);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('songs you played to the end · skips never count'),
        findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('90 days'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('5 of 6 on'), findsOneWidget,
        reason: 'five history seeds on, one remembered drop off');
    expect(find.text('Kids Song'), findsOneWidget);
    expect(find.text('Pick a song…'), findsOneWidget);
    expect(find.text('Use these 5'), findsOneWidget);

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
    // A seed chip and "+ N" are one height.
    final chip = find.ancestor(
        of: find.text('Manor · ALM'), matching: find.byType(InkWell));
    final more =
        find.ancestor(of: find.text('+ 2'), matching: find.byType(InkWell));
    expect(h(chip.first), greaterThanOrEqualTo(44));
    expect(h(more.first), h(chip.first));
    // Pills keep their canvas height but hit in a 44 px band.
    final band = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.minHeight == 44);
    final pill = find.ancestor(of: find.text('Shuffle'), matching: band);
    expect(h(pill.first), greaterThanOrEqualTo(44));
    final edit =
        find.ancestor(of: find.text('Edit'), matching: find.byType(TextButton));
    expect(h(edit), greaterThanOrEqualTo(44));
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
    await tester.tap(find.text('Edit'));
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
  });

  testWidgets('a restore the prefs route could not save says so',
      (tester) async {
    await pumpPage(tester, usual,
        fetchPrefs: (_) async => const DiscoveryFetchResult.error());
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    // The remembered drop is the last switch; turn it back on.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use these 6'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't bring those songs back. Try again."),
        findsOneWidget);
  });

  testWidgets('the seeds sheet fits a long locale at 390 px', (tester) async {
    await pumpPage(tester, usual, locale: const Locale('de'));
    // The chip row scrolls; the test font's wide glyphs push "+ 2" right.
    await tester.ensureVisible(find.text('+ 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ 2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Gesamt'), findsOneWidget);
    expect(find.text('30 Tage'), findsOneWidget);
    // Shrunk to fit, never ellipsized — the test font's square glyphs are
    // wider than any real one, so this holds at 390 px for every locale.
    for (final label in ['7 Tage', '30 Tage', '90 Tage', 'Gesamt']) {
      final para = tester.renderObject<RenderParagraph>(find.text(label));
      expect(para.didExceedMaxLines, isFalse, reason: label);
    }
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
