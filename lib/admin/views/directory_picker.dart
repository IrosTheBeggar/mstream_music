import 'package:flutter/material.dart';

import '../admin_api.dart';

/// A modal that browses the *server's* filesystem (admin file-explorer can see
/// the whole disk) and returns the chosen absolute directory path. Navigation
/// uses the server's `joinDirectory` ('..' for parent) so path-joining stays
/// correct regardless of the server OS.
class DirectoryPickerDialog extends StatefulWidget {
  final AdminApi api;
  const DirectoryPickerDialog({super.key, required this.api});

  static Future<String?> show(BuildContext context, AdminApi api) =>
      showDialog<String>(
        context: context,
        builder: (_) => DirectoryPickerDialog(api: api),
      );

  @override
  State<DirectoryPickerDialog> createState() => _DirectoryPickerDialogState();
}

class _DirectoryPickerDialogState extends State<DirectoryPickerDialog> {
  String _path = '~';
  List<String> _dirs = [];
  List<String> _drives = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrives();
    _load(directory: '~');
  }

  Future<void> _loadDrives() async {
    try {
      final drives = await widget.api.winDrives();
      if (mounted) setState(() => _drives = drives);
    } catch (_) {
      // Non-Windows server returns 400 — no drive picker needed.
    }
  }

  Future<void> _load({required String directory, String? join}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await widget.api.browseDirectory(directory, joinDirectory: join);
      if (!mounted) return;
      setState(() {
        _path = '${res['path']}';
        _dirs = [
          for (final d in (res['directories'] as List?) ?? const [])
            '${d['name']}'
        ]..sort();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Choose a folder'),
      content: SizedBox(
        width: 480,
        height: 440,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              const Icon(Icons.folder_open, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_path,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          if (_drives.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final drive in _drives)
                    ActionChip(
                      label: Text(drive),
                      onPressed: () => _load(directory: drive),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: TextStyle(color: scheme.error)))
                    : ListView(children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.arrow_upward),
                          title: const Text('..'),
                          onTap: () => _load(directory: _path, join: '..'),
                        ),
                        for (final dir in _dirs)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder),
                            title: Text(dir),
                            onTap: () => _load(directory: _path, join: dir),
                          ),
                      ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : () => Navigator.pop(context, _path),
          child: const Text('Select this folder'),
        ),
      ],
    );
  }
}
