import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// A visualizer preset's renderer. [render] draws one frame onto [canvas];
/// [music] is the shared audio texture (iChannel0). Single- and multi-pass
/// presets implement the same interface so the screen treats them uniformly.
abstract class VizRenderer {
  Future<void> load();
  void render(Canvas canvas, Size size, double time, ui.Image music);
  void dispose();

  /// Offscreen pixels per LOGICAL pixel for screen-filling shader passes, or
  /// null to draw straight to the canvas at device resolution. A fullscreen
  /// drawRect runs its fragment shader once per DEVICE pixel — logical size ×
  /// devicePixelRatio², ~2.7M invocations per pass on a 3× phone — which is
  /// what tanks the multi-pass presets on mobile GPUs. With a scale set, each
  /// pass renders offscreen at scale×logical and the GPU bilinear-upscales:
  /// ~devicePixelRatio²/scale² less fragment work, visually free on
  /// visualizer content. Set by the mobile screen; desktop leaves it null.
  static double? pixelScale;
}

// Standard float uniforms shared by every ported shader: iResolution (vec3,
// z = pixel aspect) + iTime. Samplers are set per-renderer.
void _stdUniforms(ui.FragmentShader sh, double w, double h, double time) {
  sh.setFloat(0, w);
  sh.setFloat(1, h);
  sh.setFloat(2, 1.0);
  sh.setFloat(3, time);
}

// Draw one screen-filling pass of [sh] onto [canvas]: direct at device
// resolution when [VizRenderer.pixelScale] is null, else offscreen at
// scale×logical + bilinear upscale. Sets the std uniforms (they must match
// the surface the shader actually rasterizes to); samplers are bound by the
// caller beforehand.
void _drawPass(Canvas canvas, Size size, double time, ui.FragmentShader sh) {
  final scale = VizRenderer.pixelScale;
  if (scale == null) {
    _stdUniforms(sh, size.width, size.height, time);
    canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
    return;
  }
  final w = (size.width * scale).ceilToDouble();
  final h = (size.height * scale).ceilToDouble();
  _stdUniforms(sh, w, h, time);
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = sh);
  final pic = rec.endRecording();
  final img = pic.toImageSync(w.toInt(), h.toInt());
  // Dispose the picture NOW: an undisposed picture pins its recorded shader
  // state (including every sampled image) until a GC finalizer runs, and the
  // Dart GC can't feel that native weight — at 60 fps that leaks to the iOS
  // per-process jetsam limit in minutes (seen on iPhone X).
  pic.dispose();
  canvas.drawImageRect(img, Rect.fromLTWH(0, 0, w, h), Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low);
  img.dispose();
}

/// One shader, one draw, iChannel0 = the audio texture.
class SinglePassRenderer implements VizRenderer {
  SinglePassRenderer(this.asset);
  final String asset;
  ui.FragmentShader? _shader;

  @override
  Future<void> load() async {
    final prog = await ui.FragmentProgram.fromAsset(asset);
    _shader = prog.fragmentShader();
  }

  @override
  void render(Canvas canvas, Size size, double time, ui.Image music) {
    final sh = _shader;
    if (sh == null) return;
    sh.setImageSampler(0, music);
    _drawPass(canvas, size, time, sh);
  }

  @override
  void dispose() => _shader?.dispose();
}

/// One pass of a multi-pass preset.
class PassDef {
  /// 'buffera'..'bufferd' for offscreen buffers, 'image' for the final pass.
  final String name;
  final String asset;

  /// Source for each `iChannelN` in declaration order: 'music' (the audio
  /// texture) or a buffer name. Length = the pass's sampler count.
  final List<String> channels;

  /// Render this pass at 1×1 (Shadertoy `// === size <buf> = 1x1` — a constant
  /// state buffer the image pass samples one texel of).
  final bool fixed1x1;

  const PassDef(this.name, this.asset, this.channels, {this.fixed1x1 = false});
}

/// Runs the passes in order each frame: buffer passes render to offscreen images
/// (via [Picture.toImageSync]); the `image` pass draws to the screen. A pass that
/// lists its own name in [channels] reads last frame's image (ping-pong feedback);
/// a pass that lists an earlier buffer reads this frame's freshly-rendered one.
class MultiPassRenderer implements VizRenderer {
  MultiPassRenderer(this.passes);
  final List<PassDef> passes;

  final Map<String, ui.FragmentShader> _shaders = {};
  final Map<String, ui.Image> _buffers = {};

  @override
  Future<void> load() async {
    for (final p in passes) {
      final prog = await ui.FragmentProgram.fromAsset(p.asset);
      _shaders[p.name] = prog.fragmentShader();
    }
  }

  static ui.Image _seed() {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = const Color(0xFF000000));
    final pic = rec.endRecording();
    final img = pic.toImageSync(1, 1);
    pic.dispose();
    return img;
  }

  @override
  void render(Canvas canvas, Size size, double time, ui.Image music) {
    // Seed buffers on the first frame (needs a live rasterizer, so not at load).
    for (final p in passes) {
      if (p.name != 'image') _buffers.putIfAbsent(p.name, _seed);
    }

    ui.Image chan(String c) => c == 'music' ? music : _buffers[c]!;
    // Old buffer images are read by toImageSync (eager) within this frame, then
    // freed after the whole frame's passes are done.
    final pending = <ui.Image>[];

    // Buffer passes honor pixelScale too (null = today's logical-size path).
    final bufScale = VizRenderer.pixelScale ?? 1.0;

    for (final p in passes) {
      final sh = _shaders[p.name];
      if (sh == null) continue;
      for (var i = 0; i < p.channels.length; i++) {
        sh.setImageSampler(i, chan(p.channels[i]));
      }
      if (p.name == 'image') {
        _drawPass(canvas, size, time, sh);
      } else {
        final w = p.fixed1x1 ? 1.0 : size.width * bufScale;
        final h = p.fixed1x1 ? 1.0 : size.height * bufScale;
        _stdUniforms(sh, w, h, time);
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = sh);
        final pic = rec.endRecording();
        final img = pic.toImageSync(w.ceil(), h.ceil());
        // See _drawPass: undisposed pictures pin their sampled images (here:
        // full-size feedback buffers, every frame) until a lagging finalizer
        // runs — that leak jetsams the app on phones.
        pic.dispose();
        final old = _buffers[p.name];
        if (old != null) pending.add(old);
        _buffers[p.name] = img;
      }
    }
    for (final img in pending) {
      img.dispose();
    }
  }

  @override
  void dispose() {
    for (final s in _shaders.values) {
      s.dispose();
    }
    for (final b in _buffers.values) {
      b.dispose();
    }
  }
}
