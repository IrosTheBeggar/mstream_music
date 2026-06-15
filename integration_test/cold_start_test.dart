// Cold start, no server.
//
// The smallest end-to-end test that exercises the platform-plugin init path:
// MediaManager().start() (audio_service) and ServerManager().loadServerList()
// (path_provider). With no servers.json on disk, the app should land on the
// "Welcome to mStream" no-server screen without crashing.

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
      // main() is void (fire-and-forget); pumpAndSettle waits for the async
      // startup (_startApp) to load state and mount the first frame.
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The welcome row renders localized text (see enum_labels.dart), not the
      // raw DisplayItem strings.
      expect(find.text('Welcome to mStream'), findsOneWidget);
      expect(find.text('Tap here to add a server'), findsOneWidget);
    },
  );
}
