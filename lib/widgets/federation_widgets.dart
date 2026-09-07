import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';
import '../util/federation_admin_api.dart';

/// The Federation screens' building blocks, in the home's vocabulary: the
/// uppercase section header, the card with hairline dividers, the icon-tile
/// row, chips, switches, buttons, notes — plus the formatters every screen
/// shares (relative time, limits, bytes). Nothing here talks to a server.

// ── layout ────────────────────────────────────────────────────────────

class FedSection extends StatelessWidget {
  final String title;
  final int? badge;
  final Widget? trailing;
  final bool first;
  const FedSection(this.title,
      {super.key, this.badge, this.trailing, this.first = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6, first ? 6 : 16, 6, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: VelvetColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          if (badge != null && badge! > 0) ...[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: VelvetColors.error,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class FedCard extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  const FedCard({super.key, required this.children, this.color});

  @override
  Widget build(BuildContext context) {
    final kids = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        kids.add(Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: VelvetColors.border));
      }
      kids.add(children[i]);
    }
    return Material(
      color: color ?? VelvetColors.card,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );
  }
}

class FedTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const FedTile(this.icon, {super.key, this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = color ?? VelvetColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
      child: Icon(icon, color: c, size: size * 0.55),
    );
  }
}

class FedDot extends StatelessWidget {
  final Color color;
  const FedDot(this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class FedRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Color? dot;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int subtitleLines;
  final int titleLines;
  final double titleSize;
  const FedRow({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.dot,
    this.trailing,
    this.onTap,
    this.subtitleLines = 1,
    this.titleLines = 1,
    this.titleSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          if (icon != null) ...[
            FedTile(icon!, color: iconColor),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary)),
                if (subtitle != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (dot != null) FedDot(dot!),
                      Expanded(
                        child: Text(subtitle!,
                            maxLines: subtitleLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: subtitleColor ??
                                    VelvetColors.textSecondary)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

Widget fedChevron() =>
    Icon(Icons.chevron_right, color: VelvetColors.textTertiary, size: 22);

class FedSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool busy;
  const FedSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: VelvetColors.textSecondary)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: VelvetColors.primary,
            ),
        ],
      ),
    );
  }
}

class FedCheckRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const FedCheckRow(
      {super.key,
      required this.label,
      this.subtitle,
      required this.value,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? VelvetColors.primary : Colors.transparent,
                border: value
                    ? null
                    : Border.all(color: VelvetColors.textDim, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: value
                  ? Icon(Icons.check, size: 16, color: VelvetColors.onPrimary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15, color: VelvetColors.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 12, color: VelvetColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const FedChip(this.label, {super.key, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VelvetColors.primaryDim : VelvetColors.raised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        // A Row that hugs its text: a Container with `alignment` would take
        // the Wrap's full row width instead of the chip's own.
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            border: Border.all(
                color: selected ? VelvetColors.primary : Colors.transparent,
                width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? VelvetColors.primary
                          : VelvetColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class FedChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final int? selected;
  final ValueChanged<int> onSelected;
  const FedChipRow(
      {super.key,
      required this.label,
      required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: VelvetColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < options.length; i++)
                FedChip(options[i],
                    selected: selected == i, onTap: () => onSelected(i)),
            ],
          ),
        ],
      ),
    );
  }
}

enum FedButtonKind { primary, outline, muted, danger, text }

class FedButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final FedButtonKind kind;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final double fontSize;
  const FedButton(
    this.label, {
    super.key,
    this.icon,
    this.kind = FedButtonKind.primary,
    this.onPressed,
    this.busy = false,
    this.height = 48,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    Color bg;
    Color fg;
    Border? border;
    switch (kind) {
      case FedButtonKind.primary:
        bg = VelvetColors.primary;
        fg = VelvetColors.onPrimary;
        break;
      case FedButtonKind.outline:
        bg = VelvetColors.primary.withValues(alpha: 0.08);
        fg = VelvetColors.primary;
        border = Border.all(color: VelvetColors.primary, width: 1.5);
        break;
      case FedButtonKind.muted:
        bg = VelvetColors.raised;
        fg = VelvetColors.textPrimary;
        break;
      case FedButtonKind.danger:
        bg = Colors.transparent;
        fg = VelvetColors.error;
        break;
      case FedButtonKind.text:
        bg = Colors.transparent;
        fg = VelvetColors.primary;
        break;
    }
    final content = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: fg)),
              ),
            ],
          );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A sticky action bar for a screen's `bottomNavigationBar`: every child
/// gets an equal share of the width.
class FedBottomBar extends StatelessWidget {
  final List<Widget> children;
  const FedBottomBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VelvetColors.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FedNote extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  const FedNote(this.text,
      {super.key, this.icon = Icons.warning_amber_rounded, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? VelvetColors.warning;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: VelvetColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class FedHint extends StatelessWidget {
  final String text;
  final Color? color;
  const FedHint(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: color ?? VelvetColors.textTertiary)),
      );
}

InputDecoration fedInputDecoration(String label,
    {String? hint, Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    filled: true,
    fillColor: VelvetColors.raised,
    labelStyle: TextStyle(color: VelvetColors.textSecondary, fontSize: 14),
    hintStyle: TextStyle(color: VelvetColors.textTertiary),
    contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        borderSide: BorderSide(color: VelvetColors.primary, width: 1.5)),
  );
}

Widget fedLoading() => const Center(
    child: Padding(
        padding: EdgeInsets.all(40), child: CircularProgressIndicator()));

/// A yes/no dialog; true when the user confirmed.
Future<bool> fedConfirm(BuildContext context,
    {required String message,
    required String confirmLabel,
    bool danger = false}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VelvetColors.surface,
      content: Text(message, style: TextStyle(color: VelvetColors.textPrimary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel)),
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: danger ? VelvetColors.error : VelvetColors.primary))),
      ],
    ),
  );
  return ok == true;
}

// ── formatters ────────────────────────────────────────────────────────

/// "just now" / "5 min ago" / "3 h ago" / "2 days ago", then a date.
String fmtAgo(BuildContext context, DateTime? when) {
  final l = AppLocalizations.of(context);
  if (when == null) return l.agoJustNow;
  final d = DateTime.now().difference(when);
  if (d.inSeconds < 90) return l.agoJustNow;
  if (d.inMinutes < 60) return l.agoMinutes(d.inMinutes);
  if (d.inHours < 24) return l.agoHours(d.inHours);
  if (d.inDays < 30) return l.agoDays(d.inDays);
  return MaterialLocalizations.of(context).formatShortDate(when);
}

String fmtDate(BuildContext context, DateTime when) =>
    MaterialLocalizations.of(context).formatShortDate(when);

String fmtStreamRate(AppLocalizations l, int kbps) {
  if (kbps <= 0) return l.federationUnlimited;
  if (kbps >= 1000 && kbps % 1000 == 0) return l.federationMbps(kbps ~/ 1000);
  return l.federationKbps(kbps);
}

String fmtDaily(AppLocalizations l, int mb) {
  if (mb <= 0) return l.federationUnlimited;
  if (mb >= 1024 && mb % 1024 == 0) return l.federationGbPerDay(mb ~/ 1024);
  return l.federationMbPerDay(mb);
}

String fmtStreams(AppLocalizations l, int n) =>
    n <= 0 ? l.federationUnlimited : l.federationStreamsCount(n);

/// "never expires" / "expires in 6 days" / "expires 12/9/2026" / "expired".
String fmtExpiry(BuildContext context, DateTime? when, {bool expired = false}) {
  final l = AppLocalizations.of(context);
  if (expired) return l.federationExpired;
  if (when == null) return l.federationNeverExpires;
  final d = when.difference(DateTime.now());
  if (d.isNegative) return l.federationExpired;
  if (d.inHours < 48) return l.federationExpiresIn(l.federationInHours(d.inHours < 1 ? 1 : d.inHours));
  if (d.inDays <= 60) return l.federationExpiresIn(l.federationInDays(d.inDays));
  return l.federationExpiresIn(fmtDate(context, when));
}

String fmtLimitsSummary(BuildContext context, FederationLimits limits,
    {DateTime? expiresAt, bool expired = false}) {
  final l = AppLocalizations.of(context);
  return [
    fmtStreamRate(l, limits.streamKbps),
    fmtDaily(l, limits.dailyMb),
    fmtStreams(l, limits.maxStreams),
    fmtExpiry(context, expiresAt, expired: expired),
  ].join(' · ');
}

String fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  var u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  return '${v < 10 ? v.toStringAsFixed(1) : v.round()} ${units[u]}';
}

/// "A, B and C" in a plain comma list (the arb strings take the joined
/// text as one placeholder).
String fmtList(List<String> names) => names.join(', ');
