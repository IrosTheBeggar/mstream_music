import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/local_playback_backend.dart';

// The iOS transcode fallback streams chunked with no length, and AVPlayer's
// "indefinite" duration lands in Dart as Duration.ZERO — which just_audio
// treats as a real duration and clamps every extrapolated position to, so the
// whole track "plays at 00:00" and the UI shows "/ 00:00". These pin the
// backend-boundary normalization: a zero duration means unknown (null), and
// while it reads zero the position uses just_audio's extrapolation formula
// WITHOUT the clamp.
void main() {
  group('normalizeReportedDuration', () {
    test('zero means unknown, not instant', () {
      expect(LocalPlaybackBackend.normalizeReportedDuration(Duration.zero),
          isNull);
    });

    test('null passes through', () {
      expect(LocalPlaybackBackend.normalizeReportedDuration(null), isNull);
    });

    test('a real duration passes through', () {
      const d = Duration(seconds: 74);
      expect(LocalPlaybackBackend.normalizeReportedDuration(d), d);
    });
  });

  group('unclampedPositionFor', () {
    final t0 = DateTime(2026, 1, 1, 12);

    test('holds the last event position while paused / not ready', () {
      expect(
          LocalPlaybackBackend.unclampedPositionFor(
              updatePosition: const Duration(seconds: 10),
              updateTime: t0,
              now: t0.add(const Duration(seconds: 30)),
              speed: 1.0,
              extrapolating: false),
          const Duration(seconds: 10));
    });

    test('advances in wall-clock time while playing — never clamped', () {
      // The regression: with playbackEvent.duration == zero, just_audio's own
      // getter would return zero here. 10s at the event + 4s of playback = 14s.
      expect(
          LocalPlaybackBackend.unclampedPositionFor(
              updatePosition: const Duration(seconds: 10),
              updateTime: t0,
              now: t0.add(const Duration(seconds: 4)),
              speed: 1.0,
              extrapolating: true),
          const Duration(seconds: 14));
    });

    test('scales elapsed wall-clock by the playback speed', () {
      expect(
          LocalPlaybackBackend.unclampedPositionFor(
              updatePosition: const Duration(seconds: 10),
              updateTime: t0,
              now: t0.add(const Duration(seconds: 4)),
              speed: 2.0,
              extrapolating: true),
          const Duration(seconds: 18));
    });
  });
}
