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

  // Genre filter — server-side via the `genres` + `genreMode` fields
  // on POST /api/v1/db/random-songs.
  bool genreFilterEnabled = false;
  String genreFilterMode = 'whitelist'; // 'whitelist' | 'blacklist'
  List<String> genreFilterValues = [];

  // BPM continuity — prefer next picks within ±tolerance of the
  // currently playing track's BPM. Server-side via `bpmRanges` (a
  // tight window) plus `bpmRangesWide` (fallback). Tolerance is in
  // raw BPM units (1–20, default 8 matching the webapp slider).
  bool bpmContinuityEnabled = false;
  int bpmTolerance = 8;

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
  bool sonicSimilarityEnabled = false;
  // Raw cosine threshold 0..1 for the sonic pool (server default contract;
  // webapp default 0.55). The Auto DJ screen's slider exposes 0.30–0.80.
  double sonicMinSimilarity = 0.55;

  // Explicit sonic seed — "start the session from THIS song" (webapp
  // sonicSeed parity). It wins over the playing track for a session's
  // first pick; the rolling history takes over after that. Tied to the
  // server it was picked from ([sonicSeedServer], a Server.localname) —
  // audio_stuff only sends it when the DJ runs on that server. Setting or
  // clearing it is a "new lane": the screen also asks the audio handler to
  // clear its rolling history (customAction 'clearSonicHistory').
  String? sonicSeedPath; // vpath-form, no leading slash
  String? sonicSeedTitle; // display only
  String? sonicSeedServer;

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

  Future<void> load() async {
    try {
      final f = await _file;
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      keywordFilterEnabled = m['keywordFilterEnabled'] ?? false;
      keywordFilterWords = List<String>.from(m['keywordFilterWords'] ?? []);
      genreFilterEnabled = m['genreFilterEnabled'] ?? false;
      genreFilterMode = m['genreFilterMode'] ?? 'whitelist';
      genreFilterValues = List<String>.from(m['genreFilterValues'] ?? []);
      bpmContinuityEnabled = m['bpmContinuityEnabled'] ?? false;
      bpmTolerance = (m['bpmTolerance'] ?? 8).clamp(1, 20);
      harmonicMixingEnabled = m['harmonicMixingEnabled'] ?? false;
      sonicSimilarityEnabled = m['sonicSimilarityEnabled'] ?? false;
      final sonicSim = m['sonicMinSimilarity'];
      sonicMinSimilarity =
          sonicSim is num ? sonicSim.toDouble().clamp(0.0, 1.0) : 0.55;
      sonicSeedPath = m['sonicSeedPath'] is String ? m['sonicSeedPath'] : null;
      sonicSeedTitle =
          m['sonicSeedTitle'] is String ? m['sonicSeedTitle'] : null;
      sonicSeedServer =
          m['sonicSeedServer'] is String ? m['sonicSeedServer'] : null;
      _notify();
    } catch (_) {
      // Corrupt or missing — defaults stand.
    }
  }

  Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(jsonEncode({
      'keywordFilterEnabled': keywordFilterEnabled,
      'keywordFilterWords': keywordFilterWords,
      'genreFilterEnabled': genreFilterEnabled,
      'genreFilterMode': genreFilterMode,
      'genreFilterValues': genreFilterValues,
      'bpmContinuityEnabled': bpmContinuityEnabled,
      'bpmTolerance': bpmTolerance,
      'harmonicMixingEnabled': harmonicMixingEnabled,
      'sonicSimilarityEnabled': sonicSimilarityEnabled,
      'sonicMinSimilarity': sonicMinSimilarity,
      'sonicSeedPath': sonicSeedPath,
      'sonicSeedTitle': sonicSeedTitle,
      'sonicSeedServer': sonicSeedServer,
    }));
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

  // --- Genre filter ---

  Future<void> setGenreFilterEnabled(bool v) async {
    genreFilterEnabled = v;
    _notify();
    await _save();
  }

  Future<void> setGenreFilterMode(String mode) async {
    if (mode != 'whitelist' && mode != 'blacklist') return;
    genreFilterMode = mode;
    _notify();
    await _save();
  }

  Future<void> addGenre(String genre) async {
    final trimmed = genre.trim();
    if (trimmed.isEmpty) return;
    if (genreFilterValues.contains(trimmed)) return;
    if (genreFilterValues.length >= maxGenres) return;
    genreFilterValues.add(trimmed);
    _notify();
    await _save();
  }

  Future<void> removeGenre(String genre) async {
    genreFilterValues.remove(genre);
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

  Future<void> clearSonicSeed() async {
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
