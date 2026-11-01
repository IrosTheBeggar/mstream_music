import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery_plugins.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_badges.dart';
import '../../util/discover_jobs.dart';

/// The Keep a copy surfaces' small parts (the design canvas's phone kit):
/// the colour roles the canvas added on top of VelvetColors, the choice
/// chip, the pill, the ring glyph, the skeleton block — and the words a
/// job's line and a page marker read as, from the pure job logic's phrases
/// (util/discover_jobs.dart, util/discover_badges.dart). The server's own
/// words pass through untouched.

// ── colour roles ──────────────────────────────────────────────────────────

double _lum(Color c) => c.computeLuminance();
double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [c] darkened (on a light ground) or lightened (on a dark one) until it
/// reads at 4.5:1 on [ground].
Color _readable(Color c, Color ground) {
  if (_contrast(c, ground) >= 4.5) return c;
  final darken = _lum(ground) > 0.4;
  var hsl = HSLColor.fromColor(c);
  for (var i = 0; i < 30 && _contrast(hsl.toColor(), ground) < 4.5; i++) {
    hsl = hsl.withLightness(
      (hsl.lightness + (darken ? -0.03 : 0.03)).clamp(0.0, 1.0),
    );
  }
  return hsl.toColor();
}

/// Text in the primary's place (the canvas's --ptext): the primary where it
/// reads at 4.5:1 on the sheet (Dark's amber), else the accent (Velvet's
/// blue), else the primary darkened (Light's #8A5A00-ish amber).
Color keepInk() {
  final ground = VelvetColors.surface;
  final p = VelvetColors.primary;
  if (_contrast(p, ground) >= 4.5) return p;
  final a = VelvetColors.accent;
  if (_contrast(a, ground) >= 4.5) return a;
  return _readable(p, ground);
}

/// What an on-primary label sits on (the canvas's --pfill): the primary,
/// or its darker hover shade where white on the primary falls under 4.5:1
/// (Velvet's violet).
Color keepFill() {
  final p = VelvetColors.primary;
  final on = VelvetColors.onPrimary;
  if (_contrast(on, p) >= 4.5) return p;
  final h = VelvetColors.primaryHover;
  return _contrast(on, h) > _contrast(on, p) ? h : p;
}

/// A status colour (success / warning / error) that reads at 4.5:1 on the
/// Keep card (Light's are darkened, as the canvas's are).
Color keepTone(Color c) => _readable(c, VelvetColors.card);

/// The same, on the page's ground (the row markers' glyphs).
Color keepToneOnPage(Color c) => _readable(c, VelvetColors.bg);

/// The same, on any [ground] (text on a raised card).
Color keepToneOn(Color c, Color ground) => _readable(c, ground);

// ── pieces ────────────────────────────────────────────────────────────────

/// A 44 px tall hit band around a smaller control.
class KeepHitArea extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  /// The band's height: 44 for Discover's surfaces; Add from YouTube's
  /// sheets ask for 48.
  final double minHeight;
  const KeepHitArea({
    super.key,
    required this.onTap,
    required this.child,
    this.minHeight = 44,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    ),
  );
}

/// A pill (DiscoveryPill's shape): 36 px, radius 18, 13/600. [primary]
/// fills it ([keepFill]); [expand] stretches it to the row; [busy] puts a
/// 14 px ring before the label and ignores taps.
class KeepPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool primary;
  final bool expand;
  final bool busy;
  final VoidCallback? onTap;
  const KeepPill(
    this.label, {
    super.key,
    this.icon,
    this.primary = false,
    this.expand = false,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? VelvetColors.onPrimary : VelvetColors.textPrimary;
    final tap = busy ? null : onTap;
    final pill = Material(
      color: primary ? keepFill() : VelvetColors.raised,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
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
    return Semantics(
      button: true,
      enabled: tap != null,
      child: KeepHitArea(onTap: tap, child: pill),
    );
  }
}

/// One choice of what to keep (FedChipRow's chip in the canvas's size): a
/// 13/600 label over an 11 px size line ([size]; [sizeLoading] draws a
/// skeleton in its place). Selected: primary-dim fill, 1.5 px primary edge.
class KeepChoice extends StatelessWidget {
  final String label;
  final String? size;
  final bool sizeLoading;
  final bool selected;
  final VoidCallback onTap;
  const KeepChoice({
    super.key,
    required this.label,
    this.size,
    this.sizeLoading = false,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected ? VelvetColors.primaryDim : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? VelvetColors.primary : VelvetColors.border2,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (sizeLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 1),
                    child: KeepSkeleton(width: 56, height: 10),
                  )
                else if (size != null && size!.isNotEmpty)
                  Text(
                    size!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
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

/// A still placeholder block (no animation: a sheet that waits on a slow
/// server never spins forever).
class KeepSkeleton extends StatelessWidget {
  final double width;
  final double height;
  const KeepSkeleton({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('keep-skeleton'),
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// The copying glyph: a ring with a quarter arc, drawn still (the bar or
/// the strip says it moves).
class KeepRing extends StatelessWidget {
  final double size;
  final Color color;
  const KeepRing({super.key, this.size = 16, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _RingPainter(color)),
  );
}

class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.14;
    final r = (size.shortestSide - stroke) / 2;
    final c = size.center(Offset.zero);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.3);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 0.66,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

/// The section label inside a sheet (11/700 caps, tertiary).
class KeepSheetLabel extends StatelessWidget {
  final String text;
  const KeepSheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: VelvetColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );
}

// ── words ─────────────────────────────────────────────────────────────────

/// One part of a job's line ([JobText]) in the user's language; the
/// server's own words as they came. [peer] stands in when the part names
/// no server; [artist] is the row's.
String keepJobText(
  AppLocalizations l,
  JobText t, {
  String peer = '',
  String artist = '',
}) {
  final server = t.server;
  if (server != null) return server;
  final n = t.count ?? 0;
  final who = (t.peer ?? '').isNotEmpty ? t.peer! : peer;
  return switch (t.phrase!) {
    JobPhrase.queued => l.discoverJobQueued,
    JobPhrase.queuedSub => l.discoverJobQueuedSub,
    JobPhrase.stopping => l.discoverJobStopping,
    JobPhrase.copying => l.discoverJobCopying,
    JobPhrase.downloading => l.discoverJobCopying,
    JobPhrase.starting => l.discoverJobStarting,
    JobPhrase.failed => l.discoverJobFailed,
    JobPhrase.failedSub => l.discoverJobFailedSub,
    JobPhrase.cancelled => l.discoverJobCancelledNothing,
    JobPhrase.cancelledMany => l.discoverJobCancelledSub,
    JobPhrase.cancelledSub => l.discoverJobCancelledSub,
    JobPhrase.cancelledCopySub => l.discoverJobCancelledSub,
    JobPhrase.stopped => l.discoverJobStopped,
    JobPhrase.stoppedQuota => l.discoverJobStoppedQuota(who),
    JobPhrase.stoppedBusy => l.discoverJobStoppedBusy(who),
    JobPhrase.stoppedPeer => l.discoverJobStoppedPeer(who),
    JobPhrase.stoppedRefused => l.discoverJobStoppedRefused(who),
    JobPhrase.inCollection => l.discoverJobInCollection,
    JobPhrase.owned => l.discoverJobOwned,
    JobPhrase.ownedSub => l.discoverJobOwnedSub,
    JobPhrase.skipped => l.discoverJobSkipped,
    JobPhrase.existsSub => l.discoverJobExistsSub(t.path ?? ''),
    JobPhrase.nothing => l.discoverJobNothingAll,
    JobPhrase.nothingToCopy => l.discoverJobNothingFrom(who),
    JobPhrase.onlyAppearances => l.discoverJobOnlyGuestSub(artist, who),
    JobPhrase.done => l.discoverJobDone,
    JobPhrase.savedTo => t.path ?? '',
    JobPhrase.albumsCount => l.discoverSheetAlbumCount(n),
    JobPhrase.copiedCount => l.discoverJobCopiedCount(n),
    JobPhrase.ownedCount => l.discoverJobOwnedCount(n),
    JobPhrase.failedCount => l.discoverJobFailedCount(n),
    JobPhrase.albumsFailed => l.discoverJobAlbumsFailed(n),
    JobPhrase.albumsLeftOut => l.discoverJobAlbumsLeftOut(n),
  };
}

/// A slot's word in the user's language, between ‹ › ("‹artist›"): a
/// per-song variable a path not landed yet cannot promise one value for
/// ([scopeTarget]).
String keepSlotWord(AppLocalizations l, LayoutSlot slot) {
  final word = switch (slot) {
    LayoutSlot.artist => l.discoverDestArtistSlot,
    LayoutSlot.year => l.discoverDestYearSlot,
    LayoutSlot.genre => l.discoverDestGenreSlot,
    LayoutSlot.serverFolder => l.discoverDestServerFolderSlot,
  };
  return '‹$word›';
}

/// A path's [crumbs] as one plain line ("copies › From friends ›
/// ‹artist›"), each slot as its word.
String keepPathText(AppLocalizations l, List<String> crumbs) =>
    crumbs.map((c) => slotText(c, (s) => keepSlotWord(l, s))).join(' › ');

/// The one quiet line under a path that shows [slots] (null when it shows
/// none): they come from each song's own tags — ‹server folder› from where
/// each song sits on the server — so the songs can land in more than one
/// folder, and a song with no genre leaves its folder out. A copy of one
/// song ([scope] [kScopeSong]: only its genre can be a slot) lands in one
/// folder, and says so in its own words.
String? keepSlotNote(
  AppLocalizations l,
  List<LayoutSlot> slots, {
  required String scope,
}) {
  if (slots.isEmpty) return null;
  final tags = [
    for (final s in slots)
      if (s != LayoutSlot.serverFolder) s,
  ];
  final words = tags.map((s) => keepSlotWord(l, s)).join(', ');
  if (scope == kScopeSong) return l.discoverKeepSlotNoteSong(words);
  final genre = tags.contains(LayoutSlot.genre);
  if (tags.length < slots.length) {
    final server = keepSlotWord(l, LayoutSlot.serverFolder);
    if (tags.isEmpty) return l.discoverKeepSlotNoteServer(server);
    return genre
        ? l.discoverKeepSlotNoteServerTagsGenre(tags.length, words, server)
        : l.discoverKeepSlotNoteServerTags(tags.length, words, server);
  }
  return genre
      ? l.discoverKeepSlotNoteGenre(slots.length, words)
      : l.discoverKeepSlotNote(slots.length, words);
}

/// How a slot reads inside a path: quiet and italic, set apart from the
/// folders the layout names (on top of the path's own style).
TextStyle keepSlotStyle() => TextStyle(
  color: VelvetColors.textSecondary,
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w400,
);

/// One segment of a path as spans: its text in [style], each slot's word in
/// [keepSlotStyle] — every part through [hold], so the line breaks only
/// between the › separators.
List<InlineSpan> keepCrumbSpans(
  AppLocalizations l,
  String crumb, {
  TextStyle? style,
  required String Function(String) hold,
}) => [
  for (final p in slotParts(crumb))
    p.slot == null
        ? TextSpan(text: hold(p.text), style: style)
        : TextSpan(
            text: hold(keepSlotWord(l, p.slot!)),
            style: (style ?? const TextStyle()).merge(keepSlotStyle()),
          ),
];

/// A page marker's word: "waiting", "copying…", "in your collection"… On an
/// album card a copy that says how far it is reads "copying 2 of 3" ([card]).
String keepMarkerWord(AppLocalizations l, CopyMarker m, {bool card = false}) =>
    switch (m.kind) {
      CopyMarkerKind.waiting => l.discoverMarkWaiting,
      CopyMarkerKind.copying =>
        card && m.done != null && m.total != null
            ? l.discoverMarkCopyingCount(m.done!, m.total!)
            : l.discoverMarkCopying,
      CopyMarkerKind.stopping => l.discoverMarkStopping,
      CopyMarkerKind.inCollection => l.discoverMarkInCollection,
      CopyMarkerKind.alreadyYours => l.discoverMarkAlreadyYours,
      CopyMarkerKind.stopped => l.discoverMarkStopped,
      CopyMarkerKind.refused => l.discoverMarkRefused,
      CopyMarkerKind.failed => l.discoverMarkFailed,
      CopyMarkerKind.skipped => l.discoverMarkSkipped,
    };

/// A marker's glyph: a clock while it waits, the ring while it copies, a
/// check once it is in (muted when it already was), a warning otherwise.
/// [onScrim] colours it for the dark badge on an album cover.
Widget keepMarkerGlyph(CopyMarker m, {double size = 14, bool onScrim = false}) {
  Color tone(Color c) => onScrim ? c : keepToneOnPage(c);
  final muted = onScrim ? const Color(0xFFBDBDBD) : VelvetColors.textSecondary;
  switch (m.kind) {
    case CopyMarkerKind.waiting:
      return Icon(Icons.schedule, size: size, color: muted);
    case CopyMarkerKind.copying:
    case CopyMarkerKind.stopping:
      // The canvas's --ptext on the row and on the cover's badge alike.
      return KeepRing(size: size, color: keepInkOnPage());
    case CopyMarkerKind.inCollection:
      return Icon(
        Icons.check_circle_outline,
        size: size,
        color: tone(VelvetColors.success),
      );
    case CopyMarkerKind.alreadyYours:
      return Icon(Icons.check_circle_outline, size: size, color: muted);
    case CopyMarkerKind.stopped:
    case CopyMarkerKind.refused:
    case CopyMarkerKind.skipped:
      return Icon(
        Icons.warning_amber_rounded,
        size: size,
        color: tone(VelvetColors.warning),
      );
    case CopyMarkerKind.failed:
      return Icon(
        Icons.warning_amber_rounded,
        size: size,
        color: tone(VelvetColors.error),
      );
  }
}

/// [keepInk] on the page's ground rather than the sheet's.
Color keepInkOnPage() => keepInkOn(VelvetColors.bg);

/// [keepInk] on any [ground] (a home card's).
Color keepInkOn(Color ground) {
  final p = VelvetColors.primary;
  if (_contrast(p, ground) >= 4.5) return p;
  final a = VelvetColors.accent;
  if (_contrast(a, ground) >= 4.5) return a;
  return _readable(p, ground);
}

/// "0:08" for a song, "41:07" for an album.
String keepClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

/// A file's container from its name ("MP3", "FLAC"), or null.
String? keepFormatOf(String? path) {
  final p = path ?? '';
  final dot = p.lastIndexOf('.');
  if (dot < 0 || dot < p.lastIndexOf('/') || dot == p.length - 1) return null;
  final ext = p.substring(dot + 1);
  if (ext.length > 5) return null;
  return ext.toUpperCase();
}

/// A job's peer for its line's reasons: the result's, the
/// recommendation's, else [fallback].
String keepJobPeer(DiscoveryJob job, String fallback) =>
    job.view.peerName ?? job.peerName ?? fallback;
