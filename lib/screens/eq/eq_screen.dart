// Graphic equalizer UI for the Android-native AndroidEqualizer that
// LocalPlaybackBackend attaches to the player's AudioPipeline while the EQ is
// on. The state lives in EqController (eq_controller.dart); this file only
// renders it:
//
//   * the enable switch (always shown on Android — it is how the user turns
//     the EQ on while the pipeline, and so the equalizer object, does not
//     exist yet), locked while casting or mid-toggle;
//   * one vertical slider per band the device reports, filled from 0 dB to
//     the thumb (not from the bottom), with the live gain above and the
//     centre frequency below;
//   * a row of preset chips (eq_presets.dart) above the bands; the chip
//     whose curve the gains spell is the selected one, so a drag deselects;
//   * a dB axis on the left and a 0 dB guide across the bands, both placed
//     from the same rail geometry the sliders use;
//   * Reset-to-flat in the AppBar.
//
// Gains go to the native effect on every drag tick (audio follows the thumb)
// and to settings on release only.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import 'eq_controller.dart';
import 'eq_presets.dart';

/// How far each rail stops short of its column's ends (the overlay radius):
/// the slider's track rect and the axis/guide positions are all derived from
/// this one number, which is what keeps them aligned.
const double kEqRailInset = 14;

/// Height of the label slot above (gain) and below (frequency) each rail.
const double kEqLabelSlot = 36;

class EqScreen extends StatefulWidget {
  const EqScreen({super.key, this.controller});

  /// Supplied by tests; the app builds one over the live audio side.
  final EqController? controller;

  @override
  State<EqScreen> createState() => _EqScreenState();
}

class _EqScreenState extends State<EqScreen> {
  late final EqController _controller =
      widget.controller ?? EqController(LiveEqAudio());

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.eqTitle),
            actions: [
              if (c.status == EqStatus.ready)
                TextButton(
                  onPressed: c.resetToFlat,
                  child: Text(
                    l.reset,
                    style: TextStyle(
                      color: VelvetColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: c.status == EqStatus.unsupported
                ? _Message(l.eqOnlyAndroid)
                : Column(
                    children: [
                      _EnableTile(c),
                      Divider(height: 1, color: VelvetColors.border),
                      Expanded(child: _body(c, l)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _body(EqController c, AppLocalizations l) => switch (c.status) {
        EqStatus.unsupported => _Message(l.eqOnlyAndroid),
        EqStatus.casting => _Message(l.eqCasting),
        EqStatus.off => _Message(l.eqDisabledHint),
        EqStatus.needsPlayback => _Message(l.eqNeedsPlayback),
        EqStatus.failed => _Message(l.eqInitFailed(c.failure ?? 'timeout')),
        EqStatus.noBands => _Message(l.eqNoBands),
        EqStatus.busy || EqStatus.loading => Center(
            child: CircularProgressIndicator(color: VelvetColors.primary),
          ),
        EqStatus.ready => Column(
            children: [
              _PresetRow(c),
              Expanded(
                child: _BandPanel(params: c.params!, onRelease: c.saveGains),
              ),
            ],
          ),
      };
}

class _EnableTile extends StatelessWidget {
  const _EnableTile(this.controller);
  final EqController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        l.eqTitle,
        style: TextStyle(
            color: VelvetColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        controller.enabled ? l.eqEnabledOn : l.eqEnabledOff,
        style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
      ),
      value: controller.enabled,
      onChanged: controller.canToggle ? controller.setEnabled : null,
      activeThumbColor: VelvetColors.primary,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: VelvetColors.textSecondary),
        ),
      ),
    );
  }
}

/// Where the rails sit inside a column of a given height: both label slots
/// and both insets off, max gain at the top. Shared by the sliders (through
/// [_ZeroCenteredTrack]), the axis and the 0 dB guide.
class _Rail {
  const _Rail(this.columnHeight);
  final double columnHeight;

  double get top => kEqLabelSlot + kEqRailInset;
  double get length => math.max(0, columnHeight - 2 * top);

  /// Screen y of the point `fraction` of the way from the min end (bottom)
  /// to the max end (top).
  double yFor(double fraction) => top + (1 - fraction) * length;
}

class _BandPanel extends StatelessWidget {
  const _BandPanel({required this.params, required this.onRelease});
  final EqParams params;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    // Ten bands on a phone leave ~30 dp per column: a narrower axis and
    // smaller readouts (see _BandColumn) keep them from crowding.
    final dense = params.bands.length > 6;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 8, dense ? 8 : 12, 8),
      child: LayoutBuilder(
        builder: (context, box) {
          final rail = _Rail(box.maxHeight);
          return Row(
            children: [
              SizedBox(
                  width: dense ? 40 : 48,
                  child: _DbAxis(params: params, rail: rail)),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 0 dB guide under every rail, at the exact y the
                    // sliders put their zero notch.
                    Positioned(
                      key: const Key('eq-zero-line'),
                      left: 0,
                      right: 0,
                      top: rail.yFor(params.zeroFraction) - 0.5,
                      child: Container(height: 1, color: VelvetColors.border),
                    ),
                    Row(
                      children: [
                        for (final band in params.bands)
                          Expanded(
                            child: _BandColumn(
                              band: band,
                              params: params,
                              onRelease: onRelease,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DbAxis extends StatelessWidget {
  const _DbAxis({required this.params, required this.rail});
  final EqParams params;
  final _Rail rail;

  @override
  Widget build(BuildContext context) {
    Widget label(String text, double y) => Positioned(
          right: 6,
          top: y - 7,
          height: 14,
          child: Text(
            text,
            style: TextStyle(color: VelvetColors.textTertiary, fontSize: 10),
          ),
        );
    return Stack(
      children: [
        label('+${params.maxDb.round()} dB', rail.yFor(1)),
        label('0 dB', rail.yFor(params.zeroFraction)),
        label('${params.minDb.round()} dB', rail.yFor(0)),
      ],
    );
  }
}

class _BandColumn extends StatelessWidget {
  const _BandColumn(
      {required this.band, required this.params, required this.onRelease});
  final EqBand band;
  final EqParams params;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final hz = formatFrequency(band.centerFrequency);
    final dense = params.bands.length > 6;
    return StreamBuilder<double>(
      stream: band.gainStream,
      initialData: band.gain,
      builder: (context, snap) {
        final gain = (snap.data ?? 0).clamp(params.minDb, params.maxDb);
        return Column(
          children: [
            SizedBox(
                height: kEqLabelSlot,
                child: _Readout(
                    value: formatGain(gain), unit: 'dB', dense: dense)),
            Expanded(
              // quarterTurns 3 (a quarter turn anticlockwise) puts the
              // slider's min end at the bottom and its max end at the top.
              // The Directionality pin keeps that true under an RTL locale,
              // where a Slider would otherwise run the other way.
              child: RotatedBox(
                quarterTurns: 3,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Semantics(
                    label: '$hz Hz',
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        trackShape: _ZeroCenteredTrack(
                          zeroFraction: params.zeroFraction,
                          notchColor: VelvetColors.textTertiary,
                        ),
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8, elevation: 2),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: kEqRailInset),
                        activeTrackColor: VelvetColors.primary,
                        inactiveTrackColor: VelvetColors.border,
                        thumbColor: VelvetColors.primary,
                        overlayColor: VelvetColors.primaryDim,
                      ),
                      child: Slider(
                        value: gain,
                        min: params.minDb,
                        max: params.maxDb,
                        // Per tick, fire-and-forget: the native effect
                        // follows the thumb and gainStream feeds the
                        // readout. Settings are written on release only.
                        onChanged: band.setGain,
                        onChangeEnd: (_) => onRelease(),
                        semanticFormatterCallback: (v) =>
                            '${formatGain(v)} dB',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
                height: kEqLabelSlot,
                child: _Readout(value: hz, unit: 'Hz', dense: dense)),
          ],
        );
      },
    );
  }
}

/// A value over its unit, scaled down rather than overflowing its slot under
/// a large system font.
class _Readout extends StatelessWidget {
  const _Readout(
      {required this.value, required this.unit, this.dense = false});
  final String value;
  final String unit;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: dense ? 10 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
                color: VelvetColors.textSecondary, fontSize: dense ? 8 : 9),
          ),
        ],
      ),
    );
  }
}

/// A rail whose active segment runs from 0 dB to the thumb, with a notch at
/// 0 dB. The stock track fills from the min end, which on an EQ reads as "every
/// band half boosted" when all of them are flat.
///
/// Owns the rail geometry too (an inset of [kEqRailInset] at each end) so the
/// thumb positions the slider computes from this rect match the axis and
/// guide the panel draws from the same constant.
class _ZeroCenteredTrack extends SliderTrackShape {
  const _ZeroCenteredTrack({required this.zeroFraction, required this.notchColor});
  final double zeroFraction;
  final Color notchColor;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 4;
    return Rect.fromLTWH(
      offset.dx + kEqRailInset,
      offset.dy + (parentBox.size.height - h) / 2,
      math.max(0, parentBox.size.width - 2 * kEqRailInset),
      h,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (rect.isEmpty) return;
    final canvas = context.canvas;
    final radius = Radius.circular(rect.height / 2);
    final railPaint = Paint()
      ..color = ColorTween(
            begin: sliderTheme.disabledInactiveTrackColor,
            end: sliderTheme.inactiveTrackColor,
          ).evaluate(enableAnimation) ??
          const Color(0x00000000);
    final fillPaint = Paint()
      ..color = ColorTween(
            begin: sliderTheme.disabledActiveTrackColor,
            end: sliderTheme.activeTrackColor,
          ).evaluate(enableAnimation) ??
          const Color(0x00000000);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), railPaint);

    final f = textDirection == TextDirection.rtl ? 1 - zeroFraction : zeroFraction;
    final zeroX = rect.left + f * rect.width;
    final a = math.min(zeroX, thumbCenter.dx);
    final b = math.max(zeroX, thumbCenter.dx);
    if (b - a > 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(a, rect.top, b, rect.bottom), radius),
        fillPaint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(zeroX, rect.center.dy), width: 2, height: rect.height + 8),
        const Radius.circular(1),
      ),
      Paint()..color = notchColor,
    );
  }
}

/// The preset chips: one row, scrolled sideways, the active curve filled.
class _PresetRow extends StatelessWidget {
  const _PresetRow(this.controller);
  final EqController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = controller.activePreset;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: kEqPresets.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = kEqPresets[i];
          final on = identical(p, active);
          return ChoiceChip(
            key: ValueKey('eq-preset-${p.id}'),
            label: Text(eqPresetName(l, p)),
            selected: on,
            showCheckmark: false,
            onSelected: (_) => controller.applyPreset(p),
            selectedColor: VelvetColors.primary,
            backgroundColor: Colors.transparent,
            side: BorderSide(
                color: on ? VelvetColors.primary : VelvetColors.border2),
            labelStyle: TextStyle(
              fontSize: 13,
              color: on ? VelvetColors.onPrimary : VelvetColors.textPrimary,
              fontWeight: on ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }
}

/// A preset's name in the active locale.
String eqPresetName(AppLocalizations l, EqPreset p) => switch (p.id) {
      'flat' => l.eqPresetFlat,
      'normal' => l.eqPresetNormal,
      'classical' => l.eqPresetClassical,
      'dance' => l.eqPresetDance,
      'folk' => l.eqPresetFolk,
      'heavyMetal' => l.eqPresetHeavyMetal,
      'hipHop' => l.eqPresetHipHop,
      'jazz' => l.eqPresetJazz,
      'pop' => l.eqPresetPop,
      'rock' => l.eqPresetRock,
      _ => p.id,
    };
