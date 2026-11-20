// File Explorer rows for things on this phone, with no swipe drawer: a phone
// file's track sheet ends with "Delete from this phone", a phone folder opens
// a menu (its hold or its ⋮) with the same row, and both ask before deleting
// anything — a folder with everything in it. A server song's sheet has no
// Delete, and a sideways drag on a phone file deletes nothing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';

import 'browse_keep_fixtures.dart';
import 'discovery_keep_fixtures.dart' show mockPathProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseHarness();
  late Directory dir;

  setUpAll(mockPathProvider);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('mstream-local-delete-');
    h.setUp();
  });
  tearDown(() {
    h.tearDown();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  DisplayItem localFile(String name) {
    final f = File('${dir.path}/$name')..writeAsStringSync('not really audio');
    return DisplayItem(h.home, name, 'localFile', f.path, Icon(Icons.music_note), null);
  }

  DisplayItem localFolder(String name) {
    final d = Directory('${dir.path}/$name')..createSync();
    File('${d.path}/inside.mp3').writeAsStringSync('not really audio');
    return DisplayItem(h.home, name, 'localDirectory', d.path, Icon(Icons.folder_open_outlined), null);
  }

  Future<void> openRows(WidgetTester tester, List<DisplayItem> rows, String label, String path) async {
    ServerManager().currentServer = h.home;
    BrowserManager().goToNavScreen();
    await h.pump(tester, const Browser());
    BrowserManager().setBrowserLabel(label);
    BrowserManager().addListToStack(rows, alphabetical: true, path: path);
    await BrowseHarness.frames(tester);
  }

  Future<void> openLocal(WidgetTester tester, List<DisplayItem> rows) =>
      openRows(tester, rows, 'Local Files', dir.path);

  // The delete runs on the real file system: give it real time, then frames.
  Future<void> letIoFinish(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await BrowseHarness.frames(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Finder sheetDelete() => find.byKey(const ValueKey('track-sheet-delete'));
  Finder confirm() => find.byKey(const ValueKey('browse-delete-confirm'));
  Finder moreOf(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)).first,
      matching: find.byTooltip('More actions'));

  testWidgets("a phone file's sheet ends with Delete from this phone, which asks first", (tester) async {
    final a = localFile('Drifter.mp3');
    await openLocal(tester, [a, localFile('Perspectives.mp3')]);

    await tester.longPress(find.text('Drifter.mp3'));
    await tester.pumpAndSettle();
    expect(sheetDelete(), findsOneWidget);
    expect(find.text('Delete from this phone'), findsOneWidget);
    expect(tester.getTopLeft(sheetDelete()).dy, greaterThan(tester.getTopLeft(find.text('Play now')).dy),
        reason: 'last, below the queue verbs');

    await tester.tap(sheetDelete());
    await tester.pumpAndSettle();
    expect(find.text('Delete “Drifter.mp3”?'), findsOneWidget);
    expect(find.text("It's removed from this phone."), findsOneWidget);
    await tester.tap(find.text('Go Back'));
    await tester.pumpAndSettle();
    await letIoFinish(tester);
    expect(File(a.data!).existsSync(), isTrue, reason: 'Go Back keeps it');
    expect(find.text('Drifter.mp3'), findsOneWidget);

    // The ⋮ opens the same sheet; this time, Delete.
    await tester.tap(moreOf('Drifter.mp3'));
    await tester.pumpAndSettle();
    await tester.tap(sheetDelete());
    await tester.pumpAndSettle();
    await tester.tap(confirm());
    await tester.pump();
    await letIoFinish(tester);
    expect(File(a.data!).existsSync(), isFalse);
    expect(find.text('Drifter.mp3'), findsNothing, reason: 'its row goes with it');
    expect(find.text('Perspectives.mp3'), findsOneWidget);
    await close(tester);
  });

  testWidgets("a phone folder's hold or ⋮ opens its menu; Delete asks, then takes everything in it", (tester) async {
    final mixes = localFolder('Mixes');
    await openLocal(tester, [mixes, localFile('Solo.mp3')]);
    final sheet = find.byKey(const ValueKey('browse-local-folder-sheet'));

    await tester.longPress(find.text('Mixes'));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Mixes')), findsOneWidget, reason: 'the sheet is the folder\'s');
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    await tester.tap(moreOf('Mixes'));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget, reason: 'the ⋮ opens the same menu');
    await tester.tap(find.byKey(const ValueKey('browse-delete-from-phone')));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Mixes”?'), findsOneWidget);
    expect(find.text("It's removed from this phone, with everything in it."), findsOneWidget);
    await tester.tap(confirm());
    await tester.pump();
    await letIoFinish(tester);
    expect(Directory(mixes.data!).existsSync(), isFalse);
    expect(find.text('Mixes'), findsNothing);
    expect(find.text('Solo.mp3'), findsOneWidget);
    await close(tester);
  });

  testWidgets("a server song's sheet has no Delete", (tester) async {
    await openRows(tester, [DisplayItem(h.home, 'Drifter.mp3', 'file', '/music/Drifter.mp3', Icon(Icons.music_note), null)],
        'File Explorer', '/music/');
    await tester.longPress(find.text('Drifter.mp3'));
    await tester.pumpAndSettle();
    expect(find.text('Play now'), findsOneWidget, reason: 'the sheet is open');
    expect(sheetDelete(), findsNothing);
    await close(tester);
  });

  testWidgets('a sideways drag on a phone file deletes nothing: the drawer is gone', (tester) async {
    final a = localFile('Drifter.mp3');
    await openLocal(tester, [a]);
    await tester.drag(find.text('Drifter.mp3'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await letIoFinish(tester);
    expect(find.text('Delete'), findsNothing);
    expect(File(a.data!).existsSync(), isTrue);
    expect(find.text('Drifter.mp3'), findsOneWidget);
    await close(tester);
  });
}
