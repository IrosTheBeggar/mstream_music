import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../util/browse_keep_leads.dart' show KeepSubject;
import '../util/discover_badges.dart';
import '../util/discover_copy_gate.dart' show kVariousArtistsKey;
import '../util/plan_artist_albums.dart';
import 'browse_keep_pill.dart';

/// The headers a connected server's pages gain while browsing it, each the
/// first thing its list scrolls (so at large text the list is still
/// reachable): the artist page's — whose page it is, how many albums it
/// lists, and Keep a copy of the artist's own albums — and the open
/// folder's, a compact row below a library's root.

/// The artist page's header (a connected server's artist only):
///
///   ( 56 ) Boukmanflow                    20/700, up to 3 lines
///          4 albums on Stage Peer B       13.5 secondary
///   [ Keep a copy… ]  Takes the 3 albums credited to Boukmanflow
///
/// The takes line goes under the pill once less than 140 pt is left beside
/// it, and the pill takes the full width when it would not fit beside
/// anything. No pill — the line why instead — for an artist who only
/// appears on the server's albums; none at all for Various Artists or a
/// server too old to name its albums' credits. With the gate closed the
/// header is information: an earlier artist copy's state as plain text.
class ArtistPageHeader extends StatelessWidget {
  final ArtistContext artist;

  /// The connected server's name as the page says it.
  final String peerName;

  /// The artist scope's gate is open (the page's snapshot).
  final bool open;

  /// The page marks' artist job (this server's, or another's running).
  final KeepChoiceJob? pick;
  final VoidCallback onKeep;
  final FocusNode? pillFocus;

  /// The header's own node: where focus lands when the pill is gone.
  final FocusNode? headerFocus;

  const ArtistPageHeader({
    super.key,
    required this.artist,
    required this.peerName,
    required this.open,
    required this.pick,
    required this.onKeep,
    this.pillFocus,
    this.headerFocus,
  });

  /// The albums of the artist's own the artist copy takes ("theirs"): the
  /// copy's own rule, on the page's own answer.
  int get theirs => planArtistAlbums(artist.albums, artist.name).plan.length;

  /// Whether an artist copy can be offered at all (not Various Artists, a
  /// server that names credits).
  bool get copyable =>
      nameKey(artist.name) != kVariousArtistsKey && artist.namesCredits;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ts = MediaQuery.textScalerOf(context);
    final sub = l.browseHeadAlbumsOn(artist.albumCount, peerName);
    final form = KeepPillForm.of(l, pick);
    final row = Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: VelvetColors.raised,
            shape: BoxShape.circle,
            border: Border.all(color: VelvetColors.border),
          ),
          child: Icon(Icons.person_outline,
              size: 28, color: VelvetColors.textSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                artist.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.2,
                  color: VelvetColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(
                    fontSize: 13.5, color: VelvetColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
    final title = _HeaderNode(
      label: artist.name,
      value: sub,
      focusNode: headerFocus,
      child: row,
    );

    Widget? action;
    if (copyable && open) {
      final n = theirs;
      if (n == 0) {
        action = _InfoLine(
            key: const ValueKey('browse-artist-no-copy'),
            text: l.browseKeepNoArtistCopy(artist.name));
      } else {
        final takes = l.browseKeepTakes(n, artist.name);
        action = LayoutBuilder(builder: (context, box) {
          // Measured on the widest words the artist's own copy reads in,
          // not its state's: the pill and the takes line never move
          // between states. (Another server's copy wraps in that place.)
          final w = box.maxWidth;
          final slot = KeepPagePill.ownWidth(l, ts);
          final full = ts.scale(1) > 1.3 || slot > w;
          final beside = !full && slot <= w - 12 - 140;
          final pill = KeepPageAction(
            open: true,
            pick: pick,
            subject: KeepSubject.artist,
            name: artist.name,
            peerName: peerName,
            hint: takes,
            fullWidth: full,
            onTap: onKeep,
            focusNode: pillFocus,
          );
          // The takes line is the pill's hint (in every state), never a node
          // of its own.
          final line = ExcludeSemantics(
            child: Text(
              takes,
              key: const ValueKey('browse-artist-takes'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: VelvetColors.textSecondary),
            ),
          );
          if (beside) {
            // Beside it, the pill keeps that place: the takes line starts
            // where it always does.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: slot,
                  child: Align(alignment: Alignment.topLeft, child: pill),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(alignment: Alignment.centerLeft, child: line),
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              full ? pill : Align(alignment: Alignment.centerLeft, child: pill),
              const SizedBox(height: 6),
              line,
            ],
          );
        });
      }
    } else if (copyable &&
        KeepPageAction.shows(l, false, pick)) {
      action = KeepPageAction(
        open: false,
        pick: pick,
        subject: KeepSubject.artist,
        name: artist.name,
        peerName: peerName,
        onTap: onKeep,
      );
    }

    return _HeaderFrame(
      key: const ValueKey('browse-artist-header'),
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      fraction: open && form.live ? form.fraction : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          title,
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }
}

/// The open folder's header (a connected server's folder below its
/// library's root), about 64 pt at 1.0×:
///
///   Boukmanflow  ·  Folder on Stage Peer B · 3 folders   [ Keep a copy… ]
///
/// Above 1.3× text, or with less than 150 pt left for the text beside the
/// widest words a folder copy reads in ([KeepPagePill.ownWidth]), the pill
/// goes under it — measured once, so it never moves between states. The
/// counts are the one fact the sub line adds, so they never give way
/// ([fitted]): where the line would not fit, the server's name is
/// shortened first. With the gate closed the page shows the header only for
/// an earlier (or running) copy of the folder, its state as plain text in
/// the pill's place — the caller asks [KeepPageAction.shows] first.
class FolderPageHeader extends StatelessWidget {
  /// The folder's own name.
  final String name;

  /// The open folder's own listing: its folders and its songs (an .m3u is
  /// no song), nothing counted below.
  final int folders;
  final int songs;
  final String peerName;
  final bool open;
  final KeepChoiceJob? pick;
  final VoidCallback onKeep;
  final FocusNode? pillFocus;
  final FocusNode? headerFocus;

  const FolderPageHeader({
    super.key,
    required this.name,
    required this.folders,
    required this.songs,
    required this.peerName,
    required this.open,
    required this.pick,
    required this.onKeep,
    this.pillFocus,
    this.headerFocus,
  });

  /// The open folder's counts: its folders, then its songs — each held
  /// together ("3 songs" never ends a line at "3").
  static List<String> countsOf(AppLocalizations l,
      {required int folders, required int songs}) {
    String held(String count) => count.replaceAll(' ', ' ');
    return [
      if (folders > 0) held(l.browseHeadFolders(folders)),
      if (songs > 0) held(l.discoverSheetSongCount(songs)),
    ];
  }

  /// The header's second part, whole: "Folder on Stage Peer B · 3 folders
  /// · 2 songs" (a screen reader's value, whatever the line draws).
  static String subOf(AppLocalizations l, String peerName,
          {required int folders, required int songs}) =>
      [
        l.browseHeadFolderOn(peerName),
        ...countsOf(l, folders: folders, songs: songs),
      ].join(' · ');

  /// The name and sub line the header draws, as they [fits] its text's
  /// place (a TextPainter at its style, width and lines): whole where they
  /// fit. Else the counts keep their place and the rest gives way — the
  /// server's name shortened with a trailing "…" (the longest cut that
  /// fits), then "Folder on …" gone, then the folder's own name shortened.
  /// Null where not even that leaves the counts room: the header draws the
  /// name and the counts whole, in the lines they take. With nothing
  /// counted, the line's own ellipsis cuts the server's name.
  (String, String)? fitted(
      AppLocalizations l, bool Function(String folder, String sub) fits) {
    final counts = countsOf(l, folders: folders, songs: songs);
    final whole = subOf(l, peerName, folders: folders, songs: songs);
    if (counts.isEmpty || fits(name, whole)) return (name, whole);
    String sub(String peer) =>
        [l.browseHeadFolderOn(peer), ...counts].join(' · ');
    final peer = _longestCut(peerName, (cut) => fits(name, sub(cut)));
    if (peer != null) return (name, sub(peer));
    final bare = counts.join(' · ');
    if (fits(name, bare)) return (name, bare);
    final short = _longestCut(name, (cut) => fits(cut, bare));
    return short == null ? null : (short, bare);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ts = MediaQuery.textScalerOf(context);
    final large = ts.scale(1) > 1.3;
    final lines = large ? 3 : 2;
    final form = KeepPillForm.of(l, pick);
    final action = KeepPageAction(
      open: open,
      pick: pick,
      subject: KeepSubject.folder,
      name: name,
      peerName: peerName,
      onTap: onKeep,
      focusNode: pillFocus,
    );
    // Its style as drawn — the theme's body text under it, bold where the
    // phone asks for bold text — so the line measured is the line drawn.
    var style = DefaultTextStyle.of(context)
        .style
        .merge(TextStyle(fontSize: 13, color: VelvetColors.textSecondary));
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    TextSpan line(String folder, String sub) =>
        TextSpan(style: style, children: [
          TextSpan(
            text: folder,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: VelvetColors.textPrimary,
            ),
          ),
          TextSpan(text: '  ·  $sub'),
        ]);
    Widget text(double width) {
      bool fits(String folder, String sub) {
        if (!width.isFinite) return true;
        final p = TextPainter(
          text: line(folder, sub),
          textDirection: Directionality.of(context),
          textScaler: ts,
          maxLines: lines,
        )..layout(maxWidth: width);
        final over = p.didExceedMaxLines;
        p.dispose();
        return !over;
      }

      final fit = fitted(l, fits);
      final (shown, sub) = fit ??
          (name, countsOf(l, folders: folders, songs: songs).join(' · '));
      return _HeaderNode(
        label: name,
        value: subOf(l, peerName, folders: folders, songs: songs),
        focusNode: headerFocus,
        child: Text.rich(
          line(shown, sub),
          key: const ValueKey('browse-folder-head-text'),
          maxLines: fit == null ? null : lines,
          overflow: fit == null ? null : TextOverflow.ellipsis,
        ),
      );
    }

    return _HeaderFrame(
      key: const ValueKey('browse-folder-header'),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      fraction: open && form.live ? form.fraction : null,
      child: LayoutBuilder(builder: (context, box) {
        // The widest words a folder copy reads in (the plain-text state is
        // its glyph and gap beside them, no box), and 150 pt left for the
        // text.
        final slot = KeepPagePill.ownWidth(l, ts) -
            (open ? 0 : KeepPagePill.chrome - 22);
        final under = large || box.maxWidth - 12 - slot < 150;
        if (under) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              text(box.maxWidth),
              const SizedBox(height: 8),
              action,
            ],
          );
        }
        // Beside the text, the pill keeps that place (the plain-text state
        // its own): the text never reflows as it changes.
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(child: text(box.maxWidth - 12 - slot)),
              const SizedBox(width: 12),
              SizedBox(
                width: slot,
                // As tall as the pill (and its live line), whatever holds
                // the header.
                child: Align(
                  alignment: Alignment.centerLeft,
                  heightFactor: 1,
                  child: action,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// The longest cut of [s] that [fits] — its first n characters (1 …
/// length − 1) and a trailing "…" — found by halving (a long name is a
/// handful of layouts, not one a character); null when none does.
String? _longestCut(String s, bool Function(String cut) fits) {
  final chars = s.characters.toList();
  String cut(int n) => '${chars.take(n).join().trimRight()}…';
  // Shorter fits more.
  var lo = 1, hi = chars.length - 1, best = 0;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    if (fits(cut(mid))) {
      best = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best == 0 ? null : cut(best);
}

/// A page header's own node for a screen reader — its name, its facts as
/// the value — which focus can land on when a Keep sheet's opener is gone.
class _HeaderNode extends StatelessWidget {
  final String label;
  final String value;
  final FocusNode? focusNode;
  final Widget child;
  const _HeaderNode({
    required this.label,
    required this.value,
    required this.focusNode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        header: true,
        label: label,
        value: value,
        child: Focus(
          focusNode: focusNode,
          child: ExcludeSemantics(child: child),
        ),
      );
}

/// A header's box: its padding, the 1 pt rule under it, and the 3 pt bar
/// along that edge while its own copy copies.
class _HeaderFrame extends StatelessWidget {
  final EdgeInsets padding;
  final double? fraction;
  final Widget child;
  const _HeaderFrame({
    super.key,
    required this.padding,
    required this.fraction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Stack(
        children: [
          Padding(padding: padding, child: child),
          if (f != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: KeepHeaderBar(fraction: f),
            ),
        ],
      ),
    );
  }
}

/// A quiet line with an info glyph: why there is no pill.
class _InfoLine extends StatelessWidget {
  final String text;
  const _InfoLine({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline,
                size: 14, color: VelvetColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13, height: 1.35, color: VelvetColors.textSecondary),
            ),
          ),
        ],
      );
}

/// The album banner's line when its songs name different album artists
/// (no album copy: its songs go one by one) — the info glyph and 12.5/1.35
/// secondary text, in the pill's place.
class KeepNoCreditLine extends StatelessWidget {
  const KeepNoCreditLine({super.key});

  @override
  Widget build(BuildContext context) => Row(
        key: const ValueKey('browse-keep-no-credit'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline,
                size: 14, color: VelvetColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppLocalizations.of(context).browseKeepNoCredit,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: VelvetColors.textSecondary),
            ),
          ),
        ],
      );
}
