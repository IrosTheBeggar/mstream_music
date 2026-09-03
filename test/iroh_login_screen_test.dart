// Widget tests for the Quick Connect sign-in page (TEST_PLAN.md Layer 2).
//
// IrohLoginScreen is one of the few screens that needs no plugin mocks: it
// owns two text fields and a validate callback, and touches no singletons.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/screens/iroh_login_screen.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    Future<String?> Function(String, String)? validate,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: IrohLoginScreen(
        title: 'Sign in',
        validate: validate ?? (u, p) async => null,
      ),
    ));
    await tester.pumpAndSettle();
  }

  // The password field is the obscurable one; the username field never is.
  TextField passwordField(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .firstWhere((f) => !f.enableSuggestions);

  testWidgets('password starts obscured', (tester) async {
    await pumpLogin(tester);
    expect(passwordField(tester).obscureText, isTrue);
  });

  testWidgets('eye button reveals and re-hides the password', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(passwordField(tester).obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pumpAndSettle();
    expect(passwordField(tester).obscureText, isTrue);
  });

  testWidgets('eye button labels the action it will perform, for a screen '
      'reader too', (tester) async {
    await pumpLogin(tester);
    final handle = tester.ensureSemantics();

    // IconButton routes `tooltip` into the semantics tooltip field, which
    // TalkBack announces and VoiceOver appends to the accessibility label.
    // Assert the announced string, not just the visual tooltip.
    expect(
      tester
          .getSemantics(find.byTooltip('Show password'))
          .getSemanticsData()
          .tooltip,
      'Show password',
    );
    expect(find.byTooltip('Hide password'), findsNothing);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byTooltip('Hide password'))
          .getSemanticsData()
          .tooltip,
      'Hide password',
    );
    expect(find.byTooltip('Show password'), findsNothing);

    handle.dispose();
  });

  testWidgets('eye button is inert while a sign-in is in flight',
      (tester) async {
    final gate = Completer<String?>();
    await pumpLogin(tester, validate: (u, p) => gate.future);

    await tester.enterText(find.byType(TextField).last, 'hunter2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Busy: the field is disabled, so the toggle must not be tappable.
    final button = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(TextField).last,
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);

    gate.complete(null);
    await tester.pumpAndSettle();
  });
}
