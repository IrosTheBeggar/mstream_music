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

  // Runtime-only (never persisted): the live loopback port of this server's iroh
  // tunnel while it is the active server. Set by ServerManager when the tunnel
  // starts; consumed by [effectiveBaseUrl].
  int? tunnelPort;

  // Runtime-only (never persisted): the iroh tunnel's loopback auth token while
  // this server is active. The local proxy requires it as `__lt=<token>` so other
  // apps on the device can't use it; appended to every loopback URL. Set alongside
  // [tunnelPort] by ServerManager.
  String? tunnelToken;

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

  // Discovery (sonic-similarity) capability flags from /api/v1/ping, refreshed
  // on each ping and PERSISTED like [transcodeAvailable]. Unlike transcoding
  // these are gated STRICTLY on `== true` (no optimistic-null window): the
  // webapp never calls a /discovery endpoint unless the ping advertised it,
  // and the app follows the same rule. Older servers omit the keys → false.
  //   discoveryAvailable           — local similar tracks/artists
  //   discoveryP2pAvailable        — "From the network" (P2P snapshot leads)
  //   federationDiscoveryAvailable — "From your peers" (federation leads)
  bool? discoveryAvailable;
  bool? discoveryP2pAvailable;
  bool? federationDiscoveryAvailable;
  //   discoveryPathAvailable       — sonic path between two tracks; the
  //                                  flag's real payload is "this server
  //                                  VERSION has the route" (mStream #762)
  bool? discoveryPathAvailable;

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

  // ─── Federation ────────────────────────────────────────────────────────
  // A federated server is another server's PEER, reached through that
  // parent's browse proxy (mStream #927) instead of by a URL of its own. It
  // has no credentials, no transport and no version of its own — every one
  // of those is the parent's, which is why the accessors below delegate
  // rather than storing copies.
  //
  // [federationParent] is the parent's localname: the durable link, resolved
  // to a live object by ServerManager. [federationPeerId] is the peer's row
  // id ON THAT PARENT, which is what every proxy route keys on.
  String? federationParent;
  int? federationPeerId;

  // The peer's name as the parent reports it. A federated server has no URL to
  // show — [url] holds a synthetic `federated://…` identity — so this is what
  // the UI displays. Refreshed on every reconcile; a rename on the parent is
  // just a new label, and never moves [localname].
  String? federationPeerName;

  // The parent stopped listing this peer. Flagged rather than deleted: a
  // queued track and a downloaded file both point at this localname, and
  // dropping the record would strand them. Hidden from the picker; removed
  // only when the user says so, or with the parent.
  bool federationMissing = false;

  // The user hid this peer from the picker (and the car). Peers are the
  // parent admin's data, so "remove" would only last until the next
  // reconcile mirrored the list again — hiding is the durable choice, and it
  // keeps queued and downloaded tracks resolving. Cleared with "Show".
  bool federationHidden = false;

  /// Whether the picker (and the car UI) may offer this server: not a peer
  /// its parent no longer lists, and not one the user hid.
  bool get isSelectable => !federationMissing && !federationHidden;

  // Runtime-only (never persisted): the live parent, linked by ServerManager
  // after the list loads and on every peer reconcile. Same contract as
  // [tunnelPort] — null means "not resolvable yet", and every accessor below
  // fails closed onto an unroutable origin rather than guessing.
  Server? parentServer;

  bool get isFederated => federationParent != null;

  /// The server whose transport carries this server's bytes: the parent for a
  /// federated server, itself for everything else. Null only for a federated
  /// server whose parent is not linked yet (nothing can be addressed then).
  ///
  /// Two different questions hide behind "is this an iroh server?": identity
  /// (the pairing-code menu, the one-iroh cap, the edit form — [isIroh]) and
  /// transport (does a request for it ride a loopback tunnel, and whose —
  /// [isIrohTransport]). A peer of an iroh parent answers no to the first and
  /// yes to the second.
  Server? get transportServer => isFederated ? parentServer : this;

  /// True when requests for this server travel over an iroh loopback tunnel —
  /// its own, or its parent's for a federated server.
  bool get isIrohTransport => transportServer?.isIroh == true;

  /// What to call this server in the UI: a peer's name, or the URL that
  /// identifies every other kind of server.
  String get displayName => isFederated
      ? (federationPeerName ?? 'Peer $federationPeerId')
      : url;

  /// Raw `server` string from `GET /api/` — display as reported, compare via
  /// ServerVersion.tryParse. Null means the server has never answered that
  /// endpoint, which puts it before 5.4.2 (see util/server_version.dart).
  String? serverVersion;

  /// When [serverVersion] was last fetched, so the periodic re-check knows
  /// whether it is stale. Null = never checked.
  DateTime? versionCheckedAt;

  // Full-flavor only: accept a self-signed / untrusted TLS cert for this server
  // — API calls (via Dart HttpOverrides) and streaming (via the native
  // insecure-TLS bridge for ExoPlayer). Off by default; the Play build never
  // exposes the toggle and ignores the flag.
  bool allowSelfSigned = false;

  // Auto DJ
  int? autoDJminRating;
  Map<String, bool> autoDJPaths = {};
  // Genre filter — per-server for the same reason as the two above: genre
  // strings are the library's own vocabulary, so a whitelist built from one
  // server's tags means nothing against another's (the picker even fetches
  // its autocomplete list per-server). Sent server-side as `genres` +
  // `genreMode` on random-songs. Migrated out of auto_dj.json, where it used
  // to live globally — see AutoDJManager.migrateGenreFilterToServers.
  bool autoDJGenreEnabled = false;
  String autoDJGenreMode = 'whitelist'; // 'whitelist' | 'blacklist'
  List<String> autoDJGenres = [];
  List<String> playlists = [];

  Server(this.url, this.username, this.password, this.jwt, this.localname);

  bool get isIroh => connectionType == 'iroh';

  /// Origin a request falls back to when this server can't be addressed yet —
  /// a dialing iroh tunnel, or a federated server whose parent isn't linked.
  /// Unroutable on purpose: a stray request fails fast instead of reaching
  /// something that isn't this server.
  static const String _unroutable = 'http://127.0.0.1:0';

  /// Prefix shared by every route the parent proxies on a peer's behalf
  /// (`/api/…`, `/art/…`, `/stream/…`). Meaningless unless [isFederated].
  String get federationPrefix => '/api/v1/federation/peers/$federationPeerId';

  /// The token that authenticates requests for this server. A federated server
  /// has none of its own: the proxy runs normal local-user auth on the PARENT,
  /// and the peer beyond it is reached with the parent's federation key, which
  /// never leaves the parent. Read this — not [jwt] — for anything that ends up
  /// on the wire.
  String? get authToken => isFederated ? parentServer?.jwt : jwt;

  /// The base origin to use for requests/streams right now. A federated server
  /// borrows its parent's, which is what makes an iroh parent work for free —
  /// the request rides the parent's loopback tunnel and the proxy dials the
  /// peer from there. For an iroh server it's the live local tunnel
  /// (`http://127.0.0.1:<tunnelPort>`, set by ServerManager when the server is
  /// active); for HTTP it's [url]. Before an iroh tunnel is up, or before a
  /// federated server's parent is linked, this is [_unroutable].
  String get effectiveBaseUrl {
    if (isFederated) return parentServer?.effectiveBaseUrl ?? _unroutable;
    return isIroh ? 'http://127.0.0.1:${tunnelPort ?? 0}' : url;
  }

  /// Query suffix authenticating a loopback request to the iroh tunnel
  /// (`&__lt=<token>`); empty for HTTP servers or before the token is known. For
  /// URLs built as strings that ALREADY carry a `?` (stream / art / download).
  /// A federated server inherits its parent's: the URL lands on the parent's
  /// loopback, and the browse proxy forwards no query params onward, so the
  /// loopback token can't ride through to the peer.
  String get localTokenQuery {
    if (isFederated) return parentServer?.localTokenQuery ?? '';
    return (isIroh && tunnelToken != null) ? '&__lt=$tunnelToken' : '';
  }

  /// Resolve [location] against [effectiveBaseUrl], adding the loopback token for
  /// an iroh server so the shim accepts the request. Use for all API calls.
  ///
  /// A federated server rewrites [location] onto the parent's browse proxy and
  /// then defers to the parent — so an iroh parent's `__lt` is applied once, to
  /// the outer loopback URL, and the peer sees only the proxied path.
  Uri apiUri(String location) {
    if (isFederated) {
      final parent = parentServer;
      if (parent == null) return Uri.parse(_unroutable);
      return parent.apiUri('$federationPrefix/api$location');
    }
    final u = Uri.parse(effectiveBaseUrl).resolve(location);
    if (!isIroh || tunnelToken == null) return u;
    return u.replace(queryParameters: {
      ...u.queryParameters,
      '__lt': tunnelToken!,
    });
  }

  Server.fromJson(Map<String, dynamic> json)
      : url = json['url'],
        jwt = json['jwt'],
        username = json['username'],
        password = json['password'],
        localname = json['localname'],
        autoDJPaths = json['autoDJPaths']?.cast<String, bool>() ?? {},
        autoDJminRating = json['autoDJminRating'],
        autoDJGenreEnabled = json['autoDJGenreEnabled'] == true,
        // Anything unrecognised falls back to whitelist rather than rippling
        // a junk value into the request body.
        autoDJGenreMode =
            json['autoDJGenreMode'] == 'blacklist' ? 'blacklist' : 'whitelist',
        autoDJGenres = List<String>.from(json['autoDJGenres'] ?? []),
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
        discoveryAvailable =
            json['discoveryAvailable'] is bool ? json['discoveryAvailable'] : null,
        discoveryP2pAvailable = json['discoveryP2pAvailable'] is bool
            ? json['discoveryP2pAvailable']
            : null,
        federationDiscoveryAvailable =
            json['federationDiscoveryAvailable'] is bool
                ? json['federationDiscoveryAvailable']
                : null,
        discoveryPathAvailable = json['discoveryPathAvailable'] is bool
            ? json['discoveryPathAvailable']
            : null,
        connectionType = json['connectionType'] as String? ?? 'http',
        irohPairingCode = json['irohPairingCode'] as String?,
        federationParent = json['federationParent'] as String?,
        federationPeerId =
            json['federationPeerId'] is int ? json['federationPeerId'] : null,
        federationPeerName = json['federationPeerName'] as String?,
        federationMissing = json['federationMissing'] == true,
        federationHidden = json['federationHidden'] == true,
        serverVersion = json['serverVersion'] as String?,
        versionCheckedAt = json['versionCheckedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(json['versionCheckedAt'])
            : null;

  Map<String, dynamic> toJson() => {
        'url': url,
        'jwt': jwt,
        'username': username,
        'password': password,
        'localname': localname,
        'autoDJPaths': autoDJPaths,
        'autoDJminRating': autoDJminRating,
        'autoDJGenreEnabled': autoDJGenreEnabled,
        'autoDJGenreMode': autoDJGenreMode,
        'autoDJGenres': autoDJGenres,
        'playlists': playlists,
        'allowSelfSigned': allowSelfSigned,
        'storageMode': storageMode,
        'storageBasePath': storageBasePath,
        'transcodeAvailable': transcodeAvailable,
        'transcodeDefaultCodec': transcodeDefaultCodec,
        'transcodeDefaultBitrate': transcodeDefaultBitrate,
        'discoveryAvailable': discoveryAvailable,
        'discoveryP2pAvailable': discoveryP2pAvailable,
        'federationDiscoveryAvailable': federationDiscoveryAvailable,
        'discoveryPathAvailable': discoveryPathAvailable,
        'connectionType': connectionType,
        'irohPairingCode': irohPairingCode,
        'federationParent': federationParent,
        'federationPeerId': federationPeerId,
        'federationPeerName': federationPeerName,
        'federationMissing': federationMissing,
        'federationHidden': federationHidden,
        'serverVersion': serverVersion,
        'versionCheckedAt': versionCheckedAt?.millisecondsSinceEpoch
      };
}
