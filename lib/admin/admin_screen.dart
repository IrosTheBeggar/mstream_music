import 'package:flutter/material.dart';

import 'admin_api.dart';
import 'admin_session.dart';
import 'views/about_view.dart';
import 'views/admin_access_view.dart';
import 'views/backups_view.dart';
import 'views/database_view.dart';
import 'views/directories_view.dart';
import 'views/dlna_view.dart';
import 'views/federation_view.dart';
import 'views/logs_view.dart';
import 'views/mdns_view.dart';
import 'views/settings_view.dart';
import 'views/subsonic_view.dart';
import 'views/torrent_view.dart';
import 'views/transcoding_view.dart';
import 'views/users_view.dart';

/// A navigable destination in the admin sidebar.
class _NavItem {
  final IconData icon;
  final String label;
  final Widget Function(AdminApi) build;
  const _NavItem(this.icon, this.label, this.build);
}

class _NavGroup {
  final String title;
  final List<_NavItem> items;
  const _NavGroup(this.title, this.items);
}

/// The admin shell: a responsive grouped sidebar (permanent on wide windows, a
/// Drawer on narrow ones) plus the selected view. Owns the [AdminApi] for the
/// session and rebuilds the active view fresh on selection so only one view
/// polls/fetches at a time.
class AdminScreen extends StatefulWidget {
  final AdminSession session;

  /// Called when the user picks "Log out" / "Exit". On web this clears the
  /// session and returns to the login screen; embedded it pops the route. Null
  /// hides the action entirely.
  final VoidCallback? onExit;
  final String exitLabel;

  const AdminScreen({
    super.key,
    required this.session,
    this.onExit,
    this.exitLabel = 'Log out',
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminApi _api = AdminApi(widget.session);
  int _selected = 0;

  late final List<_NavGroup> _groups = [
    _NavGroup('Config', [
      _NavItem(Icons.folder_outlined, 'Directories', (a) => DirectoriesView(api: a)),
      _NavItem(Icons.people_outline, 'Users', (a) => UsersView(api: a)),
      _NavItem(Icons.wifi_tethering, 'DLNA', (a) => DlnaView(api: a)),
      _NavItem(Icons.play_circle_outline, 'Subsonic API', (a) => SubsonicView(api: a)),
      _NavItem(Icons.travel_explore, 'MP3 Player', (a) => MdnsView(api: a)),
      _NavItem(Icons.download_outlined, 'Torrent', (a) => TorrentView(api: a)),
      _NavItem(Icons.hub_outlined, 'Federation', (a) => FederationView(api: a)),
    ]),
    _NavGroup('Server', [
      _NavItem(Icons.info_outline, 'About', (a) => AboutView(api: a)),
      _NavItem(Icons.settings_outlined, 'Settings', (a) => SettingsView(api: a)),
      _NavItem(Icons.storage_outlined, 'Database', (a) => DatabaseView(api: a)),
      _NavItem(Icons.backup_outlined, 'Backups', (a) => BackupsView(api: a)),
      _NavItem(Icons.transform, 'Transcoding', (a) => TranscodingView(api: a)),
      _NavItem(Icons.article_outlined, 'Logs', (a) => LogsView(api: a)),
      _NavItem(Icons.security_outlined, 'Admin Access', (a) => AdminAccessView(api: a)),
    ]),
  ];

  List<_NavItem> get _flat => [for (final g in _groups) ...g.items];

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _selected = index);
    Navigator.of(context).maybePop(); // close the Drawer if open
  }

  @override
  Widget build(BuildContext context) {
    final active = _flat[_selected];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final content = Scaffold(
        appBar: AppBar(
          title: Text('mStream Admin · ${active.label}'),
          leading: wide ? null : null, // Drawer button auto-added when drawer set
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
            // Fresh view on each selection (ValueKey) → only one poller at a time.
            child: KeyedSubtree(
              key: ValueKey(_selected),
              child: active.build(_api),
            ),
          ),
        ]),
      );
      return content;
    });
  }

  Widget _sidebar({required bool scrollable}) {
    int runningIndex = 0;
    final children = <Widget>[
      _Header(label: widget.session.label),
    ];
    for (final group in _groups) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(group.title.toUpperCase(),
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
          title: Text(item.label),
          onTap: () => _select(index),
        ));
      }
    }
    if (widget.onExit != null) {
      children.add(const Divider());
      children.add(ListTile(
        dense: true,
        leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
        title: Text(widget.exitLabel,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(children: [
        Icon(Icons.settings_suggest, color: scheme.primary, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('mStream Admin',
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
