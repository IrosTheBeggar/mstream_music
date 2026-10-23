// DiscoveryJobsController — the Discover visit's plug-in jobs: the gate
// (listing, destination, the account's upload right), the batch lookup of
// the connected servers' rows and what it draws (markers, card counts,
// "copying from <other server>"), start / cancel / retry / clear with the
// server's words verbatim, and the poll — 1.5 s with a sheet open, 4 s while
// Discover shows a live marker, otherwise stopped; doubled per failure to
// 60 s; paused in the background and caught up on resume; a job seen live
// and now finished is news and the rows are looked up again.
//
// The plug-in API is a scripted fake (discovery_plugin_fakes.dart) behind
// the real DiscoveryPluginsApi; the poll's timers are fired by hand.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/util/discover_badges.dart';
import 'package:mstream_music/util/discover_copy_gate.dart';

import 'discovery_plugin_fakes.dart';

const pb = {'id': 1, 'name': 'Stage Peer B'};
const pc = {'id': 4, 'name': 'Stage Peer C'};

/// A taste peers row as the route sends it, parsed the way Discover parses
/// it (the lead keeps it raw).
DiscoveryLead lead(Map<String, Object> peer, String title,
        {String artist = 'Boukmanflow', String? album = 'Borrowed Tapes', String? albumArtist, double similarity = 0.8}) =>
    DiscoveryLead.fromServerMap({
      'artist': artist,
      'title': title,
      'album': album,
      'albumArtist': albumArtist,
      'year': 2019,
      'duration': 221,
      'similarity': similarity,
      'genreTags': null,
      'albumArt': 'abc.jpg',
      'seedHash': null,
      'filepath': 'peerlib/$artist/$album/$title.mp3',
      'peer': {'id': peer['id'], 'name': peer['name']},
      'source': 'federation',
    })!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePluginServer fake;
  late FakeTimers timers;
  late Server server;
  final controllers = <DiscoveryJobsController>[];

  DiscoveryJobsController make({Server? on}) {
    final c = DiscoveryJobsController(
      server: on ?? server,
      api: fake.api(on ?? server),
      timer: timers.call,
      watchLifecycle: false,
    );
    controllers.add(c);
    return c;
  }

  final late = lead(pb, 'Late Train Verse', similarity: 0.9);
  final corner = lead(pb, 'Corner Store Loop', similarity: 0.7);
  final roof = lead(pc, 'Rooftop Cypher', similarity: 0.8);
  final glass = lead(pb, 'Glass One', artist: 'Color Out', album: 'Glass', similarity: 0.6);
  final rows = [late, roof, corner, glass];

  setUp(() {
    fake = FakePluginServer();
    timers = FakeTimers();
    server = Server('http://home.local:3000', null, null, 'JWT', 'home')
      ..discoveryPluginsAvailable = true
      ..noUpload = false;
  });
  tearDown(() {
    for (final c in controllers) {
      c.dispose();
    }
    controllers.clear();
  });

  group('the gate', () {
    test('plug-ins off: nothing is asked and Keep a copy is hidden', () async {
      server.discoveryPluginsAvailable = false;
      final c = make();
      await c.activate();
      await c.setRows(rows);
      expect(fake.requests, isEmpty);
      expect([c.gate().status, c.gate().block], [CopyGateStatus.hidden, CopyGateBlock.pluginsOff]);
      expect(c.copiesVisible, isFalse);
    });

    test('Discover opened: the listing, the destination and the job list, once a visit', () async {
      final c = make();
      expect(c.gate().status, CopyGateStatus.unknown, reason: 'still asking: draw nothing yet');
      await c.activate();
      await c.activate();
      expect([fake.count('GET', '/discovery/plugins'), fake.count('GET', '/collection/destination'), fake.count('GET', '/plugin-jobs')], [1, 1, 1]);
      expect(c.gate().ready, isTrue);
      expect(c.gate('album').ready, isTrue);
      expect(c.gate('folder').status, CopyGateStatus.hidden, reason: 'never Folder');
      expect(c.copiesVisible, isTrue);
      expect(c.destination!.destination!.vpath, 'copies');
      expect(fake.requests.every((r) => r.url.host == 'home.local'), isTrue);
    });

    test('a listing that failed hides the card, and is asked again on the next load', () async {
      fake.refuse['/discovery/plugins'] = (500, 'boom');
      final c = make();
      await c.activate();
      expect([c.gate().status, c.gate().block], [CopyGateStatus.hidden, CopyGateBlock.unavailable]);
      fake.refuse.clear();
      await c.activate();
      expect(c.gate().ready, isTrue);
      expect([fake.count('GET', '/discovery/plugins'), fake.count('GET', '/collection/destination'), fake.count('GET', '/plugin-jobs')], [2, 1, 1],
          reason: 'only what had not answered');
    });

    test('uploads off and no library read as one line each; jobs not allowed hides', () async {
      server.noUpload = true;
      var c = make();
      await c.activate();
      expect([c.gate().status, c.gate().wordingKey], [CopyGateStatus.line, kKeepUploadsOffKey]);
      expect(c.copiesVisible, isFalse);

      server.noUpload = false;
      fake.destination = {'destination': null, 'saved': null, 'libraries': []};
      c = make();
      await c.activate();
      expect([c.gate().status, c.gate().wordingKey], [CopyGateStatus.line, kKeepNoLibraryKey]);

      fake.listing = {...fake.listing, 'jobs': {'allowed': false}};
      c = make();
      await c.activate();
      expect([c.gate().status, c.gate().block], [CopyGateStatus.hidden, CopyGateBlock.jobsNotAllowed]);
    });

    test("a connected server's Server is asked through its parent", () async {
      final peer = Server('federated://home/1', null, null, null, 'peer-1')
        ..federationParent = 'home'
        ..federationPeerId = 1
        ..parentServer = server;
      final c = make(on: peer);
      expect(identical(c.server, server), isTrue);
      await c.activate();
      expect(fake.requests.every((r) => r.url.toString().startsWith('http://home.local:3000/api/v1/discovery/')), isTrue);
    });

    test('the scopes a row and a card offer', () async {
      final c = make();
      await c.activate();
      expect(c.scopesForRow(late), ['song', 'album', 'artist', 'artist-missing']);
      expect(c.scopesForCard([late, corner]), ['album', 'artist', 'artist-missing']);
      final comp = lead(pb, 'Party Verse', album: 'Block Party Comp', albumArtist: 'Various Artists');
      expect(c.scopesForCard([comp], compilation: true), ['album']);
      expect(c.scopesForRow(lead(pb, 'Untagged', artist: '', album: null)), ['song']);
    });
  });

  group('rows and lookups', () {
    test('every answer is looked up, rows exactly as received; the markers follow the jobs', () async {
      fake.addJob(late.raw, scope: 'album', state: 'running', progress: 0.4, statusText: '1 of 3 songs · 7.4 MB · Late Train Verse');
      fake.addJob(glass.raw, state: 'failed');
      final c = make();
      await c.activate();
      await c.setRows(rows);
      final batch = fake.calls('POST', '/lookup/batch').single;
      expect(jsonDecode(batch.body)['recommendations'], [for (final r in rows) jsonDecode(jsonEncode(r.raw))]);
      expect(c.markerFor(late)!.kind, CopyMarkerKind.copying);
      expect(c.markerFor(late)!.fraction, 0.4);
      expect(c.markerFor(corner)!.kind, CopyMarkerKind.copying, reason: 'the album job sits on every row of the album');
      expect(c.markerFor(roof), isNull, reason: "Stage Peer C's row: B's album copy is not C's");
      expect(c.markerFor(glass)!.kind, CopyMarkerKind.failed);
      final card = c.cardMarker([late, corner])!;
      expect([card.kind, card.done, card.total], [CopyMarkerKind.copying, 1, 3], reason: 'copying 1 of 3');
      expect(c.cardMarker([roof]), isNull);
      // the sheet on C's row: B's live album copy, said to be another server's
      final other = c.sheetJob(roof, 'album')!;
      expect([other.fromOtherPeer, other.job.peerName], [true, 'Stage Peer B']);
      expect(c.sheetJob(late, 'album')!.fromOtherPeer, isFalse);
      expect(c.sheetJob(late, 'artist'), isNull);
    });

    test('a newer answer drops the lookup of an older one; an empty answer lets the rows go', () async {
      final c = make();
      await c.activate();
      fake.lookupGate = Completer<void>();
      final first = c.setRows([late]);
      await settle();
      fake.addJob(roof.raw, state: 'queued');
      final second = c.setRows([roof]);
      fake.lookupGate!.complete();
      await Future.wait([first, second]);
      expect(c.leads, [roof]);
      expect(c.markerFor(roof)!.kind, CopyMarkerKind.waiting);
      expect(c.rowOf(late), isNull);
      await c.setRows(const []);
      expect([c.rows, c.leads], [isEmpty, isEmpty]);
      expect(fake.count('POST', '/lookup/batch'), 2, reason: 'nothing to look up for no rows');
    });

    test('a failed lookup keeps what the rows had and says so', () async {
      fake.addJob(late.raw, state: 'done', result: {'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/Late Train Verse.mp3'}});
      final c = make();
      await c.activate();
      await c.setRows(rows);
      expect(c.markerFor(late)!.kind, CopyMarkerKind.inCollection);
      fake.refuse['/lookup/batch'] = (400, 'recommendations[2].year must be ≥ 1000');
      await c.refreshLookups();
      expect(c.lookupFailed, isTrue);
      expect(c.markerFor(late)!.kind, CopyMarkerKind.inCollection);
    });
  });

  group('verbs', () {
    test('start: the row as received, the pill busy until the server answers, the job on its rows', () async {
      final c = make();
      await c.activate();
      await c.setRows(rows);
      final pending = c.start(late.raw, scope: 'album');
      expect(c.isStarting(late.raw, 'album'), isTrue);
      final r = await pending;
      expect(c.isStarting(late.raw, 'album'), isFalse);
      expect([r.ok, r.created, r.fromOtherPeer, r.job!.scope], [true, true, false, 'album']);
      final body = jsonDecode(fake.calls('POST', '/plugins/federation-copy/jobs').single.body) as Map;
      expect(body, {'recommendation': jsonDecode(jsonEncode(late.raw)), 'scope': 'album'});
      expect(c.jobs.first.id, r.job!.id);
      expect(c.markerFor(late)!.kind, CopyMarkerKind.waiting);
      expect(c.markerFor(corner)!.kind, CopyMarkerKind.waiting);
      expect(c.summary.running, 1);
      expect(timers.active?.delay, DiscoveryJobsController.kDiscoverBeat, reason: 'live now: Discover polls at 4 s');
      // a song job sends no scope
      await c.start(glass.raw);
      expect((jsonDecode(fake.calls('POST', '/plugins/federation-copy/jobs').last.body) as Map).containsKey('scope'), isFalse);
    });

    test("refused at start: the server's words, verbatim", () async {
      final c = make();
      await c.activate();
      fake.refuse['/plugins/federation-copy/jobs'] = (403, 'Uploading Disabled');
      final r = await c.start(late.raw);
      expect([r.ok, r.error, r.status], [false, 'Uploading Disabled', 403]);
      fake.refuse['/plugins/federation-copy/jobs'] = (429, 'you have 20 jobs queued or running — wait for some to finish (the limit is 20)');
      expect((await c.start(late.raw)).error, 'you have 20 jobs queued or running — wait for some to finish (the limit is 20)');
    });

    test("200 with another server's live album copy: nothing new started, said so", () async {
      final c = make();
      await c.activate();
      fake.existing = fake.addJob(late.raw, scope: 'album', state: 'running');
      final r = await c.start(roof.raw, scope: 'album');
      expect([r.ok, r.created, r.fromOtherPeer], [true, false, true]);
      // your own live job for the same key is not another server's
      final mine = await c.start(late.raw, scope: 'album');
      expect([mine.created, mine.fromOtherPeer], [false, false]);
    });

    test('cancel: queued goes at once, running is asked to stop; a cancel that lost the race reads the outcome', () async {
      final queued = fake.addJob(late.raw, state: 'queued');
      final running = fake.addJob(corner.raw, state: 'running', progress: 0.5);
      final c = make();
      await c.activate();
      await c.setRows(rows);
      final a = await c.cancel(c.jobs.firstWhere((j) => j.id == queued['id']));
      expect(a.outcome, CancelOutcome.cancelled);
      expect(c.jobs.firstWhere((j) => j.id == queued['id']).state, JobState.cancelled);
      expect(c.markerFor(late), isNull, reason: 'cancelled: no marker');
      final b = await c.cancel(c.jobs.firstWhere((j) => j.id == running['id']));
      expect(b.outcome, CancelOutcome.requested);
      expect(c.markerFor(corner)!.kind, CopyMarkerKind.stopping);
      // the job finished before the cancel reached it
      running['state'] = 'done';
      running['result'] = {'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/Corner Store Loop.mp3'}};
      final listsBefore = fake.count('GET', '/plugin-jobs');
      final lookupsBefore = fake.count('POST', '/lookup/batch');
      final r = await c.cancel(c.jobs.firstWhere((j) => j.id == running['id']));
      await settle();
      expect([r.outcome, r.message], [CancelOutcome.alreadyFinished, 'job ${running['id']} is already done']);
      expect(fake.count('GET', '/plugin-jobs'), listsBefore + 1, reason: 'read the list again');
      expect(fake.count('POST', '/lookup/batch'), greaterThan(lookupsBefore));
      expect(c.markerFor(corner)!.kind, CopyMarkerKind.inCollection);
    });

    test('retry sends the job\'s own recommendation and scope again', () async {
      final failed = fake.addJob(late.raw, scope: 'artist-missing', state: 'failed');
      final c = make();
      await c.activate();
      final r = await c.retry(c.jobs.firstWhere((j) => j.id == failed['id']));
      expect(r.created, isTrue);
      final body = jsonDecode(fake.calls('POST', '/plugins/federation-copy/jobs').single.body) as Map;
      expect(body, {'recommendation': jsonDecode(jsonEncode(late.raw)), 'scope': 'artist-missing'});
    });

    test('clear finished: the server drops them, the list and the lookups are read again', () async {
      fake.addJob(late.raw, state: 'failed');
      fake.addJob(corner.raw, state: 'running');
      final c = make();
      await c.activate();
      await c.setRows(rows);
      expect([c.summary.running, c.summary.failed], [1, 1]);
      final lookups = fake.count('POST', '/lookup/batch');
      expect(await c.clearFinished(), 1);
      await settle();
      expect([c.summary.running, c.summary.failed], [1, 0]);
      expect(c.markerFor(late), isNull);
      expect(fake.count('POST', '/lookup/batch'), lookups + 1);
    });

    test('the destination: saved, refused with the field, back to the default', () async {
      final c = make();
      await c.activate();
      expect(await c.saveDestination(const CollectionDestination(vpath: 'copies', base: 'From peers', layout: '{{PEER}}/{{ARTIST}}/{{ALBUM}}')), isTrue);
      expect([c.destination!.destination!.source, c.destination!.destination!.base], ['user', 'From peers']);
      fake.refuse['/collection/destination'] = (400, 'destination layout: unknown variable {{TRACK}}');
      expect(await c.saveDestination(const CollectionDestination(vpath: 'copies', layout: '{{TRACK}}')), isFalse);
      expect(c.destinationError, 'destination layout: unknown variable {{TRACK}}');
      expect(c.destination!.destination!.base, 'From peers', reason: 'what was saved stays');
      fake.refuse.clear();
      expect(await c.saveDestination(null), isTrue);
      expect(c.destination!.destination!.isDefault, isTrue);
    });
  });

  group('where files land: what a start sends, what a refusal draws, which answer wins', () {
    const layout = '{{ALBUMARTIST}}/{{ALBUM}}';
    Map<String, dynamic> place(String base) => {'vpath': 'copies', 'base': base, 'layout': layout, 'source': 'user'};
    CollectionDestination saved(String base) => CollectionDestination(vpath: 'copies', base: base, layout: layout);
    Map startBody() => jsonDecode(fake.calls('POST', '/plugins/federation-copy/jobs').last.body) as Map;
    String? drawnBase(DiscoveryJobsController c) => c.destination?.destination?.base;
    Future<void> releaseReads() async {
      fake.holdReads = false;
      for (final r in fake.heldReads) {
        if (!r.isCompleted) r.complete();
      }
      await settle();
    }

    test('a start sends the place shown, its source dropped; the job is pinned to it', () async {
      final c = make();
      await c.activate();
      final shown = c.destination!.destination!;
      expect(shown.source, 'default');
      final r = await c.start(late.raw, scope: 'album', shown: ShownPlace(shown));
      expect(startBody(), {
        'recommendation': jsonDecode(jsonEncode(late.raw)),
        'scope': 'album',
        'destination': {'vpath': 'copies', 'base': '', 'layout': layout},
      });
      expect([r.ok, r.created, r.destinationChanged], [true, true, false]);
      expect(r.job!.destination!.vpath, 'copies');
      // nothing shown: no place sent, nothing checked
      await c.start(glass.raw);
      expect(startBody().containsKey('destination'), isFalse);
    });

    test("409 destination_changed: nothing started, the answer's place drawn at once, the view read again", () async {
      final c = make();
      await c.activate();
      final shown = c.destination!.destination!;
      // saved on another device since the card drew its place
      fake.destination = {...fake.destination, 'destination': place('From peers')};
      fake.holdReads = true;
      final r = await c.start(late.raw, shown: ShownPlace(shown));
      expect([r.ok, r.destinationChanged, r.status], [false, true, 409]);
      expect(fake.jobs, isEmpty, reason: 'nothing started');
      expect(c.jobs, isEmpty);
      expect(drawnBase(c), 'From peers', reason: "the answer's own place, before the read answers");
      expect(c.destination!.libraries.single.vpath, 'copies', reason: 'the rest of the view stays');
      expect(c.gate().ready, isTrue);
      await settle();
      expect(fake.heldReads, hasLength(1), reason: 'the view is read again');
      expect(drawnBase(c), 'From peers');

      // another account's live job is the other 409: its words, nothing redrawn or read
      fake.startAnswer = (409, {'error': 'someone else on this server is already getting this — try again in a moment'});
      final other = await c.start(corner.raw, shown: ShownPlace(c.destination!.destination));
      expect([other.destinationChanged, other.error, other.status],
          [false, 'someone else on this server is already getting this — try again in a moment', 409]);
      await settle();
      expect(fake.heldReads, hasLength(1), reason: 'nothing read again');
      await releaseReads();
      expect(drawnBase(c), 'From peers');
    });

    test('a 409 naming nowhere closes the gate as "no library takes new files"; one naming none keeps what is drawn', () async {
      final c = make();
      await c.activate();
      final shown = c.destination!.destination!;
      fake.holdReads = true;
      fake.startAnswer = (409, {'error': 'destination_changed', 'message': 'moved'});
      expect((await c.start(late.raw, shown: ShownPlace(shown))).destinationChanged, isTrue);
      expect(drawnBase(c), '', reason: 'no place named: what is drawn stays until the read answers');
      fake.startAnswer = (409, {'error': 'destination_changed', 'message': 'moved', 'destination': null});
      expect((await c.start(late.raw, shown: ShownPlace(shown))).destinationChanged, isTrue);
      expect(c.destination!.destination, isNull);
      expect([c.gate().status, c.gate().block], [CopyGateStatus.line, CopyGateBlock.noLibrary]);
      await releaseReads();
    });

    test('re-reads draw the last one known meanwhile; an older answer landing after a newer one draws nothing', () async {
      final c = make();
      await c.activate();
      fake.holdReads = true;
      fake.destination = {...fake.destination, 'destination': place('first')};
      final a = c.loadDestination();
      await settle();
      fake.destination = {...fake.destination, 'destination': place('second')};
      final b = c.loadDestination();
      await settle();
      expect(fake.heldReads, hasLength(2));
      expect(drawnBase(c), '', reason: 'nothing new yet: the last one known');
      fake.heldReads[1].complete();
      await b;
      expect(drawnBase(c), 'second');
      fake.heldReads[0].complete();
      await a;
      expect(drawnBase(c), 'second', reason: 'the older answer is dropped');
      // a failed read keeps what is drawn
      fake.holdReads = false;
      fake.refuse['/collection/destination'] = (502, 'bad gateway');
      await c.loadDestination();
      expect([drawnBase(c), c.destinationFailed], ['second', false]);
    });

    test('a save always wins: a read or a refusal asked before it landed draws nothing', () async {
      final c = make();
      await c.activate();
      fake.holdReads = true;
      final read = c.loadDestination();
      await settle();
      expect(await c.saveDestination(saved('Saved')), isTrue);
      expect(drawnBase(c), 'Saved');
      fake.heldReads.single.complete();
      await read;
      expect(drawnBase(c), 'Saved', reason: 'the read went out before the save landed');

      // a start out before a save, refused after it: its place is not drawn
      fake.startGate = Completer<void>();
      fake.startAnswer = (409, {'error': 'destination_changed', 'destination': place('Stale')});
      final pending = c.start(late.raw, shown: ShownPlace(c.destination!.destination));
      await settle();
      expect(await c.saveDestination(saved('Saved again')), isTrue);
      fake.startGate!.complete();
      expect((await pending).destinationChanged, isTrue);
      expect(drawnBase(c), 'Saved again');
      await releaseReads();
      expect(drawnBase(c), 'Saved again');
    });

    test("Retry: the card's sends the place it shows now; the Copies sheet's the one the copy ran with — its pin, else its result's, else where files land now, read first", () async {
      final pinned = fake.addJob(late.raw, scope: 'album', state: 'failed');
      pinned['params'] = {'scope': 'album', 'destination': place('Pinned')};
      final older = fake.addJob(corner.raw, state: 'failed', result: {'destination': place('Ran')});
      final bare = fake.addJob(glass.raw, state: 'failed');
      final c = make();
      await c.activate();
      DiscoveryJob job(Map<String, dynamic> wire) => c.jobs.firstWhere((j) => j.id == wire['id']);
      Map? sent() => startBody()['destination'] as Map?;

      // The place it ran with — moved since, so the server's 409 says so.
      final r = await c.retryWhereItRan(job(pinned));
      expect(sent(), {'vpath': 'copies', 'base': 'Pinned', 'layout': layout});
      expect([r.destinationChanged, startBody()['scope']], [true, 'album']);
      await c.retryWhereItRan(job(older));
      expect(sent()!['base'], 'Ran');

      // No place of its own: the destination is read first, and that is sent.
      await settle();
      fake.destination = {...fake.destination, 'destination': place('Now')};
      final reads = fake.count('GET', '/collection/destination');
      final now = await c.retryWhereItRan(job(bare));
      expect(fake.count('GET', '/collection/destination'), reads + 1);
      expect(sent()!['base'], 'Now');
      expect([now.ok, now.created], [true, true]);

      // The card's Retry sends what the card shows.
      await c.retry(job(pinned), shown: ShownPlace(c.destination!.destination));
      expect(sent()!['base'], 'Now');
    });

    test("the Copies sheet's Retry never sends no place: a copy pinned to nowhere sends null, which the server refuses while the account has a place", () async {
      final nowhere = fake.addJob(late.raw, scope: 'album', state: 'failed');
      // Its pin outranks a place its result names.
      nowhere['params'] = {'scope': 'album', 'destination': null};
      nowhere['result'] = {'destination': place('Ran')};
      final c = make();
      await c.activate();
      final job = c.jobs.single;
      expect([job.pinnedNowhere, job.destination, job.ranWith?.destination], [true, null, null]);
      final r = await c.retryWhereItRan(job);
      expect(startBody().containsKey('destination'), isTrue);
      expect(startBody()['destination'], isNull);
      expect([r.ok, r.destinationChanged], [false, true]);
      expect(fake.jobs, hasLength(1), reason: 'nothing started');
    });

    test('a copy that names no place, the read failing and no place ever known: it sends nowhere, never no key', () async {
      fake.addJob(glass.raw, state: 'failed');
      fake.refuse['/collection/destination'] = (502, 'bad gateway');
      final c = make();
      await c.activate();
      expect(c.destination, isNull);
      final r = await c.retryWhereItRan(c.jobs.single);
      expect(startBody().containsKey('destination'), isTrue);
      expect(startBody()['destination'], isNull);
      expect(r.destinationChanged, isTrue, reason: 'the account has a place: the server says so');
      expect(fake.jobs, hasLength(1), reason: 'nothing started');
    });

    test("the Copies sheet's Retry is busy while the read it waits on is out: a second tap sends nothing", () async {
      fake.addJob(glass.raw, state: 'failed');
      final c = make();
      await c.activate();
      final job = c.jobs.single;
      final reads = fake.count('GET', '/collection/destination');
      fake.holdReads = true;
      final first = c.retryWhereItRan(job);
      await settle();
      expect(c.isStarting(glass.raw), isTrue, reason: 'its pills are busy');
      expect((await c.retryWhereItRan(job)).ignored, isTrue);
      expect(fake.count('GET', '/collection/destination'), reads + 1, reason: 'one read');
      await releaseReads();
      final r = await first;
      expect([r.ok, r.created], [true, true]);
      expect(fake.calls('POST', '/plugins/federation-copy/jobs'), hasLength(1));
      expect(c.isStarting(glass.raw), isFalse);
    });

    test('a live job already covering the key answers 200 created:false even to a place that moved: followed, never a refusal', () async {
      final c = make();
      await c.activate();
      fake.existing = fake.addJob(late.raw, scope: 'album', state: 'running');
      final r = await c.start(late.raw, scope: 'album', shown: ShownPlace(saved('Stale')));
      expect([r.ok, r.created, r.destinationChanged, r.error], [true, false, false, null]);
      expect(r.job!.id, fake.existing!['id']);
      expect(drawnBase(c), '', reason: 'nothing redrawn');
    });

    test('an older server refuses the key: the start goes through without it', () async {
      final c = make();
      await c.activate();
      fake.rejectsDestination = true;
      final r = await c.start(late.raw, shown: ShownPlace(c.destination!.destination));
      expect([r.ok, r.created, r.error], [true, true, null]);
      final starts = fake.calls('POST', '/plugins/federation-copy/jobs');
      expect([for (final s in starts) (jsonDecode(s.body) as Map).containsKey('destination')], [true, false]);
    });
  });

  group('the poll', () {
    test('nothing live: no poll at all', () async {
      fake.addJob(late.raw, state: 'done', result: {'copied': {'filepath': 'x.mp3'}});
      final c = make();
      await c.activate();
      await c.setRows(rows);
      expect(c.pollBeat, isNull);
      expect(timers.active, isNull);
    });

    test('4 s while Discover shows a live marker, 1.5 s with a sheet open, stopped when Discover is covered', () async {
      fake.addJob(late.raw, scope: 'album', state: 'running', progress: 0.1);
      final c = make();
      await c.activate();
      await c.setRows(rows);
      expect(timers.active!.delay, const Duration(seconds: 4));
      final release = c.holdFast();
      expect(timers.active!.delay, const Duration(milliseconds: 1500));
      release();
      release();
      expect(timers.active!.delay, const Duration(seconds: 4), reason: 'a second release is harmless');
      c.discoverVisible = false;
      expect(timers.active, isNull, reason: 'Discover covered, no sheet: stopped');
      final lists = fake.count('GET', '/plugin-jobs');
      c.discoverVisible = true;
      await settle();
      expect(fake.count('GET', '/plugin-jobs'), lists + 1, reason: 'back in front: catch up at once');
      expect(timers.active!.delay, const Duration(seconds: 4));
    });

    test('each beat reads the list; progress lands on the rows; a job seen live and now finished is news', () async {
      final j = fake.addJob(late.raw, scope: 'album', state: 'running', progress: 0.1, statusText: '0 of 3 songs · 0.0 MB');
      final c = make();
      await c.activate();
      await c.setRows(rows);
      final news = <DiscoveryJob>[];
      c.finished.listen(news.add);
      j['progress'] = 0.66;
      j['statusText'] = '2 of 3 songs · 14.8 MB · Corner Store Loop';
      timers.active!.fire();
      await settle();
      expect(c.markerFor(late)!.fraction, 0.66);
      expect([c.cardMarker([late, corner])!.done, c.cardMarker([late, corner])!.total], [2, 3]);
      final lookups = fake.count('POST', '/lookup/batch');
      j['state'] = 'done';
      j['progress'] = 1;
      j['result'] = {
        'scope': 'album', 'songs': {'total': 3, 'copied': [{}, {}], 'skipped': [{}], 'failed': []},
        'counts': {'total': 3, 'copied': 2, 'skipped': 1, 'failed': 0}, 'stopped': null, 'peer': pb,
      };
      timers.active!.fire();
      await settle();
      expect([for (final n in news) n.id], [j['id']]);
      expect(c.justFinished.single.id, j['id']);
      expect(c.markerFor(late)!.kind, CopyMarkerKind.inCollection);
      expect(c.cardMarker([late, corner])!.kind, CopyMarkerKind.inCollection);
      expect(fake.count('POST', '/lookup/batch'), lookups + 1, reason: 'a job ended: the rows are asked again');
      expect(timers.active, isNull, reason: 'nothing live: the poll stops');
      expect(c.summary.shown, isFalse, reason: 'a finished copy that landed leaves the Copies strip');
    });

    test('failures back off: doubled per failure, at most 60 s; a read that works resets it', () async {
      fake.addJob(late.raw, state: 'running');
      final c = make();
      await c.activate();
      await c.setRows(rows);
      fake.refuse['/plugin-jobs'] = (500, 'boom');
      final delays = <int>[];
      for (var i = 0; i < 6; i++) {
        timers.active!.fire();
        await settle();
        delays.add(timers.active!.delay.inSeconds);
      }
      expect(delays, [8, 16, 32, 60, 60, 60]);
      expect(c.jobsError, 'boom', reason: "the Copies sheet's error, in the server's words");
      fake.refuse.clear();
      timers.active!.fire();
      await settle();
      expect(timers.active!.delay, const Duration(seconds: 4));
      expect(c.jobsError, isNull);
    });

    test('in the background the poll pauses; on resume it catches up', () async {
      final j = fake.addJob(late.raw, state: 'running');
      final c = make();
      await c.activate();
      await c.setRows(rows);
      final news = <DiscoveryJob>[];
      c.finished.listen(news.add);
      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(timers.active, isNotNull, reason: 'inactive is passing: still polling');
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(timers.active, isNull);
      expect(c.pollBeat, isNull);
      j['state'] = 'done';
      j['result'] = {'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/Late Train Verse.mp3'}};
      final lists = fake.count('GET', '/plugin-jobs');
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(fake.count('GET', '/plugin-jobs'), lists + 1, reason: 'caught up at once');
      expect([for (final n in news) n.id], [j['id']], reason: 'what finished while away is news on return');
      expect(c.markerFor(late)!.kind, CopyMarkerKind.inCollection);
    });

    test('a poll that changes nothing notifies nobody', () async {
      fake.addJob(late.raw, state: 'running', progress: 0.2);
      final c = make();
      await c.activate();
      await c.setRows(rows);
      var notes = 0;
      c.addListener(() => notes++);
      timers.active!.fire();
      await settle();
      expect(notes, 0);
      fake.jobs.first['progress'] = 0.3;
      timers.active!.fire();
      await settle();
      expect(notes, 1);
    });
  });

  test('the Copies strip counts: "Copying 2 · 1 failed"', () async {
    fake.addJob(late.raw, state: 'running');
    fake.addJob(corner.raw, scope: 'album', state: 'queued');
    fake.addJob(glass.raw, state: 'failed');
    fake.addJob(roof.raw, scope: 'album', state: 'done', result: {
      'scope': 'album', 'songs': {'total': 1, 'copied': [], 'skipped': [], 'failed': []},
      'counts': {'total': 1, 'copied': 0, 'skipped': 0, 'failed': 0}, 'stopped': 'peer', 'peer': pc,
    });
    fake.addJob(lead(pb, 'Kept', album: 'Other').raw, state: 'done', result: {'copied': {'filepath': 'x.mp3'}});
    final c = make();
    await c.activate();
    final s = c.summary;
    expect([s.running, s.failed, s.shown], [2, 2, true], reason: 'a copy stopped because the peer went away counts as failed');
    expect([for (final j in c.copies) j.state], [JobState.running, JobState.queued, JobState.done, JobState.failed]);
  });
  test("only the phone's copies: another plug-in's jobs and the webapp's folder copies are neither counted, listed, marked, retried, polled for nor news", () async {
    final yt = fake.addJob(late.raw, state: 'failed')..['plugin'] = 'youtube';
    final ytLive = fake.addJob(corner.raw, state: 'running')..['plugin'] = 'youtube';
    final folder = fake.addJob(late.raw, scope: 'folder', state: 'failed');
    folder['params'] = {
      'scope': 'folder',
      'landing': {'vpath': 'music', 'path': 'mine'},
    };
    final c = make();
    await c.activate();
    await c.setRows(rows);
    expect(c.jobs, hasLength(3), reason: 'the list as the server sent it');
    expect([c.summary.running, c.summary.failed, c.summary.shown], [0, 0, false],
        reason: 'no "Copying 1 · 2 failed" for jobs that are not Keep a copy');
    expect(c.copies, isEmpty);
    expect(c.markerFor(late), isNull, reason: "a YouTube job on the row is not Keep a copy's");
    expect(c.markerFor(corner), isNull);
    expect(c.sheetJob(corner, 'song'), isNull);
    expect(c.anyLive, isFalse);
    expect(timers.active, isNull, reason: "nothing of the phone's is live: no poll");

    // Retry would POST them to federation-copy without their plug-in or
    // landing: nothing is sent.
    for (final id in [yt['id'], folder['id']]) {
      final r = await c.retry(c.jobs.firstWhere((j) => j.id == id));
      expect(r.ignored, isTrue);
    }
    expect(fake.count('POST', '/jobs'), 0);

    // A copy beside them counts, and keeps the poll going.
    final copy = fake.addJob(glass.raw, state: 'running');
    await c.refreshJobs();
    expect([c.summary.running, c.summary.failed], [1, 0]);
    expect([for (final j in c.copies) j.id], [copy['id']]);
    expect(timers.active?.delay, DiscoveryJobsController.kDiscoverBeat);

    // The YouTube download ending is no news.
    ytLive['state'] = 'done';
    await c.refreshJobs();
    expect(c.justFinished, isEmpty);
  });

  group('what the review asked for', () {
    test('a job seen live only through a lookup is news when the list shows it ended', () async {
      final c = make();
      await c.activate(); // the list is empty
      final j = fake.addJob(late.raw, state: 'running');
      await c.setRows(rows); // the lookup sees it running
      final news = <DiscoveryJob>[];
      c.finished.listen(news.add);
      j['state'] = 'done';
      j['result'] = {'copied': {'filepath': 'copies/x.mp3'}};
      timers.active!.fire();
      await settle();
      expect([for (final n in news) n.id], [j['id']]);
      expect(c.justFinished.single.id, j['id']);
    });

    test("a live row job the list does not carry is followed by lookups until it ends", () async {
      final j = fake.addJob(late.raw, state: 'running');
      final c = make();
      await c.activate();
      await c.setRows(rows);
      fake.unlisted.add(j['id'] as int);
      final lookups = fake.count('POST', '/lookup/batch');
      timers.active!.fire();
      await settle();
      expect(fake.count('POST', '/lookup/batch'), lookups + 1, reason: 'only a lookup can say how it goes');
      expect(timers.active, isNotNull, reason: 'still live on its row: still polling');
      j['state'] = 'done';
      j['result'] = {'copied': {'filepath': 'copies/x.mp3'}};
      timers.active!.fire();
      await settle();
      expect(c.markerFor(late)!.kind, CopyMarkerKind.inCollection);
      expect(timers.active, isNull, reason: 'nothing live any more: stopped');
      expect([for (final n in c.justFinished) n.id], [j['id']], reason: 'its end is news too, once');
    });

    test('"Just finished" holds the settled ones; a failed or stopped one is in the Copies list', () async {
      final ok = fake.addJob(late.raw, state: 'running');
      final bad = fake.addJob(corner.raw, scope: 'album', state: 'running');
      final c = make();
      await c.activate();
      ok['state'] = 'done';
      ok['result'] = {'copied': {'filepath': 'copies/x.mp3'}};
      bad['state'] = 'done';
      bad['result'] = {
        'scope': 'album', 'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': [{}, {}, {}]},
        'counts': {'total': 3, 'copied': 0, 'skipped': 0, 'failed': 3}, 'stopped': null, 'peer': pb,
      };
      await c.refreshJobs();
      expect([for (final j in c.justFinished) j.id], [ok['id']]);
      expect([for (final j in c.copies) j.id], [bad['id']]);
      expect([c.summary.running, c.summary.failed], [0, 1]);
    });

    test('a second tap while a start is out sends nothing', () async {
      final c = make();
      await c.activate();
      final first = c.start(late.raw, scope: 'album');
      final second = await c.start(late.raw, scope: 'album');
      expect([second.ignored, second.ok, second.error], [true, false, null]);
      expect((await first).ok, isTrue);
      expect(fake.count('POST', '/plugins/federation-copy/jobs'), 1);
    });

    test('a cancel that lost the race reads the list afresh even with a read already out', () async {
      final j = fake.addJob(late.raw, state: 'done', result: {'copied': {'filepath': 'copies/x.mp3'}});
      final c = make();
      await c.activate();
      final reads = fake.count('GET', '/plugin-jobs');
      final out = c.refreshJobs();
      final r = await c.cancel(DiscoveryJob.fromServerMap({...j, 'state': 'running'})!);
      await out;
      expect(r.outcome, CancelOutcome.alreadyFinished);
      expect(fake.count('GET', '/plugin-jobs'), reads + 2, reason: 'the one out, then a fresh one');
    });

    test("a result's counts: counts first, the lists for an older server", () {
      JobResultView v(Map<String, dynamic> r) => JobResultView(r);
      final c = v({'songs': {'total': 1200, 'copied': List.filled(500, {}), 'skipped': [], 'failed': []}, 'counts': {'total': 1200, 'copied': 700, 'skipped': 0, 'failed': 500}}).counts;
      expect([c.total, c.copied, c.skipped, c.failed, c.done], [1200, 700, 0, 500, 1200]);
      final old = v({'songs': {'total': 3, 'copied': [{}], 'skipped': [{}], 'failed': []}}).counts;
      expect([old.total, old.copied, old.skipped, old.failed], [3, 1, 1, 0]);
      expect(const JobResultView(null).counts.total, 0);
    });
  });

  group("the Keep card's choices (choiceJob)", () {
    Map<String, dynamic> walked(String album, List<String> files) => {
          'scope': 'artist-missing',
          'albums': [
            {
              'name': album,
              'songs': {
                'total': files.length,
                'copied': [for (final f in files) {'from': f, 'vpath': 'copies', 'filepath': 'copies/$album/${f.split('/').last}'}],
                'skipped': [],
                'failed': [],
              },
              'stopped': null,
            },
          ],
          'skippedAlbums': [],
          'songs': {'total': files.length, 'copied': [], 'skipped': [], 'failed': []},
          'counts': {'total': files.length, 'copied': files.length, 'skipped': 0, 'failed': 0},
          'stopped': null,
          'peer': pb,
        };

    test("Album and This song borrow a finished artist copy's account; Artist keeps its own", () async {
      fake.addJob(late.raw, scope: 'artist-missing', state: 'done', result: walked('Borrowed Tapes', [late.filepath!]));
      final c = make();
      await c.activate();
      await c.setRows(rows);
      expect(c.sheetJob(late, 'album'), isNull, reason: 'no album job of its own');
      final album = c.choiceJob(late, 'album')!;
      expect([album.wider, album.fromOtherPeer, album.job.scope], [true, false, 'artist-missing']);
      final song = c.choiceJob(late, 'song')!;
      expect([song.wider, song.job.view.copiedFilepath], [true, 'copies/Borrowed Tapes/Late Train Verse.mp3']);
      expect(c.choiceJob(corner, 'song'), isNull, reason: "its file is not in the walk's lists");
      expect(c.choiceJob(corner, 'album')!.wider, isTrue, reason: 'the same album');
      expect(c.choiceJob(roof, 'album'), isNull, reason: "Stage Peer C's row: B's copy is not C's");
      expect(c.choiceJob(glass, 'album'), isNull);
      // Artist: the job itself, its whole walk
      final own = c.sheetJob(late, 'artist-missing')!;
      expect([own.wider, (own.job.result!['albums'] as List).length], [false, 1]);
    });

    test("an album card's rows lend their jobs: an artist copy on another row of the card speaks for the card", () async {
      // The card's best row names a featured artist: its artist key is not the copy's.
      final feat = lead(pb, 'Late Train Verse', artist: 'Boukmanflow feat. Ola', albumArtist: 'Boukmanflow', similarity: 0.95);
      final plain = lead(pb, 'Corner Store Loop', albumArtist: 'Boukmanflow', similarity: 0.7);
      fake.addJob(plain.raw, scope: 'artist-missing', state: 'done', result: walked('Borrowed Tapes', [plain.filepath!]));
      final c = make();
      await c.activate();
      await c.setRows([feat, plain]);
      expect(c.choiceJob(feat, 'album'), isNull, reason: 'the best row alone holds no such copy');
      final card = c.choiceJob(feat, 'album', cardLeads: [feat, plain])!;
      expect([card.wider, card.job.scope], [true, 'artist-missing']);
    });
  });
}
