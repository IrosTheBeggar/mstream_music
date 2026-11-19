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

    test('youtube: listed and available, with acquire and lookup, on the song scope — else null', () {
      PluginListing withYoutube(Map<String, dynamic> yt) => PluginListing.fromServerMap({
            'plugins': [
              {'name': 'youtube', 'title': 'YouTube', ...yt}
            ],
            'jobs': {'allowed': true},
          });
      const full = {'capabilities': ['acquire', 'lookup'], 'scopes': ['song']};
      expect(withYoutube(full).youtube?.title, 'YouTube');
      expect(withYoutube({...full, 'capabilities': ['acquire']}).youtube, isNull, reason: 'no lookup: no pick to send');
      expect(withYoutube({...full, 'capabilities': ['lookup']}).youtube, isNull, reason: 'no acquire: no job');
      expect(withYoutube({...full, 'scopes': ['album']}).youtube, isNull, reason: 'not on the song scope');
      expect(withYoutube({...full, 'scopes': null}).youtube, isNull);
      expect(withYoutube({...full, 'available': false}).youtube, isNull, reason: 'its probe failed (no yt-dlp)');
      expect(PluginListing.fromServerMap({'plugins': []}).youtube, isNull);
    });

    test('previews: the available preview plug-ins, deezer then itunes then the rest in listing order', () {
      final l = PluginListing.fromServerMap({
        'plugins': [
          {'name': 'bandcamp', 'title': 'Preview on Bandcamp', 'capabilities': ['preview']},
          {'name': 'itunes', 'title': 'Preview on iTunes', 'capabilities': ['preview']},
          {'name': 'links', 'capabilities': ['links']},
          {'name': 'soundcloud', 'capabilities': ['preview'], 'available': false},
          {'name': 'deezer', 'title': 'Preview on Deezer', 'capabilities': ['preview']},
          {'name': 'qobuz', 'capabilities': ['preview', 'links']},
          {'name': 'deezer', 'title': 'again', 'capabilities': ['preview']},
        ],
      });
      expect([for (final p in l.previews) p.name], ['deezer', 'itunes', 'bandcamp', 'qobuz']);
      expect(l.previews.first.title, 'Preview on Deezer', reason: 'a plug-in named twice counts once: the first');
      expect(PluginListing.fromServerMap({'plugins': [{'name': 'links', 'capabilities': ['links']}]}).previews, isEmpty);
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

    test("a YouTube add's pick (params.choice) and its landed file, match and size", () {
      final yt = DiscoveryJob.fromServerMap({
        ...wire,
        'plugin': 'youtube',
        'state': 'done',
        'params': {
          'choice': {'url': 'https://www.youtube.com/watch?v=abc123'},
          'destination': {'vpath': 'music', 'base': '', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}', 'source': 'default'},
        },
        'result': {
          'downloaded': {
            'vpath': 'music', 'filepath': 'music/Static Bloom/Paper Satellites.mp3', 'trackId': 9, 'bytes': 6710886,
            'format': 'mp3', 'title': 'Paper Satellites', 'artist': 'Static Bloom', 'album': null, 'downloadId': 3,
          },
          'match': {'score': 0.91, 'url': 'https://www.youtube.com/watch?v=abc123', 'title': 'Paper Satellites', 'channel': 'Static Bloom - Topic', 'durationSec': 238, 'chosen': true},
          'missingVars': ['ALBUM'],
        },
      })!;
      expect([yt.scope, yt.choice, yt.choiceUrl],
          ['song', {'url': 'https://www.youtube.com/watch?v=abc123'}, 'https://www.youtube.com/watch?v=abc123']);
      expect(() => yt.choice!['url'] = 'x', throwsUnsupportedError, reason: 'read-only: Retry sends it as it came');
      final v = yt.view;
      expect([v.downloadedFilepath, v.downloadedBytes, v.downloadedFormat, v.matchChannel],
          ['music/Static Bloom/Paper Satellites.mp3', 6710886, 'mp3', 'Static Bloom - Topic']);
      expect(yt.destination?.vpath, 'music');

      // A job that searched for itself; odd shapes read as absent.
      final searched = DiscoveryJob.fromServerMap({...wire, 'plugin': 'youtube', 'params': null})!;
      expect([searched.choice, searched.choiceUrl], [null, null]);
      final odd = DiscoveryJob.fromServerMap({
        ...wire,
        'params': {'choice': 'https://www.youtube.com/watch?v=abc'},
        'result': {'downloaded': {'bytes': -1, 'format': 7}, 'match': 'x'},
      })!;
      expect([odd.choice, odd.choiceUrl, odd.view.downloadedBytes, odd.view.downloadedFormat, odd.view.matchChannel],
          [null, null, null, null, null]);
      expect(DiscoveryJob.fromServerMap({...wire, 'params': {'choice': {'url': 7}}})!.choiceUrl, isNull);
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

  group('PluginPreview.ofAnswer', () {
    Map<String, dynamic> answer(Map<String, dynamic>? preview, {String plugin = 'deezer'}) => {
          'plugin': plugin,
          'capabilities': ['preview'],
          'key': 'text:x',
          'recommendation': {'artist': 'Static Bloom', 'title': 'Paper Satellites'},
          'result': {'preview': preview},
        };
    const deezer = {
      'provider': 'deezer',
      'url': 'https://cdns-preview-d.dzcdn.net/stream/c-abc-1.mp3',
      'seconds': 30,
      'title': 'Paper Satellites',
      'artist': 'Static Bloom',
      'album': 'Tidewater',
      'link': 'https://www.deezer.com/track/123',
      'artwork': 'https://e-cdns-images.dzcdn.net/images/cover/abc/250x250.jpg',
      'attribution': 'Preview from Deezer',
      'match': 0.88,
    };

    test('the clip, what it matched, the attribution as sent, the store link and the cover', () {
      final p = PluginPreview.ofAnswer(answer(deezer))!;
      expect([p.provider, p.url.toString(), p.seconds, p.title, p.artist, p.album, p.attribution, p.match], [
        'deezer', 'https://cdns-preview-d.dzcdn.net/stream/c-abc-1.mp3', 30, 'Paper Satellites', 'Static Bloom', 'Tidewater',
        'Preview from Deezer', 0.88,
      ]);
      expect([p.link.toString(), p.artwork.toString()],
          ['https://www.deezer.com/track/123', 'https://e-cdns-images.dzcdn.net/images/cover/abc/250x250.jpg']);
    });

    test('no clip found is null; so is one with no web url', () {
      expect(PluginPreview.ofAnswer(answer(null)), isNull);
      expect(PluginPreview.ofAnswer(answer({...deezer, 'url': 'file:///etc/passwd'})), isNull);
      expect(PluginPreview.ofAnswer(answer({...deezer, 'url': 'javascript:alert(1)'})), isNull);
      expect(PluginPreview.ofAnswer(answer({...deezer, 'url': null})), isNull);
      expect(PluginPreview.ofAnswer({'result': 'x'}), isNull);
      expect(PluginPreview.ofAnswer(null), isNull);
    });

    test('a non-web link or cover is dropped, the clip kept; seconds default to 30; the match is clamped', () {
      final p = PluginPreview.ofAnswer(answer({
        ...deezer,
        'link': 'itms://itunes.apple.com/x',
        'artwork': 'data:image/png;base64,AAAA',
        'seconds': 'soon',
        'match': 4,
        'attribution': null,
      }))!;
      expect([p.link, p.artwork, p.seconds, p.match, p.attribution], [null, null, 30, 1.0, null]);
      expect(PluginPreview.ofAnswer(answer({...deezer, 'seconds': 0}))!.seconds, 30);
      expect(PluginPreview.ofAnswer(answer({...deezer, 'match': 'high'}))!.match, isNull);
    });

    test("the provider is the preview's own name, else the answer's plug-in", () {
      expect(PluginPreview.ofAnswer(answer({...deezer, 'provider': null}, plugin: 'itunes'))!.provider, 'itunes');
      expect(PluginPreview.ofAnswer({'result': {'preview': {...deezer, 'provider': null}}}), isNull);
    });
  });

  group('YoutubeSearch.ofAnswer', () {
    Map<String, dynamic> answer(Map<String, dynamic> lookup) => {
          'plugin': 'youtube',
          'capabilities': ['acquire', 'lookup'],
          'key': 'text:x',
          'recommendation': {},
          'result': {'lookup': lookup},
        };
    const top = {
      'id': 'abc123',
      'url': 'https://www.youtube.com/watch?v=abc123',
      'title': 'Static Bloom - Paper Satellites (Official Audio)',
      'channel': 'Static Bloom - Topic',
      'durationSec': 238,
      'thumbnail': 'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
      'topic': true,
      'score': 0.93,
    };

    test('the query, the bar, the candidates best first — a thin one (no channel, no length) kept', () {
      final s = YoutubeSearch.ofAnswer(answer({
        'query': 'Static Bloom Paper Satellites',
        'minScore': 0.62,
        'candidates': [
          top,
          {'id': null, 'url': 'https://www.youtube.com/watch?v=thin1', 'title': 'Paper Satellites', 'channel': null, 'durationSec': null, 'thumbnail': null, 'topic': false, 'score': 0.41},
        ],
        'owned': null,
      }));
      expect([s.query, s.minScore, s.owned, s.ownedFilepath], ['Static Bloom Paper Satellites', 0.62, false, null]);
      final c = s.candidates.first;
      expect([c.id, c.url, c.title, c.channel, c.durationSec, c.thumbnail.toString(), c.topic, c.score], [
        'abc123', 'https://www.youtube.com/watch?v=abc123', 'Static Bloom - Paper Satellites (Official Audio)', 'Static Bloom - Topic',
        238, 'https://i.ytimg.com/vi/abc123/hqdefault.jpg', true, 0.93,
      ]);
      final thin = s.candidates.last;
      expect([thin.id, thin.channel, thin.durationSec, thin.thumbnail, thin.topic, thin.score], [null, null, null, null, false, 0.41]);
      expect([c.loose(s.minScore), thin.loose(s.minScore)], [false, true]);
    });

    test("a link the jobs route would refuse is dropped; so is a malformed candidate", () {
      final s = YoutubeSearch.ofAnswer(answer({
        'query': 'q',
        'candidates': [
          {...top, 'url': 'https://vimeo.com/123'},
          {...top, 'url': 'https://www.youtube.com/channel/UC1'},
          {...top, 'url': 'https://youtu.be/short1'},
          {...top, 'url': null},
          'junk',
        ],
      }));
      expect([for (final c in s.candidates) c.url], ['https://youtu.be/short1']);
    });

    test('a fractional length is rounded; a non-web thumbnail, a missing score and an odd title read as absent', () {
      final c = YoutubeSearch.ofAnswer(answer({
        'candidates': [
          {...top, 'durationSec': 237.6, 'thumbnail': 'ftp://x/y.jpg', 'score': null, 'title': 42, 'topic': 'yes'},
          {...top, 'durationSec': -3},
        ],
      })).candidates;
      expect([c.first.durationSec, c.first.thumbnail, c.first.score, c.first.title, c.first.topic], [238, null, 0.0, '', false]);
      expect(c.last.durationSec, isNull);
    });

    test("the library's own copy, answered before YouTube is asked", () {
      final s = YoutubeSearch.ofAnswer(answer({
        'query': 'Static Bloom Paper Satellites',
        'minScore': 0.62,
        'candidates': [],
        'owned': {'vpath': 'music', 'filepath': 'music/Static Bloom/Tidewater/04 Paper Satellites.flac', 'by': 'tags'},
      }));
      expect([s.owned, s.ownedFilepath, s.candidates], [true, 'music/Static Bloom/Tidewater/04 Paper Satellites.flac', isEmpty]);
    });

    test('the bar defaults to 0.62; no lookup reads as nothing found', () {
      expect(YoutubeSearch.ofAnswer(answer({'query': 'q'})).minScore, kYoutubeMinScore);
      expect(YoutubeSearch.ofAnswer(answer({'query': 'q', 'minScore': 7})).minScore, 0.62);
      expect(YoutubeSearch.ofAnswer(answer({'query': 'q', 'minScore': 0.7})).minScore, 0.7);
      final none = YoutubeSearch.ofAnswer({'result': {}});
      expect([none.query, none.candidates, none.owned], ['', isEmpty, false]);
      expect(YoutubeSearch.ofAnswer(null).candidates, isEmpty);
    });
  });
}
