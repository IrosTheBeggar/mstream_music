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
  final Map<String, Uri> _proxies = <String, Uri>{}; // token -> upstream loopback URL
  HttpClient? _proxyClient; // reused for the iroh relay leg (keep-alive to loopback)

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

  /// Register an upstream loopback URL ([upstream], an iroh
  /// `http://127.0.0.1:<port>/...` tunnel URL a renderer can't reach) and return
  /// a LAN URL that reverse-proxies to it. Used to cast an iroh server's stream /
  /// art: the renderer fetches from the phone's LAN address and this server relays
  /// the bytes over the tunnel (forwarding Range so seeking works). The upstream's
  /// `__lt` loopback token rides only the inward leg — it's never in the LAN-facing
  /// URL. Reuses the token for an already-registered upstream. Requires
  /// [ensureStarted].
  Uri registerProxy(Uri upstream) {
    final server = _server;
    final host = _host;
    if (server == null || host == null) {
      throw StateError('registerProxy called before ensureStarted');
    }
    // Dedup on the URL minus the `__lt` token: the same track reloaded (seek /
    // replay / a tunnel reconnect that rotated the token) reuses its slot rather
    // than leaking a new entry — so the map stays bounded by distinct tracks, not
    // by loads. The stored upstream is refreshed to the current token for relays.
    final key = _proxyKey(upstream);
    for (final e in _proxies.entries) {
      if (_proxyKey(e.value) == key) {
        _proxies[e.key] = upstream;
        return _proxyUrlFor(host, server.port, e.key, upstream);
      }
    }
    final token = _newToken();
    _proxies[token] = upstream;
    return _proxyUrlFor(host, server.port, token, upstream);
  }

  // Dedup key for a proxied upstream: the URL without the rotating `__lt` token.
  String _proxyKey(Uri upstream) {
    if (!upstream.queryParameters.containsKey('__lt')) return upstream.toString();
    final q = Map<String, String>.from(upstream.queryParameters)..remove('__lt');
    return upstream.replace(queryParameters: q.isEmpty ? null : q).toString();
  }

  /// Close the server and forget all registered files. Called when casting ends.
  Future<void> stop() async {
    final s = _server;
    _server = null;
    _host = null;
    _files.clear();
    _types.clear();
    _dirs.clear();
    _proxies.clear();
    final pc = _proxyClient;
    _proxyClient = null;
    pc?.close(force: true);
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

  // The LAN URL a renderer fetches for a proxied upstream. Keep the upstream's
  // basename as the last segment so a content-type-by-extension sniff (and the
  // Chromecast contentType) matches what a direct stream would yield.
  Uri _proxyUrlFor(String host, int port, String token, Uri upstream) {
    final name = _basename(upstream.path);
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      pathSegments: name.isEmpty ? [token] : [token, name],
    );
  }

  String _newToken() {
    // 32 hex chars = 128-bit, matching the Rust loopback token — an unguessable
    // path segment is the only thing gating a LAN peer from a registered resource.
    const chars = '0123456789abcdef';
    final sb = StringBuffer();
    for (var i = 0; i < 32; i++) {
      sb.write(chars[_rng.nextInt(chars.length)]);
    }
    final t = sb.toString();
    return (_files.containsKey(t) ||
            _dirs.containsKey(t) ||
            _proxies.containsKey(t))
        ? _newToken()
        : t;
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
    // CORS: the Cast receiver plays HLS via MSE, i.e. it *fetches* the playlist
    // and segments cross-origin — blocked without these headers. (A plain MP4
    // loads via a <video> element and needs no CORS, which is why MP4 casting
    // worked but HLS showed the idle screen.)
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type, Range, Accept-Encoding');
    if (req.method == 'OPTIONS') {
      res.statusCode = HttpStatus.ok;
      await res.close();
      return;
    }
    try {
      final seg = req.uri.pathSegments;
      final token = seg.isEmpty ? null : seg.first;
      if (token != null && _proxies.containsKey(token)) {
        return _proxyRequest(req, _proxies[token]!);
      }
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

  // Relay a renderer's GET/HEAD to the [upstream] loopback URL, forwarding Range
  // so the renderer can seek and copying back status + content headers verbatim.
  // The upstream is the iroh tunnel's loopback listener; bytes stream through
  // without buffering the whole track. A failed inner leg surfaces as 502 so the
  // renderer (and the cast-failure fallback) treats it as a load error.
  Future<void> _proxyRequest(HttpRequest req, Uri upstream) async {
    final res = req.response;
    HttpClientRequest? up; // tracked so a timed-out relay can abort its socket
    HttpClientResponse? upRes; // tracked so a failed relay can release the socket
    try {
      final client = _proxyClient ??=
          (HttpClient()..connectionTimeout = const Duration(seconds: 15));
      final method = req.method == 'HEAD' ? 'HEAD' : 'GET';
      up = await client.openUrl(method, upstream);
      // Forward the byte range; ask for identity so Content-Length / Content-Range
      // stay exact (audio isn't gzipped, but be explicit rather than rely on it).
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) up.headers.set(HttpHeaders.rangeHeader, range);
      up.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      // Bound the wait for the upstream response headers: a tunnel that
      // accepts the connection but never answers (supervisor mid-reconnect)
      // would otherwise hang this relay and leave the renderer 'loading'
      // forever. The timeout lands in the catch below → 502 → the renderer
      // reports a media error and the cast failure walk takes over.
      upRes = await up.close().timeout(const Duration(seconds: 12));

      res.statusCode = upRes.statusCode;
      // Fall back to a basename sniff when the upstream omits Content-Type: a DLNA
      // renderer has no separate content-type field and relies on this header.
      res.headers.set(
          HttpHeaders.contentTypeHeader,
          upRes.headers.value(HttpHeaders.contentTypeHeader) ??
              _proxyFallbackType(upstream.path));
      final cr = upRes.headers.value(HttpHeaders.contentRangeHeader);
      if (cr != null) res.headers.set(HttpHeaders.contentRangeHeader, cr);
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      // A 206 may omit Content-Length (only Content-Range is required); derive it
      // from the range so the renderer always knows the body size for seeking.
      var len = upRes.headers.contentLength;
      if (len < 0 && cr != null) len = _lenFromContentRange(cr);
      if (method == 'HEAD') {
        // Raw header (not res.contentLength, which would make close() enforce a
        // matching body on this empty response).
        if (len >= 0) res.headers.set(HttpHeaders.contentLengthHeader, '$len');
        await upRes.drain<void>();
        await res.close();
        return;
      }
      if (len >= 0) res.contentLength = len; // else leave -1 → chunked
      await res.addStream(upRes);
      upRes = null; // body fully relayed — nothing to release
      await res.close();
    } catch (e) {
      castLog('LocalMediaServer proxy relay failed', error: e);
      // A relay that never got response headers (first-byte timeout) leaves
      // its request in flight on the shared keep-alive client — abort it, or
      // each timed-out fetch strands a zombie connection to the dead tunnel.
      if (upRes == null && up != null) {
        try {
          up.abort();
        } catch (_) {}
      }
      // Drain the half-read upstream so the reused keep-alive client doesn't pool
      // a dirty socket (e.g. the renderer aborted mid-stream on a seek).
      if (upRes != null) {
        try {
          await upRes.drain<void>();
        } catch (_) {}
      }
      try {
        res.statusCode = HttpStatus.badGateway;
        await res.close();
      } catch (_) {}
    }
  }

  // Content-Type fallback for a proxied upstream that omits the header. Unlike
  // the file-serving branch (always audio), the proxy relays BOTH the iroh audio
  // stream and the iroh album-art image, so the audio-only mimeForPath would
  // mislabel a header-less art relay as audio/mpeg. Recognize image extensions
  // here, then defer to the audio sniff for the stream case.
  String _proxyFallbackType(String path) {
    final name = _basename(path).toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return mimeForPath(path);
  }

  // Body length from a `Content-Range: bytes <start>-<end>/<total>` header.
  int _lenFromContentRange(String cr) {
    final m = RegExp(r'bytes\s+(\d+)-(\d+)').firstMatch(cr);
    if (m == null) return -1;
    return int.parse(m.group(2)!) - int.parse(m.group(1)!) + 1;
  }

  Future<void> _notFound(HttpResponse res) async {
    res.statusCode = HttpStatus.notFound;
    await res.close();
  }
}
