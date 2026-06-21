class Server {
  String url;
  String localname; // name we use when mappings files to the fs

  // Where downloaded files are stored. One of:
  //   'appLocal'       — internal app-private storage (default; wiped on uninstall)
  //   'appExternal'    — app-scoped external storage (Android/data/<pkg>; more
  //                      room / SD-capable, NO permission; wiped on uninstall).
  //                      The Play-compliant alternative to permanent/sdCard.
  //   'permanent'      — a user-chosen folder in shared storage (survives
  //                      uninstall). Needs All-files-access — FULL flavor only.
  //   'sdCard'         — a user-chosen folder on a removable SD card. Needs
  //                      All-files-access — FULL flavor only.
  //   'legacyExternal' — migration-only: the pre-existing saveToSdCard==true
  //                      location (getExternalStorageDirectory). Not offered in
  //                      the UI; a server keeps it until the user re-picks a mode.
  // 'permanent'/'sdCard' keep their absolute base dir in [storageBasePath];
  // the app-scoped modes resolve their base at runtime (basePath null).
  String storageMode = 'appLocal';
  String? storageBasePath;

  // Runtime-only flag (never persisted): set by a compatibility probe
  // when this client can't work with the server build at [url]. While
  // true, calls against this server short-circuit to a generic failure.
  bool unsupported = false;

  // Runtime-only (never persisted): the live loopback port of this server's iroh
  // tunnel while it is the active server. Set by ServerManager when the tunnel
  // starts; consumed by [effectiveBaseUrl].
  int? tunnelPort;

  // The server's transcoding capability from /api/v1/ping, refreshed on each
  // ping (getServerPaths) and PERSISTED so it's known at launch — before the
  // queue is restored, which would otherwise race the ping and bake in /media
  // URLs. null = unknown (not pinged yet) → treated optimistically as available
  // so a capable server isn't blocked during that window; false = no working
  // ffmpeg → stream the original; true = available. The defaults are the
  // codec/bitrate /transcode falls back to when the client omits those params.
  bool? transcodeAvailable;
  String? transcodeDefaultCodec;
  String? transcodeDefaultBitrate;

  // authentication is optional (mstream servers can be public OR private)
  String? username;
  String? password;
  String? jwt;

  // Transport for this server: 'http' (default) or 'iroh' (peer-to-peer tunnel).
  // For an iroh server [url] is only a placeholder/identity — the real base URL
  // is the live local proxy, resolved at runtime via [effectiveBaseUrl].
  String connectionType = 'http';
  // The iroh composite pairing code (durable identity + credential for an iroh
  // server, the role [url] plays for an HTTP server). Null for HTTP servers.
  String? irohPairingCode;

  // Full-flavor only: accept a self-signed / untrusted TLS cert for this server
  // — API calls (via Dart HttpOverrides) and streaming (via the native
  // insecure-TLS bridge for ExoPlayer). Off by default; the Play build never
  // exposes the toggle and ignores the flag.
  bool allowSelfSigned = false;

  // Auto DJ
  int? autoDJminRating;
  Map<String, bool> autoDJPaths = {};
  List<String> playlists = [];

  Server(this.url, this.username, this.password, this.jwt, this.localname);

  bool get isIroh => connectionType == 'iroh';

  /// The base origin to use for requests/streams right now. For an iroh server
  /// this is the live local tunnel (`http://127.0.0.1:<tunnelPort>`, set by
  /// ServerManager when the server is active); for HTTP it's [url]. When an iroh
  /// tunnel isn't up yet [tunnelPort] is null and this returns an unroutable
  /// origin, so a stray request fails fast instead of hitting the placeholder url.
  String get effectiveBaseUrl =>
      isIroh ? 'http://127.0.0.1:${tunnelPort ?? 0}' : url;

  Server.fromJson(Map<String, dynamic> json)
      : url = json['url'],
        jwt = json['jwt'],
        username = json['username'],
        password = json['password'],
        localname = json['localname'],
        autoDJPaths = json['autoDJPaths']?.cast<String, bool>() ?? {},
        autoDJminRating = json['autoDJminRating'],
        playlists = List<String>.from(json['playlists'] ?? []),
        allowSelfSigned = json['allowSelfSigned'] == true,
        // Migrate the old boolean: absent/false → appLocal; true → the
        // legacy external-app-private location (preserved losslessly so
        // existing SD-toggle downloads keep resolving).
        storageMode = json['storageMode'] is String
            ? json['storageMode'] as String
            : ((json['saveToSdCard'] == true) ? 'legacyExternal' : 'appLocal'),
        storageBasePath =
            json['storageBasePath'] is String ? json['storageBasePath'] : null,
        transcodeAvailable =
            json['transcodeAvailable'] is bool ? json['transcodeAvailable'] : null,
        transcodeDefaultCodec = json['transcodeDefaultCodec'] as String?,
        transcodeDefaultBitrate = json['transcodeDefaultBitrate'] as String?,
        connectionType = json['connectionType'] as String? ?? 'http',
        irohPairingCode = json['irohPairingCode'] as String?;

  Map<String, dynamic> toJson() => {
        'url': url,
        'jwt': jwt,
        'username': username,
        'password': password,
        'localname': localname,
        'autoDJPaths': autoDJPaths,
        'autoDJminRating': autoDJminRating,
        'playlists': playlists,
        'allowSelfSigned': allowSelfSigned,
        'storageMode': storageMode,
        'storageBasePath': storageBasePath,
        'transcodeAvailable': transcodeAvailable,
        'transcodeDefaultCodec': transcodeDefaultCodec,
        'transcodeDefaultBitrate': transcodeDefaultBitrate,
        'connectionType': connectionType,
        'irohPairingCode': irohPairingCode
      };
}
