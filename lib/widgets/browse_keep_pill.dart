import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery_plugins.dart';
import '../screens/discovery/keep_copy_ui.dart';
import '../theme/velvet_theme.dart';
import '../util/browse_keep_leads.dart' show KeepSubject;
import '../util/discover_badges.dart';
import 'browse_keep_entry.dart';
import 'keep_folder_glyph.dart';

/// Keep a copy on a connected server's page about one thing — its album,
/// its artist, the open folder (the phone spec's page pill): one 44 pt
/// pill under the page's facts, never in the toolbar (whose ⊞ Add all
/// means the queue). Opaque on the sheet's ground with a gold edge, so its
/// words keep 4.5:1 over the album's colour wash; later it carries that
/// copy's state. A tap, in every state, opens the sheet for its own scope —
/// it never starts, cancels or retries anything.
///
/// With the gate closed the page keeps an earlier (or running) copy's state
/// as plain text in the pill's place ([KeepPlainState]) — information, not
/// a button.

/// The glyph a pill's state leads with.
enum KeepPillGlyph { keep, clock, ring, dot, otherDot, check, owned, warning, error }

/// What a page pill shows for its job (the spec's pill forms): the glyph,
/// the words, their colour, and whether the edge is the final states' grey.
/// The box never changes height.
class KeepPillForm {
  final KeepPillGlyph glyph;
  final String words;
  final Color wordColor;

  /// The final states' (and another server's) quiet edge: border2.
  final bool settled;

  /// This page's own copy is waiting, starting, copying or stopping: the
  /// live line shows under the pill.
  final bool live;

  /// Its copy's fraction while it copies (the header's 3 pt bar).
  final double? fraction;

  /// Another server's copy of the same album or artist, running: its name
  /// ("Copying from Stage Peer C"), shortened before the verb ever is.
  final String? otherPeer;

  const KeepPillForm._(
    this.glyph,
    this.words,
    this.wordColor, {
    this.settled = false,
    this.live = false,
    this.fraction,
    this.otherPeer,
  });

  /// No copy (or a cancelled one): "Keep a copy…".
  bool get idle => glyph == KeepPillGlyph.keep;

  /// [pick]'s form ([album]: an album pill's name — an artist walk counts
  /// only while it is on that album).
  static KeepPillForm of(AppLocalizations l, KeepChoiceJob? pick,
      {String? album}) {
    final idle = KeepPillForm._(
        KeepPillGlyph.keep, l.browseKeepButton, keepInk());
    final job = pick?.job;
    if (job == null) return idle;
    final text = VelvetColors.textPrimary;
    if (pick!.fromOtherPeer) {
      final peer = job.peerName ?? '';
      return KeepPillForm._(
          KeepPillGlyph.otherDot, l.discoverJobFromOther(peer), text,
          settled: true, otherPeer: peer);
    }
    if (job.state == JobState.running &&
        !job.cancelRequested &&
        (job.statusText ?? '').isEmpty &&
        job.progress == null) {
      return KeepPillForm._(KeepPillGlyph.ring, l.discoverJobStarting, text,
          live: true);
    }
    final m = markerOfJob(job, album: album);
    if (m == null) return idle;
    final words = keepStateWord(l, m);
    switch (m.kind) {
      case CopyMarkerKind.waiting:
        return KeepPillForm._(KeepPillGlyph.clock, words, text, live: true);
      case CopyMarkerKind.copying:
      case CopyMarkerKind.stopping:
        return KeepPillForm._(KeepPillGlyph.dot, words, text,
            live: true,
            fraction: m.kind == CopyMarkerKind.copying ? job.progress : null);
      case CopyMarkerKind.inCollection:
        return KeepPillForm._(
            KeepPillGlyph.check, words, keepTone(VelvetColors.success),
            settled: true);
      case CopyMarkerKind.alreadyYours:
        return KeepPillForm._(KeepPillGlyph.owned, words, text, settled: true);
      case CopyMarkerKind.skipped:
      case CopyMarkerKind.stopped:
      case CopyMarkerKind.refused:
        return KeepPillForm._(
            KeepPillGlyph.warning, words, keepTone(VelvetColors.warning),
            settled: true);
      case CopyMarkerKind.failed:
        return KeepPillForm._(
            KeepPillGlyph.error, words, keepTone(VelvetColors.error),
            settled: true);
    }
  }

  /// The form with another server's name shortened ([otherPeer] only).
  KeepPillForm _named(AppLocalizations l, String peer) => KeepPillForm._(
      glyph, l.discoverJobFromOther(peer), wordColor,
      settled: settled, live: live, fraction: fraction, otherPeer: otherPeer);

  /// The pill's accessible name for the thing it keeps ([name] of
  /// [subject]): "Keep a copy of Borrowed Tapes…" idle, else "Borrowed
  /// Tapes: In your collection. Open the copy" — and, while it copies,
  /// where its files go ([into], "/"-joined for speech).
  String label(AppLocalizations l,
      {required KeepSubject subject, required String name, String? into}) {
    if (idle) {
      return switch (subject) {
        KeepSubject.artist => l.browseKeepOfArtist(name),
        KeepSubject.folder => l.browseKeepOfFolder(name),
        KeepSubject.album || KeepSubject.song => l.browseKeepOfItem(name),
      };
    }
    if (live && into != null && into.isNotEmpty) {
      return l.browseKeepStateIntoAria(name, words, into);
    }
    return l.browseKeepStateAria(name, words);
  }

  /// The glyph at [size] in its own colour ([page]: drawn on the page's
  /// ground, the plain-text state, rather than the pill's).
  Widget glyphWidget({double size = 18, bool page = false}) {
    Color tone(Color c) => page ? keepToneOnPage(c) : keepTone(c);
    final ink = page ? keepInkOnPage() : keepInk();
    Widget dot(Color c) => SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ),
        );
    return switch (glyph) {
      KeepPillGlyph.keep => KeepFolderGlyph(size: size, color: ink),
      KeepPillGlyph.clock =>
        Icon(Icons.schedule, size: size, color: VelvetColors.textSecondary),
      KeepPillGlyph.ring => SizedBox(
          width: size,
          height: size,
          child: Center(child: KeepRing(size: 14, color: ink)),
        ),
      KeepPillGlyph.dot => dot(ink),
      KeepPillGlyph.otherDot => dot(VelvetColors.textTertiary),
      KeepPillGlyph.check => Icon(Icons.check_circle_outline,
          size: size, color: tone(VelvetColors.success)),
      KeepPillGlyph.owned => Icon(Icons.check_circle_outline,
          size: size, color: VelvetColors.textSecondary),
      KeepPillGlyph.warning => Icon(Icons.warning_amber_rounded,
          size: size, color: tone(VelvetColors.warning)),
      KeepPillGlyph.error =>
        Icon(Icons.error_outline, size: size, color: tone(VelvetColors.error)),
    };
  }
}

/// The page pill (see the top of this file).
class KeepPagePill extends StatelessWidget {
  final KeepPillForm form;

  /// Its accessible name ([KeepPillForm.label]) and, for the artist's
  /// pill, its hint (the takes line, in every state).
  final String label;
  final String? hint;

  /// Under the cover at the column's full width, its content centred (the
  /// narrow rule); else its natural width.
  final bool fullWidth;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const KeepPagePill({
    super.key,
    required this.form,
    required this.label,
    this.hint,
    this.fullWidth = false,
    required this.onTap,
    this.focusNode,
  });

  static const double _minHeight = 44;

  /// What the pill's box takes beside its words: its padding, glyph, gap
  /// and edge.
  static const double chrome = 54;

  // Its letter spacing set, not inherited from the theme's body text: the
  // words drawn are as wide as the words measured.
  static TextStyle _style(Color c) => TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0,
      color: c);

  /// The widest words a page's pill can read, on one line at a scale (the
  /// words — so the locale and the page's server — and the scale are the
  /// key): measured once, however often the page rebuilds.
  static final Map<String, double> _widest = {};

  /// What [fitOther] shortened a server's name to, by words, width and
  /// scale (the pill rebuilds on every poll while another server copies).
  static final Map<String, String> _shortened = {};

  /// Whether the pill fits beside the page's other content in a text column
  /// of [columnWidth] at [textScaler]: the widest of "Keep a copy…", "In
  /// your collection" and "Copying from {this page's server}" on one line,
  /// plus its chrome — and never above 1.3× text. Measured once a page, so
  /// the pill never moves between states.
  static bool fitsBeside(AppLocalizations l, double columnWidth,
          TextScaler textScaler, String peerName) =>
      textScaler.scale(1) <= 1.3 &&
      widestWidth(l, textScaler, peerName) <= columnWidth;

  /// The pill's widest form on one line at [textScaler], its chrome
  /// included ([fitsBeside]'s measure).
  static double widestWidth(
          AppLocalizations l, TextScaler textScaler, String peerName) =>
      _widestOf([
        l.browseKeepButton,
        l.discoverJobInCollection,
        l.discoverJobFromOther(peerName),
      ], textScaler) +
      chrome;

  /// The widest word the page's own copy reads in — every state's but a
  /// count's — on one line at [textScaler], its chrome included: the place
  /// a page header keeps for the pill beside its text (measured once a
  /// page, so nothing beside it reflows as its words change). A longer
  /// state — a count past it, another server's "Copying from …", its name
  /// shortened first — wraps to two lines there, rather than the widest
  /// form keeping the header's compact row from every phone. (A folder's
  /// pill never reads another server's: a folder copy keys on its server.)
  static double ownWidth(AppLocalizations l, TextScaler textScaler) =>
      _widestOf([
        l.browseKeepButton,
        l.discoverJobStarting,
        l.browseKeepPillWaiting,
        l.discoverJobCopying,
        l.discoverJobStopping,
        l.discoverJobInCollection,
        l.discoverJobOwned,
        l.browseKeepPillSkipped,
        l.discoverJobStopped,
        l.browseKeepPillRefused,
        l.discoverJobFailed,
      ], textScaler) +
      chrome;

  /// The widest of [words] on one line at [textScaler] (no chrome).
  static double _widestOf(List<String> words, TextScaler textScaler) {
    final key = '${words.join('\u0000')}|${textScaler.scale(14)}';
    return _widest[key] ??= () {
      var w = 0.0;
      for (final s in words) {
        final p = TextPainter(
          text: TextSpan(text: s, style: _style(VelvetColors.textPrimary)),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        if (p.width > w) w = p.width;
        p.dispose();
      }
      return w;
    }();
  }

  /// "Copying from {peer}" in two lines of [width] at most: the server's
  /// name shortened with a trailing "…", never the verb — the longest cut
  /// that fits, found by halving (a long name is a handful of layouts, not
  /// one a character).
  static String fitOther(AppLocalizations l, String peer, double width,
      TextScaler textScaler) {
    bool fits(String s) {
      final p = TextPainter(
        text: TextSpan(text: s, style: _style(VelvetColors.textPrimary)),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 2,
      )..layout(maxWidth: width);
      final over = p.didExceedMaxLines;
      p.dispose();
      return !over;
    }

    if (width <= 0) return peer;
    final key = '${l.discoverJobFromOther(peer)}|$width|${textScaler.scale(14)}';
    return _shortened[key] ??= () {
      if (fits(l.discoverJobFromOther(peer))) return peer;
      final chars = peer.characters.toList();
      String cut(int n) => '${chars.take(n).join().trimRight()}…';
      // The longest n in 1 … length − 1 that fits (shorter fits more).
      var lo = 1, hi = chars.length - 1, best = 0;
      while (lo <= hi) {
        final mid = (lo + hi) ~/ 2;
        if (fits(l.discoverJobFromOther(cut(mid)))) {
          best = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      return best == 0 ? '…' : cut(best);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final edge = form.settled
        ? VelvetColors.border2
        : keepInk().withValues(alpha: 0.6);
    final radius = BorderRadius.circular(22);
    return LayoutBuilder(builder: (context, box) {
      var f = form;
      final other = form.otherPeer;
      if (other != null && box.maxWidth.isFinite) {
        final short = fitOther(l, other, box.maxWidth - chrome,
            MediaQuery.textScalerOf(context));
        if (short != other) f = form._named(l, short);
      }
      final words = Text(
        f.words,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.start,
        style: _style(f.wordColor),
      );
      final pill = Material(
        color: VelvetColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: edge, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: focusNode,
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                child: Row(
                  mainAxisSize:
                      fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: fullWidth
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    f.glyphWidget(),
                    const SizedBox(width: 8),
                    // Its natural width where nothing bounds it.
                    box.maxWidth.isFinite ? Flexible(child: words) : words,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // One node: its name and hint here, its tap and its focus the
      // InkWell's — so focus coming back to the pill is the node a screen
      // reader is on.
      return Semantics(
        key: const ValueKey('browse-keep-pill'),
        container: true,
        button: true,
        label: label,
        hint: hint,
        child: fullWidth
            ? SizedBox(width: double.infinity, child: pill)
            : pill,
      );
    });
  }
}

/// The 44 pt the album pill will take, held empty while the album's credit
/// resolves, so the pill landing moves nothing on the page.
class KeepReservedSlot extends StatelessWidget {
  const KeepReservedSlot({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
        child: SizedBox(
            key: ValueKey('browse-keep-reserved'), height: 44, width: 1),
      );
}

/// The gate closed, an earlier or running copy on the page: its state as
/// plain text in the pill's place — the status glyph in its colour, the
/// word in the page's primary text (legible on the album's wash). 32 pt,
/// not a button.
class KeepPlainState extends StatelessWidget {
  final KeepPillForm form;

  /// What it is the state of ("Borrowed Tapes"), for a screen reader.
  final String name;
  const KeepPlainState({super.key, required this.form, required this.name});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey('browse-keep-plain'),
      label: l.browseKeepStatePlainAria(name, form.words),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            form.glyphWidget(size: 16, page: true),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                form.words,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: VelvetColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under a live pill: "Copies keep going if you leave this page or Stage
/// Peer B." — the copy runs on the user's server, not on this page.
class KeepLiveLine extends StatelessWidget {
  final String peerName;
  const KeepLiveLine({super.key, required this.peerName});

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('browse-keep-live-line'),
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          AppLocalizations.of(context).browseKeepKeepsGoing(peerName),
          style: TextStyle(
              fontSize: 12, height: 1.4, color: VelvetColors.textSecondary),
        ),
      );
}

/// The 3 pt bar along a page header's bottom edge while its own copy
/// copies and says how far ([fraction]); the pill's name already carries
/// the count, so a screen reader skips it.
class KeepHeaderBar extends StatelessWidget {
  final double fraction;
  const KeepHeaderBar({super.key, required this.fraction});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          key: const ValueKey('browse-keep-bar'),
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 3,
            color: keepInk(),
            backgroundColor: VelvetColors.border,
          ),
        ),
      );
}

/// A page header's Keep a copy slot for [subject] [name]: with the gate
/// open for its scope ([open]) the pill — and the live line under it while
/// its own copy runs — else, an earlier or running copy of this server's
/// on the page, its state as plain text; else nothing. [pick] is the page
/// marks' job for it; [album] an album pill's name (its counts).
class KeepPageAction extends StatelessWidget {
  final bool open;
  final KeepChoiceJob? pick;
  final KeepSubject subject;
  final String name;
  final String peerName;
  final String? album;
  final String? hint;
  final bool fullWidth;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const KeepPageAction({
    super.key,
    required this.open,
    required this.pick,
    required this.subject,
    required this.name,
    required this.peerName,
    this.album,
    this.hint,
    this.fullWidth = false,
    required this.onTap,
    this.focusNode,
  });

  /// Whether anything shows for [open] and [pick] (a folder header, shown
  /// with the gate closed only for its copy, asks first).
  static bool shows(AppLocalizations l, bool open, KeepChoiceJob? pick) =>
      open ||
      (pick != null &&
          !pick.fromOtherPeer &&
          !KeepPillForm.of(l, pick).idle);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final form = KeepPillForm.of(l, pick, album: album);
    if (!open) {
      if (pick == null || pick!.fromOtherPeer || form.idle) {
        return const SizedBox.shrink();
      }
      return KeepPlainState(form: form, name: name);
    }
    final into = form.live && pick != null ? keepJobInto(l, pick!.job) : null;
    return Column(
      crossAxisAlignment:
          fullWidth ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KeepPagePill(
          form: form,
          label: form.label(l, subject: subject, name: name, into: into),
          hint: hint,
          fullWidth: fullWidth,
          onTap: onTap,
          focusNode: focusNode,
        ),
        if (form.live) KeepLiveLine(peerName: peerName),
      ],
    );
  }
}
