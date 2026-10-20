// What the user's server is copying for them (the design canvas's
// PhoneCopies board): the Copies sheet in every state — loading, the list
// failing, nothing copying, every row's state and verb, Cancel (and the
// cancel that lost the race), Retry, Clear finished — the home's SERVER
// "Copies" row (only where copies are possible, with its live counts), the
// toasts a copy's start and end raise, and German at 1.3×.
//
// The plug-in API is the scripted fake behind the real DiscoveryPluginsApi;
// the poll's timers are the test's; nothing touches the network.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/copies_sheet.dart';
import 'package:mstream_music/screens/discovery/copy_news.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/discovery_listing.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

import 'discovery_keep_fixtures.dart';
import 'discovery_copies_fixtures.dart';
import 'discovery_plugin_fakes.dart';

Finder inRow(Map<String, dynamic> job, Finder matching) => find.descendant(
  of: find.byKey(ValueKey('copies-row-${job['id']}')),
  matching: matching,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SheetHarness();

  setUpAll(mockPathProvider);
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<void> frames(WidgetTester tester, [int n = 6]) =>
      KeepHarness.pumpFor(tester, n);

  group('the Copies sheet', () {
    testWidgets(
      'loading: still rows at the real row height, then the rows in place',
      (tester) async {
        h.fake.listGate = Completer<void>();
        h.fake.addJob(tapes, scope: 'album', state: 'running', progress: 0.45);
        await h.pumpCopies(tester);
        expect(find.byKey(const ValueKey('copies-loading')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('copies-skeleton-row')),
          findsNWidgets(3),
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const ValueKey('copies-clear')), findsNothing);
        h.fake.listGate!.complete();
        h.fake.listGate = null;
        await frames(tester);
        expect(find.byKey(const ValueKey('copies-loading')), findsNothing);
        expect(find.text('Borrowed Tapes'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'every live and failed row: its title, "Kind · Artist · from Server", '
      'its bar or state, and its one verb',
      (tester) async {
        final running = h.fake.addJob(
          tapes,
          scope: 'album',
          state: 'running',
          progress: 0.45,
          statusText: 'song 2 of 3 · Late Train Verse',
        );
        final waiting = h.fake.addJob(brass);
        final failed = h.fake.addJob(lullaby, state: 'failed');
        failed['error'] = 'Stage Peer C is unreachable';
        final quota = h.fake.addJob(
          tapes,
          scope: 'artist',
          state: 'done',
          result: many(copied: 1, stopped: 'quota'),
        );
        final refused = h.fake.addJob(
          sessions,
          scope: 'album',
          state: 'done',
          result: many(stopped: 'refused'),
        );
        final none = h.fake.addJob(
          transmission,
          scope: 'album',
          state: 'done',
          result: many(failed: 2),
        );
        await h.pumpCopies(tester, height: 1400);
        expect(tester.takeException(), isNull);

        expect(find.text('Copies'), findsOneWidget);
        expect(find.text('Copying 2 · 4 failed'), findsOneWidget);
        expect(find.text('COPYING'), findsOneWidget);
        expect(find.text('STOPPED OR FAILED'), findsOneWidget);
        expect(find.text('JUST FINISHED'), findsNothing);

        // Running: the bar, the server's status line, Cancel.
        expect(inRow(running, find.text('Borrowed Tapes')), findsOneWidget);
        expect(
          inRow(running, find.text('Album · Boukmanflow · from Stage Peer B')),
          findsOneWidget,
        );
        final bar = tester.widget<LinearProgressIndicator>(
          inRow(running, find.byKey(const ValueKey('copies-bar'))),
        );
        expect(bar.value, 0.45);
        expect(
          inRow(running, find.text('song 2 of 3 · Late Train Verse')),
          findsOneWidget,
        );
        expect(inRow(running, find.text('Cancel')), findsOneWidget);

        // Waiting: no bar, starts on its own, Cancel.
        expect(
          inRow(waiting, find.text('Song · ALM · from Stage Peer B')),
          findsOneWidget,
        );
        expect(
          inRow(waiting, find.byKey(const ValueKey('copies-bar'))),
          findsNothing,
        );
        expect(
          inRow(waiting, find.text('Waiting for a free slot')),
          findsOneWidget,
        );
        expect(inRow(waiting, find.text('Starts on its own')), findsOneWidget);
        expect(inRow(waiting, find.text('Cancel')), findsOneWidget);

        // Failed: the server's words verbatim under "Copy failed", Retry.
        expect(
          inRow(
            failed,
            find.text('Song · Night Owl Radio · from Stage Peer C'),
          ),
          findsOneWidget,
        );
        expect(inRow(failed, find.text('Copy failed')), findsOneWidget);
        expect(
          inRow(failed, find.text('Stage Peer C is unreachable')),
          findsOneWidget,
        );
        expect(inRow(failed, find.text('Retry')), findsOneWidget);

        // Stopped by the transfer limit: its reason and what landed, Retry.
        expect(
          inRow(quota, find.text('Every album by Boukmanflow')),
          findsOneWidget,
        );
        expect(
          inRow(quota, find.text('Every album · from Stage Peer B')),
          findsOneWidget,
        );
        expect(inRow(quota, find.text('Stopped')), findsOneWidget);
        expect(
          inRow(
            quota,
            find.text("Stage Peer B's transfer limit stopped it · 1 copied"),
          ),
          findsOneWidget,
        );
        expect(inRow(quota, find.text('Retry')), findsOneWidget);

        // Refused: the same key meets the same refusal — no Retry.
        expect(
          inRow(
            refused,
            find.text(
              "Stage Peer B does not allow copies with your server's key · nothing copied",
            ),
          ),
          findsOneWidget,
        );
        expect(inRow(refused, find.text('Retry')), findsNothing);

        // Copied 0 with failures is a failure, never "already yours".
        expect(
          inRow(none, find.text('Nothing copied · 2 failed')),
          findsOneWidget,
        );
        expect(inRow(none, find.text('Retry')), findsOneWidget);
        expect(find.text('Already yours'), findsNothing);

        // Clear finished at the bottom; the sheet polls fast while open.
        expect(find.byKey(const ValueKey('copies-clear')), findsOneWidget);
        expect(h.timers.active!.delay, DiscoveryJobsController.kFastBeat);
      },
    );

    testWidgets(
      'Cancel a waiting copy (gone at once, "Stopped · nothing was copied", '
      'Add again) and a running one (Stopping…, no buttons); a copy that '
      'ends lands in Just finished with Play and Add to queue',
      (tester) async {
        final run = h.fake.addJob(orchard, state: 'running', progress: 0.3);
        final wait = h.fake.addJob(brass);
        await h.pumpCopies(tester, height: 1200);

        await tester.tap(inRow(wait, find.text('Cancel')));
        await frames(tester);
        expect(h.fake.count('POST', '/plugin-jobs/${wait['id']}/cancel'), 1);
        expect(find.text('JUST FINISHED'), findsOneWidget);
        expect(
          inRow(wait, find.text('Stopped · nothing was copied')),
          findsOneWidget,
        );
        expect(inRow(wait, find.text('Add again')), findsOneWidget);

        await tester.tap(inRow(run, find.text('Cancel')));
        await frames(tester);
        expect(inRow(run, find.text('Stopping…')), findsOneWidget);
        expect(inRow(run, find.text('Cancel')), findsNothing);
        final bar = tester.widget<LinearProgressIndicator>(
          inRow(run, find.byKey(const ValueKey('copies-bar'))),
        );
        expect(
          bar.color,
          VelvetColors.textTertiary,
          reason: 'the bar holds in text3',
        );

        // It ends having copied the song: In your collection, its folder.
        run['state'] = 'done';
        run['cancelRequested'] = false;
        run['result'] = {
          'copied': {
            'vpath': 'copies',
            'filepath':
                'copies/ALM/Free Instrumentals Vol. 9/Midnight Orchard.mp3',
            'bytes': 1000,
          },
        };
        h.timers.active!.fire();
        await frames(tester);
        expect(inRow(run, find.text('In your collection')), findsOneWidget);
        expect(
          inRow(run, find.text('copies › ALM › Free Instrumentals Vol. 9')),
          findsOneWidget,
        );
        expect(inRow(run, find.text('Play')), findsOneWidget);
        expect(
          inRow(run, find.byKey(const ValueKey('copies-queue'))),
          findsOneWidget,
        );
        expect(find.text('COPYING'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a cancel that lost the race (409): the row turns into its outcome '
      'and a toast says nothing was cancelled',
      (tester) async {
        final run = h.fake.addJob(tapes, scope: 'album', state: 'running');
        await h.pumpCopies(tester);
        // It ends on the server before the cancel reaches it.
        run['state'] = 'done';
        run['result'] = many(copied: 3);
        await tester.tap(inRow(run, find.text('Cancel')));
        await frames(tester);
        expect(h.toasts, contains('Already finished · nothing to cancel'));
        expect(inRow(run, find.text('In your collection')), findsOneWidget);
        expect(inRow(run, find.text('3 copied')), findsOneWidget);
        expect(find.text('JUST FINISHED'), findsOneWidget);
      },
    );

    testWidgets(
      'Retry starts the same copy again (the row as the job holds it, its '
      'scope); the old failure is superseded',
      (tester) async {
        final failed = h.fake.addJob(
          transmission,
          scope: 'album',
          state: 'done',
          result: many(failed: 2),
        );
        await h.pumpCopies(tester);
        await tester.tap(inRow(failed, find.text('Retry')));
        await frames(tester);
        final body =
            jsonDecode(
                  h.fake
                      .calls('POST', '/plugins/federation-copy/jobs')
                      .last
                      .body,
                )
                as Map;
        expect(body['recommendation'], jsonDecode(jsonEncode(transmission)));
        expect(body['scope'], 'album');
        expect(find.text('Waiting for a free slot'), findsOneWidget);
        expect(inRow(failed, find.text('Retry')), findsNothing);
        expect(find.text('Copying 1'), findsOneWidget);
      },
    );

    testWidgets('a refused Retry says the server\'s words in a toast', (
      tester,
    ) async {
      h.fake.addJob(lullaby, state: 'failed');
      await h.pumpCopies(tester);
      h.fake.refuse['/plugins/federation-copy/jobs'] = (
        429,
        'you have 20 jobs queued or running',
      );
      await tester.tap(find.text('Retry'));
      await frames(tester);
      expect(h.toasts, ['you have 20 jobs queued or running']);
    });

    testWidgets('Clear finished drops the finished rows on the server', (
      tester,
    ) async {
      final ok = h.fake.addJob(orchard, state: 'running');
      final bad = h.fake.addJob(lullaby, state: 'failed');
      await h.pumpCopies(tester);
      ok['state'] = 'done';
      ok['result'] = {
        'copied': {'filepath': 'copies/ALM/Free/Midnight Orchard.mp3'},
      };
      h.timers.active!.fire();
      await frames(tester);
      expect(find.text('JUST FINISHED'), findsOneWidget);
      expect(find.text('STOPPED OR FAILED'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('copies-clear')));
      await frames(tester);
      expect(h.fake.count('POST', '/plugin-jobs/clear'), 1);
      expect(find.byKey(ValueKey('copies-row-${bad['id']}')), findsNothing);
      expect(find.byKey(ValueKey('copies-row-${ok['id']}')), findsNothing);
      expect(find.text('Nothing copying'), findsOneWidget);
      expect(find.byKey(const ValueKey('copies-clear')), findsNothing);
    });

    testWidgets('the finished outcomes: already yours, you have it all, a file '
        'already there (Retry), nothing of theirs to copy', (tester) async {
      final owned = h.fake.addJob(tapes, state: 'running');
      final all = h.fake.addJob(
        sessions,
        scope: 'artist-missing',
        state: 'running',
      );
      final exists = h.fake.addJob(brass, state: 'running');
      final guest = h.fake.addJob(orchard, scope: 'artist', state: 'running');
      await h.pumpCopies(tester, height: 1400);
      owned['state'] = 'done';
      owned['result'] = {
        'skipped': 'owned',
        'existing': {'filepath': 'music/Boukmanflow/Late Train Verse.mp3'},
      };
      all['state'] = 'done';
      all['result'] = many();
      exists['state'] = 'done';
      exists['result'] = {
        'skipped': 'exists',
        'filepath': 'copies/ALM/Free Instrumentals Vol. 9/Brass District.mp3',
      };
      guest['state'] = 'done';
      guest['result'] = {
        ...many(),
        'skippedAlbums': [
          {'name': 'Guest', 'why': 'appearance'},
        ],
      };
      h.timers.active!.fire();
      await frames(tester);
      expect(inRow(owned, find.text('Already yours')), findsOneWidget);
      expect(
        inRow(owned, find.text('Your library has this song')),
        findsOneWidget,
      );
      expect(inRow(owned, find.text('Play')), findsOneWidget);
      expect(
        inRow(all, find.text("Color Out · albums you don't have")),
        findsOneWidget,
      );
      expect(
        inRow(all, find.text("What you're missing · from Stage Peer B")),
        findsOneWidget,
      );
      expect(inRow(all, find.text('You have it all')), findsOneWidget);
      expect(
        inRow(all, find.text('Nothing to copy from Stage Peer B')),
        findsOneWidget,
      );
      expect(
        inRow(exists, find.text('Skipped · a file is already there')),
        findsOneWidget,
      );
      expect(
        inRow(exists, find.text('copies › ALM › Free Instrumentals Vol. 9')),
        findsOneWidget,
      );
      expect(
        inRow(guest, find.text('Nothing of theirs to copy')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the list failing: the sentence, the server\'s words when it sent '
      'some, Try again',
      (tester) async {
        h.fake.refuse['/api/v1/discovery/plugin-jobs'] = (
          500,
          'database is locked',
        );
        await h.pumpCopies(tester);
        expect(find.text("Couldn't load your copies"), findsOneWidget);
        expect(find.text('database is locked'), findsOneWidget);
        h.fake.refuse.clear();
        h.fake.addJob(brass);
        await tester.tap(find.byKey(const ValueKey('copies-try-again')));
        await frames(tester);
        expect(find.text('Brass District'), findsOneWidget);
      },
    );

    testWidgets(
      'the list failing without words: "Your server didn\'t answer"',
      (tester) async {
        h.fake.refuse['/api/v1/discovery/plugin-jobs'] = (502, '');
        await h.pumpCopies(tester);
        expect(
          find.text("Your server didn't answer. Copies keep running there."),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'nothing copying: the short sheet, Open Discover only from the home',
      (tester) async {
        await h.pumpCopies(tester, fromHome: true);
        expect(find.text('Nothing copying'), findsOneWidget);
        expect(
          find.text(
            "Long-press a connected server's song or album on Discover to keep a copy.",
          ),
          findsOneWidget,
        );
        expect(find.text('Open Discover'), findsOneWidget);
        expect(find.byKey(const ValueKey('copies-clear')), findsNothing);
      },
    );

    testWidgets('nothing copying from Discover: no Open Discover', (
      tester,
    ) async {
      await h.pumpCopies(tester);
      expect(find.text('Nothing copying'), findsOneWidget);
      expect(find.text('Open Discover'), findsNothing);
    });

    testWidgets(
      'German at 1.3× on 360 px: everything wraps, nothing overflows',
      (tester) async {
        h.fake.addJob(
          tapes,
          scope: 'album',
          state: 'running',
          progress: 0.5,
          statusText: '1 of 3 songs · 7.4 MB · Late Train Verse',
        );
        h.fake.addJob(brass);
        final f = h.fake.addJob(lullaby, state: 'failed');
        f['error'] = 'Stage Peer C is unreachable';
        h.fake.addJob(
          tapes,
          scope: 'artist',
          state: 'done',
          result: many(copied: 1, stopped: 'quota'),
        );
        await h.pumpCopies(
          tester,
          width: 360,
          height: 780,
          textScale: 1.3,
          locale: const Locale('de'),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Kopien'), findsOneWidget);
        expect(find.text('WIRD KOPIERT'), findsOneWidget);
        expect(find.text('Erledigte entfernen'), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('copies-list')),
          const Offset(0, -600),
        );
        await frames(tester);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group("the home's SERVER Copies row", () {
    setUp(() {
      CopiesHub().makeJobs = h.make;
      CopiesHub().toast = h.toasts.add;
      CopiesHub().l10n = () => lookupAppLocalizations(const Locale('en'));
      CopiesHub().install();
    });
    tearDown(() {
      CopiesHub().reset();
      ServerManager().currentServer = null;
    });

    /// The home as built now: its SERVER section's cards, in order.
    List<String?> serverCards() {
      final home = BrowserManager().browserList;
      final at = home.indexWhere(
        (i) => i.type == 'section' && i.name == 'Server',
      );
      if (at < 0) return const [];
      return [
        for (final i in home.skip(at + 1))
          if (i.type == 'execAction') i.data,
      ];
    }

    Future<void> showHome() async {
      ServerManager().currentServer = h.server;
      BrowserManager().goToNavScreen();
      await settle();
      await settle();
    }

    test('beside Add torrent once the listing says copies are possible (the '
        'home is drawn again when it lands)', () async {
      await showHome();
      expect(serverCards(), ['torrents', 'copies']);
      expect(h.fake.count('GET', '/api/v1/discovery/plugins'), 1);
      // A home drawn again asks the list again only after a while.
      final lists = h.fake.count('GET', '/plugin-jobs');
      BrowserManager().goToNavScreen();
      await settle();
      expect(h.fake.count('GET', '/plugin-jobs'), lists);
    });

    test('a home drawn before an answer that changed it while away is drawn '
        'again on return', () async {
      await showHome();
      expect(serverCards(), ['torrents', 'copies']);
      BrowserManager().addListToStack([]);
      await settle();
      // Elsewhere (Discover's visit reads the listing afresh), the copy
      // plug-in went away.
      h.fake.listing = {
        'plugins': [
          {
            'name': 'links',
            'capabilities': ['links'],
            'scopes': ['song'],
          },
        ],
        'jobs': {'allowed': true},
      };
      await CopiesHub().visit(h.server).activate();
      await settle();
      BrowserManager().popBrowser();
      await settle();
      await settle();
      expect(serverCards(), ['torrents']);
    });

    test('hidden when the copy plug-in is not listed', () async {
      h.fake.listing = {
        'plugins': [
          {
            'name': 'links',
            'capabilities': ['links'],
            'scopes': ['song'],
          },
        ],
        'jobs': {'allowed': true},
      };
      await showHome();
      expect(serverCards(), ['torrents']);
    });

    test('hidden when jobs are not allowed', () async {
      h.fake.listing = {
        ...h.fake.listing,
        'jobs': {'allowed': false},
      };
      await showHome();
      expect(serverCards(), ['torrents']);
    });

    test(
      'hidden, and nothing asked, with uploads off or plug-ins off',
      () async {
        h.server.noUpload = true;
        await showHome();
        expect(serverCards(), ['torrents']);
        h.server
          ..noUpload = false
          ..discoveryPluginsAvailable = false;
        await showHome();
        expect(serverCards(), ['torrents']);
        expect(h.fake.requests, isEmpty);
      },
    );

    test('a peer\'s home never has it', () async {
      final peer = Server('federated://home/1', null, null, null, 'peer-1')
        ..federationParent = 'home'
        ..federationPeerId = 1
        ..federationPeerName = 'Stage Peer B'
        ..parentServer = h.server
        ..discoveryPluginsAvailable = true;
      ServerManager().serverList.add(peer);
      ServerManager().currentServer = peer;
      BrowserManager().goToNavScreen();
      await settle();
      expect(
        BrowserManager().browserList.any((i) => i.data == 'copies'),
        isFalse,
      );
    });

    test(
      'while the home is in front a live copy keeps the poll beating; a copy '
      'the home saw live toasts its end: "Added to your collection"',
      () async {
        final j = h.fake.addJob(tapes, state: 'running');
        await showHome();
        final jobs = CopiesHub().jobsFor(h.server);
        expect(jobs.summary.running, 1);
        expect(h.timers.active?.delay, DiscoveryJobsController.kDiscoverBeat);
        j['state'] = 'done';
        j['result'] = {
          'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/x.mp3'},
        };
        h.timers.active!.fire();
        await settle();
        expect(h.toasts, ['Added to your collection']);
        expect(h.timers.active, isNull, reason: 'nothing live: stopped');
      },
    );

    test('another screen in front stops the beat; the home back in front '
        'catches up', () async {
      h.fake.addJob(tapes, state: 'running');
      await showHome();
      final jobs = CopiesHub().jobsFor(h.server);
      BrowserManager().addListToStack([]);
      await settle();
      expect(jobs.discoverVisible, isFalse);
      expect(h.timers.active, isNull);
      BrowserManager().popBrowser();
      await settle();
      expect(jobs.discoverVisible, isTrue);
      expect(h.timers.active, isNotNull);
    });

    test("Discover opened from the home shares the home's copies; leaving it "
        'keeps them and lets its rows go', () async {
      await showHome();
      // The page asks nothing of its own here (taste off): only the
      // shared copies are under test.
      h.server.discoveryTasteAvailable = false;
      final shared = CopiesHub().jobsFor(h.server);
      final listings = h.fake.count('GET', '/api/v1/discovery/plugins');
      DiscoveryListing().open(h.server);
      await settle();
      expect(DiscoveryListing().controller!.jobs, same(shared));
      expect(
        h.fake.count('GET', '/api/v1/discovery/plugins'),
        listings + 1,
        reason: 'a Discover visit reads them afresh',
      );
      BrowserManager().popBrowser();
      await settle();
      expect(DiscoveryListing().controller, isNull);
      expect(CopiesHub().jobsFor(h.server), same(shared));
      expect(shared.leads, isEmpty);
      expect(() => shared.summary, returnsNormally);
    });

    testWidgets(
      'the card\'s second lines: one part per line, in their colours',
      (tester) async {
        h.fake.addJob(tapes, state: 'running');
        h.fake.addJob(lullaby, state: 'failed');
        final jobs = CopiesHub().jobsFor(h.server);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: Scaffold(body: CopiesHomeLines(jobs: jobs)),
          ),
        );
        expect(find.byKey(const ValueKey('home-copies-lines')), findsNothing);
        await jobs.activate();
        await tester.pump();
        expect(find.text('Copying 1'), findsOneWidget);
        expect(find.text('1 failed'), findsOneWidget);
        final failed = tester.widget<Text>(find.text('1 failed'));
        expect(failed.style!.color, keepTone(VelvetColors.error));
      },
    );
  });

  group('the copy toasts', () {
    late AppLocalizations l;
    setUp(() async {
      l = await AppLocalizations.delegate.load(const Locale('en'));
    });

    DiscoveryJob job(
      Map<String, dynamic> rec, {
      String? scope,
      String state = 'done',
      Map<String, dynamic>? result,
      String? error,
    }) => DiscoveryJob.fromServerMap({
      'id': 1,
      'plugin': kCopyPlugin,
      'recommendation': rec,
      'params': scope == null ? null : {'scope': scope},
      'state': state,
      'result': result,
      'error': error,
    })!;

    test('a start names what is copied and from where', () {
      expect(
        copyStartedToast(l, job(tapes, state: 'queued')),
        'Copying Late Train Verse from Stage Peer B',
      );
      expect(
        copyStartedToast(l, job(tapes, scope: 'album', state: 'queued')),
        'Copying Borrowed Tapes from Stage Peer B',
      );
      expect(
        copyStartedToast(l, job(tapes, scope: 'artist', state: 'queued')),
        'Copying every album by Boukmanflow from Stage Peer B',
      );
      expect(
        copyStartedToast(
          l,
          job(tapes, scope: 'artist-missing', state: 'queued'),
        ),
        "Copying the albums by Boukmanflow you don't have from Stage Peer B",
      );
    });

    test('an end: added only when something landed; done is not kept', () {
      expect(
        copyFinishedToast(
          l,
          job(
            tapes,
            result: {
              'copied': {'filepath': 'x.mp3'},
            },
          ),
        ),
        'Added to your collection',
      );
      expect(
        copyFinishedToast(
          l,
          job(tapes, scope: 'album', result: many(copied: 2)),
        ),
        'Added to your collection',
      );
      expect(
        copyFinishedToast(l, job(tapes, result: {'skipped': 'owned'})),
        'Already in your library',
      );
      expect(
        copyFinishedToast(
          l,
          job(
            tapes,
            scope: 'album',
            result: many(copied: 1, stopped: 'quota'),
          ),
        ),
        "Stopped early: Stage Peer B's transfer limit stopped it",
      );
      expect(
        copyFinishedToast(
          l,
          job(
            tapes,
            state: 'failed',
            error: 'Stage Peer B no longer has this file',
          ),
        ),
        'Copy failed: Stage Peer B no longer has this file',
      );
      expect(
        copyFinishedToast(
          l,
          job(tapes, scope: 'album', result: many(failed: 3)),
        ),
        'Copy failed: Nothing copied · 3 failed',
      );
      expect(copyFinishedToast(l, job(tapes, state: 'cancelled')), isNull);
      expect(
        copyFinishedToast(l, job(tapes, scope: 'album', result: many())),
        isNull,
      );
    });

    test('attachCopyToasts: once per copy seen live', () async {
      final j = h.fake.addJob(tapes, state: 'running');
      final shown = <String>[];
      final sub = attachCopyToasts(h.jobs, l10n: () => l, show: shown.add);
      await h.jobs.activate();
      j['state'] = 'failed';
      j['error'] = 'Stage Peer B is unreachable';
      await h.jobs.refreshJobs();
      await h.jobs.refreshJobs();
      await settle();
      expect(shown, ['Copy failed: Stage Peer B is unreachable']);
      await sub.cancel();
    });
  });

  group('the start toast and the first-use note (Discover)', () {
    final k = KeepHarness();
    setUp(() {
      k.setUp();
      SettingsManager().discoverKeepNoteSeen = false;
    });
    tearDown(() {
      BrowserManager().closeAlbumDetail();
      ServerManager().currentServer = null;
      SettingsManager().discoverKeepNoteSeen = false;
      k.tearDown();
    });

    testWidgets(
      'a copy started from the song sheet toasts once the sheet closes; the '
      'first-use note shows until then and goes for good',
      (tester) async {
        await k.pumpDiscover(tester);
        await tester.longPress(find.text('Late Train Verse'));
        await frames(tester, 8);
        const note =
            'Copies go to your server, not this phone. Check where they land before the first one.';
        expect(find.text(note), findsOneWidget);
        final pill = find.byKey(const ValueKey('keep-start'));
        await tester.ensureVisible(pill);
        await tester.pump();
        await tester.tap(pill);
        await frames(tester);
        expect(
          h.toasts,
          isEmpty,
          reason: 'not while the sheet that started it is up',
        );
        expect(find.text(note), findsNothing);
        expect(SettingsManager().discoverKeepNoteSeen, isTrue);
        // Close the sheet (the dimmed page above it).
        await tester.tapAt(const Offset(195, 20));
        await frames(tester, 10);
        expect(h.toasts, ['Copying Late Train Verse from Stage Peer B']);
      },
    );

    testWidgets('no note once the account has a saved destination', (
      tester,
    ) async {
      k.fake.destination = {
        ...k.fake.destination,
        'saved': {
          'vpath': 'copies',
          'base': 'mine',
          'layout': '{{ARTIST}}/{{ALBUM}}',
        },
      };
      await k.pumpDiscover(tester);
      await tester.longPress(find.text('Late Train Verse'));
      await frames(tester, 8);
      expect(find.byKey(const ValueKey('keep-first-use')), findsNothing);
    });

    testWidgets("the Copies strip opens the Copies sheet over Discover", (
      tester,
    ) async {
      DiscoveryKeepRoutes.reset();
      k.fake.addJob(
        keepRow('Late Train Verse', track: '02 - '),
        state: 'running',
      );
      await k.pumpDiscover(tester);
      await tester.tap(find.byKey(const ValueKey('discovery-copies-strip')));
      await frames(tester, 8);
      expect(find.text('COPYING'), findsOneWidget);
      expect(
        find.text('Copying 1'),
        findsNWidgets(2),
        reason: 'the strip and the sheet',
      );
    });
  });
}
