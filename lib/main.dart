import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'screens/browser.dart';
import 'singletons/server_list.dart';
import 'objects/server.dart';
import 'objects/metadata.dart';
import 'screens/about_screen.dart';
import 'screens/metadata_screen.dart';
import 'screens/auto_dj.dart';
import 'screens/downloads.dart';
import 'singletons/downloads.dart';
import 'screens/add_server.dart';
import 'screens/manage_server.dart';
import 'screens/playlists_screen.dart';
import 'screens/settings_screen.dart';

import 'singletons/media.dart';
import 'singletons/playlists.dart';
import 'singletons/settings.dart';
import 'theme/velvet_theme.dart';
import 'widgets/waveform_progress.dart';

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
  await SettingsManager().load();
  await PlaylistManager().load();

  // allow self signed SSL cert
  HttpOverrides.global = new MyHttpOverrides();

  runApp(MaterialApp(
    title: 'mStream Music',
    home: MStreamApp(),
    theme: buildVelvetTheme(),
    debugShowCheckedModeBanner: false,
  ));
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_tabController.index != 0) {
            _tabController.animateTo(0);
          } else if (BrowserManager().browserCache.length > 1) {
            BrowserManager().popBrowser();
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
            appBar: AppBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('mStream Music'),
                  StreamBuilder<Server?>(
                      stream: ServerManager().currentServerStream,
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
                            onSelected: (int selectedServerIndex) async {
                              _tabController.animateTo(0);
                              if (selectedServerIndex > -1) {
                                ServerManager()
                                    .changeCurrentServer(selectedServerIndex);

                                try {
                                  await ServerManager().getServerPaths(
                                      ServerManager().currentServer!,
                                      throwErr: true);
                                  await ServerManager().callAfterEditServer();
                                } catch (err) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              "Failed To Connect To Server")));
                                }
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
                  tabs: [
                    StreamBuilder<String>(
                        stream: BrowserManager().browserLabelStream,
                        builder: (context, snapshot) {
                          final String? label = snapshot.data;
                          return Tab(text: label ?? 'Browser');
                        }),
                    Tab(text: 'Queue'),
                  ],
                  controller: _tabController),
            ),
            drawer: Drawer(
                child: ListView(padding: EdgeInsets.zero, children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      VelvetColors.raised,
                      VelvetColors.surface,
                    ],
                  ),
                ),
                margin: EdgeInsets.zero,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.graphic_eq,
                          color: VelvetColors.primary, size: 32),
                      SizedBox(width: 10),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: 'm',
                              style: TextStyle(
                                  fontWeight: FontWeight.w300,
                                  color: VelvetColors.textSecondary)),
                          TextSpan(
                              text: 'Stream',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: VelvetColors.textPrimary)),
                        ]),
                        style: TextStyle(
                            fontSize: 22, letterSpacing: -0.3),
                      ),
                    ]),
                    SizedBox(height: 4),
                    Text('Personal music streaming',
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.router),
                title: Text('Manage Servers'),
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
                leading: Icon(Icons.download),
                title: Text('Downloads'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DownloadScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.album),
                title: Text('Auto DJ'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AutoDJScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.queue_music),
                title: Text('Playlists'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlaylistsScreen()),
                  );
                },
              ),
              Divider(color: VelvetColors.border),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutScreen()),
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
          color: VelvetColors.surface,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  StreamBuilder<List<MediaItem>>(
                      stream: MediaManager().audioHandler.queue,
                      builder: (context, snap) {
                        final n = snap.data?.length ?? 0;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            n == 0
                                ? 'Queue is empty'
                                : '$n track${n == 1 ? '' : 's'} in queue',
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5),
                          ),
                        );
                      }),
                  IconButton(
                    icon: Icon(Icons.delete_sweep),
                    color: VelvetColors.error,
                    tooltip: 'Clear queue',
                    onPressed: () {
                      MediaManager().audioHandler.customAction('clearPlaylist');
                    },
                  ),
                ]),
          )),
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
                              key: Key(queue[index].id),
                              startActionPane: ActionPane(
                                motion: DrawerMotion(),
                                extentRatio: 0.18,
                                children: [
                                  SlidableAction(
                                      backgroundColor: Colors.blueGrey,
                                      icon: Icons.download,
                                      label: 'Sync',
                                      onPressed: (context) {
                                        if (queue[index]
                                                .extras!['localPath'] ==
                                            null) {
                                          DownloadManager().downloadOneFile(
                                              queue[index].id,
                                              queue[index].extras!['server'],
                                              queue[index].extras!['path'],
                                              null);
                                        }
                                      })
                                ],
                              ),
                              endActionPane: ActionPane(
                                motion: DrawerMotion(),
                                extentRatio: 0.36,
                                dismissible: DismissiblePane(
                                  onDismissed: () {
                                    MediaManager()
                                        .audioHandler
                                        .removeQueueItemAt(index);
                                  },
                                ),
                                children: [
                                  SlidableAction(
                                      backgroundColor: VelvetColors.primary,
                                      foregroundColor: Colors.white,
                                      icon: Icons.playlist_add,
                                      label: 'Add to',
                                      onPressed: (ctx) {
                                        _showAddToPlaylistSheet(
                                            ctx, queue[index]);
                                      }),
                                  SlidableAction(
                                      backgroundColor: VelvetColors.raised,
                                      foregroundColor:
                                          VelvetColors.textPrimary,
                                      icon: Icons.info,
                                      label: 'Info',
                                      onPressed: (context) {
                                        MusicMetadata m = new MusicMetadata(
                                            queue[index].artist,
                                            queue[index].album,
                                            queue[index].title,
                                            null,
                                            null,
                                            queue[index].extras?['year'],
                                            'X',
                                            null,
                                            queue[index].extras?['artUrl']);
                                        print(queue[index]);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    MeteDataScreen(
                                                        meta: m,
                                                        path: queue[index]
                                                            .extras?['path'])));
                                      }),
                                ],
                              ),
                              child: Container(
                                  decoration: BoxDecoration(
                                    color: (queue[index] == mediaItem)
                                        ? VelvetColors.active
                                        : null,
                                    border: Border(
                                      bottom: BorderSide(
                                          color: VelvetColors.border,
                                          width: 0.5),
                                    ),
                                  ),
                                  child: IntrinsicHeight(
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                        Container(
                                          width: 3,
                                          color: queue[index].extras![
                                                      'localPath'] !=
                                                  null
                                              ? VelvetColors.success
                                              : Colors.transparent,
                                        ),
                                        Expanded(
                                            child: ListTile(
                                                leading: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: SizedBox(
                                                    width: 44,
                                                    height: 44,
                                                    child: queue[index].extras?[
                                                                'artUrl'] !=
                                                            null
                                                        ? Image.network(
                                                            queue[index]
                                                                    .extras![
                                                                'artUrl'],
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (_, __, ___) =>
                                                                    _artFallback())
                                                        : _artFallback(),
                                                  ),
                                                ),
                                                subtitle: queue[index]
                                                            .artist !=
                                                        null
                                                    ? Text(queue[index].artist!,
                                                        style: TextStyle(
                                                            color: VelvetColors
                                                                .textSecondary))
                                                    : null,
                                                title: Text(
                                                    queue[index].title,
                                                    style: TextStyle(
                                                        color: queue[index] ==
                                                                mediaItem
                                                            ? VelvetColors
                                                                .primary
                                                            : VelvetColors
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                onTap: () {
                                                  MediaManager()
                                                      .audioHandler
                                                      .skipToQueueItem(
                                                          index);
                                                  MediaManager()
                                                      .audioHandler
                                                      .play();
                                                }))
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

  Widget _artFallback() => Container(
        color: VelvetColors.raised,
        child: Icon(Icons.music_note,
            color: VelvetColors.textSecondary, size: 22),
      );

  void _showAddToPlaylistSheet(BuildContext context, MediaItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(VelvetColors.radiusLarge)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: StreamBuilder(
            stream: PlaylistManager().stream,
            initialData: PlaylistManager().playlists,
            builder: (context, snapshot) {
              final lists = snapshot.data ?? const [];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(children: [
                      Expanded(
                        child: Text('Add to playlist',
                            style: TextStyle(
                                color: VelvetColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: Icon(Icons.add,
                            color: VelvetColors.primary),
                        tooltip: 'New playlist',
                        onPressed: () async {
                          final name = await _promptName(ctx);
                          if (name != null && name.isNotEmpty) {
                            final p =
                                await PlaylistManager().create(name);
                            await PlaylistManager().addEntry(
                                PlaylistManager().playlists.indexOf(p),
                                item);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          }
                        },
                      ),
                    ]),
                  ),
                  if (lists.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Text(
                        'No playlists yet — tap + to create one.',
                        style: TextStyle(
                            color: VelvetColors.textSecondary,
                            fontSize: 13),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: lists.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: VelvetColors.border),
                        itemBuilder: (_, i) {
                          final p = lists[i];
                          return ListTile(
                            leading: Icon(Icons.queue_music,
                                color: VelvetColors.primary),
                            title: Text(p.name),
                            subtitle: Text(
                              '${p.entries.length} track${p.entries.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                  color: VelvetColors.textSecondary,
                                  fontSize: 12),
                            ),
                            onTap: () async {
                              await PlaylistManager().addEntry(i, item);
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Added to ${p.name}')),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _promptName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel',
                  style:
                      TextStyle(color: VelvetColors.textSecondary))),
          ElevatedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: Text('Create')),
        ],
      ),
    );
  }
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
        padding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
        color: VelvetColors.surface,
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          // Now-playing strip (title + artist) above the waveform.
          StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final item = snap.data;
              if (item == null) {
                return SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: VelvetColors.textPrimary)),
                        if (item.artist != null)
                          Text(item.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: VelvetColors.textSecondary)),
                      ],
                    ),
                  ),
                  StreamBuilder<MediaState>(
                    stream: _mediaStateStream,
                    builder: (context, snap) {
                      final position = snap.data?.position ?? Duration.zero;
                      final duration = item.duration;
                      return Text(
                        duration == null
                            ? _fmt(position)
                            : '${_fmt(position)} / ${_fmt(duration)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: VelvetColors.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()]),
                      );
                    },
                  ),
                ]),
              );
            },
          ),
          StreamBuilder<MediaState>(
            stream: _mediaStateStream,
            builder: (context, snapshot) {
              final mediaState = snapshot.data;
              final dur = mediaState?.mediaItem?.duration;
              final progress = (dur == null || dur.inMilliseconds == 0)
                  ? 0.0
                  : (mediaState!.position.inMilliseconds /
                          dur.inMilliseconds)
                      .clamp(0.0, 1.0);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: WaveformProgress(
                  height: 20,
                  progress: progress,
                  seed: mediaState?.mediaItem?.id,
                  onSeek: dur == null
                      ? null
                      : (fraction) {
                          MediaManager().audioHandler.seek(
                                Duration(
                                    milliseconds:
                                        (dur.inMilliseconds * fraction)
                                            .toInt()),
                              );
                        },
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
                                ? VelvetColors.primary
                                : VelvetColors.textSecondary,
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
                                ? VelvetColors.primary
                                : VelvetColors.textSecondary,
                            onPressed: toggleRepeat);
                      }),
                  StreamBuilder<dynamic>(
                      // stream: MediaManager().audioHandler.playbackState,
                      stream: MediaManager().audioHandler.customState,
                      builder: (context, snapshot) {
                        final Server? autoDJState =
                            (snapshot.data?.autoDJState as Server?);
                        return IconButton(
                            icon: Icon(Icons.album),
                            color: (autoDJState == null)
                                ? Colors.white
                                : Colors.blue,
                            onPressed: () {
                              if (ServerManager().currentServer == null) {
                                return;
                              }

                              if (autoDJState == null) {
                                MediaManager().audioHandler.customAction(
                                    'setAutoDJ', {
                                  'autoDJServer': ServerManager().currentServer
                                });

                                if (ServerManager().serverList.length == 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("Auto DJ Enabled")));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              "Auto DJ Enabled For ${ServerManager().currentServer!.url.toString()}")));
                                }
                              } else if (ServerManager().currentServer! ==
                                  autoDJState) {
                                MediaManager().audioHandler.customAction(
                                    'setAutoDJ', {'autoDJServer': null});

                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text("Auto DJ Disabled")));
                              } else {
                                MediaManager().audioHandler.customAction(
                                    'setAutoDJ', {
                                  'autoDJServer': ServerManager().currentServer
                                });
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        "Auto DJ Enabled For ${ServerManager().currentServer!.url.toString()}")));
                              }
                            });
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
          MediaManager().audioHandler.positionStream,
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
  final Server? autoDJState;

  CustomEvent(this.autoDJState);
}

String _fmt(Duration d) {
  final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:$mm:$ss';
  }
  return '$mm:$ss';
}
