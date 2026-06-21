import 'dart:async';
import 'dart:io' show HttpOverrides;

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
import 'singletons/api.dart';
import 'singletons/file_explorer.dart';
import 'singletons/app_messenger.dart';
import 'singletons/migration_manager.dart';
import 'screens/add_server.dart';
import 'screens/manage_server.dart';
import 'screens/settings_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/transcode_screen.dart';
import 'screens/share_playlist_dialog.dart';
import 'singletons/auto_dj_manager.dart';
import 'singletons/media.dart';
import 'singletons/queue_store.dart';
import 'singletons/log_manager.dart';
import 'app_version.dart';
import 'build_variant.dart';
import 'util/self_signed_overrides.dart';
import 'singletons/playlists.dart';
import 'singletons/settings.dart';
import 'theme/velvet_theme.dart';
import 'media/cast_target.dart';
import 'media/auto_browse.dart';
import 'singletons/cast_manager.dart';
import 'widgets/cast_picker_sheet.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'native/iroh_tunnel.dart';
import 'widgets/iroh_repair_sheet.dart';
import 'l10n/app_localizations.dart';
import 'widgets/player_panel.dart';
import 'widgets/browser_toolbar.dart';

void main() {
  // Run the app inside a Zone whose print() handler tees every log line into
  // the in-app diagnostic buffer (LogManager) — so users can view / copy /
  // share logs from the Diagnostics screen — while still forwarding to the
  // console / logcat. Uncaught async errors are captured here too; Flutter
  // framework errors reach the buffer via their default debugPrint path.
  runZonedGuarded(_startApp, (Object error, StackTrace stack) {
    LogManager().add('Uncaught: $error\n$stack');
  }, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, String line) {
      LogManager().add(line);
      parent.print(zone, line);
    },
  ));
}

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Full flavor only: route API HTTPS through an override that accepts a
  // self-signed cert for servers the user explicitly opted in
  // (Server.allowSelfSigned). Must be set before any HttpClient is created.
  // Streaming self-signed is handled separately (native, ExoPlayer).
  if (!isPlayBuild) HttpOverrides.global = SelfSignedHttpOverrides();
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
  // Resolve the album-art ContentProvider authority from the real package name
  // so Android Auto cover art works on any build (not just VARIANT=play ones).
  await initAutoArt();
  await MediaManager().start();
  // Saved playlists + AutoDJ config aren't needed for the first frame, and both
  // are independent pure-disk reads — start them off the critical path so two
  // sequential disk round-trips don't delay first paint. Both are stream-backed,
  // so the Playlists / AutoDJ screens populate when the reads land.
  unawaited(PlaylistManager().load());
  unawaited(AutoDJManager().load());
  appLog('[app] mStream $kAppVersion started');

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
  const MStreamApp({super.key});

  @override
  State<MStreamApp> createState() => _MStreamAppState();
}

class _MStreamAppState extends State<MStreamApp> with WidgetsBindingObserver {
  final GlobalKey<PlayerPanelState> _panelKey = GlobalKey<PlayerPanelState>();
  // The drawer is hosted on an OUTER Scaffold that wraps the player overlay (see
  // build), so the drawer + scrim paint OVER the player — it dims with the rest
  // of the content instead of floating above an open menu, and no longer needs
  // to be hidden. This key lets the app-bar hamburger open that outer drawer.
  final GlobalKey<ScaffoldState> _outerScaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<String>? _castErrorSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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
    // Suppress the home-grid flash when a non-browser startup view is set: the
    // browser shows a loading state until the chosen section loads. Set before
    // loadServerList so it's already true before the home grid first renders.
    BrowserManager().awaitingStartupView =
        SettingsManager().startupView != StartupView.browser;
    ServerManager().ensureLoaded().then((_) {
      QueueStore().init();
      unawaited(_maybeOpenStartupView());
    });
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
    // An iroh tunnel is a long-lived QUIC connection; unlike fresh per-request
    // HTTP sockets it needs an explicit kick when the device network changes.
    // Nudge it on every connectivity transition that has a usable network.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        unawaited(ServerManager().handleNetworkChange());
      }
    });
  }

  // Honors the "Startup page" setting: when it's not the browser, open that
  // browser section on top of the home grid once servers have loaded — firing
  // the same loader the matching home-grid tile does. The section is pushed
  // onto the browser stack, so the system Back button returns to the browser
  // home. While it loads, BrowserManager.awaitingStartupView (set in initState)
  // keeps the browser on a spinner instead of the home grid, so the app lands
  // directly on the section. Skipped on first run (no server configured).
  Future<void> _maybeOpenStartupView() async {
    final view = SettingsManager().startupView;
    final server = ServerManager().currentServer;
    if (view == StartupView.browser || server == null) {
      BrowserManager().awaitingStartupView = false;
      return;
    }
    try {
      switch (view) {
        case StartupView.browser:
          break;
        case StartupView.fileExplorer:
          await ApiManager().getFileList('~', useThisServer: server);
          break;
        case StartupView.playlists:
          await ApiManager().getPlaylists(useThisServer: server);
          break;
        case StartupView.albums:
          await ApiManager().getAlbums(useThisServer: server);
          break;
        case StartupView.artists:
          await ApiManager().getArtists(useThisServer: server);
          break;
        case StartupView.rated:
          await ApiManager().getRated(useThisServer: server);
          break;
        case StartupView.recent:
          await ApiManager().getRecentlyAdded(useThisServer: server);
          break;
        case StartupView.localFiles:
          await FileExplorer().getPathForServer(server);
          break;
      }
    } finally {
      // Stop suppressing the home grid. On success the section is already
      // showing; on failure (nothing pushed) re-emit so the home grid renders
      // instead of a stuck spinner.
      if (BrowserManager().awaitingStartupView) {
        BrowserManager().awaitingStartupView = false;
        BrowserManager().updateStream();
      }
    }
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
    // A tunnel can die while backgrounded (idle drop / process pressure); on
    // resume, nudge iroh + rebuild it if it's hard-down. Fire-and-forget — the
    // native start can block for tens of seconds.
    if (state == AppLifecycleState.resumed) {
      unawaited(ServerManager().handleNetworkChange());
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
    _connectivitySub?.cancel();
    DownloadManager().dispose();
    super.dispose();
  }

  // Banner for the active iroh server: reconnecting (transient), re-pair needed
  // (rotated secret), disconnected (hard-down), or — when connected — a heads-up
  // that we're on a slower relay path (the optimal direct path stays hidden, so
  // everyday use is clean). Hidden entirely for non-iroh servers. Plain English.
  Widget _tunnelBanner() {
    return StreamBuilder<IrohTunnelStatus>(
      stream: ServerManager().tunnelStatusStream,
      initialData: ServerManager().tunnelStatus,
      builder: (context, snap) {
        final st = snap.data ?? IrohTunnelStatus.down;
        if (ServerManager().currentServer?.isIroh != true) {
          return const SizedBox.shrink();
        }
        final l = AppLocalizations.of(context);
        // Connected: surface only the relayed case. Watch the path-kind stream so
        // the strip appears/clears as iroh re-homes between a direct (hole-punched)
        // and a relayed path during the session.
        if (st == IrohTunnelStatus.connected) {
          return StreamBuilder<IrohPathKind>(
            stream: ServerManager().pathKindStream,
            initialData: ServerManager().pathKind,
            builder: (context, pk) {
              if ((pk.data ?? IrohPathKind.unknown) != IrohPathKind.relay) {
                return const SizedBox.shrink();
              }
              return _bannerStrip(
                  Icons.cloud_queue, VelvetColors.warning, l.irohBannerRelay);
            },
          );
        }
        switch (st) {
          case IrohTunnelStatus.rejected:
            return _bannerStrip(
                Icons.link_off,
                VelvetColors.error,
                l.irohBannerRepair,
                action: TextButton(
                  onPressed: () => showIrohRepairSheet(context),
                  child: Text(l.irohRepairAction,
                      style: TextStyle(color: VelvetColors.primary)),
                ));
          case IrohTunnelStatus.down:
            return _bannerStrip(
                Icons.cloud_off, VelvetColors.warning, l.irohBannerDisconnected,
                action: TextButton(
                  onPressed: () =>
                      unawaited(ServerManager().handleNetworkChange()),
                  child: Text(l.irohRetry,
                      style: TextStyle(color: VelvetColors.primary)),
                ));
          case IrohTunnelStatus.connecting:
            return _bannerStrip(
                Icons.sync, VelvetColors.warning, l.irohBannerConnecting,
                action: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ));
          default: // reconnecting
            return _bannerStrip(
                Icons.sync_problem, VelvetColors.warning, l.irohBannerReconnecting,
                action: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ));
        }
      },
    );
  }

  // Thin iroh status strip — matches the migration banner's Material + padding +
  // row layout (icon · message · optional trailing action/spinner).
  Widget _bannerStrip(IconData icon, Color color, String text, {Widget? action}) {
    return Material(
      color: VelvetColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 13)),
          ),
          ?action,
        ]),
      ),
    );
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
          final scaffold = _outerScaffoldKey.currentState;
          final panel = _panelKey.currentState;
          if (scaffold != null && scaffold.isDrawerOpen) {
            // The nav drawer is open — Back closes it, instead of popping the
            // browser / exiting the app behind the open menu. PopScope has
            // canPop:false, so the drawer's own back-dismissal never fires; we
            // close it explicitly here.
            scaffold.closeDrawer();
          } else if (panel != null && panel.isExpanded) {
            panel.collapse();
          } else if (BrowserManager().albumDetail != null) {
            BrowserManager().closeAlbumDetail();
          } else if (BrowserManager().isLoading) {
            // A browse fetch is in flight — Back stops it (and re-enables taps)
            // instead of navigating away.
            BrowserManager().cancelLoading();
          } else if (BrowserManager().searchFocused) {
            // The home search field has focus (e.g. Back just dismissed the
            // keyboard) — drop focus so the search-scope preview slides away,
            // rather than popping/exiting on the same press.
            FocusManager.instance.primaryFocus?.unfocus();
          } else if (BrowserManager().search.open) {
            // The local (in-list) filter search is open — Back closes it, which
            // removes the LocalSearchBar (releasing its focus/highlight and the
            // keyboard), instead of popping the browser behind a still-open
            // search field.
            BrowserManager().closeSearch();
          } else if (BrowserManager().browserCache.length > 1) {
            BrowserManager().popBrowser();
          } else {
            SystemNavigator.pop();
          }
        },
        // The drawer lives on this OUTER Scaffold so its scrim + panel paint
        // OVER the player overlay below — the mini-player dims with the rest of
        // the content as the drawer slides in, instead of blinking out (it used
        // to be Offstage'd) or floating on top of the open menu.
        child: Scaffold(
          key: _outerScaffoldKey,
          // Keep the body full-height when the keyboard opens (see _homeScaffold).
          resizeToAvoidBottomInset: false,
          drawer: _appDrawer(context, l),
          body: Stack(children: [
            _homeScaffold(context, l),
            // Full-screen player overlay — collapsed it's the bottom mini-player;
            // expanded it rises over the app bar into the full Now Playing view.
            // RepaintBoundary isolates the playing scrubber/waveform's per-frame
            // repaints so they don't redraw the browser list painted behind it.
            Positioned.fill(
              child: RepaintBoundary(child: PlayerPanel(key: _panelKey)),
            ),
          ]),
        ));
  }

  // The home scaffold: app bar (logo · server picker · cast · browser toolbar)
  // over the browser ↔ album-detail body. It sits BELOW the player overlay and
  // the outer Scaffold's drawer in build()'s Stack, so an open drawer dims it
  // like any other content.
  Widget _homeScaffold(BuildContext context, AppLocalizations l) {
    return Scaffold(
      // The only text input over this Scaffold is the search field in the
      // toolbar (always at the top, never under the keyboard), so don't
      // resize the body when the keyboard opens. Resizing shrank the body
      // and turned the reserved mini-player strip into a grey band above
      // the keyboard — and squeezed the 27-letter scrubber into a RenderFlex
      // overflow. Leaving the body full-height keeps the list under the
      // keyboard (scrollable) with no grey gap.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        // Opens the drawer on the OUTER Scaffold (this one has none), so the
        // drawer paints over the player overlay rather than under it.
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          onPressed: () => _outerScaffoldKey.currentState?.openDrawer(),
        ),
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
                final casting = !(snapshot.data ?? CastTarget.local).isLocal;
                return IconButton(
                  icon: Icon(casting ? Icons.cast_connected : Icons.cast),
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
                final isVisible = snapshot.hasData && snapshot.data!.length > 1;
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
                            // Use the app-wide messenger key, not
                            // ScaffoldMessenger.of(context): this runs
                            // after two awaits, by which point the
                            // captured context may be unmounted (the
                            // StreamBuilder rebuilt / the menu closed).
                            rootMessengerKey.currentState?.showSnackBar(
                                SnackBar(content: Text(l.mainFailedToConnect)));
                          }
                        } else if (selectedServerIndex == -1) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AddServerScreen()));
                        }
                      },
                      icon: Icon(Icons.cloud),
                      itemBuilder: (BuildContext context) {
                        List<PopupMenuEntry<int>> popUpWidgetList =
                            ServerManager().serverList.map((server) {
                          return PopupMenuItem(
                            value: ServerManager().serverList.indexOf(server),
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
      body: Column(children: [
        _migrationBanner(),
        _tunnelBanner(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: PlayerPanel.kCollapsedHeight +
                    MediaQuery.viewPaddingOf(context).bottom),
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
                        : AlbumDetailView(key: ValueKey(album), album: album),
                  ],
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  // The navigation drawer, hosted on the OUTER Scaffold (see build) so its
  // scrim paints over the player overlay. `context` is build()'s, so a
  // ListTile's Navigator.pop() still closes the drawer (it removes the
  // drawer's local-history entry on the home route).
  Widget _appDrawer(BuildContext context, AppLocalizations l) {
    return Drawer(
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
                Icon(Icons.graphic_eq, color: VelvetColors.primary, size: 32),
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
                  style: TextStyle(fontSize: 22, letterSpacing: -0.3),
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
              MaterialPageRoute(builder: (context) => ManageServersScreen()),
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
          leading: Icon(Icons.transform),
          title: Text(l.transcodeTitle),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TranscodeScreen()),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.bug_report_outlined),
          title: Text(l.diagnosticsTitle),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DiagnosticsScreen()),
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
      ]),
    );
  }
}

class CustomEvent {
  final Server? autoDJState;

  CustomEvent(this.autoDJState);
}
