import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kReleaseMode, visibleForTesting;

/// Whether this is the Google Play (compliant) build.
///
/// Set at build time with `--dart-define=VARIANT=play`, which CI pairs with the
/// `play` Gradle flavor (see .github/workflows/release.yml). It only gates the
/// download-storage UI — it hides the Permanent / SD-card modes that need
/// "All files access". Compliance does NOT depend on this flag: the
/// MANAGE_EXTERNAL_STORAGE permission is excluded from the `play` flavor's
/// merged manifest (it lives in android/app/src/full/AndroidManifest.xml), so a
/// play build is permission-clean even if this were misconfigured.
const String _variant = String.fromEnvironment('VARIANT', defaultValue: 'full');

const bool isPlayBuild = _variant == 'play';

/// `--dart-define=YTDL_ENTRY=true|false`, when the build set it at all.
const bool _ytdlEntryDefined = bool.hasEnvironment('YTDL_ENTRY');
const bool _ytdlEntryValue = bool.fromEnvironment('YTDL_ENTRY');

/// Whether this build shows Add from YouTube at all (spec DECISIONS 9; App
/// Store 5.2.3, Play policy on downloading from YouTube) — the home card
/// and the file explorer's entry both.
///
/// `--dart-define=YTDL_ENTRY=true|false` wins; otherwise off in the Play
/// bundle and in iOS release builds, on everywhere else (the full Android
/// build, debug and profile iOS builds, desktop).
bool get ytdlEntry => resolveYtdlEntry(
      defined: _ytdlEntryDefined ? _ytdlEntryValue : null,
      play: isPlayBuild,
      release: kReleaseMode,
      platform: defaultTargetPlatform,
    );

/// [ytdlEntry]'s rule with its inputs passed in, so each case is testable:
/// [defined] is the YTDL_ENTRY define (null = not set).
@visibleForTesting
bool resolveYtdlEntry({
  required bool? defined,
  required bool play,
  required bool release,
  required TargetPlatform platform,
}) {
  if (defined != null) return defined;
  if (play) return false;
  return !(release && platform == TargetPlatform.iOS);
}
