// Beat matching's tempo windows (util/bpm_windows.dart): the tempo, half it
// and double it, each ± the tolerance — what Auto DJ sends around the
// playing track and an Instant mix page around its seed.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/bpm_windows.dart';

void main() {
  test('the tempo, half and double, each ± the tolerance', () {
    expect(bpmWindows(120, 8), [
      {'min': 112, 'max': 128},
      {'min': 52, 'max': 68},
      {'min': 232, 'max': 248},
    ]);
  });

  test('an odd tempo rounds its half (Dolo, 87 BPM)', () {
    expect(bpmWindows(87, 8), [
      {'min': 79, 'max': 95},
      {'min': 36, 'max': 52},
      {'min': 166, 'max': 182},
    ]);
  });

  test("Auto DJ's wide windows are the same three, two BPM wider", () {
    final tight = bpmWindows(100, 8);
    final wide = bpmWindows(100, 10);
    for (var i = 0; i < 3; i++) {
      expect(wide[i]['min'], tight[i]['min']! - 2);
      expect(wide[i]['max'], tight[i]['max']! + 2);
    }
  });
}
