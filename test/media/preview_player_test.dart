// The preview player over a scripted song side and clip: the song is paused
// only once a clip has loaded and resumed exactly once, and only when this
// flow paused it and nobody touched it since. Every transport command, the
// song starting by itself, a track or cast change, a call, the output
// dropping, the app going to the background and a store link each end the
// clip or drop the resume the way the sheet promises.

import 'dart:async';

import 'package:audio_session/audio_session.dart' show AudioInterruptionType;
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBindingObserver;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/cast_target.dart';
import 'package:mstream_music/media/preview_player.dart';

import 'preview_fakes.dart';

/// A binding observer that runs [onHidden] each time the app is hidden, as
/// the Peer Recommendations page's does. Added before a watch starts, it is
/// told of a lifecycle change ahead of the watch's own listener.
class _OnHidden with WidgetsBindingObserver {
  _OnHidden(this.onHidden);
  final void Function() onHidden;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden) onHidden();
  }
}

class _Rig {
  _Rig({
    bool songPlaying = true,
    bool casting = false,
    String castTarget = CastTarget.localId,
    Duration loadTimeout = const Duration(seconds: 15),
    Duration heldTimeout = const Duration(seconds: 120),
  }) {
    port = FakePreviewPort(
        songPlaying: songPlaying,
        casting: casting,
        castTarget: castTarget,
        log: log);
    next = FakePreviewClip(log: log);
    player = PreviewPlayer.withPort(port,
        loadTimeout: loadTimeout, heldTimeout: heldTimeout, makeClip: () {
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

  /// A play that names its [owner] (a page, a sheet's rows), and may ask to
  /// hold the flow when its clip completes.
  void playAs(Object? owner, String provider,
      {String url = _clipUrl, bool hold = false}) {
    player
        .play(
            provider: provider,
            url: Uri.parse(url),
            owner: owner,
            holdOnComplete: hold)
        .then(outcomes.add);
  }

  void end(PreviewEnd reason, {Object? owner}) =>
      player.end(reason, owner: owner);

  /// What pause / resume answered, in order.
  final List<bool> answers = [];
  void pause({Object? owner}) => player.pause(owner: owner).then(answers.add);
  void resume({Object? owner}) =>
      player.resume(owner: owner).then(answers.add);
}

const String _clipUrl = 'https://cdn.example/30s.mp3';
const String _nextUrl = 'https://cdn.example/next.mp3';

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
        async.elapse(PreviewPlayer.castStartWindow);
        expect(r.clip.playing, isFalse);
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 0);
      });
    });

    test('the song starting by itself on the phone ends the clip at once', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.startsByItself();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0);
      });
    });

    // DLNA's 1 s poll (and a late Chromecast status) can say PLAYING just
    // after the flow's own pause took: a cast's flag back on is believed
    // only when it still says so once the window has passed.
    test('a cast flickering back to playing: the clip plays on, and the '
        'cast resumes after it', () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.port.playingNow, isFalse);

        r.port.startsByItself(); // a poll answered before Pause applied
        async.elapse(const Duration(milliseconds: 900));
        r.port.pausedByItself(); // the next poll: PAUSED
        async.elapse(PreviewPlayer.castStartWindow);
        expect(r.clip.playing, isTrue);
        expect(r.state.phase, PreviewPhase.playing);

        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 1);
      });
    });

    test('a cast that stays playing past the window: the song started', () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        r.play('deezer');
        async.flushMicrotasks();
        r.port.startsByItself(); // the TV's own remote
        async.elapse(
            PreviewPlayer.castStartWindow - const Duration(milliseconds: 100));
        expect(r.clip.playing, isTrue, reason: 'still inside the window');
        async.elapse(const Duration(milliseconds: 100));
        expect(r.clip.playing, isFalse);
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 0);
        expect(r.port.listeners, 0);
      });
    });

    test('Play pressed while casting ends the clip at once', () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        r.play('deezer');
        async.flushMicrotasks();
        r.port.userPlay();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0);
      });
    });
  });

  // PreviewPlayer.end decides from what the song is when the flow ends, not
  // when the hold was taken: each of these fails if one of resumesSong's
  // arguments is read from the hold (or the song taken as never playing),
  // or if a change the flow saw does not drop the hold.
  group('the end reads the song as it is then', () {
    test('a pause right after the clip ended: no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        // In this order: the pause is numbered after the end was asked,
        // before it read the song.
        r.clip.finish();
        r.port.userPause();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('the song already playing again as the clip ends: no second start',
        () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.clip.finish();
        r.port.startsByItself();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('a cast target changed and changed back: no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.changeCastTarget('tv-1');
        async.flushMicrotasks();
        r.port.changeCastTarget(CastTarget.localId, casting: false);
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('a track changed and changed back: no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.changeTrack('home\u0000/Music/Other.mp3');
        async.flushMicrotasks();
        r.port.changeTrack(kFakeSongKey);
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('a cast target change landing as the clip ends: no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.clip.finish();
        r.port.changeCastTarget('tv-1');
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test('a track change landing as the clip ends: no resume', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.clip.finish();
        r.port.changeTrack('home\u0000/Music/Other.mp3');
        async.flushMicrotasks();
        expect(r.port.plays, 0);
      });
    });

    test("a call's end alone ends nothing", () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.interruptionEnds();
        async.flushMicrotasks();
        expect(r.clip.playing, isTrue);
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

    // openOutside (elsewhere_sheet.dart): a link that will not open gives
    // the song back — the user never left.
    test('a link that did not open: the hold it handed back resumes the '
        'song once', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('itunes');
        async.flushMicrotasks();
        final held = r.player.endLeavingApp();
        async.flushMicrotasks();
        expect(held, isNotNull);
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0, reason: 'leaving the app keeps it paused');
        r.player.resumeHeld(held!);
        expect(r.port.plays, 1);
        expect(r.port.playingNow, isTrue);
        r.player.resumeHeld(held);
        expect(r.port.plays, 1, reason: 'playing already: once');
      });
    });

    test('…not once the song was touched, nor while a new clip plays; no '
        'hold without a paused song', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('itunes');
        async.flushMicrotasks();
        var held = r.player.endLeavingApp()!;
        r.port.userCommand('seek');
        r.player.resumeHeld(held);
        expect(r.port.plays, 0, reason: 'a transport command since');

        final s = _Rig();
        s.play('itunes');
        async.flushMicrotasks();
        held = s.player.endLeavingApp()!;
        async.flushMicrotasks();
        s.play('deezer');
        async.flushMicrotasks();
        s.player.resumeHeld(held);
        expect(s.port.plays, 0, reason: 'the new clip holds the song now');

        final idle = _Rig(songPlaying: false);
        idle.play('itunes');
        async.flushMicrotasks();
        expect(idle.player.endLeavingApp(), isNull);
        expect(_Rig().player.endLeavingApp(), isNull, reason: 'no flow');
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

    test('a call while casting: the clip stops and the cast stays paused', () {
      fakeAsync((async) {
        final r = _Rig(castTarget: 'tv-1', casting: true);
        r.play('deezer');
        async.flushMicrotasks();
        r.port.interrupt();
        async.flushMicrotasks();
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0, reason: 'on purpose: see resumesSong');
      });
    });
  });

  // Watched from the start of a play, not once the clip has loaded: what
  // happens while it loads ends the flow before anything sounds — the song
  // never paused, no clip from the speaker.
  group('the outside world while the clip loads', () {
    final cases = <String, void Function(_Rig r)>{
      'the app goes to the background': (r) => r.port.hideApp(),
      // The handler pauses the song for it too.
      'the headphones come out': (r) => r
        ..port.becomeNoisy()
        ..port.userPause(),
      'a call': (r) => r.port.interrupt(),
      'a store link opens': (r) => r.end(PreviewEnd.leftApp),
    };
    for (final MapEntry(key: what, value: happen) in cases.entries) {
      test('$what: nothing plays, the song is never paused', () {
        fakeAsync((async) {
          final r = _Rig();
          r.next.holdLoads = true;
          r.play('deezer');
          async.flushMicrotasks();
          happen(r);
          async.flushMicrotasks();
          expect(r.state, PreviewClipState.idle, reason: what);
          expect(r.clip.pendingLoads, 0, reason: 'the end abandoned it');
          expect(r.outcomes, [PreviewPlayOutcome.superseded], reason: what);
          expect(r.port.pauses, 0, reason: what);
          expect(r.port.plays, 0, reason: what);
          expect(r.clip.playCalls, 0, reason: what);
          expect(r.port.listeners, 0, reason: what);
        });
      });
    }

    test('a duck while it loads changes nothing', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.holdLoads = true;
        r.play('deezer');
        async.flushMicrotasks();
        r.port.interrupt(AudioInterruptionType.duck);
        async.flushMicrotasks();
        r.clip.finishLoad();
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.playing]);
        expect(r.clip.playing, isTrue);
      });
    });

    test('the user pausing the song while it loads: the clip still plays',
        () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.holdLoads = true;
        r.play('deezer');
        async.flushMicrotasks();
        r.port.userPause();
        async.flushMicrotasks();
        r.clip.finishLoad();
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.playing]);
        expect(r.clip.playing, isTrue);
        expect(r.port.pauses, 0, reason: 'nothing left to pause');
      });
    });

    test('already in the background: no clip is made, nothing plays', () {
      fakeAsync((async) {
        final r = _Rig();
        r.port.visible = false;
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.superseded]);
        expect(r.clips, isEmpty);
        expect(r.port.pauses, 0);
        expect(r.state, PreviewClipState.idle);
        expect(r.port.listeners, 0);
      });
    });

    test('in the background once it loaded (no hide was heard): nothing '
        'plays', () {
      fakeAsync((async) {
        final r = _Rig();
        r.next.holdLoads = true;
        r.play('deezer');
        async.flushMicrotasks();
        r.port.visible = false;
        r.clip.finishLoad();
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.superseded]);
        expect(r.port.pauses, 0);
        expect(r.clip.playCalls, 0);
      });
    });

    test('a switch in the background resumes the song the first clip '
        'paused', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.port.visible = false;
        r.play('itunes');
        async.flushMicrotasks();
        expect(r.outcomes.last, PreviewPlayOutcome.superseded);
        expect(r.port.plays, 1);
        expect(r.clip.playing, isFalse);
      });
    });

    test('endCount: every end asked for, a flow or none, but a clip\'s own',
        () {
      fakeAsync((async) {
        final r = _Rig();
        r.end(PreviewEnd.leftApp); // nothing playing
        async.flushMicrotasks();
        expect(r.player.endCount, 1);

        r.play('deezer');
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.player.endCount, 1, reason: 'it completed');

        r.clip.loadError = Exception('gone');
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.outcomes.last, PreviewPlayOutcome.failed);
        expect(r.player.endCount, 1, reason: 'it failed');

        r.play('deezer');
        async.flushMicrotasks();
        r.port.hideApp();
        async.flushMicrotasks();
        expect(r.player.endCount, 2);
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
        expect(r.port.listeners, 0,
            reason: 'the switch did not leave a second watch');
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
        expect(r.port.listeners, 0);
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

    test('a clip the system will not play (Android: no audio focus, no '
        'error): it fails and the song resumes', () {
      fakeAsync((async) {
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.playing);
        r.clip.refuse();
        async.flushMicrotasks();
        expect(r.state,
            const PreviewClipState(provider: 'deezer', phase: PreviewPhase.failed));
        expect(r.port.plays, 1);
        expect(r.port.listeners, 0);
      });
    });

    test('a clip whose play throws (iOS: the session would not activate) '
        'fails', () {
      fakeAsync((async) {
        final r = _Rig(songPlaying: false);
        r.next.playError = Exception('session activation failed');
        r.play('itunes');
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.playing]);
        expect(r.state,
            const PreviewClipState(provider: 'itunes', phase: PreviewPhase.failed));
        expect(r.port.plays, 0, reason: 'nothing was held');
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
        expect(r.port.outsideTouches, 0);
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

  // Several surfaces share the one player (mStream plan §2 item 15): each
  // play names its owner, and an end naming one ends only that owner's
  // flow — a sheet closing over the Peer Recommendations page's clip
  // leaves it playing, and silences nobody's lookup.
  group('owners', () {
    test('an end from another owner leaves the flow playing and is not '
        'counted', () {
      fakeAsync((async) {
        final r = _Rig();
        final page = Object(), sheet = Object();
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.sheetClosed, owner: sheet);
        r.end(PreviewEnd.stopped, owner: sheet);
        async.flushMicrotasks();
        expect(r.player.endCount, 0);
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.state.owner, same(page));
        expect(r.clip.playing, isTrue);
        expect(r.clip.disposed, isFalse, reason: 'the page still plays on it');
        expect(r.port.plays, 0);

        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.player.endCount, 1);
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);
      });
    });

    test('an owner-carrying end with no live flow is not counted; '
        'sheetClosed still frees the clip player', () {
      fakeAsync((async) {
        final r = _Rig();
        final page = Object(), sheet = Object();
        r.end(PreviewEnd.sheetClosed, owner: sheet); // nothing ever played
        async.flushMicrotasks();
        expect(r.player.endCount, 0);
        expect(r.port.touches, 0);

        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.player.endCount, 1);
        expect(r.port.plays, 1);
        final first = r.clip;
        expect(first.disposed, isFalse);

        r.end(PreviewEnd.stopped, owner: sheet);
        r.end(PreviewEnd.sheetClosed, owner: sheet);
        async.flushMicrotasks();
        expect(r.player.endCount, 1, reason: "no flow of anybody's ended");
        expect(first.disposed, isTrue);
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);
      });
    });

    test('an end with no owner ends any flow (a link, the app hidden)', () {
      fakeAsync((async) {
        final r = _Rig();
        final page = Object();
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.leftApp);
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.clip.playing, isFalse);
        expect(r.port.plays, 0, reason: 'leaving the app keeps it paused');
        expect(r.player.endCount, 1);

        final s = _Rig();
        s.playAs(page, 'deezer');
        async.flushMicrotasks();
        s.port.hideApp();
        async.flushMicrotasks();
        expect(s.state, PreviewClipState.idle);
        expect(s.clip.playing, isFalse);
        expect(s.port.plays, 1);
        expect(s.player.endCount, 1);
      });
    });

    test('a null owner on either side matches', () {
      fakeAsync((async) {
        final page = Object();
        // A play that named nobody is anybody's.
        final r = _Rig();
        r.play('deezer');
        async.flushMicrotasks();
        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.player.endCount, 1);
        expect(r.port.plays, 1);

        // An owner's flow takes a pause, a resume and a keepHeld that name
        // nobody.
        final s = _Rig();
        s.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        s.pause();
        async.flushMicrotasks();
        expect(s.state.phase, PreviewPhase.paused);
        s.resume();
        async.flushMicrotasks();
        expect(s.state.phase, PreviewPhase.playing);
        expect(s.answers, [true, true]);
        s.clip.finish();
        async.flushMicrotasks();
        expect(s.state.phase, PreviewPhase.held);
        async.elapse(const Duration(seconds: 100));
        s.player.keepHeld();
        async.elapse(const Duration(seconds: 100));
        expect(s.state.phase, PreviewPhase.held, reason: 're-armed at 100 s');
        s.end(PreviewEnd.completed);
        async.flushMicrotasks();
        expect(s.state, PreviewClipState.idle);
        expect(s.port.plays, 1);
      });
    });

    test('the owner rides on loading, playing, position, duration and '
        'failed states', () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.next.holdLoads = true;
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.loading, owner: page));
        r.clip.finishLoad();
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.playing, owner: page));
        r.clip.emitDuration(const Duration(seconds: 30));
        r.clip.emitPosition(const Duration(seconds: 12));
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer',
                phase: PreviewPhase.playing,
                position: const Duration(seconds: 12),
                duration: const Duration(seconds: 30),
                owner: page));
        r.clip.breakDown();
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.failed, owner: page));

        // A load that fails, and a clip with no http(s) address.
        r.clip.loadError = Exception('gone');
        r.playAs(page, 'itunes');
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'itunes', phase: PreviewPhase.failed, owner: page));
        r.playAs(page, 'deezer', url: 'file:///sdcard/clip.mp3');
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.failed, owner: page));

        // Nobody's once it is over; the owner is part of the state.
        r.end(PreviewEnd.sheetClosed);
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(PreviewClipState.idle.owner, isNull);
        PreviewClipState owned() => PreviewClipState(
            provider: 'deezer', phase: PreviewPhase.playing, owner: page);
        expect(owned(),
            isNot(const PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.playing)));
        expect(owned(), owned());
        expect(owned().hashCode, owned().hashCode);
        expect(owned().toString(), contains('Object'));
      });
    });

    test("a switch to another owner keeps the song paused; only the new "
        "owner's end resumes it", () {
      fakeAsync((async) {
        final page = Object(), sheet = Object();
        final r = _Rig();
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        expect(r.port.pauses, 1);
        r.playAs(sheet, 'deezer', url: _nextUrl);
        async.flushMicrotasks();
        expect(r.outcomes,
            [PreviewPlayOutcome.playing, PreviewPlayOutcome.playing]);
        expect(r.state.owner, same(sheet));
        expect(r.port.pauses, 1);
        expect(r.port.plays, 0, reason: 'the song stays paused in between');

        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.playing,
            reason: "no longer the page's");
        expect(r.port.plays, 0);
        expect(r.player.endCount, 0);

        r.end(PreviewEnd.sheetClosed, owner: sheet);
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);
      });
    });
  });

  // Peer Recommendations' band: ⏸ keeps the session (plan PH4's "pause
  // keeps the session").
  group('pause and resume', () {
    test('pause keeps the session: no refused-audio failure, song stays '
        'paused, resume plays on, stop resumes the song once', () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.clip.emitDuration(const Duration(seconds: 30));
        r.clip.emitPosition(const Duration(seconds: 12));
        async.flushMicrotasks();
        r.pause(owner: page);
        async.flushMicrotasks();
        expect(r.answers, [true]);
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer',
                phase: PreviewPhase.paused,
                position: const Duration(seconds: 12),
                duration: const Duration(seconds: 30),
                owner: page));
        expect(r.clip.pauses, 1);
        expect(r.clip.playing, isFalse);
        r.clip.emitPosition(const Duration(seconds: 20));
        async.elapse(const Duration(minutes: 5));
        expect(r.state.phase, PreviewPhase.paused,
            reason: 'no refused-audio failure, no timeout');
        expect(r.state.position, const Duration(seconds: 12));
        expect(r.port.playingNow, isFalse);
        expect(r.port.plays, 0);
        expect(r.port.listeners, greaterThan(0),
            reason: 'the flow still watches the song');

        r.resume(owner: page);
        async.flushMicrotasks();
        expect(r.answers, [true, true]);
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.state.position, const Duration(seconds: 12));
        expect(r.clip.playing, isTrue);
        expect(r.clip.playCalls, 2);
        r.clip.emitPosition(const Duration(seconds: 13));
        async.elapse(const Duration(seconds: 1));
        expect(r.state.position, const Duration(seconds: 13),
            reason: 'watched afresh');
        expect(r.state.phase, PreviewPhase.playing);

        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.port.pauses, 1);
        expect(r.port.plays, 1);
        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.port.plays, 1);
      });
    });

    test('pause and resume refuse another owner and a non-playing phase; '
        'resume refuses while hidden', () {
      fakeAsync((async) {
        final page = Object(), sheet = Object();
        final r = _Rig();
        r.pause(owner: page); // no flow
        r.resume(owner: page);
        async.flushMicrotasks();
        expect(r.answers, [false, false]);
        expect(r.port.touches, 0);

        r.next.holdLoads = true;
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.pause(owner: page); // still loading
        async.flushMicrotasks();
        expect(r.answers.last, isFalse);
        expect(r.state.phase, PreviewPhase.loading);
        r.clip.finishLoad();
        async.flushMicrotasks();

        r.resume(owner: page); // playing, not paused
        r.pause(owner: sheet);
        async.flushMicrotasks();
        expect(r.answers.sublist(3), [false, false]);
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.clip.pauses, 0);

        r.pause(owner: page);
        async.flushMicrotasks();
        r.pause(owner: page); // paused already
        r.resume(owner: sheet);
        async.flushMicrotasks();
        expect(r.answers.sublist(5), [true, false, false]);
        expect(r.state.phase, PreviewPhase.paused);
        expect(r.clip.pauses, 1);

        r.port.visible = false; // in the background, no hide heard yet
        r.resume(owner: page);
        async.flushMicrotasks();
        expect(r.answers.last, isFalse);
        expect(r.state.phase, PreviewPhase.paused);
        expect(r.clip.playing, isFalse);

        r.port.visible = true;
        r.resume(owner: page);
        async.flushMicrotasks();
        expect(r.answers.last, isTrue);
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.clip.playing, isTrue);
      });
    });

    // The pause's playing=false reaches the clip's watch a turn later: one
    // still on its way when resume says playing again would read as the
    // system refusing the audio, but for the watch made afresh.
    test('pause then resume back-to-back with no flush between: no '
        'refused-audio failure, the clip plays on', () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.pause(owner: page);
        r.resume(owner: page);
        async.flushMicrotasks();
        expect(r.answers, [true, true]);
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.clip.playing, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.port.plays, 0);

        // The fresh watch still tells a refusal.
        r.clip.refuse();
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.failed);
        expect(r.port.plays, 1);
      });
    });

    test('lock-screen Play while paused ends with songStarted and nothing '
        'resumes', () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.pause(owner: page);
        async.flushMicrotasks();
        r.port.userPlay();
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 0);
        expect(r.port.playingNow, isTrue);
        expect(r.port.listeners, 0);
        expect(r.player.endCount, 1);

        r.resume(owner: page);
        async.flushMicrotasks();
        expect(r.answers, [true, false]);
        expect(r.clip.playing, isFalse);
      });
    });
  });

  // Preview all: from the first clip to the last, the song stays paused
  // (plan PH4's "a chain keeps the first flag").
  group('hold on complete', () {
    test('holdOnComplete: a completed clip holds the flow (phase held), the '
        'song stays paused, the next play switches, the final end resumes '
        'once — a chain keeps the first flag', () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        expect(r.port.pauses, 1);
        r.clip.finish();
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.held, owner: page));
        expect(r.port.plays, 0);
        expect(r.port.playingNow, isFalse);
        expect(r.clip.playing, isFalse, reason: 'stopped quietly');
        expect(r.port.listeners, greaterThan(0),
            reason: 'the flow still watches the song');
        expect(r.player.endCount, 0);

        r.playAs(page, 'deezer', url: _nextUrl, hold: true);
        async.flushMicrotasks();
        expect(r.outcomes,
            [PreviewPlayOutcome.playing, PreviewPlayOutcome.playing]);
        expect(r.port.pauses, 1, reason: 'the first pause still holds');
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.clip.loads.last.toString(), _nextUrl);
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.held);
        expect(r.port.plays, 0);

        r.end(PreviewEnd.completed, owner: page);
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);
        expect(r.port.listeners, 0);
        async.elapse(const Duration(minutes: 5));
        expect(r.port.plays, 1, reason: 'the held guard went with the flow');
      });
    });

    test('without holdOnComplete a completion ends and resumes (unchanged)',
        () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.playAs(page, 'deezer');
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);

        // A chain's last clip asks no hold.
        r.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        r.playAs(page, 'itunes', url: _nextUrl);
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.port.pauses, 2);
        expect(r.port.plays, 2);
        expect(r.player.endCount, 0, reason: 'each completed');
      });
    });

    test('a held flow times out to completed and resumes', () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        async.elapse(r.player.heldTimeout - const Duration(seconds: 1));
        expect(r.state.phase, PreviewPhase.held);
        expect(r.port.plays, 0);
        async.elapse(const Duration(seconds: 1));
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);
        expect(r.player.endCount, 0, reason: 'a completion');
        expect(r.port.listeners, 0);
      });
    });

    test('a held flow still ends as any flow does: Play on the lock screen, '
        'no resume', () {
      fakeAsync((async) {
        final page = Object();
        final r = _Rig();
        r.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        r.port.userPlay();
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 0);
        async.elapse(const Duration(minutes: 5));
        expect(r.port.plays, 0);
      });
    });

    test("keepHeld re-arms the timeout; another owner's keepHeld and a "
        'non-held phase do nothing', () {
      fakeAsync((async) {
        final page = Object(), sheet = Object();
        // Its owner's: another heldTimeout from then.
        final r = _Rig();
        r.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        r.clip.finish();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 100));
        r.player.keepHeld(owner: page);
        async.elapse(const Duration(seconds: 119));
        expect(r.state.phase, PreviewPhase.held);
        async.elapse(const Duration(seconds: 1));
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);

        // Another owner's leaves the guard where it was.
        final s = _Rig();
        s.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        s.clip.finish();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 100));
        s.player.keepHeld(owner: sheet);
        async.elapse(const Duration(seconds: 20));
        expect(s.state, PreviewClipState.idle);
        expect(s.port.plays, 1);

        // With no flow, or while it plays, it arms nothing.
        final t = _Rig();
        t.player.keepHeld(owner: page);
        t.playAs(page, 'deezer', hold: true);
        async.flushMicrotasks();
        t.player.keepHeld(owner: page);
        async.elapse(const Duration(minutes: 5));
        expect(t.state.phase, PreviewPhase.playing);
        expect(t.port.plays, 0);
      });
    });
  });

  // A page press made while a sheet's clip still runs (the sheet animating
  // closed) takes the flow over before its own clip is known.
  group('claim', () {
    test('no flow: false, and nothing is touched', () {
      fakeAsync((async) {
        final r = _Rig();
        expect(r.player.claim(owner: Object()), isFalse);
        async.flushMicrotasks();
        expect(r.state, PreviewClipState.idle);
        expect(r.port.touches, 0);
        expect(r.clips, isEmpty);
      });
    });

    test("another owner's playing clip: held for the claimant, the song "
        "kept paused; the old owner's end does nothing and is not counted; "
        'the next play is a switch; the end resumes once', () {
      fakeAsync((async) {
        final page = Object(), sheet = Object();
        final r = _Rig();
        r.playAs(sheet, 'deezer');
        async.flushMicrotasks();
        expect(r.port.pauses, 1);

        expect(r.player.claim(owner: page), isTrue);
        async.flushMicrotasks();
        expect(
            r.state,
            PreviewClipState(
                provider: 'deezer', phase: PreviewPhase.held, owner: page));
        expect(r.clip.playing, isFalse, reason: 'its clip stopped at once');
        expect(r.port.plays, 0, reason: 'the song stays paused');

        // Its position ticks no longer reach the state.
        r.clip.emitPosition(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.held);
        expect(r.state.owner, same(page));

        // The sheet closes.
        r.end(PreviewEnd.sheetClosed, owner: sheet);
        async.flushMicrotasks();
        expect(r.player.endCount, 0);
        expect(r.state.owner, same(page));
        expect(r.clip.disposed, isFalse, reason: "the page's clip player");
        expect(r.port.plays, 0);

        r.playAs(page, 'deezer', url: _nextUrl);
        async.flushMicrotasks();
        expect(r.outcomes.last, PreviewPlayOutcome.playing);
        expect(r.state.phase, PreviewPhase.playing);
        expect(r.state.owner, same(page));
        expect(r.clip.loads.last.toString(), _nextUrl);
        expect(r.port.pauses, 1, reason: "the sheet's pause still holds");
        expect(r.port.plays, 0);

        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.port.plays, 1);
        expect(r.player.endCount, 1);
      });
    });

    test('a clip still loading: its play is superseded and the song never '
        "paused; the claimant's own play pauses it once", () {
      fakeAsync((async) {
        final page = Object(), sheet = Object();
        final r = _Rig();
        r.next.holdLoads = true;
        r.playAs(sheet, 'itunes');
        async.flushMicrotasks();
        expect(r.state.phase, PreviewPhase.loading);

        expect(r.player.claim(owner: page), isTrue);
        async.flushMicrotasks();
        expect(r.outcomes, [PreviewPlayOutcome.superseded]);
        expect(r.state.phase, PreviewPhase.held);
        expect(r.port.pauses, 0);

        r.end(PreviewEnd.sheetClosed, owner: sheet);
        r.clip.holdLoads = false;
        r.playAs(page, 'deezer', url: _nextUrl);
        async.flushMicrotasks();
        expect(r.outcomes.last, PreviewPlayOutcome.playing);
        expect(r.port.pauses, 1);
        r.end(PreviewEnd.stopped, owner: page);
        async.flushMicrotasks();
        expect(r.port.plays, 1);
      });
    });

    test('a claimed flow is held: keepHeld re-arms it, it times out to a '
        "completion; its owner's own flow is left as it is", () {
      fakeAsync((async) {
        final page = Object(), sheet = Object();
        final r = _Rig();
        r.playAs(sheet, 'deezer');
        async.flushMicrotasks();
        r.player.claim(owner: page);
        async.elapse(const Duration(seconds: 100));
        r.player.keepHeld(owner: page);
        async.elapse(const Duration(seconds: 119));
        expect(r.state.phase, PreviewPhase.held);
        async.elapse(const Duration(seconds: 1));
        expect(r.state, PreviewClipState.idle);
        expect(r.port.plays, 1);

        final s = _Rig();
        s.playAs(page, 'deezer');
        async.flushMicrotasks();
        expect(s.player.claim(owner: page), isTrue);
        async.flushMicrotasks();
        expect(s.state.phase, PreviewPhase.playing);
        expect(s.clip.playing, isTrue);
      });
    });
  });

  group('songStarts', () {
    test('a Play command after it is listened to, and the flag going on '
        'while not casting; nothing before; cancelling lets go', () {
      fakeAsync((async) {
        final r = _Rig(songPlaying: false);
        r.port.userCommand('play'); // before anyone listens
        var starts = 0;
        final sub = r.player.songStarts.listen((_) => starts++);
        async.flushMicrotasks();
        expect(starts, 0, reason: 'older than the watch, and a replay');

        r.port.userPlay();
        async.flushMicrotasks();
        expect(starts, 2, reason: 'the command and the edge');
        r.port.userPause();
        r.port.userCommand('seek');
        async.flushMicrotasks();
        expect(starts, 2);
        r.port.startsByItself();
        async.flushMicrotasks();
        expect(starts, 3);

        // Casting: the flag alone is not believed; a Play still is.
        r.port.casting = true;
        r.port.pausedByItself();
        r.port.startsByItself();
        async.flushMicrotasks();
        expect(starts, 3);
        r.port.userCommand('play');
        async.flushMicrotasks();
        expect(starts, 4);

        sub.cancel();
        async.flushMicrotasks();
        expect(r.port.listeners, 0);
        r.port.userPlay();
        async.flushMicrotasks();
        expect(starts, 4);
      });
    });
  });

  // Other pieces' widget tests stand on the fake: it keeps the real
  // player's owner rules, read from the state alone.
  group('FakePreviewPlayer', () {
    test('owners, counts and phases as the real player keeps them', () async {
      final fake = FakePreviewPlayer.install();
      final page = Object(), sheet = Object();
      // A state a test emits counts like one a play published.
      fake.emit(PreviewClipState(
          provider: 'deezer', phase: PreviewPhase.playing, owner: page));
      await fake.end(PreviewEnd.sheetClosed, owner: sheet);
      expect(fake.ends, isEmpty);
      expect(fake.endCount, 0);
      expect(fake.endCalls.single, (reason: PreviewEnd.sheetClosed, owner: sheet));
      expect(fake.state.value.owner, same(page));

      expect(await fake.pause(owner: sheet), isFalse);
      expect(await fake.pause(owner: page), isTrue);
      expect(fake.state.value.phase, PreviewPhase.paused);
      fake.appVisible = false;
      expect(await fake.resume(owner: page), isFalse);
      fake.appVisible = true;
      expect(await fake.resume(), isTrue);
      expect([fake.pauses, fake.resumes], [1, 1]);

      await fake.end(PreviewEnd.stopped, owner: page);
      expect(fake.ends, [PreviewEnd.stopped]);
      expect(fake.endCount, 1);
      expect(fake.state.value, PreviewClipState.idle);
      // Nothing live: it runs, uncounted.
      await fake.end(PreviewEnd.sheetClosed, owner: sheet);
      expect(fake.ends, [PreviewEnd.stopped, PreviewEnd.sheetClosed]);
      expect(fake.endCount, 1);
      await fake.end(PreviewEnd.leftApp);
      expect(fake.endCount, 2);

      // Held on completion when the play asked it; else completed.
      await fake.play(
          provider: 'deezer',
          url: Uri.parse(_clipUrl),
          owner: page,
          holdOnComplete: true);
      expect(fake.plays.last.owner, same(page));
      expect(fake.plays.last.holdOnComplete, isTrue);
      fake.keepHeld(owner: page);
      expect(fake.keepHelds, 0, reason: 'not held yet');
      await fake.complete();
      expect(
          fake.state.value,
          PreviewClipState(
              provider: 'deezer', phase: PreviewPhase.held, owner: page));
      fake.keepHeld(owner: sheet);
      fake.keepHeld(owner: page);
      expect(fake.keepHelds, 1);
      await fake.play(provider: 'itunes', url: Uri.parse(_nextUrl), owner: page);
      await fake.complete();
      expect(fake.ends.last, PreviewEnd.completed);
      expect(fake.state.value, PreviewClipState.idle);
      expect(fake.endCount, 2);
      expect(fake.heldTimeout, const Duration(seconds: 120));
    });

    test('claim and the song watch as the real player keeps them', () async {
      final fake = FakePreviewPlayer.install();
      final page = Object(), sheet = Object();
      expect(fake.claim(owner: page), isFalse);
      expect(fake.claims, isEmpty);

      fake.emit(PreviewClipState(
          provider: 'itunes', phase: PreviewPhase.playing, owner: sheet));
      expect(fake.claim(owner: page), isTrue);
      expect(fake.claims, [page]);
      expect(
          fake.state.value,
          PreviewClipState(
              provider: 'itunes', phase: PreviewPhase.held, owner: page));
      await fake.end(PreviewEnd.sheetClosed, owner: sheet);
      expect(fake.ends, isEmpty);
      expect(fake.endCount, 0);
      expect(fake.claim(owner: page), isTrue);
      expect(fake.claims, [page], reason: 'already its own');

      expect(fake.songPlaying, isTrue);
      fake.songPlaying = false;
      final starts = <void>[];
      final sub = fake.songStarts.listen(starts.add);
      expect(fake.watchingSong, isTrue);
      fake.startSong();
      await Future<void>.delayed(Duration.zero);
      expect(starts, hasLength(1));
      expect(fake.songPlaying, isTrue);
      await sub.cancel();
      expect(fake.watchingSong, isFalse);
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

    // just_audio makes a position pipeline (and its timer) per positionStream
    // asked for once the last listener left, and stops none of them before
    // the player's dispose: every clip played in one sheet would add one.
    test('the just_audio clip keeps one position stream for its player',
        () async {
      final clip = JustAudioPreviewClip();
      final first = clip.position;
      await first.listen((_) {}).cancel();
      expect(clip.position, first);
    });

    test('FakePreviewPlayer.install() swaps it for this test only', () {
      final real = PreviewPlayer.instance;
      // Tear-downs run last-added first: this one sees install()'s restore.
      addTearDown(() => expect(PreviewPlayer.instance, same(real)));
      final fake = FakePreviewPlayer.install();
      expect(PreviewPlayer(), same(fake));
    });
  });

  // The app port's appHidden makes an AppLifecycleListener per watch, a
  // binding observer like any other. The binding tells a lifecycle change
  // to a copy of its observer list, and iOS's one "paused" is told as
  // inactive, hidden and paused in one go. A watch ended while the binding
  // tells of it (the Peer Recommendations page ending its clip as the app
  // is hidden) must not leave the binding calling a disposed listener: in
  // a debug build that throws "A AppLifecycleListener was used after being
  // disposed" (round 3's W1).
  group("the app port's lifecycle watch", () {
    PreviewPlayer appPlayer(WidgetTester tester, BindingPreviewPort port) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final clip = FakePreviewClip();
      return PreviewPlayer.withPort(port, makeClip: () => clip);
    }

    Future<void> playAs(
        WidgetTester tester, PreviewPlayer player, Object owner) async {
      unawaited(player.play(
          provider: 'deezer', url: Uri.parse(_clipUrl), owner: owner));
      await tester.pump();
      expect(player.state.value.phase, PreviewPhase.playing);
    }

    testWidgets('a binding observer told ahead of the watch cancels it as '
        'the app is hidden: the binding never calls a disposed listener, '
        'and nothing is heard', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      late StreamSubscription<void> watch;
      var cancels = 0;
      final ahead = _OnHidden(() {
        cancels++;
        unawaited(watch.cancel());
      });
      tester.binding.addObserver(ahead);
      addTearDown(() => tester.binding.removeObserver(ahead));
      var heard = 0;
      watch = AppPreviewPort().appHidden.listen((_) => heard++);

      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(cancels, 1);
      expect(heard, 0, reason: 'cancelled before its listener was told');

      foregroundApp(tester);
      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(heard, 0);
      foregroundApp(tester);
    });

    testWidgets("an observer told ahead of the watch ends the flow as the "
        'app is hidden (the Peer Recommendations page): it ends once, '
        'backgrounded, and the binding never calls a disposed listener', (
      tester,
    ) async {
      final port = BindingPreviewPort();
      final player = appPlayer(tester, port);
      final page = Object();
      final ahead = _OnHidden(
          () => unawaited(player.end(PreviewEnd.backgrounded, owner: page)));
      tester.binding.addObserver(ahead);
      addTearDown(() => tester.binding.removeObserver(ahead));
      final ends = player.endCount;
      await playAs(tester, player, page);

      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(player.state.value, PreviewClipState.idle);
      expect(player.endCount, ends + 1,
          reason: "the watch's own hide, told after the end, adds none");
      expect(port.listeners, 0);

      // Back in front, a new clip is watched afresh.
      foregroundApp(tester);
      await playAs(tester, player, page);
      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(player.state.value, PreviewClipState.idle);
      expect(player.endCount, ends + 2);
      foregroundApp(tester);
      await player.end(PreviewEnd.sheetClosed);
    });

    testWidgets("the watch's own listener ends a sheet's clip as the app is "
        'hidden (no other observer; the #237 sheet): it ends once, '
        'backgrounded, the song back, and a clip after the return is '
        'watched afresh', (tester) async {
      final port = BindingPreviewPort();
      final player = appPlayer(tester, port);
      final sheet = Object();
      final ends = player.endCount;
      await playAs(tester, player, sheet);
      expect(port.pauses, 1);

      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(player.state.value, PreviewClipState.idle);
      expect(player.endCount, ends + 1);
      expect(port.plays, 1, reason: 'backgrounded brings the song back');
      expect(port.listeners, 0);

      foregroundApp(tester);
      await playAs(tester, player, sheet);
      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(player.state.value, PreviewClipState.idle);
      expect(player.endCount, ends + 2);
      foregroundApp(tester);
      await player.end(PreviewEnd.sheetClosed);
    });
  });
}
