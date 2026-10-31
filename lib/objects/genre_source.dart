// genre_source.dart — which genres the Genres browser lists.
//
// mStream (#716) links a song to a genre one of two ways: from the file's
// own genre tag, or because the discovery model predicted the style. Its
// /api/v1/db/genres and /api/v1/db/genre-songs take a `source` filter
// ('tag' | 'model', omitted for both), and /db/genres answers with
// `sources: { tag, model }` — how many genres each kind has here. A server
// that predates the filter ignores it and sends no `sources`.

import 'server.dart';

enum GenreSource {
  tag,
  model,
  both;

  /// The server's `source` value; null for both (no filter).
  String? get apiValue => this == GenreSource.both ? null : name;

  /// The /api/v1/db/genres body that asks for this kind.
  Map<String, dynamic> get listBody =>
      apiValue == null ? <String, dynamic>{} : {'source': apiValue};
}

/// A stored setting name back to the kind; [fallback] (tags) for anything
/// unknown.
GenreSource genreSourceFromName(Object? name,
    {GenreSource fallback = GenreSource.tag}) {
  for (final s in GenreSource.values) {
    if (s.name == name) return s;
  }
  return fallback;
}

/// How many genres each kind has on a server (its `sources` block).
class GenreSources {
  final int tag;
  final int model;

  const GenreSources(this.tag, this.model);

  /// null for a server that predates the filter (no block, or not a map).
  static GenreSources? fromJson(Object? json) {
    if (json is! Map) return null;
    int count(Object? v) => v is num ? v.toInt() : 0;
    return GenreSources(count(json['tag']), count(json['model']));
  }

  /// The switch is offered only when there is a choice to make.
  bool get offersChoice => tag > 0 && model > 0;

  int countOf(GenreSource s) => switch (s) {
        GenreSource.tag => tag,
        GenreSource.model => model,
        GenreSource.both => tag + model,
      };
}

/// The single kind to ask for instead of [chosen] when the server has none
/// of it and some of the other (an untagged library, a server without the
/// model) — null to keep [chosen]. Both never falls back: it is everything.
GenreSource? genreSourceFallback(GenreSource chosen, GenreSources? sources) {
  if (sources == null || chosen == GenreSource.both) return null;
  if (sources.countOf(chosen) > 0) return null;
  final other = chosen == GenreSource.tag ? GenreSource.model : GenreSource.tag;
  return sources.countOf(other) > 0 ? other : null;
}

/// The genre list's own state, one per browser frame that shows it: which
/// kind is listed, what the server said it has, and whose list it is.
class GenreListFrame {
  final Server? server;
  final GenreSource source;
  final GenreSources? sources;

  const GenreListFrame(this.server, this.source, this.sources);

  /// Whether the toolbar shows the Tags | Generated | Both switch.
  bool get offersChoice => sources?.offersChoice ?? false;

  /// What a genre's songs are asked for with: the one kind listed, or null —
  /// both kinds, or a server that cannot tell them apart.
  GenreSource? get songsSource =>
      sources == null || source == GenreSource.both ? null : source;
}
