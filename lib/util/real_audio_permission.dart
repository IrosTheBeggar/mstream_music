import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';

/// Two-step opt-in for [VisualizerAudioSource.real]: an explanation dialog
/// saying *why* a music app wants the microphone, then the OS prompt. Returns
/// true only when the user accepted both and RECORD_AUDIO is granted, so the
/// caller can leave the setting alone on a refusal.
///
/// Shared by Settings → Visualizer audio source and the first-run setup flow —
/// a consent flow that drifts between two call sites is a consent flow that
/// eventually lies in one of them.
Future<bool> confirmRealAudioPermission(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final consented = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VelvetColors.surface,
      title: Text(l.realAudioDialogTitle,
          style: TextStyle(color: VelvetColors.textPrimary)),
      content: Text(
        l.realAudioDialogBody,
        style: TextStyle(color: VelvetColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.cancel,
              style: TextStyle(color: VelvetColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.continueLabel,
              style: TextStyle(color: VelvetColors.primary)),
        ),
      ],
    ),
  );
  if (consented != true || !context.mounted) return false;

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
