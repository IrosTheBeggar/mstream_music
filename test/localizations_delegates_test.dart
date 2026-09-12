// Regression test for #169 (grey screen on any non-English device language).
//
// The UI is built on package:material_ui, whose MaterialLocalizations is a
// different type from package:flutter/material's. The generated
// AppLocalizations.localizationsDelegates only carries flutter_localizations'
// delegates (the flutter/material type), so on its own it leaves material_ui
// widgets with English-only DefaultMaterialLocalizations — every lookup on a
// German/French/… device threw, and in release the screen became the grey
// ErrorWidget. appLocalizationsDelegates adds the material_ui + cupertino_ui
// global delegates; every MaterialApp in the app and the tests must use it.
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';

void main() {
  // The same lookups the real screens make: the drawer tooltip (main.dart),
  // what TextField / TabBar / dialogs read internally, and the app's own
  // strings — rendered so a failure surfaces as a build exception.
  Widget probe(Locale locale, List<LocalizationsDelegate<dynamic>> delegates) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(
            '${MaterialLocalizations.of(context).openAppDrawerTooltip}|'
            '${CupertinoLocalizations.of(context).pasteButtonLabel}|'
            '${AppLocalizations.of(context).addServerTitle}',
          ),
        ),
      );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('material_ui + cupertino_ui localizations resolve for $locale',
        (tester) async {
      await tester.pumpWidget(probe(locale, appLocalizationsDelegates));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsOneWidget);
    });
  }

  testWidgets('a non-English locale gets translated material strings',
      (tester) async {
    await tester.pumpWidget(probe(const Locale('de'), appLocalizationsDelegates));
    await tester.pumpAndSettle();
    final tooltip = tester.widget<Text>(find.byType(Text)).data!.split('|').first;
    expect(tooltip, isNotEmpty);
    expect(tooltip, isNot('Open navigation menu'));
  });

  testWidgets('the generated list alone is NOT enough for a non-English locale',
      (tester) async {
    // Two errors are reported: WidgetsApp's debug warning that the locale is
    // not supported by every delegate, then the real assertion. The test
    // binding collapses two into a generic "multiple exceptions" note, so
    // capture them at the source instead of via takeException().
    final reported = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => reported.add(details.exceptionAsString());
    try {
      await tester.pumpWidget(
          probe(const Locale('de'), AppLocalizations.localizationsDelegates));
    } finally {
      FlutterError.onError = previous;
    }
    expect(reported.join(' '), contains('No MaterialLocalizations found'));
  });
}
