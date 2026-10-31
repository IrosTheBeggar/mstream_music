import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/library_index.dart';
import 'package:mstream_music/singletons/outbox.dart';

void main() {
  late Directory tmp;
  final server = Server('http://h', null, null, null, 'home');
  final ob = OutboxManager();

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('outbox_');
    LibraryIndexManager().close();
    await LibraryIndexManager().open(path: p.join(tmp.path, 'index.db'));
    LibraryIndexManager().index!.upsertTracks('home', const [
      RemoteTrack(id: 1, path: '/music/a.mp3', title: 'A', artist: 'Ann'),
      RemoteTrack(id: 2, path: '/music/b.mp3', title: 'B', artist: 'Bob'),
    ], 'r1');
    ob.now = () => DateTime.fromMillisecondsSinceEpoch(1000);
  });
  tearDown(() {
    LibraryIndexManager().close();
    ob.sender = OutboxManager.post;
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('enqueue mirrors the write into the index and counts as pending', () {
    expect(ob.enqueue(server, OutboxOp.rate, {'filepath': 'music/a.mp3', 'rating': 8}),
        isTrue);
    expect(ob.enqueue(server, OutboxOp.playlistAdd, {'playlist': 'Mix', 'song': 'music/b.mp3'}),
        isTrue);
    final ix = LibraryIndexManager().index!;
    expect(ix.rated('home').single.path, '/music/a.mp3');
    expect(ix.rated('home').single.rating, 8);
    expect(ix.playlistItems('home', 'Mix').single.path, '/music/b.mp3');
    expect(ob.pending(server), 2);
    expect(ix.outbox('home').first.created, 1000);
    expect(ix.outbox('home').first.payload, {'filepath': 'music/a.mp3', 'rating': 8});
  });

  test('replay: in order, a rejected write is dropped, a network failure stops it',
      () async {
    ob.enqueue(server, OutboxOp.rate, {'filepath': 'music/a.mp3', 'rating': 8});
    ob.enqueue(server, OutboxOp.playlistNew, {'title': 'Bad'});
    ob.enqueue(server, OutboxOp.playlistRename, {'oldName': 'Bad', 'newName': 'Good'});
    ob.enqueue(server, OutboxOp.playlistDelete, {'playlistname': 'Good'});
    final sent = <String>[];
    ob.sender = (s, e) async {
      sent.add(e.op);
      if (e.op == OutboxOp.playlistNew) throw const OutboxRejected(400);
      if (e.op == OutboxOp.playlistRename) throw const SocketException('down');
    };
    await ob.replay(server);
    expect(sent, [OutboxOp.rate, OutboxOp.playlistNew, OutboxOp.playlistRename]);
    final left = LibraryIndexManager().index!.outbox('home');
    expect(left.map((e) => e.op), [OutboxOp.playlistRename, OutboxOp.playlistDelete]);
    expect(left.first.attempts, 1);
    expect(left.first.lastError, contains('down'));

    // The next ping resumes from the failed one.
    sent.clear();
    ob.sender = (s, e) async => sent.add(e.op);
    await ob.replay(server);
    expect(sent, [OutboxOp.playlistRename, OutboxOp.playlistDelete]);
    expect(ob.pending(server), 0);
  });

  test('applyLocally mirrors an online write without queueing it', () {
    ob.applyLocally(server, OutboxOp.playlistSave, {'title': 'S', 'songs': ['music/a.mp3', 'music/b.mp3']});
    final ix = LibraryIndexManager().index!;
    expect(ix.playlistItems('home', 'S').map((i) => i.path), ['/music/a.mp3', '/music/b.mp3']);
    expect(ob.pending(server), 0);
  });

  test('no index: nothing is queued and the caller hears about it', () {
    LibraryIndexManager().close();
    expect(ob.enqueue(server, OutboxOp.rate, {'filepath': 'x', 'rating': 1}), isFalse);
    expect(ob.pending(server), 0);
  });
}
