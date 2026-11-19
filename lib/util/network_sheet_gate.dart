/// What the network-lead sheet ("More like this" › From the network) holds,
/// and whether a row's tap opens it at all (pure; the design canvas's
/// NetworkSheet and Degraded boards).
///
/// The sections come from the user's OWN server's plug-in listing: PREVIEW
/// from every preview plug-in that can run ([PluginListing.previews]),
/// KEEP A COPY from the YouTube add's gate (the jobs controller's
/// youtubeGate: youtube listed with acquire, lookup and the song scope,
/// jobs allowed, the upload right, a library to put files in), "Open
/// elsewhere" from the links plug-in. "Copy title" is always there and
/// opens nothing by itself. A section that cannot work is left out, never
/// greyed — the canvas's "Can't add" holds no KEEP A COPY at all, where an
/// open Keep card would say why in one line.
///
/// Never on a network row: the copy plug-in (federation-copy) and
/// federation-play, which act on a connected server's files.
library;

import '../objects/discovery_plugins.dart';
import 'discover_copy_gate.dart';

/// The sheet's KEEP A COPY block (the YouTube add).
enum YoutubeBlock {
  /// No block and no gap.
  hidden,

  /// The listing or the destination is still being asked: a skeleton where
  /// the block goes.
  unknown,

  /// The block shows (Search YouTube can start).
  ready,
}

class NetworkSheetSections {
  /// One preview row each, in the sheet's order (deezer, itunes, then the
  /// rest).
  final List<DiscoveryPlugin> previews;
  final YoutubeBlock youtube;

  /// "Open elsewhere ›" (the links plug-in); without it the sheet offers
  /// "Open on MusicBrainz" when the row names a recording.
  final bool links;

  const NetworkSheetSections({
    this.previews = const [],
    this.youtube = YoutubeBlock.hidden,
    this.links = false,
  });

  /// Nothing but "Copy title": plug-ins off, the listing not read (or
  /// unreadable), nothing listed the sheet can use.
  static const NetworkSheetSections none = NetworkSheetSections();

  /// The sheet has something a row's tap cannot do by itself (a block still
  /// being confirmed counts).
  bool get any =>
      previews.isNotEmpty || youtube != YoutubeBlock.hidden || links;

  @override
  String toString() =>
      'NetworkSheetSections(previews: ${[for (final p in previews) p.name]}, '
      'youtube: ${youtube.name}, links: $links)';
}

/// The KEEP A COPY block for the YouTube add's [gate]: ready shows it,
/// unknown holds its place, and every refusal — the one-line ones
/// included — leaves it out.
YoutubeBlock youtubeBlockOf(CopyGate gate) => switch (gate.status) {
  CopyGateStatus.ready => YoutubeBlock.ready,
  CopyGateStatus.unknown => YoutubeBlock.unknown,
  CopyGateStatus.hidden || CopyGateStatus.line => YoutubeBlock.hidden,
};

/// The sheet's sections. [pluginsAvailable] is the user's own server's flag
/// (Server.discoveryPluginsAvailable — never a seed server's: a connected
/// server's virtual Server pins its flags); [listing] its plug-in listing,
/// null while unasked, in flight or unreadable. [youtubeGate] is the jobs
/// controller's (DiscoveryJobsController.youtubeGate), read as it is — no
/// second gate chain here; [buildShowsYoutube] is the build's switch
/// (DiscoveryJobsController.youtubeShown): off in the Play bundle and iOS
/// release builds, where no YouTube block shows whatever the server says.
NetworkSheetSections networkSheetSections({
  required bool? pluginsAvailable,
  PluginListing? listing,
  required CopyGate youtubeGate,
  required bool buildShowsYoutube,
}) {
  if (pluginsAvailable != true || listing == null) {
    return NetworkSheetSections.none;
  }
  return NetworkSheetSections(
    previews: listing.previews,
    youtube: buildShowsYoutube
        ? youtubeBlockOf(youtubeGate)
        : YoutubeBlock.hidden,
    links: listing.links != null,
  );
}

/// What a tap on a "From the network" row does.
enum NetworkLeadTap {
  /// Opens the network-lead sheet.
  sheet,

  /// Copies "Artist - Title" (today's row: "Copied — go find it!").
  copy,
}

/// The tap on a network row: the sheet when the user's own server's
/// plug-ins are on ([pluginsAvailable]), its listing has answered
/// ([listing]), the row could be made a recommendation the plug-in routes
/// take ([sendable]: objects/discovery.dart sendableRecommendation) and the
/// sheet has something to offer ([sections]); otherwise the copy.
NetworkLeadTap networkLeadTap({
  required bool? pluginsAvailable,
  PluginListing? listing,
  required NetworkSheetSections sections,
  required Map<String, dynamic>? sendable,
}) =>
    pluginsAvailable == true &&
        listing != null &&
        sendable != null &&
        sections.any
    ? NetworkLeadTap.sheet
    : NetworkLeadTap.copy;
