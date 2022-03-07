import 'package:flutter/material.dart';
import 'package:mstream_music/objects/server.dart';
import '../singletons/server_list.dart';
import '../singletons/media.dart';

class AutoDJScreen extends StatelessWidget {
  setAutoDJ(Server? server) {
    if (ServerManager().currentServer == null) {
      return;
    }

    MediaManager().audioHandler.customAction('setAutoDJ', {
      'serverURL': server?.url.toString() ??
          ServerManager().currentServer!.url.toString(),
      'token': server?.jwt ?? ServerManager().currentServer!.jwt,
      'autoDJMinRating': server?.autoDJminRating ??
          ServerManager().currentServer!.autoDJminRating
    });
  }

  setAutoDJMinRating(int? rating) {
    if (ServerManager().currentServer == null) {
      return;
    }

    MediaManager().audioHandler.customAction('setAutoDJMinRating', {
      'autoDJMinRating': rating,
    });
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
              if (ServerManager().serverList.length == 1) ...[
                StreamBuilder<dynamic>(
                    stream: MediaManager().audioHandler.customState,
                    builder: (context, snapshot) {
                      final String? autoDJState =
                          (snapshot.data?.autoDJState as String?);
                      return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              primary: autoDJState == null
                                  ? Colors.green
                                  : Colors.orange.shade900,
                              textStyle: const TextStyle(fontSize: 20)),
                          child: autoDJState == null
                              ? Text('Enable')
                              : Text('Disable'),
                          onPressed: () => {setAutoDJ(null)});
                    }),
              ] else if (ServerManager().serverList.length > 1) ...[
                StreamBuilder<dynamic>(
                    stream: MediaManager().audioHandler.customState,
                    builder: (context, snapshot) {
                      final String? autoDJState =
                          (snapshot.data?.autoDJState as String?);
                      if (autoDJState == null) {
                        return Text('Auto DJ Disabled');
                      }

                      return Text('Auto DJ Server: $autoDJState',
                          style: TextStyle(fontWeight: FontWeight.bold));
                    }),
                StreamBuilder<dynamic>(
                    stream: MediaManager().audioHandler.customState,
                    builder: (context, snapshot) {
                      final String? autoDJState =
                          (snapshot.data?.autoDJState as String?);

                      List<DropdownMenuItem<Server>> lol = [];

                      Server? disableFlag;
                      ServerManager().serverList.forEach((value) {
                        if (value.url.toString() == autoDJState) {
                          disableFlag = value;
                          return;
                        }

                        lol.add(DropdownMenuItem<Server>(
                          value: value,
                          child: Text(value.url.toString()),
                        ));
                      });

                      if (disableFlag != null) {
                        lol.add(DropdownMenuItem<Server>(
                          value: disableFlag,
                          child: Text('Disable Auto DJ'),
                        ));
                      }

                      return DropdownButton<Server>(
                        //value: autoDJState,
                        hint: Text('Choose Server'),
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
              // Text('Min Rating', style: TextStyle(fontWeight: FontWeight.bold)),
              // if (ServerManager().serverList.length == 1) ...[
              //   // show license
              //   DropdownButton<int>(
              //     value: ServerManager().currentServer?.autoDJminRating,
              //     items: [
              //       DropdownMenuItem<int>(
              //         value: null,
              //         child: Text('N/A'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 1,
              //         child: Text('0.5'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 2,
              //         child: Text('1'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 3,
              //         child: Text('1.5'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 4,
              //         child: Text('2'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 5,
              //         child: Text('2.5'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 6,
              //         child: Text('3'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 7,
              //         child: Text('3.5'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 8,
              //         child: Text('4'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 9,
              //         child: Text('4.5'),
              //       ),
              //       DropdownMenuItem<int>(
              //         value: 10,
              //         child: Text('5'),
              //       ),
              //     ],
              //     onChanged: (int? newValue) {
              //       ServerManager().currentServer!.autoDJminRating = newValue;
              //       ServerManager().callAfterEditServer();

              //       return;
              //     },
              //   )
              // ] else if (ServerManager().serverList.length > 1)
              //   ...[]
            ])));
  }
}
