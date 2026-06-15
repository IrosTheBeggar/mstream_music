import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/settings.dart';

// SearchScope is the contract behind the DB-search scope dropdown: each scope
// maps to a combination of the /api/v1/db/search `no*` flags. ApiManager
// .searchServer sends `noArtists: !scope.includeArtists` (etc.), so these
// getters decide which categories the server actually queries. The default
// `everything` must reproduce mStream's legacy artists+albums+songs search
// (i.e. files excluded → noFiles:true), so that's pinned explicitly.
void main() {
  group('SearchScope category flags', () {
    test('everything = artists + albums + songs, files excluded (legacy)', () {
      const s = SearchScope.everything;
      expect(s.includeArtists, isTrue);
      expect(s.includeAlbums, isTrue);
      expect(s.includeSongs, isTrue);
      expect(s.includeFiles, isFalse);
      // The flags the API actually sends — legacy behaviour was noFiles:true.
      expect(!s.includeFiles, isTrue);
    });

    test('single-category scopes query exactly one category', () {
      void only(SearchScope s,
          {required bool artists,
          required bool albums,
          required bool songs,
          required bool files}) {
        expect(s.includeArtists, artists, reason: '$s artists');
        expect(s.includeAlbums, albums, reason: '$s albums');
        expect(s.includeSongs, songs, reason: '$s songs');
        expect(s.includeFiles, files, reason: '$s files');
      }

      only(SearchScope.artists,
          artists: true, albums: false, songs: false, files: false);
      only(SearchScope.albums,
          artists: false, albums: true, songs: false, files: false);
      only(SearchScope.songs,
          artists: false, albums: false, songs: true, files: false);
      only(SearchScope.files,
          artists: false, albums: false, songs: false, files: true);
    });

    test('every scope queries at least one category (no empty search)', () {
      for (final s in SearchScope.values) {
        final any = s.includeArtists ||
            s.includeAlbums ||
            s.includeSongs ||
            s.includeFiles;
        expect(any, isTrue, reason: '$s would send all no* flags true');
      }
    });
  });
}
