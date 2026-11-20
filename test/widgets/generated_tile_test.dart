// widgets/generated_tile.dart — a lead's tile on the Peer Recommendations
// page (mStream docs/peer-recommendations-plan.md §4.2 PH3 and §5.1): the
// server's letter drawn verbatim at 45 % of the side, the field and ink from
// the server's hue in the theme's colours (boards M:44 and V:44, hue 203), a
// plain raised square for a lead with no tile, and earned art that keeps the
// generated face until it loads and falls back to it when it cannot load.

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/image_cache.dart';
import 'package:mstream_music/widgets/generated_tile.dart';

void main() {
  final dark = paletteFor(AppTheme.dark);
  final light = paletteFor(AppTheme.light);
  tearDown(() => VelvetColors.setActive(dark));

  Widget host(Widget tile, {double textScale = 1}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: Center(child: tile)),
        ),
      );

  Text letterOf(WidgetTester t, String letter) => t.widget<Text>(
      find.descendant(
          of: find.byType(GeneratedTile), matching: find.text(letter)));

  Color fieldOf(WidgetTester t) => t
      .widget<ColoredBox>(find.descendant(
          of: find.byType(GeneratedTile), matching: find.byType(ColoredBox)))
      .color;

  group('draws the letter verbatim at 45 %', () {
    testWidgets('79 at 175, w600, height 1.0 (M:44)', (t) async {
      await t.pumpWidget(
          host(const GeneratedTile(size: 175, hue: 203, letter: 'H')));
      final text = letterOf(t, 'H');
      expect(text.style!.fontSize, 79);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(text.style!.height, 1.0);
      expect(text.maxLines, 1);
      expect(t.getSize(find.byType(GeneratedTile)), const Size(175, 175));
    });

    testWidgets('75 at 167.5, the small phone (V:118)', (t) async {
      await t.pumpWidget(
          host(const GeneratedTile(size: 167.5, hue: 203, letter: 'H')));
      expect(letterOf(t, 'H').style!.fontSize, 75);
      expect(t.getSize(find.byType(GeneratedTile)), const Size(167.5, 167.5));
    });

    testWidgets('as sent: never upper-cased, never trimmed or folded',
        (t) async {
      for (final letter in ['ß', '坂', 'É', '1', 'h']) {
        await t.pumpWidget(
            host(GeneratedTile(size: 175, hue: 248, letter: letter)));
        expect(letterOf(t, letter).data, letter);
      }
    });

    testWidgets('an empty letter draws the field alone', (t) async {
      await t.pumpWidget(host(const GeneratedTile(size: 175, hue: 61)));
      expect(fieldOf(t), HSLColor.fromAHSL(1, 61, .22, .24).toColor());
      expect(letterOf(t, '').data, '');
    });

    testWidgets('the band passes its own size', (t) async {
      await t.pumpWidget(host(const GeneratedTile(
          size: 44,
          hue: 203,
          letter: 'H',
          radius: VelvetColors.radiusSmall,
          letterSize: 20)));
      expect(letterOf(t, 'H').style!.fontSize, 20);
      expect(t.getSize(find.byType(GeneratedTile)), const Size(44, 44));
    });

    testWidgets('large text leaves the tile and its letter alone (V:158)',
        (t) async {
      await t.pumpWidget(host(
          const GeneratedTile(size: 175, hue: 203, letter: 'H'),
          textScale: 1.3));
      expect(t.getSize(find.byType(GeneratedTile)), const Size(175, 175));
      // The painted size, not just the style's: the scaler is off.
      expect(t.getSize(find.text('H')).height, 79);
    });

    testWidgets('the tile says nothing to a screen reader (the card does)',
        (t) async {
      final semantics = t.ensureSemantics();
      // A bare letter would be read out.
      await t.pumpWidget(host(const Text('H')));
      expect(find.bySemanticsLabel('H'), findsOneWidget);
      await t.pumpWidget(
          host(const GeneratedTile(size: 175, hue: 203, letter: 'H')));
      expect(find.bySemanticsLabel('H'), findsNothing);
      semantics.dispose();
    });
  });

  group('dark and light colours from the hue', () {
    testWidgets('dark: hsl(203 22% 24%) field, hsl(203 30% 72%) ink (M:44)',
        (t) async {
      VelvetColors.setActive(dark);
      await t.pumpWidget(
          host(const GeneratedTile(size: 175, hue: 203, letter: 'H')));
      expect(fieldOf(t), const Color(0xFF30404B));
      expect(letterOf(t, 'H').style!.color, const Color(0xFFA2BDCD));
    });

    testWidgets('light: hsl(203 28% 86%) field, hsl(203 30% 32%) ink (V:44)',
        (t) async {
      VelvetColors.setActive(light);
      await t.pumpWidget(
          host(const GeneratedTile(size: 175, hue: 203, letter: 'H')));
      expect(fieldOf(t), const Color(0xFFD1DEE5));
      expect(letterOf(t, 'H').style!.color, const Color(0xFF39576A));
    });

    testWidgets('velvet is a dark ground', (t) async {
      VelvetColors.setActive(paletteFor(AppTheme.velvet));
      await t.pumpWidget(
          host(const GeneratedTile(size: 175, hue: 203, letter: 'H')));
      expect(fieldOf(t), const Color(0xFF30404B));
    });

    testWidgets('a theme switch repaints the tile', (t) async {
      VelvetColors.setActive(dark);
      await t.pumpWidget(
          host(const GeneratedTile(size: 175, hue: 203, letter: 'H')));
      expect(fieldOf(t), const Color(0xFF30404B));
      VelvetColors.setActive(light);
      // Not const: a rebuild reads the palette again, as the app's theme
      // switch rebuilds the tree.
      await t.pumpWidget(
          host(GeneratedTile(size: 175, hue: 203, letter: 'H')));
      expect(fieldOf(t), const Color(0xFFD1DEE5));
    });

    testWidgets('the radius clips the corners (12 by default)', (t) async {
      await t.pumpWidget(
          host(const GeneratedTile(size: 175, hue: 203, letter: 'H')));
      expect(t.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
          BorderRadius.circular(12));
      await t.pumpWidget(host(const GeneratedTile(
          size: 44, hue: 203, letter: 'H', radius: VelvetColors.radiusSmall)));
      expect(t.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
          BorderRadius.circular(7));
    });
  });

  group('no tile → raised, no letter', () {
    for (final MapEntry(key: name, value: p)
        in {'dark': dark, 'light': light}.entries) {
      testWidgets(name, (t) async {
        VelvetColors.setActive(p);
        await t.pumpWidget(host(const GeneratedTile(size: 175, letter: 'H')));
        expect(fieldOf(t), p.raised);
        expect(
            find.descendant(
                of: find.byType(GeneratedTile), matching: find.byType(Text)),
            findsNothing);
        expect(t.getSize(find.byType(GeneratedTile)), const Size(175, 175));
      });
    }
  });

  group('art shows the image; a broken one falls back', () {
    testWidgets('the art covers the tile, decoded at its size', (t) async {
      final art = Uri.parse('https://cdn.example/cover/ok-1.jpg');
      await t.pumpWidget(host(
          GeneratedTile(size: 175, hue: 203, letter: 'H', art: art)));
      final image = t.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.width, 175);
      expect(image.height, 175);
      final provider = image.image;
      expect(provider, isA<ResizeImage>());
      final resize = provider as ResizeImage;
      expect(resize.width, artCacheSize(175));
      expect((resize.imageProvider as NetworkImage).url, art.toString());
    });

    testWidgets('keeps the generated face while earned art loads', (t) async {
      final art = Uri.parse('https://cdn.example/cover/slow-1.jpg');
      await t.pumpWidget(host(
          GeneratedTile(size: 175, hue: 203, letter: 'H', art: art)));
      // The first frame, before any byte of the cover arrived: the field
      // and its letter, not an empty square.
      expect(find.byType(Image), findsOneWidget);
      expect(letterOf(t, 'H').style!.fontSize, 79);
      expect(fieldOf(t), const Color(0xFF30404B));
      expect(
          find.descendant(
              of: find.byType(GeneratedTile), matching: find.byType(RawImage)),
          findsNothing);
      // The test's HTTP answers 400, so the cover never draws a frame: the
      // face is still there once everything settled, through errorBuilder.
      await t.pumpAndSettle();
      expect(letterOf(t, 'H').data, 'H');
      expect(fieldOf(t), const Color(0xFF30404B));
    });

    testWidgets('a cover already in the cache swaps in at once', (t) async {
      final art = Uri.parse('https://cdn.example/cover/cached-1.jpg');
      final side = artCacheSize(175);
      final picture = (await t.runAsync(
          () => createTestImage(width: side, height: side)))!;
      // The provider the tile builds, keyed as the tile keys it.
      final provider =
          ResizeImage(NetworkImage(art.toString()), width: side);
      final key = await provider.obtainKey(ImageConfiguration.empty);
      imageCache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
              SynchronousFuture(ImageInfo(image: picture))));
      addTearDown(imageCache.clear);
      await t.pumpWidget(host(
          GeneratedTile(size: 175, hue: 203, letter: 'H', art: art)));
      final raw = t.widget<RawImage>(find.descendant(
          of: find.byType(GeneratedTile), matching: find.byType(RawImage)));
      expect(raw.image, isNotNull);
      expect(find.text('H'), findsNothing);
      expect(
          find.descendant(
              of: find.byType(GeneratedTile),
              matching: find.byType(ColoredBox)),
          findsNothing);
    });

    testWidgets('a broken image draws the generated face', (t) async {
      // flutter_test answers every request 400, so the art fails to load.
      final art = Uri.parse('https://cdn.example/cover/broken-1.jpg');
      VelvetColors.setActive(light);
      await t.pumpWidget(host(
          GeneratedTile(size: 175, hue: 203, letter: 'H', art: art)));
      for (var i = 0; i < 5 && find.text('H').evaluate().isEmpty; i++) {
        await t.pump();
      }
      expect(letterOf(t, 'H').style!.fontSize, 79);
      expect(fieldOf(t), const Color(0xFFD1DEE5));
    });

    testWidgets('a broken image with no tile falls back to raised', (t) async {
      final art = Uri.parse('https://cdn.example/cover/broken-2.jpg');
      await t.pumpWidget(host(GeneratedTile(size: 175, art: art)));
      for (var i = 0;
          i < 5 &&
              find
                  .descendant(
                      of: find.byType(GeneratedTile),
                      matching: find.byType(ColoredBox))
                  .evaluate()
                  .isEmpty;
          i++) {
        await t.pump();
      }
      expect(fieldOf(t), VelvetColors.raised);
    });
  });
}
