// mood_filter.dart — the mood filters on Albums, Artists and Discover.
//
// mStream (#1092) scores every song with mood heads and filters lists by
// them. A filter has up to four groups, and a group left out does not
// filter:
//   valence  happy | neutral | sad
//   energy   relaxed | neutral | aggressive
//   voice    instrumental | vocals
//   tags     any of acoustic, party, danceable — every picked tag must hold
// /api/v1/db/albums and /api/v1/db/artists take it as `moods` in a POST
// body (the federation browse proxy forwards bodies, not query strings) and
// answer with the filter they applied — `moods`, {} when none — while the
// server can filter. A server that cannot (older, or no scores yet) leaves
// the key out, so the answer says whether to offer the filters. Discover's
// /api/v1/discovery/taste takes it too, gated on the server's `moodFilters`
// flag (Server.moodFiltersAvailable): its body schema refuses unknown keys.
// So do the song lists, /api/v1/db/rated and /api/v1/db/recent/added
// (mStream #1095): their answers are bare arrays, with no room for the
// echo, and recent/added's schema refuses unknown keys too. So does Auto
// DJ's /api/v1/db/random-songs (mStream #1096), which keeps every pick of a
// session inside the mood and echoes the filter it picked under.
//
// A score is the model's confidence, not how strongly a song is relaxed.
// `threshold` (mStream #1099) says how sure every group must be: a number
// the server takes, 0.5 when left out. The sheet's Strict | Standard |
// Loose are the phone's names for three of them (MoodLevel). A filtered
// song list's songs each carry `moodMatch`, 0 to 1, how surely the song
// fits; the list's Sort can draw the best first (byMoodMatch).

import 'display_item.dart';
import 'server.dart';

/// The three single-choice scales. Enum names are the wire keys.
enum MoodScale {
  valence(['happy', 'neutral', 'sad']),
  energy(['relaxed', 'neutral', 'aggressive']),
  voice(['instrumental', 'vocals']);

  const MoodScale(this.choices);

  /// Its values, in the sheet's order; also the wire values.
  final List<String> choices;
}

/// The multi-choice tags, in the sheet's (and the wire's) order.
const List<String> kMoodTags = ['acoustic', 'party', 'danceable'];

/// How sure every group must be: the sheet's words for the server's
/// `threshold`. Standard is the server's default, so it sends nothing.
enum MoodLevel {
  strict(0.7),
  standard(0.5),
  loose(0.3);

  const MoodLevel(this.threshold);

  final double threshold;

  /// The level a `threshold` names: Standard for none, or for one the
  /// phone does not offer.
  static MoodLevel of(Object? threshold) {
    if (threshold is! num) return standard;
    final t = (threshold * 100).round();
    for (final level in values) {
      if ((level.threshold * 100).round() == t) return level;
    }
    return standard;
  }
}

/// One page's filter. Immutable: every change makes a new one.
class MoodFilter {
  final String? valence;
  final String? energy;
  final String? voice;

  /// Picked tags, always in [kMoodTags] order.
  final List<String> tags;

  /// How sure every group must be. Kept with nothing set (the sheet shows
  /// it either way), but sent only beside a group.
  final MoodLevel level;

  const MoodFilter(
      {this.valence,
      this.energy,
      this.voice,
      this.tags = const [],
      this.level = MoodLevel.standard});

  static const empty = MoodFilter();

  /// The wire form read back (a saved filter, or an answer's echo). Only
  /// what the server knows survives: an unknown value or tag is dropped
  /// rather than sent to a route that would refuse it.
  factory MoodFilter.fromJson(Object? json) {
    if (json is! Map) return empty;
    var f = empty;
    for (final scale in MoodScale.values) {
      final v = json[scale.name];
      if (v is String) f = f.withScale(scale, v);
    }
    final tags = json['tags'];
    if (tags is List) {
      for (final t in {...tags.whereType<String>()}) {
        f = f.toggleTag(t);
      }
    }
    return f.withLevel(MoodLevel.of(json['threshold']));
  }

  bool get isEmpty =>
      valence == null && energy == null && voice == null && tags.isEmpty;

  /// How many choices are set: the scales that filter, plus the tags (the
  /// Filters button's badge). The level is not a choice.
  int get count =>
      [valence, energy, voice].where((v) => v != null).length + tags.length;

  String? valueOf(MoodScale scale) => switch (scale) {
        MoodScale.valence => valence,
        MoodScale.energy => energy,
        MoodScale.voice => voice,
      };

  /// [scale] set to [value] (null lets the scale go). A value the scale
  /// does not have changes nothing.
  MoodFilter withScale(MoodScale scale, String? value) {
    if (value != null && !scale.choices.contains(value)) return this;
    return MoodFilter(
      valence: scale == MoodScale.valence ? value : valence,
      energy: scale == MoodScale.energy ? value : energy,
      voice: scale == MoodScale.voice ? value : voice,
      tags: tags,
      level: level,
    );
  }

  /// [tag] picked if it was not, let go if it was. An unknown tag changes
  /// nothing.
  MoodFilter toggleTag(String tag) {
    if (!kMoodTags.contains(tag)) return this;
    final on = tags.contains(tag);
    return MoodFilter(
      valence: valence,
      energy: energy,
      voice: voice,
      tags: [
        for (final t in kMoodTags)
          if (t == tag ? !on : tags.contains(t)) t
      ],
      level: level,
    );
  }

  /// [to] as the level, the choices as they are.
  MoodFilter withLevel(MoodLevel to) => to == level
      ? this
      : MoodFilter(
          valence: valence, energy: energy, voice: voice, tags: tags, level: to);

  /// The wire form: only the groups that filter, tags in a fixed order —
  /// or null when nothing filters, so no `moods` key is sent at all.
  Map<String, dynamic>? toJson() => isEmpty
      ? null
      : {
          if (valence != null) 'valence': valence,
          if (energy != null) 'energy': energy,
          if (voice != null) 'voice': voice,
          if (tags.isNotEmpty) 'tags': List.of(tags),
          if (level != MoodLevel.standard) 'threshold': level.threshold,
        };

  /// The saved form (Auto DJ's file): the wire form, and a level picked
  /// with nothing set yet, which the wire form leaves out.
  Map<String, dynamic>? toSavedJson() =>
      toJson() ??
      (level == MoodLevel.standard ? null : {'threshold': level.threshold});

  @override
  bool operator ==(Object other) =>
      other is MoodFilter &&
      other.valence == valence &&
      other.energy == energy &&
      other.voice == voice &&
      other.tags.length == tags.length &&
      other.tags.every(tags.contains) &&
      other.level == level;

  @override
  int get hashCode =>
      Object.hash(valence, energy, voice, Object.hashAll(tags), level);
}

/// Whether a random-songs answer's [echo] (its `moods`) is the filter it was
/// [asked] for. A server that could not filter leaves the key out, and one
/// that filtered nothing answers {}: either way its songs are not from
/// inside the mood.
bool moodEchoFits(Object? echo, MoodFilter asked) =>
    echo is Map && MoodFilter.fromJson(echo) == asked;

/// The pages that filter by mood. Each keeps its own filter.
enum MoodPage {
  albums,
  artists,
  rated,
  recent,
  discover;

  /// Rated and Recent: song lists, which the sheet offers a Sort on.
  bool get sorts => this == rated || this == recent;
}

/// A song list's order under a mood filter: its own (Rated by rating,
/// Recent newest first), or the best `moodMatch` first.
enum MoodSort { list, match }

/// Each page's filter, and a song list's Sort, for as long as the app runs
/// (as in the webapp: a filter set on Albums is there on the next visit, and
/// does not filter Artists). Not saved. [generation] counts each page's
/// changes, so a list asked for under an older filter can tell its answer
/// is stale.
class MoodFilters {
  static final MoodFilters _instance = MoodFilters._();
  factory MoodFilters() => _instance;
  MoodFilters._();

  final Map<MoodPage, MoodFilter> _filters = {};
  final Map<MoodPage, MoodSort> _sorts = {};
  final Map<MoodPage, int> _generations = {};

  MoodFilter of(MoodPage page) => _filters[page] ?? MoodFilter.empty;

  /// The page's Sort as last picked, which rests while no mood is set.
  MoodSort sortOf(MoodPage page) => _sorts[page] ?? MoodSort.list;

  /// The order the page's list shows: its Sort while a mood is set, its
  /// own otherwise (Match has nothing to rank by).
  MoodSort orderOf(MoodPage page) =>
      of(page).isEmpty ? MoodSort.list : sortOf(page);

  int generation(MoodPage page) => _generations[page] ?? 0;

  /// [filter], and a song list's [sort] when given, become the page's.
  /// True when its list has to be asked again: what it sends or the order
  /// it shows changed — a level picked with no mood set changes neither,
  /// and neither does the same choice made again. Only those count as a
  /// [generation].
  bool set(MoodPage page, MoodFilter filter, {MoodSort? sort}) {
    final before = _asked(page);
    _filters[page] = filter;
    if (sort != null) _sorts[page] = sort;
    if (_asked(page) == before) return false;
    _generations[page] = generation(page) + 1;
    return true;
  }

  /// What the page's list is asked with and shown in.
  (MoodFilter, MoodSort) _asked(MoodPage page) => of(page).isEmpty
      ? (MoodFilter.empty, MoodSort.list)
      : (of(page), orderOf(page));

  /// Every page back to no filter (tests).
  void reset() {
    _filters.clear();
    _sorts.clear();
    _generations.clear();
  }
}

/// A list the toolbar offers Filters on: an Albums or Artists list whose
/// server answered with the echo, or a Rated or Recent list whose server's
/// flag says it filters by mood. One per browser frame
/// (BrowserManager.moodFrameCache), like the genre list's state.
class MoodListFrame {
  final Server? server;
  final MoodPage page;

  const MoodListFrame(this.server, this.page);

  /// The frame for a list answer: null unless it carries `moods` (an
  /// object), which a server that cannot filter leaves out.
  static MoodListFrame? fromAnswer(Object? res, Server? server, MoodPage page) =>
      res is Map && res['moods'] is Map ? MoodListFrame(server, page) : null;
}

/// A song row's match in a filtered song list's answer (0 to 1), or null.
double? moodMatchOf(Object? song) =>
    song is Map && song['moodMatch'] is num
        ? (song['moodMatch'] as num).toDouble()
        : null;

/// A filtered Rated or Recent list, best match first. Equal matches keep
/// the list's own order, and a song with none goes last; a list with no
/// matches (unfiltered) comes back as it is.
List<DisplayItem> byMoodMatch(List<DisplayItem> songs) {
  if (!songs.any((s) => s.moodMatch != null)) return songs;
  final order = [for (var i = 0; i < songs.length; i++) i];
  double m(int i) => songs[i].moodMatch ?? -1;
  // List.sort is not stable: the index breaks the ties.
  order.sort((a, b) {
    final by = m(b).compareTo(m(a));
    return by != 0 ? by : a.compareTo(b);
  });
  return [for (final i in order) songs[i]];
}
