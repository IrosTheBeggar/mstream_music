import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';

/// How the user answered [askForRealAudio].
class RealAudioAnswer {
  /// Which button: "Use real audio" (true) or "Use synthesized data".
  final bool wantsReal;

  /// True only when they chose real audio AND RECORD_AUDIO is now granted.
  final bool granted;

  /// Whether "Don't ask again" was ticked — always false unless the dialog
  /// offered it.
  final bool dontAskAgain;

  const RealAudioAnswer({
    required this.wantsReal,
    required this.granted,
    required this.dontAskAgain,
  });
}

/// Two-step opt-in for [VisualizerAudioSource.real]: an explanation dialog
/// saying *why* a music app wants the microphone, then — on "Use real audio" —
/// the OS prompt. Null when the dialog is dismissed (scrim or Back) instead of
/// answered with either button.
///
/// [offerDontAskAgain] adds the "Don't ask again" checkbox, for the prompt
/// that meets a visualizer opened without the permission. Settings leaves it
/// off: there the user picked real audio themselves, so nothing is nagging.
///
/// Shared by Settings → Visualizer audio source and the visualizer launcher —
/// a consent flow that drifts between two call sites is a consent flow that
/// eventually lies in one of them.
Future<RealAudioAnswer?> askForRealAudio(BuildContext context,
    {bool offerDontAskAgain = false}) async {
  final l = AppLocalizations.of(context);
  var dontAskAgain = false;
  final useReal = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VelvetColors.surface,
      // Three blocks of copy plus a checkbox: let a large text scale scroll
      // rather than overflow.
      scrollable: true,
      title: Text(l.realAudioDialogTitle,
          style: TextStyle(color: VelvetColors.textPrimary)),
      content: StatefulBuilder(
        builder: (ctx, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Two spans rather than one string: the reassurance is bold, and
            // the split has to survive translation — a substring match for
            // "the last sentence" would break the moment a locale punctuates
            // differently.
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l.realAudioDialogBody} '),
                TextSpan(
                  text: l.realAudioNoMic,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ]),
              style: TextStyle(color: VelvetColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(l.realAudioSynthesizedNote,
                style: TextStyle(color: VelvetColors.textSecondary)),
            if (offerDontAskAgain) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                activeColor: VelvetColors.primary,
                value: dontAskAgain,
                onChanged: (v) =>
                    setDialogState(() => dontAskAgain = v ?? false),
                title: Text(l.realAudioDontAskAgain,
                    style: TextStyle(color: VelvetColors.textPrimary)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.realAudioUseSynthesized,
              style: TextStyle(color: VelvetColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.realAudioUseReal,
              style: TextStyle(color: VelvetColors.primary)),
        ),
      ],
    ),
  );
  if (useReal == null || !context.mounted) return null;

  final granted = useReal && await _requestMicrophone(context, l);
  return RealAudioAnswer(
      wantsReal: useReal, granted: granted, dontAskAgain: dontAskAgain);
}

/// Settings' entry point: true only when the user accepted both steps, so the
/// caller can leave the setting alone on a refusal.
Future<bool> confirmRealAudioPermission(BuildContext context) async =>
    (await askForRealAudio(context))?.granted ?? false;

/// The OS prompt, plus a snackbar saying so when it comes back refused. A
/// permanent refusal returns at once with no prompt at all, so that snackbar
/// carries the way to system settings.
Future<bool> _requestMicrophone(
    BuildContext context, AppLocalizations l) async {
  final status = await Permission.microphone.request();
  if (status.isGranted) return true;

  if (context.mounted) {
    final permanentlyDenied = status.isPermanentlyDenied;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(permanentlyDenied
            ? l.realAudioPermPermanentlyDenied
            : l.realAudioPermDenied),
        action: permanentlyDenied
            ? SnackBarAction(
                label: l.openSettings,
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
  }
  return false;
}
