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
              child: StreamBuilder<List<Server>>(
                  stream: ServerManager().serverListStream,
                  builder: (context, snapshot) {
                    final List<Server> cServerList = snapshot.data!;
                    return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: cServerList.length,
                        itemBuilder: (BuildContext context, int index) {
                          return ListTile(
                            title: Text(cServerList[index].nickname,
                                style: TextStyle(
                                    color: Colors.black, fontSize: 18)),
                            subtitle: Text(
                              cServerList[index].url,
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
                                            TextButton(
                                              child: Text("Go Back"),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                            TextButton(
                                              child: Text(
                                                "Delete",
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                              onPressed: () {
                                                try {
                                                  ServerManager().removeServer(
                                                      cServerList[index],
                                                      false);
                                                } catch (err) {}
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
                        });
                  }),
            ),
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
