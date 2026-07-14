import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  MediaItem serverItem(String path, {String server = 's1'}) => MediaItem(
        id: 'http://host/media$path?token=t',
        title: path,
        extras: {'server': server, 'path': path},
      );

  group('AudioPlayerHandler.queueWithoutServer', () {
    // Deleting a server drops its queued tracks; the plan must map the
    // playing row to its post-removal index (or a sensible neighbour) so the
    // setSources+seek that applies it lands where the listener expects.

    test('null when nothing in the queue belongs to the server', () {
      final q = [serverItem('/a'), serverItem('/b')];
      expect(AudioPlayerHandler.queueWithoutServer(q, 's2', 0), isNull);
    });

    test('current item survives: index follows its shifted position', () {
      final q = [
        serverItem('/dead1', server: 'gone'),
        serverItem('/a'),
        serverItem('/dead2', server: 'gone'),
        serverItem('/b'), // current
      ];
      final plan = AudioPlayerHandler.queueWithoutServer(q, 'gone', 3)!;
      expect(plan.keep.map((m) => m.title), ['/a', '/b']);
      expect(plan.currentSurvives, isTrue);
      expect(plan.newIndex, 1);
      // Survivors keep their instances (backend sources swap by identity).
      expect(identical(plan.keep[0], q[1]), isTrue);
    });

    test('current item removed: lands on the first survivor after it', () {
      final q = [
        serverItem('/a'),
        serverItem('/dead', server: 'gone'), // current
        serverItem('/dead2', server: 'gone'),
        serverItem('/b'),
      ];
      final plan = AudioPlayerHandler.queueWithoutServer(q, 'gone', 1)!;
      expect(plan.keep.map((m) => m.title), ['/a', '/b']);
      expect(plan.currentSurvives, isFalse);
      expect(plan.newIndex, 1, reason: 'the item after the removed block');
    });

    test('current removed with no survivor after: lands on the last one', () {
      final q = [
        serverItem('/a'),
        serverItem('/b'),
        serverItem('/dead', server: 'gone'), // current
      ];
      final plan = AudioPlayerHandler.queueWithoutServer(q, 'gone', 2)!;
      expect(plan.keep.map((m) => m.title), ['/a', '/b']);
      expect(plan.currentSurvives, isFalse);
      expect(plan.newIndex, 1);
    });

    test('whole queue belonged to the server: empty plan', () {
      final q = [serverItem('/a', server: 'gone')];
      final plan = AudioPlayerHandler.queueWithoutServer(q, 'gone', 0)!;
      expect(plan.keep, isEmpty);
      expect(plan.newIndex, 0);
      expect(plan.currentSurvives, isFalse);
    });

    test('items without a server extra are never dropped', () {
      final q = [
        MediaItem(id: 'file:///local/x.mp3', title: 'local'),
        serverItem('/dead', server: 'gone'),
      ];
      final plan = AudioPlayerHandler.queueWithoutServer(q, 'gone', 0)!;
      expect(plan.keep.single.title, 'local');
      expect(plan.currentSurvives, isTrue);
      expect(plan.newIndex, 0);
    });
  });
}
