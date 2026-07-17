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

  static const _repo = 'IrosTheBeggar/mStream';

  /// Pinned floor: the verified, offline fallback version. With
  /// [autoUpdateToLatest] on, the manager runs the latest GitHub release that is
  /// >= this floor when reachable, and falls back to the newest already-installed
  /// version (or the floor) when offline. Bump it when a newer version becomes
  /// the guaranteed-shipped baseline.
  String floorVersion = '6.15.1';

  /// On [ensureReady], resolve to the latest release (>= [floorVersion]) instead
  /// of pinning the floor — i.e. the app auto-updates to the newest server.
  bool autoUpdateToLatest = true;

  /// Per-version pinned SHA-256 of the release zip, keyed by version then
  /// platform ([ServerRelease.platformKey]). A pinned hash is enforced; a
  /// version/platform without one is accepted on HTTPS trust + a warning (so a
  /// brand-new release the app hasn't pinned yet still auto-updates). Compute
  /// hashes via tool/server_binary_probe.dart.
  static const Map<String, Map<String, String>> _knownHashes = {
    '6.15.1': {
      'win-x64':
          '95180bc852d76f910eaf71b3c530077c1fda80da43bbc5517254182b35c5e5dd',
    },
    '6.15.2': {
      'win-x64':
          'cce87f60a6a97206a22949ba753f81e799553fbb63ceed95c23f5191b6809c17',
    },
  };

  ServerRelease _releaseFor(String version) => ServerRelease(
        repo: _repo,
        version: version,
        sha256ByPlatform: _knownHashes[version] ?? const <String, String>{},
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

  /// Absolute root every managed server binary lives under (per-version
  /// subdirs). Lets the controller verify that a process holding our port is
  /// one of OUR binaries before adopting or reaping it — a user's separate
  /// mStream install must be neither.
  Future<String> installRootPath() async => (await _root()).path;

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
    final v = version ?? floorVersion;
    final vd = _versionDir(await _root(), v);
    if (!await _verifiedMarker(vd).exists()) return null;
    final exe = _exePath(vd, v);
    return await File(exe).exists() ? exe : null;
  }

  /// Ensure the resolved version (latest >= floor when auto-updating + online,
  /// else the floor / newest installed) is downloaded, verified, and extracted.
  /// Returns the executable path, or null on an unsupported platform / failure
  /// (inspect [status] for the reason). A present+verified install short-circuits.
  Future<String?> ensureReady() async {
    if (!isSupported) {
      _set(const ServerStatus(ServerPhase.unsupported));
      return null;
    }
    final version = await _resolveVersion();
    final existing = await installedExecutable(version);
    if (existing != null) {
      _set(ServerStatus(ServerPhase.ready,
          version: version, executablePath: existing));
      return existing;
    }
    return _install(_releaseFor(version));
  }

  /// The version to run: the latest GitHub release >= [floorVersion] when
  /// [autoUpdateToLatest] and reachable; otherwise the newest already-installed
  /// version, or the floor.
  Future<String> _resolveVersion() async {
    if (autoUpdateToLatest) {
      final latest = await _tryLatestVersion();
      if (latest != null && _compareVersions(latest, floorVersion) >= 0) {
        _log('auto-update: latest release $latest (floor $floorVersion)');
        return latest;
      }
    }
    final installed = await _newestInstalled();
    return installed ?? floorVersion;
  }

  Future<String?> _tryLatestVersion() async {
    try {
      return await _latestVersion(_repo);
    } catch (e) {
      _log('latest-version check failed (offline?): $e');
      return null;
    }
  }

  /// Newest already-installed + verified version, or null if none.
  Future<String?> _newestInstalled() async {
    final root = await _root();
    String? best;
    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      final v = p.basename(e.path);
      if (!_looksLikeVersion(v)) continue;
      if (!await _verifiedMarker(e).exists()) continue;
      if (best == null || _compareVersions(v, best) > 0) best = v;
    }
    return best;
  }

  /// Query GitHub for the latest release and compare to what's installed.
  /// Does not download — call [applyUpdate] to act on it.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!isSupported) return null;
    final prev = status.value;
    _set(const ServerStatus(ServerPhase.checking));
    try {
      final latest = await _latestVersion(_repo);
      final installed = await _newestInstalled();
      _set(prev); // restore the prior phase; the check itself isn't a state
      return UpdateInfo(installedVersion: installed, latestVersion: latest);
    } catch (e) {
      _log('update check failed: $e');
      _set(prev);
      return null;
    }
  }

  /// Download + verify + activate [version] (the install pipeline prunes older
  /// versions, keeping one for rollback). Used to apply an update reported by
  /// [checkForUpdate]; [ensureReady] already does this for the resolved version.
  Future<String?> applyUpdate(String version) => _install(_releaseFor(version));

  // ── install pipeline ──
  Future<String?> _install(ServerRelease release) async {
    final url = release.downloadUrl;
    if (url == null) {
      _set(const ServerStatus(ServerPhase.unsupported));
      return null;
    }
    final root = await _root();
    // Keep the .zip extension: archive's extractFileToDisk picks the format from
    // the file name and rejects an unknown/none suffix.
    final tmpZip = File(p.join(root.path, '${release.version}.download.zip'));
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
