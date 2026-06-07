import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../theme/velvet_theme.dart';

/// Dedicated page for transcoding configuration, reached from the drawer.
///
/// Hosts the transcode on/off control plus the per-request codec / bitrate the
/// app sends to the mStream `/transcode` endpoint. "Server default" (null) omits
/// the param so the server uses its own configured default. The dropdowns are
/// disabled while transcoding is off.
class TranscodeScreen extends StatefulWidget {
  @override
  State<TranscodeScreen> createState() => _TranscodeScreenState();
}

class _TranscodeScreenState extends State<TranscodeScreen> {
  // Codec tokens are lowercase on the wire; show them with conventional casing.
  String _codecLabel(String codec) {
    switch (codec) {
      case 'mp3':
        return 'MP3';
      case 'opus':
        return 'Opus';
      case 'aac':
        return 'AAC';
    }
    return codec;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tm = TranscodeManager();
    final bool on = tm.transcodeOn;
    final Color labelColor =
        on ? VelvetColors.textPrimary : VelvetColors.textSecondary;

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
              value: on,
              onChanged: (v) async {
                await SettingsManager().setTranscode(v);
                if (mounted) setState(() {});
              },
              activeThumbColor: VelvetColors.primary,
            ),
            Divider(height: 1, color: VelvetColors.border),
            ListTile(
              enabled: on,
              title: Text(l.transcodeCodec, style: TextStyle(color: labelColor)),
              trailing: DropdownButton<String?>(
                value: tm.codec,
                underline: const SizedBox.shrink(),
                dropdownColor: VelvetColors.surface,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
                onChanged: on
                    ? (v) async {
                        await SettingsManager().setTranscodeCodec(v);
                        if (mounted) setState(() {});
                      }
                    : null,
                items: [
                  DropdownMenuItem<String?>(
                      value: null, child: Text(l.transcodeAuto)),
                  ...TranscodeManager.codecs.map(
                    (c) => DropdownMenuItem<String?>(
                        value: c, child: Text(_codecLabel(c))),
                  ),
                ],
              ),
            ),
            ListTile(
              enabled: on,
              title:
                  Text(l.transcodeBitrate, style: TextStyle(color: labelColor)),
              trailing: DropdownButton<String?>(
                value: tm.bitrate,
                underline: const SizedBox.shrink(),
                dropdownColor: VelvetColors.surface,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
                onChanged: on
                    ? (v) async {
                        await SettingsManager().setTranscodeBitrate(v);
                        if (mounted) setState(() {});
                      }
                    : null,
                items: [
                  DropdownMenuItem<String?>(
                      value: null, child: Text(l.transcodeAuto)),
                  ...TranscodeManager.bitrates.map(
                    (b) => DropdownMenuItem<String?>(value: b, child: Text(b)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: VelvetColors.border),
          ],
        ),
      ),
    );
  }
}
