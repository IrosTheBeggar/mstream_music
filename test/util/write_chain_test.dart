import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/write_chain.dart';

void main() {
  group('WriteChain', () {
    test('serializes overlapping actions in submission order', () async {
      final chain = WriteChain();
      final log = <String>[];
      final gate = Completer<void>();

      // First action blocks until released; the rest are queued behind it.
      final f1 = chain.run(() async {
        log.add('a:start');
        await gate.future;
        log.add('a:end');
      });
      final f2 = chain.run(() async => log.add('b'));
      final f3 = chain.run(() async => log.add('c'));

      // Nothing after the first can run while it is in flight — this is the
      // interleaved truncate+write hazard the chain exists to prevent.
      await Future<void>.delayed(Duration.zero);
      expect(log, ['a:start']);

      gate.complete();
      await Future.wait([f1, f2, f3]);
      expect(log, ['a:start', 'a:end', 'b', 'c']);
    });

    test('a failed action does not block later actions', () async {
      final chain = WriteChain();
      final log = <String>[];

      final failing = chain.run(() async => throw StateError('disk full'));
      final after = chain.run(() async => log.add('after'));

      await expectLater(failing, throwsStateError);
      await after;
      expect(log, ['after']);
    });

    test('each caller sees its own action outcome', () async {
      final chain = WriteChain();
      final ok = chain.run(() async {});
      final bad = chain.run(() async => throw StateError('nope'));
      final okAgain = chain.run(() async {});

      await expectLater(ok, completes);
      await expectLater(bad, throwsStateError);
      await expectLater(okAgain, completes);
    });
  });
}
