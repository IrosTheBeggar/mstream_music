import 'package:flutter/material.dart';

import '../objects/server.dart';
import '../singletons/server_list.dart';
import 'add_server.dart';

class ManageServersScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Manage Servers"),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddServerScreen()),
            );
          },
          child: Icon(Icons.add),
          backgroundColor: Color(0xFFFFAB00),
        ),
        body: Row(children: [
          Expanded(
              child: SizedBox(
                  child: StreamBuilder<List<Server>>(
                      stream: ServerManager().serverListStream,
                      builder: (context, snapshot) {
                        final List<Server> cServerList = snapshot.data ?? [];
                        return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: cServerList.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    Divider(height: 3, color: Colors.black),
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                title: Text(cServerList[index].url,
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 18)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: Icon(Icons.edit),
                                        color: Color(0xFF212121),
                                        tooltip: 'Edit Server',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    EditServerScreen(
                                                        editThisServer: index)),
                                          );
                                        }),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Delete Server',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            // return object of type Dialog
                                            return DeleteServerDialog(
                                                cServer: ServerManager()
                                                    .serverList[index]);
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            });
                      })))
        ]));
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
    return AlertDialog(
      title: Text("Confirm Remove Server"),
      content: Row(children: <Widget>[
        Checkbox(
            value: isRemoveFilesOnServerDeleteSelected,
            onChanged: (bool? value) {
              setState(() {
                isRemoveFilesOnServerDeleteSelected =
                    !isRemoveFilesOnServerDeleteSelected;
              });
            }),
        Flexible(child: Text("Remove synced files from device?"))
      ]),
      actions: <Widget>[
        TextButton(
          child: Text("Go Back"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(
            "Delete",
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
