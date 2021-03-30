import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';

import '../objects/server.dart';
import '../singletons/server_list.dart';
import 'add_server.dart';

class ManageServersScreen extends StatefulWidget {
  @override
  ManageServersScreenState createState() {
    return ManageServersScreenState();
  }
}

class ManageServersScreenState extends State<ManageServersScreen> {
  Future<void> _deleteServeDirectory(Server removedServer) async {
    final directory = await getApplicationDocumentsDirectory();
    var dir = new Directory(path.join(
        directory.path.toString(), 'media/' + removedServer.localname));
    dir.delete(recursive: true);
  }

  @override
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
                child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: ServerManager.serverList.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: Text(ServerManager.serverList[index].nickname,
                            style:
                                TextStyle(color: Colors.black, fontSize: 18)),
                        subtitle: Text(
                          ServerManager.serverList[index].url,
                          style: TextStyle(color: Colors.black),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: Icon(Icons.edit),
                                color: Color(0xFF212121),
                                tooltip: 'Edit Server',
                                onPressed: () {
                                  // editThisServer = index;
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //       builder: (context) =>
                                  //           EditServerScreen()),
                                  // );
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
                                    return AlertDialog(
                                      title: Text("Confirm Remove Server"),
                                      content: Row(children: <Widget>[
                                        DeleteServerAlertForm(),
                                        Flexible(
                                            child: Text(
                                                "Remove synced files from device?"))
                                      ]),
                                      actions: <Widget>[
                                        FlatButton(
                                          child: Text("Go Back"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        FlatButton(
                                          child: Text(
                                            "Delete",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onPressed: () {
                                            // try {
                                            //   ServerManager.serverList[index];
                                            //   Server removedServer =
                                            //       serverList.removeAt(index);

                                            //   // Handle case were all servers are removed
                                            //   if (ServerManager
                                            //           .serverList.length ==
                                            //       0) {
                                            //     ServerManager.currentServer =
                                            //         null;
                                            //   } else if (currentServer ==
                                            //       index) {
                                            //     // Handle case where user removes the current server
                                            //     redrawServerFlag.value =
                                            //         !redrawServerFlag.value;
                                            //     setState(() {
                                            //       currentServer = 0;
                                            //     });
                                            //   } else if (currentServer >
                                            //       index) {
                                            //     // Handle case where curent server is after removed index
                                            //     setState(() {
                                            //       currentServer =
                                            //           currentServer - 1;
                                            //     });
                                            //   }

                                            //   // Delete files
                                            //   if (isRemoveFilesOnServerDeleteSelected ==
                                            //       true) {
                                            //     _deleteServeDirectory(
                                            //         removedServer);
                                            //   }
                                            // } catch (err) {}
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    })),
          )
        ]));
  }
}

class DeleteServerAlertForm extends StatefulWidget {
  // DeleteServerAlertForm({Key key}) : super(key: key);

  @override
  _DeleteServerAlertFormState createState() =>
      new _DeleteServerAlertFormState();
}

bool isRemoveFilesOnServerDeleteSelected = false;

class _DeleteServerAlertFormState extends State<DeleteServerAlertForm> {
  @override
  void initState() {
    isRemoveFilesOnServerDeleteSelected = false;
  }

  @override
  Widget build(BuildContext context) {
    return new Checkbox(
        value: isRemoveFilesOnServerDeleteSelected,
        onChanged: (bool? value) {
          isRemoveFilesOnServerDeleteSelected =
              !isRemoveFilesOnServerDeleteSelected;
        });
  }
}
