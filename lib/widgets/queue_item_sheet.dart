import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/discover_badges.dart' show CopyMarker;
import '../util/image_cache.dart';
import '../util/media_format.dart';
import 'browse_keep_entry.dart';
import 'fact_badge.dart';
import 'star_rating.dart';

/// Open the options sheet for a queued song: a hold on its row, or a tap on
/// its grip.
Future<void> showQueueItemSheet(BuildContext context, QueueItemSheet sheet) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetColors.surface,
      // Scroll-controlled and scrolling inside, like the track sheet, so a
      // long action list at a large text size can never overflow it.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => sheet,
    );

/// A queued song's options: the track sheet's header — cover, title,
/// "artist · album", the format readout, the rating and what the file knows
/// (key, tempo, lyrics) — over the verbs that fit a song already in the
/// queue.
///
/// The queue says which verbs apply by handing them in: a null one is left
/// out (Play next on the song that's playing or the one already next, Keep
/// a copy… on anything but a connected server's song whose gate is open,
/// Add to playlist off the user's own server, Download once downloaded,
/// Find similar without discovery). Each runs after the sheet has closed,
/// on the queue's own context.
class QueueItemSheet extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onPlayNext;
  final VoidCallback? onKeep;

  /// The Keep a copy… row's own ask for the song's copy state.
  final Future<CopyMarker?> Function()? keepAsk;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onDownload;
  final VoidCallback? onFindSimilar;
  final VoidCallback onInfo;
  final VoidCallback onRemove;

  const QueueItemSheet({
    super.key,
    required this.item,
    required this.onInfo,
    required this.onRemove,
    this.onPlayNext,
    this.onKeep,
    this.keepAsk,
    this.onAddToPlaylist,
    this.onDownload,
    this.onFindSimilar,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = item.extras ?? const <String, dynamic>{};
    final server = ServerManager().byLocalname(e['server'] as String?);
    // A connected server's song: no rating (rate-song is off the federation
    // allowlist, and the rating would be someone else's anyway) and no
    // lyrics badge (nothing could open them) — the track sheet's rule.
    final federated = server?.isFederated == true;
    final artist = item.artist?.trim() ?? '';
    final album = item.album?.trim() ?? '';
    final byline = [
      if (artist.isNotEmpty) artist,
      if (album.isNotEmpty) album,
    ].join('  ·  ');
    final format = (e['format'] as String?)?.trim();
    final bitrate = (e['bitrate'] as num?)?.toInt();
    final sampleRate = (e['sampleRate'] as num?)?.toInt();
    final duration = item.duration;
    final spec = [
      if (format != null && format.isNotEmpty) format.toUpperCase(),
      if (bitrate != null && bitrate > 0) formatBitrate(bitrate),
      if (sampleRate != null && sampleRate > 0) formatSampleRate(sampleRate),
      if (duration != null) formatDuration(duration, padMinutes: false),
    ].join('  ·  ');
    final key = (e['musicalKey'] as String?)?.trim() ?? '';
    final bpm = (e['bpm'] as num?)?.round();
    final canRate = !federated && MediaItemRating.canRate(item);
    final lyrics = e['hasLyrics'] == true && !federated;
    // A tempo of 0 is "the scanner found no BPM", not a 0-BPM song.
    final hasTempo = bpm != null && bpm > 0;
    final badges = canRate || key.isNotEmpty || hasTempo || lyrics;
    final artUrl = e['artUrl'] as String?;

    Widget action(IconData icon, String label, VoidCallback run,
        {Color? color, Key? rowKey}) {
      return ListTile(
        key: rowKey,
        leading: Icon(icon, color: color ?? VelvetColors.textSecondary),
        title: Text(label,
            style: TextStyle(color: color ?? VelvetColors.textPrimary)),
        onTap: () {
          Navigator.of(context).pop();
          run();
        },
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: VelvetColors.border2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: artUrl != null
                                ? Image.network(artUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: artCacheSize(60),
                                    errorBuilder: (_, _, _) =>
                                        albumArtFallback(iconSize: 26))
                                : albumArtFallback(iconSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              header: true,
                              headingLevel: 1,
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: VelvetColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (byline.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  byline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: VelvetColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (spec.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  spec,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    letterSpacing: 0.2,
                                    color: VelvetColors.textTertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (badges)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (canRate) MediaItemRating(item: item, size: 16),
                          if (key.isNotEmpty) factBadge(Icons.piano, key),
                          if (hasTempo) factBadge(Icons.speed, '$bpm BPM'),
                          if (lyrics)
                            factBadge(Icons.lyrics_rounded, l.lyricsTitle),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Divider(color: VelvetColors.border, height: 1),
            if (onPlayNext != null)
              action(Icons.playlist_play, l.queuePlayNext, onPlayNext!,
                  rowKey: const ValueKey('queue-sheet-play-next')),
            // The library verb before the device verb, as in the track
            // sheet: a copy on the user's server, then Download to this phone.
            if (onKeep != null)
              KeepMenuRow(
                label: l.browseKeepOfItem(item.title),
                state: const KeepMenuState.ask(),
                ask: keepAsk,
                onTap: () {
                  Navigator.of(context).pop();
                  onKeep!();
                },
              ),
            if (onAddToPlaylist != null)
              action(Icons.playlist_add, l.trackAddToPlaylist,
                  onAddToPlaylist!,
                  rowKey: const ValueKey('queue-sheet-playlist')),
            if (onDownload != null)
              action(Icons.download_for_offline, l.download, onDownload!,
                  rowKey: const ValueKey('queue-sheet-download')),
            if (onFindSimilar != null)
              action(Icons.explore, l.discoverFindSimilar, onFindSimilar!,
                  rowKey: const ValueKey('queue-sheet-similar')),
            action(Icons.info_outline, l.info, onInfo,
                rowKey: const ValueKey('queue-sheet-info')),
            Divider(
                color: VelvetColors.border, height: 9, indent: 0, endIndent: 0),
            action(Icons.delete_outline, l.queueRemoveFromQueue, onRemove,
                color: VelvetColors.error,
                rowKey: const ValueKey('queue-sheet-remove')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
