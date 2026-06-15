import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/settings.dart';

// The search dropdown stores a Set<SearchCategory>; ApiManager.searchServer
// maps it 1:1 onto /api/v1/db/search's no* flags (noArtists = !contains(...)).
// Two invariants are pinned here:
//   1. The default set reproduces mStream's legacy search — artists + albums +
//      songs, files OFF (the old hard-coded noFiles:true).
//   2. applyToggle never empties the set, so a search always has a target.
void main() {
  group('default search categories', () {
    test('is artists + albums + songs, files off (legacy parity)', () {
      const d = SettingsManager.defaultSearchCategories;
      expect(d, {
        SearchCategory.artists,
        SearchCategory.albums,
        SearchCategory.songs,
      });
      // The flag the API derives from this — legacy behaviour was noFiles:true.
      expect(d.contains(SearchCategory.files), isFalse);
    });
  });

  group('SettingsManager.applyToggle', () {
    test('adds an unselected category', () {
      final r = SettingsManager.applyToggle(
          {SearchCategory.artists}, SearchCategory.files);
      expect(r, {SearchCategory.artists, SearchCategory.files});
    });

    test('removes a selected category when others remain', () {
      final r = SettingsManager.applyToggle(
          {SearchCategory.artists, SearchCategory.albums},
          SearchCategory.albums);
      expect(r, {SearchCategory.artists});
    });

    test('unchecking the last category is a no-op (keeps at least one)', () {
      final current = {SearchCategory.songs};
      final r = SettingsManager.applyToggle(current, SearchCategory.songs);
      expect(r, {SearchCategory.songs});
      expect(identical(r, current), isTrue,
          reason: 'returns the input unchanged so callers skip persisting');
    });

    test('does not mutate the input set', () {
      final current = {SearchCategory.artists};
      SettingsManager.applyToggle(current, SearchCategory.albums);
      expect(current, {SearchCategory.artists},
          reason: 'input set must be left untouched');
    });
  });
}
