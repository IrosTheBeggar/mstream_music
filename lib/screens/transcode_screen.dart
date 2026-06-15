import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../theme/velvet_theme.dart';

/// Dedicated page for transcoding configuration, reached from the drawer.
///
/// Hosts the transcode on/off control plus the per-request codec / bitrate the
/// app sends to the mStream `/transcode` endpoint. "Server default" omits the
/// param so the server uses its own configured default — and we label it with
/// the actual default (from `/api/v1/ping`) when the active server reports one.
/// The dropdowns are disabled while transcoding is off.
class TranscodeScreen extends StatefulWidget {
  const TranscodeScreen({super.key});

  @override
  State<TranscodeScreen> createState() => _TranscodeScreenState();
}

class _TranscodeScreenState extends State<TranscodeScreen> {
  // Track the ping so the "server can't transcode" note only shows once we
  // actually know (ping succeeded) — never while loading or on ping failure.
  bool _loading = true;
  bool _pingOk = false;

  @override
  void initState() {
    super.initState();
    _refreshServerDefaults();
  }

  /// Refresh the active server's transcode defaults + availability from
  /// `/api/v1/ping` so the "Server default (…)" labels and the unavailable
  /// note are accurate.
  Future<void> _refreshServerDefaults() async {
    final server = ServerManager().currentServer;
    if (server == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      await ServerManager().getServerPaths(server, throwErr: true);
      _pingOk = true;
    } catch (_) {
      _pingOk = false; // unknown — don't claim transcoding is unavailable
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Push the changed transcode settings onto the current queue, per the user's
  /// "Apply to current queue" preference (whole-queue reload vs upcoming-only).
  Future<void> _applyToQueue() async {
    await MediaManager().audioHandler.customAction(
      'rebuildTranscodeUrls',
      {'upcomingOnly': !TranscodeManager().rebuildWholeQueue},
    );
  }

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

    // Label the "Server default" option with what the active server actually
    // falls back to, when it reported it via ping.
    final server = ServerManager().currentServer;
    final String? defCodec = server?.transcodeDefaultCodec;
    final String? defBitrate = server?.transcodeDefaultBitrate;
    final String codecAuto = defCodec != null
        ? '${l.transcodeAuto} (${_codecLabel(defCodec)})'
        : l.transcodeAuto;
    final String bitrateAuto = defBitrate != null
        ? '${l.transcodeAuto} ($defBitrate)'
        : l.transcodeAuto;

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
                await _applyToQueue();
                if (mounted) setState(() {});
              },
              activeThumbColor: VelvetColors.primary,
            ),
            Divider(height: 1, color: VelvetColors.border),
            if (!_loading &&
                _pingOk &&
                server != null &&
                server.transcodeAvailable == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: VelvetColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.transcodeUnavailable,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
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
                        await _applyToQueue();
                        if (mounted) setState(() {});
                      }
                    : null,
                items: [
                  DropdownMenuItem<String?>(
                      value: null, child: Text(codecAuto)),
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
                        await _applyToQueue();
                        if (mounted) setState(() {});
                      }
                    : null,
                items: [
                  DropdownMenuItem<String?>(
                      value: null, child: Text(bitrateAuto)),
                  ...TranscodeManager.bitrates.map(
                    (b) => DropdownMenuItem<String?>(value: b, child: Text(b)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: VelvetColors.border),
            CheckboxListTile(
              value: tm.rebuildWholeQueue,
              onChanged: (v) async {
                await SettingsManager().setTranscodeRebuildWholeQueue(v ?? true);
                if (mounted) setState(() {});
              },
              title: Text(l.transcodeReloadQueue,
                  style: TextStyle(color: VelvetColors.textPrimary)),
              subtitle: Text(
                l.transcodeReloadQueueSubtitle,
                style:
                    TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
              ),
              activeColor: VelvetColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ],
        ),
      ),
    );
  }
}
