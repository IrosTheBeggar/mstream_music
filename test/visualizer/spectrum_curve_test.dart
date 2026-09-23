import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/visualizer/spectrum_curve.dart';

/// [value] rounded to the nearest 32-bit float, as a C++ float store does.
final Float32List _scratch = Float32List(1);
double _f32(double value) {
  _scratch[0] = value;
  return _scratch[0];
}

/// The signal tool/audio_texture_golden/generate.cpp feeds the C++, bit for
/// bit: integer arithmetic, and float operations that are exact or singly
/// rounded, in the same order.
class _Signal {
  int _lcg = 0x2545F491;
  int _bass = 0, _mid = 0, _high = 0;
  final double _c05 = _f32(0.05), _c01 = _f32(0.1);

  double _noise() {
    _lcg = (_lcg * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _f32(_f32((_lcg >> 8) * (1.0 / 16777216.0)) * 2.0 - 1.0);
  }

  static double _triangle(int phase) {
    final t = _f32((phase >> 8) * (1.0 / 16777216.0));
    return _f32(_f32(4.0 * _f32((t - 0.5).abs())) - 1.0);
  }

  (double, double) frame() {
    _bass = (_bass + 5843493) & 0xFFFFFFFF;
    _mid = (_mid + 42852281) & 0xFFFFFFFF;
    _high = (_high + 292174646) & 0xFFFFFFFF;
    final left = _f32(_f32(_triangle(_bass) * 0.5) + _f32(_noise() * _c05));
    final right = _f32(_f32(_f32(_triangle(_mid) * 0.25) + _f32(_triangle(_high) * _c01)) +
        _f32(_noise() * _c05));
    return (left, right);
  }
}

int _fnv1a(int hash, double value) {
  final bits = ByteData(4)..setFloat32(0, value, Endian.little);
  for (var i = 0; i < 4; i++) {
    hash ^= bits.getUint8(i);
    // 64-bit multiply, wrapping, as the C++ does.
    hash = (hash * 1099511628211).toUnsigned(64);
  }
  return hash;
}

List<double> _tone(double amplitude, double cyclesPerWindow) => List.generate(
      SpectrumCurve.fftSize,
      (i) => amplitude * math.sin(2 * math.pi * cyclesPerWindow * i / SpectrumCurve.fftSize),
    );

void main() {
  test('it uploads what Android uploads for the same signal', () {
    final golden = File('test/visualizer/audio_texture_golden.bin').readAsBytesSync();
    final header = ByteData.sublistView(golden, 0, 24);
    expect(String.fromCharCodes(golden.sublist(0, 8)), 'MSATGLD1');
    final steps = header.getUint32(8, Endian.little);
    final frames = header.getUint32(12, Endian.little);
    final expectedHash = header.getUint64(16, Endian.little);
    const perUpload = SpectrumCurve.bins * 2;
    expect(golden.length, 24 + steps * perUpload);

    // The input first, so a generator that drifted is named as that rather
    // than as a hundred differing bytes.
    final signal = _Signal();
    var hash = 0xcbf29ce484222325;
    final batches = <List<double>>[];
    for (var step = 0; step < steps; step++) {
      final mono = <double>[];
      for (var i = 0; i < frames; i++) {
        final (left, right) = step < 8 ? signal.frame() : (0.0, 0.0);
        hash = _fnv1a(_fnv1a(hash, left), right);
        mono.add(_f32(0.5 * _f32(left + right)));
      }
      batches.add(mono);
    }
    expect(hash, expectedHash, reason: 'the signal made here is not the one the C++ was fed');

    // One Android smoothing step per update, exactly.
    const dt = 1 / 30;
    expect(dt * 30, 1.0);

    final curve = SpectrumCurve();
    final history = <double>[];
    var differing = 0;
    for (var step = 0; step < steps; step++) {
      if (step == 5) curve.setParams(minDb: -80, maxDb: -30, smoothing: 0.6);
      history.addAll(batches[step]);
      curve.update(history, dt);
      final want = golden.sublist(24 + step * perUpload, 24 + (step + 1) * perUpload);
      for (var i = 0; i < perUpload; i++) {
        final got = curve.bytes[i];
        if (got != want[i]) differing++;
        expect((got - want[i]).abs(), lessThanOrEqualTo(1),
            reason: 'upload $step, ${i < SpectrumCurve.bins ? 'bin' : 'sample'} '
                '${i % SpectrumCurve.bins}: $got here, ${want[i]} from the C++');
      }
    }
    // On the Mac that generated the vectors the match is exact: none of the
    // 10,240 bytes differ. One step either way is for another platform's libm,
    // or the FFT in double beside kissfft's float, landing across a truncation
    // boundary, which should be rare; a curve that was merely close would
    // differ everywhere.
    expect(differing, lessThanOrEqualTo(steps * perUpload ~/ 100),
        reason: '$differing of ${steps * perUpload} bytes differ by one');
  });

  test("a tone's level is its amplitude in decibels", () {
    // Normalised to amplitude, a -40 dB tone reads 0.01 in its bin, and the
    // default window puts -40 dB (-40 + 69.7) / 49 of the way up.
    final curve = SpectrumCurve()
      ..setParams(minDb: SpectrumCurve.defaultMinDb, maxDb: SpectrumCurve.defaultMaxDb, smoothing: 0);
    curve.update(_tone(0.01, 64), 1 / 30);
    final expected = ((-40 + 69.7) / 49 * 255).truncate();
    expect((curve.bytes[64] - expected).abs(), lessThanOrEqualTo(2));
    expect(curve.bytes[20], lessThan(40), reason: 'the tone stays in its bin');
    expect(curve.bytes[200], lessThan(40), reason: 'the tone stays in its bin');
  });

  test('silence reads as nothing and a flat line', () {
    final curve = SpectrumCurve()..update(List.filled(SpectrumCurve.fftSize, 0.0), 1);
    expect(curve.bytes.sublist(0, SpectrumCurve.bins), everyElement(0));
    expect(curve.bytes.sublist(SpectrumCurve.bins), everyElement(127));
  });

  test('smoothing is a rate per second, not per update', () {
    // Two updates of a sixtieth of a second land where one of a thirtieth
    // does: a 120 Hz screen must not settle faster than a 60 Hz one.
    final loud = _tone(0.5, 32);
    final fast = SpectrumCurve()
      ..update(loud, 1 / 60)
      ..update(loud, 1 / 60);
    final slow = SpectrumCurve()..update(loud, 1 / 30);
    for (var bin = 0; bin < SpectrumCurve.bins; bin++) {
      expect((fast.bytes[bin] - slow.bytes[bin]).abs(), lessThanOrEqualTo(1), reason: 'bin $bin');
    }
  });

  test('a curve with nothing in it is refused, and smoothing is bounded', () {
    // setParams follows Android's: an empty window keeps the old one, and
    // smoothing past 0.99 is 0.99 — so a tone reads as it did before.
    final loud = _tone(0.5, 32);
    final plain = SpectrumCurve()..update(loud, 1 / 30);
    final refused = SpectrumCurve()
      ..setParams(minDb: -20, maxDb: -20, smoothing: SpectrumCurve.defaultSmoothing)
      ..update(loud, 1 / 30);
    expect(refused.bytes, plain.bytes);

    final held = SpectrumCurve()
      ..setParams(minDb: SpectrumCurve.defaultMinDb, maxDb: SpectrumCurve.defaultMaxDb, smoothing: 5)
      ..update(loud, 1 / 30);
    final atCap = SpectrumCurve()
      ..setParams(minDb: SpectrumCurve.defaultMinDb, maxDb: SpectrumCurve.defaultMaxDb, smoothing: 0.99)
      ..update(loud, 1 / 30);
    expect(held.bytes, atCap.bytes);
  });
}
