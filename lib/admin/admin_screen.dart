import 'package:flutter/material.dart';

import 'admin_api.dart';
import 'admin_session.dart';
import 'admin_widgets.dart';
import '../l10n/app_localizations.dart';
import 'views/about_view.dart';
import 'views/admin_access_view.dart';
import 'views/backups_view.dart';
import 'views/database_view.dart';
import 'views/directories_view.dart';
import 'views/dlna_view.dart';
import 'views/federation_view.dart';
import 'views/logs_view.dart';
import 'views/settings_view.dart';
import 'views/torrent_view.dart';
import 'views/transcoding_view.dart';
import 'views/users_view.dart';

/// A navigable destination in the admin sidebar.
class _NavItem {
  final IconData icon;
  final String Function(AppLocalizations) label;
  final Widget Function(AdminApi) build;
  const _NavItem(this.icon, this.label, this.build);
}

class _NavGroup {
  final String Function(AppLocalizations) title;
  final List<_NavItem> items;
  const _NavGroup(this.title, this.items);
}

/// The admin shell: a responsive grouped sidebar (permanent on wide windows, a
/// Drawer on narrow ones) plus the selected view. Owns the [AdminApi] for the
/// session. Views are built lazily on first visit and kept mounted after, and
/// only the visible one is marked active, so at most one view polls at a time.
class AdminScreen extends StatefulWidget {
  final AdminSession session;

  /// Called when the user picks "Log out" / "Exit". On web this clears the
  /// session and returns to the login screen; embedded it pops the route. Null
  /// hides the action entirely.
  final VoidCallback? onExit;

  /// Override for the exit action's label. Null → localized "Log out".
  final String? exitLabel;

  /// True when the panel is a route pushed inside the mobile app, as opposed to
  /// the standalone web build. Embedded, leaving is a normal navigation the user
  /// does often, so it gets an app-bar button; on web the only "exit" is logging
  /// out, which belongs in the drawer where it cannot be hit by accident.
  final bool embedded;

  const AdminScreen({
    super.key,
    required this.session,
    this.onExit,
    this.exitLabel,
    this.embedded = false,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminApi _api = AdminApi(widget.session);
  int _selected = 0;

  /// Indices that have been opened at least once, and so are built and kept
  /// mounted in the IndexedStack. Everything else is an empty placeholder.
  final Set<int> _visited = {0};

  late final List<_NavGroup> _groups = [
    _NavGroup((l) => l.adminConfigGroup, [
      _NavItem(Icons.folder_outlined, (l) => l.adminDirectories, (a) => DirectoriesView(api: a)),
      _NavItem(Icons.people_outline, (l) => l.adminUsers, (a) => UsersView(api: a)),
      _NavItem(Icons.wifi_tethering, (l) => l.adminDLNA, (a) => DlnaView(api: a)),
      _NavItem(Icons.download_outlined, (l) => l.adminTorrent, (a) => TorrentView(api: a)),
      _NavItem(Icons.hub_outlined, (l) => l.adminFederation, (a) => FederationView(api: a)),
    ]),
    _NavGroup((l) => l.adminServerGroup, [
      _NavItem(Icons.info_outline, (l) => l.adminAbout, (a) => AboutView(api: a)),
      _NavItem(Icons.settings_outlined, (l) => l.adminSettings, (a) => SettingsView(api: a)),
      _NavItem(Icons.storage_outlined, (l) => l.adminDatabase, (a) => DatabaseView(api: a)),
      _NavItem(Icons.backup_outlined, (l) => l.adminBackups, (a) => BackupsView(api: a)),
      _NavItem(Icons.transform, (l) => l.adminTranscoding, (a) => TranscodingView(api: a)),
      _NavItem(Icons.article_outlined, (l) => l.adminLogs, (a) => LogsView(api: a)),
      _NavItem(Icons.security_outlined, (l) => l.adminAccess, (a) => AdminAccessView(api: a)),
    ]),
  ];

  List<_NavItem> get _flat => [for (final g in _groups) ...g.items];

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _visited.add(index);
    });
    Navigator.of(context).maybePop(); // close the Drawer if open
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final flat = _flat;
    final active = flat[_selected];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final content = Scaffold(
        appBar: AppBar(
          // Narrow: just the section. "mStream Admin · Transcoding" does not fit
          // a phone and truncates the half that says which view you are on, and
          // the drawer header already carries the brand and the server.
          title: Text(wide ? l.adminAppBarTitle(active.label(l)) : active.label(l)),
          actions: [
            // The hamburger owns the leading slot, so the way back to the app
            // sits on the right rather than being buried at the foot of the
            // drawer.
            if (widget.embedded && widget.onExit != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: widget.exitLabel ?? l.adminClose,
                onPressed: widget.onExit,
              ),
          ],
        ),
        drawer: wide ? null : Drawer(child: _sidebar(scrollable: true)),
        body: Row(children: [
          if (wide)
            SizedBox(
              width: 260,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: _sidebar(scrollable: true),
              ),
            ),
          Expanded(
            // Build a view the first time it is opened, then keep it mounted so
            // returning to it is instant and its state survives. Unvisited slots
            // stay empty placeholders: opening the panel must not fire fourteen
            // loaders at once, which on a phone means fourteen parallel requests
            // over whatever connection the user happens to be on.
            //
            // Only the active view's AdminViewActive is true, so polling views
            // (logs, torrent, backups) stay paused while mounted but offscreen —
            // preserving "one poller at a time".
            child: IndexedStack(
              index: _selected,
              children: [
                for (int i = 0; i < flat.length; i++)
                  if (_visited.contains(i))
                    AdminViewActive(
                      active: i == _selected,
                      child: flat[i].build(_api),
                    )
                  else
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ]),
      );
      return content;
    });
  }

  Widget _sidebar({required bool scrollable}) {
    final l = AppLocalizations.of(context);
    int runningIndex = 0;
    final children = <Widget>[
      _Header(label: widget.session.label),
    ];
    for (final group in _groups) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(group.title(l).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ));
      for (final item in group.items) {
        final index = runningIndex++;
        final selected = index == _selected;
        children.add(ListTile(
          dense: true,
          selected: selected,
          selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          leading: Icon(item.icon),
          title: Text(item.label(l)),
          onTap: () => _select(index),
        ));
      }
    }
    if (widget.onExit != null) {
      children.add(const Divider());
      children.add(ListTile(
        dense: true,
        leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
        title: Text(widget.exitLabel ?? l.adminLogOut,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        onTap: widget.onExit,
      ));
    }
    return SafeArea(
      child: ListView(padding: EdgeInsets.zero, children: children),
    );
  }
}

class _Header extends StatelessWidget {
  final String? label;
  const _Header({this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(children: [
        Icon(Icons.settings_suggest, color: scheme.primary, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.adminPanelTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (label != null && label!.isNotEmpty)
              Text(label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
          ]),
        ),
      ]),
    );
  }
}
