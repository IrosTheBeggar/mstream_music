import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/ytdl_guess.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_card_parts.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart';

/// The four tag fields inside the result card (spec §3 "Edit tags"):
/// TITLE, ARTIST, ALBUM and YEAR, each with one helper line — where its
/// value came from, "Edited" once typed in, or what a blank field does —
/// and the restore chips that put back what the guess removed.
///
/// A field taking focus keeps itself and the SAVES TO crumbs (under
/// [savesKey]) in view above the keyboard: its scroll padding reaches down
/// to them, so
/// the field's own reveal (on focus, and again as the keyboard rises)
/// brings both. A focus asked from elsewhere (Enter details, the Where
/// sheet's "Edit tags" / "Add a year") is taken on the next build.
class YtdlTagFields extends StatefulWidget {
  final YtdlDraft draft;

  /// The SAVES TO block a focused field keeps in view.
  final GlobalKey savesKey;

  const YtdlTagFields({super.key, required this.draft, required this.savesKey});

  @override
  State<YtdlTagFields> createState() => _YtdlTagFieldsState();
}

class _YtdlTagFieldsState extends State<YtdlTagFields> {
  final Map<YtdlField, GlobalKey> _boxes = {
    for (final f in YtdlField.values) f: GlobalKey(),
  };

  /// How far below each field the SAVES TO block ends: its scroll padding.
  final Map<YtdlField, double> _below = {};

  YtdlDraft get _d => widget.draft;

  @override
  void initState() {
    super.initState();
    for (final f in YtdlField.values) {
      _d.focusFor(f).addListener(_focusMoved);
    }
  }

  @override
  void dispose() {
    for (final f in YtdlField.values) {
      _d.focusFor(f).removeListener(_focusMoved);
    }
    super.dispose();
  }

  void _focusMoved() {
    if (mounted) setState(() {});
  }

  /// After each layout: measure what each field's reveal must reach, then
  /// take a focus asked from elsewhere.
  void _afterLayout(Duration _) {
    if (!mounted) return;
    _measure();
    final f = _d.takeFocusRequest();
    if (f != null) _d.focusFor(f).requestFocus();
  }

  /// What must stay in view under the field: the SAVES TO crumbs (spec
  /// §3) — not the whole block, whose file and left-out lines below them
  /// can make the reveal too tall for what the keyboard leaves. The block
  /// itself when it draws no crumbs (a layout to fix).
  RenderBox? _savesTarget() {
    final root = widget.savesKey.currentContext;
    if (root is! Element) return null;
    RenderBox? crumbs;
    void visit(Element e) {
      if (crumbs != null) return;
      if (e.widget is YtdlCrumbs) {
        final r = e.findRenderObject();
        if (r is RenderBox && r.hasSize) crumbs = r;
        return;
      }
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
    if (crumbs != null) return crumbs;
    final block = root.findRenderObject();
    return block is RenderBox && block.hasSize ? block : null;
  }

  /// [f]'s text line (its RenderEditable), else the field's box.
  RenderBox? _textBox(YtdlField f) {
    final root = _boxes[f]!.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize) return null;
    RenderBox? text;
    void visit(RenderObject r) {
      if (text != null) return;
      if (r is RenderEditable) {
        if (r.hasSize) text = r;
        return;
      }
      r.visitChildren(visit);
    }

    visit(root);
    return text ?? root;
  }

  void _measure() {
    final saves = _savesTarget();
    if (saves == null) return;
    final savesBottom = saves.localToGlobal(Offset(0, saves.size.height)).dy;
    // About 400 px of list remain on an 844 px phone with the keyboard up
    // (spec §3): a reveal taller than what is left would push the field
    // itself off the top, so it stops short of that.
    final height = MediaQuery.sizeOf(context).height;
    final scroll = Scrollable.maybeOf(context)?.position;
    final viewport = scroll != null && scroll.hasViewportDimension
        ? scroll.viewportDimension
        : height;
    // The view's own inset: a Scaffold that resizes for the keyboard hides
    // it from its body's MediaQuery. Before the keyboard is up, allow for
    // the one about to come (about 36% of a phone's height).
    final view = View.of(context);
    final up = view.viewInsets.bottom > 0;
    final keyboard = up ? 0 : height * 0.36;
    var changed = false;
    for (final f in YtdlField.values) {
      // The reveal pads the caret's line, not the field's box: measure
      // from the text's own bottom, 12 px and a border above the box's.
      final box = _textBox(f);
      if (box == null) continue;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      // Room for the line itself and its 40 px top padding.
      final cap = math.max(0.0, viewport - keyboard - box.size.height - 48);
      final below = math.min(math.max(0.0, savesBottom - bottom) + 12, cap);
      if (((_below[f] ?? -100) - below).abs() > 1) {
        _below[f] = below;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    final g = _d.guess;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          l,
          YtdlField.title,
          l.ytdlFieldTitle,
          below: [
            if (_restoreChips(l, g).isNotEmpty)
              Wrap(spacing: 8, children: _restoreChips(l, g)),
          ],
        ),
        const SizedBox(height: 12),
        _field(
          l,
          YtdlField.artist,
          l.torrentArtistLabel,
          check: _d.sourceOf(YtdlField.artist) == YtdlFieldSource.youtubeArtist,
          below: [
            if (_orYoutube(g) case final name?)
              YtdlHelper(l.ytdlOrYoutubeArtist(name)),
            if (_d.canRestoreArtistStrip && g.artistStrip != null)
              Wrap(
                children: [
                  _chip(
                    key: const ValueKey('ytdl-restore-strip'),
                    label: g.artistStrip!,
                    spoken: l.ytdlA11yPutBack(g.artistStrip!),
                    onTap: _d.restoreArtistStrip,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        _field(l, YtdlField.album, l.torrentAlbumLabel),
        const SizedBox(height: 12),
        _field(l, YtdlField.year, l.torrentYearLabel),
      ],
    );
  }

  /// "Or YouTube's artist: …" — the split's artist differs from YouTube's.
  String? _orYoutube(YtdlGuess g) {
    if (g.tier != YtdlTier.split || !_d.canSwap || g.artistAgrees) return null;
    if (g.youtubeArtist.isEmpty) return null;
    if (_d.edited(YtdlField.artist)) return null;
    return g.youtubeArtist;
  }

  /// "↶ (Official Video)", "↶ [HD]", then "↶ Split at -": the pieces still
  /// out of the title, in the order the board draws them. None while the
  /// artist and title are swapped (the FoundCleaned board): a piece put
  /// back would go into what is now the artist.
  List<Widget> _restoreChips(AppLocalizations l, YtdlGuess g) {
    final out = <Widget>[];
    if (_d.swapped) return out;
    final restored = _d.restored;
    for (final kind in [YtdlCut.noise, YtdlCut.split]) {
      for (var i = 0; i < g.fragments.length; i++) {
        final f = g.fragments[i];
        if (f.kind != kind || restored.contains(i)) continue;
        final split = kind == YtdlCut.split;
        out.add(
          _chip(
            key: ValueKey('ytdl-restore-$i'),
            label: split ? l.ytdlRestoreSplit(f.text) : f.text,
            spoken: split
                ? (f.text == ':'
                      ? l.ytdlA11yUndoSplitColon
                      : l.ytdlA11yUndoSplit)
                : l.ytdlA11yPutBack(f.text),
            onTap: () => _d.restore(i),
          ),
        );
      }
    }
    return out;
  }

  /// A restore chip: 32 px drawn (radius 8) on a 48 px band.
  Widget _chip({
    required Key key,
    required String label,
    required String spoken,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: spoken,
    excludeSemantics: true,
    onTap: onTap,
    child: KeepHitArea(
      key: key,
      minHeight: kYtdlHit,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: VelvetColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VelvetColors.border2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.undo, size: 14, color: VelvetColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: VelvetColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    AppLocalizations l,
    YtdlField f,
    String label, {
    bool check = false,
    List<Widget> below = const [],
  }) {
    final year = f == YtdlField.year;
    final invalid = year && _d.yearInvalid;
    final err = ytdlTone(context, VelvetColors.error);
    final radius = BorderRadius.circular(7);
    OutlineInputBorder edge(Color c, double w) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: c, width: w),
    );
    final pad = _below[f] ?? 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: YtdlFieldLabel(label)),
        const SizedBox(height: 4),
        // The caps label above is drawn only; this names the field.
        Semantics(
          key: _boxes[f],
          label: label,
          child: TextField(
            key: ValueKey('ytdl-field-${f.name}'),
            controller: _d.controllerFor(f),
            focusNode: _d.focusFor(f),
            scrollPadding: EdgeInsets.fromLTRB(20, 40, 20, pad),
            keyboardType: year ? TextInputType.number : TextInputType.text,
            inputFormatters: year
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            textInputAction: year ? TextInputAction.done : TextInputAction.next,
            textCapitalization: year
                ? TextCapitalization.none
                : TextCapitalization.words,
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
            cursorColor: VelvetColors.primary,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: VelvetColors.bg,
              constraints: const BoxConstraints(minHeight: kYtdlHit),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: invalid
                  ? edge(err, 1.5)
                  : check
                  ? edge(VelvetColors.primary, 1.5)
                  : edge(VelvetColors.border2, 1),
              focusedBorder: invalid
                  ? edge(err, 1.5)
                  : edge(VelvetColors.primary, 1.5),
              border: edge(VelvetColors.border2, 1),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (invalid)
          YtdlStatusLine(
            key: const ValueKey('ytdl-year-error'),
            icon: Icons.error_outline,
            color: err,
            fontSize: 12,
            text: l.ytdlYearInvalid,
          )
        else
          YtdlHelper(_helper(l, f), key: ValueKey('ytdl-help-${f.name}')),
        ...below,
      ],
    );
  }

  /// The field's one helper line (spec §3): its source, "Edited" once
  /// typed in, or — empty, typed or not — what a blank field does (the
  /// FoundMusic board: "an emptied one [switches] to its blank line").
  String _helper(AppLocalizations l, YtdlField f) {
    final g = _d.guess;
    final source = _d.controllerFor(f).text.trim().isEmpty
        ? YtdlFieldSource.blank
        : _d.sourceOf(f);
    if (source == YtdlFieldSource.edited) return l.ytdlHelpEdited;
    switch (f) {
      case YtdlField.title:
        return switch (source) {
          YtdlFieldSource.blank => l.ytdlBlankTitle,
          YtdlFieldSource.music => l.ytdlHelpMusic,
          YtdlFieldSource.videoTitleCleaned => l.ytdlHelpVideoTitleCleaned,
          _ => l.ytdlHelpVideoTitle,
        };
      case YtdlField.artist:
        if (source == YtdlFieldSource.blank) {
          if (g.tier == YtdlTier.music) return l.ytdlBlankArtistMusic;
          final raw = g.youtubeArtistRaw.trim();
          return raw.isEmpty
              ? l.ytdlBlankArtistGuessUnnamed
              : l.ytdlBlankArtistGuess(raw);
        }
        if (source == YtdlFieldSource.music) return l.ytdlHelpMusic;
        if (source == YtdlFieldSource.videoTitle) return l.ytdlHelpVideoTitle;
        if (source == YtdlFieldSource.videoTitleCleaned) {
          return l.ytdlHelpVideoTitleCleaned;
        }
        final strip = g.artistStrip;
        if (strip != null && !_d.artistStripRestored) {
          return l.ytdlHelpYoutubeArtistStripped(strip);
        }
        return g.tier == YtdlTier.youtubeArtist
            ? l.ytdlHelpYoutubeArtistCheck
            : l.ytdlHelpYoutubeArtist;
      case YtdlField.album:
        if (source == YtdlFieldSource.blank) {
          return g.album.isNotEmpty || (_d.meta?.album ?? '').isNotEmpty
              ? l.ytdlBlankAlbumKeeps
              : l.ytdlBlankAlbumSingle;
        }
        return l.ytdlHelpMusic;
      case YtdlField.year:
        return switch (source) {
          YtdlFieldSource.blank => l.ytdlBlankYear,
          YtdlFieldSource.videoRelease => l.ytdlHelpVideoRelease,
          _ => l.ytdlHelpMusic,
        };
    }
  }
}
