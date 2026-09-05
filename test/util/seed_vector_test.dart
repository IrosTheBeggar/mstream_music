import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/seed_vector.dart';

// The seed a multi-server Auto DJ session sends to every server: the
// unit-length mean of the anchor tracks' embeddings, on the wire as base64
// float32 little-endian (mStream #929, random-songs `similarToVector`).

Float32List v(List<double> xs) => Float32List.fromList(xs);

void expectClose(Float32List got, List<double> want, {double eps = 1e-6}) {
  expect(got.length, want.length);
  for (var i = 0; i < want.length; i++) {
    expect((got[i] - want[i]).abs() <= eps, isTrue,
        reason: 'component $i: ${got[i]} vs ${want[i]}');
  }
}

void main() {
  test('the wire form is little-endian, which is what every target is', () {
    expect(Endian.host, Endian.little);
  });

  group('meanUnitVector', () {
    test('averages two anchors and re-normalizes', () {
      final m = meanUnitVector([v([1, 0, 0, 0]), v([0, 1, 0, 0])], 4)!;
      final r = 1 / 1.4142135623730951;
      expectClose(m, [r, r, 0, 0]);
    });

    test('a single anchor comes back unchanged', () {
      expectClose(meanUnitVector([v([0, 0, 1, 0])], 4)!, [0, 0, 1, 0]);
    });

    test('scaled anchors still give a unit vector', () {
      // Servers hand out unit vectors, but a caller must not depend on it:
      // the server re-normalizes, and so does this.
      final m = meanUnitVector([v([3, 4, 0, 0]), v([3, 4, 0, 0])], 4)!;
      expectClose(m, [0.6, 0.8, 0, 0]);
    });

    test('near-opposite anchors that cancel out give null, not a zero seed', () {
      expect(meanUnitVector([v([1, 0, 0, 0]), v([-1, 0, 0, 0])], 4), isNull);
    });

    test('nothing to average gives null', () {
      expect(meanUnitVector(const <Float32List>[], 4), isNull);
      expect(meanUnitVector([v([1, 0, 0, 0])], 0), isNull);
    });

    test('a vector of the wrong length is skipped, not summed', () {
      final m = meanUnitVector([v([1, 0, 0, 0]), v([0, 1, 0])], 4)!;
      expectClose(m, [1, 0, 0, 0]);
      expect(meanUnitVector([v([0, 1, 0])], 4), isNull);
    });
  });

  group('wire encoding', () {
    test('encode then decode round-trips the exact floats', () {
      final seed = meanUnitVector([v([1, 2, 3, 4])], 4)!;
      final wire = encodeWireVector(seed);
      final back = decodeWireVector(wire, 4)!;
      expectClose(back, seed.toList(), eps: 0);
    });

    test('the payload is exactly dim × 4 bytes', () {
      final wire = seedVectorBase64([v([1, 0, 0, 0])], 4)!;
      expect(Uint8List.fromList(wire.codeUnits).length, greaterThan(0));
      expect(decodeWireVector(wire, 4)!.lengthInBytes, 16);
    });

    test('a payload of the wrong length or bad base64 decodes to null', () {
      final three = encodeWireVector(v([1, 0, 0]));
      expect(decodeWireVector(three, 4), isNull);
      expect(decodeWireVector('!!!not-base64!!!', 4), isNull);
      expect(decodeWireVector('', 4), isNull);
    });

    test('seedVectorBase64 is null when the anchors give nothing usable', () {
      expect(seedVectorBase64(const <Float32List>[], 4), isNull);
      expect(seedVectorBase64([v([1, 0, 0, 0]), v([-1, 0, 0, 0])], 4), isNull);
    });
  });
}
