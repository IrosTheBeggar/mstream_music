import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import 'add_server.dart';

class ManageServersScreen extends StatelessWidget {
  void _pushEdit(BuildContext context, int index) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => EditServerScreen(editThisServer: index)));
  }

  void _showServerInfo(BuildContext context, int index) {
    final l = AppLocalizations.of(context);
    FileExplorer()
        .getServerDir(ServerManager().serverList[index])
        .then((dir) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(l.manageServerInfo),
            content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ServerManager().serverList[index].url,
                      style: TextStyle(color: VelvetColors.textPrimary)),
                  const SizedBox(height: 16),
                  Text(l.manageServerDownloadFolder,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(dir, style: TextStyle(color: VelvetColors.textPrimary)),
                ]),
            actions: <Widget>[
              TextButton(
                child: Text(l.manageServerCopyPath),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: dir));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l.manageServerPathCopied)));
                },
              )
            ],
          );
        },
      );
    });
  }

  void _showDeleteDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteServerDialog(cServer: ServerManager().serverList[index]);
      },
    );
  }

  // A single popup-menu row: leading icon + label, both tintable (used to
  // flag the destructive Delete action in the error color).
  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 20, color: color ?? VelvetColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color ?? VelvetColors.textPrimary)),
      ]),
    );
  }

  // The per-row ⋮ overflow menu (Make Default / Info / Edit / Delete).
  Widget _overflowMenu(BuildContext context, int index) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: VelvetColors.textSecondary),
      color: VelvetColors.surface,
      tooltip: l.mainMore,
      onSelected: (String command) {
        switch (command) {
          case 'edit':
            _pushEdit(context, index);
            break;
          case 'default':
            ServerManager().makeDefault(index);
            break;
          case 'info':
            _showServerInfo(context, index);
            break;
          case 'delete':
            _showDeleteDialog(context, index);
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        // Index 0 is already the default server, so omit the action.
        if (index != 0)
          _menuItem('default', Icons.arrow_upward_rounded, l.makeDefault),
        _menuItem('info', Icons.info_outline, l.info),
        _menuItem('edit', Icons.edit_outlined, l.edit),
        _menuItem('delete', Icons.delete_outline, l.delete,
            color: VelvetColors.error),
      ],
    );
  }

  // A modern server row, mirroring the playlist rows: an icon tile (tinted
  // for the default server), the URL, a star marking the default, and the
  // ⋮ menu. Tapping the row opens the edit screen.
  Widget _serverRow(BuildContext context, Server server, int index) {
    final bool isDefault = index == 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pushEdit(context, index),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: VelvetColors.border, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      isDefault ? VelvetColors.primaryDim : VelvetColors.raised,
                  borderRadius:
                      BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                child: Icon(Icons.dns,
                    color: isDefault
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  server.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary,
                  ),
                ),
              ),
              if (isDefault)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child:
                      Icon(Icons.star, size: 16, color: VelvetColors.primary),
                ),
              _overflowMenu(context, index),
            ],
          ),
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.manageServersTitle),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddServerScreen()),
          );
        },
        child: Icon(
          Icons.add,
          color: VelvetColors.onPrimary,
        ),
        backgroundColor: VelvetColors.primary,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Server>>(
          stream: ServerManager().serverListStream,
          builder: (context, snapshot) {
            final List<Server> cServerList = snapshot.data ?? [];
            if (cServerList.isEmpty) {
              return Center(
                child: Icon(
                  Icons.dns_outlined,
                  size: 72,
                  color: VelvetColors.textSecondary.withValues(alpha: 0.4),
                ),
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: cServerList.length,
              itemBuilder: (BuildContext context, int index) =>
                  _serverRow(context, cServerList[index], index),
            );
          },
        ),
      ),
    );
  }
}

class DeleteServerDialog extends StatefulWidget {
  final Server cServer;

  DeleteServerDialog({required this.cServer});

  @override
  _DeleteServerDialogState createState() => _DeleteServerDialogState();
}

class _DeleteServerDialogState extends State<DeleteServerDialog> {
  bool isRemoveFilesOnServerDeleteSelected = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.confirmRemoveServerTitle),
      content: Row(children: <Widget>[
        Checkbox(
            value: isRemoveFilesOnServerDeleteSelected,
            onChanged: (bool? value) {
              setState(() {
                isRemoveFilesOnServerDeleteSelected =
                    !isRemoveFilesOnServerDeleteSelected;
              });
            }),
        Flexible(child: Text(l.removeSyncedFiles))
      ]),
      actions: <Widget>[
        TextButton(
          child: Text(l.goBack),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(
            l.delete,
            style: TextStyle(color: VelvetColors.error),
          ),
          onPressed: () {
            try {
              ServerManager().removeServer(
                  widget.cServer, isRemoveFilesOnServerDeleteSelected);
            } catch (err) {}
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
