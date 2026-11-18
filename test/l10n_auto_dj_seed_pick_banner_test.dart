// The Seeds page's library pick banners, in every locale.
//
// While the user picks a song from the library for More like or Less like,
// the banner over the library names that list as the Seeds page's card does,
// word for word, inside the quote marks the locale's strings put around a
// label (English quotes none), and never names the other list. Italian once
// used «» there, where its other labels have “”.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';

void main() {
  // Each locale's quote marks around a label, opening and closing; a space
  // stands for any space (French puts one inside its guillemets). English
  // has none: its name stands bare, between spaces.
  const quotes = {
    'de': ('„', '“'),
    'en': (' ', ' '),
    'es': ('«', '»'),
    'fr': ('« ', ' »'),
    'it': ('“', '”'),
    'ja': ('「', '」'),
    'pl': ('„', '”'),
    'pt': ('“', '”'),
    'ru': ('«', '»'),
    'zh': ('“', '”'),
  };

  String spaced(String s) => s.replaceAll(RegExp(r'\s'), ' ');

  test('every supported locale is checked', () {
    expect({for (final l in AppLocalizations.supportedLocales) l.languageCode},
        quotes.keys.toSet());
  });

  for (final MapEntry(key: code, value: (open, close)) in quotes.entries) {
    test('$code: each banner names its own list, in the quote marks of the '
        "locale's labels", () {
      final l = lookupAppLocalizations(Locale(code));
      for (final (banner, list, other) in [
        (l.autoDjSeedPickBannerMore, l.autoDjMoreLike, l.autoDjLessLike),
        (l.autoDjSeedPickBannerLess, l.autoDjLessLike, l.autoDjMoreLike),
      ]) {
        expect(spaced(banner), contains('$open$list$close'), reason: banner);
        expect(banner, isNot(contains(other)), reason: banner);
      }
    });
  }
}
