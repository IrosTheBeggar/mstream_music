// PeerRecsListing (lib/screens/discovery/peer_recs_listing.dart; mStream
// docs/peer-recommendations-plan.md §2 items 14–16, §3.5 R6–R7; the phone
// build plan's piece L): the one marker frame the page keeps on
// BrowserManager's stack; the visit it owns — the controller, the clip
// session, the own server's plug-in jobs — and when it lets go (Back, a
// stack reset); what covers it (another frame, a page route over the home
// pushed straight over it or over a sheet, album detail, Now Playing
// expanded, the app drawer; never a modal sheet) and what a cover does to
// the clip and the poll; R7's pop, only from the top and never under the
// lead sheet; and the wiring between the parts (holding, the provider
// check, a late sheet close, the answers store outliving its visit).
//
// The page's routes are FakePeerRecs (answered at once), the plug-in
// routes FakePluginServer, the engine FakePreviewPlayer: nothing touches
// the network or the audio service.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/peer_recs_controller.dart';
import 'package:mstream_music/screens/discovery/peer_recs_listing.dart';
import 'package:mstream_music/screens/discovery/peer_recs_previews.dart';
import 'package:mstream_music/singletons/app_route_observer.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';

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

bool _homeHasCard() =>
    BrowserManager().browserList.any((i) => i.data == 'peerRecs');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The browser resolves on-device download badges through path_provider.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/nonexistent-peer-recs-test-dir');
  });

  late FakePeerRecs f;
  late Server server;
  late FakePreviewPlayer engine;
  late FakePluginServer plugins;
  late FakeTimers jobTimers;
  late int jobsMade;

  setUp(() {
    ServerManager().serverList.clear();
    f = FakePeerRecs();
    server = f.server;
    f.auto = stage;
    f.peersAuto = () => peersOk(peersMemberJson);
    ServerManager().serverList.add(server);
    ServerManager().currentServer = server;
    BrowserManager().goToNavScreen();
    engine = FakePreviewPlayer.install();
    plugins = FakePluginServer()..listLeadPlugins(youtube: false);
    plugins.previews['deezer'] = deezerWire();
    jobTimers = FakeTimers();
    jobsMade = 0;
    CopiesHub().makeJobs = (s) {
      jobsMade++;
      return DiscoveryJobsController(
          server: s,
          api: plugins.api(s),
          timer: jobTimers.call,
          watchLifecycle: false);
    };
    nowPlayingExpanded.value = false;
    appDrawerOpen.value = false;
    appRouteObserver.debugReset();
  });

  tearDown(() async {
    // Let the visit go (a reset stack is no frame), then the singletons.
    BrowserManager().goToNavScreen();
    await settle();
    CopiesHub().reset();
    nowPlayingExpanded.value = false;
    appDrawerOpen.value = false;
    appRouteObserver.debugReset();
    ServerManager().currentServer = null;
    ServerManager().serverList.clear();
  });

  /// Open the page over the home with [f]'s controller; the own server's
  /// plug-ins on ([withPlugins]) or off.
  Future<PeerRecsController> open({bool withPlugins = true}) async {
    server.discoveryPluginsAvailable = withPlugins;
    final c = f.makeController();
    PeerRecsListing().open(server, controller: c);
    await settle();
    return c;
  }

  DiscoveryLead leadOf(PeerRecsController c, String title) =>
      c.leads.firstWhere((l) => l.title == title);

  /// Press [title]'s circle and let its clip play.
  Future<PeerRecsPreviews> play(PeerRecsController c, String title) async {
    final p = PeerRecsListing().previews!;
    await p.press(leadOf(c, title), c.leads);
    await settle();
    expect(p.status, PeerClipStatus.playing, reason: 'the clip plays');
    return p;
  }

  group('open and Back', () {
    test('open pushes one marker frame labelled Peer Recommendations, asks '
        'R1 and polls', () async {
      final home = BrowserManager().browserList.toList();
      expect(_homeHasCard(), isTrue, reason: 'the flag shows the card');
      final c = f.makeController();
      PeerRecsListing().open(server, controller: c);

      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'a frame like Discover, not a route');
      final frame = BrowserManager().browserList;
      final top = BrowserManager().browserCache.last;
      expect(frame, hasLength(1), reason: 'one marker item');
      expect(frame.single.type, kPeerRecsBar);
      expect(frame.single.name, kPeerRecsLabel);
      expect(frame.single.server, same(server));
      expect(PeerRecsListing.isListing(frame), isTrue);
      expect(PeerRecsListing.isListing(home), isFalse);
      expect(PeerRecsListing.isListing(const <DisplayItem>[]), isFalse);
      expect(BrowserManager().listName, kPeerRecsLabel);
      expect(PeerRecsListing().controller, same(c));
      expect(PeerRecsListing().previews, isNotNull);
      expect(PeerRecsListing().jobs, isNull,
          reason: "the own server's plug-ins are off here");

      await settle();
      expect(f.bodies, hasLength(1), reason: 'R1, once');
      expect(f.bodies.single['sources'], ['network']);
      expect(f.bodies.single['limit'], {'seeds': 12, 'network': 32});
      expect(f.polls, 1, reason: 'the strip polls at once');
      expect(c.state, PeerRecsState.ready);
      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'answers never push or replace the frame');
      expect(BrowserManager().browserCache.last, same(top));
    });

    test('Back pops: the clip ends sheetClosed (resuming), the controller '
        'disposed, polls stop', () async {
      final c = await open();
      final p = await play(c, 'Signal Fires');
      expect(engine.held, isNotNull, reason: 'the song is held');
      expect(c.nextPollIn, isNotNull);

      BrowserManager().popBrowser();
      await settle();
      expect(BrowserManager().browserCache, hasLength(1));
      expect(PeerRecsListing().controller, isNull);
      expect(PeerRecsListing().previews, isNull);
      expect(PeerRecsListing().jobs, isNull);
      expect(engine.ends, [PreviewEnd.sheetClosed]);
      expect(engine.endCalls.last.owner, same(p));
      expect(engine.held, isNull, reason: 'sheetClosed gives the song back');
      expect(c.polling, isFalse, reason: 'disposed');
      expect(f.timers.active, isNull, reason: 'no poll left');
      final polls = f.polls;
      await settle();
      expect(f.polls, polls);
      expect(BrowserManager().browserCache, hasLength(1),
          reason: 'nothing comes back as a frame');
    });

    test('Back with no clip frees the clip player (an owner-carrying '
        'sheetClosed that ends nothing)', () async {
      await open();
      final p = PeerRecsListing().previews!;
      BrowserManager().popBrowser();
      await settle();
      expect(engine.endCalls, [(reason: PreviewEnd.sheetClosed, owner: p)]);
      expect(engine.endCount, 0, reason: 'no flow ended, nothing counted');
    });

    test('a fresh open is a fresh visit; the previous one is let go',
        () async {
      final first = await open();
      final p1 = PeerRecsListing().previews;
      BrowserManager().popBrowser();
      await settle();
      final second = await open();
      expect(PeerRecsListing().controller, same(second));
      expect(second, isNot(same(first)));
      expect(PeerRecsListing().previews, isNot(same(p1)));
      expect(BrowserManager().browserCache, hasLength(2));
    });
  });

  group('covers', () {
    test('covered by a frame: the clip ends stopped, polls pause; back on '
        'top: one poll at once, the label restored', () async {
      final c = await open();
      final p = await play(c, 'Signal Fires');
      final polls = f.polls;

      // What a strip tap that opens a list would do: a frame over the page.
      BrowserManager().setBrowserLabel('File Explorer');
      BrowserManager().addListToStack(
          [DisplayItem(server, 'music', 'directory', '/music', null, null)],
          path: '/');
      await settle();
      expect(PeerRecsListing().covered, isTrue);
      expect(PeerRecsListing().controller, same(c), reason: 'covered, not gone');
      expect(engine.ends, [PreviewEnd.stopped]);
      expect(engine.endCalls.single.owner, same(p));
      expect(p.isLive, isFalse);
      expect(c.nextPollIn, isNull, reason: 'no poll while covered');
      expect(f.polls, polls);
      expect(BrowserManager().listName, 'File Explorer');

      BrowserManager().popBrowser();
      await settle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, polls + 1, reason: 'one poll at once (R6)');
      expect(c.nextPollIn, isNotNull);
      expect(BrowserManager().listName, kPeerRecsLabel);
      expect(engine.ends, [PreviewEnd.stopped], reason: 'nothing more ends');
    });

    test('album detail and an expanded Now Playing cover; a modal bottom '
        'sheet does not', () async {
      final c = await open();
      var polls = f.polls;

      // Album detail over the browser (no frame, no route).
      await play(c, 'Signal Fires');
      BrowserManager().openAlbumDetail(
          DisplayItem(server, 'Night Ferry', 'album', 'Night Ferry', null, null));
      await settle();
      expect(PeerRecsListing().covered, isTrue);
      expect(engine.ends, [PreviewEnd.stopped]);
      expect(c.nextPollIn, isNull);
      BrowserManager().closeAlbumDetail();
      await settle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, ++polls);

      // Now Playing expanded (the player panel's flag).
      await play(c, 'Signal Fires');
      nowPlayingExpanded.value = true;
      await settle();
      expect(PeerRecsListing().covered, isTrue);
      expect(engine.ends, [PreviewEnd.stopped, PreviewEnd.stopped]);
      expect(c.nextPollIn, isNull);
      nowPlayingExpanded.value = false;
      await settle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, ++polls);

      // A page route pushed over the home (the app's route observer counts
      // the page routes on the navigator).
      final home = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final settings =
          MaterialPageRoute<void>(builder: (_) => const SizedBox());
      appRouteObserver.didPush(home, null);
      expect(PeerRecsListing().covered, isFalse, reason: 'the home alone');
      appRouteObserver.didPush(settings, home);
      expect(PeerRecsListing().covered, isTrue);
      expect(c.nextPollIn, isNull);
      appRouteObserver.didPop(settings, home);
      await settle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, ++polls);

      // A page route pushed over a sheet (Find similar from the seeds
      // sheet): the route under it is the sheet's, and it still covers.
      final sheet = ModalBottomSheetRoute<void>(
          builder: (_) => const SizedBox(), isScrollControlled: false);
      final similar =
          MaterialPageRoute<void>(builder: (_) => const SizedBox());
      appRouteObserver.didPush(sheet, home);
      expect(PeerRecsListing().covered, isFalse, reason: 'a sheet is no cover');
      appRouteObserver.didPush(similar, sheet);
      expect(PeerRecsListing().covered, isTrue);
      expect(c.nextPollIn, isNull);
      appRouteObserver.didPop(similar, sheet);
      await settle();
      expect(PeerRecsListing().covered, isFalse, reason: 'the sheet again');
      expect(f.polls, ++polls);
      appRouteObserver.didPop(sheet, home);
      await settle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, polls, reason: 'a sheet closing is no uncover');

      // The lead sheet (a modal bottom sheet) is no cover: the poll goes on
      // and nothing ends.
      final ends = engine.ends.length;
      PeerRecsListing().setSheetOpen(true, visit: c);
      expect(PeerRecsListing().covered, isFalse);
      expect(c.nextPollIn, isNotNull);
      expect(engine.ends, hasLength(ends));
      PeerRecsListing().setSheetOpen(false, visit: c);
    });

    test('the app drawer covers: the clip ends stopped, polls pause; closed: '
        'one poll at once', () async {
      final c = await open();
      final p = await play(c, 'Signal Fires');
      final polls = f.polls;

      appDrawerOpen.value = true;
      await settle();
      expect(PeerRecsListing().covered, isTrue);
      expect(engine.ends, [PreviewEnd.stopped],
          reason: 'its band is under the drawer');
      expect(engine.endCalls.single.owner, same(p));
      expect(c.nextPollIn, isNull, reason: 'no poll while covered');
      expect(f.polls, polls);

      appDrawerOpen.value = false;
      await settle();
      expect(PeerRecsListing().covered, isFalse);
      expect(f.polls, polls + 1, reason: 'one poll at once (R6)');
      expect(c.nextPollIn, isNotNull);

      // A visit let go stops watching the drawer.
      BrowserManager().popBrowser();
      await settle();
      final ends = engine.ends.length;
      appDrawerOpen.value = true;
      await settle();
      expect(engine.ends, hasLength(ends));
      expect(PeerRecsListing().covered, isFalse);
    });
  });

  group('off (R7)', () {
    test('R7 off on top: pops and redraws the home without the card',
        () async {
      final c = await open();
      final home = BrowserManager().browserCache.first;
      f.repingPeerRecs = false;
      await c.offCheck(PeerRecsOffSource.peers);
      await settle();
      expect(c.off, isTrue);
      expect(BrowserManager().browserCache, hasLength(1));
      expect(BrowserManager.isHomeList(BrowserManager().browserList), isTrue);
      expect(BrowserManager().browserCache.first, isNot(same(home)),
          reason: 'the home is built again from the flags');
      expect(_homeHasCard(), isFalse);
      expect(PeerRecsListing().controller, isNull);
    });

    test('a flag already off at open leaves at once', () async {
      server.peerRecsAvailable = false;
      final c = f.makeController();
      PeerRecsListing().open(server, controller: c);
      await settle();
      expect(BrowserManager().browserCache, hasLength(1));
      expect(PeerRecsListing().controller, isNull);
      expect(f.requests, isEmpty);
      expect(_homeHasCard(), isFalse);
    });

    test('R7 off while covered: pops when uncovered', () async {
      final c = await open();
      BrowserManager().setBrowserLabel('File Explorer');
      BrowserManager().addListToStack(
          [DisplayItem(server, 'music', 'directory', '/music', null, null)],
          path: '/');
      await settle();
      f.repingPeerRecs = false;
      await c.offCheck(PeerRecsOffSource.clip);
      await settle();
      expect(c.off, isTrue);
      expect(BrowserManager().browserCache, hasLength(3),
          reason: 'only the top is ever popped');
      expect(BrowserManager().listName, 'File Explorer');
      expect(PeerRecsListing().controller, same(c));

      BrowserManager().popBrowser();
      await settle();
      expect(BrowserManager().browserCache, hasLength(1));
      expect(BrowserManager.isHomeList(BrowserManager().browserList), isTrue);
      expect(_homeHasCard(), isFalse);
      expect(PeerRecsListing().controller, isNull);
    });

    test('R7 off while the lead sheet is open: the frame stays until the '
        'sheet closes, then pops', () async {
      final c = await open();
      PeerRecsListing().setSheetOpen(true, visit: c);
      f.repingPeerRecs = false;
      await c.offCheck(PeerRecsOffSource.clip);
      await settle();
      expect(c.off, isTrue);
      expect(BrowserManager().browserCache, hasLength(2),
          reason: 'the frame never changes under a modal sheet');
      expect(PeerRecsListing().controller, same(c));

      PeerRecsListing().setSheetOpen(false, visit: c);
      await settle();
      expect(BrowserManager().browserCache, hasLength(1));
      expect(_homeHasCard(), isFalse);
      expect(PeerRecsListing().controller, isNull);
    });

    test('still on after the re-ping: the page stays', () async {
      final c = await open();
      await c.offCheck(PeerRecsOffSource.peers);
      await settle();
      expect(c.off, isFalse);
      expect(BrowserManager().browserCache, hasLength(2));
      expect(PeerRecsListing().controller, same(c));
    });
  });

  group('wiring', () {
    test('plug-ins off: no jobs, no listing call, no circles', () async {
      final c = await open(withPlugins: false);
      expect(PeerRecsListing().jobs, isNull);
      expect(jobsMade, 0, reason: "no own server's jobs are made");
      expect(plugins.count('GET', '/api/v1/discovery/plugins'), 0);
      final p = PeerRecsListing().previews!;
      expect(p.providerPlugin, isNull);
      expect(c.leads, hasLength(12));
      expect(c.leads.map(p.circleOf).toSet(), {PeerCircle.hidden});
      await p.previewAll(c.leads);
      expect(p.isLive, isFalse);
      expect(engine.plays, isEmpty);
    });

    test("plug-ins on: the own server's jobs, the listing read; read again "
        'on the next visit', () async {
      await open();
      final jobs = PeerRecsListing().jobs;
      expect(jobs, isNotNull);
      expect(jobsMade, 1);
      expect(jobs!.listing, isNotNull);
      expect(PeerRecsListing().previews!.providerPlugin?.name, 'deezer');
      final reads = plugins.count('GET', '/api/v1/discovery/plugins');
      expect(reads, 1);

      BrowserManager().popBrowser();
      await settle();
      await open();
      expect(PeerRecsListing().jobs, same(jobs), reason: "the hub's, kept");
      expect(jobsMade, 1);
      expect(plugins.count('GET', '/api/v1/discovery/plugins'), reads + 1,
          reason: 'the listing is read again each visit');
    });

    test('a provider change in the listing clears the answers', () async {
      final c = await open();
      final p = PeerRecsListing().previews!;
      final answers = p.answers;
      answers.put(peerLeadKey(leadOf(c, 'Salt Road')), 'deezer', null);
      expect(answers.length, 1);
      expect(p.circleOf(leadOf(c, 'Salt Road')), PeerCircle.muted);

      // Read again with the same plug-ins: nothing is forgotten.
      await PeerRecsListing().jobs!.regate();
      await settle();
      expect(answers.length, 1);

      // Deezer gone: iTunes previews now, the old answers go.
      plugins.listing = {
        ...plugins.listing,
        'plugins': [
          for (final e in plugins.listing['plugins'] as List)
            if ((e as Map)['name'] != 'deezer') e,
        ],
      };
      await PeerRecsListing().jobs!.regate();
      await settle();
      expect(p.providerPlugin?.name, 'itunes');
      expect(answers.length, 0);
      expect(p.circleOf(leadOf(c, 'Salt Road')), PeerCircle.idle);
    });

    test('holding while the sheet is open and while a clip is live',
        () async {
      final c = await open();
      expect(c.holding, isFalse);
      PeerRecsListing().setSheetOpen(true, visit: c);
      expect(c.holding, isTrue);
      expect(PeerRecsListing().sheetOpen, isTrue);
      PeerRecsListing().setSheetOpen(false, visit: c);
      expect(c.holding, isFalse);

      final p = await play(c, 'Signal Fires');
      expect(c.holding, isTrue, reason: 'a clip is live');
      PeerRecsListing().setSheetOpen(true, visit: c);
      await p.stop();
      await settle();
      expect(c.holding, isTrue, reason: 'the sheet still holds');
      PeerRecsListing().setSheetOpen(false, visit: c);
      expect(c.holding, isFalse);
    });

    test('a late setSheetOpen(false) from a detached visit does nothing (no '
        'notify on a disposed controller)', () async {
      final old = await open();
      PeerRecsListing().setSheetOpen(true, visit: old);
      BrowserManager().popBrowser();
      await settle();
      expect(PeerRecsListing().controller, isNull);
      expect(PeerRecsListing().sheetOpen, isFalse,
          reason: 'cleared with the visit');
      // The sheet the old visit opened closes now.
      PeerRecsListing().setSheetOpen(false, visit: old);
      expect(old.holding, isTrue, reason: 'untouched: it is disposed');

      // A new visit is not the old sheet's.
      final c = await open();
      PeerRecsListing().setSheetOpen(true, visit: old);
      expect(c.holding, isFalse);
      expect(PeerRecsListing().sheetOpen, isFalse);
      PeerRecsListing().setSheetOpen(true, visit: c);
      PeerRecsListing().setSheetOpen(false, visit: old);
      expect(c.holding, isTrue, reason: "the old sheet's close is not ours");
    });

    test('detach leaves the answers store usable for a sheet still open',
        () async {
      final c = await open();
      final answers = PeerRecsListing().previews!.answers;
      final key = peerLeadKey(leadOf(c, 'Signal Fires'));
      PeerRecsListing().setSheetOpen(true, visit: c);
      BrowserManager().popBrowser();
      await settle();
      expect(PeerRecsListing().previews, isNull);

      // The sheet's row answers after the page is gone.
      var notes = 0;
      answers.addListener(() => notes++);
      answers.put(key, 'deezer', null);
      expect(answers.of(key, 'deezer')?.none, isTrue);
      expect(notes, 1);
      answers.clear();
      expect(notes, 2);
    });

    test('a new answer on screen tells the previews: Preview all stops at '
        "its clip's end", () async {
      final c = await open();
      final p = PeerRecsListing().previews!;
      await p.previewAll(c.leads);
      await settle();
      expect(p.chain, isTrue);
      await c.select(kKitchen);
      await settle();
      expect(c.leads.every((l) => l.endpointId == kKitchen), isTrue);
      expect(p.chain, isFalse, reason: 'listChanged: no running on');
    });
  });
}
