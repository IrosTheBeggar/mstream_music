import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../../util/ytdl_errors.dart';
import '../../util/ytdl_guess.dart';
import '../../util/ytdl_link.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_card_parts.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart';
import 'ytdl_saves_block.dart';
import 'ytdl_tag_fields.dart';

/// What shows under the paste card once a video link is in (spec §3, §8;
/// the LookingUp, Found…, LinkStates and ServerStates boards): the lookup's
/// skeleton ("Reading the video…", "Still looking…" with "Enter details
/// yourself"); a failed or timed-out lookup with "Enter details" and "Try
/// again"; the offline banner; the yt-dlp-missing panel in place of the
/// card; or the result card itself — the late-answer strip, the cover and
/// tags, where they came from, what cleaning removed, the link's notes,
/// "Edit tags" and its fields, SAVES TO, the name check and the noMkdir
/// choices.
///
/// The found card is one summary node for a screen reader ("One More Time,
/// by Daft Punk, album Discovery, 2001. Tags from YouTube Music. Saves to
/// Music, then Daft Punk, then Discovery, a new folder."), with its links
/// and fields focusable on their own (spec §9).
class YtdlResultCard extends StatelessWidget {
  final YtdlDraft draft;

  /// The explorer's folder sheet: SAVES HERE, Sort into subfolders…
  final bool sheet;

  /// "Change" (SAVES TO, the older-server clash panel): Where new songs land.
  final VoidCallback? onChange;

  /// "Choose a folder…" (noMkdir).
  final VoidCallback? onChooseFolder;

  /// "Change format" (the clash panels): the format menu on the chip.
  final VoidCallback? onChangeFormat;

  /// "Sort into subfolders…" (the sheet).
  final VoidCallback? onSortSubfolders;

  /// The SAVES TO block a focused tag field keeps in view (the screen's or
  /// the sheet's, kept across builds).
  final GlobalKey savesKey;

  const YtdlResultCard({
    super.key,
    required this.draft,
    required this.savesKey,
    this.sheet = false,
    this.onChange,
    this.onChooseFolder,
    this.onChangeFormat,
    this.onSortSubfolders,
  });

  YtdlDraft get _d => draft;

  /// A card shows (the screen pins the action bar under it).
  static bool showsFor(YtdlDraft d) => d.parsed.kind == YtdlLinkKind.video;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _d,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    if (!showsFor(_d)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final manual = _d.manual;
    switch (_d.lookup) {
      case YtdlLookupState.ytdlpMissing:
        return _missing(l);
      case YtdlLookupState.offline:
        return _withNotes(
          l,
          YtdlNote(
            key: const ValueKey('ytdl-offline'),
            icon: Icons.cloud_off,
            text: l.ytdlOffline,
          ),
        );
      case YtdlLookupState.idle:
      case YtdlLookupState.loading:
      case YtdlLookupState.slow:
        if (!manual) return _withNotes(l, _skeleton(context, l));
      case YtdlLookupState.failed:
      case YtdlLookupState.timedOut:
        if (!manual) return _failed(l);
      case YtdlLookupState.found:
        break;
    }
    return _card(context, l);
  }

  // ── states before a reading ─────────────────────────────────────────────

  /// [w] with the link's own notes under it: what the link says is known
  /// before any lookup answers (the LinkStates board's live panel sits
  /// under the field, no card).
  Widget _withNotes(AppLocalizations l, Widget w) {
    final notes = _notes(l);
    if (notes.isEmpty) return w;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [w, ...notes],
    );
  }

  /// The card: raised, and its links, tags and status words measured on
  /// that ground ([YtdlGround]).
  Widget _shell({Key? key, required List<Widget> children}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(12),
    ),
    child: YtdlGround(
      color: VelvetColors.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );

  /// "Reading the video…" under a still skeleton (no shimmer: a slow server
  /// never animates forever, and reduced motion gets a still glyph too).
  Widget _skeleton(BuildContext context, AppLocalizations l) {
    final slow = _d.lookup == YtdlLookupState.slow;
    final still = MediaQuery.disableAnimationsOf(context);
    final block = Color.lerp(VelvetColors.border, VelvetColors.border2, 0.4)!;
    Widget bar(double factor, double height) => FractionallySizedBox(
      widthFactor: factor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: block,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return _shell(
      key: const ValueKey('ytdl-skeleton'),
      children: [
        ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: block,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(0.72, 14),
                      const SizedBox(height: 10),
                      bar(0.48, 11),
                      const SizedBox(height: 10),
                      bar(0.34, 11),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            children: [
              if (slow || still)
                Icon(
                  slow ? Icons.schedule : Icons.hourglass_empty,
                  size: 14,
                  color: VelvetColors.textSecondary,
                )
              else
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VelvetColors.textSecondary,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slow ? l.ytdlLookupSlow : l.ytdlLookupReading,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (slow)
          YtdlTextLink(
            l.ytdlLookupEnterYourself,
            key: const ValueKey('ytdl-enter-yourself'),
            padding: const EdgeInsetsDirectional.only(end: 8),
            onTap: _d.enterManually,
          ),
      ],
    );
  }

  /// Why the lookup failed, in the words spec §8 gives each answer: yt-dlp
  /// couldn't read the video (the bare 500), the time ran out, no route,
  /// a 400 about the link, or the server's own words.
  String _failedText(AppLocalizations l) {
    if (_d.lookup == YtdlLookupState.timedOut) return l.ytdlLookupTimedOut;
    final f = _d.lookupFailure;
    switch (f?.problem) {
      case YtdlProblem.noRoute:
        return l.ytdlErrNoRoute;
      case YtdlProblem.badRequest:
        return l.ytdlErrBadRequest;
      case YtdlProblem.other:
        final words = ytdlServerWords(f!);
        return words == null ? l.ytdlErrServer : l.ytdlErrOther(words);
      default:
        return l.ytdlLookupFailed;
    }
  }

  /// The lookup failed or ran out of time: say why, offer "Enter details"
  /// (not when the server has no YouTube route — an add 404s the same
  /// way) and "Try again"; Add stays on, into the library's top folder,
  /// unless a check panel below says otherwise.
  Widget _failed(AppLocalizations l) {
    final noRoute = _d.lookupFailure?.problem == YtdlProblem.noRoute;
    return _shell(
      key: const ValueKey('ytdl-lookup-failed'),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YtdlCover(),
            const SizedBox(width: 12),
            Expanded(
              child: YtdlStatusLine(
                icon: Icons.error_outline,
                color: keepTone(VelvetColors.error),
                textColor: VelvetColors.textPrimary,
                text: _failedText(l),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (!noRoute)
              YtdlOutlinedPill(
                l.ytdlLookupEnterDetails,
                key: const ValueKey('ytdl-enter-details'),
                onTap: _d.enterManually,
              ),
            YtdlTextLink(
              l.discoverPageRetry,
              key: const ValueKey('ytdl-retry-lookup'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onTap: _d.retryLookup,
            ),
          ],
        ),
        ..._notes(l),
        const SizedBox(height: 6),
        _divider(),
        _saves(),
        // The noMkdir choices (a remembered layout's literal folder, an
        // unchecked one) and the sheet's way to subfolders.
        ..._panels(l),
      ],
    );
  }

  /// In place of the card: the server has no yt-dlp (remembered for the
  /// session); "Try again" asks once more. No action bar under it.
  Widget _missing(AppLocalizations l) => _shell(
    key: const ValueKey('ytdl-ytdlp-missing'),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: VelvetColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.ytdlYtdlpMissing,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                ),
                YtdlTextLink(
                  l.discoverPageRetry,
                  key: const ValueKey('ytdl-ytdlp-retry'),
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  onTap: _d.retryLookup,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  // ── the card ────────────────────────────────────────────────────────────

  Widget _card(BuildContext context, AppLocalizations l) {
    // A late answer not used yet is no reading of this card: what shows is
    // what was typed, with no source line and no summary (the LookingUp
    // board, frame c).
    final found =
        _d.lookup == YtdlLookupState.found && _d.meta != null && !_d.lateAnswer;
    final source = found ? _source(l) : null;
    final title = _d.displayTitle;
    final failedLookup =
        _d.lookup == YtdlLookupState.failed ||
        _d.lookup == YtdlLookupState.timedOut;
    // "Cleaned from …" once noise came out (a split alone has its chip).
    final cleaned =
        _d.canUndoAll && _d.guess.fragments.any((f) => f.kind == YtdlCut.noise);
    final summary = found ? _summary(l, source!.$3) : null;

    Widget quiet(Widget w) => summary == null ? w : ExcludeSemantics(child: w);

    final card = _shell(
      key: const ValueKey('ytdl-card'),
      children: [
        if (_d.lateAnswer) ...[_late(l), const SizedBox(height: 10)],
        if (_d.manual && failedLookup) ...[
          YtdlNote(
            key: const ValueKey('ytdl-using-yours'),
            icon: Icons.error_outline,
            text: l.ytdlLookupFailedUsingYours,
          ),
          const SizedBox(height: 10),
        ],
        quiet(_header(l, title, found)),
        if (source != null) ...[
          const SizedBox(height: 10),
          quiet(_sourceLine(source)),
        ],
        if (cleaned) ...[
          Row(
            children: [
              // Read on its own: the summary doesn't say what came out.
              Expanded(
                child: Text(
                  l.ytdlCleanedFrom(_d.guess.rawTitle),
                  style: TextStyle(
                    color: VelvetColors.helper,
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
              ),
              YtdlTextLink(
                l.ytdlUndoAll,
                key: const ValueKey('ytdl-undo-all'),
                fontSize: 13,
                padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
                onTap: _d.undoAll,
              ),
            ],
          ),
        ] else if (source != null)
          const SizedBox(height: 4),
        ..._notes(l),
        _editRow(l),
        if (_d.tagsOpen) ...[
          const SizedBox(height: 4),
          YtdlTagFields(draft: _d, savesKey: savesKey),
          const SizedBox(height: 12),
        ],
        _divider(),
        _saves(summarized: summary != null),
        ..._panels(l),
      ],
    );
    if (summary == null) return card;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: summary,
      child: card,
    );
  }

  Widget _divider() => Container(height: 1, color: VelvetColors.border);

  Widget _saves({bool summarized = false}) => KeyedSubtree(
    key: savesKey,
    child: YtdlSavesBlock(
      draft: _d,
      sheet: sheet,
      summarized: summarized,
      onChange: onChange,
    ),
  );

  List<Widget> _panels(AppLocalizations l) => [
    if (_d.addAnyway || _d.clashBlocks) ...[
      const SizedBox(height: 10),
      YtdlClashPanel(
        draft: _d,
        sheet: sheet,
        onChangeFormat: onChangeFormat,
        onChange: onChange,
        onSortSubfolders: onSortSubfolders,
      ),
    ],
    if (_d.mkdirBlocked) ...[
      const SizedBox(height: 10),
      YtdlNoMkdirPanel(draft: _d, onChooseFolder: onChooseFolder),
    ],
    // The sheet's way to subfolders (hidden under noMkdir), unless the
    // older server's clash panel already offers it.
    if (sheet && YtdlSavesBlock.maySort(_d) && !_d.clashBlocks)
      YtdlTextLink(
        l.ytdlSortSubfolders,
        key: const ValueKey('ytdl-sort-subfolders'),
        padding: const EdgeInsetsDirectional.only(end: 8),
        onTap: onSortSubfolders,
      ),
  ];

  /// "Details found for this video · Use them · Your edits stay."
  Widget _late(AppLocalizations l) => Container(
    key: const ValueKey('ytdl-late'),
    padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
    decoration: BoxDecoration(
      color: VelvetColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: VelvetColors.border2),
    ),
    child: Row(
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: 18,
          color: VelvetColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.ytdlLateFound,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
                Text(
                  l.ytdlLateEditsStay,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        YtdlTextLink(
          l.ytdlLateUseThem,
          key: const ValueKey('ytdl-use-late'),
          onTap: _d.useLateAnswer,
        ),
      ],
    ),
  );

  /// The artist and album the file will get: the fields, else — left
  /// blank — YouTube's own tags, which the server keeps when a field isn't
  /// sent (the helpers under the fields say the same). Only once the
  /// reading is the card's ([found]): before a late answer is used, the
  /// card is what was typed.
  (String, String) _shownTags(bool found) {
    final t = _d.tags;
    final m = found ? _d.meta : null;
    return (
      t.artist.isNotEmpty ? t.artist : (m?.artist ?? '').trim(),
      t.album.isNotEmpty ? t.album : (m?.album ?? '').trim(),
    );
  }

  /// The cover, then title, artist and "Discovery · 2001" / "No album" —
  /// what will be written: the fields as they stand, YouTube's for a
  /// blank one.
  Widget _header(AppLocalizations l, String title, bool found) {
    final (artist, album) = _shownTags(found);
    final year = _d.tags.year;
    // The album isolated, so a right-to-left name keeps "album · year".
    final third = found || album.isNotEmpty || year.isNotEmpty
        ? [
            album.isEmpty ? l.ytdlCardNoAlbum : ytdlIsolate(album),
            if (year.isNotEmpty) year,
          ].join(' · ')
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YtdlCover(url: _d.meta?.thumbnail),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isNotEmpty ? title : _d.parsed.shown,
                key: const ValueKey('ytdl-card-title'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: title.isNotEmpty
                      ? VelvetColors.textPrimary
                      : VelvetColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 20 / 15,
                ),
              ),
              if (artist.isNotEmpty)
                Text(
                  artist,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
              if (third != null)
                Text(
                  third,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.helper,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Where the tags came from, as an icon and its words: ✓ YouTube Music;
  /// ✦ the video title (agreeing with YouTube's artist, or not); ⚠ YouTube's
  /// artist field — also once a split is undone.
  (IconData, Color, String) _source(AppLocalizations l) {
    final g = _d.guess;
    switch (g.tier) {
      case YtdlTier.music:
        return (
          Icons.check_circle,
          keepTone(VelvetColors.success),
          l.ytdlSourceMusic,
        );
      case YtdlTier.split when _d.canSwap:
        return (
          Icons.auto_fix_high,
          VelvetColors.textSecondary,
          g.artistAgrees ? l.ytdlSourceSplitAgrees : l.ytdlSourceSplit,
        );
      case YtdlTier.split:
      case YtdlTier.youtubeArtist:
      case YtdlTier.none:
        return (
          Icons.warning_amber_rounded,
          keepTone(VelvetColors.warning),
          l.ytdlSourceChannel,
        );
    }
  }

  Widget _sourceLine((IconData, Color, String) s) => YtdlStatusLine(
    key: const ValueKey('ytdl-source'),
    icon: s.$1,
    color: s.$2,
    textColor: VelvetColors.textPrimary,
    live: false,
    text: s.$3,
  );

  /// The link's own notes: "Just this video, not the playlist." and the
  /// live-stream warning in the tier's words.
  List<Widget> _notes(AppLocalizations l) {
    final p = _d.parsed;
    return [
      if (p.inPlaylist) ...[
        const SizedBox(height: 10),
        YtdlNote(
          key: const ValueKey('ytdl-in-playlist'),
          icon: Icons.info_outline,
          text: l.ytdlLinkInPlaylist,
        ),
      ],
      if (p.live) ...[
        const SizedBox(height: 10),
        YtdlNote(
          key: const ValueKey('ytdl-live'),
          icon: Icons.warning_amber_rounded,
          warning: true,
          text: _d.owner.tier == YtdlServerTier.full
              ? l.ytdlLinkLive
              : l.ytdlLinkLiveOlder,
        ),
      ],
    ];
  }

  /// "Edit tags" (its fields open inside the card), and once they are open
  /// in the split tier, "Swap artist and title".
  Widget _editRow(AppLocalizations l) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      // A disclosure: it opens and closes the fields, focusing none.
      Semantics(
        expanded: _d.tagsOpen,
        child: YtdlTextLink(
          l.ytdlEditTags,
          key: const ValueKey('ytdl-edit-tags'),
          icon: Icons.edit_outlined,
          padding: const EdgeInsetsDirectional.only(end: 8),
          onTap: () => _d.tagsOpen ? _d.closeTags() : _d.openTags(),
        ),
      ),
      if (_d.tagsOpen && _d.canSwap)
        YtdlTextLink(
          l.ytdlSwap,
          key: const ValueKey('ytdl-swap'),
          onTap: _d.swap,
        ),
    ],
  );

  /// The card read as one sentence (spec §9); only for a found card.
  String _summary(AppLocalizations l, String source) {
    final t = _d.tags;
    final (artist, album) = _shownTags(true);
    final title = _d.displayTitle;
    final details = [
      artist.isEmpty ? title : l.ytdlSummaryBy(title, artist),
      album.isEmpty ? l.ytdlSummaryNoAlbum : l.ytdlSummaryAlbum(album),
      if (t.year.isNotEmpty) t.year,
    ].join(', ');
    final target = _d.target;
    final String path;
    if (!target.valid) {
      path = l.discoverDestFixLayout;
    } else if (_d.lookupBlank) {
      path = ytdlSpokenPath(l, [target.library, l.ytdlSampleFile]);
    } else {
      path = ytdlSpokenPath(
        l,
        target.crumbs,
        newAt: {for (final i in _d.newSegments) i + 1},
      );
    }
    return l.ytdlSummary(details, source, path);
  }
}
