import 'package:flutter/material.dart';
import 'package:mstream_music/objects/server.dart';
import '../singletons/server_list.dart';
import '../singletons/media.dart';

class AutoDJScreen extends StatelessWidget {
  setAutoDJ(Server? server) {
    MediaManager()
        .audioHandler
        .customAction('setAutoDJ', {'autoDJServer': server});
  }

  @override
  Widget build(BuildContext context) {
    // Handle No Servers
    if (ServerManager().serverList.length == 0) {
      return Scaffold(
          backgroundColor: Color(0xFF3f3f3f),
          appBar: AppBar(
            title: Text("Auto DJ"),
          ),
          body: Container(
              padding: EdgeInsets.all(40.0),
              child: ListView(children: [
                Text('Please add a server'),
              ])));
    }

    return Scaffold(
        backgroundColor: Color(0xFF3f3f3f),
        appBar: AppBar(
          title: Text("Auto DJ"),
        ),
        body: Container(
            padding: EdgeInsets.all(40.0),
            child: ListView(children: [
              StreamBuilder<dynamic>(
                  stream: MediaManager().audioHandler.customState,
                  builder: (context, snapshot) {
                    final Server? autoDJState =
                        (snapshot.data?.autoDJState as Server?);
                    return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: autoDJState == null
                                ? Colors.green
                                : Colors.orange.shade900,
                            textStyle: const TextStyle(fontSize: 20)),
                        child: autoDJState == null
                            ? Text('Enable')
                            : Text('Disable'),
                        onPressed: () => {
                              setAutoDJ(autoDJState == null
                                  ? ServerManager().currentServer
                                  : null)
                            });
                  }),
              Container(
                height: 20,
              ),
              if (ServerManager().serverList.length > 1) ...[
                StreamBuilder<dynamic>(
                    stream: MediaManager().audioHandler.customState,
                    builder: (context, snapshot) {
                      final Server? autoDJState =
                          (snapshot.data?.autoDJState as Server?);
                      if (autoDJState == null) {
                        return Container();
                      }

                      return Text('Auto DJ Server: ${autoDJState.url}',
                          style: TextStyle(fontWeight: FontWeight.bold));
                    }),
                StreamBuilder<dynamic>(
                    stream: MediaManager().audioHandler.customState,
                    builder: (context, snapshot) {
                      final Server? autoDJState =
                          (snapshot.data?.autoDJState as Server?);

                      if (autoDJState == null) {
                        return Container();
                      }

                      List<DropdownMenuItem<Server>> lol = [];

                      ServerManager().serverList.forEach((value) {
                        if (value == autoDJState) {
                          return;
                        }

                        lol.add(DropdownMenuItem<Server>(
                          value: value,
                          child: Text(value.url.toString()),
                        ));
                      });

                      return DropdownButton<Server>(
                        //value: autoDJState,
                        hint: Text('Change Server'),
                        items: lol,
                        onChanged: (newValue) {
                          setAutoDJ(newValue);
                        },
                      );
                    }),
              ],
              Container(
                height: 20,
              ),
              StreamBuilder<dynamic>(
                  stream: MediaManager().audioHandler.customState,
                  builder: (context, snapshot) {
                    final Server? autoDJState =
                        (snapshot.data?.autoDJState as Server?);
                    if (autoDJState == null) {
                      return Container();
                    }

                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Min Rating',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<int>(
                            value: autoDJState.autoDJminRating,
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text('N/A'),
                              ),
                              DropdownMenuItem<int>(
                                value: 1,
                                child: Text('0.5'),
                              ),
                              DropdownMenuItem<int>(
                                value: 2,
                                child: Text('1'),
                              ),
                              DropdownMenuItem<int>(
                                value: 3,
                                child: Text('1.5'),
                              ),
                              DropdownMenuItem<int>(
                                value: 4,
                                child: Text('2'),
                              ),
                              DropdownMenuItem<int>(
                                value: 5,
                                child: Text('2.5'),
                              ),
                              DropdownMenuItem<int>(
                                value: 6,
                                child: Text('3'),
                              ),
                              DropdownMenuItem<int>(
                                value: 7,
                                child: Text('3.5'),
                              ),
                              DropdownMenuItem<int>(
                                value: 8,
                                child: Text('4'),
                              ),
                              DropdownMenuItem<int>(
                                value: 9,
                                child: Text('4.5'),
                              ),
                              DropdownMenuItem<int>(
                                value: 10,
                                child: Text('5'),
                              ),
                            ],
                            onChanged: (int? newValue) {
                              autoDJState.autoDJminRating = newValue;

                              MediaManager()
                                  .audioHandler
                                  .customAction('forceAutoDJRefresh');

                              ServerManager().callAfterEditServer();

                              print(ServerManager()
                                  .currentServer
                                  ?.autoDJminRating);
                              return;
                            },
                          )
                        ]);
                  }),
              StreamBuilder<dynamic>(
                  stream: MediaManager().audioHandler.customState,
                  builder: (context, snapshot) {
                    final Server? autoDJState =
                        (snapshot.data?.autoDJState as Server?);
                    if (autoDJState == null ||
                        autoDJState.autoDJPaths.length < 2) {
                      return Container();
                    }

                    List<Widget> lol = [
                      Container(
                        height: 20,
                      ),
                      Text('Select Folders',
                          style: TextStyle(fontWeight: FontWeight.bold))
                    ];

                    autoDJState.autoDJPaths.forEach((k, v) {
                      lol.add(ListTile(
                        leading: Switch(
                            value: v,
                            onChanged: (value) {
                              bool falseFlag = false;
                              autoDJState.autoDJPaths.forEach((key, value) {
                                if (key == k) {
                                  return;
                                }

                                if (value == true) {
                                  falseFlag = true;
                                }
                              });

                              if (falseFlag == false) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'You must have 1 folder selected')));
                                return;
                              }

                              autoDJState.autoDJPaths[k] = value;
                              MediaManager()
                                  .audioHandler
                                  .customAction('forceAutoDJRefresh');
                              ServerManager().callAfterEditServer();
                            }),
                        title: Text(k),
                      ));
                    });

                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lol);
                  }),
            ])));
  }
}
