import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/singletons/play_history.dart';
import 'package:mstream_music/singletons/play_sync.dart';

PlayEvent ev(String id, {String server = 'home', String path = '/a.mp3', int? peerId, DateTime? at}) {
  final t = (at ?? DateTime(2026, 9, 10, 20)).toUtc();
  return PlayEvent(
    id: id,
    startedAt: t,
    endedAt: t.add(const Duration(minutes: 3)),
    track: TrackFacts(server: server, peerId: peerId, path: path, title: 'T', hash: 'h'),
    playedMs: 180000,
    outcome: PlayOutcome.completed,
    source: PlaySource.manual,
    counted: true,
  );
}

void main() {
  late Directory dir;
  final sync = PlaySync();
  final history = PlayHistory();
  var clock = DateTime.utc(2026, 9, 10, 20);
  final calls = <(String, List<String>)>[];
  final targets = <String, SyncTarget>{
    'home': const SyncTarget(localname: 'home', statsCapable: true),
    'old': const SyncTarget(localname: 'old', statsCapable: false),
    'tunnel': const SyncTarget(localname: 'tunnel', statsCapable: true, reachable: false),
  };
  Future<PostPlaysResult> Function(String, List<PlayEvent>) answer = (t, b) async => PostPlaysResult(accepted: b.map((e) => e.id).toList());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('play-sync-');
    PlayHistory.storageDirectory = () async => dir;
    history.resetForTest();
    sync.resetForTest();
    calls.clear();
    clock = DateTime.utc(2026, 9, 10, 20);
    sync.now = () => clock;
    sync.resolveTarget = (n) => targets[n];
    sync.targetFor = (n) => n == 'bobs' ? 'home' : n;
    sync.post = (t, b) {
      calls.add((t, b.map((e) => e.id).toList()));
      return answer(t, b);
    };
    answer = (t, b) async => PostPlaysResult(accepted: b.map((e) => e.id).toList());
  });
  tearDown(() async {
    sync.resetForTest();
    history.resetForTest();
    await dir.delete(recursive: true);
  });

  test('routing: a server track to its server, a peer track to the parent, a local file nowhere', () async {
    await sync.onEvent(ev('s1'));
    await sync.onEvent(ev('p1', server: 'bobs', peerId: 3));
    await sync.onEvent(ev('l1', server: '', path: '/sdcard/x.mp3'));
    await sync.drain();
    expect(calls.map((c) => c.$1).toSet(), {'home'});
    expect(calls.expand((c) => c.$2).toSet(), {'s1', 'p1'});
    expect(history.outboxCount, 0);
    expect(sync.posted, 2);
  });

  test('no capability or no route: the events wait in the outbox, nothing is probed', () async {
    await history.enqueue('old', ev('o1', server: 'old'));
    await history.enqueue('tunnel', ev('t1', server: 'tunnel'));
    await sync.drain();
    expect(calls, isEmpty);
    expect(history.pending('old').length, 1);
    expect(history.pending('tunnel').length, 1);
    targets['tunnel'] = const SyncTarget(localname: 'tunnel', statsCapable: true, reachable: true);
    await sync.drain(reason: 'tunnel up');
    expect(calls.single.$1, 'tunnel');
    expect(history.pending('tunnel'), isEmpty);
    targets['tunnel'] = const SyncTarget(localname: 'tunnel', statsCapable: true, reachable: false);
  });

  test('accepted, duplicates and rejected all settle; rejections are counted', () async {
    for (final id in ['a', 'b', 'c']) {
      await history.enqueue('home', ev(id));
    }
    answer = (t, b) async => const PostPlaysResult(accepted: ['a'], duplicates: ['b'], rejected: {'c': 'unknown-track'});
    await sync.drain();
    expect(history.pending('home'), isEmpty);
    expect([sync.posted, sync.rejected], [1, 1]);
    expect(sync.lastError, null);
    expect(sync.lastPostAt, clock);
  });

  test('a network failure backs the target off: 1, 2, 4 minutes, and a success resets it', () async {
    await history.enqueue('home', ev('a'));
    answer = (t, b) async => throw const PostPlaysException(PostFailure.network, 'timeout');
    await sync.drain();
    expect(calls.length, 1);
    expect(history.pending('home').length, 1);
    expect(sync.backoff.blocked('home', clock), true);
    expect(sync.backoff.remaining('home', clock), const Duration(minutes: 1));
    await sync.drain();
    expect(calls.length, 1, reason: 'blocked: no second call');
    clock = clock.add(const Duration(minutes: 1, seconds: 1));
    await sync.drain();
    expect(calls.length, 2);
    expect(sync.backoff.remaining('home', clock), const Duration(minutes: 2));
    clock = clock.add(const Duration(minutes: 2, seconds: 1));
    await sync.drain();
    expect(sync.backoff.remaining('home', clock), const Duration(minutes: 4));
    answer = (t, b) async => PostPlaysResult(accepted: b.map((e) => e.id).toList());
    clock = clock.add(const Duration(minutes: 4, seconds: 1));
    await sync.drain();
    expect(history.pending('home'), isEmpty);
    expect(sync.backoff.blocked('home', clock), false);
    expect(sync.lastError, null);
  });

  test('news about the network bypasses the backoff', () async {
    await history.enqueue('home', ev('a'));
    answer = (t, b) async => throw const PostPlaysException(PostFailure.network, 'timeout');
    await sync.drain();
    expect(sync.backoff.blocked('home', clock), true);
    answer = (t, b) async => PostPlaysResult(accepted: b.map((e) => e.id).toList());
    await sync.drain(reason: 'connectivity', bypassBackoff: true);
    expect(history.pending('home'), isEmpty);
    expect(sync.backoff.blocked('home', clock), false);
  });

  test('backoff caps at 30 minutes', () {
    final b = Backoff();
    final t = DateTime.utc(2026);
    for (var i = 0; i < 12; i++) {
      b.failed('x', t);
    }
    expect(b.remaining('x', t), const Duration(minutes: 30));
  });

  test('401/403 parks the target until its credentials change', () async {
    await history.enqueue('home', ev('a'));
    answer = (t, b) async => throw const PostPlaysException(PostFailure.unauthorized, 'http 401');
    await sync.drain();
    expect(sync.isParked('home'), true);
    clock = clock.add(const Duration(hours: 5));
    await sync.drain();
    expect(calls.length, 1, reason: 'parked: time alone does not retry');
    answer = (t, b) async => PostPlaysResult(accepted: b.map((e) => e.id).toList());
    sync.unpark('home');
    await sync.drain();
    expect(calls.length, 2);
    expect(history.pending('home'), isEmpty);
  });

  test('another failure waits for the next trigger without backoff', () async {
    await history.enqueue('home', ev('a'));
    answer = (t, b) async => throw const PostPlaysException(PostFailure.server, 'http 500');
    await sync.drain();
    expect(history.pending('home').length, 1);
    expect(sync.backoff.blocked('home', clock), false);
    answer = (t, b) async => PostPlaysResult(accepted: b.map((e) => e.id).toList());
    await sync.drain();
    expect(history.pending('home'), isEmpty);
  });

  test('batches of 200, oldest first, until the target is empty', () async {
    for (var i = 0; i < 450; i++) {
      await history.enqueue('home', ev('e$i', at: DateTime(2026, 9, 1).add(Duration(minutes: i))));
    }
    await sync.drain();
    expect(calls.map((c) => c.$2.length).toList(), [200, 200, 50]);
    expect(calls.first.$2.first, 'e0');
    expect(history.outboxCount, 0);
  });

  test('a target that no longer exists is purged; an empty answer stops the drain', () async {
    await history.enqueue('gone', ev('g', server: 'gone'));
    await history.enqueue('home', ev('h'));
    answer = (t, b) async => const PostPlaysResult();
    await sync.drain();
    expect(history.pending('gone'), isEmpty);
    expect(history.pending('home').length, 1, reason: 'nothing settled, nothing dropped');
    expect(calls.length, 1);
  });

  test('turning sync off empties the outbox; on drains it', () async {
    await history.enqueue('home', ev('a'));
    sync.setEnabled(false);
    await Future<void>.delayed(Duration.zero);
    expect(history.outboxCount, 0);
    await sync.onEvent(ev('b'));
    expect(history.outboxCount, 0, reason: 'off: nothing queued');
    sync.setEnabled(true);
    await sync.onEvent(ev('c'));
    await sync.drain();
    expect(calls.expand((c) => c.$2).toList(), ['c']);
  });

  test('PostPlaysResult parses the server answer', () {
    final r = PostPlaysResult.fromJson({'accepted': ['a'], 'duplicates': ['b', 3], 'rejected': [{'id': 'c', 'reason': 'bad-time'}, {'nope': 1}]});
    expect(r.accepted, ['a']);
    expect(r.duplicates, ['b']);
    expect(r.rejected, {'c': 'bad-time'});
    expect(r.settled.toSet(), {'a', 'b', 'c'});
  });
}
