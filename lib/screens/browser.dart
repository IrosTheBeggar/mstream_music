import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/downloads.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import '../l10n/app_localizations.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../widgets/album_grid.dart';
import '../widgets/letter_strip.dart';
import '../widgets/local_search_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'dart:io';

import '../singletons/media.dart';

import 'add_server.dart';

class Browser extends StatefulWidget {
  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  // Local-search state. _searchOpen toggles the header search field;
  // _searchQuery filters the *displayed* list only — BrowserManager's
  // browserList and back-stack are never mutated, so navigation, the
  // letter-strip math and scroll restore all stay intact. Any
  // navigation (folder/album/etc. tap, or Back) clears both via
  // _closeSearch() so a filter never carries over into a new view.
  String _searchQuery = '';
  bool _searchOpen = false;

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

  void _closeSearch() {
    if (!_searchOpen && _searchQuery.isEmpty) return;
    setState(() {
      _searchOpen = false;
      _searchQuery = '';
    });
  }

  void handleTap(
      List<DisplayItem> browserList, int index, BuildContext context) {
    if (_navTypes.contains(browserList[index].type)) {
      _closeSearch();
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
      ApiManager().getAlbumSongs(browserList[index].data,
          useThisServer: browserList[index].server);
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
    await _enqueue(_buildLocalFileItem(i));
  }

  Future<void> addFile(DisplayItem i) async {
    final item = await _buildFileItem(i);
    if (item != null) await _enqueue(item);
  }

  // Pure builder for a localFile MediaItem. No I/O.
  MediaItem _buildLocalFileItem(DisplayItem i) {
    return new MediaItem(
        id: Uuid().v4(),
        title: i.name.split('/').last,
        extras: {'path': i.data, 'localPath': i.data!});
  }

  // Builder for a server-file MediaItem. Async because it has to check
  // whether the file is already cached locally to decide between a
  // local path and a streaming URL. Returns null if the download dir
  // isn't available.
  Future<MediaItem?> _buildFileItem(DisplayItem i) async {
    String downloadDirectory = i.server!.localname + i.data!;
    final dir = await FileExplorer()
        .getDownloadDir(i.server!.storageMode, i.server!.storageBasePath);
    // A null dir means the configured location is unavailable (SD card
    // removed / folder deleted) — treat as "not downloaded".
    final String? finalString =
        dir == null ? null : '${dir.path}/media/$downloadDirectory';
    final bool isLocal =
        finalString != null && new File(finalString).existsSync() == true;

    // Streaming URL — used as the MediaItem id for BOTH local and online
    // items, so playback can fall back to streaming if the local file goes
    // missing (moved mid-migration, SD removed, deleted externally). The
    // local path lives in extras and is re-checked for existence at play time.
    String p = '';
    i.data!.split("/").forEach((element) {
      if (element.length == 0) return;
      p += "/" + Uri.encodeComponent(element);
    });
    final String prefix =
        TranscodeManager().transcodeOn == true ? '/transcode' : '/media';
    final String streamUrl = i.server!.url +
        prefix +
        p +
        '?app_uuid=' +
        Uuid().v4() +
        (i.server!.jwt == null ? '' : '&token=' + i.server!.jwt!);

    final String? artUrl = i.metadata?.albumArt != null
        ? Uri.parse(i.server!.url.toString())
            .resolve('/album-art/' +
                i.metadata!.albumArt! +
                '?compress=l&token=' +
                (i.server!.jwt ?? ''))
            .toString()
        : null;

    return new MediaItem(
        id: streamUrl,
        title: i.metadata?.title ?? i.name,
        album: i.metadata?.album,
        artist: i.metadata?.artist,
        extras: {
          'server': i.server!.localname,
          'path': i.data,
          if (isLocal) 'localPath': finalString,
          'year': i.metadata?.year,
          'track': i.metadata?.track,
          'disc': i.metadata?.disc,
          'artUrl': artUrl,
          // bpm + musicalKey power AutoDJ's BPM-continuity / harmonic-mixing
          // modes — read off the currently playing item.
          'bpm': i.metadata?.bpm,
          'musicalKey': i.metadata?.musicalKey,
        });

    // TODO: Fire of request for metadata
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

  // Pattern A: clear the queue, fill it with every playable item from
  // the current browser view (in order), jump to the tapped one, play.
  Future<void> _playFromHere(
      List<DisplayItem> browserList, int tappedIndex) async {
    // Filter to playable rows, remember where the tap lands within
    // the filtered list. Non-song rows (folders, headers) are skipped.
    final playable = <DisplayItem>[];
    int newIndex = 0;
    for (var j = 0; j < browserList.length; j++) {
      final t = browserList[j].type;
      if (t == 'file' || t == 'localFile') {
        if (j == tappedIndex) newIndex = playable.length;
        playable.add(browserList[j]);
      }
    }
    if (playable.isEmpty) return;

    // Build all MediaItems first so a failed build doesn't leave us
    // with a half-replaced queue.
    final items = <MediaItem>[];
    for (final i in playable) {
      final m = i.type == 'localFile'
          ? _buildLocalFileItem(i)
          : await _buildFileItem(i);
      if (m != null) items.add(m);
    }
    if (items.isEmpty) return;

    await MediaManager().audioHandler.customAction('clearPlaylist');
    for (final m in items) {
      await MediaManager().audioHandler.addQueueItem(m);
    }
    await MediaManager().audioHandler.skipToQueueItem(newIndex);
    await MediaManager().audioHandler.play();
  }

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
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
      child: Slidable(
          endActionPane: ActionPane(
            motion: DrawerMotion(),
            children: [
              SlidableAction(
                  backgroundColor: Colors.redAccent,
                  icon: Icons.remove_circle,
                  label: l.delete,
                  onPressed: (context) {
                    showDialog(
                        context: c,
                        builder: (BuildContext context) {
                          return AlertDialog(
                              title: Text(l.browserConfirmDeletePlaylist),
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
                                      ApiManager().removePlaylist(b[i].data!,
                                          useThisServer: b[i].server);
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
                title: b[i].getText(),
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
          )),
    );
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

  // Browser "Download all": same confirm + empty-state UX as the queue's
  // button. Counts the file rows in the *current* list (folders / headers
  // are ignored); alerts if there are none, otherwise confirms the count
  // before enqueueing. downloadOneFile no-ops on files already on disk.
  void _downloadAll(BuildContext context) {
    final files =
        BrowserManager().browserList.where((e) => e.type == 'file').toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nothing to download in this list')));
      return;
    }
    final n = files.length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text('Download all'),
        content: Text('$n file${n == 1 ? '' : 's'} will be downloaded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              for (final e in files) {
                String downloadUrl = e.server!.url +
                    '/media' +
                    e.data! +
                    (e.server!.jwt == null ? '' : '?token=' + e.server!.jwt!);
                DownloadManager().downloadOneFile(
                    downloadUrl, e.server!.localname, e.data!,
                    referenceItem: e);
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$n download${n == 1 ? '' : 's'} started')));
            },
            child: Text('Download'),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(children: <Widget>[
      Material(
        color: VelvetColors.surface,
        child: StreamBuilder<List<DisplayItem>>(
            stream: BrowserManager().browserListStream,
            builder: (context, snapshot) {
              final List<DisplayItem> browserList = snapshot.data ?? [];

              if (browserList.length > 0) {
                print(browserList[0].type);
              }
              return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (browserList.length == 0 ||
                        browserList[0].type != 'execAction') ...[
                      if (_searchOpen) ...[
                        // Search mode: a close button + the live-filtering
                        // field fill the header. Download / Add All are
                        // hidden here so they always act on the full list,
                        // never the filtered subset.
                        IconButton(
                            icon: Icon(Icons.close,
                                color: VelvetColors.textSecondary),
                            tooltip: 'Close search',
                            onPressed: _closeSearch),
                        Expanded(
                            child: LocalSearchBar(
                                hintText: 'Search this list',
                                onChanged: (q) =>
                                    setState(() => _searchQuery = q))),
                      ] else ...[
                      IconButton(
                          icon: Icon(Icons.keyboard_arrow_left,
                              color: VelvetColors.textSecondary),
                          tooltip: l.goBack,
                          onPressed: () {
                            _closeSearch();
                            BrowserManager().popBrowser();
                          }),
                      Row(children: <Widget>[
                        IconButton(
                            icon: Icon(Icons.search,
                                color: VelvetColors.textSecondary),
                            tooltip: 'Search list',
                            onPressed: () =>
                                setState(() => _searchOpen = true)),
                        IconButton(
                            icon: Icon(
                              Icons.download_sharp,
                              color: VelvetColors.textSecondary,
                            ),
                            tooltip: l.download,
                            onPressed: () => _downloadAll(context)),
                        IconButton(
                            icon: Icon(
                              Icons.library_add,
                              color: VelvetColors.textSecondary,
                            ),
                            tooltip: l.addAll,
                            onPressed: () {
                              int n = 0;

                              BrowserManager().browserList.forEach((element) {
                                if (element.type == 'localFile') {
                                  if (element.data!.substring(
                                          element.data!.length - 4) ==
                                      '.m3u') {
                                    return;
                                  }
                                  addLocalFile(element);
                                  n++;
                                } else if (element.type == 'file') {
                                  if (element.data!.substring(
                                          element.data!.length - 4) ==
                                      '.m3u') {
                                    return;
                                  }
                                  addFile(element);
                                  n++;
                                }
                              });

                              if (n > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text(l.browserSongsAdded(n))));
                              }
                            })
                      ])
                      ],
                    ] else ...[
                      Expanded(
                          child: TextField(
                              onSubmitted: (text) {
                                ApiManager().searchServer(text);
                                print('First text field: $text');
                              },
                              style: TextStyle(color: VelvetColors.textSecondary),
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: VelvetColors.textSecondary,
                                ),
                                hintStyle: TextStyle(
                                  color: VelvetColors.textSecondary,
                                ),
                                labelStyle: TextStyle(
                                  color: VelvetColors.textSecondary,
                                ),
                                hintText: l.browserSearchHint,
                              )))
                    ]
                  ]);
            }),
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
                    final String q = _searchQuery.trim();
                    final bool filtering =
                        _searchOpen && q.isNotEmpty && !isHome;
                    final List<DisplayItem> browserList = filtering
                        ? rawList.where((it) => it.matchesQuery(q)).toList()
                        : rawList;

                    if (filtering && browserList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No matches for "$q"',
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
