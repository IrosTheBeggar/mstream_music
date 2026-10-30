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
// echo, and recent/added's schema refuses unknown keys too.

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

  const MoodFilter({this.valence, this.energy, this.voice, this.tags = const []});

  static const empty = MoodFilter();

  bool get isEmpty =>
      valence == null && energy == null && voice == null && tags.isEmpty;

  /// How many choices are set: the scales that filter, plus the tags (the
  /// Filters button's badge).
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
    );
  }

  /// The wire form: only the groups that filter, tags in a fixed order —
  /// or null when nothing filters, so no `moods` key is sent at all.
  Map<String, dynamic>? toJson() => isEmpty
      ? null
      : {
          if (valence != null) 'valence': valence,
          if (energy != null) 'energy': energy,
          if (voice != null) 'voice': voice,
          if (tags.isNotEmpty) 'tags': List.of(tags),
        };

  @override
  bool operator ==(Object other) =>
      other is MoodFilter &&
      other.valence == valence &&
      other.energy == energy &&
      other.voice == voice &&
      other.tags.length == tags.length &&
      other.tags.every(tags.contains);

  @override
  int get hashCode => Object.hash(valence, energy, voice, Object.hashAll(tags));
}

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
