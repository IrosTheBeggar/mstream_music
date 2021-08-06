import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'screens/browser.dart';
import 'singletons/server_list.dart';
import 'singletons/file_explorer.dart';
import 'objects/server.dart';
import 'screens/about_screen.dart';
import 'screens/downloads.dart';
import 'singletons/downloads.dart';
import 'screens/add_server.dart';
import 'screens/manage_server.dart';

import 'singletons/media.dart';

import 'dart:io';

// allow self signed SSL cert
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  await MediaManager().start();

  // allow self signed SSL cert
  HttpOverrides.global = new MyHttpOverrides();

  runApp(new MaterialApp(
      title: 'mStream Music',
      home: MStreamApp(),
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Color(0xFF212121),
          primaryColorDark: Color(0xFF000000),
          primaryColorLight: Color(0xFF484848),
          accentColor: Color(0xFFffab00),
          buttonColor: Color(0xFFFFAB00),
          scaffoldBackgroundColor: Color(0xFFe1e2e1),
          cardColor: Color(0xFFffffff))));
}

class MStreamApp extends StatefulWidget {
  @override
  _MStreamAppState createState() => new _MStreamAppState();
}

class _MStreamAppState extends State<MStreamApp>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    ServerManager().loadServerList();
    DownloadManager().initDownloader();
  }

  @override
  void dispose() {
    DownloadManager().dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      return new Future.value(false);
    } else if (BrowserManager().browserCache.length > 1) {
      BrowserManager().popBrowser();
      return new Future.value(false);
    } else {
      return new Future.value(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
            appBar: AppBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('mStream Music'),
                  StreamBuilder<Server?>(
                      stream: ServerManager().curentServerStream,
                      builder: (context, snapshot) {
                        final Server? cServer = snapshot.data;
                        return Visibility(
                          visible: cServer != null,
                          child: Text(
                            cServer == null ? '' : cServer.url,
                            style: TextStyle(fontSize: 12.0),
                          ),
                        );
                      }),
                ],
              ),
              actions: <Widget>[
                StreamBuilder<List<Server>>(
                    stream: ServerManager().serverListStream,
                    builder: (context, snapshot) {
                      final isVisible =
                          snapshot.hasData && snapshot.data!.length > 1;
                      return Visibility(
                        visible: isVisible,
                        child: PopupMenuButton(
                            onSelected: (int selectedServerIndex) {
                              _tabController.animateTo(0);
                              if (selectedServerIndex > -1) {
                                ServerManager()
                                    .changeCurrentServer(selectedServerIndex);
                              } else if (selectedServerIndex == -1) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            AddServerScreen()));
                              }
                            },
                            icon: Icon(Icons.cloud),
                            itemBuilder: (BuildContext context) {
                              List<PopupMenuEntry<int>> popUpWidgetList =
                                  ServerManager().serverList.map((server) {
                                return PopupMenuItem(
                                  value: ServerManager()
                                      .serverList
                                      .indexOf(server),
                                  child: Text(server.url,
                                      style: TextStyle(
                                          color: server ==
                                                  ServerManager().currentServer
                                              ? Colors.blue
                                              : Colors.black)),
                                );
                              }).toList();

                              return popUpWidgetList;
                            }),
                      );
                    }),
              ],
              bottom: TabBar(
                  labelColor: Color(0xFFffab00),
                  indicatorColor: Color(0xFFffab00),
                  unselectedLabelColor: Color(0xFFcccccc),
                  tabs: [
                    StreamBuilder<String>(
                        stream: BrowserManager().broswerLabelStream,
                        builder: (context, snapshot) {
                          final String? label = snapshot.data;
                          return Tab(text: label ?? 'Browser');
                        }),
                    Tab(text: 'Queue'),
                  ],
                  controller: _tabController),
            ),
            drawer: Drawer(
                child: ListView(children: <Widget>[
              ListTile(
                title: Text(
                  'mStream Music',
                  style: TextStyle(
                      fontFamily: 'Jura',
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Color(0xFFffab00)),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => AboutScreen()));
                },
              ),
              Divider(),
              // ListTile(
              //   leading: Icon(Icons.folder),
              //   title: Text(
              //     'File Explorer',
              //     style: TextStyle(
              //         fontFamily: 'Jura',
              //         fontWeight: FontWeight.bold,
              //         fontSize: 17),
              //   ),
              //   onTap: () {
              //     FileExplorer().getLocalFiles(null);
              //     Navigator.of(context).pop();
              //     _tabController.animateTo(0);
              //   },
              // ),
              ListTile(
                title: Text('Manage Servers',
                    style: TextStyle(
                        fontFamily: 'Jura',
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                leading: Icon(Icons.router),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ManageServersScreen()),
                  );
                },
              ),
              ListTile(
                title: Text('Downloads',
                    style: TextStyle(
                        fontFamily: 'Jura',
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                leading: Icon(Icons.download),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DownloadScreen()),
                  );
                },
              ),
            ])),
            body: TabBarView(
                children: [Browser(), NowPlaying()],
                controller: _tabController),
            bottomNavigationBar: BottomBar()));
  }
}

class NowPlaying extends StatelessWidget {
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Material(
          color: Colors.white,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(children: []),
                Row(children: [
                  IconButton(
                    splashColor: Colors.red,
                    icon: Icon(Icons.cancel),
                    color: Colors.redAccent,
                    onPressed: () {
                      MediaManager().audioHandler.customAction('clearPlaylist');
                    },
                  ),
                ])
              ])),
      Expanded(
          child: SizedBox(
              child: StreamBuilder<QueueState>(
                  stream: _queueStateStream,
                  builder: (context, snapshot) {
                    final queueState = snapshot.data;
                    final queue = queueState?.queue ?? [];
                    final mediaItem = queueState?.mediaItem;

                    return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: queue.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Slidable(
                              actionPane: SlidableDrawerActionPane(),
                              key: Key(queue[index].id),
                              dismissal: SlidableDismissal(
                                child: SlidableDrawerDismissal(),
                                onDismissed: (actionType) {
                                  MediaManager()
                                      .audioHandler
                                      .removeQueueItemAt(index);
                                },
                              ),
                              actions: <Widget>[
                                // IconSlideAction(
                                //     color: Colors.blueGrey,
                                //     icon: ,
                                //     caption: 'Rate',
                                //     onTap: () {
                                //       showDialog(
                                //           context: context,
                                //           builder: (BuildContext context) {
                                //             return AlertDialog(
                                //                 title: Text("Rate Song"),
                                //                 content: Column(
                                //                   mainAxisSize:
                                //                       MainAxisSize.min,
                                //                 ),
                                //                 actions: [
                                //                   TextButton(
                                //                     child: Text("Go Back"),
                                //                     onPressed: () {
                                //                       Navigator.of(context)
                                //                           .pop();
                                //                     },
                                //                   ),
                                //                 ]);
                                //           });
                                //     }),
                                IconSlideAction(
                                    color: Colors.blueGrey,
                                    icon: Icons.download,
                                    caption: 'Sync',
                                    onTap: () {
                                      if (queue[index].extras!['localPath'] ==
                                          null) {
                                        DownloadManager().downloadOneFile(
                                            queue[index].id,
                                            queue[index].extras!['server'],
                                            queue[index].extras!['path']);
                                      }
                                    })
                              ],
                              actionExtentRatio: 0.18,
                              child: Container(
                                  color: (queue[index] == mediaItem)
                                      ? Color(0xFFffab00)
                                      : null,
                                  child: IntrinsicHeight(
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                        Container(
                                          width: 4,
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: LinearProgressIndicator(
                                              value: queue[index].extras![
                                                          'localPath'] ==
                                                      null
                                                  ? 0 // TODO: check for download progress
                                                  : 1,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                      Colors.blue),
                                              backgroundColor:
                                                  Colors.white.withOpacity(0),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                            child: Container(
                                                child: ListTile(
                                                    // tileColor: (queue[index] ==
                                                    //         mediaItem)
                                                    //     ? Color(0xFFffab00)
                                                    //     : null,
                                                    title: Text(
                                                        queue[index].title,
                                                        style: TextStyle(
                                                            fontFamily: 'Jura',
                                                            fontSize: 18,
                                                            color:
                                                                Colors.black)),
                                                    onTap: () {
                                                      MediaManager()
                                                          .audioHandler
                                                          .skipToQueueItem(
                                                              index);
                                                      MediaManager()
                                                          .audioHandler
                                                          .play();
                                                    })))
                                      ]))));
                        });
                  })))
    ]);
  }

  Stream<QueueState> get _queueStateStream =>
      Rx.combineLatest2<List<MediaItem>?, MediaItem?, QueueState>(
          MediaManager().audioHandler.queue,
          MediaManager().audioHandler.mediaItem,
          (queue, mediaItem) => QueueState(queue, mediaItem));
}

class BottomBar extends StatelessWidget {
  toggleShuffle() {
    MediaManager().audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
  }

  toggleRepeat() {
    MediaManager().audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
  }

  Widget build(BuildContext context) {
    return BottomAppBar(
        color: Color(0xFF212121),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(
            height: 8,
          ),
          StreamBuilder<MediaState>(
            stream: _mediaStateStream,
            builder: (context, snapshot) {
              final mediaState = snapshot.data;
              return GestureDetector(
                onTapUp: (TapUpDetails details) {
                  double width = MediaQuery.of(context).size.width;
                  double percentage = details.globalPosition.dx / width;
                  Duration duration =
                      mediaState?.mediaItem?.duration ?? Duration.zero;

                  double doubleDs = duration.inSeconds.toDouble();
                  int newDuration = (doubleDs * percentage).toInt();

                  MediaManager()
                      .audioHandler
                      .seek(Duration(seconds: newDuration));
                },
                child: Container(
                  height: 16,
                  child: LinearProgressIndicator(
                    value: (mediaState?.position.inSeconds ?? 0) /
                        (mediaState?.mediaItem?.duration?.inSeconds ?? 1),
                    backgroundColor: Color(0xFF484848),
                    valueColor: new AlwaysStoppedAnimation(Color(0xFFc67c00)),
                  ),
                ),
              );
            },
          ),
          Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous),
                    onPressed: MediaManager().audioHandler.skipToPrevious,
                  ),
                  StreamBuilder<bool>(
                    stream: MediaManager()
                        .audioHandler
                        .playbackState
                        .map((state) => state.playing)
                        .distinct(),
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;
                      if (playing)
                        return pauseButton();
                      else
                        return playButton();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next),
                    onPressed: MediaManager().audioHandler.skipToNext,
                  ),
                ]),
                Row(children: [
                  StreamBuilder<AudioServiceShuffleMode>(
                      // stream: MediaManager().audioHandler.playbackState,
                      stream: MediaManager()
                          .audioHandler
                          .playbackState
                          .map((state) => state.shuffleMode)
                          .distinct(),
                      builder: (context, snapshot) {
                        final mediaState = snapshot.data;
                        return IconButton(
                            icon: Icon(Icons.shuffle),
                            color: (mediaState == AudioServiceShuffleMode.all)
                                ? Colors.blue
                                : Colors.white,
                            onPressed: toggleShuffle);
                      }),
                  StreamBuilder<AudioServiceRepeatMode>(
                      // stream: MediaManager().audioHandler.playbackState,
                      stream: MediaManager()
                          .audioHandler
                          .playbackState
                          .map((state) => state.repeatMode)
                          .distinct(),
                      builder: (context, snapshot) {
                        final mediaState = snapshot.data;
                        return IconButton(
                            icon: Icon(Icons.loop_sharp),
                            color: (mediaState == AudioServiceRepeatMode.all)
                                ? Colors.blue
                                : Colors.white,
                            onPressed: toggleRepeat);
                      }),
                ])
              ])
        ]));
  }

  /// A stream reporting the combined state of the current media item and its
  /// current position.
  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest2<MediaItem?, Duration, MediaState>(
          MediaManager().audioHandler.mediaItem,
          AudioService.positionStream,
          (mediaItem, position) => MediaState(mediaItem, position));

  IconButton playButton() => IconButton(
        icon: Icon(Icons.play_arrow),
        // iconSize: 64.0,
        onPressed: MediaManager().audioHandler.play,
      );

  IconButton pauseButton() => IconButton(
        icon: Icon(Icons.pause),
        // iconSize: 64.0,
        onPressed: MediaManager().audioHandler.pause,
      );
}

class QueueState {
  final List<MediaItem>? queue;
  final MediaItem? mediaItem;

  QueueState(this.queue, this.mediaItem);
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

class CustomEvent {
  final int handlerIndex;

  CustomEvent(this.handlerIndex);
}
