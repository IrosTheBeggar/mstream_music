import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import 'screens/browser.dart';
import 'screens/album_detail_view.dart';
import 'objects/display_item.dart';
import 'singletons/server_list.dart';
import 'objects/server.dart';
import 'screens/about_screen.dart';
import 'screens/auto_dj.dart';
// import 'screens/downloads.dart'; // DownloadScreen — drawer entry hidden below
import 'singletons/downloads.dart';
import 'singletons/app_messenger.dart';
import 'singletons/migration_manager.dart';
import 'screens/add_server.dart';
import 'screens/manage_server.dart';
import 'screens/settings_screen.dart';
import 'screens/share_playlist_dialog.dart';
import 'singletons/auto_dj_manager.dart';
import 'singletons/media.dart';
import 'singletons/queue_store.dart';
import 'singletons/playlists.dart';
import 'singletons/settings.dart';
import 'theme/velvet_theme.dart';
import 'media/cast_target.dart';
import 'singletons/cast_manager.dart';
import 'widgets/cast_picker_sheet.dart';
import 'l10n/app_localizations.dart';
import 'widgets/player_panel.dart';
import 'widgets/browser_toolbar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the system bars edge-to-edge from the first frame, so a launch that
  // inherits a leftover immersive mode (e.g. the app was killed while the
  // Visualizer had the nav bar hidden) still comes up with the nav bar visible.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Lock to portrait: the player panel, queue, and browser layouts are designed
  // for a tall aspect ratio and are unusable in landscape. Also pinned in the
  // Android manifest (android:screenOrientation) so the launch splash can't
  // flash sideways before Flutter starts.
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  // Settings load must come before MediaManager.start() so the audio
  // handler's _init() can read persisted EQ state when it attaches the
  // AndroidEqualizer to the player.
  await SettingsManager().load();
  await MediaManager().start();
  await PlaylistManager().load();
  await AutoDJManager().load();

  // Wrap MaterialApp in a StreamBuilder bound to the theme + locale
  // settings so switching either triggers a full rebuild. setActive runs
  // *inside* the builder, immediately before MaterialApp returns, so the
  // ThemeData and any direct VelvetColors lookups stay in sync.
  // combineLatest2 (rxdart) merges the two streams into one record so a
  // single StreamBuilder drives both; locale == null follows the device.
  runApp(StreamBuilder<(AppTheme, Locale?, int?)>(
    stream: Rx.combineLatest3(
      SettingsManager().themeStream,
      SettingsManager().localeStream,
      SettingsManager().accentColorStream,
      (AppTheme theme, Locale? locale, int? accent) => (theme, locale, accent),
    ),
    initialData: (
      SettingsManager().appTheme,
      SettingsManager().localeOverride,
      SettingsManager().accentColor,
    ),
    builder: (context, snapshot) {
      final (theme, locale, accent) =
          snapshot.data ?? (AppTheme.dark, null, null);
      // A custom accent (if set) overrides the theme's built-in primary and its
      // derived shades across every theme.
      var palette = paletteFor(theme);
      if (accent != null) palette = palette.withAccent(Color(accent));
      VelvetColors.setActive(palette);
      return MaterialApp(
        title: 'mStream Music',
        scaffoldMessengerKey: rootMessengerKey,
        home: MStreamApp(),
        theme: buildAppTheme(palette),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
      );
    },
  ));
}

class MStreamApp extends StatefulWidget {
  @override
  _MStreamAppState createState() => new _MStreamAppState();
}

class _MStreamAppState extends State<MStreamApp> with WidgetsBindingObserver {
  final GlobalKey<PlayerPanelState> _panelKey = GlobalKey<PlayerPanelState>();
  // The full-screen player overlay sits above the Scaffold, so it would also
  // paint over an open drawer; hide it while the drawer is open.
  final ValueNotifier<bool> _drawerOpen = ValueNotifier<bool>(false);
  StreamSubscription<String>? _castErrorSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the system navigation/status bars visible (drawn edge-to-edge behind
    // the app) whenever the main screen is up. The Visualizer flips to immersive
    // and restores this on exit, but a kill mid-immersive can leak that mode to
    // the next launch — asserting here (and on resume) keeps the nav bar up.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Restore the persisted queue/position once servers are loaded (server
    // items are matched to a configured server by localname to rebuild their
    // streaming URLs). loadServerList's future completes after the list is
    // populated, so the queue comes back at the spot it was left.
    ServerManager().loadServerList().then((_) => QueueStore().init());
    DownloadManager().initDownloader();
    // Resume a storage move that was interrupted by an app restart.
    MigrationManager().resumeIfNeeded();
    // Android 13+ (targetSdk >= 33): OS no longer auto-prompts; audio_service
    // can't run its foreground media notification without this, so playback
    // silently fails. Fire-and-forget — first call shows the system dialog,
    // subsequent calls are no-ops once granted. Must run after runApp so the
    // permission_handler plugin has an Activity to attach the dialog to.
    Permission.notification.request();
    // Surface cast failures (renderer unreachable / session won't connect) as a
    // toast; the handler has already fallen back to local playback.
    _castErrorSub = CastManager().castErrorStream.listen((msg) {
      rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On resume, re-assert edge-to-edge so a hidden nav bar (e.g. left over from
    // the Visualizer's immersive mode) comes back — but only when the main
    // screen is the top route, so we don't fight the Visualizer if it's open.
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    // Flush the queue/position to disk when leaving the foreground, so a
    // backgrounded app that's later killed by the OS still reopens in place.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      QueueStore().saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _castErrorSub?.cancel();
    _drawerOpen.dispose();
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
        final l = AppLocalizations.of(context);
        final pct = p.fraction;
        final label = p.failed
            ? l.migMoveStopped
            : p.done
                ? (p.skipped > 0
                    ? l.migMoveCompleteSkipped(p.skipped)
                    : l.migMoveComplete)
                : l.migMoving(pct != null
                    ? '${(pct * 100).round()}%'
                    : '${p.moved}/${p.total}');
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
                    compactButton(l.migRetry, VelvetColors.primary,
                        () => MigrationManager().retry()),
                  if (!p.done)
                    compactButton(l.cancel, VelvetColors.textSecondary,
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
    final l = AppLocalizations.of(context);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final panel = _panelKey.currentState;
          if (panel != null && panel.isExpanded) {
            panel.collapse();
          } else if (BrowserManager().albumDetail != null) {
            BrowserManager().closeAlbumDetail();
          } else if (BrowserManager().isLoading) {
            // A browse fetch is in flight — Back stops it (and re-enables taps)
            // instead of navigating away.
            BrowserManager().cancelLoading();
          } else if (BrowserManager().browserCache.length > 1) {
            BrowserManager().popBrowser();
          } else {
            SystemNavigator.pop();
          }
        },
        child: Stack(children: [
          Scaffold(
            onDrawerChanged: (open) => _drawerOpen.value = open,
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
                StreamBuilder<CastTarget>(
                    stream: CastManager().activeTargetStream,
                    initialData: CastManager().activeTarget,
                    builder: (context, snapshot) {
                      final casting =
                          !(snapshot.data ?? CastTarget.local).isLocal;
                      return IconButton(
                        icon:
                            Icon(casting ? Icons.cast_connected : Icons.cast),
                        tooltip: AppLocalizations.of(context).castPlayOnTooltip,
                        color: casting ? VelvetColors.primary : null,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: VelvetColors.surface,
                            isScrollControlled: true,
                            builder: (_) => CastPickerSheet(),
                          );
                        },
                      );
                    }),
                StreamBuilder<List<Server>>(
                    stream: ServerManager().serverListStream,
                    builder: (context, snapshot) {
                      final isVisible =
                          snapshot.hasData && snapshot.data!.length > 1;
                      return Visibility(
                        visible: isVisible,
                        child: PopupMenuButton(
                            onSelected: (int selectedServerIndex) async {
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
                                              l.mainFailedToConnect)));
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
              // Consolidated browser chrome (back · label/album · search ·
              // download · add-all) — replaces both the old label-only strip and
              // the Browser's in-body header row. See widgets/browser_toolbar.dart.
              bottom: const BrowserToolbar(),
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
                    Text(l.drawerTagline,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.router),
                title: Text(l.manageServersTitle),
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
                title: Text(l.autoDjTitle),
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
                title: Text(l.shareTitle),
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
                title: Text(l.settingsTitle),
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
                title: Text(l.aboutTitle),
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
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: PlayerPanel.kCollapsedHeight +
                          MediaQuery.of(context).viewPadding.bottom),
                  child: StreamBuilder<DisplayItem?>(
                    stream: BrowserManager().albumDetailStream,
                    initialData: BrowserManager().albumDetail,
                    builder: (context, snap) {
                      final album = snap.data;
                      // Album detail renders over the browser, which stays alive
                      // in the IndexedStack so its scroll/search survive. Same
                      // browser model (no route), so the mini-player overlay —
                      // which sits above this Scaffold — stays visible.
                      return IndexedStack(
                        index: album == null ? 0 : 1,
                        sizing: StackFit.expand,
                        children: [
                          Browser(),
                          album == null
                              ? const SizedBox.shrink()
                              : AlbumDetailView(
                                  key: ValueKey(album), album: album),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ]),
          ),
          // Full-screen player overlay — collapsed it's the bottom mini-player;
          // expanded it rises over the app bar into a full Now Playing screen.
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _drawerOpen,
              builder: (_, open, child) =>
                  Offstage(offstage: open, child: child),
              child: PlayerPanel(key: _panelKey),
            ),
          ),
        ]));
  }
}

class CustomEvent {
  final Server? autoDJState;

  CustomEvent(this.autoDJState);
}
