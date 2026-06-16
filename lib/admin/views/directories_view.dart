import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';
import 'directory_picker.dart';

/// "Directories" — the libraries (vpaths) the server scans.
class DirectoriesView extends StatelessWidget {
  final AdminApi api;
  const DirectoriesView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.getDirectories,
      builder: (context, dirs, reload) {
        final names = dirs.keys.toList()..sort();
        return Stack(children: [
          AdminViewBody(children: [
            if (names.isEmpty)
              const AdminCard(
                title: 'No libraries yet',
                icon: Icons.folder_off_outlined,
                children: [
                  Text('Add a directory to start scanning music into the library.'),
                ],
              ),
            for (final name in names)
              _LibraryCard(
                api: api,
                name: name,
                info: Map<String, dynamic>.from(dirs[name]),
                reload: reload,
              ),
            const SizedBox(height: 64), // room for the FAB
          ]),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Add directory'),
              onPressed: () async {
                final added = await showDialog<bool>(
                  context: context,
                  builder: (_) => _AddDirectoryDialog(api: api),
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

class _LibraryCard extends StatelessWidget {
  final AdminApi api;
  final String name;
  final Map<String, dynamic> info;
  final Future<void> Function() reload;
  const _LibraryCard(
      {required this.api,
      required this.name,
      required this.info,
      required this.reload});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "$name"?'),
        content: const Text(
            'This removes the library and its scanned tracks from the database. '
            'Files on disk are left untouched.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runAdminAction(context, () => api.removeDirectory(name),
          success: 'Library removed');
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: name,
      icon: info['type'] == 'audiobook' ? Icons.menu_book : Icons.library_music,
      trailing: [
        IconButton(
          tooltip: 'Remove',
          icon: Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.error),
          onPressed: () => _confirmDelete(context),
        ),
      ],
      children: [
        AdminInfoRow('Path', '${info['root'] ?? ''}'),
        AdminInfoRow('Type', '${info['type'] ?? 'music'}'),
        AdminAsyncSwitch(
          title: 'Follow symlinks',
          subtitle: 'Takes effect on the next scan',
          value: info['followSymlinks'] == true,
          onChanged: (v) => api.setFollowSymlinks(name, v),
        ),
      ],
    );
  }
}

class _AddDirectoryDialog extends StatefulWidget {
  final AdminApi api;
  const _AddDirectoryDialog({required this.api});

  @override
  State<_AddDirectoryDialog> createState() => _AddDirectoryDialogState();
}

class _AddDirectoryDialogState extends State<_AddDirectoryDialog> {
  final _vpath = TextEditingController();
  String? _directory;
  bool _autoAccess = false;
  bool _isAudioBooks = false;
  bool _busy = false;

  @override
  void dispose() {
    _vpath.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vpath = _vpath.text.trim();
    if (_directory == null || vpath.isEmpty) {
      adminToast(context, 'Pick a folder and enter a name', error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAdminAction(
      context,
      () => widget.api.addDirectory(_directory!, vpath,
          autoAccess: _autoAccess, isAudioBooks: _isAudioBooks),
      success: 'Directory added — scanning started',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add directory'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: Text(_directory ?? 'Choose folder on server…',
                overflow: TextOverflow.ellipsis),
            onPressed: () async {
              final picked =
                  await DirectoryPickerDialog.show(context, widget.api);
              if (picked != null) setState(() => _directory = picked);
            },
          ),
          if (_directory != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_directory!,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _vpath,
            decoration: const InputDecoration(
              labelText: 'Library name (vpath)',
              helperText: 'Letters, numbers and dashes',
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Grant all users access'),
            value: _autoAccess,
            onChanged: (v) => setState(() => _autoAccess = v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Audiobook library'),
            value: _isAudioBooks,
            onChanged: (v) => setState(() => _isAudioBooks = v ?? false),
          ),
        ]),
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
              : const Text('Add'),
        ),
      ],
    );
  }
}
