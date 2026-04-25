// Cold start, no server.
//
// The smallest end-to-end test that exercises the platform-plugin init path:
// MediaManager().start() (audio_service) and ServerManager().loadServerList()
// (path_provider). With no servers.json on disk, the app should land on the
// "Welcome To mStream" no-server screen without crashing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mstream_music/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final dir = await getApplicationDocumentsDirectory();
    final serversFile = File('${dir.path}/servers.json');
    if (await serversFile.exists()) {
      await serversFile.delete();
    }
  });

  testWidgets(
    'cold start with no server shows welcome screen',
    (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Welcome To mStream'), findsOneWidget);
      expect(find.text('Click here to add server'), findsOneWidget);

      expect(find.text('mStream Music'), findsWidgets);
    },
  );
}
