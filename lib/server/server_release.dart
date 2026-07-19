import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

/// Describes a downloadable mStream server release on GitHub and maps the
/// current platform to its release asset.
///
/// The mStream release layout (from its `build-bun.yml`) is deterministic, so
/// the asset URL can be built without hitting the API:
///   `https://github.com/<repo>/releases/download/v<version>/mStream-<version>-<key>.zip`
/// and the zip contains a top-level folder `mStream-<version>-<key>/` holding the
/// Bun-compiled `mStream(.exe)` plus its sidecars (rust-parser, rust-server-audio).
class ServerRelease {
  const ServerRelease({
    required this.repo,
    required this.version,
    this.sha256ByPlatform = const {},
  });

  /// `owner/name`, e.g. `IrosTheBeggar/mStream`.
  final String repo;

  /// Semver without the leading `v`, e.g. `6.15.1`.
  final String version;

  /// Pinned SHA-256 of the release zip, keyed by [platformKey]. When a hash is
  /// present for the current platform the manager enforces it; when absent the
  /// download is accepted on HTTPS trust alone (and flagged). Pin hashes for
  /// production — mStream's releases ship no checksums file to fetch.
  final Map<String, String> sha256ByPlatform;

  String get tag => 'v$version';

  /// Release-asset platform suffix for the current OS/arch, or null if this
  /// platform has no mStream release. Targets the glibc Linux builds; the
  /// `-musl` variants are a separate suffix not selected here.
  static String? platformKey() {
    switch (Abi.current()) {
      case Abi.windowsX64:
        return 'win-x64';
      case Abi.macosArm64:
        return 'darwin-arm64';
      case Abi.macosX64:
        return 'darwin-x64';
      case Abi.linuxX64:
        return 'linux-x64';
      case Abi.linuxArm64:
        return 'linux-arm64';
      default:
        return null;
    }
  }

  static bool get isPlatformSupported => platformKey() != null;

  /// Release asset filename for this platform, or null if unsupported.
  String? get assetName {
    final k = platformKey();
    return k == null ? null : 'mStream-$version-$k.zip';
  }

  /// Direct download URL (no API call needed — the layout is deterministic).
  String? get downloadUrl {
    final a = assetName;
    return a == null
        ? null
        : 'https://github.com/$repo/releases/download/$tag/$a';
  }

  /// Top-level folder inside the zip: `mStream-<version>-<key>`.
  String? get archiveRootDir {
    final k = platformKey();
    return k == null ? null : 'mStream-$version-$k';
  }

  /// The Bun-compiled executable's path within [archiveRootDir]. Windows/Linux
  /// zips place the bare binary at the archive root; the darwin zips wrap the
  /// server in an app bundle, with the binary (and its bin/ sidecars + webapp/,
  /// which it resolves relative to itself) under Contents/MacOS.
  static String get executableName => Platform.isWindows
      ? 'mStream.exe'
      : Platform.isMacOS
          ? 'mStream.app/Contents/MacOS/mStream'
          : 'mStream';

  /// Pinned hash for the current platform, if any.
  String? get expectedSha256 {
    final k = platformKey();
    return k == null ? null : sha256ByPlatform[k];
  }
}
