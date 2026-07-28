import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../singletons/settings.dart';
import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../widgets/album_grid.dart';
import '../widgets/letter_strip.dart';
import '../widgets/player_panel.dart';
import '../widgets/playlist_name_dialog.dart';
import '../widgets/star_rating.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../widgets/track_actions_sheet.dart';

import '../singletons/media.dart';
import '../util/queue_actions.dart';

import 'add_server.dart';

class Browser extends StatefulWidget {
  const Browser({super.key});

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  // Item types whose tap loads a new list (vs. file/localFile, which
  // just enqueue and leave the current list in place). Tapping any of
  // these closes local search.
  static const Set<String> _navTypes = {
    'addServer',
    'directory',
    'playlist',
    'execAction',
    'artist',
    'album',
    'localDirectory',
  };

  void handleTap(
      List<DisplayItem> browserList, int index, BuildContext context) {
    // A browse fetch is already in flight — ignore taps until it resolves (or
    // is cancelled with Back). Without this, tapping a second folder before the
    // first finished kicked off a racing request and the screen showed whichever
    // returned last. addServer stays actionable (the no-server screen never has
    // a load in flight, but never lock the user out of adding a server).
    if (BrowserManager().isLoading &&
        browserList[index].type != 'addServer') {
      return;
    }

    if (_navTypes.contains(browserList[index].type)) {
      BrowserManager().closeSearch();
    }

    if (browserList[index].type == 'addServer') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddServerScreen()),
      );
      return;
    }

    if (browserList[index].type == 'directory') {
      ApiManager().getFileList(browserList[index].data ?? '',
          useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'playlist') {
      ApiManager().getPlaylistContents(browserList[index].data ?? '',
          useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'playlists') {
      ApiManager().getPlaylists(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'fileExplorer') {
      ApiManager().getFileList("~", useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'recent') {
      ApiManager().getRecentlyAdded(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'rated') {
      ApiManager().getRated(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'albums') {
      ApiManager().getAlbums(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'localFiles') {
      FileExplorer().getPathForServer(browserList[index].server!);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'artists') {
      ApiManager().getArtists(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'artist') {
      ApiManager().getArtistAlbums(browserList[index].data ?? '',
          useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'album') {
      // Open the album detail over the browser body (no route) — keeps the
      // file-explorer model and the mini-player visible. See main.dart's
      // IndexedStack and BrowserManager.albumDetail.
      BrowserManager().openAlbumDetail(browserList[index]);
      return;
    }

    if (browserList[index].type == 'file') {
      if (SettingsManager().tapBehavior == TapBehavior.playFromHere) {
        _playFromHere(browserList, index);
      } else {
        addFile(browserList[index]);
      }
      return;
    }

    if (browserList[index].type == 'localDirectory') {
      FileExplorer()
          .getLocalFiles(browserList[index].data, browserList[index].server!);
      return;
    }

    if (browserList[index].type == 'localFile') {
      if (SettingsManager().tapBehavior == TapBehavior.playFromHere) {
        _playFromHere(browserList, index);
      } else {
        addLocalFile(browserList[index]);
      }
      return;
    }
  }

  // Side-effect entry points. Build the MediaItem then run it through
  // _enqueue, which applies the user's tap behavior preference.
  Future<void> addLocalFile(DisplayItem i) async {
    await _enqueue(buildLocalFileMediaItem(i));
  }

  Future<void> addFile(DisplayItem i) async {
    final item = await buildServerFileMediaItem(i);
    if (item != null) await _enqueue(item);
  }

  // Adds the item to the queue, then dispatches on the user's tap
  // behavior preference. Pattern A (playFromHere) doesn't reach here
  // — it's handled directly in handleTap because it needs the
  // surrounding browser context to know what to fill the queue with.
  Future<void> _enqueue(MediaItem item) async {
    final wasEmpty = MediaManager().audioHandler.queue.value.isEmpty;
    await MediaManager().audioHandler.addQueueItem(item);

    switch (SettingsManager().tapBehavior) {
      case TapBehavior.addToQueue:
        // Convenience: first tap from a fresh state shouldn't require
        // a separate Play press to actually start anything.
        if (wasEmpty) {
          await MediaManager().audioHandler.play();
        }
        break;
      case TapBehavior.appendAndJump:
        final queueLen = MediaManager().audioHandler.queue.value.length;
        await MediaManager().audioHandler.skipToQueueItem(queueLen - 1);
        await MediaManager().audioHandler.play();
        break;
      case TapBehavior.playFromHere:
        // Unreachable — see handleTap.
        break;
    }
  }

  // Pattern A: clear the queue, fill it with every playable item from the
  // current browser view (in order), jump to the tapped one, play. Delegates to
  // the shared helper (util/queue_actions.dart) so the album-detail screen plays
  // albums with identical semantics.
  Future<void> _playFromHere(List<DisplayItem> browserList, int tappedIndex) =>
      playFromHere(browserList, tappedIndex);

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

  Widget makePlaylistWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => handleTap(b, i, c),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: VelvetColors.border, width: 0.5)),
          ),
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

  // Floating so it clears the docked mini-player overlay (a plain bottom
  // snackbar renders behind it).
  void _playlistError(BuildContext context) {
    final l = AppLocalizations.of(context);
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
    final allowWrap = b.length < LetterStrip.minItemsToShow;
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Slidable(
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              children: [
                SlidableAction(
                    backgroundColor: Colors.red,
                    icon: Icons.delete,
                    label: l.delete,
                    onPressed: (context) {
                      showDialog(
                          context: c,
                          builder: (BuildContext context) {
                            return AlertDialog(
                                title: Text(l.browserConfirmDeleteFolder),
                                content: b[i].getText(),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text(l.goBack),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                      child: Text(
                                        l.delete,
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () {
                                        FileExplorer().deleteDirectory(
                                            b[i].data!, b[i].server);
                                        Navigator.of(context).pop();
                                      })
                                ]);
                          });
                    })
              ],
            ),
            child: Builder(
              builder: (context) => ListTile(
                  leading: b[i].icon,
                  title: b[i].getText(truncate: !allowWrap),
                  subtitle: b[i].getSubText(),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_left,
                      size: 20.0,
                      color: Colors.brown[900],
                    ),
                    onPressed: () {
                      Slidable.of(context)?.openEndActionPane();
                    },
                  ),
                  onTap: () {
                    handleTap(b, i, c);
                  }),
            )));
  }

  Widget makeLocalFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    final allowWrap = b.length < LetterStrip.minItemsToShow;
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Slidable(
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              children: [
                SlidableAction(
                    backgroundColor: Colors.red,
                    icon: Icons.delete,
                    label: l.delete,
                    onPressed: (context) {
                      FileExplorer().deleteFile(b[i].data!, b[i].server);
                    })
              ],
            ),
            child: Builder(
              builder: (context) => ListTile(
                  leading: b[i].icon,
                  title: b[i].getText(truncate: !allowWrap),
                  subtitle: b[i].getSubText(),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_left,
                      size: 20.0,
                      color: Colors.brown[900],
                    ),
                    onPressed: () {
                      Slidable.of(context)?.openEndActionPane();
                    },
                  ),
                  // Same long-press context sheet as server rows — the queue
                  // actions apply to local files too (Find similar hides
                  // itself: a local path can't seed the similarity index).
                  onLongPress: () => _showTrackActions(b[i], c),
                  onTap: () {
                    handleTap(b, i, c);
                  }),
            )));
  }

  Widget makeFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // Below the letter-strip threshold there's no strip math to keep
    // uniform — let long folder names wrap and show in full. Smaller
    // folders tend to have longer / more descriptive names.
    final allowWrap = b.length < LetterStrip.minItemsToShow;
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Slidable(
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              children: [
                SlidableAction(
                    backgroundColor: Colors.blueGrey,
                    icon: Icons.add_to_queue,
                    label: l.addAll,
                    onPressed: (context) {
                      ApiManager().getRecursiveFiles(b[i].data!,
                          useThisServer: b[i].server);
                    })
              ],
            ),
            child: Builder(
              builder: (context) => ListTile(
                  leading: b[i].icon,
                  title: b[i].getText(truncate: !allowWrap),
                  subtitle: b[i].getSubText(),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_left,
                      size: 20.0,
                      color: Colors.brown[900],
                    ),
                    onPressed: () {
                      Slidable.of(context)?.openEndActionPane();
                    },
                  ),
                  onTap: () {
                    handleTap(b, i, c);
                  }),
            )));
  }

  // Album list rows. Unlike makeBasicWidget, the leading is a FIXED-size
  // thumbnail (cover art or a same-size placeholder) so the title/subtitle
  // start at the same x whether or not a row has art — getImage() returns a
  // full-height image for art rows but a tiny Icon for the rest, which
  // misaligns the text.
  Widget makeAlbumWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: ListTile(
            leading: b[i].getAlbumThumb(),
            title: b[i].getText(l: l),
            subtitle: b[i].getSubText(l: l),
            onTap: () {
              handleTap(b, i, c);
            }));
  }

  Widget makeBasicWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: ListTile(
            leading: b[i].getImage(),
            title: b[i].getText(l: l),
            subtitle: b[i].getSubText(l: l),
            onTap: () {
              handleTap(b, i, c);
            }));
  }

  // ── Default browser landing: section shortcuts as a modern card grid ──
  Widget _homeView(BuildContext context, List<DisplayItem> items) {
    final l = AppLocalizations.of(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final iconData = item.icon?.icon ?? Icons.chevron_right;
        return Material(
          color: VelvetColors.surface,
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => handleTap(items, i, context),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: VelvetColors.border),
                borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: VelvetColors.primaryDim,
                      borderRadius:
                          BorderRadius.circular(VelvetColors.radiusSmall),
                    ),
                    child: Icon(iconData,
                        color: VelvetColors.primary, size: 24),
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
      },
    );
  }

  // Long-press context sheet for track rows: the album-detail queue actions
  // (Add next / Play now / Add to end) plus Find similar when the track's
  // server supports discovery. Long-press = item context menu is the
  // convention everywhere (Apple Music / Spotify / Symfonium).
  void _showTrackActions(DisplayItem item, BuildContext c) {
    showModalBottomSheet(
      context: c,
      backgroundColor: VelvetColors.surface,
      builder: (_) => TrackActionsSheet(item: item, parentContext: c),
    );
  }

  Widget makeFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    // Same wrap-on-small-list rule as folders: below the letter-strip
    // threshold there's no uniform-row constraint, so long song names
    // get to show in full.
    final allowWrap = b.length < LetterStrip.minItemsToShow;
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Material(
            color: VelvetColors.bg,
            child: InkWell(
                splashColor: VelvetColors.primaryDim,
                onLongPress: () => _showTrackActions(b[i], c),
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
                              // Server songs get a tappable rating star at the
                              // end (same pattern as the album rows). Local files
                              // have no server-side rating, so no star. Needs a
                              // metadata object too — without one the rate has
                              // nowhere to write back to (onChanged below).
                              trailing: (b[i].type == 'file' &&
                                      b[i].server != null &&
                                      b[i].data != null &&
                                      b[i].metadata != null)
                                  ? RatingControl(
                                      rating: b[i].metadata?.rating,
                                      server: b[i].server!,
                                      filepath: b[i].data!,
                                      size: 11,
                                      onChanged: (r) {
                                        b[i].metadata?.rating = r;
                                        BrowserManager().updateStream();
                                      },
                                    )
                                  : null,
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

                    // The default browser landing (section shortcuts) gets a
                    // modern card grid instead of plain list rows.
                    if (isHome) {
                      // While a configured "startup view" loads on launch, show
                      // a spinner instead of the home grid so the app lands
                      // straight on the chosen section (no home-grid flash).
                      if (BrowserManager().awaitingStartupView) {
                        return Center(
                          child: CircularProgressIndicator(
                              color: VelvetColors.primary),
                        );
                      }
                      return _homeView(context, browserList);
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
                        final Widget content = useGrid
                            ? AlbumGrid(
                                items: browserList,
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
                              );

                        // Only overlay the letter scrubber for views
                        // the server sorts alphabetically (Albums,
                        // Artists, File Explorer) — see BrowserManager
                        // .alphabeticalCache.
                        if (!BrowserManager().isAlphabetical ||
                            browserList.isEmpty ||
                            filtering) {
                          return content;
                        }
                        return Stack(
                          children: [
                            content,
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: LetterStrip(
                                items: browserList,
                                onJump: (i) {
                                  final sc = BrowserManager().sc;
                                  if (!sc.hasClients) return;
                                  final double offset;
                                  if (useGrid) {
                                    final w = MediaQuery.of(context)
                                        .size
                                        .width;
                                    final cols = AlbumGrid.columnsFor(w);
                                    final rowH = AlbumGrid.rowHeightFor(w);
                                    final row = i ~/ cols;
                                    offset = AlbumGrid.padTop +
                                        row * (rowH + AlbumGrid.spacing);
                                  } else {
                                    // Sum the SAME per-row extents the ListView
                                    // lays out with (see _rowExtent) so the jump
                                    // lands exactly on the target row. File
                                    // Explorer mixes 1- and 2-line rows, hence
                                    // the walk-and-sum. O(i), microseconds even
                                    // at 10k+ items.
                                    double sum = 0;
                                    final stop =
                                        i.clamp(0, browserList.length);
                                    for (var k = 0; k < stop; k++) {
                                      sum += _rowExtent(browserList[k], ts);
                                    }
                                    offset = sum;
                                  }
                                  sc.jumpTo(offset
                                      .clamp(
                                          0.0, sc.position.maxScrollExtent)
                                      .toDouble());
                                },
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
