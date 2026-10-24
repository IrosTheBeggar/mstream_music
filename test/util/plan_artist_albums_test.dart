// util/plan_artist_albums.dart — the albums an artist copy takes and leaves
// out, held to the server's planArtistAlbums through the webapp's cases
// (mStream test/unit/webapp-discover-jobs.test.mjs, "planArtistAlbums and
// the left-out line"): the sheet must count the albums the copy takes.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/plan_artist_albums.dart';

void main() {
  // Boukmanflow on Stage Peer B: three of his own, a collaboration credited
  // to him outside a compilation, a compilation he is on, an album his
  // credit only reaches through a track, and songs outside an album.
  final listing = {
    'albums': [
      {'name': 'Second Shift', 'year': 2023, 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false, 'track_count': 3},
      {'name': 'Harbour Lights', 'year': 2021, 'album_artist': 'boukmanflow ', 'artists': ['Boukmanflow'], 'compilation': false, 'track_count': 3},
      {'name': 'Borrowed Tapes', 'year': '2019', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false, 'track_count': '3'},
      {'name': 'Split Series', 'year': 2022, 'album_artist': null, 'artists': ['ALM', 'Boukmanflow'], 'compilation': false, 'track_count': 2},
      {'name': 'Night Market Sampler', 'year': 2024, 'album_artist': 'Various Artists', 'artists': ['Color Out', 'Boukmanflow', 'ALM'], 'compilation': true, 'track_count': 3},
      {'name': 'Guest Spots', 'year': null, 'album_artist': 'Color Out', 'artists': ['Color Out'], 'compilation': false, 'track_count': null},
      {'name': '  ', 'year': null, 'album_artist': 'Boukmanflow'},
      {'name': null, 'year': null, 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false, 'track_count': null},
      null,
      'junk',
      {'name': 7},
    ],
  };
  final albums = listing['albums']!;

  List<List<Object?>> rows(List<PlannedAlbum> l) =>
      [for (final a in l) [a.name, a.year, a.trackCount, a.albumArtist, a.why]];

  group("the copy's own plan, album for album", () {
    test('Boukmanflow: his three, and the collaboration credited to him; the compilation and the guest spot left out', () {
      final p = planArtistAlbums(listing, 'Boukmanflow');
      // federation-copy planArtistAlbums' answer for the same listing
      expect(rows(p.plan), [
        ['Second Shift', 2023, 3, 'Boukmanflow', null],
        ['Harbour Lights', 2021, 3, 'boukmanflow ', null],
        ['Borrowed Tapes', 2019, 3, 'Boukmanflow', null],
        ['Split Series', 2022, 2, null, null],
      ]);
      expect(rows(p.skipped), [
        ['Night Market Sampler', 2024, 3, null, 'appearance'],
        ['Guest Spots', null, null, null, 'appearance'],
      ]);
      expect(p.singles, isTrue);
      expect(p.appearances, ['Night Market Sampler', 'Guest Spots']);
    });

    test('the artist matched as the server matches it (nameKey): case and spaces aside', () {
      expect(rows(planArtistAlbums(listing, ' BOUKMANFLOW ').plan).map((r) => r.first),
          ['Second Shift', 'Harbour Lights', 'Borrowed Tapes', 'Split Series']);
    });

    test('only the missing: the ones the library has by name stay out as owned; without it they are taken', () {
      final keys = {'harbour lights'};
      final p = planArtistAlbums(listing, 'Boukmanflow', localKeys: keys, onlyMissing: true);
      expect(p.plan.map((a) => a.name), ['Second Shift', 'Borrowed Tapes', 'Split Series']);
      expect(rows(p.skipped), [
        ['Harbour Lights', 2021, 3, null, 'owned'],
        ['Night Market Sampler', 2024, 3, null, 'appearance'],
        ['Guest Spots', null, null, null, 'appearance'],
      ]);
      expect(planArtistAlbums(listing, 'Boukmanflow', localKeys: keys).plan, hasLength(4),
          reason: 'the library is read only for only-missing');
    });

    test('Color Out: her own album, and nothing of the compilation she is on', () {
      final p = planArtistAlbums(listing, 'Color Out');
      expect(p.plan.map((a) => a.name), ['Guest Spots']);
      expect(p.skipped.map((a) => a.name), [
        'Second Shift', 'Harbour Lights', 'Borrowed Tapes', 'Split Series', 'Night Market Sampler',
      ]);
    });

    test('Lantern Choir only appears: nothing to take, everything left out', () {
      final p = planArtistAlbums({'albums': [albums[4]]}, 'Lantern Choir');
      expect([p.plan.length, p.appearances], [0, ['Night Market Sampler']]);
    });

    test("an album credited to the artist is theirs though the listing calls it a compilation; a blank credit is no credit", () {
      final p = planArtistAlbums({
        'albums': [
          // federation-copy planArtistAlbums: its album_artist IS the artist
          {'name': 'DJ Set', 'year': 2020, 'album_artist': 'Boukmanflow', 'artists': ['ALM', 'Color Out'], 'compilation': true, 'track_count': 9},
          {'name': 'Blank Credit', 'year': 2018, 'album_artist': '  ', 'artists': ['Boukmanflow'], 'compilation': false, 'track_count': 2},
        ],
      }, 'Boukmanflow');
      expect(rows(p.plan), [
        ['DJ Set', 2020, 9, 'Boukmanflow', null],
        ['Blank Credit', 2018, 2, null, null],
      ]);
      expect(p.skipped, isEmpty);
    });

    test('no singles bucket, no answer, a bare list', () {
      expect(planArtistAlbums({'albums': []}, 'x').singles, isFalse);
      final none = planArtistAlbums(null, 'x');
      expect([none.plan, none.skipped, none.singles], [isEmpty, isEmpty, false]);
      expect(planArtistAlbums(albums, 'Boukmanflow').plan, hasLength(4),
          reason: 'the albums list itself reads as the answer');
    });
  });

  group('the left-out line', () {
    test('one album by name, then the songs outside an album', () {
      final one = artistLeftOut(
          {'albums': albums.where((a) => a is! Map || a['name'] != 'Guest Spots').toList()},
          'Boukmanflow')!;
      expect([one.one, one.many, one.singles, one.albums], ['Night Market Sampler', 0, true, ['Night Market Sampler']]);
    });

    test('several counted', () {
      final many = artistLeftOut({
        'albums': albums.where((a) => a is Map && a['name'] is String && (a['name'] as String).trim().isNotEmpty).toList(),
      }, 'Boukmanflow')!;
      expect([many.one, many.many, many.singles], [null, 2, false]);
    });

    test('singles alone still stay out; every album theirs and no singles is no line; no answer is none', () {
      final singles = artistLeftOut({'albums': [albums[0], albums[7]]}, 'Boukmanflow')!;
      expect([singles.one, singles.many, singles.singles], [null, 0, true]);
      expect(artistLeftOut({'albums': albums.sublist(0, 4)}, 'Boukmanflow'), isNull);
      expect(artistLeftOut(null, 'Boukmanflow'), isNull);
    });
  });
}
