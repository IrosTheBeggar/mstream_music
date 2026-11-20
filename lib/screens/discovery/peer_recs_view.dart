import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../media/preview_player.dart';
import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../singletons/browser_list.dart';
import '../../theme/velvet_theme.dart';
import '../../util/network_sheet_gate.dart' show NetworkLeadTap;
import '../../util/peer_recs_rules.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_keep_routes.dart';
import 'discovery_widgets.dart'
    show DiscoveryConfigBar, DiscoveryScanPendingCard;
import 'elsewhere_sheet.dart' show openOutside;
import 'keep_toast.dart';
import 'network_lead_sheet.dart' show networkLeadTapFor;
import 'network_preview_rows.dart' show previewProviderLabel;
import 'peer_recs_band.dart';
import 'peer_recs_cards.dart';
import 'peer_recs_controller.dart';
import 'peer_recs_listing.dart';
import 'peer_recs_previews.dart';
import 'peer_recs_strip.dart';

/// The Peer Recommendations frame (mStream docs/peer-recommendations-plan.md
/// §4.2 "Drawing"; the phone boards Main, States and Variants), drawn from
/// the open visit ([PeerRecsListing]) rather than from the frame's items:
/// one scroller — Discover's configuration bar, the peer strip, then the
/// grid of leads and its footer, or the page's state — pulled down for New
/// seeds, and the live preview's band docked under it as the frame's last
/// child, just above the mini player.
///
/// A card's tap opens #237's network-lead sheet with the visit's preview
/// answers (or copies the lead when the own server's plug-ins could offer
/// nothing for it); its circle plays the page's preview. Every toast floats
/// over the band while it shows: the band tells KeepToast its height.
///
/// Drawn again after a frame pushed over it goes, the page is at the scroll
/// offset it had, from its first frame.
class PeerRecsView extends StatefulWidget {
  const PeerRecsView({super.key});

  @override
  State<PeerRecsView> createState() => _PeerRecsViewState();
}

class _PeerRecsViewState extends State<PeerRecsView> {
  // The scroller's own page storage, one per mount. It is seeded with the
  // offset the page had when a frame was pushed over it, so the new scroll
  // position starts there and the first frame is drawn in place.
  //
  // Any scrollable drawn inside the page with no page-storage key of its own
  // files its offset under the scroller's entry, wherever the key sits above
  // it: it would start at the page's vertical offset, and its own offset
  // would overwrite the page's. So none keeps its offset here (the strip's
  // controller has keepScrollOffset false); one that must keep it needs its
  // own PageStorageKey.
  final PageStorageBucket _offsets = PageStorageBucket();
  double? _restore;

  @override
  void initState() {
    super.initState();
    PeerRecsListing().attachView(context);
    _restore = PeerRecsListing().takeRestoreOffset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Called again whenever a route rises over the page's route or goes (a
    // sheet, a dialog, a page). R7 never changes the frame under one. What
    // covers the page is the listing's to read (a page route over the home,
    // counted by the app's route observer; a sheet is no cover).
    PeerRecsListing().setViewRoute(ModalRoute.of(context));
  }

  @override
  void dispose() {
    PeerRecsListing().detachView(context);
    super.dispose();
  }

  // ── what a tap does ──────────────────────────────────────────────────

  /// A card's tap (plan §2 item 15, the build plan's D1): with the own
  /// server's plug-ins able to offer something for [lead], #237's
  /// network-lead sheet — the page's list held while it is up, a live clip
  /// ended first (the sheet hides the band; D2) — else its copy. Nothing
  /// plays and nothing is resolved here.
  Future<void> _openLead(PeerRecsController c, PeerRecsPreviews p,
      DiscoveryJobsController? jobs, DiscoveryLead lead) async {
    final l = AppLocalizations.of(context);
    if (jobs == null || networkLeadTapFor(jobs, lead) == NetworkLeadTap.copy) {
      await Clipboard.setData(ClipboardData(text: peerCopyText(lead)));
      PeerRecsListing().toast(l.peerRecsCopied);
      return;
    }
    final visit = c;
    // Holding first, so the clip ending next does not let a waiting R4
    // re-ask redraw the list just before the sheet rises.
    PeerRecsListing().setSheetOpen(true, visit: visit);
    if (p.isLive) unawaited(p.leave(PreviewEnd.stopped));
    try {
      await DiscoveryKeepRoutes.openPeerLead(
        context,
        jobs,
        lead,
        seedTitle: c.seedTitleOf(lead),
        answers: (store: p.answers, leadKey: peerLeadKey(lead)),
      );
    } finally {
      // A no-op once the visit is gone; the view itself may be gone while
      // the visit is not (covered from inside the sheet).
      PeerRecsListing().setSheetOpen(false, visit: visit);
    }
  }

  Future<void> _copyList(PeerRecsController c) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: c.copyListText()));
    PeerRecsListing().toast(l.peerRecsCopied);
  }

  /// The band's attribution link: out of the app (the clip ends as it
  /// leaves); a link that does not open says so.
  Future<void> _openLink(Uri link) async {
    final l = AppLocalizations.of(context);
    var ok = false;
    try {
      ok = await openOutside(link);
    } catch (_) {
      ok = false;
    }
    if (!ok) PeerRecsListing().toast(l.discoverToastLinkFailed);
  }

  /// "More options" opens the seeds sheet, which covers the band too: a
  /// live clip ends first (D2).
  void _openSeeds(PeerRecsPreviews p) {
    if (p.isLive) unawaited(p.leave(PreviewEnd.stopped));
  }

  // ── drawing ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Every stack change: the visit on screen may be a new one (the browser
    // hands this view over as the same const widget).
    return StreamBuilder<List<DisplayItem>>(
      stream: BrowserManager().browserListStream,
      builder: (context, _) {
        final listing = PeerRecsListing();
        final c = listing.controller;
        final p = listing.previews;
        final jobs = listing.jobs;
        if (c == null || p == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: Listenable.merge([c, p, ?jobs]),
          builder: (context, _) => _page(context, c, p, jobs),
        );
      },
    );
  }

  Widget _page(BuildContext context, PeerRecsController c, PeerRecsPreviews p,
      DiscoveryJobsController? jobs) {
    final provider = p.providerPlugin;
    final providerLabel =
        provider == null ? '' : previewProviderLabel(provider);
    final state = c.state;
    final strip = c.stripVisible;
    final live = p.isLive ? p.live : null;
    final liveKey = live == null ? null : peerLeadKey(live);

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: DiscoveryConfigBar(
          controller: c,
          onOpenSeeds: () => _openSeeds(p),
        ),
      ),
      if (strip)
        SliverToBoxAdapter(
          child: PeerStripView(
            items: c.stripItems,
            onSelect: c.select,
            onAdd: c.add,
          ),
        ),
      ...switch (state) {
        PeerRecsState.ready => [
            SliverPadding(
              // The strip ends 12 under its labels; without it the grid
              // keeps that air under the bar.
              padding: EdgeInsets.only(top: strip ? 0 : 12),
              sliver: SliverToBoxAdapter(
                child: PeerLeadGrid(
                  leads: c.leads,
                  circleOf: p.circleOf,
                  artOf: p.cardArt,
                  isLive: (lead) =>
                      liveKey != null && peerLeadKey(lead) == liveKey,
                  onOpen: (lead) => unawaited(_openLead(c, p, jobs, lead)),
                  onPlay: (lead) => unawaited(p.press(lead, c.leads)),
                  providerLabel: providerLabel,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: PeerRecsFooter(
                showPreviewAll: provider != null,
                running: p.chain && p.isLive,
                onPreviewAll: () => unawaited(p.previewAll(c.leads)),
                onCopyList: () => unawaited(_copyList(c)),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        PeerRecsState.loading => [
            SliverPadding(
              padding: EdgeInsets.only(top: strip ? 0 : 12, bottom: 24),
              sliver: const SliverToBoxAdapter(child: PeerRecsSkeleton()),
            ),
          ],
        PeerRecsState.scanPending => [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverToBoxAdapter(
                child: DiscoveryScanPendingCard(
                  rechecking: c.rechecking,
                  onRecheck: () => unawaited(c.recheck()),
                ),
              ),
            ),
          ],
        PeerRecsState.noPeers ||
        PeerRecsState.nothingNew ||
        PeerRecsState.failed =>
          [
            // Centred in the room under the bar and the strip; its own
            // padding keeps 24 at the bottom.
            SliverFillRemaining(
              hasScrollBody: false,
              child: PeerRecsStateView(
                state: state,
                onRetry: () => unawaited(c.retry()),
                onNewSeeds: () => unawaited(c.refresh()),
              ),
            ),
          ],
      },
    ];

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: VelvetColors.primary,
            onRefresh: c.refresh,
            child: PageStorage(
              bucket: _offsets,
              child: KeyedSubtree(
                key: const PageStorageKey<String>('peer-recs-offset'),
                child: Builder(builder: (context) {
                  // Written under the same storage key the scroller reads,
                  // before the scroller is built: its new position starts
                  // at the kept offset.
                  final o = _restore;
                  if (o != null) {
                    _restore = null;
                    PageStorage.of(context).writeState(context, o);
                  }
                  return CustomScrollView(
                    key: const ValueKey('peer-recs-scroll'),
                    controller: BrowserManager().sc,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: slivers,
                  );
                }),
              ),
            ),
          ),
        ),
        if (live != null)
          _DockedBand(
            child: PeerRecsBand(
              lead: live,
              art: p.bandArt(live),
              attribution: p.preview?.attribution,
              link: p.preview?.link,
              status: p.status,
              progress: p.progress,
              providerLabel: providerLabel,
              hasNext: p.hasNext,
              onToggle: () => unawaited(p.toggle()),
              onNext: () => unawaited(p.next()),
              onClose: () => unawaited(p.stop()),
              onLink: (uri) => unawaited(_openLink(uri)),
            ),
          ),
      ],
    );
  }
}

/// The band as the page docks it over the mini player. After every layout
/// that changes its height it puts that height in [KeepToast.dockLift], and
/// 0 once it goes, so every toast (the page's and CopiesHub's) floats over
/// it while it shows and drops back once it is gone.
class _DockedBand extends SingleChildRenderObjectWidget {
  const _DockedBand({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDockedBand();
}

class _RenderDockedBand extends RenderProxyBox {
  // The band docked now. A band that goes in the frame its successor came
  // never resets the successor's height.
  static _RenderDockedBand? _docked;

  double _height = 0;
  bool _scheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    _height = size.height;
    _docked = this;
    if (_scheduled || KeepToast.dockLift.value == _height) return;
    // Not during layout: the toast rebuilds when the lift changes.
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (identical(_docked, this)) KeepToast.dockLift.value = _height;
    });
  }

  @override
  void dispose() {
    if (identical(_docked, this)) {
      _docked = null;
      // Disposed while the tree is locked: the toast drops back after the
      // frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_docked == null) KeepToast.dockLift.value = 0;
      });
    }
    super.dispose();
  }
}
