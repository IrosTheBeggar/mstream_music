import 'dart:io';
import 'dart:math' show Random;

import 'cast_art.dart' show mimeForPath;
import 'cast_log.dart';

/// On-device HTTP server that streams phone-local audio files to a cast
/// renderer over the LAN.
///
/// DLNA / Chromecast renderers fetch media by URL and can't reach a file on the
/// phone's storage, so a local file-explorer track (whose `MediaItem.id` is a
/// UUID, not a URL) can't be cast directly. This server exposes such a file at
/// `http://<phone-lan-ip>:<port>/<token>/<name>.<ext>` for the duration of the
/// cast session; the cast backends [registerFile] a local file and hand the
/// renderer that URL instead of the unreachable id.
///
/// Scope / security: only files explicitly [registerFile]d are served (random
/// per-file token in the path; unknown tokens → 404), and the server runs only
/// while casting (started lazily by [ensureStarted], [stop]ped when playback
/// returns to the phone). Range requests are honoured so renderers can seek.
class LocalMediaServer {
  LocalMediaServer._();
  static final LocalMediaServer _instance = LocalMediaServer._();
  factory LocalMediaServer() => _instance;

  HttpServer? _server;
  String? _host; // LAN IPv4 the renderer connects back to
  final Random _rng = Random();
  final Map<String, String> _files = <String, String>{}; // token -> abs path
  final Map<String, String> _types = <String, String>{}; // token -> content type
  final Map<String, String> _dirs = <String, String>{}; // token -> directory

  bool get isRunning => _server != null;

  /// Bind the server (idempotent) and cache the LAN host + port. Call before
  /// each [registerFile]. Throws if the phone has no usable LAN address.
  Future<void> ensureStarted() async {
    if (_server != null) return;
    final host = await _lanAddress();
    if (host == null) {
      throw StateError('No LAN IPv4 address available (not on Wi-Fi?)');
    }
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    _host = host;
    server.listen(_handle,
        onError: (Object e) => castLog('LocalMediaServer listen error', error: e));
  }

  /// Register [absPath] for serving and return the URL the renderer fetches.
  /// Reuses the token for an already-registered path. Requires [ensureStarted].
  Uri registerFile(String absPath, {String? contentType}) {
    final server = _server;
    final host = _host;
    if (server == null || host == null) {
      throw StateError('registerFile called before ensureStarted');
    }
    for (final e in _files.entries) {
      if (e.value == absPath) {
        if (contentType != null) _types[e.key] = contentType;
        return _urlFor(host, server.port, e.key, absPath);
      }
    }
    final token = _newToken();
    _files[token] = absPath;
    if (contentType != null) _types[token] = contentType;
    return _urlFor(host, server.port, token, absPath);
  }

  /// Register a directory and return the URL for its [playlist] entry. Any file
  /// in the directory is then served at `<base>/<name>` — used for HLS, where
  /// the `.m3u8` references its `.ts` segments by relative name. Requires
  /// [ensureStarted].
  Uri registerDirectory(String dirPath, {String playlist = 'index.m3u8'}) {
    final server = _server;
    final host = _host;
    if (server == null || host == null) {
      throw StateError('registerDirectory called before ensureStarted');
    }
    String? token;
    for (final e in _dirs.entries) {
      if (e.value == dirPath) {
        token = e.key;
        break;
      }
    }
    token ??= _newToken();
    _dirs[token] = dirPath;
    return Uri(
        scheme: 'http', host: host, port: server.port,
        pathSegments: [token, playlist]);
  }

  /// Close the server and forget all registered files. Called when casting ends.
  Future<void> stop() async {
    final s = _server;
    _server = null;
    _host = null;
    _files.clear();
    _types.clear();
    _dirs.clear();
    if (s != null) {
      try {
        await s.close(force: true);
      } catch (_) {}
    }
  }

  // ── internals ──

  Uri _urlFor(String host, int port, String token, String absPath) => Uri(
        scheme: 'http',
        host: host,
        port: port,
        pathSegments: [token, _basename(absPath)],
      );

  String _newToken() {
    const chars = '0123456789abcdef';
    final sb = StringBuffer();
    for (var i = 0; i < 16; i++) {
      sb.write(chars[_rng.nextInt(chars.length)]);
    }
    final t = sb.toString();
    return (_files.containsKey(t) || _dirs.containsKey(t)) ? _newToken() : t;
  }

  String? _hlsType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (n.endsWith('.ts')) return 'video/mp2t';
    return null;
  }

  String _basename(String path) {
    final slash = path.lastIndexOf('/');
    final back = path.lastIndexOf('\\');
    final cut = slash > back ? slash : back;
    return cut >= 0 ? path.substring(cut + 1) : path;
  }

  Future<String?> _lanAddress() async {
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      // Prefer a private (RFC1918) address — the one a renderer on the same
      // Wi-Fi can reach.
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (_isPrivate(addr.address)) return addr.address;
        }
      }
      // Fallback: first non-loopback IPv4.
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          return addr.address;
        }
      }
    } catch (e) {
      castLog('LocalMediaServer LAN address lookup failed', error: e);
    }
    return null;
  }

  bool _isPrivate(String ip) =>
      ip.startsWith('192.168.') || ip.startsWith('10.') || _is172Private(ip);

  bool _is172Private(String ip) {
    if (!ip.startsWith('172.')) return false;
    final parts = ip.split('.');
    if (parts.length < 2) return false;
    final second = int.tryParse(parts[1]) ?? 0;
    return second >= 16 && second <= 31;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final seg = req.uri.pathSegments;
      final token = seg.isEmpty ? null : seg.first;
      String? path;
      String? contentType;
      if (token != null) {
        if (_files.containsKey(token)) {
          path = _files[token];
          contentType = _types[token];
        } else if (_dirs.containsKey(token) && seg.length >= 2) {
          final name = seg[1];
          if (name.isNotEmpty && !name.contains('..') && !name.contains('/')) {
            path = '${_dirs[token]}/$name';
            contentType = _hlsType(name);
          }
        }
      }
      if (path == null) return _notFound(res);
      final file = File(path);
      if (!await file.exists()) return _notFound(res);

      final length = await file.length();
      res.headers
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentTypeHeader,
            contentType ?? mimeForPath(path));

      // Parse a single byte range (renderers send `bytes=start-` or
      // `bytes=start-end`); multi-range isn't used by media renderers.
      var start = 0;
      var end = length - 1;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.startsWith('bytes=')) {
        final spec = range.substring(6).split('-');
        if (spec[0].isNotEmpty) start = int.tryParse(spec[0]) ?? 0;
        if (spec.length > 1 && spec[1].isNotEmpty) {
          end = int.tryParse(spec[1]) ?? end;
        }
        if (start < 0 || start >= length || start > end) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
          await res.close();
          return;
        }
        if (end > length - 1) end = length - 1;
        res.statusCode = HttpStatus.partialContent;
        res.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length');
      } else {
        res.statusCode = HttpStatus.ok;
      }

      final len = end - start + 1;
      if (req.method == 'HEAD') {
        // Set the length as a raw header (not res.contentLength, which would
        // make close() enforce a matching body size on this empty response).
        res.headers.set(HttpHeaders.contentLengthHeader, '$len');
        await res.close();
        return;
      }
      res.contentLength = len;
      await res.addStream(file.openRead(start, end + 1));
      await res.close();
    } catch (e) {
      castLog('LocalMediaServer request failed', error: e);
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _notFound(HttpResponse res) async {
    res.statusCode = HttpStatus.notFound;
    await res.close();
  }
}
