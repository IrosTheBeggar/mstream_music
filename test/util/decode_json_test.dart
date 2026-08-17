import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/decode_json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeJsonBody', () {
    test('small bodies decode inline and correctly', () async {
      final decoded = await decodeJsonBody('{"a": [1, 2], "b": "x"}');
      expect(decoded, {
        'a': [1, 2],
        'b': 'x',
      });
    });

    test('bodies over the threshold decode off-isolate to the same result',
        () async {
      // Build a payload guaranteed past the isolate threshold, shaped like a
      // whole-library response.
      final artists =
          List.generate(6000, (i) => 'Artist $i — padding padding padding');
      final body = jsonEncode({'artists': artists});
      expect(body.length, greaterThan(kIsolateDecodeThreshold));

      final decoded = await decodeJsonBody(body);
      expect(decoded['artists'], hasLength(6000));
      expect(decoded['artists'][5999], artists[5999]);
      // Must equal the inline decode exactly.
      expect(decoded, jsonDecode(body));
    });

    test('malformed JSON throws (same contract as jsonDecode)', () async {
      await expectLater(decodeJsonBody('{nope'), throwsFormatException);
    });
  });
}
