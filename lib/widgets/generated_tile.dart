// A lead's tile on the Peer Recommendations page (mStream
// docs/peer-recommendations-plan.md §4.2 PH3 and §5.1): the earned art when a
// preview brought some, else the generated face the server stamped, a field in
// the lead's hue with its letter in the middle.
//
// The tile is drawn verbatim: the server computes the hue and the letter, and
// the client only turns the hue into the theme's colours (peer_recs_colours).
// A lead with no tile at all draws a plain raised square with no letter.

import 'package:material_ui/material_ui.dart';

import '../theme/velvet_theme.dart';
import '../util/image_cache.dart' show artCacheSize;
import '../util/peer_recs_colours.dart';

class GeneratedTile extends StatelessWidget {
  const GeneratedTile({
    super.key,
    required this.size,
    this.hue,
    this.letter = '',
    this.art,
    this.radius = VelvetColors.radiusLarge,
    this.letterSize,
  });

  /// The tile's side, in logical pixels.
  final double size;

  /// The server's hue (0–359). Null when the lead has no tile.
  final int? hue;

  /// The server's letter, drawn as sent. It may be empty.
  final String letter;

  /// Earned art (§5.4). The generated face shows until it loads, and a
  /// broken image falls back to it.
  final Uri? art;

  final double radius;

  /// The letter's size. The card's is 45 % of its side, rounded (79 at 175,
  /// 75 at 167.5, boards M:44 and V:118); the band passes its own.
  final double? letterSize;

  @override
  Widget build(BuildContext context) {
    final art = this.art;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: art == null
              ? _face()
              : Image.network(
                  art.toString(),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: artCacheSize(size),
                  // The generated face stays until the art's first frame,
                  // so a cover still on its way never leaves an empty
                  // square. A cover already in the cache swaps in at once.
                  frameBuilder: (_, child, frame, sync) =>
                      sync || frame != null ? child : _face(),
                  errorBuilder: (_, _, _) => _face(),
                ),
        ),
      ),
    );
  }

  Widget _face() {
    final hue = this.hue;
    if (hue == null) {
      return ColoredBox(
        color: VelvetColors.raised,
        child: const SizedBox.expand(),
      );
    }
    final light = peerLightGround();
    return ColoredBox(
      color: peerTileField(hue, light: light),
      child: Center(
        child: Text(
          letter,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          // The tile is a picture: at a larger text size the boards keep the
          // letter at 45 % of the tile (V:158).
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: peerTileInk(hue, light: light),
            fontSize: letterSize ?? (size * 0.45).roundToDouble(),
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
