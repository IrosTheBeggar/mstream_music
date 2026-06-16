import 'package:flutter/material.dart';

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
  static const _modes = {
    'all': 'All networks',
    'localhost': 'Localhost only',
    'whitelist': 'IP whitelist',
    'none': 'None (lock admin)',
  };

  late String _mode = _modes.containsKey(widget.access['mode'])
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
    await runAdminAction(
      context,
      () => widget.api.setAdminAccess(_mode,
          whitelist: _mode == 'whitelist' ? _whitelist : null),
      success: 'Admin access updated',
    );
    await widget.reload();
  }

  Future<void> _confirmLock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock the admin API?'),
        content: const Text(
            'This disables the entire /admin API for everyone. You will not be '
            'able to undo it from this panel — it requires editing the server '
            'config file and restarting. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lock'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await runAdminAction(context, () => widget.api.lockAdminApi(true),
          success: 'Admin API locked');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminViewBody(children: [
      AdminCard(
        title: 'Network access',
        subtitle: 'Restrict which networks may reach the admin API.',
        icon: Icons.security_outlined,
        children: [
          AdminDropdownRow<String>(
            label: 'Mode',
            value: _mode,
            items: [
              for (final e in _modes.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            // Local change only — applied with the button so the whitelist can
            // be edited first.
            onChanged: (v) async => setState(() => _mode = v),
          ),
          if (_mode == 'whitelist') ...[
            const Divider(height: 24),
            Text('Whitelisted IPs / CIDRs',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            if (_whitelist.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('None yet',
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
                  decoration: const InputDecoration(
                    labelText: 'Add IP or CIDR',
                    hintText: '192.168.1.0/24',
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
            child: AdminActionButton(label: 'Apply', onPressed: _apply),
          ),
        ],
      ),
      AdminCard(
        title: 'Danger zone',
        icon: Icons.warning_amber,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock admin API'),
            subtitle: const Text(
                'Disable the entire admin API. Cannot be undone from here.'),
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              onPressed: _confirmLock,
              child: const Text('Lock'),
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
