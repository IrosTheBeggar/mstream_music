// The Settings page (screens/settings_screen.dart): every row is one line
// showing its value, never a description; a choice opens a picker sheet that
// applies the pick; the rows that belong to Download the queue fold away with
// it; switching Record plays off and Reset both ask first.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/player_layout.dart';
import 'package:mstream_music/screens/settings_screen.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

void main() {
  late Directory dir;

  // Settings and the listening history write through path_provider; a VM
  // test has no platform side, so point it at a scratch folder.
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('settings-screen-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  setUp(() {
    SettingsManager()
      ..appTheme = AppTheme.dark
      ..playerLayout = PlayerLayout.medium
      ..language = null
      ..tapBehavior = TapBehavior.playFromHere
      ..startupView = StartupView.browser
      ..offlineQueue = false
      ..offlineQueueWifiOnly = true
      ..autoDownloadCap = 50
      ..albumGrid = true
      ..ratingAllowHalf = false
      ..letterStripThreshold = 25
      ..historyEnabled = true
      ..historySendToServer = true;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();
  }

  // Scroll the row in, then fully on screen: scrollUntilVisible stops as
  // soon as an edge shows, which leaves a tap target half off the page.
  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  Finder switchFor(String title) => find.widgetWithText(SwitchListTile, title);

  testWidgets('rows show their value, not a description', (tester) async {
    await open(tester);
    for (final value in [
      'Dark',
      'Medium',
      'System default',
      'Play from here',
    ]) {
      expect(find.text(value), findsOneWidget, reason: value);
    }
    expect(find.textContaining('amber'), findsNothing);
    expect(find.textContaining('Tapping a song'), findsNothing);
    await scrollTo(tester, find.text('Startup page'));
    expect(find.text('Browser'), findsOneWidget);
    expect(find.text('25+ items'), findsOneWidget);
  });

  testWidgets('a picker sheet applies the pick and closes', (tester) async {
    await open(tester);
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    // The sheet lists every theme by name, nothing more.
    for (final name in ['Velvet', 'Light']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(SettingsManager().appTheme, AppTheme.light);
    expect(find.text('Velvet'), findsNothing); // sheet closed
  });

  testWidgets('the language list is sorted by name, System default first',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    double top(String label) => tester.getTopLeft(find.text(label).last).dy;
    expect(top('System default'), lessThan(top('Deutsch')));
    expect(top('Deutsch'), lessThan(top('English')));
    expect(top('Español'), lessThan(top('Français')));
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(SettingsManager().language, 'de');
  });

  testWidgets("Download the queue's rows fold away with it", (tester) async {
    SettingsManager().offlineQueue = true;
    await open(tester);
    await scrollTo(tester, find.text('Download limit'));
    expect(find.text('Wi-Fi only'), findsOneWidget);
    expect(find.text('50 songs'), findsOneWidget);
    expect(find.textContaining('Queue downloads only'), findsOneWidget);

    await scrollTo(tester, switchFor('Download the queue'));
    await tester.tap(switchFor('Download the queue'));
    await tester.pumpAndSettle();
    expect(SettingsManager().offlineQueue, isFalse);
    expect(find.text('Wi-Fi only'), findsNothing);
    expect(find.text('Download limit'), findsNothing);
    expect(find.textContaining('Queue downloads only'), findsNothing);
  });

  testWidgets('the half-star how-to shows only while half stars are on',
      (tester) async {
    await open(tester);
    await scrollTo(tester, switchFor('Half-star ratings'));
    expect(find.text('Long-press a star'), findsNothing);
    await tester.tap(switchFor('Half-star ratings'));
    await tester.pumpAndSettle();
    expect(find.text('Long-press a star'), findsOneWidget);
  });

  testWidgets('Record plays off asks first; Cancel keeps recording',
      (tester) async {
    await open(tester);
    await scrollTo(tester, switchFor('Record plays'));

    await tester.tap(switchFor('Record plays'));
    await tester.pumpAndSettle();
    expect(find.text('Stop recording plays?'), findsOneWidget);
    expect(find.textContaining("Servers keep theirs"), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(SettingsManager().historyEnabled, isTrue);

    await tester.tap(switchFor('Record plays'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(SettingsManager().historyEnabled, isFalse);
  });

  testWidgets('Reset asks first and says what else it resets',
      (tester) async {
    SettingsManager().albumGrid = false;
    await open(tester);
    await scrollTo(tester, find.text('Reset settings'));
    await tester.tap(find.text('Reset settings'));
    await tester.pumpAndSettle();
    expect(find.text('Reset settings?'), findsOneWidget);
    expect(find.textContaining('Transcoding'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(SettingsManager().albumGrid, isFalse); // nothing reset
  });
}
