// Playback progress bar.
//
// Reported symptom: the progress bar gets stuck. This test exercises
// the real audio path with a tiny in-memory silent WAV and asserts the
// bar's value advances monotonically and stays in [0, 1] during real
// playback.
//
// Mechanism if you need to debug: the collapsed mini-player's
// WaveformProgress shows progress = position / duration. Position comes
// from _player.positionStream; duration is propagated to
// audio_service.mediaItem by the durationStream listener in
// AudioPlayerHandler._init (lib/media/audio_stuff.dart). If duration
// never reaches mediaItem, the formula falls back to position / 1,
// which grows unbounded — the bar visually pegs at 100% after one
// second.
//
// The expanded now-playing sheet stays in the tree (at opacity 0) while
// collapsed, so it carries its own play button + scrubber too. Every
// finder is scoped to the mini-player's Key('miniPlayer') so we read the
// collapsed bar, not the sheet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/widgets/waveform_progress.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mockServer;

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(resetAppState);

  tearDown(() async {
    await mockServer?.close();
    mockServer = null;
  });

  testWidgets(
    'mini-player progress bar advances during playback',
    (WidgetTester tester) async {
      // Long enough that playback is still running when the assertions
      // sample the bar — iOS's first AVPlayer spin-up plus the settle
      // waits below can eat ~5s before the first sample.
      final wavBytes = buildSilentWav(seconds: 30);

      mockServer = await MockServer.start(
        {
          '/api/v1/db/albums': (_) => {
                'albums': [
                  {
                    'name': 'Silent Album',
                    'year': 2026,
                    'album_art_file': null,
                  },
                ],
              },
          '/api/v1/db/album-songs': (_) => [
                {
                  'filepath': 'silent-album/silence.wav',
                  'metadata': {
                    'artist': 'Test Artist',
                    'album': 'Silent Album',
                    'title': 'Five Seconds of Silence',
                    'track': 1,
                    'disc': 1,
                    'year': 2026,
                    'hash': 'h-silence',
                    'rating': null,
                    'album-art': null,
                  },
                },
              ],
        },
        defaultHandler: (req) {
          if (req.uri.path.startsWith('/media/')) return wavBytes;
          return null;
        },
      );

      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(find.text('Silent Album'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Five Seconds of Silence'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tapping the first track from a fresh queue auto-plays it (the
      // addToQueue "first tap also starts playback" convenience in
      // browser.dart), so the mini-player usually shows pause already.
      // Press play only if it somehow came up paused.
      final playButton = find.descendant(
        of: find.byKey(const Key('miniPlayer')),
        matching: find.byIcon(Icons.play_arrow),
      );
      if (playButton.evaluate().isNotEmpty) {
        await tester.tap(playButton);
      }

      // Real-time pumping so just_audio's positionStream and
      // durationStream actually fire.
      await _pumpFor(tester, const Duration(seconds: 3));

      // Sanity: playback is running.
      expect(
        find.descendant(
          of: find.byKey(const Key('miniPlayer')),
          matching: find.byIcon(Icons.pause),
        ),
        findsOneWidget,
        reason: 'play button should flip to pause once playback starts',
      );

      // The duration must reach mediaItem for the progress bar formula
      // to work. If this assertion fails, the bar is "stuck" because
      // value = position / 1 grows past 1.0 and clamps visually at
      // 100%. Fix lives in AudioPlayerHandler._init's durationStream
      // listener at lib/media/audio_stuff.dart.
      final mediaItem =
          MediaManager().audioHandler.mediaItem.valueOrNull;
      expect(mediaItem, isNotNull);
      expect(
        mediaItem!.duration,
        isNotNull,
        reason:
            'mediaItem.duration is null even though playback is active. '
            'audio_stuff.dart\'s durationStream listener guards on '
            'index != null, but currentIndex can still be null when '
            'durationStream first fires for a freshly-added queue '
            'item. The listener needs to fall back to index 0 (or '
            'react to currentIndex changes too).',
      );

      // Sample the bar twice across ~2s of real playback.
      final v1 = _readMiniBarProgress(tester);
      await _pumpFor(tester, const Duration(seconds: 2));
      final v2 = _readMiniBarProgress(tester);

      expect(v2, greaterThan(v1),
          reason: 'progress should advance during playback (v1=$v1, '
              'v2=$v2)');
      expect(v2, greaterThan(0.0));
      expect(
        v2,
        lessThanOrEqualTo(1.0),
        reason:
            'progress should be a fraction in [0,1]. Values > 1 mean '
            'duration is missing from the formula — same root cause as '
            'the duration-null assertion above.',
      );
    },
  );
}

double _readMiniBarProgress(WidgetTester tester) {
  final bar = tester.widget<WaveformProgress>(
    find.descendant(
      of: find.byKey(const Key('miniPlayer')),
      matching: find.byType(WaveformProgress),
    ),
  );
  return bar.progress;
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  final ticks = total.inMilliseconds ~/ step.inMilliseconds;
  for (int i = 0; i < ticks; i++) {
    await tester.pump(step);
  }
}
