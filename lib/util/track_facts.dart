import 'package:audio_service/audio_service.dart' show MediaItem;

import '../objects/play_event.dart';
import 'media_item_credits.dart';
import 'stream_url.dart';

/// What a play event or an Auto DJ seed needs from a queue item, copied out
/// so it renders offline with no fetch.
///
/// [peerIdOf] gives a federated server's own row id on its parent, the
/// `peerId` the play sync routes a federated play by; PlayTracker.factsFor
/// passes the server list's. Seeds pass none, since nothing they send is
/// routed by peer. The mapping lives here, away from the tracker and the
/// handler, so the code that turns queue rows into seeds can be tested
/// without the app around it. Pure; unit-tested.
TrackFacts trackFactsFor(MediaItem item,
    {int? Function(String server)? peerIdOf}) {
  final extras = item.extras ?? const <String, dynamic>{};
  final server = extras['server'] as String? ?? '';
  final artUrl = extras['artUrl'];
  return TrackFacts(
    server: server,
    peerId: server.isEmpty ? null : peerIdOf?.call(server),
    path: extras['path'] as String? ?? item.id,
    hash: extras['hash'] as String?,
    title: item.title.isEmpty ? null : item.title,
    // The primary artist, not the "A feat. B" credit the item displays:
    // the phone's Top artists and the server's snapshot fallback both group
    // plays by this name.
    artist: primaryArtistOf(item),
    album: item.album,
    artFile: artUrl is String ? albumArtFileFromUrl(artUrl) : null,
    durationMs: item.duration?.inMilliseconds,
  );
}
