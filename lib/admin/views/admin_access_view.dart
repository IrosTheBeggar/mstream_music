import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Admin Access" — the application-level IP gate for the admin surface
/// (`adminAccess.mode`) plus the global admin-API lock.
class AdminAccessView extends StatelessWidget {
  final AdminApi api;
  const AdminAccessView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.getConfig,
      builder: (context, config, reload) {
        final access = (config['adminAccess'] as Map?) ?? const {};
        return _AdminAccessEditor(api: api, access: access, reload: reload);
      },
    );
  }
}

class _AdminAccessEditor extends StatefulWidget {
  final AdminApi api;
  final Map access;
  final Future<void> Function() reload;
  const _AdminAccessEditor(
      {required this.api, required this.access, required this.reload});

  @override
  State<_AdminAccessEditor> createState() => _AdminAccessEditorState();
}

class _AdminAccessEditorState extends State<_AdminAccessEditor> {
  static const _modeKeys = ['all', 'localhost', 'whitelist', 'none'];

  String _modeLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'localhost':
        return l.adminLocalhostOnly;
      case 'whitelist':
        return l.adminIpWhitelist;
      case 'none':
        return l.adminNoneLockAdmin;
      case 'all':
      default:
        return l.adminAllNetworks;
    }
  }

  late String _mode = _modeKeys.contains(widget.access['mode'])
      ? widget.access['mode']
      : 'all';
  late final List<String> _whitelist = [
    for (final e in (widget.access['whitelist'] as List?) ?? const []) '$e'
  ];
  final TextEditingController _newIp = TextEditingController();

  @override
  void dispose() {
    _newIp.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l = AppLocalizations.of(context);
    await runAdminAction(
      context,
      () => widget.api.setAdminAccess(_mode,
          whitelist: _mode == 'whitelist' ? _whitelist : null),
      success: l.adminAccessUpdated,
    );
    await widget.reload();
  }

  Future<void> _confirmLock() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.adminLockAdminApiDialog),
          content: Text(l.adminLockAdminApiDialogBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.adminCancel)),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.adminLockButton),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      await runAdminAction(context, () => widget.api.lockAdminApi(true),
          success: l.adminAdminApiLocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AdminViewBody(children: [
      AdminCard(
        title: l.adminNetworkAccess,
        subtitle: l.adminNetworkAccessSubtitle,
        icon: Icons.security_outlined,
        children: [
          AdminDropdownRow<String>(
            label: l.adminMode,
            value: _mode,
            items: [
              for (final e in _modeKeys)
                DropdownMenuItem(value: e, child: Text(_modeLabel(l, e))),
            ],
            // Local change only — applied with the button so the whitelist can
            // be edited first.
            onChanged: (v) async => setState(() => _mode = v),
          ),
          if (_mode == 'whitelist') ...[
            const Divider(height: 24),
            Text(l.adminWhitelistedIps,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            if (_whitelist.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l.adminNoneYet,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ip in _whitelist)
                  Chip(
                    label: Text(ip),
                    onDeleted: () => setState(() => _whitelist.remove(ip)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newIp,
                  decoration: InputDecoration(
                    labelText: l.adminAddIpOrCidr,
                    hintText: l.adminCidrExample,
                  ),
                  onSubmitted: (_) => _addIp(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                  onPressed: _addIp, icon: const Icon(Icons.add)),
            ]),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AdminActionButton(label: l.adminApply, onPressed: _apply),
          ),
        ],
      ),
      AdminCard(
        title: l.adminDangerZone,
        icon: Icons.warning_amber,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.adminLockAdminApi),
            subtitle: Text(l.adminLockAdminApiSubtitle),
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              onPressed: _confirmLock,
              child: Text(l.adminLockButton),
            ),
          ),
        ],
      ),
    ]);
  }

  void _addIp() {
    final ip = _newIp.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      if (!_whitelist.contains(ip)) _whitelist.add(ip);
      _newIp.clear();
    });
  }
}
