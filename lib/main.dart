import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'screens/browser.dart';
import 'singletons/server_list.dart';
import 'objects/server.dart';
import 'objects/metadata.dart';
import 'screens/about_screen.dart';
import 'screens/metadata_screen.dart';
import 'screens/auto_dj.dart';
// import 'screens/downloads.dart'; // DownloadScreen — drawer entry hidden below
import 'singletons/downloads.dart';
import 'singletons/app_messenger.dart';
import 'singletons/migration_manager.dart';
import 'screens/add_server.dart';
import 'screens/manage_server.dart';
import 'screens/playlists_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/share_playlist_dialog.dart';
import 'screens/visualizer_screen.dart';

import 'singletons/auto_dj_manager.dart';
import 'singletons/media.dart';
import 'singletons/playlists.dart';
import 'singletons/settings.dart';
import 'singletons/sleep_timer.dart';
import 'theme/velvet_theme.dart';
import 'widgets/sleep_timer_sheet.dart';
import 'media/cast_target.dart';
import 'singletons/cast_manager.dart';
import 'widgets/cast_picker_sheet.dart';
import 'widgets/waveform_progress.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Settings load must come before MediaManager.start() so the audio
  // handler's _init() can read persisted EQ state when it attaches the
  // AndroidEqualizer to the player.
  await SettingsManager().load();
  await MediaManager().start();
  await PlaylistManager().load();
  await AutoDJManager().load();

  // Wrap MaterialApp in a StreamBuilder bound to the theme setting so
  // switching themes triggers a full retheme. setActive runs *inside*
  // the builder, immediately before MaterialApp returns, so the
  // ThemeData and any direct VelvetColors lookups stay in sync.
  runApp(StreamBuilder<AppTheme>(
    stream: SettingsManager().themeStream,
    initialData: SettingsManager().appTheme,
    builder: (context, snapshot) {
      final palette = paletteFor(snapshot.data ?? AppTheme.dark);
      VelvetColors.setActive(palette);
      return MaterialApp(
        title: 'mStream Music',
        scaffoldMessengerKey: rootMessengerKey,
        home: MStreamApp(),
        theme: buildAppTheme(palette),
        debugShowCheckedModeBanner: false,
      );
    },
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
    // Resume a storage move that was interrupted by an app restart.
    MigrationManager().resumeIfNeeded();
    // Android 13+ (targetSdk >= 33): OS no longer auto-prompts; audio_service
    // can't run its foreground media notification without this, so playback
    // silently fails. Fire-and-forget — first call shows the system dialog,
    // subsequent calls are no-ops once granted. Must run after runApp so the
    // permission_handler plugin has an Activity to attach the dialog to.
    Permission.notification.request();
  }

  @override
  void dispose() {
    DownloadManager().dispose();
    super.dispose();
  }

  // Thin banner above the tabs showing a background storage move's progress
  // (and resumed moves after an app restart). Hidden when none is running.
  Widget _migrationBanner() {
    return StreamBuilder<MigrationProgress?>(
      stream: MigrationManager().progressStream,
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return const SizedBox.shrink();
        final pct = p.fraction;
        final label = p.failed
            ? 'Move stopped — not enough space, or the location is unavailable.'
            : p.done
                ? (p.skipped > 0
                    ? 'Move complete — ${p.skipped} file'
                        "${p.skipped == 1 ? '' : 's'} skipped "
                        '(unsupported on the destination)'
                    : 'Move complete')
                : 'Moving downloads… '
                    '${pct != null ? '${(pct * 100).round()}%' : '${p.moved}/${p.total}'}'
                    ' — keep the app open';
        Widget compactButton(String text, Color color, VoidCallback onTap) {
          return TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(text, style: TextStyle(color: color, fontSize: 12)),
          );
        }

        return Material(
          color: VelvetColors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                      p.failed
                          ? Icons.error_outline
                          : p.done
                              ? Icons.check_circle_outline
                              : Icons.drive_file_move_outline,
                      size: 16,
                      color:
                          p.failed ? VelvetColors.error : VelvetColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(label,
                          style: TextStyle(
                              color: VelvetColors.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                  if (p.failed)
                    compactButton('Retry', VelvetColors.primary,
                        () => MigrationManager().retry()),
                  if (!p.done)
                    compactButton('Cancel', VelvetColors.textSecondary,
                        () => MigrationManager().cancel()),
                ]),
                if (!p.failed) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: VelvetColors.border2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: 'm',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: VelvetColors.appBarTextSecondary)),
                      TextSpan(
                          text: 'Stream',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: VelvetColors.appBarText)),
                    ]),
                    style: TextStyle(fontSize: 18, letterSpacing: -0.3),
                  ),
                  StreamBuilder<Server?>(
                      stream: ServerManager().currentServerStream,
                      builder: (context, snapshot) {
                        final Server? cServer = snapshot.data;
                        return Visibility(
                          visible: cServer != null,
                          child: Text(
                            cServer == null ? '' : cServer.url,
                            style: TextStyle(
                                fontSize: 11,
                                color: VelvetColors.appBarTextSecondary,
                                fontWeight: FontWeight.normal),
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
                                              ? VelvetColors.primary
                                              : VelvetColors.textPrimary)),
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
              // Downloads drawer entry hidden — per-file download progress
              // now shows inline on each browser row (the green left-edge
              // bar), so the dedicated Downloads page is redundant for
              // monitoring. Uncomment this and the screens/downloads.dart
              // import to restore; DownloadScreen and the DownloadManager
              // stream are both still in the tree.
              // ListTile(
              //   leading: Icon(Icons.download),
              //   title: Text('Downloads'),
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => DownloadScreen()),
              //     );
              //   },
              // ),
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
                leading: Icon(Icons.share),
                title: Text('Share Playlist'),
                onTap: () {
                  Navigator.of(context).pop();
                  showSharePlaylistDialog(context);
                },
              ),
              // Local playlists drawer entry hidden — having both this and
              // the server-side "Playlists" browser node was confusing.
              // Uncomment to restore; the PlaylistsScreen / PlaylistManager
              // code is still in the tree and PlaylistManager().load() still
              // runs at startup so saved playlists survive.
              // ListTile(
              //   leading: Icon(Icons.queue_music),
              //   title: Text('Playlists'),
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => PlaylistsScreen()),
              //     );
              //   },
              // ),
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
            body: Column(children: [
              _migrationBanner(),
              Expanded(
                  child: TabBarView(
                      children: [Browser(), NowPlaying()],
                      controller: _tabController)),
            ]),
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
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(Icons.auto_awesome),
                      color: VelvetColors.textSecondary,
                      tooltip: 'Visualizer',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => VisualizerScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.download_for_offline),
                      color: VelvetColors.textSecondary,
                      tooltip: 'Download all',
                      onPressed: () => _downloadAll(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_sweep),
                      color: VelvetColors.error,
                      tooltip: 'Clear queue',
                      onPressed: () {
                        MediaManager().audioHandler.customAction('clearPlaylist');
                      },
                    ),
                  ]),
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
                                              queue[index].extras!['path']);
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
                                  // "Add to" (local playlist) action hidden
                                  // alongside the drawer entry. Restore both
                                  // together when local playlists return.
                                  // SlidableAction(
                                  //     backgroundColor: VelvetColors.primary,
                                  //     foregroundColor: Colors.white,
                                  //     icon: Icons.playlist_add,
                                  //     label: 'Add to',
                                  //     onPressed: (ctx) {
                                  //       _showAddToPlaylistSheet(
                                  //           ctx, queue[index]);
                                  //     }),
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

  // Queue "Download all": enqueue every track that isn't already on the
  // device (no localPath) and is actually downloadable (has a server +
  // path — local-only files are skipped). Confirms the count first and
  // lets the user back out. downloadOneFile no-ops on files already on
  // disk, so re-running is harmless.
  void _downloadAll(BuildContext context) {
    final queue = MediaManager().audioHandler.queue.value;
    final pending = queue
        .where((m) =>
            m.extras?['localPath'] == null &&
            m.extras?['server'] != null &&
            m.extras?['path'] != null)
        .toList();

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(queue.isEmpty
              ? 'Queue is empty — nothing to download'
              : 'Nothing to download — tracks are already saved')));
      return;
    }

    final n = pending.length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text('Download all'),
        content: Text(
            '$n track${n == 1 ? '' : 's'} will be downloaded for offline playback.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              for (final m in pending) {
                DownloadManager().downloadOneFile(
                    m.id, m.extras!['server'], m.extras!['path']);
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text('$n download${n == 1 ? '' : 's'} started')));
            },
            child: Text('Download'),
          ),
        ],
      ),
    );
  }

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
    // BottomBar mirrors the AppBar (appBarBg) rather than the body
    // surface, so in the Light theme it stays a dark strip with light
    // text — master's signature look — instead of a low-contrast
    // white block on a light gray body. IconTheme wrap sets the
    // default icon color for the whole bar; per-button overrides
    // (active shuffle/repeat/autoDJ) still apply.
    return BottomAppBar(
        padding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
        color: VelvetColors.appBarBg,
        child: IconTheme(
          data: IconThemeData(color: VelvetColors.appBarTextSecondary),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          // Compact now-playing row: title — artist on the left,
          // mm:ss / mm:ss on the right, then the waveform on the row
          // BELOW. Both share a single ~36px tall line each so the
          // BottomAppBar stays inside the Scaffold's allocation.
          StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final item = snap.data;
              return Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: SizedBox(
                  height: 16,
                  child: item == null
                      ? null
                      : Row(children: [
                          Expanded(
                            child: Text(
                              item.artist == null
                                  ? item.title
                                  : '${item.title}  ·  ${item.artist}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: VelvetColors.appBarText,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          StreamBuilder<MediaState>(
                            stream: _mediaStateStream,
                            builder: (context, snap) {
                              final position =
                                  snap.data?.position ?? Duration.zero;
                              final duration = item.duration;
                              return Text(
                                duration == null
                                    ? _fmt(position)
                                    : '${_fmt(position)} / ${_fmt(duration)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: VelvetColors.appBarTextSecondary),
                              );
                            },
                          ),
                        ]),
                ),
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
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: WaveformProgress(
                  height: 16,
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
                                : VelvetColors.appBarTextSecondary,
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
                                : VelvetColors.appBarTextSecondary,
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
                                ? VelvetColors.appBarText
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
                  StreamBuilder<CastTarget>(
                      stream: CastManager().activeTargetStream,
                      initialData: CastManager().activeTarget,
                      builder: (context, snapshot) {
                        final casting =
                            !(snapshot.data ?? CastTarget.local).isLocal;
                        return IconButton(
                          icon: Icon(
                              casting ? Icons.cast_connected : Icons.cast),
                          tooltip: 'Play on…',
                          color: casting
                              ? VelvetColors.primary
                              : VelvetColors.appBarTextSecondary,
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: VelvetColors.surface,
                              builder: (_) => CastPickerSheet(),
                            );
                          },
                        );
                      }),
                  StreamBuilder<Duration?>(
                      stream: SleepTimerManager().remainingStream,
                      initialData: SleepTimerManager().remaining,
                      builder: (context, snapshot) {
                        final active = snapshot.data != null;
                        return IconButton(
                          icon: Icon(active
                              ? Icons.bedtime
                              : Icons.bedtime_outlined),
                          color: active
                              ? VelvetColors.primary
                              : VelvetColors.appBarTextSecondary,
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: VelvetColors.surface,
                              // isScrollControlled lets the sheet
                              // exceed the default half-screen cap
                              // — needed because the custom-time
                              // TextField triggers the soft keyboard
                              // and the sheet has to grow + resize
                              // to stay above it.
                              isScrollControlled: true,
                              builder: (_) => SleepTimerSheet(),
                            );
                          },
                        );
                      }),
                ])
              ])
        ])));
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
