import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Users" — accounts, per-user library access and permission flags.
class UsersView extends StatelessWidget {
  final AdminApi api;
  const UsersView({super.key, required this.api});

  Future<({Map<String, dynamic> users, List<String> libs})> _load() async {
    final (users, dirs) = await (api.getUsers(), api.getDirectories()).wait;
    return (users: users, libs: dirs.keys.toList()..sort());
  }

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        final l = AppLocalizations.of(context);
        final names = data.users.keys.toList()..sort();
        return Stack(children: [
          AdminViewBody(children: [
            if (names.isEmpty)
              AdminCard(
                title: l.adminNoUsersTitle,
                subtitle: l.adminNoUsersSubtitle,
                icon: Icons.person_off_outlined,
                children: const [],
              ),
            for (final name in names)
              _UserCard(
                api: api,
                username: name,
                info: Map<String, dynamic>.from(data.users[name]),
                allLibs: data.libs,
                reload: reload,
              ),
            const SizedBox(height: 64),
          ]),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: Text(l.adminAddUserButton),
              onPressed: () async {
                final added = await showDialog<bool>(
                  context: context,
                  builder: (_) => _AddUserDialog(api: api, allLibs: data.libs),
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

class _UserCard extends StatefulWidget {
  final AdminApi api;
  final String username;
  final Map<String, dynamic> info;
  final List<String> allLibs;
  final Future<void> Function() reload;
  const _UserCard({
    required this.api,
    required this.username,
    required this.info,
    required this.allLibs,
    required this.reload,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  late bool _admin = widget.info['admin'] == true;
  late bool _mkdir = widget.info['allowMkdir'] == true;
  late bool _upload = widget.info['allowUpload'] == true;
  late bool _fileModify = widget.info['allowFileModify'] == true;
  late bool _serverAudio = widget.info['allowServerAudio'] == true;
  late bool _torrent = widget.info['allowTorrent'] == true;
  late List<String> _vpaths = [
    for (final v in (widget.info['vpaths'] as List?) ?? const []) '$v'
  ];

  /// Access flags are set as a group (POST /users/access), so any single
  /// toggle re-sends the whole set; revert local state on failure.
  Future<void> _setAccess(void Function() mutate, void Function() revert) async {
    setState(mutate);
    final ok = await runAdminAction(
      context,
      () => widget.api.setUserAccess(
        widget.username,
        admin: _admin,
        allowMkdir: _mkdir,
        allowUpload: _upload,
        allowFileModify: _fileModify,
        allowServerAudio: _serverAudio,
      ),
    );
    if (!ok && mounted) setState(revert);
  }

  Widget _flag(String label, bool value, void Function(bool) set) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: (v) => set(v),
    );
  }

  Future<void> _editVpaths() async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiSelectDialog(
        title: l.adminLibraryAccessDialogTitle,
        all: widget.allLibs,
        selected: _vpaths,
      ),
    );
    if (result != null && mounted) {
      setState(() => _vpaths = result);
      await runAdminAction(
          context, () => widget.api.setUserVPaths(widget.username, result),
          success: l.adminLibraryAccessUpdatedToast);
    }
  }

  Future<void> _changePassword({bool subsonic = false}) async {
    final l = AppLocalizations.of(context);
    final pw = await _promptPassword(context,
        title: subsonic
            ? l.adminSetSubsonicPasswordTitle
            : l.adminSetPasswordTitle);
    if (pw == null || !mounted) return;
    await runAdminAction(
      context,
      () => subsonic
          ? widget.api.setUserSubsonicPassword(widget.username, pw)
          : widget.api.setUserPassword(widget.username, pw),
      success: l.adminPasswordUpdatedToast,
    );
  }

  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.adminDeleteUserTitle(widget.username)),
          content: Text(l.adminDeleteUserWarning),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.adminCancel)),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.adminDelete),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      await runAdminAction(
          context, () => widget.api.deleteUser(widget.username),
          success: l.adminUserDeletedToast);
      await widget.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AdminCard(
      title: widget.username,
      icon: Icons.person,
      trailing: [
        if (_admin)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: StatusPill(label: l.adminStatusPillLabel, color: Colors.indigo),
          ),
        PopupMenuButton<String>(
          itemBuilder: (_) => [
            PopupMenuItem(value: 'pw', child: Text(l.adminSetPasswordTitle)),
            PopupMenuItem(
                value: 'spw', child: Text(l.adminSetSubsonicPasswordTitle)),
            PopupMenuItem(
                value: 'del',
                child: Text(l.adminDeleteUserMenuItem,
                    style: TextStyle(color: scheme.error))),
          ],
          onSelected: (v) {
            switch (v) {
              case 'pw':
                _changePassword();
              case 'spw':
                _changePassword(subsonic: true);
              case 'del':
                _confirmDelete();
            }
          },
        ),
      ],
      children: [
        Row(children: [
          Expanded(
            child: Text(
              _vpaths.isEmpty ? l.adminNoLibraryAccessLabel : _vpaths.join(', '),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: Text(l.adminLibrariesButton),
            onPressed: _editVpaths,
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          _flag(l.adminAdminToggleTitle, _admin,
              (v) => _setAccess(() => _admin = v, () => _admin = !v)),
          _flag(l.adminMakeDirsToggleTitle, _mkdir,
              (v) => _setAccess(() => _mkdir = v, () => _mkdir = !v)),
          _flag(l.adminUploadToggleTitle, _upload,
              (v) => _setAccess(() => _upload = v, () => _upload = !v)),
          _flag(l.adminModifyFilesToggleTitle, _fileModify,
              (v) => _setAccess(() => _fileModify = v, () => _fileModify = !v)),
          _flag(l.adminServerAudioToggleTitle, _serverAudio,
              (v) => _setAccess(() => _serverAudio = v, () => _serverAudio = !v)),
          FilterChip(
            label: Text(l.adminTorrent),
            selected: _torrent,
            onSelected: (v) async {
              setState(() => _torrent = v);
              final ok = await runAdminAction(context,
                  () => widget.api.setUserTorrentAccess(widget.username, v));
              if (!ok && mounted) setState(() => _torrent = !v);
            },
          ),
        ]),
      ],
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  final AdminApi api;
  final List<String> allLibs;
  const _AddUserDialog({required this.api, required this.allLibs});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _subsonic = TextEditingController();
  bool _admin = false;
  bool _mkdir = true;
  bool _upload = true;
  bool _serverAudio = false;
  final Set<String> _vpaths = {};
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _subsonic.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      adminToast(context, l.adminUsernamePasswordRequiredError, error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAdminAction(
      context,
      () => widget.api.addUser(
        _username.text.trim(),
        _password.text,
        admin: _admin,
        vpaths: _vpaths.toList(),
        allowMkdir: _mkdir,
        allowUpload: _upload,
        allowServerAudio: _serverAudio,
        subsonicPassword:
            _subsonic.text.isEmpty ? null : _subsonic.text,
      ),
      success: l.adminUserCreatedToast,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.adminAddUserDialogTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _username,
                decoration: InputDecoration(labelText: l.adminUsername)),
            const SizedBox(height: 8),
            TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l.adminPassword)),
            const SizedBox(height: 8),
            TextField(
                controller: _subsonic,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: l.adminSubsonicPasswordLabel)),
            const SizedBox(height: 12),
            if (widget.allLibs.isNotEmpty) ...[
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.adminLibraryAccessHeader)),
              Wrap(
                spacing: 8,
                children: [
                  for (final lib in widget.allLibs)
                    FilterChip(
                      label: Text(lib),
                      selected: _vpaths.contains(lib),
                      onSelected: (v) => setState(() =>
                          v ? _vpaths.add(lib) : _vpaths.remove(lib)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.adminAdministratorToggleTitle),
              value: _admin,
              onChanged: (v) => setState(() => _admin = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.adminAllowMakeDirectoriesTitle),
              value: _mkdir,
              onChanged: (v) => setState(() => _mkdir = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.adminAllowUploadTitle),
              value: _upload,
              onChanged: (v) => setState(() => _upload = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.adminAllowServerAudioTitle),
              value: _serverAudio,
              onChanged: (v) => setState(() => _serverAudio = v ?? false),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.adminCancel)),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.adminCreate),
        ),
      ],
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> all;
  final List<String> selected;
  const _MultiSelectDialog(
      {required this.title, required this.all, required this.selected});

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<String> _sel = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: widget.all.isEmpty
            ? Text(l.adminNoLibrariesConfigured)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final lib in widget.all)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(lib),
                      value: _sel.contains(lib),
                      onChanged: (v) => setState(
                          () => v == true ? _sel.add(lib) : _sel.remove(lib)),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.adminCancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _sel.toList()),
            child: Text(l.adminSave)),
      ],
    );
  }
}

Future<String?> _promptPassword(BuildContext context,
    {required String title}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: l.adminNewPasswordLabel),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.adminCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: Text(l.adminSave)),
        ],
      );
    },
  );
  ctrl.dispose();
  return (result == null || result.isEmpty) ? null : result;
}
