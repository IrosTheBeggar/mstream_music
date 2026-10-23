// lib/util/discover_badges.dart — what the user already did with a
// Discover lead, ported from the mStream webapp's
// webapp/alpha/discovery-page.js. The cases are
// test/unit/webapp-discovery-page.test.mjs's "jobBadges" and "connected
// servers' badges" groups, one for one (the webapp's stub DISCOVERJOBS
// cases run here against the real jobRowState), then the phone's markers:
// glyph + word per row and card, the strip's fraction, "copying 2 of 3".
//
// The batch lookup is answered as the server's does — each row's keys, and
// the jobs under any of them — with keys built here the way the server's
// jobKeysFor builds them in the respect that matters: album and artist keys
// carry NO server, so Stage Peer B's and Stage Peer C's "Borrowed Tapes"
// share one album key.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/discover_badges.dart';
import 'package:mstream_music/util/discover_jobs.dart';

String _norm(Object? v) => '${v ?? ''}'.trim().toLowerCase();
bool _has(Object? v) => v is String && v.trim().isNotEmpty;

/// The server's jobKeysFor, in shape: a scope's key exists only when the
/// recommendation has its field; album / artist keys ignore the peer.
Map<String, String> keysOfRec(Map<String, dynamic> rec) => {
      'song': 'text:${_norm(rec['artist'])}|${_norm(rec['title'])}|${_norm(rec['album'])}',
      if (_has(rec['album']))
        'album': 'album:${_norm(_has(rec['artist']) ? rec['artist'] : rec['albumArtist'])}|${_norm(rec['album'])}',
      if (_has(rec['artist'])) 'artist': 'artist:${_norm(rec['artist'])}',
      if (_has(rec['artist'])) 'artist-missing': 'artist-missing:${_norm(rec['artist'])}',
      if (_has(rec['filepath'])) 'folder': 'folder:${(rec['peer'] as Map?)?['id']}|${rec['filepath']}',
    };

/// The batch route: results aligned with the recommendations, each with
/// the jobs under any of its keys.
List<JobLookup?> batchAnswer(List<Map<String, dynamic>> recs, List<DiscoveryJob> jobs) => [
      for (final rec in recs)
        () {
          final keys = keysOfRec(rec);
          final own = keys.values.toSet();
          return JobLookup(key: keys['song'], keys: keys, jobs: [for (final j in jobs) if (own.contains(j.key)) j]);
        }(),
    ];

DiscoveryJob jobOf(Map<String, dynamic> m) => DiscoveryJob.fromServerMap(m)!;

const pb = {'id': 1, 'name': 'Stage Peer B'};
const pc = {'id': 4, 'name': 'Stage Peer C'};

Map<String, dynamic> fedRow(Map<String, Object> peer, String title,
        {String artist = 'Artist Q', String? album = 'Album P1', String? albumArtist, int year = 2020, double similarity = 0.74, String? filepath}) =>
    Map.unmodifiable({
      'artist': artist,
      'title': title,
      'album': album,
      'albumArtist': albumArtist,
      'year': year,
      'duration': 243,
      'similarity': similarity,
      'genreTags': null,
      'recordingMbid': null,
      'filepath': filepath ?? 'music/q/$title.mp3',
      'peer': {'id': peer['id'], 'name': peer['name']},
      'source': 'federation',
    });

Map<String, dynamic> tape(Map<String, Object> peer, String title, double similarity) => fedRow(peer, title,
    artist: 'Boukmanflow', album: 'Borrowed Tapes', year: 2021, similarity: similarity, filepath: 'peerlib/Boukmanflow/Borrowed Tapes/$title.mp3');

Map<String, dynamic> recOf(Map<String, dynamic> raw, [Map<String, dynamic> over = const {}]) => {
      'source': 'federation',
      'peer': raw['peer'],
      'title': raw['title'],
      'artist': raw['artist'],
      'album': raw['album'],
      'year': raw['year'],
      'filepath': raw['filepath'],
      ...over,
    };

/// The webapp test's `copy(id, row, scope, state, result, over)`.
DiscoveryJob copy(int id, Map<String, dynamic> raw, String scope, String state,
        [Map<String, dynamic>? result, Map<String, dynamic> over = const {}]) =>
    jobOf({
      'id': id,
      'plugin': 'federation-copy',
      'key': keysOfRec(raw)[scope],
      'state': state,
      'params': scope == 'song' ? <String, dynamic>{} : {'scope': scope},
      'recommendation': recOf(raw),
      'result': result,
      'progress': state == 'running' ? 0.4 : null,
      'statusText': state == 'running' ? 'album 1 of 1 · 2 of 3 songs' : null,
      ...over,
    });

Map<String, dynamic> albumDone(int copied, [Map<String, dynamic> over = const {}]) => {
      'scope': 'album',
      'songs': {'total': 3, 'copied': List.generate(copied, (_) => {}), 'skipped': [], 'failed': []},
      'counts': {'total': 3, 'copied': copied, 'skipped': 0, 'failed': 0},
      'stopped': null,
      'peer': pb,
      ...over,
    };

/// A page of connected-server rows, best match first, and its album cards
/// (grouped by server + album + artist, as the Discover controller groups
/// them), the cards finding their rows by raw row.
class Page {
  final List<Map<String, dynamic>> raws;
  final List<BadgeCard> cards;
  Page(List<Map<String, dynamic>> rows)
      : raws = ([...rows]..sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double))),
        cards = [] {
    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final r in raws) {
      final k = '${(r['peer'] as Map)['id']}|${_norm(r['album'])}|${_norm(r['albumArtist'] ?? r['artist'])}';
      byKey.putIfAbsent(k, () => []).add(r);
    }
    for (final group in byKey.values) {
      cards.add(BadgeCard(peerId: (group.first['peer'] as Map)['id'] as int, album: group.first['album'] as String, raws: group));
    }
  }

  List<BadgeRow> get rows => [for (final r in raws) BadgeRow.of(r)];
  int byTitle(String t) => raws.indexWhere((r) => r['title'] == t);
  List<BadgeRow> lookedUp(List<DiscoveryJob> jobs) => jobBadges(rows, results: batchAnswer(raws, jobs));
}

void main() {
  group('jobBadges', () {
    final net = [
      fedRow(pb, 'Lead One', artist: 'Artist M', album: 'Album N1'),
      fedRow(pb, 'Lead Two', artist: 'Artist N', album: 'Album N2'),
      fedRow(pb, 'Lead Three', artist: 'Artist O', album: null),
    ];
    final rows = [for (final r in net) BadgeRow.of(r)];
    final k0 = keysOfRec(net[0]);
    final k1 = keysOfRec(net[1]);
    DiscoveryJob job(int id, String? key, String state, [Map<String, dynamic> over = const {}]) =>
        jobOf({'id': id, 'plugin': 'youtube', 'key': key, 'state': state, 'params': {}, ...over});

    test("the batch answer sets each row's keys and its badge", () {
      final jobs = [job(5, k0['song'], 'done'), job(7, k0['song'], 'running'), job(3, k1['album'], 'failed', {'plugin': 'federation-copy', 'params': {'scope': 'album'}})];
      final chunks = lookupChunks(net);
      expect(chunks, hasLength(1));
      expect(identical(chunks[0][0], net[0]), isTrue, reason: 'the lookup sends the raw rows');
      final badged = jobBadges(rows, results: batchAnswer(chunks[0], jobs));
      expect(badged[0].recKey, k0['song']);
      expect(badged[0].recKeys, contains(k0['album']));
      expect(badged[0].jobs['youtube']!.id, 5, reason: 'jobsBySlot keeps the first per slot, as the server orders them');
      final b0 = badged[0].badge!;
      expect([b0.row.kind, b0.plugin, b0.live, b0.slot, b0.scope, b0.kind, b0.jobId], [JobRowKind.done, 'youtube', false, 'youtube', 'song', null, 5]);
      expect(badged[1].badge!.slot, 'federation-copy@album');
      expect(badged[1].badge!.kind, JobKind.album);
      expect(badged[2].badge, isNull);
      expect(badged[2].jobs, isEmpty);
      expect(identical(badged[0].raw, net[0]), isTrue, reason: 'the raw row survives');
      expect(rows[0].badge, isNull, reason: 'the input rows are not mutated');
    });

    test('a flat job list (the poll) merges by key: newer wins, live outranks finished, cancelled shows nothing', () {
      final first = jobBadges(rows, results: batchAnswer(net, [job(5, k0['song'], 'done')]));
      final polled = jobBadges(first, jobs: [job(9, k0['song'], 'queued'), job(4, k0['song'], 'running'), job(11, 'text:other', 'running')]);
      expect(polled[0].jobs['youtube']!.id, 9);
      expect(polled[0].badge!.row.kind, JobRowKind.queued);
      expect(polled[0].badge!.live, isTrue);
      expect(anyLiveBadge(polled), isTrue);
      expect(polled[1].badge, isNull, reason: "another row's job stays off this one");
      // Two slots: the live copy outranks the finished download.
      final two = jobBadges(first, jobs: [job(12, k0['album'], 'running', {'plugin': 'federation-copy', 'params': {'scope': 'album'}})]);
      expect(two[0].badge!.slot, 'federation-copy@album');
      // A failure outranks a finished job; a cancelled one is no badge.
      final failed = jobBadges(first, jobs: [job(13, k0['artist'], 'failed', {'params': {'scope': 'artist'}})]);
      expect(failed[0].badge!.row.kind, JobRowKind.failed);
      final cancelled = jobBadges(rows, results: batchAnswer(net, [job(6, k0['song'], 'cancelled')]));
      expect(cancelled[0].badge, isNull);
      expect(anyLiveBadge(cancelled), isFalse);
      // Rows that never had a lookup have no keys: the poll leaves them alone.
      expect(jobBadges(rows, jobs: [job(1, k0['song'], 'running')])[0].badge, isNull);
    });

    test('a chunk that failed (null answer) leaves its rows as they were', () {
      final first = jobBadges(rows, results: batchAnswer(net, [job(5, k0['song'], 'done')]));
      final again = jobBadges(first, results: List<JobLookup?>.filled(net.length, null));
      expect(again[0].badge!.jobId, 5);
      expect(again[0].recKeys, first[0].recKeys);
    });

    test('the badge is the job row the sheet would show', () {
      final page = Page([tape(pb, 'Late Train Verse', 0.9), tape(pb, 'Corner Store Loop', 0.7), fedRow(pb, 'Glass One', artist: 'Color Out', album: 'Glass', similarity: 0.6)]);
      final copying = jobOf({
        'id': 21, 'plugin': 'federation-copy', 'key': keysOfRec(page.raws[0])['album'], 'state': 'running', 'progress': 0.25,
        'statusText': '2 of 7 songs', 'params': {'scope': 'album'}, 'cancelRequested': false,
      });
      final badged = page.lookedUp([copying]);
      final b = badged[0].badge!;
      expect(b.row.kind, JobRowKind.running);
      expect(b.row.tag, JobPhrase.copying);
      expect(b.row.sub, [const JobText.server('2 of 7 songs · 25%')]);
      expect(b.kind, JobKind.album);
      expect(b.row.actions, [JobAction.cancel]);
      expect(badged[1].badge!.jobId, 21, reason: 'two songs of one album share the album job');
      expect(badged[2].badge, isNull, reason: 'another album: nothing');
    });

    test('lookups go in chunks of 100', () {
      final many = List.generate(230, (i) => <String, dynamic>{'title': 't$i', 'source': 'p2p'});
      expect([for (final c in lookupChunks(many)) c.length], [100, 100, 30]);
      expect(lookupChunks([null, null]), isEmpty);
    });
  });

  // The play page's connected-server rows and album cards: one badge per
  // server. The stage's 'Borrowed Tapes' (B holds two of its songs here, C
  // one) shares one album key across both.
  group("connected servers' badges: per server, the album cards from their rows", () {
    Page page() => Page([
          tape(pb, 'Late Train Verse', 0.9),
          tape(pb, 'Corner Store Loop', 0.7),
          fedRow(pb, 'Glass One', artist: 'Color Out', album: 'Glass', similarity: 0.6),
          tape(pc, 'Rooftop Cypher', 0.8),
        ]);

    test('the fixture: one album key across both servers, the cards apart', () {
      final p = page();
      expect([for (final r in p.raws) [(r['peer'] as Map)['id'], r['title']]], [
        [1, 'Late Train Verse'], [4, 'Rooftop Cypher'], [1, 'Corner Store Loop'], [1, 'Glass One'],
      ]);
      expect(keysOfRec(p.raws[p.byTitle('Late Train Verse')])['album'], keysOfRec(p.raws[p.byTitle('Rooftop Cypher')])['album'],
          reason: 'the album key ignores the server');
      expect([for (final c in p.cards) [c.peerId, c.album, c.raws.length]], [
        [1, 'Borrowed Tapes', 2], [4, 'Borrowed Tapes', 1], [1, 'Glass', 1],
      ]);
    });

    test('an album job badges every row of its card and the card; a song job only its row, never a card', () {
      final p = page();
      final late = p.raws[p.byTitle('Late Train Verse')];
      var badged = p.lookedUp([copy(30, late, 'album', 'running')]);
      for (final t in ['Late Train Verse', 'Corner Store Loop']) {
        final b = badged[p.byTitle(t)].badge!;
        expect([b.row.kind, b.row.tag, b.kind, b.slot, b.row.progress], [JobRowKind.running, JobPhrase.copying, JobKind.album, 'federation-copy@album', 40], reason: t);
      }
      expect(badged[p.byTitle('Glass One')].badge, isNull, reason: 'another album: nothing');
      var cardBadges = peerAlbumBadges(p.cards, badged);
      expect([cardBadges[0]!.row.kind, cardBadges[0]!.kind, cardBadges[0]!.jobId], [JobRowKind.running, JobKind.album, 30]);
      expect([cardBadges[1], cardBadges[2]], [null, null], reason: "C's card and the other album stay bare");
      expect(anyLiveBadge(badged), isTrue);

      badged = p.lookedUp([copy(31, late, 'song', 'done', {'copied': {'vpath': 'collection', 'filepath': 'collection/From peers/Boukmanflow/Borrowed Tapes/Late Train Verse.mp3'}})]);
      expect([badged[p.byTitle('Late Train Verse')].badge!.row.kind, badged[p.byTitle('Late Train Verse')].badge!.row.tag], [JobRowKind.copied, JobPhrase.inCollection]);
      expect(badged[p.byTitle('Corner Store Loop')].badge, isNull, reason: 'one song of the album is not the album');
      cardBadges = peerAlbumBadges(p.cards, badged);
      expect(cardBadges, [null, null, null], reason: 'a song job never badges a card');
    });

    test("another server's album copy never badges this server's rows or card — running or done — and stays in their jobs, marked", () {
      final p = page();
      final roof = p.raws[p.byTitle('Rooftop Cypher')];
      for (final job in [copy(40, roof, 'album', 'running'), copy(41, roof, 'album', 'done', albumDone(1, {'peer': pc}))]) {
        final badged = p.lookedUp([job]);
        for (final t in ['Late Train Verse', 'Corner Store Loop']) {
          final r = badged[p.byTitle(t)];
          expect(r.badge, isNull, reason: "$t (${job.state}): C's copy is not B's");
          expect(r.jobs['federation-copy@album']!.id, job.id, reason: "kept in the row's jobs (the sheet says \"from Stage Peer C\")");
          expect(r.otherPeer, ['federation-copy@album']);
          expect(r.isOtherPeer(kCopyPlugin, 'album'), isTrue);
        }
        final own = badged[p.byTitle('Rooftop Cypher')];
        expect(own.badge!.jobId, job.id, reason: "C's own row shows it");
        expect(own.otherPeer, isEmpty);
        final cardBadges = peerAlbumBadges(p.cards, badged);
        expect(cardBadges[0], isNull, reason: "B's Borrowed Tapes card: no badge");
        expect(cardBadges[1]!.jobId, job.id, reason: "C's card: its own copy");
      }
      final done = peerAlbumBadges(p.cards, p.lookedUp([copy(41, roof, 'album', 'done', albumDone(1, {'peer': pc}))]))[1]!;
      expect([done.row.kind, done.row.tag, done.kind], [JobRowKind.copiedMany, JobPhrase.inCollection, JobKind.album]);
      // the poll's flat list merges the same way (no new lookup)
      final first = p.lookedUp([]);
      final polled = jobBadges(first, jobs: [copy(42, roof, 'album', 'running')]);
      expect(polled[p.byTitle('Late Train Verse')].badge, isNull);
      expect(polled[p.byTitle('Late Train Verse')].otherPeer, ['federation-copy@album']);
      expect(polled[p.byTitle('Rooftop Cypher')].badge!.jobId, 42);
    });

    test('a song copied from another server is the same recording: it badges the row wherever it came from', () {
      final p = page();
      final late = p.raws[p.byTitle('Late Train Verse')];
      final fromC = copy(50, late, 'song', 'done', {'copied': {'vpath': 'collection', 'filepath': 'collection/x.mp3'}}, {'recommendation': recOf(late, {'peer': pc})});
      final badged = p.lookedUp([fromC]);
      expect(badged[p.byTitle('Late Train Verse')].badge!.jobId, 50);
      expect(badged[p.byTitle('Late Train Verse')].otherPeer, isEmpty);
    });

    test("an artist job badges that server's rows and cards of the artist — never another server's, never another artist's", () {
      final p = page();
      final late = p.raws[p.byTitle('Late Train Verse')];
      for (final (scope, kind) in [('artist', JobKind.artist), ('artist-missing', JobKind.artistMissing)]) {
        final badged = p.lookedUp([copy(60, late, scope, 'queued')]);
        expect([badged[p.byTitle('Late Train Verse')].badge!.kind, badged[p.byTitle('Corner Store Loop')].badge!.kind], [kind, kind], reason: scope);
        expect(badged[p.byTitle('Rooftop Cypher')].badge, isNull, reason: "$scope: C's row");
        expect(badged[p.byTitle('Glass One')].badge, isNull, reason: '$scope: Color Out');
        final cardBadges = peerAlbumBadges(p.cards, badged);
        expect([for (final b in cardBadges) b == null ? null : [b.row.kind, b.kind]], [[JobRowKind.queued, kind], null, null], reason: scope);
      }
    });

    // An artist walk as federation-copy reports it.
    Map<String, dynamic> walked(String name, {int copied = 0, int skipped = 0, int failed = 0, String? stopped, String? error}) => error != null
        ? {'name': name, 'year': null, 'error': error, 'songs': {'total': 0, 'copied': [], 'skipped': [], 'failed': []}, 'bytes': 0, 'stopped': null}
        : {
            'name': name, 'year': 2021, 'bytes': 0, 'stopped': stopped,
            'songs': {
              'total': copied + skipped + failed,
              'copied': List.generate(copied, (_) => {}),
              'skipped': List.generate(skipped, (_) => {'why': 'owned'}),
              'failed': List.generate(failed, (_) => {'error': 'x'}),
            },
          };
    Map<String, dynamic> artistDone(List<Map<String, dynamic>> albums, List<Map<String, dynamic>> skippedAlbums, [Map<String, dynamic> over = const {}]) {
      int sum(String k) => albums.fold(0, (n, a) => n + ((a['songs'] as Map)[k] as List).length);
      final total = albums.fold<int>(0, (n, a) => n + ((a['songs'] as Map)['total'] as int));
      return {
        'scope': 'artist', 'artist': {'name': 'Boukmanflow'}, 'albums': albums, 'skippedAlbums': skippedAlbums,
        'songs': {
          'total': total,
          'copied': [for (final a in albums) ...((a['songs'] as Map)['copied'] as List)],
          'skipped': [for (final a in albums) ...((a['songs'] as Map)['skipped'] as List)],
          'failed': [for (final a in albums) ...((a['songs'] as Map)['failed'] as List)],
        },
        'counts': {'total': total, 'copied': sum('copied'), 'skipped': sum('skipped'), 'failed': sum('failed')},
        'stopped': null, 'peer': pb, ...over,
      };
    }

    // B also holds a song Boukmanflow only guests on, on a compilation that
    // names no album artist: the card groups by the track's artist, so
    // Discover draws 'Block Party Comp · Boukmanflow' — the same artist key.
    Page compPage() => Page([
          tape(pb, 'Late Train Verse', 0.9),
          tape(pb, 'Corner Store Loop', 0.7),
          fedRow(pb, 'Party Verse', artist: 'Boukmanflow', album: 'Block Party Comp', year: 2020, similarity: 0.65, filepath: 'peerlib/VA/Block Party Comp/07 - Party Verse.mp3'),
        ]);

    test('a finished artist copy speaks for each card as its walk did: a compilation they only guest on is never "in your collection"', () {
      final p = compPage();
      final late = p.raws[p.byTitle('Late Train Verse')];
      expect([for (final c in p.cards) c.album], ['Borrowed Tapes', 'Block Party Comp']);
      expect(keysOfRec(late)['artist'], keysOfRec(p.raws[p.byTitle('Party Verse')])['artist'], reason: 'one artist key for both albums');
      final result = artistDone([walked('Borrowed Tapes', copied: 2)], [{'name': 'Block Party Comp', 'year': 2020, 'trackCount': 12, 'why': 'appearance'}]);
      final badged = p.lookedUp([copy(90, late, 'artist', 'done', result)]);
      for (final t in ['Late Train Verse', 'Corner Store Loop']) {
        final b = badged[p.byTitle(t)].badge!;
        expect([b.row.kind, b.row.tag, b.kind, b.jobId], [JobRowKind.copiedMany, JobPhrase.inCollection, JobKind.artist, 90], reason: t);
      }
      expect(badged[p.byTitle('Party Verse')].badge, isNull, reason: 'the walk left the compilation out: nothing of it is in the library');
      expect(badged[p.byTitle('Party Verse')].jobs['federation-copy@artist']!.id, 90, reason: "still the row's job (the sheet shows it)");
      final cardBadges = peerAlbumBadges(p.cards, badged);
      expect([for (final b in cardBadges) b == null ? null : [b.row.kind, b.row.tag, b.kind]], [
        [JobRowKind.copiedMany, JobPhrase.inCollection, JobKind.artist], null,
      ]);
      // while it runs, every card of the artist reads "copying · every album"
      final live = peerAlbumBadges(p.cards, p.lookedUp([copy(91, late, 'artist', 'running')]));
      expect([for (final b in live) [b!.row.kind, b.kind]], [[JobRowKind.running, JobKind.artist], [JobRowKind.running, JobKind.artist]]);
    });

    test('album by album: its own songs\' account, "already yours" when only-missing left it out, nothing where its listing failed or the walk never reached it', () {
      final p = page();
      final late = p.raws[p.byTitle('Late Train Verse')];
      List<JobBadge?> card(Map<String, dynamic> result, [String scope = 'artist']) {
        final badged = p.lookedUp([copy(95, late, scope, 'done', result)]);
        return [peerAlbumBadges(p.cards, badged)[0], badged[p.byTitle('Late Train Verse')].badge];
      }

      List<Object?> states(List<JobBadge?> pair) => [for (final b in pair) b == null ? null : [b.row.kind, b.row.tag]];
      // the job copied 3 elsewhere, but every song of THIS album failed
      final mixed = artistDone([walked('Borrowed Tapes', failed: 2), walked('Second Wind', copied: 3)], []);
      expect(jobRowState(copy(95, late, 'artist', 'done', mixed)).kind, JobRowKind.copiedMany, reason: 'the job as a whole');
      expect(states(card(mixed)), [[JobRowKind.failed, JobPhrase.failed], [JobRowKind.failed, JobPhrase.failed]]);
      // the walk names albums as the peer's listing spells them: folded as name-key.js folds them
      expect(states(card(artistDone([walked('borrowed  TAPES', copied: 2)], []))), [[JobRowKind.copiedMany, JobPhrase.inCollection], [JobRowKind.copiedMany, JobPhrase.inCollection]]);
      expect(states(card(artistDone([walked('Borrowed Tapes', skipped: 2)], []))), [[JobRowKind.owned, JobPhrase.owned], [JobRowKind.owned, JobPhrase.owned]]);
      // only-missing left it out: the library has it
      final owned = artistDone([walked('Second Wind', copied: 3)], [{'name': 'Borrowed Tapes', 'year': 2021, 'trackCount': 2, 'why': 'owned'}], {'scope': 'artist-missing'});
      final ownedPair = card(owned, 'artist-missing');
      expect(states(ownedPair), [[JobRowKind.owned, JobPhrase.owned], [JobRowKind.owned, JobPhrase.owned]]);
      expect(ownedPair[0]!.kind, JobKind.artistMissing);
      // its listing failed, the walk went on: nothing claimed for it
      expect(card(artistDone([walked('Borrowed Tapes', error: 'Stage Peer B answered 500'), walked('Second Wind', copied: 3)], [])), [null, null]);
      // the run stopped there (the transfer limit): stopped
      final quota = card(artistDone([walked('Second Wind', copied: 3), walked('Borrowed Tapes', error: 'transfer limit')], [], {'stopped': 'quota'}));
      expect(states(quota), [[JobRowKind.stopped, JobPhrase.stopped], [JobRowKind.stopped, JobPhrase.stopped]]);
      // stopped mid-album: that album stopped; one the walk never reached says nothing
      expect(states(card(artistDone([walked('Borrowed Tapes', copied: 1, stopped: 'busy')], [], {'stopped': 'busy'}))), [[JobRowKind.stopped, JobPhrase.stopped], [JobRowKind.stopped, JobPhrase.stopped]]);
      expect(card(artistDone([walked('Second Wind', copied: 1, stopped: 'quota')], [], {'stopped': 'quota'})), [null, null]);
      // a done artist job with no walk at all to read: nothing claimed
      expect(card({'counts': {'total': 2, 'copied': 2, 'skipped': 0, 'failed': 0}, 'songs': {'total': 2, 'copied': [{}, {}], 'skipped': [], 'failed': []}, 'stopped': null}), [null, null]);
      // a failed artist job (it never walked) still says so on every card of the artist
      final failed = p.lookedUp([copy(96, late, 'artist', 'failed', null, {'error': 'Stage Peer B is unreachable'})]);
      expect([peerAlbumBadges(p.cards, failed)[0]!.row.kind, failed[p.byTitle('Corner Store Loop')].badge!.row.kind], [JobRowKind.failed, JobRowKind.failed]);
      // an album job is the album's: unchanged
      expect(peerAlbumBadges(p.cards, p.lookedUp([copy(97, late, 'album', 'done', albumDone(3))]))[0]!.row.kind, JobRowKind.copiedMany);
    });

    test("nameKey is src/db/name-key.js's, byte for byte (golden values)", () {
      final gold = jsonDecode(File('test/util/fixtures/discover_layout_gold.json').readAsStringSync()) as Map;
      final names = gold['names'] as List;
      final want = gold['nameKey'] as List;
      for (var i = 0; i < names.length; i++) {
        expect(nameKey(names[i]), want[i], reason: jsonEncode(names[i]));
      }
    });

    test('"done" is not "kept": a copy stopped by the quota reads stopped, one whose songs all failed reads failed — on rows and cards', () {
      final p = page();
      final late = p.raws[p.byTitle('Late Train Verse')];
      final quota = p.lookedUp([copy(70, late, 'album', 'done', albumDone(1, {'stopped': 'quota'}))]);
      for (final b in [quota[p.byTitle('Late Train Verse')].badge!, peerAlbumBadges(p.cards, quota)[0]!]) {
        expect([b.row.kind, b.row.tag, b.row.tagTone], [JobRowKind.stopped, JobPhrase.stopped, JobTone.error]);
      }
      final failed = p.lookedUp([
        copy(71, late, 'album', 'done', albumDone(0, {'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': [{}, {}, {}]}, 'counts': {'total': 3, 'copied': 0, 'skipped': 0, 'failed': 3}}))
      ]);
      final fb = peerAlbumBadges(p.cards, failed)[0]!;
      expect([fb.row.kind, fb.row.tag, fb.row.tagTone], [JobRowKind.failed, JobPhrase.failed, JobTone.error], reason: 'never "already yours"');
    });

    test('the card ranks as a row does: a live copy over a finished one; a folder job never badges', () {
      final p = page();
      final late = p.raws[p.byTitle('Late Train Verse')];
      final badged = p.lookedUp([copy(80, late, 'album', 'done', albumDone(3)), copy(81, late, 'artist', 'running')]);
      expect([peerAlbumBadges(p.cards, badged)[0]!.jobId, badged[p.byTitle('Late Train Verse')].badge!.jobId], [81, 81]);
      final folder = jobOf({
        'id': 82, 'plugin': 'federation-copy', 'key': keysOfRec(late)['folder'], 'state': 'running', 'params': {'scope': 'folder'},
        'recommendation': recOf(late),
      });
      final withFolder = p.lookedUp([folder]);
      expect(withFolder[p.byTitle('Late Train Verse')].badge, isNull, reason: 'Discover never offers a folder copy');
      // no rows, a card with no raws, no cards: no badge, never a throw
      expect(peerAlbumBadges(p.cards, []), [null, null, null]);
      expect(peerAlbumBadges([const BadgeCard(peerId: 1)], badged), [null]);
      expect(peerAlbumBadges(null, badged), isEmpty);
    });

    // The compilations decision (2026-10-19): rows may carry albumArtist,
    // and a compilation is one card under its album artist — its album job
    // sends the best row unchanged and badges every row of the card.
    test('a compilation card: rows by different artists share the album job and the card shows it', () {
      final p = Page([
        fedRow(pb, 'Party Verse', artist: 'Boukmanflow', album: 'Block Party Comp', albumArtist: 'Various Artists', similarity: 0.9),
        fedRow(pb, 'Kim Song', artist: 'Peer Kim', album: 'Block Party Comp', albumArtist: 'Various Artists', similarity: 0.8),
      ]);
      expect([for (final c in p.cards) [c.album, c.raws.length]], [['Block Party Comp', 2]], reason: 'one card, not one per track artist');
      // the server keys the compilation's album job by the album (its own
      // business); every row of the card answers that key in its lookup
      final key = 'album:various artists|block party comp';
      final job = jobOf({
        'id': 99, 'plugin': 'federation-copy', 'key': key, 'state': 'running', 'progress': 0.33,
        'statusText': '1 of 3 songs · 7.4 MB', 'params': {'scope': 'album'}, 'recommendation': p.raws[0],
      });
      final results = [
        for (final r in p.raws) JobLookup(key: keysOfRec(r)['song'], keys: {...keysOfRec(r), 'album': key}, jobs: [job]),
      ];
      final badged = jobBadges(p.rows, results: results);
      expect([for (final r in badged) r.badge?.jobId], [99, 99]);
      final card = peerAlbumBadges(p.cards, badged).single!;
      final m = copyMarkerOf(card, album: 'Block Party Comp')!;
      expect([m.kind, m.done, m.total, m.fraction], [CopyMarkerKind.copying, 1, 3, 0.33]);
    });
  });

  group("the phone's markers", () {
    final page = Page([tape(pb, 'Late Train Verse', 0.9), tape(pb, 'Corner Store Loop', 0.7)]);
    final late = page.raws[0];
    CopyMarker? rowMarker(DiscoveryJob job) => copyMarkerOf(page.lookedUp([job])[0].badge, album: 'Borrowed Tapes');
    CopyMarker? cardMarker(DiscoveryJob job) => copyMarkerOf(peerAlbumBadges(page.cards, page.lookedUp([job]))[0], album: 'Borrowed Tapes');

    test('which marker a job shows — done is not kept', () {
      expect(rowMarker(copy(1, late, 'song', 'queued'))!.kind, CopyMarkerKind.waiting);
      expect(rowMarker(copy(2, late, 'song', 'running'))!.kind, CopyMarkerKind.copying);
      expect(rowMarker(copy(3, late, 'song', 'running', null, {'cancelRequested': true}))!.kind, CopyMarkerKind.stopping);
      expect(rowMarker(copy(4, late, 'song', 'done', {'copied': {'filepath': 'demo/a.mp3'}}))!.kind, CopyMarkerKind.inCollection);
      expect(rowMarker(copy(5, late, 'album', 'done', albumDone(2)))!.kind, CopyMarkerKind.inCollection);
      expect(rowMarker(copy(6, late, 'song', 'done', {'skipped': 'owned', 'existing': {'filepath': 'demo/a.mp3'}}))!.kind, CopyMarkerKind.alreadyYours);
      expect(rowMarker(copy(7, late, 'album', 'done', albumDone(0, {'songs': {'total': 0, 'copied': [], 'skipped': [], 'failed': []}, 'counts': {'total': 0, 'copied': 0, 'skipped': 0, 'failed': 0}})))!.kind,
          CopyMarkerKind.alreadyYours, reason: 'nothing to copy: you have it all');
      expect(rowMarker(copy(8, late, 'album', 'done', albumDone(1, {'stopped': 'quota'})))!.kind, CopyMarkerKind.stopped);
      expect(rowMarker(copy(9, late, 'album', 'done', albumDone(0, {'stopped': 'refused'})))!.kind, CopyMarkerKind.refused);
      expect(rowMarker(copy(10, late, 'song', 'failed', null, {'error': 'Stage Peer B is unreachable'}))!.kind, CopyMarkerKind.failed);
      expect(rowMarker(copy(11, late, 'album', 'done', albumDone(0, {'counts': {'total': 3, 'copied': 0, 'skipped': 0, 'failed': 3}})))!.kind, CopyMarkerKind.failed,
          reason: 'copied 0 with failures is a failure');
      expect(rowMarker(copy(12, late, 'song', 'done', {'skipped': 'exists', 'filepath': 'demo/a.mp3'}))!.kind, CopyMarkerKind.skipped);
      expect(rowMarker(copy(13, late, 'song', 'cancelled')), isNull, reason: 'cancelled: no marker');
      final guest = copy(14, late, 'artist', 'done', {
        'scope': 'artist', 'albums': [], 'skippedAlbums': [{'name': 'Borrowed Tapes', 'why': 'appearance'}],
        'songs': {'total': 0, 'copied': [], 'skipped': [], 'failed': []}, 'counts': {'total': 0, 'copied': 0, 'skipped': 0, 'failed': 0}, 'stopped': null,
      });
      expect(copyMarkerOf(badgeOf({'federation-copy@artist': guest})), isNull, reason: 'nothing of theirs to copy: no marker');
      expect(copyMarkerOf(null), isNull);
    });

    test("the row's strip is the copy's fraction while it moves; unknown is a sliding segment", () {
      final m = rowMarker(copy(20, late, 'song', 'running', null, {'progress': 0.62}))!;
      expect([m.kind, m.fraction, m.showsStrip, m.live], [CopyMarkerKind.copying, 0.62, true, true]);
      final unknown = rowMarker(copy(21, late, 'song', 'running', null, {'progress': null}))!;
      expect([unknown.fraction, unknown.showsStrip], [null, true]);
      final waiting = rowMarker(copy(22, late, 'song', 'queued'))!;
      expect([waiting.showsStrip, waiting.live], [false, true]);
      expect(rowMarker(copy(23, late, 'song', 'done', {'copied': {'filepath': 'demo/a.mp3'}}))!.showsStrip, isFalse);
    });

    test('a copying card counts its songs: "copying 2 of 3" from the server\'s progress line', () {
      final album = cardMarker(copy(30, late, 'album', 'running', null, {'statusText': '2 of 3 songs · 7.4 MB · Late Train Verse'}))!;
      expect([album.kind, album.done, album.total], [CopyMarkerKind.copying, 2, 3]);
      // still asking the peer: no count yet ("copying…")
      final asking = cardMarker(copy(31, late, 'album', 'running', null, {'statusText': 'asking Stage Peer B for “Borrowed Tapes”', 'progress': 0}))!;
      expect([asking.kind, asking.done, asking.total], [CopyMarkerKind.copying, null, null]);
      // an artist walk counts only while it is on this card's album
      final onIt = cardMarker(copy(32, late, 'artist', 'running', null, {'statusText': 'album 2 of 5 · Borrowed Tapes · 1 of 3 songs · 2.1 MB'}))!;
      expect([onIt.done, onIt.total], [1, 3]);
      final elsewhere = cardMarker(copy(33, late, 'artist', 'running', null, {'statusText': 'album 1 of 5 · Second Wind · 4 of 9 songs · 9.0 MB'}))!;
      expect([elsewhere.kind, elsewhere.done, elsewhere.total], [CopyMarkerKind.copying, null, null]);
      // the walk's summary line names albums, not songs of one
      final summary = cardMarker(copy(34, late, 'artist', 'running', null, {'statusText': '2 of 5 albums · 7 songs copied · 12.0 MB'}))!;
      expect(summary.done, isNull);
      // a song name that reads like a count does not fool the album head
      expect(copyingCounts(copy(35, late, 'album', 'done', albumDone(3))), isNull, reason: 'only while running');
    });
  });

  // The Keep card's choices: a finished wider copy of the same server speaks
  // for a narrower choice — as its walk came out for the album, as its song
  // lists name the song's file — unless the choice's own job is live or
  // newer (the user's Boukmanflow report, 2026-10-20: "Only the albums you
  // don't have" copied Borrowed Tapes, and the Album choice still offered
  // "Add album").
  group("the Keep card's choices: a finished wider copy speaks for a narrower one", () {
    final late = tape(pb, 'Late Train Verse', 0.9);
    final lateFile = late['filepath'] as String;
    final cornerFile = 'peerlib/Boukmanflow/Borrowed Tapes/Corner Store Loop.mp3';
    final roof = tape(pc, 'Rooftop Cypher', 0.8);

    Map<String, dynamic> landed(String from) => {
          'from': from,
          'vpath': 'copies',
          'filepath': 'copies/Boukmanflow/Borrowed Tapes/${from.split('/').last}',
          'trackId': 7,
          'bytes': 1234,
        };
    Map<String, dynamic> songsOf({List<Map<String, dynamic>> copied = const [], List<Map<String, dynamic>> skipped = const [], List<Map<String, dynamic>> failed = const []}) =>
        {'total': copied.length + skipped.length + failed.length, 'copied': copied, 'skipped': skipped, 'failed': failed};
    Map<String, dynamic> walk(String name, Map<String, dynamic> songs, {String? error}) =>
        {'name': name, 'year': 2021, 'songs': songs, 'bytes': 0, 'stopped': null, 'error': ?error};
    // federation-copy's artist result: the walk, what it left out, the songs
    // of every album gathered (each with its album's name).
    Map<String, dynamic> artistResult(String scope, List<Map<String, dynamic>> albums, [List<Map<String, dynamic>> left = const []]) {
      List<Map<String, dynamic>> all(String k) => [
            for (final a in albums)
              for (final e in ((a['songs'] as Map)[k] as List)) {'album': a['name'], ...(e as Map<String, dynamic>)},
          ];
      final total = albums.fold<int>(0, (n, a) => n + ((a['songs'] as Map)['total'] as int));
      return {
        'scope': scope,
        'artist': {'name': 'Boukmanflow'},
        'albums': albums,
        'skippedAlbums': left,
        'songs': {'total': total, 'copied': all('copied'), 'skipped': all('skipped'), 'failed': all('failed')},
        'counts': {'total': total, 'copied': all('copied').length, 'skipped': all('skipped').length, 'failed': all('failed').length},
        'stopped': null,
        'peer': pb,
      };
    }

    Map<String, dynamic> albumResult(Map<String, dynamic> songs) => {
          'scope': 'album',
          'album': {'name': 'Borrowed Tapes', 'artist': 'Boukmanflow', 'albumArtist': null, 'year': 2021},
          'songs': songs,
          'counts': {
            'total': songs['total'],
            'copied': (songs['copied'] as List).length,
            'skipped': (songs['skipped'] as List).length,
            'failed': (songs['failed'] as List).length,
          },
          'stopped': null,
          'peer': pb,
        };

    // The user's run: only the albums they lacked — Borrowed Tapes, all three songs copied.
    final missingCopied = artistResult('artist-missing', [
      walk('Borrowed Tapes', songsOf(copied: [landed(lateFile), landed(cornerFile), landed('peerlib/Boukmanflow/Borrowed Tapes/Rooftop Cypher.mp3')])),
    ], [
      {'name': 'Night Market', 'year': 2018, 'why': 'owned'},
    ]);

    KeepChoiceJob? album(List<DiscoveryJob> held, {DiscoveryJob? own, bool ownFromOtherPeer = false, String? albumName = 'Borrowed Tapes'}) =>
        keepChoiceJob('album', own: own, ownFromOtherPeer: ownFromOtherPeer, held: held, peerId: 1, album: albumName, filepath: lateFile);
    KeepChoiceJob? song(List<DiscoveryJob> held, {DiscoveryJob? own, String filepath = ''}) =>
        keepChoiceJob('song', own: own, held: held, peerId: 1, album: 'Borrowed Tapes', filepath: filepath.isEmpty ? lateFile : filepath);
    List<Object?> read(KeepChoiceJob? pick) {
      if (pick == null) return [null];
      final row = jobRowState(pick.job, plugin: kCopyPlugin);
      return [pick.job.id, row.kind, row.tag, pick.wider, row.sub, row.filepath];
    }

    test('jobNewer: the finish times, else the update times, else the ids', () {
      DiscoveryJob j(int id, {int? finished, int? updated}) =>
          copy(id, late, 'album', 'done', null, {'finishedAt': finished, 'updatedAt': updated});
      expect(jobNewer(j(1, finished: 2000), j(2, finished: 1000)), isTrue, reason: 'finished later, though older');
      expect(jobNewer(j(2, finished: 1000), j(1, finished: 2000)), isFalse);
      expect(jobNewer(j(1, finished: 5, updated: 2000), j(2, finished: 5, updated: 1000)), isTrue, reason: 'the same finish: the update');
      expect(jobNewer(j(1, updated: 2000), j(2, finished: 3000, updated: 1000)), isTrue, reason: 'one lacks a finish time: the updates');
      expect(jobNewer(j(2), j(1)), isTrue, reason: 'no times: the ids');
      expect(jobNewer(j(1), j(2)), isFalse);
      expect(jobNewer(j(1, finished: 7), j(2, finished: 7)), isFalse, reason: 'a tie all the way: the ids');
    });

    test('Album: an only-missing copy that copied this album reads "in your collection · 3 copied", from that job', () {
      for (final scope in ['artist-missing', 'artist']) {
        final res = scope == 'artist' ? {...missingCopied, 'scope': 'artist'} : missingCopied;
        final pick = album([copy(70, late, scope, 'done', res, {'finishedAt': 2000})]);
        expect(read(pick), [70, JobRowKind.copiedMany, JobPhrase.inCollection, true, [const JobText(JobPhrase.copiedCount, count: 3)], null], reason: scope);
        expect(pick!.fromOtherPeer, isFalse);
        expect(jobScope(pick.job), scope, reason: 'still that job (its scope, its id)');
      }
    });

    test('Album: left out as owned reads "already yours"; a guest spot or an album never walked offers Add album', () {
      final owned = artistResult('artist-missing', [walk('Second Wind', songsOf(copied: [landed('peerlib/x/1.mp3')]))], [
        {'name': 'Borrowed Tapes', 'year': 2021, 'why': 'owned'},
      ]);
      final pick = album([copy(71, late, 'artist-missing', 'done', owned)]);
      expect(read(pick).sublist(0, 4), [71, JobRowKind.owned, JobPhrase.owned, true]);
      final guest = artistResult('artist', [walk('Second Wind', songsOf(copied: [landed('peerlib/x/1.mp3')]))], [
        {'name': 'Borrowed Tapes', 'year': 2021, 'why': 'appearance'},
      ]);
      expect(album([copy(72, late, 'artist', 'done', guest)]), isNull, reason: 'appearance: nothing');
      final elsewhere = artistResult('artist-missing', [walk('Second Wind', songsOf(copied: [landed('peerlib/x/1.mp3')]))]);
      expect(album([copy(73, late, 'artist-missing', 'done', elsewhere)]), isNull, reason: 'never walked: nothing');
      expect(album([copy(70, late, 'artist-missing', 'done', missingCopied)], albumName: null), isNull, reason: 'a row with no album');
    });

    test('Album: only a FINISHED wider copy — a live or failed one stays on Artist; a listing that failed says nothing', () {
      expect(album([copy(74, late, 'artist-missing', 'running')]), isNull);
      expect(album([copy(75, late, 'artist', 'queued')]), isNull);
      expect(album([copy(76, late, 'artist', 'failed', null, {'error': 'Stage Peer B is unreachable'})]), isNull);
      expect(album([copy(77, late, 'artist', 'cancelled', missingCopied)]), isNull);
      final listingFailed = artistResult('artist', [walk('Borrowed Tapes', songsOf(), error: 'Stage Peer B answered 500'), walk('Second Wind', songsOf(copied: [landed('peerlib/x/1.mp3')]))]);
      expect(album([copy(78, late, 'artist', 'done', listingFailed)]), isNull);
      // the run stopped on this album: jobForAlbum's own "stopped"
      final stopped = {
        ...artistResult('artist', [walk('Borrowed Tapes', songsOf(), error: 'transfer limit')]),
        'stopped': 'quota',
      };
      expect(read(album([copy(79, late, 'artist', 'done', stopped)])).sublist(0, 4), [79, JobRowKind.stopped, JobPhrase.stopped, true]);
    });

    test("Album: another server's finished artist copy is ignored", () {
      final fromC = copy(80, roof, 'artist-missing', 'done', {...missingCopied, 'peer': pc});
      expect(fromC.peerId, 4);
      expect(album([fromC]), isNull);
      // ... and with this server's own beside it, this server's speaks
      expect(read(album([fromC, copy(81, late, 'artist', 'done', missingCopied)]))[0], 81);
    });

    test("Album: the choice's own album job wins when it is live, or newer", () {
      final wider = copy(82, late, 'artist-missing', 'done', missingCopied, {'finishedAt': 2000});
      // the user's second press: an album job after the artist job, "already yours"
      final ownNewer = copy(83, late, 'album', 'done', albumResult(songsOf(skipped: [{'from': lateFile, 'why': 'owned', 'at': 'copies/x.mp3'}])), {'finishedAt': 3000});
      expect(read(album([wider, ownNewer], own: ownNewer)).sublist(0, 4), [83, JobRowKind.owned, JobPhrase.owned, false]);
      // an older album job: the artist copy's account is the newer word
      final ownOlder = copy(84, late, 'album', 'done', albumResult(songsOf(failed: [{'from': lateFile, 'error': 'x'}])), {'finishedAt': 1000});
      expect(read(album([wider, ownOlder], own: ownOlder)).sublist(0, 4), [82, JobRowKind.copiedMany, JobPhrase.inCollection, true]);
      // newer by id when no times are known
      final noTimesWider = copy(85, late, 'artist-missing', 'done', missingCopied);
      final noTimesOwn = copy(86, late, 'album', 'done', albumResult(songsOf(copied: [landed(lateFile)])));
      expect(read(album([noTimesWider, noTimesOwn], own: noTimesOwn))[0], 86);
      expect(read(album([copy(87, late, 'artist-missing', 'done', missingCopied), copy(86, late, 'album', 'done', albumResult(songsOf()))], own: copy(86, late, 'album', 'done', albumResult(songsOf()))))[0], 87);
      // a live album job always wins, however new the wider copy
      final live = copy(88, late, 'album', 'running', null, {'updatedAt': 1});
      final pick = album([copy(89, late, 'artist-missing', 'done', missingCopied, {'finishedAt': 9999, 'updatedAt': 9999}), live], own: live);
      expect(read(pick).sublist(0, 4), [88, JobRowKind.running, JobPhrase.copying, false]);
      // no wider word: the own job as before
      expect(read(album([ownOlder], own: ownOlder))[0], 84);
      expect(album(const []), isNull);
    });

    test("Album: another server's album copy shows only while it runs; a wider copy of this server stands in once it ends", () {
      final cLive = copy(90, roof, 'album', 'running');
      final cDone = copy(91, roof, 'album', 'done', albumResult(songsOf(copied: [landed(lateFile)])), {'finishedAt': 9000});
      final wider = copy(92, late, 'artist-missing', 'done', missingCopied, {'finishedAt': 1000});
      final live = album([cLive, wider], own: cLive, ownFromOtherPeer: true)!;
      expect([live.job.id, live.fromOtherPeer, live.wider], [90, true, false]);
      expect(read(album([cDone, wider], own: cDone, ownFromOtherPeer: true)).sublist(0, 4), [92, JobRowKind.copiedMany, JobPhrase.inCollection, true], reason: "C's finished copy is not B's word, however new");
      expect(album([cDone], own: cDone, ownFromOtherPeer: true), isNull);
    });

    test("This song: a finished album copy that names this song's file — copied, already yours, skipped; failed or unlisted says nothing", () {
      final copied = song([copy(100, late, 'album', 'done', albumResult(songsOf(copied: [landed(cornerFile), landed(lateFile)])))]);
      expect(read(copied), [100, JobRowKind.copied, JobPhrase.inCollection, true, [const JobText.server('copies / Boukmanflow / Borrowed Tapes / Late Train Verse.mp3')], 'copies/Boukmanflow/Borrowed Tapes/Late Train Verse.mp3']);
      expect(copied!.job.view.isMany, isFalse, reason: "a song copy's shape");
      final owned = song([copy(101, late, 'album', 'done', albumResult(songsOf(skipped: [{'from': lateFile, 'why': 'owned', 'at': 'music/Boukmanflow/Late Train Verse.flac'}])))]);
      expect(read(owned), [101, JobRowKind.owned, JobPhrase.owned, true, [const JobText.server('music / Boukmanflow / Late Train Verse.flac')], 'music/Boukmanflow/Late Train Verse.flac']);
      final ownedNowhere = song([copy(102, late, 'album', 'done', albumResult(songsOf(skipped: [{'from': lateFile, 'why': 'owned', 'at': null}])))]);
      expect(read(ownedNowhere), [102, JobRowKind.owned, JobPhrase.owned, true, [const JobText(JobPhrase.ownedSub)], null]);
      // a file already at the path is not "yours": the song copy's own "skipped"
      final exists = song([copy(103, late, 'album', 'done', albumResult(songsOf(skipped: [{'from': lateFile, 'why': 'exists', 'at': 'copies/Boukmanflow/Borrowed Tapes/Late Train Verse.mp3'}])))]);
      expect(read(exists).sublist(0, 4), [103, JobRowKind.exists, JobPhrase.skipped, true]);
      expect(song([copy(104, late, 'album', 'done', albumResult(songsOf(copied: [landed(cornerFile)], failed: [{'from': lateFile, 'error': 'x'}])))]), isNull, reason: 'its copy failed');
      expect(song([copy(105, late, 'album', 'done', albumResult(songsOf(copied: [landed(cornerFile)])))]), isNull, reason: 'not listed');
      expect(song([copy(106, late, 'album', 'done', albumResult(songsOf(copied: [{'from': lateFile, 'vpath': 'copies'}])))]), isNull, reason: 'no landed file named');
      // the paths compare without a leading slash
      expect(read(song([copy(107, late, 'album', 'done', albumResult(songsOf(copied: [landed('/$lateFile')])))]))[1], JobRowKind.copied);
    });

    test("This song: an artist copy's account of the row's album names the song too; an album left out as owned proves nothing of one song", () {
      final pick = song([copy(110, late, 'artist-missing', 'done', missingCopied)]);
      expect(read(pick).sublist(0, 4), [110, JobRowKind.copied, JobPhrase.inCollection, true]);
      expect(pick!.job.view.copiedFilepath, 'copies/Boukmanflow/Borrowed Tapes/Late Train Verse.mp3');
      final owned = artistResult('artist-missing', const [], [
        {'name': 'Borrowed Tapes', 'year': 2021, 'why': 'owned'},
      ]);
      expect(song([copy(111, late, 'artist-missing', 'done', owned)]), isNull);
      // the walk copied the album under another name: not this row's album
      final other = artistResult('artist', [walk('Second Wind', songsOf(copied: [landed(lateFile)]))]);
      expect(song([copy(112, late, 'artist', 'done', other)]), isNull);
    });

    test("This song: the song's own job wins when live or newer; another server's album copy never speaks", () {
      final albumJob = copy(120, late, 'album', 'done', albumResult(songsOf(copied: [landed(lateFile)])), {'finishedAt': 2000});
      final ownNewer = copy(121, late, 'song', 'done', {'skipped': 'owned', 'existing': {'filepath': 'music/a.mp3'}}, {'finishedAt': 3000});
      expect(read(song([albumJob, ownNewer], own: ownNewer)).sublist(0, 4), [121, JobRowKind.owned, JobPhrase.owned, false]);
      final ownOlder = copy(122, late, 'song', 'failed', null, {'finishedAt': 1000, 'error': 'gone'});
      expect(read(song([albumJob, ownOlder], own: ownOlder)).sublist(0, 4), [120, JobRowKind.copied, JobPhrase.inCollection, true]);
      final live = copy(123, late, 'song', 'queued');
      expect(read(song([albumJob, live], own: live)).sublist(0, 4), [123, JobRowKind.queued, JobPhrase.queued, false]);
      final fromC = copy(124, roof, 'album', 'done', {...albumResult(songsOf(copied: [landed(lateFile)])), 'peer': pc});
      expect(song([fromC]), isNull);
      // the newest of two wider words
      final artistJob = copy(125, late, 'artist-missing', 'done', {
        ...artistResult('artist-missing', [walk('Borrowed Tapes', songsOf(skipped: [{'from': lateFile, 'why': 'owned', 'at': 'copies/x.mp3'}]))]),
      }, {'finishedAt': 5000});
      expect(read(song([albumJob, artistJob]))[0], 125);
      expect(read(song([albumJob, copy(126, late, 'artist', 'done', artistJob.result, {'finishedAt': 100})]))[0], 120);
    });

    test('Artist and other scopes: no wider word', () {
      expect(widerChoiceView('artist', [copy(130, late, 'artist-missing', 'done', missingCopied)], peerId: 1, album: 'Borrowed Tapes'), isNull);
      expect(widerChoiceView('album', [copy(131, late, 'album', 'done', albumResult(songsOf(copied: [landed(lateFile)])))], peerId: 1, album: 'Borrowed Tapes'), isNull, reason: 'an album job is the album choice\'s own');
      expect(widerChoiceView('song', [copy(132, late, 'song', 'done', {'copied': {'filepath': 'a.mp3'}})], peerId: 1, album: 'Borrowed Tapes', filepath: lateFile), isNull);
    });
  });
}
