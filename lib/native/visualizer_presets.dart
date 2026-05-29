// Loads visualizer presets bundled as Flutter assets and pushes them
// into the running native engine via [VisualizerBridge.loadPreset].
//
// Engine-aware:
//   ProjectM (Milkdrop)  → reads `assets/presets/*.milk`
//   Shadertoy fragment   → reads `assets/shaders/*.glsl`
//
// Each engine's catalog is cached separately after first listing.
// Adding/removing a preset = drop a file in/out of the matching
// assets directory and rebuild — no code changes needed. Each shader
// file starts with metadata comments (// title:, // author:, //
// license:) so we can surface attribution in the UI later.

import 'dart:math';

import 'package:flutter/services.dart';

import 'visualizer_bridge.dart';

/// Which preset library a [VisualizerPresets] call targets. Mirrors the
/// engine kind used at bridge construction time — the catalog must
/// match whatever the native side was built for.
enum VisualizerPresetKind { milkdrop, shader }

class VisualizerPresets {
  VisualizerPresets._();
  static final VisualizerPresets _instance = VisualizerPresets._();
  factory VisualizerPresets() => _instance;

  final Map<VisualizerPresetKind, List<String>?> _paths = {};
  final Map<VisualizerPresetKind, int> _cursors = {};
  final Random _rng = Random();

  // The most recently loaded preset's asset path and raw source. The
  // visualizer screen reads [currentShaderSource] to parse `// param:`
  // tuning knobs, and uses [currentShaderPath] as the persistence key.
  String? _currentPath;
  String? _currentSource;

  /// Asset path of the most recently loaded preset (null until one loads).
  String? get currentShaderPath => _currentPath;

  /// Raw source of the most recently loaded preset (null until one loads).
  String? get currentShaderSource => _currentSource;

  String _directoryFor(VisualizerPresetKind kind) {
    switch (kind) {
      case VisualizerPresetKind.milkdrop:
        return 'assets/presets/';
      case VisualizerPresetKind.shader:
        return 'assets/shaders/';
    }
  }

  String _extensionFor(VisualizerPresetKind kind) {
    switch (kind) {
      case VisualizerPresetKind.milkdrop:
        return '.milk';
      case VisualizerPresetKind.shader:
        return '.glsl';
    }
  }

  /// Asset paths bundled for [kind]. Cached after first read.
  Future<List<String>> _list(VisualizerPresetKind kind) async {
    final cached = _paths[kind];
    if (cached != null) return cached;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final dir = _directoryFor(kind);
      final ext = _extensionFor(kind);
      final found = manifest
          .listAssets()
          .where((k) => k.startsWith(dir) && k.endsWith(ext))
          .toList()
        ..sort();
      _paths[kind] = found;
      // ignore: avoid_print
      print('VisualizerPresets[${kind.name}]: found ${found.length}');
      return found;
    } catch (e) {
      // ignore: avoid_print
      print('VisualizerPresets[${kind.name}]: manifest read failed: $e');
      _paths[kind] = const [];
      return const [];
    }
  }

  /// Load a random preset of the given kind into the running engine.
  /// Returns the loaded asset path (or null if nothing is bundled).
  Future<String?> loadRandom(
    VisualizerPresetKind kind, {
    bool smooth = true,
  }) async {
    final paths = await _list(kind);
    if (paths.isEmpty) return null;
    final pick = paths[_rng.nextInt(paths.length)];
    await _loadByPath(pick, smooth: smooth);
    return pick;
  }

  /// Advance to the next preset in the sorted list, wrapping around.
  /// Returns the loaded asset path (or null if nothing is bundled).
  Future<String?> loadNext(
    VisualizerPresetKind kind, {
    bool smooth = true,
  }) async {
    final paths = await _list(kind);
    if (paths.isEmpty) return null;
    final next = ((_cursors[kind] ?? -1) + 1) % paths.length;
    _cursors[kind] = next;
    await _loadByPath(paths[next], smooth: smooth);
    return paths[next];
  }

  Future<void> _loadByPath(String assetPath, {required bool smooth}) async {
    final data = await rootBundle.loadString(assetPath);
    _currentPath = assetPath;
    _currentSource = data;
    await VisualizerBridge.loadPreset(data, smooth: smooth);
  }
}
