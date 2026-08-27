import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../singletons/downloads.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/real_audio_permission.dart';
import '../widgets/accent_color_sheet.dart';

/// First-run setup, shown once after the user's first server is added (see
/// main.dart's serverListStream listener). Deliberately the shape people
/// already know from other apps: swipeable pages, dots, Back/Next, Skip.
///
/// Every page writes straight through to [SettingsManager], so a user who
/// backs out mid-flow keeps whatever they already picked. Leaving by ANY route
/// — Continue, Skip, system Back — marks onboarding done, so this never
/// reappears.
class SetupFlowScreen extends StatefulWidget {
  /// Whether leaving the flow marks onboarding done. True on the real first
  /// run. The debug drawer entry passes false so previewing the pages doesn't
  /// burn the flag and suppress the genuine first-run flow afterwards.
  final bool markCompleteOnExit;

  const SetupFlowScreen({super.key, this.markCompleteOnExit = true});

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen> {
  final _controller = PageController();
  int _page = 0;

  /// Real-audio capture goes through `android.media.audiofx.Visualizer`, so
  /// the page is meaningless anywhere else — iOS, macOS, Windows and Linux
  /// drop straight from the accent page to playback.
  static final bool _hasVisualizerPage = Platform.isAndroid;

  late final List<Widget Function(AppLocalizations)> _pages = [
    _accentPage,
    if (_hasVisualizerPage) _visualizerPage,
    _playbackPage,
    _offlinePage,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  void _back() => _controller.previousPage(
      duration: const Duration(milliseconds: 260), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLast = _page == _pages.length - 1;

    return PopScope(
      // Marks completion however the route leaves — Continue and Skip both pop,
      // and so does system Back, so this one hook covers all three.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.markCompleteOnExit) {
          unawaited(SettingsManager().setOnboardingComplete(true));
        }
      },
      child: Scaffold(
        backgroundColor: VelvetColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        l.setupTitle,
                        style: TextStyle(
                          color: VelvetColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    // Nothing left to skip on the closing page.
                    if (!isLast)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l.setupSkip,
                          style: TextStyle(color: VelvetColors.textSecondary),
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [for (final p in _pages) p(l)],
                ),
              ),
              _dots(),
              _navBar(l, isLast),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _pages.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _page ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    i == _page ? VelvetColors.primary : VelvetColors.border2,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navBar(AppLocalizations l, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          // Kept in the layout (not just hidden) on page one so the Next
          // button doesn't jump sideways between pages.
          SizedBox(
            width: 96,
            child: _page == 0
                ? null
                : TextButton(
                    onPressed: _back,
                    child: Text(l.setupBack,
                        style: TextStyle(color: VelvetColors.textSecondary)),
                  ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              foregroundColor: onAccent(VelvetColors.primary),
              minimumSize: const Size(140, 48),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: Text(isLast ? l.setupFinish : l.setupNext),
          ),
        ],
      ),
    );
  }

  // --- pages -------------------------------------------------------------

  // Shared page chrome: big icon, title, body, then whatever control the page
  // owns. Scrollable so a large text scale or a short screen doesn't overflow.
  Widget _pageShell(
      {required IconData icon,
      required String title,
      String? body,
      required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: VelvetColors.primaryDim,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: VelvetColors.primary),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }

  Widget _accentPage(AppLocalizations l) {
    final current = SettingsManager().accentColor;
    // What reverting looks like: the active theme's own primary.
    final themeDefault = paletteFor(SettingsManager().appTheme).primary;

    void pick(int? argb) {
      // setAccentColor re-emits the accent stream, which rebuilds MaterialApp
      // — the whole app (this page included) recolours as you tap.
      SettingsManager().setAccentColor(argb);
      setState(() {});
    }

    return _pageShell(
      icon: Icons.palette_outlined,
      title: l.setupAccentTitle,
      body: l.setupAccentBody,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: [
          // No reset icon here (unlike the Settings sheet): on this screen the
          // theme default is just the starting colour, not a "revert" action,
          // and the glyph made the first swatch read as a different kind of
          // control than the seven beside it. It keeps the tooltip and the
          // selected check like every other swatch.
          AccentSwatch(
            color: themeDefault,
            selected: current == null,
            tooltip: l.accentThemeDefault,
            onTap: () => pick(null),
          ),
          for (final c in accentPresetsFor(themeDefault))
            AccentSwatch(
              color: c,
              selected: current == accentArgb(c),
              onTap: () => pick(accentArgb(c)),
            ),
        ],
      ),
    );
  }

  Widget _visualizerPage(AppLocalizations l) {
    final on =
        SettingsManager().visualizerAudioSource == VisualizerAudioSource.real;

    Future<void> toggle(bool want) async {
      if (want) {
        // Explanation dialog + OS prompt; a refusal leaves the switch off.
        final ok = await confirmRealAudioPermission(context);
        if (!ok) return;
      }
      await SettingsManager().setVisualizerAudioSource(
          want ? VisualizerAudioSource.real : VisualizerAudioSource.synthesized);
      if (mounted) setState(() {});
    }

    return _pageShell(
      icon: Icons.graphic_eq,
      title: l.setupVisualizerTitle,
      body: l.setupVisualizerBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: VelvetColors.card,
              border: Border.all(color: VelvetColors.border),
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
            ),
            child: SwitchListTile(
              title: Text(
                VisualizerAudioSource.real.label(l),
                style: TextStyle(color: VelvetColors.textPrimary),
              ),
              value: on,
              onChanged: toggle,
              activeThumbColor: VelvetColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mic_none, size: 18, color: VelvetColors.warning),
              const SizedBox(width: 10),
              Expanded(
                // Two spans rather than one string: the closing reassurance is
                // underlined, and the split has to survive translation — a
                // substring match for "the last sentence" would break the
                // moment a locale punctuates differently.
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l.setupVisualizerWarning} '),
                      TextSpan(
                        text: l.setupVisualizerNoMic,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: VelvetColors.textTertiary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playbackPage(AppLocalizations l) {
    final current = SettingsManager().tapBehavior;
    return _pageShell(
      icon: Icons.touch_app_outlined,
      title: l.setupPlaybackTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in _tapOrder)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _choice(
                title: b.label(l),
                subtitle: _tapSubtitle(l, b),
                selected: b == current,
                onTap: () async {
                  await SettingsManager().setTapBehavior(b);
                  if (mounted) setState(() {});
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Tap-behaviour options in the order this page offers them: the fresh-
  /// install default leads, rather than sitting third because that is where it
  /// happens to fall in the enum's declaration order. Settings still lists
  /// them in declaration order.
  static const List<TapBehavior> _tapOrder = [
    TapBehavior.playFromHere,
    TapBehavior.addToQueue,
    TapBehavior.appendAndJump,
  ];

  /// Cap choices for the stepper: a low 10 to keep a small cache reachable,
  /// then 25 at a time, then "keep everything". 0 means unlimited and sits
  /// LAST so "+" always reads as "keep more" — at its numeric position the
  /// control would step from 10 straight to unlimited going down.
  static const List<int> _capSteps = [
    10, 25, 50, 75, 100, 125, 150, 175, 200, 0, //
  ];

  /// Index into [_capSteps] for the stored cap, snapping a value typed in
  /// Settings (which allows any number) to the nearest offered step.
  int get _capIndex {
    final cap = SettingsManager().autoDownloadCap;
    if (cap <= 0) return _capSteps.length - 1; // unlimited
    var best = 0;
    for (var i = 1; i < _capSteps.length - 1; i++) {
      if ((_capSteps[i] - cap).abs() < (_capSteps[best] - cap).abs()) best = i;
    }
    return best;
  }

  Widget _offlinePage(AppLocalizations l) {
    final on = SettingsManager().offlineQueue;
    final idx = _capIndex;

    Future<void> setCap(int i) async {
      final next = i.clamp(0, _capSteps.length - 1);
      if (next == idx) return;
      await SettingsManager().setAutoDownloadCap(_capSteps[next]);
      if (mounted) setState(() {});
      // No enforceAutoDownloadCap() here: nothing has been auto-downloaded yet
      // on a first run, and a lowered cap is applied on the next download.
    }

    return _pageShell(
      icon: Icons.download_for_offline_outlined,
      title: l.setupOfflineTitle,
      body: l.settingsOfflineQueueSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: VelvetColors.card,
              border: Border.all(color: VelvetColors.border),
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
            ),
            child: SwitchListTile(
              title: Text(
                l.settingsOfflineQueue,
                style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
              ),
              value: on,
              onChanged: (v) async {
                await SettingsManager().setOfflineQueue(v);
                if (v) {
                  // Sweep whatever is already queued instead of waiting for the
                  // next queue edit — mirrors the Settings toggle.
                  unawaited(DownloadManager().sweepQueueNow());
                } else {
                  // Wi-Fi-held tasks survive restarts; drop them so they can't
                  // fire long after the user said stop.
                  unawaited(DownloadManager().cancelWifiHeld());
                }
                if (mounted) setState(() {});
              },
              activeThumbColor: VelvetColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Only meaningful while the switch is on; dimmed and inert otherwise
          // rather than hidden, so the option is discoverable either way.
          Opacity(
            opacity: on ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !on,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: VelvetColors.card,
                  border: Border.all(color: VelvetColors.border),
                  borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.settingsAutoDownloadCap,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _stepButton(Icons.remove, idx > 0, () => setCap(idx - 1)),
                    SizedBox(
                      width: 74,
                      child: Text(
                        _capSteps[idx] <= 0
                            ? l.settingsAutoDownloadCapUnlimited
                            : '${_capSteps[idx]}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VelvetColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _stepButton(Icons.add, idx < _capSteps.length - 1,
                        () => setCap(idx + 1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, bool enabled, VoidCallback onTap) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 22,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: 20,
          color:
              enabled ? VelvetColors.textSecondary : VelvetColors.textDim,
        ),
      ),
    );
  }

  // Radio-style option card. Hand-rolled rather than RadioListTile: the app
  // styles its own surfaces, and this keeps the whole row a hit target.
  Widget _choice({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? VelvetColors.primaryDim : VelvetColors.card,
          border: Border.all(
            color: selected ? VelvetColors.primary : VelvetColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color:
                  selected ? VelvetColors.primary : VelvetColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _tapSubtitle(AppLocalizations l, TapBehavior b) {
    switch (b) {
      case TapBehavior.addToQueue:
        return l.tapSubtitleAddToQueue;
      case TapBehavior.playFromHere:
        return l.tapSubtitlePlayFromHere;
      case TapBehavior.appendAndJump:
        return l.tapSubtitleAppendAndJump;
    }
  }
}
