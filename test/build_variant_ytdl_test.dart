// Which builds show Add from YouTube at all (spec DECISIONS 9; App Store
// 5.2.3, Play policy): an explicit --dart-define=YTDL_ENTRY always wins;
// without it the Play bundle and iOS release builds hide it, and every
// other build — the full Android flavour, debug and profile iOS, desktop —
// shows it. The test run itself sets no define and is not the Play bundle.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/build_variant.dart';

void main() {
  bool entry(
          {bool? defined,
          bool play = false,
          bool release = false,
          TargetPlatform platform = TargetPlatform.android}) =>
      resolveYtdlEntry(
          defined: defined, play: play, release: release, platform: platform);

  test('no define: off in the Play bundle, whatever the platform or mode', () {
    for (final platform in TargetPlatform.values) {
      for (final release in [false, true]) {
        expect(entry(play: true, release: release, platform: platform), isFalse,
            reason: '$platform release=$release');
      }
    }
  });

  test('no define: off in an iOS release build only', () {
    expect(entry(release: true, platform: TargetPlatform.iOS), isFalse);
    expect(entry(release: false, platform: TargetPlatform.iOS), isTrue,
        reason: 'debug and profile builds keep it for development');
    expect(entry(release: true, platform: TargetPlatform.android), isTrue,
        reason: 'the full (sideload / F-Droid) flavour');
    expect(entry(release: true, platform: TargetPlatform.macOS), isTrue);
  });

  test('YTDL_ENTRY set explicitly always wins', () {
    expect(entry(defined: true, play: true, release: true), isTrue);
    expect(entry(defined: true, release: true, platform: TargetPlatform.iOS),
        isTrue, reason: 'a TestFlight build made to try it');
    expect(entry(defined: false), isFalse);
    expect(entry(defined: false, platform: TargetPlatform.macOS), isFalse);
  });

  test('this test run (no define, debug, not Play) shows it', () {
    expect(isPlayBuild, isFalse);
    expect(ytdlEntry, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(ytdlEntry, isTrue, reason: 'iOS, but not a release build');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
