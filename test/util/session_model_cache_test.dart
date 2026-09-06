import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/session_model_cache.dart';

// The per-server model memory behind the multi-server Auto DJ handshake:
// a known model is trusted for a while, "no model" is asked again sooner.

void main() {
  final t0 = DateTime(2026, 9, 6, 12, 0, 0);

  test('nothing recorded is unknown', () {
    expect(SessionModelCache().lookup('a', t0), isNull);
  });

  test('a known model is trusted until okTtl, then asked again', () {
    final c = SessionModelCache();
    c.record('a', 'effnet-discogs', t0);
    expect(c.lookup('a', t0)?.modelId, 'effnet-discogs');
    expect(
        c.lookup('a', t0.add(const Duration(minutes: 4, seconds: 59)))?.modelId,
        'effnet-discogs');
    expect(c.lookup('a', t0.add(const Duration(minutes: 5))), isNull);
  });

  test('a fresh "no model" answer is an answer, not an unknown', () {
    final c = SessionModelCache();
    c.record('a', null, t0);
    final got = c.lookup('a', t0.add(const Duration(seconds: 30)));
    expect(got, isNotNull);
    expect(got!.modelId, isNull);
  });

  test('"no model" is retried after the shorter retryTtl', () {
    final c = SessionModelCache();
    c.record('a', null, t0);
    expect(c.lookup('a', t0.add(const Duration(seconds: 59))), isNotNull);
    expect(c.lookup('a', t0.add(const Duration(minutes: 1))), isNull);
  });

  test('a later answer replaces the earlier one; clear forgets all', () {
    final c = SessionModelCache();
    c.record('a', null, t0);
    c.record('a', 'test-fake', t0.add(const Duration(seconds: 10)));
    expect(c.lookup('a', t0.add(const Duration(seconds: 20)))?.modelId,
        'test-fake');
    c.clear();
    expect(c.lookup('a', t0.add(const Duration(seconds: 20))), isNull);
  });
}
