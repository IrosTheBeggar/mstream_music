// The destination sheet's shared parts (screens/discovery/destination_pieces
// .dart), on their own: a locked library chip (a lock for the check, read as
// off, deaf to taps), a used variable button (a tick before the token, in
// the ink colour, tertiary while off), the hit band each piece sits on (44
// by default, 48 when asked — the drawn chip keeps its own size), Save's
// key on the pill, the preview card's live region and its margins, and the
// text helpers both sheets edit a layout with (the token, the unbreakable
// run, inserting at the caret, the validator's words, what a field
// reveals). The destination sheet itself is pinned down in
// discovery_destination_elsewhere_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/screens/discovery/destination_pieces.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/discover_jobs.dart';

void main() {
  /// [child] alone on a page, at its own size.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: page!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  Color iconColor(WidgetTester tester, IconData icon) =>
      tester.widget<Icon>(find.byIcon(icon)).color!;

  group('DestLibraryChip', () {
    testWidgets('chosen: a check, and a tap picks it', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DestLibraryChip(name: 'Music', selected: true, onTap: () => taps++),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(
        tester.getSemantics(find.text('Music')),
        isSemantics(
          label: 'Music',
          isButton: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      await tester.tap(find.byType(DestLibraryChip));
      expect(taps, 1);
    });

    testWidgets('locked: a lock for the check, read as off, deaf to taps', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        DestLibraryChip(
          name: 'Music',
          selected: true,
          locked: true,
          onTap: () => taps++,
        ),
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing, reason: 'no choice');
      expect(iconColor(tester, Icons.lock_outline), VelvetColors.textSecondary);
      expect(
        tester.getSemantics(find.text('Music')),
        isSemantics(
          label: 'Music',
          isButton: false,
          hasEnabledState: true,
          isEnabled: false,
          isInMutuallyExclusiveGroup: false,
          hasCheckedState: false,
        ),
      );
      await tester.tap(find.byType(DestLibraryChip));
      await tester.tapAt(tester.getTopLeft(find.byType(DestLibraryChip)));
      expect(taps, 0);
    });

    testWidgets('locked: raised, a plain edge, the lock side tighter', (
      tester,
    ) async {
      await pump(
        tester,
        const DestLibraryChip(name: 'Music', selected: true, locked: true),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(DestLibraryChip),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, VelvetColors.raised);
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(DestLibraryChip),
          matching: find.byType(Container),
        ),
      );
      final border = (box.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, VelvetColors.border2);
      expect(border.top.width, 1);
      expect(box.padding, const EdgeInsetsDirectional.only(start: 12, end: 14));
    });

    testWidgets('the band: 44 by default, 48 when asked; the chip stays 40', (
      tester,
    ) async {
      await pump(tester, const DestLibraryChip(name: 'Music', selected: false));
      expect(tester.getSize(find.byType(DestLibraryChip)).height, 44);
      var taps = 0;
      await pump(
        tester,
        DestLibraryChip(
          name: 'Music',
          selected: false,
          minHit: 48,
          onTap: () => taps++,
        ),
      );
      final band = find.byType(DestLibraryChip);
      expect(tester.getSize(band).height, 48);
      expect(
        tester
            .getSize(find.descendant(of: band, matching: find.byType(Material)))
            .height,
        40,
      );
      // Just inside the band's top edge: past the chip, still a tap on it.
      await tester.tapAt(tester.getTopLeft(band) + const Offset(20, 1));
      expect(taps, 1);
    });
  });

  group('DestVarChip', () {
    testWidgets('unused: the token alone', (tester) async {
      await pump(
        tester,
        DestVarChip(token: '{{ARTIST}}', label: 'Insert artist', onTap: () {}),
      );
      expect(find.text('{{ARTIST}}'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('used: a tick before the token in the ink colour; the label '
        'is what is read', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DestVarChip(
          token: '{{ARTIST}}',
          label: 'Insert artist, used',
          used: true,
          onTap: () => taps++,
        ),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(iconColor(tester, Icons.check), keepInk());
      expect(
        tester.getTopLeft(find.byIcon(Icons.check)).dx,
        lessThan(tester.getTopLeft(find.text('{{ARTIST}}')).dx),
        reason: 'the tick comes first',
      );
      expect(
        tester.getSemantics(find.byType(DestVarChip)),
        isSemantics(
          label: 'Insert artist, used',
          isButton: true,
          isEnabled: true,
        ),
      );
      // Still a button: a token used once can go in again.
      await tester.tap(find.byType(DestVarChip));
      expect(taps, 1);
    });

    testWidgets('used and off: the tick goes tertiary with the token', (
      tester,
    ) async {
      await pump(
        tester,
        const DestVarChip(
          token: '{{YEAR}}',
          label: 'Insert year, used',
          used: true,
        ),
      );
      expect(iconColor(tester, Icons.check), VelvetColors.textTertiary);
      expect(
        tester.widget<Text>(find.text('{{YEAR}}')).style!.color,
        VelvetColors.textTertiary,
      );
      expect(
        tester.getSemantics(find.byType(DestVarChip)),
        isSemantics(isButton: true, isEnabled: false),
      );
    });

    testWidgets('the band: 44 by default, 48 when asked; the chip stays 32', (
      tester,
    ) async {
      await pump(
        tester,
        DestVarChip(token: '{{ALBUM}}', label: 'Insert album', onTap: () {}),
      );
      expect(tester.getSize(find.byType(DestVarChip)).height, 44);
      var taps = 0;
      await pump(
        tester,
        DestVarChip(
          token: '{{ALBUM}}',
          label: 'Insert album',
          minHit: 48,
          onTap: () => taps++,
        ),
      );
      final band = find.byType(DestVarChip);
      expect(tester.getSize(band).height, 48);
      expect(
        tester
            .getSize(
              find.descendant(of: band, matching: find.byType(Container)),
            )
            .height,
        32,
      );
      await tester.tapAt(tester.getBottomLeft(band) + const Offset(10, -1));
      expect(taps, 1);
    });
  });

  group('DestSaveButton', () {
    testWidgets("the pill keeps the tests' key unless given another", (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        DestSaveButton(
          label: 'Save',
          busy: false,
          enabled: true,
          onTap: () => taps++,
        ),
      );
      expect(find.byKey(const ValueKey('destination-save')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('destination-save')));
      expect(taps, 1);

      await pump(
        tester,
        DestSaveButton(
          label: 'Save',
          busy: false,
          enabled: true,
          valueKey: const ValueKey('where-save'),
          onTap: () => taps++,
        ),
      );
      expect(find.byKey(const ValueKey('destination-save')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('where-save')));
      expect(taps, 2);
    });

    testWidgets('off or busy: no tap; busy draws the ring', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DestSaveButton(
          label: 'Saving…',
          busy: true,
          enabled: true,
          onTap: () => taps++,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(DestSaveButton));
      await pump(
        tester,
        DestSaveButton(
          label: 'Save',
          busy: false,
          enabled: false,
          onTap: () => taps++,
        ),
      );
      expect(
        tester.getSemantics(find.text('Save')),
        isSemantics(isButton: true, isEnabled: false),
      );
      await tester.tap(find.byType(DestSaveButton));
      expect(taps, 0);
    });

    testWidgets('the band: 44 by default, 48 when asked', (tester) async {
      await pump(
        tester,
        DestSaveButton(label: 'Save', busy: false, enabled: true, onTap: () {}),
      );
      expect(tester.getSize(find.byType(DestSaveButton)).height, 44);
      await pump(
        tester,
        DestSaveButton(
          label: 'Save',
          busy: false,
          enabled: true,
          minHit: 48,
          onTap: () {},
        ),
      );
      expect(tester.getSize(find.byType(DestSaveButton)).height, 48);
    });
  });

  group('KeepHitArea', () {
    testWidgets('44 unless asked for more', (tester) async {
      Widget area([double? height]) => height == null
          ? KeepHitArea(
              onTap: () {},
              child: const SizedBox(width: 20, height: 10),
            )
          : KeepHitArea(
              onTap: () {},
              minHeight: height,
              child: const SizedBox(width: 20, height: 10),
            );
      await pump(tester, area());
      expect(tester.getSize(find.byType(KeepHitArea)).height, 44);
      await pump(tester, area(48));
      expect(tester.getSize(find.byType(KeepHitArea)).height, 48);
    });
  });

  group('DestPreviewShell', () {
    testWidgets("one live region around the content, the sheet's margins", (
      tester,
    ) async {
      await pump(
        tester,
        const DestPreviewShell(
          icon: Icon(Icons.folder_outlined, size: 16),
          content: Text('Music › Daft Punk'),
        ),
      );
      expect(
        tester.getSemantics(find.text('Music › Daft Punk')),
        isSemantics(isLiveRegion: true),
      );
      Container card() => tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DestPreviewShell),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(card().margin, const EdgeInsets.fromLTRB(16, 12, 16, 4));
      expect(
        card().padding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
      expect((card().decoration! as BoxDecoration).color, VelvetColors.raised);

      await pump(
        tester,
        const DestPreviewShell(
          compact: true,
          icon: Icon(Icons.folder_outlined, size: 16),
          content: Text('Music › Daft Punk'),
        ),
      );
      expect(card().margin, const EdgeInsets.fromLTRB(16, 8, 16, 4));
      expect(
        card().padding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
    });

    testWidgets('margin and padding replace the defaults', (tester) async {
      await pump(
        tester,
        const DestPreviewShell(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          icon: Icon(Icons.folder_outlined, size: 18),
          content: Text('A song lands at'),
        ),
      );
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DestPreviewShell),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(card.margin, EdgeInsets.zero);
      expect(
        card.padding,
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    });
  });

  group('destErrorLine', () {
    testWidgets("the server's words: the error tone, announced", (
      tester,
    ) async {
      await pump(
        tester,
        destErrorLine('No such folder', const ValueKey('line')),
      );
      expect(find.byKey(const ValueKey('line')), findsOneWidget);
      expect(
        iconColor(tester, Icons.error_outline),
        keepTone(VelvetColors.error),
      );
      expect(
        tester.getSemantics(find.text('No such folder')),
        isSemantics(isLiveRegion: true),
      );
    });

    testWidgets('as typed: the warning tone, not announced', (tester) async {
      await pump(
        tester,
        destErrorLine('Bad layout', const ValueKey('line'), warning: true),
      );
      expect(
        iconColor(tester, Icons.warning_amber_rounded),
        keepTone(VelvetColors.warning),
      );
      expect(
        tester.getSemantics(find.text('Bad layout')),
        isSemantics(isLiveRegion: false),
      );
    });
  });

  group('text helpers', () {
    test('destToken spells a variable as a layout does', () {
      expect(destToken('ARTIST'), '{{ARTIST}}');
    });

    test('destHold: no-break spaces, a word joiner after each hyphen', () {
      expect(
        destHold('01 - Rooftop Cypher.mp3'),
        '01\u00A0-\u2060\u00A0Rooftop\u00A0Cypher.mp3',
      );
    });

    testWidgets('destInsertVar: at the caret, over a selection, at the end '
        'without one — the caret after it, the field focused', (tester) async {
      final field = TextEditingController(text: 'Music/');
      final focus = FocusNode();
      addTearDown(field.dispose);
      addTearDown(focus.dispose);
      await pump(tester, TextField(controller: field, focusNode: focus));

      // Never had a caret: the end.
      expect(field.selection.isValid, isFalse);
      destInsertVar(field, focus, '{{ARTIST}}');
      await tester.pump();
      expect(field.text, 'Music/{{ARTIST}}');
      expect(field.selection, const TextSelection.collapsed(offset: 16));
      expect(focus.hasFocus, isTrue);

      // At the caret.
      field.selection = const TextSelection.collapsed(offset: 6);
      destInsertVar(field, focus, '{{YEAR}} ');
      expect(field.text, 'Music/{{YEAR}} {{ARTIST}}');
      expect(field.selection, const TextSelection.collapsed(offset: 15));

      // Over a selection.
      field.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      destInsertVar(field, focus, '{{ALBUM}}');
      expect(field.text, '{{ALBUM}}/{{YEAR}} {{ARTIST}}');
      expect(field.selection, const TextSelection.collapsed(offset: 9));
    });

    test("destLayoutProblem: the validator's codes in words", () {
      final l = lookupAppLocalizations(const Locale('en'));
      const vars = ['ARTIST', 'ALBUM'];
      String words(String layout) =>
          destLayoutProblem(l, validateLayout(layout), vars);

      // An unknown variable is named as it was typed.
      expect(
        words('{{ title }}'),
        l.discoverDestErrUnknownVar('{{ title }}', 'ARTIST, ALBUM'),
      );
      expect(
        destLayoutProblem(
          l,
          const LayoutCheck.bad('unknown_variable', variable: 'TITLE'),
          vars,
        ),
        l.discoverDestErrUnknownVar('{{TITLE}}', 'ARTIST, ALBUM'),
      );
      expect(words('{ARTIST}'), l.discoverDestErrBraces('{{ARTIST}}'));
      expect(words('/Music'), l.discoverDestErrAbsolute);
      expect(words('a/../b'), l.discoverDestErrTraversal);
      expect(words('C:'), l.discoverDestErrDrive);
      expect(words('x/C:/y'), l.discoverDestErrDrive);
      expect(words('a' * 501), l.discoverDestErrTooLong(kMaxLayoutLength));
      expect(
        destLayoutProblem(l, const LayoutCheck.bad('something_new'), vars),
        l.discoverDestErrGeneric,
      );
    });

    testWidgets('destReveal: up to 120 under the line, less in a short form, '
        'none when the form has no room', (tester) async {
      late BuildContext context;
      Future<void> at(double scale) => pump(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
        textScale: scale,
      );

      await at(1);
      expect(
        destReveal(context, 400),
        const EdgeInsets.only(top: 16, bottom: 120),
      );
      expect(
        destReveal(context, 100),
        const EdgeInsets.only(top: 16, bottom: 60),
      );
      expect(destReveal(context, 20), const EdgeInsets.only(top: 16));
      // Large text: a taller line leaves less under it.
      await at(2);
      expect(
        destReveal(context, 100),
        const EdgeInsets.only(top: 16, bottom: 36),
      );
    });
  });
}
