// Keep a copy while browsing a connected server, as the copy surfaces show
// it: a folder copy's row in the Copies sheet (its name, "Folder · from
// Server", a folder tile, Retry with its own landing), its toasts under the
// folder's name, the start toast's "View", and a toast with an action — its
// 44 pt button outside the dismissing tap, and held for a screen reader.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/screens/discovery/copy_news.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';

import 'discovery_copies_fixtures.dart';
import 'discovery_keep_fixtures.dart';

const tapesFolder = {
  'source': 'federation',
  'peer': peerB,
  'filepath': 'music/Boukmanflow/Borrowed Tapes',
  'title': 'Borrowed Tapes',
};

Map<String, dynamic> folderResult({int copied = 2, int failed = 1, String? stopped}) => {
      'scope': 'folder',
      'folder': {'path': 'music/Boukmanflow/Borrowed Tapes', 'name': 'Borrowed Tapes', 'landed': 'copies/From Sam'},
      'layout': 'folder',
      'songs': {'total': copied + failed, 'copied': [], 'skipped': [], 'failed': []},
      'counts': {'total': copied + failed, 'copied': copied, 'skipped': 0, 'failed': failed},
      'skippedFiles': [],
      'stopped': stopped,
      'peer': peerB,
    };

void main() {
  final h = SheetHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  group("a folder copy in the Copies sheet", () {
    testWidgets("its name, \"Folder · from Stage Peer B\", a folder tile; Retry sends its own landing", (tester) async {
      final j = h.fake.addJob(tapesFolder, scope: 'folder', state: 'done', result: folderResult(copied: 0, failed: 3));
      j['params'] = {
        'scope': 'folder',
        'landing': {'vpath': 'copies', 'path': 'From Sam'},
        'destination': h.fake.destination['destination'],
      };
      await h.pumpCopies(tester);
      expect(find.text('Borrowed Tapes'), findsOneWidget);
      expect(find.text('Folder · from Stage Peer B'), findsOneWidget);
      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.text('1 failed'), findsOneWidget, reason: 'counted with the rest');
      await tester.tap(find.byKey(const ValueKey('copies-retry')));
      await KeepHarness.pumpFor(tester, 8);
      final body = jsonDecode(h.fake.calls('POST', '/plugins/federation-copy/jobs').single.body) as Map;
      expect([body['scope'], body['landing']], ['folder', {'vpath': 'copies', 'path': 'From Sam'}]);
    });

    testWidgets('refused: stopped, and no Retry', (tester) async {
      final j = h.fake.addJob(tapesFolder, scope: 'folder', state: 'done', result: folderResult(copied: 0, failed: 0, stopped: 'refused'));
      j['params'] = {'scope': 'folder'};
      await h.pumpCopies(tester);
      expect(find.text('Borrowed Tapes'), findsOneWidget);
      expect(find.byKey(const ValueKey('copies-retry')), findsNothing);
    });
  });

  group("its toasts", () {
    late AppLocalizations l;
    setUp(() async {
      l = await AppLocalizations.delegate.load(const Locale('en'));
    });

    DiscoveryJob job({String state = 'queued', Map<String, dynamic>? result}) => DiscoveryJob.fromServerMap({
          'id': 1,
          'plugin': kCopyPlugin,
          'recommendation': tapesFolder,
          'params': {'scope': 'folder'},
          'state': state,
          'result': result,
        })!;

    test("start and end under the folder's name", () {
      expect(copyStartedToast(l, job()), 'Copying Borrowed Tapes from Stage Peer B');
      expect(copyFinishedToast(l, job(state: 'done', result: folderResult())), 'Added to your collection');
      expect(copyFinishedToast(l, job(state: 'done', result: folderResult(copied: 0, failed: 3))), startsWith('Copy failed: '));
    });

    test('a copy started while browsing offers View; Discover\'s start toast none', () {
      final actions = <(String, String)>[];
      VoidCallback? view;
      KeepToast.debugActionSink = (m, a, onAction) {
        actions.add((m, a));
        view = onAction;
      };
      addTearDown(() => KeepToast.debugActionSink = null);
      var opened = 0;
      showCopyStarted(null, l, job(), onView: () => opened++);
      expect(h.toasts.last, 'Copying Borrowed Tapes from Stage Peer B');
      expect(actions, [('Copying Borrowed Tapes from Stage Peer B', 'View')]);
      view!();
      expect(opened, 1);
      showCopyStarted(null, l, job());
      expect(actions, hasLength(1));
    });
  });

  group('a toast with an action', () {
    Future<void> pumpApp(WidgetTester tester, {bool screenReader = false}) async {
      KeepToast.debugSink = null;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: screenReader),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => KeepToast.show(context, 'Copying Borrowed Tapes from Stage Peer B', action: 'View', onAction: () => h.toasts.add('viewed')),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump();
    }

    testWidgets('its button is 44 pt and outside the dismissing tap; it goes after 4 s', (tester) async {
      await pumpApp(tester);
      final button = find.byKey(const ValueKey('keep-toast-action'));
      expect(button, findsOneWidget);
      final size = tester.getSize(button);
      expect(size.height >= 44 && size.width >= 44, isTrue);
      expect(find.byKey(const ValueKey('keep-toast-close')), findsNothing);
      await tester.tap(button);
      await tester.pump();
      expect([h.toasts.last, KeepToast.showing], ['viewed', false]);

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(KeepToast.kShowFor);
      expect(KeepToast.showing, isFalse);
    });

    testWidgets('with a screen reader navigating it stays until closed, with a ✕', (tester) async {
      await pumpApp(tester, screenReader: true);
      await tester.pump(const Duration(seconds: 10));
      expect(KeepToast.showing, isTrue);
      final close = find.byKey(const ValueKey('keep-toast-close'));
      expect(close, findsOneWidget);
      expect(tester.getSize(close), const Size(44, 44));
      await tester.tap(close);
      await tester.pump();
      expect(KeepToast.showing, isFalse);
    });
  });
}
