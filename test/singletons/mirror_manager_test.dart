import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_mirror/library_mirror.dart' show RuleKind;
import 'package:path/path.dart' as p;

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/library_index.dart';
import 'package:mstream_music/singletons/mirror_manager.dart';

void main() {
  group('ServerManifestClient', () {
    final server = Server('http://h:1', null, null, 'jwt-1', 'home');

    ServerManifestClient client(http.Response Function(http.Request) handle) =>
        ServerManifestClient(server, client: () => MockClient((r) async => handle(r)));

    test('sends the token, the quoted If-None-Match and the paging body', () async {
      late http.Request seen;
      final c = client((r) {
        seen = r;
        return http.Response(jsonEncode({'revision': 'r2', 'scanning': false, 'next': null,
          'entries': [{'filepath': 'music/a.mp3', 'id': 1, 'metadata': {'title': 'A'}}]}), 200);
      });
      final page = await c.fetchPage(cursor: 7, limit: 50, ifNoneMatch: 'r1');
      expect(seen.url.path, '/api/v1/sync/manifest');
      expect(seen.headers['x-access-token'], 'jwt-1');
      expect(seen.headers['If-None-Match'], '"r1"');
      expect(jsonDecode(seen.body), {'cursor': 7, 'limit': 50});
      expect(page!.revision, 'r2');
      expect(page.entries.single.path, '/music/a.mp3');
      expect(page.entries.single.title, 'A');
    });

    test('a 304 is null and the first page omits the cursor', () async {
      late http.Request seen;
      final c = client((r) {
        seen = r;
        return http.Response('', 304);
      });
      expect(await c.fetchPage(ifNoneMatch: 'r1'), isNull);
      expect(jsonDecode(seen.body), {'limit': 2000});
    });

    test('any other status throws', () async {
      final c = client((_) => http.Response('nope', 500));
      expect(c.fetchPage(), throwsA(isA<HttpException>()));
    });
  });

  group('MirrorManager rules', () {
    late Directory tmp;
    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('mirror_manager_');
      await LibraryIndexManager().open(path: p.join(tmp.path, 'index.db'));
    });
    tearDown(() {
      LibraryIndexManager().close();
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('keep-full-copy toggles a library rule and publishes a status', () async {
      final s = Server('http://h:1', null, null, null, 'home');
      final m = MirrorManager();
      expect(m.keepsFullCopy(s, 'music'), isFalse);
      expect(m.hasRules(s), isFalse);

      // syncAvailable is unset, so the sync the toggle kicks off returns early.
      m.setKeepFullCopy(s, 'music', true);
      expect(m.keepsFullCopy(s, 'music'), isTrue);
      expect(m.hasRules(s), isTrue);
      final rule = LibraryIndexManager().index!.subscriptionsFor('home').single;
      expect(rule.kind, 'library');
      expect(rule.key, 'music');
      expect(m.statusFor(s)!.files, 0);
      expect(m.statusFor(s)!.running, isFalse);

      m.setKeepFullCopy(s, 'music', false);
      expect(m.keepsFullCopy(s, 'music'), isFalse);
      expect(LibraryIndexManager().index!.subscriptionsFor('home'), isEmpty);
      expect(await m.sync(s), isNull, reason: 'no sync flag → no run');
    });

    test('album / artist rules: keepsRule, setRule, canKeep', () {
      final s = Server('http://h:1', null, null, null, 'home');
      final m = MirrorManager();
      expect(m.canKeep(s), isFalse, reason: 'no sync flag');
      s.syncAvailable = true;
      expect(m.canKeep(s), isTrue);
      // Back to "unknown" so the sync a toggle kicks off returns early.
      s.syncAvailable = null;
      m.setRule(s, RuleKind.album, 'Be Somebody', true);
      m.setRule(s, RuleKind.artist, 'Icarus', true);
      expect(m.keepsRule(s, RuleKind.album, 'Be Somebody'), isTrue);
      expect(m.keepsRule(s, RuleKind.album, 'Other'), isFalse);
      expect(m.keepsFullCopy(s, 'music'), isFalse);
      final rules = LibraryIndexManager().index!.subscriptionsFor('home');
      expect(rules.map((r) => (r.kind, r.key)),
          [(RuleKind.album, 'Be Somebody'), (RuleKind.artist, 'Icarus')]);
      m.setRule(s, RuleKind.album, 'Be Somebody', false);
      expect(LibraryIndexManager().index!.subscriptionsFor('home').single.kind,
          RuleKind.artist);
    });
  });

  group('Server library-copy settings', () {
    const base = {'url': 'u', 'username': null, 'password': null, 'jwt': null, 'localname': 'l'};

    test('defaults: 30 days, Wi-Fi only, sync flag unknown', () {
      final s = Server.fromJson(Map.of(base));
      expect(s.mirrorRetentionDays, 30);
      expect(s.mirrorWifiOnly, isTrue);
      expect(s.syncAvailable, isNull);
    });

    test('round-trips', () {
      final s = Server.fromJson({...base, 'mirrorRetentionDays': 0, 'mirrorWifiOnly': false,
        'syncAvailable': true});
      final back = Server.fromJson(s.toJson());
      expect(back.mirrorRetentionDays, 0);
      expect(back.mirrorWifiOnly, isFalse);
      expect(back.syncAvailable, isTrue);
    });

    test('junk values fall back to the defaults', () {
      final s = Server.fromJson({...base, 'mirrorRetentionDays': 'x', 'mirrorWifiOnly': 3,
        'syncAvailable': 'yes'});
      expect(s.mirrorRetentionDays, 30);
      expect(s.mirrorWifiOnly, isTrue);
      expect(s.syncAvailable, isNull);
    });
  });
}
