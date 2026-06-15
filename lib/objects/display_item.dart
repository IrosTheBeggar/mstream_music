import 'dart:io';

import 'package:flutter/material.dart';

import 'server.dart';
import 'metadata.dart';
import '../theme/velvet_theme.dart';
import '../util/stream_url.dart';
import '../util/image_cache.dart';
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

  Widget? getImage() {
    String? aaFile = altAlbumArt ?? metadata?.albumArt;

    if (server != null && aaFile != null) {
      return Image.network(buildAlbumArtUrl(server!, aaFile));
    }

    return icon;
  }

  // A fixed-size album thumbnail for list rows. Returns the cover art
  // when present, otherwise a SAME-SIZE placeholder tile — so the row
  // title/subtitle line up whether or not an album has art. (A bare
  // Icon is far narrower than a loaded image, which knocks the text out
  // of alignment between art / no-art rows.) Mirrors getImage's
  // art-URL building (compress=s for a small thumbnail).
  Widget getAlbumThumb({double size = 48}) {
    final String? aaFile = altAlbumArt ?? metadata?.albumArt;
    final BorderRadius radius =
        BorderRadius.circular(VelvetColors.radiusSmall);
    if (server != null && aaFile != null) {
      final String url = buildAlbumArtUrl(server!, aaFile);
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: artCacheSize(size),
          errorBuilder: (_, _, _) => _albumThumbPlaceholder(size, radius),
        ),
      );
    }
    return _albumThumbPlaceholder(size, radius);
  }

  Widget _albumThumbPlaceholder(double size, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: radius,
      ),
      child: Icon(
        Icons.album,
        color: VelvetColors.textSecondary,
        size: size * 0.56,
      ),
    );
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
      final ratingPrefix = showRating == true && metadata?.rating != null
          ? '[${metadata!.rating! / 2}] '
          : '';
      return Text(
        '$ratingPrefix${metadata!.title!}',
        style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
        maxLines: truncate ? 1 : null,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    if (type == 'file' || type == 'localFile') {
      final ratingPrefix = showRating == true && metadata?.rating != null
          ? '[${metadata!.rating! / 2}] '
          : '';
      return Text(
        '$ratingPrefix${data!.split('/').last}',
        style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
        maxLines: truncate ? 1 : null,
        overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    return Text(
      // Built-in browser nodes (execAction) and the no-server welcome
      // item (addServer) carry fixed English names; localize them.
      // Server folder/file names pass through browserChromeLabel
      // unchanged (default case), so real data is never mistranslated.
      (l != null && (type == 'execAction' || type == 'addServer'))
          ? browserChromeLabel(l, name)
          : name,
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
      return Text(
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

  // Plain data constructor. The on-device "downloaded" badge is no longer
  // resolved here: this used to fire a per-item getDownloadDir() + File.exists()
  // straight from the constructor, so building a folder of N file rows kicked
  // off N disk probes AND up to N full browser re-emits (each present file
  // called BrowserManager().updateStream()). BrowserManager now resolves the
  // badge for a whole list in one batched pass — see [recheckDownloadedIn] and
  // BrowserManager._resolveDownloadBadges.
  DisplayItem(
      this.server, this.name, this.type, this.data, this.icon, this.subtext);

  // Re-evaluates whether this file exists under [dir] — the server's already-
  // resolved download base, so the full path is <dir>/media/<localname>/... —
  // and updates [downloadProgress] (100 = present, 0 = not). [dir] null means
  // the location is currently unavailable (SD card out / folder deleted) and is
  // treated as "no local copy". Also CLEARS a stale badge, so after a server's
  // download location changes a row that no longer has a copy stops claiming
  // one. A row that's mid-download (1–99%) is left alone.
  //
  // Takes a pre-resolved [dir] so a caller can resolve getDownloadDir() ONCE
  // for a whole list (it's a platform-channel / stat call) and refresh the
  // browser stream once after the batch, instead of paying that cost per row.
  // See BrowserManager._resolveDownloadBadges.
  Future<void> recheckDownloadedIn(Directory? dir) async {
    if (type != 'file' || server == null || data == null) return;
    if (downloadProgress > 0 && downloadProgress < 100) return;
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
