// Loads Milkdrop .milk presets bundled as Flutter assets and pushes
// them into the running visualizer via [VisualizerBridge.loadPreset].
//
// First call lists the assets/presets/ directory (via the asset
// manifest), caches the list, and keeps the order stable so
// [random] and [next] are deterministic within a session.

import 'dart:math';

import 'package:flutter/services.dart';

import 'visualizer_bridge.dart';

class VisualizerPresets {
  VisualizerPresets._();
  static final VisualizerPresets _instance = VisualizerPresets._();
  factory VisualizerPresets() => _instance;

  List<String>? _paths;
  int _cursor = 0;
  final Random _rng = Random();

  /// Asset paths under `assets/presets/`. Cached after first read.
  /// Uses Flutter 3.10+'s binary AssetManifest API.
  Future<List<String>> _list() async {
    final cached = _paths;
    if (cached != null) return cached;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final found = manifest
          .listAssets()
          .where((k) => k.startsWith('assets/presets/') && k.endsWith('.milk'))
          .toList()
        ..sort();
      _paths = found;
      // ignore: avoid_print
      print('VisualizerPresets: found ${found.length} preset(s)');
      return found;
    } catch (e) {
      // ignore: avoid_print
      print('VisualizerPresets: manifest read failed: $e');
      _paths = const [];
      return const [];
    }
  }

  /// Load a random preset into the running visualizer. No-op if no
  /// presets are bundled or if no visualizer instance is alive.
  Future<void> loadRandom({bool smooth = true}) async {
    final paths = await _list();
    if (paths.isEmpty) return;
    final pick = paths[_rng.nextInt(paths.length)];
    await _loadByPath(pick, smooth: smooth);
  }

  /// Advance to the next preset in the (sorted) list. Wraps around.
  Future<void> loadNext({bool smooth = true}) async {
    final paths = await _list();
    if (paths.isEmpty) return;
    _cursor = (_cursor + 1) % paths.length;
    await _loadByPath(paths[_cursor], smooth: smooth);
  }

  Future<void> _loadByPath(String assetPath, {required bool smooth}) async {
    final data = await rootBundle.loadString(assetPath);
    await VisualizerBridge.loadPreset(data, smooth: smooth);
  }
}
