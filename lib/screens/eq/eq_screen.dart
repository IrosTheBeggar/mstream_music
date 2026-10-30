// Graphic equalizer UI over whichever Android engine the handler built
// (the ten-band DynamicsProcessing engine, or the device's AndroidEqualizer
// below Android 9). The state lives in EqController (eq_controller.dart);
// this file only renders it:
//
//   * the enable switch (always shown on Android — it is how the user turns
//     the EQ on while the pipeline, and so the equalizer object, does not
//     exist yet), locked while casting or mid-toggle;
//   * a row of preset chips (eq_presets.dart): the chip whose curve the gains
//     spell is the selected one, so a drag deselects; gains that spell nothing
//     put a "Custom" chip first and a Save button under the panel, and the
//     user's saved curves follow the built-ins after a divider (long-press one
//     to rename or delete it);
//   * the band panel: one vertical slider per band on a hairline rail, and
//     under the sliders a curve through every thumb with a fill down to 0 dB
//     (eq_curve.dart), so the shape of the sound reads at a glance. The gain
//     of the band being dragged shows in a bubble over its thumb; the rest
//     of the time only the frequencies are labelled;
//   * a dB axis on the left and a 0 dB guide across the bands, placed from
//     the same rail geometry the sliders and the curve use;
//   * Reset-to-flat in the AppBar.
//
// Gains go to the native effect on every drag tick (audio follows the thumb)
// and to settings on release only.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import 'eq_controller.dart';
import 'eq_curve.dart';
import 'eq_presets.dart';

/// How far each rail stops short of its column's ends (the overlay radius):
/// the slider's track rect, the curve, the axis and the guide positions are
/// all derived from this one number, which is what keeps them aligned.
const double kEqRailInset = 14;

/// Room above the rails for the value bubble over a thumb at max gain.
const double kEqBubbleSlot = 30;

/// Height of the frequency label slot under each rail.
const double kEqLabelSlot = 24;

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
                child: _BandPanel(
                  params: c.params!,
                  gains: c.gains,
                  onRelease: c.saveGains,
                ),
              ),
              _ActionRow(c),
            ],
          ),
      };
}

/// Under the panel: Save, once the gains spell no preset. The row keeps its
/// height either way, so the first drag that leaves a preset does not shrink
/// the panel under the finger.
class _ActionRow extends StatelessWidget {
  const _ActionRow(this.controller);
  final EqController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 60,
      child: controller.isCustom
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                key: const Key('eq-save-preset'),
                onPressed: () => _savePreset(context, controller),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetColors.primary,
                  foregroundColor: VelvetColors.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(l.eqSaveAsPreset,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            )
          : null,
    );
  }
}

Future<void> _savePreset(BuildContext context, EqController c) async {
  final l = AppLocalizations.of(context);
  final name = await _askPresetName(
    context,
    title: l.eqSavePresetTitle,
    initial: '',
    controller: c,
  );
  if (name == null) return;
  await c.saveUserPreset(name);
}

/// The long-press menu on a saved chip: rename (through the name sheet) or
/// delete (after a confirmation).
Future<void> _showUserPresetMenu(
    BuildContext context, EqController c, EqPreset preset) async {
  final l = AppLocalizations.of(context);
  final name = preset.name ?? preset.id;
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: VelvetColors.raised,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              name,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textPrimary),
            ),
          ),
          ListTile(
            key: const Key('eq-preset-menu-rename'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.rename),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            key: const Key('eq-preset-menu-delete'),
            leading: const Icon(Icons.delete_outline),
            title: Text(l.delete),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'rename':
      final renamed = await _askPresetName(
        context,
        title: l.eqRenamePresetTitle,
        initial: name,
        controller: c,
        renaming: preset,
      );
      if (renamed != null) await c.renameUserPreset(preset, renamed);
    case 'delete':
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VelvetColors.raised,
          title: Text(l.eqDeletePresetConfirm(name),
              style: TextStyle(fontSize: 18, color: VelvetColors.textPrimary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel,
                  style: TextStyle(color: VelvetColors.textSecondary)),
            ),
            TextButton(
              key: const Key('eq-preset-delete-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.delete,
                  style: TextStyle(
                      color: VelvetColors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (ok == true) await c.deleteUserPreset(preset);
  }
}

/// The name sheet, for a new preset or a rename. Resolves to the trimmed name,
/// or null on cancel.
Future<String?> _askPresetName(
  BuildContext context, {
  required String title,
  required String initial,
  required EqController controller,
  EqPreset? renaming,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VelvetColors.raised,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _PresetNameSheet(
        title: title,
        initial: initial,
        controller: controller,
        renaming: renaming,
      ),
    ),
  );
}

class _PresetNameSheet extends StatefulWidget {
  const _PresetNameSheet({
    required this.title,
    required this.initial,
    required this.controller,
    this.renaming,
  });
  final String title;
  final String initial;
  final EqController controller;

  /// The preset being renamed, or null when saving a new one. A clash with
  /// another saved name blocks a rename; when saving it means Replace.
  final EqPreset? renaming;

  @override
  State<_PresetNameSheet> createState() => _PresetNameSheetState();
}

class _PresetNameSheetState extends State<_PresetNameSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  )..selection =
      TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = _text.text.trim();
    final clash = widget.controller.userPresetNamed(name);
    final renaming = widget.renaming;
    final blocked = renaming != null && clash != null && clash.id != renaming.id;
    final replaces = renaming == null && clash != null;
    final canSubmit = name.isNotEmpty && !blocked;
    void submit() => Navigator.pop(context, name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 14),
          Text(
            widget.title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: VelvetColors.textPrimary),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('eq-preset-name'),
            controller: _text,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canSubmit) submit();
            },
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              labelText: l.eqPresetNameLabel,
              counterText: '',
              helperText: blocked
                  ? l.eqPresetNameTaken
                  : renaming == null
                      ? l.eqSavePresetHint
                      : null,
              helperMaxLines: 3,
              helperStyle: TextStyle(
                  color: blocked
                      ? VelvetColors.error
                      : VelvetColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel,
                    style: TextStyle(
                        color: VelvetColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('eq-preset-sheet-save'),
                onPressed: canSubmit ? submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetColors.primary,
                  foregroundColor: VelvetColors.onPrimary,
                ),
                child: Text(replaces ? l.eqReplacePreset : l.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: VelvetColors.border2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
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

/// Where the rails sit inside a column of a given height: the bubble slot,
/// the label slot and both insets off, max gain at the top. Shared by the
/// sliders (through [_RailTrack]), the curve painter, the axis and the 0 dB
/// guide.
class _Rail {
  const _Rail(this.columnHeight);
  final double columnHeight;

  double get top => kEqBubbleSlot + kEqRailInset;
  double get length =>
      math.max(0, columnHeight - top - kEqLabelSlot - kEqRailInset);

  /// Screen y of the point `fraction` of the way from the min end (bottom)
  /// to the max end (top).
  double yFor(double fraction) => top + (1 - fraction) * length;
}

/// The card with the axis, the curve, the sliders and the value bubble. Owns
/// one piece of state: which band is being dragged.
class _BandPanel extends StatefulWidget {
  const _BandPanel(
      {required this.params, required this.gains, required this.onRelease});
  final EqParams params;

  /// The live gains in band order (the controller's, which it refreshes on
  /// every tick of every band).
  final List<double> gains;
  final VoidCallback onRelease;

  @override
  State<_BandPanel> createState() => _BandPanelState();
}

class _BandPanelState extends State<_BandPanel> {
  int? _active;

  @override
  Widget build(BuildContext context) {
    final params = widget.params;
    final n = params.bands.length;
    final gains = widget.gains.length == n
        ? widget.gains
        : [for (final b in params.bands) b.gain];
    // Ten bands on a phone leave ~32 dp per column: a narrower axis keeps
    // them from crowding.
    final dense = n > 6;
    final active = _active;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.only(right: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: VelvetColors.card,
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      ),
      // Low to high always reads left to right, whatever the locale: the
      // curve is painted in band order, so the columns must be too.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, box) {
            final rail = _Rail(box.maxHeight);
            return Row(
              children: [
                SizedBox(
                  width: dense ? 28 : 36,
                  child: _DbAxis(params: params, rail: rail),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, plot) {
                      final colW = plot.maxWidth / n;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // 0 dB guide under every rail, at the exact y the
                          // sliders put 0 dB.
                          Positioned(
                            key: const Key('eq-zero-line'),
                            left: 0,
                            right: 0,
                            top: rail.yFor(params.zeroFraction) - 0.5,
                            child: Container(
                                height: 1, color: VelvetColors.border2),
                          ),
                          CustomPaint(
                            key: const Key('eq-curve'),
                            painter: EqCurvePainter(
                              gains: gains,
                              minDb: params.minDb,
                              maxDb: params.maxDb,
                              top: rail.top,
                              length: rail.length,
                              active: active,
                              accent: VelvetColors.primary,
                              ring: VelvetColors.card,
                              grid: VelvetColors.border.withValues(alpha: 0.6),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < n; i++)
                                Expanded(
                                  child: _BandColumn(
                                    band: params.bands[i],
                                    gain: gains[i],
                                    params: params,
                                    active: active == i,
                                    onStart: () =>
                                        setState(() => _active = i),
                                    onEnd: () {
                                      setState(() => _active = null);
                                      widget.onRelease();
                                    },
                                  ),
                                ),
                            ],
                          ),
                          if (active != null)
                            _Bubble(
                              x: colW * (active + 0.5),
                              thumbY: rail.yFor(
                                  params.fractionOf(gains[active])),
                              plotWidth: plot.maxWidth,
                              text: formatGain(gains[active]),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The dragged band's gain, in a pill just above its thumb and centred on its
/// column (shifted in at the panel's edges). Decoration only: the slider's
/// own semantics announce the value.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.x,
    required this.thumbY,
    required this.plotWidth,
    required this.text,
  });
  final double x;
  final double thumbY;
  final double plotWidth;
  final String text;

  static const double width = 52;
  static const double height = 26;

  /// Thumb radius plus a gap: the bubble's bottom sits this far above the
  /// thumb's centre.
  static const double lift = 14;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const Key('eq-bubble'),
      left: (x - width / 2).clamp(0.0, math.max(0.0, plotWidth - width)),
      top: thumbY - lift - height,
      width: width,
      height: height,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VelvetColors.primary,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: VelvetColors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
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
    Widget label(String text, double y, {Color? color, double size = 11}) =>
        Positioned(
          right: 4,
          top: y - 7,
          height: 14,
          child: Text(
            text,
            style: TextStyle(
                color: color ?? VelvetColors.textSecondary, fontSize: size),
          ),
        );
    return Stack(
      children: [
        label('dB', rail.top - 17, color: VelvetColors.textTertiary, size: 10),
        label('+${params.maxDb.round()}', rail.yFor(1)),
        label('0', rail.yFor(params.zeroFraction)),
        label('${params.minDb.round()}', rail.yFor(0)),
        label('Hz', rail.columnHeight - kEqLabelSlot / 2,
            color: VelvetColors.textTertiary, size: 10),
      ],
    );
  }
}

class _BandColumn extends StatelessWidget {
  const _BandColumn({
    required this.band,
    required this.gain,
    required this.params,
    required this.active,
    required this.onStart,
    required this.onEnd,
  });
  final EqBand band;
  final double gain;
  final EqParams params;
  final bool active;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final hz = formatFrequency(band.centerFrequency);
    final value = gain.clamp(params.minDb, params.maxDb);
    return Column(
      children: [
        const SizedBox(height: kEqBubbleSlot),
        Expanded(
          // quarterTurns 3 (a quarter turn anticlockwise) puts the slider's
          // min end at the bottom and its max end at the top. The
          // Directionality pin keeps that true under an RTL locale, where a
          // Slider would otherwise run the other way.
          child: RotatedBox(
            quarterTurns: 3,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Semantics(
                label: '$hz Hz',
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    trackShape: const _RailTrack(),
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                        elevation: 0,
                        pressedElevation: 0),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: kEqRailInset),
                    activeTrackColor: VelvetColors.primary,
                    inactiveTrackColor: active
                        ? VelvetColors.primary.withValues(alpha: 0.45)
                        : VelvetColors.border2,
                    thumbColor: VelvetColors.primary,
                    overlayColor: VelvetColors.primaryDim,
                  ),
                  child: Slider(
                    value: value,
                    min: params.minDb,
                    max: params.maxDb,
                    onChangeStart: (_) => onStart(),
                    // Per tick, fire-and-forget: the native effect follows
                    // the thumb and the band's gain stream feeds the
                    // controller, the curve and the bubble. Settings are
                    // written on release only.
                    onChanged: band.setGain,
                    onChangeEnd: (_) => onEnd(),
                    semanticFormatterCallback: (v) => '${formatGain(v)} dB',
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: kEqLabelSlot,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hz,
                style: TextStyle(
                  color: active
                      ? VelvetColors.textPrimary
                      : VelvetColors.textSecondary,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A plain hairline rail: no active segment (the curve's fill says how far
/// from 0 dB a band sits) and an inset of [kEqRailInset] at each end, so the
/// thumb positions the slider computes from this rect match the curve, the
/// axis and the guide drawn from the same constant.
class _RailTrack extends SliderTrackShape {
  const _RailTrack();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 2;
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
    final railPaint = Paint()
      ..color = ColorTween(
            begin: sliderTheme.disabledInactiveTrackColor,
            end: sliderTheme.inactiveTrackColor,
          ).evaluate(enableAnimation) ??
          const Color(0x00000000);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      railPaint,
    );
  }
}

/// The preset chips: one row, scrolled sideways, the active curve filled.
/// "Custom" leads when the gains spell nothing; the user's saved curves
/// follow the built-ins after a divider.
class _PresetRow extends StatelessWidget {
  const _PresetRow(this.controller);
  final EqController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final activeId = controller.activePreset?.id;
    final user = controller.userPresets;
    final chips = <Widget>[
      if (controller.isCustom)
        _PresetChip(
          chipKey: const ValueKey('eq-preset-custom'),
          label: l.eqPresetCustom,
          selected: true,
          onSelected: () {},
        ),
      for (final p in kEqPresets)
        _PresetChip(
          chipKey: ValueKey('eq-preset-${p.id}'),
          label: eqPresetName(l, p),
          selected: p.id == activeId,
          onSelected: () => controller.applyPreset(p),
        ),
      if (user.isNotEmpty)
        Center(
          child: Container(width: 1, height: 20, color: VelvetColors.border2),
        ),
      for (final p in user)
        GestureDetector(
          onLongPress: () => _showUserPresetMenu(context, controller, p),
          child: _PresetChip(
            chipKey: ValueKey('eq-preset-${p.id}'),
            label: p.name ?? p.id,
            selected: p.id == activeId,
            onSelected: () => controller.applyPreset(p),
          ),
        ),
    ];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: chips.length,
        separatorBuilder: (_, _) => SizedBox(width: 8),
        itemBuilder: (context, i) => chips[i],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  /// Goes on the ChoiceChip itself, which is what tests look up.
  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: chipKey,
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: VelvetColors.primary,
      backgroundColor: Colors.transparent,
      side: BorderSide(
          color: selected ? VelvetColors.primary : VelvetColors.border2),
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? VelvetColors.onPrimary : VelvetColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
