import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/auto_browse.dart';
import 'package:mstream_music/native/carplay_bridge.dart';

void main() {
  group('CarPlayBridge.encodeItem', () {
    test('a browse node: not playable, not a notice, no art', () {
      const m = MediaItem(
          id: 'mstreamauto://cat?s=demo&k=albums', title: 'Albums', playable: false);
      expect(CarPlayBridge.encodeItem(m), {
        'id': 'mstreamauto://cat?s=demo&k=albums',
        'title': 'Albums',
        'subtitle': null,
        'artUri': null,
        'playable': false,
        'notice': false,
      });
    });

    test('a track: playable by default, art as a plain URL string', () {
      final m = MediaItem(
          id: 'https://demo/stream/1',
          title: 'Hear The Cry',
          artist: 'Selfless',
          album: 'Album',
          artUri: Uri.parse('https://demo/art/1.jpg?token=abc'));
      final e = CarPlayBridge.encodeItem(m);
      expect(e['playable'], isTrue);
      expect(e['subtitle'], 'Selfless');
      expect(e['artUri'], 'https://demo/art/1.jpg?token=abc');
      expect(e['notice'], isFalse);
    });

    test('subtitle falls back to the album when there is no artist', () {
      const m = MediaItem(id: 'x', title: 'T', album: 'The Album');
      expect(CarPlayBridge.encodeItem(m)['subtitle'], 'The Album');
    });

    test('the notice row is flagged so the car disables it', () {
      final m = MediaItem(
          id: AutoBrowse.noticeId,
          title: 'Nothing here',
          artist: 'This list is empty',
          playable: false);
      final e = CarPlayBridge.encodeItem(m);
      expect(e['notice'], isTrue);
      expect(e['playable'], isFalse);
    });
  });
}
