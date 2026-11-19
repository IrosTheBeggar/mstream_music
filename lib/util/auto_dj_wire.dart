// How the Auto DJ's session seeds (util/auto_dj_seeds.dart) go out on the
// wire: the More like rows a pick can send as its positive seeds, the Less
// like keys of a random-songs body and the servers they go to, the repeats a
// pick across several servers passes over, and what the embeddings route
// says about a seed.
//
// The rules live here, away from the handler, because AudioPlayerHandler is
// never built in tests and most of lib/ is one import cycle with it. This
// file imports only audio_service, the Server and TrackFacts objects, the
// seed vector math and the seeds model, so its test runs on plain values
// while the rest of the app is mid-edit.

import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart' show MediaItem;

import '../objects/play_event.dart';
import '../objects/server.dart';
import 'auto_dj_seeds.dart';
import 'seed_vector.dart';

// The server's caps: random-songs takes at most eight `similarTo` paths, and
// at most eight negatives, `lessLike` paths and `lessLikeVectors` together.
// Anything over is a 400 the capability learner can't retry, so the pick
// would be lost.
const int _wireCap = 8;

/// [items] past [n] cut down to the newest [n] (the last ones, since every
/// list here runs oldest first).
List<T> _newest<T>(List<T> items, int n) {
  if (n <= 0) return <T>[];
  return items.length <= n ? items : items.sublist(items.length - n);
}

/// The More like rows a pick's request can carry, as the pairs it sends:
/// each row [usable] accepts, with the server that holds its song, since a
/// path seed resolves only there, and its wire path. Oldest first, at most
/// eight (the server's `similarTo` cap). Past eight the rows stay home as a
/// list past eight trims them: the oldest row whose stored pin is false
/// first, the oldest of all only when every one is pinned. Only Stay close's
/// one song carries More like past eight, so when rows a server refused
/// come back, the user's pins go out and the stand-in waits.
///
/// The old ring kept a path-to-owner map and filtered it by owner name. The
/// test is now the caller's: the single-server body takes the rows on the
/// DJ's own server, a session across several the rows on any of its
/// servers, and neither takes a row found dead this lane. Pure; unit-tested.
List<({String server, String path})> usableSeeds(
    Iterable<AutoDjSeed> rows, bool Function(AutoDjSeed) usable) {
  final kept = [
    for (final s in rows)
      if (s.server.isNotEmpty && s.wirePath.isNotEmpty && usable(s)) s,
  ];
  while (kept.length > _wireCap) {
    final i = kept.indexWhere((s) => !s.pinned);
    kept.removeAt(i < 0 ? 0 : i);
  }
  return [for (final s in kept) (server: s.server, path: s.wirePath)];
}

/// Whether a pick across several servers can carry the More like row [s] as
/// a seed: not one a server refused this lane ([unusable], by key), on a
/// server that is still there ([owner] finds it by localname, null once it
/// is gone) and one of the session's ([inSession]), and, when that is
/// another server than the DJ's ([dj]), one able to hand out its song's
/// vector at all ([canSeed]: discovery on with its scan done, not dropped
/// this session, a build with the embeddings route). The DJ's own rows need
/// no such test, since the single-server body carries them by path.
///
/// A row this rejects is no seed of the pick: Drift falls back to the
/// playing track, and a Stay close lane that has not anchored yet admits its
/// one song to start ([stayCloseAdmission], [AutoDjSeeds.admitAnchor]). A
/// row on a server that can never turn it into a vector would otherwise
/// hold both off for the whole lane, and leave every pick plain random. Nor
/// is a song it rejects taken in as that one song ([stayCloseAdmit]): the
/// lane would be anchored on a row no pick sends. Pure; unit-tested.
bool seedCarriedAcross(AutoDjSeed s,
    {required String dj,
    required Server? Function(String localname) owner,
    required bool Function(String localname) inSession,
    required bool Function(Server owner) canSeed,
    Set<String> unusable = const {}}) {
  if (unusable.contains(s.key)) return false;
  final o = owner(s.server);
  if (o == null || !inSession(s.server)) return false;
  return s.server == dj || canSeed(o);
}

/// Whether a Stay close pick that goes out on the single-server route
/// anchors this once as Drift does, on the explicit seed or the playing
/// track: the session spans several servers ([multiServer]), and its frozen
/// More like holds rows a pick across them can carry ([anyAcross]) but none
/// the single-server body can ([anyHere]). The pick across them ran and
/// found nothing, typically because the servers holding those rows did not
/// answer this time (a tunnel down, a timeout). Without this, every pick
/// stays plain random until they are back, though the DJ's own track plays.
/// No row is admitted for it, so the frozen list is the same when they
/// answer again. Pure; unit-tested.
bool stayCloseFallsBack(
        {required bool multiServer,
        required bool locked,
        required bool anyHere,
        required bool anyAcross}) =>
    multiServer && locked && !anyHere && anyAcross;

/// Stay close's one admission, judged on every Stay close pick with sonic
/// similarity in play: a lane with nothing to stay close to gets one song
/// to start (the first song, or the one playing), and after that nothing is
/// added. [anchored] says the lane already had something to stay close to;
/// [anyUsable], that More like holds a row the pick's request can carry
/// (the rows Stay close carried over from earlier lanes included);
/// [pinFound], that there is a song to admit (the explicit seed, else the
/// playing track) that the pick's request can carry too ([stayCloseAdmit]).
/// A song the user chose to start from comes in through Add song's path
/// instead, pinned ([addsChosenSong]), while More like can take a row; with
/// More like full and nothing in it usable, this admits it as the lane's one
/// song, unpinned, once it plays.
///
/// The lane is anchored from the first pick that finds a usable row, so
/// once the user removes every row nothing is admitted, and picks go
/// without positives until the user adds a song, switches the mode or a new
/// lane starts. [tryAdmit] says to admit the song now: only while the lane
/// is not anchored and no row is usable. The caller marks the lane anchored
/// after an admission only when it changed the set, since a refused one (a
/// song already in a list) added nothing, and the lane is still looking for
/// its one song. A full More like refuses nothing: the one song comes in
/// past eight, up to [AutoDjSeeds.maxStoredPerList] rows
/// ([AutoDjSeeds.admitAnchor]). A lane anchored only by rows a server then
/// refuses, before it took in a song of its own, looks again
/// ([stayCloseReleases]). Pure; unit-tested.
({bool tryAdmit, bool anchored}) stayCloseAdmission(
        {required bool anchored,
        required bool anyUsable,
        required bool pinFound}) =>
    (
      tryAdmit: !anchored && !anyUsable && pinFound,
      anchored: anchored || anyUsable,
    );

/// Stay close's admission on one pick, as the handler runs it on every Stay
/// close pick with sonic similarity in play ([stayCloseAdmission]): [song]
/// (the explicit seed, else the playing track; null with neither) taken
/// into [seeds] as the lane's one song ([AutoDjSeeds.admitAnchor]) while
/// the lane has had nothing to stay close to ([anchored] false) and More
/// like holds no row the pick's request can carry ([usable], the lane's own
/// test of a row).
///
/// The song counts only when that request can carry it as well, judged as
/// the row it would become. One on a server of the session that can't hand
/// out its vector (discovery off or still scanning there, dropped this
/// session, too old), or one a server refused this lane, is no song to
/// stay close to: taken in, it would anchor the lane on a row no pick
/// sends, and every pick after it would go without sonic similarity. So
/// the lane keeps looking, and the next song it can carry comes in,
/// typically the DJ's own next pick.
///
/// [seeds] comes back identical when nothing was taken in; [admitted] says
/// the lane took its one song on this pick, and [anchored] is what the
/// lane's flag becomes. Pure; unit-tested.
({AutoDjSeeds seeds, bool anchored, bool admitted}) stayCloseAdmit(
    AutoDjSeeds seeds,
    {required bool anchored,
    required TrackFacts? song,
    required bool Function(AutoDjSeed) usable,
    required DateTime now}) {
  final r = stayCloseAdmission(
      anchored: anchored,
      anyUsable: seeds.moreLike.any(usable),
      pinFound: song != null &&
          usable(AutoDjSeed(
              song: song, origin: SeedOrigin.anchor, addedAt: now)));
  if (!r.tryAdmit || song == null) {
    return (seeds: seeds, anchored: r.anchored, admitted: false);
  }
  final next = seeds.admitAnchor(song, usable: usable, now: now);
  final took = !identical(next, seeds);
  return (seeds: next, anchored: r.anchored || took, admitted: took);
}

/// Whether the song playing joins More like at a lane's first pick (Drift's
/// blend): at each new start, a new queue, Stop/Start, a server switch or
/// the first pick after an app restart, the DJ's unpinned picks have just
/// gone, and the picks would otherwise follow the user's pins alone,
/// whatever they put on. So the song playing joins, unpinned, beside the
/// pins, and rotates out like any DJ pick.
///
/// Only in Drift ([drift]; Stay close adds nothing on its own), at the
/// lane's first pick ([laneStart]), and for a song the pick's route can use
/// as a More like row ([usable]: a server song the request can carry, never
/// a local file). Never for a song in Less like ([inLessLike]), one More
/// like already holds ([alreadyMoreLike]: a pin, a seeded start's opener, a
/// row carried over), which keeps its place and its pin, or a DJ pick of
/// this lane ([isDjPick]), which joins when it starts playing. Pure;
/// unit-tested.
bool blendsOnLaneStart(
        {required bool drift,
        required bool laneStart,
        required bool usable,
        required bool inLessLike,
        required bool alreadyMoreLike,
        required bool isDjPick}) =>
    drift &&
    laneStart &&
    usable &&
    !inLessLike &&
    !alreadyMoreLike &&
    !isDjPick;

/// Whether a quick skip of the row keyed [key] is one of the song this
/// lane's start blended into More like as the user's own ([blendsOnLaneStart];
/// [blended] is that row's seed key, null in a lane that blended nothing).
/// That song steers the picks like a DJ pick, so a quick skip takes it out
/// of More like as a quick-skipped DJ pick leaves, and nothing is learned
/// from it: it never joins Less like.
///
/// Only for a row the DJ did not queue ([isDjPick] false). A DJ pick the
/// start blended in (a row an earlier lane or run left at the end of the
/// queue, or this lane's DJ serving the blended song again) keeps the DJ
/// pick's own rule, Learn from skips included. And only while More like
/// holds it unpinned ([unpinnedInMoreLike]): a song the user pinned since
/// stays put, so its skip says nothing. Pure; unit-tested.
bool quickSkipsBlend(
        {required String key,
        required String? blended,
        required bool isDjPick,
        required bool unpinnedInMoreLike}) =>
    !isDjPick && blended != null && key == blended && unpinnedInMoreLike;

/// Whether [song], a row of a random-songs answer from the server named
/// [server], is the blended song the user quick-skipped in this lane
/// ([skipped]: its seed key, null when there is none). The DJ never served
/// that song, so the ignoreList the pick round-trips holds no id for it,
/// and out of More like it is no seed either: nothing else keeps it from
/// coming straight back. So the pick passes over it for the rest of the
/// lane, as it passes over a keyword block. Pure; unit-tested.
bool isSkippedBlend(Map<String, dynamic> song, String server, String? skipped) {
  if (skipped == null) return false;
  final path = song['filepath'];
  return path is String && seedKey(server, path) == skipped;
}

/// Whether the single-server body whose More like rows were [sent] carried
/// the song Drift's blend took in at its lane's start ([blend]: that row's
/// seed key, or null once a server has judged it, by taking a body that
/// carried it or by refusing it). Pure; unit-tested.
bool carriesBlend(
        String? blend, Iterable<({String server, String path})> sent) =>
    blend != null && sent.any((r) => seedKey(r.server, r.path) == blend);

/// The More like row a refused single-server body is laid on when neither
/// the server's answer nor the probes say which row it meant ([healed]
/// false). Its 404 "Track not found" or 400 "not analyzed yet" names no
/// path, and a probe can say nothing: a server from before the embeddings
/// route answers each with its HTML 404, and a probe can time out. When the
/// body carried the song Drift's blend took in at the lane's start
/// ([carriesBlend]), that song is the one: the user just put it on, and no
/// server has judged it yet (a new album still being scanned, a track the
/// analyser can't read, a song deleted since it was downloaded). With it
/// out, the rows it joined go again on their own, as the lane's requests
/// went before the blend, and the lane keeps its sonic similarity. Null
/// hands the failure to the usual handling. Pure; unit-tested.
String? blendCulprit(
        {required bool healed,
        required String? blend,
        required Iterable<({String server, String path})> sent}) =>
    !healed && carriesBlend(blend, sent) ? blend : null;

/// Whether a single-server body's sonic fields after a heal ([next]) differ
/// from the ones its server just refused ([refused]; null is none). A heal
/// that takes out a lane's one row leaves Drift to fall back on the song
/// playing, and that can be the very row it took out (the song the lane's
/// start blended in, a seeded start's opener). The same `similarTo` again
/// would only be refused again, so the answer in hand stands for that body
/// and no request is spent on it. Both come from the same builder
/// (AudioPlayerHandler.sonicParams), so equal fields encode alike. Pure;
/// unit-tested.
bool sonicFieldsDiffer(
        Map<String, dynamic>? refused, Map<String, dynamic>? next) =>
    jsonEncode(refused) != jsonEncode(next);

/// Whether a seeded start in Stay close adds its opening song to More like,
/// pinned, the way Add song does: the lists are frozen ([stayClose]), the
/// user chose that song ([chosen]: Recently played, or a pick from the
/// library, never Random) and More like can take a row ([canAdd]). In Drift
/// the opener joins unpinned instead, as the lane's first row. Pure;
/// unit-tested.
bool addsChosenSong(
        {required bool stayClose,
        required bool chosen,
        required bool canAdd}) =>
    stayClose && chosen && canAdd;

/// Whether a Stay close lane looks for its one song again after the engine
/// set More like rows aside (a server refused them as seeds: gone from its
/// library, or not analysed yet): the lists are frozen ([frozen]), the lane
/// has not taken in a song of its own ([admitted] false), and More like
/// holds no row its requests can still carry ([anyUsable] false). Such a
/// lane was anchored only by rows it never could stay close to (a row it
/// carried over, a song the user added, that the server turned down), so
/// it gets its one song as a lane with nothing gets it, and the refused
/// rows stay listed beside it. Never after the lane's own song (one song
/// only), and never for the user's removals, which no refusal goes
/// through: a list the user emptied stays empty. Pure; unit-tested.
bool stayCloseReleases(
        {required bool frozen,
        required bool admitted,
        required bool anyUsable}) =>
    frozen && !admitted && !anyUsable;

/// The servers the next pick would send Less like negatives to: the DJ's
/// own ([dj]), and, in a session across several ([multiServer]), each
/// server the pick may ask ([candidates], the fan-out's), each only when it
/// takes negatives ([Server.lessLikeUsable]), once each. A server of the
/// session that sits every pick out (dropped this session, or without mood
/// scores while a mood is set) is asked nothing, so the negatives it would
/// be sent change no pick. Pure; unit-tested.
List<Server> negativeTargets(
    {Server? dj,
    required bool multiServer,
    Iterable<Server> candidates = const []}) {
  final out = <Server>[];
  final seen = <String>{};
  void add(Server s) {
    if (s.lessLikeUsable && seen.add(s.localname)) out.add(s);
  }

  if (dj != null) add(dj);
  if (multiServer) candidates.forEach(add);
  return out;
}

/// The servers out of [servers] (the Seeds page's seed servers, the home
/// first) whose songs Add song may offer for [list]: the ones whose songs the
/// lane can use there, which is what the engine will actually send. Their
/// order is kept.
///
/// With the DJ off ([dj] null) every one of them, so the page can still be
/// filled before Start. More like: the DJ's own server, whose songs the
/// single-server body carries by path, and, in a session across several
/// servers ([multiServer]), each other one that can hand out its songs'
/// vectors ([canSeed]). Less like: a server the next pick sends negatives to
/// ([negativeTargets]: it takes them, and the pick may ask it), which gets
/// its own songs as paths; a server dropped from the fan-out this session,
/// or one without mood scores while a mood is set, is asked nothing. And, in
/// a session across several servers, one that can hand out its songs'
/// vectors while some OTHER server there takes negatives, which gets them as
/// vectors. Whether a vector's model matches the session's is known only at
/// the pick, so that is left to it.
///
/// Another server's Less like rows reach it only on a pick that goes across
/// the servers. A pick that can't asks the DJ's own server alone, which
/// takes only its own songs: Stay close with no More like row the lane can
/// carry, sonic similarity dropped for the session, a DJ server with
/// nothing to seed from. Those rows wait for the next pick that does, and
/// are offered all the same, since that changes from one pick to the next.
/// Pure; unit-tested.
List<Server> seedAddServersFor(SeedList list, List<Server> servers,
    {required String? dj,
    required bool multiServer,
    required bool Function(Server) canSeed,
    required List<Server> negativeTargets}) {
  if (dj == null) return servers;
  final takers = {for (final t in negativeTargets) t.localname};
  bool usable(Server s) => switch (list) {
        SeedList.moreLike => s.localname == dj || (multiServer && canSeed(s)),
        SeedList.lessLike => takers.contains(s.localname) ||
            (multiServer &&
                canSeed(s) &&
                takers.any((t) => t != s.localname)),
      };
  return [
    for (final s in servers)
      if (usable(s)) s,
  ];
}

/// The Less like negatives a pick would send, server by server ([sent]: each
/// server's localname and its [AutoDjSeeds.negativesFor]), as one value to
/// compare before and after a quick skip. Each server takes its negatives as
/// a set (one similarity floor per song), so their order is left out: a
/// re-skip of a Less like song moves its row to the newest place, which
/// changes nothing a server is sent. Pure; unit-tested.
String negativesSnapshot(
    Map<String, ({List<String> paths, List<String> vectors})> sent) {
  final servers = sent.keys.toList()..sort();
  return jsonEncode([
    for (final s in servers)
      [
        s,
        [...sent[s]!.paths]..sort(),
        [...sent[s]!.vectors]..sort(),
      ],
  ]);
}

/// What the embeddings route (`POST /api/v1/discovery/local/embeddings`)
/// said about one seed path ([EmbeddingsReading]).
enum SeedVerdict {
  /// The song's vector came back.
  vector,

  /// The server has the song but no vector for it yet (`notAnalyzed`).
  notAnalyzed,

  /// The server has no such song: its uniform 404 "Track not found", for a
  /// request that asked about this path alone.
  gone,

  /// Nothing about the song: no answer (a timeout, a dropped connection),
  /// or one that says nothing about it (discovery off, a build without the
  /// route, any other status, a body that doesn't parse, a 404 for a batch
  /// that doesn't say which of its paths is gone).
  unknown,
}

/// The embeddings route's answer for the seed paths it was asked about,
/// path by path ([readEmbeddingsAnswer]). A seed the server can't use (gone,
/// not analysed yet) is told apart from a server that just didn't say,
/// which the old null for all of them could not. Pure; unit-tested.
class EmbeddingsReading {
  /// The model the vectors are in, and their length. Null when none came
  /// back.
  final String? modelId;
  final int? dim;

  /// One verdict per path asked, in the order asked.
  final List<SeedVerdict> verdicts;

  /// The vectors, aligned with [verdicts]: set where a vector came back in
  /// [modelId], null elsewhere.
  final List<Float32List?> vectors;

  /// The route refused the whole batch with its 404 "Track not found": a
  /// path in it is gone, but not which, so each one is worth asking about
  /// on its own.
  final bool someGone;

  const EmbeddingsReading._(
      {this.modelId,
      this.dim,
      required this.verdicts,
      required this.vectors,
      this.someGone = false});

  /// Nothing known about any of [n] paths.
  factory EmbeddingsReading._unknown(int n, {bool someGone = false}) =>
      EmbeddingsReading._(
          verdicts: List.filled(n, SeedVerdict.unknown),
          vectors: List.filled(n, null),
          someGone: someGone);

  /// One reading out of [probes], each the answer for one path asked on its
  /// own, in the order of the paths. The vectors in another model than the
  /// first one's are left out, the way vectors that mean different things
  /// are never averaged; their verdict stays [SeedVerdict.vector], since the
  /// song itself is fine.
  factory EmbeddingsReading.ofProbes(List<EmbeddingsReading> probes) {
    String? modelId;
    int? dim;
    final verdicts = <SeedVerdict>[];
    final vectors = <Float32List?>[];
    for (final p in probes) {
      final verdict =
          p.verdicts.isEmpty ? SeedVerdict.unknown : p.verdicts.first;
      var vector = p.vectors.isEmpty ? null : p.vectors.first;
      if (vector != null) {
        if (modelId == null) {
          modelId = p.modelId;
          dim = p.dim;
        } else if (p.modelId != modelId || p.dim != dim) {
          vector = null;
        }
      }
      verdicts.add(verdict);
      vectors.add(vector);
    }
    return EmbeddingsReading._(
        modelId: modelId, dim: dim, verdicts: verdicts, vectors: vectors);
  }

  /// Whether the server said the path at [i] can't seed: it is gone, or not
  /// analysed yet. A path it said nothing about is not refused.
  bool refuses(int i) =>
      i >= 0 &&
      i < verdicts.length &&
      (verdicts[i] == SeedVerdict.gone ||
          verdicts[i] == SeedVerdict.notAnalyzed);

  /// The vectors that came back, with their model and length, or null when
  /// none did.
  ({String modelId, int dim, List<Float32List> vectors})? get found {
    final got = vectors.nonNulls.toList();
    final id = modelId;
    final d = dim;
    if (got.isEmpty || id == null || d == null) return null;
    return (modelId: id, dim: d, vectors: got);
  }
}

/// The embeddings route's answer, [status] and [body] (no status when
/// nothing answered: a timeout, a dropped connection), read for the
/// [asked] paths ([EmbeddingsReading]).
///
/// A 2xx names the model and the vector length, and holds one entry per
/// path asked, in order, each echoing its `filePath`: a vector of that
/// length, or `notAnalyzed` with a null embedding. The route's 404 "Track
/// not found" refuses the whole batch for one path it can't resolve, so it
/// says [SeedVerdict.gone] only of a path asked alone. Anything else (a
/// 403 "Discovery is disabled", the HTML 404 of a build without the route,
/// a 400, a 5xx, a body that doesn't parse, an entry for another path, a
/// vector of the wrong length) says nothing about the songs. Pure;
/// unit-tested.
EmbeddingsReading readEmbeddingsAnswer(List<String> asked,
    {int? status, String? body}) {
  final n = asked.length;
  if (status == null || n == 0) return EmbeddingsReading._unknown(n);
  Object? decoded;
  try {
    decoded = body == null ? null : jsonDecode(body);
  } on FormatException {
    decoded = null;
  }
  if (status == 404) {
    final error = decoded is Map ? decoded['error'] : null;
    final gone =
        error is String && error.toLowerCase().contains('track not found');
    if (!gone) return EmbeddingsReading._unknown(n);
    if (n == 1) {
      return EmbeddingsReading._(
          verdicts: const [SeedVerdict.gone], vectors: const [null]);
    }
    return EmbeddingsReading._unknown(n, someGone: true);
  }
  if (status < 200 || status > 299 || decoded is! Map) {
    return EmbeddingsReading._unknown(n);
  }
  final model = decoded['model'];
  final modelId = model is Map ? model['id']?.toString() : null;
  final dim = decoded['dim'];
  final tracks = decoded['tracks'];
  if (modelId == null || modelId.isEmpty || dim is! int || dim <= 0) {
    return EmbeddingsReading._unknown(n);
  }
  final verdicts = <SeedVerdict>[];
  final vectors = <Float32List?>[];
  for (var i = 0; i < n; i++) {
    final t = tracks is List && i < tracks.length ? tracks[i] : null;
    var verdict = SeedVerdict.unknown;
    Float32List? vector;
    final echoed = t is Map ? t['filePath'] : null;
    if (t is Map && (echoed == null || echoed == asked[i])) {
      final b64 = t['embedding'];
      if (b64 is String && b64.isNotEmpty) {
        // A vector of another length than the answer names is a server bug,
        // not a verdict on the song.
        vector = decodeWireVector(b64, dim);
        if (vector != null) verdict = SeedVerdict.vector;
      } else if (b64 == null || t['notAnalyzed'] == true) {
        verdict = SeedVerdict.notAnalyzed;
      }
    }
    verdicts.add(verdict);
    vectors.add(vector);
  }
  return EmbeddingsReading._(
      modelId: modelId, dim: dim, verdicts: verdicts, vectors: vectors);
}

/// The Less like keys of a random-songs body (mStream #1108): `lessLike`
/// for [paths] the server resolves itself, `lessLikeVectors` for [vectors]
/// (base64 embeddings of songs it doesn't hold) with the `lessLikeModelId`
/// they were computed in. Both lists run oldest first, as
/// [AutoDjSeeds.negativesFor] gives them.
///
/// Only those three keys, and never `minSimilarity`: the negatives also go
/// out on a pick that dropped its positive seeds, and a `minSimilarity`
/// without a seed is a 400 that loses the pick (the server applies its own
/// floor to negatives sent alone). An empty list is an absent key, since
/// each array must hold at least one item. Vectors go only with a model id,
/// which the server requires beside them. Paths come first and the two
/// together stay within eight, the newest of each kept: a ninth negative is
/// a 400 the learner can't retry. Pure; unit-tested.
Map<String, dynamic> lessLikeParams(
    {List<String> paths = const [],
    List<String> vectors = const [],
    String? modelId}) {
  final own = _newest([
    for (final p in paths)
      if (seedWirePath(p).isNotEmpty) seedWirePath(p),
  ], _wireCap);
  final carried = modelId == null || modelId.isEmpty
      ? const <String>[]
      : _newest([
          for (final v in vectors)
            if (v.isNotEmpty) v,
        ], _wireCap - own.length);
  return {
    if (own.isNotEmpty) 'lessLike': own,
    if (carried.isNotEmpty) ...{
      'lessLikeVectors': carried,
      'lessLikeModelId': modelId,
    },
  };
}

/// What no server may answer a pick across several servers with, as
/// `server|wirePath` keys: a vector seed carries no hashes for a server
/// to exclude on its own, and the ignoreList is only a soft cooldown, so
/// this set is the session's one hard guard against repeats there.
///
/// It holds the playing row ([current] in [queue]), the last five DJ picks
/// at or before it, every row after it (a song queued ahead is a repeat
/// whoever queued it), every More like row ([moreLike]), the seeds the
/// pick sends ([seeds]) and the songs the lane passes over ([avoid]: the
/// blended song the user quick-skipped, [isSkippedBlend]). The old ring
/// held the last five picks QUEUED, the batch ahead among them, in either
/// mode. More like now fills as picks play, holds only the anchor in Stay
/// close, and loses a song the user skipped quickly, so the queue supplies
/// what it no longer does. With no current row every row counts as ahead.
/// Rows with no server (local files) or no path are left out. Pure;
/// unit-tested.
Set<String> fanOutRecentKeys(List<MediaItem> queue, int? current,
    {required Iterable<AutoDjSeed> moreLike,
    Iterable<({String server, String path})> seeds = const [],
    Iterable<({String server, String path})> avoid = const []}) {
  final out = <String>{};
  void add(Object? server, Object? path) {
    if (server is! String || server.isEmpty || path is! String) return;
    final wire = seedWirePath(path);
    if (wire.isNotEmpty) out.add('$server|$wire');
  }

  final cur = current == null || current < 0
      ? -1
      : (current >= queue.length ? queue.length - 1 : current);
  for (var i = cur + 1; i < queue.length; i++) {
    add(queue[i].extras?['server'], queue[i].extras?['path']);
  }
  if (cur >= 0) {
    add(queue[cur].extras?['server'], queue[cur].extras?['path']);
  }
  var picks = 0;
  for (var i = cur; i >= 0 && picks < 5; i--) {
    final extras = queue[i].extras;
    if (extras?['djPick'] != true) continue;
    picks++;
    add(extras?['server'], extras?['path']);
  }
  for (final s in moreLike) {
    add(s.server, s.wirePath);
  }
  for (final s in seeds) {
    add(s.server, s.path);
  }
  for (final s in avoid) {
    add(s.server, s.path);
  }
  return out;
}
