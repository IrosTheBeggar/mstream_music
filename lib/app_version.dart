/// Single source of truth for the user-facing version label.
///
/// Referenced by the About and Attributions screens. `release.sh` bumps
/// this constant alongside pubspec.yaml's `version:` line, so there is
/// exactly one place a version string can drift from.
const String kAppVersion = 'v0.23.0';
