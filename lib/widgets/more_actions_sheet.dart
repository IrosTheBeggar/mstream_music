import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/media.dart';
import '../singletons/sleep_timer.dart';
import '../theme/velvet_theme.dart';
import '../util/media_format.dart';
import 'queue_list.dart';
import 'sleep_timer_sheet.dart';

/// "More" actions bottom sheet — collects the session/secondary controls that
/// used to crowd the bottom bar (Auto DJ, sleep timer, visualizer, clear
/// queue), leaving the bar to transport + shuffle/repeat.
///
/// [parentContext] is a context ABOVE this sheet (the bottom bar's), used to
/// launch follow-on navigation / sheets after this one is dismissed — the
/// sheet's own context is gone once it's popped.
class MoreActionsSheet extends StatelessWidget {
  final BuildContext parentContext;
  const MoreActionsSheet({super.key, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Auto DJ — toggles in place; the switch reflects live state.
          StreamBuilder<dynamic>(
            stream: MediaManager().audioHandler.customState,
            builder: (context, snapshot) {
              final Server? autoDJState =
                  (snapshot.data?.autoDJState as Server?);
              final on = autoDJState != null;
              return SwitchListTile(
                secondary: Icon(Icons.album,
                    color: on
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary),
                title: Text(l.autoDjTitle,
                    style: TextStyle(color: VelvetColors.textPrimary)),
                subtitle: Text(on ? l.commonOn : l.commonOff,
                    style: TextStyle(color: VelvetColors.textSecondary)),
                value: on,
                activeThumbColor: VelvetColors.primary,
                // Shared with the queue header's DJ button (queue_list.dart).
                onChanged: (_) => toggleAutoDJ(context),
              );
            },
          ),
          // Discover is deliberately absent: the collapsible bar under the
          // queue is its home, and it sits a few pixels from this button.
          // Sleep timer — opens the timer picker.
          StreamBuilder<Duration?>(
            stream: SleepTimerManager().remainingStream,
            initialData: SleepTimerManager().remaining,
            builder: (context, snapshot) {
              final d = snapshot.data;
              final active = d != null;
              return ListTile(
                leading: Icon(active ? Icons.bedtime : Icons.bedtime_outlined,
                    color: active
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary),
                title: Text(l.sleepTimerTitle,
                    style: TextStyle(color: VelvetColors.textPrimary)),
                subtitle: Text(
                    d != null ? l.sleepTimerPausesIn(_fmt(d)) : l.commonOff,
                    style: TextStyle(color: VelvetColors.textSecondary)),
                onTap: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: parentContext,
                    backgroundColor: VelvetColors.surface,
                    isScrollControlled: true,
                    builder: (_) => SleepTimerSheet(),
                  );
                },
              );
            },
          ),
          // Visualizer is deliberately absent too: the mini player carries
          // it, one tap away without opening this sheet at all.
          // Download queue — save every downloadable track to the device.
          ListTile(
            leading: Icon(Icons.download_for_offline,
                color: VelvetColors.textSecondary),
            title: Text(l.queueDownloadAll,
                style: TextStyle(color: VelvetColors.textPrimary)),
            onTap: () {
              Navigator.of(context).pop();
              downloadQueue(parentContext);
            },
          ),
          // Clear queue.
          ListTile(
            leading: Icon(Icons.delete_sweep, color: VelvetColors.error),
            title: Text(l.mainClearQueue,
                style: TextStyle(color: VelvetColors.textPrimary)),
            onTap: () {
              Navigator.of(context).pop();
              MediaManager().audioHandler.customAction('clearPlaylist');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _fmt(Duration d) => formatDuration(d, padMinutes: false);
}
