import 'package:flutter/material.dart';
import 'package:disk_space/disk_space.dart';

import '../singletons/downloads.dart';
import '../objects/download_tracker.dart';

class DownloadScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Downloads"),
        ),
        body: Column(children: [
          Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Testing This Text',
                style: TextStyle(
                  color: Colors.blue,
                ),
              ),
              FutureBuilder(
                future: DiskSpace.getTotalDiskSpace,
                builder: (BuildContext _, AsyncSnapshot snapshot) {
                  print(snapshot.data.toString());
                  return Text(
                    snapshot.data.toString(),
                    style: TextStyle(
                      color: Colors.blue,
                    ),
                  );
                },
              )
            ],
          )),
          Expanded(
              child: SizedBox(
                  child: StreamBuilder<Map<String, DownloadTracker>>(
                      stream: DownloadManager().downloadSream,
                      builder: (context, snapshot) {
                        final List<DownloadTracker> dList = snapshot
                                .data?.entries
                                .map((e) => e.value)
                                .toList() ??
                            [];

                        return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: dList.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    Divider(height: 3, color: Colors.black),
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                title: Text(
                                  dList[index].filePath,
                                ),
                                subtitle:
                                    Text(dList[index].progress.toString()),
                              );
                            });
                      })))
        ]));
  }
}
