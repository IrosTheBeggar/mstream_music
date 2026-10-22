// lib/util/discover_jobs.dart — the Discover job rows' pure half, ported
// from the mStream webapp's webapp/alpha/discover-jobs.js. The cases below
// are test/unit/webapp-discover-jobs.test.mjs's, one for one (the youtube
// download rows included: the state machine is the same for every plug-in),
// then the phone's own: the Copies list keeps a finished copy that failed or
// stopped, a compilation's album title, the re-paired peer, the poll delay.
//
// The layout preview is held to the server's own engine through golden
// values it produced (test/util/fixtures/discover_layout_gold.json, made by
// discover_layout_gold.mjs from the mStream checkout), as the webapp's test
// holds its copy to src/torrent/path-template.js and destination.js.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/discover_jobs.dart';

final int now = DateTime.utc(2026, 8, 18, 12).millisecondsSinceEpoch;
const int day = 24 * 60 * 60 * 1000;

/// The webapp test's `job(over)`: a queued youtube job unless [over] says
/// otherwise — through the real parser.
DiscoveryJob job([Map<String, dynamic> over = const {}]) =>
    DiscoveryJob.fromServerMap({
      'id': 1,
      'plugin': 'youtube',
      'state': 'queued',
      'progress': null,
      'statusText': null,
      'result': null,
      'error': null,
      'cancelRequested': false,
      'createdAt': now,
      'recommendation': {'artist': 'Neon Harbor', 'title': 'Salt & Static'},
      ...over,
    })!;

DiscoveryJob copyJob([Map<String, dynamic> over = const {}]) =>
    job({'plugin': 'federation-copy', ...over});

JobText p(JobPhrase phrase, {int? count, String? peer, String? path}) =>
    JobText(phrase, count: count, peer: peer, path: path);
JobText srv(String s) => JobText.server(s);

/// The webapp test's `many(over)`: an album copy's result.
Map<String, dynamic> many([Map<String, dynamic> over = const {}]) => {
      'scope': 'album',
      'album': {'name': 'Night Ferry', 'artist': 'Nova'},
      'songs': {
        'total': 4,
        'copied': [
          {'from': 'a'},
          {'from': 'b'}
        ],
        'skipped': [
          {'from': 'c', 'why': 'owned'}
        ],
        'failed': [],
      },
      'bytes': 10,
      'stopped': null,
      'peer': {'id': 1, 'name': "Sam's server"},
      ...over,
    };

Map<String, dynamic> songs(
        {int total = 0, int copied = 0, int skipped = 0, int failed = 0}) =>
    {
      'total': total,
      'copied': List.generate(copied, (_) => <String, dynamic>{}),
      'skipped': List.generate(skipped, (_) => <String, dynamic>{}),
      'failed': List.generate(failed, (_) => <String, dynamic>{}),
    };

void main() {
  group('the layout preview agrees with the server engine (golden values)', () {
    final gold = jsonDecode(
            File('test/util/fixtures/discover_layout_gold.json').readAsStringSync())
        as Map<String, dynamic>;
    // { x: n } stands for 'x' repeated n times.
    Object? unpack(Object? v) =>
        v is Map && v.length == 1 && v['x'] is int ? 'x' * (v['x'] as int) : v;
    List<Object?> list(String k) => [for (final v in gold[k] as List) unpack(v)];
    final layouts = [...list('layouts'), ...list('badLayouts')].cast<String>();
    final tags = [
      for (final t in gold['tags'] as List)
        {for (final e in (t as Map).entries) e.key as String: unpack(e.value)}
    ];

    test('sanitizeSegment, value for value', () {
      final segs = list('segments');
      final want = list('sanitize');
      for (var i = 0; i < segs.length; i++) {
        expect(sanitizeSegment(segs[i]), want[i], reason: 'sanitize ${segs[i]}');
      }
    });

    test('resolveLayout: every layout × tag set × peer', () {
      for (final r in gold['resolve'] as List) {
        final layout = layouts[r['layout'] as int];
        final mine = resolveLayout(layout, {...tags[r['tags'] as int], 'peer': r['peer']});
        expect(mine.path, unpack(r['path']), reason: 'resolve "$layout" #${r['tags']} / ${r['peer']}');
        expect(mine.missingVars, r['missingVars']);
      }
    });

    test('validateLayout accepts and refuses what the server does, with the same error code', () {
      final want = gold['validate'] as List;
      for (var i = 0; i < layouts.length; i++) {
        final mine = validateLayout(layouts[i]);
        expect(mine.valid, want[i]['valid'], reason: 'validity of "${layouts[i]}"');
        if (want[i]['valid'] != true) expect(mine.error, want[i]['error']);
      }
      final unknown = validateLayout('{{ARTIST}}/{{TRACK}}');
      expect([unknown.valid, unknown.error, unknown.variable], [false, 'unknown_variable', 'TRACK']);
      expect(validateLayout(null).valid, isFalse);
      expect([...kLayoutVars]..sort(), [...(gold['layoutVars'] as List).cast<String>()]..sort(),
          reason: 'the same variables are offered');
      expect(kDefaultLayout, gold['defaultLayout']);
    });

    test('the base folder and the file name follow the same rules', () {
      final bases = list('bases');
      final want = gold['normalizeBase'] as List;
      for (var i = 0; i < bases.length; i++) {
        final mine = normalizeBase(bases[i]);
        expect(mine.valid, want[i]['valid'], reason: 'base ${bases[i]}');
        if (want[i]['valid'] == true) {
          expect(mine.base, want[i]['base']);
        } else {
          expect(mine.error, want[i]['error']);
        }
      }
      final files = list('files');
      final names = list('safeFileName');
      for (var i = 0; i < files.length; i++) {
        expect(safeFileName(files[i]), names[i], reason: 'file name ${files[i]}');
      }
    });

    test('previewTarget is renderTarget for everything the server would accept', () {
      final good = list('layouts').cast<String>();
      for (final r in gold['renderTarget'] as List) {
        final mine = previewTarget(
          vpath: 'music',
          base: r['base'],
          layout: good[r['layout'] as int],
          tags: tags[r['tags'] as int],
          peerName: "Sam's server",
          fileName: 'shared/03 Paper Lanterns.flac',
        );
        expect(mine.valid, isTrue);
        expect(mine.relPath, unpack(r['relPath']), reason: '${good[r['layout'] as int]} / ${r['base']}');
        expect(mine.missingVars, r['missingVars']);
      }
    });

    test('previewTarget names the broken field, and splits the path for the preview line', () {
      final ok = previewTarget(
          vpath: 'music',
          base: 'From peers',
          layout: '{{ARTIST}}/{{ALBUM}} ({{YEAR}})',
          tags: {'artist': 'Marlowe Vale', 'album': 'Night Ferry'},
          peerName: 'Sam',
          fileName: 'x/03 Paper Lanterns.flac');
      expect([ok.library, ok.base, ok.rendered, ok.file, ok.relPath, ok.missingVars], [
        'music',
        'From peers',
        'Marlowe Vale/Night Ferry ()',
        '03 Paper Lanterns.flac',
        'From peers/Marlowe Vale/Night Ferry ()/03 Paper Lanterns.flac',
        ['YEAR'],
      ]);
      final badLayout = previewTarget(vpath: 'music', base: '', layout: '{{ARTIST}}/{{TRACK}}', tags: {}, fileName: 'a.mp3');
      expect([badLayout.valid, badLayout.field, badLayout.error, badLayout.variable], [false, 'layout', 'unknown_variable', 'TRACK']);
      final badBase = previewTarget(vpath: 'music', base: '../up', layout: '{{ARTIST}}', tags: {}, fileName: 'a.mp3');
      expect([badBase.valid, badBase.field, badBase.error], [false, 'base', 'traversal']);
      // Tags that render nothing: the file lands in the base folder itself.
      final bare = previewTarget(vpath: 'music', base: 'Inbox', layout: '{{GENRE}}', tags: {}, fileName: 'a.mp3');
      expect(bare.relPath, 'Inbox/a.mp3');
      expect(pathCrumbs('music/A/B/c.mp3'), ['music', 'A', 'B', 'c.mp3']);
    });

    test("the Keep card's destination line: library › folders, no file", () {
      final t = previewTarget(
          vpath: 'demo',
          base: '',
          layout: '{{ARTIST}}/{{ALBUM}}',
          tags: {'artist': 'Boukmanflow', 'album': 'Borrowed Tapes'},
          fileName: 'peerlib/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3');
      expect(t.crumbs, ['demo', 'Boukmanflow', 'Borrowed Tapes']);
      expect(t.relPath, 'Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3');
    });
  });

  group('a job as a row', () {
    test('idle: a download offers Download, a copy offers Add', () {
      final dl = jobRowState(null, plugin: 'youtube');
      expect([dl.kind, dl.actions, dl.icon, dl.live], [JobRowKind.idle, [JobAction.start], JobIcon.download, false]);
      expect(jobRowState(null, plugin: 'federation-copy').icon, JobIcon.folder);
    });

    test('queued and running: progress, the status line, Cancel; a requested cancel takes the button away', () {
      final q = jobRowState(job({'state': 'queued'}));
      expect([q.kind, q.tag, q.actions, q.live, q.icon], [JobRowKind.queued, JobPhrase.queued, [JobAction.cancel], true, JobIcon.clock]);
      final r = jobRowState(job({'state': 'running', 'progress': 0.432, 'statusText': 'Neon Harbor – Salt & Static (Official Audio)'}));
      expect([r.kind, r.tag, r.progress, r.actions], [JobRowKind.running, JobPhrase.downloading, 43, [JobAction.cancel]]);
      expect(r.sub, [srv('Neon Harbor – Salt & Static (Official Audio) · 43%')]);
      // A status line with its own percentage is not given a second one.
      expect(jobRowState(job({'state': 'running', 'progress': 0.45, 'statusText': '43% of “Salt & Static”'})).sub,
          [srv('43% of “Salt & Static”')]);
      final searching = jobRowState(job({'state': 'running', 'progress': null, 'statusText': 'Searching YouTube'}));
      expect([searching.indeterminate, searching.progress, searching.sub], [true, null, [srv('Searching YouTube')]]);
      expect(jobRowState(job({'state': 'running'})).sub, [p(JobPhrase.starting)]);
      final copying = jobRowState(job({'plugin': 'federation-copy', 'state': 'running', 'progress': 0.5}));
      expect([copying.tag, copying.sub], [JobPhrase.copying, [srv('50%')]]);
      final stopping = jobRowState(job({'state': 'running', 'progress': 0.5, 'cancelRequested': true}));
      expect([stopping.tag, stopping.actions], [JobPhrase.stopping, <JobAction>[]]);
    });

    test('a finished download: done, saved to its place in the collection, playable', () {
      const fp = 'music/Neon Harbor/Low Tide/Salt_Static.mp3';
      final done = jobRowState(job({
        'state': 'done',
        'result': {
          'downloaded': {'vpath': 'music', 'filepath': fp, 'trackId': 9, 'bytes': 10066329, 'format': 'mp3', 'downloadId': 4},
          'match': {'url': 'https://youtu.be/x'},
          'missingVars': [],
        }
      }));
      expect([done.kind, done.tag, done.tagTone, done.actions, done.filepath],
          [JobRowKind.downloaded, JobPhrase.done, JobTone.ok, [JobAction.play, JobAction.queue], fp]);
      expect(done.sub, [p(JobPhrase.savedTo, path: 'music / Neon Harbor / Low Tide / Salt_Static.mp3')]);
    });

    test('a finished copy: copied, already owned, or a file in the way', () {
      final copied = jobRowState(job({
        'plugin': 'federation-copy',
        'state': 'done',
        'result': {
          'copied': {'vpath': 'music', 'filepath': 'music/Marlowe Vale/Night Ferry/03 Paper Lanterns.flac'}
        }
      }));
      expect([copied.kind, copied.tag, copied.actions], [JobRowKind.copied, JobPhrase.inCollection, [JobAction.play, JobAction.queue]]);
      expect(copied.filepath, 'music/Marlowe Vale/Night Ferry/03 Paper Lanterns.flac');
      final owned = jobRowState(job({
        'plugin': 'federation-copy',
        'state': 'done',
        'result': {
          'skipped': 'owned',
          'existing': {'filepath': 'music/x/y.flac', 'by': 'hash'}
        }
      }));
      expect([owned.kind, owned.actions, owned.filepath], [JobRowKind.owned, [JobAction.play, JobAction.queue], 'music/x/y.flac']);
      final exists = jobRowState(job({
        'plugin': 'federation-copy',
        'state': 'done',
        'result': {'skipped': 'exists', 'filepath': 'music/x/y.flac'}
      }));
      expect([exists.kind, exists.actions, exists.sub],
          [JobRowKind.exists, [JobAction.retry], [p(JobPhrase.existsSub, path: 'music / x / y.flac')]]);
    });

    test("failed carries the server's reason; cancelled offers the download again; an unknown result is just done", () {
      final failed = jobRowState(job({'state': 'failed', 'error': 'Nothing matched closely enough (best score 0.41, needs 0.62)'}));
      expect([failed.kind, failed.tagTone, failed.actions, failed.sub], [
        JobRowKind.failed,
        JobTone.error,
        [JobAction.retry],
        [srv('Nothing matched closely enough (best score 0.41, needs 0.62)')]
      ]);
      expect(jobRowState(job({'state': 'failed'})).sub, [p(JobPhrase.failedSub)]);
      final cancelled = jobRowState(job({'state': 'cancelled'}));
      expect([cancelled.kind, cancelled.muted, cancelled.actions, cancelled.sub],
          [JobRowKind.cancelled, true, [JobAction.start], [p(JobPhrase.cancelledSub)]]);
      expect(jobRowState(job({'plugin': 'federation-copy', 'state': 'cancelled'})).sub, [p(JobPhrase.cancelledCopySub)]);
      expect(jobRowState(job({'state': 'done', 'result': {'echoed': 'x'}})).kind, JobRowKind.done);
      expect(jobRowState(job({'state': 'done'})).actions, <JobAction>[]);
    });

    test('formatting helpers', () {
      expect([0, 512, 2048, 5.5 * 1024 * 1024, 98 * 1024 * 1024, 3 * 1024 * 1024 * 1024, double.nan].map(fmtBytes).toList(),
          ['', '512 B', '2 KB', '5.5 MB', '98 MB', '3.0 GB', '']);
      final idx = jobsByPlugin([job({'id': 5, 'plugin': 'youtube'}), job({'id': 4, 'plugin': 'youtube'}), job({'id': 3, 'plugin': 'federation-copy'})]);
      expect({for (final e in idx.entries) e.key: e.value.id}, {'youtube': 5, 'federation-copy': 3});
      expect(jobsByPlugin(null), isEmpty);
    });
  });

  test("the phone's copies: Keep a copy's plug-in, a Discover scope, started as Discover starts it", () {
    expect(isDiscoverCopy(copyJob()), isTrue);
    for (final scope in ['album', 'artist', 'artist-missing']) {
      expect(isDiscoverCopy(copyJob({'params': {'scope': scope}})), isTrue, reason: scope);
    }
    expect(isDiscoverCopy(job()), isFalse, reason: 'a YouTube download');
    expect(isDiscoverCopy(copyJob({'params': {'scope': 'folder'}})), isFalse, reason: 'never Folder');
    expect(
        isDiscoverCopy(copyJob({
          'params': {'scope': 'album', 'landing': {'vpath': 'music', 'path': 'mine'}}
        })),
        isFalse,
        reason: 'a landing the webapp chose');
    expect(isDiscoverCopy(copyJob({'params': {'choice': {'url': 'https://example.com/x'}}})), isFalse);
    expect(isDiscoverCopy(null), isFalse);
  });

  group('where a copy lands', () {
    const place = CollectionDestination(vpath: 'copies', base: 'From peers/Stage', layout: '{{ALBUMARTIST}}/{{ALBUM}}', source: 'user');

    test("sameDestination is the jobs route's: the library, the base folder normalised, the layout exactly; source ignored", () {
      CollectionDestination d({String vpath = 'copies', String base = 'From peers/Stage', String layout = '{{ALBUMARTIST}}/{{ALBUM}}', String? source}) =>
          CollectionDestination(vpath: vpath, base: base, layout: layout, source: source);
      expect(sameDestination(place, d()), isTrue, reason: 'source is not compared');
      expect(sameDestination(place, d(base: r' From peers \ Stage/ ')), isTrue, reason: 'either separator, names trimmed, empty ones gone');
      expect(sameDestination(place, d(base: 'From peers')), isFalse);
      expect(sameDestination(place, d(vpath: 'music')), isFalse);
      expect(sameDestination(place, d(layout: '{{ARTIST}}/{{ALBUM}}')), isFalse);
      expect(sameDestination(place, d(layout: '{{ALBUMARTIST}}/{{ALBUM}} ')), isFalse, reason: 'the layout character for character');
      expect(sameDestination(d(base: '../up'), d(base: '../up')), isFalse, reason: 'a base the server refuses matches nothing');
      expect(sameDestination(null, null), isTrue);
      expect(sameDestination(place, null), isFalse);
      expect(sameDestination(null, place), isFalse);
    });

    test("a job's place: its pin, else its result's (a job from before the pin), else none", () {
      Map<String, dynamic> wire(String base) => {'vpath': 'copies', 'base': base, 'layout': '{{ALBUMARTIST}}/{{ALBUM}}'};
      expect(copyJob({'params': {'scope': 'album', 'destination': wire('Pinned')}, 'result': {'destination': wire('Ran')}}).destination!.base, 'Pinned');
      expect(copyJob({'params': {'scope': 'album'}, 'result': {'destination': wire('Ran')}}).destination!.base, 'Ran');
      expect(copyJob().destination, isNull);
      expect(copyJob({'params': {'destination': null}}).destination, isNull, reason: 'pinned to nowhere');
      expect(copyJob({'params': {'destination': null}, 'result': {'destination': wire('Ran')}}).destination, isNull, reason: 'the pin outranks its result');
    });

    test("the place a restart sends: the pin — nowhere included — else the result's; none when it names neither", () {
      Map<String, dynamic> wire(String base) => {'vpath': 'copies', 'base': base, 'layout': '{{ALBUMARTIST}}/{{ALBUM}}'};
      final nowhere = copyJob({'params': {'destination': null}, 'result': {'destination': wire('Ran')}});
      expect([nowhere.pinnedNowhere, nowhere.ranWith != null, nowhere.ranWith?.toJson()], [true, true, null]);
      expect(copyJob({'params': {'scope': 'album'}, 'result': {'destination': wire('Ran')}}).ranWith!.toJson(),
          {'vpath': 'copies', 'base': 'Ran', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}'});
      expect([copyJob().pinnedNowhere, copyJob().ranWith], [false, null]);
      expect(copyJob({'params': {'scope': 'album'}}).pinnedNowhere, isFalse, reason: 'no destination key is no pin');
    });
  });

  group('the Copies list (the webapp\'s downloads strip)', () {
    final jobs = [
      job({'id': 1, 'state': 'done', 'createdAt': now - 50, 'result': {'copied': {'filepath': 'music/a.flac'}}}),
      job({'id': 2, 'state': 'failed', 'createdAt': now - 40, 'error': 'nope'}),
      job({'id': 3, 'state': 'done', 'createdAt': now - 30, 'result': {'downloaded': {'filepath': 'music/Neon Harbor/a.mp3'}}}),
      job({'id': 4, 'state': 'queued', 'createdAt': now - 20}),
      job({'id': 5, 'state': 'running', 'createdAt': now - 10}),
      job({'id': 6, 'state': 'cancelled', 'createdAt': now - 5}),
      job({'id': 7, 'state': 'done', 'createdAt': now - 4, 'result': {'skipped': 'owned', 'existing': {'filepath': 'music/a.mp3'}}}),
      job({'id': 8, 'state': 'failed', 'createdAt': now - 3, 'error': 'also nope'}),
      job({'id': 9, 'state': 'running', 'createdAt': now - 2}),
    ];
    List<int> ids(List<DiscoveryJob> l) => [for (final j in l) j.id];

    test('holds what still wants the user — live work first, then failures, newest first within a kind; a landed download is settled', () {
      expect(ids(trayRows(jobs)), [9, 5, 4, 8, 2]);
      expect(trayRows(null), isEmpty);
    });

    test('a failure that was retried leaves the list: a newer job for the same plug-in and recommendation supersedes it', () {
      final retried = [
        job({'id': 10, 'key': 'text:a', 'state': 'failed', 'createdAt': now - 30}),
        job({'id': 11, 'key': 'text:a', 'state': 'running', 'createdAt': now - 20}),
        job({'id': 12, 'key': 'text:b', 'state': 'failed', 'createdAt': now - 10}),
        job({'id': 13, 'key': 'text:a', 'plugin': 'other', 'state': 'failed', 'createdAt': now - 5}),
      ];
      expect(ids(trayRows(retried)), [11, 13, 12]);
      // Even a cancelled retry closes the matter; the newest failure still shows.
      expect(trayRows([job({'id': 20, 'key': 'text:c', 'state': 'failed'}), job({'id': 21, 'key': 'text:c', 'state': 'cancelled'})]), isEmpty);
      expect(ids(trayRows([job({'id': 30, 'key': 'text:d', 'state': 'failed'}), job({'id': 31, 'key': 'text:d', 'state': 'failed'})])), [31]);
      expect(traySummary(retried).failed, 2);
    });

    test('the summary counts running and failed, leaves zeroes out, and says whether to keep polling fast', () {
      final s = traySummary(jobs);
      expect([s.total, s.running, s.failed, s.live, s.clearable], [5, 3, 2, true, true]);
      final quiet = traySummary([jobs[1]]);
      expect([quiet.total, quiet.live, quiet.clearable, quiet.running, quiet.failed], [1, false, true, 0, 1]);
      expect([traySummary([jobs[2]]).total, traySummary([]).total], [0, 0], reason: 'a landed download is not in the list');
      expect(traySummary([]).shown, isFalse);
    });

    test('titles, and what finished between two polls', () {
      expect(jobTitle(jobs[0]), 'Salt & Static — Neon Harbor');
      expect(jobTitle(DiscoveryJob.fromServerMap({'id': 1, 'plugin': 'x', 'recommendation': {'title': 'Only a title'}})), 'Only a title');
      expect(jobTitle(null), '');
      final before = [job({'id': 1, 'state': 'running'}), job({'id': 2, 'state': 'queued'}), job({'id': 3, 'state': 'failed'})];
      final after = [
        job({'id': 1, 'state': 'done', 'result': {'downloaded': {'filepath': 'music/a.mp3'}}}),
        job({'id': 2, 'state': 'running'}),
        job({'id': 3, 'state': 'failed'}),
        job({'id': 4, 'state': 'done'}),
      ];
      expect(ids(finishedSince(before, after)), [1], reason: 'only a job seen live and now finished is news');
      expect(finishedSince(null, after), isEmpty);
    });

    // The phone's departure: "1 failed" counts the failed OR stopped copies
    // left (the canvas's strip rule), and a finished album copy that copied
    // nothing because its songs failed, or that stopped early, waits there
    // for Retry or Clear finished like a failed job does.
    test('a finished copy that failed or stopped stays in the list; one that landed, or was already yours, does not', () {
      final failedMany = copyJob({'id': 40, 'key': 'album:x', 'state': 'done', 'params': {'scope': 'album'},
          'result': many({'songs': songs(total: 1, failed: 1), 'counts': {'total': 1, 'copied': 0, 'skipped': 0, 'failed': 1}})});
      final stopped = copyJob({'id': 41, 'key': 'album:y', 'state': 'done', 'params': {'scope': 'album'}, 'result': many({'stopped': 'quota'})});
      final refused = copyJob({'id': 42, 'key': 'album:z', 'state': 'done', 'params': {'scope': 'album'}, 'result': many({'stopped': 'refused'})});
      final landed = copyJob({'id': 43, 'key': 'album:w', 'state': 'done', 'params': {'scope': 'album'}, 'result': many()});
      final owned = copyJob({'id': 44, 'key': 'album:v', 'state': 'done', 'params': {'scope': 'album'},
          'result': many({'songs': songs(total: 2, skipped: 2)})});
      final running = copyJob({'id': 45, 'key': 'album:u', 'state': 'running', 'progress': 0.4});
      final list = [failedMany, stopped, refused, landed, owned, running];
      expect(ids(trayRows(list)), [45, 42, 41, 40]);
      final s = traySummary(list);
      expect([s.running, s.failed, s.total], [1, 3, 4], reason: 'Copying 1 · 3 failed');
      expect([wantsAttention(failedMany), wantsAttention(stopped), wantsAttention(landed), wantsAttention(owned)], [true, true, false, false]);
      // retried: the newer job for the same key supersedes the stopped one
      final again = copyJob({'id': 46, 'key': 'album:y', 'state': 'queued'});
      expect(ids(trayRows([stopped, again])), [46]);
    });

    test("a compilation's album copy is titled by its album artist", () {
      final comp = copyJob({'params': {'scope': 'album'}, 'recommendation': {'title': 'Party Verse', 'artist': 'Peer Kim', 'album': 'Block Party Comp', 'albumArtist': 'Various Artists'}});
      expect(jobTitle(comp), 'Block Party Comp — Various Artists');
      final plain = copyJob({'params': {'scope': 'album'}, 'recommendation': {'title': 'Departure', 'artist': 'Marlowe Vale', 'album': 'Night Ferry', 'albumArtist': null}});
      expect(jobTitle(plain), 'Night Ferry — Marlowe Vale');
    });

    test('a copy refused because the peer was re-paired asks for new seeds, not Retry', () {
      expect(jobNeedsNewSeeds(copyJob({'state': 'failed', 'error': 'this server is no longer paired with Stage Peer B'})), isTrue);
      expect(jobNeedsNewSeeds(copyJob({'state': 'failed', 'error': 'Stage Peer B is unreachable'})), isFalse);
      expect(jobNeedsNewSeeds(copyJob({'state': 'running'})), isFalse);
    });

    test('the poll delay: the beat, doubled per failure, at most 60 s', () {
      const fast = Duration(milliseconds: 1500);
      expect([for (var f = 0; f < 8; f++) pollDelay(fast, f).inMilliseconds], [1500, 3000, 6000, 12000, 24000, 48000, 60000, 60000]);
      expect(pollDelay(const Duration(seconds: 4), 0), const Duration(seconds: 4));
    });
  });

  group('a lookup answer indexed by plug-in, per scope', () {
    test('jobsByPlugin: the song rows see song jobs, the album rows album jobs', () {
      final jobs = [
        DiscoveryJob.fromServerMap({'id': 1, 'plugin': 'federation-copy', 'params': {'scope': 'album'}})!,
        DiscoveryJob.fromServerMap({'id': 2, 'plugin': 'federation-copy', 'params': null})!,
        DiscoveryJob.fromServerMap({'id': 3, 'plugin': 'youtube', 'params': {'choice': {'url': 'x'}}})!,
      ];
      Map<String, int> ids(Map<String, DiscoveryJob> m) => {for (final e in m.entries) e.key: e.value.id};
      expect(ids(jobsByPlugin(jobs)), {'federation-copy': 2, 'youtube': 3});
      expect(ids(jobsByPlugin(jobs, 'album')), {'federation-copy': 1});
      expect(jobsByPlugin(jobs, 'artist'), isEmpty);
      expect(jobsByPlugin(null), isEmpty);
    });
  });

  group('album and artist jobs as rows', () {
    test('scope, slot and the index by slot', () {
      expect(kJobScopes, ['song', 'album', 'artist', 'artist-missing']);
      expect(jobScope(job()), 'song');
      expect(jobScope(job({'params': {'scope': 'album'}})), 'album');
      expect(jobSlot('federation-copy', 'song'), 'federation-copy');
      expect(jobSlot('federation-copy'), 'federation-copy');
      expect(jobSlot('federation-copy', 'album'), 'federation-copy@album');
      final jobs = [
        copyJob({'id': 1, 'params': {'scope': 'album'}}),
        copyJob({'id': 2}),
        copyJob({'id': 3, 'params': {'scope': 'artist-missing'}}),
        copyJob({'id': 4}),
      ];
      expect({for (final e in jobsBySlot(jobs).entries) e.key: e.value.id},
          {'federation-copy@album': 1, 'federation-copy': 2, 'federation-copy@artist-missing': 3},
          reason: 'the first seen per slot');
      expect(jobsBySlot(null), isEmpty);
    });

    test('done: in your collection with the counts; nothing copied reads as already yours; an artist job counts its albums', () {
      final done = jobRowState(copyJob({'state': 'done', 'params': {'scope': 'album'}, 'result': many()}));
      expect([done.kind, done.tag, done.tagTone, done.icon, done.actions],
          [JobRowKind.copiedMany, JobPhrase.inCollection, JobTone.ok, JobIcon.check, [JobAction.start]],
          reason: 'done, and startable again for the gaps');
      expect(done.sub, [p(JobPhrase.copiedCount, count: 2), p(JobPhrase.ownedCount, count: 1)]);
      final owned = jobRowState(copyJob({'state': 'done', 'params': {'scope': 'album'}, 'result': many({'songs': songs(total: 2, skipped: 2)})}));
      expect([owned.kind, owned.tag, owned.tagTone, owned.sub],
          [JobRowKind.owned, JobPhrase.owned, JobTone.ok, [p(JobPhrase.ownedCount, count: 2)]]);
      final artist = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'artist'},
        'result': many({
          'scope': 'artist',
          'albums': [{'name': 'A'}, {'name': 'B'}],
          'skippedAlbums': [{'name': 'C', 'why': 'appearance'}],
          'songs': {'total': 3, 'copied': [{}, {}, {}], 'skipped': [], 'failed': [{'from': 'x', 'error': 'gone'}]},
        })
      }));
      expect([for (final t in artist.sub!) [t.phrase, t.count]], [
        [JobPhrase.albumsCount, 2],
        [JobPhrase.copiedCount, 3],
        [JobPhrase.failedCount, 1],
        [JobPhrase.albumsLeftOut, 1]
      ]);
      final single = jobRowState(copyJob({'state': 'done', 'result': {'copied': {'vpath': 'music', 'filepath': 'music/x/y.flac'}}}));
      expect(single.kind, JobRowKind.copied, reason: 'a single copy reads as before');
    });

    // "done" is not "kept": a many-song job ends done however it went.
    test('done with nothing copied and a song failed is a failure (Retry), never "already yours"', () {
      final failed = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'album'},
        'result': many({'songs': {'total': 1, 'copied': [], 'skipped': [], 'failed': [{'from': 'a', 'error': 'gone'}]}, 'counts': {'total': 1, 'copied': 0, 'skipped': 0, 'failed': 1}, 'stopped': null}),
      }));
      expect([failed.kind, failed.tag, failed.tagTone, failed.icon, failed.iconTone, failed.actions],
          [JobRowKind.failed, JobPhrase.failed, JobTone.error, JobIcon.warn, JobTone.error, [JobAction.retry]]);
      expect(failed.sub, [p(JobPhrase.failedCount, count: 1)]);
      // one song already here, one failed: still a failure — nothing landed
      final mixed = jobRowState(copyJob({'state': 'done', 'params': {'scope': 'album'}, 'result': many({'songs': songs(total: 2, skipped: 1, failed: 1)})}));
      expect(mixed.kind, JobRowKind.failed);
      // an artist job whose album listings failed copied nothing either
      final listings = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'artist'},
        'result': many({'scope': 'artist', 'albums': [{'name': 'A', 'error': 'peer said 500'}], 'skippedAlbums': [], 'songs': songs()}),
      }));
      expect([listings.kind, [for (final t in listings.sub!) t.phrase]], [JobRowKind.failed, [JobPhrase.albumsFailed]]);
      expect(jobRowState(copyJob({'state': 'done', 'params': {'scope': 'album'}, 'result': many({'songs': songs(total: 1, failed: 1)})})).live, isFalse);
    });

    test('the counts come from result.counts — the lists stop at 500 entries', () {
      final capped = List.generate(500, (_) => <String, dynamic>{});
      final big = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'artist'},
        'result': many({'scope': 'artist', 'songs': {'total': 1200, 'copied': capped, 'skipped': [], 'failed': capped}, 'counts': {'total': 1200, 'copied': 700, 'skipped': 0, 'failed': 500}, 'truncated': true}),
      }));
      expect([for (final t in big.sub!) [t.phrase, t.count]], [
        [JobPhrase.copiedCount, 700],
        [JobPhrase.failedCount, 500]
      ]);
      // counts says nothing was copied though a list (an old shape) is not empty: counts wins
      final zero = jobRowState(copyJob({'state': 'done', 'params': {'scope': 'album'}, 'result': many({'counts': {'total': 3, 'copied': 0, 'skipped': 3, 'failed': 0}})}));
      expect(zero.kind, JobRowKind.owned);
      // a result with counts alone (no lists) is still a many-song result
      final bare = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'album'},
        'result': {'scope': 'album', 'counts': {'total': 2, 'copied': 2, 'skipped': 0, 'failed': 0}, 'stopped': null, 'peer': {'id': 1, 'name': 'S'}},
      }));
      expect([bare.kind, bare.sub], [JobRowKind.copiedMany, [p(JobPhrase.copiedCount, count: 2)]]);
    });

    test('nothing at all: "nothing to copy" — an artist who only appears on the peer\'s albums says so; all their albums already here is "already yours"', () {
      final guest = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'artist'},
        'result': many({
          'scope': 'artist',
          'albums': [],
          'skippedAlbums': [{'name': 'Comp', 'why': 'appearance'}, {'name': 'Feat', 'why': 'appearance'}],
          'songs': songs(),
          'counts': {'total': 0, 'copied': 0, 'skipped': 0, 'failed': 0},
        }),
      }));
      expect([guest.kind, guest.tag, guest.tagTone, guest.muted, guest.actions],
          [JobRowKind.nothing, JobPhrase.nothing, JobTone.plain, true, [JobAction.start]]);
      expect(guest.sub, [p(JobPhrase.onlyAppearances, count: 2)]);
      final none = jobRowState(copyJob({'state': 'done', 'params': {'scope': 'artist-missing'}, 'result': many({'scope': 'artist-missing', 'albums': [], 'skippedAlbums': [], 'songs': songs()})}));
      expect([none.kind, none.tag, none.sub], [JobRowKind.nothing, JobPhrase.nothing, [p(JobPhrase.nothingToCopy)]]);
      final have = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'artist-missing'},
        'result': many({'scope': 'artist-missing', 'albums': [], 'skippedAlbums': [{'name': 'A', 'why': 'owned'}, {'name': 'B', 'why': 'owned'}], 'songs': songs()}),
      }));
      expect([have.kind, have.tag, [for (final t in have.sub!) t.phrase]], [JobRowKind.owned, JobPhrase.owned, [JobPhrase.albumsLeftOut]]);
    });

    test("stopped by the peer's limit or the peer going away: a warning with the counts and Retry; refused has no Retry; a cancel keeps its counts", () {
      final quota = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'album'},
        'result': many({'stopped': 'quota', 'songs': {'total': 4, 'copied': [{}], 'skipped': [], 'failed': [{'from': 'b', 'error': 'limit'}]}}),
      }));
      expect([quota.kind, quota.tag, quota.tagTone, quota.icon, quota.iconTone, quota.actions],
          [JobRowKind.stopped, JobPhrase.stopped, JobTone.error, JobIcon.warn, JobTone.error, [JobAction.retry]]);
      expect(quota.sub!.first, p(JobPhrase.stoppedQuota, peer: "Sam's server"));
      expect([for (final t in quota.sub!.skip(1)) t.phrase], [JobPhrase.copiedCount, JobPhrase.failedCount]);
      final peer = jobRowState(copyJob({'state': 'done', 'params': {'scope': 'album'}, 'result': many({'stopped': 'peer'})}));
      expect([peer.sub!.first.phrase, peer.actions], [JobPhrase.stoppedPeer, [JobAction.retry]]);
      final busy = jobRowState(copyJob({'state': 'done', 'params': {'scope': 'album'}, 'result': many({'stopped': 'busy', 'songs': songs(total: 3, copied: 3)})}));
      expect(busy.kind, JobRowKind.stopped, reason: 'stopped early wins over what landed: never "in your collection"');
      // A peer with copies off refuses again: Retry would meet the same refusal.
      final refused = jobRowState(copyJob({
        'state': 'done',
        'params': {'scope': 'album'},
        'result': many({'stopped': 'refused', 'songs': songs(total: 1, failed: 1), 'counts': {'total': 1, 'copied': 0, 'skipped': 0, 'failed': 1}}),
      }));
      expect([refused.kind, refused.tag, refused.sub!.first, refused.actions],
          [JobRowKind.stopped, JobPhrase.stopped, p(JobPhrase.stoppedRefused, peer: "Sam's server"), <JobAction>[]]);
      // A song the peer refuses ends done with `stopped: 'refused'` and no
      // counts (mStream since 2026-10-21): the same refusal, never "done".
      final song = jobRowState(copyJob({
        'state': 'done',
        'params': {'destination': null},
        'result': {'stopped': 'refused', 'peer': {'id': 2, 'name': "Sam's server"}, 'destination': null},
      }));
      expect([song.kind, song.tag, song.tagTone, song.sub, song.actions],
          [JobRowKind.stopped, JobPhrase.stopped, JobTone.error, [p(JobPhrase.stoppedRefused, peer: "Sam's server")], <JobAction>[]]);
      final cancelled = jobRowState(copyJob({'state': 'cancelled', 'params': {'scope': 'album'}, 'result': many({'stopped': 'cancelled', 'songs': songs(total: 4, copied: 1)})}));
      expect([cancelled.kind, cancelled.muted, cancelled.actions], [JobRowKind.cancelled, true, [JobAction.start]]);
      expect([for (final t in cancelled.sub!) t.phrase], [JobPhrase.cancelledMany, JobPhrase.copiedCount]);
      final early = jobRowState(copyJob({'state': 'cancelled', 'params': {'scope': 'album'}, 'result': many({'stopped': 'cancelled', 'songs': songs(total: 4)})}));
      expect(early.sub, [p(JobPhrase.cancelledMany)], reason: 'cancelled before anything landed: just "Stopped"');
      final plain = jobRowState(copyJob({'state': 'cancelled'}));
      expect(plain.sub, [p(JobPhrase.cancelledCopySub)], reason: 'a single copy reads as before');
    });

    test('the list names an album job by its album and an artist job by its artist, with the kind beside it', () {
      const rec = {'title': 'Departure', 'artist': 'Marlowe Vale', 'album': 'Night Ferry'};
      expect(jobTitle(job({'recommendation': rec})), 'Departure — Marlowe Vale');
      expect(jobTitle(job({'recommendation': rec, 'params': {'scope': 'album'}})), 'Night Ferry — Marlowe Vale');
      expect(jobTitle(job({'recommendation': rec, 'params': {'scope': 'artist'}})), 'Marlowe Vale');
      expect(jobTitle(job({'recommendation': rec, 'params': {'scope': 'artist-missing'}})), 'Marlowe Vale');
      expect([
        jobKind(job()),
        jobKind(job({'params': {'scope': 'album'}})),
        jobKind(job({'params': {'scope': 'artist'}})),
        jobKind(job({'params': {'scope': 'artist-missing'}})),
      ], [null, JobKind.album, JobKind.artist, JobKind.artistMissing]);
    });
  });
}
