import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../discovery/keep_copy_ui.dart';

/// The Add from YouTube home card's second line (spec §2), live from the
/// server's [YtdlServerState]: the first count that is not zero wins —
/// "Adding {n}" in the primary's ink, "{n} failed" in the error tone (until
/// the screen is opened), "Added {n}" in the secondary grey (until the
/// screen is opened, for at most an hour) — and otherwise nothing, so the
/// card is one line like Add torrent beside it.
class YtdlHomeLines extends StatelessWidget {
  final YtdlServerState state;
  const YtdlHomeLines({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.summary;
        final (String text, Color color) = s.adding > 0
            ? (l.ytdlHomeAdding(s.adding), keepInkOn(VelvetColors.card))
            : s.failed > 0
                ? (l.ytdlHomeFailed(s.failed), keepTone(VelvetColors.error))
                : s.added > 0
                    ? (l.ytdlHomeAdded(s.added), VelvetColors.textSecondary)
                    : ('', VelvetColors.textSecondary);
        if (text.isEmpty) return const SizedBox.shrink();
        return Text(
          text,
          key: const ValueKey('ytdl-home-lines'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: color, height: 17 / 13),
        );
      },
    );
  }
}
