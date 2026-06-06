import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import '../l10n/app_localizations.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../singletons/settings.dart';
import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../widgets/album_grid.dart';
import '../widgets/letter_strip.dart';
import '../widgets/player_panel.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../singletons/media.dart';
import '../util/queue_actions.dart';

import 'add_server.dart';

class Browser extends StatefulWidget {
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
  // null if cancelled.
  Future<String?> _playlistNameDialog(BuildContext context,
      {required String title, required String action, String? initial}) {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: VelvetColors.textPrimary),
          decoration: InputDecoration(hintText: l.playlistNameHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
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
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
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
                  leading: b[i].icon ?? null,
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
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
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
                  leading: b[i].icon ?? null,
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

  Widget makeFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // Below the letter-strip threshold there's no strip math to keep
    // uniform — let long folder names wrap and show in full. Smaller
    // folders tend to have longer / more descriptive names.
    final allowWrap = b.length < LetterStrip.minItemsToShow;
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
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
                  leading: b[i].icon ?? null,
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

  Widget makeBasicWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: ListTile(
            leading: b[i].getImage(),
            title: b[i].getText(l: l),
            subtitle: b[i].getSubText(l: l),
            onTap: () {
              handleTap(b, i, c);
            }));
  }

  Widget makeFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    // Same wrap-on-small-list rule as folders: below the letter-strip
    // threshold there's no uniform-row constraint, so long song names
    // get to show in full.
    final allowWrap = b.length < LetterStrip.minItemsToShow;
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: Material(
            color: VelvetColors.bg,
            child: InkWell(
                splashColor: VelvetColors.primaryDim,
                child: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                      Container(
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
                              onTap: () {
                                handleTap(b, i, c);
                              }))
                    ])))));
  }

  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(children: <Widget>[
      // Current File Explorer path — a thin strip under the toolbar/back button.
      // Only shown in the file explorer (BrowserManager.currentPath is null
      // elsewhere); rebuilds on each navigation via browserListStream.
      StreamBuilder<List<DisplayItem>>(
        stream: BrowserManager().browserListStream,
        builder: (context, _) {
          final path = BrowserManager().currentPath;
          if (path == null) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 4, 12, 5),
            decoration: BoxDecoration(
              color: VelvetColors.raised,
              border: Border(bottom: BorderSide(color: VelvetColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 13, color: VelvetColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    path.isEmpty ? '/' : path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: VelvetColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                            // Theme override so the browser's rows
                            // are denser than the global ListTile
                            // default — gains ~26px of horizontal
                            // space for the title (less truncation)
                            // without affecting Settings/About/etc.
                            //   contentPadding: 16 -> 10 (saves 12)
                            //   horizontalTitleGap: 16 -> 10 (saves 6)
                            //   minLeadingWidth: 40 -> 32 (saves 8)
                            // Heights are unchanged by these knobs,
                            // so the letter-scrub cumulative math
                            // stays correct.
                            : Theme(
                                data: Theme.of(context).copyWith(
                                  listTileTheme: Theme.of(context)
                                      .listTileTheme
                                      .copyWith(
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 10),
                                        horizontalTitleGap: 10,
                                        minLeadingWidth: 32,
                                      ),
                                ),
                                child: ListView.separated(
                                    controller: BrowserManager().sc,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    separatorBuilder:
                                        (BuildContext context, int index) =>
                                            Divider(
                                                height: 1,
                                                color:
                                                    VelvetColors.border),
                                    itemCount: browserList.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      if (browserList.length == 0) {
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
                                    // ListTile heights vary per-row by
                                    // whether a subtitle is present:
                                    //   1-line (Artists, dirs): ~56dp
                                    //     + 1 border + 1 separator = 58
                                    //   2-line (Albums, files w/ meta):
                                    //     ~72dp + 1 border + 1 sep = 74
                                    // File Explorer mixes both inside
                                    // a single list (directories first,
                                    // then metadata-bearing files), so
                                    // we have to walk and SUM rather
                                    // than multiply by a single height.
                                    // O(i), microseconds even at 10k+
                                    // items. Tune these constants if
                                    // taps land too high or too low.
                                    const oneLineRow = 58.0;
                                    const twoLineRow = 74.0;
                                    double sum = 0;
                                    final stop =
                                        i.clamp(0, browserList.length);
                                    for (var k = 0; k < stop; k++) {
                                      final it = browserList[k];
                                      final twoLine = it.metadata?.artist !=
                                              null ||
                                          it.subtext != null;
                                      sum += twoLine
                                          ? twoLineRow
                                          : oneLineRow;
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
    ]);
  }
}
