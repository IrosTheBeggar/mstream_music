import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../theme/velvet_theme.dart';

/// Dedicated page for transcoding configuration, reached from the drawer.
///
/// Currently hosts the single transcode on/off control (moved out of the
/// general Settings page so transcoding has its own home and room to grow).
class TranscodeScreen extends StatefulWidget {
  @override
  State<TranscodeScreen> createState() => _TranscodeScreenState();
}

class _TranscodeScreenState extends State<TranscodeScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.transcodeTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            SwitchListTile(
              secondary:
                  Icon(Icons.transform, color: VelvetColors.textSecondary),
              title: Text(l.settingsTranscode),
              subtitle: Text(
                l.settingsTranscodeSubtitle,
                style:
                    TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
              ),
              value: TranscodeManager().transcodeOn,
              onChanged: (v) async {
                await SettingsManager().setTranscode(v);
                if (mounted) setState(() {});
              },
              activeThumbColor: VelvetColors.primary,
            ),
            Divider(height: 1, color: VelvetColors.border),
          ],
        ),
      ),
    );
  }
}
