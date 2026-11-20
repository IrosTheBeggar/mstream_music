import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../media/preview_player.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/log_manager.dart';
import '../../theme/velvet_theme.dart';
import '../../util/image_cache.dart' show artCacheSize;
import '../../util/network_sheet_gate.dart';
import 'copy_news.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_keep_routes.dart';
import 'discovery_sheet_parts.dart';
import 'elsewhere_sheet.dart' show openOutside;
import 'keep_copy_ui.dart';
import 'keep_toast.dart';
import 'network_preview_rows.dart';
import 'preview_answers.dart';
import 'youtube_pick_card.dart';

/// The network-lead sheet (the design canvas's NetworkSheet board): what a
/// "From the network" row on More like this opens — a song in someone
/// else's library on the P2P network, which the phone cannot play. Its
/// header says what and where from ("From the network · Vinyl Vault",
/// "88% match to “Tidewater”"), pinned while the rest scrolls (up to 130 %
/// text; past it the header scrolls away too); then a
/// 30-second preview from each catalogue the user's own server offers
/// (network_preview_rows.dart), KEEP A COPY — the YouTube add, when it can
/// run here — and "Open elsewhere ›" (or "Open on MusicBrainz" without the
/// links plug-in) and "Copy title".
///
/// Nothing reaches Deezer, iTunes or YouTube until the user presses: on
/// open the sheet asks only the user's own server, for where files land
/// (read again with every sheet that may add, as each Keep card does). It
/// sends every plug-in the row as a recommendation those routes take
/// (objects/discovery.dart sendableRecommendation: the per-song network
/// route hands out a peer's tags as they are).
///
/// It opens at 0.62 of the screen, snaps to 0.94, and closes below 0.40. A
/// clip it plays stops as it closes, and the song it paused comes back.

/// The sheet's sections for [jobs]' server, as the gate reads them
/// (util/network_sheet_gate.dart): the user's own server's flag and
/// listing, and the jobs controller's YouTube gate.
NetworkSheetSections networkSheetSectionsFor(DiscoveryJobsController jobs) =>
    networkSheetSections(
      pluginsAvailable: jobs.server.discoveryPluginsAvailable,
      listing: jobs.listing,
      youtubeGate: jobs.youtubeGate(),
      buildShowsYoutube: jobs.youtubeShown,
    );

/// What a tap on [lead]'s "From the network" row does with [jobs]' server:
/// open the sheet, or copy its title (util/network_sheet_gate.dart
/// networkLeadTap).
NetworkLeadTap networkLeadTapFor(
  DiscoveryJobsController jobs,
  DiscoveryLead lead,
) => networkLeadTap(
  pluginsAvailable: jobs.server.discoveryPluginsAvailable,
  listing: jobs.listing,
  sections: networkSheetSectionsFor(jobs),
  sendable: lead.recommendation,
);

/// Opens [lead]'s sheet. [jobs] is the user's own server's controller
/// (CopiesHub().jobsFor: shared, never disposed by a page). The sheet sends
/// [lead]'s repaired recommendation ([DiscoveryLead.recommendation]) — the
/// caller may pass the lead as parsed or already repaired
/// (`lead.withRaw(lead.recommendation!)`). [seedTitle] names the song the
/// row sounds like ("88% match to “Tidewater”"); [autoSearch] starts the
/// YouTube search as the sheet opens (Copies' "Choose another", with
/// [avoidUrl] the upload that failed: another is picked first);
/// [onLeadAction] runs once, on the sheet's first lead action (a preview,
/// Play, Add to queue, Add this one: More like this pins its seed). An add
/// the sheet started is toasted once it closes, with "View" (Copies) while
/// it runs, or — ended by then — with its ending; one the user already
/// asked to stop says nothing. A start the server answers after the sheet
/// closed is toasted as it answers. [answers]: the Peer Recommendations
/// visit's preview answers for [lead] (network_preview_rows.dart
/// NetworkPreviews.answers), shared both ways.
Future<void> showNetworkLeadSheet(
  BuildContext context, {
  required DiscoveryJobsController jobs,
  required DiscoveryLead lead,
  String? seedTitle,
  bool autoSearch = false,
  String? avoidUrl,
  VoidCallback? onLeadAction,
  LeadPreviewAnswers? answers,
}) async {
  final l = AppLocalizations.of(context);
  final started = <DiscoveryJob>[];
  var closed = false;
  BuildContext? host() =>
      context.mounted ? context : rootNavigatorKey.currentContext;
  void tell(DiscoveryJob job) {
    // One that already ended (the library had it) is no "Adding …": its
    // ending instead — unless the poll told it while the sheet was open.
    final last = jobs.latest(job);
    if (!last.live) {
      final ended = jobs.claimEnding(last) ? copyFinishedToast(l, last) : null;
      if (ended != null) KeepToast.show(host(), ended);
      return;
    }
    // Stopping (Cancel on a running add): "Adding …" would be the last
    // word on an add the user called off; its ending says nothing either.
    if (last.cancelRequested) return;
    showCopyStarted(
      host(),
      l,
      last,
      onView: () {
        final at = host();
        if (at != null && at.mounted) DiscoveryKeepRoutes.openCopies(at, jobs);
      },
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: VelvetColors.surface,
    isScrollControlled: true,
    // The pinned header paints the sheet's colour edge to edge: clipped to
    // the rounded top.
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => NetworkLeadSheet(
      jobs: jobs,
      lead: lead,
      seedTitle: seedTitle,
      autoSearch: autoSearch,
      avoidUrl: avoidUrl,
      onLeadAction: onLeadAction,
      answers: answers,
      // Answered once the sheet has closed (or while it animates away):
      // told at once.
      onStarted: (job) => closed ? tell(job) : started.add(job),
    ),
  );
  closed = true;
  if (started.isNotEmpty) tell(started.last);
}

/// What the sheet hands KEEP A COPY's block (the YouTube add:
/// [YoutubeKeepBlock]) — everything the block cannot know by itself. The
/// sheet already holds the fast poll, reads the destination again as it
/// opens, ends a clip as it closes, and draws the section's label above the
/// block.
class NetworkKeepSlot {
  /// The user's own server's jobs controller.
  final DiscoveryJobsController jobs;

  /// The lead; its [DiscoveryLead.raw] is the repaired recommendation every
  /// plug-in call sends.
  final DiscoveryLead lead;

  /// Start the YouTube search as the sheet opens (Copies' "Choose
  /// another").
  final bool autoSearch;

  /// The upload not to pick first: the one Copies' "Choose another" row
  /// failed with (the block's own lookup may find a newer add, or none).
  final String? avoidUrl;

  /// A lead action (Play, Add to queue, Add this one): the sheet passes the
  /// first on (More like this pins its seed).
  final VoidCallback onLeadAction;

  /// An add the server took as new: toasted once the sheet closes (at once
  /// when the answer comes after it closed — call it then too).
  final void Function(DiscoveryJob job) onStarted;

  /// A press the server refused with 403 or 404 (the plug-in, the jobs gate
  /// or the upload right moved): the section goes for the sheet's life, the
  /// gate is read again, and [message] is toasted.
  final void Function(String message) onRefused;

  /// A floating toast above the mini player (KeepToast); still shows once
  /// the sheet has gone.
  final void Function(String message) toast;

  const NetworkKeepSlot({
    required this.jobs,
    required this.lead,
    required this.autoSearch,
    this.avoidUrl,
    required this.onLeadAction,
    required this.onStarted,
    required this.onRefused,
    required this.toast,
  });
}

class NetworkLeadSheet extends StatefulWidget {
  final DiscoveryJobsController jobs;
  final DiscoveryLead lead;
  final String? seedTitle;
  final bool autoSearch;
  final String? avoidUrl;
  final VoidCallback? onLeadAction;

  /// An add the server took as new: toasted once the sheet closes (at once
  /// when it answers after).
  final void Function(DiscoveryJob job)? onStarted;

  /// The Peer Recommendations visit's preview answers for [lead], shared
  /// with the sheet's rows (NetworkPreviews.answers).
  final LeadPreviewAnswers? answers;

  const NetworkLeadSheet({
    super.key,
    required this.jobs,
    required this.lead,
    this.seedTitle,
    this.autoSearch = false,
    this.avoidUrl,
    this.onLeadAction,
    this.onStarted,
    this.answers,
  });

  /// The sheet's frame (DraggableScrollableSheet): where it opens and snaps
  /// (both shares of the screen), and below which a drag closes it.
  static const double kOpenSize = 0.62;
  static const double kMaxSize = 0.94;
  static const double kMinSize = 0.40;

  /// Stands in for KEEP A COPY's block (tests): drawn once its gate is
  /// ready, under the section's label; null from it draws no section. Null
  /// (the app) draws the YouTube add's [YoutubeKeepBlock].
  static Widget? Function(BuildContext context, NetworkKeepSlot slot)?
  keepBlock;

  @override
  State<NetworkLeadSheet> createState() => _NetworkLeadSheetState();
}

class _NetworkLeadSheetState extends State<NetworkLeadSheet> {
  DiscoveryJobsController get jobs => widget.jobs;

  /// The lead the sheet acts on: its raw row repaired into the
  /// recommendation every plug-in call sends (as given when it cannot be:
  /// such a row never opens the sheet).
  late final DiscoveryLead _lead = _sendable(widget.lead);

  late final NetworkPreviews _previews;
  VoidCallback? _release;
  bool _acted = false;

  /// KEEP A COPY went away on a press (the server answered 403 or 404: the
  /// plug-in, the jobs gate or the upload right moved): gone for the
  /// sheet's life, whatever the gate reads after.
  bool _keepGone = false;

  static DiscoveryLead _sendable(DiscoveryLead lead) {
    final rec = lead.recommendation;
    return rec == null ? lead : lead.withRaw(rec);
  }

  @override
  void initState() {
    super.initState();
    // A sheet that may show a job polls fast while it is open.
    _release = jobs.holdFast();
    if (jobs.listing == null) unawaited(jobs.activate());
    // Where files land, read again as every sheet that may add does — on
    // the user's own server only.
    unawaited(jobs.loadDestination());
    _previews = NetworkPreviews(
      api: jobs.api,
      recommendation: _lead.raw,
      onPress: _leadAction,
      onGone: _previewGone,
      answers: widget.answers,
    );
    final s = networkSheetSectionsFor(jobs);
    appLog(
      '[lead] sheet open previews=${s.previews.length} '
      'youtube=${s.youtube.name} links=${s.links}',
    );
  }

  @override
  void dispose() {
    // The sheet's clip stops; the song it paused comes back. Another
    // surface's clip (the Peer Recommendations page's) plays on.
    unawaited(PreviewPlayer().end(PreviewEnd.sheetClosed, owner: _previews));
    _previews.dispose();
    _release?.call();
    super.dispose();
  }

  /// The sheet's first lead action (More like this pins its seed).
  void _leadAction() {
    if (_acted) return;
    _acted = true;
    widget.onLeadAction?.call();
  }

  /// Safe once the sheet has gone (an Add to queue or a start answered
  /// after it closed): the root navigator's overlay then.
  void _toast(String message) =>
      KeepToast.show(mounted ? context : null, message);

  /// A preview plug-in answered 403 or 404: its row is gone; the gate is
  /// read again and the user told why the row they pressed went away.
  void _previewGone(String plugin) {
    unawaited(jobs.regate());
    if (mounted) _toast(AppLocalizations.of(context).discoverLeadOptionOff);
  }

  /// KEEP A COPY refused on a press (403 / 404): the section goes, the gate
  /// is read again, and [message] says why ("Adding songs was just turned
  /// off for your account.", "That option was just switched off on this
  /// server.").
  void _keepRefused(String message) {
    unawaited(jobs.regate());
    if (mounted) setState(() => _keepGone = true);
    _toast(message);
  }

  /// An add the server took as new (toasted once the sheet closes).
  void _started(DiscoveryJob job) => widget.onStarted?.call(job);

  Future<void> _openMusicBrainz(String mbid) async {
    final l = AppLocalizations.of(context);
    var ok = false;
    try {
      ok = await openOutside(
        Uri(
          scheme: 'https',
          host: 'musicbrainz.org',
          pathSegments: ['recording', mbid],
        ),
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) _toast(l.discoverToastLinkFailed);
  }

  Future<void> _copyTitle() async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _lead.copyText));
    if (mounted) _toast(l.copiedToClipboard);
  }

  // ── drawing ──────────────────────────────────────────────────────────

  /// Past this text scale the header scrolls away with the sections (only
  /// the grab handle stays): pinned, it would fill most of a small phone's
  /// sheet.
  static const double kPinHeaderUpTo = 1.3;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pin =
        MediaQuery.textScalerOf(context).scale(16) <= 16 * kPinHeaderUpTo;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: NetworkLeadSheet.kOpenSize,
      minChildSize: NetworkLeadSheet.kMinSize,
      maxChildSize: NetworkLeadSheet.kMaxSize,
      snap: true,
      snapSizes: const [NetworkLeadSheet.kOpenSize],
      builder: (context, scroll) => SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([jobs, _previews]),
          builder: (context, _) {
            final s = networkSheetSectionsFor(jobs);
            final keep = _keepCopy(l, s);
            // A row whose plug-in went away on a press stays away.
            final previews = [
              for (final p in s.previews)
                if (!_previews.isGone(p.name)) p,
            ];
            final head = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_header(l), discoverySheetDivider()],
            );
            return CustomScrollView(
              key: const ValueKey('network-lead-sheet'),
              controller: scroll,
              slivers: [
                PinnedHeaderSliver(
                  child: ColoredBox(
                    color: VelvetColors.surface,
                    child: pin
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [const DiscoverySheetGrabHandle(), head],
                          )
                        : const DiscoverySheetGrabHandle(),
                  ),
                ),
                if (!pin) SliverToBoxAdapter(child: head),
                // One box, not a lazy list: the sections keep their state
                // (a search running, a clip's row) however far they scroll.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (previews.isNotEmpty)
                        NetworkPreviewSection(
                          previews: _previews,
                          plugins: previews,
                        ),
                      ?keep,
                      if (previews.isNotEmpty || keep != null) ...[
                        const SizedBox(height: 16),
                        discoverySheetDivider(),
                      ],
                      ..._actions(l, s),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Cover, title, "artist · album · year · length", where it comes from
  /// and how close it sounds to the seed — one header node.
  Widget _header(AppLocalizations l) {
    final lead = _lead;
    final d = lead.durationSeconds;
    final peer = (lead.peerLabel ?? lead.peerName ?? '').trim();
    final seed = (widget.seedTitle ?? '').trim();
    final pct = (lead.similarity * 100).round();
    return MergeSemantics(
      key: const ValueKey('network-lead-header'),
      child: Semantics(
        header: true,
        headingLevel: 1,
        child: DiscoverySheetHeader(
          cover: _cover(),
          title: lead.title,
          byline: [
            if (lead.artist.trim().isNotEmpty) lead.artist.trim(),
            if ((lead.album ?? '').trim().isNotEmpty) lead.album!.trim(),
            if (lead.year != null) '${lead.year}',
            if (d != null)
              keepClock(Duration(milliseconds: (d * 1000).round())),
          ].join(' · '),
          sourceLines: [
            peer.isEmpty
                ? l.discoverFromNetwork
                : '${l.discoverFromNetwork} · $peer',
            // None for a lead reopened from a job (no similarity to tell).
            if (pct > 0)
              seed.isEmpty
                  ? l.discoverLeadMatch(pct)
                  : l.discoverLeadMatchTo(pct, seed),
          ],
        ),
      ),
    );
  }

  /// The first cover a preview brought (Deezer's before iTunes'), else the
  /// network's tile.
  Widget _cover() {
    final tile = discoverySheetTile(Icons.public, shape: BoxShape.rectangle);
    final art = _previews.artwork;
    if (art == null) {
      return KeyedSubtree(key: const ValueKey('lead-cover-tile'), child: tile);
    }
    return ClipRRect(
      key: const ValueKey('lead-cover-art'),
      borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      child: Image.network(
        art.toString(),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        cacheWidth: artCacheSize(60),
        errorBuilder: (_, _, _) => tile,
      ),
    );
  }

  /// KEEP A COPY: the YouTube add. Left out (never greyed) when its gate
  /// refuses or a press found it gone; a 44 px skeleton while the listing
  /// or the destination is still being asked; once ready, the
  /// [YoutubeKeepBlock] (or what [NetworkLeadSheet.keepBlock] draws),
  /// handed a [NetworkKeepSlot].
  Widget? _keepCopy(AppLocalizations l, NetworkSheetSections s) {
    if (_keepGone || s.youtube == YoutubeBlock.hidden) return null;
    final Widget? block;
    if (s.youtube == YoutubeBlock.unknown) {
      block = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: KeepSkeleton(width: double.infinity, height: 44),
      );
    } else {
      final slot = NetworkKeepSlot(
        jobs: jobs,
        lead: _lead,
        autoSearch: widget.autoSearch,
        avoidUrl: widget.avoidUrl,
        onLeadAction: _leadAction,
        onStarted: _started,
        onRefused: _keepRefused,
        toast: _toast,
      );
      final stand = NetworkLeadSheet.keepBlock;
      block = stand != null
          ? stand(context, slot)
          : YoutubeKeepBlock(slot: slot);
    }
    if (block == null) return null;
    return Column(
      key: const ValueKey('lead-keep-copy'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [KeepSheetLabel(l.discoverSheetKeepCopy), block],
    );
  }

  /// "Open elsewhere ›" (or, without the links plug-in, "Open on
  /// MusicBrainz" for a row naming its recording), then "Copy title".
  List<Widget> _actions(AppLocalizations l, NetworkSheetSections s) {
    final mbid = _lead.recordingMbid;
    return [
      if (s.links)
        DiscoverySheetActionRow(
          key: const ValueKey('lead-elsewhere'),
          icon: Icons.open_in_new,
          label: l.discoverSheetOpenElsewhere,
          chevron: true,
          onTap: () => DiscoveryKeepRoutes.openElsewhere(context, jobs, _lead),
        )
      else if (mbid != null)
        DiscoverySheetActionRow(
          key: const ValueKey('lead-musicbrainz'),
          icon: Icons.open_in_new,
          label: l.discoverOpenMusicBrainz,
          onTap: () => unawaited(_openMusicBrainz(mbid)),
        ),
      DiscoverySheetActionRow(
        key: const ValueKey('lead-copy-title'),
        icon: Icons.content_copy,
        label: l.discoverLeadCopyTitle,
        onTap: () => unawaited(_copyTitle()),
      ),
    ];
  }
}
