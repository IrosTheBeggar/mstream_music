import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../media/cast_target.dart';
import '../screens/visualizer_screen.dart';
import '../singletons/cast_manager.dart';
import '../singletons/media.dart';
import '../singletons/sleep_timer.dart';
import '../theme/velvet_theme.dart';
import '../util/media_format.dart';
import '../visualizer/shader_visualizer_screen.dart';
import 'cast_picker_sheet.dart';
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
          // Auto DJ is deliberately absent: it is a labelled button a few
          // pixels away in the queue header and again in the mini player.
          // Discover is absent for the same reason — the collapsible bar
          // under the queue is its home.
          //
          // Visualizer and cast moved DOWN here from the now-playing header.
          // They were two glyphs competing with the art and the transport for
          // a strip that is mostly about the song; here they sit with the
          // other things you do to a session rather than to a track.
          ListTile(
            leading:
                Icon(Icons.auto_awesome, color: VelvetColors.textSecondary),
            title: Text(l.visualizerTitle,
                style: TextStyle(color: VelvetColors.textPrimary)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(parentContext).push(MaterialPageRoute(
                  builder: (_) => Platform.isAndroid
                      ? VisualizerScreen()
                      : const ShaderVisualizerScreen()));
            },
          ),
          StreamBuilder<CastTarget>(
            stream: CastManager().activeTargetStream,
            initialData: CastManager().activeTarget,
            builder: (context, snap) {
              final casting = !(snap.data ?? CastTarget.local).isLocal;
              return ListTile(
                leading: Icon(casting ? Icons.cast_connected : Icons.cast,
                    color: casting
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary),
                title: Text(l.castPlayOnTooltip,
                    style: TextStyle(color: VelvetColors.textPrimary)),
                subtitle: casting
                    ? Text(snap.data!.name,
                        style: TextStyle(color: VelvetColors.textSecondary))
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: parentContext,
                    backgroundColor: VelvetColors.surface,
                    isScrollControlled: true,
                    builder: (_) => CastPickerSheet(),
                  );
                },
              );
            },
          ),
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
