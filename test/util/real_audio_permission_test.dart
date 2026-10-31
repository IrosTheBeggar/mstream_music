// The real-audio consent dialog (util/real_audio_permission.dart): it says why
// the microphone; "Don't ask again" appears only when offered and rides back on
// the answer; "Use synthesized data" never reaches Android; "Use real audio"
// asks Android for the microphone, and a refusal says so in a snackbar — with
// the way to system settings once Android has stopped asking; dismissing the
// dialog is no answer at all.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/util/real_audio_permission.dart';

const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

// permission_handler's wire values: Permission.microphone, and the
// PermissionStatus codes the platform side answers with.
const _microphone = 7;
const _denied = 0;
const _granted = 1;
const _permanentlyDenied = 4;

Widget _app(Widget body) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(body: body),
    );

void main() {
  late List<MethodCall> calls;

  /// Android answers every permission request with [status]; a status check
  /// says [current] (not yet granted, unless a test says otherwise).
  void androidAnswers(int status, {int current = _denied}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissions, (call) async {
      calls.add(call);
      if (call.method == 'checkPermissionStatus') return current;
      return {for (final p in call.arguments as List) p as int: status};
    });
  }

  setUp(() {
    calls = [];
    androidAnswers(_denied);
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_permissions, null));

  /// A page whose button opens the dialog; each answer lands in the list
  /// returned (null: dismissed).
  Future<List<RealAudioAnswer?>> open(WidgetTester tester,
      {bool offerDontAskAgain = false}) async {
    final answers = <RealAudioAnswer?>[];
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => answers.add(await askForRealAudio(context,
            offerDontAskAgain: offerDontAskAgain)),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  Future<void> tapAndSettle(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('says why the microphone; no checkbox unless offered',
      (tester) async {
    await open(tester);
    expect(find.text('Use real audio?'), findsOneWidget);
    expect(find.textContaining('the microphone permission'), findsOneWidget);
    expect(find.textContaining('mStream never uses your microphone.'),
        findsOneWidget);
    expect(find.textContaining('synthesized data instead'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Use synthesized data'), findsOneWidget);
    expect(find.text('Use real audio'), findsOneWidget);
  });

  testWidgets('Use synthesized data answers without asking Android',
      (tester) async {
    final answers = await open(tester, offerDontAskAgain: true);
    expect(find.text("Don't ask again"), findsOneWidget);
    await tapAndSettle(tester, 'Use synthesized data');

    expect(find.text('Use real audio?'), findsNothing);
    final answer = answers.single!;
    expect(answer.wantsReal, isFalse);
    expect(answer.granted, isFalse);
    expect(answer.dontAskAgain, isFalse);
    expect(calls, isEmpty);
  });

  testWidgets("a Don't ask again tick rides back on the answer",
      (tester) async {
    final answers = await open(tester, offerDontAskAgain: true);
    await tester.tap(find.text("Don't ask again"));
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
    await tapAndSettle(tester, 'Use synthesized data');

    expect(answers.single!.dontAskAgain, isTrue);
  });

  testWidgets('dismissing the dialog is no answer', (tester) async {
    final answers = await open(tester, offerDontAskAgain: true);
    await tester.tap(find.text("Don't ask again"));
    await tester.pump();
    await tester.tapAt(const Offset(8, 8)); // the scrim
    await tester.pumpAndSettle();

    expect(find.text('Use real audio?'), findsNothing);
    expect(answers, [null]);
    expect(calls, isEmpty);
  });

  testWidgets('Use real audio asks Android for the microphone; a grant is '
      'granted', (tester) async {
    androidAnswers(_granted);
    final answers = await open(tester);
    await tapAndSettle(tester, 'Use real audio');

    expect(calls.single.method, 'requestPermissions');
    expect(calls.single.arguments, [_microphone]);
    expect(answers.single!.wantsReal, isTrue);
    expect(answers.single!.granted, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refusal comes back ungranted, and a snackbar says so',
      (tester) async {
    final answers = await open(tester);
    await tapAndSettle(tester, 'Use real audio');

    expect(answers.single!.wantsReal, isTrue);
    expect(answers.single!.granted, isFalse);
    expect(find.text('Permission denied. Staying on synthesized audio.'),
        findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
  });

  testWidgets('a permanent refusal points at system settings',
      (tester) async {
    androidAnswers(_permanentlyDenied);
    final answers = await open(tester);
    await tapAndSettle(tester, 'Use real audio');

    expect(answers.single!.granted, isFalse);
    expect(
        find.text('Permission permanently denied. Enable it in system settings '
            'to use real audio.'),
        findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Open settings'),
        findsOneWidget);
  });

  testWidgets('Settings gets true only for a grant', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            results.add(await confirmRealAudioPermission(context)),
        child: const Text('open'),
      ),
    )));

    for (final (button, status) in [
      ('Use synthesized data', _granted),
      ('Use real audio', _denied),
      ('Use real audio', _granted),
    ]) {
      androidAnswers(status);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, button);
    }
    expect(results, [false, false, true]);
  });

  testWidgets('Settings with the permission already granted: no dialog',
      (tester) async {
    final results = <bool>[];
    androidAnswers(_denied, current: _granted);
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            results.add(await confirmRealAudioPermission(context)),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Use real audio?'), findsNothing);
    expect(results, [true]);
    expect(calls.map((c) => c.method), ['checkPermissionStatus']);
  });
}
