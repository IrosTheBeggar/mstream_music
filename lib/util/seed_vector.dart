// Portable sonic seeds (mStream #929): the math that turns the embeddings of
// what is playing into ONE vector every server can be asked with.
//
// A single-server Auto DJ session seeds random-songs with filepaths, which
// name rows on the server that holds them. A multi-server session reads the
// vector behind each anchor track from its own server
// (/api/v1/discovery/local/embeddings), averages them here, and sends the
// result to every server as `similarToVector`. The server re-normalizes on
// arrival, but a unit vector is what the contract asks for and what keeps
// the reported cosines honest.
//
// Wire form, both directions: base64 of dim × float32, little-endian. Every
// platform Flutter ships to is little-endian, so a Float32List's own bytes
// are the wire bytes — [decodeWireVector] and [encodeWireVector] assert it
// rather than silently producing garbage on an exotic host.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// The unit-length mean of [vectors], or null when there is nothing to
/// average or the mean collapses to zero / non-finite (near-opposite
/// anchors). A vector whose length is not [dim] is skipped rather than
/// poisoning the sum — the caller already dropped whole servers that
/// answered with a different model, so a stray length here is a bug upstream
/// and one bad seed should not silence the rest.
Float32List? meanUnitVector(Iterable<Float32List> vectors, int dim) {
  if (dim <= 0) return null;
  final sum = Float64List(dim);
  var n = 0;
  for (final v in vectors) {
    if (v.length != dim) continue;
    for (var i = 0; i < dim; i++) {
      sum[i] += v[i];
    }
    n++;
  }
  if (n == 0) return null;

  var sumSq = 0.0;
  for (var i = 0; i < dim; i++) {
    sum[i] /= n;
    sumSq += sum[i] * sum[i];
  }
  final norm = math.sqrt(sumSq);
  if (norm == 0 || !norm.isFinite) return null;

  final out = Float32List(dim);
  for (var i = 0; i < dim; i++) {
    out[i] = sum[i] / norm;
  }
  return out;
}

/// [v] as random-songs' `similarToVector` takes it.
String encodeWireVector(Float32List v) {
  assert(Endian.host == Endian.little, 'wire vectors are little-endian');
  return base64Encode(
      v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes));
}

/// A wire vector (base64 float32 little-endian) as an aligned Float32List, or
/// null when the payload is not exactly [dim] floats — a server answering
/// with a different dim than it advertised is not worth guessing about.
Float32List? decodeWireVector(String base64, int dim) {
  assert(Endian.host == Endian.little, 'wire vectors are little-endian');
  final Uint8List bytes;
  try {
    bytes = base64Decode(base64);
  } on FormatException {
    return null;
  }
  if (dim <= 0 || bytes.lengthInBytes != dim * 4) return null;
  // Copy into a fresh buffer: the decoded list's offset is not guaranteed to
  // suit a Float32List view, and a view over it would alias the input.
  final aligned = Uint8List.fromList(bytes);
  return aligned.buffer.asFloat32List();
}

/// One-call form of the above for the picker: the seed to send, or null when
/// the anchors give nothing usable.
String? seedVectorBase64(Iterable<Float32List> vectors, int dim) {
  final v = meanUnitVector(vectors, dim);
  return v == null ? null : encodeWireVector(v);
}
