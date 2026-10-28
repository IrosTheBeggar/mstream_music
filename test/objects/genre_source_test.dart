// genre_source.dart — the Genres browser's kinds (tags / generated / both)
// against mStream's `source` filter and `sources` answer (mStream #716): the
// request bodies, reading the answer (null for a server that predates the
// filter), when the switch is offered, the fallback when one kind is
// empty, and what a genre's songs are asked for with.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/genre_source.dart';

void main() {
  group('GenreSource', () {
    test('both asks without a filter; a single kind names itself', () {
      expect(GenreSource.tag.listBody, {'source': 'tag'});
      expect(GenreSource.model.listBody, {'source': 'model'});
      expect(GenreSource.both.listBody, isEmpty);
      expect(GenreSource.both.apiValue, isNull);
    });

    test('a stored name reads back; anything else is tags', () {
      expect(genreSourceFromName('model'), GenreSource.model);
      expect(genreSourceFromName('both'), GenreSource.both);
      expect(genreSourceFromName(null), GenreSource.tag);
      expect(genreSourceFromName('guess'), GenreSource.tag);
    });
  });

  group('GenreSources', () {
    test('reads the counts; a server without the block gives null', () {
      final s = GenreSources.fromJson({'tag': 9, 'model': 32});
      expect(s!.tag, 9);
      expect(s.model, 32);
      expect(s.countOf(GenreSource.both), 41);
      expect(GenreSources.fromJson(null), isNull);
      expect(GenreSources.fromJson('nope'), isNull);
    });

    test('the choice is offered only when both kinds exist', () {
      expect(const GenreSources(9, 32).offersChoice, isTrue);
      expect(const GenreSources(9, 0).offersChoice, isFalse);
      expect(const GenreSources(0, 32).offersChoice, isFalse);
    });
  });

  group('genreSourceFallback', () {
    test('an empty single kind falls back to the other one', () {
      expect(genreSourceFallback(GenreSource.tag, const GenreSources(0, 5)),
          GenreSource.model);
      expect(genreSourceFallback(GenreSource.model, const GenreSources(5, 0)),
          GenreSource.tag);
    });

    test('keeps the choice when it has genres, or nothing does', () {
      expect(genreSourceFallback(GenreSource.tag, const GenreSources(5, 5)),
          isNull);
      expect(genreSourceFallback(GenreSource.tag, const GenreSources(0, 0)),
          isNull);
    });

    test('both never falls back, and an older server never does', () {
      expect(genreSourceFallback(GenreSource.both, const GenreSources(0, 5)),
          isNull);
      expect(genreSourceFallback(GenreSource.tag, null), isNull);
    });
  });

  group('GenreListFrame.songsSource', () {
    test('a single kind is carried into a genre\'s songs', () {
      expect(
          const GenreListFrame(null, GenreSource.model, GenreSources(1, 1))
              .songsSource,
          GenreSource.model);
    });

    test('both, or a server without the filter, asks for every song', () {
      expect(
          const GenreListFrame(null, GenreSource.both, GenreSources(1, 1))
              .songsSource,
          isNull);
      expect(const GenreListFrame(null, GenreSource.tag, null).songsSource,
          isNull);
      expect(const GenreListFrame(null, GenreSource.tag, null).offersChoice,
          isFalse);
    });
  });
}
