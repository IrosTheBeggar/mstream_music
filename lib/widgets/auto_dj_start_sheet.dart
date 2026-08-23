import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../singletons/auto_dj_manager.dart';
import '../theme/velvet_theme.dart';

/// Chooser shown when Auto DJ is switched on with nothing queued: the DJ needs
/// a first track and there is none to infer one from.
///
/// Pops with the chosen [EmptyQueueStart] ([random] or [pick]), or null if
/// dismissed. Never pops [EmptyQueueStart.ask] — that value means "show this
/// sheet", so returning it would be a loop. Ticking remember persists the
/// choice, and [toggleAutoDJ] then skips straight past this next time.
class AutoDjStartSheet extends StatefulWidget {
  const AutoDjStartSheet({super.key});

  @override
  State<AutoDjStartSheet> createState() => _AutoDjStartSheetState();
}

class _AutoDjStartSheetState extends State<AutoDjStartSheet> {
  bool _remember = false;

  Future<void> _choose(EmptyQueueStart choice) async {
    // Persist BEFORE popping: the caller acts on the result immediately, and
    // on the pick path it tears this route down to reach the browser.
    if (_remember) await AutoDJManager().setEmptyQueueStart(choice);
    if (mounted) Navigator.of(context).pop(choice);
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: VelvetColors.primary),
      title: Text(title,
          style: TextStyle(
              color: VelvetColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.autoDjStartTitle,
                    style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(l.autoDjStartSubtitle,
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _option(
            icon: Icons.casino,
            title: l.autoDjStartRandom,
            subtitle: l.autoDjStartRandomSub,
            onTap: () => _choose(EmptyQueueStart.random),
          ),
          _option(
            icon: Icons.library_music_outlined,
            title: l.autoDjStartPick,
            subtitle: l.autoDjStartPickSub,
            onTap: () => _choose(EmptyQueueStart.pick),
          ),
          Divider(color: VelvetColors.border, height: 1),
          CheckboxListTile(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: VelvetColors.primary,
            title: Text(l.autoDjStartRemember,
                style: TextStyle(color: VelvetColors.textPrimary)),
            subtitle: Text(l.autoDjStartRememberSub,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
