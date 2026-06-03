// ambient_color.dart — album-art ambient color engine, ported from the design's
// color.jsx (OKLCH-based, vibrancy- + contrast-gated) with a dependency-free
// dominant-color extractor built on Flutter's own image decoder.
//
// Lessons baked in (from Spotify / Material You / Palette API):
//   1) seed from a vibrancy-gated swatch   2) grayscale fallback (reject low chroma)
//   3) blend perceptually in OKLab         4) hard contrast floor vs. white text
//
// No third-party packages: `palette_generator` is discontinued, so the seed is
// extracted here by decoding a downscaled frame via dart:ui and quantizing it.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// ── Tunables (mirror color.jsx) ──
const double _chromaFloor = 0.030; // below this the art is "grayscale" → no tint
const double _chromaCap = 0.150; // keep tones rich but never neon
const double _minContrast = 4.5; // white queue text must clear this (WCAG)

// ─────────────────────────────────────────────────────────────
// sRGB ⇄ linear
// ─────────────────────────────────────────────────────────────
double _s2l(int c) {
  final x = c / 255.0;
  return x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
}

int _l2s(double c) {
  final x = c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  return (x.clamp(0.0, 1.0) * 255).round();
}

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

// ─────────────────────────────────────────────────────────────
// OKLab / OKLCH (Björn Ottosson)
// ─────────────────────────────────────────────────────────────
class _Oklab {
  final double l, a, b;
  const _Oklab(this.l, this.a, this.b);
}

_Oklab _rgbToOklab(int r, int g, int b) {
  final lr = _s2l(r), lg = _s2l(g), lb = _s2l(b);
  final l = _cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  final m = _cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  final s = _cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  return _Oklab(
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

List<int> _oklabToRgb(double bL, double a, double bb) {
  final l_ = bL + 0.3963377774 * a + 0.2158037573 * bb;
  final m_ = bL - 0.1055613458 * a - 0.0638541728 * bb;
  final s_ = bL - 0.0894841775 * a - 1.2914855480 * bb;
  final l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
  return [
    _l2s(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    _l2s(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    _l2s(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  ];
}

List<int> _oklchToRgb(double l, double c, double h) =>
    _oklabToRgb(l, c * math.cos(h), c * math.sin(h));

// Perceptual blend of two RGB triples in OKLab.
List<int> _mixOk(List<int> c1, List<int> c2, double t) {
  final a = _rgbToOklab(c1[0], c1[1], c1[2]);
  final b = _rgbToOklab(c2[0], c2[1], c2[2]);
  return _oklabToRgb(
    a.l + (b.l - a.l) * t,
    a.a + (b.a - a.a) * t,
    a.b + (b.b - a.b) * t,
  );
}

// WCAG relative luminance + contrast vs. white.
double _relLum(int r, int g, int b) =>
    0.2126 * _s2l(r) + 0.7152 * _s2l(g) + 0.0722 * _s2l(b);
double _contrastWhite(int r, int g, int b) => 1.05 / (_relLum(r, g, b) + 0.05);

/// Builds the bottom-right radial ambient gradient from a [seed] color (the
/// dominant album-art color) over [base] (the dark sheet background). Returns
/// null when the art is too neutral to tint (grayscale fallback).
///
/// [vibrant] = false (default) is the calm "muted" look; true is Spotify-style
/// punch from the more saturated seed.
Gradient? ambientGradient(Color seed, {required Color base, bool vibrant = false}) {
  final r = (seed.r * 255.0).round(),
      g = (seed.g * 255.0).round(),
      b = (seed.b * 255.0).round();
  final lab = _rgbToOklab(r, g, b);
  final chroma = math.sqrt(lab.a * lab.a + lab.b * lab.b);
  final hue = math.atan2(lab.b, lab.a);

  // (2) grayscale fallback — reject near-neutral seeds.
  if (chroma < _chromaFloor) return null;

  // (3) work in OKLCH: lift muted seeds into a visible glow; keep vibrant rich.
  double l = vibrant ? math.max(lab.l, 0.42) : lab.l + 0.16;
  final c = math.min(chroma * (vibrant ? 1.05 : 1.1), _chromaCap);

  // (4) hard contrast floor: darken in L until white text clears MIN_CONTRAST.
  var bright = _oklchToRgb(l, c, hue);
  var guard = 0;
  while (_contrastWhite(bright[0], bright[1], bright[2]) < _minContrast &&
      l > 0.08 &&
      guard++ < 60) {
    l -= 0.012;
    bright = _oklchToRgb(l, c, hue);
  }

  final brightColor = Color.fromARGB(255, bright[0], bright[1], bright[2]);
  final midRgb = _mixOk(bright,
      [(base.r * 255.0).round(), (base.g * 255.0).round(), (base.b * 255.0).round()],
      0.55);
  final midColor = Color.fromARGB(255, midRgb[0], midRgb[1], midRgb[2]);

  // CSS: radial-gradient(130% 100% at 100% 100%, bright 0%, mid 38%, bg 72%)
  return RadialGradient(
    center: Alignment.bottomRight,
    radius: 1.3,
    colors: [brightColor, midColor, base],
    stops: const [0.0, 0.38, 0.72],
  );
}

// ─────────────────────────────────────────────────────────────
// Dominant-color extraction (no third-party package)
// ─────────────────────────────────────────────────────────────
final Map<String, Color?> _seedCache = {};

/// Extracts a representative color from the artwork at [url] for use as the
/// ambient seed. [vibrant] picks the most saturated swatch; otherwise the
/// dominant (field) color. Decodes a small 64px frame and quantizes it — no
/// second network fetch beyond Flutter's image cache. Returns null on failure.
Future<Color?> dominantAlbumColor(String url, {bool vibrant = false}) async {
  final key = '$url|${vibrant ? 'v' : 'm'}';
  if (_seedCache.containsKey(key)) return _seedCache[key];
  try {
    final image = await _loadDownscaled(url);
    final w = image.width, h = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return _seedCache[key] = null;
    final px = data.buffer.asUint8List();
    final color = vibrant ? _vibrantOf(px, w, h) : _dominantOf(px, w, h);
    return _seedCache[key] = color;
  } catch (_) {
    return _seedCache[key] = null;
  }
}

Future<ui.Image> _loadDownscaled(String url) {
  // ResizeImage caps the decode at 64px, so toByteData stays tiny (~16KB) and
  // the result is shared with Flutter's image cache.
  final provider = ResizeImage(NetworkImage(url), width: 64, height: 64);
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<ui.Image>();
  late ImageStreamListener listener;
  listener = ImageStreamListener((info, _) {
    if (!completer.isCompleted) completer.complete(info.image);
    stream.removeListener(listener);
  }, onError: (e, st) {
    if (!completer.isCompleted) completer.completeError(e);
    stream.removeListener(listener);
  });
  stream.addListener(listener);
  return completer.future;
}

// Most-populous 12-bit color bucket (the field / dominant tone).
Color? _dominantOf(Uint8List px, int w, int h) {
  const grid = 20;
  final counts = <int, int>{};
  final sums = <int, List<int>>{};
  for (int gy = 0; gy < grid; gy++) {
    for (int gx = 0; gx < grid; gx++) {
      final x = (gx * w / grid).floor();
      final y = (gy * h / grid).floor();
      final i = (y * w + x) * 4;
      if (i + 3 >= px.length) continue;
      if (px[i + 3] < 128) continue; // skip transparent
      final r = px[i], g = px[i + 1], b = px[i + 2];
      final bucket = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
      final s = sums.putIfAbsent(bucket, () => [0, 0, 0, 0]);
      s[0] += r;
      s[1] += g;
      s[2] += b;
      s[3] += 1;
    }
  }
  if (counts.isEmpty) return null;
  int bestKey = counts.keys.first, bestCount = -1;
  counts.forEach((k, c) {
    if (c > bestCount) {
      bestCount = c;
      bestKey = k;
    }
  });
  final s = sums[bestKey]!;
  return Color.fromARGB(
      255, (s[0] / s[3]).round(), (s[1] / s[3]).round(), (s[2] / s[3]).round());
}

// Highest-chroma swatch within a brightness gate (Spotify-style seed).
Color? _vibrantOf(Uint8List px, int w, int h) {
  const grid = 22;
  int br = 0, bg = 0, bb = 0;
  double best = -1;
  for (int gy = 0; gy < grid; gy++) {
    for (int gx = 0; gx < grid; gx++) {
      final x = (gx * w / grid).floor();
      final y = (gy * h / grid).floor();
      final i = (y * w + x) * 4;
      if (i + 3 >= px.length) continue;
      if (px[i + 3] < 128) continue;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      if (mx < 60 || mx > 235) continue; // gate out near-black / near-white
      final chroma = (mx - mn).toDouble();
      if (chroma > best) {
        best = chroma;
        br = r;
        bg = g;
        bb = b;
      }
    }
  }
  if (best < 0) return null;
  return Color.fromARGB(255, br, bg, bb);
}
