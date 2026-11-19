import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

// The queue-end Auto-DJ top-up trigger. The regression this pins: an IDLE
// player's stub index emissions land on the last row without any playback
// behind them — a batch "Add all" onto a fresh-boot player with the DJ armed
// fired the top-up, each appended pick re-emitted the new last index, and the
// loop stacked eleven picks in nine seconds while the now-playing surface
// flashed through them. Only a real playback session may top up.
void main() {
  bool topUp(int? index, int len, BackendProcessingState s,
          {bool inFailureWalk = false, bool clearing = false}) =>
      AudioPlayerHandler.shouldTopUpAutoDJ(
          index: index,
          queueLength: len,
          state: s,
          inFailureWalk: inFailureWalk,
          clearing: clearing);

  test('advancing into the last track tops up', () {
    expect(topUp(29, 30, BackendProcessingState.ready), isTrue);
  });

  test('the queue completing on the last track tops up (infinite play)', () {
    expect(topUp(29, 30, BackendProcessingState.completed), isTrue);
  });

  test('IDLE emissions on the last row must NOT top up', () {
    // The runaway: fresh-boot idle player, 30 tracks batch-added, stub emits
    // index 29 — no session, no top-up.
    expect(topUp(29, 30, BackendProcessingState.idle), isFalse);
    // And each DJ append's follow-on idle emission (the loop's second half).
    expect(topUp(30, 31, BackendProcessingState.idle), isFalse);
  });

  test('mid-queue emissions never top up', () {
    expect(topUp(3, 30, BackendProcessingState.ready), isFalse);
  });

  test('null index / empty queue never top up', () {
    expect(topUp(null, 30, BackendProcessingState.ready), isFalse);
    expect(topUp(0, 0, BackendProcessingState.ready), isFalse);
  });

  test('a live failure walk must NOT be fed picks', () {
    // The other runaway: streams broken but the random-songs API healthy.
    // Each failed-track skip lands on the last row LOADING (non-idle), so
    // without this input the walk and the DJ feed each other unboundedly —
    // the walk's exit conditions both chase the queue the DJ keeps growing.
    expect(topUp(29, 30, BackendProcessingState.loading, inFailureWalk: true),
        isFalse);
    expect(topUp(29, 30, BackendProcessingState.ready, inFailureWalk: true),
        isFalse);
    // A recovered player (any track reached ready → the budget reset) tops
    // up again as normal.
    expect(topUp(29, 30, BackendProcessingState.ready), isTrue);
  });

  test('a queue clear under way never tops up', () {
    // The clear opens the new lane at once, but the old rows wait in the
    // queue until the player has stopped, and the stop's own events re-emit
    // the playing index on the last row. A top-up then would open the new
    // lane on the row being thrown away: Drift's blend took it into More
    // like, and the pick would land in the emptied queue.
    expect(topUp(1, 2, BackendProcessingState.ready, clearing: true), isFalse);
    expect(topUp(1, 2, BackendProcessingState.completed, clearing: true),
        isFalse);
    // Once the clear is done the queue is empty, and the next queue tops up
    // as normal.
    expect(topUp(1, 2, BackendProcessingState.ready), isTrue);
  });
}
