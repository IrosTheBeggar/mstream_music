// What the Seeds page's Add song sheet offers, as the TrackFacts a seed row
// holds: a search hit turned into one, the queue's coming rows turned into
// the Up next section, the playing row Less like's Skipped section opens
// with, and the name a row shows.
//
// Kept apart from the sheet and the page, which reach the whole app through
// the audio handler and the server list, so these rules are tested on plain
// values. The file imports only the data types and the pure seed and facts
// helpers, none of which reach main.dart, so its test runs on its own.

import 'package:audio_service/audio_service.dart' show MediaItem;

import '../objects/display_item.dart';
import '../objects/play_event.dart';
import 'auto_dj_seeds.dart';
import 'track_facts.dart';

/// A song search hit ([DisplayItem], as ApiManager.fetchSongSearch answers)
/// as the facts a seed row keeps, with no fetch.
///
/// The path stays as the hit carries it, with the queue's leading slash;
/// the seed's key and wire path drop it. The art is the hit's art FILE, never
/// a built URL, which carries a token and goes stale. Search answers with
/// lite metadata, which has no hash (it reads as ''), so the hash is left
/// unknown. With no metadata at all (an older server) the title falls back to
/// the hit's name, which the server makes "Artist - Title". The artist is the
/// primary one, as the other seed rows and Recently played show it. Pure;
/// unit-tested.
TrackFacts seedFactsFromItem(DisplayItem i) {
  final md = i.metadata;
  final seconds = md?.durationSeconds;
  return TrackFacts(
    server: i.server?.localname ?? '',
    path: i.data ?? '',
    hash: _text(md?.hash),
    title: _text(md?.title) ?? _text(i.name),
    artist: _text(md?.artist),
    album: _text(md?.album),
    artFile: _text(i.altAlbumArt) ?? _text(md?.albumArt),
    durationMs: seconds == null ? null : (seconds * 1000).round(),
  );
}

/// The Add song sheet's Up next: the queue's rows after the playing one at
/// [index], as seed facts, in queue order, at most [limit].
///
/// Only songs a seed can come from: a server row ([eligible] says which
/// servers the session draws from), never a local file, which no server can
/// resolve. A row whose [seedKey] is in [taken] (the target list has it
/// already) is left out, and a song queued twice shows once. With nothing
/// playing ([index] null) every row is still to come. Under shuffle the play
/// order differs from the queue's, so this is the queue's order, which is
/// what the queue screen shows. Pure; unit-tested.
List<TrackFacts> upNextFacts(List<MediaItem> queue, int? index,
    {required bool Function(String server) eligible,
    Set<String> taken = const {},
    int limit = 20}) {
  final out = <TrackFacts>[];
  final seen = <String>{};
  final start = index == null || index < 0 ? 0 : index + 1;
  for (var i = start; i < queue.length && out.length < limit; i++) {
    final song = trackFactsFor(queue[i]);
    if (song.isLocalFile || seedWirePath(song.path).isEmpty) continue;
    if (!eligible(song.server)) continue;
    final key = seedKey(song.server, song.path);
    if (taken.contains(key) || !seen.add(key)) continue;
    out.add(song);
  }
  return out;
}

/// The song Less like's Skipped section opens with: the queue's row at
/// [index], the playing one that Up next starts after, as seed facts, by Up
/// next's rules for a row ([upNextFacts]): a server song, never a local file,
/// on a server [eligible] lets in, that the target list doesn't hold yet
/// ([taken]). Null with nothing playing ([index] null, or off either end of
/// [queue]) and for a row those rules leave out. Pure; unit-tested.
TrackFacts? playingFacts(List<MediaItem> queue, int? index,
        {required bool Function(String server) eligible,
        Set<String> taken = const {}}) =>
    index == null || index < 0 || index >= queue.length
        ? null
        : upNextFacts([queue[index]], null, eligible: eligible, taken: taken)
            .firstOrNull;

/// The name a seed row and an Add song row show for [song]: its title, else
/// the file's name, as the Auto DJ start prompts name a song they have no
/// title for. Pure; unit-tested.
String seedTitle(TrackFacts song) =>
    _text(song.title) ?? song.path.split('/').last;

// [s] when it holds more than blanks, else null: a field the server sent
// empty says no more than one it left out.
String? _text(String? s) => s == null || s.trim().isEmpty ? null : s;
