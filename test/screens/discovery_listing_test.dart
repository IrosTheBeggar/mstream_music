// Discover as a browser listing (mStream plan §2.13, the play-now page; the
// phone's "browser format, not a new page"): the DisplayItems the controller
// feeds the browser list — the configuration bar first, then sections and
// the browser's own album and song items, in order; the connected-server
// block hidden without connected servers; the states; the seed picker —
// and the frame DiscoveryListing keeps on BrowserManager's stack, swapped in
// place as answers land and let go after Back. A widget pass draws it all
// through the real Browser screen.
//
// The controller's taste route answers at once (or on a completer), so
// nothing here touches the network or the audio service.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/discovery_listing.dart';
import 'package:mstream_music/screens/discovery/discovery_page_controller.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/track_capture.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';

import 'discovery_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Server server;

  // The browser resolves on-device download badges for file rows through
  // path_provider; a VM test has no platform side, so answer it.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/nonexistent-discovery-test-dir');
  });

  setUp(() {
    ServerManager().serverList.clear();
    server = discoveryServer();
  });
  tearDown(() {
    ServerManager().serverList.clear();
  });

  Server peer(int id) =>
      Server('federated://home/$id', null, null, null, 'peer-$id')
        ..federationParent = 'home'
        ..federationPeerId = id
        ..parentServer = server;

  DiscoveryPageController make(
          Future<DiscoveryFetchResult<TasteResponse>> Function(TasteRequest)
              answer) =>
      DiscoveryPageController(
        server: server,
        fetch: (_, r) => answer(r),
        reping: (_) async {},
        readWindow: () => kTasteDefaultWindow,
        saveWindow: (_) {},
        now: () => DateTime.utc(2026, 10, 5, 12),
      );

  Future<DiscoveryFetchResult<TasteResponse>> usual(TasteRequest r) async =>
      DiscoveryFetchResult.ok(parse(isPeersCall(r)
          ? peersPayload()
          : mainPayload(exclude: excludeOf(r))));

  /// A compact picture of a listing: type, plus the key a test cares about
  /// (the section / state / footer key, the row's title, the album's name).
  List<String> shape(List<DisplayItem> items) => [
        for (final it in items)
          switch (it.type) {
            'section' => 'section:${it.data}',
            kDiscoverState => 'state:${it.data}',
            kDiscoverFoot => 'foot:${it.data}',
            'file' => 'file:${it.metadata?.title}',
            'album' => 'album:${it.name}',
            _ => it.type,
          }
      ];

  group('the items the controller feeds the browser', () {
    test('the bar, the library albums, the library songs and their footer, '
        "then one connected server's songs and theirs", () async {
      ServerManager().serverList.addAll([server, peer(7)]);
      final c = make(usual);
      addTearDown(c.dispose);
      await c.load();
      final items = discoveryListingItems(c);
      expect(shape(items), [
        kDiscoverBar,
        'section:albumsLibrary',
        'album:Dive',
        'album:Immunity',
        'section:songsLibrary',
        'file:Dawn Chorus',
        'file:Cirrus',
        'file:Open Eye Signal',
        'file:Weightless',
        'file:Teardrop',
        'foot:library',
        // Sam's row has no album tag: no connected-server album strip.
        'section:songsPeers',
        'file:Blurred EP',
        'foot:peers',
      ]);
      // The one server that answered names its section.
      final peersHeader =
          items.firstWhere((i) => i.data == DiscoverySection.songsPeers.name);
      expect(peersHeader.subtext, "Sam's server");
      expect(DiscoveryListing.isListing(items), isTrue);
      expect(BrowserManager.isHomeList(items), isFalse,
          reason: 'drawn as a listing, never as the home card grid');
      // The items ARE the controller's rows, so queue actions that fill
      // metadata in place act on what the browser shows.
      expect(items.where((i) => i.type == 'file').first,
          same(c.libraryRows.first));
      expect(items.where((i) => i.type == 'file').last, same(c.peerRows.single));
    });

    test('several connected servers: their albums after the library\'s, '
        'their songs after the library\'s, unnamed', () async {
      ServerManager().serverList.addAll([server, peer(7), peer(8)]);
      final c = make((r) async => DiscoveryFetchResult.ok(
          parse(isPeersCall(r) ? manyPeersPayload() : mainPayload())));
      addTearDown(c.dispose);
      await c.load();
      final items = discoveryListingItems(c);
      expect(shape(items), [
        kDiscoverBar,
        'section:albumsLibrary',
        'album:Dive',
        'album:Immunity',
        'section:albumsPeers',
        'album:Blurred',
        'album:Persona',
        'section:songsLibrary',
        'file:Dawn Chorus',
        'file:Cirrus',
        'file:Open Eye Signal',
        'file:Weightless',
        'file:Teardrop',
        'foot:library',
        'section:songsPeers',
        'file:Bravo',
        'file:Delta',
        'file:Alpha',
        'file:Charlie',
        'foot:peers',
      ]);
      for (final h in items.where((i) => i.type == 'section')) {
        expect(h.subtext, isNull, reason: '"… from connected servers"');
      }
    });

    test('no connected servers: no connected-server block at all', () async {
      server = discoveryServer(peers: false);
      final c = make(usual);
      addTearDown(c.dispose);
      await c.load();
      final items = shape(discoveryListingItems(c));
      expect(items.where((s) => s.contains('Peers') || s.endsWith('peers')),
          isEmpty);
      expect(items.last, 'foot:library');
    });

    test('paired servers with nothing playable: the quiet line', () async {
      // Sam answered but is not mirrored: its row cannot play here.
      final c = make(usual);
      addTearDown(c.dispose);
      await c.load();
      final items = shape(discoveryListingItems(c));
      expect(items.sublist(items.length - 2),
          ['section:songsPeers', 'state:peersQuiet']);
      expect(items, isNot(contains('section:albumsPeers')));
    });

    test('the connected servers still answering: placeholders, no header',
        () async {
      final peersAnswer = Completer<DiscoveryFetchResult<TasteResponse>>();
      final c = make((r) => isPeersCall(r)
          ? peersAnswer.future
          : Future.value(DiscoveryFetchResult.ok(parse(mainPayload()))));
      addTearDown(c.dispose);
      final done = c.load();
      await Future<void>.delayed(Duration.zero);
      expect(shape(discoveryListingItems(c)).last, 'state:peersLoading');
      peersAnswer.complete(DiscoveryFetchResult.ok(parse(peersPayload())));
      await done;
      expect(shape(discoveryListingItems(c)).last, 'state:peersQuiet');
    });

    test('before the first answer: the bar over placeholders', () async {
      final main = Completer<DiscoveryFetchResult<TasteResponse>>();
      final c = make((r) => main.future);
      addTearDown(c.dispose);
      unawaited(c.load());
      await Future<void>.delayed(Duration.zero);
      expect(shape(discoveryListingItems(c)), [kDiscoverBar, 'state:loading']);
      main.complete(const DiscoveryFetchResult.error());
    });

    test('a failed first call: the bar and Try again', () async {
      final c = make((r) async => const DiscoveryFetchResult.error());
      addTearDown(c.dispose);
      await c.load();
      expect(shape(discoveryListingItems(c)), [kDiscoverBar, 'state:failed']);
    });

    test('switched off: one line, no bar', () async {
      server.discoveryTasteAvailable = false;
      final c = make(usual);
      addTearDown(c.dispose);
      await c.load();
      final items = discoveryListingItems(c);
      expect(shape(items), ['state:off']);
      expect(DiscoveryListing.isListing(items), isTrue);
    });

    test('refused with the flags still on: the scan-pending card', () async {
      final c =
          make((r) async => const DiscoveryFetchResult.disabled());
      addTearDown(c.dispose);
      await c.load();
      expect(shape(discoveryListingItems(c)),
          [kDiscoverBar, 'state:scanPending']);
    });

    test('nothing finished: the random card over the suggestions', () async {
      final c = make((r) async => DiscoveryFetchResult.ok(parse(isPeersCall(r)
          ? {'peers': null}
          : mainPayload(
              seedSource: 'random',
              fallback: true,
              seeds: [seedRow('hr', 'Pick', 'Someone')]))));
      addTearDown(c.dispose);
      await c.load();
      final items = shape(discoveryListingItems(c));
      expect(items.take(3),
          [kDiscoverBar, 'state:random', 'section:albumsLibrary']);
      expect(items.last, 'foot:library',
          reason: 'no connected server is asked for a random seed');
    });

    test('the library with nothing: its header and one line, no footer',
        () async {
      server = discoveryServer(peers: false);
      final c = make((r) async => DiscoveryFetchResult.ok(parse(
          mainPayload(tracks: const [])..['library']['albums'] = const [])));
      addTearDown(c.dispose);
      await c.load();
      expect(shape(discoveryListingItems(c)),
          [kDiscoverBar, 'section:songsLibrary', 'state:libraryEmpty']);
    });

    test('nothing analyzed yet: the card, no empty lines', () async {
      final c = make((r) async => DiscoveryFetchResult.ok(parse(isPeersCall(r)
          ? peersPayload()
          : (mainPayload(tracks: const [])
            ..['notAnalyzed'] = true
            ..['library']['albums'] = const []))));
      addTearDown(c.dispose);
      await c.load();
      expect(shape(discoveryListingItems(c)),
          [kDiscoverBar, 'state:scanPending']);
    });

    test('no counts, percentages or play facts anywhere in the items',
        () async {
      ServerManager().serverList.addAll([server, peer(7), peer(8)]);
      final c = make((r) async => DiscoveryFetchResult.ok(
          parse(isPeersCall(r) ? manyPeersPayload() : mainPayload())));
      addTearDown(c.dispose);
      await c.load();
      for (final it in discoveryListingItems(c)) {
        final line = it.subtext ?? '';
        expect(line, isNot(contains('%')), reason: line);
        expect(line, isNot(matches(RegExp(r'\d'))),
            reason: 'no year, count or when-label: "$line"');
        expect(line.toLowerCase(), isNot(contains('played')), reason: line);
      }
    });
  });

  group('the frame on the browser stack', () {
    setUp(() {
      // A one-frame stack: the server home.
      ServerManager().serverList.add(server);
      ServerManager().currentServer = server;
      BrowserManager().goToNavScreen();
    });
    tearDown(() => ServerManager().currentServer = null);

    test('pushed over the home, filled in place as answers land, let go '
        'after Back', () async {
      final main = Completer<DiscoveryFetchResult<TasteResponse>>();
      final c = make((r) => isPeersCall(r)
          ? Future.value(DiscoveryFetchResult.ok(parse(peersPayload())))
          : main.future);
      DiscoveryListing().open(server, controller: c);

      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'a frame like Albums, not a route');
      expect(BrowserManager().listName, 'Discover');
      expect(DiscoveryListing().controller, same(c));
      expect(shape(BrowserManager().browserList), [kDiscoverBar, 'state:loading']);

      main.complete(DiscoveryFetchResult.ok(parse(mainPayload())));
      await pumpEventQueue();
      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'replaced in place, never pushed again');
      expect(shape(BrowserManager().browserList).take(4), [
        kDiscoverBar,
        'section:albumsLibrary',
        'album:Dive',
        'album:Immunity',
      ]);

      // Back: the home again, and the controller is let go at once —
      // nothing has to be in flight for the listing to notice.
      BrowserManager().popBrowser();
      expect(BrowserManager().browserCache, hasLength(1));
      expect(BrowserManager.isHomeList(BrowserManager().browserList), isTrue);
      await pumpEventQueue();
      expect(DiscoveryListing().controller, isNull);
      await c.refresh();
      await pumpEventQueue();
      expect(BrowserManager().browserCache, hasLength(1),
          reason: 'a late answer never comes back as a frame');
    });

    test('Back from a list opened over Discover names the toolbar Discover '
        'again', () async {
      final c = make(usual);
      DiscoveryListing().open(server, controller: c);
      await pumpEventQueue();
      // What "Browse your library" does: the File Explorer, over Discover.
      BrowserManager().setBrowserLabel('File Explorer');
      BrowserManager().addListToStack(
          [DisplayItem(server, 'music', 'directory', '/music', null, null)],
          path: '/');
      await pumpEventQueue();
      expect(BrowserManager().listName, 'File Explorer');
      expect(DiscoveryListing().controller, same(c),
          reason: 'covered, not gone');

      BrowserManager().popBrowser();
      await pumpEventQueue();
      expect(DiscoveryListing.isListing(BrowserManager().browserList), isTrue);
      expect(BrowserManager().listName, 'Discover');
      expect(DiscoveryListing().controller, same(c));
    });

    test('a fresh open builds a fresh controller: no pins, drops or passed '
        'picks carried over', () async {
      // The flags off, so the app's own controller asks nothing (no
      // network): what is under test is that open() builds a new one.
      server.discoveryTasteAvailable = false;
      DiscoveryListing().open(server);
      await pumpEventQueue();
      final first = DiscoveryListing().controller;
      expect(first, isNotNull);
      BrowserManager().popBrowser();
      await pumpEventQueue();
      expect(DiscoveryListing().controller, isNull);

      DiscoveryListing().open(server);
      await pumpEventQueue();
      final second = DiscoveryListing().controller;
      expect(second, isNotNull);
      expect(second, isNot(same(first)));
      expect(second!.passed, isEmpty);
      expect(second.pins, isEmpty);
      expect(second.exclude, isEmpty);
      BrowserManager().popBrowser();
      await pumpEventQueue();
    });

    test('opening Discover again lets the previous controller go', () async {
      final first = make(usual);
      DiscoveryListing().open(server, controller: first);
      await pumpEventQueue();
      BrowserManager().popBrowser();
      final second = make(usual);
      DiscoveryListing().open(server, controller: second);
      await pumpEventQueue();
      expect(DiscoveryListing().controller, same(second));
      expect(BrowserManager().browserCache, hasLength(2));
    });
  });

  group('drawn by the browser', () {
    setUp(() {
      ServerManager().serverList.add(server);
      ServerManager().currentServer = server;
      BrowserManager().goToNavScreen();
    });
    tearDown(() => ServerManager().currentServer = null);

    Future<List<TasteRequest>> pumpBrowser(WidgetTester tester,
        {Future<DiscoveryFetchResult<TasteResponse>> Function(TasteRequest)?
            answer,
        bool toolbar = false}) async {
      tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final asked = <TasteRequest>[];
      final c = make((r) {
        asked.add(r);
        return (answer ?? usual)(r);
      });
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
            appBar: toolbar ? const BrowserToolbar() : null,
            body: const Browser()),
      ));
      DiscoveryListing().open(server, controller: c);
      await tester.pumpAndSettle();
      return asked;
    }

    testWidgets('the random card: Another pick asks again with the pick '
        'passed over; no New seeds on the card', (tester) async {
      final asked = await pumpBrowser(tester,
          answer: (r) async => DiscoveryFetchResult.ok(parse(isPeersCall(r)
              ? {'peers': null}
              : mainPayload(
                  seedSource: 'random',
                  fallback: true,
                  network: false,
                  seeds: [seedRow('hr', 'Pick', 'Someone')]))));
      expect(find.text('Finish a few songs and this page learns your taste'),
          findsOneWidget);
      expect(find.text("You've been through every song you finished"),
          findsNothing);
      expect(find.text('New seeds'), findsNothing);
      final before = asked.where((r) => !isPeersCall(r)).length;
      await tester.tap(find.text('Another pick'));
      await tester.pumpAndSettle();
      final main = asked.where((r) => !isPeersCall(r)).toList();
      expect(main, hasLength(before + 1));
      expect(main.last.toJson()['exclude'], ['hr']);
      expect(main.last.toJson().containsKey('pin'), isFalse);
    });

    testWidgets('the bar, the sections and the rows, with no numbers',
        (tester) async {
      await pumpBrowser(tester);
      expect(tester.takeException(), isNull, reason: 'no overflow at 390 px');

      expect(find.byKey(const ValueKey('discovery-config-bar')), findsOneWidget);
      expect(find.text('Based on the last'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('More options'), findsOneWidget);
      expect(find.text('ALBUMS FROM YOUR LIBRARY'), findsOneWidget);
      expect(find.text('SONGS FROM YOUR LIBRARY'), findsOneWidget);
      // Album cards: title and artist, no year.
      expect(find.text('Dive'), findsOneWidget);
      expect(find.text('Tycho'), findsOneWidget);
      expect(find.textContaining('2011'), findsNothing);
      // Song rows: title and the artist line, no play facts.
      expect(find.text('Dawn Chorus'), findsOneWidget);
      expect(find.text('Moderat'), findsOneWidget);
      expect(find.textContaining('never played'), findsNothing);
      expect(find.textContaining('last played'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      // The seeds stay in the sheet.
      expect(find.text('Manor'), findsNothing);
      // The footer's verbs, without counts.
      expect(find.text('Queue all'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Save as playlist'), findsOneWidget);
      expect(find.textContaining('Play all'), findsNothing);
      // Gone: the network and the per-server headers.
      expect(find.text('FROM THE NETWORK'), findsNothing);
      expect(find.textContaining('online'), findsNothing);
      expect(find.textContaining('See all'), findsNothing);
    });

    testWidgets('More options: the seeds with their switches, no checkbox; '
        'Use these asks again with the drop', (tester) async {
      final asked = await pumpBrowser(tester);
      final before = asked.where((r) => !isPeersCall(r)).length;
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text("Include songs I've played lately"), findsNothing);
      expect(find.text('Manor'), findsOneWidget);
      expect(find.text('Pick a song…'), findsOneWidget);
      expect(find.textContaining('LEFT OUT', findRichText: true), findsNothing,
          reason: 'nothing dropped on a fresh visit');

      // Switch one seed off: nothing is asked until "Use these N".
      await tester.tap(find.text('Roygbiv'));
      await tester.pump();
      expect(asked.where((r) => !isPeersCall(r)), hasLength(before));
      await tester.tap(find.text('Use these 4'));
      await tester.pumpAndSettle();
      expect(find.text('Manor'), findsNothing, reason: 'the sheet closed');
      final main = asked.where((r) => !isPeersCall(r)).toList();
      expect(main, hasLength(before + 1));
      expect(main.last.toJson()['exclude'], ['h2']);
      expect(main.last.toJson().containsKey('remember'), isFalse);
      expect(DiscoveryListing().controller?.exclude, ['h2']);

      // The answer's excluded row is what the sheet draws as left out.
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.textContaining('LEFT OUT', findRichText: true),
          findsOneWidget);
      expect(find.text('Left h2'), findsOneWidget);
    });

    // The connected servers' rows without their art: a test has no image
    // server, and the browser's song-row art (DisplayItem.getImage) draws
    // the debug error box when a load fails.
    Map<String, dynamic> peersWithoutArt() {
      final p = manyPeersPayload();
      for (final g in p['peers']['peers'] as List) {
        for (final r in g['results'] as List) {
          (r as Map).remove('album_art_file');
        }
      }
      return p;
    }

    // A song row's tap reaches the browser's own tap handling with the row
    // it shows: an armed pick (TrackCapture, checked before the tap
    // behaviour queues) receives it, so nothing touches the audio service.
    testWidgets('a song row, library or connected server, taps through the '
        "browser's tap handling", (tester) async {
      ServerManager().serverList.addAll([peer(7), peer(8)]);
      await pumpBrowser(tester,
          answer: (r) async => DiscoveryFetchResult.ok(
              parse(isPeersCall(r) ? peersWithoutArt() : mainPayload())));
      final c = DiscoveryListing().controller!;

      DisplayItem? got;
      TrackCapture.arm(TrackCaptureRequest(
          server: server, bannerLabel: (_) => '', onPicked: (i) => got = i));
      addTearDown(TrackCapture.cancel);
      await tester.tap(find.text('Cirrus'));
      await tester.pump();
      expect(got, same(c.libraryRows[1]));

      final delta = c.peerRows.firstWhere((r) => r.name == 'Delta');
      TrackCapture.arm(TrackCaptureRequest(
          server: delta.server!,
          bannerLabel: (_) => '',
          onPicked: (i) => got = i));
      await tester.tap(find.text('Delta'));
      await tester.pump();
      expect(got, same(delta),
          reason: "a connected server's row is a file on that peer");
    });

    testWidgets('an album card opens where albums open — the library\'s, '
        "and a connected server's from its own strip", (tester) async {
      ServerManager().serverList.addAll([peer(7), peer(8)]);
      await pumpBrowser(tester,
          answer: (r) async => DiscoveryFetchResult.ok(
              parse(isPeersCall(r) ? peersWithoutArt() : mainPayload())));
      addTearDown(BrowserManager().closeAlbumDetail);
      final c = DiscoveryListing().controller!;

      await tester.tap(find.text('Immunity'));
      await tester.pump();
      expect(BrowserManager().albumDetail, same(c.albumItems[1]));
      BrowserManager().closeAlbumDetail();

      // The second card of the second strip: the strip's from + k mapping.
      await tester.tap(find.text('Persona'));
      await tester.pump();
      final opened = BrowserManager().albumDetail;
      expect(opened, same(c.peerAlbumItems[1]));
      expect(opened?.server?.federationPeerId, 8);
      expect(opened?.trackArtist, 'Rival Consoles');
    });

    testWidgets('a search-narrowed listing taps the row it shows',
        (tester) async {
      await pumpBrowser(tester);
      addTearDown(BrowserManager().closeAlbumDetail);
      addTearDown(BrowserManager().closeSearch);
      final c = DiscoveryListing().controller!;
      BrowserManager().openSearch();
      BrowserManager().setSearchQuery('Immunity');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-config-bar')), findsOneWidget,
          reason: 'the bar stays');
      expect(find.text('Dive'), findsNothing);
      await tester.tap(find.text('Immunity').first);
      await tester.pump();
      expect(BrowserManager().albumDetail, same(c.albumItems[1]));
    });

    testWidgets('the library-empty line has no button', (tester) async {
      await pumpBrowser(tester,
          answer: (r) async => DiscoveryFetchResult.ok(parse(isPeersCall(r)
              ? peersPayload()
              : (mainPayload(tracks: const [])
                ..['library']['albums'] = const []))));
      expect(find.text('Nothing new in your library sounds like these songs.'),
          findsOneWidget);
      expect(find.text("Include songs I've played lately"), findsNothing);
    });

    Finder inBar(IconData icon) => find.descendant(
        of: find.byType(BrowserToolbar), matching: find.byIcon(icon));

    testWidgets('the toolbar has no page-wide Play, Add all or Download',
        (tester) async {
      await pumpBrowser(tester, toolbar: true);
      expect(inBar(Icons.arrow_back), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget, reason: 'the label');
      expect(inBar(Icons.search), findsNothing,
          reason: 'New seeds has its place');
      expect(inBar(Icons.refresh), findsOneWidget);
      expect(inBar(Icons.play_arrow), findsNothing);
      expect(inBar(Icons.library_add), findsNothing);
      expect(inBar(Icons.download_sharp), findsNothing);
      expect(inBar(Icons.more_vert), findsNothing,
          reason: 'no overflow: nothing page-wide to put in it');
    });

    testWidgets("New seeds replaces search on Discover's bar only, and "
        'is a plain re-ask', (tester) async {
      final held = <Completer<DiscoveryFetchResult<TasteResponse>>>[];
      var hold = false;
      final asked = await pumpBrowser(tester, toolbar: true, answer: (r) {
        if (!hold) return usual(r);
        final c = Completer<DiscoveryFetchResult<TasteResponse>>();
        held.add(c);
        return c.future;
      });
      final c = DiscoveryListing().controller!;
      final button = find.byTooltip('New seeds');
      expect(button, findsOneWidget);
      expect(inBar(Icons.search), findsNothing);

      final first = asked.where((r) => !isPeersCall(r)).last.toJson();
      hold = true;
      await tester.tap(button);
      await tester.pump();
      final main = asked.where((r) => !isPeersCall(r)).last.toJson();
      expect(main, first,
          reason: 'the same question: the server draws a new random batch');
      expect(main.containsKey('exclude'), isFalse);
      // The previous answer stays up under the bar's busy line; the button
      // is off until the new one lands.
      expect(find.text('Dawn Chorus'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('discovery-config-bar')),
              matching: find.byType(LinearProgressIndicator)),
          findsOneWidget);
      expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('discovery-new-seeds')))
              .onPressed,
          isNull);

      // Another batch of finished songs, and what they suggest.
      Future<DiscoveryFetchResult<TasteResponse>> rotated(
              TasteRequest r) async =>
          isPeersCall(r)
              ? usual(r)
              : DiscoveryFetchResult.ok(parse(mainPayload(
                  seeds: [
                    seedRow('h6', 'Nightcall', 'Kavinsky'),
                    seedRow('h7', 'Midnight City', 'M83'),
                  ],
                  tracks: [trackRow('Glasshouse', 'Kiasmos', 0.81)],
                )));
      hold = false;
      for (var i = 0; i < held.length; i++) {
        held[i].complete(await rotated(
            asked[asked.length - held.length + i]));
      }
      await tester.pumpAndSettle();
      expect(c.loading, isFalse);
      expect([for (final s in c.seeds) s.hash], ['h6', 'h7'],
          reason: 'the seed picker reads the new seeds');
      expect(find.text('Glasshouse'), findsOneWidget,
          reason: 'the new answer is drawn');
      expect(find.text('Dawn Chorus'), findsNothing);
      expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('discovery-new-seeds')))
              .onPressed,
          isNotNull);

      // Another list opened over Discover keeps its search, and no New
      // seeds.
      BrowserManager().setBrowserLabel('File Explorer');
      BrowserManager().addListToStack(
          [DisplayItem(server, 'music', 'directory', '/music', null, null)],
          path: '/');
      await tester.pumpAndSettle();
      expect(inBar(Icons.search), findsOneWidget);
      expect(find.byTooltip('New seeds'), findsNothing);

      // Back on Discover: New seeds again.
      BrowserManager().popBrowser();
      await tester.pumpAndSettle();
      expect(find.byTooltip('New seeds'), findsOneWidget);
      expect(inBar(Icons.search), findsNothing);
    });

    testWidgets('pull to refresh asks again', (tester) async {
      final asked = await pumpBrowser(tester);
      final before = asked.length;
      // The indicator arms at a quarter of the list's height (2600 here).
      await tester.fling(
          find.text('Dawn Chorus'), const Offset(0, 1200), 1000);
      await tester.pumpAndSettle();
      expect(asked.length, greaterThan(before));
      expect(asked.where((r) => !isPeersCall(r)), hasLength(2),
          reason: 'the library asked again');
    });
  });
}
