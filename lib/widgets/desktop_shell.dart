// desktop_shell.dart — the wide/desktop layout, in the shape of a traditional
// desktop music player: a top bar of section tabs (Now Playing · Library ·
// P2P · Federation · Visualizer · Stats · Settings) with the server picker,
// the Library tab keeping a persistent left sidebar (search · music · tools)
// beside the browse / album-detail area in a nested Navigator (tool screens
// open inside the content pane while the sidebar and player stay put) and an
// optional right-hand queue panel, the other tabs hosting their phone screens
// in Navigators of their own, and a full-width Now Playing bar pinned to the
// bottom under all of it (art · transport · seek · volume · queue).
//
// Chosen over the phone shell by a width breakpoint in MStreamApp.build (desktop
// platforms only). This is a VIEW only: it reads the same singletons / streams
// as the mobile UI and drives the same AudioPlayerHandler — no playback or
// business logic lives here.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, KeyDownEvent, LogicalKeyboardKey;
import 'package:rxdart/rxdart.dart';

import '../util/desktop_platform.dart';
import '../l10n/app_localizations.dart';
import '../media/cast_target.dart';
import '../objects/display_item.dart';
import '../objects/lyrics.dart';
import '../objects/server.dart';
import '../screens/add_server.dart';
import '../screens/album_detail_view.dart';
import '../screens/auto_dj.dart';
import '../screens/browser.dart';
import '../screens/desktop_search.dart';
import '../screens/discover_screen.dart';
import '../screens/federation/federation_screen.dart';
import '../screens/listening/listening_screen.dart';
import '../screens/p2p/p2p_screen.dart';
import '../screens/manage_server.dart';
import '../screens/metadata_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/share_playlist_dialog.dart';
import '../screens/transcode_screen.dart';
import '../singletons/api.dart';
import '../singletons/app_messenger.dart';
import '../singletons/browser_list.dart';
import '../singletons/log_manager.dart';
import '../singletons/cast_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../native/projectm_controller.dart';
import '../native/projectm_desktop.dart';
import '../theme/velvet_theme.dart';
import 'desktop_toast.dart';
import '../util/hotkeys.dart';
import '../util/image_cache.dart';
import '../util/media_format.dart';
import '../util/wake_guard.dart';
import '../util/startup_view.dart';
import '../visualizer/projectm_screen.dart';
import '../visualizer/shader_visualizer_screen.dart';
import 'browser_toolbar.dart';
import 'cast_picker_sheet.dart';
import 'star_rating.dart';
import 'media_shortcuts.dart';
import 'playlist_name_dialog.dart';
import 'queue_list.dart';

// Width of the fixed left navigation rail. The right queue panel's width is
// computed at build time to match the now-playing view (see _DesktopShellState).
const double _kSidebarWidth = 208;
// The app-drawn top bar (_DesktopTopBar): the chrome-black band carrying the
// wordmark, the section tabs and the server picker. On macOS it is also the
// window title bar, with the native traffic lights floating over its left end.
const double _kTitleBarHeight = 52;
// Now Playing bar, top to bottom: breathing room, the elapsed/duration row,
// the waveform seek strip, then the controls row (which keeps the original
// 64px it was designed at).
const double _kBarTopPad = 8;
const double _kTimeRowHeight = 16;
const double _kSeekStripHeight = 32;
const double _kControlsHeight = 64;
const double _kNowPlayingHeight =
    _kBarTopPad + _kTimeRowHeight + _kSeekStripHeight + _kControlsHeight;

class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

// The top bar's destinations. Now Playing is a full-window view laid over
// whichever tab it was opened from (see _tabUnderNowPlaying); the rest are
// bodies of their own.
enum _ShellTab { nowPlaying, library, p2p, federation, visualizer, stats, settings }

// Which tabs the top bar shows for [s] — the phone home's group rule: a group
// the server cannot serve is left out, never greyed. P2P and Federation need
// a non-federated server that advertises them (Federation also shows for
// anyone with peers to browse).
List<_ShellTab> _tabsFor(Server? s) {
  final network = s != null && !s.isFederated;
  return [
    _ShellTab.nowPlaying,
    _ShellTab.library,
    if (network && (s.p2pAvailable == true || s.discoveryP2pAvailable == true))
      _ShellTab.p2p,
    if (network &&
        (s.federationAvailable == true ||
            ServerManager().federatedChildren(s).isNotEmpty))
      _ShellTab.federation,
    _ShellTab.visualizer,
    _ShellTab.stats,
    _ShellTab.settings,
  ];
}

class _DesktopShellState extends State<DesktopShell> {
  // The Library tab's content pane is its own Navigator so tool screens push
  // WITHIN it — keeping the sidebar, the top bar and the Now Playing bar
  // visible — instead of covering the whole window the way a root-level push
  // would. Every other tab's body gets the same treatment (_TabNavigator).
  final GlobalKey<NavigatorState> _contentNav = GlobalKey<NavigatorState>();

  // Highlighted sidebar destination, by key. '' = the browse landing; a
  // category key ('albums', …), a tool key, or 'search'.
  String _active = '';
  bool _queueOpen = false;
  // Which dock panel shows beside the browse pane while the dock is open.
  _DockTab _dockTab = _DockTab.queue;
  // The top bar's current tab. Now Playing (polish #7) lays over whichever
  // tab it was opened from — via the bar's expand glyph or its own tab — and
  // returns there on close (esc / the corner chip / any other tab).
  // _npVisualizer switches its backdrop between blurred album art and the
  // live shader visualizer.
  _ShellTab _tab = _ShellTab.library;
  _ShellTab _tabUnderNowPlaying = _ShellTab.library;
  bool _npVisualizer = false;
  // Party mode: OS fullscreen + a soft lock that removes the exits (esc /
  // close / the top bar, which the view then covers), holds the display
  // awake, and disables library-affecting controls. Unlocked by
  // hold-to-confirm, gated behind the optional PIN when one is set.
  bool _npLocked = false;

  Future<void> _setPartyMode(bool on) async {
    setState(() => _npLocked = on);
    if (on) {
      await WakeGuard.instance.acquire();
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
      WakeGuard.instance.release();
    }
  }

  bool get _nowPlayingOpen => _tab == _ShellTab.nowPlaying;

  void _openNowPlaying() {
    if (_nowPlayingOpen) return;
    setState(() {
      _tabUnderNowPlaying = _tab;
      _tab = _ShellTab.nowPlaying;
    });
  }

  void _closeNowPlaying() {
    // A lingering fullscreen/lock must never outlive the view.
    if (_npLocked) _setPartyMode(false);
    setState(() => _tab = _tabUnderNowPlaying);
  }

  void _openTab(_ShellTab tab) {
    if (tab == _ShellTab.nowPlaying) {
      _openNowPlaying();
      return;
    }
    if (_npLocked) return; // party mode owns the exits
    setState(() => _tab = tab);
  }

  // Sidebar and search actions belong to the Library tab; reaching them from
  // elsewhere (the server picker's Manage Servers, ⌘K) lands there first.
  void _ensureLibrary() {
    if (_tab != _ShellTab.library) _openTab(_ShellTab.library);
  }

  // Native Milkdrop visualizer is desktop-only and needs the engine DLL loaded.
  static final bool _projectMAvailable =
      ProjectMDesktop.isSupported && ProjectMController.isAvailable;

  Server? get _server => ServerManager().currentServer;

  // MUSIC section: direct browse destinations. Each loads its view into the
  // shared browse pane via the same ApiManager calls the phone browser uses.
  late final List<_Category> _categories = [
    _Category(
      'files',
      Icons.folder_outlined,
      'File Explorer',
      () => ApiManager().getFileList('~', useThisServer: _server),
    ),
    _Category(
      'playlists',
      Icons.queue_music,
      'Playlists',
      () => ApiManager().getPlaylists(useThisServer: _server),
    ),
    _Category(
      'albums',
      Icons.album_outlined,
      'Albums',
      () => ApiManager().getAlbums(useThisServer: _server),
    ),
    _Category(
      'artists',
      Icons.person_outline,
      'Artists',
      () => ApiManager().getArtists(useThisServer: _server),
    ),
    _Category(
      'recent',
      Icons.fiber_new_outlined,
      'Recently Added',
      () => ApiManager().getRecentlyAdded(useThisServer: _server),
    ),
    _Category(
      'rated',
      Icons.star_outline,
      'Rated',
      () => ApiManager().getRated(useThisServer: _server),
    ),
  ];

  // TOOLS section: screens pushed into the content pane.
  late final List<_NavItem> _tools = [
    _NavItem(
      'autodj',
      Icons.album_outlined,
      (l) => l.autoDjTitle,
      (_) => AutoDJScreen(),
    ),
    _NavItem(
      'transcode',
      Icons.transform,
      (l) => l.transcodeTitle,
      (_) => TranscodeScreen(),
    ),
  ];

  // Reached from the server picker's menu rather than the sidebar; opens in
  // the Library's content pane like any tool.
  late final _NavItem _manageServers = _NavItem(
    'manageServers',
    Icons.dns_outlined,
    (l) => l.manageServersTitle,
    (_) => ManageServersScreen(),
  );

  // Sidebar highlight for the startup section: the launch loader and a server
  // switch open a section directly (bypassing _openCategory), so mirror it here.
  static const Map<StartupView, String> _startupSectionKeys = {
    StartupView.fileExplorer: 'files',
    StartupView.playlists: 'playlists',
    StartupView.albums: 'albums',
    StartupView.artists: 'artists',
    StartupView.recent: 'recent',
    StartupView.rated: 'rated',
  };
  String get _startupKey =>
      _startupSectionKeys[SettingsManager().effectiveStartupView] ?? '';

  StreamSubscription<Server?>? _serverSub;

  @override
  void initState() {
    super.initState();
    // Highlight the startup section on launch, and re-sync whenever the current
    // server switches — both load their section directly, so _openCategory
    // (which normally sets the highlight) never runs.
    _active = _startupKey;
    _serverSub = ServerManager().currentServerStream.distinct().listen((s) {
      if (!mounted) return;
      setState(() {
        _active = _startupKey;
        // A tab the new server cannot serve (P2P / Federation) folds back to
        // the Library rather than showing a screen for the wrong server.
        final visible = _tabsFor(s);
        if (!visible.contains(_tab)) _tab = _ShellTab.library;
        if (!visible.contains(_tabUnderNowPlaying)) {
          _tabUnderNowPlaying = _ShellTab.library;
        }
      });
    });
  }

  @override
  void dispose() {
    _serverSub?.cancel();
    super.dispose();
  }

  // Reset to the browse root so destinations never stack on each other. Also
  // dismisses an open album detail: it's an overlay ABOVE the browse pane
  // (IndexedStack in _DesktopBrowseView), so without this a sidebar jump
  // loads the new section underneath while the album panel stays up.
  void _showBrowse() {
    BrowserManager().closeAlbumDetail();
    _contentNav.currentState?.popUntil((r) => r.isFirst);
  }

  void _openCategory(_Category cat) {
    _ensureLibrary();
    _showBrowse();
    cat.load();
    setState(() => _active = cat.key);
  }

  // The server-wide search page (sidebar tile + ⌘K). ⌘K toggles: a second
  // press while the page is up pops back to browse. The browse list's LOCAL
  // filter (which this tile used to open) moved to ⌘F — see the MediaShortcuts
  // extra bindings in build().
  bool _searchOpen = false;
  void _openSearch() {
    _ensureLibrary();
    if (_searchOpen) {
      _contentNav.currentState?.maybePop();
      return;
    }
    _showBrowse();
    _searchOpen = true;
    // Zero-duration route: sidebar destinations swap the content pane in
    // place, so search appearing with a slide read as foreign. It still
    // rides the content Navigator (Esc/⌘K pop it, _showBrowse clears it on
    // any sidebar jump) — it just materializes like every other page.
    _contentNav.currentState
        ?.push(PageRouteBuilder(
          pageBuilder: (_, _, _) => const DesktopSearchScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ))
        .then((_) => _searchOpen = false);
    setState(() => _active = 'search');
  }

  void _openTool(_NavItem tool) {
    _ensureLibrary();
    _showBrowse();
    _contentNav.currentState?.push(
      MaterialPageRoute(builder: (_) => tool.build(context)),
    );
    setState(() => _active = tool.key);
  }

  // The body of a top-bar tab other than Library: the phone's screen, in its
  // own Navigator so its sub-screens (peer detail, federation settings, …)
  // push inside the pane. Built only while the tab shows — the visualizer in
  // particular must not keep rendering offstage.
  Widget _tabBody(_ShellTab tab, Server? server) {
    switch (tab) {
      case _ShellTab.p2p:
        return server == null
            ? const _NoServerPane()
            : P2pScreen(server: server);
      case _ShellTab.federation:
        return server == null
            ? const _NoServerPane()
            : FederationScreen(parent: server);
      case _ShellTab.visualizer:
        // The engine picked in Settings, when the native one is loadable here.
        final milkdrop = _projectMAvailable &&
            SettingsManager().visualizerEngine == VisualizerEngine.milkdrop;
        return milkdrop
            ? const ProjectMScreen()
            : const ShaderVisualizerScreen();
      case _ShellTab.stats:
        return const ListeningScreen();
      case _ShellTab.settings:
        return SettingsScreen();
      case _ShellTab.library:
      case _ShellTab.nowPlaying:
        return const SizedBox.shrink(); // never a tab body — see build()
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;
    // Match the queue panel's width to the now-playing view — the bar's right
    // third (Expanded flex 1 of the flex-2 center + flex-1 now-playing split).
    // When the queue opens it then covers exactly that region and the transport
    // doesn't shift. (No dividers off this width: sidebar↔content is a tone
    // boundary and browse↔queue share one flat field.)
    final queueWidth =
        (MediaQuery.sizeOf(context).width - _kSidebarWidth) / 3;
    // Now Playing lays over the tab it opened from, which keeps rendering
    // underneath — state and all — exactly as it was left.
    final under = _nowPlayingOpen ? _tabUnderNowPlaying : _tab;
    final library = Row(
      children: [
        _DesktopSidebar(
          categories: _categories,
          tools: _tools,
          active: _active,
          onCategory: _openCategory,
          onSearch: _openSearch,
          onTool: _openTool,
        ),
        Expanded(
          child: Navigator(
            key: _contentNav,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const _DesktopBrowseView(),
            ),
          ),
        ),
        // Dock column (queue · lyrics · similar · info) — no divider against
        // the browse pane: both sit on one flat field, web-app style, and only
        // their content rows rise above it.
        if (_queueOpen)
          SizedBox(
            width: queueWidth,
            child: _DesktopDock(
              tab: _dockTab,
              onTab: (t) => setState(() => _dockTab = t),
            ),
          ),
      ],
    );
    // Material, not Scaffold, on purpose: a Scaffold here would register with
    // the root ScaffoldMessenger and render every SnackBar full-width across
    // the window bottom — over the Now Playing bar. Desktop notifications go
    // through the corner-toast layer below instead (see DesktopToasts); pushed
    // screens with their own Scaffolds still show their local SnackBars within
    // the content pane, which ends above the bar.
    final shell = Material(
      color: VelvetColors.bg,
      child: Column(
        children: [
          Expanded(
            // The Library keeps its navigator, browse state and queue column
            // alive across tab switches (IndexedStack pauses its tickers while
            // hidden); the other tabs are rebuilt on entry, so the visualizer
            // stops when it is left and P2P / Federation start on a fresh
            // controller for the current server.
            child: IndexedStack(
              index: under == _ShellTab.library ? 0 : 1,
              sizing: StackFit.expand,
              children: [
                library,
                if (under == _ShellTab.library)
                  const SizedBox.shrink()
                else
                  _TabNavigator(
                    key: ValueKey('${under.name}:${server?.localname}'),
                    child: _tabBody(under, server),
                  ),
              ],
            ),
          ),
          // Full-width Now Playing bar under every pane — the sidebar included
          // — so the bar and its scrub line run edge to edge, queue open or
          // closed, and every control sits along the bottom.
          DesktopNowPlayingBar(
            queueOpen: _queueOpen,
            onToggleQueue: () => setState(() => _queueOpen = !_queueOpen),
            onOpenNowPlaying: _openNowPlaying,
            nowPlayingWidth: queueWidth,
          ),
        ],
      ),
    );
    // Wrap the whole shell so the media keys work regardless of which pane has
    // focus (text fields still consume their own keys first). The toast layer
    // sits bottom-right just above the Now Playing bar — the standard desktop
    // notification corner (Windows / VS Code / Slack) — so toasts never cover
    // the transport controls.
    return MediaShortcuts(
      // The two shell-owned actions in the user's keymap (defaults ⌘K / ⌘F,
      // rebindable in Settings > Keyboard Shortcuts): the search page, which
      // toggles, and the browse list's local filter, which lost its sidebar
      // tile to that page. Everything else in the map is player transport
      // and MediaShortcuts runs it directly.
      shellActions: {
        HotkeyAction.openSearch: _openSearch,
        HotkeyAction.localFilter: () => BrowserManager().openSearch(),
      },
      child: Stack(
        children: [
          // The top bar sits above the shell columns but INSIDE this stack,
          // so the locked Now Playing view can still cover the whole window,
          // chrome included.
          Column(
            children: [
              _DesktopTopBar(
                tab: _tab,
                onTab: _openTab,
                onManageServers: () => _openTool(_manageServers),
              ),
              Expanded(child: shell),
            ],
          ),
          // The scrub strip is the TOP BAND of the Now Playing bar itself —
          // the bar reserves _kSeekStripHeight for it (see
          // DesktopNowPlayingBar), and the strip floats over that band,
          // spanning the window's left edge → the bar's now-playing tab
          // (which owns the bar's full-height right corner) in both queue
          // states. The 12px side insets match the elapsed/duration row's
          // padding above, so the strip's ends line up with the time stamps.
          // The waveform bars rise and reflect around the band's center line;
          // with no waveform available the band draws the slim line there.
          Positioned(
            left: 12,
            right: queueWidth + 12,
            bottom: _kControlsHeight,
            height: _kSeekStripHeight,
            child: const _SeekBar(),
          ),
          Positioned(
            // Hug the content pane's bottom-right: when the queue panel is
            // open, shift left past it (+ its divider) so toasts float over
            // the main page, not the queue.
            right: (_queueOpen ? queueWidth : 0) + 16,
            bottom: _kNowPlayingHeight + 16,
            child: const DesktopToastHost(),
          ),
          // Full-window Now Playing dwell mode — topmost. It leaves the top
          // bar clickable (the tabs are a way out) until party mode locks it,
          // when it covers the chrome too (the V2 "backdrop" design).
          if (_nowPlayingOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: _npLocked ? 0 : _kTitleBarHeight,
              child: _NowPlayingOverlay(
                visualizer: _npVisualizer,
                locked: _npLocked,
                onToggleVisualizer: () =>
                    setState(() => _npVisualizer = !_npVisualizer),
                onLock: () => _setPartyMode(true),
                onUnlock: () => _setPartyMode(false),
                onClose: _closeNowPlaying,
              ),
            ),
        ],
      ),
    );
  }
}

// A tab body's own Navigator: the phone screen is the root route, and whatever
// it pushes (peer detail, a settings sub-page) stays inside the pane under the
// top bar and above the Now Playing bar.
class _TabNavigator extends StatelessWidget {
  final Widget child;
  const _TabNavigator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }
}

// P2P / Federation with no server selected — the tabs hide in that state,
// so this only shows if one was reached mid-switch.
class _NoServerPane extends StatelessWidget {
  const _NoServerPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No server selected',
        style: TextStyle(color: VelvetColors.textSecondary),
      ),
    );
  }
}

// A tool destination: a stable key (for highlight), an icon, a localized label,
// and the screen it pushes into the content pane.
class _NavItem {
  final String key;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final Widget Function(BuildContext) build;
  const _NavItem(this.key, this.icon, this.label, this.build);
}

// A MUSIC-section browse destination: a key, icon, label, and the loader that
// fills the shared browse pane (the same ApiManager calls the phone uses).
class _Category {
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback load;
  const _Category(this.key, this.icon, this.label, this.load);
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: VelvetColors.textTertiary,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _DesktopSidebar extends StatelessWidget {
  final List<_Category> categories;
  final List<_NavItem> tools;
  final String active;
  final void Function(_Category) onCategory;
  final VoidCallback onSearch;
  final void Function(_NavItem) onTool;
  const _DesktopSidebar({
    required this.categories,
    required this.tools,
    required this.active,
    required this.onCategory,
    required this.onSearch,
    required this.onTool,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: _kSidebarWidth,
      // Nav tone: on the tricolor themes (Slate/Graphite/Onyx) this is the
      // webapp's scheme — dark frame, a lighter nav panel (navBg), the
      // content field in between. Older themes set navBg = appBarBg and the
      // sidebar shares the frame tone. The quiet right-edge hairline is the
      // shell's only structural divider besides the top bar's accent line
      // (the bar | content boundary is a bare tone shift) — drawn inside the
      // sidebar's width, so nothing shifts.
      decoration: BoxDecoration(
        color: VelvetColors.navBg,
        border: Border(
          right: BorderSide(color: VelvetColors.border2, width: 1),
        ),
      ),
      // The wordmark, the server picker and Settings all live in the top bar
      // now, so the sidebar is the Library's own navigation and nothing else.
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SidebarTile(
            icon: Icons.search,
            label: 'Search',
            selected: active == 'search',
            onTap: onSearch,
          ),
          const _SectionHeader('MUSIC'),
          for (final c in categories)
            _SidebarTile(
              icon: c.icon,
              label: c.label,
              selected: active == c.key,
              onTap: () => onCategory(c),
            ),
          const _SectionHeader('TOOLS'),
          for (final t in tools)
            _SidebarTile(
              icon: t.icon,
              label: t.label(l),
              selected: active == t.key,
              onTap: () => onTool(t),
            ),
        ],
      ),
    );
  }
}

/// The mStream brand mark — amber glyph + split-weight "m"/"Stream" wordmark.
/// One definition serving both slots that show it (the sidebar header on
/// native-chrome platforms, the window title bar elsewhere); size and ink are
/// the only per-slot tuning.
class _Wordmark extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final double gap;
  final Color bright;
  final Color dim;
  const _Wordmark({
    required this.iconSize,
    required this.fontSize,
    required this.gap,
    required this.bright,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.graphic_eq, color: VelvetColors.primary, size: iconSize),
        SizedBox(width: gap),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'm',
                style: TextStyle(fontWeight: FontWeight.w300, color: dim),
              ),
              TextSpan(
                text: 'Stream',
                style: TextStyle(fontWeight: FontWeight.w700, color: bright),
              ),
            ],
          ),
          style: TextStyle(fontSize: fontSize, letterSpacing: -0.3),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar: wordmark · section tabs · server picker
// ---------------------------------------------------------------------------

/// The app-drawn band across the top of the window: the wordmark, the
/// section tabs (Now Playing · Library · P2P · Federation · Visualizer ·
/// Stats · Settings — the network pair only when the server serves them) and
/// the server picker at the right end. On macOS it is also the window title
/// bar (TitleBarStyle.hidden — set in initDesktopWindow): the native traffic
/// lights float over its left end and DragToMoveArea gives the band
/// window-drag plus double-click zoom. Windows/Linux keep their native chrome
/// above it.
class _DesktopTopBar extends StatelessWidget {
  final _ShellTab tab;
  final void Function(_ShellTab) onTab;
  final VoidCallback onManageServers;
  const _DesktopTopBar({
    required this.tab,
    required this.onTab,
    required this.onManageServers,
  });

  /// Clearance for the native close/minimize/zoom cluster, which macOS pins
  /// at its standard spot over the band's left end: three buttons ending at
  /// x ≈ 70 in the hidden-titlebar layout, plus breathing room.
  static const double _trafficLightInset = 80;

  static String _label(AppLocalizations l, _ShellTab t) => switch (t) {
        _ShellTab.nowPlaying => l.nowPlaying,
        _ShellTab.library => 'Library',
        _ShellTab.p2p => 'P2P',
        _ShellTab.federation => l.federationTitle,
        _ShellTab.visualizer => l.visualizerTitle,
        _ShellTab.stats => 'Stats',
        _ShellTab.settings => l.settingsTitle,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // A Material (not a bare DecoratedBox like the old title band): the tabs
    // and the picker are ink surfaces and need one above them.
    final band = Material(
      color: VelvetColors.titleBarBg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: VelvetColors.titleBarLine)),
        ),
        child: SizedBox(
          height: _kTitleBarHeight,
          // The tab set depends on the current server's capabilities, which
          // the ping fills in after the switch — so rebuild on both streams.
          child: StreamBuilder<List<Server>>(
            stream: ServerManager().serverListStream,
            initialData: ServerManager().serverList,
            builder: (context, _) => StreamBuilder<Server?>(
              stream: ServerManager().currentServerStream,
              initialData: ServerManager().currentServer,
              builder: (context, snap) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: usesCustomTitleBar ? _trafficLightInset : 20),
                    Center(
                      child: _Wordmark(
                        iconSize: 22,
                        fontSize: 17,
                        gap: 8,
                        bright: VelvetColors.appBarText,
                        dim: VelvetColors.appBarTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 20),
                    for (final t in _tabsFor(snap.data))
                      _TopTab(
                        label: _label(l, t),
                        selected: t == tab,
                        onTap: () => onTab(t),
                      ),
                    const Spacer(),
                    Center(child: _ServerPicker(onManageServers: onManageServers)),
                    const SizedBox(width: 12),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    return usesCustomTitleBar ? DragToMoveArea(child: band) : band;
  }
}

/// One top-bar destination: label only, the selected one in the primary ink
/// with an accent underline sitting on the band's bottom edge; hover
/// brightens the rest.
class _TopTab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TopTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TopTab> createState() => _TopTabState();
}

class _TopTabState extends State<_TopTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lit = widget.selected || _hover;
    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hover = h),
      hoverColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: widget.selected ? VelvetColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
            color: lit
                ? VelvetColors.appBarText
                : VelvetColors.appBarTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// Current-server pill + a popup to switch servers, add one, or open Manage
/// Servers. Mirrors the phone app bar's server picker (same ServerManager
/// calls); unlike the old sidebar row it shows with a single server too, since
/// it is the one place Add/Manage Servers live on desktop.
class _ServerPicker extends StatelessWidget {
  final VoidCallback onManageServers;
  const _ServerPicker({required this.onManageServers});

  static const int _addServer = -1;
  static const int _manageServers = -2;

  Future<void> _switchTo(BuildContext context, int index) async {
    if (index == _addServer) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AddServerScreen()));
      return;
    }
    if (index == _manageServers) {
      onManageServers();
      return;
    }
    // Capture the localized error before any await — the context may be gone by
    // the time the connect fails, and we surface it through the app-wide
    // messenger (like the phone picker) rather than this element's context.
    final failedMsg = AppLocalizations.of(context).mainFailedToConnect;
    // Hold the browse pane on a spinner for the whole switch (connect + the
    // default section load). Without this the pane renders its interim states
    // mid-switch — the home-menu reset reads as a flash of the offline
    // placeholder before the section lands. Cleared in finally: on success the
    // loaded section renders; on failure the home menu is in place, so the
    // pane settles on the offline placeholder alongside the toast.
    BrowserManager().awaitingSectionLoad = true;
    try {
      await ServerManager().changeCurrentServer(index);
      await ServerManager().getServerPaths(
        ServerManager().currentServer!,
        throwErr: true,
      );
      await ServerManager().callAfterEditServer();
      // Land on the configured default page for the newly-selected server
      // instead of the suppressed home grid / offline placeholder.
      await loadStartupSection(
        SettingsManager().effectiveStartupView,
        ServerManager().currentServer!,
      );
    } catch (_) {
      showGlobalSnack(failedMsg);
    } finally {
      BrowserManager().awaitingSectionLoad = false;
      BrowserManager().updateStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<Server>>(
      stream: ServerManager().serverListStream,
      initialData: ServerManager().serverList,
      builder: (context, _) => StreamBuilder<Server?>(
        stream: ServerManager().currentServerStream,
        initialData: ServerManager().currentServer,
        builder: (context, snap) {
          final server = snap.data;
          final servers = ServerManager().serverList;
          return PopupMenuButton<int>(
            tooltip: '',
            onSelected: (i) => _switchTo(context, i),
            color: VelvetColors.raised,
            itemBuilder: (context) => [
              for (final s in servers)
                PopupMenuItem(
                  value: servers.indexOf(s),
                  child: Text(
                    s.displayName,
                    style: TextStyle(
                      color: s == server
                          ? VelvetColors.primary
                          : VelvetColors.textPrimary,
                    ),
                  ),
                ),
              if (servers.isNotEmpty) const PopupMenuDivider(),
              PopupMenuItem(
                value: _addServer,
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: VelvetColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text('Add server'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _manageServers,
                child: Row(
                  children: [
                    Icon(
                      Icons.dns_outlined,
                      size: 18,
                      color: VelvetColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(l.manageServersTitle),
                  ],
                ),
              ),
            ],
            child: Container(
              height: 32,
              padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
              decoration: BoxDecoration(
                color: VelvetColors.bg,
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 16,
                    color: VelvetColors.appBarTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      server?.displayName ?? 'No server',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: VelvetColors.appBarTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.unfold_more,
                    size: 16,
                    color: VelvetColors.textTertiary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? VelvetColors.primary : VelvetColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected
            ? VelvetColors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            // h:10 so the icon lands 20px from the sidebar edge (10 outer + 10),
            // aligning with the logo, server row, and section headers.
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? VelvetColors.textPrimary
                          : VelvetColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content pane: browse list ↔ album detail (same BrowserManager model as the
// phone shell, just without the app bar / drawer chrome).
// ---------------------------------------------------------------------------

class _DesktopBrowseView extends StatelessWidget {
  const _DesktopBrowseView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VelvetColors.bg,
      child: Column(
        children: [
          // The consolidated browse chrome (back · label · search · download ·
          // add-all), constrained to the shared top-bar height so its divider
          // lines up with the sidebar's and the queue's. The toolbar carries a
          // 6px bottom pad tuned for its phone AppBar slot — cancel it with a
          // matching top pad so the content centers in the taller bar.
          // The toolbar sits directly on the content field (no chrome band) —
          // web-app style: one flat background, only content rows rise.
          const SizedBox(
            height: VelvetColors.desktopTopBarHeight,
            child: Padding(
              padding: EdgeInsets.only(top: 6),
              child: BrowserToolbar(),
            ),
          ),
          Expanded(
            child: StreamBuilder<DisplayItem?>(
              stream: BrowserManager().albumDetailStream,
              initialData: BrowserManager().albumDetail,
              builder: (context, snap) {
                final album = snap.data;
                return IndexedStack(
                  index: album == null ? 0 : 1,
                  sizing: StackFit.expand,
                  children: [
                    const Browser(),
                    album == null
                        ? const SizedBox.shrink()
                        : AlbumDetailView(key: ValueKey(album), album: album),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right-hand queue panel
// ---------------------------------------------------------------------------

// Collapsing the panel is the bar's queue glyph only — a header ✕ read as
// "clear the queue" next to the trash button, so it's gone.
// The four panels that ride beside the browse pane: the queue, and three
// views of the playing track — lyrics, similar tracks (Discover) and song
// info. One shows at a time; the others are built on entry, so nothing
// fetches for a panel nobody is looking at.
enum _DockTab { queue, lyrics, similar, info }

class _DesktopDock extends StatelessWidget {
  final _DockTab tab;
  final void Function(_DockTab) onTab;
  const _DesktopDock({required this.tab, required this.onTab});

  static String _label(AppLocalizations l, _DockTab t) => switch (t) {
        _DockTab.queue => 'Queue',
        _DockTab.lyrics => l.lyricsTitle,
        _DockTab.similar => 'Similar',
        _DockTab.info => 'Info',
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: VelvetColors.surface,
      child: Column(
        children: [
          // The tab strip takes the 56px header band the "Queue" title used
          // to own (it matches the content panes' top bars and sits directly
          // on the flat content field); the queue's actions keep its right
          // end while the queue is the showing panel.
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Row(
                children: [
                  for (final t in _DockTab.values)
                    _DockTabChip(
                      label: _label(l, t),
                      selected: t == tab,
                      onTap: () => onTab(t),
                    ),
                  const Spacer(),
                  if (tab == _DockTab.queue) ...[
                    // Clear is the most-reached-for queue action, so it gets
                    // its own button (same no-confirm behavior as the phone
                    // queue header). Light red: it's destructive, and the tint
                    // separates it from the neutral actions beside it.
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, size: 20),
                      color: VelvetColors.error,
                      tooltip: l.mainClearQueue,
                      onPressed: () => MediaManager()
                          .audioHandler
                          .customAction('clearPlaylist'),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      color: VelvetColors.surface,
                      tooltip: l.mainMore,
                      onSelected: (v) {
                        switch (v) {
                          case 'save':
                            _saveQueueAsPlaylist(context);
                            break;
                          case 'download':
                            downloadQueue(context);
                            break;
                          case 'share':
                            showSharePlaylistDialog(context);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        _queueMenuItem(
                            'save', Icons.playlist_add, 'Save as playlist'),
                        _queueMenuItem(
                          'download',
                          Icons.download_for_offline,
                          l.queueDownloadAll,
                        ),
                        _queueMenuItem(
                            'share', Icons.share_outlined, l.shareTitle),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: _body(l)),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    switch (tab) {
      case _DockTab.queue:
        return const QueueList(showItemMenu: true);
      case _DockTab.lyrics:
        // The full-screen view's synced pane, following the playing track.
        return StreamBuilder<MediaItem?>(
          stream: MediaManager().audioHandler.mediaItem,
          builder: (context, snap) => _NowPlayingLyrics(
            item: snap.data,
            placeholder: _DockNote(
              snap.data == null ? 'Nothing playing' : l.lyricsEmpty,
            ),
          ),
        );
      case _DockTab.similar:
        // No explicit seed: the screen follows the playing track and
        // refreshes on track change — the phone player's Discover entry,
        // minus its app bar.
        return const DiscoverScreen(embedded: true);
      case _DockTab.info:
        return StreamBuilder<MediaItem?>(
          stream: MediaManager().audioHandler.mediaItem,
          builder: (context, snap) {
            final item = snap.data;
            if (item == null) return const _DockNote('Nothing playing');
            return MetadataScreen(
              key: ValueKey(item.id),
              item: item,
              embedded: true,
            );
          },
        );
    }
  }
}

/// One dock tab: a rounded chip, the showing one lifted on the accent tint.
class _DockTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DockTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected
            ? VelvetColors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? VelvetColors.textPrimary
                    : VelvetColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dock panel with nothing to show yet (no track, no lyrics).
class _DockNote extends StatelessWidget {
  final String text;
  const _DockNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: VelvetColors.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}

PopupMenuItem<String> _queueMenuItem(
  String value,
  IconData icon,
  String label,
) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: VelvetColors.textSecondary),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}

/// Save the current queue as a server playlist: collect the queue's server-track
/// paths, prompt for a name, then POST /playlist/save. Local-only / no-server
/// items (which can't live in a server playlist) are skipped.
Future<void> _saveQueueAsPlaylist(BuildContext context) async {
  final paths = MediaManager().audioHandler.queue.value
      .map((m) => m.extras?['path'])
      .whereType<String>()
      .toList();
  if (paths.isEmpty) {
    showGlobalSnack('Nothing in the queue to save');
    return;
  }
  final name = await PlaylistNameDialog.show(
    context,
    title: 'Save as playlist',
    action: 'Save',
  );
  if (name == null || name.isEmpty) return;
  // Master's savePlaylist takes the target server explicitly (the sonic-path
  // flow saves to the seed track's server); the queue save keeps its old
  // semantics — the CURRENT server — and refreshes the sidebar's playlists,
  // which the old makeServerCall-based variant did implicitly.
  final server = ServerManager().currentServer;
  if (server == null) {
    showGlobalSnack('No server selected');
    return;
  }
  try {
    await ApiManager().savePlaylist(server, name, paths);
    await ApiManager().refreshPlaylists();
    showGlobalSnack('Saved “$name”');
  } catch (_) {
    showGlobalSnack('Couldn’t save the playlist');
  }
}

// ---------------------------------------------------------------------------
// Now Playing bar (full width, pinned to the bottom)
// ---------------------------------------------------------------------------

class DesktopNowPlayingBar extends StatefulWidget {
  final bool queueOpen;
  final VoidCallback onToggleQueue;
  final VoidCallback onOpenNowPlaying;
  // Fixed width for the now-playing view = the queue column's width. Fixed
  // (not Expanded/flex) so the transport keeps the EXACT same width whether
  // the queue is open or closed — a flex split rounds differently than the
  // queue's fixed SizedBox and shifts by ~1px.
  final double nowPlayingWidth;
  const DesktopNowPlayingBar({
    super.key,
    required this.queueOpen,
    required this.onToggleQueue,
    required this.onOpenNowPlaying,
    required this.nowPlayingWidth,
  });

  @override
  State<DesktopNowPlayingBar> createState() => _DesktopNowPlayingBarState();
}

class _DesktopNowPlayingBarState extends State<DesktopNowPlayingBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kNowPlayingHeight,
      // Chrome tone — frames the lighter content zone (see _DesktopSidebar).
      // No divider against the content above: the appBarBg | bg tone shift
      // alone marks the player's edge, the way the queue column meets the
      // browse pane.
      color: VelvetColors.appBarBg,
      // Left portion, top to bottom: breathing room, the elapsed/duration
      // row, the waveform band, the controls. The waveform seek strip itself
      // floats over its band from the shell's root Stack (see
      // _DesktopShellState.build) — it must overlay the Slider across panes,
      // so it can't be a plain child here; the SizedBox only reserves its
      // space. The now-playing tab owns the bar's FULL height on the right
      // (the waveform band stops where it begins) and stays put in both
      // queue states — the queue's actions live in the panel's header.
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: _kBarTopPad),
                const _TimeEndsRow(),
                const SizedBox(height: _kSeekStripHeight),
                Expanded(
                  child: Padding(
                    // Left-only: the right edge runs open so the cast button's
                    // own internal padding + the now-playing pill's padding
                    // supply the gap to the folded queue glyph — the same
                    // rhythm as the gaps between the other buttons.
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        const _DesktopTransport(),
                        const Spacer(),
                        _controls(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Fixed right region (= the queue column's width, so the transport
          // never shifts and the queue column lands exactly on it when open).
          SizedBox(
            width: widget.nowPlayingWidth,
            child: _NowPlayingTab(
              onTap: widget.onToggleQueue,
              // The bar's edge padding lives in the transport row (the
              // waveform band needs flush edges), so the tab carries its own.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: _trackInfo(),
                  ),
                  // The two corner glyphs, bottom-right (the info block reads
                  // art → text from the left, so the actions balance it on
                  // the right). Their centers sit on the controls row's axis
                  // so they read in line with the volume/cast icons; the -6
                  // cancels the tab pill's vertical margin (this Stack lives
                  // inside it).
                  //
                  // Queue toggle at the very corner — adjacent to where the
                  // queue column lands when it opens. The tab and the old
                  // queue button did the same thing, so the glyph just marks
                  // the tab; the whole card toggles.
                  Positioned(
                    right: 0,
                    bottom: (_kControlsHeight - 22) / 2 - 6,
                    child: Icon(
                      Icons.queue_music,
                      size: 22,
                      color: widget.queueOpen
                          ? VelvetColors.primary
                          : VelvetColors.textSecondary,
                    ),
                  ),
                  // Full-screen Now Playing entry, left of the queue glyph.
                  // Unlike its neighbour it carries no open-state highlight
                  // (it opens a screen, it isn't a toggle); hover brightens
                  // it in both queue states. Its own tap wins over the tab's
                  // queue toggle.
                  Positioned(
                    right: 34,
                    bottom: (_kControlsHeight - 22) / 2 - 6,
                    child: _TabGlyphButton(
                      icon: Icons.open_in_full,
                      tooltip: 'Now Playing',
                      onTap: widget.onOpenNowPlaying,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _trackInfo() {
    return StreamBuilder<MediaItem?>(
      stream: MediaManager().audioHandler.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        final extras = item?.extras ?? const <String, dynamic>{};
        final url = extras['artUrl'] as String?;
        final artist = item?.artist ?? '';
        final album = (item?.album ?? '').trim();
        final year = extras['year'];
        final albumLine = [
          if (album.isNotEmpty) album,
          if (year != null && '$year'.isNotEmpty && '$year' != '0') '$year',
        ].join(' · ');
        final bpm = extras['bpm'];
        final musicalKey = (extras['musicalKey'] as String?)?.trim();
        // Same track facts the Song Info screen surfaces, as micro-badges.
        final badges = <Widget>[
          if (bpm != null) _miniBadge('${bpm is num ? bpm.round() : bpm} BPM'),
          if (musicalKey != null && musicalKey.isNotEmpty)
            _miniBadge(musicalKey),
          if (extras['hasLyrics'] == true) _miniBadge('LYRICS'),
        ];
        // Art on the left, then up to four text rows (title / artist /
        // album · year / badges) — the tab owns the bar's whole height, so
        // it carries a real now-playing card's worth of metadata.
        return Row(
          children: [
            // Plain art — the full-screen Now Playing opens via the expand
            // glyph in the tab's corner (next to the queue glyph), not by
            // clicking here: an art tap wasn't discoverable, so the whole
            // card just toggles the queue.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 88,
                height: 88,
                child: url == null
                    ? albumArtFallback(iconSize: 32)
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        cacheWidth: artCacheSize(88),
                        errorBuilder: (_, _, _) =>
                            albumArtFallback(iconSize: 32),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null ? 'Nothing playing' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: item == null
                          ? VelvetColors.textTertiary
                          : VelvetColors.textPrimary,
                    ),
                  ),
                  if (artist.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: VelvetColors.textSecondary,
                      ),
                    ),
                  ],
                  if (albumLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      albumLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: VelvetColors.textTertiary,
                      ),
                    ),
                  ],
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    // Horizontal clip (never scrolls): at narrow widths the
                    // badge row runs out of room before the corner glyphs —
                    // cut it rather than overflow. 60 keeps it clear of them.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(right: 60),
                      child: Row(
                        children: [
                          for (final (i, b) in badges.indexed) ...[
                            if (i > 0) const SizedBox(width: 4),
                            b,
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Micro-badge for the card's facts row — the Song Info chips at bar scale.
  Widget _miniBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        border: Border.all(color: VelvetColors.border2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          height: 1.4,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: VelvetColors.textTertiary,
        ),
      ),
    );
  }

  Widget _controls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Volume icon (click to mute) + slider, both driven by the shared
        // playbackVolume notifier so the Up/Down/M keys move them in lockstep.
        ValueListenableBuilder<double>(
          valueListenable: playbackVolume,
          builder: (context, vol, _) {
            final icon = vol == 0
                ? Icons.volume_off
                : (vol < 0.5 ? Icons.volume_down : Icons.volume_up);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(icon, size: 18),
                  color: VelvetColors.textTertiary,
                  tooltip: 'Mute (M)',
                  visualDensity: VisualDensity.compact,
                  onPressed: togglePlaybackMute,
                ),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      activeTrackColor: VelvetColors.textSecondary,
                      inactiveTrackColor: VelvetColors.border2,
                      thumbColor: VelvetColors.textSecondary,
                    ),
                    child: Slider(
                      value: vol,
                      onChanged: (v) {
                        playbackVolume.value = v;
                        MediaManager().audioHandler.setVolume(v);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(width: 4),
        // Cast picker — the same sheet the phone uses; discovery runs only while
        // it's open. Icon flips to cast_connected (primary) while casting.
        StreamBuilder<CastTarget>(
          stream: CastManager().activeTargetStream,
          initialData: CastManager().activeTarget,
          builder: (context, snap) {
            final casting = !(snap.data ?? CastTarget.local).isLocal;
            return IconButton(
              icon: Icon(casting ? Icons.cast_connected : Icons.cast),
              iconSize: 22,
              tooltip: 'Cast',
              color: casting
                  ? VelvetColors.primary
                  : VelvetColors.textSecondary,
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: VelvetColors.surface,
                isScrollControlled: true,
                builder: (_) => const CastPickerSheet(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Elapsed (left) and total duration (right) riding just above the waveform
/// band, at its two ends — replaces the old inline "elapsed / total" readout
/// that sat next to the transport. Its own combined item+position stream so
/// the per-second tick repaints only this row.
class _TimeEndsRow extends StatefulWidget {
  const _TimeEndsRow();

  @override
  State<_TimeEndsRow> createState() => _TimeEndsRowState();
}

class _TimeEndsRowState extends State<_TimeEndsRow> {
  late final Stream<_MediaPos> _mediaPos = Rx.combineLatest2(
    MediaManager().audioHandler.mediaItem,
    MediaManager().audioHandler.positionStream,
    (MediaItem? item, Duration pos) => _MediaPos(item, pos),
  );

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'monospace', fontSize: 11);
    return SizedBox(
      height: _kTimeRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: StreamBuilder<_MediaPos>(
          stream: _mediaPos,
          builder: (context, snap) {
            final pos = snap.data?.position ?? Duration.zero;
            final dur = snap.data?.item?.duration;
            return Row(
              children: [
                Text(
                  formatDuration(pos),
                  // Elapsed in the accent colour, like the phone player.
                  style: style.copyWith(color: VelvetColors.primary),
                ),
                const Spacer(),
                Text(
                  dur == null ? '--:--' : formatDuration(dur),
                  style: style.copyWith(color: VelvetColors.textTertiary),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Slider track with no end insets, so the seek line runs flush across the
/// transport region's full width.
class _EdgeToEdgeTrackShape extends RoundedRectSliderTrackShape {
  const _EdgeToEdgeTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 3;
    return Rect.fromLTWH(
      offset.dx,
      offset.dy + (parentBox.size.height - h) / 2,
      parentBox.size.width,
      h,
    );
  }
}

/// SoundCloud-style waveform track: amplitude bars mirrored around the
/// content/bar boundary (the strip's vertical center) — the main bars rise
/// above the line, a dimmed reflection dips into the bar's top padding.
/// Played bars take the active (accent) colour, upcoming ones the inactive
/// grey, split at the thumb exactly like the plain track. Peaks are bucketed
/// per ~3px bar (max within the bucket, so short transients survive) and the
/// whole strip repaints only on position ticks / hover / drag.
class _WaveformTrackShape extends SliderTrackShape {
  const _WaveformTrackShape(this.peaks);

  final List<int> peaks;

  static const double _barWidth = 2;
  static const double _barGap = 1;
  // Reflection: height fraction of the main bar, and its opacity.
  static const double _mirror = 0.5;
  static const double _mirrorAlpha = 0.35;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) =>
      Rect.fromLTWH(
          offset.dx, offset.dy, parentBox.size.width, parentBox.size.height);

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    if (peaks.isEmpty) return;
    final rect = getPreferredRect(
        parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final active = (isEnabled
            ? sliderTheme.activeTrackColor
            : sliderTheme.disabledActiveTrackColor) ??
        VelvetColors.primary;
    final inactive = (isEnabled
            ? sliderTheme.inactiveTrackColor
            : sliderTheme.disabledInactiveTrackColor) ??
        VelvetColors.border2;

    final canvas = context.canvas;
    final baseline = rect.center.dy; // the content/bar boundary line
    final maxUp = rect.height / 2 - 1;
    const step = _barWidth + _barGap;
    final n = (rect.width / step).floor();
    if (n <= 0) return;
    final bar = Paint();
    for (var i = 0; i < n; i++) {
      final x = rect.left + i * step;
      final from = (i * peaks.length / n).floor();
      final to =
          ((i + 1) * peaks.length / n).ceil().clamp(from + 1, peaks.length);
      var v = 0;
      for (var j = from; j < to; j++) {
        if (peaks[j] > v) v = peaks[j];
      }
      final h = (v / 255 * maxUp).clamp(1.0, maxUp);
      final color =
          x + _barWidth / 2 <= thumbCenter.dx ? active : inactive;
      bar.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseline - h, _barWidth, h),
          const Radius.circular(1),
        ),
        bar,
      );
      bar.color = color.withValues(alpha: _mirrorAlpha);
      canvas.drawRect(
        Rect.fromLTWH(x, baseline, _barWidth, h * _mirror),
        bar,
      );
    }
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  late final Stream<_MediaPos> _mediaPos = Rx.combineLatest2(
    MediaManager().audioHandler.mediaItem,
    MediaManager().audioHandler.positionStream,
    (MediaItem? item, Duration pos) => _MediaPos(item, pos),
  );

  // Thumb appears only under the pointer (Spotify-style): the line stays
  // clean at rest but remains a full scrubber — and it's the app's ONLY
  // scrubber (the queue foot has none), so the hover/hit zone is generous.
  bool _hover = false;

  // Waveform peaks (0–255) for the CURRENT track, from the server's
  // /api/v1/db/waveform endpoint (the same one the web app's seek bar uses),
  // fetched on track change. null → the plain line (still loading, no
  // matching server, or the server can't provide peaks). Keyed by
  // server|path so a late response can't paint another track's waveform;
  // the small static cache keeps queue back-and-forth from refetching.
  List<int>? _peaks;
  String? _peaksKey;
  static final Map<String, List<int>> _peaksCache = {};
  StreamSubscription<MediaItem?>? _itemSub;

  @override
  void initState() {
    super.initState();
    // BehaviorSubject: replays the current item on listen, so the initial
    // track loads without a separate seed call.
    _itemSub = MediaManager().audioHandler.mediaItem.listen(_loadPeaksFor);
  }

  @override
  void dispose() {
    _itemSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPeaksFor(MediaItem? item) async {
    final path = item?.extras?['path'] as String?;
    final serverName = item?.extras?['server'] as String?;
    final server = ServerManager().byLocalname(serverName);
    if (item == null || path == null || server == null) {
      // Local files / no resolvable server: nothing to ask the server for.
      _peaksKey = null;
      if (mounted && _peaks != null) setState(() => _peaks = null);
      return;
    }
    final key = '$serverName|$path';
    if (key == _peaksKey) return;
    _peaksKey = key;
    final cached = _peaksCache[key];
    if (cached != null) {
      if (mounted) setState(() => _peaks = cached);
      return;
    }
    if (mounted && _peaks != null) setState(() => _peaks = null);
    final wf = await ApiManager().getWaveform(path, useThisServer: server);
    // Stale guard: the track may have changed while the server generated.
    if (!mounted || _peaksKey != key || wf == null) return;
    _peaksCache[key] = wf;
    if (_peaksCache.length > 24) {
      _peaksCache.remove(_peaksCache.keys.first);
    }
    setState(() => _peaks = wf);
  }

  @override
  Widget build(BuildContext context) {
    // The seek line floats in the shell's root Stack, above the Scaffold, so
    // it has no Material ancestor — which Slider requires (debug builds paint
    // an error banner over the bar without one). Transparent, so it adds the
    // Material contract without painting over the content/bar boundary.
    return Material(
      type: MaterialType.transparency,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: StreamBuilder<_MediaPos>(
          stream: _mediaPos,
          builder: (context, snap) {
            final pos = snap.data?.position ?? Duration.zero;
            final dur = snap.data?.item?.duration;
            final ms = dur?.inMilliseconds ?? 0;
            final ratio = ms == 0
                ? 0.0
                : (pos.inMilliseconds / ms).clamp(0.0, 1.0);
            final peaks = _peaks;
            return SliderTheme(
              data: SliderThemeData(
                trackHeight: _hover ? 4 : 3,
                // Amplitude bars when the server has peaks for this track;
                // the original slim boundary line otherwise.
                trackShape: peaks == null
                    ? const _EdgeToEdgeTrackShape()
                    : _WaveformTrackShape(peaks),
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: _hover
                    ? const RoundSliderThumbShape(enabledThumbRadius: 6)
                    : SliderComponentShape.noThumb,
                activeTrackColor: VelvetColors.primary,
                inactiveTrackColor: VelvetColors.border2,
                // Idle (nothing loaded): a quiet uniform line, no grey defaults.
                disabledActiveTrackColor: VelvetColors.border2,
                disabledInactiveTrackColor: VelvetColors.border2,
                disabledThumbColor: Colors.transparent,
                thumbColor: VelvetColors.primary,
              ),
              child: Slider(
                value: ratio,
                onChanged: dur == null
                    ? null
                    : (f) => MediaManager().audioHandler.seek(
                        Duration(milliseconds: (ms * f).round()),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// The now-playing info doubles as a button on the right of the bar: a pointer
// cursor and a hover wash signal that clicking it opens the queue.
class _NowPlayingTab extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _NowPlayingTab({required this.child, required this.onTap});
  @override
  State<_NowPlayingTab> createState() => _NowPlayingTabState();
}

class _NowPlayingTabState extends State<_NowPlayingTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          // Slim vertical margin: the card carries four info rows (title /
          // artist / album·year / badge row), so the height goes to content.
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover ? VelvetColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Shuffle · previous · play/pause · next · repeat — the same handler calls the
// phone player uses, laid out for a mouse.
class _DesktopTransport extends StatelessWidget {
  const _DesktopTransport();

  @override
  Widget build(BuildContext context) {
    final handler = MediaManager().audioHandler;
    final buttons = <Widget>[
      StreamBuilder<AudioServiceShuffleMode>(
        stream: handler.playbackState.map((s) => s.shuffleMode).distinct(),
        builder: (context, snap) {
          final on = snap.data == AudioServiceShuffleMode.all;
          return IconButton(
            icon: const Icon(Icons.shuffle, size: 18),
            tooltip: 'Shuffle (S)',
            color: on ? VelvetColors.primary : VelvetColors.textTertiary,
            onPressed: () => handler.setShuffleMode(
              on ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
            ),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.skip_previous),
        iconSize: 26,
        tooltip: 'Previous (Ctrl+←)',
        color: VelvetColors.textPrimary,
        onPressed: handler.skipToPrevious,
      ),
      StreamBuilder<bool>(
        stream: handler.playbackState.map((s) => s.playing).distinct(),
        builder: (context, snap) {
          final playing = snap.data ?? false;
          return Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: VelvetColors.primary,
              shape: BoxShape.circle,
              // Accent glow, matching the phone player's play button.
              boxShadow: [
                BoxShadow(
                  color: VelvetColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              iconSize: 22,
              padding: EdgeInsets.zero,
              tooltip: playing ? 'Pause (Space)' : 'Play (Space)',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              color: accentInk,
              onPressed: playing ? handler.pause : handler.play,
            ),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.skip_next),
        iconSize: 26,
        tooltip: 'Next (Ctrl+→)',
        color: VelvetColors.textPrimary,
        onPressed: handler.skipToNext,
      ),
      StreamBuilder<AudioServiceRepeatMode>(
        stream: handler.playbackState.map((s) => s.repeatMode).distinct(),
        builder: (context, snap) {
          final mode = snap.data ?? AudioServiceRepeatMode.none;
          final on = mode != AudioServiceRepeatMode.none;
          return IconButton(
            icon: Icon(
              mode == AudioServiceRepeatMode.one
                  ? Icons.repeat_one
                  : Icons.repeat,
              size: 18,
            ),
            tooltip: 'Repeat (R)',
            color: on ? VelvetColors.primary : VelvetColors.textTertiary,
            onPressed: () {
              final next = mode == AudioServiceRepeatMode.none
                  ? AudioServiceRepeatMode.all
                  : mode == AudioServiceRepeatMode.all
                  ? AudioServiceRepeatMode.one
                  : AudioServiceRepeatMode.none;
              handler.setRepeatMode(next);
            },
          );
        },
      ),
    ];
    // Shrink-wrap the icon buttons (default 48px tap targets would push the
    // transport + seek rows past the fixed bar height) and lay them out for a
    // mouse. The play button keeps its accent disc.
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }
}

class _MediaPos {
  final MediaItem? item;
  final Duration position;
  const _MediaPos(this.item, this.position);
}

// ───────────────────────────────────────────────────────────────────────────
// Full-screen Now Playing (polish #7, the V2 "backdrop" design): a dwell mode
// that covers the whole shell. Blurred album art (or the live shader
// visualizer) fills the window; the foreground keeps the same positions in
// both backdrop states so toggling never reflows.
// ───────────────────────────────────────────────────────────────────────────

/// The bar card's album art as the Now Playing door: hover dims the art and
/// reveals the expand glyph; the tap is the child GestureDetector's, so it
/// wins over the surrounding tab's queue toggle.
/// A corner glyph in the now-playing tab that is its own button: quiet at
/// rest, brighter while hovered (no persistent active state — see the tab's
/// queue glyph for the stateful one). GestureDetector so its tap wins over
/// the surrounding tab's InkWell.
class _TabGlyphButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TabGlyphButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TabGlyphButton> createState() => _TabGlyphButtonState();
}

class _TabGlyphButtonState extends State<_TabGlyphButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: Icon(
            widget.icon,
            size: 22,
            color:
                _hover ? VelvetColors.textPrimary : VelvetColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NowPlayingOverlay extends StatelessWidget {
  final bool visualizer;
  final bool locked;
  final VoidCallback onToggleVisualizer;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final VoidCallback onClose;
  const _NowPlayingOverlay({
    required this.visualizer,
    required this.locked,
    required this.onToggleVisualizer,
    required this.onLock,
    required this.onUnlock,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Esc closes — but NOT while locked (party mode removes the exit; the
        // lock chip's hold-to-unlock is the only way out).
        if (!locked &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: const Color(0xFF0A080E),
        child: StreamBuilder<MediaItem?>(
          stream: MediaManager().audioHandler.mediaItem,
          builder: (context, snap) {
            final item = snap.data;
            final url = item?.extras?['artUrl'] as String?;
            final subtitle = [
              item?.artist,
              item?.album,
            ].where((s) => s != null && s.isNotEmpty).join(' — ');
            return LayoutBuilder(builder: (context, box) {
              // Lyrics pane width: ~42% of the free span, bounded so it never
              // crowds the meta block at min window nor balloons on ultrawide.
              final lyricsW =
                  ((box.maxWidth - 128) * 0.42).clamp(320.0, 560.0);
              return Stack(
              fit: StackFit.expand,
              children: [
                // ── Backdrop: live visualizer OR blurred album art ──
                if (visualizer)
                  const IgnorePointer(
                    child: ShaderVisualizerScreen(backdrop: true),
                  )
                else if (url != null)
                  // Scale OUTSIDE the filter: the blur fades to transparent
                  // over ~sigma px at its layer edges, so over-scanning the
                  // blurred result pushes that fade outside the window.
                  Transform.scale(
                    scale: 1.2,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
                      child: Image.network(url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFF0A080E))),
                    ),
                  ),
                // Scrim: keeps the foreground legible — heavier when the
                // moving visualizer is behind it.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: visualizer ? .8 : .72),
                        Colors.black.withValues(alpha: visualizer ? .38 : .3),
                        Colors.black.withValues(alpha: visualizer ? .22 : .15),
                      ],
                      stops: const [0, .45, 1],
                    ),
                  ),
                ),
                // ── Foreground (same geometry in both backdrop states) ──
                // Art bottom must clear the meta block below it: the block is
                // pinned at bottom 118 and runs ~102px tall with all three
                // rows (title 40 + subtitle 28 + rating/badge 34), so 240
                // leaves a ~20px gap where 212 had the title lapping the art.
                Positioned(
                  left: 64,
                  bottom: 240,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: url == null
                          ? albumArtFallback(iconSize: 64)
                          : Image.network(url,
                              fit: BoxFit.cover,
                              cacheWidth: artCacheSize(280),
                              errorBuilder: (_, _, _) =>
                                  albumArtFallback(iconSize: 64)),
                    ),
                  ),
                ),
                Positioned(
                  left: 64,
                  right: 64.0 + lyricsW + 32,
                  bottom: 118,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null ? 'Nothing playing' : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .75),
                              fontSize: 17),
                        ),
                      ],
                      if (item != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Rate the playing track in place (server write +
                            // queue extras sync handled by the shared widget).
                            // Suppressed while locked — guests shouldn't be
                            // able to re-rate the host's library.
                            if (!locked) MediaItemRating(item: item, size: 16),
                            if (!locked &&
                                MediaItemRating.canRate(item) &&
                                _qualityBadge(item) != null)
                              const SizedBox(width: 12),
                            if (_qualityBadge(item) != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: .25)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _qualityBadge(item)!,
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: .6),
                                      fontSize: 11,
                                      letterSpacing: .6),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Lyrics (right pane) + Up Next, over the backdrop ──
                Positioned(
                  top: 72,
                  right: 64,
                  bottom: 260,
                  width: lyricsW,
                  child: _NowPlayingLyrics(item: item),
                ),
                Positioned(
                  right: 64,
                  bottom: 168,
                  width: 380,
                  child: const _UpNextStack(),
                ),
                // The same waveform seek strip the bar uses (shared peaks
                // cache, full interactivity).
                const Positioned(
                  left: 64,
                  right: 64,
                  bottom: 64,
                  height: _kSeekStripHeight,
                  child: _SeekBar(),
                ),
                const Positioned(
                  right: 64,
                  bottom: 110,
                  child: _DesktopTransport(),
                ),
                Positioned(
                  top: 16,
                  right: 20,
                  child: Row(
                    children: [
                      _CornerChip(
                        label: 'ıllı',
                        mono: true,
                        active: visualizer,
                        tooltip: 'Visualizer backdrop',
                        onTap: onToggleVisualizer,
                      ),
                      const SizedBox(width: 10),
                      if (locked)
                        // The ONLY way out of party mode: hold to unlock,
                        // gated behind the PIN when the user set one.
                        _HoldToUnlockChip(onUnlocked: onUnlock)
                      else ...[
                        _CornerChip(
                          label: 'lock',
                          icon: Icons.lock_outline,
                          tooltip: 'Party mode — fullscreen + locked controls',
                          onTap: onLock,
                        ),
                        const SizedBox(width: 10),
                        _CornerChip(label: 'esc ↩', onTap: onClose),
                      ],
                    ],
                  ),
                ),
              ],
            );
            });
          },
        ),
      ),
    );
  }

  /// "FLAC · 44.1 kHz" fidelity badge from the item's extras (Song Info's
  /// fields); bitrate stands in when the sample rate is unknown. Null when
  /// the item carries neither.
  static String? _qualityBadge(MediaItem item) {
    final fmt = (item.extras?['format'] as String?)?.toUpperCase();
    final sr = (item.extras?['sampleRate'] as num?)?.toInt();
    final br = (item.extras?['bitrate'] as num?)?.toInt();
    final parts = <String>[
      if (fmt != null && fmt.isNotEmpty) fmt,
      if (sr != null && sr > 0)
        '${(sr % 1000 == 0 ? (sr ~/ 1000).toString() : (sr / 1000).toStringAsFixed(1))} kHz'
      else if (br != null && br > 0)
        '${(br / 1000).round()} kbps',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _CornerChip extends StatelessWidget {
  final String label;
  final bool mono;
  final bool active;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback onTap;
  const _CornerChip({
    required this.label,
    required this.onTap,
    this.mono = false,
    this.active = false,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active
        ? const Color(0xFF1A1200)
        : Colors.white.withValues(alpha: .6);
    final chip = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: active ? VelvetColors.primary : Colors.black.withValues(alpha: .25),
            border: Border.all(
                color: active
                    ? VelvetColors.primary
                    : Colors.white.withValues(alpha: .22)),
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: VelvetColors.primary.withValues(alpha: .45),
                        blurRadius: 18)
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: mono ? FontWeight.w700 : FontWeight.w400,
                  fontFamily: mono ? 'monospace' : null,
                  letterSpacing: mono ? 1.6 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// The party-mode exit: press and HOLD to unlock (no accidental single tap).
/// A ring fills over the hold; releasing early cancels. On completion, if a
/// PIN is set, it must be entered before the unlock fires — the PIN gate is
/// the deliberate friction; the hold alone is the no-PIN default.
class _HoldToUnlockChip extends StatefulWidget {
  final VoidCallback onUnlocked;
  const _HoldToUnlockChip({required this.onUnlocked});

  @override
  State<_HoldToUnlockChip> createState() => _HoldToUnlockChipState();
}

class _HoldToUnlockChipState extends State<_HoldToUnlockChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _completeHold();
    });

  void _completeHold() async {
    _ctrl.reset();
    final pin = SettingsManager().partyPin;
    if (pin == null) {
      widget.onUnlocked();
      return;
    }
    final ok = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: .6),
          builder: (_) => _PinDialog(expected: pin),
        ) ??
        false;
    if (ok) widget.onUnlocked();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) => _ctrl.reset(),
        onTapCancel: () => _ctrl.reset(),
        child: Tooltip(
          message: 'Hold to unlock',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .3),
              border:
                  Border.all(color: Colors.white.withValues(alpha: .28)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_ctrl.value > 0)
                          CircularProgressIndicator(
                            value: _ctrl.value,
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(VelvetColors.primary),
                            backgroundColor:
                                Colors.white.withValues(alpha: .2),
                          ),
                        Icon(Icons.lock_outline,
                            size: 12,
                            color: Colors.white.withValues(alpha: .75)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text('hold to unlock',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 4-digit PIN confirm for unlocking party mode. Pops true on a match,
/// stays (shakes) on a mismatch; there's no cancel — the lock is the point.
class _PinDialog extends StatefulWidget {
  final String expected;
  const _PinDialog({required this.expected});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _check(String v) {
    if (v.length < 4) return;
    if (v == widget.expected) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
      _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VelvetColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter PIN to unlock',
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 24,
                    letterSpacing: 8),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _wrong ? 'Incorrect PIN' : null,
                ),
                onChanged: _check,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One parsed LRC line: when it starts, and its text.
class _LrcLine {
  final Duration time;
  final String text;
  const _LrcLine(this.time, this.text);
}

/// The Now Playing screen's lyrics pane. Fetches per track (keyed by
/// server|path with a stale guard + small cache, the waveform fetcher's
/// shape), gated on the item's `hasLyrics` flag so trackless/lyricless items
/// never even hit the network. Renders nothing when there are none.
///
/// Synced (LRC) lyrics highlight the active line and keep it centered via
/// ensureVisible; tapping a line seeks there. Plain lyrics just scroll.
class _NowPlayingLyrics extends StatefulWidget {
  final MediaItem? item;
  // Shown instead of nothing when the track has no lyrics (the dock's note);
  // the full-screen view leaves it null and shows nothing, as before.
  final Widget? placeholder;
  const _NowPlayingLyrics({required this.item, this.placeholder});

  @override
  State<_NowPlayingLyrics> createState() => _NowPlayingLyricsState();
}

class _NowPlayingLyricsState extends State<_NowPlayingLyrics> {
  static final Map<String, LyricsResult?> _cache = {};
  String? _key;
  LyricsResult? _result;
  List<_LrcLine>? _lines; // parsed synced lyrics, ascending
  List<GlobalKey>? _lineKeys;
  int _activeLine = -1;

  @override
  void initState() {
    super.initState();
    _load(widget.item);
  }

  @override
  void didUpdateWidget(_NowPlayingLyrics old) {
    super.didUpdateWidget(old);
    _load(widget.item);
  }

  Future<void> _load(MediaItem? item) async {
    final path = item?.extras?['path'] as String?;
    final serverName = item?.extras?['server'] as String?;
    final server = ServerManager().byLocalname(serverName);
    final hasLyrics = item?.extras?['hasLyrics'] == true;
    if (item == null || path == null || server == null || !hasLyrics) {
      _key = null;
      if (_result != null && mounted) setState(_clear);
      return;
    }
    final key = '$serverName|$path';
    if (key == _key) return;
    _key = key;
    if (_cache.containsKey(key)) {
      if (mounted) setState(() => _apply(_cache[key]));
      return;
    }
    if (mounted && _result != null) setState(_clear);
    LyricsResult? res;
    try {
      res = await ApiManager().fetchLyrics(server, path);
    } catch (e) {
      appLog('[lyrics] fetch failed: $e');
    }
    if (!mounted || _key != key) return; // track changed while fetching
    _cache[key] = res;
    if (_cache.length > 24) _cache.remove(_cache.keys.first);
    setState(() => _apply(res));
  }

  void _clear() {
    _result = null;
    _lines = null;
    _lineKeys = null;
    _activeLine = -1;
  }

  void _apply(LyricsResult? res) {
    _clear();
    _result = res;
    final lrc = res?.syncedLrc;
    if (lrc != null) {
      _lines = _parseLrc(lrc);
      if (_lines!.isEmpty) {
        _lines = null; // degenerate LRC — fall back to plain rendering
      } else {
        _lineKeys = List.generate(_lines!.length, (_) => GlobalKey());
      }
    }
  }

  /// `[mm:ss.xx]` (also mm:ss and h-long mm values, `.` or `:` fraction
  /// separators; multiple tags per line) → sorted line list.
  static List<_LrcLine> _parseLrc(String lrc) {
    final tag = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final out = <_LrcLine>[];
    for (final raw in lrc.split('\n')) {
      final tags = tag.allMatches(raw).toList();
      if (tags.isEmpty) continue;
      final text = raw.replaceAll(tag, '').trim();
      if (text.isEmpty) continue;
      for (final m in tags) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final fracRaw = m.group(3) ?? '0';
        final frac = int.parse(fracRaw.padRight(3, '0').substring(0, 3));
        out.add(_LrcLine(
            Duration(minutes: min, seconds: sec, milliseconds: frac), text));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    if (res == null) {
      // _key stays null when the track has no lyrics to fetch; while a fetch
      // is in flight it is set, so nothing flashes in the meantime.
      return _key == null && widget.placeholder != null
          ? widget.placeholder!
          : const SizedBox.shrink();
    }

    final Widget body;
    if (_lines != null) {
      body = StreamBuilder<Duration>(
        stream: MediaManager().audioHandler.positionStream,
        builder: (context, snap) {
          final pos = snap.data ?? Duration.zero;
          var active = -1;
          for (var i = 0; i < _lines!.length; i++) {
            if (_lines![i].time <= pos) {
              active = i;
            } else {
              break;
            }
          }
          if (active != _activeLine) {
            _activeLine = active;
            // Scroll AFTER this frame paints the new highlight.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = active >= 0 && active < _lineKeys!.length
                  ? _lineKeys![active].currentContext
                  : null;
              if (ctx != null) {
                Scrollable.ensureVisible(ctx,
                    alignment: 0.35,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic);
              }
            });
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _lines!.length; i++)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          MediaManager().audioHandler.seek(_lines![i].time),
                      child: Padding(
                        key: _lineKeys![i],
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          _lines![i].text,
                          style: i == active
                              ? const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700)
                              : TextStyle(
                                  color: Colors.white.withValues(alpha: .42),
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } else {
      final text = res.displayText;
      if (text == null) return const SizedBox.shrink();
      body = SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 120),
        child: Text(
          text,
          style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 15,
              height: 1.8),
        ),
      );
    }

    // Fade the pane's ends so lines melt into the backdrop instead of
    // clipping — the fade IS the pane's only chrome.
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent
        ],
        stops: [0, .09, .91, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: body,
    );
  }
}

/// The next couple of queue tracks, right-aligned above the transport —
/// Spotify's full-screen "Up next" corner, from our local queue. Click jumps.
class _UpNextStack extends StatelessWidget {
  const _UpNextStack();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaItem>>(
      stream: MediaManager().audioHandler.queue,
      builder: (context, qSnap) {
        final queue = qSnap.data ?? const <MediaItem>[];
        return StreamBuilder<MediaItem?>(
          stream: MediaManager().audioHandler.mediaItem,
          builder: (context, iSnap) {
            final current = iSnap.data;
            if (current == null || queue.isEmpty) {
              return const SizedBox.shrink();
            }
            final idx = queue.indexWhere((m) => m.id == current.id);
            if (idx < 0 || idx >= queue.length - 1) {
              return const SizedBox.shrink();
            }
            final next = queue.sublist(
                idx + 1, (idx + 3).clamp(0, queue.length));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('UP NEXT',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .5),
                        fontSize: 11,
                        letterSpacing: 1.6)),
                const SizedBox(height: 6),
                for (var n = 0; n < next.length; n++)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => MediaManager()
                          .audioHandler
                          .skipToQueueItem(idx + 1 + n),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          [next[n].title, next[n].artist]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' — '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .8),
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
