// English is the fallback for device languages the app does not ship.
//
// The generated AppLocalizations.supportedLocales is alphabetical, and
// Flutter's basicLocaleListResolution falls back to the first entry when the
// device lists no supported language, so the generated order alone sent
// Dutch/Swedish/… phones to a German UI. appSupportedLocales puts English
// first; every MaterialApp in the app and the tests must use it.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';

void main() {
  test('English leads the list and no locale is lost', () {
    expect(appSupportedLocales.first, const Locale('en'));
    expect(appSupportedLocales.length, AppLocalizations.supportedLocales.length);
    expect(appSupportedLocales.toSet(), AppLocalizations.supportedLocales.toSet());
  });

  test('an unsupported device language resolves to English, not German', () {
    const dutch = [Locale('nl', 'NL')];
    expect(basicLocaleListResolution(dutch, appSupportedLocales),
        const Locale('en'));
    // The generated order on its own picks German — the reason this exists.
    expect(basicLocaleListResolution(dutch, AppLocalizations.supportedLocales),
        const Locale('de'));
  });

  test('a supported device language still wins', () {
    expect(basicLocaleListResolution([const Locale('de', 'DE')], appSupportedLocales),
        const Locale('de'));
    expect(
        basicLocaleListResolution(
            [const Locale('nl'), const Locale('fr')], appSupportedLocales),
        const Locale('fr'));
  });

  testWidgets('a MaterialApp wired like main.dart falls back to English',
      (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('nl', 'NL')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    Locale? resolved;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Builder(builder: (context) {
        resolved = Localizations.localeOf(context);
        return const SizedBox();
      }),
    ));
    expect(resolved, const Locale('en'));
  });
}
