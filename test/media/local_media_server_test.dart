import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/local_media_server.dart';

void main() {
  // A 1000-byte body throughout; ranges are inclusive.
  const len = 1000;

  group('LocalMediaServer.parseRange', () {
    test('no header → whole body as 200', () {
      expect(LocalMediaServer.parseRange(null, len),
          (start: 0, end: 999, partial: false));
    });

    test('bytes=start-end serves the window, end clamped to the body', () {
      expect(LocalMediaServer.parseRange('bytes=0-499', len),
          (start: 0, end: 499, partial: true));
      expect(LocalMediaServer.parseRange('bytes=500-1999', len),
          (start: 500, end: 999, partial: true));
    });

    test('bytes=start- serves to the end', () {
      expect(LocalMediaServer.parseRange('bytes=900-', len),
          (start: 900, end: 999, partial: true));
    });

    test('suffix bytes=-N serves the LAST N bytes (the tail-probe form)', () {
      // Regression: this parsed as start=0/end=N and served the HEAD as a
      // well-formed 206 — breaking renderers probing end-of-file moov atoms /
      // ID3v1 tags.
      expect(LocalMediaServer.parseRange('bytes=-500', len),
          (start: 500, end: 999, partial: true));
      expect(LocalMediaServer.parseRange('bytes=-1', len),
          (start: 999, end: 999, partial: true));
      // A suffix longer than the body serves the whole body as 206.
      expect(LocalMediaServer.parseRange('bytes=-5000', len),
          (start: 0, end: 999, partial: true));
    });

    test('unsatisfiable ranges → null (416)', () {
      expect(LocalMediaServer.parseRange('bytes=1000-', len), isNull);
      expect(LocalMediaServer.parseRange('bytes=1000-1999', len), isNull);
      expect(LocalMediaServer.parseRange('bytes=500-100', len), isNull);
      expect(LocalMediaServer.parseRange('bytes=-0', len), isNull);
      // Empty body: any actual range is unsatisfiable.
      expect(LocalMediaServer.parseRange('bytes=0-', 0), isNull);
      expect(LocalMediaServer.parseRange('bytes=-10', 0), isNull);
    });

    test('invalid syntax is ignored → whole body as 200 (RFC 9110)', () {
      expect(LocalMediaServer.parseRange('bytes=abc-def', len),
          (start: 0, end: 999, partial: false));
      expect(LocalMediaServer.parseRange('bytes=-', len),
          (start: 0, end: 999, partial: false));
      expect(LocalMediaServer.parseRange('bytes=5', len),
          (start: 0, end: 999, partial: false));
      expect(LocalMediaServer.parseRange('items=0-499', len),
          (start: 0, end: 999, partial: false));
    });
  });
}
