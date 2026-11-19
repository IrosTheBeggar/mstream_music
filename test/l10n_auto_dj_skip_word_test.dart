// The Auto DJ's word for a skip, in every locale.
//
// The Learn from skips row, its hint and the Less like Add song sheet's
// Skipped header (over the very songs those skips name) say a skip with one
// word in each language, the one Discover uses as well. The listening
// history has its own word for a skipped play, "ignored" in French and
// Portuguese (Ignorées, Ignoradas), which once leaked into the sheet's header
// and gave the one idea two words within the feature.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';

void main() {
  // Each locale's skip word, as the stem all three strings hold, lower case.
  const skipWord = {
    'de': 'übersp',
    'en': 'skip',
    'es': 'salt',
    'fr': 'pass',
    'it': 'salt',
    'ja': 'スキップ',
    'pl': 'pomi',
    'pt': 'pula',
    'ru': 'пропу',
    'zh': '跳过',
  };

  test('every supported locale is checked', () {
    expect({for (final l in AppLocalizations.supportedLocales) l.languageCode},
        skipWord.keys.toSet());
  });

  for (final MapEntry(key: code, value: word) in skipWord.entries) {
    test('$code: the Skipped header says a skip as Learn from skips does', () {
      final l = lookupAppLocalizations(Locale(code));
      for (final s in [
        l.autoDjSkipped,
        l.autoDjLearnFromSkips,
        l.autoDjLearnFromSkipsHint,
      ]) {
        expect(s.toLowerCase(), contains(word), reason: s);
      }
    });
  }
}
