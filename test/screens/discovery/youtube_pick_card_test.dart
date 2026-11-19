// KEEP A COPY's YouTube add on the network-lead sheet (the design canvas's
// LookupReady, LookupStates and JobStates boards): where files land (GENRE,
// PEER and SERVERFOLDER always empty for a download, and said so), Change
// with a download's preview, and every state of the YouTube card — idle,
// searching (the counter, the 20 s hint, Stop waiting, the 120 s bound),
// the uploads found (collapsed and opened, the loose match, the pick, Open
// on YouTube), already yours, nothing close, busy, couldn't search, no
// answer — then Add this one and each refusal of it, and the add's line in
// the card's place: waiting, its steps, stopping, every ending and its
// verbs (Cancel, Retry, Choose another, Play, Add to queue), restored when
// the sheet opens again.
//
// Most cases pump the block on its own, handed a NetworkKeepSlot whose
// callbacks the test keeps; the last group pumps the whole sheet, where
// the block stands in KEEP A COPY. The plug-in API is the scripted fake
// behind the real DiscoveryPluginsApi; the queue, the launcher and the
// destination picker are the test's.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/destination_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/elsewhere_sheet.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/screens/discovery/network_lead_sheet.dart';
import 'package:mstream_music/screens/discovery/youtube_pick_card.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

import '../../media/preview_fakes.dart';
import '../discovery_fixtures.dart';
import '../discovery_plugin_fakes.dart';

const _listing = '/api/v1/discovery/plugins';
const _lookup = '/api/v1/discovery/plugin-jobs/lookup';
const _ytResolve = '/plugins/youtube/resolve';
const _ytJobs = '/plugins/youtube/jobs';

/// The canvas's lead: a per-song P2P row as the route hands it out.
Map<String, dynamic> netRow() => {
  'artist': 'The Quiet Assembly',
  'title': 'Paper Satellites',
  'album': 'Static Bloom',
  'year': 2011,
  'duration': 238,
  'similarity': 0.88,
  'isrc': 'US-RC1-76-07839',
  'peer': {'endpointId': 'ab' * 32, 'name': 'Vinyl Vault'},
};

/// What every call sends for [netRow].
Map<String, dynamic> repaired() =>
    sendableRecommendation(netRow(), network: true)!;

String watch(String id) => 'https://www.youtube.com/watch?v=$id';

/// The canvas's five uploads, best first: two confirmed (channel and
/// length), three thin search entries, the last under the bar.
List<Map<String, dynamic>> fiveUploads() => [
  {
    'id': 'aaaaaaaaaa1',
    'url': watch('aaaaaaaaaa1'),
    'title': 'Paper Satellites',
    'channel': 'The Quiet Assembly - Topic',
    'durationSec': 237.6,
    'topic': true,
    'score': 0.96,
  },
  {
    'id': 'bbbbbbbbbb2',
    'url': watch('bbbbbbbbbb2'),
    'title': 'The Quiet Assembly - Paper Satellites (Official Video)',
    'channel': 'The Quiet Assembly',
    'durationSec': 261,
    'score': 0.89,
  },
  {
    'id': 'cccccccccc3',
    'url': watch('cccccccccc3'),
    'title': 'Paper Satellites (2011 Remaster)',
    'score': 0.81,
  },
  {
    'id': 'dddddddddd4',
    'url': watch('dddddddddd4'),
    'title': 'the quiet assembly - paper satellites [HQ]',
    'score': 0.70,
  },
  {
    'id': 'eeeeeeeeee5',
    'url': watch('eeeeeeeeee5'),
    'title': 'Paper Satellites - The Quiet Assembly (1080p)',
    'channel': 'tapeloop_archive',
    'score': 0.55,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final defaultLaunch = elsewhereLaunch;

  late Server server;
  late FakePluginServer fake;
  late FakeTimers timers;
  late DiscoveryJobsController jobs;
  late FakePreviewPlayer preview;
  late bool youtubeShown;
  late List<String> toasts;
  late List<String> refusedWith;
  late List<DiscoveryJob> started;
  late int leadActions;
  late List<Uri> launched;
  late List<int> endsAtLaunch;
  late List<String> played;
  late List<String> queued;
  late List<(DestinationPreviewSong?, String)> changes;

  setUp(() {
    server = discoveryServer()
      ..discoveryPluginsAvailable = true
      ..noUpload = false;
    fake = FakePluginServer()..listLeadPlugins();
    fake.youtubeCandidates = fiveUploads();
    timers = FakeTimers();
    preview = FakePreviewPlayer.install();
    youtubeShown = true;
    toasts = [];
    refusedWith = [];
    started = [];
    leadActions = 0;
    launched = [];
    endsAtLaunch = [];
    played = [];
    queued = [];
    changes = [];
    KeepToast.debugSink = (m, {success = false}) => toasts.add(m);
    elsewhereLaunch = (uri) async {
      launched.add(uri);
      endsAtLaunch.add(preview.ends.length);
      return true;
    };
    YoutubeKeepBlock.play = (row) async => played.add(row.data!);
    YoutubeKeepBlock.queue = (row) async => queued.add(row.data!);
    DiscoveryKeepRoutes.changeDestination = (_, _, song, peer) =>
        changes.add((song, peer));
    NetworkLeadSheet.keepBlock = null;
  });

  tearDown(() {
    KeepToast.debugSink = null;
    KeepToast.debugActionSink = null;
    elsewhereLaunch = defaultLaunch;
    YoutubeKeepBlock.reset();
    DiscoveryKeepRoutes.reset();
    NetworkLeadSheet.keepBlock = null;
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  DiscoveryJobsController makeJobs() => DiscoveryJobsController(
    server: server,
    api: fake.api(server),
    timer: timers.call,
    watchLifecycle: false,
    youtubeShown: () => youtubeShown,
  );

  /// The block on its own, tall enough that nothing scrolls, for the
  /// repaired canvas lead; the listing, the destination and the job list
  /// read first, as the sheet's controller has them.
  Future<void> pumpBlock(
    WidgetTester tester, {
    bool autoSearch = false,
    String? avoidUrl,
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    jobs = makeJobs();
    addTearDown(jobs.dispose);
    final parsed = DiscoveryLead.fromServerMap(netRow())!;
    final lead = parsed.withRaw(parsed.recommendation!);
    unawaited(jobs.activate());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => YoutubeKeepBlock(
                slot: NetworkKeepSlot(
                  jobs: jobs,
                  lead: lead,
                  autoSearch: autoSearch,
                  avoidUrl: avoidUrl,
                  onLeadAction: () => leadActions++,
                  onStarted: started.add,
                  onRefused: refusedWith.add,
                  toast: toasts.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f, warnIfMissed: false);
    await frames(tester);
  }

  /// A line as read: its no-break spaces as spaces, no word joiners.
  String plain(WidgetTester tester, String key) {
    final text = tester.widget<Text>(find.byKey(ValueKey(key)));
    return (text.data ?? text.textSpan!.toPlainText())
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2060', '');
  }

  bool shown(String key) => find.byKey(ValueKey(key)).evaluate().isNotEmpty;

  /// Whether upload [i]'s row reads as the one picked (semantics on).
  void expectPicked(WidgetTester tester, int i, bool picked) => expect(
    tester.getSemantics(find.byKey(ValueKey('yt-candidate-$i'))),
    isSemantics(isInMutuallyExclusiveGroup: true, isChecked: picked),
  );

  /// The YouTube add the account made of the canvas lead, at the head of
  /// the list (and under its key for the lookup).
  Map<String, dynamic> ytJob({
    String state = 'queued',
    String? choice,
    Map<String, dynamic>? result,
    double? progress,
    String? statusText,
    String? error,
  }) => fake.addJob(
    repaired(),
    plugin: 'youtube',
    state: state,
    choice: choice == null ? null : {'url': choice},
    result: result,
    progress: progress,
    statusText: statusText,
    error: error,
  );

  group('Files go to', () {
    testWidgets('the layout from the song tags a download carries: no '
        'genre slot, and a layout naming GENRE says it is always empty; '
        'Change opens the picker previewing a download', (tester) async {
      fake.destination = {
        ...fake.destination,
        'destination': {
          'vpath': 'copies',
          'base': '',
          'layout': '{{GENRE}}/{{ALBUMARTIST}}/{{ALBUM}}',
          'source': 'user',
        },
      };
      await pumpBlock(tester);
      expect(tester.takeException(), isNull);
      expect(
        plain(tester, 'yt-destination-path'),
        'Files go to copies › The Quiet Assembly › Static Bloom',
      );
      expect(
        find.text('Always empty for YouTube songs, so left out: {{GENRE}}'),
        findsOneWidget,
      );
      expect(find.textContaining('genre›'), findsNothing);

      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(find.byKey(const ValueKey('yt-change')));
      expect(
        node,
        isSemantics(
          label: 'Change where added songs go',
          isButton: true,
          hasTapAction: true,
        ),
      );
      // A screen reader's (or Switch Access's) activation opens it too.
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await frames(tester);
      expect(changes, hasLength(1));
      changes.clear();
      handle.dispose();
      await tapKey(tester, 'yt-change');
      final (song, peer) = changes.single;
      expect(song!.download, isTrue);
      expect(song.title, 'Paper Satellites');
      expect(song.album, 'Static Bloom');
      expect(peer, '');
    });

    testWidgets('a layout with none of them: no note', (tester) async {
      await pumpBlock(tester);
      expect(
        plain(tester, 'yt-destination-path'),
        'Files go to copies › The Quiet Assembly › Static Bloom',
      );
      expect(find.byKey(const ValueKey('yt-never-note')), findsNothing);
    });
  });

  group('the YouTube card', () {
    testWidgets('IDLE: what it will search for, nothing asked of YouTube', (
      tester,
    ) async {
      await pumpBlock(tester);
      expect(find.text('YouTube'), findsOneWidget);
      expect(
        find.text(
          'Finds the closest upload for “The Quiet Assembly Paper '
          'Satellites” · nothing is added yet',
        ),
        findsOneWidget,
      );
      expect(find.text('Search YouTube'), findsOneWidget);
      expect(fake.count('POST', _ytResolve), 0);
      // Only the single lookup asked whether the song already has an add.
      expect(fake.count('POST', _lookup), 1);
      expect(fake.resolves('youtube'), isEmpty);
    });

    testWidgets('SEARCHING: the tag, the counter ticking each second, the '
        'hint past 20 s; at 119 s still waiting, at 120 s NO ANSWER', (
      tester,
    ) async {
      fake.resolveGates['youtube'] = Completer<void>();
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(fake.resolves('youtube').single, {'recommendation': repaired()});
      expect(find.text('Searching'), findsOneWidget);
      expect(
        find.text('Asking YouTube for “The Quiet Assembly Paper Satellites”…'),
        findsOneWidget,
      );
      expect(plain(tester, 'yt-counter'), '0:00');
      await tester.pump(const Duration(seconds: 7));
      expect(plain(tester, 'yt-counter'), '0:07');
      expect(shown('yt-slow-hint'), isFalse);
      await tester.pump(const Duration(seconds: 13));
      expect(plain(tester, 'yt-counter'), '0:20');
      expect(
        find.text(
          'YouTube can take a minute. You can close this — the server '
          'keeps searching and remembers the answer for a few hours.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 99));
      expect(plain(tester, 'yt-counter'), '1:59');
      expect(shown('yt-stop'), isTrue);
      await tester.pump(const Duration(seconds: 1));
      await frames(tester);
      expect(
        find.text(
          "YouTube didn't answer in time. The server may still finish — "
          'search again in a minute.',
        ),
        findsOneWidget,
      );
      expect(find.text('Searching'), findsNothing);
      expect(shown('yt-search-again'), isTrue);

      // The server's late answer reaches no one.
      fake.resolveGates['youtube']!.complete();
      await frames(tester);
      expect(shown('yt-uploads'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stop waiting: back to IDLE; the late answer is dropped', (
      tester,
    ) async {
      fake.resolveGates['youtube'] = Completer<void>();
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      await tester.pump(const Duration(seconds: 3));
      await tapKey(tester, 'yt-stop');
      expect(find.text('Search YouTube'), findsOneWidget);
      expect(shown('yt-counter'), isFalse);
      fake.resolveGates['youtube']!.complete();
      await frames(tester);
      expect(find.text('Search YouTube'), findsOneWidget);
      expect(shown('yt-uploads'), isFalse);
    });

    testWidgets('READY collapsed: the count, only the pick (the first), '
        '"4 more"; opened: every upload, thin ones without a sub, the '
        'loose one in its own words; Fewer closes it on the pick', (
      tester,
    ) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(find.text('5 uploads found · pick one'), findsOneWidget);
      expect(shown('yt-candidate-0'), isTrue);
      for (final i in [1, 2, 3, 4]) {
        expect(shown('yt-candidate-$i'), isFalse);
      }
      expect(find.text('Paper Satellites'), findsOneWidget);
      // A fractional length is rounded (S6).
      expect(find.text('The Quiet Assembly - Topic · 3:58'), findsOneWidget);
      expect(find.text('match 96%'), findsOneWidget);
      expect(find.text('4 more'), findsOneWidget);
      expect(find.text('Add this one'), findsOneWidget);
      expect(find.text('Only the upload you pick is added.'), findsOneWidget);
      final handle = tester.ensureSemantics();
      expectPicked(tester, 0, true);

      await tapKey(tester, 'yt-more');
      for (final i in [0, 1, 2, 3, 4]) {
        expect(shown('yt-candidate-$i'), isTrue);
      }
      expect(find.text('The Quiet Assembly · 4:21'), findsOneWidget);
      expect(find.text('Paper Satellites (2011 Remaster)'), findsOneWidget);
      // Thin rows: no channel or length, no sub line; a channel alone.
      expect(find.textContaining(' · ', findRichText: true), findsNWidgets(3));
      expect(find.text('tapeloop_archive'), findsOneWidget);
      expect(find.text('match 81%'), findsOneWidget);
      expect(find.text('loose match 55%'), findsOneWidget);
      expect(find.text('match 55%'), findsNothing);
      expect(find.text('Fewer'), findsOneWidget);

      await tapKey(tester, 'yt-candidate-2');
      expectPicked(tester, 2, true);
      expectPicked(tester, 0, false);
      await tapKey(tester, 'yt-more');
      expect(shown('yt-candidate-2'), isTrue);
      expect(shown('yt-candidate-0'), isFalse);
      handle.dispose();
    });

    testWidgets("Open on YouTube: the upload's page, a clip ending first as "
        'leaving the app', (tester) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(
        find.byTooltip('Open on YouTube'),
        findsOneWidget,
        reason: 'one row shown',
      );
      await tapKey(tester, 'yt-open-0');
      expect(launched, [Uri.parse(watch('aaaaaaaaaa1'))]);
      expect(preview.ends, [PreviewEnd.leftApp]);
      expect(endsAtLaunch, [1]);
    });

    testWidgets('one upload found: "1 upload found", no toggle', (
      tester,
    ) async {
      fake.youtubeCandidates = fiveUploads().take(1).toList();
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(find.text('1 upload found'), findsOneWidget);
      expect(shown('yt-more'), isFalse);
      expect(shown('yt-add'), isTrue);
    });

    testWidgets('ALREADY YOURS: the library file; Play and Add to queue play '
        'it, each a lead action', (tester) async {
      fake.youtubeOwned = {
        'vpath': 'music',
        'filepath': 'music/Albums/The Quiet Assembly/04 Paper Satellites.flac',
        'by': 'tags',
      };
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(find.text('Already yours'), findsOneWidget);
      expect(find.text('Your library has this song'), findsOneWidget);
      expect(
        find.text(
          'music / Albums / The Quiet Assembly / 04 Paper Satellites.flac',
        ),
        findsOneWidget,
      );
      expect(shown('yt-add'), isFalse);
      await tapKey(tester, 'yt-play');
      expect(played, [
        '/music/Albums/The Quiet Assembly/04 Paper Satellites.flac',
      ]);
      await tapKey(tester, 'yt-queue');
      expect(queued, played);
      expect(toasts, ['1 song added to queue']);
      expect(leadActions, 2);
    });

    testWidgets('NOTHING CLOSE, then Search again', (tester) async {
      fake.youtubeCandidates = [];
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(
        find.text(
          'YouTube has nothing close to “The Quiet Assembly Paper Satellites”',
        ),
        findsOneWidget,
      );
      fake.youtubeCandidates = fiveUploads();
      await tapKey(tester, 'yt-search-again');
      expect(fake.count('POST', _ytResolve), 2);
      expect(find.text('5 uploads found · pick one'), findsOneWidget);
    });

    testWidgets('BUSY (429), COULDN\'T (502; 403 reads the gate again): '
        'Search again', (tester) async {
      fake.refuse[_ytResolve] = (429, 'too many YouTube lookups at once');
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(
        find.text('YouTube is busy on this server — try again in a minute.'),
        findsOneWidget,
      );
      expect(refusedWith, isEmpty);

      fake.refuse[_ytResolve] = (502, 'the YouTube search failed');
      await tapKey(tester, 'yt-search-again');
      expect(find.text("Couldn't search YouTube right now."), findsOneWidget);

      final listings = fake.count('GET', _listing);
      fake.refuse[_ytResolve] = (403, 'Uploading Disabled');
      await tapKey(tester, 'yt-search-again');
      expect(find.text("Couldn't search YouTube right now."), findsOneWidget);
      expect(fake.count('GET', _listing), listings + 1);
      expect(refusedWith, isEmpty);
    });

    testWidgets('404 on the search: the section goes, and says why', (
      tester,
    ) async {
      fake.refuse[_ytResolve] = (404, 'no plug-in youtube');
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      expect(refusedWith, [
        'That option was just switched off on this server.',
      ]);
    });
  });

  group('Add this one', () {
    testWidgets('adds the upload picked, to the place shown: a lead action, '
        'in flight busy (the rows and the toggle still), then the line', (
      tester,
    ) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-more');
      await tapKey(tester, 'yt-candidate-1');
      fake.startGate = Completer<void>();
      await tapKey(tester, 'yt-add');
      expect(leadActions, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('yt-add')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('yt-more')))
            .onPressed,
        isNull,
      );
      final handle = tester.ensureSemantics();
      await tapKey(tester, 'yt-candidate-3');
      expectPicked(tester, 1, true);
      handle.dispose();
      // A second press sends nothing.
      await tester.tap(find.byKey(const ValueKey('yt-add')));
      await frames(tester);

      fake.startGate!.complete();
      fake.startGate = null;
      await frames(tester);
      final body = fake.starts('youtube').single;
      expect(body['recommendation'], repaired());
      expect(body['choice'], {'url': watch('bbbbbbbbbb2')});
      expect(body.containsKey('scope'), isFalse);
      expect(body['destination'], {
        'vpath': 'copies',
        'base': '',
        'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
      });
      expect(started.single.plugin, 'youtube');
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(find.text('Starts on its own'), findsOneWidget);
      expect(shown('yt-uploads'), isFalse);
    });

    testWidgets('a live add of another upload of the song (200, created '
        'false): its line, and a note; nothing new is toasted', (tester) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      fake.existing = {
        ...ytJob(state: 'running', choice: watch('zzzzzzzzzz9')),
        'statusText': 'reading the chosen upload',
      };
      fake.jobs.clear();
      await tapKey(tester, 'yt-add');
      expect(find.text('Checking the upload'), findsOneWidget);
      expect(
        find.text('Already adding another upload of this song.'),
        findsOneWidget,
      );
      expect(started, isEmpty);
    });

    testWidgets('…the note goes once that add has ended (the server names '
        'another upload\'s add only while it runs)', (tester) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      final other = ytJob(state: 'running', choice: watch('zzzzzzzzzz9'));
      fake.existing = other;
      await tapKey(tester, 'yt-add');
      expect(shown('yt-other-upload'), isTrue);
      other
        ..['state'] = 'done'
        ..['result'] = {
          'downloaded': {
            'vpath': 'copies',
            'filepath': 'copies/The Quiet Assembly/Paper_Satellites.mp3',
            'bytes': 6710886,
            'format': 'mp3',
          },
        }
        ..['updatedAt'] = 2;
      await jobs.refreshJobs();
      await frames(tester);
      expect(find.text('In your collection'), findsOneWidget);
      expect(shown('yt-other-upload'), isFalse);
    });

    testWidgets('…of the same upload: its line, no note', (tester) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      fake.existing = ytJob(state: 'queued', choice: watch('aaaaaaaaaa1'));
      fake.jobs.clear();
      await tapKey(tester, 'yt-add');
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(shown('yt-other-upload'), isFalse);
    });

    testWidgets('refused 409 (another account), 429 (with and without its '
        'count), 400 and 5xx: the card stays, the button live, a line '
        'under it', (tester) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      Future<String> refusedLine(int status, String words) async {
        fake.refuse[_ytJobs] = (status, words);
        final before = fake.count('POST', _ytJobs);
        await tapKey(tester, 'yt-add');
        // The button stays live: each press is sent.
        expect(fake.count('POST', _ytJobs), before + 1);
        expect(shown('yt-uploads'), isTrue);
        return tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('yt-refusal')),
                matching: find.byType(Text),
              ),
            )
            .data!;
      }

      expect(
        await refusedLine(
          409,
          'someone else on this server is already getting this — try again '
          'in a moment',
        ),
        'Someone else on this server is adding this right now — try again '
        'in a moment.',
      );
      expect(
        await refusedLine(
          429,
          'you have 20 jobs queued or running — wait for some to finish '
          '(the limit is 20)',
        ),
        'You have 20 waiting or running — let some finish first.',
      );
      expect(
        await refusedLine(429, 'slow down'),
        'Too many waiting — let some finish first.',
      );
      expect(
        await refusedLine(400, '"choice.url" must be a valid uri'),
        "Couldn't start this. Try again.",
      );
      expect(
        await refusedLine(500, 'HTTP 500'),
        "Couldn't start this. Try again.",
      );
      expect(started, isEmpty);
      expect(refusedWith, isEmpty);
    });

    testWidgets('no answer at all (status 0): "Couldn\'t reach your server"', (
      tester,
    ) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      fake.startGate = Completer<void>();
      await tapKey(tester, 'yt-add');
      await tester.pump(const Duration(seconds: 15));
      await frames(tester);
      expect(
        find.text("Couldn't reach your server. Try again."),
        findsOneWidget,
      );
      fake.startGate!.complete();
      await frames(tester);
    });

    testWidgets('refused 403 or 404: the section goes, with why', (
      tester,
    ) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      fake.refuse[_ytJobs] = (403, 'Uploading Disabled');
      await tapKey(tester, 'yt-add');
      fake.refuse[_ytJobs] = (404, 'no plug-in youtube');
      await tapKey(tester, 'yt-add');
      expect(refusedWith, [
        'Adding songs was just turned off for your account.',
        'That option was just switched off on this server.',
      ]);
    });

    testWidgets('where files land moved (409 destination_changed): the path '
        'above redrawn, the card stays, a line says to check it', (
      tester,
    ) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      fake.destination = {
        ...fake.destination,
        'destination': {
          'vpath': 'copies',
          'base': '',
          'layout': 'From the network/{{ALBUM}}',
          'source': 'user',
        },
      };
      await tapKey(tester, 'yt-add');
      expect(
        find.text(
          'Where files land changed since this opened. Check the path above '
          'and add again.',
        ),
        findsOneWidget,
      );
      expect(
        plain(tester, 'yt-destination-path'),
        'Files go to copies › From the network › Static Bloom',
      );
      expect(shown('yt-uploads'), isTrue);
      expect(started, isEmpty);
      // Adding again goes to the place now shown.
      await tapKey(tester, 'yt-add');
      expect(started, hasLength(1));
      expect(shown('yt-refusal'), isFalse);
    });

    testWidgets('…to nowhere: no library takes files now (the gate closes)', (
      tester,
    ) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      fake.destination = {...fake.destination, 'destination': null};
      await tapKey(tester, 'yt-add');
      expect(toasts, ['No library on your server takes new files']);
      expect(jobs.youtubeGate().ready, isFalse);
    });
  });

  group("the add's line", () {
    testWidgets('waiting: Cancel; cancelled, the card comes back under '
        '"Stopped · nothing was added"', (tester) async {
      final j = ytJob(state: 'queued', choice: watch('aaaaaaaaaa1'));
      await pumpBlock(tester);
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(shown('yt-search'), isFalse);
      await tapKey(tester, 'yt-cancel');
      expect(fake.count('POST', '/plugin-jobs/${j['id']}/cancel'), 1);
      expect(find.text('Stopped · nothing was added'), findsOneWidget);
      expect(find.text('Search YouTube'), findsOneWidget);
    });

    testWidgets('…an add started here gives back the uploads found', (
      tester,
    ) async {
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-add');
      await tapKey(tester, 'yt-cancel');
      expect(find.text('Stopped · nothing was added'), findsOneWidget);
      expect(shown('yt-uploads'), isTrue);
      expect(shown('yt-add'), isTrue);
    });

    testWidgets('running: its step and percentage, the bar; no step yet: '
        '"Starting…"; stopping: no Cancel', (tester) async {
      final j = ytJob(
        state: 'running',
        choice: watch('aaaaaaaaaa1'),
        progress: 0.42,
        statusText: '42% of “Paper Satellites”',
      );
      await pumpBlock(tester);
      expect(find.text('Fetching from YouTube · 42%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('yt-bar')),
            )
            .value,
        0.42,
      );
      expect(shown('yt-cancel'), isTrue);

      j['statusText'] = null;
      j['progress'] = 0.1;
      await jobs.refreshJobs();
      await frames(tester);
      expect(find.text('Starting…'), findsOneWidget);

      j['cancelRequested'] = true;
      await jobs.refreshJobs();
      await frames(tester);
      expect(find.text('Stopping…'), findsOneWidget);
      expect(shown('yt-cancel'), isFalse);
    });

    testWidgets('in your collection: the file, "MP3 · 6.4 MB · from …", '
        'Play and Add to queue', (tester) async {
      ytJob(
        state: 'done',
        choice: watch('aaaaaaaaaa1'),
        result: {
          'downloaded': {
            'vpath': 'copies',
            'filepath':
                'copies/The Quiet Assembly/Static Bloom/'
                'Paper_Satellites.mp3',
            'bytes': 6710886,
            'format': 'mp3',
          },
          'match': {'score': 0.96, 'channel': 'The Quiet Assembly - Topic'},
        },
      );
      await pumpBlock(tester);
      expect(find.text('In your collection'), findsOneWidget);
      expect(
        find.text(
          'copies / The Quiet Assembly / Static Bloom / Paper_Satellites.mp3',
        ),
        findsOneWidget,
      );
      expect(
        find.text('MP3 · 6.4 MB · from The Quiet Assembly - Topic'),
        findsOneWidget,
      );
      await tapKey(tester, 'yt-play');
      expect(played, [
        '/copies/The Quiet Assembly/Static Bloom/Paper_Satellites.mp3',
      ]);
      await tapKey(tester, 'yt-queue');
      expect(queued, played);
      expect(leadActions, 2);
    });

    testWidgets('already yours (the library had it): its file, Play', (
      tester,
    ) async {
      ytJob(
        state: 'done',
        result: {
          'skipped': 'owned',
          'existing': {'filepath': 'music/Albums/Paper Satellites.flac'},
        },
      );
      await pumpBlock(tester);
      expect(find.text('Already yours'), findsOneWidget);
      expect(
        find.text('music / Albums / Paper Satellites.flac'),
        findsOneWidget,
      );
      await tapKey(tester, 'yt-play');
      expect(played, ['/music/Albums/Paper Satellites.flac']);
    });

    testWidgets('a file in the way: where, nothing overwritten; Retry sends '
        'the same upload again', (tester) async {
      ytJob(
        state: 'done',
        choice: watch('cccccccccc3'),
        result: {
          'skipped': 'exists',
          'filepath': 'copies/The Quiet Assembly/Static Bloom/x.mp3',
        },
      );
      await pumpBlock(tester);
      expect(find.text('Skipped · a file is already there'), findsOneWidget);
      expect(
        find.text(
          'A file is already at copies / The Quiet Assembly / Static Bloom / '
          'x.mp3 · nothing was overwritten',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'yt-retry');
      final body = fake.starts('youtube').single;
      expect(body['choice'], {'url': watch('cccccccccc3')});
      expect(started, hasLength(1));
      expect(find.text('Waiting for a free slot'), findsOneWidget);
    });

    testWidgets('finished with nothing this line reads: "Finished"', (
      tester,
    ) async {
      ytJob(state: 'done', result: {});
      await pumpBlock(tester);
      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets("failed: \"Couldn't add\", why, Details opens the server's "
        'words; Choose another and Retry as the reason allows', (tester) async {
      final j = ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error: 'Nothing matched closely enough (best score 0.48, needs 0.62)',
      );
      await pumpBlock(tester);
      expect(find.text("Couldn't add"), findsOneWidget);
      expect(
        find.text('Nothing on YouTube was close enough (best match 48%).'),
        findsOneWidget,
      );
      expect(shown('yt-error-raw'), isFalse);
      await tapKey(tester, 'yt-details');
      expect(
        find.text(
          'Nothing matched closely enough (best score 0.48, needs 0.62)',
        ),
        findsOneWidget,
      );
      expect(shown('yt-choose-another'), isTrue);
      expect(shown('yt-retry'), isTrue);

      // (A poll redraws what it sees change: the error, with the time.)
      j['error'] =
          'the chosen upload is a live stream, not a song — pick another';
      j['updatedAt'] = 2;
      await jobs.refreshJobs();
      await frames(tester);
      expect(
        find.text('That upload is a live stream — pick another.'),
        findsOneWidget,
      );
      expect(shown('yt-choose-another'), isTrue);
      expect(shown('yt-retry'), isFalse);

      j['error'] = 'the recommendation has no artist or title to search for';
      j['updatedAt'] = 3;
      await jobs.refreshJobs();
      await frames(tester);
      expect(
        find.text('This song has no artist or title to search for.'),
        findsOneWidget,
      );
      expect(shown('yt-choose-another'), isFalse);
      expect(shown('yt-retry'), isFalse);
    });

    testWidgets('Retry on a failed add: the same upload again', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('bbbbbbbbbb2'),
        error: 'YouTube download failed: HTTP Error 403: Forbidden',
      );
      await pumpBlock(tester);
      expect(
        find.text("YouTube wouldn't hand it over — try again later."),
        findsOneWidget,
      );
      await tapKey(tester, 'yt-retry');
      expect(fake.starts('youtube').single['choice'], {
        'url': watch('bbbbbbbbbb2'),
      });
      expect(find.text('Waiting for a free slot'), findsOneWidget);
    });

    testWidgets('a Retry refused: its line under the add', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('bbbbbbbbbb2'),
        error: 'YouTube download failed: HTTP Error 403: Forbidden',
      );
      await pumpBlock(tester);
      fake.refuse[_ytJobs] = (
        409,
        'someone else on this server is already getting this',
      );
      await tapKey(tester, 'yt-retry');
      expect(find.text("Couldn't add"), findsOneWidget);
      expect(
        find.text(
          'Someone else on this server is adding this right now — try again '
          'in a moment.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a Retry out: its pill busy, and Choose another inert until '
        'it answers', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error: 'Nothing matched closely enough (best score 0.41, needs 0.62)',
      );
      await pumpBlock(tester);
      fake.startGate = Completer<void>();
      await tapKey(tester, 'yt-retry');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('yt-retry')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'yt-choose-another');
      expect(fake.count('POST', _ytResolve), 0);
      expect(shown('yt-uploads'), isFalse);
      expect(shown('yt-searching-tag'), isFalse);

      fake.startGate!.complete();
      fake.startGate = null;
      await frames(tester);
      expect(fake.starts('youtube'), hasLength(1));
      expect(find.text('Waiting for a free slot'), findsOneWidget);
    });

    testWidgets('a Cancel out: its pill busy; a second press sends nothing', (
      tester,
    ) async {
      final j = ytJob(state: 'queued', choice: watch('aaaaaaaaaa1'));
      await pumpBlock(tester);
      fake.cancelGate = Completer<void>();
      await tapKey(tester, 'yt-cancel');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('yt-cancel')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'yt-cancel');
      fake.cancelGate!.complete();
      fake.cancelGate = null;
      await frames(tester);
      expect(fake.count('POST', '/plugin-jobs/${j['id']}/cancel'), 1);
      expect(toasts, isEmpty, reason: 'no "Already finished" for a 2nd ask');
      expect(find.text('Stopped · nothing was added'), findsOneWidget);
    });

    // An add that named no upload: the server fetched the search's best
    // (youtube.js pickBest) — the first the search here finds again.
    testWidgets('Choose another on an add that named no upload and failed on '
        'the one fetched (too big): the second upload picked', (tester) async {
      ytJob(
        state: 'failed',
        error:
            'YouTube download failed: the file is larger than the 100 MB size '
            'cap, so yt-dlp did not download it',
      );
      await pumpBlock(tester);
      expect(shown('yt-retry'), isFalse);
      await tapKey(tester, 'yt-choose-another');
      expect(shown('yt-candidate-1'), isTrue);
      expect(shown('yt-candidate-0'), isFalse);
      await tapKey(tester, 'yt-add');
      expect(fake.starts('youtube').single['choice'], {
        'url': watch('bbbbbbbbbb2'),
      });
    });

    testWidgets('…one that failed on the search itself (nothing close): the '
        'best stays picked', (tester) async {
      ytJob(
        state: 'failed',
        error: 'Nothing matched closely enough (best score 0.41, needs 0.62)',
      );
      await pumpBlock(tester);
      await tapKey(tester, 'yt-choose-another');
      expect(shown('yt-candidate-0'), isTrue);
      expect(shown('yt-candidate-1'), isFalse);
    });

    testWidgets('Choose another: the search again, landing on the uploads '
        "with the first one other than the failed add's picked", (
      tester,
    ) async {
      ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error: 'Nothing matched closely enough (best score 0.48, needs 0.62)',
      );
      await pumpBlock(tester);
      await tapKey(tester, 'yt-choose-another');
      expect(fake.count('POST', _ytResolve), 1);
      expect(find.text("Couldn't add"), findsNothing);
      expect(shown('yt-candidate-1'), isTrue);
      expect(shown('yt-candidate-0'), isFalse);
      await tapKey(tester, 'yt-add');
      expect(fake.starts('youtube').single['choice'], {
        'url': watch('bbbbbbbbbb2'),
      });
    });

    testWidgets('opened to choose another (autoSearch): the search starts at '
        'once, the failed add set aside — even when the lookup answers '
        'after the search', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error: 'the chosen upload could not be read: Video unavailable',
      );
      fake.lookupGate = Completer<void>();
      await pumpBlock(tester, autoSearch: true);
      expect(fake.count('POST', _ytResolve), 1);
      expect(shown('yt-candidate-0'), isTrue, reason: 'no add known yet');
      fake.lookupGate!.complete();
      fake.lookupGate = null;
      await frames(tester);
      expect(shown('yt-candidate-1'), isTrue);
      expect(shown('yt-candidate-0'), isFalse);
      expect(find.text("Couldn't add"), findsNothing);
    });

    testWidgets('…the user\'s own pick stays', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error: 'the chosen upload could not be read: Video unavailable',
      );
      fake.lookupGate = Completer<void>();
      await pumpBlock(tester, autoSearch: true);
      await tapKey(tester, 'yt-more');
      await tapKey(tester, 'yt-candidate-0');
      fake.lookupGate!.complete();
      fake.lookupGate = null;
      await frames(tester);
      final handle = tester.ensureSemantics();
      expectPicked(tester, 0, true);
      handle.dispose();
    });

    // Copies' Choose another names the row's upload (NetworkKeepSlot.avoidUrl).
    testWidgets('…the upload Copies named is set aside even when the lookup '
        'fails', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error: 'the chosen upload could not be read: Video unavailable',
      );
      fake.refuse['/plugin-jobs/lookup'] = (500, 'the job store is busy');
      await pumpBlock(tester, autoSearch: true, avoidUrl: watch('aaaaaaaaaa1'));
      expect(fake.count('POST', '/plugin-jobs/lookup'), 1);
      expect(shown('yt-candidate-1'), isTrue);
      expect(shown('yt-candidate-0'), isFalse);
    });

    testWidgets("…and over a newer add's upload the lookup finds", (
      tester,
    ) async {
      ytJob(
        state: 'failed',
        choice: watch('bbbbbbbbbb2'),
        error: 'the chosen upload could not be read: Video unavailable',
      );
      await pumpBlock(tester, autoSearch: true, avoidUrl: watch('aaaaaaaaaa1'));
      expect(shown('yt-candidate-1'), isTrue, reason: 'not the named one');
      expect(shown('yt-candidate-0'), isFalse);
      expect(find.text("Couldn't add"), findsNothing, reason: 'set aside');
    });

    testWidgets('…a live add of the song keeps its line', (tester) async {
      ytJob(state: 'running', choice: watch('aaaaaaaaaa1'), progress: 0.5);
      await pumpBlock(tester, autoSearch: true);
      expect(find.text('Fetching from YouTube'), findsNothing);
      expect(shown('yt-job-title'), isTrue);
      expect(shown('yt-uploads'), isFalse);
    });

    testWidgets('an add started before the opening lookup answers keeps its '
        'line over the older add that lookup finds', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('zzzzzzzzzz9'),
        error: 'the chosen upload could not be read: Video unavailable',
      );
      fake.lookupGate = Completer<void>();
      await pumpBlock(tester);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-add');
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      // A server that answered the lookup before the start landed: the
      // older add alone.
      final fresh = fake.jobs.removeAt(0);
      fake.lookupGate!.complete();
      fake.lookupGate = null;
      await frames(tester);
      fake.jobs.insert(0, fresh);
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(find.text("Couldn't add"), findsNothing);
    });
  });

  group('themes', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
    }

    Color colorOf(WidgetTester tester, Finder f) =>
        tester.widget<Text>(f).style!.color!;

    for (final theme in AppTheme.values) {
      testWidgets("${theme.name}: the card's quiet lines read at 4.5:1 on it", (
        tester,
      ) async {
        VelvetColors.setActive(paletteFor(theme));
        addTearDown(() => VelvetColors.setActive(paletteFor(AppTheme.dark)));
        ytJob(state: 'cancelled', choice: watch('aaaaaaaaaa1'));
        await pumpBlock(tester);
        final card = VelvetColors.card;
        void expectReads(Map<String, Finder> lines) {
          for (final MapEntry(key: what, value: f) in lines.entries) {
            expect(
              contrast(colorOf(tester, f), card),
              greaterThanOrEqualTo(4.5),
              reason: what,
            );
          }
        }

        expectReads({
          'what it searches for': find.byKey(const ValueKey('yt-idle')),
          'the cancelled line': find.text('Stopped · nothing was added'),
        });
        await tapKey(tester, 'yt-search');
        expectReads({
          'only the pick': find.byKey(const ValueKey('yt-only-pick')),
          "an upload's channel": find.text('The Quiet Assembly - Topic · 3:58'),
        });
      });
    }
  });

  group('large text', () {
    testWidgets('360 dp at 200 %: the uploads opened and a refusal under '
        'them — nothing overflows', (tester) async {
      await pumpBlock(tester, width: 360, textScale: 2);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-more');
      expect(tester.takeException(), isNull);
      fake.refuse[_ytJobs] = (429, 'slow down');
      await tapKey(tester, 'yt-add');
      expect(shown('yt-refusal'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('…searching, past 20 s', (tester) async {
      fake.resolveGates['youtube'] = Completer<void>();
      await pumpBlock(tester, width: 360, textScale: 2);
      await tapKey(tester, 'yt-search');
      await tester.pump(const Duration(seconds: 23));
      expect(shown('yt-slow-hint'), isTrue);
      expect(tester.takeException(), isNull);
      fake.resolveGates['youtube']!.complete();
      await frames(tester);
    });

    testWidgets('…a failed add', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error: 'Nothing matched closely enough (best score 0.48, needs 0.62)',
      );
      await pumpBlock(tester, width: 360, textScale: 2);
      await tapKey(tester, 'yt-details');
      expect(shown('yt-choose-another'), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('in the sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      bool autoSearch = false,
      Map<String, dynamic>? row,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      jobs = makeJobs();
      final lead = DiscoveryLead.fromServerMap(row ?? netRow())!;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () => DiscoveryKeepRoutes.openNetworkLead(
                    context,
                    jobs,
                    lead,
                    seedTitle: 'Tidewater',
                    autoSearch: autoSearch,
                    onLeadAction: () => leadActions++,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      unawaited(jobs.activate());
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
    }

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(195, 60));
      await frames(tester, 10);
    }

    testWidgets('KEEP A COPY holds the YouTube block; opening asks no '
        'catalogue, only whether the song already has an add', (tester) async {
      await pumpSheet(tester);
      expect(find.text('KEEP A COPY'), findsOneWidget);
      expect(shown('yt-block'), isTrue);
      expect(
        tester.getTopLeft(find.text('KEEP A COPY')).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('yt-block'))).dy),
      );
      expect(
        fake.requests.where((r) => r.url.path.endsWith('/resolve')),
        isEmpty,
      );
      expect(fake.count('POST', _lookup), 1);
      expect(jsonDecode(fake.calls('POST', _lookup).single.body), {
        'recommendation': repaired(),
      });
    });

    testWidgets('a store build: no block', (tester) async {
      youtubeShown = false;
      await pumpSheet(tester);
      expect(find.text('KEEP A COPY'), findsNothing);
      expect(shown('yt-block'), isFalse);
      expect(fake.count('POST', _lookup), 0);
    });

    testWidgets('an add made here: toasted as the sheet closes, and its '
        'line back when the song opens again; Add this one pins once', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-add');
      await tapKey(tester, 'yt-cancel');
      await tapKey(tester, 'yt-add');
      expect(leadActions, 1);
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      await closeSheet(tester);
      expect(toasts, ['Adding Paper Satellites from YouTube']);

      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(shown('yt-search'), isFalse);
      await closeSheet(tester);
    });

    testWidgets('the plug-in gone on a search (404): the section goes, the '
        'gate is read again, a toast says why', (tester) async {
      fake.refuse[_ytResolve] = (404, 'no plug-in youtube');
      await pumpSheet(tester);
      final listings = fake.count('GET', _listing);
      await tapKey(tester, 'yt-search');
      expect(find.text('KEEP A COPY'), findsNothing);
      expect(shown('yt-block'), isFalse);
      expect(fake.count('GET', _listing), greaterThan(listings));
      expect(toasts, ['That option was just switched off on this server.']);
    });

    testWidgets('closed mid-search: the answer that comes after reaches no '
        'one', (tester) async {
      fake.resolveGates['youtube'] = Completer<void>();
      await pumpSheet(tester);
      await tapKey(tester, 'yt-search');
      await tester.pump(const Duration(seconds: 5));
      await closeSheet(tester);
      fake.resolveGates['youtube']!.complete();
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(shown('yt-block'), isFalse);
    });

    testWidgets("Copies' Choose another: the route opens the sheet with the "
        'search running and another upload picked', (tester) async {
      ytJob(
        state: 'failed',
        choice: watch('aaaaaaaaaa1'),
        error:
            'YouTube download failed: File is larger than max-filesize '
            '(the 100 MB size cap)',
      );
      await pumpSheet(tester, autoSearch: true);
      expect(fake.count('POST', _ytResolve), 1);
      expect(shown('yt-candidate-1'), isTrue);
      expect(shown('yt-candidate-0'), isFalse);
      await closeSheet(tester);
    });

    testWidgets("…for an add that named no upload: the second picked (the "
        'server had fetched the first)', (tester) async {
      ytJob(
        state: 'failed',
        error:
            'YouTube download failed: the download passed the 100 MB size cap '
            'and was stopped',
      );
      await pumpSheet(tester, autoSearch: true);
      expect(shown('yt-candidate-1'), isTrue);
      expect(shown('yt-candidate-0'), isFalse);
      await closeSheet(tester);
    });

    testWidgets("a peer's year of 0: the path and Change's preview both "
        'leave the year out, as the server files it', (tester) async {
      fake.destination = {
        ...fake.destination,
        'destination': {
          'vpath': 'copies',
          'base': '',
          'layout': '{{ALBUMARTIST}}/{{YEAR}}',
          'source': 'user',
        },
      };
      await pumpSheet(tester, row: {...netRow(), 'year': 0});
      expect(
        plain(tester, 'yt-destination-path'),
        'Files go to copies › The Quiet Assembly',
      );
      await tapKey(tester, 'yt-change');
      expect(changes.single.$1!.year, isNull);
      await closeSheet(tester);
    });

    testWidgets('Add to queue answered after the sheet closed: its toast '
        'still shows, nothing throws', (tester) async {
      ytJob(
        state: 'done',
        choice: watch('aaaaaaaaaa1'),
        result: {
          'downloaded': {
            'vpath': 'copies',
            'filepath': 'copies/The Quiet Assembly/Paper_Satellites.mp3',
            'bytes': 6710886,
            'format': 'mp3',
          },
        },
      );
      final gate = Completer<void>();
      YoutubeKeepBlock.queue = (row) async {
        await gate.future;
        queued.add(row.data!);
      };
      await pumpSheet(tester);
      await tapKey(tester, 'yt-queue');
      await closeSheet(tester);
      gate.complete();
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(queued, ['/copies/The Quiet Assembly/Paper_Satellites.mp3']);
      expect(toasts, ['1 song added to queue']);
    });

    testWidgets('an add cancelled while it ran ("Stopping…"): no "Adding …" '
        'as the sheet closes', (tester) async {
      await pumpSheet(tester);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-add');
      fake.jobs.first
        ..['state'] = 'running'
        ..['updatedAt'] = 2;
      await jobs.refreshJobs();
      await frames(tester);
      await tapKey(tester, 'yt-cancel');
      expect(find.text('Stopping…'), findsOneWidget);
      await closeSheet(tester);
      expect(toasts, isEmpty);
    });

    testWidgets('Add this one answered after the sheet closed: "Adding … '
        'from YouTube" with View then', (tester) async {
      final actions = <String>[];
      KeepToast.debugActionSink = (m, a, on) => actions.add(a);
      await pumpSheet(tester);
      await tapKey(tester, 'yt-search');
      fake.startGate = Completer<void>();
      await tapKey(tester, 'yt-add');
      await closeSheet(tester);
      expect(toasts, isEmpty);
      fake.startGate!.complete();
      fake.startGate = null;
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(fake.starts('youtube'), hasLength(1));
      expect(toasts, ['Adding Paper Satellites from YouTube']);
      expect(actions, ['View']);
    });

    testWidgets('…and while it animates away', (tester) async {
      await pumpSheet(tester);
      await tapKey(tester, 'yt-search');
      fake.startGate = Completer<void>();
      await tapKey(tester, 'yt-add');
      await tester.tapAt(const Offset(195, 60));
      await tester.pump(const Duration(milliseconds: 20));
      expect(shown('yt-block'), isTrue, reason: 'still on its way out');
      fake.startGate!.complete();
      fake.startGate = null;
      await tester.pump(const Duration(milliseconds: 20));
      await frames(tester, 10);
      expect(toasts, ['Adding Paper Satellites from YouTube']);
    });

    testWidgets('a refusal answered after the sheet closed, or while it '
        'animates away, is a toast', (tester) async {
      await pumpSheet(tester);
      await tapKey(tester, 'yt-search');
      fake.startGate = Completer<void>();
      fake.startAnswer = (429, {'error': 'slow down'});
      await tapKey(tester, 'yt-add');
      await closeSheet(tester);
      fake.startGate!.complete();
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(toasts, ['Too many waiting — let some finish first.']);

      toasts.clear();
      fake.startGate = Completer<void>();
      fake.startAnswer = (
        409,
        {'error': 'someone else on this server is already getting this'},
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      await tapKey(tester, 'yt-search');
      await tapKey(tester, 'yt-add');
      await tester.tapAt(const Offset(195, 60));
      await tester.pump(const Duration(milliseconds: 20));
      expect(shown('yt-block'), isTrue, reason: 'still on its way out');
      fake.startGate!.complete();
      fake.startGate = null;
      await tester.pump(const Duration(milliseconds: 20));
      await frames(tester, 10);
      expect(toasts, [
        'Someone else on this server is adding this right now — try again '
            'in a moment.',
      ]);
    });
  });
}
