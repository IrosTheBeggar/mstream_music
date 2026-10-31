// The chooser Auto DJ shows when it starts with nothing queued and First song
// is Ask or Recently played (widgets/auto_dj_start_sheet.dart), in the Auto
// DJ sheets' chrome: Random and Choose pop that choice, never Ask; Recently
// played drops down this server's recent songs and pops the one picked;
// dismissing pops nothing; Remember stores the way chosen as First song
// before the sheet closes.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/widgets/auto_dj_start_sheet.dart';
import 'package:mstream_music/widgets/federation_widgets.dart' show FedCheckRow;

/// Counts the routes popped: the sheet closes only once its save landed.
class _Pops extends NavigatorObserver {
  int count = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}

final _random = find.byKey(const ValueKey('auto-dj-start-random'));
final _choose = find.byKey(const ValueKey('auto-dj-start-choose'));
final _recentRow = find.byKey(const ValueKey('auto-dj-start-recent'));
final _remember = find.byKey(const ValueKey('auto-dj-start-remember'));
Finder _recentItem(int i) => find.byKey(ValueKey('auto-dj-recent-$i'));

const _songs = [
  TrackFacts(
      server: 'home', path: '/Jazz/So What.mp3', title: 'So What', artist: 'Miles'),
  TrackFacts(server: 'home', path: '/Ambient/Untitled.mp3'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mgr = AutoDJManager();
  late Directory scratch;
  late _Pops pops;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-start-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    pops = _Pops();
    mgr.emptyQueueStart = EmptyQueueStart.ask;
  });

  /// Opens the sheet the way the queue's Auto DJ button does; each answer
  /// lands in the list returned (null: dismissed).
  Future<List<AutoDjStartChoice?>> open(WidgetTester tester,
      {List<TrackFacts> recent = const [], bool openRecent = false}) async {
    final answers = <AutoDjStartChoice?>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      navigatorObservers: [pops],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(
                await showModalBottomSheet<AutoDjStartChoice>(
                    context: context,
                    builder: (_) => AutoDjStartSheet(
                        recent: recent, openRecent: openRecent))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  List<EmptyQueueStart?> hows(List<AutoDjStartChoice?> answers) =>
      [for (final a in answers) a?.how];

  bool remembered(WidgetTester tester) =>
      tester.widget<FedCheckRow>(_remember).value;

  /// Taps [target] off the fake clock until the sheet's pop lands: the
  /// save is real file IO.
  Future<void> tapAndSave(WidgetTester tester, Finder target) async {
    final before = pops.count;
    await tester.runAsync(() async {
      await tester.tap(target);
      for (var i = 0; i < 400 && pops.count == before; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    expect(pops.count, before + 1, reason: 'popped once the save landed');
    await tester.pumpAndSettle();
  }

  testWidgets("First song's title and words; Remember off; no buttons",
      (tester) async {
    await open(tester);
    expect(find.text('First song'), findsOneWidget);
    expect(find.text('Random'), findsOneWidget);
    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('Remember'), findsOneWidget);
    expect(find.text('Ask'), findsNothing, reason: 'never offered: a loop');
    expect(remembered(tester), isFalse);
    expect(find.byKey(const ValueKey('auto-dj-sheet-done')), findsNothing);
    expect(find.byKey(const ValueKey('auto-dj-sheet-clear')), findsNothing);
  });

  testWidgets('no recent songs on the server: no Recently played',
      (tester) async {
    await open(tester);
    expect(_recentRow, findsNothing);
    expect(find.text('Recently played'), findsNothing);
  });

  testWidgets('Random pops random; nothing is stored', (tester) async {
    final answers = await open(tester);
    await tester.tap(_random);
    await tester.pumpAndSettle();
    expect(find.text('First song'), findsNothing);
    expect(hows(answers), [EmptyQueueStart.random]);
    expect(answers.single!.song, isNull);
    expect(mgr.emptyQueueStart, EmptyQueueStart.ask);
  });

  testWidgets('Choose pops pick; nothing is stored', (tester) async {
    final answers = await open(tester);
    await tester.tap(_choose);
    await tester.pumpAndSettle();
    expect(hows(answers), [EmptyQueueStart.pick]);
    expect(mgr.emptyQueueStart, EmptyQueueStart.ask);
  });

  testWidgets('Recently played drops down the songs, titles and artists; '
      'the one picked is popped', (tester) async {
    final answers = await open(tester, recent: _songs);
    expect(find.text('Recently played'), findsOneWidget);
    expect(_recentItem(0), findsNothing, reason: 'closed until tapped');

    await tester.tap(_recentRow);
    await tester.pumpAndSettle();
    expect(_recentItem(0), findsOneWidget);
    expect(find.text('So What'), findsOneWidget);
    expect(find.text('Miles'), findsOneWidget);
    expect(find.text('Untitled.mp3'), findsOneWidget,
        reason: 'no title: the file name');

    await tester.tap(_recentItem(1));
    await tester.pumpAndSettle();
    expect(find.text('First song'), findsNothing);
    expect(hows(answers), [EmptyQueueStart.recent]);
    expect(answers.single!.song!.path, '/Ambient/Untitled.mp3');
    expect(mgr.emptyQueueStart, EmptyQueueStart.ask, reason: 'not remembered');
  });

  testWidgets('closing the dropdown leaves the sheet up', (tester) async {
    final answers = await open(tester, recent: _songs);
    await tester.tap(_recentRow);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(_recentItem(0), findsNothing);
    expect(find.text('First song'), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('First song is Recently played: the dropdown opens by itself',
      (tester) async {
    await open(tester, recent: _songs, openRecent: true);
    expect(_recentItem(0), findsOneWidget);
    expect(find.text('So What'), findsOneWidget);
  });

  testWidgets('dismissed, it pops nothing', (tester) async {
    final answers = await open(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(answers, [null]);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();
    expect(answers, [null, null]);
    expect(mgr.emptyQueueStart, EmptyQueueStart.ask);
  });

  testWidgets('Remember toggles and stores the choice before it pops',
      (tester) async {
    final answers = await open(tester);
    await tester.tap(_remember);
    await tester.pumpAndSettle();
    expect(remembered(tester), isTrue);
    await tester.tap(_remember);
    await tester.pumpAndSettle();
    expect(remembered(tester), isFalse);
    await tester.tap(_remember);
    await tester.pumpAndSettle();

    await tapAndSave(tester, _choose);
    expect(mgr.emptyQueueStart, EmptyQueueStart.pick);
    expect(hows(answers), [EmptyQueueStart.pick]);
    expect(
        File('${scratch.path}/auto_dj.json').readAsStringSync(),
        contains('"emptyQueueStart":"pick"'));
  });

  testWidgets('Remember with a recent song stores Recently played, not the '
      'song', (tester) async {
    final answers = await open(tester, recent: _songs);
    await tester.tap(_remember);
    await tester.pumpAndSettle();
    await tester.tap(_recentRow);
    await tester.pumpAndSettle();
    // The menu closes, then the sheet once its save — real file IO — lands:
    // real waits and frames in turn, so both make progress.
    await tester.tap(_recentItem(0));
    for (var i = 0; i < 200 && answers.isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(mgr.emptyQueueStart, EmptyQueueStart.recent);
    expect(hows(answers), [EmptyQueueStart.recent]);
    expect(answers.single!.song!.title, 'So What');
    expect(
        File('${scratch.path}/auto_dj.json').readAsStringSync(),
        contains('"emptyQueueStart":"recent"'));
  });
}
