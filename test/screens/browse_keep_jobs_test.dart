// Keep a copy while browsing a connected server, its jobs half: the own
// server's controller asked for a browse page's lookups without touching
// Discover's rows, a folder copy started with its landing and retried with
// it, the gate a connected server's pages snapshot (read once, never
// popping in), a browse page's marks and their poll (BrowseCopyMarks), and
// a folder's facts (its count, its tags, the own library's folders).
//
// The plug-in API is the scripted fake (discovery_plugin_fakes.dart) behind
// the real DiscoveryPluginsApi; every timer is fired by hand.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/browse_copy_marks.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/keep_folder_facts.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/util/discover_badges.dart';
import 'package:mstream_music/util/discover_jobs.dart';

import 'discovery_plugin_fakes.dart';

const pb = {'id': 1, 'name': 'Stage Peer B'};
const pc = {'id': 4, 'name': 'Stage Peer C'};

Map<String, dynamic> songRec(String title, {Map<String, Object> peer = pb, String album = 'Borrowed Tapes', String? credit}) => {
      'source': 'federation',
      'peer': peer,
      'filepath': 'music/Boukmanflow/$album/$title.mp3',
      'title': title,
      'artist': 'Boukmanflow',
      'album': album,
      'albumArtist': ?credit,
      'year': 2019,
    };

Map<String, dynamic> albumRec({Map<String, Object> peer = pb, String album = 'Borrowed Tapes'}) => {
      'source': 'federation',
      'peer': peer,
      'album': album,
      'albumArtist': 'Boukmanflow',
      'artist': 'Boukmanflow',
      'year': 2019,
    };

Map<String, dynamic> folderRec(String path, {Map<String, Object> peer = pb}) =>
    {'source': 'federation', 'peer': peer, 'filepath': path, 'title': path.split('/').last};

Map<String, dynamic> albumResult({List<String> copied = const [], List<String> failed = const [], List<(String, String)> skipped = const []}) => {
      'scope': 'album',
      'songs': {
        'total': copied.length + failed.length + skipped.length,
        'copied': [for (final f in copied) {'from': f, 'filepath': 'copies/Boukmanflow/Borrowed Tapes/${f.split('/').last}'}],
        'skipped': [for (final (f, why) in skipped) {'from': f, 'why': why, 'at': 'copies/x/${f.split('/').last}'}],
        'failed': [for (final f in failed) {'from': f, 'error': 'boom'}],
      },
      'counts': {'total': copied.length + failed.length + skipped.length, 'copied': copied.length, 'skipped': skipped.length, 'failed': failed.length},
      'stopped': null,
      'peer': pb,
    };

void main() {
  late FakePluginServer fake;
  late FakeTimers timers;
  late FakeTimers pageTimers;
  late Server home;
  late Server peer;
  final made = <DiscoveryJobsController>[];

  DiscoveryJobsController make(Server s) {
    final c = DiscoveryJobsController(server: s, api: fake.api(s), timer: timers.call, watchLifecycle: false);
    made.add(c);
    return c;
  }

  setUp(() {
    fake = FakePluginServer();
    timers = FakeTimers();
    pageTimers = FakeTimers();
    home = Server('http://home.local:3000', null, null, 'JWT', 'home')
      ..discoveryPluginsAvailable = true
      ..noUpload = false;
    peer = Server('federated://home/1', null, null, null, 'peer-1')
      ..federationParent = 'home'
      ..federationPeerId = 1
      ..federationPeerName = 'Stage Peer B'
      ..parentServer = home;
    CopiesHub().makeJobs = make;
  });
  tearDown(() {
    CopiesHub().reset();
    for (final c in made) {
      c.dispose();
    }
    made.clear();
  });

  group("the own server's controller, for a browse page", () {
    test("lookup(recs) answers the page's recommendations and never touches Discover's rows", () async {
      final c = make(home);
      await c.activate();
      final j = fake.addJob(albumRec(), scope: 'album', state: 'done', result: albumResult());
      fake.addJob(songRec('Late Train Verse'), state: 'failed')['plugin'] = 'youtube';
      final out = await c.lookup([albumRec(), songRec('Late Train Verse')]);
      expect(out, hasLength(2));
      expect([for (final x in out![0]!.jobs) x.id], [j['id']]);
      expect(out[1]!.jobs.every(isKeepCopy), isTrue, reason: 'only Keep a copy\'s jobs');
      expect([c.rows, c.leads], [isEmpty, isEmpty], reason: "Discover's row set is its own");
      expect(fake.count('POST', '/lookup/batch'), 1);
    });

    test('a lookup refused, or plug-ins off: null — no marks, nothing asked', () async {
      final c = make(home);
      fake.refuse['/lookup/batch'] = (500, 'boom');
      expect(await c.lookup([albumRec()]), isNull);
      home.discoveryPluginsAvailable = false;
      fake.requests.clear();
      expect(await c.lookup([albumRec()]), isNull);
      expect(fake.requests, isEmpty);
    });

    test('a live copy a page found is polled for while a page holds the beat, and its end is news', () async {
      final c = make(home)..discoverVisible = false; // browsing: Discover is not in front
      final news = <DiscoveryJob>[];
      c.finished.listen(news.add);
      final j = fake.addJob(folderRec('music/Boukmanflow/Borrowed Tapes'), scope: 'folder', state: 'running', statusText: '1 of 3 songs');
      await c.lookup([folderRec('music/Boukmanflow/Borrowed Tapes')]);
      expect(c.anyLive, isTrue);
      expect(timers.active, isNull, reason: 'nothing in front holds a beat');
      final release = c.holdPage();
      expect(timers.active?.delay, DiscoveryJobsController.kDiscoverBeat);
      j['state'] = 'done';
      j['result'] = albumResult(copied: ['a'])..['scope'] = 'folder';
      timers.active!.fire();
      await settle();
      expect([for (final n in news) n.id], [j['id']]);
      release();
      release();
      expect(timers.active, isNull);
    });

    test('start(landing:): none as on the server, a folder of its own, by the layout — only with scope folder, and never a null library', () async {
      final c = make(home);
      await c.activate();
      Map body() => jsonDecode(fake.calls('POST', '/plugins/federation-copy/jobs').last.body) as Map;
      final f = folderRec('music/Boukmanflow/Borrowed Tapes');
      await c.start(f, scope: kScopeFolder);
      expect([body()['scope'], body().containsKey('landing')], ['folder', false]);
      fake.jobs.clear();
      await c.start(f, scope: kScopeFolder, landing: folderLanding(FolderLanding.folder, vpath: 'copies', path: 'From Sam'));
      expect(body()['landing'], {'vpath': 'copies', 'path': 'From Sam'});
      fake.jobs.clear();
      await c.start(f, scope: kScopeFolder, landing: folderLanding(FolderLanding.folder, path: 'Borrowed Tapes'));
      expect(body()['landing'], {'path': 'Borrowed Tapes'});
      fake.jobs.clear();
      await c.start(f, scope: kScopeFolder, landing: folderLanding(FolderLanding.tags));
      expect(body()['landing'], {'tags': true});
      fake.jobs.clear();
      await c.start(albumRec(), scope: kScopeAlbum, landing: const {'tags': true});
      expect(body().containsKey('landing'), isFalse, reason: 'the route refuses a landing on any other scope');
    });

    test("a {vpath, path} landing reads nothing of the destination: no destination_changed for a place that moved", () async {
      final c = make(home);
      await c.activate();
      final shown = ShownPlace(c.destination!.destination);
      fake.destination = {
        ...fake.destination,
        'destination': {'vpath': 'copies', 'base': '', 'layout': 'Moved/{{ALBUM}}', 'source': 'user'},
      };
      final f = folderRec('music/Boukmanflow/Borrowed Tapes');
      final own = await c.start(f, scope: kScopeFolder, shown: shown, landing: const {'vpath': 'copies', 'path': 'From Sam'});
      expect([own.ok, own.destinationChanged], [true, false]);
      fake.jobs.clear();
      final mirror = await c.start(folderRec('music/Boukmanflow/Harbour Lights'), scope: kScopeFolder, shown: shown);
      expect([mirror.ok, mirror.destinationChanged], [false, true], reason: 'a mirror reads the base and the lead');
    });

    test('Retry and Add again send a folder copy\'s own landing, where it was asked to go', () async {
      final f = folderRec('music/Boukmanflow/Borrowed Tapes');
      final failed = fake.addJob(f, scope: 'folder', state: 'failed');
      failed['params'] = {'scope': 'folder', 'landing': {'vpath': null, 'path': 'From Sam'}, 'destination': fake.destination['destination']};
      final c = make(home);
      await c.activate();
      final job = c.jobs.firstWhere((j) => j.id == failed['id']);
      expect(isKeepCopy(job), isTrue);
      final r = await c.retryWhereItRan(job);
      expect(r.ok, isTrue);
      final body = jsonDecode(fake.calls('POST', '/plugins/federation-copy/jobs').last.body) as Map;
      expect([body['scope'], body['landing'], body['recommendation']['filepath']], ['folder', {'path': 'From Sam'}, 'music/Boukmanflow/Borrowed Tapes']);
      expect(body.containsKey('destination'), isTrue, reason: 'the place it ran with');
    });

    test('a start answered 403 or 404 reads the gate again', () async {
      final c = make(home);
      await c.activate();
      final lists = fake.count('GET', '/api/v1/discovery/plugins');
      fake.refuse['/plugins/federation-copy/jobs'] = (403, 'Uploading Disabled');
      final r = await c.start(songRec('Late Train Verse'));
      expect([r.ok, r.error], [false, 'Uploading Disabled']);
      await settle();
      expect(fake.count('GET', '/api/v1/discovery/plugins'), lists + 1);
      fake.refuse['/plugins/federation-copy/jobs'] = (429, 'you have 20 jobs queued or running');
      await c.start(songRec('Late Train Verse'));
      await settle();
      expect(fake.count('GET', '/api/v1/discovery/plugins'), lists + 1, reason: 'a 429 is no gate');
    });
  });

  group("the gate a connected server's pages read", () {
    test('read once: unknown, then open with its scopes (Folder as from the explorer), the cap and where files land', () async {
      fake.listing['jobs'] = {'allowed': true, 'maxFolderSongs': 1000};
      expect(CopiesHub().gateFor(peer).state, KeepGateState.unknown);
      final g = await CopiesHub().ensureGate(peer);
      expect([g.state, g.scopes, g.maxFolderSongs, g.place?.vpath, [for (final l in g.libraries) l.vpath], g.marks],
          [KeepGateState.open, {'song', 'album', 'artist', 'artist-missing', 'folder'}, 1000, 'copies', ['copies'], true]);
      expect([g.allows('folder'), g.allows('album')], [true, true]);
      expect(fake.requests.every((r) => r.url.host == 'home.local'), isTrue, reason: "the own server's, never the peer's");
    });

    test('no pop-in: a page keeps the snapshot it built with; the answer applies from the next build', () async {
      final hold = Completer<void>();
      fake.destinationGate = hold;
      final first = CopiesHub().gateFor(peer);
      final reading = CopiesHub().ensureGate(peer);
      hold.complete();
      await reading;
      expect([first.state, first.allows('song')], [KeepGateState.unknown, false], reason: 'what the page drew with');
      expect(CopiesHub().gateFor(peer).allows('song'), isTrue, reason: 'the next page built');
    });

    test('no answer in time counts as closed for the visit; the late answer applies from the next build', () async {
      final hold = Completer<void>();
      fake.destinationGate = hold;
      final g = await CopiesHub().ensureGate(peer, timeout: const Duration(milliseconds: 5));
      expect(g.state, KeepGateState.closed);
      expect(CopiesHub().gateFor(peer).state, KeepGateState.closed);
      hold.complete();
      await settle();
      expect(CopiesHub().gateFor(peer).state, KeepGateState.open);
    });

    test('closed: a failed read, no upload right, no library, jobs not allowed, plug-ins off; marks only follow the ping', () async {
      fake.refuse['/api/v1/discovery/plugins'] = (500, 'boom');
      expect((await CopiesHub().ensureGate(peer)).state, KeepGateState.closed);
      fake.refuse.clear();
      expect((await CopiesHub().ensureGate(peer)).state, KeepGateState.open, reason: 'asked again: it answers now');
      home.noUpload = true;
      final noUpload = CopiesHub().gateFor(peer);
      expect([noUpload.state, noUpload.marks], [KeepGateState.closed, true],
          reason: 'earlier copies keep their marks (the lookup route is not gated)');
      home.noUpload = false;
      fake.listing['jobs'] = {'allowed': false};
      expect((await CopiesHub().ensureGate(peer, fresh: true)).state, KeepGateState.closed);
      home.discoveryPluginsAvailable = false;
      final off = CopiesHub().gateFor(peer);
      expect([off.state, off.marks], [KeepGateState.closed, false]);
      expect(CopiesHub().gateFor(home).state, KeepGateState.closed);
    });

    test('moving onto the peer reads it; a read that failed is asked again on the next step inside', () async {
      CopiesHub().install();
      addTearDown(() => ServerManager().currentServer = null);
      fake.refuse['/api/v1/discovery/plugins'] = (500, 'boom');
      ServerManager().currentServer = peer;
      BrowserManager().goToNavScreen();
      await settle();
      expect(CopiesHub().gateFor(peer).state, KeepGateState.closed);
      expect(BrowserManager().isLoading, isFalse);
      fake.refuse.clear();
      BrowserManager().addListToStack([]);
      await settle();
      expect(CopiesHub().gateFor(peer).state, KeepGateState.open, reason: 'from the next page built');
      final lists = fake.count('GET', '/api/v1/discovery/plugins');
      BrowserManager().addListToStack([]);
      await settle();
      expect(fake.count('GET', '/api/v1/discovery/plugins'), lists, reason: 'an open gate is not asked on every step');
    });

    test('an older server: no folder in its scopes, no cap', () async {
      (fake.listing['plugins'] as List)[1] = {
        'name': 'federation-copy',
        'capabilities': ['acquire'],
        'scopes': ['song', 'album', 'artist', 'artist-missing'],
      };
      final g = await CopiesHub().ensureGate(peer);
      expect([g.allows('folder'), g.allows('song'), g.maxFolderSongs], [false, true, null]);
    });
  });

  group("a browse page's marks", () {
    late DiscoveryJobsController jobs;
    late BrowseCopyMarks marks;
    setUp(() async {
      jobs = make(home)..discoverVisible = false; // browsing: Discover is not in front
      await jobs.activate();
      marks = BrowseCopyMarks(jobs: jobs, peer: peer, timer: pageTimers.call, watchLifecycle: false);
    });
    tearDown(() => marks.dispose());

    final late = songRec('Late Train Verse');
    final corner = songRec('Corner Store Loop');
    final roof = songRec('Rooftop Cypher');

    test("an album page: the pill shows the album job, the rows what it says of each song — done is not kept", () async {
      fake.addJob(albumRec(), scope: 'album', state: 'done', result: albumResult(
        copied: [late['filepath']],
        failed: [corner['filepath']],
        skipped: [(roof['filepath'], 'owned')],
      ));
      await marks.ask([albumRec(), late, corner, roof]);
      final pill = marks.pillJob(albumRec(), kScopeAlbum)!;
      expect([pill.fromOtherPeer, markerOfJob(pill.job)?.kind], [false, CopyMarkerKind.inCollection]);
      expect([
        for (final s in [late, corner, roof]) marks.songMarker(s, albumRec: albumRec())?.kind,
      ], [CopyMarkerKind.inCollection, CopyMarkerKind.failed, CopyMarkerKind.alreadyYours],
          reason: 'a song in the failed list never reads "in your collection"');
      expect(marks.knows(late), isTrue);
    });

    test('nothing on the rows while the album copy runs; the pill copies "2 of 3"', () async {
      fake.addJob(albumRec(), scope: 'album', state: 'running', statusText: '2 of 3 songs · 4.1 MB');
      fake.addJob(late, state: 'done', result: {'copied': {'filepath': 'copies/x.mp3'}});
      await marks.ask([albumRec(), late]);
      expect(marks.songMarker(late, albumRec: albumRec()), isNull);
      final m = markerOfJob(marks.pillJob(albumRec(), kScopeAlbum)!.job, album: 'Borrowed Tapes')!;
      expect([m.kind, m.done, m.total], [CopyMarkerKind.copying, 2, 3]);
    });

    test("another server's live album copy: \"Copying from\" on the pill only — never a card's badge, never a row", () async {
      fake.addJob(albumRec(peer: pc), scope: 'album', state: 'running', statusText: '1 of 3 songs');
      await marks.ask([albumRec(), late]);
      final pill = marks.pillJob(albumRec(), kScopeAlbum)!;
      expect([pill.fromOtherPeer, pill.job.peerId], [true, 4]);
      expect(marks.albumJob(albumRec()), isNull);
      expect(marks.cardMarker(albumRec()), isNull);
      expect(marks.songMarker(late, albumRec: albumRec()), isNull);
    });

    test("a card: its album copies and a finished artist copy's account of it; never a live artist copy", () async {
      final artistRec = {'source': 'federation', 'peer': pb, 'artist': 'Boukmanflow'};
      final walk = fake.addJob(artistRec, scope: 'artist', state: 'running', statusText: 'album 1 of 3 · Borrowed Tapes · 1 of 3 songs');
      await marks.ask([albumRec(), artistRec]);
      expect(marks.cardMarker(albumRec()), isNull, reason: 'no card guesses while the walk runs');
      final pick = marks.pillJob(artistRec, kScopeArtist)!;
      expect(markerOfJob(pick.job)?.kind, CopyMarkerKind.copying, reason: 'the artist pill reads it');
      walk['state'] = 'done';
      walk['result'] = {
        'scope': 'artist',
        'albums': [
          {'name': 'Borrowed Tapes', 'songs': {'total': 3, 'copied': [{}, {}, {}], 'skipped': [], 'failed': []}},
        ],
        'skippedAlbums': [],
        'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': []},
        'counts': {'total': 3, 'copied': 3, 'skipped': 0, 'failed': 0},
        'peer': pb,
      };
      await marks.reask(albumRec());
      expect(marks.cardMarker(albumRec())?.kind, CopyMarkerKind.inCollection);
    });

    test('a folder row: its folder copies only — a folder kept as an album shows nothing', () async {
      final tapes = folderRec('music/Boukmanflow/Borrowed Tapes');
      final harbour = folderRec('music/Boukmanflow/Harbour Lights');
      fake.addJob(tapes, scope: 'folder', state: 'running', statusText: '2 of 3 songs');
      fake.addJob(albumRec(album: 'Harbour Lights'), scope: 'album', state: 'done', result: albumResult(copied: ['x']));
      await marks.ask([tapes, harbour]);
      final m = marks.folderMarker(tapes)!;
      expect([m.kind, m.done, m.total], [CopyMarkerKind.copying, 2, 3]);
      expect(marks.folderMarker(harbour), isNull);
      expect(marks.pillJob(tapes, kScopeFolder)!.job.scope, 'folder');
    });

    test('the poll: only the live recs, every 4 s while in front, holding the job list\'s beat; then it rests', () async {
      final tapes = folderRec('music/Boukmanflow/Borrowed Tapes');
      final j = fake.addJob(tapes, scope: 'folder', state: 'running', statusText: '1 of 3 songs');
      await marks.ask([tapes, late]);
      expect(marks.anyLive, isTrue);
      expect(pageTimers.active?.delay, BrowseCopyMarks.kBeat);
      expect(jobs.pollBeat, DiscoveryJobsController.kDiscoverBeat, reason: 'the job list beats too: the end toast comes from the hub');
      j['statusText'] = '2 of 3 songs';
      final asked = fake.count('POST', '/lookup/batch');
      pageTimers.active!.fire();
      await settle();
      expect(fake.count('POST', '/lookup/batch'), asked + 1);
      final recs = (jsonDecode(fake.calls('POST', '/lookup/batch').last.body) as Map)['recommendations'] as List;
      expect(recs.single['filepath'], 'music/Boukmanflow/Borrowed Tapes', reason: 'only the live rec');
      expect(marks.folderMarker(tapes)!.done, 2);
      // a page pushed over it stops it
      marks.front = false;
      expect(pageTimers.active, isNull);
      expect(jobs.pollBeat, isNull);
      marks.front = true;
      await settle();
      j['state'] = 'done';
      j['result'] = albumResult(copied: ['a'])..['scope'] = 'folder';
      pageTimers.active!.fire();
      await settle();
      expect(marks.folderMarker(tapes)!.kind, CopyMarkerKind.inCollection);
      expect([marks.anyLive, pageTimers.active], [false, null]);
    });

    test('a failed re-ask backs off; a refused first ask draws no marks', () async {
      final tapes = folderRec('music/Boukmanflow/Borrowed Tapes');
      fake.addJob(tapes, scope: 'folder', state: 'running');
      await marks.ask([tapes]);
      fake.refuse['/lookup/batch'] = (500, 'boom');
      pageTimers.active!.fire();
      await settle();
      expect(pageTimers.active?.delay, const Duration(seconds: 8));
      expect(marks.folderMarker(tapes), isNotNull, reason: 'what it had stays');
      final fresh = BrowseCopyMarks(jobs: jobs, peer: peer, timer: pageTimers.call, watchLifecycle: false);
      final shift = folderRec('music/Boukmanflow/Second Shift');
      await fresh.ask([shift]);
      expect([fresh.knows(shift), fresh.folderMarker(shift)], [false, null]);
      fresh.dispose();
    });

    test('a first ask that failed is asked again once the back-off passes — not at each rebuild — and its marks land', () async {
      final shift = folderRec('music/Boukmanflow/Second Shift');
      fake.addJob(shift, scope: 'folder', state: 'done', result: albumResult(copied: ['a'])..['scope'] = 'folder');
      fake.refuse['/lookup/batch'] = (503, 'busy');
      await marks.ask([shift]);
      expect(marks.knows(shift), isFalse);
      final asked = fake.count('POST', '/lookup/batch');
      // The page rebuilding asks again at once never: it waits on the
      // back-off.
      await marks.ask([shift]);
      marks.askSoon([shift]);
      await settle();
      expect(fake.count('POST', '/lookup/batch'), asked);
      final retry = pageTimers.active!;
      expect(retry.delay, const Duration(seconds: 8));
      fake.refuse.remove('/lookup/batch');
      retry.fire();
      await settle();
      expect(fake.count('POST', '/lookup/batch'), asked + 1);
      expect(marks.folderMarker(shift)?.kind, CopyMarkerKind.inCollection);
    });

    test('the grid rebuilding faster than the debounce never holds its ask off', () async {
      marks.askSoon([albumRec()]);
      final first = pageTimers.active!;
      for (var i = 0; i < 10; i++) {
        marks.askSoon([albumRec()]);
      }
      expect(identical(pageTimers.active, first), isTrue, reason: 'the wait already running is kept');
      expect(pageTimers.made.where((t) => t.delay == const Duration(milliseconds: 250)), hasLength(1));
      marks.askSoon([albumRec(album: 'Harbour Lights')]);
      expect(identical(pageTimers.active, first), isFalse, reason: 'a new rec waits for the scroll to settle');
      pageTimers.active!.fire();
      await settle();
      final recs = (jsonDecode(fake.calls('POST', '/lookup/batch').last.body) as Map)['recommendations'] as List;
      expect(recs, hasLength(2));
      expect(fake.count('POST', '/lookup/batch'), 1);
    });

    test("a start from a Keep sheet on the page lands on its rows at once; reask after the sheet closes", () async {
      final tapes = folderRec('music/Boukmanflow/Borrowed Tapes');
      await marks.ask([tapes]);
      expect(marks.folderMarker(tapes), isNull);
      await jobs.start(tapes, scope: kScopeFolder);
      expect(marks.folderMarker(tapes)?.kind, CopyMarkerKind.waiting);
      final asked = fake.count('POST', '/lookup/batch');
      await marks.reask(tapes);
      expect(fake.count('POST', '/lookup/batch'), asked + 1);
    });

    test('each rec asked once a visit; the grid asks once the scroll settles; reset drops what is out', () async {
      await marks.ask([late]);
      await marks.ask([late]);
      expect(fake.count('POST', '/lookup/batch'), 1);
      marks.askSoon([albumRec()]);
      marks.askSoon([albumRec(album: 'Harbour Lights'), late]);
      expect(fake.count('POST', '/lookup/batch'), 1);
      expect(pageTimers.active?.delay, const Duration(milliseconds: 250));
      pageTimers.active!.fire();
      await settle();
      expect(fake.count('POST', '/lookup/batch'), 2);
      final recs = (jsonDecode(fake.calls('POST', '/lookup/batch').last.body) as Map)['recommendations'] as List;
      expect(recs, hasLength(2), reason: 'the two albums; the song was asked already');
      final gate = Completer<void>();
      fake.lookupGate = gate;
      fake.addJob(folderRec('music/x/y'), scope: 'folder', state: 'running');
      final out = marks.ask([folderRec('music/x/y')]);
      marks.reset();
      gate.complete();
      await out;
      expect(marks.knows(folderRec('music/x/y')), isFalse, reason: 'an answer for the page it was is dropped');
    });

    test("a rec's key is its content, whatever its keys' order", () {
      expect(BrowseCopyMarks.keyOf({'a': 1, 'b': {'y': 2, 'x': 1}}), BrowseCopyMarks.keyOf({'b': {'x': 1, 'y': 2}, 'a': 1}));
    });
  });

  group("a folder's facts", () {
    final folder = FolderRef.of('/music/Boukmanflow')!;
    final paths = [
      for (final a in ['Borrowed Tapes', 'Harbour Lights', 'Second Shift'])
        for (final t in ['01.mp3', '02.mp3', '03.mp3']) 'music/Boukmanflow/$a/$t',
    ];

    test('counted once, through the connected server, as the copy plans it', () async {
      final asked = <(Server, String)>[];
      final f = KeepFolderFactsLoader(peer: peer, folder: folder, list: (s, d) async {
        asked.add((s, d));
        return [...paths, 'music/Boukmanflow/notes.txt'];
      }, tags: (_, _) async => const {});
      expect([f.facts.counted, f.counting], [false, false]);
      final a = f.count();
      expect(f.counting, isTrue);
      await Future.wait([a, f.count()]);
      expect(asked, hasLength(1));
      expect([identical(asked.single.$1, peer), asked.single.$2], [true, '/music/Boukmanflow']);
      expect(f.facts.counts, (songs: 10, subfolders: 3), reason: 'no supported list known: the peer\'s list as is');
      expect([f.facts.overCap(1000), f.facts.overCap(9), f.facts.overCap(null)], [false, true, false]);
      expect(f.songRows!.first.data, '/music/Boukmanflow/Borrowed Tapes/01.mp3');
      f.dispose();
    });

    test('a failed count: "Couldn\'t count its songs", nothing asks again by itself', () async {
      var n = 0;
      final f = KeepFolderFactsLoader(peer: peer, folder: folder, list: (_, _) async {
        n++;
        throw Exception('down');
      });
      await f.count();
      await f.count();
      expect([f.facts.countFailed, f.facts.counted, f.songRows, n], [true, false, null, 1]);
      f.dispose();
    });

    test('the tags: once, for at most 100 songs; past it, or no answer, none', () async {
      final asked = <List<String>>[];
      Future<Map<String, MusicMetadata>> tags(Server s, List<String> fps) async {
        asked.add(fps);
        return {
          for (final p in fps)
            p: MusicMetadata('Boukmanflow', p.split('/')[2], 'T', 1, 1, 2019, 'h', null, null, genres: const ['Hip-Hop'], albumArtist: 'Boukmanflow'),
        };
      }

      final f = KeepFolderFactsLoader(peer: peer, folder: folder, list: (_, _) async => paths, tags: tags);
      await Future.wait([f.readTags(), f.readTags()]);
      expect(asked, hasLength(1));
      expect(f.facts.tags!.map((t) => t.album).toSet(), {'Borrowed Tapes', 'Harbour Lights', 'Second Shift'});
      expect(f.songRows!.first.metadata?.albumArtist, 'Boukmanflow');
      final p = scopeTarget(vpath: 'copies', layout: '{{ALBUMARTIST}}/{{ALBUM}}', scope: kScopeFolder, landing: const {'tags': true},
          folder: folder.filepath, folderSongs: f.facts.songs, folderTags: f.facts.tags);
      expect([p.crumbs, p.perAlbum], [['copies', 'Boukmanflow'], true]);
      f.dispose();

      final big = KeepFolderFactsLoader(peer: peer, folder: folder,
          list: (_, _) async => [for (var i = 0; i < 101; i++) 'music/Boukmanflow/x/$i.mp3'], tags: tags);
      await big.readTags();
      expect([big.facts.tagsRead, big.facts.tags, asked.length], [true, null, 1], reason: 'past 100 songs: never asked');
      big.dispose();

      final quiet = KeepFolderFactsLoader(peer: peer, folder: folder, list: (_, _) async => paths, tags: (_, _) async => const {});
      await quiet.readTags();
      expect([quiet.facts.tagsRead, quiet.facts.tags], [true, null], reason: 'no answer: no tags');
      quiet.dispose();
    });

    test("the own library's folders: asked once per folder; one that does not exist reads as missing", () async {
      final asked = <String>[];
      final l = OwnFolderLister(own: home, fetch: (s, d) async {
        asked.add(d);
        if (d == '/copies/Borrowed Tapes') throw Exception('no such folder');
        return ['Boukmanflow', 'Color Out', 'From Sam'];
      });
      expect(l.folders('copies', ''), isNull, reason: 'Looking up…');
      await l.load('copies', '');
      expect(l.folders('copies', '')!.names, ['Boukmanflow', 'Color Out', 'From Sam']);
      final missing = await l.load('copies', 'Borrowed Tapes');
      expect([missing.missing, missing.names], [true, isEmpty]);
      await l.load('copies', ' Borrowed Tapes/ ');
      expect(asked, ['/copies', '/copies/Borrowed Tapes']);
      expect(OwnFolderLister.directoryOf('copies', 'a\\b'), '/copies/a/b');
      l.dispose();
    });
  });
}
