/// When "Keep a copy" shows, and which scopes it offers (pure; the design's
/// "When it shows" and the study's client rules).
///
/// Every entry point needs all five: the server's plug-ins on (the ping's
/// `discoveryPlugins`), the copy plug-in listed with that scope, jobs
/// allowed (`jobs.allowed`), the account may upload (ping / boot
/// `noUpload`), and a library that takes new files (the destination is not
/// null). Otherwise it is HIDDEN, never greyed — except that inside an open
/// sheet a missing upload right, or no library to put files in, reads as one
/// plain line ([CopyGateStatus.line], [CopyGate.wordingKey]).
library;

import '../objects/discovery_plugins.dart';

enum CopyGateStatus {
  /// Keep a copy can start.
  ready,

  /// No card and no gap.
  hidden,

  /// One muted line instead of the card ([CopyGate.wordingKey]).
  line,

  /// Not known yet (the listing or the destination is still being asked):
  /// draw nothing until it is.
  unknown,
}

/// Which condition failed.
enum CopyGateBlock {
  /// The server's plug-ins are off (ping / boot `discoveryPlugins`).
  pluginsOff,

  /// federation-copy is not listed (off, or its probe failed).
  notListed,

  /// federation-copy is listed without this scope.
  noScope,

  /// The acquisition gate refuses this account (`jobs.allowed` false).
  jobsNotAllowed,

  /// The listing or the destination could not be read: nothing to confirm
  /// the card by, so none.
  unavailable,

  /// The account may not add files (`noUpload`).
  noUpload,

  /// Uploads are allowed, but no library takes new files (destination null).
  noLibrary,
}

class CopyGate {
  final CopyGateStatus status;
  final CopyGateBlock? block;
  const CopyGate(this.status, [this.block]);

  bool get ready => status == CopyGateStatus.ready;

  /// The sheet draws something: the card, or its one line.
  bool get shown =>
      status == CopyGateStatus.ready || status == CopyGateStatus.line;

  /// The l10n key of the one line the sheet shows instead of the card
  /// (English: "Your account can't add files to this server" / "No library
  /// on your server takes new files"); null when the card shows or nothing
  /// does.
  String? get wordingKey => switch (block) {
        CopyGateBlock.noUpload => kKeepUploadsOffKey,
        CopyGateBlock.noLibrary => kKeepNoLibraryKey,
        _ => null,
      };

  @override
  String toString() => 'CopyGate(${status.name}${block != null ? ', ${block!.name}' : ''})';
}

/// The l10n keys [CopyGate.wordingKey] names.
const String kKeepUploadsOffKey = 'discoverKeepUploadsOff';
const String kKeepNoLibraryKey = 'discoverKeepNoLibrary';

/// The gate for one [scope]. [pluginsAvailable] is the server's flag
/// (Server.discoveryPluginsAvailable); [listing] / [destination] are null
/// while unasked or in flight, and [listingFailed] / [destinationFailed]
/// say they could not be read; [noUpload] is the account's flag
/// (Server.noUpload: null from a server too old to say — then the
/// destination alone decides, worded as "no library").
CopyGate copyGate({
  required bool? pluginsAvailable,
  PluginListing? listing,
  bool listingFailed = false,
  DestinationView? destination,
  bool destinationFailed = false,
  bool? noUpload,
  String scope = kScopeSong,
}) {
  if (pluginsAvailable != true) {
    return const CopyGate(CopyGateStatus.hidden, CopyGateBlock.pluginsOff);
  }
  if (listing == null) {
    return listingFailed
        ? const CopyGate(CopyGateStatus.hidden, CopyGateBlock.unavailable)
        : const CopyGate(CopyGateStatus.unknown);
  }
  final copy = listing.copy;
  if (copy == null) {
    return const CopyGate(CopyGateStatus.hidden, CopyGateBlock.notListed);
  }
  // Never Folder from Discover; a scope the server does not list is hidden.
  if (scope == kScopeFolder || !copy.hasScope(scope)) {
    return const CopyGate(CopyGateStatus.hidden, CopyGateBlock.noScope);
  }
  if (!listing.jobsAllowed) {
    return const CopyGate(CopyGateStatus.hidden, CopyGateBlock.jobsNotAllowed);
  }
  if (noUpload == true) {
    return const CopyGate(CopyGateStatus.line, CopyGateBlock.noUpload);
  }
  if (destination == null) {
    return destinationFailed
        ? const CopyGate(CopyGateStatus.hidden, CopyGateBlock.unavailable)
        : const CopyGate(CopyGateStatus.unknown);
  }
  if (destination.destination == null) {
    return const CopyGate(CopyGateStatus.line, CopyGateBlock.noLibrary);
  }
  return const CopyGate(CopyGateStatus.ready);
}

/// Whether the home's "Copies" row (and the Copies list) can show at all:
/// plug-ins on, the copy plug-in listed, jobs allowed, uploads allowed. No
/// destination needed — a list of copies already made reads fine without
/// one.
bool copiesListVisible({
  required bool? pluginsAvailable,
  PluginListing? listing,
  bool? noUpload,
}) =>
    pluginsAvailable == true &&
    listing?.copy != null &&
    listing!.jobsAllowed &&
    noUpload != true;

bool _hasText(Object? v) => v is String && v.trim().isNotEmpty;

/// The scopes "Keep a copy" offers for a connected-server row's
/// recommendation [rec] (sent UNCHANGED to the job route), in the sheet's
/// order, limited to what [copy] lists:
///   song            any row (never from an album card: [card])
///   album           the row names its album and its artist or album
///                   artist (with a null artist the peer would hand back
///                   every album of that name, by anyone)
///   artist,         the row names its artist — not on a compilation card,
///   artist-missing  whose rows' artists are guests on someone's album
/// Never folder.
List<String> offeredCopyScopes(
  Map<String, dynamic> rec,
  DiscoveryPlugin? copy, {
  bool card = false,
  bool compilation = false,
}) {
  if (copy == null) return const [];
  final album = _hasText(rec['album']);
  final artist = _hasText(rec['artist']);
  final albumArtist = _hasText(rec['albumArtist']);
  return [
    if (!card) kScopeSong,
    if (album && (albumArtist || artist)) kScopeAlbum,
    if (artist && !compilation) ...[kScopeArtist, kScopeArtistMissing],
  ].where(copy.hasScope).toList();
}
