import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/play_event.dart';
import '../screens/auto_dj_sheets.dart' show AutoDjSheet;
import '../singletons/auto_dj_manager.dart';
import '../singletons/log_manager.dart';
import '../theme/velvet_theme.dart';
import 'auto_dj_recent_menu.dart';
import 'federation_widgets.dart';

/// What [AutoDjStartSheet] hands back: how to start — and, for
/// [EmptyQueueStart.recent], the song to start from.
typedef AutoDjStartChoice = ({EmptyQueueStart how, TrackFacts? song});

/// Chooser shown when Auto DJ is switched on with nothing queued and First
/// song is Ask (or Recently played): the DJ needs a first track and there is
/// none to infer one from. The Auto DJ screen's sheet chrome, with the First
/// song row's words.
///
/// Pops with the choice, or null if dismissed. Never pops
/// [EmptyQueueStart.ask] — that value means "show this sheet", so returning
/// it would be a loop. Ticking Remember stores the way chosen as First song,
/// and [toggleAutoDJ] then skips straight past this next time — except for
/// Recently played, which always asks which song.
class AutoDjStartSheet extends StatefulWidget {
  const AutoDjStartSheet(
      {super.key, this.recent = const [], this.openRecent = false});

  /// The songs Recently played offers (recentlyPlayedOn); none leaves the
  /// option out — there would be nothing to choose.
  final List<TrackFacts> recent;

  /// First song is Recently played: open its dropdown straight away.
  final bool openRecent;

  @override
  State<AutoDjStartSheet> createState() => _AutoDjStartSheetState();
}

class _AutoDjStartSheetState extends State<AutoDjStartSheet> {
  bool _remember = false;

  Future<void> _choose(EmptyQueueStart how, [TrackFacts? song]) async {
    // Persist BEFORE popping: the caller acts on the result immediately, and
    // on the pick path it tears this route down to reach the browser. Popped
    // even when saving fails — the choice still stands for this start.
    try {
      if (_remember) await AutoDJManager().setEmptyQueueStart(how);
    } catch (e) {
      appLog('[dj] saving First song failed: $e');
    } finally {
      // This sheet's own route, once: a second tap during the save must not
      // pop what is underneath.
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop<AutoDjStartChoice>((how: how, song: song));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AutoDjSheet(
      title: l.autoDjFirstSong,
      child: FedCard(children: [
        FedRow(
          key: const ValueKey('auto-dj-start-random'),
          icon: Icons.casino,
          title: l.autoDjFirstSongRandom,
          onTap: () => _choose(EmptyQueueStart.random),
        ),
        FedRow(
          key: const ValueKey('auto-dj-start-choose'),
          icon: Icons.library_music_outlined,
          title: l.autoDjFirstSongChoose,
          onTap: () => _choose(EmptyQueueStart.pick),
        ),
        if (widget.recent.isNotEmpty)
          RecentlyPlayedMenu(
            songs: widget.recent,
            openAtStart: widget.openRecent,
            onPicked: (song) => _choose(EmptyQueueStart.recent, song),
            builder: (context, open) => FedRow(
              key: const ValueKey('auto-dj-start-recent'),
              icon: Icons.history,
              title: l.autoDjRecentlyPlayed,
              trailing:
                  Icon(Icons.arrow_drop_down, color: VelvetColors.textSecondary),
              onTap: open,
            ),
          ),
        FedCheckRow(
          key: const ValueKey('auto-dj-start-remember'),
          label: l.autoDjRemember,
          value: _remember,
          onChanged: (v) => setState(() => _remember = v),
        ),
      ]),
    );
  }
}
