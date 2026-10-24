// util/discover_badges.dart — which job a browse page's marks show (the
// phone spec's §5.0, rules 3 and 4): a page pill this server's live copy
// first, another server's only while it runs, else this server's last; an
// album page's song row nothing while the album copy runs, else the newer
// of its own copy and what the finished album copy says of it — a song in
// a failed list never reads "in your collection" — and its own live copy
// always.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/discover_badges.dart';
import 'package:mstream_music/util/discover_jobs.dart' show jobSlot;

const pb = {'id': 1, 'name': 'Stage Peer B'};
const pc = {'id': 4, 'name': 'Stage Peer C'};
const late = 'music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3';

DiscoveryJob job(
  int id, {
  String scope = 'album',
  String state = 'done',
  Map<String, Object> peer = pb,
  Map<String, dynamic>? result,
  String? statusText,
  int? finishedAt,
}) =>
    DiscoveryJob.fromServerMap({
      'id': id,
      'plugin': kCopyPlugin,
      'recommendation': {
        'source': 'federation',
        'peer': peer,
        if (scope == 'song') ...{'filepath': late, 'title': 'Late Train Verse'},
        'artist': 'Boukmanflow',
        if (scope != 'artist' && scope != 'artist-missing') ...{'album': 'Borrowed Tapes', 'albumArtist': 'Boukmanflow'},
      },
      'params': {if (scope != 'song') 'scope': scope},
      'state': state,
      'statusText': statusText,
      'result': result,
      'finishedAt': ?finishedAt,
    })!;

Map<String, dynamic> albumSaid({List<String> copied = const [], List<String> failed = const []}) => {
      'scope': 'album',
      'songs': {
        'total': copied.length + failed.length,
        'copied': [for (final f in copied) {'from': f, 'filepath': 'copies/$f'}],
        'skipped': [],
        'failed': [for (final f in failed) {'from': f, 'error': 'boom'}],
      },
      'counts': {'total': copied.length + failed.length, 'copied': copied.length, 'skipped': 0, 'failed': failed.length},
      'stopped': null,
    };

const songKept = {'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3'}};

void main() {
  group("a page pill's job", () {
    String slot(String scope) => jobSlot(kCopyPlugin, scope);

    test("this server's live artist copy beats another server's live one", () {
      final mine = job(10, scope: 'artist', state: 'running', statusText: '1 of 3 albums');
      final theirs = job(11, scope: 'artist-missing', state: 'running', peer: pc, statusText: '1 of 2 albums');
      final pick = pagePillJob({slot('artist'): mine, slot('artist-missing'): theirs}, kScopeArtist, peerId: 1)!;
      expect([pick.job.id, pick.fromOtherPeer], [10, false]);
    });

    test("another server's live copy shows over this server's finished one", () {
      final mine = job(10, scope: 'artist');
      final theirs = job(11, scope: 'artist-missing', state: 'running', peer: pc, statusText: '1 of 2 albums');
      final pick = pagePillJob({slot('artist'): mine, slot('artist-missing'): theirs}, kScopeArtist, peerId: 1)!;
      expect([pick.job.id, pick.fromOtherPeer], [11, true]);
    });

    test('a live copy beats a newer finished one', () {
      final live = job(10, scope: 'artist', state: 'running', statusText: '1 of 3 albums');
      final done = job(12, scope: 'artist-missing');
      expect(pagePillJob({slot('artist'): live, slot('artist-missing'): done}, kScopeArtist, peerId: 1)!.job.id, 10);
      final older = job(9, scope: 'artist');
      expect(pagePillJob({slot('artist'): older, slot('artist-missing'): done}, kScopeArtist, peerId: 1)!.job.id, 12,
          reason: 'none live: the newer');
    });

    test("another server's finished copy is the idle pill", () {
      expect(pagePillJob({slot('album'): job(10, peer: pc)}, kScopeAlbum, peerId: 1), isNull);
    });
  });

  group("an album page's song row", () {
    test('nothing while the album copy runs', () {
      expect(pageSongMarker(song: job(10, scope: 'song', result: songKept), album: job(11, state: 'running'), filepath: late), isNull);
    });

    test('an older song copy kept, a newer album copy that failed it: failed', () {
      final song = job(10, scope: 'song', result: songKept, finishedAt: 1000);
      final album = job(11, result: albumSaid(failed: [late]), finishedAt: 2000);
      expect(pageSongMarker(song: song, album: album, filepath: late)!.kind, CopyMarkerKind.failed);
    });

    test('a newer song copy kept, an older album copy that failed it: in your collection', () {
      final album = job(10, result: albumSaid(failed: [late]), finishedAt: 1000);
      final song = job(11, scope: 'song', result: songKept, finishedAt: 2000);
      expect(pageSongMarker(song: song, album: album, filepath: late)!.kind, CopyMarkerKind.inCollection);
    });

    test("the song's own live copy wins over a newer finished album copy that names it", () {
      final song = job(10, scope: 'song', state: 'queued');
      final album = job(11, result: albumSaid(copied: [late]), finishedAt: 2000);
      expect(pageSongMarker(song: song, album: album, filepath: late)!.kind, CopyMarkerKind.waiting);
    });

    test('only the album copy: what it says of this song; nothing of a song it does not name', () {
      final album = job(11, result: albumSaid(copied: [late]));
      expect(pageSongMarker(album: album, filepath: late)!.kind, CopyMarkerKind.inCollection);
      expect(pageSongMarker(album: album, filepath: 'music/Boukmanflow/Borrowed Tapes/01.mp3'), isNull);
    });
  });
}
