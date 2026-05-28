import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

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
  AppTheme appTheme = AppTheme.dark;
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

  /// Native AudioTexture response-curve defaults — keep in sync with
  /// audio_texture.cpp (minDb_ / maxDb_ / smoothing_).
  static const List<double> defaultGlobalParams = [-69.7, -20.7, 0.27];

  late final BehaviorSubject<bool> _albumGridStream =
      BehaviorSubject<bool>.seeded(albumGrid);
  late final BehaviorSubject<int> _letterStripStream =
      BehaviorSubject<int>.seeded(letterStripThreshold);
  late final BehaviorSubject<AppTheme> _themeStream =
      BehaviorSubject<AppTheme>.seeded(appTheme);
  late final BehaviorSubject<Locale?> _localeStream =
      BehaviorSubject<Locale?>.seeded(localeOverride);

  /// The forced locale, or `null` to follow the device. Fed straight to
  /// `MaterialApp.locale`.
  Locale? get localeOverride =>
      language == null ? null : Locale(language!);

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
      albumGrid = m['albumGrid'] ?? true;
      fileExplorerMetadata = m['fileExplorerMetadata'] ?? true;
      letterStripThreshold = m['letterStripThreshold'] ?? 25;
      tapBehavior = _readTapBehavior(m);
      appTheme = _readTheme(m);
      eqEnabled = m['eqEnabled'] ?? false;
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
      final lang = m['language'];
      language = lang is String ? lang : null;
      _albumGridStream.add(albumGrid);
      _letterStripStream.add(letterStripThreshold);
      _themeStream.add(appTheme);
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

  Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(jsonEncode({
      'transcode': TranscodeManager().transcodeOn,
      'albumGrid': albumGrid,
      'fileExplorerMetadata': fileExplorerMetadata,
      'letterStripThreshold': letterStripThreshold,
      'tapBehavior': tapBehavior.name,
      'theme': appTheme.name,
      'eqEnabled': eqEnabled,
      'eqBandGains': eqBandGains,
      'visualizerAudioSource': visualizerAudioSource.name,
      'visualizerEngine': visualizerEngine.name,
      'showVisualizerKnobs': showVisualizerKnobs,
      'visualizerGlobalParams': visualizerGlobalParams,
      'visualizerShaderParams': visualizerShaderParams,
      'language': language,
    }));
  }

  Future<void> setTranscode(bool v) async {
    TranscodeManager().transcodeOn = v;
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

  Future<void> setAppTheme(AppTheme v) async {
    appTheme = v;
    _themeStream.add(v);
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
    albumGrid = true;
    fileExplorerMetadata = true;
    letterStripThreshold = 25;
    tapBehavior = TapBehavior.addToQueue;
    appTheme = AppTheme.dark;
    eqEnabled = false;
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
    _localeStream.add(localeOverride);
    await _save();
  }

  Stream<bool> get albumGridStream => _albumGridStream.stream;
  Stream<int> get letterStripStream => _letterStripStream.stream;
  Stream<AppTheme> get themeStream => _themeStream.stream;
  Stream<Locale?> get localeStream => _localeStream.stream;

  void dispose() {
    _albumGridStream.close();
    _letterStripStream.close();
    _themeStream.close();
    _localeStream.close();
  }
}
