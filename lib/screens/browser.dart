import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../objects/display_item.dart';
import 'package:uuid/uuid.dart';

import '../singletons/lol.dart';

import 'add_server.dart';

class Browser extends StatelessWidget {
  void handleTap(
      List<DisplayItem> browserList, int index, BuildContext context) {
    if (browserList[index].type == 'addServer') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddServerScreen()),
      );
      return;
    }

    if (browserList[index].type == 'directory') {
      ApiManager().getFileList(browserList[index].data,
          useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'fileExplorer') {
      ApiManager().getFileList("~", useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'file') {
      // TODO: Add a unique GET param to avoid duplicate IDs
      String lolUrl = Uri.encodeFull(browserList[index].server!.url +
          '/media' +
          browserList[index].data +
          '?app_uuid=' +
          Uuid().v4() +
          (browserList[index].server!.jwt == null
              ? ''
              : '&token=' + browserList[index].server!.jwt!));

      MediaItem lol = new MediaItem(id: lolUrl, title: browserList[index].name);
      LolManager().audioHandler.addQueueItem(lol);
    }
  }

  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Material(
          color: Color(0xFFffffff),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                    icon: Icon(Icons.keyboard_arrow_left, color: Colors.black),
                    tooltip: 'Go Back',
                    onPressed: () {}),
              ])),
      Expanded(
          child: SizedBox(
              child: StreamBuilder<List<DisplayItem>>(
                  stream: BrowserManager().browserListStream,
                  builder: (context, snapshot) {
                    print(BrowserManager().browserList);
                    final List<DisplayItem> browserList = snapshot.data ?? [];
                    return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        separatorBuilder: (BuildContext context, int index) =>
                            Divider(height: 3, color: Colors.white),
                        itemCount: BrowserManager().browserList.length,
                        itemBuilder: (BuildContext context, int index) {
                          // Fixes an odd rendering bug when going between tabs
                          if (browserList.length == 0) {
                            return Container();
                          }

                          return Container(
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Color(0xFFbdbdbd)))),
                              child: Material(
                                  color: Color(0xFFe1e2e1),
                                  child: InkWell(
                                      splashColor: Colors.blue,
                                      child: IntrinsicHeight(
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: <Widget>[
                                            Container(
                                              width: 4,
                                              child: RotatedBox(
                                                quarterTurns: 3,
                                                child: LinearProgressIndicator(
                                                  // value: displayList[index].downloadProgress/100,
                                                  value: 0,
                                                  valueColor:
                                                      new AlwaysStoppedAnimation(
                                                          Colors.blue),
                                                  backgroundColor: Colors.white
                                                      .withOpacity(0),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                                child: ListTile(
                                                    leading: browserList[index]
                                                            .icon ??
                                                        null,
                                                    title: browserList[index]
                                                        .getText(),
                                                    subtitle: browserList[index]
                                                        .getSubText(),
                                                    onTap: () {
                                                      handleTap(browserList,
                                                          index, context);
                                                    }))
                                          ])))));
                        });
                  })))
    ]);
  }
}
