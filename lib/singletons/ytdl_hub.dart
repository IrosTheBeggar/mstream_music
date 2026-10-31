import 'dart:async';

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

  /// Failures in NEEDS A LOOK — failed, a name clash, a start refused —
  /// the screen has not shown yet. A "not sure" row is a guess, not a
  /// failure (spec §1), and is not counted.
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
  /// one). For one of this phone's jobs with no record, the predicted name
  /// as the folder listed it. Null when the phone cannot name the file (no
  /// tap-to-play then).
  final String? filepath;
  final int? recordId;

  /// The video's thumbnail URL from this phone's lookup: its jobs, and
  /// the records they answer (the server's record has none of its own).
  final String? cover;

  /// The library's track id (the record's, or the job's from it): album
  /// art for the row's 48 px cover.
  final int? trackId;

  const YtdlAddedRow({
    required this.title,
    required this.directory,
    this.ext,
    this.bytes,
    this.when,
    this.present = true,
    this.filepath,
    this.recordId,
    this.cover,
    this.trackId,
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

  /// The folder "Couldn't make the folder “…”" names when [mkdir] fails:
  /// the first new one. Null = [mkdir]'s last folder.
  final String? mkdirFolder;

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
    this.mkdirFolder,
    this.origin,
    this.inline,
  });
}

/// What a start, an Add again or a retry came to. [ok]: the server took
/// it (200). [timedOut]: the POST went out and no answer came — the job is
/// `startUnsure` and the hub looks for it. Otherwise [failure] says why
/// nothing started; a folder that could not be made reads
/// [YtdlProblem.mkdirFailed] with the folder's name (a 403 there is
/// [YtdlProblem.mkdirOff]).
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

  /// The file names the File Explorer shows for [directory] on [server]
  /// right now — a listing already loaded, which the explorer sheet's name
  /// check reads when the folder won't list again (spec §7) — or null when
  /// it isn't showing that folder.
  List<String>? Function(Server server, String directory) explorerFiles =
      _defaultExplorerFiles;

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

  /// The top frame's file rows when it is [directory] on [server] (a
  /// frame's rows carry its server; an empty folder's, the current one).
  static List<String>? _defaultExplorerFiles(Server server, String directory) {
    final bm = BrowserManager();
    final path = bm.currentPath;
    if (path == null ||
        bm.browserCache.isEmpty ||
        _bare(path).toLowerCase() != _bare(directory).toLowerCase()) {
      return null;
    }
    final rows = bm.browserCache.last;
    final shownOn = (rows.isNotEmpty ? rows.first.server : null) ??
        ServerManager().currentServer;
    if (shownOn == null ||
        !identical(ownServerOf(shownOn) ?? shownOn, server)) {
      return null;
    }
    return [
      for (final r in rows)
        if (r.type == 'file') r.name,
    ];
  }

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
    explorerFiles = _defaultExplorerFiles;
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

  /// The device has a usable network again (main.dart's connectivity
  /// listener): rows "Waiting for connection" poll at once, and a lookup
  /// that found no connection runs again — "the lookup runs when you're
  /// back" (spec §8 Offline) also while the screen stays in front.
  void connectivityRestored() {
    if (!_foreground) return;
    for (final s in _states.values) {
      s._foregroundChanged(true);
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

  /// The download record is paged at most this deep for one job (and for
  /// one read of ADDED that finds no ytdl row).
  static const int kRecordPages = 5;
  static const int kRecordPage = 20;

  /// How long an add waits, before its POST, for the record's newest id
  /// ([YtdlJob.recordFloor]); past it the last one read stands in.
  static const Duration kFloorWait = Duration(seconds: 5);

  /// A version probe that got no answer is asked again this long after,
  /// while a screen or sheet shows (once per failure).
  static const Duration kReprobeAfter = Duration(seconds: 3);

  final List<YtdlJob> _jobs = [];
  final Map<String, DateTime> _sentAt = {};
  final Map<String, String> _origins = {};
  final Set<String> _busy = {};

  /// Jobs whose entry read `error` while the folder (or the tier) could not
  /// say whether it was a name clash: asked again each poll, and settled
  /// failed once the entry is gone (this session only).
  final Set<String> _sawError = {};

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

  /// The smallest record id ADDED has read past (any plug-in): "Show
  /// earlier" asks before it.
  int? _addedCursor;

  /// The newest record id (any plug-in) a first page showed; 0 = the
  /// record was empty, null = never read.
  int? _newestRecordId;

  CollectionDestination? _discover;
  Map<String, String> _templates = const {};
  bool _presetsLoaded = false;
  Future<void>? _loadingPresets;

  YtdlDraft? _screenDraft;
  final Map<String, YtdlDraft> _folderDrafts = {};

  Timer? _poll;
  Timer? _reprobe;
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

  /// [YtdlHub.entryAllowed] for this server as its flags stand now. A
  /// re-ping after a 403 or "FFmpeg is not available yet" can turn it off
  /// (this state notifies when a re-ping lands): the home card and the
  /// explorer item hide, while an open screen or folder sheet stays — its
  /// Add goes or is disabled, its lookup still works (spec §8 "Audio
  /// conversion not ready", "Uploads off").
  bool get entryAllowed => YtdlHub.entryAllowed(server);

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

  /// A failure the explorer strip names ("Couldn't add …") and the home
  /// card counts ("{n} failed").
  static bool _failure(YtdlJobState s) =>
      s == YtdlJobState.failed ||
      s == YtdlJobState.failedClash ||
      s == YtdlJobState.startFailed;

  bool _fresh(YtdlJob j) =>
      _now.difference(j.endedAt ?? j.createdAt) <= kKeepFailed;

  /// ADDED: on 6.30+ the account's download record (paged) with any of
  /// this phone's finished jobs no record answered for; on older servers
  /// (and until the tier is known) this phone's finished jobs. A job that
  /// settled before its record could be read takes it once a page holds it
  /// ([_attribute]), and a job whose record is loaded — or that names the
  /// same file as a loaded record — is left to the record's row: one row
  /// per song. A record newer than what is loaded (the refresh after the
  /// job's settle still out, or failed) is not there yet: the job's own row
  /// stands in for it until it is. One older than the loaded pages comes
  /// with "Show earlier": the job waits for it rather than standing out of
  /// order above it. A record's row takes the cover of the job it answers
  /// (by id, or the same file): the video's thumbnail where the library
  /// has no art for the song.
  List<YtdlAddedRow> get added {
    final full = _tier == YtdlServerTier.full;
    final loaded = full ? {for (final r in _records) r.id} : const <int>{};
    final recorded = full
        ? {
            for (final r in _records)
              if (r.filepath.isNotEmpty) r.filepath.toLowerCase()
          }
        : const <String>{};
    final cursor = _canShowEarlier ? _addedCursor : null;
    bool recordShows(YtdlJob j) {
      final id = j.recordId;
      if (id != null &&
          (loaded.contains(id) || (cursor != null && id < cursor))) {
        return true;
      }
      return recorded.contains(j.filepath?.toLowerCase());
    }

    final mine = [
      for (final j in _jobs)
        if (j.state == YtdlJobState.added && (!full || !recordShows(j)))
          _rowOfJob(j),
    ];
    if (!full) return mine;
    final coverById = <int, String>{};
    final coverByFile = <String, String>{};
    for (final j in _jobs) {
      final cover = j.cover;
      if (j.state != YtdlJobState.added || cover == null || cover.isEmpty) {
        continue;
      }
      final id = j.recordId;
      if (id != null) coverById[id] = cover;
      final file = j.filepath;
      if (file != null) coverByFile[file.toLowerCase()] = cover;
    }
    final rows = [
      ...mine,
      for (final r in _records)
        _rowOfRecord(r,
            cover: coverById[r.id] ?? coverByFile[r.filepath.toLowerCase()]),
    ];
    rows.sort((a, b) => (b.when?.millisecondsSinceEpoch ?? 0)
        .compareTo(a.when?.millisecondsSinceEpoch ?? 0));
    return rows;
  }

  /// ADDED is being read: the tier's probe (its first page), a refresh, or
  /// Show earlier.
  bool get addedLoading => _addedLoading;

  /// "Show earlier" has more to ask for: a page counts every plug-in's
  /// rows, so only an empty page, or one shorter than asked for, is the
  /// end.
  bool get canShowEarlier => _tier == YtdlServerTier.full && _canShowEarlier;

  static YtdlAddedRow _rowOfRecord(YtdlRecord r, {String? cover}) {
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
      cover: cover,
      trackId: r.trackId,
    );
  }

  /// [j]'s file only as its record or its folder's listing named it — a
  /// predicted name the folder never showed is no file to play.
  static YtdlAddedRow _rowOfJob(YtdlJob j) {
    final named = j.filepath;
    return YtdlAddedRow(
      title: j.title,
      directory: j.directory,
      ext: named == null ? ytdlOutputExtension(j.codec) : _extOf(named),
      bytes: j.bytes,
      when: j.endedAt,
      filepath: named,
      recordId: j.recordId,
      cover: j.cover,
      trackId: j.trackId,
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
      if (_failure(j.state) && _fresh(j)) failed++;
      if (_addedNews(j, now)) done++;
    }
    return YtdlHomeSummary(adding: adding.length, failed: failed, added: done);
  }

  /// [j] counts in the home's "Added {n}" at [now].
  static bool _addedNews(YtdlJob j, DateTime now) {
    final ended = j.endedAt;
    return !j.hidden &&
        !j.seen &&
        j.state == YtdlJobState.added &&
        ended != null &&
        now.difference(ended) <= kAddedNews;
  }

  /// When the home's "Added {n}" next drops by itself — the first counted
  /// song's hour runs out — with no change to notify of; null when it
  /// counts nothing. A card showing it redraws then.
  DateTime? get addedNewsEnds {
    final now = _now;
    DateTime? first;
    for (final j in _jobs) {
      if (!_addedNews(j, now)) continue;
      final ended = j.endedAt!;
      if (first == null || ended.isBefore(first)) first = ended;
    }
    return first?.add(kAddedNews);
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

  /// The screen or any explorer sheet is showing.
  bool get _surfaceShowing =>
      _screenShowing || _folderDrafts.values.any((d) => d.attached);

  void _reprobeSoon() {
    if (_reprobe != null || _disposed || !_surfaceShowing) return;
    _reprobe = hub.timer(kReprobeAfter, () {
      _reprobe = null;
      if (!_disposed) unawaited(probeTier());
    });
  }

  /// [job] is the screen card's own add, still waiting on its POST: the
  /// card shows "Starting…" and collapses into its ADDING row only on 200
  /// (spec §6), so the screen's lists leave the row out until then.
  bool onCard(YtdlJob job) =>
      job.state == YtdlJobState.starting &&
      _origins[job.id] == 'screen' &&
      _screenShowing &&
      _screenDraft!.addPhase == YtdlAddPhase.starting;

  // ── the version tier ────────────────────────────────────────────────────

  /// Once per session: `GET /discovery/downloads?limit=20` — 200 = full
  /// (and the first ADDED page), 404 = older, anything else leaves it
  /// unknown and is asked again next time.
  Future<void> probeTier() {
    if (_tier != YtdlServerTier.unknown) return Future.value();
    return _probing ??= _probe().whenComplete(() => _probing = null);
  }

  /// The probe is ADDED's first read: [addedLoading] while it runs, so the
  /// screen draws no empty state before the rows land. Set without a
  /// notification — the probe may start in a screen's initState, mid-build —
  /// and cleared with one once it answers either way.
  Future<void> _probe() async {
    _addedLoading = true;
    try {
      final read = await _readAdded();
      if (_disposed) return;
      if (read == null) {
        _tier = YtdlServerTier.older;
      } else {
        _tier = YtdlServerTier.full;
        _records = read.rows;
        _addedCursor = read.cursor;
        _canShowEarlier = !read.end;
        _attribute();
      }
    } catch (_) {
      // Unknown still: the older rules until it answers. One lost answer
      // shouldn't hold them for a whole visit, so while a screen or sheet
      // shows, ask again shortly.
      _reprobeSoon();
    } finally {
      _addedLoading = false;
      _notify();
    }
  }

  /// One read of ADDED, newest first from [before] (null = the newest):
  /// pages until one holds a ytdl row or the record ends, at most
  /// [kRecordPages] — a page counts every plug-in's rows, so a page of
  /// Discover downloads holds none and is not the end. [cursor] is the
  /// smallest id read (the next `before`); [end]: the last page came back
  /// empty or shorter than asked for (its rows are in [rows]). Null on a
  /// server before 6.30; throws when the record can't be read.
  Future<({List<YtdlRecord> rows, int? cursor, bool end})?> _readAdded(
      {int? before}) async {
    final rows = <YtdlRecord>[];
    var cursor = before;
    for (var i = 0; i < kRecordPages; i++) {
      final page = await api.recordsPage(limit: kRecordPage, before: cursor);
      if (page == null) return null;
      if (cursor == null) _noteNewest(page.newestId ?? 0);
      rows.addAll(page.rows);
      cursor = page.oldestId ?? cursor;
      if (page.end) return (rows: rows, cursor: cursor, end: true);
      if (rows.isNotEmpty) break;
    }
    return (rows: rows, cursor: cursor, end: false);
  }

  void _noteNewest(int id) {
    final had = _newestRecordId;
    if (had == null || id > had) _newestRecordId = id;
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

  /// The newest rows replace the top of the list; pages "Show earlier"
  /// already brought stay below them.
  Future<void> _refreshAdded() async {
    _addedLoading = true;
    _notify();
    try {
      final read = await _readAdded();
      if (_disposed) return;
      if (read == null) {
        _tier = YtdlServerTier.older;
      } else {
        final cut = read.cursor;
        final older = _addedCursor;
        if (!read.end && cut != null && older != null && older < cut) {
          final fresh = {for (final r in read.rows) r.id};
          _records = [
            ...read.rows,
            for (final r in _records)
              if (r.id < cut && !fresh.contains(r.id)) r,
          ];
        } else {
          _records = read.rows;
          _addedCursor = cut;
          _canShowEarlier = !read.end;
        }
        _attribute();
      }
    } catch (_) {
      // The list keeps what it had.
    } finally {
      _addedLoading = false;
      _notify();
    }
  }

  /// "Show earlier": the rows before the oldest one read (paging past
  /// pages that hold only other plug-ins' rows); an empty or short page
  /// ends it.
  Future<void> showEarlier() async {
    final before = _addedCursor;
    if (!canShowEarlier || _addedLoading || before == null) return;
    _addedLoading = true;
    _notify();
    try {
      final read = await _readAdded(before: before);
      if (_disposed) return;
      if (read == null) {
        _tier = YtdlServerTier.older;
      } else {
        final have = {for (final r in _records) r.id};
        _records = [
          ..._records,
          ...read.rows.where((r) => !have.contains(r.id)),
        ];
        _addedCursor = read.cursor ?? before;
        if (read.end) _canShowEarlier = false;
        _attribute();
      }
    } catch (_) {
      // Tap again.
    } finally {
      _addedLoading = false;
      _notify();
    }
  }

  /// Added jobs that settled before their record could be read (a read
  /// that failed, the tier not known yet) take it once a loaded page holds
  /// it — by [_answers], bounded by the job's start, a record answering for
  /// one job only — so ADDED shows the song once and a later add can't
  /// take it.
  void _attribute() {
    final taken = {for (final j in _jobs) ?j.recordId};
    var changed = false;
    for (final j in _jobs) {
      if (j.state != YtdlJobState.added || j.recordId != null) continue;
      final r = _records
          .where((r) => !taken.contains(r.id) && _answers(j, r, bounded: true))
          .firstOrNull;
      if (r == null) continue;
      _takeRecord(j, r);
      taken.add(r.id);
      changed = true;
    }
    if (changed) _changed();
  }

  static void _takeRecord(YtdlJob job, YtdlRecord record) {
    job
      ..filepath = record.filepath
      ..bytes = record.bytes
      ..trackId = record.trackId
      ..recordId = record.id;
  }

  /// [r] is [job]'s download record: its link as `origin`, in its folder
  /// (compared without slashes, ignoring case — the record keeps the
  /// on-disk case), and not older than the job — written at or after the
  /// claimed entry's start ([YtdlJob.serverStart], both the server's
  /// clock) and newer than the record's newest row before the POST
  /// ([YtdlJob.recordFloor]). With neither bound known (a job saved by an
  /// older build, a floor that could not be read) any match counts, as the
  /// folder's predicted name does — unless [bounded].
  static bool _answers(YtdlJob job, YtdlRecord r, {bool bounded = false}) {
    if (r.origin != job.url) return false;
    if (_folderOf(r.filepath).toLowerCase() !=
        _bare(job.directory).toLowerCase()) {
      return false;
    }
    final start = job.serverStart;
    final floor = job.recordFloor;
    if (start != null && r.downloadedAt < start) return false;
    if (floor != null && r.id <= floor) return false;
    return !bounded || start != null || floor != null;
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
      mkdir: request.mkdir,
      createdAt: _now,
    );
    final origin = request.origin;
    if (origin != null) _origins[job.id] = origin;
    _jobs.insert(0, job);
    _prune();
    _changed();
    return _run(job,
        mkdir: request.mkdir,
        mkdirFolder: request.mkdirFolder,
        inline: request.inline);
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
  /// place of [job]'s row. A start failure whose add made a folder makes it
  /// again first (unless the account may not make folders) — it may have
  /// failed there; one that never needed a folder never asks for one.
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
      mkdir: job.mkdir,
      createdAt: _now,
    );
    final origin = _origins[job.id];
    if (origin != null) _origins[next.id] = origin;
    final i = _jobs.indexOf(job);
    _retire(job);
    _jobs.removeAt(i);
    _jobs.insert(0, next);
    _changed();
    final remake = job.state == YtdlJobState.startFailed &&
        job.mkdir != null &&
        !_mayNotMkdir;
    _busy.add(next.id);
    try {
      return await _run(next,
          mkdir: remake ? job.mkdir : null,
          mkdirFolder: job.problem == YtdlProblem.mkdirFailed.name
              ? job.problemDetail
              : null);
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
    _sawError.remove(job.id);
  }

  void _restart(YtdlJob job) {
    job
      ..state = YtdlJobState.starting
      ..pid = null
      ..serverStart = null
      ..recordFloor = null
      ..endedAt = null
      ..seen = false
      ..problem = null
      ..problemDetail = null;
    _sawError.remove(job.id);
    _changed();
  }

  bool get _mayNotMkdir => server.noMkdir == true || _mkdirRefused;

  /// The account was refused a folder this session (a stale noMkdir):
  /// the screen offers the three choices as it does under noMkdir.
  bool get mkdirRefused => _mkdirRefused;

  /// One add's sends. [inline] decides a start failure's routing.
  ///
  /// On 6.30+ the record's newest id is read alongside the mkdir and kept
  /// as [YtdlJob.recordFloor] before the POST, so no record older than this
  /// add can ever settle it (bounded by [kFloorWait]; the last id read
  /// stands in when it can't be had).
  Future<YtdlStartOutcome> _run(YtdlJob job,
      {String? mkdir, String? mkdirFolder, bool Function()? inline}) async {
    final api = this.api;
    final floor =
        _tier == YtdlServerTier.older ? null : _readFloor(api);
    if (mkdir != null) {
      try {
        await api.mkdir(mkdir);
      } catch (e) {
        var f = classifyYtdlMkdir(e);
        switch (f.problem) {
          case YtdlProblem.mkdirOff:
            _mkdirRefused = true;
            unawaited(_reping());
          case YtdlProblem.offline:
          case YtdlProblem.libraryGone:
            break;
          default:
            // Spec §8 "mkdir failed": the folder is named, not the status.
            f = YtdlFailure(YtdlProblem.mkdirFailed,
                mkdirFolder ?? _lastFolder(mkdir));
        }
        return _startFailed(job, f, inline);
      }
    }
    if (server.isIrohTransport && !await hub.awaitTunnel(server)) {
      return _startFailed(job, const YtdlFailure(YtdlProblem.offline), inline);
    }
    if (floor != null) {
      job.recordFloor =
          await _bounded<int?>(floor, kFloorWait) ?? _newestRecordId;
    }
    if (_disposed) return YtdlStartOutcome(job: job);
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

  /// The re-ping's flags reach every listener: a draft's Add block, the
  /// format list, [entryAllowed].
  Future<void> _reping() async {
    try {
      await hub.reping(server);
    } catch (_) {}
    _notify();
  }

  /// The record's newest id now (any plug-in): one row asked for, or the
  /// tier's probe when it is not known yet. Null when it can't be read or
  /// the server has no record.
  Future<int?> _readFloor(YtdlApi api) async {
    try {
      if (_tier == YtdlServerTier.unknown) {
        await probeTier();
        return _tier == YtdlServerTier.full ? _newestRecordId : null;
      }
      if (_tier != YtdlServerTier.full) return null;
      final page = await api.recordsPage(limit: 1);
      if (page == null) return null;
      final id = page.newestId ?? 0;
      _noteNewest(id);
      return id;
    } catch (_) {
      return null;
    }
  }

  /// [future]'s value, or null when it fails or takes longer than [limit]
  /// (on the hub's timer).
  Future<T?> _bounded<T>(Future<T> future, Duration limit) {
    final done = Completer<T?>();
    final t = hub.timer(limit, () {
      if (!done.isCompleted) done.complete(null);
    });
    future.then((v) {
      t.cancel();
      if (!done.isCompleted) done.complete(v);
    }, onError: (Object _) {
      t.cancel();
      if (!done.isCompleted) done.complete(null);
    });
    return done.future;
  }

  static String _lastFolder(String directory) {
    final crumbs = pathCrumbs(directory);
    return crumbs.isEmpty ? '' : crumbs.last;
  }

  /// A POST with no answer that may have reached the server: a timeout,
  /// or a connection lost mid-flight. One the phone could not even open
  /// (no route, refused, no such host) never left it — that is offline.
  static bool _wentOut(Object e) {
    if (e is! YtdlApiException || e.status != 0) return false;
    if (e.timedOut) return true;
    return !ytdlNeverConnected(e);
  }

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
  /// Found → ADDING or ADDED; "Not found on the server" (and its Add
  /// again) only once every one of them answered — a list, record or
  /// folder that could not be read leaves the row as it was, to check
  /// again.
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
      if (_gone(job)) return;
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
      if (_gone(job)) return;
      var unread = _tier == YtdlServerTier.unknown;
      if (_tier == YtdlServerTier.full) {
        try {
          final r = await _findRecord(job);
          if (_gone(job)) return;
          if (r != null) {
            _settle(job, YtdlJobState.added, record: r);
            return;
          }
        } catch (_) {
          unread = true;
        }
      }
      final name = await _nameInFolder(job);
      if (_gone(job)) return;
      if (name != null && name.isNotEmpty) {
        _settle(job, YtdlJobState.added, filepath: _pathIn(job, name));
        return;
      }
      if (name == null || unread) return;
      _settle(job, YtdlJobState.notFound);
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
          // Still added; the record joins the row once a page holds it.
        }
      }
      String? listed;
      if (record == null) {
        // No record to name the file: the folder does, when it shows the
        // predicted name (older servers, a record not written or not read).
        final name = await _nameInFolder(job);
        if (name != null && name.isNotEmpty) listed = _pathIn(job, name);
      }
      if (_jobs.contains(job) && job.open) {
        _settle(job, YtdlJobState.added, record: record, filepath: listed);
      }
    } else if (entry.failed) {
      await _erred(job);
    }
  }

  /// [job]'s entry ended in `error`. Only 6.30+ refuses a name clash (an
  /// older server re-tags instead): there the predicted name in the folder
  /// → failedClash, else failed. While the folder won't list (or the tier
  /// is not known) the job stays adding and the next poll asks again — a
  /// clash read as a plain failure would offer a Try again that fails the
  /// same way. Once the entry is gone ([gone]) it settles on what is known,
  /// failed when that is nothing.
  Future<void> _erred(YtdlJob job, {bool gone = false}) async {
    _sawError.add(job.id);
    await _knowTier();
    String? name;
    if (_tier != YtdlServerTier.older) name = await _nameInFolder(job);
    if (!_jobs.contains(job) || !job.open) return;
    final full = _tier == YtdlServerTier.full;
    if (!gone && _tier != YtdlServerTier.older && (!full || name == null)) {
      return;
    }
    _sawError.remove(job.id);
    _settle(
        job,
        full && name != null && name.isNotEmpty
            ? YtdlJobState.failedClash
            : YtdlJobState.failed);
  }

  /// A job whose entry is gone without this phone seeing it end (away past
  /// the tracker's 30 s, a restart, or never seen at all): the download
  /// record (6.30+) or the folder (older) says added; else "Not sure it
  /// finished". A lookup that fails leaves it for the next poll. One seen
  /// in `error` settles as a failure ([_erred]).
  Future<void> _vanished(YtdlJob job) async {
    if (_sawError.contains(job.id)) return _erred(job, gone: true);
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
    final name = await _nameInFolder(job);
    if (name == null || !_jobs.contains(job) || !job.open) return;
    final there = name.isNotEmpty;
    _settle(job, there ? YtdlJobState.added : YtdlJobState.notSureFinished,
        filepath: there ? _pathIn(job, name) : null);
  }

  /// [job]'s download record: the newest row [_answers] says is its (its
  /// link, its folder, not older than the job) that no other job holds.
  /// Paged on every plug-in's ids (a page of other plug-ins' rows is not
  /// the end) until the last page (empty, or shorter than asked for; its
  /// rows are read first), a page that reaches back past the job's start
  /// or floor, or [kRecordPages] pages. Null when there is none, or
  /// the route is missing (the tier turns older). Throws when the record
  /// cannot be read.
  Future<YtdlRecord?> _findRecord(YtdlJob job) async {
    final taken = {
      for (final j in _jobs)
        if (!identical(j, job)) ?j.recordId,
    };
    final start = job.serverStart;
    final floor = job.recordFloor;
    int? before;
    for (var i = 0; i < kRecordPages; i++) {
      final page = await api.recordsPage(limit: kRecordPage, before: before);
      if (page == null) {
        _tier = YtdlServerTier.older;
        _notify();
        return null;
      }
      if (before == null) _noteNewest(page.newestId ?? 0);
      for (final r in page.rows) {
        if (!taken.contains(r.id) && _answers(job, r)) return r;
      }
      if (page.end) return null;
      final oldestAt = page.oldestAt;
      final oldestId = page.oldestId;
      if (start != null && oldestAt != null && oldestAt < start) return null;
      if (floor != null && oldestId != null && oldestId <= floor) return null;
      before = oldestId;
    }
    return null;
  }

  /// [job]'s predicted file in its folder (ignoring case): the name as the
  /// folder lists it (the on-disk case), '' when the folder listed without
  /// it, null when the folder did not list.
  Future<String?> _nameInFolder(YtdlJob job) async {
    final name = job.predictedName.toLowerCase();
    try {
      final listing = await api.list(job.directory);
      if (name.isEmpty) return '';
      return listing.files
              .where((f) => f.toLowerCase() == name)
              .firstOrNull ??
          '';
    } catch (_) {
      return null;
    }
  }

  /// `<vpath>/<rel>/<name>`: [name] in [job]'s folder as a record names it.
  static String _pathIn(YtdlJob job, String name) =>
      '${_bare(job.directory)}/$name';

  /// The hub no longer holds [job] (dismissed while a read was out).
  bool _gone(YtdlJob job) => _disposed || !_jobs.contains(job);

  /// [job] reached [state]: kept, toasted, told on [settled]. [record]
  /// names its file; else [filepath] (the folder's listing). Nothing for a
  /// job the hub no longer holds.
  void _settle(YtdlJob job, YtdlJobState state,
      {YtdlRecord? record, String? filepath}) {
    if (_gone(job)) return;
    job
      ..state = state
      ..endedAt = _now
      ..seen = _screenShowing;
    if (record != null) {
      _takeRecord(job, record);
    } else if (filepath != null) {
      job.filepath = filepath;
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
    _reprobe?.cancel();
    _reprobe = null;
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
