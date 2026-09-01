import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';

// The sonic seed is ONE-SHOT: the empty-queue start flow sets it moments
// before arming, and the seeded start's own queue clear consumes it (see
// AudioPlayerHandler._doClearPlaylist). Because that consume now runs on
// EVERY clear, clearSonicSeed must be a true no-op when nothing is stored —
// otherwise each clear would rewrite auto_dj.json and rebuild the Auto DJ
// screen for nothing.
//
// These are plain VM tests, so the persistence path (path_provider) is
// unavailable and would throw. That is exactly what makes the no-op
// assertion meaningful: completing normally proves the guard returned
// before touching the filesystem. The clearing branch (fields set → nulled
// + one change tick + save) goes through the platform channel and is
// covered by the simulator smoke pass instead.
void main() {
  final mgr = AutoDJManager();

  setUp(() {
    mgr.sonicSeedPath = null;
    mgr.sonicSeedTitle = null;
    mgr.sonicSeedServer = null;
  });

  test('clearSonicSeed with nothing stored never reaches the save', () async {
    await expectLater(mgr.clearSonicSeed(), completes);
  });

  test('clearSonicSeed no-op emits no change tick', () async {
    var ticks = 0;
    final sub = mgr.changeStream.skip(1).listen((_) => ticks++);
    await mgr.clearSonicSeed();
    await Future<void>.delayed(Duration.zero);
    expect(ticks, 0,
        reason: 'a no-op clear must not rebuild the Auto DJ screen');
    await sub.cancel();
  });

  test('clearing a stored seed nulls every field before persisting', () async {
    mgr.sonicSeedPath = 'music/x.mp3';
    mgr.sonicSeedTitle = 'X';
    mgr.sonicSeedServer = 'srv';
    // The trailing _save() needs path_provider and fails in a VM test; the
    // in-memory clear happens before it, which is the contract the queue
    // clear depends on (autoDJ() reads these fields synchronously).
    await mgr.clearSonicSeed().catchError((_) {});
    expect(mgr.sonicSeedPath, isNull);
    expect(mgr.sonicSeedTitle, isNull);
    expect(mgr.sonicSeedServer, isNull);
  });

  test('a partially stored seed (any field set) still gets cleaned up', () async {
    // The guard keys on all three fields so a torn state is not mistaken for
    // "nothing stored".
    mgr.sonicSeedServer = 'some-server';
    await mgr.clearSonicSeed().catchError((_) {});
    expect(mgr.sonicSeedServer, isNull);
  });
}
