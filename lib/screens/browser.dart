import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/downloads.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../singletons/transcode.dart';
import '../singletons/file_explorer.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:path_provider/path_provider.dart';
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
      addFile(browserList[index]);
      return;
    }

    if (browserList[index].type == 'localDirectory') {
      FileExplorer()
          .getLocalFiles(browserList[index].data, browserList[index].server!);
      return;
    }

    if (browserList[index].type == 'localFile') {
      addLocalFile(browserList[index]);
      return;
    }
  }

  void addLocalFile(DisplayItem i) {
    MediaItem item = new MediaItem(
        id: Uuid().v4(),
        title: i.name,
        extras: {'path': i.data, 'localPath': i.data!});
    MediaManager().audioHandler.addQueueItem(item);
  }

  void addFile(DisplayItem i) async {
    // Check for song locally
    String downloadDirectory = i.server!.localname + i.data!;
    final dir = await FileExplorer().getDownloadDir(i.server!.saveToSdCard);
    if (dir == null) {
      return;
    }
    String finalString = '${dir.path}/media/$downloadDirectory';

    if (new File(finalString).existsSync() == true) {
      print('exists!');

      MediaItem item = new MediaItem(
          id: Uuid().v4(),
          title: i.name,
          extras: {'path': i.data, 'localPath': finalString});
      MediaManager().audioHandler.addQueueItem(item);
    }

    String prefix =
        TranscodeManager().transcodeOn == true ? '/transcode' : '/media';

    String lolUrl = Uri.encodeFull(i.server!.url +
        prefix +
        i.data! +
        '?app_uuid=' +
        Uuid().v4() +
        (i.server!.jwt == null ? '' : '&token=' + i.server!.jwt!));

    MediaItem item = new MediaItem(
        id: lolUrl,
        title: i.name,
        extras: {'server': i.server!.localname, 'path': i.data});

    MediaManager().audioHandler.addQueueItem(item);

    // TODO: Fire of request for metadata
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
    final _slidableKey = GlobalKey<SlidableState>();

    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
      child: Slidable(
          key: _slidableKey,
          actionPane: SlidableDrawerActionPane(),
          secondaryActions: [
            IconSlideAction(
                color: Colors.redAccent,
                icon: Icons.remove_circle,
                caption: 'Delete',
                onTap: () {
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
          child: ListTile(
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
                  _slidableKey.currentState?.open(
                    actionType: SlideActionType.secondary,
                  );
                },
              ),
              onTap: () {
                handleTap(b, i, c);
              })),
    );
  }

  Widget makeLocalFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final _slidableKey = GlobalKey<SlidableState>();

    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: Slidable(
            key: _slidableKey,
            actionPane: SlidableDrawerActionPane(),
            secondaryActions: [
              IconSlideAction(
                  color: Colors.red,
                  icon: Icons.delete,
                  caption: 'Delete',
                  onTap: () {
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
            child: ListTile(
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
                    _slidableKey.currentState?.open(
                      actionType: SlideActionType.secondary,
                    );
                  },
                ),
                onTap: () {
                  handleTap(b, i, c);
                })));
  }

  Widget makeLocalFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    final _slidableKey = GlobalKey<SlidableState>();

    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: Slidable(
            key: _slidableKey,
            actionPane: SlidableDrawerActionPane(),
            secondaryActions: [
              IconSlideAction(
                  color: Colors.red,
                  icon: Icons.delete,
                  caption: 'Delete',
                  onTap: () {
                    // ApiManager().getRecursiveFiles(b[i].data!,
                    //     useThisServer: b[i].server);
                    FileExplorer().deleteFile(b[i].data!, b[i].server);
                  })
            ],
            child: ListTile(
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
                    _slidableKey.currentState?.open(
                      actionType: SlideActionType.secondary,
                    );
                  },
                ),
                onTap: () {
                  handleTap(b, i, c);
                })));
  }

  Widget makeFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final _slidableKey = GlobalKey<SlidableState>();

    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: Slidable(
            key: _slidableKey,
            actionPane: SlidableDrawerActionPane(),
            secondaryActions: [
              IconSlideAction(
                  color: Colors.blueGrey,
                  icon: Icons.add_to_queue,
                  caption: 'Add All',
                  onTap: () {
                    ApiManager().getRecursiveFiles(b[i].data!,
                        useThisServer: b[i].server);
                  })
            ],
            child: ListTile(
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
                    _slidableKey.currentState?.open(
                      actionType: SlideActionType.secondary,
                    );
                  },
                ),
                onTap: () {
                  handleTap(b, i, c);
                })));
  }

  Widget makeBasicWidget(List<DisplayItem> b, int i, BuildContext c) {
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: ListTile(
            leading: b[i].icon ?? null,
            title: b[i].getText(),
            subtitle: b[i].getSubText(),
            onTap: () {
              handleTap(b, i, c);
            }));
  }

  Widget makeFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFbdbdbd)))),
        child: Material(
            color: Color(0xFFe1e2e1),
            child: InkWell(
                splashColor: Colors.blue,
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
                            valueColor: new AlwaysStoppedAnimation(Colors.blue),
                            backgroundColor: Colors.white.withOpacity(0),
                          ),
                        ),
                      ),
                      Expanded(
                          child: ListTile(
                              leading: b[i].icon ?? null,
                              title: b[i].getText(),
                              subtitle: b[i].getSubText(),
                              onTap: () {
                                handleTap(b, i, c);
                              }))
                    ])))));
  }

  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Material(
          color: Color(0xFFffffff),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                    icon: Icon(Icons.keyboard_arrow_left, color: Colors.black),
                    tooltip: 'Go Back',
                    onPressed: () {
                      BrowserManager().popBrowser();
                    }),
                Row(children: <Widget>[
                  IconButton(
                      icon: Icon(
                        Icons.download_sharp,
                        color: Colors.black,
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

                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('$count downloads started')));
                      }),
                  IconButton(
                      icon: Icon(
                        Icons.library_add,
                        color: Colors.black,
                      ),
                      tooltip: 'Add All',
                      onPressed: () {
                        BrowserManager().browserList.forEach((element) {
                          if (element.type == 'file') {
                            addFile(element);
                          }
                          if (element.type == 'localFile') {
                            addLocalFile(element);
                          }
                        });
                      })
                ])
              ])),
      Expanded(
          child: SizedBox(
              child: StreamBuilder<List<DisplayItem>>(
                  stream: BrowserManager().browserListStream,
                  builder: (context, snapshot) {
                    final List<DisplayItem> browserList = snapshot.data ?? [];
                    return ListView.separated(
                        controller: BrowserManager().sc,
                        physics: const AlwaysScrollableScrollPhysics(),
                        separatorBuilder: (BuildContext context, int index) =>
                            Divider(height: 3, color: Colors.white),
                        itemCount: BrowserManager().browserList.length,
                        itemBuilder: (BuildContext context, int index) {
                          // Fixes an odd rendering bug when going between tabs
                          if (browserList.length == 0) {
                            return Container();
                          }

                          return makeListItem(browserList, index, context);
                        });
                  })))
    ]);
  }
}
