// screens/discovery/peer_recs_strip.dart — the strip's own words (All,
// Adding…, Try again, No room) in every language, drawn with the real
// Roboto rather than the test font's 1 em squares, so their widths and line
// breaks are a phone's. An item is 68 px wide at text 1.0 and 88 at 1.3,
// and its label is 12 / w600 on two lines. A word wider than the item used
// to be broken by character ("Wird / hinzugefü", "Добавлени / е…"), so
// every word of every language must fit the item at both sizes, in Roboto
// Medium and in Roboto Bold (a w600 label is drawn in one or the other, or
// between them on a variable Roboto). And a word that still does not fit
// (a longer translation, a larger text size) is scaled down whole, never
// broken.
//
// Roboto covers Latin and Cyrillic. Japanese and Chinese fall back to the
// test font's squares, about a CJK glyph's width, and break between any two
// characters as they do on a phone.
//
// A peer's name is the server's, of any length. A word of it a little wider
// than the item shrinks the label whole, but only down to 0.8 of its size;
// a longer one wraps at the item's width as it did. The stage's names are
// checked in Roboto and, where the machine has it (macOS), in SF Semibold,
// the iPhone's font: the live walk drew "Lighthous / e Tapes" there. Each
// name is drawn on a shelf peer and on a "+", as the walk drew it on both,
// at text 1.0 and 1.3, at Android's non-linear 130 % and 200 %, and in SF
// with the system's Bold Text on.

import 'dart:io';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/app_localizations_de.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/screens/discovery/peer_recs_strip.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';

import 'peer_recs_strip_scalers.dart';

/// The Flutter SDK's Roboto files (bin/cache/artifacts/material_fonts):
/// from FLUTTER_ROOT, else from the flutter_tester running this test,
/// which lives under the same bin/cache/artifacts.
Directory _materialFonts() {
  final candidates = <Directory>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      Directory('$root/bin/cache/artifacts/material_fonts'),
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    candidates.add(Directory('${dir.path}/material_fonts'));
    dir = dir.parent;
  }
  for (final d in candidates) {
    if (File('${d.path}/Roboto-Regular.ttf').existsSync()) return d;
  }
  throw StateError(
    "No Roboto found (looked for the Flutter SDK's material_fonts); these "
    'tests measure real text and cannot run with the test font.',
  );
}

/// One Roboto weight as a family of its own, so the label can be drawn in
/// exactly that weight.
const String kMedium = 'Roboto Medium (strip test)';
const String kBold = 'Roboto Bold (strip test)';

/// The iPhone's system font, as macOS ships it: one variable font with
/// weight and optical-size axes. Other machines skip its tests.
final File kSfFile = File('/System/Library/Fonts/SFNS.ttf');
const String kSf = 'SF (strip test)';

/// The label as an iPhone draws it: SF at its Semibold weight (590) and its
/// smallest optical size (17, the text cut). With the label's 0.25 px
/// letter spacing it matches the live walk's screenshot to a pixel
/// ("Lighthous" 118 px wide at 2x, "Kitchen" 89, "Rooftop" 94).
const List<FontVariation> kSfSemibold = [
  FontVariation('wght', 590),
  FontVariation('opsz', 17),
];

/// SF at its text optical size with no weight of its own: the variable
/// font then takes its weight from the label's, w600 or, with Bold Text
/// on, w700.
const List<FontVariation> kSfText = [FontVariation('opsz', 17)];

Future<void> _load(String family, File file) async {
  final bytes = file.readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}

Future<void> _loadFonts() async {
  final dir = _materialFonts();
  await _load(kMedium, File('${dir.path}/Roboto-Medium.ttf'));
  await _load(kBold, File('${dir.path}/Roboto-Bold.ttf'));
  if (kSfFile.existsSync()) await _load(kSf, kSfFile);
}

/// Kana and CJK ideographs: text that breaks between any two characters.
final RegExp _cjk = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]');

final String kAdding = 'a1' * 32;
final String kFailed = 'b2' * 32;
final String kNoRoom = 'c3' * 32;

/// All, then one addable peer in each Add state that draws the app's own
/// word: Adding…, Try again, No room.
final List<PeerStripItem> kOwnWords = [
  const PeerStripItem(
      kind: PeerItemKind.all, selected: true, act: PeerItemAct.tab),
  PeerStripItem(
    kind: PeerItemKind.add,
    id: kAdding,
    label: 'Static Garden',
    monogram: 'SG',
    hue: 140,
    online: true,
    state: PeerAddView.adding,
    act: PeerItemAct.none,
  ),
  PeerStripItem(
    kind: PeerItemKind.add,
    id: kFailed,
    label: 'Rooftop FM',
    monogram: 'RF',
    hue: 12,
    online: true,
    state: PeerAddView.failed,
    act: PeerItemAct.add,
  ),
  PeerStripItem(
    kind: PeerItemKind.add,
    id: kNoRoom,
    label: 'Quiet Room',
    monogram: 'QR',
    hue: 50,
    online: true,
    state: PeerAddView.noRoom,
    act: PeerItemAct.none,
  ),
];

/// The stage's peer names, as the strip labels them.
const List<String> kStageNames = [
  'Basement Hi-Fi',
  'Kitchen Radio',
  'Attic Tapes',
  'mStream · 3f9a',
  'Lighthouse Tapes',
  'Static Garden',
  'Rooftop FM',
];

/// Names with a word a little wider than the item in Roboto too: each needs
/// 0.82 to 0.94 of its size at text 1.0 and 1.3.
const List<String> kWideNames = [
  'Philharmonic Hall',
  'Underground Radio',
  'Soundsystem',
  'Headquarters',
  'Thunderstruck',
];

/// A long single word (15 letters, it needs 0.71 or less) and a 30-letter
/// name (about 0.39): too small to read shrunk, so they wrap as they are.
const String kLongWord = 'Wohnzimmerradio';
const String kThirty = 'Funkhausarchivkellerstudiobibl';

/// One online shelf peer per name, its id `name` and the name's index,
/// then one addable peer per name with no Add yet (a "+"), its id `add`
/// and the index.
List<PeerStripItem> peersNamed(List<String> names) => [
      for (final (i, name) in names.indexed)
        PeerStripItem(
          kind: PeerItemKind.peer,
          id: 'name$i',
          label: name,
          monogram: name.substring(0, 2),
          hue: 30 * i,
          online: true,
          act: PeerItemAct.tab,
        ),
      for (final (i, name) in names.indexed)
        PeerStripItem(
          kind: PeerItemKind.add,
          id: 'add$i',
          label: name,
          monogram: name.substring(0, 2),
          hue: 30 * i,
          online: true,
          act: PeerItemAct.add,
        ),
    ];

/// German with longer words than the app's: the old "Adding…", one word
/// wider than the item, and one far wider.
class _WideGerman extends AppLocalizationsDe {
  @override
  String get peerRecsAdding => 'Wird hinzugefügt…';

  @override
  String get discoverPageRetry => 'Hinzufügen…';

  @override
  String get peerRecsNoRoom => 'Speicherplatzerschöpfung';
}

class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  const _Delegate(this.l);

  final AppLocalizations l;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(l);

  @override
  bool shouldReload(_Delegate old) => old.l != l;
}

void main() {
  setUpAll(_loadFonts);
  tearDown(() => VelvetColors.setActive(paletteFor(AppTheme.dark)));

  /// The strip of [items] (the app's own words unless given) in [locale] at
  /// [textScale] (or through [scaler]), its labels in [family] with
  /// [variations], on a view [width] wide, the system's Bold Text as
  /// [boldText] says, with the app's own theme otherwise.
  Future<void> pumpStrip(
    WidgetTester t, {
    required Locale locale,
    required String family,
    double textScale = 1,
    TextScaler? scaler,
    bool boldText = false,
    AppLocalizations? words,
    List<PeerStripItem>? items,
    List<FontVariation>? variations,
    double width = 1024,
  }) async {
    t.view.physicalSize = Size(width * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final theme = buildAppTheme(paletteFor(AppTheme.dark));
    var text = theme.textTheme.apply(fontFamily: family);
    if (variations != null) {
      // The label is drawn over the strip's Material's bodyMedium.
      text = text.copyWith(
          bodyMedium: text.bodyMedium!.copyWith(fontVariations: variations));
    }
    await t.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: [
        if (words != null) _Delegate(words),
        ...appLocalizationsDelegates,
      ],
      supportedLocales: appSupportedLocales,
      theme: theme.copyWith(textTheme: text),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: scaler ?? TextScaler.linear(textScale),
            boldText: boldText),
        child: child!,
      ),
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: PeerStripView(
              items: items ?? kOwnWords,
              onSelect: (_) {},
              onAdd: (_) {},
            ),
          ),
        ]),
      ),
    ));
  }

  Finder item(String? id) => find.byKey(ValueKey('peer-strip-${id ?? 'all'}'));
  Finder labelOf(String? id) =>
      find.descendant(of: item(id), matching: find.byType(Text)).last;
  RenderParagraph paragraphOf(WidgetTester t, String? id) =>
      t.renderObject<RenderParagraph>(find.descendant(
          of: labelOf(id), matching: find.byType(RichText)));

  /// The label's lines, as its own paragraph breaks them.
  List<String> linesOf(RenderParagraph p) {
    final text = p.text.toPlainText();
    final painter = TextPainter(
      text: p.text,
      textAlign: p.textAlign,
      textDirection: p.textDirection,
      textScaler: p.textScaler,
      maxLines: p.maxLines,
      ellipsis: '…',
      locale: p.locale,
    )..layout(maxWidth: p.constraints.maxWidth);
    final lines = <String>[];
    var offset = 0;
    while (offset < text.length) {
      final line = painter.getLineBoundary(TextPosition(offset: offset));
      if (line.end <= offset) break;
      lines.add(text.substring(line.start, line.end));
      offset = line.end;
    }
    painter.dispose();
    return lines;
  }

  /// The label is drawn whole: no line is cut short by the ellipsis, and
  /// no word is broken across two lines. A paragraph breaks inside a word
  /// only when the word is wider than the line (its narrowest unbreakable
  /// width is more than the width it was given); and in a language with
  /// spaces, every line after the first starts a new word.
  void expectWhole(WidgetTester t, String? id, String why) {
    final p = paragraphOf(t, id);
    final label = p.text.toPlainText();
    expect(p.didExceedMaxLines, isFalse, reason: '$why: "$label" is cut');
    expect(p.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(p.constraints.maxWidth),
        reason: '$why: a word of "$label" is wider than its line');
    if (!_cjk.hasMatch(label)) {
      final lines = linesOf(p);
      expect(lines.length, lessThanOrEqualTo(2), reason: '$why: $lines');
      var at = 0;
      for (final line in lines) {
        if (at > 0) {
          expect(label[at - 1].trim(), isEmpty,
              reason: '$why: "$label" breaks inside a word: $lines');
        }
        at += line.length;
      }
    }
  }

  group("every language's own words fit the item whole, at full size", () {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final family in [kMedium, kBold]) {
        for (final (scale, width) in [(1.0, 68.0), (1.3, 88.0)]) {
          testWidgets('$locale, ${family.split(' (').first}, text $scale',
              (t) async {
            await pumpStrip(t,
                locale: locale, family: family, textScale: scale);
            final l = lookupAppLocalizations(locale);
            for (final (id, words) in [
              (null, l.peerRecsAll),
              (kAdding, l.peerRecsAdding),
              (kFailed, l.discoverPageRetry),
              (kNoRoom, l.peerRecsNoRoom),
            ]) {
              final why = '$locale $family $scale';
              expect(t.widget<Text>(labelOf(id)).data, words, reason: why);
              expect(t.getSize(item(id)).width, width, reason: why);
              // The translation fits as it is: the guard below never has
              // to shrink it.
              expect(
                  find.ancestor(
                      of: labelOf(id), matching: find.byType(FittedBox)),
                  findsNothing,
                  reason: '$why: "$words" has a word wider than $width px');
              expectWhole(t, id, why);
            }
          });
        }
      }
    }
  });

  group('a word that is still too wide is scaled down whole, never broken',
      () {
    for (final (scale, width) in [(1.0, 68.0), (1.3, 88.0), (2.0, 136.0)]) {
      testWidgets('text $scale', (t) async {
        await pumpStrip(t,
            locale: const Locale('de'),
            family: kBold,
            textScale: scale,
            words: _WideGerman());
        for (final (id, words, lines) in [
          (kAdding, 'Wird hinzugefügt…', ['Wird ', 'hinzugefügt…']),
          (kFailed, 'Hinzufügen…', ['Hinzufügen…']),
          (kNoRoom, 'Speicherplatzerschöpfung', ['Speicherplatzerschöpfung']),
        ]) {
          final why = '"$words" at $scale';
          expect(t.widget<Text>(labelOf(id)).data, words, reason: why);
          expectWhole(t, id, why);
          // Broken only between words.
          expect(linesOf(paragraphOf(t, id)).map((s) => s.trimRight()),
              lines.map((s) => s.trimRight()),
              reason: why);
          // Shrunk to the item's width, and still inside the strip's two
          // label lines.
          final fitted =
              find.ancestor(of: labelOf(id), matching: find.byType(FittedBox));
          expect(fitted, findsOneWidget, reason: why);
          final box = t.getRect(fitted);
          expect(box.width, lessThanOrEqualTo(width + 0.01), reason: why);
          final whole = t.getRect(item(id));
          expect(box.left, greaterThanOrEqualTo(whole.left - 0.01));
          expect(box.right, lessThanOrEqualTo(whole.right + 0.01));
          expect(box.bottom, lessThanOrEqualTo(whole.bottom + 0.01),
              reason: why);
          // Centred under the circle.
          expect(box.center.dx,
              moreOrLessEquals(whole.center.dx, epsilon: .5),
              reason: why);
        }
        // All, short in every language, is never shrunk.
        expect(
            find.ancestor(of: labelOf(null), matching: find.byType(FittedBox)),
            findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  });

  /// How a peer's name is drawn: as it is, shrunk whole, or wrapped at the
  /// item's width.
  ///
  /// The rule, from the label's own paragraph: when its widest word fits
  /// the item, it is drawn as it is, whole. When that word needs 0.8 of its
  /// size or more, the label is shrunk by exactly that much, whole, as wide
  /// as the item and centred under the circle. Otherwise it keeps the
  /// item's width (a word wider than the line is then broken, an absurd
  /// name's lot). Every way, it stays inside the item.
  (String, double) expectName(
      WidgetTester t, String id, double width, String why) {
    final p = paragraphOf(t, id);
    final label = p.text.toPlainText();
    final widest = p.getMinIntrinsicWidth(double.infinity);
    final needs = width / widest.ceilToDouble();
    final fitted =
        find.ancestor(of: labelOf(id), matching: find.byType(FittedBox));
    final drawn = t.getRect(labelOf(id));
    final cell = t.getRect(item(id));
    expect(drawn.left, greaterThanOrEqualTo(cell.left - .01), reason: why);
    expect(drawn.right, lessThanOrEqualTo(cell.right + .01), reason: why);
    expect(drawn.bottom, lessThanOrEqualTo(cell.bottom + .01), reason: why);
    if (widest <= width) {
      expect(fitted, findsNothing, reason: '$why: "$label" fits');
      expectWhole(t, id, why);
      return ('fits', 1);
    }
    if (needs >= .8) {
      expect(fitted, findsOneWidget,
          reason: '$why: "$label" needs ${needs.toStringAsFixed(3)}');
      expectWhole(t, id, why);
      final scale = drawn.width / p.size.width;
      expect(scale, closeTo(needs, 1e-6), reason: why);
      expect(drawn.width, closeTo(width, .01), reason: why);
      expect(drawn.center.dx, closeTo(cell.center.dx, .5), reason: why);
      return ('shrunk', scale);
    }
    expect(fitted, findsNothing,
        reason: '$why: "$label" needs ${needs.toStringAsFixed(3)}');
    expect(p.size.width, closeTo(width, .01), reason: why);
    expect(drawn.width, closeTo(width, .01), reason: why);
    return ('wraps', 1);
  }

  /// Every name, each as one online shelf peer and as one "+".
  const allNames = [...kStageNames, ...kWideNames, kLongWord, kThirty];

  /// The strip of [allNames] at [scale] (or through [scaler]), and how each
  /// is drawn. A shelf peer and a "+" draw a name the same way.
  Future<Map<String, (String, double)>> drawNames(
    WidgetTester t, {
    required String family,
    double scale = 1,
    TextScaler? scaler,
    bool boldText = false,
    required double itemWidth,
    List<FontVariation>? variations,
  }) async {
    await pumpStrip(t,
        locale: const Locale('en'),
        family: family,
        textScale: scale,
        scaler: scaler,
        boldText: boldText,
        items: peersNamed(allNames),
        variations: variations,
        width: 5000);
    expect(t.takeException(), isNull);
    final why = '${family.split(' (').first} ${scaler ?? scale}'
        '${boldText ? ' bold' : ''}';
    final drawn = <String, (String, double)>{};
    for (final (i, name) in allNames.indexed) {
      for (final id in ['name$i', 'add$i']) {
        expect(t.getSize(item(id)).width, itemWidth, reason: '$why $id');
      }
      final shelf = expectName(t, 'name$i', itemWidth, '$why "$name"');
      final plus = expectName(t, 'add$i', itemWidth, '$why "+ $name"');
      expect(plus.$1, shelf.$1, reason: '$why "+ $name"');
      expect(plus.$2, closeTo(shelf.$2, 1e-9), reason: '$why "+ $name"');
      drawn[name] = shelf;
    }
    return drawn;
  }

  group("a peer's name keeps its words whole down to 0.8 of its size", () {
    for (final family in [kMedium, kBold]) {
      for (final (scale, width) in [(1.0, 68.0), (1.3, 88.0)]) {
        testWidgets('${family.split(' (').first}, text $scale', (t) async {
          final drawn = await drawNames(t,
              family: family, scale: scale, itemWidth: width);
          // Every stage name fits as it is.
          for (final name in kStageNames) {
            expect(drawn[name]!.$1, 'fits', reason: name);
          }
          // A word a little too wide shrinks the label whole.
          for (final name in kWideNames) {
            expect(drawn[name]!.$1, 'shrunk', reason: name);
            expect(drawn[name]!.$2, inInclusiveRange(.8, .95), reason: name);
          }
          // Past the floor the label wraps as it did: the long word over
          // two lines, the 30-letter name cut by its ellipsis.
          expect(drawn[kLongWord]!.$1, 'wraps');
          expect(drawn[kThirty]!.$1, 'wraps');
          expect(
              paragraphOf(t, 'name${allNames.indexOf(kLongWord)}')
                  .didExceedMaxLines,
              isFalse);
          expect(
              paragraphOf(t, 'name${allNames.indexOf(kThirty)}')
                  .didExceedMaxLines,
              isTrue);
        });
      }
    }

    // SF Semibold, the iPhone's font, where the machine has it.
    for (final (scale, width) in [(1.0, 68.0), (1.3, 88.0)]) {
      testWidgets('SF Semibold, text $scale', (t) async {
        final drawn = await drawNames(t,
            family: kSf,
            scale: scale,
            itemWidth: width,
            variations: kSfSemibold);
        // Every stage name is drawn whole: the walk's "Lighthous / e Tapes"
        // at text 1.0 is shrunk instead.
        for (final name in kStageNames) {
          expect(drawn[name]!.$1, isNot('wraps'), reason: name);
        }
        expect(drawn[kLongWord]!.$1, 'wraps');
        expect(drawn[kThirty]!.$1, 'wraps');
      }, skip: !kSfFile.existsSync());
    }

    // Android 14's text scaling is not linear. This scaler, shaped like its
    // tables, draws a 12 px font at the whole factor and a 68 px one at 68
    // (130 %) or about 72 (200 %). The item grows as its label does, 88
    // and 136 wide, so every name is drawn as at text 1.3 and 2.0. In a
    // 72 px item at 200 % "Basement", "mStream" and "Lighthouse" were
    // broken.
    for (final family in [kMedium, kBold]) {
      for (final (scaler, width) in [
        (AndroidFontScale.x13, 88.0),
        (AndroidFontScale.x20, 136.0),
      ]) {
        testWidgets('${family.split(' (').first}, $scaler', (t) async {
          final drawn = await drawNames(t,
              family: family, scaler: scaler, itemWidth: width);
          for (final name in kStageNames) {
            expect(drawn[name]!.$1, 'fits', reason: name);
          }
          for (final name in kWideNames) {
            expect(drawn[name]!.$1, 'shrunk', reason: name);
            expect(drawn[name]!.$2, inInclusiveRange(.8, .96), reason: name);
          }
          expect(drawn[kLongWord]!.$1, 'wraps');
          expect(drawn[kThirty]!.$1, 'wraps');
        });
      }
    }

    // With the system's Bold Text on, the label is drawn at w700, and SF's
    // bold is about 2 % wider than its semibold: "Lighthouse" is 68.38 px
    // at w600 and 69.92 at w700, at text 1.0. The label is measured in the
    // weight it is drawn in, so "Lighthouse Tapes" is shrunk to fit its
    // bold word. Laid out for its semibold word (69 px) it was broken.
    for (final (scale, width) in [(1.0, 68.0), (1.3, 88.0)]) {
      testWidgets('SF with Bold Text on, text $scale', (t) async {
        final drawn = await drawNames(t,
            family: kSf,
            scale: scale,
            boldText: true,
            itemWidth: width,
            variations: kSfText);
        // The label is drawn bold, and its bold word is wider than the
        // whole pixel its semibold word rounds up to.
        final p = paragraphOf(
            t, 'name${allNames.indexOf('Lighthouse Tapes')}');
        final style = p.text.style!;
        expect(style.fontWeight, FontWeight.w700);
        final semibold = TextPainter(
          text: TextSpan(
              text: 'Lighthouse',
              style: style.copyWith(fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
          textScaler: p.textScaler,
        )..layout();
        expect(semibold.width.ceilToDouble(),
            lessThan(p.getMinIntrinsicWidth(double.infinity)));
        semibold.dispose();
        expect(drawn['Lighthouse Tapes']!.$1, 'shrunk');
        for (final name in kStageNames) {
          expect(drawn[name]!.$1, isNot('wraps'), reason: name);
        }
        // Bold, "Headquarters" needs 0.78 of its size, past the floor.
        expect(drawn['Headquarters']!.$1, 'wraps');
        expect(drawn[kLongWord]!.$1, 'wraps');
        expect(drawn[kThirty]!.$1, 'wraps');
      }, skip: !kSfFile.existsSync());
    }
  });
}
