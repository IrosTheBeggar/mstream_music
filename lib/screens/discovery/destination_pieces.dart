import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart';
import 'keep_copy_ui.dart';

/// The destination sheet's parts (the design canvas's PhoneDestination
/// board), shared by Discover's "Where copies land" and Add from YouTube's
/// "Where new songs land": the grab handle, the preview card's shell, a
/// library chip, a layout's radio row, a variable button, Save, the card a
/// blocked sheet shows and a refusal's line — and the text helpers both
/// sheets edit a layout with. A piece with a hit band takes its height
/// ([KeepHitArea]'s 44 for Discover; Add from YouTube asks for 48), and the
/// keys the destination sheet's tests find stay the defaults.

// ── text ──────────────────────────────────────────────────────────────────

/// A variable as a layout spells it.
String destToken(String name) => '{{$name}}';

/// [s] as one unbreakable run: no-break spaces, and a word joiner after
/// each hyphen ("01 - Rooftop Cypher.mp3" would otherwise break after its
/// dash).
String destHold(String s) =>
    s.replaceAll(' ', '\u00A0').replaceAll('-', '-\u2060');

/// A variable button's name for a screen reader ("Insert artist"), with
/// the name it shows when the words do not already say it ("Insert album
/// artist, ALBUMARTIST"; every one in a translation): Voice Control finds a
/// button by what it shows.
String destInsertLabel(AppLocalizations l, String name) {
  final words = switch (name) {
    'ARTIST' => l.discoverDestInsertArtist,
    'ALBUM' => l.discoverDestInsertAlbum,
    'YEAR' => l.discoverDestInsertYear,
    'GENRE' => l.discoverDestInsertGenre,
    'ALBUMARTIST' => l.discoverDestInsertAlbumArtist,
    'PEER' => l.discoverDestInsertPeer,
    'SERVERFOLDER' => l.discoverDestInsertServerFolder,
    _ => destToken(name),
  };
  return words.toLowerCase().contains(name.toLowerCase())
      ? words
      : '$words, $name';
}

/// [layout] uses the variable [name] — spaced or in any case, as the
/// engine reads it ("{{ artist }}").
bool destUsesVar(String layout, String name) =>
    RegExp('\\{\\{\\s*$name\\s*\\}\\}', caseSensitive: false)
        .hasMatch(layout);

/// A variable button: [token] where [field]'s caret is (over the selection,
/// at the end when the field never had one), the caret after it, [focus]
/// back in the field. The caller turns off a button with no room left for
/// its token: the field's own length limit sees only the keyboard.
void destInsertVar(TextEditingController field, FocusNode focus, String token) {
  final v = field.value;
  final s = v.selection;
  final start = s.isValid ? s.start : v.text.length;
  final end = s.isValid ? s.end : v.text.length;
  field.value = TextEditingValue(
    text: v.text.replaceRange(start, end, token),
    selection: TextSelection.collapsed(offset: start + token.length),
  );
  focus.requestFocus();
}

/// The validator's refusal in words (the server's codes, one table); an
/// unknown variable named as it was typed, [vars] the ones to use instead.
String destLayoutProblem(
  AppLocalizations l,
  LayoutCheck check,
  List<String> vars,
) => switch (check.error) {
  'unknown_variable' => l.discoverDestErrUnknownVar(
    check.token ?? destToken(check.variable ?? ''),
    vars.join(', '),
  ),
  'unbalanced_braces' => l.discoverDestErrBraces(destToken('ARTIST')),
  'absolute_template' || 'absolute_path' => l.discoverDestErrAbsolute,
  'traversal' => l.discoverDestErrTraversal,
  'empty_path' => l.discoverDestErrEmpty,
  'home_string' => l.discoverDestErrHome,
  'drive_letter' || 'drive_letter_segment' => l.discoverDestErrDrive,
  'template_too_long' => l.discoverDestErrTooLong(kMaxLayoutLength),
  'invalid_chars' => l.discoverDestErrControl,
  _ => l.discoverDestErrGeneric,
};

/// What a field being typed in brings into view around its line, in a form
/// [height] tall: its box's top edge, and under it up to 120 px (the
/// variables under a layout's field) — less when the form is short (the
/// keyboard up, large text), so the field itself is never cut.
EdgeInsets destReveal(BuildContext context, double height) {
  const top = 16.0;
  final line = MediaQuery.textScalerOf(context).scale(24);
  return EdgeInsets.only(
    top: top,
    bottom: (height - top - line).clamp(0.0, 120.0),
  );
}

// ── pieces ────────────────────────────────────────────────────────────────

/// A refusal under its input: the server's words in the error tone,
/// announced; or the validator's as typed in the [warning] tone, read in
/// its place after the field (announced, it would talk over the typing).
Widget destErrorLine(String words, Key key, {bool warning = false}) => Padding(
  key: key,
  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
  child: Semantics(
    liveRegion: !warning,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            warning ? Icons.warning_amber_rounded : Icons.error_outline,
            size: 14,
            color: keepTone(
              warning ? VelvetColors.warning : VelvetColors.error,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            words,
            style: TextStyle(
              color: keepTone(
                warning ? VelvetColors.warning : VelvetColors.error,
              ),
              fontSize: 12,
              height: 16 / 12,
            ),
          ),
        ),
      ],
    ),
  ),
);

/// The sheet's grab handle: a 36 × 4 bar atop an 18 px band.
class DestGrabHandle extends StatelessWidget {
  const DestGrabHandle({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    child: Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: VelvetColors.border2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// The preview card around [icon] and [content]: raised, radius 10, one
/// live region (where the song lands is read as it changes). While the
/// keyboard is up ([compact]) it sits tighter; [margin] and [padding]
/// replace the destination sheet's own.
class DestPreviewShell extends StatelessWidget {
  final Widget icon;
  final Widget content;
  final bool compact;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  const DestPreviewShell({
    super.key,
    required this.icon,
    required this.content,
    this.compact = false,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: margin ?? EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 4),
    padding:
        padding ??
        EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 10),
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: icon),
          const SizedBox(width: 10),
          Expanded(child: content),
        ],
      ),
    ),
  );
}

/// A library choice (FedChipRow's chip in the canvas's size): 40 px, radius
/// 10, on a [minHit] band; the chosen one primary-dim with a 1.5 px primary
/// edge and a check. A [locked] one is the library another setting fixes
/// (Add from YouTube's "Same as Discover"): on the card ground (a step
/// under the raised controls, as the canvas draws it), a lock for the
/// check, read as off and deaf to taps; the caption beside it says what
/// sets it.
class DestLibraryChip extends StatelessWidget {
  final String name;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  final double minHit;
  const DestLibraryChip({
    super.key,
    required this.name,
    required this.selected,
    this.locked = false,
    this.onTap,
    this.minHit = 44,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    final chosen = selected && !locked;
    return Semantics(
      inMutuallyExclusiveGroup: locked ? null : true,
      checked: locked ? null : selected,
      button: locked ? null : true,
      enabled: locked ? false : null,
      child: KeepHitArea(
        onTap: locked ? null : onTap,
        minHeight: minHit,
        child: Material(
          color: chosen
              ? VelvetColors.primaryDim
              : locked
              ? VelvetColors.card
              : Colors.transparent,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 96),
            // The lock's own side a little tighter, as the canvas draws it.
            padding: locked
                ? const EdgeInsetsDirectional.only(start: 12, end: 14)
                : const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: chosen ? VelvetColors.primary : VelvetColors.border2,
                width: chosen ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (locked) ...[
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: VelvetColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ] else if (selected) ...[
                  Icon(Icons.check, size: 16, color: VelvetColors.textPrimary),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One layout: a radio, its name, and under it the template in monospace
/// (Custom's line in the plain face, read as its [hint]).
class DestLayoutOption extends StatelessWidget {
  final String label;
  final String sub;
  final bool mono;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;
  const DestLayoutOption({
    super.key,
    required this.label,
    required this.sub,
    this.mono = true,
    this.hint,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    button: true,
    label: label,
    hint: hint,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      splashColor: VelvetColors.primaryDim,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VelvetColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 15,
                        height: 20 / 15,
                      ),
                    ),
                    Text(
                      sub,
                      style: mono
                          ? TextStyle(
                              color: VelvetColors.textSecondary,
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 16 / 11,
                            )
                          : TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 12,
                              height: 16 / 12,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A variable a layout's field inserts at its caret: the token in monospace
/// on a 32 px chip, on a [minHit] band, named for a screen reader ("Insert
/// artist"). [used]: the field holds it already, a tick before the token —
/// drawn only, so [label] says it too ("Insert artist, used").
class DestVarChip extends StatelessWidget {
  final String token;
  final String label;
  final bool used;
  final VoidCallback? onTap;
  final double minHit;
  const DestVarChip({
    super.key,
    required this.token,
    required this.label,
    this.used = false,
    this.onTap,
    this.minHit = 44,
  });

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    return Semantics(
      button: true,
      enabled: !off,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: KeepHitArea(
        onTap: onTap,
        minHeight: minHit,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: VelvetColors.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VelvetColors.border2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (used) ...[
                Icon(
                  Icons.check,
                  size: 14,
                  color: off ? VelvetColors.textTertiary : keepInk(),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  token,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: off
                        ? VelvetColors.textTertiary
                        : VelvetColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Save: an outline in tertiary until there is something to save, then the
/// primary fill; a ring while it is [busy]. [valueKey] is on the pill
/// itself (what the tests find and tap), on a [minHit] band.
class DestSaveButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final Key valueKey;
  final double minHit;
  const DestSaveButton({
    super.key,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
    this.valueKey = const ValueKey('destination-save'),
    this.minHit = 44,
  });

  @override
  Widget build(BuildContext context) {
    final on = enabled && !busy;
    final fg = on ? VelvetColors.onPrimary : VelvetColors.textTertiary;
    return Semantics(
      button: true,
      enabled: on,
      child: KeepHitArea(
        onTap: on ? onTap : null,
        minHeight: minHit,
        child: Container(
          key: valueKey,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on ? keepFill() : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: on ? null : Border.all(color: VelvetColors.border2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 6),
              ],
              // A long label at large text sizes is cut, not overflowed.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// No library, uploads off, a failed read: one card, one pill.
class DestBlockCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? sub;
  final Widget pill;
  const DestBlockCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.sub,
    required this.pill,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        color: VelvetColors.card,
        border: Border.all(color: VelvetColors.border),
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VelvetColors.raised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 15,
              height: 20 / 15,
            ),
          ),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          pill,
        ],
      ),
    ),
  );
}
