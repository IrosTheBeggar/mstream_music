// Shared media-UI helpers, de-duplicated from player_panel / queue_list /
// more_actions_sheet (each used to carry its own near-identical copy).

import 'package:flutter/material.dart';

import '../theme/velvet_theme.dart';

/// Formats a [Duration] as `m:ss`, `mm:ss`, or `h:mm:ss`.
///
/// [padMinutes] pads the minutes field to two digits when there is no hours
/// component — the player's position readout wants `03:45`, while track-duration
/// columns read more naturally as `3:45`.
String formatDuration(Duration d, {bool padMinutes = true}) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '${padMinutes ? m.toString().padLeft(2, '0') : m}:$s';
}

/// The shared album-art placeholder (a raised tile + music-note glyph) shown
/// while artwork loads, on a decode error, or when a track has no art.
/// [iconSize] scales the glyph to the tile it fills.
Widget albumArtFallback({double iconSize = 20}) => Container(
      color: VelvetColors.raised,
      child: Icon(Icons.music_note,
          color: VelvetColors.textSecondary, size: iconSize),
    );

/// Physical-pixel decode cap for album art shown at [logicalSize] dp on the
/// current display. Pass this as `Image.network`'s `cacheWidth` so a large
/// server image is downsampled at decode time to the size it's actually drawn
/// at — instead of holding a full-resolution bitmap in memory (and re-uploading
/// it to the GPU) for a small thumbnail. Passing only `cacheWidth` lets Flutter
/// infer the height, preserving aspect ratio.
int artCacheWidth(BuildContext context, double logicalSize) =>
    (logicalSize * MediaQuery.devicePixelRatioOf(context)).ceil();
