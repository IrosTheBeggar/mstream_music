// Instant mix as a browser listing: the frame InstantMixListing keeps on
// BrowserManager's stack — the banner item first, then a state item or the
// answer's song rows — swapped in place as answers land and let go after
// Back with the label under it put back; a stack of them for a mix of a
// mix; the album detail it closed, opened again by Back; the filters a new
// mix opens with. A widget pass draws it through the real Browser and
// BrowserToolbar: the banner, the rows, each state's line, the verbs per
// state, Filters with its badge and the strip, a re-ask's inert rows and
// line, Save's default name, and the ✦ on the album, playlist and artist
// bars.
//
// The mix route answers through FakeMix, or a mock client where the real
// controller is made, so nothing here touches the network or the audio
// service.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/instant_mix.dart';
import 'package:mstream_music/objects/mix_filters.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/discovery_widgets.dart';
import 'package:mstream_music/screens/instant_mix/instant_mix_controller.dart';
import 'package:mstream_music/screens/instant_mix/instant_mix_listing.dart';
import 'package:mstream_music/screens/instant_mix/instant_mix_widgets.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/track_capture.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';

import 'instant_mix_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Server server;
  late FakeMix mix;

  // The browser resolves on-device download badges for file rows through
  // path_provider; a VM test has no platform side, so answer it.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/nonexistent-instant-mix-test-dir');
  });

  setUp(() {
    server = mixServer();
    mix = FakeMix();
    MixFilterStore().reset();
    ServerManager().serverList
      ..clear()
      ..add(server);
    ServerManager().currentServer = server;
    BrowserManager().closeAlbumDetail();
    BrowserManager().goToNavScreen();
  });
  tearDown(() {
    BrowserManager().closeAlbumDetail();
    ServerManager().currentServer = null;
    ServerManager().serverList.clear();
  });

  InstantMixController make(MixSeed seed, {MixFilters? filters}) =>
      InstantMixController(
          seed: seed, filters: filters, fetch: mix.call, reping: (_) async {});

  DiscoveryFetchResult<MixAnswer> ok(Map<String, dynamic> m) =>
      DiscoveryFetchResult.ok(MixAnswer.fromServerMap(server, m));

  /// A compact picture of a frame: the banner, the state, the rows' titles.
  List<String> shape(List<DisplayItem> items) => [
        for (final it in items)
          switch (it.type) {
            kMixBanner => 'banner',
            kMixState => 'state:${it.data}',
            'file' => 'file:${it.metadata?.title}',
            _ => it.type,
          }
      ];

  List<DisplayItem> albums() => [
        DisplayItem(server, 'Stim Pack Volume one', 'album',
            'Stim Pack Volume one', null, null),
      ];

  group('the frame on the browser stack', () {
    test('pushed over the home, filled in place as the answer lands, let go '
        'after Back', () async {
      final c = make(MixSeed.song(doloRow(server)));
      InstantMixListing().open(c.seed, controller: c);

      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'a frame like Discover, not a route');
      expect(BrowserManager().listName, 'Instant mix');
      expect(InstantMixListing().controller, same(c));
      expect(shape(BrowserManager().browserList), ['banner', 'state:loading']);
      expect(InstantMixListing.isListing(BrowserManager().browserList), isTrue);
      expect(BrowserManager.isHomeList(BrowserManager().browserList), isFalse,
          reason: 'drawn as a listing, never as the home card grid');
      expect(mix.bodies.single['from'],
          {'song': 'demo/Boukmanflow/Dolo.mp3'});

      mix.pending.single.complete(ok(doloMix()));
      await pumpEventQueue();
      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'replaced in place, never pushed again');
      expect(shape(BrowserManager().browserList), [
        'banner',
        'file:Dolo',
        'file:Elevation',
        'file:TopRanking',
        'file:Enfance',
      ]);
      // The items ARE the controller's rows, so queue actions that fill
      // metadata in place act on what the browser shows.
      expect(BrowserManager().browserList[1], same(c.rows.first));

      BrowserManager().popBrowser();
      await pumpEventQueue();
      expect(BrowserManager().browserCache, hasLength(1));
      expect(InstantMixListing().controller, isNull);
      await c.retry();
      await pumpEventQueue();
      expect(mix.bodies, hasLength(1), reason: 'let go: it asks no more');
      expect(BrowserManager().browserCache, hasLength(1),
          reason: 'a late change never comes back as a frame');
    });

    test('opened over a list, Back puts back the label under it', () async {
      BrowserManager().setBrowserLabel('Albums');
      BrowserManager().addListToStack(albums(), alphabetical: true);
      final c = make(MixSeed.song(doloRow(server)));
      InstantMixListing().open(c.seed, controller: c);
      expect(BrowserManager().listName, 'Instant mix');

      BrowserManager().popBrowser();
      await pumpEventQueue();
      expect(BrowserManager().listName, 'Albums');
      expect(BrowserManager().browserCache, hasLength(2));
    });

    test('a mix of a mix keeps the first alive under it: Back names the bar '
        'Instant mix again, and then the list under the first', () async {
      BrowserManager().setBrowserLabel('Albums');
      BrowserManager().addListToStack(albums(), alphabetical: true);
      final first = make(MixSeed.song(doloRow(server)));
      InstantMixListing().open(first.seed, controller: first);
      mix.pending.last.complete(ok(doloMix()));
      await pumpEventQueue();

      // A row's track sheet → Instant mix: Enfance's mix over Dolo's.
      final second = make(MixSeed.song(first.rows[3]));
      InstantMixListing().open(second.seed, controller: second);
      expect(BrowserManager().browserCache, hasLength(4));
      expect(InstantMixListing().controller, same(second));
      expect(mix.bodies.last['from'], {'song': 'demo/ALM/Enfance.mp3'});
      mix.pending.last.complete(ok(relaxedMix()));
      await pumpEventQueue();

      BrowserManager().popBrowser();
      await pumpEventQueue();
      expect(InstantMixListing().controller, same(first),
          reason: 'the first mix is alive under the second');
      expect(BrowserManager().listName, 'Instant mix');
      expect(shape(BrowserManager().browserList).take(2), ['banner', 'file:Dolo']);

      // It still follows its controller: a re-ask lands in its frame.
      final apply = first.apply(skipLive);
      mix.pending.last.complete(ok(relaxedMix()));
      await apply;
      await pumpEventQueue();
      expect(shape(BrowserManager().browserList),
          ['banner', 'file:Dolo', 'file:Enfance', 'file:The Hangout']);

      BrowserManager().popBrowser();
      await pumpEventQueue();
      expect(BrowserManager().listName, 'Albums');
      expect(InstantMixListing().controller, isNull);
    });

    test('a stack reset (a server switch) lets every mix go, and the label '
        'is the reset\'s', () async {
      BrowserManager().setBrowserLabel('Albums');
      BrowserManager().addListToStack(albums(), alphabetical: true);
      final first = make(MixSeed.song(doloRow(server)));
      InstantMixListing().open(first.seed, controller: first);
      final second = make(MixSeed.artist(server, 'ALM'));
      InstantMixListing().open(second.seed, controller: second);

      BrowserManager().goToNavScreen();
      await pumpEventQueue();
      expect(InstantMixListing().controller, isNull);
      expect(BrowserManager().browserCache, hasLength(1));
      expect(await BrowserManager().browserLabelStream.first, 'Browser');
      // Their late answers find no frame.
      for (final p in mix.pending) {
        p.complete(ok(doloMix()));
      }
      await pumpEventQueue();
      expect(BrowserManager().browserCache, hasLength(1));
    });
  });

  group('the filters a new mix opens with', () {
    // The real path: open() makes the controller, which asks ApiManager —
    // its pooled client is the mock here.
    late List<Map<String, dynamic>> asked;

    setUp(() {
      asked = [];
      http.runWithClient(
          () => ApiManager().resetDirectClient(),
          () => MockClient((req) async {
                if (req.url.path != '/api/v1/discovery/local/mix') {
                  return http.Response('not found', 404);
                }
                asked.add(jsonDecode(req.body) as Map<String, dynamic>);
                return http.Response(jsonEncode(doloMix()), 200,
                    headers: {'content-type': 'application/json'});
              }));
    });
    tearDown(() => ApiManager().resetDirectClient());

    test('the last ones applied on any mix page; an older mix keeps its own',
        () async {
      final dolo = MixSeed.song(doloRow(server));
      InstantMixListing().open(dolo);
      await pumpEventQueue();
      final first = InstantMixListing().controller!;
      expect(first.filters, MixFilters.empty);
      expect(asked.single,
          {'from': {'song': 'demo/Boukmanflow/Dolo.mp3'}, 'limit': 50});

      // Done on the first page (what applyMixFilters does).
      MixFilterStore().set(dolo, skipLive);
      await first.apply(skipLive);

      // A row's mix: it opens, and asks, under them.
      final enfance = MixSeed.song(first.rows[3]);
      InstantMixListing().open(enfance);
      await pumpEventQueue();
      final second = InstantMixListing().controller!;
      expect(second.filters, skipLive);
      expect(asked.last['skipWords'], ['live']);
      expect(asked.last['from'], {'song': 'demo/ALM/Enfance.mp3'});

      MixFilterStore().set(enfance, skipRemix);
      await second.apply(skipRemix);
      BrowserManager().popBrowser();
      await pumpEventQueue();
      expect(InstantMixListing().controller, same(first));
      expect(first.filters, skipLive, reason: 'its own, as it left them');
      expect(MixFilterStore().of(dolo), skipRemix,
          reason: 'the next mix opens with the newest');
    });
  });

  group('drawn by the browser', () {
    // Over an Albums list, as from an album's song: the home's cards read
    // the audio service, which a widget test does not start.
    setUp(() {
      BrowserManager().setBrowserLabel('Albums');
      BrowserManager().addListToStack(albums(), alphabetical: true);
    });

    Future<InstantMixController> pumpMix(WidgetTester tester,
        {MixSeed? seed, MixFilters? filters, double width = 390}) async {
      tester.view.physicalSize = Size(width * 3, 2600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const Scaffold(appBar: BrowserToolbar(), body: Browser()),
      ));
      final c = make(seed ?? MixSeed.song(doloRow(server)), filters: filters);
      InstantMixListing().open(c.seed, controller: c);
      await tester.pumpAndSettle();
      return c;
    }

    // A change that reaches the browser through its stream lands a frame
    // later: the event is delivered after the pump that would draw it.
    Future<void> settleStream(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    Future<void> answer(WidgetTester tester, Map<String, dynamic> m) async {
      mix.pending.last.complete(ok(m));
      await tester.pumpAndSettle();
    }

    Finder inBar(IconData icon) => find.descendant(
        of: find.byType(BrowserToolbar), matching: find.byIcon(icon));
    Finder inBanner(String text) => find.descendant(
        of: find.byKey(const ValueKey('mix-banner')), matching: find.text(text));

    testWidgets('loading: the banner names the seed at once, placeholder '
        'rows under it; the bar is Back and the label', (tester) async {
      await pumpMix(tester);
      expect(inBanner('Dolo'), findsOneWidget);
      expect(inBanner('Boukmanflow'), findsOneWidget);
      expect(find.byType(DiscoverySkeleton), findsOneWidget);
      expect(inBar(Icons.arrow_back), findsOneWidget);
      expect(find.descendant(
              of: find.byType(BrowserToolbar),
              matching: find.text('Instant mix')),
          findsOneWidget);
      for (final verb in [
        Icons.shuffle,
        Icons.play_arrow,
        Icons.library_add,
        Icons.playlist_add_check,
        Icons.search,
      ]) {
        expect(inBar(verb), findsNothing, reason: '$verb');
      }
      await answer(tester, doloMix());
    });

    testWidgets("ready: the browser's song rows, title and artist, no "
        'numbers; the verbs after the label, in order', (tester) async {
      await pumpMix(tester);
      await answer(tester, doloMix());
      expect(tester.takeException(), isNull, reason: 'no overflow at 390 px');
      expect(find.byType(DiscoverySkeleton), findsNothing);
      for (final title in ['Elevation', 'TopRanking', 'Enfance']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Dolo'), findsNWidgets(2),
          reason: 'the banner, and the seed leading its mix');
      expect(find.text('ALM'), findsNWidgets(2));
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining(RegExp(r'\d')), findsNothing,
          reason: 'no counts, years or match figures');

      final xs = [
        tester.getRect(find.descendant(
            of: find.byType(BrowserToolbar),
            matching: find.text('Instant mix'))).right,
        for (final verb in [
          Icons.shuffle,
          Icons.play_arrow,
          Icons.library_add,
          Icons.playlist_add_check,
        ])
          tester.getRect(inBar(verb)).left,
      ];
      expect([...xs]..sort(), xs, reason: 'label · Shuffle · Play · Add All · Save');
      expect(find.byTooltip('Save as playlist'), findsOneWidget);
      expect(inBar(Icons.search), findsNothing, reason: 'no search on a mix');
    });

    testWidgets('a narrow phone: the label ellipsizes, nothing overflows',
        (tester) async {
      await pumpMix(tester, width: 320);
      await answer(tester, doloMix());
      expect(tester.takeException(), isNull);
      expect(inBar(Icons.playlist_add_check), findsOneWidget);
    });

    testWidgets('each empty state: its one line, and no verbs',
        (tester) async {
      final cases = <String, Map<String, dynamic>>{
        'Not analyzed yet': {'notAnalyzed': true, 'songs': []},
        'Nothing similar yet': {
          'songs': [
            mixSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow'),
          ],
          'filteredOut': false,
        },
        'No songs match your filters': {'songs': [], 'filteredOut': true},
      };
      await pumpMix(tester);
      var first = true;
      for (final MapEntry(key: line, value: payload) in cases.entries) {
        if (!first) {
          final c = make(MixSeed.song(doloRow(server)));
          InstantMixListing().open(c.seed, controller: c);
          await tester.pumpAndSettle();
        }
        first = false;
        await answer(tester, payload);
        expect(find.text(line), findsOneWidget, reason: line);
        expect(find.byType(DiscoverySkeleton), findsNothing);
        expect(find.text('Try again'), findsNothing);
        expect(inBanner('Dolo'), findsOneWidget, reason: 'the banner stays');
        for (final verb in [
          Icons.shuffle,
          Icons.play_arrow,
          Icons.library_add,
          Icons.playlist_add_check,
        ]) {
          expect(inBar(verb), findsNothing, reason: '$line: $verb');
        }
        BrowserManager().popBrowser();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('switched off: its line, no verbs', (tester) async {
      await pumpMix(tester);
      mix.pending.last.complete(const DiscoveryFetchResult.disabled());
      await tester.pumpAndSettle();
      expect(find.text('Sonic discovery has been switched off on this server.'),
          findsOneWidget);
      expect(inBar(Icons.play_arrow), findsNothing);
    });

    testWidgets('failed: the line and Try again, which asks again and draws '
        'the rows', (tester) async {
      await pumpMix(tester);
      mix.pending.last.complete(const DiscoveryFetchResult.error());
      await tester.pumpAndSettle();
      expect(find.text("Couldn't build the mix"), findsOneWidget);
      expect(inBar(Icons.play_arrow), findsNothing);
      await tester.tap(find.text('Try again'));
      await settleStream(tester);
      expect(mix.bodies, hasLength(2));
      expect(find.byType(DiscoverySkeleton), findsOneWidget);
      await answer(tester, doloMix());
      expect(find.text('Enfance'), findsOneWidget);
      expect(inBar(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('a re-ask: the rows stay up but inert, the line runs under '
        'the banner, the verbs are off; the answer replaces the rows',
        (tester) async {
      final c = await pumpMix(tester);
      await answer(tester, doloMix());
      Finder line() => find.descendant(
          of: find.byKey(const ValueKey('mix-banner')),
          matching: find.byType(LinearProgressIndicator));
      expect(line(), findsNothing);

      unawaited(c.apply(skipLive));
      await settleStream(tester);
      expect(line(), findsOneWidget);
      expect(find.text('Elevation'), findsOneWidget, reason: 'the old rows');
      expect(
          tester
              .widgetList<IgnorePointer>(find.ancestor(
                  of: find.text('Elevation'),
                  matching: find.byType(IgnorePointer)))
              .any((w) => w.ignoring),
          isTrue,
          reason: 'the rows are inert');
      for (final verb in [Icons.shuffle, Icons.library_add, Icons.playlist_add_check]) {
        expect(
            tester
                .widget<IconButton>(find.ancestor(
                    of: inBar(verb), matching: find.byType(IconButton)))
                .onPressed,
            isNull,
            reason: '$verb is off while it asks');
      }

      await answer(tester, relaxedMix());
      expect(line(), findsNothing);
      expect(find.text('Elevation'), findsNothing);
      expect(find.text('The Hangout'), findsOneWidget);
      expect(
          tester
              .widget<IconButton>(find.ancestor(
                  of: inBar(Icons.shuffle), matching: find.byType(IconButton)))
              .onPressed,
          isNotNull);
    });

    testWidgets('a failed re-ask: the rows stay, the filters go back, and '
        'the snackbar says so', (tester) async {
      final c = await pumpMix(tester);
      await answer(tester, doloMix());
      final context = tester.element(find.byType(Browser));
      final done = applyMixFilters(context, c, skipLive);
      await tester.pump();
      mix.pending.last.complete(const DiscoveryFetchResult.error());
      await done;
      await settleStream(tester);
      expect(find.widgetWithText(SnackBar, "Couldn't build the mix"),
          findsOneWidget);
      expect(c.filters, MixFilters.empty);
      expect(MixFilterStore().of(c.seed), MixFilters.empty,
          reason: 'the next mix opens with what the rows were built with');
      expect(find.text('Elevation'), findsOneWidget);
      expect(find.text("Couldn't build the mix"), findsOneWidget,
          reason: 'the snackbar only: no line in place of the rows');
    });

    Finder filtersButton() => find.byKey(const ValueKey('mood-filters'));
    final strip = find.byKey(const ValueKey('mood-strip'));

    testWidgets("Filters after the label; its sheet's Done asks again, once, "
        'under the draft; the badge counts what is set and the strip names '
        'it, with Clear', (tester) async {
      server.moodFiltersAvailable = true;
      final c = await pumpMix(tester);
      await answer(tester, doloMix());
      expect(tester.takeException(), isNull, reason: 'no overflow at 390 px');
      expect(filtersButton(), findsOneWidget);
      expect(
          tester.getRect(filtersButton()).left,
          greaterThanOrEqualTo(tester
              .getRect(find.descendant(
                  of: find.byType(BrowserToolbar),
                  matching: find.text('Instant mix')))
              .right));
      expect(tester.getRect(filtersButton()).right,
          lessThanOrEqualTo(tester.getRect(inBar(Icons.shuffle)).left));
      expect(strip, findsNothing, reason: 'nothing set');

      await tester.tap(filtersButton());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mix-filter-mood')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relaxed'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mix-filter-harmonic')));
      await tester.pumpAndSettle();
      expect(mix.bodies, hasLength(1), reason: 'nothing asked before Done');
      await tester.tap(find.byKey(const ValueKey('auto-dj-sheet-done')));
      await settleStream(tester);
      expect(mix.bodies, hasLength(2), reason: 'one request');
      expect(mix.bodies.last['moods'], {'energy': 'relaxed'});
      expect(mix.bodies.last['requireMusicalKey'], isTrue);
      expect(tester.widget<IconButton>(filtersButton()).onPressed, isNull,
          reason: 'off while it asks');

      await answer(tester, relaxedMix());
      expect(c.filters.count, 2);
      expect(
          find.descendant(of: filtersButton(), matching: find.text('2')),
          findsOneWidget);
      expect(strip, findsOneWidget);
      expect(find.descendant(
              of: strip, matching: find.text('Relaxed · Harmonic mixing')),
          findsOneWidget);
      expect(
          tester.getRect(strip).bottom,
          lessThanOrEqualTo(tester
              .getRect(find.byKey(const ValueKey('mix-banner')))
              .top),
          reason: 'under the bar, above the banner');
      expect(MixFilterStore().of(c.seed), c.filters,
          reason: 'kept for the next mix');

      // The strip's Clear asks again with nothing set, at once.
      await tester.tap(find.byKey(const ValueKey('mood-strip-clear')));
      await settleStream(tester);
      expect(mix.bodies.last,
          {'from': {'song': 'demo/Boukmanflow/Dolo.mp3'}, 'limit': 50});
      await answer(tester, doloMix());
      expect(strip, findsNothing);
      expect(c.filters, MixFilters.empty);
      expect(MixFilterStore().of(c.seed), MixFilters.empty);
    });

    testWidgets('Filters and the strip when the filters emptied the list; '
        'neither for nothing similar or not analyzed', (tester) async {
      final c = await pumpMix(tester, filters: skipLive);
      expect(filtersButton(), findsOneWidget,
          reason: 'carried filters show while the first answer is out');
      expect(strip, findsOneWidget);
      await answer(tester, {'songs': [], 'filteredOut': true});
      expect(c.state, InstantMixState.noMatch);
      expect(filtersButton(), findsOneWidget, reason: 'the way back out');
      expect(find.descendant(of: strip, matching: find.text('live')),
          findsOneWidget);
      BrowserManager().popBrowser();
      await tester.pumpAndSettle();

      for (final payload in [
        {'notAnalyzed': true, 'songs': []},
        {
          'songs': [
            mixSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow'),
          ],
        },
      ]) {
        final d = make(MixSeed.song(doloRow(server)));
        InstantMixListing().open(d.seed, controller: d);
        await tester.pumpAndSettle();
        await answer(tester, payload);
        expect(filtersButton(), findsNothing, reason: '$payload');
        expect(strip, findsNothing);
        BrowserManager().popBrowser();
        await tester.pumpAndSettle();
      }
    });

    // A row's tap reaches the browser's own tap handling with the row it
    // shows: an armed pick (TrackCapture, checked before the tap
    // behaviour queues) receives it, so nothing touches the audio service.
    testWidgets("a row taps through the browser's tap handling",
        (tester) async {
      final c = await pumpMix(tester);
      await answer(tester, doloMix());
      DisplayItem? got;
      TrackCapture.arm(TrackCaptureRequest(
          server: server, bannerLabel: (_) => '', onPicked: (i) => got = i));
      addTearDown(TrackCapture.cancel);
      await tester.tap(find.text('TopRanking'));
      await tester.pump();
      expect(got, same(c.rows[2]));
    });

    testWidgets('Save as playlist: the picker, whose New playlist offers '
        '"Dolo Mix 2" when "Dolo Mix" is taken', (tester) async {
      server.playlists
        ..clear()
        ..addAll(['Dolo Mix', 'Road trip']);
      await pumpMix(tester);
      await answer(tester, doloMix());
      await tester.tap(find.byTooltip('Save as playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Road trip'), findsOneWidget,
          reason: 'an existing playlist can be picked (and overwritten)');
      await tester.tap(find.text('New playlist'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'Dolo Mix 2');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.playlists, ['Dolo Mix', 'Road trip'],
          reason: 'nothing saved');
    });

    testWidgets("the bar's Back: the mix goes, and the label under it comes "
        'back', (tester) async {
      await pumpMix(tester);
      await answer(tester, doloMix());
      await tester.tap(inBar(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(InstantMixListing().controller, isNull);
      expect(find.text('Albums'), findsOneWidget);
    });

    testWidgets('opened from an album detail: the detail closes, and Back '
        'opens it again', (tester) async {
      await pumpMix(tester);
      await answer(tester, doloMix());
      BrowserManager().popBrowser();
      await tester.pumpAndSettle();

      final album = albums().single;
      BrowserManager().openAlbumDetail(album);
      await tester.pump();
      final c = make(MixSeed.album(album));
      openInstantMix(tester.element(find.byType(Browser)), c.seed,
          controller: c);
      await tester.pump();
      expect(BrowserManager().albumDetail, isNull);
      expect(InstantMixListing().controller, same(c));
      expect(mix.bodies.last['from'], {
        'album': {'album': 'Stim Pack Volume one'},
      });
      await answer(tester, doloMix());

      await tester.tap(inBar(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(BrowserManager().albumDetail, same(album));
      expect(InstantMixListing().controller, isNull);
    });
  });

  group('the ✦ on the album, playlist and artist bars', () {
    Future<void> pumpBar(WidgetTester tester, {double width = 390}) async {
      tester.view.physicalSize = Size(width * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const Scaffold(appBar: BrowserToolbar(), body: SizedBox()),
      ));
      await tester.pumpAndSettle();
    }

    Finder inBar(IconData icon) => find.descendant(
        of: find.byType(BrowserToolbar), matching: find.byIcon(icon));
    List<DisplayItem> songs() => [doloRow(server)];

    testWidgets("an album's bar: ✦ first, before Shuffle — for a named album "
        'on a server that can mix', (tester) async {
      final album = albums().single;
      BrowserManager().openAlbumDetail(album);
      BrowserManager().albumDetailSongs = songs();
      await pumpBar(tester);
      expect(inBar(Icons.auto_awesome), findsOneWidget);
      expect(find.byTooltip('Instant mix'), findsOneWidget);
      expect(tester.getRect(inBar(Icons.auto_awesome)).right,
          lessThanOrEqualTo(tester.getRect(inBar(Icons.shuffle)).left));
      expect(tester.takeException(), isNull);

      // The singles bucket is no album.
      BrowserManager().openAlbumDetail(
          DisplayItem(server, 'SINGLES', 'album', null, null, null));
      BrowserManager().albumDetailSongs = songs();
      await tester.pumpAndSettle();
      expect(inBar(Icons.auto_awesome), findsNothing);

      // Still scanning: hidden, never greyed.
      server.discoveryReady = false;
      BrowserManager().openAlbumDetail(album);
      BrowserManager().albumDetailSongs = songs();
      await tester.pumpAndSettle();
      expect(inBar(Icons.auto_awesome), findsNothing);
      expect(inBar(Icons.shuffle), findsOneWidget);
    });

    testWidgets("a playlist's bar: ✦ before Shuffle; on a narrow phone its "
        'search, Download and Shuffle move into ⋮', (tester) async {
      BrowserManager().addListToStack(songs(), playlist: 'Road trip');
      await pumpBar(tester);
      expect(tester.getRect(inBar(Icons.auto_awesome)).right,
          lessThanOrEqualTo(tester.getRect(inBar(Icons.shuffle)).left));
      expect(inBar(Icons.search), findsOneWidget);
      expect(inBar(Icons.download_sharp), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpBar(tester, width: 320);
      expect(tester.takeException(), isNull, reason: 'nothing clipped');
      expect(inBar(Icons.auto_awesome), findsOneWidget);
      expect(inBar(Icons.play_arrow), findsOneWidget);
      expect(inBar(Icons.library_add), findsOneWidget);
      expect(inBar(Icons.shuffle), findsNothing);
      expect(inBar(Icons.search), findsNothing);
      expect(inBar(Icons.more_vert), findsOneWidget);

      // Without Instant mix the playlist bar is as it was, narrow or not.
      server.instantMixGeneration = null;
      BrowserManager().updateStream();
      await tester.pumpAndSettle();
      expect(inBar(Icons.auto_awesome), findsNothing);
      expect(inBar(Icons.search), findsOneWidget);
      expect(inBar(Icons.shuffle), findsOneWidget);
    });

    testWidgets("an artist's albums: ✦ before search", (tester) async {
      BrowserManager().setBrowserLabel('Artists');
      BrowserManager()
          .addListToStack(albums(), artist: (server: server, name: 'ALM'));
      await pumpBar(tester);
      expect(tester.getRect(inBar(Icons.auto_awesome)).right,
          lessThanOrEqualTo(tester.getRect(inBar(Icons.search)).left));

      // Any other album list: none.
      BrowserManager().setBrowserLabel('Albums');
      BrowserManager().addListToStack(albums(), alphabetical: true);
      await tester.pumpAndSettle();
      expect(inBar(Icons.auto_awesome), findsNothing);
      expect(inBar(Icons.search), findsOneWidget);
    });

    testWidgets('a connected server\'s items: never', (tester) async {
      final peer = Server('federated://home/3', null, null, null, 'peer-3')
        ..federationParent = 'home'
        ..federationPeerId = 3
        ..parentServer = server
        ..discoveryEnabled = true
        ..discoveryReady = true
        ..instantMixGeneration = 1;
      BrowserManager().addListToStack(
          [DisplayItem(peer, 'Blurred', 'album', 'Blurred', null, null)],
          artist: (server: peer, name: 'Sam'));
      await pumpBar(tester);
      expect(inBar(Icons.auto_awesome), findsNothing);
    });
  });
}
