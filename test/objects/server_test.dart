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
      // No storage fields and no legacy flag -> default app-local.
      expect(s.storageMode, 'appLocal');
      expect(s.storageBasePath, isNull);
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
        'storageMode': 'permanent',
        'storageBasePath': '/storage/emulated/0/Music',
      });
      expect(s.username, 'alice');
      expect(s.password, 'secret');
      expect(s.jwt, 'eyJhbGciOi…');
      expect(s.autoDJPaths, {'rock': true, 'jazz': false});
      expect(s.autoDJminRating, 6);
      expect(s.playlists, ['favs', 'roadtrip']);
      expect(s.storageMode, 'permanent');
      expect(s.storageBasePath, '/storage/emulated/0/Music');
    });

    test('treats missing autoDJPaths/playlists/storage as defaults', () {
      final s = Server.fromJson({
        'url': 'u',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'l',
      });
      expect(s.autoDJPaths, isEmpty);
      expect(s.playlists, isEmpty);
      expect(s.storageMode, 'appLocal');
      expect(s.storageBasePath, isNull);
    });
  });

  group('Server.fromJson storage migration', () {
    test('legacy saveToSdCard:true migrates to legacyExternal', () {
      final s = Server.fromJson({
        'url': 'u',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'l',
        'saveToSdCard': true,
      });
      // Preserved losslessly: the resolver maps legacyExternal to the old
      // getExternalStorageDirectory() so existing downloads still resolve.
      expect(s.storageMode, 'legacyExternal');
      expect(s.storageBasePath, isNull);
    });

    test('legacy saveToSdCard:false migrates to appLocal', () {
      final s = Server.fromJson({
        'url': 'u',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'l',
        'saveToSdCard': false,
      });
      expect(s.storageMode, 'appLocal');
    });

    test('explicit storageMode wins over a legacy flag', () {
      final s = Server.fromJson({
        'url': 'u',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'l',
        'saveToSdCard': true,
        'storageMode': 'appLocal',
      });
      expect(s.storageMode, 'appLocal');
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
      original.storageMode = 'permanent';
      original.storageBasePath = '/storage/emulated/0/Music';

      final reparsed = Server.fromJson(original.toJson());

      expect(reparsed.url, original.url);
      expect(reparsed.username, original.username);
      expect(reparsed.password, original.password);
      expect(reparsed.jwt, original.jwt);
      expect(reparsed.localname, original.localname);
      expect(reparsed.autoDJPaths, original.autoDJPaths);
      expect(reparsed.autoDJminRating, original.autoDJminRating);
      expect(reparsed.playlists, original.playlists);
      expect(reparsed.storageMode, original.storageMode);
      expect(reparsed.storageBasePath, original.storageBasePath);
    });

    test('does not emit the obsolete saveToSdCard key', () {
      final json = Server('u', null, null, null, 'l').toJson();
      expect(json.containsKey('saveToSdCard'), isFalse);
      expect(json['storageMode'], 'appLocal');
    });
  });

  group('discovery capability flags', () {
    test('absent keys parse as null (unknown, not false)', () {
      final s = Server.fromJson({
        'url': 'https://music.example.com',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'home',
      });
      expect(s.discoveryAvailable, isNull);
      expect(s.discoveryP2pAvailable, isNull);
      expect(s.federationDiscoveryAvailable, isNull);
    });

    test('non-bool values are ignored (defensive against corrupt files)', () {
      final s = Server.fromJson({
        'url': 'u',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'l',
        'discoveryAvailable': 'yes',
        'discoveryP2pAvailable': 1,
        'federationDiscoveryAvailable': {},
      });
      expect(s.discoveryAvailable, isNull);
      expect(s.discoveryP2pAvailable, isNull);
      expect(s.federationDiscoveryAvailable, isNull);
    });

    test('round-trips through toJson/fromJson', () {
      final original = Server('u', null, null, null, 'l');
      original.discoveryAvailable = true;
      original.discoveryP2pAvailable = false;
      original.federationDiscoveryAvailable = true;

      final reparsed = Server.fromJson(original.toJson());

      expect(reparsed.discoveryAvailable, isTrue);
      expect(reparsed.discoveryP2pAvailable, isFalse);
      expect(reparsed.federationDiscoveryAvailable, isTrue);
    });
  });
}
