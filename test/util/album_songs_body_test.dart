import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/album_songs_body.dart';

void main() {
  group('albumSongsBody', () {
    test('an album with a single credit sends name, year and album_artist', () {
      expect(albumSongsBody('Echo', year: 2010, albumArtist: 'Ann'),
          {'album': 'Echo', 'year': 2010, 'album_artist': 'Ann'});
    });

    test('a card whose rows disagree (null credit) sends the name and year only',
        () {
      expect(albumSongsBody('Twin', year: 2003, albumArtist: null),
          {'album': 'Twin', 'year': 2003});
    });

    test('an older server\'s item (no year, no credit) sends exactly the old body',
        () {
      expect(albumSongsBody('Solo'), {'album': 'Solo'});
      expect(albumSongsBody('Solo', albumArtist: '  '), {'album': 'Solo'},
          reason: 'blank is not a credit');
    });

    test('the singles bucket keeps album null', () {
      expect(albumSongsBody(null, year: null, albumArtist: 'Ann'),
          {'album': null, 'album_artist': 'Ann'});
    });
  });

  group('albumYearOf / albumArtistOf', () {
    test('year accepts int, num and numeric string', () {
      expect(albumYearOf(2001), 2001);
      expect(albumYearOf(2001.0), 2001);
      expect(albumYearOf('1999'), 1999);
      expect(albumYearOf(' 1999 '), 1999);
      expect(albumYearOf('n/a'), isNull);
      expect(albumYearOf(null), isNull);
    });

    test('album artist is a trimmed non-empty string or null', () {
      expect(albumArtistOf('Various Artists'), 'Various Artists');
      expect(albumArtistOf(' Ann '), 'Ann');
      expect(albumArtistOf(''), isNull);
      expect(albumArtistOf(null), isNull);
      expect(albumArtistOf(['Ann', 'Bob']), isNull,
          reason: 'a credits list is not the single credit');
    });
  });
}
