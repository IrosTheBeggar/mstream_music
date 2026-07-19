import 'dart:io' show Directory, File, Platform;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../singletons/log_manager.dart';

/// Base directory for the app's own data files (servers.json, queue.json, the
/// media/ download tree). Mobile keeps the app documents directory — it's
/// app-private there. Desktop uses Application Support: path_provider's
/// documents directory on macOS is the user's REAL ~/Documents, which is
/// TCC-gated — a denied permission silently failed every persist (stuck
/// "Connecting…" on add-server, queue restore failures) — and an app claiming
/// ~/Documents for internal files is wrong on any desktop OS.
Future<Directory> appDataDir() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return getApplicationSupportDirectory();
  }
  return getApplicationDocumentsDirectory();
}

/// One-time desktop migration of data that earlier builds wrote to the
/// documents directory: servers.json, queue.json, and media/ move into
/// Application Support. Same volume, so each move is an instant rename.
/// Any failure (typically macOS denying Documents access) is logged and
/// skipped — the app starts fresh in the new location, and a later launch
/// that CAN read the old files migrates whatever is still there.
Future<void> migrateLegacyDesktopData() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
  final Directory oldDir;
  final Directory newDir;
  try {
    oldDir = await getApplicationDocumentsDirectory();
    newDir = await getApplicationSupportDirectory();
  } catch (e) {
    appLog('[migrate] could not resolve data dirs: $e');
    return;
  }
  for (final name in ['servers.json', 'queue.json', 'media']) {
    try {
      final old = p.join(oldDir.path, name);
      final dest = p.join(newDir.path, name);
      final isDir = await Directory(old).exists();
      if (!isDir && !await File(old).exists()) continue;
      if (await File(dest).exists() || await Directory(dest).exists()) {
        continue; // already migrated (or fresh data exists) — leave both be
      }
      if (isDir) {
        await Directory(old).rename(dest);
      } else {
        await File(old).rename(dest);
      }
      appLog('[migrate] moved $name into app data dir');
    } catch (e) {
      appLog('[migrate] $name not migrated: $e');
    }
  }
}
