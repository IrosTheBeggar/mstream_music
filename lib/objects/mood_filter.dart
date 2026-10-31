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
// `strict: true` (the strip's Strict) keeps only strong fits — 0.7 rather
// than 0.5. Without it, a filtered song list's songs each carry `moodFit`,
// 'strong' or 'close', and the list shows the strong fits first, the close
// ones under a divider (strongFirst).

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

/// One page's filter. Immutable: every change makes a new one.
class MoodFilter {
  final String? valence;
  final String? energy;
  final String? voice;

  /// Picked tags, always in [kMoodTags] order.
  final List<String> tags;

  /// Strong fits only. It belongs to a filter that filters: an empty one
  /// drops it.
  final bool strict;

  const MoodFilter(
      {this.valence,
      this.energy,
      this.voice,
      this.tags = const [],
      this.strict = false});

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
    return f;
  }

  bool get isEmpty =>
      valence == null && energy == null && voice == null && tags.isEmpty;

  /// How many choices are set: the scales that filter, plus the tags (the
  /// Filters button's badge). Strict is not a choice.
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
      strict: strict,
    )._settled;
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
      strict: strict,
    )._settled;
  }

  /// Strict on or off. A filter with nothing set stays as it is.
  MoodFilter withStrict(bool on) => isEmpty || on == strict
      ? this
      : MoodFilter(
          valence: valence,
          energy: energy,
          voice: voice,
          tags: tags,
          strict: on);

  /// Strict goes with the last choice.
  MoodFilter get _settled => strict && isEmpty ? MoodFilter.empty : this;

  /// The wire form: only the groups that filter, tags in a fixed order —
  /// or null when nothing filters, so no `moods` key is sent at all.
  Map<String, dynamic>? toJson() => isEmpty
      ? null
      : {
          if (valence != null) 'valence': valence,
          if (energy != null) 'energy': energy,
          if (voice != null) 'voice': voice,
          if (tags.isNotEmpty) 'tags': List.of(tags),
          if (strict) 'strict': true,
        };

  @override
  bool operator ==(Object other) =>
      other is MoodFilter &&
      other.valence == valence &&
      other.energy == energy &&
      other.voice == voice &&
      other.tags.length == tags.length &&
      other.tags.every(tags.contains) &&
      other.strict == strict;

  @override
  int get hashCode =>
      Object.hash(valence, energy, voice, Object.hashAll(tags), strict);
}

/// Whether a random-songs answer's [echo] (its `moods`) is the filter it was
/// [asked] for. A server that could not filter leaves the key out, and one
/// that filtered nothing answers {}: either way its songs are not from
/// inside the mood.
bool moodEchoFits(Object? echo, MoodFilter asked) =>
    echo is Map && MoodFilter.fromJson(echo) == asked;

/// The pages that filter by mood. Each keeps its own filter.
enum MoodPage { albums, artists, rated, recent, discover }

/// Each page's filter for as long as the app runs (as in the webapp: a
/// filter set on Albums is there on the next visit, and does not filter
/// Artists). Not saved. [generation] counts each page's changes, so a list
/// asked for under an older filter can tell its answer is stale.
class MoodFilters {
  static final MoodFilters _instance = MoodFilters._();
  factory MoodFilters() => _instance;
  MoodFilters._();

  final Map<MoodPage, MoodFilter> _filters = {};
  final Map<MoodPage, int> _generations = {};

  MoodFilter of(MoodPage page) => _filters[page] ?? MoodFilter.empty;

  int generation(MoodPage page) => _generations[page] ?? 0;

  void set(MoodPage page, MoodFilter filter) {
    _filters[page] = filter;
    _generations[page] = generation(page) + 1;
  }

  /// Every page back to no filter (tests).
  void reset() {
    _filters.clear();
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

/// A song row's fit in a filtered song list's answer, or null.
String? moodFitOf(Object? song) => song is Map &&
        (song['moodFit'] == 'strong' || song['moodFit'] == 'close')
    ? song['moodFit'] as String
    : null;

/// The browser item over a filtered song list's close matches.
const String kMoodCloseMatches = 'moodCloseMatches';

/// A filtered Rated or Recent list, strong fits first: the songs the
/// server marked 'strong', in the list's own order, then — under a
/// [kMoodCloseMatches] item — the 'close' ones. A list with no close match
/// (unfiltered, or strict) comes back as it is.
List<DisplayItem> strongFirst(List<DisplayItem> songs) {
  if (!songs.any((s) => s.moodFit == 'close')) return songs;
  return [
    for (final s in songs)
      if (s.moodFit != 'close') s,
    DisplayItem(null, '', kMoodCloseMatches, null, null, null),
    for (final s in songs)
      if (s.moodFit == 'close') s,
  ];
}

/// [items] narrowed to the ones [keep] passes (a search), the close
/// matches' item kept while a close match stays under it.
List<DisplayItem> narrowKeepingCloseMatches(
    List<DisplayItem> items, bool Function(DisplayItem) keep) {
  final out = [
    for (final it in items)
      if (it.type == kMoodCloseMatches || keep(it)) it
  ];
  if (out.isNotEmpty && out.last.type == kMoodCloseMatches) out.removeLast();
  return out;
}
