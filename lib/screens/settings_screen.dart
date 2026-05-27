import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../theme/velvet_theme.dart';
import 'eq_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
        children: [
          _sectionHeader('Appearance'),
          ListTile(
            title: Text('Theme'),
            subtitle: Text(
              _themeSubtitle(SettingsManager().appTheme),
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<AppTheme>(
              value: SettingsManager().appTheme,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              items: AppTheme.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() {});
                await SettingsManager().setAppTheme(v);
                setState(() {});
              },
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader('Playback'),
          SwitchListTile(
            title: Text('Transcode audio'),
            subtitle: Text(
              'Stream a transcoded copy from the server (smaller files, '
              'slightly slower start). Off plays original files.',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: TranscodeManager().transcodeOn,
            onChanged: (v) async {
              setState(() {
                TranscodeManager().transcodeOn = v;
              });
              await SettingsManager().setTranscode(v);
            },
            activeThumbColor: VelvetColors.primary,
          ),
          ListTile(
            title: Text('When you tap a song'),
            subtitle: Text(
              _tapBehaviorSubtitle(SettingsManager().tapBehavior),
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<TapBehavior>(
              value: SettingsManager().tapBehavior,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              items: TapBehavior.values
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.label),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() {});
                await SettingsManager().setTapBehavior(v);
                setState(() {});
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.equalizer, color: VelvetColors.textSecondary),
            title: Text('Equalizer'),
            subtitle: Text(
              'Tune bass, mids, and treble. Android only.',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EqScreen()),
              );
            },
          ),
          ListTile(
            title: Text('Visualizer audio source'),
            subtitle: Text(
              _visualizerSourceSubtitle(
                  SettingsManager().visualizerAudioSource),
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<VisualizerAudioSource>(
              value: SettingsManager().visualizerAudioSource,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              items: VisualizerAudioSource.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      ))
                  .toList(),
              onChanged: (v) => _onVisualizerSourceChanged(v),
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader('Browse'),
          SwitchListTile(
            title: Text('Album grid view'),
            subtitle: Text(
              'Show albums as a grid of cards with cover art instead of '
              'a plain list.',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().albumGrid,
            onChanged: (v) async {
              setState(() {});
              await SettingsManager().setAlbumGrid(v);
              setState(() {});
            },
            activeThumbColor: VelvetColors.primary,
          ),
          SwitchListTile(
            title: Text('Read song metadata in file explorer'),
            subtitle: Text(
              'Fetch title, artist, and album art for each song when '
              "browsing server files. Off shows raw filenames (faster "
              'for huge folders).',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().fileExplorerMetadata,
            onChanged: (v) async {
              setState(() {});
              await SettingsManager().setFileExplorerMetadata(v);
              setState(() {});
            },
            activeThumbColor: VelvetColors.primary,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Letter scrubber threshold',
                        style: TextStyle(
                          fontSize: 16,
                          color: VelvetColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${SettingsManager().letterStripThreshold}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: VelvetColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Show the A-Z quick-scrub strip when a list has this '
                  'many items or more. Below this size the strip is '
                  'hidden and long folder/file names wrap to multiple '
                  'lines instead of being truncated. Set 0 to always '
                  'show the strip.',
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: VelvetColors.primary,
                    thumbColor: VelvetColors.primary,
                    overlayColor: VelvetColors.primaryDim,
                  ),
                  child: Slider(
                    value: SettingsManager()
                        .letterStripThreshold
                        .toDouble()
                        .clamp(0.0, 100.0),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) async {
                      setState(() {});
                      await SettingsManager()
                          .setLetterStripThreshold(v.round());
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader('About'),
          ListTile(
            leading: Icon(Icons.tune),
            title: Text('Reset to defaults'),
            subtitle: Text(
              'Restore all settings on this screen to their default '
              'values. Servers and downloads are not affected.',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            onTap: () async {
              await SettingsManager().resetAll();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settings restored to defaults')),
                );
              }
            },
          ),
        ],
      ),
      ),
    );
  }

  String _themeSubtitle(AppTheme t) {
    switch (t) {
      case AppTheme.velvet:
        return 'Navy and purple — the signature dark theme.';
      case AppTheme.dark:
        return 'Neutral dark with amber accents.';
      case AppTheme.light:
        return 'Light body with a dark app bar and amber accents — '
            "matches the older shipped theme.";
    }
  }

  String _visualizerSourceSubtitle(VisualizerAudioSource s) {
    switch (s) {
      case VisualizerAudioSource.synthesized:
        return 'Default. Visualizer reacts to playback timing only — no '
            'microphone permission required.';
      case VisualizerAudioSource.real:
        return 'Visualizer reacts to actual audio output. Requires the '
            'RECORD_AUDIO permission on Android.';
    }
  }

  // Dropdown handler for the visualizer source. Switching to "real"
  // walks the user through the RECORD_AUDIO permission flow with an
  // up-front explanation of *why* a music app is asking for the
  // microphone permission. If the user denies (or cancels), we revert
  // the setting so the dropdown stays honest.
  Future<void> _onVisualizerSourceChanged(VisualizerAudioSource? v) async {
    if (v == null) return;
    final current = SettingsManager().visualizerAudioSource;
    if (v == current) return;

    if (v == VisualizerAudioSource.real) {
      final ok = await _confirmRealAudioPermission();
      if (!ok) return;
    }

    await SettingsManager().setVisualizerAudioSource(v);
    if (mounted) setState(() {});
  }

  // Two-step: explanation dialog → OS permission prompt. Returns true
  // only if the user accepted both and the permission is granted.
  Future<bool> _confirmRealAudioPermission() async {
    final consented = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text('Use real audio?',
            style: TextStyle(color: VelvetColors.textPrimary)),
        content: Text(
          'Real audio mode reads the waveform of music your phone is '
          'playing so the visualizer can react to it. Android requires '
          'the RECORD_AUDIO permission for this — the app does not '
          'record or send any audio anywhere. You can switch back to '
          'synthesized at any time.',
          style: TextStyle(color: VelvetColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Continue',
                style: TextStyle(color: VelvetColors.primary)),
          ),
        ],
      ),
    );
    if (consented != true || !mounted) return false;

    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (mounted) {
      final permanentlyDenied = status.isPermanentlyDenied;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(permanentlyDenied
              ? 'Permission permanently denied. Enable it in system settings to use real audio.'
              : 'Permission denied. Staying on synthesized audio.'),
          action: permanentlyDenied
              ? SnackBarAction(
                  label: 'Open settings',
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
    }
    return false;
  }

  String _tapBehaviorSubtitle(TapBehavior b) {
    switch (b) {
      case TapBehavior.addToQueue:
        return 'Tapping a song appends it to the queue. If the queue is '
            'empty, playback starts automatically.';
      case TapBehavior.playFromHere:
        return 'Tapping a song replaces the queue with the songs in the '
            'current view and starts playback at the tapped song.';
      case TapBehavior.appendAndJump:
        return 'Tapping a song appends it to the queue and jumps playback '
            'to it, interrupting whatever was playing.';
    }
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: VelvetColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
