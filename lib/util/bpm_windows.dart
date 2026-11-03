// bpm_windows.dart — Beat matching's tempo windows, as random-songs'
// `bpmRanges` (and the Instant mix route's, which takes the same key): one
// centered on a song's tempo, one at half-tempo, one at double. The server
// OR-s them together, so a 120-BPM song matches tracks at 112–128, 52–68,
// or 232–248 (with tolerance=8). Half and double cover the common DJ
// practice of mixing across octaves.
//
// Auto DJ builds them around the playing track (audio_stuff's autoDJ), the
// mix page around its seed song (MixFilters.toRequest).

/// The three windows around [bpm], each ± [tolerance] BPM.
List<Map<String, int>> bpmWindows(int bpm, int tolerance) {
  final half = (bpm / 2).round();
  final dbl = bpm * 2;
  return [
    {'min': bpm - tolerance, 'max': bpm + tolerance},
    {'min': half - tolerance, 'max': half + tolerance},
    {'min': dbl - tolerance, 'max': dbl + tolerance},
  ];
}
