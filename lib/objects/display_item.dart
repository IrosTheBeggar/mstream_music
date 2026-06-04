import 'dart:io';

import 'package:flutter/material.dart';

import 'server.dart';
import 'metadata.dart';
import '../singletons/file_explorer.dart';
import '../theme/velvet_theme.dart';
import '../util/media_format.dart';
import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';

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

  Widget? getImage(BuildContext context) {
    String? aaFile = altAlbumArt ?? this.metadata?.albumArt ?? null;

    if (this.server != null && aaFile != null) {
      String lolUrl = Uri.encodeFull(this.server!.url +
          '/album-art/' +
          aaFile +
          '?compress=s' +
          (this.server!.jwt == null ? '' : '&token=' + this.server!.jwt!));

      // Browser-row leading thumbnail (~36dp in the dense list theme): decode
      // at that size, not the server image's full resolution.
      return Image.network(lolUrl.toString(),
          cacheWidth: artCacheWidth(context, 40));
    }

    return icon;
  }

  // Title/subtitle text widgets cap at one line with ellipsis so long
  // directory or song names don't wrap and make their row taller than
  // the others. Keeps the letter-scrub offset math (cumulative sum of
  // fixed per-row heights in browser.dart) honest.
  //
  // Font sizes were 18 (title) / 16 (subtitle), noticeably larger
  // than Material's 16/14 defaults. Dropped to 15/13 to fit more
  // characters before truncation — typical dense file-browser sizing.
  // The leading icon, horizontalTitleGap and contentPadding are also
  // tightened in browser.dart's ListView Theme override for the same
  // reason.
  //
  // [truncate] defaults to true. The folder row builders pass false
  // when the list is below the letter-strip threshold (small lists
  // don't need uniform row heights since there's no strip math to
  // honor, so long folder names get to wrap and show in full).
  Widget getText({bool truncate = true, AppLocalizations? l}) {
    if (metadata?.title != null) {
      return Text(
        (showRating == true && metadata?.rating != null
                ? '[' + (metadata!.rating! / 2).toString() + '] '
                : '') +
            metadata!.title!,
        style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
        maxLines: truncate ? 1 : null,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    if (type == 'file' || type == 'localFile') {
      return new Text(
        (showRating == true && metadata?.rating != null
                ? '[' + (metadata!.rating! / 2).toString() + '] '
                : '') +
            this.data!.split('/').last,
        style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
        maxLines: truncate ? 1 : null,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    return new Text(
      // Built-in browser nodes (execAction) and the no-server welcome
      // item (addServer) carry fixed English names; localize them.
      // Server folder/file names pass through browserChromeLabel
      // unchanged (default case), so real data is never mistranslated.
      (l != null && (type == 'execAction' || type == 'addServer'))
          ? browserChromeLabel(l, this.name)
          : this.name,
      style: TextStyle(
          fontFamily: 'Jura', fontSize: 15, color: VelvetColors.textPrimary),
      maxLines: truncate ? 1 : null,
      overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

  Widget? getSubText({AppLocalizations? l}) {
    if (metadata?.artist != null) {
      return Text(
        metadata!.artist!,
        style: TextStyle(fontSize: 13, color: VelvetColors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (subtext != null) {
      return new Text(
        (l != null && type == 'addServer')
            ? browserChromeLabel(l, subtext!)
            : subtext!,
        style: TextStyle(fontSize: 13, color: VelvetColors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return null;
  }

  // Case-insensitive substring match backing the browser's local
  // search filter. Tests the same fields getText()/getSubText() can
  // surface — title / filename / name plus artist / album / subtext —
  // so a match always corresponds to text the user can actually see.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool hit(String? s) => s != null && s.toLowerCase().contains(q);
    return hit(name) ||
        hit(metadata?.title) ||
        hit(metadata?.artist) ||
        hit(metadata?.album) ||
        hit(subtext) ||
        hit(data?.split('/').last);
  }

  // The on-device download badge is no longer probed here. Building a folder
  // of N files used to fire N independent File.exists() checks from the
  // constructor, each re-emitting the whole browser list on a hit (a burst of
  // rebuilds right as the new screen first paints). The check is now a single
  // batched pass (BrowserManager._checkDownloadStatus → recheckDownloaded) run
  // once after the list is built, emitting one coalesced refresh.
  DisplayItem(
      this.server, this.name, this.type, this.data, this.icon, this.subtext);

  // Re-evaluates whether this file exists at the server's CURRENT storage
  // location and updates [downloadProgress] (100 = present, 0 = not). Unlike
  // the constructor's one-shot check (which only ever sets 100), this also
  // CLEARS a stale badge — so after a server's download location changes, a row
  // that no longer has a local copy stops claiming it's downloaded. A row
  // that's mid-download (1–99%) is left alone. The caller refreshes the
  // browser stream once after a batch.
  Future<void> recheckDownloaded() async {
    if (type != 'file' || server == null || data == null) return;
    if (downloadProgress > 0 && downloadProgress < 100) return;
    final dir = await FileExplorer()
        .getDownloadDir(server!.storageMode, server!.storageBasePath);
    bool present = false;
    if (dir != null) {
      present =
          await File('${dir.path}/media/${server!.localname}${data!}').exists();
    }
    downloadProgress = present ? 100 : 0;
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
