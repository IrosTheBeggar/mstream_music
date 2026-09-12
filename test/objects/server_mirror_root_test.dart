import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';

void main() {
  const base = {
    'url': 'https://music.example.com',
    'username': null,
    'password': null,
    'jwt': null,
    'localname': 'home',
  };

  group('Server.mirrorRoot', () {
    test('absent → null (servers saved before the field existed)', () {
      expect(Server.fromJson(Map.of(base)).mirrorRoot, isNull);
    });

    test('round-trips through toJson/fromJson', () {
      final s = Server.fromJson({...base, 'mirrorRoot': r'C:\Music'});
      expect(s.mirrorRoot, r'C:\Music');
      expect(s.toJson()['mirrorRoot'], r'C:\Music');
      expect(Server.fromJson(s.toJson()).mirrorRoot, r'C:\Music');
    });

    test('a non-string value is ignored, not crashed on', () {
      expect(Server.fromJson({...base, 'mirrorRoot': 42}).mirrorRoot, isNull);
    });

    test('a cleared root persists as null', () {
      final s = Server('u', null, null, null, 'l')..mirrorRoot = null;
      expect(s.toJson().containsKey('mirrorRoot'), isTrue);
      expect(s.toJson()['mirrorRoot'], isNull);
    });
  });
}
