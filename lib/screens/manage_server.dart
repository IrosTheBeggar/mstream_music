import 'package:flutter/material.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import 'add_server.dart';

class ManageServersScreen extends StatelessWidget {
  Widget generateDropdownMenu(BuildContext context, int index) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton(
        onSelected: (String command) {
          if (command == 'edit') {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        EditServerScreen(editThisServer: index)));
          }
          if (command == 'default') {
            ServerManager().makeDefault(index);
          }
          if (command == 'info') {
            // SimpleDialog(children: <Widget>[]);
            FileExplorer()
                .getServerDir(ServerManager().serverList[index])
                .then((dir) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                      title: Text(l.manageServerInfo),
                      content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(ServerManager().serverList[index].url),
                            Text(''),
                            Text(l.manageServerDownloadFolder),
                            Text(''),
                            Text(dir)
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
                      ]);
                },
              );
            });
          }
          if (command == 'delete') {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                // return object of type Dialog
                return DeleteServerDialog(
                    cServer: ServerManager().serverList[index]);
              },
            );
          }
        },
        icon: Icon(
          Icons.arrow_drop_down,
          color: VelvetColors.textPrimary,
        ),
        itemBuilder: (BuildContext context) {
          List<PopupMenuEntry<String>> popUpWidgetList = [
            PopupMenuItem(
              value: 'info',
              child: Row(children: [
                Icon(
                  Icons.info,
                  color: VelvetColors.textPrimary,
                ),
                Text('   ${l.info}',
                    style: TextStyle(color: VelvetColors.textPrimary))
              ]),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(
                  Icons.edit,
                  color: VelvetColors.textPrimary,
                ),
                Text('   ${l.edit}',
                    style: TextStyle(color: VelvetColors.textPrimary))
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                ),
                Text('   ${l.delete}',
                    style: TextStyle(color: VelvetColors.textPrimary))
              ]),
            )
          ];

          if (index != 0) {
            popUpWidgetList.insert(
                0,
                PopupMenuItem(
                  value: 'default',
                  child: Row(children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: VelvetColors.textPrimary,
                    ),
                    Text('   ${l.makeDefault}',
                        style: TextStyle(color: VelvetColors.textPrimary))
                  ]),
                ));
          }

          return popUpWidgetList;
        });
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
            color: VelvetColors.textPrimary,
          ),
          backgroundColor: Color(0xFFFFAB00),
        ),
        body: SafeArea(top: false, child: Row(children: [
          Expanded(
              child: SizedBox(
                  child: StreamBuilder<List<Server>>(
                      stream: ServerManager().serverListStream,
                      builder: (context, snapshot) {
                        final List<Server> cServerList = snapshot.data ?? [];
                        return Container(
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom:
                                        BorderSide(color: Color(0xFFbdbdbd)))),
                            child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: cServerList.length,
                                separatorBuilder:
                                    (BuildContext context, int index) =>
                                        Divider(height: 3, color: Colors.white),
                                itemBuilder: (BuildContext context, int index) {
                                  return Container(
                                      decoration: BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: Color(0xFFbdbdbd)))),
                                      child: ListTile(
                                          title: Text(cServerList[index].url,
                                              style: TextStyle(
                                                  color: VelvetColors.textPrimary,
                                                  fontSize: 18)),
                                          trailing: generateDropdownMenu(
                                              context, index)));
                                }));
                      })))
        ])));
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
            style: TextStyle(color: Colors.red),
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
