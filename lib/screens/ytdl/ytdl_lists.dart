import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/display_item.dart';
import '../../objects/server.dart';
import '../../objects/ytdl_job.dart';
import '../../singletons/api.dart';
import '../../singletons/browser_list.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart' show pathCrumbs;
import '../../util/image_cache.dart';
import '../../util/queue_actions.dart';
import '../../util/server_version.dart';
import '../../util/stream_url.dart';
import '../../util/ytdl_errors.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_choose_folder_sheet.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart' show YtdlDraft, ytdlGoneLibrary, ytdlServerWords;

/// What a row's actions reach outside the hub: playing and queueing a song
/// the server added, opening its folder in the File Explorer, picking a
/// folder that exists ("Choose a folder…", C3's sheet) and the library's
/// album art for ADDED. Tests swap them ([reset] puts them back).
class YtdlListActions {
  YtdlListActions._();

  static Future<void> Function(DisplayItem song) play = playNow;
  static Future<void> Function(DisplayItem song) queue = addToQueueEnd;
  static void Function(BuildContext context, Server server, String directory)
      showFolder = ytdlShowFolder;
  static Future<String?> Function(BuildContext context, YtdlDraft draft)
      chooseFolder = showYtdlChooseFolderSheet;
  static Future<Map<String, String>> Function(
      YtdlServerState state, List<String> filepaths) albumArt = ytdlAlbumArt;

  @visibleForTesting
  static void reset() {
    play = playNow;
    queue = addToQueueEnd;
    showFolder = ytdlShowFolder;
    chooseFolder = showYtdlChooseFolderSheet;
    albumArt = ytdlAlbumArt;
  }
}

/// "Show folder" / "Show in folder": back to the browser under every pushed
/// route, and [directory] ('/Music/Daft Punk/Discovery/') opened in the File
/// Explorer — over whatever the browser showed, as a folder tap would.
void ytdlShowFolder(BuildContext context, Server server, String directory) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  final bm = BrowserManager();
  bm.closeSearch();
  if (bm.albumDetail != null) bm.closeAlbumDetail();
  unawaited(ApiManager().getFileList(directory, useThisServer: server));
}

/// The library's album-art file for each of [filepaths] ('Music/Daft
/// Punk/Random Access Memories/Instant_Crush.mp3', as the download record
/// names a song: no leading slash) on [state]'s server — one
/// `POST /api/v1/db/metadata/batch` on the hub's client (its fake in
/// tests), keyed by the path as sent. Songs without art are left out; a
/// server before the route, a refusal or no answer is an empty map.
Future<Map<String, String>> ytdlAlbumArt(
    YtdlServerState state, List<String> filepaths) async {
  final server = state.server;
  if (filepaths.isEmpty ||
      metadataBatchKnownUnsupported(
          ServerVersion.tryParse(server.serverVersion))) {
    return const {};
  }
  final api = state.api;
  try {
    final res = await (api.client ?? ApiManager().directClient)
        .post(
          server.apiUri('/api/v1/db/metadata/batch'),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.authToken ?? '',
          },
          // A bare JSON array: the route iterates the body itself.
          body: jsonEncode(filepaths),
        )
        .timeout(server.isIrohTransport ? api.irohTry : api.timeout);
    if (res.statusCode < 200 || res.statusCode > 299) return const {};
    final body = jsonDecode(res.body);
    if (body is! Map) return const {};
    return {
      for (final e in body.entries)
        if (e.value case {'metadata': {'album-art': final String art}}
            when art.isNotEmpty)
          '${e.key}': art,
    };
  } catch (_) {
    return const {};
  }
}

/// "Top of the library" / "Choose a folder…" on a start failure's row (a
/// folder that could not be made): the same song added again into
/// [directory] — one that is there (listed, or the library's top), so
/// nothing is made first — in place of [job]'s row.
Future<void> ytdlAddInto(
    YtdlServerState state, YtdlJob job, String directory) async {
  if (!state.jobs.contains(job) || job.open) return;
  final next = state.start(YtdlStartRequest(
    url: job.url,
    directory: directory.endsWith('/') ? directory : '$directory/',
    codec: job.codec,
    metadata: job.tags,
    title: job.title,
    cover: job.cover,
    predictedName: job.predictedName,
    origin: state.originOf(job),
  ));
  state.dismiss(job);
  await next;
}

/// Library art per ADDED song, by its filepath (null: asked, none found),
/// kept with the server's state for the session.
final Expando<Map<String, String?>> _addedArt = Expando('ytdl-added-art');

/// ADDING, NEEDS A LOOK and ADDED under the result card (spec §6, the
/// Downloads board): one list with section headers, every row's state in an
/// icon and words, and its actions on the hub ([YtdlServerState]). Live: it
/// listens to the state.
///
/// It draws no side padding — it sits in the screen's padded column, under
/// the paste card and the limits line. With no rows at all and [showEmpty],
/// the empty state (the Empty board) takes their place once ADDED's read is
/// in ([YtdlServerState.addedLoading]: nothing before it, so the rows never
/// replace a flash of it); the screen turns it off while a result card
/// shows.
class YtdlLists extends StatefulWidget {
  final YtdlServerState state;

  /// Put on the NEEDS A LOOK header so the screen can scroll to it
  /// ([YtdlScreen.openNeedsLook]).
  final GlobalKey? needsLookAnchor;

  /// Draw the empty state when there is nothing to list (false while the
  /// screen shows a result card above).
  final bool showEmpty;

  const YtdlLists({
    super.key,
    required this.state,
    this.needsLookAnchor,
    this.showEmpty = true,
  });

  /// How often an ADDING row's minutes move on while it is on screen.
  static const Duration kMinuteTick = Duration(seconds: 30);

  @override
  State<YtdlLists> createState() => _YtdlListsState();
}

class _YtdlListsState extends State<YtdlLists> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// "Adding · 2 min" counts on while an ADDING row shows; a poll that
  /// changes nothing does not notify, so the list ticks itself.
  void _keepTicking(bool adding) {
    if (!adding) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick?.isActive == true) return;
    _tick = widget.state.hub.timer(YtdlLists.kMinuteTick, () {
      _tick = null;
      if (mounted) setState(() {});
    });
  }

  /// ADDED's covers: the library's art for songs it can name, asked once
  /// per song per session in one batch for the rows on hand.
  Map<String, String?> _askArt(List<YtdlAddedRow> rows) {
    final st = widget.state;
    final known = _addedArt[st] ??= <String, String?>{};
    final ask = <String>[
      for (final r in rows)
        if (r.present &&
            (r.cover ?? '').isEmpty &&
            r.filepath != null &&
            !known.containsKey(r.filepath))
          r.filepath!,
    ];
    if (ask.isEmpty) return known;
    for (final f in ask) {
      known[f] = null;
    }
    YtdlListActions.albumArt(st, ask).then((found) {
      if (found.isEmpty) return;
      known.addAll(found);
      if (mounted) setState(() {});
    }, onError: (Object _) {});
    return known;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final st = widget.state;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final adding = st.adding;
        final look = st.needsLook;
        final added = st.added;
        final earlier = st.canShowEarlier;
        _keepTicking(adding.isNotEmpty);
        if (adding.isEmpty && look.isEmpty && added.isEmpty && !earlier) {
          // Not while ADDED's first read is out: its rows may be on the way.
          return widget.showEmpty && !st.addedLoading
              ? _YtdlEmpty(webApp: st.tier == YtdlServerTier.full)
              : const SizedBox.shrink();
        }
        final art = _askArt(added);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (adding.isNotEmpty) ...[
              _SectionHeader(
                key: const ValueKey('ytdl-section-adding'),
                title: l.ytdlSectionAdding,
                note: l.ytdlSectionAddingNote,
              ),
              for (final j in adding) _AddingRow(state: st, job: j),
            ],
            if (look.isNotEmpty) ...[
              KeyedSubtree(
                key: widget.needsLookAnchor,
                child: _SectionHeader(
                  key: const ValueKey('ytdl-section-needs-look'),
                  title: l.ytdlSectionNeedsLook,
                ),
              ),
              for (final j in look) _LookRow(state: st, job: j),
            ],
            if (added.isNotEmpty || earlier) ...[
              _SectionHeader(
                key: const ValueKey('ytdl-section-added'),
                title: l.ytdlSectionAdded,
              ),
              for (var i = 0; i < added.length; i++)
                _AddedRow(
                  state: st,
                  row: added[i],
                  art: art[added[i].filepath],
                  tag: added[i].recordId?.toString() ??
                      added[i].filepath ??
                      '$i',
                ),
              if (earlier)
                Center(
                  child: _TextAction(
                    key: const ValueKey('ytdl-show-earlier'),
                    label: l.ytdlShowEarlier,
                    busy: st.addedLoading,
                    onTap: () => unawaited(st.showEarlier()),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ── the pieces ────────────────────────────────────────────────────────────

/// A section label (11/700 caps in the primary's ink) with an optional
/// helper line under it: "ADDING" / "Runs on the server · can't be stopped
/// from the app".
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? note;
  const _SectionHeader({super.key, required this.title, this.note});

  @override
  Widget build(BuildContext context) {
    // One node, the label and its note read together where they stand.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  height: 13 / 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: keepInkOnPage(),
                ),
              ),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  note!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: VelvetColors.helper,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row's 48 px picture: the library's art, or the video's thumbnail
/// (centre-cropped) when this phone looked it up, else a note on a quiet
/// tile. [dim] for a song whose file is gone; [decorative] inside a row's
/// tap target, whose words name it (no "Cover" image node there).
class _Cover extends StatelessWidget {
  final String? url;
  final bool dim;
  final bool decorative;
  const _Cover({this.url, this.dim = false, this.decorative = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tile = Container(
      color: dim
          ? VelvetColors.raised
          : Color.alphaBlend(VelvetColors.hover, VelvetColors.raised),
      alignment: Alignment.center,
      child: Icon(Icons.music_note, size: 20, color: VelvetColors.helper),
    );
    final u = url;
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: u == null || u.isEmpty
            ? tile
            : Image.network(
                u,
                fit: BoxFit.cover,
                // Decoded at its drawn height: square art and a 16:9
                // thumbnail both stay sharp once cropped.
                cacheHeight: artCacheSize(48),
                errorBuilder: (_, _, _) => tile,
              ),
      ),
    );
    if (decorative) return ExcludeSemantics(child: picture);
    return Semantics(
      label: l.ytdlA11yCover,
      image: true,
      excludeSemantics: true,
      child: picture,
    );
  }
}

/// The title, the folder (cut at the start at narrow widths) and [status]
/// under it, read as one node.
class _RowText extends StatelessWidget {
  final String title;
  final String directory;
  final Widget status;
  final bool dim;
  const _RowText({
    required this.title,
    required this.directory,
    required this.status,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 20 / 15,
              fontWeight: FontWeight.w600,
              color: dim ? VelvetColors.helper : VelvetColors.textPrimary,
            ),
          ),
          YtdlCrumbLine(
            crumbs: pathCrumbs(directory),
            // The text's own family too: the line measures what fits with
            // this style, and must measure the font it draws in.
            style: DefaultTextStyle.of(context).style.merge(TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  color: dim ? VelvetColors.helper : VelvetColors.textSecondary,
                )),
          ),
          status,
        ],
      ),
    );
  }
}

/// An icon and words on one status line (they wrap under each other's
/// start, never under the icon).
class _Status extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;
  final Color color;
  final double iconSize;
  const _Status({
    required this.icon,
    required this.text,
    required this.iconColor,
    required this.color,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    // The icon sits on the first line at any text size, and grows a little
    // with it.
    final ts = MediaQuery.textScalerOf(context);
    final grown = ts.scale(iconSize);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: ts.scale(16),
            child: Center(
              widthFactor: 1,
              child: Icon(icon,
                  size: grown > iconSize * 1.5 ? iconSize * 1.5 : grown,
                  color: iconColor),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 16 / 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The indeterminate ring on an ADDING row ("Adding" to a screen reader);
/// still under reduced motion.
class _AddingRing extends StatelessWidget {
  const _AddingRing();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: l.ytdlA11yAdding,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 20,
        height: 20,
        child: still
            ? KeepRing(size: 20, color: keepInkOnPage())
            : CircularProgressIndicator(
                strokeWidth: 2.5,
                color: keepInkOnPage(),
                backgroundColor: VelvetColors.border2,
              ),
      ),
    );
  }
}

/// A row's ⋮ menu, read as "More for One More Time": its whole 48 px
/// button inside the row, where every tap on it lands. (The board pulls
/// it 12 px into the page's gutter; the gutter is the screen's padding,
/// which a tap there never reaches, so the row keeps it.)
class _RowMenu<T> extends StatelessWidget {
  final String title;
  final List<PopupMenuEntry<T>> Function(BuildContext) items;
  final void Function(T) onSelected;
  const _RowMenu({
    super.key,
    required this.title,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<T>(
      tooltip: l.ytdlA11yMoreFor(title),
      icon: Icon(Icons.more_vert, size: 22, color: VelvetColors.textSecondary),
      color: VelvetColors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: VelvetColors.border),
      ),
      itemBuilder: items,
      onSelected: onSelected,
    );
  }
}

PopupMenuItem<T> _menuItem<T>(T value, String label, {Key? key}) =>
    PopupMenuItem<T>(
      key: key,
      value: value,
      child: Text(
        label,
        style: TextStyle(fontSize: 14, color: VelvetColors.textPrimary),
      ),
    );

/// An outlined pill button (40 px drawn, a 48 px hit band): a row's first
/// action. [busy] puts a ring before the label and ignores taps.
class _OutlinedAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _OutlinedAction({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final tap = busy ? null : onTap;
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      enabled: tap != null,
      child: KeepHitArea(
        minHeight: 48,
        onTap: tap,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: VelvetColors.border2),
          ),
          child: InkWell(
            onTap: tap,
            borderRadius: radius,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VelvetColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        height: 18 / 14,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text button in the primary's ink with a 48 px hit band: Dismiss, Show
/// folder, Show earlier.
class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _TextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final tap = busy ? null : onTap;
    final ink = keepInkOnPage();
    return Semantics(
      button: true,
      enabled: tap != null,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── ADDING ────────────────────────────────────────────────────────────────

/// "One More Time · Music › Daft Punk › Discovery · Adding · 2 min · MP3"
/// with the ring, and ⋮ → Hide from this list once the server has the job
/// (a row still starting has nothing to hide yet).
class _AddingRow extends StatelessWidget {
  final YtdlServerState state;
  final YtdlJob job;
  const _AddingRow({required this.state, required this.job});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ink = keepInkOnPage();
    final Widget status;
    if (state.offline) {
      status = _Status(
        icon: Icons.cloud_off_outlined,
        iconSize: 14,
        text: l.ytdlRowWaiting,
        iconColor: VelvetColors.helper,
        color: VelvetColors.textSecondary,
      );
    } else {
      final minutes = state.hub.now().difference(job.createdAt).inMinutes;
      final text = switch (job.state) {
        YtdlJobState.starting => l.discoverJobStarting,
        YtdlJobState.startUnsure => l.ytdlRowStartUnsure,
        _ => l.ytdlRowAdding(minutes < 1 ? 1 : minutes, _formatName(job.codec)),
      };
      status = Text(
        text,
        style: TextStyle(fontSize: 12, height: 16 / 12, color: ink),
      );
    }
    final hideable = job.state == YtdlJobState.adding;
    return Padding(
      key: ValueKey('ytdl-row-${job.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _Cover(url: job.cover),
          const SizedBox(width: 12),
          Expanded(
            child: _RowText(
              title: _titleOf(job),
              directory: job.directory,
              status: status,
            ),
          ),
          const SizedBox(width: 8),
          const _AddingRing(),
          if (hideable)
            _RowMenu<int>(
              key: ValueKey('ytdl-row-more-${job.id}'),
              title: _titleOf(job),
              items: (_) => [
                _menuItem(0, l.ytdlRowHide,
                    key: const ValueKey('ytdl-row-hide')),
              ],
              onSelected: (_) {
                state.hide(job);
                state.hub.showToast(l.ytdlToastHidden);
              },
            )
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

// ── NEEDS A LOOK ──────────────────────────────────────────────────────────

/// A row that failed or whose outcome is unsure: it grows to fit its
/// reason, and its buttons sit on their own line (spec §6).
class _LookRow extends StatelessWidget {
  final YtdlServerState state;
  final YtdlJob job;
  const _LookRow({required this.state, required this.job});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final id = job.id;
    final busy = state.busy(job);
    final failedTone = keepToneOnPage(VelvetColors.error);

    Widget dismiss() => _TextAction(
          key: ValueKey('ytdl-row-dismiss-$id'),
          label: l.federationDismiss,
          onTap: () => state.dismiss(job),
        );
    Widget showFolder({bool outlined = false}) {
      void open() =>
          YtdlListActions.showFolder(context, state.server, job.directory);
      final key = ValueKey('ytdl-row-show-folder-$id');
      return outlined
          ? _OutlinedAction(key: key, label: l.ytdlRowShowFolder, onTap: open)
          : _TextAction(key: key, label: l.ytdlRowShowFolder, onTap: open);
    }

    Widget retry() => _OutlinedAction(
          key: ValueKey('ytdl-row-retry-$id'),
          label: l.discoverPageRetry,
          busy: busy,
          onTap: () => unawaited(state.retry(job)),
        );
    // The library the row's folder is in ('Music').
    final crumbs = pathCrumbs(job.directory);
    final library = crumbs.isEmpty ? state.library : crumbs.first;
    Widget topOfLibrary() => _OutlinedAction(
          key: ValueKey('ytdl-row-top-$id'),
          label: l.ytdlLayoutTop,
          busy: busy,
          onTap: () => unawaited(ytdlAddInto(state, job, '/$library/')),
        );
    Widget chooseFolder() => _TextAction(
          key: ValueKey('ytdl-row-choose-folder-$id'),
          label: l.ytdlChooseFolderLink,
          busy: busy,
          onTap: () async {
            // The sheet browses the draft's library; the session's draft
            // for that library's top folder is the one that names it.
            final dir = await YtdlListActions.chooseFolder(
                context, state.folderDraft('/$library/'));
            if (dir == null || dir.isEmpty) return;
            await ytdlAddInto(state, job, dir);
          },
        );
    Widget? changeFormat() {
      final others = [
        for (final f in state.formats)
          if (f != job.codec) f,
      ];
      if (others.isEmpty) return null;
      return _FormatRetry(
        key: ValueKey('ytdl-row-change-format-$id'),
        options: others,
        busy: busy,
        onPicked: (codec) => unawaited(state.retry(job, codec: codec)),
      );
    }

    final IconData icon;
    final Color iconColor;
    final String text;
    final Color color;
    final List<Widget?> actions;
    switch (job.state) {
      case YtdlJobState.failedClash:
        (icon, iconColor, text, color) =
            (Icons.error_outline, failedTone, l.ytdlRowClash, failedTone);
        actions = [changeFormat(), showFolder(), dismiss()];
      case YtdlJobState.failed:
        (icon, iconColor, color) = (Icons.error_outline, failedTone, failedTone);
        text = state.tier == YtdlServerTier.full
            ? l.ytdlRowFailed
            : l.ytdlRowFailedOlder;
        actions = [retry(), dismiss()];
      case YtdlJobState.notSureFinished:
        (icon, iconColor, text, color) = (
          Icons.help_outline,
          VelvetColors.textSecondary,
          l.ytdlRowNotSureFinished,
          VelvetColors.textSecondary,
        );
        actions = [showFolder(outlined: true), dismiss()];
      case YtdlJobState.notSureStarted:
        (icon, iconColor, text, color) = (
          Icons.help_outline,
          VelvetColors.textSecondary,
          l.ytdlRowNotSureStarted,
          VelvetColors.textSecondary,
        );
        actions = [
          _OutlinedAction(
            key: ValueKey('ytdl-row-check-again-$id'),
            label: l.discoverCheckAgain,
            busy: busy,
            onTap: () => unawaited(state.checkAgain(job)),
          ),
          dismiss(),
        ];
      case YtdlJobState.notFound:
        (icon, iconColor, text, color) = (
          Icons.help_outline,
          VelvetColors.textSecondary,
          l.ytdlRowNotFound,
          VelvetColors.textSecondary,
        );
        actions = [
          _OutlinedAction(
            key: ValueKey('ytdl-row-add-again-$id'),
            label: l.discoverJobAddAgain,
            busy: busy,
            onTap: () => unawaited(state.addAgain(job)),
          ),
          dismiss(),
        ];
      default: // startFailed: refused before the server took it (spec §8)
        final problem = _problemOf(job);
        (icon, iconColor, color) = (Icons.error_outline, failedTone, failedTone);
        text = _startFailedText(l, job, problem);
        actions = switch (problem) {
          // The folder couldn't be made: make it again, or add the song
          // into one that is there (spec §8 "mkdir failed").
          YtdlProblem.mkdirFailed => [retry(), chooseFolder(), dismiss()],
          // The account can't make folders: only folders that are there —
          // the library's top always is (spec §8 "mkdir off"). The
          // deepest folder that listed isn't known to a row; Choose a
          // folder reaches it.
          YtdlProblem.mkdirOff => [topOfLibrary(), chooseFolder(), dismiss()],
          // Nothing a second try can change: the account, the library or
          // the route said no.
          YtdlProblem.uploadsOff ||
          YtdlProblem.libraryGone ||
          YtdlProblem.noRoute =>
            [dismiss()],
          YtdlProblem.badFormat => [changeFormat(), dismiss()],
          _ => [retry(), dismiss()],
        };
    }

    return Padding(
      key: ValueKey('ytdl-row-$id'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(url: job.cover),
              const SizedBox(width: 12),
              Expanded(
                child: _RowText(
                  title: _titleOf(job),
                  directory: job.directory,
                  status: _Status(
                    icon: icon,
                    text: text,
                    iconColor: iconColor,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [for (final a in actions) ?a],
          ),
        ],
      ),
    );
  }
}

/// "Change format and retry": the formats the server has on, other than the
/// one that clashed (or was refused), in a menu anchored on the button.
class _FormatRetry extends StatelessWidget {
  final List<String> options;
  final bool busy;
  final void Function(String codec) onPicked;
  const _FormatRetry({
    super.key,
    required this.options,
    required this.busy,
    required this.onPicked,
  });

  Future<void> _open(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      color: VelvetColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Text(
            l.ytdlFormatMenuTitle,
            style: TextStyle(fontSize: 12, color: VelvetColors.textSecondary),
          ),
        ),
        for (final f in options)
          PopupMenuItem<String>(
            key: ValueKey('ytdl-row-format-$f'),
            value: f,
            height: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatName(f),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary,
                  ),
                ),
                if (_formatHelp(l, f) case final help?)
                  Text(
                    help,
                    style: TextStyle(
                      fontSize: 13,
                      color: VelvetColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Builder(
      builder: (context) => _OutlinedAction(
        label: l.ytdlRowChangeFormatRetry,
        busy: busy,
        onTap: () => unawaited(_open(context)),
      ),
    );
  }
}

// ── ADDED ─────────────────────────────────────────────────────────────────

enum _AddedAction { queue, showFolder }

/// A song the server added: its library art, "MP3 · 8.4 MB · 3 min ago".
/// Tap plays it, ⋮ → Add to queue / Show in folder; a row the phone can't
/// name the file for does not play. A file gone from the library is
/// greyed: "File missing · Oct 12", nothing to tap.
class _AddedRow extends StatelessWidget {
  final YtdlServerState state;
  final YtdlAddedRow row;

  /// The library's album-art file for the song ([ytdlAlbumArt]); null
  /// while unknown or when it has none.
  final String? art;
  final String tag;
  const _AddedRow({
    required this.state,
    required this.row,
    required this.tag,
    this.art,
  });

  DisplayItem? get _song {
    final path = row.filepath;
    if (path == null || path.isEmpty) return null;
    final name = path.split('/').last;
    return DisplayItem(state.server, name, 'file',
        path.startsWith('/') ? path : '/$path', null, null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = state.hub.now();
    if (!row.present) {
      final when = row.when;
      final missing = [
        l.ytdlRowFileMissing,
        if (when != null) _date(context, when, now),
      ].join(' · ');
      return Padding(
        key: ValueKey('ytdl-added-$tag'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _Cover(url: row.cover, dim: true),
            const SizedBox(width: 12),
            Expanded(
              child: _RowText(
                title: row.title,
                directory: row.directory,
                dim: true,
                status: _Status(
                  icon: Icons.music_off_outlined,
                  iconSize: 14,
                  text: missing,
                  iconColor: VelvetColors.helper,
                  color: VelvetColors.helper,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final song = _song;
    final meta = [
      if (row.ext != null) _formatName(row.ext!),
      ?_size(row.bytes),
      if (row.when != null) _ago(context, l, row.when!, now),
    ].join(' · ');
    final artFile = art;
    final cover = (row.cover ?? '').isNotEmpty
        ? row.cover
        : artFile == null
            ? null
            : buildAlbumArtUrl(state.server, artFile);
    return Padding(
      key: ValueKey('ytdl-added-$tag'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            // One node for the tap: the song's words, what tapping does.
            child: MergeSemantics(
              child: Semantics(
                button: song != null,
                child: InkWell(
                  key: ValueKey('ytdl-added-play-$tag'),
                  onTap: song == null
                      ? null
                      : () => unawaited(YtdlListActions.play(song)),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        _Cover(url: cover, decorative: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RowText(
                            title: row.title,
                            directory: row.directory,
                            status: Text(
                              meta,
                              style: TextStyle(
                                fontSize: 12,
                                height: 16 / 12,
                                color: VelvetColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _RowMenu<_AddedAction>(
            key: ValueKey('ytdl-added-more-$tag'),
            title: row.title,
            items: (_) => [
              if (song != null)
                _menuItem(_AddedAction.queue, l.discoverJobAddToQueue,
                    key: const ValueKey('ytdl-added-queue')),
              _menuItem(_AddedAction.showFolder, l.ytdlRowShowInFolder,
                  key: const ValueKey('ytdl-added-show-in-folder')),
            ],
            onSelected: (a) {
              switch (a) {
                case _AddedAction.queue:
                  if (song != null) unawaited(YtdlListActions.queue(song));
                case _AddedAction.showFolder:
                  YtdlListActions.showFolder(
                      context, state.server, row.directory);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── the empty state ───────────────────────────────────────────────────────

/// Nothing added yet and no card (the Empty board): the screen's icon, what
/// to do, and — on 6.30+, whose download record lists them — that the web
/// app's adds show here too.
class _YtdlEmpty extends StatelessWidget {
  final bool webApp;
  const _YtdlEmpty({required this.webApp});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      key: const ValueKey('ytdl-lists-empty'),
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: VelvetColors.primaryDim,
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
            ),
            child: Icon(Icons.smart_display_outlined,
                size: 22, color: VelvetColors.primary),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              children: [
                Text(
                  l.ytdlEmptyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary,
                  ),
                ),
                if (webApp) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.ytdlEmptyWebApp,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      color: VelvetColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── words ─────────────────────────────────────────────────────────────────

String _titleOf(YtdlJob job) => job.title.isEmpty ? job.url : job.title;

/// A format's name as the rows and menus show it — not localized, like the
/// transcode screen's codec names.
String _formatName(String codec) => switch (codec.toLowerCase()) {
      'mp3' => 'MP3',
      'm4a' => 'M4A',
      'opus' => 'Opus',
      'ogg' => 'OGG Vorbis',
      'flac' => 'FLAC',
      'wav' => 'WAV',
      'aac' => 'AAC',
      final other => other.toUpperCase(),
    };

/// The format menu's helper under a format (OGG Vorbis and AAC have none).
String? _formatHelp(AppLocalizations l, String codec) => switch (codec) {
      'mp3' => l.ytdlFormatMp3Help,
      'm4a' => l.ytdlFormatM4aHelp,
      'opus' => l.ytdlFormatOpusHelp,
      'flac' => l.ytdlFormatFlacHelp,
      'wav' => l.ytdlFormatWavHelp,
      _ => null,
    };

YtdlProblem? _problemOf(YtdlJob job) =>
    YtdlProblem.values.asNameMap()[job.problem ?? ''];

/// A start failure's row in the words the screen would have used (spec §8).
String _startFailedText(
    AppLocalizations l, YtdlJob job, YtdlProblem? problem) {
  final detail = job.problemDetail;
  final crumbs = pathCrumbs(job.mkdir ?? job.directory);
  final folder = crumbs.isEmpty ? '' : crumbs.last;
  return switch (problem) {
    YtdlProblem.ytdlpMissing => l.ytdlYtdlpMissing,
    YtdlProblem.ffmpegNotReady => l.ytdlErrFfmpeg,
    YtdlProblem.uploadsOff => l.ytdlErrUploadsOff,
    YtdlProblem.mkdirOff => l.ytdlNoMkdirNew(folder),
    YtdlProblem.mkdirFailed =>
      l.ytdlErrMkdir(detail == null || detail.isEmpty ? folder : detail),
    // The row can't pick another library: the sheet's first sentence only.
    YtdlProblem.libraryGone => l.ytdlErrLibraryGoneSheet(ytdlGoneLibrary(
        YtdlFailure(YtdlProblem.libraryGone, detail), job.directory)),
    YtdlProblem.noRoute => l.ytdlErrNoRoute,
    YtdlProblem.badFormat => l.ytdlErrFormatOff(_formatName(job.codec)),
    YtdlProblem.badRequest => l.ytdlErrBadRequest,
    YtdlProblem.offline => l.ytdlRowNoConnection,
    YtdlProblem.other => switch (
          ytdlServerWords(YtdlFailure(YtdlProblem.other, detail))) {
        final words? => l.ytdlErrOther(words),
        null => l.ytdlErrServer,
      },
    _ => l.ytdlErrServer,
  };
}

/// A file's size as the rows read it — decimal units, megabytes to one
/// place ("8.4 MB", "13.6 MB"), like the server's own 500 MB cap; null for
/// none.
String? _size(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).round()} KB';
  if (bytes < 1000 * 1000 * 1000) {
    return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1000 * 1000 * 1000)).toStringAsFixed(1)} GB';
}

/// "just now", "3 min ago", "2 h ago", "yesterday", "2 days ago", then the
/// date — on the hub's clock.
String _ago(
    BuildContext context, AppLocalizations l, DateTime when, DateTime now) {
  final d = now.difference(when);
  if (d.inSeconds < 90) return l.agoJustNow;
  if (d.inMinutes < 60) return l.agoMinutes(d.inMinutes);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final days = (today.difference(day).inHours / 24).round();
  if (days <= 0) return l.agoHours(d.inHours);
  if (days == 1) return l.discoverPageAgoYesterday;
  if (days < 30) return l.agoDays(days);
  return _date(context, when, now);
}

/// "Oct 12", with the year when it is not this one.
String _date(BuildContext context, DateTime when, DateTime now) {
  final m = MaterialLocalizations.of(context);
  return when.year == now.year
      ? m.formatShortMonthDay(when)
      : m.formatShortDate(when);
}
