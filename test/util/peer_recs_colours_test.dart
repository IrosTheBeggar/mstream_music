// util/peer_recs_colours.dart — the Peer Recommendations page's colours in
// every palette (mStream docs/peer-recommendations-plan.md §4.2 PH3 and §5.1;
// the phone design digest §1). The tile and circle colours come from the
// server's hue, checked against the boards' CSS: Main.dc.html 35, 37, 44 and
// 133, Variants.dc.html 21 and 44 (hsl() converted with the CSS formula).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart'
    show keepInkOnPage;
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_colours.dart';

void main() {
  final velvet = paletteFor(AppTheme.velvet);
  final dark = paletteFor(AppTheme.dark);
  final light = paletteFor(AppTheme.light);
  tearDown(() => VelvetColors.setActive(dark));

  test('VelvetColors.brightness follows setActive for velvet, dark and light',
      () {
    VelvetColors.setActive(velvet);
    expect(VelvetColors.brightness, Brightness.dark);
    expect(VelvetColors.brightness, velvet.brightness);
    VelvetColors.setActive(light);
    expect(VelvetColors.brightness, Brightness.light);
    VelvetColors.setActive(dark);
    expect(VelvetColors.brightness, Brightness.dark);
    // The theme the app builds from the palette agrees.
    for (final p in [velvet, dark, light]) {
      VelvetColors.setActive(p);
      expect(buildAppTheme(p).brightness, VelvetColors.brightness);
    }
  });

  test('peerLightGround is the Light palette only', () {
    VelvetColors.setActive(velvet);
    expect(peerLightGround(), isFalse);
    VelvetColors.setActive(dark);
    expect(peerLightGround(), isFalse);
    VelvetColors.setActive(light);
    expect(peerLightGround(), isTrue);
  });

  group('tiles (§5.1)', () {
    test('dark: field hsl(203 22% 24%), ink hsl(203 30% 72%) (M:44)', () {
      expect(peerTileField(203, light: false), const Color(0xFF30404B));
      expect(peerTileInk(203, light: false), const Color(0xFFA2BDCD));
    });

    test('light: field hsl(203 28% 86%), ink hsl(203 30% 32%) (V:44)', () {
      expect(peerTileField(203, light: true), const Color(0xFFD1DEE5));
      expect(peerTileInk(203, light: true), const Color(0xFF39576A));
    });

    test('the tile colours read the flag, not the palette', () {
      VelvetColors.setActive(light);
      expect(peerTileField(203, light: false), const Color(0xFF30404B));
      VelvetColors.setActive(dark);
      expect(peerTileField(203, light: true), const Color(0xFFD1DEE5));
    });

    test('they match HSLColor for every hue', () {
      for (var h = 0; h < 360; h += 7) {
        final d = h.toDouble();
        expect(peerTileField(h, light: false),
            HSLColor.fromAHSL(1, d, .22, .24).toColor());
        expect(peerTileInk(h, light: false),
            HSLColor.fromAHSL(1, d, .30, .72).toColor());
        expect(peerTileField(h, light: true),
            HSLColor.fromAHSL(1, d, .28, .86).toColor());
        expect(peerTileInk(h, light: true),
            HSLColor.fromAHSL(1, d, .30, .32).toColor());
      }
    });

    test('a hue out of 0–359 folds like the webapp, never throws', () {
      expect(peerTileField(360, light: false), peerTileField(0, light: false));
      expect(peerTileField(563, light: true), peerTileField(203, light: true));
      expect(peerTileInk(-157, light: false), peerTileInk(203, light: false));
      expect(peerCircleOnline(570), peerCircleOnline(210));
    });
  });

  group('peer circles (the same in every theme)', () {
    for (final MapEntry(key: name, value: p)
        in {'velvet': velvet, 'dark': dark, 'light': light}.entries) {
      test(name, () {
        VelvetColors.setActive(p);
        // M:35 online, M:37 offline, M:133 adding.
        expect(peerCircleOnline(210), const Color(0xFF90B8DF));
        expect(peerCircleOffline(140), const Color(0xFF4F9265));
        expect(peerCircleAdding(330), const Color(0x59DF90B8));
        expect(peerCircleAdding(330).withValues(alpha: 1),
            peerCircleOnline(330));
      });
    }
  });

  group('page tokens', () {
    test('dark (Main board)', () {
      VelvetColors.setActive(dark);
      expect(peerRing(), const Color(0xFFFFAB00));
      expect(peerRing(), VelvetColors.primary);
      expect(peerInk(), keepInkOnPage());
      expect(peerInk(), const Color(0xFFFFAB00));
      expect(peerOnlineDot(), const Color(0xFF34D399));
      expect(peerOnlineDot(), VelvetColors.success);
      expect(peerAllFill(), const Color(0xFF2A2A2A));
      expect(peerAllFill(), VelvetColors.raised);
      expect(peerShadow(), const Color(0x80000000));
    });

    test('light (V:21: --ring, --accent #1A1A1A, --allfill #FFF, --online '
        '#16A34A, --pshadow .28)', () {
      VelvetColors.setActive(light);
      expect(peerRing(), const Color(0xFF1A1A1A));
      expect(peerRing(), VelvetColors.textPrimary);
      expect(peerInk(), const Color(0xFF1A1A1A));
      expect(peerOnlineDot(), const Color(0xFF16A34A));
      expect(peerOnlineDot(), isNot(VelvetColors.success));
      expect(peerAllFill(), const Color(0xFFFFFFFF));
      expect(peerAllFill(), VelvetColors.card);
      expect(peerShadow(), const Color(0x47000000));
    });

    test('velvet is a dark ground: primary ring, the Keep ink', () {
      VelvetColors.setActive(velvet);
      expect(peerRing(), velvet.primary);
      expect(peerInk(), keepInkOnPage());
      expect(peerOnlineDot(), velvet.success);
      expect(peerAllFill(), velvet.raised);
      expect(peerShadow(), const Color(0x80000000));
    });

    test('a custom accent moves the dark ring with it', () {
      final teal = dark.withAccent(const Color(0xFF14B8A6));
      VelvetColors.setActive(teal);
      expect(peerRing(), teal.primary);
      expect(peerInk(), keepInkOnPage());
      final lightTeal = light.withAccent(const Color(0xFF14B8A6));
      VelvetColors.setActive(lightTeal);
      expect(peerRing(), const Color(0xFF1A1A1A));
      expect(peerInk(), const Color(0xFF1A1A1A));
    });
  });
}
