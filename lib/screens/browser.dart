import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../widgets/album_grid.dart';
import '../widgets/desktop_toast.dart';
import '../widgets/letter_strip.dart';
import '../widgets/player_panel.dart';
import '../widgets/playlist_name_dialog.dart';
import '../widgets/track_actions_sheet.dart';

import '../util/browse_actions.dart';
import '../util/media_format.dart';
import '../util/server_version.dart';


class Browser extends StatefulWidget {
  const Browser({super.key});

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  // Tap dispatch lives in util/browse_actions.dart, shared with the desktop
  // search page so sectioned results act with byte-identical semantics.
  // This stays as the local name the row builders call.
  void handleTap(
      List<DisplayItem> browserList, int index, BuildContext context) {
    handleBrowseTap(browserList, index, context);
  }

  Widget makeListItem(List<DisplayItem> b, int i, BuildContext c) {
    switch (b[i].type) {
      case "album":
        {
          return makeAlbumWidget(b, i, c);
        }
      case "file":
        {
          return makeFileWidget(b, i, c);
        }
      case "playlist":
        {
          return makePlaylistWidget(b, i, c);
        }
      case "directory":
        {
          return makeFolderWidget(b, i, c);
        }
      case "localDirectory":
        {
          return makeLocalFolderWidget(b, i, c);
        }
      case "localFile":
        {
          return makeLocalFileWidget(b, i, c);
        }
      default:
        {
          return makeBasicWidget(b, i, c);
        }
    }
  }

  // Per-row extent for the browser list, shared by the ListView's
  // itemExtentBuilder AND the letter-strip jump math so a jump lands exactly on
  // the target row — no estimation, no multi-frame settle on long lists.
  // 1-line rows (directories / artists) vs 2-line (albums / files with
  // metadata), mirroring getText/getSubText. max(base, scaled) tracks the text
  // scaler upward so larger accessibility text never clips, while staying at the
  // tuned base at the default (and smaller) text scales.
  static double _rowExtent(DisplayItem it, TextScaler ts) {
    final base =
        (it.metadata?.artist != null || it.subtext != null) ? 74.0 : 58.0;
    final scaled = ts.scale(base);
    return scaled > base ? scaled : base;
  }

  // Full box border for a browse row (web-app style: every item is a bordered
  // box on the flat field). Vertical edges + bottom on every row; top only on
  // the list's first row, so stacked rows share single hairlines instead of
  // doubling up.
  BoxDecoration _rowBoxDecoration(int i) => BoxDecoration(
        border: Border(
          top: i == 0
              ? BorderSide(color: VelvetColors.border2)
              : BorderSide.none,
          left: BorderSide(color: VelvetColors.border2),
          right: BorderSide(color: VelvetColors.border2),
          bottom: BorderSide(color: VelvetColors.border2),
        ),
      );

  Widget makePlaylistWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Material(
      // Same card tone as the file rows — playlists render in the same browse
      // pane, so a transparent row here would read as a different list.
      color: VelvetColors.card,
      child: InkWell(
        onTap: () => handleTap(b, i, c),
        child: Container(
          decoration: _rowBoxDecoration(i),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VelvetColors.raised,
                  borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                child: Icon(Icons.queue_music, color: VelvetColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: VelvetColors.textSecondary),
                color: VelvetColors.surface,
                tooltip: l.mainMore,
                onSelected: (v) {
                  if (v == 'rename') _renamePlaylist(c, b[i]);
                  if (v == 'delete') _deletePlaylist(c, b[i]);
                },
                itemBuilder: (_) => [
                  // Rename is 5.16.0; delete predates the support floor. On an
                  // older server the rename call 404s and surfaces as a
                  // generic playlist error, so drop the item instead of
                  // offering an action that cannot work.
                  if (!playlistRenameKnownUnsupported(
                      ServerVersion.tryParse(b[i].server?.serverVersion)))
                    PopupMenuItem(value: 'rename', child: Text(l.rename)),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l.delete,
                        style: TextStyle(color: VelvetColors.error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Server playlists view: New-playlist button + the playlist rows ──
  Widget _playlistsView(BuildContext context, List<DisplayItem> playlists) {
    final l = AppLocalizations.of(context);
    return Container(
      color: VelvetColors.bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _createPlaylist(context),
                icon: const Icon(Icons.add, size: 20),
                label: Text(l.playlistsNew),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VelvetColors.primary,
                  side: BorderSide(
                      color: VelvetColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(VelvetColors.radiusSmall)),
                ),
              ),
            ),
          ),
          Expanded(
            child: playlists.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.playlistsEmptyTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: BrowserManager().sc,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: playlists.length,
                    itemBuilder: (context, i) =>
                        makePlaylistWidget(playlists, i, context),
                  ),
          ),
        ],
      ),
    );
  }

  // Name-entry dialog shared by create + rename. Returns the trimmed name, or
  // null if cancelled. The controller lives inside PlaylistNameDialog (a
  // StatefulWidget) so it's disposed safely after the dialog closes.
  Future<String?> _playlistNameDialog(BuildContext context,
      {required String title, required String action, String? initial}) {
    return PlaylistNameDialog.show(context,
        title: title, action: action, initial: initial);
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final name = await _playlistNameDialog(context,
        title: l.playlistsNew, action: l.create);
    if (name == null || name.isEmpty) return;
    try {
      await ApiManager().createPlaylist(name);
    } catch (_) {
      if (context.mounted) _playlistError(context);
    }
  }

  Future<void> _renamePlaylist(BuildContext context, DisplayItem item) async {
    final l = AppLocalizations.of(context);
    final name = await _playlistNameDialog(context,
        title: l.playlistsRename, action: l.rename, initial: item.name);
    if (name == null || name.isEmpty || name == item.name) return;
    try {
      await ApiManager().renamePlaylist(item.name, name);
    } catch (_) {
      if (context.mounted) _playlistError(context);
    }
  }

  void _deletePlaylist(BuildContext context, DisplayItem item) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.browserConfirmDeletePlaylist),
        content:
            Text(item.name, style: TextStyle(color: VelvetColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ApiManager()
                  .removePlaylist(item.data!, useThisServer: item.server);
              Navigator.of(ctx).pop();
            },
            child: Text(l.delete, style: TextStyle(color: VelvetColors.error)),
          ),
        ],
      ),
    );
  }

  // Desktop shell up → corner toast (the browser has no Scaffold of its own
  // there). Phone → floating SnackBar so it clears the docked mini-player
  // overlay (a plain bottom snackbar renders behind it).
  void _playlistError(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (DesktopToasts.instance.hasHost) {
      DesktopToasts.instance.show(l.playlistActionFailed);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.playlistActionFailed),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: PlayerPanel.kCollapsedHeight +
            MediaQuery.of(context).viewPadding.bottom +
            8,
      ),
    ));
  }

  Widget makeLocalFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // Same rationale as makeFolderWidget — wrap long names below the
    // letter-strip threshold.
    final allowWrap = !LetterStrip.showsFor(b);
    return Material(
        // Row surface: one tone above the flat pane field (web-app style).
        color: VelvetColors.card,
        child: Container(
            decoration: _rowBoxDecoration(i),
            child: ListTile(
            leading: b[i].icon,
            title: b[i].getText(truncate: !allowWrap),
            subtitle: b[i].getSubText(),
            // The ⋮ menu replaces the old swipe pane + caret: Delete was the
            // pane's only action, and a swipe (or the caret that opened it)
            // has no mouse equivalent on desktop.
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: VelvetColors.textSecondary),
              color: VelvetColors.surface,
              tooltip: l.mainMore,
              onSelected: (v) {
                if (v == 'delete') {
                  showDialog(
                      context: c,
                      builder: (BuildContext context) {
                        return AlertDialog(
                            title: Text(l.browserConfirmDeleteFolder),
                            content: b[i].getText(),
                            actions: <Widget>[
                              TextButton(
                                child: Text(l.goBack),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                  child: Text(
                                    l.delete,
                                    style: TextStyle(color: VelvetColors.error),
                                  ),
                                  onPressed: () {
                                    FileExplorer().deleteDirectory(
                                        b[i].data!, b[i].server);
                                    Navigator.of(context).pop();
                                  })
                            ]);
                      });
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.delete,
                      style: TextStyle(color: VelvetColors.error)),
                ),
              ],
            ),
            onTap: () {
              handleTap(b, i, c);
            })));
  }

  Widget makeLocalFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    final allowWrap = !LetterStrip.showsFor(b);
    return Material(
        // Row surface: one tone above the flat pane field (web-app style).
        color: VelvetColors.card,
        child: Container(
            decoration: _rowBoxDecoration(i),
            child: ListTile(
            leading: b[i].icon,
            title: b[i].getText(truncate: !allowWrap),
            subtitle: b[i].getSubText(),
            // The ⋮ menu carries both destinations the old swipe pane and
            // caret split between them: the track sheet (rate / queue / find
            // similar) and Delete — so every action is mouse-reachable.
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: VelvetColors.textSecondary),
              color: VelvetColors.surface,
              tooltip: l.mainMore,
              onSelected: (v) {
                if (v == 'actions') {
                  _showTrackActions(b[i], c);
                } else if (v == 'delete') {
                  FileExplorer().deleteFile(b[i].data!, b[i].server);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'actions', child: Text(l.browserMoreActions)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.delete,
                      style: TextStyle(color: VelvetColors.error)),
                ),
              ],
            ),
            // Same long-press context sheet as server rows — the queue
            // actions apply to local files too (Find similar hides
            // itself: a local path can't seed the similarity index).
            onLongPress: () => _showTrackActions(b[i], c),
            onTap: () {
              handleTap(b, i, c);
            })));
  }

  Widget makeFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // Below the letter-strip threshold there's no strip math to keep
    // uniform — let long folder names wrap and show in full. Smaller
    // folders tend to have longer / more descriptive names.
    final allowWrap = !LetterStrip.showsFor(b);
    return Material(
        // Row surface: one tone above the flat pane field (web-app style).
        color: VelvetColors.card,
        child: Container(
            decoration: _rowBoxDecoration(i),
            child: ListTile(
            // Long-press = this row's actions, the same convention the track
            // rows use (touch); the ⋮ menu is the same reach for a mouse.
            onLongPress: () => _showFolderActions(b[i], c),
            leading: b[i].icon,
            title: b[i].getText(truncate: !allowWrap),
            subtitle: b[i].getSubText(),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: VelvetColors.textSecondary),
              color: VelvetColors.surface,
              tooltip: l.mainMore,
              onSelected: (v) {
                if (v == 'addAll') {
                  ApiManager().getRecursiveFiles(b[i].data!,
                      useThisServer: b[i].server);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'addAll', child: Text(l.addAll)),
              ],
            ),
            onTap: () {
              handleTap(b, i, c);
            })));
  }

  // Album list rows. Unlike makeBasicWidget, the leading is a FIXED-size
  // thumbnail (cover art or a same-size placeholder) so the title/subtitle
  // start at the same x whether or not a row has art — getImage() returns a
  // full-height image for art rows but a tiny Icon for the rest, which
  // misaligns the text.
  Widget makeAlbumWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Material(
        // Row surface: one tone above the flat pane field (web-app style).
        color: VelvetColors.card,
        child: Container(
            decoration: _rowBoxDecoration(i),
            child: ListTile(
            leading: b[i].getAlbumThumb(),
            title: b[i].getText(l: l),
            subtitle: b[i].getSubText(l: l),
            onTap: () {
              handleTap(b, i, c);
            })));
  }

  Widget makeBasicWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Material(
        // Row surface: one tone above the flat pane field (web-app style).
        color: VelvetColors.card,
        child: Container(
            decoration: _rowBoxDecoration(i),
            child: ListTile(
            leading: b[i].getImage(),
            title: b[i].getText(l: l),
            subtitle: b[i].getSubText(l: l),
            onTap: () {
              handleTap(b, i, c);
            })));
  }

  // ── Default browser landing: section shortcuts as a card grid ──
  //
  // Cards sit on VelvetColors.card, the token the palette has always defined
  // and this screen never used: face and page were both `surface`, so a card
  // was a 1px border around nothing and the grid read flat. On the real
  // surface the border is redundant and gone.
  //
  // Laid out as rows rather than a GridView because an odd item count left
  // the last card stranded beside a hole — the trailing one spans the row
  // instead. IntrinsicHeight pairs each row to its taller card, so a row is
  // as tall as its content needs and no taller: with a fixed aspect ratio the
  // card height fell out of the screen WIDTH, which on a narrow phone (or at
  // a large text scale) squeezed the tile and label into less room than they
  // occupy and overflowed.
  Widget _homeView(BuildContext context, List<DisplayItem> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final pair = items.skip(i).take(2).toList();
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : _homeCardGap),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < pair.length; j++) ...[
                if (j > 0) SizedBox(width: _homeCardGap),
                Expanded(child: _homeCard(context, items, i + j)),
              ],
            ],
          ),
        ),
      ));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      children: rows,
    );
  }

  static const double _homeCardGap = 10;

  Widget _homeCard(BuildContext context, List<DisplayItem> items, int i) {
    final l = AppLocalizations.of(context);
    final item = items[i];
    final iconData = item.icon?.icon ?? Icons.chevron_right;
    return Material(
      color: VelvetColors.card,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => handleTap(items, i, context),
        child: Padding(
          // Tighter vertically than horizontally: the vertical axis is the one
          // that runs out first, and the tile already carries its own visual
          // padding around the icon.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: VelvetColors.primaryDim,
                  borderRadius:
                      BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                child: Icon(iconData, color: VelvetColors.primary, size: 22),
              ),
              Text(
                browserChromeLabel(l, item.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Long-press sheet for a folder row: the one thing you can do to a folder
  /// without opening it. Same sheet shape as the track one so a long-press
  /// means the same thing everywhere in the browser.
  void _showFolderActions(DisplayItem item, BuildContext c) {
    final l = AppLocalizations.of(c);
    showModalBottomSheet(
      context: c,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(children: [
                Icon(Icons.folder, color: VelvetColors.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary),
                  ),
                ),
              ]),
            ),
            Divider(color: VelvetColors.border, height: 17),
            ListTile(
              leading: Icon(Icons.library_add, color: VelvetColors.primary),
              title: Text(l.addAll,
                  style: TextStyle(color: VelvetColors.textPrimary)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                ApiManager().getRecursiveFiles(item.data!,
                    useThisServer: item.server);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Long-press context sheet for track rows: the album-detail queue actions
  // (Add next / Play now / Add to end) plus Find similar when the track's
  // server supports discovery. Long-press = item context menu is the
  // convention everywhere (Apple Music / Spotify / Symfonium).
  void _showTrackActions(DisplayItem item, BuildContext c) =>
      showTrackActionsSheet(c, item);

  Widget makeFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    // Same wrap-on-small-list rule as folders: below the letter-strip
    // threshold there's no uniform-row constraint, so long song names
    // get to show in full.
    final allowWrap = !LetterStrip.showsFor(b);
    return Container(
        decoration: _rowBoxDecoration(i),
        child: Material(
            // Rows sit one tone above the pane backdrop (card > bg) so the
            // content zone gets its own hierarchy, dark-theme-style, instead
            // of leaning on the hairline borders alone.
            color: VelvetColors.card,
            child: InkWell(
                splashColor: VelvetColors.primaryDim,
                // Nothing for an .m3u: the track sheet rates, queues and finds
                // similar music for the row it opens on, and none of that
                // means anything for a playlist file.
                //
                // A no-op rather than null, deliberately. With no long-press
                // recognizer the tap one wins and fires on release however
                // long the press was, so `null` made holding an .m3u OPEN it
                // — measured, not assumed. An empty handler claims the
                // gesture and the press ends where it started: nothing.
                onLongPress: isM3u(b[i].data)
                    ? () {}
                    : () => _showTrackActions(b[i], c),
                child: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                      SizedBox(
                        width: 4,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            // value: displayList[index].downloadProgress/100,
                            // Index against the passed list `b` (the
                            // possibly search-filtered view), not the
                            // manager's unfiltered browserList — otherwise
                            // the bar reads the wrong row while searching.
                            value: b[i].downloadProgress / 100,
                            valueColor: AlwaysStoppedAnimation(
                                VelvetColors.success),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      Expanded(
                          child: ListTile(
                              leading: b[i].getImage(),
                              title: b[i].getText(truncate: !allowWrap),
                              subtitle: b[i].getSubText(),
                              // No trailing control: it sat exactly where
                              // the letter strip lands, and long-press opens
                              // the same sheet.
                              onTap: () {
                                handleTap(b, i, c);
                              }))
                    ])))));
  }

  // In-flow context strip under the toolbar: the query on a search-results list,
  // or the current directory in the file explorer. Both are persistent context
  // for their view (tracked per stack frame, so they revert on back-nav). The
  // transient search-scope preview is a separate slide-over overlay so it
  // doesn't shove the list down — see _searchScopePreview.
  Widget _browserSubheader(BuildContext context, AppLocalizations l) {
    return StreamBuilder<List<DisplayItem>>(
      stream: BrowserManager().browserListStream,
      builder: (context, _) {
        final term = BrowserManager().currentSearchTerm;
        if (term != null) {
          return _subheaderStrip(Icons.search, l.searchSubheaderResults(term));
        }
        final path = BrowserManager().currentPath;
        if (path != null) {
          return _subheaderStrip(
              Icons.folder_outlined, path.isEmpty ? '/' : path,
              mono: true);
        }
        final playlist = BrowserManager().currentPlaylist;
        if (playlist != null) {
          // Same strip the file explorer uses for its path — the toolbar no
          // longer carries a label on this view, so this is what names it.
          return _subheaderStrip(Icons.queue_music, playlist);
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Transient search-scope preview that SLIDES OVER the list (rather than
  // pushing it down) while the home search field is focused, so the user can
  // see — and fix — a stale category selection before typing. Driven by
  // BrowserManager.searchFocused; wrapped in IgnorePointer so it never blocks
  // taps on the list beneath it.
  Widget _searchScopePreview(BuildContext context, AppLocalizations l) {
    return IgnorePointer(
      child: StreamBuilder<bool>(
        stream: BrowserManager().searchFocusedStream,
        initialData: BrowserManager().searchFocused,
        builder: (context, focusSnap) {
          return ClipRect(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              offset:
                  (focusSnap.data ?? false) ? Offset.zero : const Offset(0, -1),
              child: StreamBuilder<Set<SearchCategory>>(
                stream: SettingsManager().searchCategoriesStream,
                initialData: SettingsManager().searchCategories,
                builder: (context, catSnap) {
                  final cats =
                      catSnap.data ?? SettingsManager().searchCategories;
                  final names = SearchCategory.values
                      .where(cats.contains)
                      .map((c) => c.label(l))
                      .join(' · ');
                  return _subheaderStrip(
                      Icons.manage_search, l.searchSubheaderCategories(names));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _subheaderStrip(IconData icon, String text, {bool mono = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 12, 5),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: VelvetColors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: mono ? 'monospace' : null,
                fontSize: 11.5,
                color: VelvetColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Stack(children: <Widget>[
      Column(children: <Widget>[
      // In-flow context strip under the toolbar (search term / file path) —
      // see _browserSubheader.
      _browserSubheader(context, l),
      // Thin indeterminate bar while any browser server call is in
      // flight (all go through ApiManager.makeServerCall). Fixed 3px
      // slot — empty when idle — so the list never jumps.
      StreamBuilder<bool>(
        stream: BrowserManager().loadingStream,
        initialData: BrowserManager().isLoading,
        builder: (context, snap) {
          final loading = snap.data ?? false;
          return SizedBox(
            height: 3,
            child: loading
                ? LinearProgressIndicator(
                    minHeight: 3,
                    color: VelvetColors.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          );
        },
      ),
      Expanded(
          child: SizedBox(
              child: StreamBuilder<List<DisplayItem>>(
                  stream: BrowserManager().browserListStream,
                  builder: (context, snapshot) {
                    final List<DisplayItem> rawList = snapshot.data ?? [];

                    // Local search filters only the *displayed* list; the
                    // manager's browserList (hence navigation / back-stack
                    // / scroll restore) is untouched. The execAction home
                    // menu is fixed section shortcuts, not content, so it
                    // is never filtered.
                    final bool isHome = rawList.isNotEmpty &&
                        rawList[0].type == 'execAction';
                    // Search state lives in BrowserManager (the top toolbar owns
                    // the field) and re-emits this list on every change, so
                    // reading it synchronously here re-filters live.
                    final search = BrowserManager().search;
                    final String q = search.query.trim();
                    final bool filtering =
                        search.open && q.isNotEmpty && !isHome;
                    final List<DisplayItem> browserList = filtering
                        ? rawList.where((it) => it.matchesQuery(q)).toList()
                        : rawList;

                    // A section load is pending (launch startup view, or a
                    // desktop server switch): hold a spinner over every interim
                    // state — empty list, home menu, placeholder — until the
                    // setter clears the flag. First so nothing below can flash
                    // mid-load; whoever set the flag re-emits on completion and
                    // the pane settles on the loaded section, the empty state,
                    // or (after a failure) the offline placeholder.
                    if (BrowserManager().awaitingSectionLoad) {
                      return Center(
                        child: CircularProgressIndicator(
                            color: VelvetColors.primary),
                      );
                    }

                    if (filtering && browserList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l.browserNoMatches(q),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 14),
                          ),
                        ),
                      );
                    }

                    final bool isDesktop = Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS;

                    // The default browser landing (section shortcuts). On desktop
                    // the home grid just duplicates the sidebar, so show the
                    // placeholder (which points at the sidebar) instead — this is
                    // also where an offline current server lands once its startup
                    // section fails to load.
                    if (isHome) {
                      return isDesktop
                          ? const _DesktopBrowsePlaceholder()
                          : _homeView(context, browserList);
                    }

                    // Desktop: a root-level empty pane (browserCache <= 1) means no
                    // section is loaded — typically the current server is offline —
                    // so show the placeholder rather than a blank list. An empty
                    // list *inside* a loaded folder (browserCache > 1) is a real
                    // empty folder and falls through to the normal list below.
                    if (isDesktop &&
                        browserList.isEmpty &&
                        BrowserManager().browserCache.length <= 1) {
                      return const _DesktopBrowsePlaceholder();
                    }

                    // An open playlist with nothing in it. Without this the
                    // user gets a blank screen that's indistinguishable from
                    // a failed load. Keyed off the frame's playlist name, so
                    // an empty FOLDER is unaffected.
                    if (browserList.isEmpty &&
                        BrowserManager().currentPlaylist != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l.playlistEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: VelvetColors.textTertiary,
                                fontSize: 14),
                          ),
                        ),
                      );
                    }

                    // The server "Playlists" view gets its own layout: a New-
                    // playlist button + modern rows with a rename/delete menu.
                    // Detected by item type ('playlist'); the empty-list case is
                    // keyed off the section label.
                    final isPlaylistView =
                        browserList.every((e) => e.type == 'playlist') &&
                            (browserList.isNotEmpty ||
                                BrowserManager().listName == 'Playlists');
                    if (isPlaylistView) {
                      return _playlistsView(context, browserList);
                    }

                    // A loaded but EMPTY listing — e.g. the File Explorer root
                    // of a server with no music folders configured yet (the
                    // bundled server before setup), or an empty directory. An
                    // explicit empty state instead of a blank pane; the server
                    // answered, so the offline placeholder would be wrong here.
                    if (browserList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l.browserEmptyList,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 14),
                          ),
                        ),
                      );
                    }

                    // If the whole list is albums and the user has the
                    // album-grid setting on, show a grid of album cards
                    // instead of the plain list.
                    final allAlbums = browserList.isNotEmpty &&
                        browserList.every((e) => e.type == 'album');
                    return StreamBuilder<bool>(
                      stream: SettingsManager().albumGridStream,
                      initialData: SettingsManager().albumGrid,
                      builder: (context, gridSnap) {
                        final useGrid = (gridSnap.data ?? true) && allAlbums;
                        final ts = MediaQuery.textScalerOf(context);
                        // Reserve the strip's width only when the strip will
                        // actually be there — the same three conditions the
                        // overlay below uses, plus the strip's own
                        // will-I-render check. Otherwise a list short enough
                        // to hide the strip would still get an empty gutter.
                        final stripShowing = BrowserManager().isAlphabetical &&
                            browserList.isNotEmpty &&
                            !filtering &&
                            LetterStrip.showsFor(browserList);
                        // Desktop shows the strip as a row ABOVE the list, so
                        // no side gutter is reserved there.
                        final horizontalStrip = Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS;
                        final gutter = stripShowing && !horizontalStrip
                            ? LetterStrip.gutterWidth
                            : 0.0;
                        final stripOnLeft = LetterStrip.onLeft;
                        final Widget content = useGrid
                            ? AlbumGrid(
                                items: browserList,
                                gutter: gutter,
                                // Pass the shared controller so the
                                // letter-strip's jumpTo actually
                                // moves the grid (and so the existing
                                // scroll-restore logic works in grid
                                // mode too).
                                controller: BrowserManager().sc,
                                onTap: (i) =>
                                    handleTap(browserList, i, context),
                              )
                            // ListTileTheme override so the browser's rows
                            // are denser than the global ListTile
                            // default — gains ~26px of horizontal
                            // space for the title (less truncation)
                            // without affecting Settings/About/etc.
                            // (.merge, not a full Theme copyWith, so a
                            // list rebuild doesn't allocate a whole
                            // ThemeData — see the download-tick rebuilds.)
                            //   contentPadding: 16 -> 10 (saves 12)
                            //   horizontalTitleGap: 16 -> 10 (saves 6)
                            //   minLeadingWidth: 40 -> 32 (saves 8)
                            // Heights are unchanged by these knobs,
                            // so the letter-scrub cumulative math
                            // stays correct.
                            : ListTileTheme.merge(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                horizontalTitleGap: 10,
                                minLeadingWidth: 32,
                                // The gutter is padding on the LIST, not on
                                // the rows' contents: a row draws its own
                                // bottom border across its full width, so
                                // insetting only the content left the divider
                                // running on under the strip.
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      left: stripOnLeft ? gutter : 0,
                                      right: stripOnLeft ? 0 : gutter),
                                  child: ListView.builder(
                                    controller: BrowserManager().sc,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: browserList.length,
                                    // Known per-row extents give the sliver O(1)
                                    // seek, so the letter-strip jumpTo lands
                                    // instantly instead of estimating + settling
                                    // over frames on long lists (the scrub lag).
                                    // Rows already draw their own bottom border,
                                    // so the old Divider separator is dropped.
                                    // See _rowExtent.
                                    itemExtentBuilder: (index, _) =>
                                        _rowExtent(browserList[index], ts),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      if (browserList.isEmpty) {
                                        return Container();
                                      }
                                      return makeListItem(
                                          browserList, index, context);
                                    }),
                                ),
                              );

                        // Only overlay the letter scrubber for views
                        // the server sorts alphabetically (Albums,
                        // Artists, File Explorer) — see BrowserManager
                        // .alphabeticalCache. `stripShowing` carries the
                        // strip's own will-I-render check too, so the rule
                        // below can never be drawn beside nothing.
                        if (!stripShowing) {
                          return content;
                        }
                        void onJump(int i) {
                          final sc = BrowserManager().sc;
                          if (!sc.hasClients) return;
                          final double offset;
                          if (useGrid) {
                            final w = MediaQuery.of(context).size.width;
                            final cols = AlbumGrid.columnsFor(w, gutter);
                            final rowH = AlbumGrid.rowHeightFor(w, gutter);
                            final row = i ~/ cols;
                            offset = AlbumGrid.padTop +
                                row * (rowH + AlbumGrid.spacing);
                          } else {
                            // Sum the SAME per-row extents the ListView lays out
                            // with (see _rowExtent) so the jump lands exactly on
                            // the target row. File Explorer mixes 1- and 2-line
                            // rows, hence the walk-and-sum. O(i), microseconds
                            // even at 10k+ items.
                            double sum = 0;
                            final stop = i.clamp(0, browserList.length);
                            for (var k = 0; k < stop; k++) {
                              sum += _rowExtent(browserList[k], ts);
                            }
                            offset = sum;
                          }
                          sc.jumpTo(offset
                              .clamp(0.0, sc.position.maxScrollExtent)
                              .toDouble());
                        }

                        // Jump to the first item in a letter's section — the
                        // shared target for the letter row and type-to-jump.
                        void onLetter(String letter) {
                          for (var k = 0; k < browserList.length; k++) {
                            if (LetterStrip.indexLetter(browserList[k]) ==
                                letter) {
                              onJump(k);
                              return;
                            }
                          }
                        }

                        // Desktop: a clickable letter row above the list, plus
                        // type-to-jump (press a letter to jump to its section).
                        // Mobile: the vertical strip overlaid on the right edge
                        // (finger-drag).
                        if (horizontalStrip) {
                          return _TypeToJump(
                            onLetter: onLetter,
                            child: Column(
                              children: [
                                LetterStrip(
                                  items: browserList,
                                  axis: Axis.horizontal,
                                  onJump: onJump,
                                ),
                                Expanded(child: content),
                              ],
                            ),
                          );
                        }
                        return Stack(
                          children: [
                            content,
                            // A hairline between the rows and the strip, in
                            // the row divider's own colour so the two read as
                            // one grid. Drawn here rather than as a border on
                            // the strip: the strip's visible pill is rounded
                            // and only as tall as its letters, and this has to
                            // run the full height of the list.
                            Positioned(
                              left: stripOnLeft
                                  ? LetterStrip.stripWidth
                                  : null,
                              right: stripOnLeft
                                  ? null
                                  : LetterStrip.stripWidth,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                  width: 1, color: VelvetColors.border),
                            ),
                            Positioned(
                              left: stripOnLeft ? 0 : null,
                              right: stripOnLeft ? null : 0,
                              top: 0,
                              bottom: 0,
                              child: LetterStrip(
                                items: browserList,
                                onJump: onJump,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  })))
      ]),
      // Slide-over search-scope preview over the top of the list (focus-driven).
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _searchScopePreview(context, l),
      ),
    ]);
  }
}

// Desktop type-to-jump: while the browse list holds focus, pressing a letter (or
// digit → '#') jumps to that A–Z section — the keyboard companion to the letter
// row. Requests focus on mount; typing in the search field (which isn't a
// descendant) keeps its own focus, so letters there type normally.
class _TypeToJump extends StatefulWidget {
  final Widget child;
  final void Function(String letter) onLetter;
  const _TypeToJump({required this.child, required this.onLetter});

  @override
  State<_TypeToJump> createState() => _TypeToJumpState();
}

class _TypeToJumpState extends State<_TypeToJump> {
  final FocusNode _node = FocusNode(debugLabel: 'browserTypeToJump');

  @override
  void initState() {
    super.initState();
    // Arm type-to-jump on mount, but DON'T steal focus from an active text
    // field — notably the search box, which remounts this widget when cleared
    // back to empty (filtering → browse). Only grab focus when nothing specific
    // is focused yet, so clearing the search keeps its caret until you click away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = FocusManager.instance.primaryFocus;
      if (focused == null || focused is FocusScopeNode) {
        _node.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Leave modifier chords (Ctrl+F, ⌘A, …) to their shortcuts.
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final ch = event.character;
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;
    final code = ch.toUpperCase().codeUnitAt(0);
    if (code >= 0x41 && code <= 0x5A) {
      widget.onLetter(ch.toUpperCase());
      return KeyEventResult.handled;
    }
    if (code >= 0x30 && code <= 0x39) {
      widget.onLetter('#');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(focusNode: _node, onKeyEvent: _onKey, child: widget.child);
  }
}

// Desktop stand-in for the browser home grid (which duplicates the sidebar). Shown
// when nothing is loaded — usually because the current server is offline and the
// startup section couldn't load. Points at the sidebar rather than the old menu.
class _DesktopBrowsePlaceholder extends StatelessWidget {
  const _DesktopBrowsePlaceholder();

  @override
  Widget build(BuildContext context) {
    final server = ServerManager().currentServer;
    return _offline(noServer: server == null);
  }

  Widget _offline({required bool noServer}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(noServer ? Icons.dns_outlined : Icons.travel_explore_outlined,
                size: 48, color: VelvetColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              noServer ? 'No server connected' : 'Nothing loaded',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              noServer
                  ? 'Add or select a server from the sidebar to start browsing.'
                  : 'The current server may be offline. Pick a section — or a '
                      'different server — from the sidebar.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: VelvetColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
