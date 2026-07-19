// desktop_shell.dart — the wide/desktop layout, in the shape of a traditional
// desktop music player: a persistent left sidebar (server picker · library ·
// tools), the browse / album-detail area in a nested Navigator so tool screens
// (Settings, Diagnostics, …) open inside the content pane while the sidebar and
// player stay put, an optional right-hand queue panel, and a full-width Now
// Playing bar pinned to the bottom (art · transport · seek · volume · queue).
//
// Chosen over the phone shell by a width breakpoint in MStreamApp.build (desktop
// platforms only). This is a VIEW only: it reads the same singletons / streams
// as the mobile UI and drives the same AudioPlayerHandler — no playback or
// business logic lives here.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../media/cast_target.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../screens/about_screen.dart';
import '../screens/add_server.dart';
import '../screens/album_detail_view.dart';
import '../screens/auto_dj.dart';
import '../screens/browser.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/manage_server.dart';
import '../screens/settings_screen.dart';
import '../screens/share_playlist_dialog.dart';
import '../screens/transcode_screen.dart';
import '../singletons/api.dart';
import '../singletons/app_messenger.dart';
import '../singletons/browser_list.dart';
import '../singletons/cast_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../native/projectm_controller.dart';
import '../native/projectm_desktop.dart';
import '../theme/velvet_theme.dart';
import 'desktop_toast.dart';
import '../util/image_cache.dart';
import '../util/media_format.dart';
import '../util/startup_view.dart';
import '../visualizer/projectm_screen.dart';
import '../visualizer/shader_visualizer_screen.dart';
import 'browser_toolbar.dart';
import 'cast_picker_sheet.dart';
import 'media_shortcuts.dart';
import 'playlist_name_dialog.dart';
import 'queue_list.dart';

// Width of the fixed left navigation rail. The right queue panel's width is
// computed at build time to match the now-playing view (see _DesktopShellState).
const double _kSidebarWidth = 208;
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

class _DesktopShellState extends State<DesktopShell> {
  // The content pane is its own Navigator so tool screens push WITHIN it —
  // keeping the sidebar and the Now Playing bar visible — instead of covering
  // the whole window the way a root-level push would.
  final GlobalKey<NavigatorState> _contentNav = GlobalKey<NavigatorState>();

  // Highlighted sidebar destination, by key. '' = the browse landing; a
  // category key ('albums', …), a tool key, 'search', or a visualizer key.
  String _active = '';
  bool _queueOpen = false;

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

  // Bottom gear overflow: settings / admin, kept out of the primary nav per
  // desktop convention.
  late final List<_NavItem> _gearItems = [
    _NavItem(
      'manageServers',
      Icons.dns_outlined,
      (l) => l.manageServersTitle,
      (_) => ManageServersScreen(),
    ),
    _NavItem(
      'settings',
      Icons.settings_outlined,
      (l) => l.settingsTitle,
      (_) => SettingsScreen(),
    ),
    _NavItem(
      'diagnostics',
      Icons.bug_report_outlined,
      (l) => l.diagnosticsTitle,
      (_) => DiagnosticsScreen(),
    ),
    _NavItem(
      'about',
      Icons.info_outline,
      (l) => l.aboutTitle,
      (_) => AboutScreen(),
    ),
  ];

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
    _serverSub = ServerManager().currentServerStream.distinct().listen((_) {
      if (mounted) setState(() => _active = _startupKey);
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
    _showBrowse();
    cat.load();
    setState(() => _active = cat.key);
  }

  void _openSearch() {
    _showBrowse();
    BrowserManager().openSearch();
    setState(() => _active = 'search');
  }

  void _openTool(_NavItem tool) {
    _showBrowse();
    _contentNav.currentState?.push(
      MaterialPageRoute(builder: (_) => tool.build(context)),
    );
    setState(() => _active = tool.key);
  }

  void _openVisualizer() {
    _showBrowse();
    _contentNav.currentState?.push(
      MaterialPageRoute(builder: (_) => const ShaderVisualizerScreen()),
    );
    setState(() => _active = 'visualizer');
  }

  void _openProjectM() {
    _showBrowse();
    _contentNav.currentState?.push(
      MaterialPageRoute(builder: (_) => const ProjectMScreen()),
    );
    setState(() => _active = 'milkdrop');
  }

  @override
  Widget build(BuildContext context) {
    // Match the queue panel's width to the now-playing view — the bar's right
    // third (Expanded flex 1 of the flex-2 center + flex-1 now-playing split).
    // When the queue opens it then covers exactly that region and the transport
    // doesn't shift. -1 accounts for the divider between the content and queue.
    // (No divider between the sidebar and content — the chrome/content tone
    // change is the boundary now.)
    final queueWidth =
        (MediaQuery.sizeOf(context).width - _kSidebarWidth) / 3 - 1;
    // Material, not Scaffold, on purpose: a Scaffold here would register with
    // the root ScaffoldMessenger and render every SnackBar full-width across
    // the window bottom — over the Now Playing bar. Desktop notifications go
    // through the corner-toast layer below instead (see DesktopToasts); pushed
    // screens with their own Scaffolds still show their local SnackBars within
    // the content pane, which ends above the bar.
    final shell = Material(
      color: VelvetColors.bg,
      child: Row(
        children: [
          // Sidebar runs the full window height down the left edge (like the
          // queue on the right); the Now Playing bar begins where it ends, so
          // the nav gets the bar's height back as extra vertical space.
          _DesktopSidebar(
            categories: _categories,
            tools: _tools,
            gearItems: _gearItems,
            active: _active,
            onCategory: _openCategory,
            onSearch: _openSearch,
            onTool: _openTool,
            onVisualizer: _openVisualizer,
            onProjectM: _projectMAvailable ? _openProjectM : null,
          ),
          // Everything right of the sidebar: content (+ the queue column when
          // open) stacked ABOVE a full-width Now Playing bar — so the bar and
          // its top-edge scrub line always run to the screen's right edge,
          // queue open or closed, and every control sits along the bottom.
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Navigator(
                          key: _contentNav,
                          onGenerateRoute: (_) => MaterialPageRoute(
                            builder: (_) => const _DesktopBrowseView(),
                          ),
                        ),
                      ),
                      // Queue column: now-playing card on top, then the list;
                      // its actions dock in the bar below.
                      if (_queueOpen) ...[
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: VelvetColors.border,
                        ),
                        SizedBox(
                          width: queueWidth,
                          child: _DesktopQueuePanel(
                            onClose: () =>
                                setState(() => _queueOpen = false),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DesktopNowPlayingBar(
                  queueOpen: _queueOpen,
                  onToggleQueue: () => setState(() => _queueOpen = !_queueOpen),
                  nowPlayingWidth: queueWidth + 1,
                ),
              ],
            ),
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
      child: Stack(
        children: [
          shell,
          // The scrub strip is the TOP BAND of the Now Playing bar itself —
          // the bar reserves _kSeekStripHeight for it (see
          // DesktopNowPlayingBar), and the strip floats over that band,
          // spanning sidebar → the bar's now-playing tab (which owns the
          // bar's full-height right corner) in both queue states. The
          // waveform bars rise and reflect around the band's center line;
          // with no waveform available the band draws the slim line there.
          Positioned(
            left: _kSidebarWidth,
            right: queueWidth + 1,
            bottom: _kControlsHeight,
            height: _kSeekStripHeight,
            child: const _SeekBar(),
          ),
          Positioned(
            // Hug the content pane's bottom-right: when the queue panel is
            // open, shift left past it (+ its divider) so toasts float over
            // the main page, not the queue.
            right: (_queueOpen ? queueWidth + 1 : 0) + 16,
            bottom: _kNowPlayingHeight + 16,
            child: const DesktopToastHost(),
          ),
        ],
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
  final List<_NavItem> gearItems;
  final String active;
  final void Function(_Category) onCategory;
  final VoidCallback onSearch;
  final void Function(_NavItem) onTool;
  final VoidCallback onVisualizer;
  final VoidCallback? onProjectM; // null when projectM isn't available
  const _DesktopSidebar({
    required this.categories,
    required this.tools,
    required this.gearItems,
    required this.active,
    required this.onCategory,
    required this.onSearch,
    required this.onTool,
    required this.onVisualizer,
    required this.onProjectM,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: _kSidebarWidth,
      // Chrome tone: the sidebar, the Now Playing bar, and the three aligned
      // top bars share the darker appBarBg so they read as one frame around
      // the lighter content zone (Spotify-style tonal zoning). The light
      // right-edge hairline (with its twin on the bar's top edge) is one of
      // the two structural lines dividing nav | content | player — drawn
      // inside the sidebar's width, so nothing shifts.
      decoration: BoxDecoration(
        color: VelvetColors.appBarBg,
        border: Border(
          right: BorderSide(color: VelvetColors.border2, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header pinned to the shared top-bar height so it stays one band
          // with the browse toolbar and the queue header (no divider — the
          // chrome/content tone shift marks the band's edge in those panes).
          const SizedBox(
            height: VelvetColors.desktopTopBarHeight,
            child: _SidebarLogo(),
          ),
          // Server switcher (hidden with a single server) sits under the
          // aligned header line rather than stretching the header.
          const _SidebarServer(),
          Expanded(
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
                _SidebarTile(
                  icon: Icons.graphic_eq,
                  label: 'Visualizer',
                  selected: active == 'visualizer',
                  onTap: onVisualizer,
                ),
                if (onProjectM != null)
                  _SidebarTile(
                    icon: Icons.auto_awesome,
                    label: 'Milkdrop',
                    selected: active == 'milkdrop',
                    onTap: onProjectM!,
                  ),
              ],
            ),
          ),
          // Bottom: a Settings/admin overflow, kept out of the primary nav
          // (desktop-style). Presented as a full-width tile that opens the menu.
          Divider(height: 1, color: VelvetColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: PopupMenuButton<_NavItem>(
              tooltip: '',
              color: VelvetColors.surface,
              onSelected: onTool,
              itemBuilder: (_) => [
                for (final g in gearItems)
                  PopupMenuItem<_NavItem>(
                    value: g,
                    child: Row(
                      children: [
                        Icon(
                          g.icon,
                          size: 18,
                          color: VelvetColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(g.label(l)),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: VelvetColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: VelvetColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, color: VelvetColors.primary, size: 26),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'm',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    color: VelvetColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: 'Stream',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: VelvetColors.textPrimary,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 20, letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }
}

// Current-server readout + a popup to switch servers or add a new one. Mirrors
// the phone app bar's server picker (same ServerManager calls).
class _SidebarServer extends StatelessWidget {
  const _SidebarServer();

  Future<void> _switchTo(BuildContext context, int index) async {
    if (index == -1) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AddServerScreen()));
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
    return StreamBuilder<List<Server>>(
      stream: ServerManager().serverListStream,
      initialData: ServerManager().serverList,
      builder: (context, listSnap) {
        // With a single server (the common desktop case: just the built-in
        // one) a switcher is noise — hide the whole row. Adding servers stays
        // reachable via Manage Servers, and the dropdown reappears as soon as
        // a second server exists.
        if ((listSnap.data ?? const <Server>[]).length <= 1) {
          return const SizedBox.shrink();
        }
        return _dropdown(context);
      },
    );
  }

  Widget _dropdown(BuildContext context) {
    return StreamBuilder<Server?>(
      stream: ServerManager().currentServerStream,
      initialData: ServerManager().currentServer,
      builder: (context, snap) {
        final server = snap.data;
        return PopupMenuButton<int>(
          tooltip: '',
          onSelected: (i) => _switchTo(context, i),
          color: VelvetColors.raised,
          itemBuilder: (context) => [
            for (final s in ServerManager().serverList)
              PopupMenuItem(
                value: ServerManager().serverList.indexOf(s),
                child: Text(
                  s.url,
                  style: TextStyle(
                    color: s == ServerManager().currentServer
                        ? VelvetColors.primary
                        : VelvetColors.textPrimary,
                  ),
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: -1,
              child: Row(
                children: [
                  Icon(Icons.add, size: 18, color: VelvetColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text('Add server'),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 18,
                  color: VelvetColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    server?.url ?? 'No server',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: VelvetColors.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.unfold_more,
                  size: 18,
                  color: VelvetColors.textTertiary,
                ),
              ],
            ),
          ),
        );
      },
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
          ColoredBox(
            color: VelvetColors.appBarBg,
            child: const SizedBox(
              height: VelvetColors.desktopTopBarHeight,
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: BrowserToolbar(),
              ),
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

class _DesktopQueuePanel extends StatelessWidget {
  const _DesktopQueuePanel({required this.onClose});

  /// Collapses the panel — the header's ✕ (the bar's now-playing tab stays
  /// put in both queue states, so the close affordance lives up here).
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: VelvetColors.surface,
      child: Column(
        children: [
          // "Queue" header carrying the queue's actions — no now-playing card
          // up here (the bar's full-height tab shows the playing track), so
          // the column reads header → list. 56 matches the content panes'
          // top bars, and the chrome tone keeps the three top bars one band.
          ColoredBox(
            color: VelvetColors.appBarBg,
            child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  Text(
                    'Queue',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: VelvetColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Clear is the most-reached-for queue action, so it gets
                  // its own button (same no-confirm behavior as the phone
                  // queue header).
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, size: 20),
                    color: VelvetColors.textSecondary,
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
                      _queueMenuItem('share', Icons.share_outlined, l.shareTitle),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: VelvetColors.textSecondary,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
          ),
          const Expanded(child: QueueList(showItemMenu: true)),
        ],
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
  try {
    await ApiManager().savePlaylist(name, paths);
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
  // Fixed width for the now-playing view = the queue's reserved right region
  // (queueWidth + 1 divider). Fixed (not Expanded/flex) so the transport keeps
  // the EXACT same width whether the queue is open or closed — a flex split
  // rounds differently than the queue's fixed SizedBox and shifts by ~1px.
  final double nowPlayingWidth;
  const DesktopNowPlayingBar({
    super.key,
    required this.queueOpen,
    required this.onToggleQueue,
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
      // The light top hairline is the second of the two structural lines
      // (the sidebar's right edge is the other), dividing player from
      // content; it draws inside the bar's height, above the top pad.
      decoration: BoxDecoration(
        color: VelvetColors.appBarBg,
        border: Border(
          top: BorderSide(color: VelvetColors.border2, width: 1),
        ),
      ),
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
                    // Left inset clears the folded queue glyph below.
                    padding: const EdgeInsets.only(left: 34, right: 16),
                    child: _trackInfo(),
                  ),
                  // The queue affordance, folded into the tab — the tab and
                  // the old queue button did the same thing, so the glyph now
                  // just marks the tab's corner. Its center sits on the
                  // controls row's axis so it reads in line with the
                  // volume/cast icons to its left; the -12 cancels the tab
                  // pill's vertical margin (this Stack lives inside it).
                  Positioned(
                    // left 0 within the pill's 10px pad: with the controls
                    // row's right padding removed, cast's ~13px internal pad
                    // + the pill pad ≈ the button row's glyph-to-glyph gap.
                    left: 0,
                    bottom: (_kControlsHeight - 22) / 2 - 12,
                    child: Icon(
                      Icons.queue_music,
                      size: 22,
                      color: widget.queueOpen
                          ? VelvetColors.primary
                          : VelvetColors.textSecondary,
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
        final url = item?.extras?['artUrl'] as String?;
        final artist = item?.artist ?? '';
        final album = item?.album ?? '';
        // Three text lines (title / artist / album) beside near-full-height
        // art — the tab owns the bar's whole 120px, so it can carry a real
        // now-playing card's worth of metadata instead of a strip's.
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item == null ? 'Nothing playing' : item.title,
                    maxLines: 1,
                    textAlign: TextAlign.right,
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
                    const SizedBox(height: 3),
                    Text(
                      artist,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: VelvetColors.textSecondary,
                      ),
                    ),
                  ],
                  if (album.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      album,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: VelvetColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
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
          ],
        );
      },
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
          margin: const EdgeInsets.symmetric(vertical: 12),
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
