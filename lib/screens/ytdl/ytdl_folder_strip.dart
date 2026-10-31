import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../objects/display_item.dart';
import '../../objects/server.dart';
import '../../objects/ytdl_job.dart';
import '../../singletons/api.dart';
import '../../singletons/browser_list.dart';
import '../../singletons/server_list.dart';
import '../../singletons/settings.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart' show pathCrumbs;
import '../discovery/keep_copy_ui.dart';
import 'ytdl_screen.dart';

/// The server a File Explorer frame belongs to: frames carry none, so its
/// first row's, else the current server (an empty folder has no rows) —
/// what makeServerCall falls back to as well.
Server? ytdlExplorerServer() {
  final rows = BrowserManager().browserList;
  return (rows.isNotEmpty ? rows.first.server : null) ??
      ServerManager().currentServer;
}

/// Whether the folder on screen offers Add from YouTube (spec §7): the hub
/// is wired into the app, and [YtdlHub.explorerEntryAllowed] for its server
/// and path — so never at '/', in Local Files, in an m3u, on a peer, with
/// uploads off, conversion off or no library, and never in a store build.
bool ytdlExplorerEntry() =>
    YtdlHub().installed &&
    YtdlHub.explorerEntryAllowed(
        ytdlExplorerServer(), BrowserManager().currentPath);

/// The row the explorer tints for 2 s after a re-list (spec §7 "When
/// done"): the new file, or the subfolder it went into. A tint only — the
/// rows keep their heights, which the letter strip's jump maths sums.
class YtdlRowHighlight {
  YtdlRowHighlight._();

  static const Duration kFor = Duration(seconds: 2);

  static Server? _server;
  static String? _data;
  static Timer? _off;

  /// [item] is the highlighted row (its server and path, ignoring case).
  static bool isLit(DisplayItem item) {
    final data = _data;
    return data != null &&
        identical(item.server, _server) &&
        item.data?.toLowerCase() == data.toLowerCase();
  }

  /// Light the row at [data] on [server] for [kFor] (on [timer]), redrawing
  /// the list on and off.
  static void light(Server? server, String data,
      {Timer Function(Duration, void Function())? timer}) {
    _off?.cancel();
    _server = server;
    _data = data;
    BrowserManager().updateStream();
    _off = (timer ?? Timer.new)(kFor, () {
      _off = null;
      _server = null;
      _data = null;
      BrowserManager().updateStream();
    });
  }

  @visibleForTesting
  static void reset() {
    _off?.cancel();
    _off = null;
    _server = null;
    _data = null;
  }
}

/// The strip above a File Explorer folder while Add from YouTube works in it
/// or below it (spec §7, the ExplorerAfter board): "Adding “One More
/// Time”… · See all", "Adding 2 videos… · See all", or — once one failed —
/// "Couldn't add “Around the World” · Details" on a 12% error tint. Only on
/// [server] (its own server's jobs), only in the target folder and its
/// parents ([YtdlServerState.jobsUnder]).
///
/// While it is up it also keeps the folder fresh: when a job settles in
/// [path] or below, the folder is listed again headless and replaces its
/// frame in place ([BrowserManager.replaceFrame]: no scroll jump, the search
/// left as it was), and the new file — or the subfolder it went into — is
/// tinted for 2 s.
class YtdlFolderStrip extends StatefulWidget {
  final Server server;

  /// The explorer path on screen ('/Music/Daft Punk/').
  final String path;

  const YtdlFolderStrip({super.key, required this.server, required this.path});

  /// [directory]'s raw `POST /api/v1/file-explorer` answer, with the
  /// metadata the browser's own listing asks for — headless (no loading bar,
  /// taps never blocked), on the hub's client for the server (its fake in
  /// tests). Null for an answer that is not a listing.
  static Future<Map?> _listFolder(
      YtdlServerState state, String directory) async {
    final server = state.server;
    final api = state.api;
    final res = await (api.client ?? ApiManager().directClient)
        .post(
          server.apiUri('/api/v1/file-explorer'),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.authToken ?? '',
          },
          body: jsonEncode({
            'directory': directory,
            'pullMetadata': SettingsManager().fileExplorerMetadata,
          }),
        )
        .timeout(server.isIrohTransport ? api.irohTry : api.timeout);
    if (res.statusCode < 200 || res.statusCode > 299) return null;
    final body = jsonDecode(res.body);
    return body is Map ? body : null;
  }

  @override
  State<YtdlFolderStrip> createState() => _YtdlFolderStripState();
}

class _YtdlFolderStripState extends State<YtdlFolderStrip> {
  late YtdlServerState _state = YtdlHub().stateFor(widget.server);
  StreamSubscription<YtdlJob>? _settled;

  @override
  void initState() {
    super.initState();
    _settled = _state.settled.listen(_onSettled);
  }

  @override
  void didUpdateWidget(YtdlFolderStrip old) {
    super.didUpdateWidget(old);
    final next = YtdlHub().stateFor(widget.server);
    if (!identical(next, _state)) {
      _settled?.cancel();
      _state = next;
      _settled = _state.settled.listen(_onSettled);
    }
  }

  @override
  void dispose() {
    _settled?.cancel();
    super.dispose();
  }

  /// '/Music/Daft Punk' → '/music/daft punk/' (paths compare like the
  /// hub's, ignoring case).
  static String _norm(String path) =>
      (path.endsWith('/') ? path : '$path/').toLowerCase();

  /// A job settled: if the folder on screen is its folder or a parent of
  /// it, list it again (the frame is held by identity, so an answer that
  /// lands after the user left changes nothing on screen).
  Future<void> _onSettled(YtdlJob job) async {
    final path = widget.path;
    final bm = BrowserManager();
    if (bm.currentPath != path || bm.browserCache.isEmpty) return;
    final here = _norm(path);
    if (!_norm(job.directory).startsWith(here)) return;
    final frame = bm.browserCache.last;
    final server = frame.isNotEmpty ? frame.first.server : widget.server;
    final Map? res;
    try {
      res = await YtdlFolderStrip._listFolder(_state, path);
    } catch (_) {
      return;
    }
    if (res == null || !mounted) return;
    final List<DisplayItem> rows;
    try {
      rows = ApiManager().fileExplorerRows(server, res);
    } catch (_) {
      return;
    }
    if (!bm.replaceFrame(frame, rows)) return;
    if (job.state != YtdlJobState.added || bm.currentPath != path) return;
    final lit = _rowFor(job, rows);
    if (lit != null) {
      YtdlRowHighlight.light(server, lit, timer: _state.hub.timer);
    }
  }

  /// The row [job] put in the folder on screen: its file when it went right
  /// here — named by the download record, else the predicted name — or the
  /// subfolder it went into. Null when no listed row matches (nothing is
  /// tinted then).
  String? _rowFor(YtdlJob job, List<DisplayItem> rows) {
    final here = pathCrumbs(widget.path);
    final there = pathCrumbs(job.directory);
    String? want;
    if (there.length > here.length) {
      want = p.join(widget.path, there[here.length]);
    } else {
      final named = job.filepath;
      if (named != null && named.isNotEmpty) {
        want = named.startsWith('/') ? named : '/$named';
      } else if (job.predictedName.isNotEmpty) {
        want = p.join(widget.path, job.predictedName);
      }
    }
    final w = want?.toLowerCase();
    if (w == null) return null;
    for (final r in rows) {
      if (r.data?.toLowerCase() == w) return r.data;
    }
    return null;
  }

  void _open({bool needsLook = false}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            YtdlScreen(server: widget.server, openNeedsLook: needsLook)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final jobs = _state.jobsUnder(widget.path);
        final open = [for (final j in jobs) if (j.open) j];
        if (open.isNotEmpty) {
          return _Strip(
            key: const ValueKey('ytdl-strip'),
            lead: const _StripRing(),
            text: open.length == 1
                ? l.ytdlStripAdding(_titleOf(open.single))
                : l.ytdlStripAddingCount(open.length),
            action: l.ytdlStripSeeAll,
            actionKey: const ValueKey('ytdl-strip-see-all'),
            onAction: _open,
          );
        }
        if (jobs.isEmpty) return const SizedBox.shrink();
        return _Strip(
          key: const ValueKey('ytdl-strip-failed'),
          tint: Color.alphaBlend(
              VelvetColors.error.withValues(alpha: 0.12), VelvetColors.raised),
          lead: Icon(Icons.error_outline,
              size: 16, color: keepToneOnPage(VelvetColors.error)),
          text: l.ytdlCouldntAdd(_titleOf(jobs.first)),
          action: l.ytdlStripDetails,
          actionKey: const ValueKey('ytdl-strip-details'),
          onAction: () => _open(needsLook: true),
        );
      },
    );
  }

  static String _titleOf(YtdlJob job) => job.title.isEmpty ? job.url : job.title;
}

/// The strip's 40 px row: [lead], one line of words, a text button in the
/// primary's ink (a 48 px hit band) — announced politely as it changes.
class _Strip extends StatelessWidget {
  final Widget lead;
  final String text;
  final String action;
  final Key actionKey;
  final VoidCallback onAction;
  final Color? tint;
  const _Strip({
    super.key,
    required this.lead,
    required this.text,
    required this.action,
    required this.actionKey,
    required this.onAction,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final ink = keepInkOn(tint ?? VelvetColors.raised);
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      decoration: BoxDecoration(
        color: tint ?? VelvetColors.raised,
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  color: VelvetColors.textPrimary,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            child: InkWell(
              key: actionKey,
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      action,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip's 16 px ring (still under reduced motion).
class _StripRing extends StatelessWidget {
  const _StripRing();

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final ink = keepInkOn(VelvetColors.raised);
    return SizedBox(
      width: 16,
      height: 16,
      child: still
          ? KeepRing(size: 16, color: ink)
          : CircularProgressIndicator(
              strokeWidth: 2,
              color: ink,
              backgroundColor: VelvetColors.border2,
            ),
    );
  }
}
