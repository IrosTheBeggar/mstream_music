import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart' show pathCrumbs;
import '../../util/ytdl_filename.dart';
import '../../util/ytdl_layout.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_card_parts.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart';

/// The result card's SAVES TO block (spec §3, §4, §8): the path — wrapping
/// only at ›, a "new" tag on each folder that will be made, a folder an
/// empty variable left as brackets in amber — and "Just this song · Undo",
/// "Couldn't check this folder", the file name ("about One_More_Time.mp3",
/// cut in the middle to one line), the left-out variables, the bracket
/// warning with its link to the field, and on the screen "Change". The
/// explorer sheet reads SAVES HERE while the song goes into the folder on
/// screen.
class YtdlSavesBlock extends StatelessWidget {
  final YtdlDraft draft;

  /// The explorer's folder sheet (SAVES HERE, Sort into subfolders…).
  final bool sheet;

  /// The crumbs are read in the card's summary already.
  final bool summarized;

  final VoidCallback? onChange;

  const YtdlSavesBlock({
    super.key,
    required this.draft,
    this.sheet = false,
    this.summarized = false,
    this.onChange,
  });

  YtdlDraft get _d => draft;

  /// "Sort into subfolders…" shows only for an account that may make
  /// folders (spec §7).
  static bool maySort(YtdlDraft d) =>
      d.owner.server.noMkdir != true && !d.owner.mkdirRefused;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = _d.target;
    final here =
        sheet && _d.subLayout == kYtdlLayoutTop && _d.justThisSong == null;
    final blank = _d.lookupBlank;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 20),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: YtdlFieldLabel(here ? l.ytdlSavesHere : l.ytdlSavesTo),
          ),
        ),
        const SizedBox(height: 4),
        if (!t.valid)
          YtdlStatusLine(
            icon: Icons.warning_amber_rounded,
            color: keepTone(VelvetColors.warning),
            textColor: VelvetColors.textPrimary,
            text: l.discoverDestFixLayout,
          )
        else
          _crumbs(l, t, blank),
        if (_d.checkUnknown && t.valid) ...[
          const SizedBox(height: 2),
          YtdlHelper(l.ytdlCheckFailed, color: VelvetColors.textSecondary),
        ],
        if (_d.predictedName.isNotEmpty) ...[
          const SizedBox(height: 4),
          // Not in the summary: read on its own, the full name.
          YtdlFileLine(name: _d.predictedName, dropsLetters: _d.dropsLetters),
        ],
        if (blank) ...[
          const SizedBox(height: 2),
          YtdlHelper(l.ytdlLookupNoTags),
        ] else if (t.valid && t.missingVars.isNotEmpty) ...[
          const SizedBox(height: 4),
          YtdlHelper(
            l.discoverDestMissing(
              t.missingVars.map((v) => '{{$v}}').join(', '),
            ),
            color: VelvetColors.textSecondary,
          ),
        ],
        if (t.valid && t.neverVars.isNotEmpty) ...[
          const SizedBox(height: 4),
          YtdlHelper(
            l.ytdlWhereAlwaysEmpty(t.neverVars.map((v) => '{{$v}}').join(', ')),
            color: VelvetColors.textSecondary,
          ),
        ],
        if (t.valid && t.trap != null) ...[
          const SizedBox(height: 6),
          _trap(l, t.trap!),
        ],
      ],
    );
    if (sheet) {
      return Padding(padding: const EdgeInsets.only(top: 10), child: body);
    }
    // "Change ›" sits on the label's line; its 48 px band reaches into the
    // gap above the label (inside the block, so it takes taps) rather
    // than pushing the path down.
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.only(top: 14), child: body),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: YtdlTextLink(
            l.discoverKeepChange,
            key: const ValueKey('ytdl-saves-change'),
            trailingIcon: Icons.chevron_right,
            padding: const EdgeInsetsDirectional.only(start: 8),
            onTap: onChange,
          ),
        ),
      ],
    );
  }

  /// The path, then "Just this song · Undo" when a choice for this song is
  /// in force. In a summarized card only the path is quiet (the summary
  /// reads it); the tag and its Undo are read and reached on their own.
  Widget _crumbs(AppLocalizations l, YtdlTarget t, bool blank) {
    final style = TextStyle(fontSize: 14, height: 20 / 14);
    final Widget path = blank
        ? YtdlCrumbs(
            crumbs: [t.library, l.ytdlSampleFile],
            sampleAt: const {1},
            style: style,
          )
        : YtdlCrumbs(
            crumbs: t.crumbs,
            newAt: {for (final i in _d.newSegments) i + 1},
            trapAt: {
              if (t.trap != null && t.segments.contains(t.trap!.folder))
                t.segments.indexOf(t.trap!.folder) + 1,
            },
            style: style,
          );
    final crumbs = summarized ? ExcludeSemantics(child: path) : path;
    if (_d.justThisSong == null) return crumbs;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: crumbs,
        ),
        YtdlTag(l.ytdlJustThisSong),
        YtdlTextLink(
          l.ytdlUndo,
          key: const ValueKey('ytdl-just-undo'),
          fontSize: 13,
          padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
          onTap: _d.undoJustThisSong,
        ),
      ],
    );
  }

  /// The bracket warning (spec §4): the folder an empty variable left as
  /// brackets, and the link that opens the field to fill it.
  Widget _trap(AppLocalizations l, YtdlTrap trap) {
    final (text, link, field) = switch (trap.kind) {
      YtdlTrapKind.emptyFolder => (
        l.ytdlTrapEmpty(trap.folder),
        l.ytdlEditTags,
        YtdlField.album,
      ),
      YtdlTrapKind.missingYear => (
        l.ytdlTrapNoYear(trap.folder),
        l.ytdlTrapAddYear,
        YtdlField.year,
      ),
      YtdlTrapKind.other => (
        l.ytdlTrapOther(trap.folder),
        l.ytdlEditTags,
        YtdlField.album,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YtdlStatusLine(
          key: const ValueKey('ytdl-trap'),
          icon: Icons.warning_amber_rounded,
          color: keepTone(VelvetColors.warning),
          textColor: VelvetColors.textPrimary,
          fontSize: 12,
          text: text,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16),
          child: YtdlTextLink(
            link,
            key: const ValueKey('ytdl-trap-link'),
            onTap: () => _d.openTags(focus: field),
          ),
        ),
      ],
    );
  }
}

/// "about One_More_Time.mp3" (or "· letters outside A–Z are dropped from
/// file names"): the file name in mono, cut in the middle so the line
/// keeps one row and the extension (spec §9); the full name is read out.
class YtdlFileLine extends StatelessWidget {
  final String name;
  final bool dropsLetters;
  const YtdlFileLine({
    super.key,
    required this.name,
    this.dropsLetters = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (before, after) = ytdlAround(
      dropsLetters ? l.ytdlFileAboutLettersDropped : l.ytdlFileAbout,
    );
    // Measured as drawn: the painter in [_fit] doesn't inherit
    // DefaultTextStyle, and the theme's face and letter spacing would make
    // a name it thought fits wrap to a second line.
    final about = DefaultTextStyle.of(context).style.merge(TextStyle(
      color: VelvetColors.helper,
      fontSize: 12,
      height: 16 / 12,
    ));
    final mono = about.copyWith(
      color: VelvetColors.textSecondary,
      fontFamily: 'monospace',
      fontSize: 11.5,
    );
    return Semantics(
      label: dropsLetters
          ? l.ytdlFileAboutLettersDropped(name)
          : l.ytdlFileAbout(name),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final shown = _fit(
            before,
            name,
            about,
            mono,
            box.maxWidth,
            Directionality.of(context),
            MediaQuery.textScalerOf(context),
          );
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: before, style: about),
                TextSpan(text: shown, style: mono),
                TextSpan(text: after, style: about),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The longest middle-cut of [name] that fits on one line after
  /// [before]; [name] whole when it fits.
  static String _fit(
    String before,
    String name,
    TextStyle about,
    TextStyle mono,
    double maxWidth,
    TextDirection dir,
    TextScaler scaler,
  ) {
    bool fits(String n) {
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: before, style: about),
            TextSpan(text: n, style: mono),
          ],
        ),
        textDirection: dir,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final ok = tp.width <= maxWidth;
      tp.dispose();
      return ok;
    }

    if (!maxWidth.isFinite || fits(name)) return name;
    var lo = 8;
    var hi = name.runes.length - 1;
    var best = ytdlMiddleEllipsis(name, lo);
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final cut = ytdlMiddleEllipsis(name, mid);
      if (fits(cut)) {
        best = cut;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best;
  }
}

/// The name check's panel (spec §3 "Name check"): on 6.30+ "Something like
/// … looks to be in this folder already" with "Change format — …" (Add
/// becomes an outlined "Add anyway"); on older servers "A file named … is
/// already in this folder" with "Change format" and "Change" (the sheet:
/// "Sort into subfolders…"), and Add is off. "Change format" hides when
/// the server offers one format.
class YtdlClashPanel extends StatelessWidget {
  final YtdlDraft draft;
  final bool sheet;
  final VoidCallback? onChangeFormat;
  final VoidCallback? onChange;
  final VoidCallback? onSortSubfolders;

  const YtdlClashPanel({
    super.key,
    required this.draft,
    this.sheet = false,
    this.onChangeFormat,
    this.onChange,
    this.onSortSubfolders,
  });

  @override
  Widget build(BuildContext context) {
    final d = draft;
    if (!d.addAnyway && !d.clashBlocks) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final name = d.predictedName;
    final formats = d.formats.length > 1;
    if (d.addAnyway) {
      return YtdlNote(
        key: const ValueKey('ytdl-clash'),
        icon: Icons.warning_amber_rounded,
        warning: true,
        text: l.ytdlClash(name),
        children: [
          if (formats)
            YtdlTextLink(
              l.ytdlClashChangeFormat,
              key: const ValueKey('ytdl-clash-format'),
              wrap: true,
              padding: EdgeInsets.zero,
              onTap: onChangeFormat,
            ),
        ],
      );
    }
    return YtdlNote(
      key: const ValueKey('ytdl-clash'),
      icon: Icons.warning_amber_rounded,
      warning: true,
      text: l.ytdlClashOlder(name),
      children: [
        Wrap(
          spacing: 16,
          children: [
            if (formats)
              YtdlTextLink(
                l.ytdlChangeFormat,
                key: const ValueKey('ytdl-clash-format'),
                padding: EdgeInsets.zero,
                onTap: onChangeFormat,
              ),
            if (!sheet)
              YtdlTextLink(
                l.discoverKeepChange,
                key: const ValueKey('ytdl-clash-change'),
                padding: EdgeInsets.zero,
                onTap: onChange,
              )
            else if (YtdlSavesBlock.maySort(d))
              YtdlTextLink(
                l.ytdlSortSubfolders,
                key: const ValueKey('ytdl-clash-sort'),
                padding: EdgeInsets.zero,
                onTap: onSortSubfolders,
              ),
          ],
        ),
      ],
    );
  }
}

/// The account can't make folders and one on the path is new or unchecked
/// (spec §8 "mkdir off"): why, then the three ways on — "Save to Music ›
/// Daft Punk instead · Just this song" (the deepest folder that listed;
/// hidden when none did, or when that is the library's top, which "Top of
/// the library" already offers), "Top of the library" and "Choose a
/// folder…".
class YtdlNoMkdirPanel extends StatelessWidget {
  final YtdlDraft draft;
  final VoidCallback? onChooseFolder;

  const YtdlNoMkdirPanel({super.key, required this.draft, this.onChooseFolder});

  @override
  Widget build(BuildContext context) {
    final d = draft;
    if (!d.mkdirBlocked) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = d.target;
    final fresh = d.newSegments.isEmpty
        ? null
        : d.newSegments.reduce((a, b) => a < b ? a : b);
    final text = fresh != null && fresh < t.segments.length
        ? l.ytdlNoMkdirNew(t.segments[fresh])
        : l.ytdlNoMkdirUnchecked;
    final deepest = d.deepestExisting;
    final instead = deepest == null ? null : pathCrumbs(deepest);
    return YtdlNote(
      key: const ValueKey('ytdl-nomkdir'),
      icon: Icons.warning_amber_rounded,
      warning: true,
      fontSize: 14,
      text: text,
      below: [
        if (instead != null && instead.length > 1) ...[
          const SizedBox(height: 10),
          _SaveInstead(
            path: ytdlPathText(instead),
            onTap: d.saveToDeepestInstead,
          ),
        ],
        const SizedBox(height: 2),
        Wrap(
          children: [
            YtdlTextLink(
              l.ytdlLayoutTop,
              key: const ValueKey('ytdl-use-top'),
              onTap: d.useTopOfLibrary,
            ),
            YtdlTextLink(
              l.ytdlChooseFolderLink,
              key: const ValueKey('ytdl-choose-folder'),
              onTap: onChooseFolder,
            ),
          ],
        ),
      ],
    );
  }
}

/// "Save to Music › Daft Punk instead" over "Just this song": the tonal
/// choice (primary-dim, radius 12, at least 52 px).
class _SaveInstead extends StatelessWidget {
  final String path;
  final VoidCallback onTap;
  const _SaveInstead({required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: VelvetColors.primaryDim,
      borderRadius: radius,
      child: InkWell(
        key: const ValueKey('ytdl-save-deepest'),
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l.ytdlSaveToInstead(path),
                style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 20 / 14,
                ),
              ),
              Text(
                l.ytdlJustThisSong,
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
    );
  }
}
