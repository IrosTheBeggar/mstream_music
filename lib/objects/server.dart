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

  // authentication is optional (mstream servers can be public OR private)
  String? username;
  String? password;
  String? jwt;

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
            json['storageBasePath'] is String ? json['storageBasePath'] : null;

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
        'storageBasePath': storageBasePath
      };
}
