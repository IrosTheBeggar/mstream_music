import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../objects/player_layout.dart';
import '../singletons/downloads.dart';
import '../singletons/media.dart';
import '../singletons/queue_store.dart';
import '../singletons/settings.dart';
import '../singletons/app_messenger.dart';
import '../theme/velvet_theme.dart';
import '../widgets/accent_color_sheet.dart';
import 'eq_screen.dart';
import 'imported_shaders_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
    'ru': 'Русский',
    'it': 'Italiano',
    'pl': 'Polski',
    'ja': '日本語',
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
            title: Text(l.settingsAccentColor),
            subtitle: Text(
              l.settingsAccentColorSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: VelvetColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: VelvetColors.border),
              ),
            ),
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: VelvetColors.surface,
              isScrollControlled: true,
              builder: (_) => const AccentColorSheet(),
            ),
          ),
          ListTile(
            title: const Text('Now Playing layout'),
            subtitle: Text(
              _playerLayoutSubtitle(l, SettingsManager().playerLayout),
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<PlayerLayout>(
              value: SettingsManager().playerLayout,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              items: PlayerLayout.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_playerLayoutLabel(l, p)),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() {});
                await SettingsManager().setPlayerLayout(v);
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
          ListTile(
            title: Text(l.settingsStartupPage),
            subtitle: Text(
              l.settingsStartupPageSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: DropdownButton<StartupView>(
              value: SettingsManager().startupView,
              underline: SizedBox.shrink(),
              dropdownColor: VelvetColors.surface,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              items: StartupView.values
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v.label(l)),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await SettingsManager().setStartupView(v);
                setState(() {});
              },
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader(l.settingsSectionPlayback),
          SwitchListTile(
            title: Text(l.settingsResumeQueue),
            subtitle: Text(
              l.settingsResumeQueueSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().resumeQueue,
            onChanged: (v) async {
              setState(() {});
              await SettingsManager().setResumeQueue(v);
              // Apply immediately: persist the current queue when turning on,
              // or delete the stored queue when turning off.
              await QueueStore().saveNow();
              setState(() {});
            },
            activeThumbColor: VelvetColors.primary,
          ),
          SwitchListTile(
            title: Text(l.settingsOfflineQueue),
            subtitle: Text(
              l.settingsOfflineQueueSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().offlineQueue,
            onChanged: (v) async {
              setState(() {});
              await SettingsManager().setOfflineQueue(v);
              if (v) {
                // Act now, not on the next queue edit: sweep the current
                // queue (also clears the once-per-session attempt guard so
                // earlier failures get a fresh chance).
                unawaited(DownloadManager().sweepQueueNow());
              } else {
                // Wi-Fi-held tasks would otherwise sit in WorkManager
                // indefinitely (they survive restarts) and fire long after
                // the user said stop. Running transfers finish normally.
                unawaited(DownloadManager().cancelWifiHeld());
              }
              setState(() {});
            },
            activeThumbColor: VelvetColors.primary,
          ),
          SwitchListTile(
            title: Text(l.settingsOfflineQueueWifiOnly),
            subtitle: Text(
              l.settingsOfflineQueueWifiOnlySubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().offlineQueueWifiOnly,
            // Only meaningful while keep-queue-offline is on (existing
            // transfers keep the constraint they were enqueued with).
            onChanged: !SettingsManager().offlineQueue
                ? null
                : (v) async {
                    setState(() {});
                    await SettingsManager().setOfflineQueueWifiOnly(v);
                    setState(() {});
                  },
            activeThumbColor: VelvetColors.primary,
          ),
          ListTile(
            enabled: SettingsManager().offlineQueue,
            title: Text(l.settingsAutoDownloadCap),
            subtitle: Text(
              _autoDownloadCapSubtitle(l, SettingsManager().autoDownloadCap),
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: Text(
              SettingsManager().autoDownloadCap <= 0
                  ? l.settingsAutoDownloadCapUnlimited
                  : '${SettingsManager().autoDownloadCap}',
              style: TextStyle(
                  color: SettingsManager().offlineQueue
                      ? VelvetColors.primary
                      : VelvetColors.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            onTap: !SettingsManager().offlineQueue
                ? null
                : () => _editAutoDownloadCap(l),
          ),
          SwitchListTile(
            title: Text(l.settingsRatingHalf),
            subtitle: Text(
              l.settingsRatingHalfSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().ratingAllowHalf,
            onChanged: (v) async {
              // setState first so the switch flips immediately (the manager
              // updates its in-memory value synchronously; the await only
              // persists). Mirrors the Resume-queue toggle above.
              setState(() {});
              await SettingsManager().setRatingAllowHalf(v);
              setState(() {});
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
            leading:
                Icon(Icons.auto_awesome, color: VelvetColors.textSecondary),
            title: Text(l.importedShadersTitle),
            subtitle: Text(
              l.importedShadersSettingsSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ImportedShadersScreen()),
              );
            },
          ),
          ListTile(
            title: Text(l.settingsCastQuality),
            subtitle: Text(
              _castQualitySubtitle(l, SettingsManager().castVisualizerQuality),
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
              // resetAll flips eqEnabled by direct field write; the pipelined
              // player would keep coloring audio while the EQ screen says
              // Off. Route the audible half through the handler (rebuilds to
              // a plain player) — only when EQ was actually on.
              final eqWasOn = SettingsManager().eqEnabled;
              await SettingsManager().resetAll();
              if (eqWasOn) {
                unawaited(MediaManager().audioHandler.setEqEnabled(false));
              }
              if (mounted) setState(() {});
              // App-wide messenger so the toast doesn't depend on this screen's
              // context surviving the await.
              showGlobalSnack(l.settingsResetDone);
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

  String _playerLayoutLabel(AppLocalizations l, PlayerLayout p) {
    switch (p) {
      case PlayerLayout.small:
        return l.playerLayoutSmall;
      case PlayerLayout.medium:
        return l.playerLayoutMedium;
      case PlayerLayout.large:
        return l.playerLayoutLarge;
      case PlayerLayout.xl:
        return l.playerLayoutXl;
    }
  }

  String _playerLayoutSubtitle(AppLocalizations l, PlayerLayout p) {
    switch (p) {
      case PlayerLayout.small:
        return l.playerLayoutSmallDesc;
      case PlayerLayout.medium:
        return l.playerLayoutMediumDesc;
      case PlayerLayout.large:
        return l.playerLayoutLargeDesc;
      case PlayerLayout.xl:
        return l.playerLayoutXlDesc;
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

  String _castQualitySubtitle(AppLocalizations l, CastVisualizerQuality q) {
    switch (q) {
      case CastVisualizerQuality.hd720:
        return l.settingsCastQualitySubtitle720;
      case CastVisualizerQuality.fhd1080:
        return l.settingsCastQualitySubtitle1080;
      case CastVisualizerQuality.uhd2160:
        return l.settingsCastQualitySubtitle4k;
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

  String _autoDownloadCapSubtitle(AppLocalizations l, int cap) =>
      cap <= 0 ? l.settingsAutoDownloadCapSubtitleUnlimited : l.settingsAutoDownloadCapSubtitle;

  // Prompt for the auto-download retention limit. 0 (or empty) = unlimited.
  // Applying a lower value evicts down to it immediately — a deliberate,
  // user-initiated moment, the only place besides a fresh auto-download where
  // eviction is allowed to run.
  Future<void> _editAutoDownloadCap(AppLocalizations l) async {
    final current = SettingsManager().autoDownloadCap;
    final ctrl = TextEditingController(text: current <= 0 ? '' : '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.settingsAutoDownloadCap,
            style: TextStyle(color: VelvetColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.settingsAutoDownloadCapDialogBody,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 13)),
            SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: VelvetColors.textPrimary),
              decoration: InputDecoration(
                labelText: l.settingsAutoDownloadCapField,
                hintText: l.settingsAutoDownloadCapUnlimited,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: Text(l.cancel,
                  style: TextStyle(color: VelvetColors.textSecondary))),
          TextButton(
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim()) ?? 0;
                Navigator.of(dctx).pop(v < 0 ? 0 : v);
              },
              child: Text(l.save)),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final lowered = result != 0 &&
        (current == 0 || result < current); // 0 = unlimited (never lower)
    await SettingsManager().setAutoDownloadCap(result);
    if (lowered) unawaited(DownloadManager().enforceAutoDownloadCap());
    if (mounted) setState(() {});
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
