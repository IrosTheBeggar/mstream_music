import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../theme/velvet_theme.dart';
import '../../util/queue_actions.dart';
import '../../widgets/album_grid.dart';
import 'discovery_page_controller.dart';
import 'discovery_widgets.dart';

/// "See all" for one source of the Discover page (the PhoneLibrary canvas
/// board): every row the visit fetched, and — for the library — the filter
/// chips, which refetch with the new filter (remembered server-side). It
/// reads the page's controller, so the page under it follows the same
/// filter when the user comes back.
class DiscoverySourceList extends StatelessWidget {
  final DiscoveryPageController controller;
  final TasteSource source;
  const DiscoverySourceList(
      {super.key, required this.controller, required this.source});

  static const _filters = [
    TasteFilter.unplayed,
    TasteFilter.fresh,
    TasteFilter.all,
  ];

  static String filterLabel(AppLocalizations l, TasteFilter f) => switch (f) {
        TasteFilter.unplayed => l.discoverPageFilterUnplayed,
        TasteFilter.fresh => l.discoverPageFilterFresh(kDiscoveryStaleDays),
        TasteFilter.all => l.discoverPageFilterAll,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final (title, subtitle) = _titles(l);
        final rows = c.libraryRows;
        return Scaffold(
          backgroundColor: VelvetColors.bg,
          appBar: AppBar(
            backgroundColor: VelvetColors.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: VelvetColors.textPrimary,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12)),
              ],
            ),
            actions: source == TasteSource.library && rows.isNotEmpty
                ? [
                    IconButton(
                      icon: Icon(Icons.play_arrow,
                          color: VelvetColors.textPrimary),
                      tooltip: l.playAll,
                      onPressed: () => playFromHere(rows, 0),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.shuffle, color: VelvetColors.textPrimary),
                      tooltip: l.shuffle,
                      onPressed: () => playFromHere(rows, 0, shuffle: true),
                    ),
                    IconButton(
                      icon: Icon(Icons.playlist_add,
                          color: VelvetColors.textPrimary),
                      tooltip: l.discoverPageAddToQueue,
                      onPressed: () => discoveryQueueAll(context, rows),
                    ),
                  ]
                : null,
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: switch (source) {
                TasteSource.library => _library(context, l),
                TasteSource.network => _network(l),
                TasteSource.peers => _peers(context, l),
              },
            ),
          ),
        );
      },
    );
  }

  (String, String?) _titles(AppLocalizations l) {
    final c = controller;
    switch (source) {
      case TasteSource.library:
        final lib = c.library;
        return (
          l.discoverPageFromLibrary,
          lib == null
              ? null
              : [
                  if (lib.albums.isNotEmpty)
                    l.discoverPageAlbumsCount(lib.albums.length),
                  l.discoverPageSongsCount(lib.tracks.length),
                  l.discoverMatchedBySound,
                ].join(' · '),
        );
      case TasteSource.network:
        final net = c.network;
        return (
          l.discoverFromNetwork,
          net == null ? null : l.discoverPageServersSearched(net.searchedPeers),
        );
      case TasteSource.peers:
        final p = c.peers;
        final online = p?.peers.where((g) => g.reachable).length ?? 0;
        return (
          l.discoverFromPeers,
          p == null || p.peers.isEmpty
              ? null
              : l.discoverPagePeersOnline(online, p.peers.length),
        );
    }
  }

  List<Widget> _library(BuildContext context, AppLocalizations l) {
    final c = controller;
    final lib = c.library;
    final out = <Widget>[
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            for (final f in _filters) ...[
              DiscoveryChoicePill(
                filterLabel(l, f),
                // The pending choice while its refetch runs; the controller
                // puts the old one back if that refetch fails.
                selected: c.effectiveFilter == f,
                onTap: () => c.setFilter(f),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      if (c.loading)
        LinearProgressIndicator(
          minHeight: 2,
          color: VelvetColors.primary,
          backgroundColor: Colors.transparent,
        ),
      // A failed filter change keeps the rows below; say so here, where
      // the chip was tapped (the page's own line is under this route).
      if (c.error && !c.loading) DiscoveryHint(l.discoverPageError),
    ];
    if (lib == null) {
      if (c.loading) out.add(discoveryLoadingRow());
      return out;
    }
    if (lib.albums.isEmpty && lib.tracks.isEmpty) {
      out.add(DiscoveryHint(discoveryScanWaiting(c)
          ? l.discoverPageScanWaiting
          : l.discoverPageLibraryEmpty));
      return out;
    }
    if (lib.albums.isNotEmpty) {
      out.add(DiscoverySectionHeader(l.discoverPageAlbumsHeader));
      out.add(LayoutBuilder(builder: (context, box) {
        // AlbumGrid's column rule, so the cards read the same size here as
        // in the albums browser.
        final cols = AlbumGrid.columnsFor(box.maxWidth);
        const gap = 12.0;
        final w = (box.maxWidth - 32 - gap * (cols - 1)) / cols;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0;
                  i < lib.albums.length && i < c.albumItems.length;
                  i++)
                DiscoveryAlbumCard(
                  item: c.albumItems[i],
                  album: lib.albums[i],
                  width: w,
                  onTap: () => discoveryOpenAlbum(context, c.albumItems[i]),
                ),
            ],
          ),
        );
      }));
    }
    final rows = c.libraryRows;
    if (lib.tracks.isNotEmpty) {
      out.add(DiscoverySectionHeader(l.discoverPageSongsHeader,
          meta: '${lib.tracks.length}'));
      for (var i = 0; i < lib.tracks.length && i < rows.length; i++) {
        out.add(DiscoveryTrackRow(
          row: rows[i],
          track: lib.tracks[i],
          now: c.now(),
          onTap: () => discoveryTapTrack(context, rows, i),
          onNext: () => discoveryQueueNext(context, rows[i]),
          onQueue: () => discoveryQueueEnd(context, rows[i]),
          onMore: () => discoveryTrackActions(context, rows[i]),
        ));
      }
    }
    return out;
  }

  List<Widget> _network(AppLocalizations l) {
    final net = controller.network;
    if (net == null) return const [];
    if (net.results.isEmpty) {
      return [DiscoveryHint(discoveryNetworkEmptyLine(l, controller, net))];
    }
    return [
      const SizedBox(height: 8),
      for (final lead in net.results)
        DiscoveryLeadRow(lead: lead, newArtist: controller.newArtistsOnly),
    ];
  }

  List<Widget> _peers(BuildContext context, AppLocalizations l) {
    final p = controller.peers;
    if (p == null) {
      return controller.loadingPeers ? [discoveryLoadingRow()] : const [];
    }
    return [
      const SizedBox(height: 8),
      ...discoveryPeerGroups(context, controller, p),
    ];
  }
}
