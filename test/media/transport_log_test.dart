// The handler's numbered transport commands: the number moves the moment a
// verb is called, the command reaches listeners afterwards, and each of the
// seven verbs notes itself as its very first statement. That last part is
// pinned in the source: a note moved below one of play's early returns
// would let the sleep timer's pause slip by unnumbered, and the song would
// resume after a preview clip the timer meant to end the night on.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/transport_log.dart';

void main() {
  group('TransportLog', () {
    test('the number moves synchronously, the command arrives after', () async {
      final log = TransportLog();
      final got = <TransportCommand>[];
      final sub = log.commands.listen(got.add);
      expect(log.epoch, 0);

      log.note('pause');
      expect(log.epoch, 1, reason: 'readable right after the call');
      expect(got, isEmpty, reason: 'delivered asynchronously');
      log.note('play');
      log.note('seek');
      expect(log.epoch, 3);

      await Future<void>.delayed(Duration.zero);
      expect(got, [
        (epoch: 1, command: 'pause'),
        (epoch: 2, command: 'play'),
        (epoch: 3, command: 'seek'),
      ]);
      await sub.cancel();
    });

    test('every listener hears it; a late one only what follows', () async {
      final log = TransportLog();
      final a = <int>[];
      final b = <int>[];
      final subA = log.commands.listen((c) => a.add(c.epoch));
      log.note('play');
      await Future<void>.delayed(Duration.zero);
      final subB = log.commands.listen((c) => b.add(c.epoch));
      log.note('pause');
      await Future<void>.delayed(Duration.zero);
      expect(a, [1, 2]);
      expect(b, [2]);
      await subA.cancel();
      await subB.cancel();
    });

    test('the seven verbs', () {
      expect(TransportLog.verbs, [
        'play',
        'pause',
        'stop',
        'seek',
        'skipToNext',
        'skipToPrevious',
        'skipToQueueItem',
      ]);
    });
  });

  group('AudioPlayerHandler notes every verb first (source pin)', () {
    final source = File('lib/media/audio_stuff.dart').readAsStringSync();

    test('the handler owns one log', () {
      expect(
          RegExp(r'final TransportLog transport = TransportLog\(\);')
              .allMatches(source),
          hasLength(1));
    });

    for (final verb in TransportLog.verbs) {
      test('$verb starts with transport.note(\'$verb\')', () {
        final head = RegExp(
            r'@override\s+Future<void> ' + verb + r'\([^)]*\)( async)? \{');
        final heads = head.allMatches(source).toList();
        expect(heads, hasLength(1), reason: 'one $verb override');
        // The body from its opening brace, line comments and blank lines
        // skipped: the first statement must be the note.
        final body = source
            .substring(heads.single.end)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('//'));
        expect(body.first, "transport.note('$verb');");
      });
    }

    test('nothing else notes a command', () {
      expect(RegExp(r'transport\.note\(').allMatches(source),
          hasLength(TransportLog.verbs.length));
    });
  });
}
