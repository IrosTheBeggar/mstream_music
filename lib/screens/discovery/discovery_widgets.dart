import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../singletons/api.dart';
import '../../theme/velvet_theme.dart';
import '../../util/queue_actions.dart';
import '../../widgets/album_grid.dart';
import '../../widgets/player_panel.dart';
import '../../widgets/playlist_picker_sheet.dart';
import '../../widgets/song_picker_sheet.dart';
import 'discovery_listing.dart';
import 'discovery_page_controller.dart';
import 'discovery_seeds_sheet.dart';

/// The pieces of Discover's browser listing that the browser does not draw
/// itself — the configuration bar, the state cards, the footers — and the
/// actions behind them (discovery_listing.dart says what the listing holds;
/// browser.dart draws its album and song items as it draws them
/// everywhere). Colours come from VelvetColors only, and nothing here shows
/// a count, a percentage or a play fact: Discover is the play-now page.

// ── formatters ──────────────────────────────────────────────────────────

/// "30 days" / "All time" for a taste window (days; 0 = all time).
String discoveryWindowLabel(AppLocalizations l, int window) =>
    window <= 0 ? l.discoverPageWindowAll : l.discoverPageWindowDays(window);

/// A calendar-day relative time: today, yesterday, N days, then months, then
/// years — the seeds sheet's "finished 8 months ago" scale, which fmtAgo
/// (minutes to a short date) does not cover.
String discoveryAgo(AppLocalizations l, DateTime when, DateTime now) {
  final a = when.toLocal();
  final b = now.toLocal();
  final days = (DateTime(b.year, b.month, b.day)
              .difference(DateTime(a.year, a.month, a.day))
              .inHours /
          24)
      .round();
  if (days <= 0) return l.discoverPageAgoToday;
  if (days == 1) return l.discoverPageAgoYesterday;
  if (days < 30) return l.agoDays(days);
  // 30-day months reach 12 at day 360, a few days before 365 does: from
  // there it is "1 year ago", never "12 months ago".
  final months = days ~/ 30;
  if (months < 12) return l.discoverPageAgoMonths(months);
  final years = days ~/ 365;
  return l.discoverPageAgoYears(years < 1 ? 1 : years);
}

/// A Discover 'section' item's header: "Albums from your library",
/// "Songs from Sam's server", "Songs from connected servers"…
String discoverySectionLabel(AppLocalizations l, DisplayItem section) {
  final name = section.subtext;
  return switch (DiscoverySection.values.asNameMap()[section.data]) {
    DiscoverySection.albumsLibrary => l.discoverPageAlbumsLibrary,
    DiscoverySection.albumsPeers => name == null
        ? l.discoverPageAlbumsPeers
        : l.discoverPageAlbumsPeer(name),
    DiscoverySection.songsLibrary => l.discoverPageSongsLibrary,
    DiscoverySection.songsPeers =>
      name == null ? l.discoverPageSongsPeers : l.discoverPageSongsPeer(name),
    null => section.name,
  };
}

// ── actions ─────────────────────────────────────────────────────────────

/// Floating, so it clears the docked mini-player (a plain bottom snackbar
/// renders behind it) — the browser's own playlist-error toast.
void discoveryToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.only(
      left: 16,
      right: 16,
      bottom: PlayerPanel.kCollapsedHeight +
          MediaQuery.of(context).viewPadding.bottom +
          8,
    ),
  ));
}

/// "More options": the seeds sheet. "Use these N" pops it and asks again;
/// the page shows the new answer when it lands.
Future<void> discoveryEditSeeds(
    BuildContext context, DiscoveryPageController c) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VelvetColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DiscoverySeedsSheet(controller: c),
  );
}

/// "Choose a song…" on the nothing-finished card: pin one of your own.
Future<void> discoveryChooseSong(
    BuildContext context, DiscoveryPageController c) async {
  final l = AppLocalizations.of(context);
  final picked = await showModalBottomSheet<DisplayItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VelvetColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) =>
        SongPickerSheet(server: c.server, title: l.discoverPageChooseSong),
  );
  final path = picked?.data;
  if (path == null) return;
  await c.pinSong(path);
}

/// "Browse your library": the server's File Explorer, pushed over Discover
/// (Back comes back here) — the webapp's button opens the same view.
void discoveryBrowseLibrary(DiscoveryPageController c) {
  ApiManager().getFileList('~', useThisServer: c.server);
}

/// A footer's "Queue all": the end of the queue, in the listing's order.
Future<void> discoveryQueueAll(
    BuildContext context, List<DisplayItem> rows) async {
  final l = AppLocalizations.of(context);
  final n = await addRowsToQueue(rows);
  if (n > 0 && context.mounted) discoveryToast(context, l.browserSongsAdded(n));
}

/// The library footer's "Save as playlist" — the sonic path screen's flow:
/// the shared picker (create-or-overwrite), then playlist/save with the
/// rows' paths.
Future<void> discoverySaveAsPlaylist(
    BuildContext context, DiscoveryPageController c,
    List<DisplayItem> rows) async {
  final l = AppLocalizations.of(context);
  final server = c.server;
  final name = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: VelvetColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => PlaylistPickerSheet(server: server),
  );
  final playlist = name?.trim();
  if (playlist == null || playlist.isEmpty) return;
  try {
    await ApiManager().savePlaylist(
        server, playlist, [for (final r in rows) ?r.data]);
    // Keep the pickers fresh before the next ping refreshes the list.
    if (!server.playlists.contains(playlist)) server.playlists.add(playlist);
    if (context.mounted) {
      discoveryToast(context, l.addedToPlaylist(playlist));
    }
  } catch (_) {
    if (context.mounted) discoveryToast(context, l.trackAddToPlaylistFailed);
  }
}

// ── layout ──────────────────────────────────────────────────────────────

/// The tap-target floor for every control Discover adds (44 px; Apple's
/// HIG and the Material 48 dp padded target both clear it).
const double kDiscoveryTapTarget = 44;

/// A [kDiscoveryTapTarget]-tall hit area around a smaller visual control,
/// the way Material pads a dense button's tap target: the control keeps its
/// canvas height and a tap in the band above or below it still lands. The
/// inner InkWell wins taps on the visual itself (the deepest recognizer is
/// first in the arena), so its ink still shows there.
class _HitArea extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _HitArea({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDiscoveryTapTarget),
          // Factors of 1: as tall as the floor and as wide as the control,
          // never stretched to the parent (a Wrap would lay one per row).
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      );
}

/// The gray configuration bar, the listing's first row: "Based on the last
/// [30 days ▾]" (the window's one home, remembered on this phone) and "More
/// options", which opens the seeds sheet. One Wrap, so a narrow screen or a large text
/// setting moves "More options" to a second line instead of overflowing.
///
/// Each control is off — and dimmed, since their text carries its own
/// colour — while it could not do anything useful: during a call (a change
/// would only race the answer it is about to replace), under the 403 latch
/// (nothing would be asked; the scan-pending card's "Check again" is the way
/// out), and for "More options" before any answer (no seeds to show yet).
/// A thin line under the bar says a call is out while rows are already up.
class DiscoveryConfigBar extends StatelessWidget {
  final DiscoveryPageController controller;
  const DiscoveryConfigBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final idle = !c.loading && !c.disabled;
    final canSeeds = idle && c.seeded != null;
    final current = c.window;
    // Plain text colours, not the link colour: on the bar's `raised` the
    // primary is unreadable in Light (amber on light gray) and the
    // secondary text too faint in Velvet.
    final ink = VelvetColors.textPrimary;
    return Container(
      key: const ValueKey('discovery-config-bar'),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      // "Based on the last All time" reads wrong.
                      current <= 0
                          ? l.discoverPageBasedOnAllTime
                          : l.discoverPageBasedOnLast,
                      style: TextStyle(color: ink, fontSize: 13),
                    ),
                    Opacity(
                      opacity: idle ? 1 : 0.5,
                      child: PopupMenuButton<int>(
                        key: const ValueKey('discovery-window'),
                        enabled: idle,
                        tooltip: '',
                        initialValue: current,
                        color: VelvetColors.surface,
                        onSelected: (w) => unawaited(c.setWindow(w)),
                        itemBuilder: (_) => [
                          for (final w in kTasteWindows)
                            CheckedPopupMenuItem<int>(
                              value: w,
                              checked: w == current,
                              child: Text(
                                discoveryWindowLabel(l, w),
                                style: TextStyle(
                                    color: VelvetColors.textPrimary,
                                    fontSize: 14),
                              ),
                            ),
                        ],
                        child: _WindowPill(discoveryWindowLabel(l, current)),
                      ),
                    ),
                  ],
                ),
                Opacity(
                  opacity: canSeeds ? 1 : 0.5,
                  // Standard density: the padded 48 px target.
                  child: TextButton(
                    key: const ValueKey('discovery-more-options'),
                    onPressed:
                        canSeeds ? () => discoveryEditSeeds(context, c) : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      l.discoverPageMoreOptions,
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: VelvetColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // A fixed 2 px slot, so the rows never jump when it comes and goes.
          SizedBox(
            height: 2,
            child: c.loading && c.seeded != null
                ? LinearProgressIndicator(
                    minHeight: 2,
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

/// The window chooser's face in the configuration bar: the window in force
/// and a caret, outlined so it reads on the bar's gray in every palette.
/// 32 px tall (taller only under a large text setting); the
/// [kDiscoveryTapTarget] band around it is the menu's hit area too. The
/// label ellipsizes rather than overflow a bar narrower than it.
class _WindowPill extends StatelessWidget {
  final String label;
  const _WindowPill(this.label);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kDiscoveryTapTarget),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: VelvetColors.border2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down,
                  size: 20, color: VelvetColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's one dim line ("Nothing from your connected servers right
/// now."), with an optional button after it.
class DiscoveryHint extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const DiscoveryHint(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 13,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 4),
              DiscoveryPill(action!, onTap: onAction),
            ],
          ],
        ),
      );
}

/// The width of one card in a Discover album strip (the browser's
/// _discoveryAlbumStrip); the strip is one card tall.
const double kDiscoverStripCardWidth = 132;
const double kDiscoverStripHeight = kDiscoverStripCardWidth / AlbumGrid.aspectRatio;

/// A Discover album strip's placeholder: the strip's own height, cards and
/// padding, so the strip that replaces it moves nothing below it.
class DiscoveryStripSkeleton extends StatelessWidget {
  const DiscoveryStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const ValueKey('discovery-strip-skeleton'),
        height: kDiscoverStripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: AlbumGrid.spacing),
          itemBuilder: (_, _) => Container(
            width: kDiscoverStripCardWidth,
            decoration: BoxDecoration(
              color: VelvetColors.raised,
              borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
            ),
          ),
        ),
      );
}

/// Placeholders while a source is asked — album tiles and song rows in the
/// browser's shapes, no words.
class DiscoverySkeleton extends StatelessWidget {
  final bool albums;
  final int rows;
  const DiscoverySkeleton({super.key, this.albums = false, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    Widget block(double w, double h, {double r = 4}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: VelvetColors.raised,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (albums)
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  block(128, 160, r: VelvetColors.radiusLarge),
                ],
              ],
            ),
          ),
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
            child: Row(children: [
              block(40, 40, r: VelvetColors.radiusSmall),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                        widthFactor: 0.6, child: block(double.infinity, 12)),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                        widthFactor: 0.4, child: block(double.infinity, 10)),
                  ],
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

/// A rounded action pill (the footers, the state cards); [primary] fills
/// it with the accent.
class DiscoveryPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback? onTap;
  const DiscoveryPill(this.label,
      {super.key, this.icon, this.primary = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? VelvetColors.onPrimary : VelvetColors.textPrimary;
    // 36 px on the canvas; the hit area reaches the 44 px floor.
    return _HitArea(
        onTap: onTap,
        child: Material(
          color: primary ? VelvetColors.primary : VelvetColors.raised,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  // Ellipsized rather than overflowing a row narrower than
                  // it (a long locale under a large text setting on a small
                  // phone).
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fg, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

/// A song list's footer: "Queue all · Shuffle · Save as playlist" under the
/// library's songs, "Queue all" under the connected servers' — the verbs
/// that act on the whole list. No counts.
class DiscoveryFooter extends StatelessWidget {
  final DiscoveryPageController controller;

  /// [kDiscoverFootLibrary] or [kDiscoverFootPeers].
  final String which;
  const DiscoveryFooter(
      {super.key, required this.controller, required this.which});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final library = which == kDiscoverFootLibrary;
    final rows = library ? c.libraryRows : c.peerRows;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Wrap(
        spacing: 8,
        // The pills' 44 px hit areas already space the rows.
        runSpacing: 0,
        children: [
          DiscoveryPill(l.discoverQueueAll,
              icon: Icons.playlist_add,
              primary: true,
              onTap: () => discoveryQueueAll(context, rows)),
          if (library) ...[
            DiscoveryPill(l.shuffle,
                icon: Icons.shuffle,
                onTap: () => playFromHere(rows, 0, shuffle: true)),
            DiscoveryPill(l.discoverPageSaveAsPlaylist,
                icon: Icons.queue_music,
                onTap: () => discoverySaveAsPlaylist(context, c, rows)),
          ],
        ],
      ),
    );
  }
}

/// A state card's frame: a raised panel with a title, a body and buttons.
class _StateCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? body;
  final List<Widget> actions;
  const _StateCard(
      {this.icon, required this.title, this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VelvetColors.card,
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
          border: Border.all(color: VelvetColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: VelvetColors.textSecondary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 13,
                    height: 1.4),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                // The pills' 44 px hit areas already space the rows.
                runSpacing: 0,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The library call failed: one line and Try again.
class DiscoveryFailedCard extends StatelessWidget {
  final VoidCallback onRetry;
  const DiscoveryFailedCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _StateCard(
      icon: Icons.cloud_off_outlined,
      title: l.discoverPageError,
      actions: [
        DiscoveryPill(l.discoverPageRetry,
            icon: Icons.refresh, primary: true, onTap: onRetry),
      ],
    );
  }
}

/// Discovery is on but nothing is analyzed yet — DiscoverScreen's
/// scan-pending copy, with its "Check again".
class DiscoveryScanPendingCard extends StatelessWidget {
  final bool rechecking;
  final VoidCallback onRecheck;
  const DiscoveryScanPendingCard(
      {super.key, required this.rechecking, required this.onRecheck});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _StateCard(
      icon: Icons.hourglass_empty,
      title: l.discoverScanPendingTitle,
      body: l.discoverScanPendingBody,
      actions: [
        DiscoveryPill(l.discoverCheckAgain,
            icon: Icons.refresh, onTap: rechecking ? null : onRecheck),
      ],
    );
  }
}

/// Nothing finished yet (plan §2.8): the seeds are one random library song.
/// Says why, and offers another pick, a song of the user's own, or the
/// library itself.
class DiscoveryRandomCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onAnotherPick;
  final VoidCallback onChooseSong;
  final VoidCallback onBrowse;
  const DiscoveryRandomCard({
    super.key,
    required this.busy,
    required this.onAnotherPick,
    required this.onChooseSong,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _StateCard(
      title: l.discoverPageRandomTitle,
      body: l.discoverPageRandomBody,
      actions: [
        DiscoveryPill(l.discoverPageAnotherPick,
            icon: Icons.casino_outlined,
            primary: true,
            onTap: busy ? null : onAnotherPick),
        DiscoveryPill(l.discoverPageChooseSong,
            icon: Icons.search, onTap: busy ? null : onChooseSong),
        DiscoveryPill(l.discoverPageBrowseLibrary,
            icon: Icons.folder_outlined, onTap: onBrowse),
      ],
    );
  }
}

/// One [kDiscoverState] item, drawn. The browser hands each state item
/// here; the controller is the open listing's.
Widget discoveryStateWidget(BuildContext context, DisplayItem item,
    DiscoveryPageController? c, {bool grid = true}) {
  final l = AppLocalizations.of(context);
  final state = DiscoveryListingState.values.asNameMap()[item.data];
  switch (state) {
    case DiscoveryListingState.off:
      return DiscoveryHint(l.discoverTurnedOff);
    case DiscoveryListingState.loading:
      return const DiscoverySkeleton(albums: true, rows: 6);
    case DiscoveryListingState.peersLoading:
      return const DiscoverySkeleton(rows: 3);
    case DiscoveryListingState.peersAlbumsLoading:
      // With the album grid off, albums are rows: a count no placeholder
      // can know, so two rows stand in.
      return grid ? const DiscoveryStripSkeleton() : const DiscoverySkeleton(rows: 2);
    case DiscoveryListingState.peersFailed:
      return DiscoveryHint(l.discoverPagePeersFailed,
          action: l.discoverPageRetry,
          onAction: c == null ? null : () => unawaited(c.retryPeers()));
    case DiscoveryListingState.failed:
      return DiscoveryFailedCard(onRetry: () => c?.refresh());
    case DiscoveryListingState.scanPending:
      return DiscoveryScanPendingCard(
          rechecking: c?.rechecking ?? false,
          onRecheck: () => c?.recheck());
    case DiscoveryListingState.random:
      return DiscoveryRandomCard(
        busy: c == null || c.loading,
        onAnotherPick: () {
          if (c != null) unawaited(c.anotherPick());
        },
        onChooseSong: () {
          if (c != null) discoveryChooseSong(context, c);
        },
        onBrowse: () {
          if (c != null) discoveryBrowseLibrary(c);
        },
      );
    case DiscoveryListingState.libraryEmpty:
      return DiscoveryHint(l.discoverPageLibraryNothing);
    case DiscoveryListingState.peersQuiet:
      return DiscoveryHint(l.discoverPagePeersQuiet);
    case null:
      return const SizedBox.shrink();
  }
}
