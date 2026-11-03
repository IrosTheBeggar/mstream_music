// mix_filters.dart — what an Instant Mix page asks the server for, and the
// filters a new page opens with.
//
// Every request a mix page makes is built here, by [MixFilters.toRequest]:
// the seed's `from`, `limit`, and the page's filters. The route takes Auto
// DJ's own filter keys (random-songs' ignoreVPaths, minRating, genres,
// length, moods, tempo and key) plus a mix-only skipWords, each sent only
// while it holds a value and each a hard filter the server never relaxes.
// The library ones go through libraryFilterFields, as Auto DJ's do, so the
// same choices go out the same way. Tempo and key are windows around the
// seed song's own (bpmWindows, camelotNeighbours): only a song seed has a
// tempo or a key, so only its page offers them.
//
// A page holds what it applies, nothing more ([MixFilters.forSeed]). It
// never reads or writes Auto DJ's filters: a new page opens with the last
// ones applied on any mix page this run ([MixFilterStore]).

import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../util/bpm_windows.dart';
import '../util/camelot.dart';
import '../util/library_filters.dart';
import 'genre_source.dart';
import 'instant_mix.dart';
import 'mood_filter.dart';
import 'server.dart';

/// Whether a mix page on [server] offers Smart filters: the server says it
/// filters by mood (a peer's flag is pinned off).
bool mixOffersMood(Server server) => server.moodFiltersAvailable == true;

/// The folders a mix page on [server] can switch off, in the server's
/// order: none unless it has two or more. They are the server's folders as
/// it last reported them (the keys of Server.autoDJPaths); which of them
/// are on there is Auto DJ's, and never read here.
List<String> mixFolders(Server server) => server.autoDJPaths.length > 1
    ? List.of(server.autoDJPaths.keys)
    : const [];

/// The filters on one mix page, in its Filters sheet's order. Immutable: a
/// change is a new value, which the page asks the server with
/// (InstantMixController.apply).
@immutable
class MixFilters {
  /// Smart filters.
  final MoodFilter mood;

  final GenreChoice genres;

  /// The minimum rating on the server's half-star scale, 1–10; 0 is Any.
  final int minRating;

  /// The length window in seconds; 0 is no limit on that side.
  final int minDuration;
  final int maxDuration;

  /// Whether a song with no known length counts — only beside a limit.
  final bool allowUnknownDuration;

  /// Beat matching: within [bpmTolerance] BPM of the seed's tempo, or of
  /// half or double it.
  final bool tempo;
  final int bpmTolerance;

  /// Harmonic mixing: in a key that mixes with the seed's.
  final bool harmonic;

  /// Words that keep a song out: its title, artist, album or path holding
  /// one (the server matches them).
  final List<String> skipWords;

  /// The server's folders switched off, in its order.
  final List<String> foldersOff;

  const MixFilters({
    this.mood = MoodFilter.empty,
    this.genres = GenreChoice.none,
    this.minRating = 0,
    this.minDuration = 0,
    this.maxDuration = 0,
    this.allowUnknownDuration = false,
    this.tempo = false,
    this.bpmTolerance = defaultBpmTolerance,
    this.harmonic = false,
    this.skipWords = const [],
    this.foldersOff = const [],
  });

  /// Beat matching's tolerance until one is picked (Auto DJ's default).
  static const int defaultBpmTolerance = 8;

  /// Nothing set: the mix of the seed alone.
  static const MixFilters empty = MixFilters();

  bool get hasLength => minDuration > 0 || maxDuration > 0;

  /// Whether nothing is set, so no filter key goes out.
  bool get isEmpty =>
      mood.isEmpty &&
      genres.isEmpty &&
      minRating == 0 &&
      !hasLength &&
      !tempo &&
      !harmonic &&
      skipWords.isEmpty &&
      foldersOff.isEmpty;

  /// The Filters button's badge: the mood's choices, and one for each other
  /// row that is set.
  int get count =>
      mood.count +
      [
        !genres.isEmpty,
        minRating > 0,
        hasLength,
        tempo,
        harmonic,
        skipWords.isNotEmpty,
        foldersOff.isNotEmpty,
      ].where((set) => set).length;

  MixFilters copyWith({
    MoodFilter? mood,
    GenreChoice? genres,
    int? minRating,
    int? minDuration,
    int? maxDuration,
    bool? allowUnknownDuration,
    bool? tempo,
    int? bpmTolerance,
    bool? harmonic,
    List<String>? skipWords,
    List<String>? foldersOff,
  }) =>
      MixFilters(
        mood: mood ?? this.mood,
        genres: genres ?? this.genres,
        minRating: minRating ?? this.minRating,
        minDuration: minDuration ?? this.minDuration,
        maxDuration: maxDuration ?? this.maxDuration,
        allowUnknownDuration: allowUnknownDuration ?? this.allowUnknownDuration,
        tempo: tempo ?? this.tempo,
        bpmTolerance: bpmTolerance ?? this.bpmTolerance,
        harmonic: harmonic ?? this.harmonic,
        skipWords: skipWords ?? this.skipWords,
        foldersOff: foldersOff ?? this.foldersOff,
      );

  /// These filters as a page for [seed] applies them: what it cannot —
  /// Beat matching without the seed's tempo, Harmonic mixing without its
  /// key, a mood where the server has no scores, a rating on a peer,
  /// folders the server does not have — is left out, so the page never
  /// names a filter its rows ignore.
  MixFilters forSeed(MixSeed seed) {
    final server = seed.server;
    final folders = mixFolders(server);
    final off = [
      for (final f in folders)
        if (foldersOff.contains(f)) f,
    ];
    return copyWith(
      mood: mixOffersMood(server) ? mood : MoodFilter.empty,
      minRating: server.isFederated ? 0 : minRating,
      tempo: tempo && seed.hasBpm,
      harmonic: harmonic && seed.camelotKey != null,
      // Every folder off would leave the server nothing to draw from.
      foldersOff: off.length < folders.length ? off : const [],
    );
  }

  /// The body of POST /api/v1/discovery/local/mix for [seed] under these
  /// filters: `from`, `limit`, and each filter that is set.
  Map<String, dynamic> toRequest(MixSeed seed) {
    final bpm = seed.bpm;
    final key = seed.camelotKey;
    return {
      'from': Map.of(seed.from),
      'limit': kInstantMixLimit,
      ...libraryFilterFields(
        seed.server,
        ignoreVPaths: foldersOff,
        minRating: minRating > 0 ? minRating : null,
        genres: genres.genres,
        genreMode: genres.mode,
        genreSource: genres.source,
        duration: hasLength
            ? (
                min: minDuration > 0 ? minDuration : null,
                max: maxDuration > 0 ? maxDuration : null,
              )
            : null,
        allowUnknownDuration: allowUnknownDuration,
        mood: mood,
      ),
      if (tempo && bpm != null && bpm > 0)
        'bpmRanges': [
          // The route takes windows inside 0–1000 BPM: one past an end (a
          // stray tag's double tempo) is cut there rather than refused.
          for (final w in bpmWindows(bpm, bpmTolerance))
            {'min': w['min']!.clamp(0, 1000), 'max': w['max']!.clamp(0, 1000)},
        ],
      if (harmonic && key != null) ...{
        'musicalKeys': camelotNeighbours(key),
        'requireMusicalKey': true,
      },
      if (skipWords.isNotEmpty) 'skipWords': List.of(skipWords),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MixFilters &&
      other.mood == mood &&
      other.genres == genres &&
      other.minRating == minRating &&
      other.minDuration == minDuration &&
      other.maxDuration == maxDuration &&
      other.allowUnknownDuration == allowUnknownDuration &&
      other.tempo == tempo &&
      other.bpmTolerance == bpmTolerance &&
      other.harmonic == harmonic &&
      listEquals(other.skipWords, skipWords) &&
      listEquals(other.foldersOff, foldersOff);

  @override
  int get hashCode => Object.hash(
      mood,
      genres,
      minRating,
      minDuration,
      maxDuration,
      allowUnknownDuration,
      tempo,
      bpmTolerance,
      harmonic,
      Object.hashAll(skipWords),
      Object.hashAll(foldersOff));
}

/// The filters a new mix page opens with: the last ones applied on any mix
/// page (its Filters' Done, its strip's Clear), for as long as the app runs
/// — as on the mood lists, a filter set once is there on the next mix. Not
/// saved, and never Auto DJ's: its filters steer a playing session.
///
/// Mood, length, tempo, harmonic mixing and skip words are the app's: they
/// mean the same on every server. Genres, rating and folders are each
/// server's own (a genre or a folder is one library's word), by localname.
/// An open page keeps the filters it has until its own change: an older mix
/// under a newer one is not touched by the newer one's.
class MixFilterStore {
  static final MixFilterStore _instance = MixFilterStore._();
  factory MixFilterStore() => _instance;
  MixFilterStore._();

  /// The app's parts (the per-server fields unused).
  MixFilters _app = MixFilters.empty;

  /// Each server's parts, by localname (the app's fields unused).
  final Map<String, MixFilters> _servers = {};

  /// What a new page for [seed] opens with: the app's parts and its
  /// server's, less what that page cannot apply ([MixFilters.forSeed]).
  MixFilters of(MixSeed seed) {
    final own = _servers[seed.server.localname] ?? MixFilters.empty;
    return _app
        .copyWith(
            genres: own.genres,
            minRating: own.minRating,
            foldersOff: own.foldersOff)
        .forSeed(seed);
  }

  /// [filters], applied on [seed]'s page, become the store's — the parts
  /// that page offers. What it could not apply (Beat matching on an album's
  /// mix, a mood where the server has no scores) stays as it was, for the
  /// pages that can.
  void set(MixSeed seed, MixFilters filters) {
    final server = seed.server;
    _app = MixFilters(
      mood: mixOffersMood(server) ? filters.mood : _app.mood,
      minDuration: filters.minDuration,
      maxDuration: filters.maxDuration,
      allowUnknownDuration: filters.allowUnknownDuration,
      tempo: seed.hasBpm ? filters.tempo : _app.tempo,
      bpmTolerance: seed.hasBpm ? filters.bpmTolerance : _app.bpmTolerance,
      harmonic: seed.camelotKey != null ? filters.harmonic : _app.harmonic,
      skipWords: filters.skipWords,
    );
    final own = _servers[server.localname] ?? MixFilters.empty;
    _servers[server.localname] = MixFilters(
      genres: filters.genres,
      minRating: server.isFederated ? own.minRating : filters.minRating,
      foldersOff:
          mixFolders(server).isEmpty ? own.foldersOff : filters.foldersOff,
    );
  }

  /// Nothing kept (tests).
  void reset() {
    _app = MixFilters.empty;
    _servers.clear();
  }
}
