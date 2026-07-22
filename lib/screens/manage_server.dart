import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';
import '../native/iroh_tunnel.dart';
import '../singletons/log_manager.dart';
import '../theme/velvet_theme.dart';
import '../widgets/iroh_pairing_qr_sheet.dart';
import 'add_server.dart';

class ManageServersScreen extends StatelessWidget {
  const ManageServersScreen({super.key});

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

  // The per-row ⋮ overflow menu (Make Default / Info / Pairing code / Edit /
  // Delete).
  Widget _overflowMenu(BuildContext context, int index) {
    final l = AppLocalizations.of(context);
    final Server server = ServerManager().serverList[index];
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
          case 'pairingCode':
            showIrohPairingQrSheet(context, server.irohPairingCode!);
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
        // Re-share this iroh server's pairing QR so another device can pair.
        if (server.isIroh && server.irohPairingCode != null)
          _menuItem('pairingCode', Icons.qr_code_2, l.irohShowPairingCode),
        _menuItem('edit', Icons.edit_outlined, l.edit),
        // The app-managed embedded server can't be removed from the UI: the
        // app runs it, so deleting the entry would just strand the running
        // server (Server Mode reconfigures it instead).
        if (!ServerManager().serverList[index].isAttachedServer)
          _menuItem('delete', Icons.delete_outline, l.delete,
              color: VelvetColors.error),
      ],
    );
  }

  // Live Direct/Relay chip for the ACTIVE iroh server's tunnel — shown only while
  // CONNECTED (the banner covers reconnecting/down/re-pair), so the chip stays
  // focused on direct-vs-relay and never shows an ambiguous "…" when disconnected.
  // Meaningless for HTTP/inactive servers, so the caller also gates on those.
  Widget _irohPathChip() {
    return StreamBuilder<IrohTunnelStatus>(
      stream: ServerManager().tunnelStatusStream,
      initialData: ServerManager().tunnelStatus,
      builder: (context, sSnap) {
        if (sSnap.data != IrohTunnelStatus.connected) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<IrohPathKind>(
          stream: ServerManager().pathKindStream,
          initialData: ServerManager().pathKind,
          builder: (context, pSnap) {
            final pk = pSnap.data ?? IrohPathKind.unknown;
            if (pk == IrohPathKind.unknown) return const SizedBox.shrink();
            final l = AppLocalizations.of(context);
            final bool relay = pk == IrohPathKind.relay;
            final Color color =
                relay ? VelvetColors.warning : VelvetColors.success;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(relay ? Icons.cloud_queue : Icons.bolt,
                    size: 13, color: color),
                const SizedBox(width: 4),
                Text(relay ? l.irohPathRelay : l.irohPathDirect,
                    style: TextStyle(fontSize: 11, color: color)),
              ]),
            );
          },
        );
      },
    );
  }

  // "Built-in" chip for the app-managed embedded server (isAttachedServer) so
  // it's obvious which entry IS this PC's own server. Same visual language as
  // the Direct/Relay chip.
  Widget _builtInChip(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: VelvetColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.computer, size: 13, color: VelvetColors.primary),
        const SizedBox(width: 4),
        Text(l.serverBadgeBuiltIn,
            style: TextStyle(fontSize: 11, color: VelvetColors.primary)),
      ]),
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
              if (server.isAttachedServer)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _builtInChip(context),
                ),
              if (server.isIroh && server == ServerManager().currentServer)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _irohPathChip(),
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

  @override
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
        backgroundColor: VelvetColors.primary,
        child: Icon(
          Icons.add,
          color: VelvetColors.onPrimary,
        ),
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

  DeleteServerDialog({super.key, required this.cServer});

  @override
  State<DeleteServerDialog> createState() => _DeleteServerDialogState();
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
            } catch (err) {
              appLog('[server] remove failed: $err');
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
