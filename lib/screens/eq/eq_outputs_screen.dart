// The Outputs screen: the output in use and the ones remembered, each with
// its curve, the switch that makes the engine follow the route, a preset
// picker per output and a swipe to forget one. Ten-band engine only: the
// router (lib/media/eq_output_router.dart) is null elsewhere, and the EQ
// screen's options sheet does not offer this page then.

import 'package:flutter/foundation.dart' show listEquals;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../media/eq_output_router.dart';
import '../../theme/velvet_theme.dart';
import 'eq_controller.dart';
import 'eq_curve.dart';
import 'eq_presets.dart';
import 'eq_sheet_handle.dart';
import 'eq_screen.dart' show eqPresetName;

/// What to call an output: a Bluetooth device's own name, the kind otherwise.
String eqOutputLabel(AppLocalizations l, EqOutputKind kind, String name) {
  if (kind == EqOutputKind.bluetooth && name.isNotEmpty) return name;
  return switch (kind) {
    EqOutputKind.speaker => l.eqOutputSpeaker,
    EqOutputKind.wired => l.eqOutputWired,
    EqOutputKind.bluetooth => l.eqOutputBluetooth,
    EqOutputKind.usb => l.eqOutputUsb,
    EqOutputKind.hdmi => l.eqOutputHdmi,
    EqOutputKind.other => l.eqOutputOther,
  };
}

IconData _iconFor(EqOutputKind kind) => switch (kind) {
      EqOutputKind.speaker => Icons.phone_android,
      EqOutputKind.wired => Icons.headphones,
      EqOutputKind.bluetooth => Icons.bluetooth,
      EqOutputKind.usb => Icons.usb,
      EqOutputKind.hdmi => Icons.tv,
      EqOutputKind.other => Icons.speaker,
    };

class EqOutputsScreen extends StatelessWidget {
  const EqOutputsScreen({super.key, required this.controller});
  final EqController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final out = controller.outputs;
        return Scaffold(
          appBar: AppBar(title: Text(l.eqOutputsTitle)),
          body: out == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.eqOutputsEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VelvetColors.textSecondary),
                    ),
                  ),
                )
              : _Body(controller: controller, out: out),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.out});
  final EqController controller;
  final EqOutputRouter out;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profiles = out.profiles;
    final current = out.current;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SwitchListTile(
          key: const Key('eq-out-switch'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(
            l.eqOutputsSwitch,
            style: TextStyle(
                color: VelvetColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            l.eqOutputsSwitchHint,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
          ),
          value: out.enabled,
          onChanged: out.setEnabled,
          activeThumbColor: VelvetColors.primary,
        ),
        Divider(height: 1, color: VelvetColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            l.eqOutputsRemembered.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: VelvetColors.primary,
            ),
          ),
        ),
        if (profiles.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              l.eqOutputsEmpty,
              style: TextStyle(color: VelvetColors.textSecondary, fontSize: 14),
            ),
          )
        else
          for (final p in profiles)
            _OutputRow(
              controller: controller,
              out: out,
              profile: p,
              isNow: p.key == current?.key,
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            l.eqOutputsHint,
            style: TextStyle(color: VelvetColors.textTertiary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({
    required this.controller,
    required this.out,
    required this.profile,
    required this.isNow,
  });
  final EqController controller;
  final EqOutputRouter out;
  final EqOutputProfile profile;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = profile;
    final label = eqOutputLabel(l, p.kind, p.name);
    final preset = presetForLayout(out.frequencies, out.minDb, out.maxDb, p.gains,
        user: controller.userPresets);
    final locale = Localizations.localeOf(context).toString();
    final when = isNow
        ? l.eqOutputPlayingNow
        : l.eqOutputLastUsed(DateFormat.MMMd(locale).format(p.lastUsed));
    final parts = [
      if (p.kind == EqOutputKind.bluetooth) l.eqOutputBluetooth,
      preset == null ? l.eqPresetCustom : eqPresetName(l, preset),
      when,
    ];
    return Dismissible(
      key: ValueKey('eq-out-${p.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: VelvetColors.error.withValues(alpha: 0.25),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: VelvetColors.error),
      ),
      confirmDismiss: (_) => _confirmForget(context, l, label),
      onDismissed: (_) => out.forget(p.key),
      child: ListTile(
        key: ValueKey('eq-out-row-${p.key}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(_iconFor(p.kind),
            color: isNow ? VelvetColors.primary : VelvetColors.textSecondary),
        title: Text(
          label,
          style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          parts.join(' · '),
          style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Sparkline(gains: p.gains),
            if (isNow) ...[
              const SizedBox(width: 10),
              _NowPill(l.eqOutputNowPill),
            ],
          ],
        ),
        onTap: () => _pickPreset(context, controller, out, p, label),
      ),
    );
  }
}

Future<bool> _confirmForget(
    BuildContext context, AppLocalizations l, String label) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VelvetColors.raised,
      title: Text(l.eqOutputForgetConfirm(label),
          style: TextStyle(fontSize: 17, color: VelvetColors.textPrimary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel,
              style: TextStyle(color: VelvetColors.textSecondary)),
        ),
        TextButton(
          key: const Key('eq-out-forget-confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.eqOutputForget,
              style: TextStyle(
                  color: VelvetColors.error, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// A preset for one output: the built-ins and the user's own, the one its
/// curve spells ticked. Live at once when that output is the one in use.
Future<void> _pickPreset(BuildContext context, EqController controller,
    EqOutputRouter out, EqOutputProfile p, String label) {
  final l = AppLocalizations.of(context);
  final presets = [...kEqPresets, ...controller.userPresets];
  return showModalBottomSheet<void>(
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
          const EqSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              l.eqOutputPickPreset(label),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textPrimary),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final preset in presets)
                  ListTile(
                    key: ValueKey('eq-out-pick-${preset.id}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(eqPresetName(l, preset),
                        style: TextStyle(color: VelvetColors.textPrimary)),
                    trailing: preset.matchesLayout(
                            out.frequencies, out.minDb, out.maxDb, p.gains)
                        ? Icon(Icons.check, color: VelvetColors.primary)
                        : null,
                    onTap: () async {
                      await out.setProfileGains(
                          p.key,
                          preset.gainsForLayout(
                              out.frequencies, out.minDb, out.maxDb));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _NowPill extends StatelessWidget {
  const _NowPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: VelvetColors.primary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: VelvetColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A 64×24 picture of a curve: the shape, not the numbers, so a row reads at
/// a glance. ±6 dB fills the height; more is clamped.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.gains});
  final List<double> gains;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(64, 24),
      painter: _SparkPainter(
        gains: gains,
        accent: VelvetColors.primary,
        zero: VelvetColors.border2,
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.gains, required this.accent, required this.zero});
  final List<double> gains;
  final Color accent;
  final Color zero;

  @override
  void paint(Canvas canvas, Size size) {
    final n = gains.length;
    final mid = size.height / 2;
    canvas.drawLine(Offset(4, mid), Offset(size.width - 4, mid),
        Paint()..color = zero..strokeWidth = 1);
    if (n == 0) return;
    final pts = [
      for (var i = 0; i < n; i++)
        Offset(
          n == 1 ? size.width / 2 : 4 + (size.width - 8) * i / (n - 1),
          mid - gains[i].clamp(-6.0, 6.0) * ((mid - 2) / 6),
        ),
    ];
    final curve = curvePath(pts);
    final fill = Path.from(curve)
      ..lineTo(pts.last.dx, mid)
      ..lineTo(pts.first.dx, mid)
      ..close();
    canvas.drawPath(fill, Paint()..color = accent.withValues(alpha: 0.25));
    canvas.drawPath(
      curve,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      !listEquals(old.gains, gains) || old.accent != accent || old.zero != zero;
}
