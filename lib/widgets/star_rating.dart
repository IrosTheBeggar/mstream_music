import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';

/// Renders an mStream song rating (0–10 on the wire) as up to 5 stars
/// (`rating / 2`). Read-only by default; pass [onRate] to make it interactive.
///
/// Input granularity follows Settings → "Half-star ratings":
///   • whole stars (default): a tap sets that star (2·i+2 on the 0–10 scale);
///   • half stars (opt-in): a long-press sets the half value (2·i+1).
/// Tapping the star that already represents the current rating clears it (→ null).
/// The *display* always renders halves (`star_half`) so a half rating set on the
/// web client still shows correctly regardless of the input setting.
class StarRating extends StatelessWidget {
  /// Current rating on the server's 0–10 scale; null or 0 = unrated.
  final int? rating;
  final double size;

  /// When non-null the widget is interactive and calls this with the new
  /// 0–10 value (or null to clear).
  final ValueChanged<int?>? onRate;

  const StarRating({super.key, this.rating, this.size = 20, this.onRate});

  @override
  Widget build(BuildContext context) {
    final int value = (rating ?? 0).clamp(0, 10);
    final bool allowHalf = SettingsManager().ratingAllowHalf;
    final bool interactive = onRate != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final int fullVal = 2 * i + 2; // this star fully lit
        final int halfVal = 2 * i + 1; // this star half lit
        final IconData icon = value >= fullVal
            ? Icons.star
            : (value >= halfVal ? Icons.star_half : Icons.star_border);
        final Widget star = Icon(
          icon,
          size: size,
          color: value >= halfVal
              ? VelvetColors.primary
              : VelvetColors.textSecondary,
        );
        if (!interactive) return star;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Whole-star tap; tapping the current top star clears the rating.
          onTap: () => onRate!(value == fullVal ? null : fullVal),
          // Half-star only when the user opted in.
          onLongPress: allowHalf
              ? () => onRate!(value == halfVal ? null : halfVal)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: star,
          ),
        );
      }),
    );
  }
}

/// Opens a small dialog to rate a single track. Each tap optimistically applies
/// via [onChanged] and POSTs to the track's [server] (so a mixed-server queue
/// rates each track on its own server); on failure it reverts and toasts.
/// [filepath] is the track's data path (a leading slash is tolerated — rateSong
/// strips it).
Future<void> showRatingDialog(
  BuildContext context, {
  required Server server,
  required String filepath,
  required int? current,
  required ValueChanged<int?> onChanged,
}) {
  int? value = current;
  // Monotonic token: each tap claims the next number. On a failed POST we revert
  // only if our tap is still the latest — a tap that lands while we were waiting
  // wins, so rapid taps never clobber each other with a stale revert.
  int seq = 0;
  return showDialog<void>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setLocal) {
        final l = AppLocalizations.of(dctx);
        // Optimistically apply [v] to the UI, queue and server; on a server
        // rejection revert to the pre-tap value, but only when no newer tap has
        // since superseded this one.
        Future<void> apply(int? v) async {
          final mySeq = ++seq;
          final prev = value;
          setLocal(() => value = v);
          onChanged(v);
          // Keep the queue + now-playing item's extras in sync, so Song Info and
          // a restart both reflect the rating (rateSong is the server-side
          // write). Pass the server so a mixed-server queue patches only this
          // track, never a same-path track on a different server.
          MediaManager().audioHandler.customAction('updateRating',
              {'filepath': filepath, 'rating': v, 'server': server.localname});
          try {
            await ApiManager().rateSong(server, filepath, v);
          } catch (_) {
            if (mySeq != seq) return; // a newer tap won — don't revert to stale
            onChanged(prev);
            MediaManager().audioHandler.customAction('updateRating', {
              'filepath': filepath,
              'rating': prev,
              'server': server.localname,
            });
            if (dctx.mounted) {
              setLocal(() => value = prev);
              ScaffoldMessenger.of(dctx).showSnackBar(
                  SnackBar(content: Text(l.ratingFailed)));
            }
          }
        }

        return AlertDialog(
          backgroundColor: VelvetColors.surface,
          title: Text(l.ratingTitle,
              style: TextStyle(color: VelvetColors.textPrimary)),
          content: StarRating(rating: value, size: 38, onRate: apply),
          actions: [
            // Whole-star input can't clear an odd (half) rating by tapping — no
            // whole star equals it — so a dedicated Clear is the only way out of
            // one. Shown whenever a rating is set.
            if (value != null && value! > 0)
              TextButton(
                onPressed: () => apply(null),
                child: Text(l.clear),
              ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: Text(MaterialLocalizations.of(dctx).closeButtonLabel),
            ),
          ],
        );
      },
    ),
  );
}

/// Compact, tappable rating indicator used inline wherever a track can be rated:
/// small stars when rated, a single outline star when not — always shown, so an
/// unrated track is one tap from the rating form (opened via [showRatingDialog]).
/// Pure UI: the host supplies the track's [server] + [filepath] and an
/// [onChanged] to persist the new value and refresh its own view.
class RatingControl extends StatelessWidget {
  final int? rating;
  final Server server;
  final String filepath;
  final ValueChanged<int?> onChanged;
  final double size;

  const RatingControl({
    super.key,
    required this.rating,
    required this.server,
    required this.filepath,
    required this.onChanged,
    this.size = 12,
  });

  // 0–10 server scale → a compact 0–5 label: "5", "3.5", "3".
  static String _half(int v) {
    final s = v / 2.0;
    return s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    // Clamp to the 0–10 wire range so out-of-range data can't render "5.5".
    final v = (rating ?? 0).clamp(0, 10);
    final rated = v > 0;
    return InkWell(
      onTap: () => showRatingDialog(context,
          server: server,
          filepath: filepath,
          current: rating,
          onChanged: onChanged),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(2),
        // Compact readout to save horizontal room: the value out of 5 + a star
        // ("3.5★") when rated, a single outline star otherwise (still a
        // tap-to-rate affordance). The full 5-star input lives in the dialog.
        child: rated
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _half(v),
                    style: TextStyle(
                      fontSize: size + 1,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: VelvetColors.primary,
                    ),
                  ),
                  Icon(Icons.star, size: size + 1, color: VelvetColors.primary),
                ],
              )
            : Icon(Icons.star_border,
                size: size + 4, color: VelvetColors.textTertiary),
      ),
    );
  }
}

/// [RatingControl] for a now-playing / Song-Info [MediaItem]: seeds the rating
/// from `extras['rating']`, updates it locally on a rate (so the star reflects
/// immediately without re-enqueuing the track), resets when the track changes,
/// and resolves the track's server from `extras['server']`. Renders nothing for
/// an item with no resolvable server/path (e.g. a local file).
class MediaItemRating extends StatefulWidget {
  final MediaItem item;
  final double size;
  const MediaItemRating({super.key, required this.item, this.size = 14});

  /// Whether [item] can be rated — it carries a resolvable source server and a
  /// file path (false for a local file). Lets a host drop the widget entirely
  /// instead of laying out an invisible [SizedBox]; [build] applies the same
  /// test and renders nothing when it fails.
  static bool canRate(MediaItem item) =>
      ServerManager().byLocalname(item.extras?['server'] as String?) != null &&
      item.extras?['path'] != null;

  @override
  State<MediaItemRating> createState() => _MediaItemRatingState();
}

class _MediaItemRatingState extends State<MediaItemRating> {
  int? _rating;

  @override
  void initState() {
    super.initState();
    _rating = (widget.item.extras?['rating'] as num?)?.toInt();
  }

  @override
  void didUpdateWidget(MediaItemRating old) {
    super.didUpdateWidget(old);
    // Re-seed when the track changes OR its rating did — e.g. it was rated from
    // the album/browser while playing, and updateRating re-emitted the item
    // with new extras under the same id.
    final newRating = (widget.item.extras?['rating'] as num?)?.toInt();
    if (old.item.id != widget.item.id ||
        (old.item.extras?['rating'] as num?)?.toInt() != newRating) {
      _rating = newRating;
    }
  }

  @override
  Widget build(BuildContext context) {
    final server =
        ServerManager().byLocalname(widget.item.extras?['server'] as String?);
    final path = widget.item.extras?['path'] as String?;
    if (server == null || path == null) return const SizedBox.shrink();
    return RatingControl(
      rating: _rating,
      server: server,
      filepath: path,
      size: widget.size,
      onChanged: (r) {
        if (mounted) setState(() => _rating = r);
      },
    );
  }
}
