import 'dart:async' show StreamSubscription, unawaited;
import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../l10n/language_names.dart';
import '../native/torrent_channel.dart';
import '../native/user_shaders.dart';
import '../objects/player_layout.dart';
import '../singletons/downloads.dart';
import '../singletons/media.dart';
import '../singletons/queue_store.dart';
import '../singletons/settings.dart';
import '../singletons/play_history.dart';
import '../singletons/play_sync.dart';
import '../widgets/federation_widgets.dart';
import '../singletons/app_messenger.dart';
import '../theme/velvet_theme.dart';
import '../util/real_audio_permission.dart';
import '../widgets/accent_color_sheet.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/home_widget_sheet.dart';
import 'imported_shaders_screen.dart';

/// One page, every row one line: a row shows its current value (or a switch),
/// never a description. Choices open a picker sheet; the few facts that matter
/// before a change (deletion, permissions) live in the dialogs where they bite.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // In-flight letter-strip slider drag value. Updated locally per drag tick;
  // committed via setLetterStripThreshold only in onChangeEnd — the setter
  // rewrites all of settings.json AND re-emits the whole browser list per
  // call, which used to run on every tick of a drag.
  int? _letterStripDrag;

  // Live listening-history figures: plays waiting to be sent and the size on
  // disk. Both move while the page is open (a track ends, a drain lands).
  int _unsynced = PlayHistory().outboxCount;
  int? _historyBytes;
  StreamSubscription<void>? _historySub;
  StreamSubscription<void>? _syncSub;

  // Files in the imported-shaders folder (Android); null until scanned.
  int? _shaderCount;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
    _historySub = PlayHistory().changes.listen((_) => _refreshHistory());
    _syncSub = PlaySync().changes.listen((_) => _refreshHistory());
    if (Platform.isAndroid) _countShaders();
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    final bytes = await PlayHistory().sizeBytes();
    if (!mounted) return;
    setState(() {
      _unsynced = PlayHistory().outboxCount;
      _historyBytes = bytes;
    });
  }

  Future<void> _countShaders() async {
    final n = (await UserShaders().list()).length;
    if (mounted) setState(() => _shaderCount = n);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = SettingsManager();
    final threshold = _letterStripDrag ?? s.letterStripThreshold;
    final bytes = _historyBytes;
    final historyEmpty = bytes == 0 && _unsynced == 0;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Section(
              header: l.settingsSectionAppearance,
              children: [
                _ValueRow(
                  title: l.settingsTheme,
                  value: s.appTheme.label(l),
                  onTap: _pickTheme,
                ),
                _ValueRow(
                  title: l.settingsAccentColor,
                  trailing: Container(
                    width: 22,
                    height: 22,
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
                _ValueRow(
                  title: l.settingsPlayerLayout,
                  value: _playerLayoutLabel(l, s.playerLayout),
                  onTap: _pickPlayerLayout,
                ),
                // The one leading icon on the page: someone stuck in a
                // language they can't read can still find this row.
                _ValueRow(
                  leading: Icon(Icons.language, color: VelvetColors.textSecondary),
                  title: l.settingsLanguage,
                  value: _languageLabel(l, s.language),
                  onTap: _pickLanguage,
                ),
                // The home-screen widget: Android places it from the sheet
                // (the launcher's pin request, one of five sizes); iOS has no
                // such API, so its sheet says where the gallery is.
                if (Platform.isAndroid || Platform.isIOS)
                  _ValueRow(
                    title: l.settingsHomeWidget,
                    chevron: true,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: VelvetColors.surface,
                      builder: (_) => const HomeWidgetSheet(),
                    ),
                  ),
              ],
            ),
            _Section(
              header: l.settingsSectionPlayback,
              footer: s.offlineQueue ? l.settingsOfflineQueueFooter : null,
              children: [
                _ValueRow(
                  title: l.settingsTapBehavior,
                  value: s.tapBehavior.label(l),
                  onTap: _pickTapBehavior,
                ),
                _SwitchRow(
                  title: l.settingsResumeQueue,
                  value: s.resumeQueue,
                  onChanged: (v) async {
                    setState(() {});
                    await s.setResumeQueue(v);
                    // Apply immediately: persist the current queue when
                    // turning on, or delete the stored queue when turning off.
                    await QueueStore().saveNow();
                    if (mounted) setState(() {});
                  },
                ),
                _SwitchRow(
                  title: l.settingsOfflineQueue,
                  value: s.offlineQueue,
                  onChanged: (v) async {
                    setState(() {});
                    await s.setOfflineQueue(v);
                    if (v) {
                      // Act now, not on the next queue edit: sweep the current
                      // queue (also clears the once-per-session attempt guard
                      // so earlier failures get a fresh chance).
                      unawaited(DownloadManager().sweepQueueNow());
                    } else {
                      // Wi-Fi-held tasks would otherwise sit in WorkManager
                      // indefinitely (they survive restarts) and fire long
                      // after the user said stop.
                      unawaited(DownloadManager().cancelWifiHeld());
                    }
                    if (mounted) setState(() {});
                  },
                ),
                // Only meaningful while the queue downloads (existing
                // transfers keep the constraint they were enqueued with).
                _Nested(
                  visible: s.offlineQueue,
                  children: [
                    _SwitchRow(
                      title: l.settingsOfflineQueueWifiOnly,
                      value: s.offlineQueueWifiOnly,
                      onChanged: (v) async {
                        setState(() {});
                        await s.setOfflineQueueWifiOnly(v);
                        if (mounted) setState(() {});
                      },
                    ),
                    _ValueRow(
                      title: l.settingsAutoDownloadCap,
                      value: s.autoDownloadCap <= 0
                          ? l.settingsAutoDownloadCapUnlimited
                          : l.settingsAutoDownloadCapValue(s.autoDownloadCap),
                      onTap: _editAutoDownloadCap,
                    ),
                  ],
                ),
              ],
            ),
            _Section(
              header: l.settingsSectionBrowse,
              children: [
                _ValueRow(
                  title: l.settingsStartupPage,
                  value: s.startupView.label(l),
                  onTap: _pickStartupView,
                ),
                _SwitchRow(
                  title: l.settingsAlbumGrid,
                  value: s.albumGrid,
                  onChanged: (v) async {
                    setState(() {});
                    await s.setAlbumGrid(v);
                    if (mounted) setState(() {});
                  },
                ),
                _SwitchRow(
                  title: l.settingsFileMetadata,
                  value: s.fileExplorerMetadata,
                  onChanged: (v) async {
                    setState(() {});
                    await s.setFileExplorerMetadata(v);
                    if (mounted) setState(() {});
                  },
                ),
                // The how-to line matters only once half stars are on.
                _SwitchRow(
                  title: l.settingsRatingHalf,
                  subtitle: s.ratingAllowHalf ? l.settingsRatingHalfSubtitle : null,
                  value: s.ratingAllowHalf,
                  onChanged: (v) async {
                    setState(() {});
                    await s.setRatingAllowHalf(v);
                    if (mounted) setState(() {});
                  },
                ),
                _ValueRow(
                  title: l.settingsLetterStrip,
                  value: l.settingsLetterStripValue(threshold),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: VelvetColors.primary,
                      thumbColor: VelvetColors.primary,
                      overlayColor: VelvetColors.primaryDim,
                    ),
                    child: Slider(
                      value: threshold.toDouble().clamp(0.0, 100.0),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      semanticFormatterCallback: (v) =>
                          '${l.settingsLetterStrip}: ${l.settingsLetterStripValue(v.round())}',
                      // Local during the drag; committed once on release — the
                      // setter rewrites settings.json and re-emits the entire
                      // browser list, so it must not run per tick.
                      onChanged: (v) =>
                          setState(() => _letterStripDrag = v.round()),
                      onChangeEnd: (v) async {
                        await s.setLetterStripThreshold(v.round());
                        if (mounted) setState(() => _letterStripDrag = null);
                      },
                    ),
                  ),
                ),
                // The same number decides whether long names wrap — the one
                // coupling the row's value can't say.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l.settingsLetterStripHint,
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 12),
                  ),
                ),
                _Nested(
                  visible: true,
                  children: [
                    // Title above the buttons, not beside them: at a large
                    // text size two long labels (Izquierda / Derecha) would
                    // leave the title no room on its line.
                    ListTile(
                      title: Text(l.settingsLetterStripSide),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SegmentedButton<LetterStripSide>(
                            segments: [
                              ButtonSegment(
                                  value: LetterStripSide.left,
                                  label: Text(l.settingsLetterStripLeft)),
                              ButtonSegment(
                                  value: LetterStripSide.right,
                                  label: Text(l.settingsLetterStripRight)),
                            ],
                            selected: {s.letterStripSide},
                            onSelectionChanged: (set) async {
                              if (set.isEmpty) return;
                              await s.setLetterStripSide(set.first);
                              if (mounted) setState(() {});
                            },
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: VelvetColors.primary,
                              selectedForegroundColor: VelvetColors.onPrimary,
                              foregroundColor: VelvetColors.textPrimary,
                              side: BorderSide(color: VelvetColors.border2),
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Android-only: nothing else can be opened *with* a torrent,
                // so on other platforms these rows would control nothing.
                if (TorrentChannel.isSupported) ...[
                  // Stored as "skip", shown as "ask" — the sheet's own
                  // checkbox is what sets it, and this is the only way back
                  // from that box.
                  _SwitchRow(
                    title: l.settingsTorrentAskTitle,
                    value: !s.torrentSkipChooser,
                    onChanged: (v) async {
                      setState(() {});
                      await s.setTorrentSkipChooser(!v);
                      if (mounted) setState(() {});
                    },
                  ),
                  // Paired with the switch above: that one decides what
                  // mStream does with a torrent it receives, this one whether
                  // it receives them at all. Also the only in-app way back
                  // from having made some other app the default.
                  _ValueRow(
                    title: l.settingsTorrentDefaultTitle,
                    trailing: Icon(Icons.open_in_new,
                        size: 20,
                        color: VelvetColors.textSecondary,
                        semanticLabel: l.settingsTorrentDefaultSub),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final failed = !await TorrentChannel.openDefaultSettings();
                      if (failed && context.mounted) {
                        messenger.showSnackBar(SnackBar(
                            content: Text(AppLocalizations.of(context)
                                .settingsTorrentDefaultFailed)));
                      }
                    },
                  ),
                ],
              ],
            ),
            // The visualizer rows are Android-only features (the projectM/EGL
            // visualizer's tuning, imported shaders); iOS decodes the stream
            // itself and has nothing to set. Cast resolution lives in the cast
            // picker, under the checkbox it depends on.
            if (Platform.isAndroid)
              _Section(
                header: l.settingsSectionVisualizer,
                children: [
                  _ValueRow(
                    title: l.settingsVisualizerSource,
                    value: s.visualizerAudioSource.label(l),
                    onTap: _pickVisualizerSource,
                  ),
                  _SwitchRow(
                    title: l.settingsVisualizerKnobs,
                    subtitle: l.settingsVisualizerKnobsSubtitle,
                    value: s.showVisualizerKnobs,
                    onChanged: (v) async {
                      setState(() {});
                      await s.setShowVisualizerKnobs(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  _ValueRow(
                    title: l.importedShadersTitle,
                    value: (_shaderCount ?? 0) > 0 ? '$_shaderCount' : null,
                    chevron: true,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ImportedShadersScreen()),
                      );
                      _countShaders();
                    },
                  ),
                ],
              ),
            _Section(
              header: l.listeningTitle,
              footer: l.settingsHistoryFooter,
              children: [
                _SwitchRow(
                  title: l.settingsHistoryEnabled,
                  value: s.historyEnabled,
                  onChanged: _setHistoryEnabled,
                ),
                // Independent of recording: a server's stats can include this
                // phone while it keeps no record of its own.
                _SwitchRow(
                  title: l.settingsHistorySend,
                  subtitle: s.historySendToServer && _unsynced > 0
                      ? l.listeningUnsynced(_unsynced)
                      : null,
                  value: s.historySendToServer,
                  onChanged: (v) async {
                    setState(() {});
                    await s.setHistorySendToServer(v);
                    if (mounted) setState(() {});
                  },
                ),
                _ValueRow(
                  title: l.settingsHistoryClear,
                  value: bytes == null
                      ? null
                      : historyEmpty
                          ? l.settingsHistoryEmpty
                          : _fmtBytes(bytes),
                  enabled: !historyEmpty,
                  onTap: _clearHistory,
                ),
              ],
            ),
            _Section(
              children: [
                _ValueRow(
                  title: l.settingsReset,
                  titleColor: VelvetColors.error,
                  onTap: _reset,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // A picker sheet for a value row; applies the pick and rebuilds. A pick
  // of the current value (or a dismissal) changes nothing.
  Future<void> _choose<T>(String title, T selected,
      List<ChoiceOption<T>> options, Future<void> Function(T) apply) async {
    final picked = await showChoiceSheet<T>(context,
        title: title, options: options, selected: selected);
    if (picked == null || picked.value == selected) return;
    await apply(picked.value);
    if (mounted) setState(() {});
  }

  Future<void> _pickTheme() {
    final l = AppLocalizations.of(context);
    return _choose<AppTheme>(
      l.settingsTheme,
      SettingsManager().appTheme,
      [
        for (final t in AppTheme.values)
          ChoiceOption(t, t.label(l), preview: _ThemeSwatch(t)),
      ],
      SettingsManager().setAppTheme,
    );
  }

  Future<void> _pickPlayerLayout() {
    final l = AppLocalizations.of(context);
    return _choose<PlayerLayout>(
      l.settingsPlayerLayout,
      SettingsManager().playerLayout,
      [
        for (final p in PlayerLayout.values)
          ChoiceOption(p, _playerLayoutLabel(l, p),
              preview: _LayoutThumb(p)),
      ],
      SettingsManager().setPlayerLayout,
    );
  }

  Future<void> _pickLanguage() {
    final l = AppLocalizations.of(context);
    // "System default" (null) first, then one entry per supported locale by
    // name — derived from the generated supportedLocales so new ARB files
    // appear automatically.
    final codes = [
      for (final loc in AppLocalizations.supportedLocales) loc.languageCode,
    ]..sort((a, b) => (kLanguageEndonyms[a] ?? a)
        .compareTo(kLanguageEndonyms[b] ?? b));
    return _choose<String?>(
      l.settingsLanguage,
      SettingsManager().language,
      [
        ChoiceOption<String?>(null, l.languageSystemDefault),
        for (final code in codes)
          ChoiceOption<String?>(code, kLanguageEndonyms[code] ?? code,
              locale: Locale(code)),
      ],
      SettingsManager().setLanguage,
    );
  }

  Future<void> _pickTapBehavior() {
    final l = AppLocalizations.of(context);
    return _choose<TapBehavior>(
      l.settingsTapBehavior,
      SettingsManager().tapBehavior,
      [
        for (final b in TapBehavior.values)
          ChoiceOption(b, b.label(l), hint: _tapBehaviorHint(l, b)),
      ],
      SettingsManager().setTapBehavior,
    );
  }

  Future<void> _pickStartupView() {
    final l = AppLocalizations.of(context);
    return _choose<StartupView>(
      l.settingsStartupPage,
      SettingsManager().startupView,
      [
        // "Recent" is the home tile's name for recently ADDED — say so here,
        // where it could be read as recently played.
        for (final v in StartupView.values)
          ChoiceOption(v, v.label(l),
              hint: v == StartupView.recent ? l.settingsStartupRecentHint : null),
      ],
      SettingsManager().setStartupView,
    );
  }

  Future<void> _pickVisualizerSource() {
    final l = AppLocalizations.of(context);
    return _choose<VisualizerAudioSource>(
      l.settingsVisualizerSource,
      SettingsManager().visualizerAudioSource,
      [
        for (final s in VisualizerAudioSource.values)
          ChoiceOption(s, s.label(l), hint: _visualizerSourceHint(l, s)),
      ],
      _setVisualizerSource,
    );
  }

  // Switching to "real" walks the user through the microphone permission
  // with an up-front explanation of why a music app asks for it — unless
  // Android already granted it. On a refusal the setting stays as it was.
  Future<void> _setVisualizerSource(VisualizerAudioSource v) async {
    if (v == VisualizerAudioSource.real) {
      // Shared with the drawer's visualizer launcher — see
      // util/real_audio_permission.
      final ok = await confirmRealAudioPermission(context);
      if (!ok) return;
    }
    await SettingsManager().setVisualizerAudioSource(v);
  }

  // Turning recording off deletes this phone's record — unsent plays
  // included — so it asks first; turning it on is instant.
  Future<void> _setHistoryEnabled(bool v) async {
    if (!v) {
      final l = AppLocalizations.of(context);
      final ok = await fedConfirm(context,
          title: l.settingsHistoryOffTitle,
          message: l.settingsHistoryOffBody(PlayHistory().outboxCount),
          confirmLabel: l.settingsHistoryOffConfirm,
          danger: true);
      if (!ok || !mounted) return;
    }
    setState(() {});
    await SettingsManager().setHistoryEnabled(v);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    final l = AppLocalizations.of(context);
    final ok = await fedConfirm(context,
        title: l.settingsHistoryClearTitle,
        message: l.settingsHistoryClearConfirm(
            _fmtBytes(_historyBytes ?? 0), PlayHistory().outboxCount),
        confirmLabel: l.clear,
        danger: true);
    if (!ok) return;
    await PlayHistory().clear();
    showGlobalSnack(l.settingsHistoryCleared);
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    // The equalizer is Android-only, so only Android's copy names it.
    final ok = await fedConfirm(context,
        title: l.settingsResetTitle,
        message: Platform.isAndroid ? l.settingsResetBody : l.settingsResetBodyIos,
        confirmLabel: l.reset,
        danger: true);
    if (!ok) return;
    final eqWasOn = SettingsManager().eqEnabled;
    await SettingsManager().resetAll();
    // Reset turns the queue downloads off: drop the transfers held for
    // Wi-Fi, as the switch does.
    unawaited(DownloadManager().cancelWifiHeld());
    // resetAll writes the EQ fields directly; the live engine keeps its
    // curve (and the five-band player its pipeline) until told.
    unawaited(MediaManager().audioHandler.resetEqualizer(wasOn: eqWasOn));
    if (mounted) setState(() {});
    // App-wide messenger so the toast doesn't depend on this screen's
    // context surviving the await.
    showGlobalSnack(l.settingsResetDone);
  }

  String _languageLabel(AppLocalizations l, String? code) => code == null
      ? l.languageSystemDefault
      : (kLanguageEndonyms[code] ?? code);

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

  String _visualizerSourceHint(AppLocalizations l, VisualizerAudioSource s) {
    switch (s) {
      case VisualizerAudioSource.synthesized:
        return l.visualizerSourceSubtitleSynthesized;
      case VisualizerAudioSource.real:
        return l.visualizerSourceSubtitleReal;
    }
  }

  String _tapBehaviorHint(AppLocalizations l, TapBehavior b) {
    switch (b) {
      case TapBehavior.addToQueue:
        return l.tapSubtitleAddToQueue;
      case TapBehavior.playFromHere:
        return l.tapSubtitlePlayFromHere;
      case TapBehavior.appendAndJump:
        return l.tapSubtitleAppendAndJump;
    }
  }

  // Prompt for the auto-download retention limit. 0 (or empty) = unlimited.
  // Applying a lower value evicts down to it immediately — a deliberate,
  // user-initiated moment, the only place besides a fresh auto-download where
  // eviction is allowed to run.
  Future<void> _editAutoDownloadCap() async {
    final current = SettingsManager().autoDownloadCap;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _AutoDownloadCapDialog(current: current),
    );
    if (result == null) return;
    final lowered = result != 0 &&
        (current == 0 || result < current); // 0 = unlimited (never lower)
    await SettingsManager().setAutoDownloadCap(result);
    if (lowered) unawaited(DownloadManager().enforceAutoDownloadCap());
    if (mounted) setState(() {});
  }

  String _fmtBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// A group on the page: an upper-cased accent header, a card of rows, and an
/// optional grey footer — the one place a group explains itself. No header
/// leaves a plain gap (Reset, alone at the end).
class _Section extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const _Section({this.header, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    final footer = this.footer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Semantics(
              header: true,
              child: Text(
                header.toUpperCase(),
                style: TextStyle(
                  color: VelvetColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: VelvetColors.card,
            borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: footer == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    footer,
                    style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
        ),
      ],
    );
  }
}

/// A row that shows its current value (or a swatch, an icon) at the trailing
/// edge, with an optional chevron when it opens a page.
class _ValueRow extends StatelessWidget {
  final String title;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final bool chevron;
  final bool enabled;
  final Color? titleColor;
  final VoidCallback? onTap;

  const _ValueRow({
    required this.title,
    this.value,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.enabled = true,
    this.titleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final trailing = this.trailing;
    final ends = <Widget>[
      if (value != null)
        // Long values (a German label, a long endonym) ellipsize rather than
        // squeeze the title to nothing.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
                color: enabled
                    ? VelvetColors.textSecondary
                    : VelvetColors.textTertiary,
                fontSize: 14),
          ),
        ),
      ?trailing,
      if (chevron)
        Icon(Icons.chevron_right, color: VelvetColors.textSecondary, size: 20),
    ];
    return ListTile(
      leading: leading,
      title: Text(title,
          style: titleColor == null ? null : TextStyle(color: titleColor)),
      trailing: ends.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: ends,
            ),
      enabled: enabled,
      onTap: onTap,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: VelvetColors.primary,
    );
  }
}

/// Rows that belong to the row above: indented behind a rule, and folded
/// away while that row is off, so the page says the dependency instead of a
/// sentence.
class _Nested extends StatelessWidget {
  final bool visible;
  final List<Widget> children;

  const _Nested({required this.visible, required this.children});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: visible
          ? Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 0, 8),
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(color: VelvetColors.border, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// A theme's palette in a chip: its background, a card, and the accent —
/// a custom accent replaces every theme's own, so the chip shows that one.
class _ThemeSwatch extends StatelessWidget {
  final AppTheme theme;

  const _ThemeSwatch(this.theme);

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(theme);
    final custom = SettingsManager().accentColor;
    final accent = custom == null ? p.primary : Color(custom);
    return Container(
      width: 44,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Row(
        spacing: 4,
        children: [
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

/// A Now Playing layout drawn small: the slim bar, the banner, centred art,
/// hero art — each above the queue it leaves room for.
class _LayoutThumb extends StatelessWidget {
  final PlayerLayout layout;

  const _LayoutThumb(this.layout);

  @override
  Widget build(BuildContext context) {
    Widget line({double? width, double height = 3, Color? color}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color ?? VelvetColors.border,
            borderRadius: BorderRadius.circular(1),
          ),
        );
    Widget art(double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: VelvetColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        );
    final title = VelvetColors.textTertiary;
    final children = switch (layout) {
      PlayerLayout.small => [
          line(height: 8, color: VelvetColors.border2),
          for (var i = 0; i < 7; i++) line(),
        ],
      PlayerLayout.medium => [
          Row(
            spacing: 3,
            children: [
              art(14),
              Expanded(
                child: Column(
                  spacing: 3,
                  children: [line(color: title), line(color: title)],
                ),
              ),
            ],
          ),
          for (var i = 0; i < 5; i++) line(),
        ],
      PlayerLayout.large => [
          art(20),
          line(width: 24, color: title),
          for (var i = 0; i < 4; i++) line(),
        ],
      PlayerLayout.xl => [
          art(30),
          line(width: 24, color: title),
          for (var i = 0; i < 2; i++) line(),
        ],
    };
    return Container(
      width: 40,
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VelvetColors.bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: VelvetColors.border),
      ),
      child: Column(
        spacing: 3,
        crossAxisAlignment: layout == PlayerLayout.large ||
                layout == PlayerLayout.xl
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// Number prompt for the auto-download retention limit; pops with the parsed
// value (empty or 0 = unlimited), null on cancel. Stateful for the same reason
// as add_server's _NewFolderDialog: the controller must outlive the dialog's
// exit animation.
class _AutoDownloadCapDialog extends StatefulWidget {
  final int current;
  const _AutoDownloadCapDialog({required this.current});

  @override
  State<_AutoDownloadCapDialog> createState() => _AutoDownloadCapDialogState();
}

class _AutoDownloadCapDialogState extends State<_AutoDownloadCapDialog> {
  late final _ctrl = TextEditingController(
      text: widget.current <= 0 ? '' : '${widget.current}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: VelvetColors.surface,
      title: Text(l.settingsAutoDownloadCap,
          style: TextStyle(color: VelvetColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.settingsAutoDownloadCapDialogBody,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 13)),
          SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: VelvetColors.textPrimary),
            decoration: InputDecoration(
              labelText: l.settingsAutoDownloadCapField,
              hintText: l.settingsAutoDownloadCapUnlimited,
              helperText: l.settingsAutoDownloadCapHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel,
                style: TextStyle(color: VelvetColors.textSecondary))),
        TextButton(
            onPressed: () {
              final v = int.tryParse(_ctrl.text.trim()) ?? 0;
              Navigator.of(context).pop(v < 0 ? 0 : v);
            },
            child: Text(l.save)),
      ],
    );
  }
}
