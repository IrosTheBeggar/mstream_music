/// A language's name in its own language. Intentionally NOT translated —
/// users recognize their language by its endonym. Keyed by language code;
/// pickers are built from AppLocalizations.supportedLocales so they
/// auto-grow as ARB files are added, falling back to the raw code for a
/// locale that isn't listed here yet.
///
/// Shared by Settings → Language and the first-run no-server screen.
const Map<String, String> kLanguageEndonyms = {
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt': 'Português',
  'zh': '中文',
  'ru': 'Русский',
  'it': 'Italiano',
  'pl': 'Polski',
  'ja': '日本語',
};
