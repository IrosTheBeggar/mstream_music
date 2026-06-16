import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';

/// Name-entry dialog shared by playlist create + rename.
///
/// A StatefulWidget so the TextEditingController's lifetime is tied to the
/// dialog: it's disposed in [State.dispose], which Flutter runs only after the
/// route is fully removed (the close transition finished). Disposing it inline
/// right after `await showDialog` instead disposes it while the closing dialog's
/// autofocus TextField is still mounted, which crashes ("used after disposed").
class PlaylistNameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String? initial;

  const PlaylistNameDialog({
    super.key,
    required this.title,
    required this.action,
    this.initial,
  });

  /// Shows the dialog; resolves to the trimmed name, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String action,
    String? initial,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          PlaylistNameDialog(title: title, action: action, initial: initial),
    );
  }

  @override
  State<PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<PlaylistNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: VelvetColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: InputDecoration(hintText: l.playlistNameHint),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel,
              style: TextStyle(color: VelvetColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.action),
        ),
      ],
    );
  }
}
