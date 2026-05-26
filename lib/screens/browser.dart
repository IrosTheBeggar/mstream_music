import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/downloads.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../widgets/album_grid.dart';
import '../widgets/letter_strip.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'dart:io';

import '../singletons/media.dart';

import 'add_server.dart';

class Browser extends StatelessWidget {
  void handleTap(
      List<DisplayItem> browserList, int index, BuildContext context) {
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
    final dir = await FileExplorer().getDownloadDir(i.server!.saveToSdCard);
    if (dir == null) return null;
    String finalString = '${dir.path}/media/$downloadDirectory';

    if (new File(finalString).existsSync() == true) {
      String? artUrl = i.metadata?.albumArt != null
          ? Uri.parse(i.server!.url.toString())
              .resolve('/album-art/' +
                  i.metadata!.albumArt! +
                  '?compress=l&token=' +
                  (i.server!.jwt ?? ''))
              .toString()
          : null;

      return new MediaItem(
          id: Uuid().v4(),
          title: i.metadata?.title ?? i.name,
          album: i.metadata?.album,
          artist: i.metadata?.artist,
          extras: {
            'path': i.data,
            'localPath': finalString,
            'year': i.metadata?.year,
            'artUrl': artUrl,
          });
    }

    String prefix =
        TranscodeManager().transcodeOn == true ? '/transcode' : '/media';

    String p = '';
    i.data!.split("/").forEach((element) {
      if (element.length == 0) {
        return;
      }
      p += "/" + Uri.encodeComponent(element);
    });

    String lolUrl = i.server!.url +
        prefix +
        p +
        '?app_uuid=' +
        Uuid().v4() +
        (i.server!.jwt == null ? '' : '&token=' + i.server!.jwt!);

    String? artUrl = i.metadata?.albumArt != null
        ? Uri.parse(i.server!.url.toString())
            .resolve('/album-art/' +
                i.metadata!.albumArt! +
                '?compress=l&token=' +
                (i.server!.jwt ?? ''))
            .toString()
        : null;

    return new MediaItem(
        id: lolUrl,
        title: i.metadata?.title ?? i.name,
        album: i.metadata?.album,
        artist: i.metadata?.artist,
        extras: {
          'server': i.server!.localname,
          'path': i.data,
          'year': i.metadata?.year,
          'artUrl': artUrl,
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
                  label: 'Delete',
                  onPressed: (context) {
                    showDialog(
                        context: c,
                        builder: (BuildContext context) {
                          return AlertDialog(
                              title: Text("Confirm Delete Playlist"),
                              content: b[i].getText(),
                              actions: <Widget>[
                                TextButton(
                                  child: Text("Go Back"),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                    child: Text(
                                      "Delete",
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
                    label: 'Delete',
                    onPressed: (context) {
                      showDialog(
                          context: c,
                          builder: (BuildContext context) {
                            return AlertDialog(
                                title: Text("Confirm Delete Folder"),
                                content: b[i].getText(),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Go Back"),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                      child: Text(
                                        "Delete",
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
                    label: 'Delete',
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
                    label: 'Add All',
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
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: ListTile(
            leading: b[i].getImage(),
            title: b[i].getText(),
            subtitle: b[i].getSubText(),
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
                            value: BrowserManager()
                                    .browserList[i]
                                    .downloadProgress /
                                100,
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
                      IconButton(
                          icon: Icon(Icons.keyboard_arrow_left,
                              color: VelvetColors.textSecondary),
                          tooltip: 'Go Back',
                          onPressed: () {
                            BrowserManager().popBrowser();
                          }),
                      Row(children: <Widget>[
                        IconButton(
                            icon: Icon(
                              Icons.download_sharp,
                              color: VelvetColors.textSecondary,
                            ),
                            tooltip: 'Download',
                            onPressed: () {
                              int count = 0;

                              BrowserManager().browserList.forEach((e) {
                                if (e.type == 'file') {
                                  String downloadUrl = e.server!.url +
                                      '/media' +
                                      e.data! +
                                      (e.server!.jwt == null
                                          ? ''
                                          : '?token=' + e.server!.jwt!);

                                  DownloadManager().downloadOneFile(
                                      downloadUrl,
                                      e.server!.localname,
                                      e.data!,
                                      e.server!.saveToSdCard);
                                  count++;
                                }
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('$count downloads started')));
                            }),
                        IconButton(
                            icon: Icon(
                              Icons.library_add,
                              color: VelvetColors.textSecondary,
                            ),
                            tooltip: 'Add All',
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
                                        content: Text(n.toString() +
                                            " songs added to queue")));
                              }
                            })
                      ])
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
                                hintText: 'Search Database',
                              )))
                    ]
                  ]);
            }),
      ),
      Expanded(
          child: SizedBox(
              child: StreamBuilder<List<DisplayItem>>(
                  stream: BrowserManager().browserListStream,
                  builder: (context, snapshot) {
                    final List<DisplayItem> browserList = snapshot.data ?? [];

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
                            browserList.isEmpty) {
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
