import 'package:flutter/material.dart';

import '../singletons/sleep_timer.dart';
import '../theme/velvet_theme.dart';

class SleepTimerSheet extends StatelessWidget {
  static const _presets = <int>[15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime, color: VelvetColors.primary),
                const SizedBox(width: 10),
                Text(
                  'Sleep timer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            StreamBuilder<Duration?>(
              stream: SleepTimerManager().remainingStream,
              initialData: SleepTimerManager().remaining,
              builder: (context, snapshot) {
                final d = snapshot.data;
                return Text(
                  d == null
                      ? 'Pick a duration to pause playback after.'
                      : 'Pauses in ${_format(d)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: VelvetColors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets
                  .map((m) => _PresetChip(minutes: m))
                  .toList(),
            ),
            const SizedBox(height: 12),
            StreamBuilder<Duration?>(
              stream: SleepTimerManager().remainingStream,
              initialData: SleepTimerManager().remaining,
              builder: (context, snapshot) {
                if (snapshot.data == null) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(Icons.close, color: VelvetColors.textSecondary),
                    label: Text(
                      'Cancel timer',
                      style: TextStyle(color: VelvetColors.textSecondary),
                    ),
                    onPressed: () {
                      SleepTimerManager().cancel();
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _PresetChip extends StatelessWidget {
  final int minutes;
  const _PresetChip({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text('$minutes min'),
      backgroundColor: VelvetColors.surface,
      labelStyle: TextStyle(color: VelvetColors.textPrimary),
      side: BorderSide(color: VelvetColors.border),
      onPressed: () {
        SleepTimerManager().start(Duration(minutes: minutes));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep timer set for $minutes minutes')),
        );
      },
    );
  }
}
