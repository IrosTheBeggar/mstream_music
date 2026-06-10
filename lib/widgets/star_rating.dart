import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
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
  return showDialog<void>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setLocal) {
        final l = AppLocalizations.of(dctx);
        return AlertDialog(
          backgroundColor: VelvetColors.surface,
          title: Text(l.ratingTitle,
              style: TextStyle(color: VelvetColors.textPrimary)),
          content: StarRating(
            rating: value,
            size: 38,
            onRate: (v) async {
              final prev = value;
              setLocal(() => value = v);
              onChanged(v);
              try {
                await ApiManager().rateSong(server, filepath, v);
              } catch (_) {
                setLocal(() => value = prev);
                onChanged(prev);
                if (dctx.mounted) {
                  ScaffoldMessenger.of(dctx).showSnackBar(
                      SnackBar(content: Text(l.ratingFailed)));
                }
              }
            },
          ),
          actions: [
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
