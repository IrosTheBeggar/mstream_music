// Editing a server persists the freshly obtained JWT (PR #119).
//
// The edit flow's checkServer() logs in and threads the new token into
// saveServer(lol, res['token']), but the shouldUpdate branch used to ignore
// the jwt parameter entirely — after an edit the app kept sending the old,
// dead token on every request, and nothing re-logs-in on a 401.
//
// Two contracts:
//   1. Auth path (ping non-200 → login runs): the token from the login
//      response replaces the stored one.
//   2. No-login path (ping 200 → public/no-auth save): the stored token is
//      KEPT — an empty jwt means no login ran, and clobbering it would break
//      iroh servers whose pairing-time JWT never comes from this flow.

import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/add_server.dart';
import 'package:mstream_music/singletons/server_list.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mock;
  String? lastLoginPassword;

  setUp(() async {
    await resetAppState();
    lastLoginPassword = null;
  });

  tearDown(() async {
    await mock?.close();
    mock = null;
  });

  Future<void> pumpEditScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox()),
    ));
    await tester.pumpAndSettle();
    // Pushed (not home:) so saveServer's Navigator.pop has a route to pop.
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute(
            builder: (_) => const EditServerScreen(editThisServer: 0)));
    await tester.pumpAndSettle();
  }

  Future<void> waitFor(bool Function() cond, String what,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  testWidgets('edit + login replaces the stored JWT', (tester) async {
    mock = await MockServer.start({
      // Non-200 ping forces checkServer down the login path.
      '/api/v1/ping': (req) => null,
      '/api/v1/auth/login': (HttpRequest req) async {
        final body = await utf8.decoder.bind(req).join();
        lastLoginPassword = Uri.splitQueryString(body)['password'];
        return {'token': 'tok-FRESH'};
      },
    });
    ServerManager()
        .serverList
        .add(Server(mock!.url, 'user', 'pw-old', 'tok-OLD', 'edit-target'));

    await pumpEditScreen(tester);
    await tester.tap(find.text('Save'));
    // Real network round-trip — poll the singleton rather than pumpAndSettle
    // (the login + save run behind awaits the widget tree doesn't surface).
    await tester.runAsync(() => waitFor(
        () => ServerManager().byLocalname('edit-target')?.jwt == 'tok-FRESH',
        'the fresh token to be stored'));

    expect(ServerManager().byLocalname('edit-target')!.jwt, 'tok-FRESH',
        reason: 'the edit used to keep sending the old, dead token');
    expect(lastLoginPassword, 'pw-old',
        reason: 'login must run with the form credentials');
  });

  testWidgets('edit via the no-auth ping path keeps the stored JWT',
      (tester) async {
    // Default harness /ping answers 200 → saveServer(lol) runs with jwt ''.
    mock = await MockServer.start({});
    ServerManager()
        .serverList
        .add(Server(mock!.url, 'user', 'pw-old', 'tok-KEEP', 'edit-target'));

    await pumpEditScreen(tester);
    await tester.tap(find.text('Save'));
    // The save pops the pushed route when it completes. Pump-poll (not
    // runAsync): the pop only shows up in the tree once frames are pumped.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (tester.any(find.byType(EditServerScreen))) {
      if (DateTime.now().isAfter(deadline)) {
        fail('timed out waiting for the edit screen to pop after saving');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(ServerManager().byLocalname('edit-target')!.jwt, 'tok-KEEP',
        reason: 'no login ran, so the stored token must survive '
            '(iroh pairing tokens come from outside this flow)');
  });
}
