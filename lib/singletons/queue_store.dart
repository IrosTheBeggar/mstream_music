import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../objects/server.dart';
import '../util/stream_url.dart';
import 'media.dart';
import 'server_list.dart';
import 'log_manager.dart';
import 'settings.dart';

/// Persists the play queue + current track/position so they survive the app
/// being closed and reopened. Mirrors the servers.json approach: a single JSON
/// file (`queue.json`) in the app documents directory.
///
/// Server items are stored by their stable bits (server localname + path +
/// display metadata); the streaming URL is rebuilt on restore with the current
/// token/transcode setting — the per-build `app_uuid` and token baked into a
/// saved URL would otherwise go stale. Local files keep their `localPath`; the
/// playback backend re-checks existence at play time and streams as a fallback.
class QueueStore {
  QueueStore._();
  static final QueueStore _instance = QueueStore._();
  factory QueueStore() => _instance;

  // Bump if the on-disk shape changes incompatibly; an older file is then
  // ignored (not crashed on) at restore.
  static const int _schemaVersion = 1;
  // Coalesce bursts of change events (a "play from here" fires one queue edit
  // per track) into a single write.
  static const Duration _debounce = Duration(milliseconds: 800);
  // Position checkpoint cadence while playing — covers a hard kill that fires
  // no lifecycle callback (otherwise we'd lose position since the last edit).
  static const Duration _tick = Duration(seconds: 10);

  bool _restoring = false;
  bool _started = false;
  Timer? _debounceTimer;
  Timer? _ticker;
  final List<StreamSubscription> _subs = [];

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/queue.json');
  }

  /// Restore the saved queue (if any) into the audio handler, then start
  /// listening so the file stays current. Call ONCE at startup AFTER servers
  /// have loaded — server items are matched to a configured server by localname.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    _restoring = true;
    try {
      await _restore();
    } catch (e) {
      // A corrupt / incompatible file must never block startup.
      appLog('[queue] restore failed: $e');
    }
    _restoring = false;
    _attachListeners();
  }

  // Persist repeat as a tri-state name so a true single-track repeat-one loop
  // survives a restart; it used to be a bool (== all), which collapsed 'one' to
  // 'off'. Legacy snapshots stored a bool, so the reader still accepts true.
  static String _repeatName(AudioServiceRepeatMode m) =>
      m == AudioServiceRepeatMode.one
          ? 'one'
          : m == AudioServiceRepeatMode.none
              ? 'none'
              : 'all';

  static AudioServiceRepeatMode _repeatFromStored(dynamic v) => v == 'one'
      ? AudioServiceRepeatMode.one
      : (v == 'all' || v == true)
          ? AudioServiceRepeatMode.all
          : AudioServiceRepeatMode.none;

  /// Localname of the server the saved queue would resume on — its current-index
  /// item's `extras['server']` — or null when there's no resumable queue or that
  /// item is local. Lets startup bring that (iroh) server's tunnel up in the
  /// BACKGROUND before restoring, so the items rebuild against a live tunnel
  /// instead of a dead loopback port (the default stays the selected server).
  /// Cheap: reads + parses the file but builds no MediaItems.
  Future<String?> peekResumeServer() async {
    if (!SettingsManager().resumeQueue) return null;
    try {
      final file = await _file;
      if (!await file.exists()) return null;
      final dynamic raw = jsonDecode(await file.readAsString());
      if (raw is! Map || raw['version'] != _schemaVersion) return null;
      final dynamic items = raw['items'];
      if (items is! List || items.isEmpty) return null;
      int index = (raw['index'] is int) ? raw['index'] as int : 0;
      if (index < 0 || index >= items.length) index = 0;
      final entry = items[index];
      if (entry is! Map) return null;
      final extras = entry['extras'];
      return (extras is Map) ? extras['server'] as String? : null;
    } catch (_) {
      return null; // a corrupt/unreadable file must never block startup
    }
  }

  Future<void> _restore() async {
    if (!SettingsManager().resumeQueue) return; // feature disabled
    final file = await _file;
    if (!await file.exists()) return;

    final dynamic raw = jsonDecode(await file.readAsString());
    if (raw is! Map) return;
    if (raw['version'] != _schemaVersion) return;
    final dynamic rawItems = raw['items'];
    if (rawItems is! List) return;

    final items = <MediaItem>[];
    for (final entry in rawItems) {
      if (entry is! Map) continue;
      final m = itemFromJson(Map<String, dynamic>.from(entry));
      if (m != null) items.add(m); // null = its server is no longer configured
    }
    if (items.isEmpty) return;

    int index = (raw['index'] is int) ? raw['index'] as int : 0;
    if (index < 0 || index >= items.length) index = 0;
    final int positionMs = (raw['positionMs'] is int) ? raw['positionMs'] as int : 0;

    await MediaManager().audioHandler.restoreQueue(
          items,
          index,
          Duration(milliseconds: positionMs),
          shuffle: raw['shuffle'] == true,
          repeat: _repeatFromStored(raw['repeat']),
        );
  }

  void _attachListeners() {
    final handler = MediaManager().audioHandler;
    // Queue edits (add / remove / reorder / clear) and track changes.
    _subs.add(handler.queue.listen((_) => _schedule()));
    _subs.add(handler.mediaItem.listen((_) => _schedule()));
    // Periodic position checkpoint while actually playing.
    _ticker = Timer.periodic(_tick, (_) {
      if (handler.queue.value.isNotEmpty &&
          handler.playbackState.value.playing) {
        _schedule();
      }
    });
  }

  void _schedule() {
    if (_restoring) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, saveNow);
  }

  /// Cancel the checkpoint timer + change listeners. The singleton normally
  /// lives for the app's lifetime; this exists so the resources are releasable
  /// (and to keep the ticker reference meaningfully held).
  void dispose() {
    _debounceTimer?.cancel();
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  /// Write the current snapshot immediately (flush). Called on app pause/detach
  /// so a backgrounded-then-killed app keeps its place. Deletes the file when
  /// the queue is empty so a cleared queue doesn't resurrect on next launch.
  Future<void> saveNow() async {
    if (_restoring) return;
    _debounceTimer?.cancel();
    try {
      final file = await _file;
      if (!SettingsManager().resumeQueue) {
        // Feature disabled — drop any saved queue so it can't be restored.
        if (await file.exists()) await file.delete();
        return;
      }
      final handler = MediaManager().audioHandler;
      final queue = handler.queue.value;
      if (queue.isEmpty) {
        if (await file.exists()) await file.delete();
        return;
      }
      final state = handler.playbackState.value;
      final snapshot = <String, dynamic>{
        'version': _schemaVersion,
        'index': state.queueIndex ?? 0,
        'positionMs': handler.position.inMilliseconds,
        'shuffle': state.shuffleMode == AudioServiceShuffleMode.all,
        'repeat': _repeatName(state.repeatMode),
        'items': queue.map(itemToJson).toList(),
      };
      await file.writeAsString(jsonEncode(snapshot));
    } catch (e) {
      appLog('[queue] save failed: $e');
    }
  }

  // ── (de)serialization — pure & static so they're unit-testable ──

  /// Serialize a [MediaItem] to a JSON-safe map.
  static Map<String, dynamic> itemToJson(MediaItem m) => {
        'id': m.id,
        'title': m.title,
        'album': m.album,
        'artist': m.artist,
        'genre': m.genre,
        'durationMs': m.duration?.inMilliseconds,
        'extras': m.extras ?? const <String, dynamic>{},
      };

  /// Rebuild a [MediaItem] from its saved map. A server item (carries
  /// `extras['server']`) gets a freshly-built streaming URL via [resolveServer]
  /// — returns null if that server is no longer configured. A local item is
  /// rebuilt as-is (the backend resolves its localPath at play time).
  /// [resolveServer] defaults to a ServerManager lookup; injectable for tests.
  static MediaItem? itemFromJson(Map<String, dynamic> j,
      {Server? Function(String localname)? resolveServer}) {
    final extras = Map<String, dynamic>.from(j['extras'] ?? const {});
    final serverName = extras['server'] as String?;
    final Server? server =
        serverName != null ? (resolveServer ?? _defaultResolve)(serverName) : null;

    String id;
    if (serverName != null) {
      if (server == null) return null; // server removed since the queue was saved
      final path = extras['path'] as String?;
      if (path == null) return null;
      id = buildServerStreamUrl(server, path);
    } else {
      // Local file: id is unused for playback (localPath drives it), but keep a
      // stable value when present.
      id = (j['id'] as String?) ?? Uuid().v4();
    }

    // For an iroh server the persisted artUrl carries the PREVIOUS session's
    // ephemeral loopback port + token, so re-origin it against the current tunnel:
    // pull the album-art file + compress out of the stale URL and rebuild via
    // buildAlbumArtUrl (live effectiveBaseUrl/token). HTTP servers keep the URL.
    String? artUrl = extras['artUrl'] as String?;
    if (artUrl != null && server != null && server.isIroh) {
      final u = Uri.tryParse(artUrl);
      if (u != null &&
          u.pathSegments.length >= 2 &&
          u.pathSegments.first == 'album-art') {
        artUrl = buildAlbumArtUrl(server, u.pathSegments.sublist(1).join('/'),
            compress: u.queryParameters['compress'] ?? 's');
        extras['artUrl'] = artUrl; // keep extras consistent (player panel / Auto)
      }
    }

    return MediaItem(
      id: id,
      title: (j['title'] as String?) ??
          (extras['path'] as String?)?.split('/').last ??
          'Unknown',
      album: j['album'] as String?,
      artist: j['artist'] as String?,
      genre: j['genre'] as String?,
      // Restore artwork for the lock screen / Android Auto (re-originated above
      // for iroh; the persisted URL is kept as-is for HTTP servers).
      artUri: artUrl != null ? Uri.tryParse(artUrl) : null,
      duration:
          j['durationMs'] is int ? Duration(milliseconds: j['durationMs'] as int) : null,
      extras: extras,
    );
  }

  static Server? _defaultResolve(String localname) =>
      ServerManager().byLocalname(localname);
}
