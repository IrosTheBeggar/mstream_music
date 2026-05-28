import 'package:flutter/material.dart';
// import 'package:disk_space/disk_space.dart';

import '../l10n/app_localizations.dart';
import '../singletons/downloads.dart';
import '../objects/download_tracker.dart';
import '../theme/velvet_theme.dart';

class DownloadScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(l.downloadsTitle),
        ),
        body: SafeArea(top: false, child: Column(children: [
          // Card(
          //     child: Column(
          //   mainAxisSize: MainAxisSize.min,
          //   children: [
          //     Text(
          //       'Total Storage Space (in MiB)',
          //       style: TextStyle(
          //         color: Colors.blue,
          //       ),
          //     ),
          //     FutureBuilder(
          //       future: DiskSpace.getTotalDiskSpace,
          //       builder: (BuildContext _, AsyncSnapshot snapshot) {
          //         print(snapshot.data.toString());
          //         return Text(
          //           snapshot.data.toString(),
          //           style: TextStyle(
          //             color: Colors.blue,
          //           ),
          //         );
          //       },
          //     )
          //   ],
          // )),
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
                                    Divider(height: 3, color: VelvetColors.textPrimary),
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                title: Text(
                                  dList[index].filePath,
                                  style: TextStyle(
                                    color: VelvetColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  l.downloadProgress(
                                      (dList[index].progress * 100)
                                          .toStringAsFixed(0)),
                                  style: TextStyle(
                                    color: VelvetColors.textPrimary,
                                  ),
                                ),
                              );
                            });
                      })))
        ])));
  }
}
