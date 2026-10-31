import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:library_mirror/library_mirror.dart';

import '../objects/server.dart';
import 'library_index.dart';
import 'log_manager.dart';

/// The queued write kinds and the endpoint each replays to. A payload is
/// the request body exactly as the online call sends it.
abstract final class OutboxOp {
  static const String rate = 'rate';
  static const String playlistAdd = 'playlist-add';
  static const String playlistNew = 'playlist-new';
  static const String playlistSave = 'playlist-save';
  static const String playlistRename = 'playlist-rename';
  static const String playlistDelete = 'playlist-delete';

  static const Map<String, String> endpoints = {
    rate: '/api/v1/db/rate-song',
    playlistAdd: '/api/v1/playlist/add-song',
    playlistNew: '/api/v1/playlist/new',
    playlistSave: '/api/v1/playlist/save',
    playlistRename: '/api/v1/playlist/rename',
    playlistDelete: '/api/v1/playlist/delete',
  };
}

/// The server refused a queued write for good — a 4xx that is not an auth,
/// timeout or rate-limit hiccup — so retrying would fail the same way.
class OutboxRejected implements Exception {
  final int status;
  const OutboxRejected(this.status);
  @override
  String toString() => 'OutboxRejected($status)';
}

/// Writes made while a server is browsed offline (A5 of
/// BACKUP_SYNC_IMPLEMENTATION.md): a rating, a playlist edit. Each is
/// applied to the index at once, so the offline lists show it, and queued
/// with its request body; the queue replays in order after the next
/// successful ping. Last writer wins. A write the server rejects is logged
/// and dropped; a network failure stops the replay until the next ping.
class OutboxManager {
  OutboxManager._();
  static final OutboxManager _instance = OutboxManager._();
  factory OutboxManager() => _instance;

  /// Sends one queued entry — replaced in tests.
  Future<void> Function(Server server, OutboxEntry entry) sender = post;
  DateTime Function() now = DateTime.now;
  final Set<String> _replaying = {};

  LibraryIndex? get _ix => LibraryIndexManager().index;

  /// Writes waiting for [s].
  int pending(Server s) => _ix?.outboxCount(s.localname) ?? 0;

  /// Queues [op] for replay and mirrors it into the index. False when there
  /// is no index to hold it — the caller then reports the write as failed.
  bool enqueue(Server s, String op, Map<String, dynamic> payload) {
    final ix = _ix;
    if (ix == null) return false;
    ix.enqueue(s.localname, op, payload,
        created: now().millisecondsSinceEpoch);
    applyLocally(s, op, payload);
    appLog('[outbox] ${s.localname}: queued $op');
    return true;
  }

  /// Mirrors a write into the index — queued, or just made online — so the
  /// offline copy agrees with the server without waiting for a run.
  void applyLocally(Server s, String op, Map<String, dynamic> payload) {
    final ix = _ix;
    if (ix == null) return;
    final n = s.localname;
    try {
      switch (op) {
        case OutboxOp.rate:
          ix.setRating(n, _dataPath(payload['filepath']),
              (payload['rating'] as num?)?.toInt());
        case OutboxOp.playlistAdd:
          ix.addPlaylistItem(
              n, '${payload['playlist']}', _dataPath(payload['song']));
        case OutboxOp.playlistNew:
          ix.createPlaylist(n, '${payload['title']}');
        case OutboxOp.playlistSave:
          ix.savePlaylist(n, '${payload['title']}', [
            for (final f in (payload['songs'] as List? ?? const []))
              _dataPath(f)
          ]);
        case OutboxOp.playlistRename:
          ix.renamePlaylist(
              n, '${payload['oldName']}', '${payload['newName']}');
        case OutboxOp.playlistDelete:
          ix.deletePlaylist(n, '${payload['playlistname']}');
      }
    } catch (e) {
      appLog('[outbox] $n: could not mirror $op: $e');
    }
  }

  /// Sends what is queued for [s], oldest first. Stops at the first network
  /// failure (the next ping tries again); drops what the server rejects.
  Future<void> replay(Server s) async {
    final ix = _ix;
    final n = s.localname;
    if (ix == null || !_replaying.add(n)) return;
    try {
      final entries = ix.outbox(n);
      if (entries.isEmpty) return;
      var sent = 0, done = 0;
      for (final e in entries) {
        try {
          await sender(s, e);
          ix.outboxDone(e.id);
          sent++;
          done++;
        } on OutboxRejected catch (err) {
          appLog('[outbox] $n: ${e.op} rejected (HTTP ${err.status}) — dropped');
          ix.outboxDone(e.id);
          done++;
        } catch (err) {
          ix.outboxFailed(e.id, '$err');
          appLog('[outbox] $n: ${e.op} failed ($err); '
              '${entries.length - done} left for the next ping');
          break;
        }
      }
      if (sent > 0) appLog('[outbox] $n: replayed $sent change(s)');
    } finally {
      _replaying.remove(n);
    }
  }

  /// The default sender: the entry's endpoint with the server's token.
  static Future<void> post(Server s, OutboxEntry e) async {
    final location = OutboxOp.endpoints[e.op];
    if (location == null) throw const OutboxRejected(0);
    final res = await http
        .post(s.apiUri(location),
            body: jsonEncode(e.payload),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': s.authToken ?? '',
            })
        .timeout(const Duration(seconds: 15));
    final code = res.statusCode;
    if (code >= 200 && code < 300) return;
    if (code >= 400 && code < 500 && code != 401 && code != 408 && code != 429) {
      throw OutboxRejected(code);
    }
    throw HttpException('$location: HTTP $code');
  }

  /// The app's data path for a server filepath (leading slash).
  static String _dataPath(Object? fp) {
    final f = '$fp';
    return f.startsWith('/') ? f : '/$f';
  }
}
