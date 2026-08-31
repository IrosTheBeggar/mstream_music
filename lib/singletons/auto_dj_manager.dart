// App-level AutoDJ configuration.
//
// Filters here apply across whichever server is currently driving
// AutoDJ — they aren't tied to any specific library. (Per-server
// fields like minRating + vpath inclusion still live on the Server
// object since those depend on the library.)
//
// Persisted to auto_dj.json next to settings.json. Mirrors the
// webapp's localStorage namespace structurally — same fields, same
// defaults (everything off), same caps.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../objects/server.dart';

/// Which paths feed random-songs' `similarTo` when sonic mode is on — a
/// pure client-side policy (the server statelessly averages whatever
/// arrives; webapp auto-dj.js parity):
///   rolling — the last-N DJ picks (session centroid; the session follows
///             its own vibe and can slowly evolve)
///   locked  — one pinned anchor for the whole session lane ("stay on
///             seed"); the pin itself is session state on the audio handler
/// Persisted under the JSON 'sonicAnchorMode' key by name. Localized
/// labels: SonicAnchorModeLabel in lib/l10n/enum_labels.dart.
enum SonicAnchorMode { rolling, locked }

/// What Auto DJ does when it is switched on with NOTHING queued. With a queue
/// it never applies: the DJ takes its cue from the tracks already there.
///
/// [ask] shows the chooser each time; the other two are what "remember this"
/// stores, so the toggle becomes one tap.
enum EmptyQueueStart {
  /// Ask on every empty-queue start.
  ask,

  /// Pull a random song from the library and build outward from it.
  random,

  /// Drop into the library so the user picks the opening track.
  pick,
}

class AutoDJManager {
  AutoDJManager._privateConstructor();
  static final AutoDJManager _instance = AutoDJManager._privateConstructor();
  factory AutoDJManager() => _instance;

  static const _filename = 'auto_dj.json';

  // Caps mirror webapp/alpha/auto-dj.js — defence against runaway
  // payloads to /api/v1/db/random-songs (which Joi-validates max 200
  // genres / max 50 keywords).
  static const int maxKeywords = 50;
  static const int maxGenres = 200;

  // Keyword filter — applied client-side after the server responds.
  // The server doesn't know about this; we retry the request up to
  // 5 times if responses get blocked.
  bool keywordFilterEnabled = false;
  List<String> keywordFilterWords = [];

  // Genre filter — MOVED to the Server object (autoDJGenreEnabled /
  // autoDJGenreMode / autoDJGenres). Genre strings are a library's own
  // vocabulary, so a list built against one server never made sense applied
  // to another.
  //
  // These three hold what an older auto_dj.json still carries, in memory
  // only, until migrateGenreFilterToServers copies it onto the servers. Null
  // means "nothing left to migrate", which is also the state of every file
  // written since: _save only writes the legacy keys while they are non-null,
  // so the first save after migrating drops them for good. Their presence in
  // the file IS the migration flag — no separate bookkeeping key.
  bool? _legacyGenreEnabled;
  String? _legacyGenreMode;
  List<String>? _legacyGenreValues;

  // BPM continuity — prefer next picks within ±tolerance of the
  // currently playing track's BPM. Server-side via `bpmRanges` (a
  // tight window) plus `bpmRangesWide` (fallback). Tolerance is in
  // raw BPM units (1–20, default 8 matching the webapp slider).
  bool bpmContinuityEnabled = false;
  int bpmTolerance = 8;

  // Track-length window — server-side via `minDuration` / `maxDuration` on
  // POST /api/v1/db/random-songs, in SECONDS. The server applies it at the
  // base-conditions layer and NEVER relaxes it in the waterfall (unlike the
  // BPM windows), so an over-tight window 400s rather than quietly widening.
  //
  // The rails are the off positions: [durationFloorSec] means "no minimum"
  // and [durationCeilSec] means "no maximum", so a bound at either end is
  // simply not sent. That keeps one control able to express min-only,
  // max-only, both, or neither — which is exactly the server's contract.
  bool durationFilterEnabled = false;
  int minDurationSec = 120; // the "skip interludes" default
  int maxDurationSec = durationCeilSec;
  // Tracks the scanner never read a length for are EXCLUDED by default,
  // matching the server: an unknown length can't be shown to satisfy the
  // bound. On a partially-scanned library that can shrink the pool much more
  // than intended, which is what this opts back out of.
  bool allowUnknownDuration = false;

  /// Bottom rail of the length slider — "no minimum".
  static const int durationFloorSec = 0;

  /// Top rail — "no maximum". 20 minutes covers ordinary tracks with room to
  /// spare; anything longer is the case the user wants to keep, not exclude.
  static const int durationCeilSec = 1200;

  /// Slider granularity. 15s steps give 80 divisions — fine enough to land on
  /// a real intent ("over 90 seconds") without pretending to per-second aim.
  static const int durationStepSec = 15;

  // Harmonic mixing — prefer keys that mix well with the currently
  // locked Camelot anchor (which AudioPlayerHandler sets from the
  // first DJ-picked song of a session). Server-side via
  // `musicalKeys` (anchor + 5 neighbours).
  bool harmonicMixingEnabled = false;

  // Sonic similarity — constrain picks to the session's vibe, server-side
  // via the `similarTo` + `minSimilarity` fields on POST
  // /api/v1/db/random-songs (the sonic pool is a hard base constraint the
  // BPM/key waterfall relaxes within). Seeds are the rolling anchor kept in
  // audio_stuff.dart. Only effective when the DJ server advertised
  // `discovery` on ping (Server.discoveryAvailable).
  /// On by default. It is the feature that makes Auto DJ feel like a DJ
  /// rather than shuffle, and leaving it off meant most people never found it.
  ///
  /// Safe to default only because the failure paths degrade now: a server
  /// without the capability disables the switch, one below 6.15.2 disables it
  /// too, and a server that has discovery but no scan data yet drops the
  /// constraint on the first pick and keeps playing (see the suppression in
  /// audio_stuff's autoDJ). Before that, defaulting this on would have meant
  /// Auto DJ producing nothing on any unscanned library.
  ///
  /// This is the FIELD default, so it applies to fresh installs only —
  /// _save() writes every key, so anyone who has ever touched an Auto DJ
  /// setting has an explicit value in auto_dj.json and keeps it.
  bool sonicSimilarityEnabled = true;
  // Raw cosine threshold 0..1 for the sonic pool (server default contract;
  // webapp default 0.55). The Auto DJ screen's slider exposes 0.30–0.80.
  double sonicMinSimilarity = 0.55;

  // Anchor policy for the sonic seeds — see [SonicAnchorMode].
  SonicAnchorMode sonicAnchorMode = SonicAnchorMode.rolling;

  // Explicit sonic seed — "start the session from THIS song" (webapp
  // sonicSeed parity). It wins over the playing track for a session's
  // first pick; the rolling history takes over after that. Tied to the
  // server it was picked from ([sonicSeedServer], a Server.localname) —
  // audio_stuff only sends it when the DJ runs on that server.
  //
  // ONE-SHOT, like the webapp's (resetAnchors consumes it there): set by the
  // empty-queue start flow moments before the DJ is armed, and consumed by
  // the seeded start's own queue clear (_doClearPlaylist), so it never
  // outlives the session it opened. It used to persist forever, which made
  // any later empty-queue setAutoDJ — Android Auto's Shuffle All — silently
  // replay the last seed song instead of starting fresh.
  String? sonicSeedPath; // vpath-form, no leading slash
  String? sonicSeedTitle; // display only
  String? sonicSeedServer;

  /// See [EmptyQueueStart]. Defaults to asking, because guessing wrong here
  /// either plays a song nobody chose or dumps the user in a browser they
  /// didn't ask for.
  EmptyQueueStart emptyQueueStart = EmptyQueueStart.ask;

  /// [Server.localname] Auto DJ was last switched on for, or null when it was
  /// off. Written by the audio handler on every setAutoDJ, and read once at
  /// launch to bring the DJ back up where it was left — armed only, never
  /// playing (see AudioPlayerHandler.restoreAutoDJ).
  String? enabledServer;

  // Single "something changed" stream — the AutoDJ screen subscribes
  // once and rebuilds on each emit. Cheaper than one stream per field
  // for the small surface area here.
  final BehaviorSubject<int> _changeStream = BehaviorSubject<int>.seeded(0);
  int _tick = 0;
  Stream<int> get changeStream => _changeStream.stream;

  void _notify() {
    _tick++;
    _changeStream.add(_tick);
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  // Memoized: the launch path reads this file from two places (the off-the-
  // critical-path warm-up and the Auto DJ restore, which needs the value to
  // actually be there), and one disk round-trip is enough for both.
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final f = await _file;
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      keywordFilterEnabled = m['keywordFilterEnabled'] ?? false;
      keywordFilterWords = List<String>.from(m['keywordFilterWords'] ?? []);
      if (m.containsKey('genreFilterValues') ||
          m.containsKey('genreFilterEnabled')) {
        _legacyGenreEnabled = m['genreFilterEnabled'] == true;
        _legacyGenreMode =
            m['genreFilterMode'] == 'blacklist' ? 'blacklist' : 'whitelist';
        _legacyGenreValues = List<String>.from(m['genreFilterValues'] ?? []);
      }
      bpmContinuityEnabled = m['bpmContinuityEnabled'] ?? false;
      bpmTolerance = (m['bpmTolerance'] ?? 8).clamp(1, 20);
      harmonicMixingEnabled = m['harmonicMixingEnabled'] ?? false;
      // ?? true matches the field default: a stored file that predates the
      // key (rather than one that stored `false`) reads as a fresh install
      // and gets the new default. An explicit false is still an explicit
      // false and survives.
      sonicSimilarityEnabled = m['sonicSimilarityEnabled'] ?? true;
      final sonicSim = m['sonicMinSimilarity'];
      sonicMinSimilarity =
          sonicSim is num ? sonicSim.toDouble().clamp(0.0, 1.0) : 0.55;
      // Hardened like genreFilterMode: stale/unknown stored values fall
      // back to rolling instead of rippling junk into request building.
      sonicAnchorMode = SonicAnchorMode.values.asNameMap()[m['sonicAnchorMode']] ??
          SonicAnchorMode.rolling;
      sonicSeedPath = m['sonicSeedPath'] is String ? m['sonicSeedPath'] : null;
      sonicSeedTitle =
          m['sonicSeedTitle'] is String ? m['sonicSeedTitle'] : null;
      sonicSeedServer =
          m['sonicSeedServer'] is String ? m['sonicSeedServer'] : null;
      // Hardened like sonicAnchorMode: an unknown stored value falls back to
      // asking rather than silently committing the user to a behaviour.
      emptyQueueStart =
          EmptyQueueStart.values.asNameMap()[m['emptyQueueStart']] ??
              EmptyQueueStart.ask;
      durationFilterEnabled = m['durationFilterEnabled'] ?? false;
      // Clamped on read: a hand-edited or future-written file must not put the
      // slider off its own track, and an inverted pair would send a window
      // nothing can satisfy.
      minDurationSec = _clampDuration(m['minDurationSec'], 120);
      maxDurationSec = _clampDuration(m['maxDurationSec'], durationCeilSec);
      if (minDurationSec > maxDurationSec) {
        minDurationSec = durationFloorSec;
        maxDurationSec = durationCeilSec;
      }
      allowUnknownDuration = m['allowUnknownDuration'] ?? false;
      enabledServer = m['enabledServer'] is String ? m['enabledServer'] : null;
      _notify();
    } catch (_) {
      // Corrupt or missing — defaults stand.
    }
  }

  static int _clampDuration(dynamic raw, int fallback) {
    final v = raw is num ? raw.round() : fallback;
    return v.clamp(durationFloorSec, durationCeilSec);
  }

  Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(jsonEncode({
      // Held only until the migration runs; see the field declarations.
      if (_legacyGenreValues != null) ...{
        'genreFilterEnabled': _legacyGenreEnabled ?? false,
        'genreFilterMode': _legacyGenreMode ?? 'whitelist',
        'genreFilterValues': _legacyGenreValues,
      },
      'keywordFilterEnabled': keywordFilterEnabled,
      'keywordFilterWords': keywordFilterWords,
      'bpmContinuityEnabled': bpmContinuityEnabled,
      'bpmTolerance': bpmTolerance,
      'harmonicMixingEnabled': harmonicMixingEnabled,
      'sonicSimilarityEnabled': sonicSimilarityEnabled,
      'sonicMinSimilarity': sonicMinSimilarity,
      'sonicAnchorMode': sonicAnchorMode.name,
      'sonicSeedPath': sonicSeedPath,
      'sonicSeedTitle': sonicSeedTitle,
      'sonicSeedServer': sonicSeedServer,
      'emptyQueueStart': emptyQueueStart.name,
      'enabledServer': enabledServer,
      'durationFilterEnabled': durationFilterEnabled,
      'minDurationSec': minDurationSec,
      'maxDurationSec': maxDurationSec,
      'allowUnknownDuration': allowUnknownDuration,
    }));
  }

  /// Remember which server Auto DJ is running on (null = off). Called from the
  /// audio handler's setAutoDJ, so every path that toggles the DJ — the queue
  /// header, the Auto DJ screen, Android Auto — records itself with no extra
  /// plumbing. No _notify(): the screens read the live on/off state off the
  /// handler's customState, not this field.
  Future<void> setEnabledServer(String? localname) async {
    if (enabledServer == localname) return;
    enabledServer = localname;
    await _save();
  }

  // --- Track-length window ---

  Future<void> setDurationFilterEnabled(bool v) async {
    durationFilterEnabled = v;
    _notify();
    await _save();
  }

  /// Both bounds move together — the slider is one control, and letting them
  /// cross would produce a window with no possible match.
  Future<void> setDurationRange(int minSec, int maxSec) async {
    minDurationSec = minSec.clamp(durationFloorSec, durationCeilSec);
    maxDurationSec = maxSec.clamp(durationFloorSec, durationCeilSec);
    if (minDurationSec > maxDurationSec) {
      final swap = minDurationSec;
      minDurationSec = maxDurationSec;
      maxDurationSec = swap;
    }
    _notify();
    await _save();
  }

  Future<void> setAllowUnknownDuration(bool v) async {
    allowUnknownDuration = v;
    _notify();
    await _save();
  }

  /// The bounds actually worth sending. A rail means "unbounded", so it is
  /// omitted; the server treats a missing bound as no constraint on that side.
  /// Null when the window is wide open, which is the cue to send nothing at
  /// all — including allowUnknownDuration, which the server no-ops without a
  /// window to apply it to.
  ({int? min, int? max})? get activeDurationBounds {
    if (!durationFilterEnabled) return null;
    final min = minDurationSec > durationFloorSec ? minDurationSec : null;
    final max = maxDurationSec < durationCeilSec ? maxDurationSec : null;
    if (min == null && max == null) return null;
    return (min: min, max: max);
  }

  // --- Keyword filter ---

  Future<void> setKeywordFilterEnabled(bool v) async {
    keywordFilterEnabled = v;
    _notify();
    await _save();
  }

  Future<void> addKeyword(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    if (keywordFilterWords.contains(trimmed)) return;
    if (keywordFilterWords.length >= maxKeywords) return;
    keywordFilterWords.add(trimmed);
    _notify();
    await _save();
  }

  Future<void> removeKeyword(String word) async {
    keywordFilterWords.remove(word);
    _notify();
    await _save();
  }

  /// The Auto DJ constraints that describe the LIBRARY rather than the
  /// session: excluded vpaths, minimum rating, genre, track length.
  ///
  /// Shared by the DJ's own picks and by the "Surprise me" opening track so
  /// the two cannot drift. They had: the opener sent only vpaths and rating,
  /// so a genre blacklist or a track-length window was silently skipped for
  /// track one and honoured from track two onward. Anything added here now
  /// reaches both.
  ///
  /// Deliberately EXCLUDES BPM continuity, harmonic mixing and sonic
  /// similarity. Each of those keys off a currently playing track or a locked
  /// anchor, and the caller that needs this most — a cold start on an empty
  /// queue — has neither.
  Map<String, dynamic> libraryFilters(Server server) {
    final out = <String, dynamic>{};
    final ignoreVPaths = <String>[
      for (final e in server.autoDJPaths.entries)
        if (e.value == false) e.key,
    ];
    if (ignoreVPaths.isNotEmpty) out['ignoreVPaths'] = ignoreVPaths;
    if (server.autoDJminRating != null) {
      out['minRating'] = server.autoDJminRating;
    }
    if (server.autoDJGenreEnabled && server.autoDJGenres.isNotEmpty) {
      out['genres'] = server.autoDJGenres;
      out['genreMode'] = server.autoDJGenreMode;
    }
    final bounds = activeDurationBounds;
    if (bounds != null) {
      if (bounds.min != null) out['minDuration'] = bounds.min;
      if (bounds.max != null) out['maxDuration'] = bounds.max;
      if (allowUnknownDuration) out['allowUnknownDuration'] = true;
    }
    return out;
  }

  // --- Genre filter migration (global -> per-server) ---

  /// Copy a pre-move global genre filter onto [servers], once.
  ///
  /// It goes onto EVERY server rather than a chosen one: globally it applied
  /// to whichever server the DJ happened to run on, so writing it everywhere
  /// is what actually preserves the behaviour the user had. A server that
  /// already carries its own genre list is left alone.
  ///
  /// No-ops when there is nothing to migrate, and — importantly — when
  /// [servers] is empty: the values stay in the file for a later launch
  /// rather than being dropped on a boot that raced the server list.
  /// [persistServers] must write the server list to disk — the caller owns
  /// that, so this stays free of ServerManager.
  Future<void> migrateGenreFilterToServers(
      List<Server> servers, Future<void> Function() persistServers) async {
    final values = _legacyGenreValues;
    if (values == null) return;
    if (servers.isEmpty) return;

    for (final s in servers) {
      if (s.autoDJGenres.isNotEmpty) continue;
      s.autoDJGenres = List<String>.from(values.take(maxGenres));
      s.autoDJGenreMode = _legacyGenreMode ?? 'whitelist';
      s.autoDJGenreEnabled = _legacyGenreEnabled ?? false;
    }

    // Order matters, and getting it wrong loses the filter outright: the new
    // home has to be on disk BEFORE the old one is cleared. Writing auto_dj
    // first would mean a failed or interrupted server write left the values
    // in neither file.
    await persistServers();

    _legacyGenreEnabled = null;
    _legacyGenreMode = null;
    _legacyGenreValues = null;
    _notify();
    await _save();
  }

  // --- BPM continuity & harmonic mixing ---

  Future<void> setBpmContinuityEnabled(bool v) async {
    bpmContinuityEnabled = v;
    _notify();
    await _save();
  }

  Future<void> setBpmTolerance(int v) async {
    bpmTolerance = v.clamp(1, 20);
    _notify();
    await _save();
  }

  Future<void> setHarmonicMixingEnabled(bool v) async {
    harmonicMixingEnabled = v;
    _notify();
    await _save();
  }

  Future<void> setSonicSimilarityEnabled(bool v) async {
    sonicSimilarityEnabled = v;
    _notify();
    await _save();
  }

  Future<void> setSonicMinSimilarity(double v) async {
    sonicMinSimilarity = v.clamp(0.0, 1.0);
    _notify();
    await _save();
  }

  Future<void> setSonicAnchorMode(SonicAnchorMode v) async {
    sonicAnchorMode = v;
    _notify();
    await _save();
  }

  Future<void> setSonicSeed(
      {required String path,
      required String title,
      required String server}) async {
    final norm = path.startsWith('/') ? path.substring(1) : path;
    if (norm.isEmpty) return;
    sonicSeedPath = norm;
    sonicSeedTitle = title;
    sonicSeedServer = server;
    _notify();
    await _save();
  }

  Future<void> setEmptyQueueStart(EmptyQueueStart v) async {
    emptyQueueStart = v;
    _notify();
    await _save();
  }

  Future<void> clearSonicSeed() async {
    // No-op when nothing is stored: the seed is one-shot and this runs on
    // every queue clear (see AudioPlayerHandler._doClearPlaylist), so an
    // unconditional body would rewrite auto_dj.json and rebuild the Auto DJ
    // screen on each clear for nothing.
    if (sonicSeedPath == null &&
        sonicSeedTitle == null &&
        sonicSeedServer == null) {
      return;
    }
    sonicSeedPath = null;
    sonicSeedTitle = null;
    sonicSeedServer = null;
    _notify();
    await _save();
  }

  // Returns true if the song should be skipped per the client-side
  // keyword filter. Matches webapp behaviour: checks title/artist/
  // album/filepath joined and lowercased against the keyword list.
  bool isKeywordBlocked(Map<String, dynamic> song) {
    if (!keywordFilterEnabled || keywordFilterWords.isEmpty) return false;
    final meta = (song['metadata'] as Map?) ?? const {};
    final haystack = [
      meta['title'] ?? '',
      meta['artist'] ?? '',
      meta['album'] ?? '',
      song['filepath'] ?? '',
    ].join(' ').toLowerCase();
    for (final word in keywordFilterWords) {
      if (haystack.contains(word.toLowerCase())) return true;
    }
    return false;
  }

  void dispose() {
    _changeStream.close();
  }
}
