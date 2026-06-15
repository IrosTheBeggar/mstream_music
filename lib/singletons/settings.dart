import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../objects/player_layout.dart';
import '../theme/velvet_theme.dart';
import 'transcode.dart';

/// How tapping a song in the browser should behave. The default
/// `addToQueue` matches mStream's classic queue-builder model — taps
/// append; you start playback explicitly. The other two modes are
/// opt-in via Settings → Playback.
enum TapBehavior {
  /// Append to the end of the queue. If the queue was empty, start
  /// playback automatically so the first tap from a clean state
  /// "just works."
  addToQueue,

  /// Replace the queue with all playable songs in the current browser
  /// view (album songs, search results, etc.) and start playback at
  /// the tapped song. Spotify / Apple Music model.
  playFromHere,

  /// Append to the end of the queue, then jump playback to the new
  /// item — every tap interrupts whatever is currently playing while
  /// keeping previously-tapped songs around in queue history.
  appendAndJump;

  // Localized labels: TapBehaviorLabel extension in lib/l10n/enum_labels.dart.
}

/// Which view the app opens into on launch. `browser` is the normal home grid;
/// any other value loads that browser section on top of the home grid at
/// startup, so the system Back button returns to the browser home. Persisted.
enum StartupView {
  browser,
  fileExplorer,
  playlists,
  albums,
  artists,
  rated,
  recent,
  localFiles;

  // Localized labels: StartupViewLabel extension in lib/l10n/enum_labels.dart.
}

/// Which rendering engine the visualizer screen uses. Milkdrop is the
/// projectM Cream-of-the-Crop pack; Shadertoy is our Shadertoy-style
/// fragment shader catalog (drop .glsl files in assets/shaders/ to
/// extend). Persisted so the choice survives app restart.
enum VisualizerEngine {
  milkdrop,
  shader;

  // Localized labels: VisualizerEngineLabel extension in lib/l10n/enum_labels.dart.

  /// Wire kind passed across the MethodChannel to the native bridge.
  /// Must match the enum in visualizer_bridge.cpp.
  int get nativeKind {
    switch (this) {
      case VisualizerEngine.milkdrop:
        return 0;
      case VisualizerEngine.shader:
        return 1;
    }
  }
}

/// Resolution the visualizer is rendered + encoded at when cast to a TV. 1080p
/// is the default (sharp on any Chromecast, modest encode load); 720p trades
/// detail for the lightest load; 4K needs a 4K-capable Chromecast and ~4× the
/// encode work. Persisted.
enum CastVisualizerQuality {
  hd720(1280, 720, '720p'),
  fhd1080(1920, 1080, '1080p'),
  uhd2160(3840, 2160, '4K');

  const CastVisualizerQuality(this.width, this.height, this.label);

  final int width;
  final int height;
  final String label;
}

/// Where the visualizer screen pulls its frame-driving audio data
/// from. `synthesized` (the default) generates fake PCM from playback
/// position — no permissions, works on every platform. `real` taps
/// the OS audio output via `android.media.audiofx.Visualizer` and
/// requires `RECORD_AUDIO` (Android refuses to give an app its own
/// playback waveform without that permission).
enum VisualizerAudioSource {
  synthesized,
  real;

  // Localized labels: VisualizerAudioSourceLabel extension in
  // lib/l10n/enum_labels.dart.
}

/// A category the whole-server DB search (POST /api/v1/db/search) can query.
/// The endpoint exposes these four independently through its `noArtists` /
/// `noAlbums` / `noTitles` / `noFiles` flags, so the search dropdown lets the
/// user tick any combination (see [SettingsManager.searchCategories]).
/// Persisted as a list of names under the JSON 'searchCategories' key.
enum SearchCategory {
  artists,
  albums,
  songs,
  files;

  // Localized labels: SearchCategoryLabel extension in lib/l10n/enum_labels.dart.
}

/// User-tweakable settings persisted to disk as a JSON blob next to
/// servers.json. Uses path_provider — same dependency the rest of the
/// app already pulls in — so no SharedPreferences plugin required.
class SettingsManager {
  SettingsManager._privateConstructor();
  static final SettingsManager _instance = SettingsManager._privateConstructor();
  factory SettingsManager() => _instance;

  static const _filename = 'settings.json';

  bool albumGrid = true;
  bool fileExplorerMetadata = true;
  // The letter-scrub strip hides (and the browser allows long
  // folder/file names to wrap) when a list has fewer than this many
  // items. Single knob driving both behaviors.
  int letterStripThreshold = 25;
  TapBehavior tapBehavior = TapBehavior.addToQueue;
  StartupView startupView = StartupView.browser;
  // Which categories the whole-server search queries. The default
  // (artists + albums + songs, files off) reproduces mStream's classic search;
  // files is opt-in because bare filepath matches are noisy next to titles.
  // The browser toolbar's checkbox dropdown writes this; at least one category
  // is always kept selected (see [toggleSearchCategory]).
  static const Set<SearchCategory> defaultSearchCategories = {
    SearchCategory.artists,
    SearchCategory.albums,
    SearchCategory.songs,
  };
  Set<SearchCategory> searchCategories = defaultSearchCategories;
  AppTheme appTheme = AppTheme.dark;
  // Which Now Playing layout the expanded player uses (Small/Medium/Large/XL).
  PlayerLayout playerLayout = PlayerLayout.medium;
  // Custom accent colour as an ARGB int, or null to use each theme's built-in
  // primary. When set it overrides the accent across all three themes.
  int? accentColor;
  // UI language. `null` means "follow the device locale" (the default);
  // a language code like 'en'/'es' forces that language regardless of
  // the OS setting. Persisted as the JSON 'language' key.
  String? language;
  // Android-only equalizer state. Empty gains list means "apply nothing"
  // (device defaults / flat). Gains are in dB; the valid range and band
  // count are device-dependent and discovered at runtime via
  // AndroidEqualizer.parameters.
  bool eqEnabled = false;
  List<double> eqBandGains = const [];
  // Whether the play queue + position are persisted and restored on the next
  // launch (see QueueStore). On by default.
  bool resumeQueue = true;
  // Whether in-app diagnostic logging is captured (see LogManager) so users can
  // view / copy / share logs from the Diagnostics screen. On by default.
  bool diagnosticsLogging = true;
  // Visualizer audio source — synthesized is the default so the
  // visualizer Just Works without prompting for RECORD_AUDIO. Users
  // can opt into real audio in Settings; the toggle there walks them
  // through the permission flow.
  VisualizerAudioSource visualizerAudioSource =
      VisualizerAudioSource.synthesized;
  // Visualizer rendering engine. Milkdrop is the default — it's the
  // richer engine and the one we shipped first. Shader engine is the
  // lighter alternative driven by the bundled .glsl catalog.
  VisualizerEngine visualizerEngine = VisualizerEngine.milkdrop;

  // Visualizer tuning knobs (Shader engine only). Hidden by default —
  // flipping [showVisualizerKnobs] reveals an in-visualizer slider panel
  // for curious users. Tuned values persist: [visualizerGlobalParams] is
  // the global response-curve override [minDb, maxDb, smoothing] (empty =
  // native defaults), and [visualizerShaderParams] holds per-shader
  // iParams overrides keyed by the shader's asset path.
  bool showVisualizerKnobs = false;
  List<double> visualizerGlobalParams = const [];
  Map<String, List<double>> visualizerShaderParams = {};

  // Whether picking a Chromecast in the cast picker streams the on-device
  // visualizer (rendered to video) instead of plain audio. Sticky across
  // restarts; only meaningful for Chromecast targets.
  bool castVisualizerEnabled = false;

  // Resolution the cast visualizer is rendered + encoded at. Sticky.
  CastVisualizerQuality castVisualizerQuality = CastVisualizerQuality.fhd1080;

  /// Native AudioTexture response-curve defaults — keep in sync with
  /// audio_texture.cpp (minDb_ / maxDb_ / smoothing_).
  static const List<double> defaultGlobalParams = [-69.7, -20.7, 0.27];

  late final BehaviorSubject<bool> _albumGridStream =
      BehaviorSubject<bool>.seeded(albumGrid);
  late final BehaviorSubject<int> _letterStripStream =
      BehaviorSubject<int>.seeded(letterStripThreshold);
  late final BehaviorSubject<AppTheme> _themeStream =
      BehaviorSubject<AppTheme>.seeded(appTheme);
  late final BehaviorSubject<PlayerLayout> _playerLayoutStream =
      BehaviorSubject<PlayerLayout>.seeded(playerLayout);
  late final BehaviorSubject<int?> _accentColorStream =
      BehaviorSubject<int?>.seeded(accentColor);
  late final BehaviorSubject<Locale?> _localeStream =
      BehaviorSubject<Locale?>.seeded(localeOverride);

  /// The forced locale, or `null` to follow the device. Fed straight to
  /// `MaterialApp.locale`. Parses BCP-47-ish codes so script- and
  /// region-qualified values ("zh_Hant", "pt_BR") round-trip correctly
  /// instead of collapsing into a single bogus subtag.
  Locale? get localeOverride {
    final code = language;
    if (code == null) return null;
    final parts = code.split(RegExp(r'[-_]'));
    if (parts.length == 1) return Locale(parts[0]);
    // A 4-letter second subtag is a script (Hans/Hant/…); otherwise
    // treat it as a region/country code.
    if (parts[1].length == 4) {
      return Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: parts[1],
        countryCode: parts.length > 2 ? parts[2] : null,
      );
    }
    return Locale(parts[0], parts[1]);
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  /// Loads from disk, applies values in-memory, and pushes to the
  /// related streams. Call once at app startup.
  Future<void> load() async {
    try {
      final f = await _file;
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      TranscodeManager().transcodeOn = m['transcode'] ?? false;
      final tcCodec = m['transcodeCodec'];
      TranscodeManager().codec =
          TranscodeManager.codecs.contains(tcCodec) ? tcCodec as String : null;
      final tcBitrate = m['transcodeBitrate'];
      TranscodeManager().bitrate = TranscodeManager.bitrates.contains(tcBitrate)
          ? tcBitrate as String
          : null;
      TranscodeManager().rebuildWholeQueue =
          m['transcodeRebuildWholeQueue'] ?? true;
      albumGrid = m['albumGrid'] ?? true;
      fileExplorerMetadata = m['fileExplorerMetadata'] ?? true;
      letterStripThreshold = m['letterStripThreshold'] ?? 25;
      tapBehavior = _readTapBehavior(m);
      startupView = _readStartupView(m);
      searchCategories = _readSearchCategories(m);
      appTheme = _readTheme(m);
      playerLayout = _readPlayerLayout(m);
      final accent = m['accentColor'];
      accentColor = accent is int ? accent : null;
      eqEnabled = m['eqEnabled'] ?? false;
      resumeQueue = m['resumeQueue'] ?? true;
      diagnosticsLogging = m['diagnosticsLogging'] ?? true;
      final rawGains = m['eqBandGains'];
      eqBandGains = rawGains is List
          ? rawGains.whereType<num>().map((n) => n.toDouble()).toList()
          : const [];
      visualizerAudioSource = _readVisualizerAudioSource(m);
      visualizerEngine = _readVisualizerEngine(m);
      showVisualizerKnobs = m['showVisualizerKnobs'] ?? false;
      final rawGlobal = m['visualizerGlobalParams'];
      visualizerGlobalParams = rawGlobal is List
          ? rawGlobal.whereType<num>().map((n) => n.toDouble()).toList()
          : const [];
      visualizerShaderParams = {};
      final rawShaderParams = m['visualizerShaderParams'];
      if (rawShaderParams is Map) {
        rawShaderParams.forEach((k, v) {
          if (k is String && v is List) {
            visualizerShaderParams[k] =
                v.whereType<num>().map((n) => n.toDouble()).toList();
          }
        });
      }
      castVisualizerEnabled = m['castVisualizerEnabled'] ?? false;
      castVisualizerQuality = _readCastVisualizerQuality(m);
      final lang = m['language'];
      language = lang is String ? lang : null;
      _albumGridStream.add(albumGrid);
      _letterStripStream.add(letterStripThreshold);
      _themeStream.add(appTheme);
      _playerLayoutStream.add(playerLayout);
      _accentColorStream.add(accentColor);
      _localeStream.add(localeOverride);
    } catch (_) {
      // Corrupt or missing file: fall back to defaults.
    }
  }

  AppTheme _readTheme(Map<String, dynamic> m) {
    final str = m['theme'];
    if (str is String) {
      for (final t in AppTheme.values) {
        if (t.name == str) return t;
      }
    }
    return AppTheme.dark;
  }

  PlayerLayout _readPlayerLayout(Map<String, dynamic> m) {
    final str = m['playerLayout'];
    if (str is String) {
      for (final p in PlayerLayout.values) {
        if (p.name == str) return p;
      }
    }
    return PlayerLayout.medium;
  }

  VisualizerAudioSource _readVisualizerAudioSource(Map<String, dynamic> m) {
    final str = m['visualizerAudioSource'];
    if (str is String) {
      for (final v in VisualizerAudioSource.values) {
        if (v.name == str) return v;
      }
    }
    return VisualizerAudioSource.synthesized;
  }

  VisualizerEngine _readVisualizerEngine(Map<String, dynamic> m) {
    final str = m['visualizerEngine'];
    if (str is String) {
      for (final v in VisualizerEngine.values) {
        if (v.name == str) return v;
      }
    }
    return VisualizerEngine.milkdrop;
  }

  CastVisualizerQuality _readCastVisualizerQuality(Map<String, dynamic> m) {
    final str = m['castVisualizerQuality'];
    if (str is String) {
      for (final q in CastVisualizerQuality.values) {
        if (q.name == str) return q;
      }
    }
    return CastVisualizerQuality.fhd1080;
  }

  /// Reads tapBehavior, with one-shot migration from the old boolean
  /// `autoPlayOnTap` key. Old `true` is the closest semantic match for
  /// the new `appendAndJump` mode (the behavior the toggle used to
  /// enable verbatim); old `false` defaults to `addToQueue`.
  TapBehavior _readTapBehavior(Map<String, dynamic> m) {
    final str = m['tapBehavior'];
    if (str is String) {
      for (final b in TapBehavior.values) {
        if (b.name == str) return b;
      }
    }
    if (m['autoPlayOnTap'] == true) return TapBehavior.appendAndJump;
    return TapBehavior.addToQueue;
  }

  StartupView _readStartupView(Map<String, dynamic> m) {
    final str = m['startupView'];
    if (str is String) {
      for (final v in StartupView.values) {
        if (v.name == str) return v;
      }
    }
    return StartupView.browser;
  }

  Set<SearchCategory> _readSearchCategories(Map<String, dynamic> m) {
    final raw = m['searchCategories'];
    if (raw is List) {
      final set = <SearchCategory>{};
      for (final item in raw) {
        for (final c in SearchCategory.values) {
          if (c.name == item) set.add(c);
        }
      }
      // Empty/garbage shouldn't leave the user unable to search anything.
      if (set.isNotEmpty) return set;
    }
    // Migrate the pre-multiselect single 'searchScope' enum, if present, so an
    // existing install keeps a sensible selection after upgrading.
    final legacy = m['searchScope'];
    if (legacy is String) return _migrateLegacyScope(legacy);
    return {...defaultSearchCategories};
  }

  /// Maps the old single-select scope name to the equivalent category set.
  static Set<SearchCategory> _migrateLegacyScope(String scope) {
    switch (scope) {
      case 'artists':
        return {SearchCategory.artists};
      case 'albums':
        return {SearchCategory.albums};
      case 'songs':
        return {SearchCategory.songs};
      case 'files':
        return {SearchCategory.files};
      case 'everything':
      default:
        return {...defaultSearchCategories};
    }
  }

  /// Pure toggle used by the checkbox dropdown: flips [c] within [current]
  /// but never empties the set — unchecking the last remaining category is a
  /// no-op (returns [current] unchanged), so a search always has a target.
  static Set<SearchCategory> applyToggle(
      Set<SearchCategory> current, SearchCategory c) {
    if (current.contains(c)) {
      if (current.length == 1) return current;
      return {...current}..remove(c);
    }
    return {...current, c};
  }

  Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(jsonEncode({
      'transcode': TranscodeManager().transcodeOn,
      'transcodeCodec': TranscodeManager().codec,
      'transcodeBitrate': TranscodeManager().bitrate,
      'transcodeRebuildWholeQueue': TranscodeManager().rebuildWholeQueue,
      'albumGrid': albumGrid,
      'fileExplorerMetadata': fileExplorerMetadata,
      'letterStripThreshold': letterStripThreshold,
      'tapBehavior': tapBehavior.name,
      'startupView': startupView.name,
      'searchCategories': searchCategories.map((c) => c.name).toList(),
      'theme': appTheme.name,
      'playerLayout': playerLayout.name,
      'accentColor': accentColor,
      'eqEnabled': eqEnabled,
      'resumeQueue': resumeQueue,
      'diagnosticsLogging': diagnosticsLogging,
      'eqBandGains': eqBandGains,
      'visualizerAudioSource': visualizerAudioSource.name,
      'visualizerEngine': visualizerEngine.name,
      'showVisualizerKnobs': showVisualizerKnobs,
      'visualizerGlobalParams': visualizerGlobalParams,
      'visualizerShaderParams': visualizerShaderParams,
      'castVisualizerEnabled': castVisualizerEnabled,
      'castVisualizerQuality': castVisualizerQuality.name,
      'language': language,
    }));
  }

  Future<void> setTranscode(bool v) async {
    TranscodeManager().transcodeOn = v;
    await _save();
  }

  Future<void> setTranscodeCodec(String? v) async {
    TranscodeManager().codec = v;
    await _save();
  }

  Future<void> setTranscodeBitrate(String? v) async {
    TranscodeManager().bitrate = v;
    await _save();
  }

  Future<void> setTranscodeRebuildWholeQueue(bool v) async {
    TranscodeManager().rebuildWholeQueue = v;
    await _save();
  }

  Future<void> setAlbumGrid(bool v) async {
    albumGrid = v;
    _albumGridStream.add(v);
    await _save();
  }

  Future<void> setFileExplorerMetadata(bool v) async {
    fileExplorerMetadata = v;
    await _save();
  }

  Future<void> setLetterStripThreshold(int v) async {
    letterStripThreshold = v;
    _letterStripStream.add(v);
    await _save();
  }

  Future<void> setTapBehavior(TapBehavior v) async {
    tapBehavior = v;
    await _save();
  }

  Future<void> setStartupView(StartupView v) async {
    startupView = v;
    await _save();
  }

  /// Toggle whether [c] is one of the searched categories. Keeps at least one
  /// category selected (see [applyToggle]); persists only when it changed.
  Future<void> toggleSearchCategory(SearchCategory c) async {
    final next = applyToggle(searchCategories, c);
    if (identical(next, searchCategories)) return; // unchanged (last one)
    searchCategories = next;
    await _save();
  }

  Future<void> setAppTheme(AppTheme v) async {
    appTheme = v;
    _themeStream.add(v);
    await _save();
  }

  Future<void> setPlayerLayout(PlayerLayout v) async {
    playerLayout = v;
    _playerLayoutStream.add(v);
    await _save();
  }

  /// Set the custom accent colour (ARGB int), or `null` to fall back to each
  /// theme's built-in primary.
  Future<void> setAccentColor(int? v) async {
    accentColor = v;
    _accentColorStream.add(v);
    await _save();
  }

  /// Sets the UI language. Pass `null` to follow the device locale.
  Future<void> setLanguage(String? code) async {
    language = code;
    _localeStream.add(localeOverride);
    await _save();
  }

  Future<void> setEqEnabled(bool v) async {
    eqEnabled = v;
    await _save();
  }

  Future<void> setResumeQueue(bool v) async {
    resumeQueue = v;
    await _save();
  }

  Future<void> setDiagnosticsLogging(bool v) async {
    diagnosticsLogging = v;
    await _save();
  }

  Future<void> setEqBandGains(List<double> v) async {
    eqBandGains = v;
    await _save();
  }

  Future<void> setVisualizerAudioSource(VisualizerAudioSource v) async {
    visualizerAudioSource = v;
    await _save();
  }

  Future<void> setVisualizerEngine(VisualizerEngine v) async {
    visualizerEngine = v;
    await _save();
  }

  Future<void> setCastVisualizerEnabled(bool v) async {
    castVisualizerEnabled = v;
    await _save();
  }

  Future<void> setCastVisualizerQuality(CastVisualizerQuality v) async {
    castVisualizerQuality = v;
    await _save();
  }

  Future<void> setShowVisualizerKnobs(bool v) async {
    showVisualizerKnobs = v;
    await _save();
  }

  Future<void> setVisualizerGlobalParams(List<double> v) async {
    visualizerGlobalParams = v;
    await _save();
  }

  /// Persist per-shader iParams overrides for [key] (the shader asset
  /// path). Call on slider release, not every drag tick.
  Future<void> setVisualizerShaderParams(String key, List<double> v) async {
    visualizerShaderParams = {...visualizerShaderParams, key: v};
    await _save();
  }

  /// Drop any saved overrides for [key], reverting it to shader defaults.
  Future<void> clearVisualizerShaderParams(String key) async {
    if (!visualizerShaderParams.containsKey(key)) return;
    visualizerShaderParams = {...visualizerShaderParams}..remove(key);
    await _save();
  }

  Future<void> resetAll() async {
    TranscodeManager().transcodeOn = false;
    TranscodeManager().codec = null;
    TranscodeManager().bitrate = null;
    TranscodeManager().rebuildWholeQueue = true;
    albumGrid = true;
    fileExplorerMetadata = true;
    letterStripThreshold = 25;
    tapBehavior = TapBehavior.addToQueue;
    startupView = StartupView.browser;
    searchCategories = {...defaultSearchCategories};
    appTheme = AppTheme.dark;
    playerLayout = PlayerLayout.medium;
    accentColor = null;
    eqEnabled = false;
    resumeQueue = true;
    diagnosticsLogging = true;
    eqBandGains = const [];
    visualizerAudioSource = VisualizerAudioSource.synthesized;
    visualizerEngine = VisualizerEngine.milkdrop;
    showVisualizerKnobs = false;
    visualizerGlobalParams = const [];
    visualizerShaderParams = {};
    language = null;
    _albumGridStream.add(albumGrid);
    _letterStripStream.add(letterStripThreshold);
    _themeStream.add(appTheme);
    _accentColorStream.add(accentColor);
    _localeStream.add(localeOverride);
    await _save();
  }

  Stream<bool> get albumGridStream => _albumGridStream.stream;
  Stream<int> get letterStripStream => _letterStripStream.stream;
  Stream<AppTheme> get themeStream => _themeStream.stream;
  Stream<PlayerLayout> get playerLayoutStream => _playerLayoutStream.stream;
  Stream<int?> get accentColorStream => _accentColorStream.stream;
  Stream<Locale?> get localeStream => _localeStream.stream;

  void dispose() {
    _albumGridStream.close();
    _letterStripStream.close();
    _themeStream.close();
    _playerLayoutStream.close();
    _accentColorStream.close();
    _localeStream.close();
  }
}
