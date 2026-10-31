import 'dart:async';

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
///
/// "Added {n}" runs out with nothing to notify of, so while it shows the
/// line wakes itself when the first counted song's hour is up
/// ([YtdlServerState.addedNewsEnds], on the hub's timer).
class YtdlHomeLines extends StatefulWidget {
  final YtdlServerState state;
  const YtdlHomeLines({super.key, required this.state});

  @override
  State<YtdlHomeLines> createState() => _YtdlHomeLinesState();
}

class _YtdlHomeLinesState extends State<YtdlHomeLines> {
  Timer? _expiry;
  DateTime? _expiresAt;

  @override
  void didUpdateWidget(YtdlHomeLines old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state)) _stopExpiry();
  }

  @override
  void dispose() {
    _stopExpiry();
    super.dispose();
  }

  void _stopExpiry() {
    _expiry?.cancel();
    _expiry = null;
    _expiresAt = null;
  }

  /// Wake when "Added {n}" next drops ([showsAdded]), else not at all.
  void _keepExpiry(bool showsAdded) {
    final st = widget.state;
    final at = showsAdded ? st.addedNewsEnds : null;
    if (at == null) {
      _stopExpiry();
      return;
    }
    if (at == _expiresAt && _expiry?.isActive == true) return;
    _expiry?.cancel();
    _expiresAt = at;
    // Past the hour by a moment: the summary still counts a song at
    // exactly an hour.
    final wait = at.difference(st.hub.now()) + const Duration(seconds: 1);
    _expiry = st.hub.timer(wait.isNegative ? Duration.zero : wait, () {
      _expiry = null;
      _expiresAt = null;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state.summary;
        final (String text, Color color) = s.adding > 0
            ? (l.ytdlHomeAdding(s.adding), keepInkOn(VelvetColors.card))
            : s.failed > 0
                ? (l.ytdlHomeFailed(s.failed), keepTone(VelvetColors.error))
                : s.added > 0
                    ? (l.ytdlHomeAdded(s.added), VelvetColors.textSecondary)
                    : ('', VelvetColors.textSecondary);
        _keepExpiry(s.adding == 0 && s.failed == 0 && s.added > 0);
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
