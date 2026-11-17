import 'package:material_ui/material_ui.dart';

import '../objects/play_event.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/image_cache.dart';
import '../util/media_format.dart';
import '../util/stream_url.dart';

/// A seed's album art: a [size] square with corners rounded by 6, as the Seeds
/// page's rows draw it (40 px).
///
/// The art URL is built here, at draw time, from the song's art file and its
/// server's live record. A seed stores only the file: a built URL carries the
/// token and, on an iroh server, a loopback port that changes every session,
/// so a stored one would go stale. A song with no art, a server that no
/// longer resolves, an image still loading or one that fails all show the
/// shared placeholder. Decorative: the row's own label names the song.
class SeedArt extends StatelessWidget {
  final TrackFacts song;
  final double size;

  const SeedArt({super.key, required this.song, required this.size});

  @override
  Widget build(BuildContext context) =>
      _seedImage(song, size, radius: SeedTiles._radius);
}

/// The newest seeds' art in an overlapping row, as the Seeds rows on the Auto
/// DJ screen (26 px) and in quick config (24 px) show it.
///
/// Each tile is a [size] square with a 2 px [ring] in the colour of the card
/// it sits on, and each next tile starts 8 px over the one before and is
/// drawn on top of it, so the ring cuts a clean edge into its neighbour.
/// [songs] come newest first, as AutoDjSeeds.tiles gives them, so the newest
/// is the leftmost. None draws nothing. Decorative: the row's title says
/// Seeds.
class SeedTiles extends StatelessWidget {
  final List<TrackFacts> songs;
  final double size;
  final Color ring;

  const SeedTiles(
      {super.key, required this.songs, required this.size, required this.ring});

  // The board's shape: each tile tucked 8 px under the next, a 2 px ring, the
  // outer corners rounded by 6 (and so the art's inner ones by 4).
  static const double _overlap = 8;
  static const double _ringWidth = 2;
  static const double _radius = 6;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final step = size - _overlap;
    final art = size - 2 * _ringWidth;
    // A tile with no art yet, or none at all, shows the shared placeholder,
    // which is filled with the raised colour. On a ring of that very colour
    // (quick config's popover) its square would vanish and leave a bare
    // note, so there it takes the border colour, one step off the ring.
    final fill = ring == VelvetColors.raised ? VelvetColors.border : null;
    return ExcludeSemantics(
      child: SizedBox(
        width: size + step * (songs.length - 1),
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < songs.length; i++)
              Positioned(
                left: step * i,
                top: 0,
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(_ringWidth),
                  decoration: BoxDecoration(
                    color: ring,
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                  child: _seedImage(songs[i], art,
                      radius: _radius - _ringWidth, fill: fill),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// [song]'s art as a [size] square rounded by [radius]; see [SeedArt] for why
// the URL is built here and when the placeholder shows. [fill] is the
// placeholder's colour, the shared one's unless given.
Widget _seedImage(TrackFacts song, double size,
    {required double radius, Color? fill}) {
  final server = ServerManager().byLocalname(song.server);
  final art = song.artFile;
  Widget placeholder() => albumArtFallback(iconSize: size * 0.5, color: fill);
  return SizedBox(
    width: size,
    height: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: server == null || art == null || art.isEmpty
          ? placeholder()
          : Image.network(
              buildAlbumArtUrl(server, art),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: artCacheSize(size),
              excludeFromSemantics: true,
              // The placeholder until the first frame, so a row never shows a
              // blank square while its art loads.
              frameBuilder: (_, child, frame, sync) =>
                  frame == null && !sync ? placeholder() : child,
              errorBuilder: (_, _, _) => placeholder(),
            ),
    ),
  );
}
