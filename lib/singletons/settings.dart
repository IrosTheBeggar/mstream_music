import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'transcode.dart';

/// User-tweakable settings persisted to disk as a JSON blob next to
/// servers.json. Uses path_provider — same dependency the rest of the
/// app already pulls in — so no SharedPreferences plugin required.
class SettingsManager {
  SettingsManager._privateConstructor();
  static final SettingsManager _instance = SettingsManager._privateConstructor();
  factory SettingsManager() => _instance;

  static const _filename = 'settings.json';

  bool albumGrid = true;
  bool autoPlayOnTap = false;

  late final BehaviorSubject<bool> _albumGridStream =
      BehaviorSubject<bool>.seeded(albumGrid);

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  /// Loads from disk, applies values in-memory, and pushes to the
  /// related streams. Call once at app startup.
  Future<void> load() async {
    try {
      final f = await _file;
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      TranscodeManager().transcodeOn = m['transcode'] ?? false;
      albumGrid = m['albumGrid'] ?? true;
      autoPlayOnTap = m['autoPlayOnTap'] ?? false;
      _albumGridStream.add(albumGrid);
    } catch (_) {
      // Corrupt or missing file: fall back to defaults.
    }
  }

  Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(jsonEncode({
      'transcode': TranscodeManager().transcodeOn,
      'albumGrid': albumGrid,
      'autoPlayOnTap': autoPlayOnTap,
    }));
  }

  Future<void> setTranscode(bool v) async {
    TranscodeManager().transcodeOn = v;
    await _save();
  }

  Future<void> setAlbumGrid(bool v) async {
    albumGrid = v;
    _albumGridStream.add(v);
    await _save();
  }

  Future<void> setAutoPlayOnTap(bool v) async {
    autoPlayOnTap = v;
    await _save();
  }

  Future<void> resetAll() async {
    TranscodeManager().transcodeOn = false;
    albumGrid = true;
    autoPlayOnTap = false;
    _albumGridStream.add(albumGrid);
    await _save();
  }

  Stream<bool> get albumGridStream => _albumGridStream.stream;

  void dispose() {
    _albumGridStream.close();
  }
}
