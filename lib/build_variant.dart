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
