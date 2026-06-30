import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'server_release.dart';

/// Lifecycle phase of the managed server binary.
enum ServerPhase {
  idle,
  checking, // querying GitHub for the latest version
  downloading, // [ServerStatus.progress] is meaningful (0..1)
  verifying, // SHA-256
  extracting,
  ready, // [ServerStatus.executablePath] is set
  error,
  unsupported, // no mStream release for this platform
}

@immutable
class ServerStatus {
  const ServerStatus(
    this.phase, {
    this.progress = 0,
    this.version,
    this.executablePath,
    this.error,
  });

  final ServerPhase phase;
  final double progress;
  final String? version;
  final String? executablePath;
  final String? error;
}

/// Result of an update check.
@immutable
class UpdateInfo {
  const UpdateInfo({required this.installedVersion, required this.latestVersion});
  final String? installedVersion; // null if nothing installed yet
  final String latestVersion;
  bool get hasUpdate => installedVersion != latestVersion;
}

/// Downloads, verifies, extracts, and updates the bundled mStream server
/// binary. Owns only acquisition + on-disk lifecycle — spawning the server is a
/// separate concern (a later piece). The binaries live in a per-version folder
/// under the app-support dir so an update never clobbers a working install and a
/// previous version stays around for rollback.
///
/// Decoupling: the app pins a [target] version; mStream releases on its own
/// cadence and the manager fetches the matching asset by deterministic URL. The
/// only coupling between the two projects is this version string plus the iroh
/// tunnel's ALPN contract.
class ServerBinaryManager {
  ServerBinaryManager._();
  static final ServerBinaryManager instance = ServerBinaryManager._();

  /// The version the app targets. Bump it (in an app release) to adopt a new
  /// server: the manager downloads it on next [ensureReady], activates it, and
  /// prunes older versions (keeping one for rollback).
  ServerRelease target = const ServerRelease(
    repo: 'IrosTheBeggar/mStream',
    version: '6.15.1',
    // Pinned per-platform SHA-256 of the release zip (compute via
    // tool/server_binary_probe.dart). A pinned hash is enforced; an unpinned
    // platform is accepted on HTTPS trust + a warning. win-x64 verified against
    // the real v6.15.1 release; fill the others when those builds are targeted.
    sha256ByPlatform: <String, String>{
      'win-x64':
          '95180bc852d76f910eaf71b3c530077c1fda80da43bbc5517254182b35c5e5dd',
    },
  );

  final ValueNotifier<ServerStatus> status =
      ValueNotifier<ServerStatus>(const ServerStatus(ServerPhase.idle));

  bool get isSupported => ServerRelease.isPlatformSupported;

  Directory? _rootCache;

  void _log(String m) => debugPrint('[server-bin] $m');

  void _set(ServerStatus s) => status.value = s;

  Future<Directory> _root() async {
    if (_rootCache != null) return _rootCache!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'mstream-server'));
    await dir.create(recursive: true);
    return _rootCache = dir;
  }

  Directory _versionDir(Directory root, String version) =>
      Directory(p.join(root.path, version));

  File _verifiedMarker(Directory versionDir) =>
      File(p.join(versionDir.path, '.verified'));

  // <versionDir>/mStream-<version>-<key>/mStream(.exe)
  String _exePath(Directory versionDir, String version) => p.join(
        versionDir.path,
        'mStream-$version-${ServerRelease.platformKey()}',
        ServerRelease.executableName,
      );

  /// Path to the executable for [version] (default: the target) if it's
  /// installed AND verified, else null.
  Future<String?> installedExecutable([String? version]) async {
    if (!isSupported) return null;
    final v = version ?? target.version;
    final vd = _versionDir(await _root(), v);
    if (!await _verifiedMarker(vd).exists()) return null;
    final exe = _exePath(vd, v);
    return await File(exe).exists() ? exe : null;
  }

  /// Ensure the [target] version is downloaded, verified, and extracted.
  /// Returns the executable path, or null on an unsupported platform / failure
  /// (inspect [status] for the reason). Idempotent: a present+verified install
  /// short-circuits.
  Future<String?> ensureReady() async {
    if (!isSupported) {
      _set(const ServerStatus(ServerPhase.unsupported));
      return null;
    }
    final existing = await installedExecutable();
    if (existing != null) {
      _set(ServerStatus(ServerPhase.ready,
          version: target.version, executablePath: existing));
      return existing;
    }
    return _install(target);
  }

  /// Query GitHub for the latest release and compare to what's installed.
  /// Does not download — call [applyUpdate] to act on it.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!isSupported) return null;
    final prev = status.value;
    _set(const ServerStatus(ServerPhase.checking));
    try {
      final latest = await _latestVersion(target.repo);
      final installed = await installedExecutable() != null ? target.version : null;
      _set(prev); // restore the prior phase; the check itself isn't a state
      return UpdateInfo(installedVersion: installed, latestVersion: latest);
    } catch (e) {
      _log('update check failed: $e');
      _set(prev);
      return null;
    }
  }

  /// Download + verify + activate [version], adopt it as the new [target], and
  /// prune older versions. Use after [checkForUpdate] reports an update (note:
  /// a dynamically-chosen version has no pinned hash unless the app ships one,
  /// so it's accepted on HTTPS trust — see [_verify]).
  Future<String?> applyUpdate(String version) async {
    final release = ServerRelease(
      repo: target.repo,
      version: version,
      sha256ByPlatform: target.sha256ByPlatform,
    );
    final exe = await _install(release);
    if (exe != null) target = release;
    return exe;
  }

  // ── install pipeline ──
  Future<String?> _install(ServerRelease release) async {
    final url = release.downloadUrl;
    if (url == null) {
      _set(const ServerStatus(ServerPhase.unsupported));
      return null;
    }
    final root = await _root();
    final tmpZip = File(p.join(root.path, '${release.version}.download'));
    final tmpDir = Directory(p.join(root.path, '${release.version}.extracting'));
    final finalDir = _versionDir(root, release.version);
    try {
      await _download(url, tmpZip, release.version);

      _set(ServerStatus(ServerPhase.verifying, version: release.version));
      await _verify(tmpZip, release.expectedSha256, release);

      _set(ServerStatus(ServerPhase.extracting, version: release.version));
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      await tmpDir.create(recursive: true);
      await extractFileToDisk(tmpZip.path, tmpDir.path);

      // Atomic activate: swap the fully-extracted temp dir into place only after
      // verify+extract succeed, so a crash mid-update never leaves a half-install.
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
      await tmpDir.rename(finalDir.path);

      final exe = _exePath(finalDir, release.version);
      if (!await File(exe).exists()) {
        throw StateError('executable missing after extract: $exe');
      }
      await _makeExecutable(exe);
      await _verifiedMarker(finalDir)
          .writeAsString('${release.version}\n${DateTime.now().toUtc().toIso8601String()}\n');

      await _safeDelete(tmpZip);
      await _prune(root, keep: release.version);

      _set(ServerStatus(ServerPhase.ready,
          version: release.version, executablePath: exe));
      _log('ready: $exe');
      return exe;
    } catch (e) {
      _log('install failed: $e');
      await _safeDelete(tmpZip);
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true).catchError((_) => tmpDir);
      }
      _set(ServerStatus(ServerPhase.error,
          version: release.version, error: '$e'));
      return null;
    }
  }

  Future<void> _download(String url, File dest, String version) async {
    final client = http.Client();
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode != 200) {
        throw HttpException('download failed: HTTP ${resp.statusCode} for $url');
      }
      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = dest.openWrite();
      _set(ServerStatus(ServerPhase.downloading, version: version));
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            _set(ServerStatus(ServerPhase.downloading,
                progress: received / total, version: version));
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<void> _verify(File zip, String? expected, ServerRelease release) async {
    if (expected == null || expected.isEmpty) {
      _log('WARNING: no pinned SHA-256 for ${release.version}/'
          '${ServerRelease.platformKey()} — accepting on HTTPS trust only. '
          'Pin a hash for production.');
      return;
    }
    final actual = await _sha256OfFile(zip);
    if (actual.toLowerCase() != expected.toLowerCase()) {
      throw StateError(
          'checksum mismatch for ${release.assetName}: expected $expected, got $actual');
    }
    _log('checksum verified: $actual');
  }

  Future<String> _sha256OfFile(File f) async {
    final digest = await sha256.bind(f.openRead()).single;
    return digest.toString();
  }

  Future<void> _makeExecutable(String path) async {
    if (Platform.isWindows) return;
    // The extracted Bun binary + its sidecars need the executable bit on
    // macOS/Linux. (macOS additionally needs the binary signed/notarized or the
    // quarantine xattr stripped — handled elsewhere.)
    try {
      await Process.run('chmod', ['+x', path]);
    } catch (e) {
      _log('chmod failed (non-fatal): $e');
    }
  }

  /// Keep [keep] and the single next-newest version; delete the rest.
  Future<void> _prune(Directory root, {required String keep}) async {
    final dirs = <Directory>[];
    await for (final e in root.list(followLinks: false)) {
      if (e is Directory && _looksLikeVersion(p.basename(e.path))) {
        dirs.add(e);
      }
    }
    dirs.sort((a, b) => _compareVersions(
        p.basename(b.path), p.basename(a.path))); // newest first
    final survivors = <String>{keep};
    for (final d in dirs) {
      if (survivors.length >= 2) break;
      survivors.add(p.basename(d.path));
    }
    for (final d in dirs) {
      if (!survivors.contains(p.basename(d.path))) {
        _log('pruning old version ${p.basename(d.path)}');
        await d.delete(recursive: true).catchError((_) => d);
      }
    }
  }

  Future<String> _latestVersion(String repo) async {
    final resp = await http.get(
      Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (resp.statusCode != 200) {
      throw HttpException('GitHub API HTTP ${resp.statusCode}');
    }
    final tag = (jsonDecode(resp.body) as Map<String, dynamic>)['tag_name'];
    if (tag is! String || tag.isEmpty) throw const FormatException('no tag_name');
    return tag.startsWith('v') ? tag.substring(1) : tag;
  }

  Future<void> _safeDelete(File f) async {
    if (await f.exists()) await f.delete().catchError((_) => f);
  }

  static final RegExp _semverish = RegExp(r'^\d+\.\d+\.\d+');
  static bool _looksLikeVersion(String s) => _semverish.hasMatch(s);

  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final pb = b.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final c = (pa.length > i ? pa[i] : 0).compareTo(pb.length > i ? pb[i] : 0);
      if (c != 0) return c;
    }
    return a.compareTo(b);
  }
}
