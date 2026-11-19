// The preview player over a scripted song side and clip: the song is paused
// only once a clip has loaded and resumed exactly once, and only when this
// flow paused it and nobody touched it since. Every transport command, the
// song starting by itself, a track or cast change, a call, the output
// dropping, the app going to the background and a store link each end the
// clip or drop the resume the way the sheet promises.

import 'dart:async';

import 'package:audio_session/audio_session.dart' show AudioInterruptionType;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/cast_target.dart';
import 'package:mstream_music/media/preview_player.dart';

import 'preview_fakes.dart';

class _Rig {
  _Rig({
    bool songPlaying = true,
    bool casting = false,
    String castTarget = CastTarget.localId,
    Duration loadTimeout = const Duration(seconds: 15),
  }) {
    port = FakePreviewPort(
        songPlaying: songPlaying,
        casting: casting,
        castTarget: castTarget,
        log: log);
    next = FakePreviewClip(log: log);
    player =
        PreviewPlayer.withPort(port, loadTimeout: loadTimeout, makeClip: () {
      final made = next;
      clips.add(made);
      next = FakePreviewClip(log: log);
      return made;
    });
  }

  final List<String> log = [];
  final List<FakePreviewClip> clips = [];
  final List<PreviewPlayOutcome> outcomes = [];
  late final FakePreviewPort port;
  late final PreviewPlayer player;

  /// The clip the next play makes, to set up before it does.
  late FakePreviewClip next;

  FakePreviewClip get clip => clips.last;
  PreviewClipState get state => player.state.value;

  void play(String provider, [String url = 'https://cdn.example/30s.mp3']) {
    player.play(provider: provider, url: Uri.parse(url)).then(outcomes.add);
  }

  void end(PreviewEnd reason) => player.end(reason);
}

void main() {
  group('a clip over a playing song', () {
    test('load, then pause the song, then play; the end resumes it once', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();

        expect(r.outcomes, [PreviewPlayOutcome.playing]);
        expect(r.log, ['clip.stop', 'clip.load', 'song.pause', 'clip.play']);
        expect(r.port.playingNow, isFalse);
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.state.provider, 'deezer');
        expect(r.clip.loads.single.toString(), 'https://cdn.example/30s.mp3');

        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 1);
        expect(r.port.playingNow, isTrue);
        expect(r.log.sublist(4), ['clip.stop', 'song.play'],
            reason: 'the clip is told to stop before the song resumes');
        expect(r.state, PreviewClipState.idle);
        expect(r.port.listeners, 0, reason: 'the flow stopped watching');

        // Nothing after the end brings it back a second time.
        r.end(PreviewEnd.sheetClosed);
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 1);
      });
    });

    test('the song plays on while the clip loads', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.holdLoads = true;
        r.play('itunes');
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.loading);
        expect(r.state.provider, 'itunes');
        expect(r.port.pauses, 0);
        expect(r.port.playingNow, isTrue);

        r.clip.finishLoad();
        async.flushMicrotasks();
        expect(r.port.pauses, 1);
        expect(r.clip.playing, isTrue);
      });
    });

    test('its own pause is not taken for the user touching the song', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        expect(r.clip.playing, isTrue);
        expect(r.state.phase, PreviewPhase.playing);
      });
    });

    test('position and length reach the state while it plays', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.clip.emitDuration(const Duration(seconds: 30));
        r.clip.emitPosition(const Duration(seconds: 12));
        async.flushMicrotasks();
        expect(
            r.state,
            const PreviewClipState(
                provider: 'deezer',
                phase: PreviewPhase.playing,
                position: Duration(seconds: 12),
                duration: Duration(seconds: 30)));
      });
    });
  });

  group('somebody else touches the song', () {
    test('the sleep timer pausing mid-clip: the clip stops, no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.userPause(); // the song is already paused: no stream moves
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.state, PreviewClipState.idle);

        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
        expect(r.port.playingNow, isFalse);
      });
    });

    test('a stop ends the clip too, with no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.userStop();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0);
      });
    });

    test('Play on the lock screen: the clip stops, no extra resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.userPlay();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 0);
        expect(r.port.playingNow, isTrue);
      });
    });

    test('a seek or a skip: the clip plays on, the song stays paused', () {
      for (final verb in ['seek', 'skipToNext', 'skipToQueueItem']) {
        fakeAsync((async) {
          final r = _Rig();
          r.play('deezer');
          async.flushMicrotasks();
          r.port.userCommand(verb);
          async.flushMicrotasks();
          expect(r.clip.playing, isTrue, reason: verb);

          r.clip.finish();
          async.flushMicrotasks();
          expect(r.port.plays, 0, reason: verb);
        });
      }
    });

    test('a different track: the clip plays on, no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.changeTrack('home\u0000/Music/Other.mp3');
        async.flushMicrotasks();
        expect(r.clip.playing, isTrue);
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('the cast target changed: the clip plays on, no resume', () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        r.play('deezer');
        async.flushMicrotasks();
        r.port.changeCastTarget(CastTarget.localId, casting: false);
        async.flushMicrotasks();
        expect(r.clip.playing, isTrue);
        r.end(PreviewEnd.sheetClosed);
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    // The replay of a BehaviorSubject can still say playing after the pause
    // was sent (a renderer answering slowly): only a false → true edge is
    // the song starting.
    test('a stale playing replay does not end the clip; an edge does', () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        final gate = r.port.pauseGate = Completer<void>();
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.port.pauses, 1);
        expect(r.port.playingNow, isTrue, reason: 'the pause has not landed');

        gate.complete();
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.playing]);
        expect(r.clip.playing, isTrue);

        r.port.startsByItself(); // a park pick landing, the end of a call
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 0);
      });
    });
  });

  group('the outside world', () {
    test('a call: the clip stops and the song stays paused; a duck is not', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.interrupt(AudioInterruptionType.duck);
        async.flushMicrotasks();
        expect(r.clip.playing, isTrue);

        r.port.interrupt();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        r.port.interruptionEnds();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
        expect(r.clip.playing, isFalse, reason: 'never brought back');
      });
    });

    test('the output drops: local stays paused, a cast resumes', () {
      fakeAsync((async) {
        final local = _Rig();
        local.play('deezer');
        async.flushMicrotasks();
        local.port.becomeNoisy();
        async.flushMicrotasks();
        expect(local.clip.playing, isFalse);
        expect(local.port.plays, 0);

        final cast = _Rig(castTarget: 'tv-1', casting: true);
        cast.play('deezer');
        async.flushMicrotasks();
        cast.port.becomeNoisy();
        async.flushMicrotasks();
        expect(cast.clip.playing, isFalse);
        expect(cast.port.plays, 1);
      });
    });

    test('the app goes to the background: the song resumes', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('itunes');
        async.flushMicrotasks();
        r.port.hideApp();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 1);
      });
    });

    test('a store link (left the app): no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('itunes');
        async.flushMicrotasks();
        r.end(PreviewEnd.leftApp);
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0);
        // Leaving the app afterwards changes nothing.
        r.port.hideApp();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('casting: the cast is paused and resumed like local playback', () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.port.pauses, 1);
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 1);
      });
    });
  });

  group('switching and stopping', () {
    test('another provider: still one pause, one resume at the end', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.play('itunes');
        async.flushMicrotasks();
        expect(r.outcomes,
            [PreviewPlayOutcome.playing, PreviewPlayOutcome.playing]);
        expect(r.port.pauses, 1);
        expect(r.port.plays, 0, reason: 'the song stays paused in between');
        expect(r.clips, hasLength(1), reason: 'one player, reused');
        expect(r.clip.loads, hasLength(2));
        expect(r.state.provider, 'itunes');

        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 1);
      });
    });

    test('a tap superseded while it loads does nothing', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.holdLoads = true;
        r.play('deezer');
        async.flushMicrotasks();
        r.play('itunes'); // its stop interrupts deezer's load
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.superseded]);
        expect(r.port.pauses, 0);
        expect(r.clip.playCalls, 0);

        r.clip.finishLoad();
        async.flushMicrotasks();
        expect(r.outcomes,
            [PreviewPlayOutcome.superseded, PreviewPlayOutcome.playing]);
        expect(r.port.pauses, 1);
        expect(r.clip.playCalls, 1);
        expect(r.state.provider, 'itunes');
      });
    });

    test('an end while it loads: superseded, the song never paused', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.holdLoads = true;
        r.play('deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.sheetClosed);
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.superseded]);
        expect(r.port.pauses, 0);
        expect(r.port.plays, 0);
        expect(r.clip.disposed, isTrue);
        expect(r.state, PreviewClipState.idle);
      });
    });

    test(
        'the playing tile tapped: the clip resets and the song resumes; '
        'tapped again at once, the song pauses again', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.stopped);
        r.play('deezer'); // in the same turn as the resume
        async.flushMicrotasks();
        expect(r.port.plays, 1);
        expect(r.port.pauses, 2);
        expect(r.outcomes.last, PreviewPlayOutcome.playing);
        expect(r.clip.playing, isTrue,
            reason: 'our own resume is not '
                'taken for the song starting');
        expect(r.state.phase, PreviewPhase.playing);

        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 2);
      });
    });

    test('a pause still landing when the sheet closes: the song comes back',
        () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        final gate = r.port.pauseGate = Completer<void>();
        r.play('deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.sheetClosed);
        async.flushMicrotasks();
        expect(r.port.plays, 1);

        gate.complete();
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.superseded]);
        expect(r.clip.playCalls, 0);
      });
    });

    test('two ends: only the first decides', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.clip.finish();
        r.end(PreviewEnd.sheetClosed);
        async.flushMicrotasks();
        expect(r.port.plays, 1);
      });
    });
  });

  group('failures', () {
    test('a failed load with nothing held never touches the song', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.loadError = Exception('403 Forbidden');
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.failed]);
        expect(r.port.touches, 0);
        expect(r.port.playingNow, isTrue);
        expect(
            r.state,
            const PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.failed));

        // A retry starts afresh.
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.outcomes.last, PreviewPlayOutcome.playing);
        expect(r.port.pauses, 1);
      });
    });

    test('a load that never answers fails at the load timeout', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.holdLoads = true;
        r.play('itunes');
        async.elapse(const Duration(seconds: 14));
        expect(r.outcomes, isEmpty);
        expect(r.state.phase, PreviewPhase.loading);
        async.elapse(const Duration(seconds: 1));
        expect(r.outcomes, [PreviewPlayOutcome.failed]);
        expect(r.state.phase, PreviewPhase.failed);
        expect(r.port.pauses, 0);
        expect(r.clip.pendingLoads, 0, reason: 'the stop abandoned it');
      });
    });

    test('a failed switch resumes the song the first clip paused', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.clip.loadError = Exception('timeout');
        r.play('itunes');
        async.flushMicrotasks();
        expect(r.outcomes.last, PreviewPlayOutcome.failed);
        expect(r.port.plays, 1);
        expect(
            r.state,
            const PreviewClipState(
                provider: 'itunes', phase: PreviewPhase.failed));
      });
    });

    test('a clip that breaks while playing fails and resumes the song', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.clip.breakDown();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 1);
        expect(r.state.phase, PreviewPhase.failed);
        expect(r.state.provider, 'deezer');
      });
    });

    test('only http(s) clips: anything else fails without a player', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer', 'file:///sdcard/Music/clip.mp3');
        r.play('itunes', 'content://media/external/audio/1');
        r.play('deezer', 'https:///no-host.mp3');
        async.flushMicrotasks();
        expect(r.outcomes, List.filled(3, PreviewPlayOutcome.failed));
        expect(r.clips, isEmpty);
        expect(r.port.touches, 0);
      });
    });
  });

  group('no song playing', () {
    test('nothing is paused or resumed', () {
      fakeAsync((async) {
        final r = _Rig(songPlaying: false);
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.port.pauses, 0);
        expect(r.clip.playing, isTrue);
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('Play on the lock screen still stops the clip', () {
      fakeAsync((async) {
        final r = _Rig(songPlaying: false);
        r.play('deezer');
        async.flushMicrotasks();
        r.port.userPlay();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0);
      });
    });
  });

  group('nothing playing', () {
    test('end() does nothing and touches nothing', () {
      fakeAsync((async) {
        final r = _Rig();
        for (final reason in PreviewEnd.values) {
          r.end(reason);
        }
        async.flushMicrotasks();
        expect(r.port.touches, 0);
        expect(r.clips, isEmpty);
        expect(r.log, isEmpty);
        expect(r.state, PreviewClipState.idle);
      });
    });

    test('the sheet closing frees the stopped clip; the next play makes one',
        () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.stopped);
        async.flushMicrotasks();
        final first = r.clip;
        expect(first.disposed, isFalse, reason: 'kept for a replay');

        r.end(PreviewEnd.sheetClosed);
        async.flushMicrotasks();
        expect(first.disposed, isTrue);
        expect(r.port.plays, 1, reason: 'the stop already resumed it');

        r.play('itunes');
        async.flushMicrotasks();
        expect(r.clips, hasLength(2));
        expect(r.clip.playing, isTrue);
      });
    });

    test('the sheet closing clears a failed state', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.loadError = Exception('gone');
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.failed);
        r.end(PreviewEnd.leftApp);
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.failed,
            reason: 'a link opening keeps the row as it was');
        r.end(PreviewEnd.sheetClosed);
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
      });
    });
  });

  group('the app player', () {
    // A sheet's dispose ends the preview even in a test that never set a
    // fake: the app's port must not reach MediaManager (never started in
    // tests: its handler is a late field) unless a clip actually loaded.
    test('ending with nothing playing reaches no singleton', () async {
      final previous = PreviewPlayer.instance;
      addTearDown(() => PreviewPlayer.instance = previous);
      PreviewPlayer.reset();
      expect(PreviewPlayer(), isNot(same(previous)));
      for (final reason in PreviewEnd.values) {
        await PreviewPlayer().end(reason);
      }
      expect(PreviewPlayer().state.value, PreviewClipState.idle);
    });

    test('FakePreviewPlayer.install() swaps it for this test only', () {
      final real = PreviewPlayer.instance;
      // Tear-downs run last-added first: this one sees install()'s restore.
      addTearDown(() => expect(PreviewPlayer.instance, same(real)));
      final fake = FakePreviewPlayer.install();
      expect(PreviewPlayer(), same(fake));
    });
  });
}
