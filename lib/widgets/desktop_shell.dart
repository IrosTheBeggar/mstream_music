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
import '../native/projectm_controller.dart';
import '../native/projectm_desktop.dart';
import '../theme/velvet_theme.dart';
import '../util/image_cache.dart';
import '../util/media_format.dart';
import '../visualizer/projectm_screen.dart';
import '../visualizer/shader_visualizer_screen.dart';
import 'browser_toolbar.dart';
import 'cast_picker_sheet.dart';
import 'media_shortcuts.dart';
import 'playlist_name_dialog.dart';
import 'queue_list.dart';

// Width of the fixed left navigation rail. The right queue panel's width is
// computed at build time to match the now-playing view (see _DesktopShellState).
const double _kSidebarWidth = 248;
const double _kNowPlayingHeight = 88;

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
    _Category('files', Icons.folder_outlined, 'File Explorer',
        () => ApiManager().getFileList('~', useThisServer: _server)),
    _Category('playlists', Icons.queue_music, 'Playlists',
        () => ApiManager().getPlaylists(useThisServer: _server)),
    _Category('albums', Icons.album_outlined, 'Albums',
        () => ApiManager().getAlbums(useThisServer: _server)),
    _Category('artists', Icons.person_outline, 'Artists',
        () => ApiManager().getArtists(useThisServer: _server)),
    _Category('recent', Icons.fiber_new_outlined, 'Recently Added',
        () => ApiManager().getRecentlyAdded(useThisServer: _server)),
    _Category('rated', Icons.star_outline, 'Rated',
        () => ApiManager().getRated(useThisServer: _server)),
  ];

  // TOOLS section: screens pushed into the content pane.
  late final List<_NavItem> _tools = [
    _NavItem('autodj', Icons.album_outlined, (l) => l.autoDjTitle,
        (_) => AutoDJScreen()),
    _NavItem('transcode', Icons.transform, (l) => l.transcodeTitle,
        (_) => TranscodeScreen()),
  ];

  // Bottom gear overflow: settings / admin, kept out of the primary nav per
  // desktop convention.
  late final List<_NavItem> _gearItems = [
    _NavItem('manageServers', Icons.dns_outlined, (l) => l.manageServersTitle,
        (_) => ManageServersScreen()),
    _NavItem('settings', Icons.settings_outlined, (l) => l.settingsTitle,
        (_) => SettingsScreen()),
    _NavItem('diagnostics', Icons.bug_report_outlined,
        (l) => l.diagnosticsTitle, (_) => DiagnosticsScreen()),
    _NavItem('about', Icons.info_outline, (l) => l.aboutTitle,
        (_) => AboutScreen()),
  ];

  // Reset to the browse root so destinations never stack on each other.
  void _showBrowse() => _contentNav.currentState?.popUntil((r) => r.isFirst);

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
    _contentNav.currentState
        ?.push(MaterialPageRoute(builder: (_) => tool.build(context)));
    setState(() => _active = tool.key);
  }

  void _openVisualizer() {
    _showBrowse();
    _contentNav.currentState?.push(
        MaterialPageRoute(builder: (_) => const ShaderVisualizerScreen()));
    setState(() => _active = 'visualizer');
  }

  void _openProjectM() {
    _showBrowse();
    _contentNav.currentState
        ?.push(MaterialPageRoute(builder: (_) => const ProjectMScreen()));
    setState(() => _active = 'milkdrop');
  }

  @override
  Widget build(BuildContext context) {
    // Match the queue panel's width to the now-playing view — the bar's right
    // third (Expanded flex 1 of the flex-2 center + flex-1 now-playing split).
    // When the queue opens it then covers exactly that region and the transport
    // doesn't shift. -1 accounts for the divider between the content and queue.
    final queueWidth =
        (MediaQuery.sizeOf(context).width - _kSidebarWidth - 1) / 3 - 1;
    final shell = Scaffold(
      backgroundColor: VelvetColors.bg,
      body: Row(
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
          VerticalDivider(width: 1, thickness: 1, color: VelvetColors.border),
          // Browse content with the Now Playing bar pinned along its bottom —
          // spanning only the width between the sidebar and the queue.
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Navigator(
                    key: _contentNav,
                    onGenerateRoute: (_) => MaterialPageRoute(
                        builder: (_) => const _DesktopBrowseView()),
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
          // Queue runs the full window height down the right edge, carrying the
          // expanded now-playing info at its own bottom.
          if (_queueOpen) ...[
            VerticalDivider(width: 1, thickness: 1, color: VelvetColors.border),
            SizedBox(
              width: queueWidth,
              child: _DesktopQueuePanel(
                  onClose: () => setState(() => _queueOpen = false)),
            ),
          ],
        ],
      ),
    );
    // Wrap the whole shell so the media keys work regardless of which pane has
    // focus (text fields still consume their own keys first).
    return MediaShortcuts(child: shell);
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
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: VelvetColors.textTertiary)),
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
      color: VelvetColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarLogo(),
          const _SidebarServer(),
          Divider(height: 1, color: VelvetColors.border),
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
                    child: Row(children: [
                      Icon(g.icon, size: 18, color: VelvetColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(g.label(l)),
                    ]),
                  ),
              ],
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                child: Row(children: [
                  Icon(Icons.settings_outlined,
                      size: 20, color: VelvetColors.textSecondary),
                  const SizedBox(width: 14),
                  Text('Settings',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: VelvetColors.textSecondary)),
                ]),
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, color: VelvetColors.primary, size: 26),
          const SizedBox(width: 10),
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
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => AddServerScreen()));
      return;
    }
    // Capture the localized error before any await — the context may be gone by
    // the time the connect fails, and we surface it through the app-wide
    // messenger (like the phone picker) rather than this element's context.
    final failedMsg = AppLocalizations.of(context).mainFailedToConnect;
    ServerManager().changeCurrentServer(index);
    try {
      await ServerManager()
          .getServerPaths(ServerManager().currentServer!, throwErr: true);
      await ServerManager().callAfterEditServer();
    } catch (_) {
      showGlobalSnack(failedMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: Text(s.url,
                    style: TextStyle(
                        color: s == ServerManager().currentServer
                            ? VelvetColors.primary
                            : VelvetColors.textPrimary)),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: -1,
              child: Row(children: [
                Icon(Icons.add, size: 18, color: VelvetColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Add server'),
              ]),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Icon(Icons.dns_outlined,
                    size: 18, color: VelvetColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    server?.url ?? 'No server',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: VelvetColors.textSecondary),
                  ),
                ),
                Icon(Icons.unfold_more,
                    size: 18, color: VelvetColors.textTertiary),
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
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? VelvetColors.textPrimary
                              : VelvetColors.textSecondary)),
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
          // add-all). It's a PreferredSizeWidget; give it its intrinsic height
          // since it's not in an AppBar's bottom slot here.
          const SizedBox(height: 50, child: BrowserToolbar()),
          Divider(height: 1, color: VelvetColors.border),
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
  final VoidCallback onClose;
  const _DesktopQueuePanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: VelvetColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Text('Queue',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: VelvetColors.textPrimary)),
                const Spacer(),
                // Queue actions (act on the queue, so they live here): save the
                // queue as a playlist, download it, or share it.
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
                    _queueMenuItem('save', Icons.playlist_add, 'Save as playlist'),
                    _queueMenuItem(
                        'download', Icons.download_for_offline, l.queueDownloadAll),
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
          Divider(height: 1, color: VelvetColors.border),
          const Expanded(child: QueueList(showItemMenu: true)),
          Divider(height: 1, color: VelvetColors.border),
          // The expanded now-playing lives at the foot of the queue — this is
          // what the bar's compact now-playing "grows into" when opened.
          const _ExpandedNowPlaying(),
        ],
      ),
    );
  }
}

PopupMenuItem<String> _queueMenuItem(
    String value, IconData icon, String label) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(children: [
      Icon(icon, size: 18, color: VelvetColors.textSecondary),
      const SizedBox(width: 12),
      Text(label),
    ]),
  );
}

/// Save the current queue as a server playlist: collect the queue's server-track
/// paths, prompt for a name, then POST /playlist/save. Local-only / no-server
/// items (which can't live in a server playlist) are skipped.
Future<void> _saveQueueAsPlaylist(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final paths = MediaManager()
      .audioHandler
      .queue
      .value
      .map((m) => m.extras?['path'])
      .whereType<String>()
      .toList();
  if (paths.isEmpty) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Nothing in the queue to save')));
    return;
  }
  final name = await PlaylistNameDialog.show(context,
      title: 'Save as playlist', action: 'Save');
  if (name == null || name.isEmpty) return;
  try {
    await ApiManager().savePlaylist(name, paths);
    messenger.showSnackBar(SnackBar(content: Text('Saved “$name”')));
  } catch (_) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Couldn’t save the playlist')));
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
      decoration: BoxDecoration(
        color: VelvetColors.surface,
        border: Border(top: BorderSide(color: VelvetColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Transport (left-aligned) and the right-aligned control cluster
          // (volume · cast · queue) sit above the progress bar, starting flush
          // at the bar's left edge.
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _SeekBar(),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const _DesktopTransport(),
                    const Spacer(),
                    _controls(),
                  ],
                ),
              ],
            ),
          ),
          // Right: now-playing info — click to open the queue. Fixed width (=
          // the queue's reserved region) so the transport doesn't shift when the
          // queue opens and this is dropped.
          if (!widget.queueOpen)
            SizedBox(
              width: widget.nowPlayingWidth,
              child: _NowPlayingTab(
                  onTap: widget.onToggleQueue, child: _trackInfo()),
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
        final subtitle = [item?.artist, item?.album]
            .where((s) => s != null && s.isNotEmpty)
            .join(' — ');
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(item == null ? 'Nothing playing' : item.title,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: item == null
                              ? VelvetColors.textTertiary
                              : VelvetColors.textPrimary)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: VelvetColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: url == null
                    ? albumArtFallback(iconSize: 22)
                    : Image.network(url,
                        fit: BoxFit.cover,
                        cacheWidth: artCacheSize(56),
                        errorBuilder: (_, _, _) =>
                            albumArtFallback(iconSize: 22)),
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
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 10),
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
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
              color:
                  casting ? VelvetColors.primary : VelvetColors.textSecondary,
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: VelvetColors.surface,
                isScrollControlled: true,
                builder: (_) => const CastPickerSheet(),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.queue_music),
          iconSize: 22,
          tooltip: 'Queue',
          color: widget.queueOpen
              ? VelvetColors.primary
              : VelvetColors.textSecondary,
          onPressed: widget.onToggleQueue,
        ),
      ],
    );
  }
}

// Elapsed · slider · duration, driven by its own combined item+position stream
// so a per-second position tick repaints only the slider.
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_MediaPos>(
      stream: _mediaPos,
      builder: (context, snap) {
        final pos = snap.data?.position ?? Duration.zero;
        final dur = snap.data?.item?.duration;
        final ms = dur?.inMilliseconds ?? 0;
        final ratio =
            ms == 0 ? 0.0 : (pos.inMilliseconds / ms).clamp(0.0, 1.0);
        return Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(formatDuration(pos),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      // Elapsed in the accent colour, like the phone player.
                      color: VelvetColors.primary)),
            ),
            Expanded(
              // Bound the slider's height so it can't push the transport+seek
              // column past the fixed bar height (Sliders otherwise reserve the
              // full interactive dimension).
              child: SizedBox(
                height: 28,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: VelvetColors.primary,
                    inactiveTrackColor: VelvetColors.border2,
                    thumbColor: VelvetColors.primary,
                  ),
                  child: Slider(
                    value: ratio,
                    onChanged: dur == null
                        ? null
                        : (f) => MediaManager()
                            .audioHandler
                            .seek(Duration(milliseconds: (ms * f).round())),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(dur == null ? '--:--' : formatDuration(dur),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: VelvetColors.textTertiary)),
            ),
          ],
        );
      },
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

// Larger now-playing block at the foot of the queue panel: art + title/artist
// over the same seek bar as the main Now Playing bar.
class _ExpandedNowPlaying extends StatelessWidget {
  const _ExpandedNowPlaying();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VelvetColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final item = snap.data;
              final url = item?.extras?['artUrl'] as String?;
              final subtitle = [item?.artist, item?.album]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' — ');
              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: url == null
                          ? albumArtFallback(iconSize: 28)
                          : Image.network(url,
                              fit: BoxFit.cover,
                              cacheWidth: artCacheSize(72),
                              errorBuilder: (_, _, _) =>
                                  albumArtFallback(iconSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item == null ? 'Nothing playing' : item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: item == null
                                    ? VelvetColors.textTertiary
                                    : VelvetColors.textPrimary)),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: VelvetColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
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
            onPressed: () => handler.setShuffleMode(on
                ? AudioServiceShuffleMode.none
                : AudioServiceShuffleMode.all),
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
                    offset: const Offset(0, 4)),
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
                size: 18),
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
