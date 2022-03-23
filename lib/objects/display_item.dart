import 'dart:io';

import 'package:flutter/material.dart';

import 'server.dart';
import 'metadata.dart';
import '../singletons/browser_list.dart';
import '../singletons/file_explorer.dart';

class DisplayItem {
  final Server? server;
  final String type;
  final String? data;

  bool showRating = false;

  Icon? icon;
  String name;
  MusicMetadata? metadata;
  String? altAlbumArt;
  String? subtext;

  int downloadProgress = 0;

  Widget? getImage() {
    String? aaFile = altAlbumArt ?? this.metadata?.albumArt ?? null;

    if (this.server != null && aaFile != null) {
      String lolUrl = Uri.encodeFull(this.server!.url +
          '/album-art/' +
          aaFile +
          '?compress=s' +
          (this.server!.jwt == null ? '' : '&token=' + this.server!.jwt!));

      return Image.network(lolUrl.toString());
    }

    return icon;
  }

  Widget getText() {
    if (metadata?.title != null) {
      return Text(
        (showRating == true && metadata?.rating != null
                ? '[' + (metadata!.rating! / 2).toString() + '] '
                : '') +
            metadata!.title!,
        style: TextStyle(color: Colors.black),
      );
    }

    if (type == 'file' || type == 'localFile') {
      return new Text(
          (showRating == true && metadata?.rating != null
                  ? '[' + (metadata!.rating! / 2).toString() + '] '
                  : '') +
              this.data!.split('/').last,
          style: TextStyle(fontSize: 18, color: Colors.black));
    }

    return new Text(this.name,
        style:
            TextStyle(fontFamily: 'Jura', fontSize: 18, color: Colors.black));
  }

  Widget? getSubText() {
    if (metadata?.artist != null) {
      return Text(
        metadata!.artist!,
        style: TextStyle(fontSize: 16, color: Colors.black),
      );
    }

    if (subtext != null) {
      return new Text(
        subtext!,
        style: TextStyle(fontSize: 16, color: Colors.black),
      );
    }

    return null;
  }

  DisplayItem(
      this.server, this.name, this.type, this.data, this.icon, this.subtext) {
    // Check if file is saved on device
    if (this.type == 'file') {
      String downloadDirectory = this.server!.localname + this.data!;
      FileExplorer().getDownloadDir(this.server!.saveToSdCard).then((dir) {
        if (dir == null) {
          return;
        }
        String finalString = '${dir.path}/media/$downloadDirectory';

        new File(finalString).exists().then((ex) {
          if (ex == true) {
            this.downloadProgress = 100;
            BrowserManager().updateStream();
          }
        });
      });
    }
  }

  // DisplayItem.fromJson(Map<String, dynamic> json)
  //     : name = json['name'],
  //       type = json['type'],
  //       server = json['server'],
  //       subtext = json['subtext'],
  //       data = json['data'];

  // Map<String, dynamic> toJson() => {
  //       'name': name,
  //       'server': server,
  //       'type': type,
  //       'subtext': subtext,
  //       'data': data
  //     };
}
