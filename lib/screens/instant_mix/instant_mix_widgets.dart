import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/display_item.dart';
import '../../objects/instant_mix.dart';
import '../../objects/mix_filters.dart';
import '../../theme/velvet_theme.dart';
import '../../util/image_cache.dart';
import '../../util/media_format.dart';
import '../discovery/discovery_widgets.dart';
import 'instant_mix_controller.dart';

/// The pieces of an Instant mix page the browser does not draw itself: the
/// seed's banner and the state lines (instant_mix_listing.dart says what
/// the frame holds; browser.dart draws its song rows as it draws them
/// everywhere). No counts, percentages or match facts anywhere.

/// The seed's banner, fixed above the rows: its tile, its title and, for a
/// song or an album, its artist — the album detail's banner, without the
/// facts line. A 3 px slot along its bottom edge carries the line that runs
/// while the page asks again, so nothing moves when it comes and goes.
class InstantMixBanner extends StatelessWidget {
  final InstantMixController controller;
  const InstantMixBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final seed = controller.seed;
    final subtitle = seed.subtitle;
    return Container(
      key: const ValueKey('mix-banner'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 13),
            child: Row(
              children: [
                _MixTile(seed: seed),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        seed.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                          letterSpacing: -0.2,
                          color: VelvetColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              color: VelvetColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 3,
            child: controller.refreshing
                ? LinearProgressIndicator(
                    minHeight: 3,
                    color: VelvetColors.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// The banner's 86 px tile: a song's or an album's cover (the placeholder
/// tile without one), a round person for an artist, the playlist glyph for
/// a playlist.
class _MixTile extends StatelessWidget {
  static const double _size = 86;
  final MixSeed seed;
  const _MixTile({required this.seed});

  @override
  Widget build(BuildContext context) {
    switch (seed.kind) {
      case MixSeedKind.artist:
        return Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: VelvetColors.raised,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person, size: 40, color: VelvetColors.textSecondary),
        );
      case MixSeedKind.playlist:
        return Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: VelvetColors.raised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.queue_music, size: 40, color: VelvetColors.primary),
        );
      case MixSeedKind.song:
      case MixSeedKind.album:
        final url = seed.artUrl;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: _size,
            height: _size,
            child: url != null
                ? Image.network(url,
                    fit: BoxFit.cover,
                    cacheWidth: artCacheSize(_size),
                    errorBuilder: (_, _, _) => albumArtFallback(iconSize: 30))
                : albumArtFallback(iconSize: 30),
          ),
        );
    }
  }
}

/// A mix frame's state item, drawn: the placeholder rows while the first
/// answer is out, else the state's one line — Try again on the failed one.
Widget instantMixStateWidget(
    BuildContext context, DisplayItem item, InstantMixController? c) {
  final l = AppLocalizations.of(context);
  switch (InstantMixState.values.asNameMap()[item.data]) {
    case InstantMixState.loading:
      return const DiscoverySkeleton(rows: 6);
    case InstantMixState.notAnalyzed:
      return DiscoveryHint(l.instantMixNotAnalyzed);
    case InstantMixState.nothingSimilar:
      return DiscoveryHint(l.instantMixNothingSimilar);
    case InstantMixState.noMatch:
      return DiscoveryHint(l.autoDjSeedNoMatch);
    case InstantMixState.off:
      return DiscoveryHint(l.discoverTurnedOff);
    case InstantMixState.failed:
      return DiscoveryHint(l.instantMixFailed,
          action: l.discoverPageRetry,
          onAction: c == null ? null : () => unawaited(c.retry()));
    case InstantMixState.ready:
    case null:
      return const SizedBox.shrink();
  }
}

/// A filter change on the page — the Filters' Done, the strip's Clear:
/// [next] applied, and kept for the next mix page (MixFilterStore); and
/// "Couldn't build the mix" when the server could not answer it — the rows
/// stayed, and so did the filters they were built with, which the store
/// gets back too.
Future<void> applyMixFilters(
    BuildContext context, InstantMixController c, MixFilters next) async {
  final l = AppLocalizations.of(context);
  final store = MixFilterStore();
  store.set(c.seed, next);
  if (await c.apply(next)) return;
  store.set(c.seed, c.filters);
  if (context.mounted) discoveryToast(context, l.instantMixFailed);
}
