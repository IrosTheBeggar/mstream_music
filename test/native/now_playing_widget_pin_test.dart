import 'package:flutter_test/flutter_test.dart';
import 'package:now_playing_widget/now_playing_widget.dart';

/// The Settings sheet's model of what the Android side offers to pin.
void main() {
  group('PinTargets.parse', () {
    test('a well-formed reply keeps the sizes in order with their labels', () {
      final t = PinTargets.parse({
        'supported': true,
        'targets': [
          {'size': '2x1', 'label': 'Now Playing 2×1'},
          {'size': '4x3', 'label': 'Now Playing 4×3'},
        ],
      });
      expect(t.supported, isTrue);
      expect(t.targets.map((e) => e.size), ['2x1', '4x3']);
      expect(t.targets.first.label, 'Now Playing 2×1');
    });

    test('the channel\'s untyped maps parse the same', () {
      final t = PinTargets.parse(<Object?, Object?>{
        'supported': true,
        'targets': <Object?>[
          <Object?, Object?>{'size': '4x1', 'label': 'Now Playing 4×1'},
        ],
      });
      expect(t.targets.single.size, '4x1');
    });

    test('malformed entries are skipped; a non-map reply is none', () {
      final t = PinTargets.parse({
        'supported': true,
        'targets': [
          {'size': '', 'label': 'blank size'},
          {'label': 'no size'},
          'not a map',
          {'size': '2x2', 'label': 'Now Playing 2×2'},
        ],
      });
      expect(t.targets.map((e) => e.size), ['2x2']);
      expect(PinTargets.parse(null), same(PinTargets.none));
      expect(PinTargets.parse('nope').targets, isEmpty);
    });

    test('supported is false unless the native side says true', () {
      expect(PinTargets.parse({'targets': []}).supported, isFalse);
      expect(PinTargets.parse({'supported': 'yes', 'targets': []}).supported,
          isFalse);
    });
  });
}
