import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';

/// Curated accent presets — all bright/saturated so they read on the dark
/// surfaces and keep the on-accent glyphs legible.
const List<Color> _accentPresets = [
  Color(0xFFFFAB00), // amber
  Color(0xFFFB923C), // orange
  Color(0xFFEF4444), // red
  Color(0xFFEC4899), // pink
  Color(0xFF8B5CF6), // purple
  Color(0xFF3B82F6), // blue
  Color(0xFF06B6D4), // cyan
  Color(0xFF22C55E), // green
];

// Full hue spectrum for the hue slider track.
const List<Color> _hueTrack = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

int _argb(Color c) {
  int ch(double v) => (v * 255.0).round() & 0xff;
  return 0xFF000000 | (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
}

/// Bottom sheet to choose the app accent: curated swatches + a custom HSV
/// picker. Writes through `SettingsManager().setAccentColor` (null = each
/// theme's built-in primary), which live-rebuilds the whole app via the theme
/// stream — so picks preview instantly on the real UI behind the sheet.
class AccentColorSheet extends StatefulWidget {
  const AccentColorSheet({super.key});

  @override
  State<AccentColorSheet> createState() => _AccentColorSheetState();
}

class _AccentColorSheetState extends State<AccentColorSheet> {
  // The dragged custom colour. A ValueNotifier (not setState) so a drag tick
  // rebuilds only the preview + sliders subtree below, not the whole sheet.
  late final ValueNotifier<HSVColor> _hsv;

  @override
  void initState() {
    super.initState();
    final current = SettingsManager().accentColor;
    _hsv = ValueNotifier(HSVColor.fromColor(
        current != null ? Color(current) : VelvetColors.primary));
  }

  @override
  void dispose() {
    _hsv.dispose();
    super.dispose();
  }

  void _applyPreset(int? argb) {
    SettingsManager().setAccentColor(argb);
    Navigator.of(context).pop();
  }

  // Persist the custom colour on release only (not per drag tick) — the live
  // sheet preview is driven by [_hsv] during the drag.
  void _commitCustom() =>
      SettingsManager().setAccentColor(_argb(_hsv.value.toColor()));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = SettingsManager().accentColor;
    // The current theme's built-in accent (ignoring any override) — shown on
    // the "Theme default" chip so the user sees what reverting looks like.
    final themeDefault = paletteFor(SettingsManager().appTheme).primary;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: VelvetColors.border2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              l.settingsAccentColor,
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _Swatch(
                  color: themeDefault,
                  selected: current == null,
                  icon: Icons.format_color_reset,
                  tooltip: l.accentThemeDefault,
                  onTap: () => _applyPreset(null),
                ),
                for (final c in _accentPresets)
                  _Swatch(
                    color: c,
                    selected: current == _argb(c),
                    onTap: () => _applyPreset(_argb(c)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: VelvetColors.border, height: 1),
            const SizedBox(height: 16),
            Text(
              l.accentCustom.toUpperCase(),
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            // Only the preview swatch + sliders depend on the dragged colour, so
            // a drag tick rebuilds just this subtree via [_hsv] — not the whole
            // sheet (handle, title, preset swatches, dividers).
            ValueListenableBuilder<HSVColor>(
              valueListenable: _hsv,
              builder: (context, hsv, _) {
                final custom = hsv.toColor();
                return Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: custom,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: VelvetColors.border),
                      ),
                      child: current == _argb(custom)
                          ? Icon(Icons.check, color: onAccent(custom), size: 22)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _GradientBar(
                            colors: _hueTrack,
                            t: hsv.hue / 360.0,
                            onChanged: (v) =>
                                _hsv.value = hsv.withHue(v * 360.0),
                            onEnd: _commitCustom,
                          ),
                          const SizedBox(height: 12),
                          _GradientBar(
                            colors: [
                              HSVColor.fromAHSV(1, hsv.hue, 0, hsv.value)
                                  .toColor(),
                              HSVColor.fromAHSV(1, hsv.hue, 1, hsv.value)
                                  .toColor(),
                            ],
                            t: hsv.saturation,
                            onChanged: (v) =>
                                _hsv.value = hsv.withSaturation(v),
                            onEnd: _commitCustom,
                          ),
                          const SizedBox(height: 12),
                          _GradientBar(
                            colors: [
                              Colors.black,
                              HSVColor.fromAHSV(1, hsv.hue, hsv.saturation, 1)
                                  .toColor(),
                            ],
                            t: hsv.value,
                            onChanged: (v) => _hsv.value = hsv.withValue(v),
                            onEnd: _commitCustom,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? VelvetColors.textPrimary : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: 18, color: onAccent(color))
            : (selected
                ? Icon(Icons.check, size: 20, color: onAccent(color))
                : null),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

/// A horizontal gradient track with a draggable thumb. [t] is 0..1; [onChanged]
/// fires continuously while dragging (for live preview), [onEnd] on release.
class _GradientBar extends StatelessWidget {
  final List<Color> colors;
  final double t;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;
  const _GradientBar({
    required this.colors,
    required this.t,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    const h = 26.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        void handle(double dx) => onChanged((dx / w).clamp(0.0, 1.0));
        final thumbLeft = (t * w - h / 2).clamp(0.0, w - h);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            handle(d.localPosition.dx);
            onEnd();
          },
          onHorizontalDragUpdate: (d) => handle(d.localPosition.dx),
          onHorizontalDragEnd: (_) => onEnd(),
          child: SizedBox(
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(h / 2),
                    border: Border.all(color: VelvetColors.border),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  top: 0,
                  child: Container(
                    width: h,
                    height: h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.black54, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
