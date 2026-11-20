// A snackbar's action ("Undo", "OK", "Open settings") reads on the snackbar
// in every palette and with any accent: the accent where it reaches 4.5:1
// on the snackbar's ground, the snackbar's own text colour where it does
// not. Left to Material it fell to onPrimary — black on the dark palette's
// grey snackbar.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final base = {
    for (final t in AppTheme.values) t.name: paletteFor(t),
  };
  final accents = [
    const Color(0xFFFFAB00), // amber, the default
    const Color(0xFF8B5CF6), // purple
    const Color(0xFF1B5E20), // a dark green
    const Color(0xFFFFEB3B), // a pale yellow
    const Color(0xFF0D47A1), // a deep blue
  ];

  test('every palette and accent: the action reads on the snackbar (4.5:1)', () {
    for (final e in base.entries) {
      for (final p in [e.value, for (final a in accents) e.value.withAccent(a)]) {
        final ink = snackBarActionInk(p);
        expect(contrast(ink, p.raised), greaterThanOrEqualTo(4.5),
            reason: '${e.key} with accent ${p.primary}');
        expect(buildAppTheme(p).snackBarTheme.actionTextColor, ink);
      }
    }
  });

  test('the accent where it reads, the text colour where it does not', () {
    final dark = paletteFor(AppTheme.dark);
    expect(snackBarActionInk(dark), dark.primary, reason: 'amber on the dark grey snackbar');
    final light = paletteFor(AppTheme.light);
    expect(snackBarActionInk(light), light.textPrimary, reason: 'amber on the light snackbar would be 1.7:1');
  });
}
