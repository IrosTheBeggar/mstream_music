import 'package:flutter/material.dart';
import '../singletons/browser_list.dart';
import '../objects/display_item.dart';

import 'add_server.dart';

class Browser extends StatelessWidget {
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
              // TODO: fix bug where list doesn;t rerender after first server is added
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
                                                      if (browserList[index]
                                                              .type ==
                                                          'addServer') {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  AddServerScreen()),
                                                        );
                                                        return;
                                                      }
                                                    }))
                                          ])))));
                        });
                  })))
    ]);
  }
}
