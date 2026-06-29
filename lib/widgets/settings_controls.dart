// Reusable preference controls shared between the Settings screen and the
// first-run "Quick setup" card on the Add Server screen. Each is a
// self-contained StatefulWidget that reads/writes SettingsManager and owns its
// own setState, so it looks and behaves identically wherever it's dropped in.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import 'accent_color_sheet.dart';

// Not const: VelvetColors.* are theme-dependent globals, so this re-evaluates
// per build (matching the original inline style and picking up theme changes).
TextStyle get _subtitleStyle =>
    TextStyle(color: VelvetColors.textSecondary, fontSize: 12);

// ── Language ──────────────────────────────────────────────────────────────
class LanguageSettingTile extends StatefulWidget {
  // When compact, the subtitle is dropped (used in the tight first-run card).
  final bool compact;
  const LanguageSettingTile({super.key, this.compact = false});

  @override
  State<LanguageSettingTile> createState() => _LanguageSettingTileState();
}

class _LanguageSettingTileState extends State<LanguageSettingTile> {
  // A language's name in its own language. Intentionally NOT translated —
  // users recognize their language by its endonym. The picker is built from
  // AppLocalizations.supportedLocales so it auto-grows as ARB files are added.
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
    return ListTile(
      title: Text(l.settingsLanguage, overflow: TextOverflow.ellipsis),
      subtitle: widget.compact
          ? null
          : Text(l.settingsLanguageSubtitle, style: _subtitleStyle),
      trailing: DropdownButton<String?>(
        value: SettingsManager().language,
        underline: SizedBox.shrink(),
        dropdownColor: VelvetColors.surface,
        style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
        // "System default" (null) first, then one entry per supported locale.
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(l.languageSystemDefault),
          ),
          ...AppLocalizations.supportedLocales.map(
            (loc) => DropdownMenuItem<String?>(
              value: loc.languageCode,
              child: Text(_endonyms[loc.languageCode] ?? loc.languageCode),
            ),
          ),
        ],
        // null is a valid choice (follow device), so we don't early-return on it.
        onChanged: (v) async {
          setState(() {});
          await SettingsManager().setLanguage(v);
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

// ── "When you tap a song" ───────────────────────────────────────────────────
class TapBehaviorSettingTile extends StatefulWidget {
  const TapBehaviorSettingTile({super.key});

  @override
  State<TapBehaviorSettingTile> createState() => _TapBehaviorSettingTileState();
}

class _TapBehaviorSettingTileState extends State<TapBehaviorSettingTile> {
  String _subtitle(AppLocalizations l, TapBehavior b) {
    switch (b) {
      case TapBehavior.addToQueue:
        return l.tapSubtitleAddToQueue;
      case TapBehavior.playFromHere:
        return l.tapSubtitlePlayFromHere;
      case TapBehavior.appendAndJump:
        return l.tapSubtitleAppendAndJump;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      title: Text(l.settingsTapBehavior, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(l, SettingsManager().tapBehavior),
          style: _subtitleStyle),
      trailing: DropdownButton<TapBehavior>(
        value: SettingsManager().tapBehavior,
        underline: SizedBox.shrink(),
        dropdownColor: VelvetColors.surface,
        style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
        items: TapBehavior.values
            .map((b) => DropdownMenuItem(value: b, child: Text(b.label(l))))
            .toList(),
        onChanged: (v) async {
          if (v == null) return;
          setState(() {});
          await SettingsManager().setTapBehavior(v);
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

// ── Visualizer audio source (carries the RECORD_AUDIO permission flow) ───────
class VisualizerSourceSettingTile extends StatefulWidget {
  const VisualizerSourceSettingTile({super.key});

  @override
  State<VisualizerSourceSettingTile> createState() =>
      _VisualizerSourceSettingTileState();
}

class _VisualizerSourceSettingTileState
    extends State<VisualizerSourceSettingTile> {
  String _subtitle(AppLocalizations l, VisualizerAudioSource s) {
    switch (s) {
      case VisualizerAudioSource.synthesized:
        return l.visualizerSourceSubtitleSynthesized;
      case VisualizerAudioSource.real:
        return l.visualizerSourceSubtitleReal;
    }
  }

  // Switching to "real" walks the user through the RECORD_AUDIO permission flow
  // with an up-front explanation of *why* a music app wants the microphone. If
  // the user denies (or cancels), we revert so the dropdown stays honest.
  Future<void> _onChanged(VisualizerAudioSource? v) async {
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

  // Two-step: explanation dialog → OS permission prompt. Returns true only if
  // the user accepted both and the permission is granted.
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      title: Text(l.settingsVisualizerSource, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(l, SettingsManager().visualizerAudioSource),
          style: _subtitleStyle),
      trailing: DropdownButton<VisualizerAudioSource>(
        value: SettingsManager().visualizerAudioSource,
        underline: SizedBox.shrink(),
        dropdownColor: VelvetColors.surface,
        style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
        items: VisualizerAudioSource.values
            .map((s) => DropdownMenuItem(value: s, child: Text(s.label(l))))
            .toList(),
        onChanged: _onChanged,
      ),
    );
  }
}

// ── Accent colour picker ────────────────────────────────────────────────────
class AccentColorSettingTile extends StatefulWidget {
  const AccentColorSettingTile({super.key});

  @override
  State<AccentColorSettingTile> createState() => _AccentColorSettingTileState();
}

class _AccentColorSettingTileState extends State<AccentColorSettingTile> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      title: Text(l.settingsAccentColor, overflow: TextOverflow.ellipsis),
      subtitle: Text(l.settingsAccentColorSubtitle, style: _subtitleStyle),
      trailing: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: VelvetColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: VelvetColors.border),
        ),
      ),
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          backgroundColor: VelvetColors.surface,
          isScrollControlled: true,
          builder: (_) => const AccentColorSheet(),
        );
        if (mounted) setState(() {}); // refresh the swatch to the new accent
      },
    );
  }
}
