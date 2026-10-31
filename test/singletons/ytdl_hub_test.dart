// YtdlHub and YtdlServerState against the scripted server in ytdl_fakes:
// the gates that hide the entry points (peer, uploads off, conversion off,
// no library, store builds), the version probe, and a job's whole life —
// the POST sent once and never again (a timeout looked for for two
// minutes, the tunnel waited for before the one send), claims by link and
// folder that never compare clocks, endings read from the download record
// (origin, folder, at most five pages, one job per record) or the folder
// (name clash), entries that vanish unseen, failures routed to the surface
// that shows them or to a row and a toast, re-pings and the format reset.
// Then persistence and resuming after a restart, polling only while a job
// is open and the app is in front, the home summary and markSeen, the
// lists, the remembered destination and format, and the account presets.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/build_variant.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/objects/ytdl_job.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/util/ytdl_api.dart';
import 'package:mstream_music/util/ytdl_errors.dart';
import 'package:mstream_music/util/ytdl_layout.dart';

import 'ytdl_fakes.dart';

const dir = '/Music/Daft Punk/Discovery/';
const beat = YtdlServerState.kPollBeat;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late YtdlHarness h;
  late Server s;
  YtdlServerState state() => h.hub.stateFor(s);

  setUp(() {
    h = YtdlHarness()..wire();
    s = ytdlServer();
    h.fake.folder(dir);
  });
  tearDown(() => h.unwire());

  /// Start the usual add and let its first poll claim the entry.
  Future<YtdlJob> started({YtdlStartRequest? request}) async {
    final out = await state().start(request ?? h.request());
    await ytdlSettle();
    return out.job!;
  }

  group('gates (spec §2, §7)', () {
    test('an own server with a library, uploads and conversion allowed', () {
      expect(YtdlHub.entryAllowed(s), isTrue);
      expect(YtdlHub.entryAllowed(ytdlServer(transcode: true, noUpload: false)), isTrue);
    });

    test('hidden: no server, a peer, uploads off, conversion off, no library', () {
      expect(YtdlHub.entryAllowed(null), isFalse);
      expect(YtdlHub.entryAllowed(ytdlPeerOf(s)), isFalse);
      expect(YtdlHub.entryAllowed(ytdlServer(noUpload: true)), isFalse);
      expect(YtdlHub.entryAllowed(ytdlServer(transcode: false)), isFalse);
      expect(YtdlHub.entryAllowed(ytdlServer(libraries: const [])), isFalse);
    });

    test('a store build hides it; YTDL_ENTRY set explicitly wins', () {
      YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
          defined: null, play: true, release: true, platform: TargetPlatform.android);
      expect(YtdlHub.entryAllowed(s), isFalse);
      YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
          defined: null, play: false, release: true, platform: TargetPlatform.iOS);
      expect(YtdlHub.entryAllowed(s), isFalse);
      YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
          defined: true, play: false, release: true, platform: TargetPlatform.iOS);
      expect(YtdlHub.entryAllowed(s), isTrue);
      YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
          defined: null, play: false, release: true, platform: TargetPlatform.android);
      expect(YtdlHub.entryAllowed(s), isTrue);
    });

    test('the explorer: a server folder below the root, not an m3u, not Local Files', () {
      expect(YtdlHub.explorerEntryAllowed(s, '/Music/Daft Punk/'), isTrue);
      expect(YtdlHub.explorerEntryAllowed(s, '/Music/'), isTrue);
      expect(YtdlHub.explorerEntryAllowed(s, '/'), isFalse);
      expect(YtdlHub.explorerEntryAllowed(s, null), isFalse);
      expect(YtdlHub.explorerEntryAllowed(s, 'Album/Sub'), isFalse);
      expect(YtdlHub.explorerEntryAllowed(s, ''), isFalse);
      expect(YtdlHub.explorerEntryAllowed(s, '/Music/mix.M3U'), isFalse);
      expect(YtdlHub.explorerEntryAllowed(ytdlPeerOf(s), '/Shared/'), isFalse);
      expect(YtdlHub.explorerEntryAllowed(ytdlServer(noUpload: true), '/Music/'), isFalse);
    });

    test('install points the home card at entryAllowed; reset takes it back', () {
      expect(BrowserManager.homeYtdlRow(s), isFalse);
      h.hub.install();
      expect(BrowserManager.homeYtdlRow(s), isTrue);
      expect(BrowserManager.homeYtdlRow(ytdlServer(noUpload: true)), isFalse);
      h.hub.reset();
      expect(BrowserManager.homeYtdlRow(s), isFalse);
      h.wire();
    });

    test('a peer shares its parent\'s state', () {
      expect(identical(h.hub.stateFor(ytdlPeerOf(s)), state()), isTrue);
    });
  });

  group('the version probe', () {
    test('200 → full, with the first ADDED page', () async {
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3', title: 'One More Time');
      await state().probeTier();
      expect(state().tier, YtdlServerTier.full);
      expect(state().added.single.title, 'One More Time');
    });

    test('Express\'s 404 → older; asked once per session', () async {
      h.fake.hasRecords = false;
      await state().probeTier();
      await state().probeTier();
      expect(state().tier, YtdlServerTier.older);
      expect(h.fake.count('GET', '/discovery/downloads'), 1);
    });

    test('anything else leaves it unknown, and the next ask probes again', () async {
      h.fake.recordsRefusal = (500, 'Server Error');
      await state().probeTier();
      expect(state().tier, YtdlServerTier.unknown);
      h.fake.recordsRefusal = null;
      await state().probeTier();
      expect(state().tier, YtdlServerTier.full);
      expect(h.fake.count('GET', '/discovery/downloads'), 2);
    });

    test('a 404 that carries the server\'s words is not an older server', () async {
      h.fake.recordsRefusal = (404, 'not available');
      await state().probeTier();
      expect(state().tier, YtdlServerTier.unknown);
    });

    test('ADDED reads as loading while the probe is out — set with no '
        'notification (it may start mid-build) — and clears with one, '
        'answered or not', () async {
      var told = 0;
      state().addListener(() => told++);
      h.fake.recordsGate = Completer<void>();
      final probe = state().probeTier();
      expect(state().addedLoading, isTrue);
      expect(told, 0);
      h.fake.recordsGate!.complete();
      await probe;
      expect(state().addedLoading, isFalse);
      expect(told, 1);

      h.unwire();
      h = YtdlHarness()..wire();
      s = ytdlServer();
      told = 0;
      state().addListener(() => told++);
      h.fake.recordsThrows = const SocketException('Network is unreachable');
      final failing = state().probeTier();
      expect(state().addedLoading, isTrue);
      await failing;
      expect(state().tier, YtdlServerTier.unknown);
      expect(state().addedLoading, isFalse);
      expect(told, 1);
    });
  });

  group('the add (spec §6)', () {
    test('a starting row at once; 200 → adding; the first poll claims the entry', () async {
      final st = state();
      h.fake.addGate = Completer<void>();
      final pending = st.start(h.request());
      expect(st.adding.single.state, YtdlJobState.starting);
      expect(h.persisted, isNotEmpty);
      h.fake.addGate!.complete();
      final out = await pending;
      expect(out.ok, isTrue);
      await ytdlSettle();
      final job = out.job!;
      expect(job.state, YtdlJobState.adding);
      expect(job.pid, h.fake.entryFor(kOneMoreTime)['pid']);
      expect(job.serverStart, h.fake.entryFor(kOneMoreTime)['startTime']);
      expect(h.fake.bodies('POST', '/api/v1/ytdl/').single, {
        'directory': dir,
        'url': kOneMoreTime,
        'outputCodec': 'mp3',
        'metadata': {
          'title': 'One More Time',
          'artist': 'Daft Punk',
          'album': 'Discovery',
          'year': '2001',
        },
      });
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 0);
    });

    test('blank tags are not sent; the metadata key goes when none is left', () async {
      await started(request: h.request(metadata: const {'title': ' ', 'artist': ''}));
      expect(h.fake.bodies('POST', '/api/v1/ytdl/').single.containsKey('metadata'), isFalse);
      expect(state().jobs.single.tags, isEmpty);
    });

    test('mkdir first, only when asked, with the target folder', () async {
      await started(request: h.request(directory: '/Music/Gorillaz/', mkdir: '/Music/Gorillaz/'));
      expect(h.fake.bodies('POST', '/file-explorer/mkdir').single, {'directory': '/Music/Gorillaz/'});
      expect(h.fake.exists('/Music/Gorillaz/'), isTrue);
      expect(h.fake.requests.map((r) => r.url.path).toList().indexOf('/api/v1/file-explorer/mkdir'),
          lessThan(h.fake.requests.map((r) => r.url.path).toList().indexOf('/api/v1/ytdl/')));
    });

    test('a mkdir failure is the mkdir\'s: nothing is POSTed, the folder is named', () async {
      h.fake.mkdirRefusal = (500, 'Server Error');
      final out = await state().start(h.request(mkdir: dir, inline: () => true));
      // Spec §8 "mkdir failed": "Couldn't make the folder “Discovery”." —
      // told apart from an add's own bare 500.
      expect(out.failure, const YtdlFailure(YtdlProblem.mkdirFailed, 'Discovery'));
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0);
    });

    test('mkdir failures: the first new folder named; a row keeps it; offline stays offline', () async {
      h.fake.mkdirThrows = TimeoutException('slow');
      final named = await state().start(YtdlStartRequest(
        url: kOneMoreTime,
        directory: dir,
        codec: 'mp3',
        title: 'One More Time',
        predictedName: 'One_More_Time.mp3',
        mkdir: dir,
        mkdirFolder: 'Daft Punk',
        inline: () => false,
      ));
      expect(named.failure, const YtdlFailure(YtdlProblem.mkdirFailed, 'Daft Punk'));
      expect(named.job!.state, YtdlJobState.startFailed);
      expect(named.job!.problem, 'mkdirFailed');
      expect(named.job!.problemDetail, 'Daft Punk');
      expect(named.job!.mkdir, dir);

      h.fake.mkdirThrows = const SocketException('Network is unreachable');
      final off = await state().start(h.request(url: kFeelGood, mkdir: dir, inline: () => true));
      expect(off.failure, const YtdlFailure(YtdlProblem.offline));

      // Try again on the row makes the folder again and names it the same.
      h.fake.mkdirThrows = null;
      h.fake.mkdirRefusal = (500, 'Server Error');
      final again = await state().retry(named.job!);
      expect(again.failure, const YtdlFailure(YtdlProblem.mkdirFailed, 'Daft Punk'));
    });

    test('mkdir 403 → mkdirOff, a re-ping, and the account treated as noMkdir', () async {
      h.fake.mkdirRefusal = (403, 'Create Folder Disabled');
      final out = await state().start(h.request(mkdir: dir, inline: () => true));
      await ytdlSettle();
      expect(out.failure?.problem, YtdlProblem.mkdirOff);
      expect(h.repings, [s]);
      expect(state().mkdirRefused, isTrue);
    });

    test('a timeout is never retried: startUnsure, then a claim within 2 min → adding', () async {
      h.fake.addThrows = TimeoutException('no answer');
      final out = await state().start(h.request());
      expect(out.ok, isFalse);
      expect(out.timedOut, isTrue);
      expect(out.failure, isNull);
      final job = out.job!;
      expect(job.state, YtdlJobState.startUnsure);
      expect(state().adding, [job]);
      // The POST reached the server; its answer did not reach the phone.
      h.fake.addEntry(url: kOneMoreTime, directory: dir);
      await h.timers.elapse(const Duration(minutes: 1));
      expect(job.state, YtdlJobState.adding);
      expect(job.pid, h.fake.entryFor(kOneMoreTime)['pid']);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
    });

    test('a timeout with no match for 2 min → notSureStarted (no toast)', () async {
      h.fake.addThrows = TimeoutException('no answer');
      final job = (await state().start(h.request())).job!;
      final settled = <YtdlJob>[];
      final sub = state().settled.listen(settled.add);
      await h.timers.elapse(const Duration(seconds: 117));
      expect(job.state, YtdlJobState.startUnsure);
      await h.timers.elapse(const Duration(seconds: 6));
      expect(job.state, YtdlJobState.notSureStarted);
      expect(state().needsLook, [job]);
      expect(settled, [job]);
      expect(h.toasts, isEmpty);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
      expect(h.timers.hasActive(beat), isFalse);
      await sub.cancel();
    });

    test('a connection lost mid-flight is unsure too; one that never opened is offline', () async {
      h.fake.addThrows = http.ClientException('Connection closed before full header was received');
      final unsure = await state().start(h.request());
      expect(unsure.timedOut, isTrue);
      expect(unsure.job!.state, YtdlJobState.startUnsure);

      h.fake.addThrows = const SocketException('Failed host lookup: music.example');
      final off = await state().start(h.request(url: kFeelGood, inline: () => true));
      expect(off.timedOut, isFalse);
      expect(off.failure, const YtdlFailure(YtdlProblem.offline));
      expect(state().jobs.where((j) => j.url == kFeelGood), isEmpty);
    });

    test('over a tunnel that is not up: a wait before the one send', () async {
      s = ytdlIrohServer(tunnelUp: false);
      h.tunnelReady = false;
      final out = await state().start(h.request(directory: '/Music/'));
      expect(h.tunnelWaits, 1);
      expect(out.timedOut, isFalse);
      expect(out.failure, const YtdlFailure(YtdlProblem.offline));
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0);
      expect(out.job!.state, YtdlJobState.startFailed);
      expect(out.job!.problem, 'offline');

      h.tunnelReady = true;
      final ok = await state().start(h.request(directory: '/Music/', url: kFeelGood));
      expect(ok.ok, isTrue);
      expect(h.tunnelWaits, 2);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
    });

    test('no tunnel wait for a plain server', () async {
      await started();
      expect(h.tunnelWaits, 0);
    });
  });

  group('failure routing', () {
    test('the surface still showing: the row is dropped, no toast', () async {
      h.fake.addRefusal = (500, 'Server Error');
      final out = await state().start(h.request(inline: () => true));
      expect(out.failure, const YtdlFailure(YtdlProblem.serverError));
      expect(state().jobs, isEmpty);
      expect(h.toasts, isEmpty);
    });

    test('the surface gone: a startFailed row with the reason, and a toast', () async {
      h.fake.addRefusal = (400, 'Not A Directory');
      final settled = <YtdlJob>[];
      final sub = state().settled.listen(settled.add);
      final out = await state().start(h.request(inline: () => false));
      await ytdlSettle();
      final job = out.job!;
      expect(job.state, YtdlJobState.startFailed);
      expect(job.problem, 'other');
      expect(job.problemDetail, 'Not A Directory');
      expect(state().needsLook, [job]);
      expect(h.toastTexts, ['Couldn\'t add “One More Time”']);
      expect(h.toasts.single.success, isFalse);
      expect(settled, [job]);
      await sub.cancel();
    });

    test('discardStartFailure drops a row', () async {
      h.fake.addRefusal = (500, 'Server Error');
      final job = (await state().start(h.request())).job!;
      state().discardStartFailure(job);
      expect(state().jobs, isEmpty);
    });

    test('403 and "FFmpeg is not available yet" re-ping the server', () async {
      h.fake.addRefusal = (403, 'Uploading Disabled');
      final a = await state().start(h.request(inline: () => true));
      expect(a.failure?.problem, YtdlProblem.uploadsOff);
      h.fake.addRefusal = (500, 'FFmpeg is not available yet');
      final b = await state().start(h.request(inline: () => true));
      await ytdlSettle();
      expect(b.failure?.problem, YtdlProblem.ffmpegNotReady);
      expect(h.repings, [s, s]);
    });

    test('a 400 on outputCodec resets the remembered format', () async {
      s.ytdlFormat = 'opus';
      s.supportedAudioFormats = ['mp3', 'opus'];
      expect(state().format, 'opus');
      h.fake.addRefusal = (400, '"outputCodec" must be one of [mp3]');
      final out = await state().start(h.request(codec: 'opus', inline: () => true));
      await ytdlSettle();
      expect(out.failure?.problem, YtdlProblem.badFormat);
      expect(s.ytdlFormat, isNull);
      expect(state().format, 'mp3');
      expect(h.repings, [s]);
    });

    test('a lost library the server did not name is named from the folder', () async {
      h.fake.addRefusal = (404, 'Something about a path');
      final out = await state().start(h.request(inline: () => false));
      expect(out.failure, const YtdlFailure(YtdlProblem.libraryGone, 'Music'));
      expect(out.job!.problemDetail, 'Music');
      h.fake.addRefusal = (404, "Library 'Podcasts' not found");
      final named = await state().start(h.request(inline: () => true));
      expect(named.failure, const YtdlFailure(YtdlProblem.libraryGone, 'Podcasts'));
    });
  });

  group('claims', () {
    test('the newest unclaimed entry with the same link and folder', () async {
      final other = h.fake.addEntry(url: kOneMoreTime, directory: dir);
      final job = await started();
      expect(job.pid, isNot(other['pid']));
      expect(job.pid, h.fake.tracker.last['pid']);
    });

    test('entries for another folder or link are ignored', () async {
      h.fake.addStartsEntry = false;
      final job = await started();
      h.fake.addEntry(url: kOneMoreTime, directory: '/Music/Elsewhere/');
      h.fake.addEntry(url: kFeelGood, directory: dir);
      await h.timers.elapse(beat);
      expect(job.pid, isNull);
      expect(job.state, YtdlJobState.adding);
    });

    test('two adds of the same link to the same folder follow distinct pids', () async {
      final a = await started();
      final b = await started();
      expect(a.pid, isNotNull);
      expect(b.pid, isNotNull);
      expect(a.pid, isNot(b.pid));
      expect(b.pid, h.fake.tracker.last['pid']);
    });

    test('a pid a settled or dismissed job held is never claimed again', () async {
      final a = await started();
      h.fake.finish(a.pid!);
      await h.timers.elapse(beat);
      expect(a.state, YtdlJobState.added);
      // The finished entry stays listed for 30 s; a new add whose entry has
      // not shown yet must not take it.
      h.fake.addStartsEntry = false;
      final b = await started();
      await h.timers.elapse(beat);
      expect(b.pid, isNull);
      state().dismiss(a);
      await h.timers.elapse(beat);
      expect(b.pid, isNull);
    });
  });

  group('endings', () {
    test('complete → added from the record: origin and folder match', () async {
      final job = await started();
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      final record = h.fake.records.first;
      expect(job.state, YtdlJobState.added);
      expect(job.filepath, 'Music/Daft Punk/Discovery/One_More_Time.mp3');
      expect(job.recordId, record['id']);
      expect(job.bytes, record['bytes']);
      expect(job.trackId, record['trackId']);
      expect(job.endedAt, h.clock.current);
      expect(h.toasts.single.message,
          'Added “One More Time” to \u2068Daft Punk\u2069 › \u2068Discovery\u2069');
      expect(h.toasts.single.success, isTrue);
    });

    test('the record\'s folder compares without slashes, ignoring case', () async {
      final job = await started();
      h.fake.finish(job.pid!, record: false);
      h.fake.addRecord(relativePath: 'daft punk/DISCOVERY/One_More_Time.mp3', origin: kOneMoreTime);
      h.fake.addRecord(relativePath: 'Elsewhere/One_More_Time.mp3', origin: kOneMoreTime);
      await h.timers.elapse(beat);
      expect(job.filepath, 'Music/daft punk/DISCOVERY/One_More_Time.mp3');
    });

    test('pages back at most five times', () async {
      await state().probeTier();
      final job = await started();
      h.fake.finish(job.pid!, record: false);
      final mine = h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      for (var i = 0; i < 80; i++) {
        h.fake.addRecord(relativePath: 'Other/$i.mp3', origin: kFeelGood);
      }
      final before = h.fake.count('GET', '/discovery/downloads');
      await h.timers.elapse(beat);
      expect(job.recordId, mine['id'], reason: 'the fifth page');
      // One page more and it is past the limit: still added, unnamed.
      final again = await started();
      h.fake.finish(again.pid!, record: false);
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      for (var i = 0; i < 100; i++) {
        h.fake.addRecord(relativePath: 'More/$i.mp3', origin: kFeelGood);
      }
      final mid = h.fake.count('GET', '/discovery/downloads');
      await h.timers.elapse(beat);
      expect(again.state, YtdlJobState.added);
      expect(again.recordId, isNull);
      // No record to name it: the folder's listing does.
      expect(again.filepath, 'Music/Daft Punk/Discovery/One_More_Time.mp3');
      final after = h.fake.count('GET', '/discovery/downloads');
      // Each settle reads ADDED again once after it; the second add read
      // the record's newest id once before its POST.
      expect(mid - before, 5 + 1 + 1);
      expect(after - mid, 5 + 1);
    });

    test('stops at a row older than the claimed entry\'s start', () async {
      await state().probeTier();
      h.fake.addRecord(
          relativePath: 'Old/old.mp3', origin: kFeelGood, downloadedAt: h.fake.serverNow - 50000);
      final job = await started();
      h.fake.finish(job.pid!, record: false);
      final before = h.fake.count('GET', '/discovery/downloads');
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(job.recordId, isNull);
      expect(h.fake.count('GET', '/discovery/downloads') - before, 1 + 1);
    });

    test('a record answers for one job only', () async {
      final a = await started();
      final b = await started();
      h.fake.finish(a.pid!);
      h.fake.finish(b.pid!, fileName: 'One_More_Time_2.mp3');
      await h.timers.elapse(beat);
      expect(a.state, YtdlJobState.added);
      expect(b.state, YtdlJobState.added);
      expect(a.recordId, isNotNull);
      expect(b.recordId, isNotNull);
      expect(a.recordId, isNot(b.recordId));
    });

    test('complete with no record → still added, named by the folder\'s listing', () async {
      final job = await started();
      h.fake.finish(job.pid!, record: false, fileName: 'one_more_time.MP3');
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(job.recordId, isNull);
      expect(job.filepath, 'Music/Daft Punk/Discovery/one_more_time.MP3', reason: 'as listed');
      expect(state().added.single.filepath, 'Music/Daft Punk/Discovery/one_more_time.MP3');
    });

    test('a file the folder does not show is never offered as certain', () async {
      h.fake.hasRecords = false;
      final job = await started();
      // yt-dlp named it otherwise than predicted.
      h.fake.finish(job.pid!, fileName: 'Real_Name.mp3');
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      final row = state().added.single;
      expect(row.filepath, isNull, reason: 'no tap-to-play on a guess');
      expect(row.ext, 'mp3');
      expect(row.directory, dir);
    });

    test('an older server: complete → added, the record never asked again', () async {
      h.fake.hasRecords = false;
      final job = await started();
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(h.fake.count('GET', '/discovery/downloads'), 1, reason: 'the probe');
      expect(state().added.single.title, 'One More Time');
    });

    test('error with the predicted name in the folder → failedClash (6.30+)', () async {
      final job = await started();
      h.fake.file(dir, 'one_more_time.MP3');
      h.fake.fail(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.failedClash);
      expect(h.toastTexts, ['Couldn\'t add “One More Time”']);
    });

    test('error without it → failed; an older server never reads a clash', () async {
      final job = await started();
      h.fake.fail(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.failed);

      h.unwire();
      h = YtdlHarness()..wire();
      s = ytdlServer();
      h.fake
        ..hasRecords = false
        ..folder(dir, files: ['One_More_Time.mp3']);
      final old = await started();
      h.fake.fail(old.pid!);
      await h.timers.elapse(beat);
      expect(old.state, YtdlJobState.failed);
    });

    test('a claimed pid gone unseen: the record → added, none → notSureFinished', () async {
      final a = await started();
      final b = await started(request: h.request(url: kFeelGood, title: 'Feel Good Inc.'));
      h.fake.forget(a.pid!);
      h.fake.forget(b.pid!);
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      await h.timers.elapse(beat);
      expect(a.state, YtdlJobState.added);
      expect(a.recordId, isNotNull);
      expect(b.state, YtdlJobState.notSureFinished);
      expect(h.toastTexts, ['Added “One More Time” to \u2068Daft Punk\u2069 › \u2068Discovery\u2069']);
    });

    test('an older server reads the folder for a vanished pid', () async {
      h.fake.hasRecords = false;
      final a = await started();
      final b = await started(request: h.request(url: kFeelGood, predictedName: 'Feel.mp3'));
      h.fake
        ..file(dir, 'One_More_Time.mp3')
        ..forget(a.pid!)
        ..forget(b.pid!);
      await h.timers.elapse(beat);
      expect(a.state, YtdlJobState.added);
      expect(b.state, YtdlJobState.notSureFinished);
    });

    test('a vanished job whose folder will not list waits for the next poll', () async {
      h.fake.hasRecords = false;
      final job = await started();
      h.fake
        ..forget(job.pid!)
        ..listFails.add(dir);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.adding);
      h.fake.listFails.clear();
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.notSureFinished);
    });

    test('taken (200) but never listed for 2 min: read as vanished', () async {
      h.fake.addStartsEntry = false;
      final job = await started();
      await h.timers.elapse(const Duration(seconds: 90));
      expect(job.state, YtdlJobState.adding);
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      await h.timers.elapse(const Duration(seconds: 33));
      expect(job.state, YtdlJobState.added);
    });

    test('a status this build does not know keeps the job adding', () async {
      final job = await started();
      h.fake.entry(job.pid!)['status'] = 'paused';
      await h.timers.elapse(beat * 3);
      expect(job.state, YtdlJobState.adding);
    });
  });

  group('Check again and Add again', () {
    Future<YtdlJob> notSure() async {
      h.fake.addThrows = TimeoutException('no answer');
      final job = (await state().start(h.request())).job!;
      h.fake.addThrows = null;
      await h.timers.elapse(const Duration(minutes: 2, seconds: 3));
      expect(job.state, YtdlJobState.notSureStarted);
      return job;
    }

    test('found in the job list → adding, and followed', () async {
      final job = await notSure();
      h.fake.addEntry(url: kOneMoreTime, directory: dir);
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.adding);
      expect(job.pid, h.fake.tracker.last['pid']);
      expect(h.timers.hasActive(beat), isTrue);
    });

    test('found in the record → added', () async {
      final job = await notSure();
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.added);
    });

    test('the predicted name in the folder → added', () async {
      final job = await notSure();
      h.fake.file(dir, 'One_More_Time.mp3');
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.added);
    });

    test('nothing → notFound; Add again POSTs exactly once more', () async {
      final job = await notSure();
      final pending = state().checkAgain(job);
      expect(state().busy(job), isTrue);
      await pending;
      expect(state().busy(job), isFalse);
      expect(job.state, YtdlJobState.notFound);
      expect(state().needsLook, [job]);
      final out = await state().addAgain(job);
      await ytdlSettle();
      expect(out.ok, isTrue);
      expect(job.state, YtdlJobState.adding);
      expect(job.pid, isNotNull);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 2);
      expect(state().jobs, [job], reason: 'the same row');
    });

    test('a job list that fails leaves the row as it was', () async {
      final job = await notSure();
      h.fake.jobsThrows = const SocketException('Network is unreachable');
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.notSureStarted);
    });

    test('a record or folder that could not be read offers no Add again', () async {
      final job = await notSure();
      h.fake
        ..recordsRefusal = (500, 'Server Error')
        ..listFails.add(dir);
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.notSureStarted);
      expect(state().busy(job), isFalse);
      // The record unread, the folder listed without the song.
      h.fake.listFails.clear();
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.notSureStarted);
      // The record read (nothing), the folder unread.
      h.fake
        ..recordsRefusal = null
        ..listFails.add(dir);
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.notSureStarted);
      // Every source answered: now it is not found.
      h.fake.listFails.clear();
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.notFound);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
    });

    test('a row dismissed while Check again reads the record is not settled', () async {
      final job = await notSure();
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      final settled = <YtdlJob>[];
      final sub = state().settled.listen(settled.add);
      h.fake.recordsGate = Completer<void>();
      final pending = state().checkAgain(job);
      await ytdlSettle();
      state().dismiss(job);
      h.fake.recordsGate!.complete();
      await pending;
      expect(state().jobs, isEmpty);
      expect(job.state, YtdlJobState.notSureStarted);
      expect(h.toasts, isEmpty);
      expect(settled, isEmpty);
      await sub.cancel();
    });

    test('an earlier add\'s record (at or below the floor) is not this add', () async {
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3'); // 100
      final job = await notSure();
      expect(job.recordFloor, 100);
      expect(job.serverStart, isNull, reason: 'it never claimed an entry');
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.notFound);
      expect(job.recordId, isNull);
      // Its own record, written after the POST, answers.
      final own = h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      await state().checkAgain(job);
      expect(job.state, YtdlJobState.added);
      expect(job.recordId, own['id']);
    });
  });

  group('rows: hide, dismiss, retry', () {
    test('hide: off the list, still followed to its end', () async {
      final job = await started();
      state().hide(job);
      expect(state().adding, isEmpty);
      expect(state().summary.adding, 0);
      expect(h.timers.hasActive(beat), isTrue);
      expect(state().isAdding(kOneMoreTime, dir), isTrue);
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
    });

    test('dismiss: a settled row goes (and is persisted)', () async {
      h.fake.addRefusal = (500, 'Server Error');
      final job = (await state().start(h.request())).job!;
      h.persisted.clear();
      state().dismiss(job);
      expect(state().jobs, isEmpty);
      expect(s.ytdlJobs, isEmpty);
      expect(h.persisted, [s]);
    });

    test('Change format and retry: a new add in the new format in place of the row', () async {
      final job = await started();
      h.fake
        ..file(dir, 'One_More_Time.mp3')
        ..fail(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.failedClash);
      final out = await state().retry(job, codec: 'opus');
      await ytdlSettle();
      final next = out.job!;
      expect(state().jobs, [next]);
      expect(next.codec, 'opus');
      expect(next.predictedName, 'One_More_Time.opus');
      expect(next.state, YtdlJobState.adding);
      expect(h.fake.bodies('POST', '/api/v1/ytdl/').last['outputCodec'], 'opus');
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 0);
    });

    test('Try again on a start failure makes the folder again first', () async {
      h.fake.mkdirRefusal = (500, 'Server Error');
      final job = (await state().start(h.request(directory: '/Music/New/', mkdir: '/Music/New/'))).job!;
      expect(job.state, YtdlJobState.startFailed);
      h.fake.mkdirRefusal = null;
      final out = await state().retry(job);
      expect(out.ok, isTrue);
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 2);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
    });

    test('… but never for an account that may not make folders', () async {
      s.noMkdir = true;
      h.fake.addRefusal = (500, 'Server Error');
      final job = (await state().start(h.request())).job!;
      h.fake.addRefusal = null;
      await state().retry(job);
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 0);
    });
  });

  group('persistence and restarts', () {
    test('every change is written to the server\'s jobs', () async {
      final job = await started();
      final saved = s.ytdlJobs.single;
      expect(saved['id'], job.id);
      expect(saved['state'], 'adding');
      expect(saved['pid'], job.pid);
      expect(h.persisted, everyElement(same(s)));
    });

    test('a restart reloads the rows, and an open job resumes polling', () async {
      final job = await started();
      final pid = job.pid!;
      h.hub.reset();
      h.wire();
      final again = state();
      expect(again.jobs.single.id, job.id);
      expect(again.jobs.single.pid, pid);
      await ytdlSettle();
      expect(h.timers.hasActive(beat), isTrue);
      h.fake.finish(pid);
      await h.timers.elapse(beat);
      expect(again.jobs.single.state, YtdlJobState.added);
    });

    test('after a restart a pid gone is read as vanished', () async {
      final job = await started();
      h.hub.reset();
      h.fake.forget(job.pid!);
      h.wire();
      state();
      await ytdlSettle();
      expect(state().jobs.single.state, YtdlJobState.notSureFinished);
    });

    test('a job that was mid-POST is looked for as a timed-out one', () async {
      s.ytdlJobs = [
        {
          'id': 'j-1',
          'url': kOneMoreTime,
          'directory': dir,
          'codec': 'mp3',
          'title': 'One More Time',
          'predictedName': 'One_More_Time.mp3',
          'createdAt': h.clock.current.millisecondsSinceEpoch,
          'state': 'starting',
        }
      ];
      h.fake.addEntry(url: kOneMoreTime, directory: dir);
      final job = state().jobs.single;
      expect(job.state, YtdlJobState.startUnsure);
      await ytdlSettle();
      expect(job.state, YtdlJobState.adding);
      expect(job.pid, isNotNull);
    });

    test('loads drop failures older than 7 days and keep at most 20', () {
      final now = h.clock.current;
      Map<String, dynamic> row(String id, String st, Duration ago) => {
            'id': id,
            'url': kOneMoreTime,
            'directory': dir,
            'state': st,
            'createdAt': now.subtract(ago).millisecondsSinceEpoch,
            'endedAt': now.subtract(ago).millisecondsSinceEpoch,
          };
      s.ytdlJobs = [
        row('old-fail', 'failed', const Duration(days: 8)),
        row('fresh-fail', 'failed', const Duration(minutes: 30)),
        row('week-fail', 'failed', const Duration(days: 6)),
        for (var i = 0; i < 25; i++) row('added-$i', 'added', Duration(hours: i)),
      ];
      final ids = state().jobs.map((j) => j.id).toList();
      expect(ids, isNot(contains('old-fail')));
      expect(ids, contains('fresh-fail'));
      expect(ids.length, YtdlServerState.kKeepJobs);
      expect(ids, contains('added-0'));
      // The oldest settled rows go first.
      expect(ids, isNot(contains('week-fail')));
      expect(ids, isNot(contains('added-24')));
    });
  });

  group('polling', () {
    test('only while a job is open', () async {
      expect(h.timers.hasActive(beat), isFalse);
      final job = await started();
      expect(h.timers.hasActive(beat), isTrue);
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(h.timers.hasActive(beat), isFalse);
      final polls = h.fake.count('GET', '/ytdl/downloads');
      await h.timers.elapse(const Duration(seconds: 30));
      expect(h.fake.count('GET', '/ytdl/downloads'), polls);
    });

    test('paused in the background; one poll on resume', () async {
      await started();
      h.hub.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(h.timers.hasActive(beat), isFalse);
      final polls = h.fake.count('GET', '/ytdl/downloads');
      await h.timers.elapse(const Duration(seconds: 30));
      expect(h.fake.count('GET', '/ytdl/downloads'), polls);
      h.hub.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await ytdlSettle();
      expect(h.fake.count('GET', '/ytdl/downloads'), polls);
      h.hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await ytdlSettle();
      expect(h.fake.count('GET', '/ytdl/downloads'), polls + 1);
      expect(h.timers.hasActive(beat), isTrue);
    });

    test('a start while in the background polls once it is back', () async {
      h.hub.didChangeAppLifecycleState(AppLifecycleState.hidden);
      final job = (await state().start(h.request())).job!;
      await ytdlSettle();
      expect(h.timers.hasActive(beat), isFalse);
      h.hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await ytdlSettle();
      expect(job.pid, isNotNull);
    });

    test('a poll with no answer marks the rows offline until one answers', () async {
      await started();
      h.fake.jobsThrows = const SocketException('Network is unreachable');
      await h.timers.elapse(beat);
      expect(state().offline, isTrue);
      expect(h.timers.hasActive(beat), isTrue);
      h.fake.jobsThrows = null;
      await h.timers.elapse(beat);
      expect(state().offline, isFalse);
    });
  });

  group('summary, markSeen and the strip', () {
    test('Adding n, then n failed until seen, then Added n for an hour', () async {
      final job = await started();
      expect(state().summary, const YtdlHomeSummary(adding: 1));
      h.fake.addRefusal = (500, 'Server Error');
      await state().start(h.request(url: kFeelGood));
      expect(state().summary, const YtdlHomeSummary(adding: 1, failed: 1));
      state().markSeen();
      expect(state().summary, const YtdlHomeSummary(adding: 1));
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(state().summary, const YtdlHomeSummary(added: 1));
      h.clock.advance(const Duration(minutes: 61));
      expect(state().summary.isEmpty, isTrue);
    });

    test('"failed" counts failures only: a not-sure row is a guess', () async {
      h.fake.addThrows = TimeoutException('no answer');
      final job = (await state().start(h.request())).job!;
      await h.timers.elapse(YtdlServerState.kClaimWindow + beat);
      expect(job.state, YtdlJobState.notSureStarted);
      expect(state().needsLook, [job]);
      expect(state().summary.isEmpty, isTrue);
      h.fake.addThrows = null;
      h.fake.addRefusal = (500, 'Server Error');
      await state().start(h.request(url: kFeelGood));
      expect(state().summary, const YtdlHomeSummary(failed: 1));
    });

    test('addedNewsEnds: when the first counted song\'s hour runs out', () async {
      expect(state().addedNewsEnds, isNull);
      final a = await started();
      h.clock.advance(const Duration(minutes: 10));
      final b = await started(request: h.request(url: kFeelGood));
      h.fake.finish(a.pid!);
      await h.timers.elapse(beat);
      final aEnded = a.endedAt!;
      h.clock.advance(const Duration(minutes: 5));
      h.fake.finish(b.pid!);
      await h.timers.elapse(beat);
      expect(state().summary.added, 2);
      expect(state().addedNewsEnds, aEnded.add(YtdlServerState.kAddedNews));
      h.clock.advance(const Duration(minutes: 56));
      expect(state().summary.added, 1);
      expect(state().addedNewsEnds, b.endedAt!.add(YtdlServerState.kAddedNews));
      state().markSeen();
      expect(state().addedNewsEnds, isNull);
    });

    test('what settles while the screen shows is seen at once', () async {
      state().screenDraft.attach();
      final job = await started();
      h.fake.fail(job.pid!);
      await h.timers.elapse(beat);
      expect(job.seen, isTrue);
      expect(state().summary.isEmpty, isTrue);
    });

    test('markSeen is persisted', () async {
      h.fake.addRefusal = (500, 'Server Error');
      await state().start(h.request());
      h.persisted.clear();
      state().markSeen();
      expect(s.ytdlJobs.single['seen'], isTrue);
      expect(h.persisted, [s]);
    });

    test('jobsUnder: open and unseen failed jobs in the folder or below', () async {
      final job = await started();
      expect(state().jobsUnder('/Music/Daft Punk/'), [job]);
      expect(state().jobsUnder('/Music/Daft Punk/Discovery/'), [job]);
      expect(state().jobsUnder('/music/daft punk'), [job]);
      expect(state().jobsUnder('/Music/Other/'), isEmpty);
      h.fake.fail(job.pid!);
      await h.timers.elapse(beat);
      expect(state().jobsUnder('/Music/'), [job]);
      state().markSeen();
      expect(state().jobsUnder('/Music/'), isEmpty);
    });
  });

  group('lists', () {
    test('needsLook: the failure states, newest first, for 7 days', () async {
      h.fake.addRefusal = (500, 'Server Error');
      final a = (await state().start(h.request())).job!;
      h.clock.advance(const Duration(minutes: 1));
      final b = (await state().start(h.request(url: kFeelGood))).job!;
      expect(state().needsLook, [b, a]);
      h.clock.advance(const Duration(days: 8));
      expect(state().needsLook, isEmpty);
    });

    test('ADDED on 6.30+: the record\'s rows, with the file as the record names it', () async {
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3', title: 'One More Time');
      h.fake.addRecord(plugin: 'federation-copy', relativePath: 'x/y.flac');
      h.fake.addRecord(relativePath: 'Gone.opus', present: false, title: null);
      await state().probeTier();
      final rows = state().added;
      expect(rows.map((r) => r.title), ['Gone', 'One More Time']);
      expect(rows.first.present, isFalse);
      expect(rows.first.directory, '/Music/');
      expect(rows.first.ext, 'opus');
      expect(rows.last.directory, '/Music/Daft Punk/Discovery/');
      expect(rows.last.filepath, 'Music/Daft Punk/Discovery/One_More_Time.mp3');
      expect(rows.last.bytes, 8400000);
      expect(rows.last.recordId, isNotNull);
    });

    test('Show earlier pages before the smallest id; a short page ends it, '
        'its rows kept', () async {
      for (var i = 0; i < 25; i++) {
        h.fake.addRecord(relativePath: 'A/$i.mp3');
      }
      await state().probeTier();
      expect(state().added.length, 20);
      expect(state().canShowEarlier, isTrue);
      await state().showEarlier();
      expect(state().added.length, 25);
      expect(state().canShowEarlier, isFalse);
      final asked = h.fake.calls('GET', '/discovery/downloads').map((r) => r.url.queryParameters['before']);
      expect(asked, [null, '105']);
    });

    test('Show earlier on a page exactly as long as asked: the next, empty '
        'page ends it', () async {
      for (var i = 0; i < 40; i++) {
        h.fake.addRecord(relativePath: 'A/$i.mp3');
      }
      await state().probeTier();
      await state().showEarlier();
      expect(state().added.length, 40);
      expect(state().canShowEarlier, isTrue);
      await state().showEarlier();
      expect(state().added.length, 40);
      expect(state().canShowEarlier, isFalse);
    });

    test('the whole record on the first page: its rows, and no Show earlier',
        () async {
      for (var i = 0; i < 3; i++) {
        h.fake.addRecord(relativePath: 'A/$i.mp3');
      }
      await state().probeTier();
      expect(state().tier, YtdlServerTier.full);
      expect(state().added, hasLength(3));
      expect(state().canShowEarlier, isFalse);
      expect(h.fake.count('GET', '/discovery/downloads'), 1);
      await state().refreshAdded();
      expect(state().added, hasLength(3));
      expect(state().canShowEarlier, isFalse);
    });

    test('refreshAdded reads the first page again; older servers ask nothing', () async {
      await state().probeTier();
      h.fake.addRecord(relativePath: 'New.mp3');
      await state().refreshAdded();
      expect(state().added.single.title, 'New');
      expect(state().addedLoading, isFalse);

      h.unwire();
      h = YtdlHarness()..wire();
      s = ytdlServer();
      h.fake.hasRecords = false;
      await state().probeTier();
      await state().refreshAdded();
      expect(h.fake.count('GET', '/discovery/downloads'), 1);
    });

    test('onScreenOpened: seen, the tier, the presets, one poll', () async {
      final job = await started();
      h.fake.addRefusal = (500, 'Server Error');
      await state().start(h.request(url: kFeelGood));
      final polls = h.fake.count('GET', '/ytdl/downloads');
      await state().onScreenOpened();
      expect(state().summary.failed, 0);
      expect(state().tier, YtdlServerTier.full);
      expect(state().presetsLoaded, isTrue);
      expect(h.fake.count('GET', '/ytdl/downloads'), polls + 1);
      expect(job.state, YtdlJobState.adding);
    });
  });

  group('destination and format memory (spec §4, §5)', () {
    test('first use: the first library, Artist / Album', () {
      s = ytdlServer(libraries: const ['Music', 'Podcasts']);
      expect(state().library, 'Music');
      expect(state().layout, kYtdlLayoutArtistAlbum);
      expect(state().layoutKind, 'artistAlbum');
      expect(state().rememberedChoice,
          const YtdlChoice(library: 'Music', layout: kYtdlLayoutArtistAlbum, kind: 'artistAlbum'));
    });

    test('first use follows Discover\'s library when it is the user\'s own', () async {
      s = ytdlServer(libraries: const ['Music', 'Podcasts'])..discoveryPluginsAvailable = true;
      h.fake.discoverAt('Podcasts');
      await state().loadPresets();
      expect(state().library, 'Podcasts');
      expect(state().layout, kYtdlLayoutArtistAlbum, reason: 'never inherited');
    });

    test('a library default (source default) is no first-use library', () async {
      s = ytdlServer(libraries: const ['Music', 'Podcasts'])..discoveryPluginsAvailable = true;
      h.fake.discoverAt('Podcasts', source: 'default');
      await state().loadPresets();
      expect(state().library, 'Music');
      expect(state().discoverDestination, isNull);
    });

    test('remembered wins while the account has the library', () async {
      s = ytdlServer(libraries: const ['Music', 'Podcasts']);
      await state().rememberDestination(library: 'Podcasts', layout: '', kind: 'top');
      expect(state().library, 'Podcasts');
      expect(state().layout, '');
      expect(state().layoutKind, 'top');
      expect([s.ytdlLibrary, s.ytdlLayout, s.ytdlLayoutKind], ['Podcasts', '', 'top']);
      expect(h.persisted, [s]);
      s.autoDJPaths = {'Music': true};
      expect(state().library, 'Music');
    });

    test('"Same as Discover" keeps a folded copy and follows Discover once known', () async {
      s.discoveryPluginsAvailable = true;
      await state().rememberDestination(
          library: 'Music', layout: '{{ALBUMARTIST}}', kind: 'discover', base: 'From Discover');
      expect(s.ytdlLayout, 'From Discover/{{ALBUMARTIST}}');
      expect(state().rememberedChoice.layout, 'From Discover/{{ALBUMARTIST}}');
      expect(state().layoutKind, 'discover');
      h.fake.discoverAt('Music', base: 'Copies', layout: '{{ARTIST}}/{{ALBUM}}');
      await state().loadPresets();
      final c = state().rememberedChoice;
      expect([c.library, c.base, c.layout, c.kind], ['Music', 'Copies', '{{ARTIST}}/{{ALBUM}}', 'discover']);
    });

    test('"Same as Discover" with Discover gone reads as custom', () async {
      s.discoveryPluginsAvailable = true;
      await state().rememberDestination(library: 'Music', layout: '{{ALBUM}}', kind: 'discover');
      h.fake.discoverAt('Music', source: 'default');
      await state().loadPresets();
      expect(state().layoutKind, 'custom');
      expect(state().rememberedChoice.layout, '{{ALBUM}}');
    });

    test('"Library layout" follows the library\'s template', () async {
      h.fake.pathTemplates = {
        'vpaths': {
          'Music': {'template': '{{artist}}/{{year}}'}
        }
      };
      await state().rememberDestination(library: 'Music', layout: '{{ALBUM}}', kind: 'library');
      await state().loadPresets();
      expect(state().libraryTemplates, {'Music': '{{artist}}/{{year}}'});
      expect(state().rememberedChoice.layout, '{{artist}}/{{year}}');
    });

    test('format: mp3 by default, remembered, back to the default when turned off', () async {
      expect(state().formats, ['mp3']);
      expect(state().format, 'mp3');
      s.supportedAudioFormats = ['flac', 'opus'];
      expect(state().formats, ['opus', 'flac']);
      expect(state().format, 'opus');
      await state().rememberFormat('flac');
      expect(state().format, 'flac');
      expect(s.ytdlFormat, 'flac');
      expect(h.persisted, [s]);
      s.supportedAudioFormats = ['mp3', 'opus'];
      expect(state().format, 'mp3');
      await state().resetFormat();
      expect(s.ytdlFormat, isNull);
    });
  });

  group('presets (read only)', () {
    test('Discover\'s destination only with plug-ins on; templates from the view', () async {
      s.discoveryPluginsAvailable = true;
      h.fake.discoverAt('Music');
      (h.fake.destination!['libraries'] as List).first['template'] = '{{ARTIST}}';
      await state().loadPresets();
      expect(state().discoverDestination?.vpath, 'Music');
      expect(state().libraryTemplates, {'Music': '{{ARTIST}}'});
      expect(h.fake.count('GET', '/torrent/path-templates'), 0);
    });

    test('plug-ins off: no destination asked; the torrent templates instead', () async {
      h.fake.discoverAt('Music');
      h.fake.pathTemplates = {
        'vpaths': {
          'Music': {'template': '{{artist}}'},
          'Podcasts': {'template': ''},
        },
      };
      await state().loadPresets();
      expect(h.fake.count('GET', '/discovery/collection/destination'), 0);
      expect(state().discoverDestination, isNull);
      expect(state().libraryTemplates, {'Music': '{{artist}}'});
    });

    test('once per session', () async {
      await state().loadPresets();
      await state().loadPresets();
      expect(h.fake.count('GET', '/torrent/path-templates'), 1);
      expect(state().presetsLoaded, isTrue);
    });
  });

  group('the record bound (BUILD NOTES: no row older than the job)', () {
    test('a record older than the claimed entry never settles a vanished job', () async {
      // An earlier add of the same link into the same folder that no job
      // here holds (the web app's, or a dismissed row's).
      h.fake.file(dir, 'One_More_Time.mp3');
      final r0 = h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      final job = await started();
      expect(job.serverStart, greaterThan(r0['downloadedAt'] as int));
      // A job saved before floors existed: only its start bounds it.
      job.recordFloor = null;
      // It failed while the app was away; the entry left the tracker unseen.
      h.fake.forget(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.notSureFinished);
      expect(job.recordId, isNull);
      expect(h.toasts, isEmpty);
    });

    test('complete with no new record does not take an older one', () async {
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      final job = await started();
      job.recordFloor = null;
      h.fake.finish(job.pid!, record: false);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(job.recordId, isNull);
    });

    test('the record\'s newest id is read before the POST and kept on the job', () async {
      h.fake.addRecord(plugin: 'youtube', relativePath: 'x.mp3', origin: 'x'); // 100
      await state().probeTier();
      h.fake.addRecord(plugin: 'youtube', relativePath: 'y.mp3', origin: 'y'); // 101
      final job = await started();
      expect(job.recordFloor, 101);
      final paths = h.fake.requests.map((r) => r.url.path).toList();
      expect(paths.lastIndexOf('/api/v1/discovery/downloads'), lessThan(paths.indexOf('/api/v1/ytdl/')));
      expect(h.fake.calls('GET', '/discovery/downloads').last.url.queryParameters['limit'], '1');
    });

    test('… the last id read stands in when it cannot be had in time', () async {
      h.fake.addRecord(relativePath: 'Old.mp3'); // 100
      await state().probeTier();
      h.fake.recordsGate = Completer<void>();
      final pending = state().start(h.request());
      await ytdlSettle();
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0, reason: 'waiting for the floor');
      await h.timers.elapse(YtdlServerState.kFloorWait);
      final out = await pending;
      expect(out.ok, isTrue);
      expect(out.job!.recordFloor, 100);
      h.fake.recordsGate!.complete();
      await ytdlSettle();

      h.fake.recordsThrows = const SocketException('Network is unreachable');
      final failed = await state().start(h.request(url: kFeelGood));
      expect(failed.job!.recordFloor, 100);
    });
  });

  group('record pages count every plug-in (a page with no ytdl row is not the end)', () {
    void discoverRows(int n) {
      for (var i = 0; i < n; i++) {
        h.fake.addRecord(plugin: 'youtube', relativePath: 'Discover/$i.mp3', origin: 'x');
      }
    }

    test('ADDED reads past a page of Discover downloads; the short page '
        'after it ends the record', () async {
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3', title: 'One More Time');
      discoverRows(20);
      await state().probeTier();
      expect(state().tier, YtdlServerTier.full);
      expect(state().added.single.title, 'One More Time');
      expect(state().canShowEarlier, isFalse);
    });

    test('Show earlier pages past them too, on every plug-in\'s ids', () async {
      for (var i = 0; i < 5; i++) {
        h.fake.addRecord(relativePath: 'A/$i.mp3'); // 100–104
      }
      discoverRows(20); // 105–124
      for (var i = 0; i < 20; i++) {
        h.fake.addRecord(relativePath: 'B/$i.mp3'); // 125–144
      }
      await state().probeTier();
      expect(state().added, hasLength(20));
      await state().showEarlier();
      expect(state().added, hasLength(25));
      expect(state().canShowEarlier, isFalse);
      final asked = h.fake.calls('GET', '/discovery/downloads').map((r) => r.url.queryParameters['before']);
      expect(asked, [null, '125', '105']);
    });

    test('a vanished job finds its record under a page of Discover downloads', () async {
      final job = await started();
      h.fake
        ..forget(job.pid!)
        ..addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      discoverRows(20);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(job.recordId, isNotNull);
    });

    test('a refresh keeps the pages Show earlier brought', () async {
      for (var i = 0; i < 25; i++) {
        h.fake.addRecord(relativePath: 'A/$i.mp3');
      }
      await state().probeTier();
      await state().showEarlier();
      expect(state().added, hasLength(25));
      h.fake.addRecord(relativePath: 'New.mp3');
      await state().refreshAdded();
      expect(state().added, hasLength(26));
      expect(state().added.first.title, 'New');
    });
  });

  group('ADDED rows', () {
    test('a record this phone\'s job matched carries the job\'s cover; one '
        'no job holds has none', () async {
      const thumb = 'https://i.ytimg.com/vi/FGBhQbmPwH8/hq.jpg';
      await state().probeTier();
      final job = await started(request: h.request(cover: thumb));
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(job.recordId, isNotNull);
      final row = state().added.single;
      expect(row.recordId, job.recordId);
      expect(row.cover, thumb);
      h.fake.addRecord(
          relativePath: 'Other.mp3', origin: 'https://www.youtube.com/watch?v=x');
      await state().refreshAdded();
      expect(state().added.map((r) => r.cover), [null, thumb]);
    });

    test('a job settled before its record could be read takes it: one row', () async {
      await state().probeTier();
      final job = await started();
      h.fake
        ..finish(job.pid!)
        ..recordsRefusal = (500, 'Server Error');
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(job.recordId, isNull);
      h.fake.recordsRefusal = null;
      await state().refreshAdded();
      expect(job.recordId, h.fake.records.first['id']);
      expect(state().added, hasLength(1));
      expect(state().added.single.recordId, job.recordId);
      expect(s.ytdlJobs.single['recordId'], job.recordId, reason: 'persisted');
    });

    test('… also when the tier was not known yet as it settled', () async {
      h.fake.recordsRefusal = (500, 'Server Error');
      final job = await started();
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(state().tier, YtdlServerTier.unknown);
      expect(job.state, YtdlJobState.added);
      h.fake.recordsRefusal = null;
      await state().onScreenOpened();
      expect(state().tier, YtdlServerTier.full);
      expect(job.recordId, h.fake.records.first['id']);
      expect(state().added, hasLength(1));
    });

    test('a job row and a record naming the same file show once', () async {
      // The job could not attribute it (unbounded: saved by an older build).
      final job = await started();
      job
        ..recordFloor = null
        ..serverStart = null;
      h.fake.finish(job.pid!, record: false);
      await h.timers.elapse(beat);
      expect(job.filepath, 'Music/Daft Punk/Discovery/One_More_Time.mp3');
      h.fake.addRecord(relativePath: 'Daft Punk/Discovery/One_More_Time.mp3');
      await state().refreshAdded();
      expect(state().added.single.recordId, isNotNull);
    });

    test('rows carry the cover (a job\'s) and the track id', () async {
      h.fake.hasRecords = false;
      final job = await started(
          request: const YtdlStartRequest(
              url: kOneMoreTime,
              directory: dir,
              codec: 'mp3',
              title: 'One More Time',
              cover: 'https://i.ytimg.com/vi/FGBhQbmPwH8/hq.jpg',
              predictedName: 'One_More_Time.mp3'));
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(state().added.single.cover, 'https://i.ytimg.com/vi/FGBhQbmPwH8/hq.jpg');

      h.unwire();
      h = YtdlHarness()..wire();
      s = ytdlServer();
      final r = h.fake.addRecord(relativePath: 'One_More_Time.mp3', trackId: 4242);
      await state().probeTier();
      expect(state().added.single.trackId, 4242);
      expect(state().added.single.recordId, r['id']);
    });

    /// The server's client with the record reads counted ([RecordReads]).
    RecordReads watchRecordReads() {
      final reads = RecordReads();
      h.hub.makeApi = (srv) => YtdlApi(srv,
          client: MockClient((req) async {
            if (req.url.path.endsWith('/api/v1/discovery/downloads')) {
              await reads.next();
            }
            return h.fake.handle(req);
          }),
          awaitTunnel: (_) async => true);
      return reads;
    }

    test('a job that took its record keeps its row while the refresh after '
        'it fails (spec §6: the row moves to ADDED)', () async {
      final reads = watchRecordReads();
      await state().probeTier();
      final job = await started();
      h.fake.finish(job.pid!);
      // Its own record page answers; the refresh right after it fails.
      reads.failFrom = reads.count + 2;
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.added);
      expect(job.recordId, isNotNull);
      expect(h.toasts.last.success, isTrue);
      expect(state().added.map((r) => r.title), ['One More Time']);
      expect(state().added.single.recordId, job.recordId);
      // A later read brings the record's row in its place: one row.
      reads.failFrom = null;
      await state().refreshAdded();
      expect(state().added, hasLength(1));
      expect(state().added.single.recordId, job.recordId);
    });

    test('… and while that refresh is still out: never in no list', () async {
      final reads = watchRecordReads();
      await state().probeTier();
      final job = await started();
      h.fake.finish(job.pid!);
      final hold = Completer<void>();
      reads
        ..holdFrom = reads.count + 2
        ..hold = hold;
      await h.timers.elapse(beat);
      expect(job.recordId, isNotNull);
      expect(state().addedLoading, isTrue);
      expect(state().adding, isEmpty);
      expect(state().added.map((r) => r.title), ['One More Time']);
      hold.complete();
      await ytdlSettle();
      expect(state().addedLoading, isFalse);
      expect(state().added.single.recordId, job.recordId);
    });

    test('a job whose record is older than the loaded pages waits for Show '
        'earlier instead of standing above them', () async {
      await state().probeTier();
      final job = await started();
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      final id = job.recordId!;
      for (var i = 0; i < 25; i++) {
        h.fake.addRecord(
            relativePath: 'Other/$i.mp3',
            origin: 'https://www.youtube.com/watch?v=other$i');
      }
      // A restart: the first page holds only newer rows.
      h.hub.reset();
      h.wire();
      await state().probeTier();
      expect(state().jobs.single.recordId, id);
      expect(state().added, hasLength(20));
      expect(state().added.map((r) => r.recordId), isNot(contains(id)));
      await state().showEarlier();
      expect(state().added.where((r) => r.recordId == id), hasLength(1));
      expect(state().added.where((r) => r.title == 'One More Time'), hasLength(1));
    });
  });

  group('failures: the clash read, Try again, re-pings', () {
    test('an error entry whose folder won\'t list waits: a clash is not read as a plain failure', () async {
      final job = await started();
      h.fake
        ..file(dir, 'One_More_Time.mp3')
        ..fail(job.pid!)
        ..listFails.add(dir);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.adding);
      h.fake.listFails.clear();
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.failedClash);
    });

    test('… and settles failed once the entry is gone and the folder still won\'t list', () async {
      final job = await started();
      h.fake
        ..fail(job.pid!)
        ..listFails.add(dir);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.adding);
      h.fake.forget(job.pid!);
      await h.timers.elapse(beat);
      expect(job.state, YtdlJobState.failed);
    });

    test('Try again on a start failure that needed no folder makes none', () async {
      h.fake.addRefusal = (500, 'FFmpeg is not available yet');
      final job = (await state().start(h.request(inline: () => false))).job!;
      expect(job.state, YtdlJobState.startFailed);
      expect(job.mkdir, isNull);
      h.fake
        ..addRefusal = null
        ..mkdirRefusal = (403, 'Create Folder Disabled');
      h.toasts.clear();
      final out = await state().retry(job);
      expect(out.ok, isTrue);
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 0);
      expect(state().mkdirRefused, isFalse);
      expect(h.toasts, isEmpty);
    });

    test('a re-ping is heard; a converter it turned off closes the entry', () async {
      h.hub.reping = (srv) async {
        await Future<void>.delayed(Duration.zero);
        srv.transcodeAvailable = false;
      };
      var heardOff = 0;
      state().addListener(() {
        if (s.transcodeAvailable == false) heardOff++;
      });
      h.fake.addRefusal = (500, 'FFmpeg is not available yet');
      await state().start(h.request(inline: () => true));
      await ytdlSettle();
      expect(heardOff, greaterThan(0));
      expect(state().entryAllowed, isFalse);
    });

    test('a connection back polls the waiting rows at once', () async {
      await started();
      h.fake.jobsThrows = const SocketException('Network is unreachable');
      await h.timers.elapse(beat);
      expect(state().offline, isTrue);
      h.fake.jobsThrows = null;
      final polls = h.fake.count('GET', '/ytdl/downloads');
      h.hub.connectivityRestored();
      await ytdlSettle();
      expect(h.fake.count('GET', '/ytdl/downloads'), polls + 1);
      expect(state().offline, isFalse);
    });
  });

  group('toasts', () {
    test('a song in the library\'s top folder names the library', () async {
      final job = await started(request: h.request(directory: '/Music/'));
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(h.toastTexts.single, 'Added “One More Time” to \u2068Music\u2069');
    });

    test('a deep path is cut at the start', () async {
      const deep = '/Music/A/B/C/';
      h.fake.folder(deep);
      final job = await started(request: h.request(directory: deep));
      h.fake.finish(job.pid!);
      await h.timers.elapse(beat);
      expect(h.toastTexts.single, 'Added “One More Time” to … › \u2068B\u2069 › \u2068C\u2069');
    });
  });
}

/// Record reads as a test's client counts them: from the [failFrom]th on
/// they throw, from the [holdFrom]th on they wait for [hold].
class RecordReads {
  int count = 0;
  int? failFrom;
  int? holdFrom;
  Completer<void>? hold;

  Future<void> next() async {
    final n = ++count;
    final fail = failFrom;
    if (fail != null && n >= fail) {
      throw http.ClientException('Connection reset by peer');
    }
    final from = holdFrom;
    if (from != null && n >= from) await hold!.future;
  }
}
