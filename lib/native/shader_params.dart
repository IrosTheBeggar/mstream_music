// Parses the per-shader tuning knobs a `.glsl` declares in its header.
//
// A shader exposes a knob with a comment line of the form:
//
//   // param: <name> <min> <max> <default>
//
// e.g.  // param: flash 0.0 1.5 0.6
//
// The i-th `// param:` line (in source order) maps to `iParams[i]` in the
// shader — the engine binds the pushed values to a `uniform float
// iParams[NUM_PARAMS]`. The in-app tuning panel builds one slider per
// declared param, and pushes the values through VisualizerBridge.setTuning
// prefixed by the three global response-curve knobs.

/// One tunable knob declared by a shader. [index] is its `iParams[]` slot.
class ShaderParam {
  final int index;
  final String name;
  final double min;
  final double max;
  final double def;

  const ShaderParam({
    required this.index,
    required this.name,
    required this.min,
    required this.max,
    required this.def,
  });

  /// Clamp a value to this param's declared range.
  double clamp(double v) => v < min ? min : (v > max ? max : v);
}

final RegExp _paramLine = RegExp(
  r'^\s*//\s*param:\s*([A-Za-z0-9_]+)\s+(-?[0-9]*\.?[0-9]+)\s+'
  r'(-?[0-9]*\.?[0-9]+)\s+(-?[0-9]*\.?[0-9]+)\s*$',
  multiLine: true,
);

/// Extracts `// param:` declarations from [source], in declaration order
/// (so each param's list position == its `iParams[]` index). Malformed or
/// degenerate (max <= min) lines are skipped. Capped at [maxParams] to
/// match the engine's `iParams[]` size.
List<ShaderParam> parseShaderParams(String source, {int maxParams = 8}) {
  final out = <ShaderParam>[];
  for (final m in _paramLine.allMatches(source)) {
    if (out.length >= maxParams) break;
    final min = double.tryParse(m.group(2)!);
    final max = double.tryParse(m.group(3)!);
    final def = double.tryParse(m.group(4)!);
    if (min == null || max == null || def == null || max <= min) continue;
    out.add(ShaderParam(
      index: out.length,
      name: m.group(1)!,
      min: min,
      max: max,
      def: def,
    ));
  }
  return out;
}
