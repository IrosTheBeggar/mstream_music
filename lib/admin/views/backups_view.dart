import 'dart:async';

import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';
import 'directory_picker.dart';

/// "Backups" — per-library backup destinations with triggers, retention, live
/// progress and run history.
class BackupsView extends StatelessWidget {
  final AdminApi api;
  const BackupsView({super.key, required this.api});

  Future<({List<dynamic> dests, Map<String, int> libs})> _load() async {
    final dests = await api.backupDestinations();
    final dirs = await api.getDirectories();
    final libs = <String, int>{};
    dirs.forEach((name, info) {
      final id = (info is Map && info['id'] is num)
          ? (info['id'] as num).toInt()
          : null;
      if (id != null) libs[name] = id;
    });
    return (dests: dests, libs: libs);
  }

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        return Stack(children: [
          AdminViewBody(children: [
            _StatusBanner(api: api),
            if (data.dests.isEmpty)
              const AdminCard(
                title: 'No backup destinations',
                icon: Icons.backup_outlined,
                children: [
                  Text('Add a destination to mirror a library to another folder.'),
                ],
              ),
            for (final d in data.dests)
              _DestinationCard(
                  api: api, dest: Map<String, dynamic>.from(d), reload: reload),
            const SizedBox(height: 64),
          ]),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add destination'),
              onPressed: data.libs.isEmpty
                  ? () => adminToast(context, 'Add a library first', error: true)
                  : () async {
                      final added = await showDialog<bool>(
                        context: context,
                        builder: (_) =>
                            _DestinationDialog(api: api, libs: data.libs),
                      );
                      if (added == true) await reload();
                    },
            ),
          ),
        ]);
      },
    );
  }
}

class _StatusBanner extends StatefulWidget {
  final AdminApi api;
  const _StatusBanner({required this.api});

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner> {
  Map<String, dynamic> _status = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final s = await widget.api.backupStatus();
      if (mounted) setState(() => _status = s);
    } catch (_) {/* transient */}
  }

  @override
  Widget build(BuildContext context) {
    final active = _status['active'];
    final queue = (_status['queueLength'] is num)
        ? (_status['queueLength'] as num).toInt()
        : 0;
    if (active == null) {
      if (queue == 0) return const SizedBox.shrink();
      return AdminCard(
        title: 'Backup queue',
        icon: Icons.schedule,
        children: [Text('$queue task(s) queued')],
      );
    }
    final a = Map<String, dynamic>.from(active);
    final copied = (a['filesCopied'] ?? 0) as num;
    final unchanged = (a['filesUnchanged'] ?? 0) as num;
    final trashed = (a['filesTrashed'] ?? 0) as num;
    final done = copied + unchanged + trashed;
    final expected = a['expectedFiles'];
    final value = (expected is num && expected > 0) ? (done / expected).clamp(0, 1).toDouble() : null;
    return AdminCard(
      title: 'Backing up: ${a['libraryName'] ?? ''}',
      icon: Icons.sync,
      trailing: const [StatusPill(label: 'running', color: Colors.blue)],
      children: [
        LinearProgressIndicator(value: value),
        const SizedBox(height: 6),
        Text(
            '$done files${expected is num ? ' / $expected' : ''} · '
            '$copied copied, $unchanged unchanged, $trashed trashed'),
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final AdminApi api;
  final Map<String, dynamic> dest;
  final Future<void> Function() reload;
  const _DestinationCard(
      {required this.api, required this.dest, required this.reload});

  int get _id => (dest['id'] as num).toInt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = dest['enabled'] == true;
    final last = dest['lastRun'];
    return AdminCard(
      title: '${dest['library_name'] ?? 'library'}',
      icon: Icons.backup_outlined,
      trailing: [
        StatusPill(
          label: enabled ? 'enabled' : 'disabled',
          color: enabled ? Colors.green : Colors.grey,
        ),
      ],
      children: [
        AdminInfoRow('Destination', '${dest['dest_path'] ?? ''}'),
        AdminInfoRow('Trigger', '${dest['trigger_type'] ?? ''}'
            '${dest['trigger_type'] == 'daily' ? ' @ ${dest['daily_at_hour']}:00' : ''}'),
        AdminInfoRow('Retention', '${dest['retention_days'] ?? 0} days'),
        if (last is Map)
          AdminInfoRow('Last run',
              '${last['status'] ?? '?'} · ${last['files_copied'] ?? 0} copied'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          AdminActionButton(
            label: 'Run now',
            icon: Icons.play_arrow,
            success: 'Backup queued',
            onPressed: () async {
              final r = await api.runBackup(_id);
              if (context.mounted && r['status'] == 'skipped') {
                adminToast(context, 'Already running — skipped');
              }
            },
          ),
          AdminActionButton(
            label: 'History',
            tonal: true,
            onPressed: () async {
              final history = await api.backupHistory(_id);
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (_) => _HistoryDialog(history: history),
              );
            },
          ),
          AdminActionButton(
            label: 'Edit',
            icon: Icons.edit,
            tonal: true,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) =>
                    _DestinationDialog(api: api, libs: const {}, existing: dest),
              );
              if (ok == true) await reload();
            },
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () async {
              await runAdminAction(context, () => api.deleteBackupDestination(_id),
                  success: 'Destination deleted');
              await reload();
            },
            child: const Text('Delete'),
          ),
        ]),
      ],
    );
  }
}

class _HistoryDialog extends StatelessWidget {
  final List<dynamic> history;
  const _HistoryDialog({required this.history});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backup history'),
      content: SizedBox(
        width: 460,
        height: 360,
        child: history.isEmpty
            ? const Center(child: Text('No history yet'))
            : ListView(children: [
                for (final h in history)
                  ListTile(
                    dense: true,
                    leading: Icon(_statusIcon(h['status'])),
                    title: Text('${h['status']} · ${h['trigger_reason'] ?? ''}'),
                    subtitle: Text(
                        '${h['started_at'] ?? ''}\n'
                        '${h['files_copied'] ?? 0} copied, '
                        '${h['files_unchanged'] ?? 0} unchanged'
                        '${h['error_message'] != null ? '\n${h['error_message']}' : ''}'),
                    isThreeLine: true,
                  ),
              ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  IconData _statusIcon(dynamic status) {
    switch ('$status') {
      case 'completed':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      case 'in-progress':
        return Icons.sync;
      default:
        return Icons.remove_circle_outline;
    }
  }
}

class _DestinationDialog extends StatefulWidget {
  final AdminApi api;
  final Map<String, int> libs;
  final Map<String, dynamic>? existing;
  const _DestinationDialog(
      {required this.api, required this.libs, this.existing});

  @override
  State<_DestinationDialog> createState() => _DestinationDialogState();
}

class _DestinationDialogState extends State<_DestinationDialog> {
  late int? _libraryId =
      widget.existing != null ? (widget.existing!['library_id'] as num).toInt() : null;
  late final _destPath = TextEditingController(
      text: '${widget.existing?['dest_path'] ?? ''}');
  late String _trigger = '${widget.existing?['trigger_type'] ?? 'after-scan'}';
  late int _dailyHour = (widget.existing?['daily_at_hour'] is num)
      ? (widget.existing!['daily_at_hour'] as num).toInt()
      : 3;
  late final _retention = TextEditingController(
      text: '${widget.existing?['retention_days'] ?? 30}');
  late bool _enabled = widget.existing?['enabled'] != false;
  bool _busy = false;
  String? _checkResult;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _destPath.dispose();
    _retention.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_libraryId == null || _destPath.text.trim().isEmpty) return;
    try {
      final r = await widget.api
          .backupCheckPath(_libraryId!, _destPath.text.trim());
      final errors = (r['errors'] as List?) ?? const [];
      final warnings = (r['warnings'] as List?) ?? const [];
      setState(() => _checkResult = r['ok'] == true
          ? (warnings.isEmpty ? 'OK' : '⚠ ${warnings.join('; ')}')
          : '✗ ${errors.join('; ')}');
    } catch (e) {
      setState(() => _checkResult = '$e');
    }
  }

  Future<void> _submit() async {
    if (!_isEdit && _libraryId == null) {
      adminToast(context, 'Pick a library', error: true);
      return;
    }
    if (_destPath.text.trim().isEmpty) {
      adminToast(context, 'Pick a destination path', error: true);
      return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'destPath': _destPath.text.trim(),
      'triggerType': _trigger,
      if (_trigger == 'daily') 'dailyAtHour': _dailyHour,
      'retentionDays': int.tryParse(_retention.text.trim()) ?? 30,
      'enabled': _enabled,
    };
    final ok = await runAdminAction(
      context,
      () => _isEdit
          ? widget.api
              .updateBackupDestination((widget.existing!['id'] as num).toInt(), body)
          : widget.api.createBackupDestination({...body, 'libraryId': _libraryId}),
      success: _isEdit ? 'Destination updated' : 'Destination created',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit destination' : 'Add backup destination'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!_isEdit)
              DropdownButtonFormField<int>(
                initialValue: _libraryId,
                decoration: const InputDecoration(labelText: 'Library'),
                items: [
                  for (final e in widget.libs.entries)
                    DropdownMenuItem(value: e.value, child: Text(e.key)),
                ],
                onChanged: (v) => setState(() => _libraryId = v),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _destPath,
                  decoration:
                      const InputDecoration(labelText: 'Destination path'),
                ),
              ),
              IconButton(
                tooltip: 'Browse server',
                icon: const Icon(Icons.folder_open),
                onPressed: () async {
                  final picked =
                      await DirectoryPickerDialog.show(context, widget.api);
                  if (picked != null) setState(() => _destPath.text = picked);
                },
              ),
            ]),
            if (_checkResult != null)
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_checkResult!,
                      style: const TextStyle(fontSize: 12))),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: _check, child: const Text('Check path')),
            ),
            DropdownButtonFormField<String>(
              initialValue: _trigger,
              decoration: const InputDecoration(labelText: 'Trigger'),
              items: const [
                DropdownMenuItem(value: 'after-scan', child: Text('After each scan')),
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'manual', child: Text('Manual only')),
              ],
              onChanged: (v) => setState(() => _trigger = v ?? 'after-scan'),
            ),
            if (_trigger == 'daily')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Text('Run at hour: '),
                  DropdownButton<int>(
                    value: _dailyHour,
                    items: [
                      for (var h = 0; h < 24; h++)
                        DropdownMenuItem(
                            value: h,
                            child: Text('${h.toString().padLeft(2, '0')}:00')),
                    ],
                    onChanged: (v) => setState(() => _dailyHour = v ?? 3),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _retention,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Retention (days, 0 = keep all)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
