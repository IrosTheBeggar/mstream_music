import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../theme/velvet_theme.dart';
import 'eq_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // A language's name in its own language. Intentionally NOT translated —
  // users recognize their language by its endonym. Keyed by language
  // code; the picker is built from AppLocalizations.supportedLocales so
  // it auto-grows as ARB files are added.
  static const _endonyms = <String, String>{
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
    'zh': '中文',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
        children: [
          _sectionHeader(l.settingsSectionAppearance),
          ListTile(
            title: Text(l.settingsTheme),
            subtitle: Text(
              _themeSubtitle(l, SettingsManager().appTheme),
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
                        child: Text(t.label(l)),
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
          ListTile(
            title: Text(l.settingsLanguage),
            subtitle: Text(
              l.settingsLanguageSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<String?>(
              value: SettingsManager().language,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              // "System default" (null) first, then one entry per
              // supported locale — derived from the generated
              // supportedLocales so new ARB files appear automatically.
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l.languageSystemDefault),
                ),
                ...AppLocalizations.supportedLocales.map(
                  (loc) => DropdownMenuItem<String?>(
                    value: loc.languageCode,
                    child: Text(
                        _endonyms[loc.languageCode] ?? loc.languageCode),
                  ),
                ),
              ],
              // null is a valid choice here (follow device), so unlike the
              // theme picker we don't early-return on null.
              onChanged: (v) async {
                setState(() {});
                await SettingsManager().setLanguage(v);
                setState(() {});
              },
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader(l.settingsSectionPlayback),
          SwitchListTile(
            title: Text(l.settingsTranscode),
            subtitle: Text(
              l.settingsTranscodeSubtitle,
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
            title: Text(l.settingsTapBehavior),
            subtitle: Text(
              _tapBehaviorSubtitle(l, SettingsManager().tapBehavior),
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
                        child: Text(b.label(l)),
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
            title: Text(l.eqTitle),
            subtitle: Text(
              l.settingsEqSubtitle,
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
            title: Text(l.settingsVisualizerEngine),
            subtitle: Text(
              _visualizerEngineSubtitle(l, SettingsManager().visualizerEngine),
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<VisualizerEngine>(
              value: SettingsManager().visualizerEngine,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              items: VisualizerEngine.values
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.label(l)),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await SettingsManager().setVisualizerEngine(v);
                if (mounted) setState(() {});
              },
            ),
          ),
          ListTile(
            title: Text(l.settingsVisualizerSource),
            subtitle: Text(
              _visualizerSourceSubtitle(
                  l, SettingsManager().visualizerAudioSource),
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
                        child: Text(s.label(l)),
                      ))
                  .toList(),
              onChanged: (v) => _onVisualizerSourceChanged(v),
            ),
          ),
          SwitchListTile(
            title: Text(l.settingsVisualizerKnobs),
            subtitle: Text(
              l.settingsVisualizerKnobsSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().showVisualizerKnobs,
            onChanged: (v) async {
              setState(() {});
              await SettingsManager().setShowVisualizerKnobs(v);
              setState(() {});
            },
            activeThumbColor: VelvetColors.primary,
          ),
          ListTile(
            title: Text('Cast visualizer quality'),
            subtitle: Text(
              _castQualitySubtitle(SettingsManager().castVisualizerQuality),
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<CastVisualizerQuality>(
              value: SettingsManager().castVisualizerQuality,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              items: CastVisualizerQuality.values
                  .map((q) => DropdownMenuItem(
                        value: q,
                        child: Text(q.label),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await SettingsManager().setCastVisualizerQuality(v);
                if (mounted) setState(() {});
              },
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader(l.settingsSectionBrowse),
          SwitchListTile(
            title: Text(l.settingsAlbumGrid),
            subtitle: Text(
              l.settingsAlbumGridSubtitle,
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
            title: Text(l.settingsFileMetadata),
            subtitle: Text(
              l.settingsFileMetadataSubtitle,
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
                        l.settingsLetterStrip,
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
                  l.settingsLetterStripSubtitle,
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
          _sectionHeader(l.settingsSectionAbout),
          ListTile(
            leading: Icon(Icons.tune),
            title: Text(l.settingsReset),
            subtitle: Text(
              l.settingsResetSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            onTap: () async {
              await SettingsManager().resetAll();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.settingsResetDone)),
                );
              }
            },
          ),
        ],
      ),
      ),
    );
  }

  String _themeSubtitle(AppLocalizations l, AppTheme t) {
    switch (t) {
      case AppTheme.velvet:
        return l.themeSubtitleVelvet;
      case AppTheme.dark:
        return l.themeSubtitleDark;
      case AppTheme.light:
        return l.themeSubtitleLight;
    }
  }

  String _visualizerEngineSubtitle(AppLocalizations l, VisualizerEngine e) {
    switch (e) {
      case VisualizerEngine.milkdrop:
        return l.visualizerEngineSubtitleMilkdrop;
      case VisualizerEngine.shader:
        return l.visualizerEngineSubtitleShaders;
    }
  }

  String _castQualitySubtitle(CastVisualizerQuality q) {
    switch (q) {
      case CastVisualizerQuality.hd720:
        return 'Resolution the visualizer streams to a TV at. 720p — lightest '
            'on the phone.';
      case CastVisualizerQuality.fhd1080:
        return 'Resolution the visualizer streams to a TV at. 1080p — sharp on '
            'any Chromecast (default).';
      case CastVisualizerQuality.uhd2160:
        return 'Resolution the visualizer streams to a TV at. 4K — needs a 4K '
            'Chromecast; much heavier on the phone.';
    }
  }

  String _visualizerSourceSubtitle(AppLocalizations l, VisualizerAudioSource s) {
    switch (s) {
      case VisualizerAudioSource.synthesized:
        return l.visualizerSourceSubtitleSynthesized;
      case VisualizerAudioSource.real:
        return l.visualizerSourceSubtitleReal;
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
    if (consented != true || !mounted) return false;

    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (mounted) {
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

  String _tapBehaviorSubtitle(AppLocalizations l, TapBehavior b) {
    switch (b) {
      case TapBehavior.addToQueue:
        return l.tapSubtitleAddToQueue;
      case TapBehavior.playFromHere:
        return l.tapSubtitlePlayFromHere;
      case TapBehavior.appendAndJump:
        return l.tapSubtitleAppendAndJump;
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
