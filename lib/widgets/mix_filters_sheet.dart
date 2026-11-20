// mix_filters_sheet.dart — an Instant mix page's Filters: Auto DJ's filter
// rows on one sheet, in Auto DJ's order — Smart filters · Genres · Rating ·
// Length · Beat matching · Harmonic mixing · Skip words — then the server's
// folders when it has two or more. No headings: on a mix every filter must
// match. Beat matching and Harmonic mixing are built around a song seed's
// own tempo and key, so they are offered only for a song that has them (an
// album, an artist or a playlist has no single tempo or key).
//
// The sheet holds a draft of the page's filters. Each row opens Auto DJ's
// own sheet for it in value mode (auto_dj_sheets.dart), which hands its
// choice back to the draft; the switch and the folders change it in place.
// Done hands the draft back, applied as one request; Clear empties it; and
// closing the sheet any other way changes nothing. While anything is set,
// the page's strip names it (mixFilterLabels), with Clear.

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/instant_mix.dart';
import '../objects/mix_filters.dart';
import '../objects/server.dart';
import '../screens/auto_dj.dart'
    show AutoDjSwitchRow, AutoDjValueRow, autoDjGenreValue;
import '../screens/auto_dj_sheets.dart';
import '../screens/instant_mix/instant_mix_controller.dart';
import '../screens/instant_mix/instant_mix_widgets.dart' show applyMixFilters;
import '../singletons/auto_dj_manager.dart' show AutoDJManager;
import '../util/auto_dj_values.dart';
import 'federation_widgets.dart';
import 'mood_filter_sheet.dart';

/// The Filters on [c]'s page. Done applies the draft as one request
/// (applyMixFilters: kept for the next mix too, and said when it fails).
Future<void> showMixFiltersSheet(
    BuildContext context, InstantMixController c) async {
  final next = await showAutoDjSheet<MixFilters>(
      context, (_) => MixFiltersSheet(seed: c.seed, initial: c.filters));
  if (next == null || !context.mounted) return;
  await applyMixFilters(context, c, next);
}

/// What [f] sets, in words, in the sheet's order — the page's strip: the
/// mood's choices, the genres, the rating, the length, the tempo, Harmonic
/// mixing, the skip words, and [server]'s folders still on when one is off.
List<String> mixFilterLabels(AppLocalizations l, MixFilters f, Server server) {
  final genres = autoDjGenreValue(l, f.genres);
  return [
    if (!f.mood.isEmpty) ...moodLabels(l, f.mood),
    ?genres,
    if (f.minRating > 0) l.autoDjRatingValue(fmtStars(f.minRating)),
    if (f.hasLength) _lengthValue(l, f),
    if (f.tempo) l.autoDjBpmTolerance(f.bpmTolerance),
    if (f.harmonic) l.autoDjHarmonicTitle,
    ...f.skipWords,
    if (f.foldersOff.isNotEmpty)
      for (final folder in mixFolders(server))
        if (!f.foldersOff.contains(folder)) folder,
  ];
}

/// The length window in words, as Auto DJ's row says it.
String _lengthValue(AppLocalizations l, MixFilters f) => autoDjLengthValue(
    l,
    f.minDuration,
    f.maxDuration > 0 ? f.maxDuration : AutoDJManager.durationCeilSec);

class MixFiltersSheet extends StatefulWidget {
  const MixFiltersSheet({super.key, required this.seed, required this.initial});

  final MixSeed seed;

  /// The page's filters, which the draft starts from.
  final MixFilters initial;

  @override
  State<MixFiltersSheet> createState() => _MixFiltersSheetState();
}

class _MixFiltersSheetState extends State<MixFiltersSheet> {
  late MixFilters _draft = widget.initial;

  Server get _server => widget.seed.server;

  /// A row's own sheet, over this one.
  Future<void> _open(WidgetBuilder builder) =>
      showAutoDjSheet<void>(context, builder);

  void _set(MixFilters next) {
    if (mounted) setState(() => _draft = next);
  }

  AutoDjTone _tone(bool set) => set ? AutoDjTone.active : AutoDjTone.neutral;

  Widget _moodRow(AppLocalizations l) {
    const key = ValueKey('mix-filter-mood');
    final reason = autoDjMoodBlocked(l, home: _server, set: [_server]);
    if (reason != null) {
      return AutoDjValueRow(key: key, title: l.autoDjMoodTitle, value: reason);
    }
    final mood = _draft.mood;
    return AutoDjValueRow(
      key: key,
      title: l.autoDjMoodTitle,
      value: mood.isEmpty ? l.autoDjAny : moodLabels(l, mood).join(' · '),
      tone: _tone(!mood.isEmpty),
      onTap: () async {
        final f = await showMoodFilterSheet(context, _draft.mood,
            title: l.autoDjMoodTitle);
        if (f != null) _set(_draft.copyWith(mood: f.filter));
      },
    );
  }

  Widget _genresRow(AppLocalizations l) {
    final value = autoDjGenreValue(l, _draft.genres);
    return AutoDjValueRow(
      key: const ValueKey('mix-filter-genres'),
      title: l.autoDjGenres,
      value: value ?? l.autoDjAny,
      tone: _tone(value != null),
      onTap: () => _open((_) => GenresSheet(
          servers: [_server],
          initial: _server,
          value: _draft.genres,
          onDone: (g) => _set(_draft.copyWith(genres: g)))),
    );
  }

  Widget _ratingRow(AppLocalizations l) {
    final r = _draft.minRating;
    return AutoDjValueRow(
      key: const ValueKey('mix-filter-rating'),
      title: l.autoDjRating,
      value: r > 0 ? l.autoDjRatingValue(fmtStars(r)) : l.autoDjAny,
      tone: _tone(r > 0),
      onTap: () => _open((_) => RatingSheet(
          servers: [_server],
          initial: _server,
          value: r > 0 ? r : null,
          onDone: (v) => _set(_draft.copyWith(minRating: v ?? 0)))),
    );
  }

  Widget _lengthRow(AppLocalizations l) {
    final d = _draft;
    return AutoDjValueRow(
      key: const ValueKey('mix-filter-length'),
      title: l.autoDjDurationRange,
      value: d.hasLength ? _lengthValue(l, d) : l.autoDjAny,
      tone: _tone(d.hasLength),
      onTap: () => _open((_) => LengthSheet(
          value: (
            min: d.minDuration,
            max: d.maxDuration,
            allowUnknown: d.allowUnknownDuration,
          ),
          onDone: (v) => _set(_draft.copyWith(
              minDuration: v.min,
              maxDuration: v.max,
              allowUnknownDuration: v.allowUnknown)))),
    );
  }

  Widget _tempoRow(AppLocalizations l) {
    final d = _draft;
    return AutoDjValueRow(
      key: const ValueKey('mix-filter-tempo'),
      title: l.autoDjTempo,
      value: d.tempo ? l.autoDjBpmTolerance(d.bpmTolerance) : l.commonOff,
      tone: _tone(d.tempo),
      onTap: () => _open((_) => TempoSheet(
          value: (on: d.tempo, tolerance: d.bpmTolerance),
          onDone: (v) => _set(
              _draft.copyWith(tempo: v.on, bpmTolerance: v.tolerance)))),
    );
  }

  // A plain yes or no, so a switch in place, without Auto DJ's line under
  // it: that speaks of a DJ's next pick.
  Widget _harmonicRow(AppLocalizations l) => AutoDjSwitchRow(
        key: const ValueKey('mix-filter-harmonic'),
        switchKey: const ValueKey('mix-filter-harmonic-switch'),
        title: l.autoDjHarmonicTitle,
        value: _draft.harmonic,
        onChanged: (v) => _set(_draft.copyWith(harmonic: v)),
      );

  Widget _skipWordsRow(AppLocalizations l) {
    final words = _draft.skipWords;
    return AutoDjValueRow(
      key: const ValueKey('mix-filter-skip-words'),
      title: l.autoDjSkipWords,
      value: words.isEmpty ? l.commonOff : words.join(' · '),
      tone: _tone(words.isNotEmpty),
      onTap: () => _open((_) => SkipWordsSheet(
          value: words, onDone: (w) => _set(_draft.copyWith(skipWords: w)))),
    );
  }

  Widget _folders(List<String> folders) {
    final off = _draft.foldersOff;
    return AutoDjFolderCard(
      server: _server,
      folders: {for (final f in folders) f: !off.contains(f)},
      onChanged: (folder, on) => _set(_draft.copyWith(foldersOff: [
        for (final f in folders)
          if (f == folder ? !on : off.contains(f)) f,
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final seed = widget.seed;
    final folders = mixFolders(_server);
    return AutoDjSheet(
      title: l.moodFilters,
      clearable: true,
      onClear: _draft.isEmpty
          ? null
          : () => setState(() => _draft = MixFilters.empty),
      onDone: () => Navigator.of(context).pop<MixFilters>(_draft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FedCard(children: [
          _moodRow(l),
          _genresRow(l),
          _ratingRow(l),
          _lengthRow(l),
          if (seed.hasBpm) _tempoRow(l),
          if (seed.camelotKey != null) _harmonicRow(l),
          _skipWordsRow(l),
        ]),
        if (folders.isNotEmpty) _folders(folders),
      ]),
    );
  }
}
