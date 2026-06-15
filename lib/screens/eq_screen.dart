// Graphic equalizer UI for the Android-native AndroidEqualizer that
// audio_stuff.dart attaches to the player's AudioPipeline.
//
// The handler-side plumbing (AndroidEqualizer attach, _applySavedEqualizer
// on init, SettingsManager.eqEnabled / eqBandGains persistence) was
// landed by another agent. This screen renders the user-facing
// controls and writes back via the same persistence hooks.
//
// What you get:
//   * Enable/disable toggle (drives AndroidEqualizer.setEnabled +
//     SettingsManager.setEqEnabled)
//   * N vertical sliders, one per band reported by the device's
//     native equalizer (typically 5 on Samsung, varies by SoC). Each
//     slider streams its gain via AndroidEqualizerBand.gainStream so
//     UI stays in sync with audio.
//   * Reset-to-flat in the AppBar
//
// Persistence: gains are written to settings.json on onChangeEnd
// (not on every drag tick) to avoid thrashing the JSON file.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../media/cast_target.dart';
import '../singletons/cast_manager.dart';
import '../l10n/app_localizations.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';

// Why the EQ couldn't be shown. Stored as a kind (not a localized
// string) so the message is resolved against the active locale at
// render time and stays correct if the language changes.
enum _EqError { onlyAndroid, needsPlayback, initFailed, casting }

class EqScreen extends StatefulWidget {
  const EqScreen({super.key});

  @override
  State<EqScreen> createState() => _EqScreenState();
}

class _EqScreenState extends State<EqScreen> {
  AndroidEqualizerParameters? _params;
  bool _loading = true;
  _EqError? _errorKind;
  // Raw exception text for _EqError.initFailed (not translated).
  String? _errorDetail;
  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<CastTarget>? _castSub;

  @override
  void initState() {
    super.initState();
    _attemptLoad();
    // AndroidEqualizer.parameters only resolves once the native
    // audio session is alive — i.e. something's been queued. If the
    // user opens this screen with an idle queue, the initial attempt
    // times out. Watch playback state and retry the moment audio
    // actually starts, so the user can queue something and come
    // back without having to navigate out and back in.
    _playbackSub = MediaManager().audioHandler.playbackState.listen((state) {
      if (_params == null &&
          !CastManager().isCasting &&
          state.processingState != AudioProcessingState.idle) {
        _attemptLoad();
      }
    });
    // The EQ only affects local playback. React to cast connect/disconnect so
    // the screen swaps between the sliders and an explanatory message instead
    // of leaving stale, inert controls on screen while audio is on the TV.
    _castSub = CastManager().activeTargetStream.listen((_) {
      if (!mounted) return;
      if (CastManager().isCasting) {
        setState(() {
          _params = null;
          _loading = false;
          _errorKind = _EqError.casting;
        });
      } else {
        setState(() {
          _params = null;
          _loading = true;
          _errorKind = null;
        });
        _attemptLoad();
      }
    });
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _castSub?.cancel();
    super.dispose();
  }

  Future<void> _attemptLoad() async {
    // While casting, the active backend has no equalizer; show why rather than
    // the generic "Android only" message (which is wrong — we *are* on Android).
    if (CastManager().isCasting) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _params = null;
        _errorKind = _EqError.casting;
      });
      return;
    }
    final eq = MediaManager().audioHandler.equalizer;
    if (eq == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKind = _EqError.onlyAndroid;
      });
      return;
    }
    // Already loaded — nothing to do (guards against the playback
    // listener firing a duplicate fetch after we've succeeded once).
    if (_params != null) return;

    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorKind = null;
      _errorDetail = null;
    });

    try {
      // 3s is plenty when the session is alive (resolves in ms);
      // when it isn't, the wait would otherwise be unbounded.
      final p = await eq.parameters.timeout(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _params = p;
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKind = _EqError.needsPlayback;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKind = _EqError.initFailed;
        _errorDetail = '$e';
      });
    }
  }

  Future<void> _setEnabled(bool v) async {
    final eq = MediaManager().audioHandler.equalizer;
    if (eq == null) return;
    await eq.setEnabled(v);
    await SettingsManager().setEqEnabled(v);
  }

  // Snapshot the current band gains and write them to settings.json.
  // Called on slider release (not on every drag tick) so the file
  // isn't rewritten dozens of times per gesture.
  Future<void> _persistGains() async {
    if (_params == null) return;
    final gains = _params!.bands.map((b) => b.gain).toList();
    await SettingsManager().setEqBandGains(gains);
  }

  Future<void> _resetToFlat() async {
    if (_params == null) return;
    for (final band in _params!.bands) {
      await band.setGain(0);
    }
    await _persistGains();
  }

  // 60 → "60", 1000 → "1k", 1500 → "1.5k", 14000 → "14k"
  String _formatFreq(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return k == k.roundToDouble()
          ? '${k.round()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '${hz.round()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).eqTitle),
        actions: [
          if (_params != null && _params!.bands.isNotEmpty)
            TextButton(
              onPressed: _resetToFlat,
              child: Text(
                AppLocalizations.of(context).reset,
                style: TextStyle(
                  color: VelvetColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: VelvetColors.primary),
      );
    }
    if (_errorKind != null) {
      final String msg;
      switch (_errorKind!) {
        case _EqError.onlyAndroid:
          msg = l.eqOnlyAndroid;
          break;
        case _EqError.needsPlayback:
          msg = l.eqNeedsPlayback;
          break;
        case _EqError.initFailed:
          msg = l.eqInitFailed(_errorDetail ?? '');
          break;
        case _EqError.casting:
          msg = l.eqCasting;
          break;
      }
      return Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: VelvetColors.textSecondary),
          ),
        ),
      );
    }
    final p = _params!;
    if (p.bands.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            l.eqNoBands,
            textAlign: TextAlign.center,
            style: TextStyle(color: VelvetColors.textSecondary),
          ),
        ),
      );
    }

    final eq = MediaManager().audioHandler.equalizer!;

    return Column(
      children: [
        // Enable/disable — reactive via the equalizer's enabledStream
        // so external mutations (e.g. settings sync, app restart)
        // reflect here too. Initial value seeded from the persisted
        // setting so the switch shows the right state before the
        // first stream emission.
        StreamBuilder<bool>(
          stream: eq.enabledStream,
          initialData: SettingsManager().eqEnabled,
          builder: (context, snap) {
            final on = snap.data ?? false;
            return SwitchListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                l.eqTitle,
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                on ? l.eqEnabledOn : l.eqEnabledOff,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 12),
              ),
              value: on,
              onChanged: _setEnabled,
              activeThumbColor: VelvetColors.primary,
            );
          },
        ),
        Divider(height: 1, color: VelvetColors.border),
        // dB range labels above the sliders, aligned to the rail
        // positions (min on the left, 0 in the middle, max on the
        // right) so the user can read the absolute span at a glance.
        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Text(
                '${p.minDecibels.toStringAsFixed(0)} dB',
                style: TextStyle(
                    color: VelvetColors.textTertiary, fontSize: 10),
              ),
              Spacer(),
              Text(
                '0 dB',
                style: TextStyle(
                    color: VelvetColors.textTertiary, fontSize: 10),
              ),
              Spacer(),
              Text(
                '+${p.maxDecibels.toStringAsFixed(0)} dB',
                style: TextStyle(
                    color: VelvetColors.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: p.bands
                  .map((band) => Expanded(child: _buildBandSlider(band, p)))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBandSlider(
      AndroidEqualizerBand band, AndroidEqualizerParameters p) {
    return StreamBuilder<double>(
      stream: band.gainStream,
      initialData: band.gain,
      builder: (context, snap) {
        final gain = (snap.data ?? 0).clamp(p.minDecibels, p.maxDecibels);
        final sign = gain >= 0 ? '+' : '';
        return Column(
          children: [
            SizedBox(height: 12),
            // Live gain readout in dB — updates as the user drags.
            Text(
              '$sign${gain.toStringAsFixed(1)}',
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'dB',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 9),
            ),
            SizedBox(height: 4),
            // Vertical slider via RotatedBox. Three-quarter rotation
            // puts "0" at the top and "max gain" at the top — the
            // standard graphical-EQ orientation.
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: VelvetColors.primary,
                    thumbColor: VelvetColors.primary,
                    inactiveTrackColor: VelvetColors.border,
                    overlayColor: VelvetColors.primaryDim,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: gain,
                    min: p.minDecibels,
                    max: p.maxDecibels,
                    // setGain is fire-and-forget per drag tick so
                    // audio responds immediately; gainStream will
                    // bring the readout above into sync.
                    onChanged: (v) {
                      band.setGain(v);
                    },
                    onChangeEnd: (_) => _persistGains(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              _formatFreq(band.centerFrequency),
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Hz',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 9),
            ),
            SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
