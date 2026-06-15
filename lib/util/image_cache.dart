import 'dart:ui' as ui;

/// Physical-pixel decode dimension for showing album art at [logicalSize]
/// logical pixels. Pass it as `Image.network(..., cacheWidth: artCacheSize(n))`
/// so the engine decodes the art at display resolution instead of holding the
/// full-resolution source bitmap in the image cache — cutting memory use and
/// decode jank on art-heavy scrolling lists (the album grid, the queue, browser
/// thumbnails).
///
/// Scales by the device pixel ratio so the decode stays crisp on high-density
/// screens. Reads the implicit view's DPR rather than a MediaQuery so it also
/// works from the context-free render helpers (DisplayItem.getAlbumThumb, the
/// player panel's shared _albumArt). Falls back to the logical size when no view
/// is attached yet — the decode is still bounded, just potentially a touch soft.
int artCacheSize(double logicalSize) {
  final dpr = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
  return (logicalSize * dpr).round();
}
