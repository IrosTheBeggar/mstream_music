import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../singletons/sleep_timer.dart';
import '../theme/velvet_theme.dart';

class SleepTimerSheet extends StatefulWidget {
  static const _presets = <int>[15, 30, 45, 60, 90];

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  final TextEditingController _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _startMinutes(int minutes) {
    final l = AppLocalizations.of(context);
    SleepTimerManager().start(Duration(minutes: minutes));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.sleepTimerSet(minutes))),
    );
  }

  void _startCustom() {
    final raw = _customCtrl.text.trim();
    final mins = int.tryParse(raw);
    if (mins == null || mins < 1 || mins > 600) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).sleepTimerInvalid)),
      );
      return;
    }
    _startMinutes(mins);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // viewInsets.bottom = on-screen keyboard height (0 when hidden).
    // Padding here pushes the sheet's content above the keyboard so
    // the custom-time TextField stays visible while typing.
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
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
                    l.sleepTimerTitle,
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
                        ? l.sleepTimerHint
                        : l.sleepTimerPausesIn(_format(d)),
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
                children: SleepTimerSheet._presets
                    .map((m) => _PresetChip(
                          minutes: m,
                          onTap: () => _startMinutes(m),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              // Custom-minutes row. TextField + Start; Enter on the
              // soft keyboard also fires Start. Validation message
              // shown via a SnackBar so the input row stays tidy.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _startCustom(),
                      decoration: InputDecoration(
                        labelText: l.sleepTimerCustom,
                        hintText: l.sleepTimerCustomHint,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _startCustom,
                    icon: Icon(Icons.play_arrow, size: 18),
                    label: Text(l.start),
                    style: TextButton.styleFrom(
                      foregroundColor: VelvetColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              StreamBuilder<Duration?>(
                stream: SleepTimerManager().remainingStream,
                initialData: SleepTimerManager().remaining,
                builder: (context, snapshot) {
                  if (snapshot.data == null) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(Icons.close,
                          color: VelvetColors.textSecondary),
                      label: Text(
                        l.sleepTimerCancel,
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
  final VoidCallback onTap;
  const _PresetChip({required this.minutes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(AppLocalizations.of(context).sleepTimerMinutes(minutes)),
      backgroundColor: VelvetColors.surface,
      labelStyle: TextStyle(color: VelvetColors.textPrimary),
      side: BorderSide(color: VelvetColors.border),
      onPressed: onTap,
    );
  }
}
