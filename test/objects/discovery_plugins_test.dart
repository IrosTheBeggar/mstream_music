// lib/objects/discovery_plugins.dart — the plug-in API's wire shapes
// (mStream docs/openapi.yaml): what each parser keeps, and that a malformed
// entry is dropped or a malformed field read as absent, never thrown on.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';

void main() {
  group('PluginListing', () {
    test('the plug-ins, their scopes and the jobs gate (stage A\'s shape)', () {
      final l = PluginListing.fromServerMap({
        'plugins': [
          {'name': 'links', 'title': 'Open elsewhere', 'description': 'd', 'capabilities': ['links'], 'scope': 'server', 'enabled': true, 'scopes': ['song'], 'settings': [], 'available': true},
          {'name': 'deezer', 'title': 'Deezer', 'capabilities': ['preview'], 'scopes': ['song']},
          {'name': 'federation-copy', 'title': 'Add to your collection', 'capabilities': ['acquire'], 'scopes': ['song', 'album', 'artist', 'artist-missing', 'folder'], 'settings': ['destination']},
          {'title': 'no name'},
          'junk',
        ],
        'jobs': {'allowed': true},
      });
      expect([for (final p in l.plugins) p.name], ['links', 'deezer', 'federation-copy']);
      expect(l.jobsAllowed, isTrue);
      expect(l.copy!.scopes, ['song', 'album', 'artist', 'artist-missing', 'folder']);
      expect(l.copy!.hasCapability('acquire'), isTrue);
      expect(l.copy!.hasScope('album'), isTrue);
      expect(l.links!.title, 'Open elsewhere');
      expect(l.plugin('youtube'), isNull);
    });

    test('no jobs block, jobs not allowed, an unavailable plug-in', () {
      expect(PluginListing.fromServerMap({'plugins': []}).jobsAllowed, isFalse);
      expect(PluginListing.fromServerMap({'jobs': {'allowed': 'yes'}}).jobsAllowed, isFalse);
      final l = PluginListing.fromServerMap({
        'plugins': [
          {'name': 'federation-copy', 'scopes': ['song'], 'available': false}
        ],
        'jobs': {'allowed': true},
      });
      expect(l.copy, isNull, reason: 'a plug-in whose probe failed cannot run');
      expect(l.plugins.single.title, 'federation-copy', reason: 'the name stands in for a missing title');
    });
  });

  group('DiscoveryJob', () {
    final wire = {
      'id': 12,
      'plugin': 'federation-copy',
      'userId': 3,
      'key': 'album:06676dc1b229a92dc5da197690c55ebf',
      'recommendation': {
        'source': 'federation',
        'peer': {'id': 1, 'name': 'Stage Peer B'},
        'title': 'Late Train Verse',
        'artist': 'Boukmanflow',
        'album': 'Borrowed Tapes',
        'filepath': 'peerlib/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
      },
      'params': {'scope': 'album'},
      'state': 'running',
      'progress': 0.4,
      'statusText': '1 of 3 songs · 7.4 MB',
      'result': null,
      'error': null,
      'attempts': 1,
      'cancelRequested': false,
      'createdAt': 1760900000000,
      'updatedAt': 1760900001000,
      'startedAt': 1760900000500,
      'finishedAt': null,
    };

    test('every field, the scope, the server it came from', () {
      final j = DiscoveryJob.fromServerMap(wire)!;
      expect([j.id, j.plugin, j.userId, j.key, j.state, j.progress, j.statusText, j.attempts, j.cancelRequested],
          [12, 'federation-copy', 3, 'album:06676dc1b229a92dc5da197690c55ebf', JobState.running, 0.4, '1 of 3 songs · 7.4 MB', 1, false]);
      expect([j.createdAt, j.updatedAt, j.startedAt, j.finishedAt], [1760900000000, 1760900001000, 1760900000500, null]);
      expect([j.scope, j.live, j.peerId, j.peerName], ['album', true, 1, 'Stage Peer B']);
      expect(j.recommendation['filepath'], 'peerlib/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3');
      expect(() => (j.recommendation as Map)['x'] = 1, throwsUnsupportedError, reason: 'read-only: Retry sends it as it came');
    });

    test('a song job has no scope; an unknown state is no state; a malformed job is dropped', () {
      final song = DiscoveryJob.fromServerMap({...wire, 'params': null})!;
      expect(song.scope, 'song');
      final odd = DiscoveryJob.fromServerMap({...wire, 'state': 'paused', 'progress': 'half', 'attempts': 'x'})!;
      expect([odd.state, odd.live, odd.progress, odd.attempts], [null, false, null, 0]);
      expect(DiscoveryJob.fromServerMap({...wire, 'progress': 7})!.progress, 1.0, reason: 'clamped to 0..1');
      expect(DiscoveryJob.fromServerMap({'plugin': 'x'}), isNull, reason: 'no id');
      expect(DiscoveryJob.fromServerMap({'id': 1}), isNull, reason: 'no plug-in');
      expect(DiscoveryJob.fromServerMap('junk'), isNull);
    });

    test('the result views: a song copy and an album copy', () {
      final song = DiscoveryJob.fromServerMap({
        ...wire,
        'state': 'done',
        'params': null,
        'result': {
          'copied': {'vpath': 'demo', 'filepath': 'demo/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', 'trackId': 4, 'bytes': 7340032}
        },
      })!;
      expect([song.view.isMany, song.view.copiedFilepath, song.view.copiedBytes],
          [false, 'demo/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', 7340032]);
      final album = DiscoveryJob.fromServerMap({
        ...wire,
        'state': 'done',
        'result': {
          'scope': 'artist',
          'songs': {'total': 3, 'copied': [{}], 'skipped': [{}], 'failed': [{}]},
          'counts': {'total': 3, 'copied': 1, 'skipped': 1, 'failed': 1},
          'albums': [{'name': 'Borrowed Tapes', 'year': 2019, 'songs': {'total': 3}, 'stopped': null}, {'name': 'X', 'error': 'peer said 500'}],
          'skippedAlbums': [{'name': 'Block Party Comp', 'why': 'appearance'}],
          'stopped': 'quota',
          'peer': {'id': 1, 'name': 'Stage Peer B'},
          'bytes': 99,
          'truncated': true,
        },
      })!;
      final v = album.view;
      expect([v.isMany, v.stopped, v.peerName, v.bytes, v.truncated], [true, 'quota', 'Stage Peer B', 99, true]);
      expect([for (final a in v.albums) [a.name, a.year, a.error]], [['Borrowed Tapes', 2019, null], ['X', null, 'peer said 500']]);
      expect([for (final a in v.skippedAlbums) [a.name, a.why]], [['Block Party Comp', 'appearance']]);
      expect(const JobResultView(null).isMany, isFalse);
    });

    test('withResult keeps everything else', () {
      final j = DiscoveryJob.fromServerMap(wire)!;
      final k = j.withResult({'counts': {'total': 1}});
      expect([k.id, k.key, k.state, k.scope, k.peerId, k.view.isMany], [12, j.key, JobState.running, 'album', 1, true]);
    });
  });

  group('JobLookup', () {
    test('the song key, every scope\'s key, the jobs', () {
      final l = JobLookup.fromServerMap({
        'key': 'text:boukmanflow|late train verse',
        'keys': {'song': 'text:boukmanflow|late train verse', 'album': 'album:x', 'artist': 'artist:y', 'artist-missing': 'artist-missing:y', 'folder': 'folder:z', 'bad': 3},
        'jobs': [{'id': 1, 'plugin': 'federation-copy', 'state': 'done'}, 'junk'],
      })!;
      expect(l.key, 'text:boukmanflow|late train verse');
      expect(l.keys.keys, ['song', 'album', 'artist', 'artist-missing', 'folder']);
      expect(l.allKeys, ['text:boukmanflow|late train verse', 'album:x', 'artist:y', 'artist-missing:y', 'folder:z']);
      expect(l.jobs.single.id, 1);
      expect(JobLookup.fromServerMap(null), isNull);
    });
  });

  group('DestinationView', () {
    test("stage A's default: the demo library, the default layout", () {
      final d = DestinationView.fromServerMap({
        'destination': {'vpath': 'demo', 'base': '', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}', 'source': 'default'},
        'saved': null,
        'libraries': [{'vpath': 'demo', 'template': null}, {'vpath': 'music', 'template': '{{ALBUMARTIST}}/{{ALBUM}}'}, {'template': 'x'}],
        'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
        'variables': ['ARTIST', 'ALBUM', 'YEAR', 'GENRE', 'ALBUMARTIST', 'PEER'],
      });
      expect([d.destination!.vpath, d.destination!.base, d.destination!.layout, d.destination!.isDefault], ['demo', '', '{{ALBUMARTIST}}/{{ALBUM}}', true]);
      expect(d.saved, isNull);
      expect([for (final l in d.libraries) [l.vpath, l.template]], [['demo', null], ['music', '{{ALBUMARTIST}}/{{ALBUM}}']]);
      expect(d.variables, hasLength(6));
      expect(d.destination!.toJson(), {'vpath': 'demo', 'base': '', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}'});
    });

    test('nowhere to put a file: destination null, no libraries', () {
      final d = DestinationView.fromServerMap({'destination': null, 'saved': null, 'libraries': []});
      expect([d.destination, d.libraries, d.defaultLayout], [null, isEmpty, '{{ALBUMARTIST}}/{{ALBUM}}']);
    });
  });

  group('links', () {
    test('canonical first, then the searches; only web links', () {
      final links = pluginLinksOf({
        'plugin': 'links',
        'result': {
          'links': [
            {'id': 'deezer-search', 'label': 'Search Deezer', 'url': 'https://www.deezer.com/search/x', 'kind': 'search'},
            {'id': 'musicbrainz-recording', 'label': 'MusicBrainz recording', 'url': 'https://musicbrainz.org/recording/abc', 'kind': 'canonical'},
            {'id': 'evil', 'label': 'x', 'url': 'javascript:alert(1)', 'kind': 'search'},
            {'id': 'nourl', 'label': 'x'},
          ]
        }
      });
      expect([for (final l in links) l.id], ['musicbrainz-recording', 'deezer-search']);
      expect(links.first.canonical, isTrue);
      expect(pluginLinksOf({'result': {'links': []}}), isEmpty);
      expect(pluginLinksOf(null), isEmpty);
    });
  });
}
