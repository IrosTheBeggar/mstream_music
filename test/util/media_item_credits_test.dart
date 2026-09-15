import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/media_item_credits.dart';

void main() {
  group('primaryArtistOf', () {
    test('prefers the primary artist in extras over the display string', () {
      final item = MediaItem(
        id: 'http://s/x.mp3',
        title: 'Together',
        artist: 'Ann feat. Bob',
        extras: {'server': 's', 'artist': 'Ann'},
      );
      expect(primaryArtistOf(item), 'Ann');
    });

    test('falls back to the item artist for an entry an older build persisted',
        () {
      final item = MediaItem(
        id: 'http://s/x.mp3',
        title: 'One',
        artist: 'Ann',
        extras: {'server': 's'},
      );
      expect(primaryArtistOf(item), 'Ann');
    });

    test('a blank or missing primary artist falls back too', () {
      final blank = MediaItem(
        id: 'x',
        title: 'T',
        artist: 'Ann',
        extras: {'artist': '  '},
      );
      expect(primaryArtistOf(blank), 'Ann');
      final nothing = MediaItem(id: 'y', title: 'T');
      expect(primaryArtistOf(nothing), isNull);
    });
  });
}
