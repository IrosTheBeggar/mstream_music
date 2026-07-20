import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../screens/discover_screen.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import 'player_panel.dart';

/// Track context sheet, opened by long-pressing a browser row. Long-press on
/// a list row conventionally opens the item's context menu (Apple Music,
/// Spotify, Symfonium all do exactly this), so this sheet carries the same
/// queue actions the album-detail dropdown offers — the browser's first
/// per-track actions — plus Find similar when the track's server supports
/// discovery.
///
/// [parentContext] is a context ABOVE this sheet (the browser's), used for
/// follow-on navigation and snackbars after the sheet is popped — the
/// sheet's own context is gone once it closes.
class TrackActionsSheet extends StatelessWidget {
  final DisplayItem item;
  final BuildContext parentContext;
  const TrackActionsSheet(
      {super.key, required this.item, required this.parentContext});

  // Floating so it clears the docked mini-player overlay (a plain bottom
  // snackbar renders behind it) — same fix as the browser's other toasts.
  void _queuedToast() {
    final l = AppLocalizations.of(parentContext);
    ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
      content: Text(l.browserSongsAdded(1)),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: PlayerPanel.kCollapsedHeight +
            MediaQuery.of(parentContext).viewPadding.bottom +
            8,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title =
        item.metadata?.title ?? (item.data ?? item.name).split('/').last;
    final artist = item.metadata?.artist;
    // Find similar needs a SERVER path as the seed (a downloaded copy's
    // local path can't address the similarity index) and a server that
    // advertised discovery on ping.
    final canFindSimilar = item.type == 'file' &&
        item.server?.discoveryAvailable == true &&
        item.data != null;

    Widget action(IconData icon, String label, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: VelvetColors.textSecondary),
        title: Text(label, style: TextStyle(color: VelvetColors.textPrimary)),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track header, so the sheet self-identifies (matches the
          // streaming apps' long-press sheets).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (artist != null && artist.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          action(Icons.playlist_play, l.queueAddNext, () async {
            if (await addNext(item) != null) _queuedToast();
          }),
          action(Icons.play_arrow, l.queuePlayNow, () => playNow(item)),
          // Redundant when the row tap already appends (addToQueue /
          // appendAndJump tap behaviors) — same rule as the album-detail
          // dropdown.
          if (SettingsManager().tapBehavior == TapBehavior.playFromHere)
            action(Icons.queue_music, l.queueAddToEnd, () async {
              await addToQueueEnd(item);
              _queuedToast();
            }),
          if (canFindSimilar)
            action(Icons.explore, l.discoverFindSimilar, () {
              Navigator.of(parentContext).push(MaterialPageRoute(
                builder: (_) => DiscoverScreen(
                  seedServer: item.server,
                  seedPath: item.data,
                  seedTitle: title,
                  seedArtist: artist,
                ),
              ));
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
