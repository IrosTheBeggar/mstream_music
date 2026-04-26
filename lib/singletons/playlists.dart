// Local playlist manager.
//
// Persists user-created playlists to playlists.json next to the other
// app state files. Playlists are MediaItem-derived, so playback rebuilds
// queue items from PlaylistEntry without re-hitting the server.
//
// Singleton with a stream so the playlist screen reflects edits live.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../objects/playlist.dart';
import '../singletons/media.dart';

class PlaylistManager {
  PlaylistManager._privateConstructor();
  static final PlaylistManager _instance = PlaylistManager._privateConstructor();
  factory PlaylistManager() => _instance;

  static const _filename = 'playlists.json';

  final List<Playlist> playlists = [];

  late final BehaviorSubject<List<Playlist>> _stream =
      BehaviorSubject<List<Playlist>>.seeded(playlists);

  Stream<List<Playlist>> get stream => _stream.stream;

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<void> load() async {
    try {
      final f = await _file;
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final list = (jsonDecode(raw) as List)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
      playlists.clear();
      playlists.addAll(list);
      _stream.add(playlists);
    } catch (_) {
      // Bad/missing file: fall back to empty.
    }
  }

  Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(jsonEncode(playlists.map((p) => p.toJson()).toList()));
  }

  Future<Playlist> create(String name) async {
    final p = Playlist(name: name, entries: []);
    playlists.add(p);
    _stream.add(playlists);
    await _save();
    return p;
  }

  Future<void> rename(int index, String newName) async {
    if (index < 0 || index >= playlists.length) return;
    playlists[index].name = newName;
    _stream.add(playlists);
    await _save();
  }

  Future<void> remove(int index) async {
    if (index < 0 || index >= playlists.length) return;
    playlists.removeAt(index);
    _stream.add(playlists);
    await _save();
  }

  Future<void> addEntry(int index, MediaItem item) async {
    if (index < 0 || index >= playlists.length) return;
    playlists[index].entries.add(PlaylistEntry.fromMediaItem(item));
    _stream.add(playlists);
    await _save();
  }

  Future<void> removeEntry(int playlistIndex, int entryIndex) async {
    if (playlistIndex < 0 || playlistIndex >= playlists.length) return;
    final p = playlists[playlistIndex];
    if (entryIndex < 0 || entryIndex >= p.entries.length) return;
    p.entries.removeAt(entryIndex);
    _stream.add(playlists);
    await _save();
  }

  /// Replaces the queue with the playlist's entries and starts playback.
  Future<void> playPlaylist(int index) async {
    if (index < 0 || index >= playlists.length) return;
    final handler = MediaManager().audioHandler;
    await handler.customAction('clearPlaylist');
    for (final entry in playlists[index].entries) {
      await handler.addQueueItem(entry.toMediaItem());
    }
    if (playlists[index].entries.isNotEmpty) {
      await handler.skipToQueueItem(0);
      await handler.play();
    }
  }

  void dispose() => _stream.close();
}
