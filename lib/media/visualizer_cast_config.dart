import '../native/shader_params.dart';
import '../native/visualizer_presets.dart';
import '../singletons/settings.dart';

/// The engine + preset + tuning to render when **casting** the visualizer,
/// derived from the user's persisted visualizer settings so the cast looks like
/// what they'd see on the visualizer screen. Built by [resolveVisualizerCastConfig].
class VisualizerCastConfig {
  /// Native engine id (matches VisualizerBridge.engineProjectM / engineShader).
  final int engine;

  /// Raw `.milk` / `.glsl` source to load (null → the engine's idle preset).
  final String? preset;

  /// `[minDb, maxDb, smoothing, ...iParams]` for the shader engine; null for
  /// Milkdrop (which ignores tuning).
  final List<double>? tuning;

  const VisualizerCastConfig({
    required this.engine,
    this.preset,
    this.tuning,
  });
}

/// Resolve the visualizer-cast render config from settings. Picks a *random*
/// preset of the configured engine's kind — via [VisualizerPresets.randomData],
/// which has no side effects on the on-screen engine (so casting never disturbs
/// an open visualizer screen, and the kind always matches the chosen engine).
///
/// For the shader engine it also builds the tuning vector the shaders' `iParams`
/// expect: the global response curve (from settings, or the native defaults) plus
/// each shader param's declared default — mirroring
/// `VisualizerScreen._onShaderLoaded` so the cast reacts to audio the same way.
/// (Per-shader *saved* slider overrides aren't applied — the random cast preset
/// isn't necessarily the one the user tuned on-screen.)
Future<VisualizerCastConfig> resolveVisualizerCastConfig() async {
  final eng = SettingsManager().visualizerEngine;
  final kind = eng == VisualizerEngine.shader
      ? VisualizerPresetKind.shader
      : VisualizerPresetKind.milkdrop;
  final preset = await VisualizerPresets().randomData(kind);

  List<double>? tuning;
  if (eng == VisualizerEngine.shader && preset != null) {
    final saved = SettingsManager().visualizerGlobalParams;
    final globals = saved.length == SettingsManager.defaultGlobalParams.length
        ? List<double>.from(saved)
        : List<double>.from(SettingsManager.defaultGlobalParams);
    tuning = <double>[
      ...globals,
      for (final p in parseShaderParams(preset)) p.def,
    ];
  }

  return VisualizerCastConfig(
    engine: eng.nativeKind,
    preset: preset,
    tuning: tuning,
  );
}
