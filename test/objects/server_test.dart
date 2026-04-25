import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';

void main() {
  group('Server.fromJson', () {
    test('parses minimal payload (only required fields)', () {
      final s = Server.fromJson({
        'url': 'https://music.example.com',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'home',
      });
      expect(s.url, 'https://music.example.com');
      expect(s.localname, 'home');
      expect(s.username, isNull);
      expect(s.password, isNull);
      expect(s.jwt, isNull);
      expect(s.autoDJPaths, isEmpty);
      expect(s.autoDJminRating, isNull);
      expect(s.playlists, isEmpty);
      expect(s.saveToSdCard, isFalse);
    });

    test('parses full payload with auto DJ + playlists', () {
      final s = Server.fromJson({
        'url': 'https://music.example.com',
        'username': 'alice',
        'password': 'secret',
        'jwt': 'eyJhbGciOi…',
        'localname': 'main',
        'autoDJPaths': {'rock': true, 'jazz': false},
        'autoDJminRating': 6,
        'playlists': ['favs', 'roadtrip'],
        'saveToSdCard': true,
      });
      expect(s.username, 'alice');
      expect(s.password, 'secret');
      expect(s.jwt, 'eyJhbGciOi…');
      expect(s.autoDJPaths, {'rock': true, 'jazz': false});
      expect(s.autoDJminRating, 6);
      expect(s.playlists, ['favs', 'roadtrip']);
      expect(s.saveToSdCard, isTrue);
    });

    test('treats missing autoDJPaths/playlists/saveToSdCard as defaults', () {
      final s = Server.fromJson({
        'url': 'u',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'l',
      });
      expect(s.autoDJPaths, isEmpty);
      expect(s.playlists, isEmpty);
      expect(s.saveToSdCard, isFalse);
    });
  });

  group('Server.toJson', () {
    test('round-trips through fromJson without data loss', () {
      final original = Server(
        'https://music.example.com',
        'alice',
        'secret',
        'jwt-token',
        'main',
      );
      original.autoDJPaths = {'rock': true, 'jazz': false};
      original.autoDJminRating = 7;
      original.playlists = ['p1'];
      original.saveToSdCard = true;

      final reparsed = Server.fromJson(original.toJson());

      expect(reparsed.url, original.url);
      expect(reparsed.username, original.username);
      expect(reparsed.password, original.password);
      expect(reparsed.jwt, original.jwt);
      expect(reparsed.localname, original.localname);
      expect(reparsed.autoDJPaths, original.autoDJPaths);
      expect(reparsed.autoDJminRating, original.autoDJminRating);
      expect(reparsed.playlists, original.playlists);
      expect(reparsed.saveToSdCard, original.saveToSdCard);
    });
  });
}
