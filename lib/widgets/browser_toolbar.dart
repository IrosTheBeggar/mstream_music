// browser_toolbar.dart — the consolidated chrome that lives in the AppBar's
// bottom slot (replacing the old label-only strip AND the Browser's in-body
// header row). One context-aware bar frees the vertical space those two used to
// take and lets the album detail view drop its own back/overflow.
//
// Contexts (driven by BrowserManager streams):
//   • album detail open → back · album name · download · add-all
//   • local search open → close · filter field
//   • home (section list) → the "search the whole server" field
//   • normal list        → back · label · search · download · add-all
//
// Search state lives in BrowserManager (the body does the filtering); the
// download / add-all actions operate on the current list — the album's loaded
// songs when the detail view is up, otherwise the browser list.

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../objects/display_item.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/downloads.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import 'local_search_bar.dart';

// Combined snapshot the toolbar renders from.
typedef _Tb = ({
  DisplayItem? album,
  ({bool open, String query}) search,
  String label,
  List<DisplayItem> list,
});

class BrowserToolbar extends StatefulWidget implements PreferredSizeWidget {
  const BrowserToolbar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  State<BrowserToolbar> createState() => _BrowserToolbarState();
}

class _BrowserToolbarState extends State<BrowserToolbar> {
  late final Stream<_Tb> _stream = Rx.combineLatest4<
      DisplayItem?,
      ({bool open, String query}),
      String,
      List<DisplayItem>,
      _Tb>(
    BrowserManager().albumDetailStream,
    BrowserManager().searchStream,
    BrowserManager().browserLabelStream,
    BrowserManager().browserListStream,
    (album, search, label, list) =>
        (album: album, search: search, label: label, list: list),
  );

  // Files in [all] that can be downloaded (server files only), de-noised of
  // playlists. Album songs and browse rows both flow through here.
  List<DisplayItem> _downloadable(List<DisplayItem> all) => all
      .where((e) =>
          e.type == 'file' &&
          e.server != null &&
          e.data != null &&
          !e.data!.toLowerCase().endsWith('.m3u'))
      .toList();

  // Playable rows for add-all (server + local files), minus playlists.
  List<DisplayItem> _enqueueable(List<DisplayItem> all) => all
      .where((e) =>
          (e.type == 'file' || e.type == 'localFile') &&
          e.data != null &&
          !e.data!.toLowerCase().endsWith('.m3u'))
      .toList();

  // Mirrors the old browser "Download all": confirm the count, then enqueue
  // downloads (downloadOneFile no-ops on files already on disk).
  void _downloadAll(BuildContext context, List<DisplayItem> all) {
    final l = AppLocalizations.of(context);
    final files = _downloadable(all);
    if (files.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.browserNothingToDownload)));
      return;
    }
    final n = files.length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.browserDownloadAllTitle),
        content: Text(l.browserDownloadAllConfirm(n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              for (final e in files) {
                final downloadUrl = e.server!.url +
                    '/media' +
                    e.data! +
                    (e.server!.jwt == null ? '' : '?token=' + e.server!.jwt!);
                DownloadManager().downloadOneFile(
                    downloadUrl, e.server!.localname, e.data!,
                    referenceItem: e);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.browserDownloadsStarted(n))));
            },
            child: Text(l.download),
          ),
        ],
      ),
    );
  }

  Future<void> _addAll(BuildContext context, List<DisplayItem> all) async {
    final l = AppLocalizations.of(context);
    final n = await addRowsToQueue(_enqueueable(all));
    if (!context.mounted || n == 0) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.browserSongsAdded(n))));
  }

  // The list the download / add-all actions act on right now.
  List<DisplayItem> get _actionTargets => BrowserManager().albumDetail != null
      ? (BrowserManager().albumDetailSongs ?? const [])
      : BrowserManager().browserList;

  Widget _icon(IconData icon, String tooltip, VoidCallback onTap) => IconButton(
        icon: Icon(icon, size: 22),
        color: VelvetColors.appBarTextSecondary,
        tooltip: tooltip,
        onPressed: onTap,
      );

  Widget _title(String text) => Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: VelvetColors.appBarText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: widget.preferredSize.height,
      child: StreamBuilder<_Tb>(
        stream: _stream,
        initialData: (
          album: BrowserManager().albumDetail,
          search: BrowserManager().search,
          label: BrowserManager().listName,
          list: BrowserManager().browserList,
        ),
        builder: (context, snap) {
          final s = snap.data!;
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: _content(context, l, s),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l, _Tb s) {
    // Album detail: back · name · download · add-all (Play/Shuffle stay in the
    // banner). Acts on the album's loaded songs.
    if (s.album != null) {
      return Row(children: [
        _icon(Icons.arrow_back, l.goBack,
            () => BrowserManager().closeAlbumDetail()),
        _title(s.album!.name),
        _icon(Icons.download_sharp, l.download,
            () => _downloadAll(context, _actionTargets)),
        _icon(Icons.library_add, l.addAll,
            () => _addAll(context, _actionTargets)),
      ]);
    }

    // Local search active: close · live filter field.
    if (s.search.open) {
      return Row(children: [
        _icon(Icons.close, l.browserCloseSearch,
            () => BrowserManager().closeSearch()),
        Expanded(
          child: LocalSearchBar(
            key: const ValueKey('browser-search'),
            hintText: l.browserSearchThisList,
            onChanged: BrowserManager().setSearchQuery,
          ),
        ),
        const SizedBox(width: 4),
      ]);
    }

    // Home section list: the "search the whole server" field.
    final isHome = s.list.isNotEmpty && s.list[0].type == 'execAction';
    if (isHome) {
      return Row(children: [
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            textInputAction: TextInputAction.search,
            onSubmitted: (text) => ApiManager().searchServer(text),
            style: TextStyle(color: VelvetColors.appBarText, fontSize: 15),
            cursorColor: VelvetColors.primary,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixIcon:
                  Icon(Icons.search, color: VelvetColors.appBarTextSecondary),
              hintText: l.browserSearchHint,
              hintStyle: TextStyle(color: VelvetColors.appBarTextSecondary),
            ),
          ),
        ),
      ]);
    }

    // Normal list: back (when there's somewhere to go) · label · search ·
    // download · add-all.
    final canBack = BrowserManager().browserCache.length > 1;
    return Row(children: [
      if (canBack)
        _icon(Icons.arrow_back, l.goBack, () {
          BrowserManager().closeSearch();
          BrowserManager().popBrowser();
        })
      else
        const SizedBox(width: 12),
      _title(browserChromeLabel(l, s.label)),
      _icon(Icons.search, l.browserSearchList,
          () => BrowserManager().openSearch()),
      _icon(Icons.download_sharp, l.download,
          () => _downloadAll(context, _actionTargets)),
      _icon(Icons.library_add, l.addAll,
          () => _addAll(context, _actionTargets)),
    ]);
  }
}
