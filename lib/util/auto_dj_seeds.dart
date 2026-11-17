// The Auto DJ's session seeds (design E): the More like and Less like lists
// the Seeds page shows, the engine sends as random-songs' positive and
// negative sonic seeds, and quick skips teach. One immutable value holds both
// lists; every operation returns a new value, or the same one when nothing
// changed, so a caller can tell a no-op by identity and skip telling the UI.
//
// The rules live here, not on the handler, because AudioPlayerHandler is
// never built in tests: the caps, the pins, Drift's rotation and expiry, and
// Stay close's freeze are all decided below and unit-tested on plain values.
// The file imports nothing but TrackFacts, so its test stays outside the
// app's import cycle and runs while the rest of lib/ is mid-edit.

import '../objects/play_event.dart';

/// Which of the two seed lists a row is in. More like holds the songs a pick
/// is drawn towards (random-songs' `similarTo`), Less like the ones it is
/// steered away from (`lessLike`).
enum SeedList { moreLike, lessLike }

/// How a row came to be in its list. The engine needs this only to find the
/// Stay close bootstrap row ([anchor]) again. The user's own rows are told
/// apart by [AutoDjSeed.pinned], never by their origin, because the user can
/// pin a row of any origin.
enum SeedOrigin {
  /// A DJ pick of this lane, pushed into More like when it started playing.
  pick,

  /// The song a lane opened on: a seeded start's opener, or in Drift the
  /// song playing at a lane's first pick (the blend, util/auto_dj_wire.dart
  /// blendsOnLaneStart).
  opener,

  /// The one song a Stay close lane admits to start, when More like holds
  /// nothing its request can carry ([AutoDjSeeds.admitAnchor]).
  anchor,

  /// A quick skip that Learn from skips put into Less like.
  skip,

  /// A row the user put there: Add song, a move between the lists, or a row
  /// held aside while the DJ was off. It comes in pinned.
  manual,
}

/// [path] as a seed travels on the wire: without the leading slash that a
/// browsed or searched queue row keeps. The server resolves `similarTo`,
/// `lessLike` and the embeddings route by vpath, and a DJ pick's own path
/// never had one. Pure; unit-tested.
String seedWirePath(String path) =>
    path.startsWith('/') ? path.substring(1) : path;

/// A seed's identity: its server's localname and its [seedWirePath], joined by
/// a NUL. A song is one key whichever form its path came in (a DJ pick's bare
/// vpath, a browsed row's '/'-path), and the same vpath on two servers is two
/// songs, which the old path-keyed owners map could not tell apart.
/// Pure; unit-tested.
String seedKey(String server, String path) =>
    '$server\u0000${seedWirePath(path)}';

/// Whether a row the user adds on the Seeds page (Add song) goes into the
/// held-aside set rather than the live one: while a set is held aside
/// ([held]), with the DJ off ([armed] false), and with it on before its
/// lane's first pick ([lanePicked] false). Every lane edge in Drift starts
/// the live set over (all but the user's pins and the unpinned skips; Stay
/// close keeps every row, [AutoDjSeeds.carryOver]), and with the Seeds
/// page's box ticked a queue clear takes the pins too. A lane that has not
/// picked yet can still meet one: the seeded start that opens it clears the
/// queue once more, as does a Play from here. Held aside, the row survives
/// those and joins at the lane's first pick ([AutoDjSeeds.merge]), where the
/// live set is the lane's to keep. Pure; unit-tested.
bool seedAddHeldAside(
        {required bool held, required bool armed, required bool lanePicked}) =>
    held || !armed || !lanePicked;

/// Whether a queue clear also takes the pinned rows out of both lists (the
/// Seeds page's "Clear pins when the queue is cleared"): the box is ticked
/// ([setting]), the user cleared the queue ([userClear]: Clear queue, or a
/// play that replaces the queue, never the seeded start's own clear) and
/// the queue held a row ([queueHadRows]). Pure; unit-tested.
bool clearsPinsOnClear(
        {required bool userClear,
        required bool queueHadRows,
        required bool setting}) =>
    userClear && queueHadRows && setting;

/// A seed row with the list it is in: what auto_dj.json keeps of the seeds
/// (`pinnedSeeds`, [AutoDjSeeds.storedRows]). In Drift those are the rows
/// the user pinned, so their pins outlive the app; in Stay close every row
/// the page shows, each with its own pin, so the lists come back as they
/// stood.
typedef StoredSeed = ({SeedList list, AutoDjSeed seed});

/// [s] as auto_dj.json stores it: its list, its song, its origin, its own
/// pin and when it came in (ms since the epoch). Not its vector, which the
/// engine fetches again when it needs one. Pure; unit-tested.
Map<String, dynamic> storedSeedToJson(StoredSeed s) => {
      'list': s.list.name,
      'song': s.seed.song.toJson(),
      'origin': s.seed.origin.name,
      'pinned': s.seed.pinned,
      'at': s.seed.addedAt.millisecondsSinceEpoch,
    };

// The range DateTime takes, in ms on either side of the epoch.
const int _maxEpochMs = 8640000000000000;

/// A moment auto_dj.json stores as ms since the epoch ([raw]) read back:
/// null for a missing value, one that is no int and one past the range a
/// DateTime takes. It never throws: the manager's load is one try block,
/// and a throw there would cost every key it reads after this one. Pure;
/// unit-tested.
DateTime? storedTimeFromJson(Object? raw) =>
    raw is int && raw >= -_maxEpochMs && raw <= _maxEpochMs
        ? DateTime.fromMillisecondsSinceEpoch(raw)
        : null;

/// One stored row ([storedSeedToJson]) read back, with no vector. Null for
/// anything that isn't one: not a map, a missing or unknown list, a song
/// [TrackFacts.fromJson] refuses, a local file or a path with nothing left
/// once its slash goes. It keeps its stored pin, and only an explicit
/// `false` reads as unpinned: a file from before the key held the user's
/// pins alone, so a missing key or a junk value reads as pinned. An unknown
/// or missing origin reads as [SeedOrigin.manual], since the origin matters
/// only for an unpinned anchor; a file a newer build wrote keeps its rows. A
/// missing, non-int or out-of-range time reads as [now]
/// ([storedTimeFromJson]). It never throws, so one bad entry can't cost the
/// rest of the file. Pure; unit-tested.
StoredSeed? storedSeedFromJson(Object? json, {required DateTime now}) {
  if (json is! Map) return null;
  final list = SeedList.values.asNameMap()[json['list']];
  final raw = json['song'];
  if (list == null || raw is! Map) return null;
  final song = TrackFacts.fromJson(raw);
  if (song == null ||
      song.isLocalFile ||
      seedWirePath(song.path).isEmpty) {
    return null;
  }
  final origin =
      SeedOrigin.values.asNameMap()[json['origin']] ?? SeedOrigin.manual;
  return (
    list: list,
    seed: AutoDjSeed(
        song: song,
        pinned: json['pinned'] != false,
        origin: origin,
        addedAt: storedTimeFromJson(json['at']) ?? now),
  );
}

/// The stored rows [rows] as one comparable value: each row's list, its own
/// pin and its key, in order. The handler saves the rows only when this
/// changes, so a pick that adds an unpinned row in Drift writes nothing.
/// Pure; unit-tested.
String pinnedSeedsSignature(Iterable<StoredSeed> rows) => [
      // Length-prefixed, so no key can run into the next.
      for (final r in rows)
        '${r.list.name}/${r.seed.pinned ? 'p' : 'u'}/'
            '${r.seed.key.length}/${r.seed.key}',
    ].join();

/// A launch's load of the stored rows [stored] (auto_dj.json's, as read)
/// into [live], in the stored mode: Stay close when [frozen]. [saved] is the
/// save baseline: the signature of [stored] as it was read, pins included,
/// so the first save ([pinnedSeedsToSave]) writes only what differs from the
/// file, such as a row filtered out or capped.
///
/// Drift: only the stored pins come back. A file written in Stay close also
/// holds the rows it showed pinned only because it stood frozen; in Drift
/// those start over with the lane, so the first save writes the pins alone.
/// The pins of the servers [knownServer] knows, capped
/// ([restorablePinnedRows]), go to the oldest end of the lists
/// ([AutoDjSeeds.withPinnedRows]), and the set leaves Stay close
/// ([AutoDjSeeds.inMode]).
///
/// Stay close: every stored row comes back with its own pin, so the lists
/// stand as the page showed them, past [AutoDjSeeds.maxPerList] too when
/// Stay close's one song carried More like there (up to
/// [AutoDjSeeds.maxStoredPerList]). They join a set that is frozen first, so
/// no ring trims More like and nothing is pruned: [live] when it is frozen
/// already (an arm froze the empty set before this ran: a headless one, or
/// a Start that beat the launch restore), the empty set frozen from
/// [frozenAt], when the stored lists froze (else from [now]), or [live]
/// frozen at [now]. A stored skip keeps the Drift time its clock had run
/// when the stored lists froze, moved onto that set's freeze, so the time
/// the app was closed never counts as Drift time. Pure; unit-tested.
({AutoDjSeeds seeds, String saved}) loadStoredPins(
    AutoDjSeeds live, Iterable<StoredSeed> stored,
    {required bool Function(String server) knownServer,
    required bool frozen,
    DateTime? frozenAt,
    required DateTime now}) {
  final saved = pinnedSeedsSignature(stored);
  if (!frozen) {
    final pins = [
      for (final r in stored)
        if (r.seed.pinned) r,
    ];
    return (
      seeds: live
          .withPinnedRows(restorablePinnedRows(pins, knownServer: knownServer))
          .inMode(now, frozen: false),
      saved: saved,
    );
  }
  // Never through freeze() on a set that is not frozen yet: its prune would
  // drop every stored skip as 30 minutes old by the wall clock, and its
  // frozenAt of now would throw the stored pause away.
  final AutoDjSeeds frame;
  if (live.frozen) {
    frame = live;
  } else if (live.isEmpty) {
    frame = AutoDjSeeds(frozen: true, frozenAt: frozenAt ?? now);
  } else {
    frame = live.freeze(now);
  }
  return (
    seeds: frame.withPinnedRows(
        restorablePinnedRows(stored,
            knownServer: knownServer, perList: AutoDjSeeds.maxStoredPerList),
        storedFrozenAt: frozenAt),
    saved: saved,
  );
}

/// The rows to save for [view] (the seeds as the page shows them), given
/// [saved], the signature of the rows last saved ([pinnedSeedsSignature]):
/// null when there is nothing to write, because no launch has taken the
/// stored rows back in yet ([saved] null: the file holds rows this run never
/// read) or what the file keeps ([AutoDjSeeds.storedRows]) is as saved (in
/// Drift, a change that only adds or drops unpinned rows). Else the rows to
/// write, the baseline that follows, and when the lists froze ([frozenAt],
/// null in Drift), both from the one [view], so the file's rows and its
/// frozenAt always agree. A freeze or a thaw writes only when it changes
/// what the file keeps, which takes a row that is no pin: a set of pins
/// alone keeps the same rows in both modes, and its stored frozenAt may then
/// be stale. That is harmless, since only an unpinned Less like row reads
/// it, and whatever brings one into a frozen set changes the rows and
/// writes the frozenAt of the moment. Pure; unit-tested.
({String signature, List<StoredSeed> rows, DateTime? frozenAt})?
    pinnedSeedsToSave(AutoDjSeeds view, {required String? saved}) {
  if (saved == null) return null;
  final rows = view.storedRows;
  final signature = pinnedSeedsSignature(rows);
  return signature == saved
      ? null
      : (
          signature: signature,
          rows: rows,
          frozenAt: view.frozen ? view.frozenAt : null,
        );
}

/// Whether a save of [view] has to take the stored rows in first
/// ([loadStoredPins]): no load has run this run ([saved] null, the
/// baseline [pinnedSeedsToSave] reads), a server is known ([serversKnown])
/// and [view] holds a pin of the user's, which only the user makes before a
/// load. A run that launched with no server (a fresh install, the last
/// server removed) leaves the load undone, and with the DJ never armed
/// nothing else would run it: every pin the user makes would stay unsaved.
/// While no server is known the load waits, since every stored row would
/// read as one of a deleted server; and with no pin in view there is nothing
/// to save, so a run that never pins never touches the file. Pure;
/// unit-tested.
bool pinsLoadOwed(AutoDjSeeds view,
        {required String? saved, required bool serversKnown}) =>
    saved == null && serversKnown && view.pinnedRows.isNotEmpty;

/// The stored rows [entries] (in file order: More like's rows oldest first,
/// then Less like's) that a launch brings back, each with its own pin: the
/// rows of servers [knownServer] knows, once each (a key that appears more
/// than once keeps its last entry), and at most [perList] of each list
/// ([AutoDjSeeds.maxPerList] unless the caller says otherwise: a Stay close
/// load passes [AutoDjSeeds.maxStoredPerList]), in file order. Past it the
/// oldest rows whose stored pin is false go first, then the oldest of all,
/// so a file edited past the bound never costs a pin while an unpinned row
/// stays. Nothing is reversed, so a load followed by a save writes the same
/// list. Pure; unit-tested.
List<StoredSeed> restorablePinnedRows(Iterable<StoredSeed> entries,
    {required bool Function(String server) knownServer,
    int perList = AutoDjSeeds.maxPerList}) {
  final known = [
    for (final e in entries)
      if (knownServer(e.seed.server)) e,
  ];
  final last = <String, int>{};
  for (var i = 0; i < known.length; i++) {
    last[known[i].seed.key] = i;
  }
  final once = [
    for (var i = 0; i < known.length; i++)
      if (last[known[i].seed.key] == i) known[i],
  ];
  final keep = List<bool>.filled(once.length, true);
  for (final list in SeedList.values) {
    final rows = [
      for (var i = 0; i < once.length; i++)
        if (once[i].list == list) i,
    ];
    var over = rows.length - perList;
    // The oldest unpinned rows first, then the oldest of all.
    for (final i in rows) {
      if (over <= 0) break;
      if (!once[i].seed.pinned) {
        keep[i] = false;
        over--;
      }
    }
    for (final i in rows) {
      if (over <= 0) break;
      if (keep[i]) {
        keep[i] = false;
        over--;
      }
    }
  }
  return [
    for (var i = 0; i < once.length; i++)
      if (keep[i]) once[i],
  ];
}

/// One row of a seed list: the song and what the lists know about it.
/// Immutable. Pure; unit-tested.
class AutoDjSeed {
  /// The song as the row shows it, copied from the queue item, the search hit
  /// or the play history it came from. Its path stays in the form it came in,
  /// for display and lookups; [key] and [wirePath] normalise it.
  final TrackFacts song;

  /// The user's own pin. A pinned row never rotates out of More like and
  /// never expires from Less like, and it outlives the lane and the app
  /// ([AutoDjSeeds.carryOver], [AutoDjSeeds.pinnedRows]). Stay close shows
  /// every row pinned without touching this flag ([AutoDjSeeds.shownPinned]),
  /// so going back to Drift gives the user exactly the pins they had.
  final bool pinned;

  /// Why the row is here (see [SeedOrigin]).
  final SeedOrigin origin;

  /// When the row came in. An unpinned Less like row expires
  /// [AutoDjSeeds.lessLikeTtl] after it. [AutoDjSeeds.thaw] moves it forward
  /// by the time the lists stood frozen, so that clock counts Drift time
  /// only. More like rows age by their place in the list instead.
  final DateTime addedAt;

  /// The song's embedding, base64 as the embeddings route answers it. Cached
  /// so a session across several servers can send this Less like row to the
  /// servers that don't hold the song (`lessLikeVectors`). Null until fetched.
  final String? vector;

  /// The model [vector] was computed in. A server only takes vectors of the
  /// model it answers in, so the vectors sent are the ones of the session's
  /// model ([AutoDjSeeds.negativesFor]).
  final String? vectorModel;

  const AutoDjSeed({
    required this.song,
    this.pinned = false,
    required this.origin,
    required this.addedAt,
    this.vector,
    this.vectorModel,
  });

  /// This row's identity ([seedKey]): one song on one server.
  String get key => seedKey(song.server, song.path);

  /// The localname of the server that holds the song: the only server a path
  /// seed resolves on.
  String get server => song.server;

  /// The song's path as the server takes it ([seedWirePath]).
  String get wirePath => seedWirePath(song.path);

  /// This row with the given fields changed. A null argument keeps the
  /// current value, so a cached vector can be replaced but never dropped.
  AutoDjSeed copyWith({
    bool? pinned,
    DateTime? addedAt,
    SeedOrigin? origin,
    String? vector,
    String? vectorModel,
  }) =>
      AutoDjSeed(
        song: song,
        pinned: pinned ?? this.pinned,
        origin: origin ?? this.origin,
        addedAt: addedAt ?? this.addedAt,
        vector: vector ?? this.vector,
        vectorModel: vectorModel ?? this.vectorModel,
      );

  @override
  String toString() => 'AutoDjSeed(${song.server}:${song.path}, '
      '${origin.name}${pinned ? ', pinned' : ''})';
}

/// The Auto DJ's two seed lists, More like and Less like, and whether they
/// stand frozen (Stay close). Immutable: every operation returns a new value,
/// or `this` when it changes nothing. Pure; unit-tested.
///
/// Drift (not [frozen]): DJ picks rotate through More like as they play
/// ([pushPick]); at most [rollingCap] unpinned rows stay, the oldest leaving
/// first. Unpinned Less like rows expire after [lessLikeTtl] ([prune]).
///
/// Stay close ([frozen]): both lists hold still. Every row shows pinned, no
/// pick is pushed, no skip is learned and nothing expires. The stored pins
/// are left as they were, so [thaw] gives them back. A lane with nothing to
/// stay close to takes in one song to start ([admitAnchor]); after that the
/// engine adds and takes out nothing ([culprits]), and only the user's edits
/// change the lists. (A lane whose rows a server refused before it took in
/// its song had nothing to stay close to after all, and takes it in then:
/// util/auto_dj_wire.dart, stayCloseReleases.)
///
/// Either mode: the user's own edits ([addManual], [move], [remove]) work
/// whenever the target list can take a row ([canAdd]). A list holds no more
/// than [maxPerList] rows, but for Stay close's one song, which comes in past
/// it when nothing in More like is usable ([admitAnchor]); and a song is
/// never in both lists, because the server keeps a positive that is also a
/// negative and ignores the negative.
///
/// In Drift the rows the user pinned (the stored pin, not Stay close's look)
/// outlive the lane: a new queue, Stop/Start and a server switch keep them
/// ([carryOver]), and so does an app restart ([storedRows],
/// [withPinnedRows]). The DJ's own unpinned picks start over with each lane,
/// and unpinned Less like rows (skips) keep their clocks through it, though
/// not through a restart. In Stay close every row the page shows outlives
/// all of these, with its own pin and its clock paused, so back in Drift the
/// user still gets exactly their own pins.
class AutoDjSeeds {
  /// How many unpinned rows More like keeps in Drift: the webapp's ring of
  /// five of the up-to-eight seeds the server takes.
  static const int rollingCap = 5;

  /// The most rows a list holds, pinned or not. Stay close's one song is the
  /// one row that comes in past it, up to [maxStoredPerList] ([admitAnchor]).
  static const int maxPerList = 8;

  /// How far Stay close's one song can carry More like ([admitAnchor]: one
  /// song per lane that had nothing to stay close to), and so the most rows
  /// of a list a launch brings back from a file written in Stay close
  /// ([restorablePinnedRows]) and the most More like rows a frozen set takes
  /// in at the load ([withPinnedRows]; Less like stays at [maxPerList]). A
  /// restart therefore keeps every row the page showed; only a file edited
  /// by hand goes past this, and then its oldest unpinned rows go first.
  static const int maxStoredPerList = 2 * maxPerList;

  /// How long an unpinned Less like row lasts, in Drift time.
  static const Duration lessLikeTtl = Duration(minutes: 30);

  // The server's own caps: random-songs takes at most eight `similarTo` paths
  // and at most eight negatives, paths and vectors together. Anything over is
  // a 400 the capability learner can't retry, so the pick would be lost. It
  // happens to equal [maxPerList] but is not the same rule.
  static const int _wireCap = 8;

  /// The positive seeds, oldest first.
  final List<AutoDjSeed> moreLike;

  /// The negative seeds, oldest first.
  final List<AutoDjSeed> lessLike;

  /// Stay close: both lists hold still and every row shows pinned.
  final bool frozen;

  /// When the lists froze, so [thaw] can move the Less like clocks forward by
  /// the time they stood still. Null while not frozen.
  final DateTime? frozenAt;

  /// The lists are taken as given and never changed in place; every
  /// operation builds new ones.
  const AutoDjSeeds({
    this.moreLike = const [],
    this.lessLike = const [],
    this.frozen = false,
    this.frozenAt,
  });

  /// Both lists empty, not frozen: what the handler holds before the first
  /// arm makes a set in the stored mode ([AutoDjSeeds.fresh]).
  static const AutoDjSeeds empty = AutoDjSeeds();

  /// Both lists empty, frozen when [frozen] (the stored mode is Stay close),
  /// with the freeze starting [now].
  factory AutoDjSeeds.fresh({required bool frozen, required DateTime now}) =>
      AutoDjSeeds(frozen: frozen, frozenAt: frozen ? now : null);

  /// Whether both lists are empty.
  bool get isEmpty => moreLike.isEmpty && lessLike.isEmpty;

  /// Whether the page shows [s] pinned: the user pinned it, or Stay close
  /// holds every row in place.
  bool shownPinned(AutoDjSeed s) => frozen || s.pinned;

  /// Whether [list] holds the row [key] ([seedKey]).
  bool has(SeedList list, String key) => _indexOf(_rows(list), key) >= 0;

  /// Whether [list] can take one more row: it has room, or one of its rows
  /// is shown unpinned and can make way. A list of [maxPerList] rows that all
  /// show pinned is full; the page disables Add song and the move into it.
  bool canAdd(SeedList list) {
    final rows = _rows(list);
    return rows.length < maxPerList || rows.any((s) => !shownPinned(s));
  }

  /// [song], a DJ pick that started playing, as the newest More like row
  /// ([origin] says which kind: the seeded start's opener and Drift's blend
  /// of the song playing at a lane's first pick pass [SeedOrigin.opener]).
  ///
  /// It comes in unpinned. A song already in More like moves to the newest
  /// place and keeps its pin and its cached vector. Then the oldest unpinned
  /// rows leave until at most [rollingCap] unpinned rows remain, and never
  /// more than the room the pinned ones leave in [maxPerList], so with eight
  /// rows of the user's own the pick does not get in.
  ///
  /// `this` while frozen (Stay close adds nothing), for a song in Less like
  /// (the user is steering away from it) and for a song with no server or
  /// path (a local file, which no server can resolve).
  AutoDjSeeds pushPick(TrackFacts song,
      {SeedOrigin origin = SeedOrigin.pick, required DateTime now}) {
    if (frozen || !_seedable(song)) return this;
    final key = seedKey(song.server, song.path);
    if (_indexOf(lessLike, key) >= 0) return this;
    final i = _indexOf(moreLike, key);
    // Already the newest row, for the same reason: nothing to move.
    if (i >= 0 && i == moreLike.length - 1 && moreLike[i].origin == origin) {
      return this;
    }
    final old = i < 0 ? null : moreLike[i];
    final row = AutoDjSeed(
      song: song,
      pinned: old?.pinned ?? false,
      origin: origin,
      addedAt: now,
      vector: old?.vector,
      vectorModel: old?.vectorModel,
    );
    return _withRows(
        _fit([..._without(moreLike, key), row], rolling: true), lessLike);
  }

  /// The Stay close bootstrap: [song] becomes the newest More like row, of
  /// origin [SeedOrigin.anchor], when no row there is [usable] (the engine's
  /// test: a row the coming request can carry and that isn't known dead).
  /// The engine asks this once per lane, for the one song a lane with
  /// nothing to stay close to starts from (util/auto_dj_wire.dart,
  /// stayCloseAdmission).
  ///
  /// It ignores [frozen] on purpose. Stay close freezes what is there, and a
  /// lane that starts with nothing would otherwise go unanchored for its
  /// whole life. The row comes in unpinned (shown pinned while frozen), so
  /// in Drift it rotates out like a pick. In Stay close it outlives the lane
  /// with every other row the page shows ([carryOver]).
  ///
  /// It never takes a row out, so the engine never removes one while
  /// frozen. An older lane's anchor that this lane can't carry (one on a
  /// server this lane doesn't ask, say) stays listed beside the new one.
  ///
  /// It comes in even past [maxPerList] (the user's choice, 2026-11-17): a
  /// More like full of rows the lane can't use (the old server's songs after
  /// a move of the DJ, or songs a server refused) would otherwise leave the
  /// lane without sonic similarity until the user removed one. Only then,
  /// since a usable row means nothing is admitted, and once per lane, so the
  /// list grows past eight by one song per lane at most, and never past
  /// [maxStoredPerList], all a restart brings back. The page shows the list
  /// full ([canAdd]) until rows go; a request past eight leaves the stand-in
  /// out before a pin (usableSeeds); Drift trims it back at the thaw.
  ///
  /// `this` when a row is usable, for a song already in either list (its row
  /// would be judged the same way), for a song with no server or path, and
  /// at [maxStoredPerList] rows.
  AutoDjSeeds admitAnchor(TrackFacts song,
      {required bool Function(AutoDjSeed) usable, required DateTime now}) {
    if (!_seedable(song) || moreLike.any(usable)) return this;
    final key = seedKey(song.server, song.path);
    if (_indexOf(lessLike, key) >= 0 || _indexOf(moreLike, key) >= 0) {
      return this;
    }
    if (moreLike.length >= maxStoredPerList) return this;
    return _withRows([
      ...moreLike,
      AutoDjSeed(song: song, origin: SeedOrigin.anchor, addedAt: now),
    ], lessLike);
  }

  /// [song], a DJ pick, was skipped quickly (heard briefly, and not long
  /// enough to count as a play). The handler calls this too for the user's
  /// own song that the lane's start blended into More like, with [learn]
  /// false: nothing is learned from a song the user put on.
  ///
  /// It leaves More like, unless the user pinned it there: then it stays,
  /// and no skip moves it to Less like either. When [learn] (Learn from
  /// skips is on and a server in scope takes negatives) it also becomes the
  /// newest Less like row: unpinned, its 30 minutes starting [now]. A song
  /// already in Less like moves to the newest place with a fresh clock and
  /// keeps its pin. At [maxPerList] rows the oldest unpinned one leaves; with
  /// eight pinned rows the skip is not added.
  ///
  /// `this` while frozen: Stay close neither drops nor learns.
  AutoDjSeeds quickSkip(TrackFacts song,
      {required bool learn, required DateTime now}) {
    if (frozen || !_seedable(song)) return this;
    final key = seedKey(song.server, song.path);
    final i = _indexOf(moreLike, key);
    if (i >= 0 && moreLike[i].pinned) return this;
    final more = i < 0 ? moreLike : _without(moreLike, key);
    var less = lessLike;
    if (learn) {
      final j = _indexOf(lessLike, key);
      final old = j < 0 ? null : lessLike[j];
      // A vector cached on either row is the same song's, so it carries over.
      final cached = old ?? (i < 0 ? null : moreLike[i]);
      final row = AutoDjSeed(
        song: song,
        pinned: old?.pinned ?? false,
        origin: SeedOrigin.skip,
        addedAt: now,
        vector: cached?.vector,
        vectorModel: cached?.vectorModel,
      );
      less = _fit([..._without(lessLike, key), row], rolling: false);
    }
    return _withRows(more, less);
  }

  /// [song] put into [list] by the user (Add song): pinned, the newest row,
  /// and out of the other list, where it can't stay (see the class doc). A
  /// song already in [list] moves to the newest place, pinned. In Drift the
  /// oldest unpinned rows then make way as [pushPick]'s capacity says.
  ///
  /// It works in either mode. `this` when [list] can't take a row
  /// ([canAdd]), and for a song with no server or path.
  AutoDjSeeds addManual(SeedList list, TrackFacts song,
      {required DateTime now}) {
    if (!canAdd(list) || !_seedable(song)) return this;
    final key = seedKey(song.server, song.path);
    final rows = _rows(list);
    final other = _rows(_other(list));
    final i = _indexOf(rows, key);
    final j = _indexOf(other, key);
    final cached = i >= 0 ? rows[i] : (j >= 0 ? other[j] : null);
    final row = AutoDjSeed(
      song: song,
      pinned: true,
      origin: SeedOrigin.manual,
      addedAt: now,
      vector: cached?.vector,
      vectorModel: cached?.vectorModel,
    );
    final target = _fit([..._without(rows, key), row],
        rolling: list == SeedList.moreLike && !frozen);
    return _withLists(list, target, _without(other, key));
  }

  /// The row [key] in [list] pinned or unpinned by the user. Unpinning a Less
  /// like row starts its 30 minutes over from [now], so a row the user just
  /// let go of doesn't vanish at once. An unpinned More like row stays until
  /// the next pick rotates the list, rather than the moment it is let go.
  ///
  /// `this` while frozen: Stay close shows every pin locked, and the stored
  /// pins wait for [thaw] unchanged. Also `this` for a row that isn't there
  /// or already has that pin.
  AutoDjSeeds setPinned(SeedList list, String key, bool pinned,
      {required DateTime now}) {
    if (frozen) return this;
    final rows = _rows(list);
    final i = _indexOf(rows, key);
    if (i < 0 || rows[i].pinned == pinned) return this;
    final restart = !pinned && list == SeedList.lessLike;
    final next = [...rows];
    next[i] = rows[i].copyWith(pinned: pinned, addedAt: restart ? now : null);
    return _withLists(list, next, _rows(_other(list)));
  }

  /// [list] without the row [key], whatever its pin and whichever the mode.
  /// `this` when it isn't there.
  AutoDjSeeds remove(SeedList list, String key) {
    final rows = _rows(list);
    if (_indexOf(rows, key) < 0) return this;
    return _withLists(list, _without(rows, key), _rows(_other(list)));
  }

  /// The row [key] moved to the other list by the user (a row's "More like
  /// this" / "Less like this"): there it is a [SeedOrigin.manual] row, pinned
  /// and the newest, keeping the song and its cached vector. In Drift the
  /// target's oldest unpinned rows then make way as [addManual] says.
  ///
  /// `this` when neither list holds [key], and when the other list can't
  /// take a row ([canAdd]).
  AutoDjSeeds move(String key, {required DateTime now}) {
    final SeedList from;
    if (_indexOf(moreLike, key) >= 0) {
      from = SeedList.moreLike;
    } else if (_indexOf(lessLike, key) >= 0) {
      from = SeedList.lessLike;
    } else {
      return this;
    }
    final to = _other(from);
    if (!canAdd(to)) return this;
    final source = _rows(from);
    final old = source[_indexOf(source, key)];
    final row = AutoDjSeed(
      song: old.song,
      pinned: true,
      origin: SeedOrigin.manual,
      addedAt: now,
      vector: old.vector,
      vectorModel: old.vectorModel,
    );
    final target = _fit([..._rows(to), row],
        rolling: to == SeedList.moreLike && !frozen);
    return _withLists(to, target, _without(source, key));
  }

  /// Both lists without the rows of [origin], whatever their pin.
  AutoDjSeeds removeOrigin(SeedOrigin origin) => _withRows([
        for (final s in moreLike)
          if (s.origin != origin) s,
      ], [
        for (final s in lessLike)
          if (s.origin != origin) s,
      ]);

  /// The lists frozen from [now] (Stay close). The unpinned Less like rows
  /// whose Drift time has already run out by [now] go first ([prune]): the
  /// timers that drop them run on the monotonic clock, which a sleeping
  /// device stops while the rows' clocks run on, so such a row can still be
  /// listed at the switch, and frozen in it would show pinned and go out as
  /// a negative until the thaw. Nothing else changes: the stored pins stay
  /// as they are for [thaw]. `this` when already frozen, so the freeze keeps
  /// the moment it started.
  AutoDjSeeds freeze(DateTime now) {
    if (frozen) return this;
    final live = prune(now);
    return AutoDjSeeds(
        moreLike: live.moreLike,
        lessLike: live.lessLike,
        frozen: true,
        frozenAt: now);
  }

  /// The lists back in Drift at [now]. The user's own pins show again (they
  /// were never changed). Each unpinned Less like clock moves forward by the
  /// time it stood still, so expiry counts Drift time only. More like is
  /// trimmed to [pushPick]'s capacity, oldest unpinned first, since rows the
  /// freeze took in (Add song, the anchor) may have filled it past the ring.
  /// `this` when not frozen.
  AutoDjSeeds thaw(DateTime now) {
    if (!frozen) return this;
    return AutoDjSeeds(
      moreLike: List.unmodifiable(_fit(moreLike, rolling: true)),
      lessLike: List.unmodifiable([
        for (final s in lessLike)
          if (s.pinned)
            s
          else
            s.copyWith(addedAt: s.addedAt.add(_stoodStill(s, now))),
      ]),
    );
  }

  /// The lists without the unpinned Less like rows whose
  /// [lessLikeTtl] has run out by [now]. `this` while frozen, when the clocks
  /// stand still, and when nothing expired.
  AutoDjSeeds prune(DateTime now) {
    if (frozen) return this;
    return _withRows(moreLike, [
      for (final s in lessLike)
        if (s.pinned || now.difference(s.addedAt) < lessLikeTtl) s,
    ]);
  }

  /// When the next unpinned Less like row runs out ([prune]): the earliest
  /// [AutoDjSeed.addedAt] plus [lessLikeTtl]. Null while frozen, and when no
  /// row can expire. The handler arms one timer for it, so the page never
  /// lists an expired row.
  DateTime? get nextExpiry {
    if (frozen) return null;
    DateTime? first;
    for (final s in lessLike) {
      if (s.pinned) continue;
      final due = s.addedAt.add(lessLikeTtl);
      if (first == null || due.isBefore(first)) first = due;
    }
    return first;
  }

  /// Both lists without the rows of the server [localname], whatever their
  /// pin: the server was removed, and nothing else can resolve its paths.
  AutoDjSeeds withoutServer(String localname) => _withRows([
        for (final s in moreLike)
          if (s.server != localname) s,
      ], [
        for (final s in lessLike)
          if (s.server != localname) s,
      ]);

  /// Both lists without the rows whose [AutoDjSeed.key] is in [keys].
  AutoDjSeeds withoutKeys(Set<String> keys) => keys.isEmpty
      ? this
      : _withRows([
          for (final s in moreLike)
            if (!keys.contains(s.key)) s,
        ], [
          for (final s in lessLike)
            if (!keys.contains(s.key)) s,
        ]);

  /// The row [key] with its embedding cached: [vector] (base64) in the model
  /// [modelId]. `this` when no row has that key, or it already holds that
  /// vector.
  AutoDjSeeds withVector(String key, String vector, String modelId) {
    AutoDjSeed cache(AutoDjSeed s) =>
        s.key == key && (s.vector != vector || s.vectorModel != modelId)
            ? s.copyWith(vector: vector, vectorModel: modelId)
            : s;
    return _withRows(
        [for (final s in moreLike) cache(s)], [for (final s in lessLike) cache(s)]);
  }

  /// This (live) set with the rows of [pending], the set the page edits while
  /// the DJ is off or its lane has not picked yet ([seedAddHeldAside]),
  /// imported. The lane's first pick merges it in; until then the page shows
  /// exactly this merge, so held-aside rows never vanish at Start.
  ///
  /// Pending rows are the user's own: they come in as they are there,
  /// pinned unless the user unpinned one, each the newest of its list. A
  /// pending row wins over the same song in either live list, because it is
  /// the user's later word on it; a vector cached on the live row carries
  /// over. An unpinned Less like row keeps the Drift time its clock has
  /// already run. The caps then apply as for any edit, live's oldest
  /// unpinned rows making way first.
  ///
  /// The result is frozen when either set is. The two freeze and thaw
  /// together, so they differ only while live is still the [empty] set
  /// held before the first arm.
  AutoDjSeeds merge(AutoDjSeeds pending, {required DateTime now}) {
    if (pending.isEmpty) return this;
    final isFrozen = frozen || pending.frozen;
    final since = frozen ? frozenAt : pending.frozenAt;
    var more = [...moreLike];
    var less = [...lessLike];
    for (final list in SeedList.values) {
      for (final p in pending._rows(list)) {
        final key = p.key;
        final live = _find(more, key) ?? _find(less, key);
        more = _without(more, key);
        less = _without(less, key);
        var row = p;
        if (row.vector == null && live?.vector != null) {
          row = row.copyWith(vector: live!.vector, vectorModel: live.vectorModel);
        }
        if (list == SeedList.lessLike && !row.pinned) {
          row = row.copyWith(
              addedAt: _clockAt(pending._ran(row, now), row.addedAt,
                  frozen: isFrozen, since: since ?? now, now: now));
        }
        (list == SeedList.moreLike ? more : less).add(row);
      }
    }
    // A frozen live set already past [maxPerList] (Stay close's one song)
    // keeps that many: what comes in makes room as an edit would, oldest
    // unpinned first, but the merge itself takes no row of it out.
    final moreCap = isFrozen && moreLike.length > maxPerList
        ? moreLike.length
        : maxPerList;
    return AutoDjSeeds(
      moreLike: List.unmodifiable(_fit(more, rolling: !isFrozen, cap: moreCap)),
      lessLike: List.unmodifiable(_fit(less, rolling: false)),
      frozen: isFrozen,
      frozenAt: isFrozen ? since : null,
    );
  }

  /// The rows whose STORED pin is set, in both lists, More like's first and
  /// each list in its order (oldest first): what auto_dj.json keeps in Drift
  /// ([storedRows]), and what tells a save that the user pinned a row before
  /// any load ([pinsLoadOwed]). Never a row that only shows pinned because
  /// the lists are frozen (an anchor, a pick frozen from Drift).
  List<StoredSeed> get pinnedRows => [
        for (final s in moreLike)
          if (s.pinned) (list: SeedList.moreLike, seed: s),
        for (final s in lessLike)
          if (s.pinned) (list: SeedList.lessLike, seed: s),
      ];

  /// What auto_dj.json keeps of this set ([storedSeedToJson]). While frozen
  /// (Stay close): every row of both lists, each with its own pin, since
  /// every row the page shows there outlives the lane and the app. In Drift:
  /// the rows the user pinned ([pinnedRows]). More like's first, each list
  /// in its order (oldest first).
  List<StoredSeed> get storedRows => frozen
      ? [
          for (final s in moreLike) (list: SeedList.moreLike, seed: s),
          for (final s in lessLike) (list: SeedList.lessLike, seed: s),
        ]
      : pinnedRows;

  /// This set with the stored rows [rows] (an app restart's,
  /// [restorablePinnedRows]) taken back in, each with its own pin, at the
  /// OLDEST end of their lists, in their order. A song this set already
  /// holds, in either list, keeps this set's row, since that is the later
  /// word on it, and a song never ends up in both lists. A song [rows] names
  /// twice keeps its last entry. The caps then apply: past [maxPerList] (More
  /// like of a frozen set: past [maxStoredPerList], so a Stay close load
  /// keeps what the page showed) the oldest unpinned row goes, and in Drift
  /// More like keeps the ring. `this` when nothing comes in.
  ///
  /// [storedFrozenAt]: the stored lists stood frozen (Stay close) since
  /// then. Into a frozen set, each unpinned Less like row among [rows] keeps
  /// the Drift time its clock had run by that moment, moved onto this set's
  /// own freeze, as [merge] moves the rows of a frozen set held aside. Null
  /// reads as this set's own freeze: nothing is moved.
  AutoDjSeeds withPinnedRows(Iterable<StoredSeed> rows,
      {DateTime? storedFrozenAt}) {
    final held = {
      for (final s in moreLike) s.key,
      for (final s in lessLike) s.key,
    };
    final incoming = [
      for (final r in rows)
        if (_seedable(r.seed.song) && !held.contains(r.seed.key)) r,
    ];
    final last = <String, int>{};
    for (var i = 0; i < incoming.length; i++) {
      last[incoming[i].seed.key] = i;
    }
    // The clock of a stored skip on this set's freeze: the time it had run
    // when the stored lists froze, or none when it came in after that.
    final since = frozenAt;
    AutoDjSeed rebased(AutoDjSeed s) {
      final from = storedFrozenAt;
      if (!frozen || from == null || since == null) return s;
      final ran = s.addedAt.isBefore(from)
          ? from.difference(s.addedAt)
          : Duration.zero;
      final at =
          _clockAt(ran, s.addedAt, frozen: true, since: since, now: since);
      return at == s.addedAt ? s : s.copyWith(addedAt: at);
    }

    final more = <AutoDjSeed>[];
    final less = <AutoDjSeed>[];
    for (var i = 0; i < incoming.length; i++) {
      final r = incoming[i];
      if (last[r.seed.key] != i) continue;
      if (r.list == SeedList.moreLike) {
        more.add(r.seed);
      } else {
        less.add(r.seed.pinned ? r.seed : rebased(r.seed));
      }
    }
    if (more.isEmpty && less.isEmpty) return this;
    // Frozen (a Stay close load), More like keeps what the page showed, past
    // [maxPerList] too when Stay close's one song carried it there.
    return _withRows(
        _fit([...more, ...moreLike],
            rolling: !frozen, cap: frozen ? maxStoredPerList : maxPerList),
        _fit([...less, ...lessLike], rolling: false));
  }

  /// This set as a new lane (a new queue, Stop/Start, a server switch, the
  /// launch restore, Discover's start) starts from it at [now], in the
  /// stored mode: Stay close when [frozen].
  ///
  /// Stay close keeps everything while frozen. Every row of both lists stays
  /// as it is: its own pin, its clock and its cached vector, the user's pins,
  /// an earlier lane's anchor, the picks frozen from Drift, an opener and the
  /// unpinned skips alike, since the page shows every one of them pinned. The
  /// set keeps its frozenAt, so the clocks stay paused and the time it has
  /// stood frozen still counts as pause at the next thaw. A set that is not
  /// frozen yet (only the never-armed [empty] one can be, in Stay close)
  /// freezes at [now] first ([inMode]).
  ///
  /// Drift: every row the user pinned stays, in both lists; every unpinned
  /// Less like row (a skip) stays with its clock untouched, so it keeps its
  /// 30 minutes; every unpinned More like row (a pick, the opener, an
  /// anchor) goes. Cached vectors stay. A set still frozen thaws, its frozen
  /// time counting as pause.
  AutoDjSeeds carryOver(DateTime now, {required bool frozen}) => frozen
      ? inMode(now, frozen: true)
      : _withRows([
          for (final s in moreLike)
            if (s.pinned) s,
        ], lessLike)
          .inMode(now, frozen: false);

  /// This set frozen (Stay close) or not, as [frozen] asks, at [now]: `this`
  /// when it already is, so a frozen set keeps the moment its freeze began;
  /// else [freeze] or [thaw].
  AutoDjSeeds inMode(DateTime now, {required bool frozen}) =>
      frozen ? freeze(now) : thaw(now);

  /// Both lists without the rows the page shows pinned ([shownPinned]): the
  /// Seeds page's "Clear pins when the queue is cleared". In Drift those are
  /// the rows the user pinned, and the unpinned picks and skips stay, the
  /// skips with their clocks. In Stay close every row shows pinned, so both
  /// lists empty, and the set stays frozen from when it froze. `this` when
  /// no row shows pinned.
  AutoDjSeeds withoutPinned() => _withRows([
        for (final s in moreLike)
          if (!shownPinned(s)) s,
      ], [
        for (final s in lessLike)
          if (!shownPinned(s)) s,
      ]);

  /// What becomes of the More like rows [keys] names that a server refused
  /// as seeds: a row the page shows pinned ([shownPinned]: the user's own
  /// pin, or any row while frozen) is set aside, kept on the page but out of
  /// the lane's requests; any other row is dropped. So in Stay close the
  /// engine never takes a row out: a dead row stays listed until the user
  /// removes it. Keys that name no More like row are in neither set.
  ({Set<String> drop, Set<String> setAside}) culprits(Set<String> keys) {
    final drop = <String>{};
    final setAside = <String>{};
    for (final s in moreLike) {
      if (!keys.contains(s.key)) continue;
      (shownPinned(s) ? setAside : drop).add(s.key);
    }
    return (drop: drop, setAside: setAside);
  }

  /// More like's paths as random-songs takes them (`similarTo`): only the
  /// rows of [server] when it is given, since a single-server body may carry
  /// only paths that server holds. At most eight, the newest kept, oldest
  /// first.
  List<String> positivePaths({String? server}) => _newest([
        for (final s in moreLike)
          if ((server == null || s.server == server) && s.wirePath.isNotEmpty)
            s.wirePath,
      ], _wireCap);

  /// The Less like rows to send to [server]: its own songs as `lessLike`
  /// paths, which it resolves itself, then the other servers' songs as
  /// `lessLikeVectors`, only those with a vector cached in [modelId] (the
  /// model the server answers in; none when [modelId] is null). Paths come
  /// first and the two together stay within the server's cap of eight, the
  /// newest of each kept.
  ({List<String> paths, List<String> vectors}) negativesFor(String server,
      {String? modelId}) {
    final paths = _newest([
      for (final s in lessLike)
        if (s.server == server && s.wirePath.isNotEmpty) s.wirePath,
    ], _wireCap);
    final vectors = _newest([
      if (modelId != null)
        for (final s in lessLike)
          if (s.server != server &&
              s.vectorModel == modelId &&
              (s.vector?.isNotEmpty ?? false))
            s.vector!,
    ], _wireCap - paths.length);
    return (paths: paths, vectors: vectors);
  }

  /// The newest [n] More like rows, newest first: the art tiles on the Auto
  /// DJ screen's and quick config's Seeds rows.
  List<AutoDjSeed> tiles([int n = 3]) =>
      n <= 0 ? const [] : moreLike.reversed.take(n).toList();

  @override
  String toString() => 'AutoDjSeeds(more: $moreLike, less: $lessLike'
      '${frozen ? ', frozen' : ''})';

  // ── helpers ──

  List<AutoDjSeed> _rows(SeedList list) =>
      list == SeedList.moreLike ? moreLike : lessLike;

  static SeedList _other(SeedList list) =>
      list == SeedList.moreLike ? SeedList.lessLike : SeedList.moreLike;

  // A song only a server can resolve: a local file (no server) or a row with
  // no path is never a seed.
  static bool _seedable(TrackFacts song) =>
      song.server.isNotEmpty && seedWirePath(song.path).isNotEmpty;

  static int _indexOf(List<AutoDjSeed> rows, String key) =>
      rows.indexWhere((s) => s.key == key);

  static AutoDjSeed? _find(List<AutoDjSeed> rows, String key) {
    final i = _indexOf(rows, key);
    return i < 0 ? null : rows[i];
  }

  static List<AutoDjSeed> _without(List<AutoDjSeed> rows, String key) => [
        for (final s in rows)
          if (s.key != key) s,
      ];

  static List<String> _newest(List<String> items, int n) =>
      items.length <= n ? items : items.sublist(items.length - n);

  /// [rows] trimmed to what a list may hold. Past [cap] ([maxPerList] unless
  /// a frozen set keeps more, Stay close's one song) the oldest row whose
  /// stored pin is false leaves first (the oldest row at all only when every
  /// one is pinned, which only a merge can bring about). With [rolling]
  /// (More like in Drift) the oldest unpinned rows then leave until at most
  /// [rollingCap] remain, and no more than the room the pinned rows leave.
  static List<AutoDjSeed> _fit(List<AutoDjSeed> rows,
      {required bool rolling, int cap = maxPerList}) {
    final out = [...rows];
    while (out.length > cap) {
      final i = out.indexWhere((s) => !s.pinned);
      out.removeAt(i < 0 ? 0 : i);
    }
    if (rolling) {
      final pinned = out.where((s) => s.pinned).length;
      final room =
          maxPerList - pinned < rollingCap ? maxPerList - pinned : rollingCap;
      var unpinned = out.length - pinned;
      while (unpinned > room) {
        out.removeAt(out.indexWhere((s) => !s.pinned));
        unpinned--;
      }
    }
    return out;
  }

  /// This set with [list] holding [rows] and the other list [other].
  AutoDjSeeds _withLists(
          SeedList list, List<AutoDjSeed> rows, List<AutoDjSeed> other) =>
      list == SeedList.moreLike ? _withRows(rows, other) : _withRows(other, rows);

  /// This set with [more] and [less] as its lists, or `this` when they hold
  /// the very same rows in the same order.
  AutoDjSeeds _withRows(List<AutoDjSeed> more, List<AutoDjSeed> less) {
    if (_same(more, moreLike) && _same(less, lessLike)) return this;
    return AutoDjSeeds(
      moreLike: List.unmodifiable(more),
      lessLike: List.unmodifiable(less),
      frozen: frozen,
      frozenAt: frozenAt,
    );
  }

  static bool _same(List<AutoDjSeed> a, List<AutoDjSeed> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// How long [s]'s clock has stood still in this freeze by [now]: since the
  /// freeze began, or since the row came in when that was later. A set
  /// frozen with no recorded start credits no pause.
  Duration _stoodStill(AutoDjSeed s, DateTime now) {
    final since = frozenAt ?? now;
    final from = s.addedAt.isAfter(since) ? s.addedAt : since;
    final d = now.difference(from);
    return d.isNegative ? Duration.zero : d;
  }

  /// How much Drift time [s]'s clock has run in this set by [now].
  Duration _ran(AutoDjSeed s, DateTime now) {
    if (!frozen) return now.difference(s.addedAt);
    final since = frozenAt ?? now;
    return s.addedAt.isBefore(since) ? since.difference(s.addedAt) : Duration.zero;
  }

  /// The [AutoDjSeed.addedAt] that gives a clock which has [ran] the same
  /// count in a set that is [frozen] since [since] (or not frozen). A row
  /// whose clock never ran keeps its own time when it came in after the
  /// freeze began.
  static DateTime _clockAt(Duration ran, DateTime addedAt,
      {required bool frozen, required DateTime since, required DateTime now}) {
    if (!frozen) return now.subtract(ran);
    if (ran == Duration.zero) return addedAt.isAfter(since) ? addedAt : since;
    return since.subtract(ran);
  }
}
