class Server {
  String url;
  String localname; // name we use when mappings files to the fs

  // Where downloaded files are stored. One of:
  //   'appLocal'       — internal app-private storage (default; wiped on uninstall)
  //   'permanent'      — a user-chosen folder in shared storage (survives uninstall)
  //   'sdCard'         — a user-chosen folder on a removable SD card
  //   'legacyExternal' — migration-only: the pre-existing saveToSdCard==true
  //                      location (getExternalStorageDirectory). Not offered in
  //                      the UI; a server keeps it until the user re-picks a mode.
  // 'permanent'/'sdCard' keep their absolute base dir in [storageBasePath];
  // 'appLocal'/'legacyExternal' resolve their base at runtime (basePath null).
  String storageMode = 'appLocal';
  String? storageBasePath;

  // Runtime-only flag (never persisted): set by a compatibility probe
  // when this client can't work with the server build at [url]. While
  // true, calls against this server short-circuit to a generic failure.
  bool unsupported = false;

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

  // Auto DJ
  int? autoDJminRating;
  Map<String, bool> autoDJPaths = {};
  List<String> playlists = [];

  Server(this.url, this.username, this.password, this.jwt, this.localname);

  Server.fromJson(Map<String, dynamic> json)
      : url = json['url'],
        jwt = json['jwt'],
        username = json['username'],
        password = json['password'],
        localname = json['localname'],
        autoDJPaths = json['autoDJPaths']?.cast<String, bool>() ?? {},
        autoDJminRating = json['autoDJminRating'],
        playlists = List<String>.from(json['playlists'] ?? []),
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
        transcodeDefaultBitrate = json['transcodeDefaultBitrate'] as String?;

  Map<String, dynamic> toJson() => {
        'url': url,
        'jwt': jwt,
        'username': username,
        'password': password,
        'localname': localname,
        'autoDJPaths': autoDJPaths,
        'autoDJminRating': autoDJminRating,
        'playlists': playlists,
        'storageMode': storageMode,
        'storageBasePath': storageBasePath,
        'transcodeAvailable': transcodeAvailable,
        'transcodeDefaultCodec': transcodeDefaultCodec,
        'transcodeDefaultBitrate': transcodeDefaultBitrate
      };
}
