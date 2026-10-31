import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;

import '../build_variant.dart';
import '../l10n/app_localizations.dart';
import '../objects/discovery_plugins.dart';
import '../objects/server.dart';
import '../objects/ytdl_job.dart';
import '../screens/discovery/keep_toast.dart';
import '../screens/ytdl/ytdl_crumbs.dart';
import '../screens/ytdl/ytdl_draft.dart';
import '../util/discover_jobs.dart' show foldBase, pathCrumbs;
import '../util/discovery_plugins_api.dart';
import '../util/media_format.dart' show isM3u;
import '../util/ytdl_api.dart';
import '../util/ytdl_errors.dart';
import '../util/ytdl_filename.dart' show ytdlOutputExtension;
import '../util/ytdl_formats.dart';
import '../util/ytdl_layout.dart';
import 'api.dart';
import 'app_messenger.dart';
import 'browser_list.dart';
import 'server_list.dart';

/// What the phone knows of a server's Add from YouTube behaviour (design
/// spec §1 "Server floor"). [full] is mStream 6.30+ — the staging folder,
/// the caps, the live filter, the download record and the name-clash
/// refusal — read from `GET /discovery/downloads` answering 200, which
/// shipped in the same release. Until that answer the older rules apply.
enum YtdlServerTier { unknown, older, full }

/// The home card's second line (spec §2): the first count that is not zero
/// wins — "Adding {n}", "{n} failed", "Added {n}".
class YtdlHomeSummary {
  final int adding;

  /// Rows in NEEDS A LOOK the screen has not shown yet.
  final int failed;

  /// Songs that finished in the last hour, not seen on the screen yet.
  final int added;

  const YtdlHomeSummary({this.adding = 0, this.failed = 0, this.added = 0});

  bool get isEmpty => adding == 0 && failed == 0 && added == 0;

  @override
  bool operator ==(Object other) =>
      other is YtdlHomeSummary &&
      other.adding == adding &&
      other.failed == failed &&
      other.added == added;

  @override
  int get hashCode => Object.hash(adding, failed, added);

  @override
  String toString() =>
      'YtdlHomeSummary($adding adding, $failed failed, $added added)';
}

/// One ADDED row: a download record (6.30+, every device's and the web
/// app's adds) or one of this phone's finished jobs (older servers).
class YtdlAddedRow {
  final String title;

  /// The folder, like '/Music/Daft Punk/Discovery/' (for crumbs).
  final String directory;

  /// The file's extension, lower case ('mp3'); null when it has none.
  final String? ext;
  final int? bytes;

  /// When it landed (display only: a record's time is the server's clock).
  final DateTime? when;

  /// The library still has the song (a record's track row exists).
  final bool present;

  /// The song on the server as the download record names it:
  /// `<vpath>/<rel>`, NO leading slash (a browser file row's `data` has
  /// one). Null when the phone cannot name the file.
  final String? filepath;
  final int? recordId;

  const YtdlAddedRow({
    required this.title,
    required this.directory,
    this.ext,
    this.bytes,
    this.when,
    this.present = true,
    this.filepath,
    this.recordId,
  });

  @override
  String toString() => 'YtdlAddedRow($title, $filepath)';
}

/// One tap of Add to library, as the hub runs it.
class YtdlStartRequest {
  /// The canonical link (util/ytdl_link.dart) and the folder, exactly as
  /// POSTed.
  final String url;
  final String directory;
  final String codec;

  /// The tags to write: non-empty values only (the year 4 digits).
  final Map<String, String> metadata;

  /// What the row calls it, its cover, and the file name yt-dlp will
  /// most likely give it.
  final String title;
  final String? cover;
  final String predictedName;

  /// The folder to make first (recursive) when one on the path is new or
  /// could not be checked; null = it is there.
  final String? mkdir;

  /// `screen` | `folder:<currentPath>` — which surface sent it.
  final String? origin;

  /// True while the surface that sent it shows its own failures (its
  /// screen or sheet is up): a failure before the server took the add is
  /// then dropped from the rows ([YtdlServerState.discardStartFailure])
  /// and left to that surface. Asked when the failure arrives; null or
  /// false → a "Couldn't add" row and toast.
  final bool Function()? inline;

  const YtdlStartRequest({
    required this.url,
    required this.directory,
    required this.codec,
    this.metadata = const {},
    required this.title,
    this.cover,
    required this.predictedName,
    this.mkdir,
    this.origin,
    this.inline,
  });
}

/// What a start, an Add again or a retry came to. [ok]: the server took
/// it (200). [timedOut]: the POST went out and no answer came — the job is
/// `startUnsure` and the hub looks for it. Otherwise [failure] says why
/// nothing started.
class YtdlStartOutcome {
  final bool ok;
  final bool timedOut;
  final YtdlFailure? failure;
  final YtdlJob? job;

  const YtdlStartOutcome({
    this.ok = false,
    this.timedOut = false,
    this.failure,
    this.job,
  });

  @override
  String toString() =>
      'YtdlStartOutcome(${ok ? 'ok' : timedOut ? 'timed out' : failure})';
}

/// Add from YouTube's state, one [YtdlServerState] per own server, shared
/// by everything that shows it: the screen and its rows, the file
/// explorer's sheet and strip, the home card's second line. One poll per
/// server, one toast per ending.
///
/// The hub owns every add from the tap — the mkdir and the POST — so
/// leaving the screen or closing the sheet never cancels one (spec §6
/// "Who owns the request"). Jobs persist with their server; drafts live
/// in memory for the session.
///
/// [install] wires it into the app (main.dart): the home's SERVER card
/// asks [entryAllowed] through [BrowserManager.homeYtdlRow], and the
/// app's lifecycle pauses the polls in the background.
class YtdlHub with WidgetsBindingObserver {
  YtdlHub._();
  static final YtdlHub _instance = YtdlHub._();
  factory YtdlHub() => _instance;

  // ── test seams (reset() restores the defaults) ──────────────────────────

  /// How a server's client is made (tests wire one to their fake).
  YtdlApi Function(Server server) makeApi = _defaultMakeApi;
  static YtdlApi _defaultMakeApi(Server server) => YtdlApi(server);

  Timer Function(Duration delay, void Function() fire) timer = Timer.new;
  DateTime Function() now = DateTime.now;

  /// Where a toast goes; null = KeepToast in the root overlay.
  void Function(String message, {bool success})? toast;

  /// The words a toast reads (the app's navigator context's by default).
  AppLocalizations? Function() l10n = _rootL10n;

  /// Writes a server's remembered choices and jobs to servers.json.
  Future<void> Function(Server server) persist = _defaultPersist;

  /// Pings a server again: a 403 or an "FFmpeg is not available yet" means
  /// a flag the ping gave is stale (spec §2).
  Future<void> Function(Server server) reping = _defaultReping;

  Future<bool> Function() clipboardHasText = _defaultHasText;
  Future<String?> Function() clipboardText = _defaultClipText;

  /// Waits for a tunnel server's tunnel before the add's one send — a
  /// wait, never a retry: before the tunnel is up the request would be
  /// refused on the phone and read as offline.
  Future<bool> Function(Server server) awaitTunnel = _defaultAwaitTunnel;

  /// The account's collection destination (Discover's "Same as Discover"
  /// and the libraries' templates), read only.
  Future<DestinationView> Function(Server server) destinationOf =
      _defaultDestination;

  /// `GET /torrent/path-templates`: the libraries' templates when the
  /// destination view has none.
  Future<Map<String, dynamic>> Function(Server server) pathTemplatesOf =
      _defaultPathTemplates;

  /// False leaves the app lifecycle to the caller
  /// ([didChangeAppLifecycleState]; tests).
  bool watchLifecycle = true;

  /// Whether this build shows the feature at all ([ytdlEntry]; tests make
  /// it a store build with resolveYtdlEntry).
  @visibleForTesting
  static bool Function() buildShowsEntry = _defaultBuildShowsEntry;
  static bool _defaultBuildShowsEntry() => ytdlEntry;

  static AppLocalizations? _rootL10n() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    try {
      return AppLocalizations.of(ctx);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _defaultPersist(Server server) =>
      ServerManager().writeServerFile();

  static Future<void> _defaultReping(Server server) =>
      ServerManager().getServerPaths(server);

  static Future<bool> _defaultHasText() => Clipboard.hasStrings();

  static Future<String?> _defaultClipText() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  static Future<bool> _defaultAwaitTunnel(Server server) =>
      ServerManager().awaitTunnelReady(
          server: server,
          timeout: const Duration(seconds: 12),
          caller: 'ytdl-add');

  static Future<DestinationView> _defaultDestination(Server server) =>
      DiscoveryPluginsApi(server).destination();

  static Future<Map<String, dynamic>> _defaultPathTemplates(Server server) =>
      ApiManager().torrentPathTemplates(server: server);

  // ── state ───────────────────────────────────────────────────────────────

  final Map<Server, YtdlServerState> _states = Map.identity();
  bool _installed = false;
  bool _observing = false;
  bool _foreground = true;

  bool get installed => _installed;

  /// The app is in front (polls run only then).
  bool get foreground => _foreground;

  /// Wire the hub into the app: the home's card and the app lifecycle.
  /// Jobs load per server on its first [stateFor].
  void install() {
    if (_installed) return;
    _installed = true;
    BrowserManager.homeYtdlRow = entryAllowed;
    _observe();
  }

  /// Undo [install], stop every poll, let every state and draft go, and
  /// restore the seams (tests).
  void reset() {
    for (final s in _states.values) {
      s._dispose();
    }
    _states.clear();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _installed = false;
    _foreground = true;
    BrowserManager.homeYtdlRow = BrowserManager.noYtdlRow;
    makeApi = _defaultMakeApi;
    timer = Timer.new;
    now = DateTime.now;
    toast = null;
    l10n = _rootL10n;
    persist = _defaultPersist;
    reping = _defaultReping;
    clipboardHasText = _defaultHasText;
    clipboardText = _defaultClipText;
    awaitTunnel = _defaultAwaitTunnel;
    destinationOf = _defaultDestination;
    pathTemplatesOf = _defaultPathTemplates;
    watchLifecycle = true;
    buildShowsEntry = _defaultBuildShowsEntry;
  }

  void _observe() {
    if (!watchLifecycle || _observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // No binding (a plain unit test): the caller drives the lifecycle.
    }
  }

  /// Spec §2 gates — hidden, never greyed: a build that shows the feature,
  /// an own server (`/ytdl` is off the federation allowlist), an account
  /// that may upload, audio conversion not known to be off (the route's
  /// own ffmpeg check), and at least one library.
  static bool entryAllowed(Server? server) =>
      buildShowsEntry() &&
      server != null &&
      !server.isFederated &&
      server.noUpload != true &&
      server.transcodeAvailable != false &&
      server.autoDJPaths.isNotEmpty;

  /// Spec §7: [entryAllowed], in a server explorer frame (its path starts
  /// with '/'; Local Files' never does) below the root, not an m3u.
  static bool explorerEntryAllowed(Server? server, String? currentPath) =>
      entryAllowed(server) &&
      currentPath != null &&
      currentPath.startsWith('/') &&
      currentPath != '/' &&
      !isM3u(currentPath);

  /// [server]'s own server's state (one each, kept for the app's life).
  /// The first ask loads the jobs it persisted; open ones resume polling.
  YtdlServerState stateFor(Server server) {
    final own = ownServerOf(server) ?? server;
    final have = _states[own];
    if (have != null) return have;
    _observe();
    final state = YtdlServerState._(this, own);
    _states[own] = state;
    state._load();
    return state;
  }

  /// A toast through [toast] or KeepToast.
  void showToast(String message, {bool success = false}) {
    final t = toast;
    if (t != null) {
      t(message, success: success);
    } else {
      KeepToast.show(null, message, success: success);
    }
  }

  /// In the background every poll pauses; back in front each server with
  /// a job open polls once (what ended while away settles then).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool fg;
    switch (state) {
      case AppLifecycleState.resumed:
        fg = true;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        fg = false;
      case AppLifecycleState.inactive:
        return; // a passing state (a system sheet, the app switcher)
    }
    if (fg == _foreground) return;
    _foreground = fg;
    for (final s in _states.values) {
      s._foregroundChanged(fg);
    }
  }
}

/// Add from YouTube on one own server: its jobs and their polling, the
/// ADDED list, the remembered destination and format, the account's
/// presets, the version tier, and the drafts of its screen and of each
/// explorer folder.
class YtdlServerState extends ChangeNotifier {
  YtdlServerState._(this.hub, this.server);

  final YtdlHub hub;
  final Server server;

  /// Every 3 s while a job is open and the app is in front (spec §6).
  static const Duration kPollBeat = Duration(seconds: 3);

  /// How long a job the server never answered for (a timed-out POST), or
  /// one it took but whose entry never showed up, is looked for.
  static const Duration kClaimWindow = Duration(minutes: 2);

  /// NEEDS A LOOK keeps a row this long; at most [kKeepJobs] jobs persist.
  static const Duration kKeepFailed = Duration(days: 7);
  static const int kKeepJobs = 20;

  /// "Added {n}" on the home card lasts this long.
  static const Duration kAddedNews = Duration(hours: 1);

  /// The download record is paged at most this deep for one job.
  static const int kRecordPages = 5;
  static const int kRecordPage = 20;

  final List<YtdlJob> _jobs = [];
  final Map<String, DateTime> _sentAt = {};
  final Map<String, String> _origins = {};
  final Set<String> _busy = {};

  /// Pids of rows dismissed this session: a new job never claims one.
  final Set<int> _retiredPids = {};
  final StreamController<YtdlJob> _settledOut =
      StreamController<YtdlJob>.broadcast();

  YtdlServerTier _tier = YtdlServerTier.unknown;
  Future<void>? _probing;
  bool _ytdlpMissing = false;
  bool _offline = false;
  bool _mkdirRefused = false;

  List<YtdlRecord> _records = const [];
  bool _addedLoading = false;
  bool _canShowEarlier = false;
  Future<void>? _refreshingAdded;

  CollectionDestination? _discover;
  Map<String, String> _templates = const {};
  bool _presetsLoaded = false;
  Future<void>? _loadingPresets;

  YtdlDraft? _screenDraft;
  final Map<String, YtdlDraft> _folderDrafts = {};

  Timer? _poll;
  Future<void>? _polling;
  bool _disposed = false;

  YtdlApi get api => hub.makeApi(server);
  DateTime get _now => hub.now();

  // ── reading ─────────────────────────────────────────────────────────────

  /// Probed once per session ([probeTier]); the older rules until it answers.
  YtdlServerTier get tier => _tier;

  /// The server has no yt-dlp (spec §8): remembered for the session, so a
  /// later visit shows it at once; a lookup that works clears it.
  bool get ytdlpMissing => _ytdlpMissing;
  set ytdlpMissing(bool v) {
    if (v == _ytdlpMissing) return;
    _ytdlpMissing = v;
    _notify();
  }

  /// The last poll got no answer at all: open rows read "Waiting for
  /// connection" (spec §8).
  bool get offline => _offline;

  /// Every job this phone knows on this server, newest first (tests and
  /// the rows' actions).
  List<YtdlJob> get jobs => List.unmodifiable(_jobs);

  /// Open and not hidden — starting, startUnsure, adding — newest first.
  List<YtdlJob> get adding =>
      [for (final j in _jobs) if (j.open && !j.hidden) j];

  /// NEEDS A LOOK: not hidden, at most 7 days old, newest first.
  List<YtdlJob> get needsLook => [
        for (final j in _jobs)
          if (!j.hidden && _needsLook(j.state) && _fresh(j)) j,
      ];

  static bool _needsLook(YtdlJobState s) => switch (s) {
        YtdlJobState.failedClash ||
        YtdlJobState.failed ||
        YtdlJobState.notSureFinished ||
        YtdlJobState.notSureStarted ||
        YtdlJobState.notFound ||
        YtdlJobState.startFailed =>
          true,
        _ => false,
      };

  /// A failure the explorer strip names ("Couldn't add …").
  static bool _failure(YtdlJobState s) =>
      s == YtdlJobState.failed ||
      s == YtdlJobState.failedClash ||
      s == YtdlJobState.startFailed;

  bool _fresh(YtdlJob j) =>
      _now.difference(j.endedAt ?? j.createdAt) <= kKeepFailed;

  /// ADDED: on 6.30+ the account's download record (paged) with any of
  /// this phone's finished jobs no record answered for; on older servers
  /// (and until the tier is known) this phone's finished jobs.
  List<YtdlAddedRow> get added {
    final mine = [
      for (final j in _jobs)
        if (j.state == YtdlJobState.added &&
            (_tier != YtdlServerTier.full || j.recordId == null))
          _rowOfJob(j),
    ];
    if (_tier != YtdlServerTier.full) return mine;
    final rows = [...mine, for (final r in _records) _rowOfRecord(r)];
    rows.sort((a, b) => (b.when?.millisecondsSinceEpoch ?? 0)
        .compareTo(a.when?.millisecondsSinceEpoch ?? 0));
    return rows;
  }

  bool get addedLoading => _addedLoading;

  /// "Show earlier" has more to ask for: a page counts every plug-in's
  /// rows, so only an empty one is the end.
  bool get canShowEarlier => _tier == YtdlServerTier.full && _canShowEarlier;

  static YtdlAddedRow _rowOfRecord(YtdlRecord r) {
    final folder = _folderOf(r.filepath);
    final name = r.filepath.split('/').last;
    final dot = name.lastIndexOf('.');
    return YtdlAddedRow(
      title: r.title ?? (dot > 0 ? name.substring(0, dot) : name),
      directory: folder.isEmpty ? '/' : '/$folder/',
      ext: _extOf(r.filepath),
      bytes: r.bytes,
      when: r.downloadedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(r.downloadedAt)
          : null,
      present: r.present,
      filepath: r.filepath.isEmpty ? null : r.filepath,
      recordId: r.id,
    );
  }

  static YtdlAddedRow _rowOfJob(YtdlJob j) {
    final named = j.filepath ??
        (j.predictedName.isEmpty
            ? null
            : '${_bare(j.directory)}/${j.predictedName}');
    return YtdlAddedRow(
      title: j.title,
      directory: j.directory,
      ext: named == null ? ytdlOutputExtension(j.codec) : _extOf(named),
      bytes: j.bytes,
      when: j.endedAt,
      filepath: named,
      recordId: j.recordId,
    );
  }

  static String? _extOf(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 && dot < name.length - 1
        ? name.substring(dot + 1).toLowerCase()
        : null;
  }

  /// The home card's second line (spec §2).
  YtdlHomeSummary get summary {
    final now = _now;
    var failed = 0;
    var done = 0;
    for (final j in _jobs) {
      if (j.hidden || j.seen) continue;
      if (_needsLook(j.state) && _fresh(j)) failed++;
      final ended = j.endedAt;
      if (j.state == YtdlJobState.added &&
          ended != null &&
          now.difference(ended) <= kAddedNews) {
        done++;
      }
    }
    return YtdlHomeSummary(adding: adding.length, failed: failed, added: done);
  }

  /// The screen showed every outcome so far: the home's "failed" and
  /// "Added" counts clear.
  void markSeen() {
    var changed = false;
    for (final j in _jobs) {
      if (!j.open && !j.seen) {
        j.seen = true;
        changed = true;
      }
    }
    if (!changed) return;
    _changed();
  }

  /// The explorer strip's jobs for the folder on screen (spec §7): open
  /// ones, and failures not yet seen, whose folder is [folderPath] or
  /// below it.
  List<YtdlJob> jobsUnder(String folderPath) {
    final base = _slashed(folderPath).toLowerCase();
    return [
      for (final j in _jobs)
        if (!j.hidden &&
            (j.open || (_failure(j.state) && !j.seen)) &&
            _slashed(j.directory).toLowerCase().startsWith(base))
          j,
    ];
  }

  /// A job reached added or a failure ("not sure" states included): the
  /// explorer re-lists its folder.
  Stream<YtdlJob> get settled => _settledOut.stream;

  /// Which surface started [job] (`screen` | `folder:<path>`), this
  /// session only.
  String? originOf(YtdlJob job) => _origins[job.id];

  /// A Check again, Add again or retry for [job] is running (its buttons
  /// are busy).
  bool busy(YtdlJob job) => _busy.contains(job.id);

  /// An open job (hidden ones too: the server keeps going) adds [url] to
  /// [directory] — "Already adding to this folder".
  bool isAdding(String url, String directory) =>
      _jobs.any((j) => j.open && j.url == url && j.directory == directory);

  // ── destination memory (spec §4 "Remembered per server, on this phone")

  /// The remembered library while the account still has it; else first
  /// use: Discover's library when its destination is the user's own, else
  /// the first library.
  String get library {
    final libraries = server.autoDJPaths.keys;
    final remembered = server.ytdlLibrary;
    if (remembered != null && libraries.contains(remembered)) return remembered;
    final d = _discover;
    if (d != null && libraries.contains(d.vpath)) return d.vpath;
    return libraries.isEmpty ? '' : libraries.first;
  }

  /// The remembered layout, else Artist / Album (never inherited).
  String get layout => server.ytdlLayout ?? kYtdlLayoutArtistAlbum;

  /// 'artistAlbum' | 'artist' | 'top' | 'discover' | 'library' | 'custom'.
  /// "Same as Discover" and "Library layout" read 'custom' once the
  /// presets answered without them.
  String get layoutKind {
    final kind = server.ytdlLayoutKind;
    if (kind == 'discover' && _presetsLoaded && _discover == null) {
      return 'custom';
    }
    if (kind == 'library' && _presetsLoaded && _templates[library] == null) {
      return 'custom';
    }
    if (kind != null) return kind;
    return switch (layout) {
      kYtdlLayoutTop => 'top',
      kYtdlLayoutArtistAlbum => 'artistAlbum',
      kYtdlLayoutArtist => 'artist',
      _ => 'custom',
    };
  }

  /// The choice new songs land by: the remembered one, following "Same as
  /// Discover" and "Library layout" to their preset while it is known.
  YtdlChoice get rememberedChoice {
    final kind = layoutKind;
    final d = _discover;
    if (kind == 'discover' && d != null) {
      return YtdlChoice(
          library: d.vpath, layout: d.layout, kind: kind, base: d.base);
    }
    final lib = library;
    final template = _templates[lib];
    if (kind == 'library' && template != null) {
      return YtdlChoice(library: lib, layout: template, kind: kind);
    }
    return YtdlChoice(library: lib, layout: layout, kind: kind);
  }

  /// Save "Where new songs land" for this server. A "Same as Discover"
  /// choice keeps its base folders in front of the layout ([foldBase]): the
  /// copy used while Discover's destination is not known.
  Future<void> rememberDestination({
    required String library,
    required String layout,
    required String kind,
    String base = '',
  }) async {
    server.ytdlLibrary = library;
    server.ytdlLayout = kind == 'discover' ? foldBase(base, layout) : layout;
    server.ytdlLayoutKind = kind;
    _notify();
    await _persist();
  }

  String get format =>
      ytdlEffectiveFormat(server.ytdlFormat, server.supportedAudioFormats);
  List<String> get formats => ytdlFormatOptions(server.supportedAudioFormats);

  Future<void> rememberFormat(String codec) async {
    server.ytdlFormat = codec;
    _notify();
    await _persist();
  }

  /// After a 400 on `outputCodec` (spec §5): back to the default.
  Future<void> resetFormat() async {
    if (server.ytdlFormat == null) return;
    server.ytdlFormat = null;
    _notify();
    await _persist();
  }

  // ── account presets (read only, never written — spec §4) ────────────────

  /// The account's collection destination, only when it is the user's own
  /// (source 'user'): "Same as Discover".
  CollectionDestination? get discoverDestination => _discover;

  /// vpath → the library's admin path template ("Library layout").
  Map<String, String> get libraryTemplates => _templates;

  bool get presetsLoaded => _presetsLoaded;

  /// Once per session (again after a destination read that failed);
  /// best-effort.
  Future<void> loadPresets() {
    if (_presetsLoaded) return Future.value();
    return _loadingPresets ??=
        _loadPresets().whenComplete(() => _loadingPresets = null);
  }

  Future<void> _loadPresets() async {
    var unread = false;
    DestinationView? view;
    if (server.discoveryPluginsAvailable == true) {
      try {
        view = await hub.destinationOf(server);
      } catch (_) {
        unread = true;
      }
    }
    if (_disposed) return;
    final d = view?.destination;
    final templates = <String, String>{
      for (final lib in view?.libraries ?? const <WritableLibrary>[])
        if ((lib.template ?? '').trim().isNotEmpty) lib.vpath: lib.template!,
    };
    if (templates.isEmpty) {
      try {
        final vpaths = (await hub.pathTemplatesOf(server))['vpaths'];
        if (vpaths is Map) {
          for (final e in vpaths.entries) {
            final t = e.value is Map ? (e.value as Map)['template'] : null;
            if (e.key is String && t is String && t.trim().isNotEmpty) {
              templates[e.key as String] = t;
            }
          }
        }
      } catch (_) {
        // No torrent templates either: no "Library layout".
      }
    }
    if (_disposed) return;
    _discover = d != null && d.source == 'user' ? d : null;
    _templates = Map.unmodifiable(templates);
    _presetsLoaded = !unread;
    _notify();
  }

  // ── drafts (in memory for the session — spec §6 "Leaving early") ────────

  YtdlDraft get screenDraft => _screenDraft ??= YtdlDraft(this);

  YtdlDraft folderDraft(String currentPath) =>
      _folderDrafts[currentPath] ??= YtdlDraft(this, folder: currentPath);

  /// The screen is showing (its draft is attached): what settles now has
  /// been seen.
  bool get _screenShowing => _screenDraft?.attached == true;

  // ── the version tier ────────────────────────────────────────────────────

  /// Once per session: `GET /discovery/downloads?limit=20` — 200 = full
  /// (and the first ADDED page), 404 = older, anything else leaves it
  /// unknown and is asked again next time.
  Future<void> probeTier() {
    if (_tier != YtdlServerTier.unknown) return Future.value();
    return _probing ??= _probe().whenComplete(() => _probing = null);
  }

  Future<void> _probe() async {
    try {
      final rows = await api.records(limit: kRecordPage);
      if (_disposed) return;
      if (rows == null) {
        _tier = YtdlServerTier.older;
      } else {
        _tier = YtdlServerTier.full;
        _records = rows;
        _canShowEarlier = rows.isNotEmpty;
      }
      _notify();
    } catch (_) {
      // Unknown still: the older rules, and the next ask probes again.
    }
  }

  Future<void> _knowTier() async {
    if (_tier == YtdlServerTier.unknown) await probeTier();
  }

  /// The screen opened: outcomes seen, the tier and ADDED read, the
  /// presets loaded, and one poll.
  Future<void> onScreenOpened() async {
    markSeen();
    await Future.wait([
      if (_tier == YtdlServerTier.unknown) probeTier() else refreshAdded(),
      loadPresets(),
      poll(),
    ]);
  }

  // ── ADDED ───────────────────────────────────────────────────────────────

  /// Read the record's first page again (6.30+; older servers list this
  /// phone's jobs and ask nothing).
  Future<void> refreshAdded() {
    if (_tier == YtdlServerTier.older) return Future.value();
    if (_tier == YtdlServerTier.unknown) return probeTier();
    return _refreshingAdded ??=
        _refreshAdded().whenComplete(() => _refreshingAdded = null);
  }

  Future<void> _refreshAdded() async {
    _addedLoading = true;
    _notify();
    try {
      final rows = await api.records(limit: kRecordPage);
      if (_disposed) return;
      if (rows == null) {
        _tier = YtdlServerTier.older;
      } else {
        _records = rows;
        _canShowEarlier = rows.isNotEmpty;
      }
    } catch (_) {
      // The list keeps what it had.
    } finally {
      _addedLoading = false;
      _notify();
    }
  }

  /// "Show earlier": the page before the oldest row shown.
  Future<void> showEarlier() async {
    if (!canShowEarlier || _addedLoading || _records.isEmpty) return;
    _addedLoading = true;
    _notify();
    try {
      final before = _records.map((r) => r.id).reduce(math.min);
      final rows = await api.records(limit: kRecordPage, before: before);
      if (_disposed) return;
      if (rows == null) {
        _tier = YtdlServerTier.older;
      } else if (rows.isEmpty) {
        _canShowEarlier = false;
      } else {
        final have = {for (final r in _records) r.id};
        _records = [..._records, ...rows.where((r) => !have.contains(r.id))];
      }
    } catch (_) {
      // Tap again.
    } finally {
      _addedLoading = false;
      _notify();
    }
  }

  // ── jobs (spec §6) ──────────────────────────────────────────────────────

  /// Add to library: a `starting` row at once, then the mkdir (when a
  /// folder is new or unknown), a wait for the tunnel, and the POST — sent
  /// once, never retried. Leaving never cancels it.
  Future<YtdlStartOutcome> start(YtdlStartRequest request) {
    final job = YtdlJob(
      id: _newId(),
      url: request.url,
      directory: request.directory,
      codec: request.codec,
      tags: Map.unmodifiable({
        for (final e in request.metadata.entries)
          if (kYtdlTagKeys.contains(e.key) && e.value.trim().isNotEmpty)
            e.key: e.value,
      }),
      title: request.title,
      cover: request.cover,
      predictedName: request.predictedName,
      createdAt: _now,
    );
    final origin = request.origin;
    if (origin != null) _origins[job.id] = origin;
    _jobs.insert(0, job);
    _prune();
    _changed();
    return _run(job, mkdir: request.mkdir, inline: request.inline);
  }

  int _seq = 0;
  String _newId() {
    final at = _now.microsecondsSinceEpoch.toRadixString(36);
    return 'yt-$at-${(++_seq).toRadixString(36)}';
  }

  /// "Not found on the server" → Add again: the same add, POSTed once more.
  Future<YtdlStartOutcome> addAgain(YtdlJob job) async {
    if (!_jobs.contains(job) || job.open || _busy.contains(job.id)) {
      return YtdlStartOutcome(job: job);
    }
    _busy.add(job.id);
    _restart(job);
    try {
      return await _run(job);
    } finally {
      _busy.remove(job.id);
      _notify();
    }
  }

  /// "Try again" (a failed row, a start failure) or "Change format and
  /// retry" (a name clash, with [codec]): a new add of the same song in
  /// place of [job]'s row. A start failure makes its folder again first
  /// (unless the account may not make folders) — it may have failed there.
  Future<YtdlStartOutcome> retry(YtdlJob job, {String? codec}) async {
    if (!_jobs.contains(job) || job.open) return YtdlStartOutcome(job: job);
    final c = codec ?? job.codec;
    final next = YtdlJob(
      id: _newId(),
      url: job.url,
      directory: job.directory,
      codec: c,
      tags: job.tags,
      title: job.title,
      cover: job.cover,
      predictedName: _renamed(job.predictedName, c),
      createdAt: _now,
    );
    final origin = _origins[job.id];
    if (origin != null) _origins[next.id] = origin;
    final i = _jobs.indexOf(job);
    _retire(job);
    _jobs.removeAt(i);
    _jobs.insert(0, next);
    _changed();
    final remake =
        job.state == YtdlJobState.startFailed && !_mayNotMkdir;
    _busy.add(next.id);
    try {
      return await _run(next, mkdir: remake ? job.directory : null);
    } finally {
      _busy.remove(next.id);
      _notify();
    }
  }

  /// The predicted name with another format's extension.
  static String _renamed(String name, String codec) {
    if (name.isEmpty) return name;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    return '$stem.${ytdlOutputExtension(codec)}';
  }

  /// "Hide from this list": an open job keeps being followed (the server
  /// keeps going); the row goes.
  void hide(YtdlJob job) {
    if (job.hidden) return;
    job.hidden = true;
    _changed();
  }

  /// Dismiss a row: a settled job goes; an open one is hidden.
  void dismiss(YtdlJob job) {
    if (job.open) return hide(job);
    if (!_jobs.remove(job)) return;
    _retire(job);
    _changed();
  }

  /// A start failure its surface shows itself (spec §6 failure routing):
  /// the row goes, nothing is toasted.
  void discardStartFailure(YtdlJob job) {
    if (!_jobs.remove(job)) return;
    _retire(job);
    _changed();
  }

  void _retire(YtdlJob job) {
    final pid = job.pid;
    if (pid != null) _retiredPids.add(pid);
    _sentAt.remove(job.id);
  }

  void _restart(YtdlJob job) {
    job
      ..state = YtdlJobState.starting
      ..pid = null
      ..serverStart = null
      ..endedAt = null
      ..seen = false
      ..problem = null
      ..problemDetail = null;
    _changed();
  }

  bool get _mayNotMkdir => server.noMkdir == true || _mkdirRefused;

  /// The account was refused a folder this session (a stale noMkdir):
  /// the screen offers the three choices as it does under noMkdir.
  bool get mkdirRefused => _mkdirRefused;

  /// One add's sends. [inline] decides a start failure's routing.
  Future<YtdlStartOutcome> _run(YtdlJob job,
      {String? mkdir, bool Function()? inline}) async {
    final api = this.api;
    if (mkdir != null) {
      try {
        await api.mkdir(mkdir);
      } catch (e) {
        final f = classifyYtdlMkdir(e);
        if (f.problem == YtdlProblem.mkdirOff) {
          _mkdirRefused = true;
          unawaited(_reping());
        }
        return _startFailed(job, f, inline);
      }
    }
    if (server.isIrohTransport && !await hub.awaitTunnel(server)) {
      return _startFailed(job, const YtdlFailure(YtdlProblem.offline), inline);
    }
    _sentAt[job.id] = _now;
    try {
      await api.add(
          directory: job.directory,
          url: job.url,
          codec: job.codec,
          metadata: job.tags);
    } catch (e) {
      if (_disposed) return YtdlStartOutcome(job: job);
      if (_wentOut(e)) {
        job.state = YtdlJobState.startUnsure;
        _changed();
        _schedule();
        return YtdlStartOutcome(timedOut: true, job: job);
      }
      final f = classifyYtdlAdd(e);
      switch (f.problem) {
        case YtdlProblem.uploadsOff:
        case YtdlProblem.ffmpegNotReady:
          unawaited(_reping());
        case YtdlProblem.badFormat:
          // The server turned the format off: its list is stale too.
          unawaited(resetFormat());
          unawaited(_reping());
        default:
          break;
      }
      return _startFailed(job, f, inline);
    }
    if (_disposed) return YtdlStartOutcome(ok: true, job: job);
    job.state = YtdlJobState.adding;
    _changed();
    // The entry claims on the first poll after the 200.
    unawaited(poll());
    return YtdlStartOutcome(ok: true, job: job);
  }

  Future<void> _reping() async {
    try {
      await hub.reping(server);
    } catch (_) {}
  }

  /// A POST with no answer that may have reached the server: a timeout,
  /// or a connection lost mid-flight. One the phone could not even open
  /// (no route, refused, no such host) never left it — that is offline.
  static bool _wentOut(Object e) {
    if (e is! YtdlApiException || e.status != 0) return false;
    if (e.timedOut) return true;
    final cause = e.cause;
    if (cause is SocketException) {
      final words = '$cause';
      return !_neverConnected.any(words.contains);
    }
    return true;
  }

  static const List<String> _neverConnected = [
    'Failed host lookup',
    'Connection refused',
    'Network is unreachable',
    'No route to host',
  ];

  /// A start that failed before the server took it: its surface's to show
  /// when [inline] says so, else a "Couldn't add" row and toast. A lost
  /// library's name comes from the folder when the server's words lack it.
  YtdlStartOutcome _startFailed(
      YtdlJob job, YtdlFailure failure, bool Function()? inline) {
    final f = failure.problem == YtdlProblem.libraryGone &&
            failure.detail == null
        ? YtdlFailure(YtdlProblem.libraryGone, _libraryOf(job.directory))
        : failure;
    if (_disposed) return YtdlStartOutcome(failure: f, job: job);
    if (inline?.call() == true) {
      discardStartFailure(job);
      return YtdlStartOutcome(failure: f, job: job);
    }
    job
      ..problem = f.problem.name
      ..problemDetail = f.detail;
    _settle(job, YtdlJobState.startFailed);
    return YtdlStartOutcome(failure: f, job: job);
  }

  static String? _libraryOf(String directory) {
    final crumbs = pathCrumbs(directory);
    return crumbs.isEmpty ? null : crumbs.first;
  }

  /// "Not sure it started" → Check again: the server's job list, the
  /// download record (6.30+) and the folder, for this link and folder.
  /// Found → ADDING or ADDED; else "Not found on the server".
  Future<void> checkAgain(YtdlJob job) async {
    if (!_jobs.contains(job) || job.open || _busy.contains(job.id)) return;
    _busy.add(job.id);
    _notify();
    try {
      final List<YtdlServerJob> entries;
      try {
        entries = await api.jobs();
      } catch (_) {
        return;
      }
      if (_disposed || !_jobs.contains(job)) return;
      final entry = _unclaimedFor(job, entries, _claimedPids());
      if (entry != null) {
        job
          ..state = YtdlJobState.adding
          ..endedAt = null;
        _claim(job, entry);
        _changed();
        await _follow(job, entry);
        _schedule();
        return;
      }
      await _knowTier();
      if (_tier == YtdlServerTier.full) {
        YtdlRecord? r;
        try {
          r = await _findRecord(job);
        } catch (_) {}
        if (r != null) {
          _settle(job, YtdlJobState.added, record: r);
          return;
        }
      }
      final present = await _nameInFolder(job) == true;
      if (_disposed || !_jobs.contains(job)) return;
      _settle(job, present ? YtdlJobState.added : YtdlJobState.notFound);
    } finally {
      _busy.remove(job.id);
      _notify();
    }
  }

  // ── polling ─────────────────────────────────────────────────────────────

  bool get _needsPoll => _jobs.any((j) =>
      j.state == YtdlJobState.adding || j.state == YtdlJobState.startUnsure);

  /// The next poll is scheduled (tests).
  @visibleForTesting
  bool get pollScheduled => _poll != null;

  void _schedule() {
    _poll?.cancel();
    _poll = null;
    if (_disposed || !hub.foreground || !_needsPoll) return;
    _poll = hub.timer(kPollBeat, () {
      _poll = null;
      unawaited(poll());
    });
  }

  /// Read `GET /ytdl/downloads` once and move every open job by it. One at
  /// a time: a poll already out is joined.
  Future<void> poll() {
    if (_disposed) return Future.value();
    return _polling ??= _pollOnce().whenComplete(() {
      _polling = null;
      _schedule();
    });
  }

  Future<void> _pollOnce() async {
    if (!_needsPoll) return;
    final List<YtdlServerJob> entries;
    try {
      entries = await api.jobs();
    } catch (e) {
      if (_disposed) return;
      final offline = e is YtdlApiException && e.status == 0;
      if (offline != _offline) {
        _offline = offline;
        _notify();
      }
      return;
    }
    if (_disposed) return;
    if (_offline) {
      _offline = false;
      _notify();
    }
    final claimed = _claimedPids();
    // Claimed jobs follow their pid; a pid gone is a job that ended unseen.
    for (final job in [..._jobs]) {
      final pid = job.pid;
      if (!_polled(job) || pid == null) continue;
      final entry = entries
          .where((e) =>
              e.pid == pid && e.url == job.url && e.directory == job.directory)
          .firstOrNull;
      if (entry == null) {
        await _vanished(job);
      } else {
        await _follow(job, entry);
      }
      if (_disposed) return;
    }
    // Unclaimed ones, newest first, take the newest entry for their link
    // and folder that no other job holds.
    for (final job in [..._jobs]) {
      if (!_polled(job) || job.pid != null) continue;
      final entry = _unclaimedFor(job, entries, claimed);
      if (entry != null) {
        claimed.add(entry.pid);
        _claim(job, entry);
        job.state = YtdlJobState.adding;
        _changed();
        await _follow(job, entry);
      } else if (_now.difference(_sentAt[job.id] ?? job.createdAt) >
          kClaimWindow) {
        if (job.state == YtdlJobState.startUnsure) {
          _settle(job, YtdlJobState.notSureStarted);
        } else {
          // Taken (200) but never seen in the list: it ended unseen.
          await _vanished(job);
        }
      }
      if (_disposed) return;
    }
  }

  bool _polled(YtdlJob job) =>
      _jobs.contains(job) &&
      (job.state == YtdlJobState.adding ||
          job.state == YtdlJobState.startUnsure);

  Set<int> _claimedPids() => {
        ..._retiredPids,
        for (final j in _jobs) ?j.pid,
      };

  /// The newest entry for [job]'s link and folder that no job holds.
  static YtdlServerJob? _unclaimedFor(
      YtdlJob job, List<YtdlServerJob> entries, Set<int> claimed) {
    YtdlServerJob? best;
    for (final e in entries) {
      if (e.url != job.url || e.directory != job.directory) continue;
      if (claimed.contains(e.pid)) continue;
      if (best == null || e.startTime > best.startTime) best = e;
    }
    return best;
  }

  void _claim(YtdlJob job, YtdlServerJob entry) {
    job
      ..pid = entry.pid
      ..serverStart = entry.startTime;
  }

  /// A claimed entry's status moves its job: complete → added, error →
  /// a failure; downloading (or a status this build does not know) →
  /// still adding.
  Future<void> _follow(YtdlJob job, YtdlServerJob entry) async {
    if (entry.complete) {
      await _knowTier();
      YtdlRecord? record;
      if (_tier == YtdlServerTier.full) {
        try {
          record = await _findRecord(job);
        } catch (_) {
          // No record to name the file: still added, crumbs from the folder.
        }
      }
      if (_jobs.contains(job) && job.open) {
        _settle(job, YtdlJobState.added, record: record);
      }
    } else if (entry.failed) {
      await _knowTier();
      final present = await _nameInFolder(job);
      if (!_jobs.contains(job) || !job.open) return;
      // Only 6.30+ refuses a name clash; an older server re-tags instead.
      _settle(
          job,
          present == true && _tier == YtdlServerTier.full
              ? YtdlJobState.failedClash
              : YtdlJobState.failed);
    }
  }

  /// A job whose entry is gone without this phone seeing it end (away past
  /// the tracker's 30 s, a restart, or never seen at all): the download
  /// record (6.30+) or the folder (older) says added; else "Not sure it
  /// finished". A lookup that fails leaves it for the next poll.
  Future<void> _vanished(YtdlJob job) async {
    await _knowTier();
    if (_tier == YtdlServerTier.full) {
      final YtdlRecord? r;
      try {
        r = await _findRecord(job);
      } catch (_) {
        return;
      }
      // The record route may have just said this is an older server.
      if (_tier == YtdlServerTier.full) {
        if (!_jobs.contains(job) || !job.open) return;
        _settle(
            job, r != null ? YtdlJobState.added : YtdlJobState.notSureFinished,
            record: r);
        return;
      }
    }
    final present = await _nameInFolder(job);
    if (present == null || !_jobs.contains(job) || !job.open) return;
    _settle(job, present ? YtdlJobState.added : YtdlJobState.notSureFinished);
  }

  /// [job]'s download record: the newest row with its link as `origin` in
  /// its folder (compared without slashes, ignoring case — the record keeps
  /// the on-disk case) that no other job holds. Paged back until a row is
  /// older than the claimed entry's start (both the server's clock), at
  /// most [kRecordPages] pages. Null when there is none, or the route is
  /// missing (the tier turns older). Throws when the record cannot be read.
  Future<YtdlRecord?> _findRecord(YtdlJob job) async {
    final taken = {
      for (final j in _jobs)
        if (!identical(j, job)) ?j.recordId,
    };
    final folder = _bare(job.directory).toLowerCase();
    final start = job.serverStart;
    int? before;
    for (var page = 0; page < kRecordPages; page++) {
      final rows = await api.records(limit: kRecordPage, before: before);
      if (rows == null) {
        _tier = YtdlServerTier.older;
        _notify();
        return null;
      }
      if (rows.isEmpty) return null;
      for (final r in rows) {
        if (taken.contains(r.id) || r.origin != job.url) continue;
        if (_folderOf(r.filepath).toLowerCase() == folder) return r;
      }
      if (start != null && rows.any((r) => r.downloadedAt < start)) {
        return null;
      }
      before = rows.map((r) => r.id).reduce(math.min);
    }
    return null;
  }

  /// Whether [job]'s predicted file is in its folder (ignoring case); null
  /// when the folder did not list.
  Future<bool?> _nameInFolder(YtdlJob job) async {
    final name = job.predictedName.toLowerCase();
    try {
      final listing = await api.list(job.directory);
      return name.isNotEmpty &&
          listing.files.any((f) => f.toLowerCase() == name);
    } catch (_) {
      return null;
    }
  }

  /// [job] reached [state]: kept, toasted, told on [settled].
  void _settle(YtdlJob job, YtdlJobState state, {YtdlRecord? record}) {
    if (_disposed) return;
    job
      ..state = state
      ..endedAt = _now
      ..seen = _screenShowing;
    if (record != null) {
      job
        ..filepath = record.filepath
        ..bytes = record.bytes
        ..trackId = record.trackId
        ..recordId = record.id;
    }
    _changed();
    _toastFor(job);
    _settledOut.add(job);
    if (state == YtdlJobState.added && _tier == YtdlServerTier.full) {
      unawaited(refreshAdded());
    }
    _schedule();
  }

  /// "Added “One More Time” to Daft Punk › Discovery" or "Couldn't add
  /// “…”". The "not sure" states say nothing: their rows ask for a look.
  void _toastFor(YtdlJob job) {
    final l = hub.l10n();
    if (l == null) return;
    final title = job.title.isEmpty ? job.url : job.title;
    switch (job.state) {
      case YtdlJobState.added:
        hub.showToast(l.ytdlToastAdded(title, _toastPath(job.directory)),
            success: true);
      case YtdlJobState.failed:
      case YtdlJobState.failedClash:
      case YtdlJobState.startFailed:
        hub.showToast(l.ytdlCouldntAdd(title));
      default:
        break;
    }
  }

  /// The folders below the library (the library itself for its top
  /// folder), cut at the start past two (spec §9): "… › Daft Punk ›
  /// Homework".
  static String _toastPath(String directory) {
    final crumbs = pathCrumbs(directory);
    if (crumbs.isEmpty) return '';
    final below = crumbs.sublist(1);
    if (below.length > 2) {
      return '…$kYtdlCrumbSep${ytdlPathText(below.sublist(below.length - 2))}';
    }
    return ytdlToastPath(crumbs.first, below);
  }

  // ── loading and keeping ─────────────────────────────────────────────────

  /// The jobs [server] persisted. One that was mid-POST when the app went
  /// may have reached the server: it is looked for as a timed-out one.
  void _load() {
    for (final raw in server.ytdlJobs) {
      final job = YtdlJob.tryFromJson(raw);
      if (job == null || _jobs.any((j) => j.id == job.id)) continue;
      if (job.state == YtdlJobState.starting) {
        job.state = YtdlJobState.startUnsure;
      }
      _jobs.add(job);
    }
    _jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _prune();
    if (_needsPoll && hub.foreground) unawaited(poll());
  }

  /// Failed rows go after 7 days; at most [kKeepJobs] stay, the oldest
  /// settled ones dropped first. Open jobs always stay.
  void _prune() {
    _jobs.removeWhere((j) => !j.open && _needsLook(j.state) && !_fresh(j));
    var extra = _jobs.length - kKeepJobs;
    for (var i = _jobs.length - 1; i >= 0 && extra > 0; i--) {
      if (_jobs[i].open) continue;
      _retire(_jobs.removeAt(i));
      extra--;
    }
  }

  /// A job changed: persisted and told.
  void _changed() {
    if (_disposed) return;
    unawaited(_persist());
    _notify();
  }

  Future<void> _persist() async {
    server.ytdlJobs = [for (final j in _jobs) j.toJson()];
    try {
      await hub.persist(server);
    } catch (_) {}
  }

  void _foregroundChanged(bool fg) {
    if (!fg) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (_needsPoll) unawaited(poll());
    _screenDraft?.resumed();
    for (final d in _folderDrafts.values) {
      d.resumed();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    _poll?.cancel();
    _poll = null;
    _screenDraft?.dispose();
    for (final d in _folderDrafts.values) {
      d.dispose();
    }
    _folderDrafts.clear();
    unawaited(_settledOut.close());
    dispose();
  }
}

/// '/Music/Daft Punk/' → 'Music/Daft Punk'.
String _bare(String directory) =>
    directory.replaceAll(RegExp(r'^/+|/+$'), '');

/// 'Music/Daft Punk/One_More_Time.mp3' → 'Music/Daft Punk'.
String _folderOf(String filepath) {
  final bare = _bare(filepath);
  final slash = bare.lastIndexOf('/');
  return slash < 0 ? '' : bare.substring(0, slash);
}

/// [path] ending in one '/'.
String _slashed(String path) => path.endsWith('/') ? path : '$path/';
