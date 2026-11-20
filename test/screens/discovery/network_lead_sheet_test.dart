// The network-lead sheet (the design canvas's NetworkSheet and Degraded
// boards): what a "From the network" row on More like this opens — the
// pinned header ("From the network · Vinyl Vault", "88% match to
// “Tidewater”"), the 30-second previews in each of their states, KEEP A
// COPY's place (the YouTube block itself is slice D2's: here a stub stands
// in through NetworkLeadSheet.keepBlock), Open elsewhere / Open on
// MusicBrainz / Copy title, what opening asks (nothing of a catalogue),
// what closing does (the clip stops, an add it started is toasted), and
// every link that leaves the app ending a clip first.
//
// The plug-in API is the scripted fake behind the real DiscoveryPluginsApi;
// the preview player is the fake one (media/preview_fakes.dart); the URL
// launcher, the toasts and the clipboard are the test's.

import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/elsewhere_sheet.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart'
    show KeepRing;
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/screens/discovery/network_lead_sheet.dart';
import 'package:mstream_music/screens/discovery/network_preview_rows.dart';
import 'package:mstream_music/screens/discovery/peer_recs_previews.dart';
import 'package:mstream_music/screens/discovery/preview_answers.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_rules.dart' show PeerClipStatus;

import '../../media/preview_fakes.dart';
import '../discovery_fixtures.dart';
import '../discovery_plugin_fakes.dart';
import 'peer_recs_fixtures.dart' show parseLeads, tasteJson;

const _dest = '/api/v1/discovery/collection/destination';
const _listing = '/api/v1/discovery/plugins';
const _mbid = '0f3e9b1c-7a2d-4c55-9e11-2b6f0d8a4c11';

/// The canvas's lead: a per-song P2P row as the route hands it out (a raw
/// ISRC tag, no source).
Map<String, dynamic> netRow({
  double similarity = 0.88,
  String? peerName = 'Vinyl Vault',
  String? mbid = _mbid,
}) => {
  'artist': 'The Quiet Assembly',
  'title': 'Paper Satellites',
  'album': 'Static Bloom',
  'year': 2011,
  'duration': 238,
  'similarity': similarity,
  'recordingMbid': ?mbid,
  'isrc': 'US-RC1-76-07839',
  'exportId': 'vv-0042',
  'peer': {'endpointId': 'ab' * 32, 'name': ?peerName},
};

DiscoveryLead leadOf(Map<String, dynamic> row) =>
    DiscoveryLead.fromServerMap(row)!;

/// What every plug-in call sends for [netRow].
Map<String, dynamic> repaired([Map<String, dynamic>? row]) =>
    sendableRecommendation(row ?? netRow(), network: true)!;

Map<String, dynamic> deezerClip() => {
  'provider': 'deezer',
  'url': 'https://cdns-preview.dzcdn.net/stream/paper-satellites.mp3',
  'seconds': 30,
  'title': 'Paper Satellites',
  'artist': 'The Quiet Assembly',
  'album': 'Static Bloom',
  'attribution': 'Preview from Deezer',
  'link': 'https://www.deezer.com/track/31415',
  'artwork': 'https://e-cdns-images.dzcdn.net/images/cover/250x250.jpg',
  'match': 0.97,
};

/// [clip] as a resolve's 200 answers it, read the way the API reads it.
PluginPreview answerOf(Map<String, dynamic> clip) => PluginPreview.ofAnswer({
  'plugin': clip['provider'],
  'result': {'preview': clip},
})!;

Map<String, dynamic> itunesClip() => {
  'provider': 'itunes',
  'url': 'https://audio-ssl.itunes.apple.com/paper-satellites.m4a',
  'seconds': 30,
  'title': 'Paper Satellites',
  'artist': 'The Quiet Assembly',
  'attribution': 'Provided courtesy of iTunes',
  'link': 'https://music.apple.com/album/static-bloom/1?i=2',
  'artwork': 'https://is1-ssl.mzstatic.com/image/100x100bb.jpg',
  'match': 0.9,
};

/// The song side with the app's timing: the handler's Play is numbered at
/// once, but the song's playing flag goes on only later, as the handler's
/// playbackState does.
class _LateFlagPort extends FakePreviewPort {
  @override
  void playSong() {
    touches++;
    plays++;
    log.add('song.play');
    transport.note('play');
    Timer(const Duration(milliseconds: 30), startsByItself);
  }
}

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
  late List<(String, String, VoidCallback)> actions;
  late List<Uri> launched;

  /// How many ends the preview player had seen as each link launched.
  late List<int> endsAtLaunch;
  late bool launchOk;
  late int leadActions;
  late List<DiscoveryLead> elsewhere;
  late List<String> copies;
  late List<NetworkKeepSlot> slots;
  String? clipboard;

  /// How many sheets DiscoveryKeepRoutes.openPeerLead opened have closed.
  late int peerClosed;

  setUp(() {
    server = discoveryServer()
      ..discoveryPluginsAvailable = true
      ..noUpload = false;
    fake = FakePluginServer()..listLeadPlugins();
    timers = FakeTimers();
    preview = FakePreviewPlayer.install();
    youtubeShown = true;
    toasts = [];
    actions = [];
    launched = [];
    endsAtLaunch = [];
    launchOk = true;
    leadActions = 0;
    elsewhere = [];
    copies = [];
    slots = [];
    clipboard = null;
    peerClosed = 0;
    KeepToast.debugSink = (m, {success = false}) => toasts.add(m);
    KeepToast.debugActionSink = (m, a, on) => actions.add((m, a, on));
    elsewhereLaunch = (uri) async {
      launched.add(uri);
      endsAtLaunch.add(preview.ends.length);
      return launchOk;
    };
    DiscoveryKeepRoutes.openElsewhere = (_, _, lead) => elsewhere.add(lead);
    DiscoveryKeepRoutes.openCopies = (_, _) => copies.add('copies');
    NetworkLeadSheet.keepBlock = null;
  });

  tearDown(() {
    KeepToast.debugSink = null;
    KeepToast.debugActionSink = null;
    elsewhereLaunch = defaultLaunch;
    DiscoveryKeepRoutes.reset();
    NetworkLeadSheet.keepBlock = null;
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A stub KEEP A COPY block: what the sheet hands it is kept.
  void stubKeepBlock({double height = 40}) {
    NetworkLeadSheet.keepBlock = (context, slot) {
      slots.add(slot);
      return SizedBox(
        key: const ValueKey('stub-keep-block'),
        height: height,
        child: const Text('youtube block'),
      );
    };
  }

  /// More like this behind the sheet: a button that opens it (through
  /// DiscoveryKeepRoutes.openNetworkLead when [viaRoute], openPeerLead —
  /// Peer Recommendations' card — when [viaPeerRoute], else
  /// showNetworkLeadSheet) for [lead], at 390 × 844, sharing [answers].
  Future<void> pumpSheet(
    WidgetTester tester, {
    DiscoveryLead? lead,
    String? seedTitle = 'Tidewater',
    bool activate = true,
    bool viaRoute = false,
    bool viaPeerRoute = false,
    bool autoSearch = false,
    LeadPreviewAnswers? answers,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    jobs = DiscoveryJobsController(
      server: server,
      api: fake.api(server),
      timer: timers.call,
      watchLifecycle: false,
      youtubeShown: () => youtubeShown,
    );
    final theLead = lead ?? leadOf(netRow());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () {
                  if (viaPeerRoute) {
                    unawaited(
                      DiscoveryKeepRoutes.openPeerLead(
                        context,
                        jobs,
                        theLead,
                        seedTitle: seedTitle,
                        answers: answers,
                      ).then((_) => peerClosed++),
                    );
                  } else if (viaRoute) {
                    DiscoveryKeepRoutes.openNetworkLead(
                      context,
                      jobs,
                      theLead,
                      seedTitle: seedTitle,
                      autoSearch: autoSearch,
                      onLeadAction: () => leadActions++,
                    );
                  } else {
                    unawaited(
                      showNetworkLeadSheet(
                        context,
                        jobs: jobs,
                        lead: theLead,
                        seedTitle: seedTitle,
                        autoSearch: autoSearch,
                        onLeadAction: () => leadActions++,
                        answers: answers,
                      ),
                    );
                  }
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    if (activate) {
      unawaited(jobs.activate());
      await frames(tester);
    }
    await tester.tap(find.byKey(const ValueKey('open')));
    await frames(tester, 8);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f, warnIfMissed: false);
    await frames(tester);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    // The barrier above the sheet's top edge.
    await tester.tapAt(const Offset(195, 60));
    await frames(tester, 10);
  }

  /// The header cover's address, when a preview brought one.
  String? coverUrl(WidgetTester tester) {
    final f = find.descendant(
      of: find.byKey(const ValueKey('lead-cover-art')),
      matching: find.byType(Image),
    );
    if (f.evaluate().isEmpty) return null;
    final image = tester.widget<Image>(f.first).image;
    final provider = image is ResizeImage ? image.imageProvider : image;
    return (provider as NetworkImage).url;
  }

  int resolveCount() =>
      fake.requests.where((r) => r.url.path.endsWith('/resolve')).length;

  group('the frame and the header', () {
    testWidgets('the canvas lead: title, "artist · album · year · length", '
        'where it comes from, how close it sounds to the seed; the '
        "network's tile before any preview", (tester) async {
      await pumpSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Paper Satellites'), findsOneWidget);
      expect(
        find.text('The Quiet Assembly · Static Bloom · 2011 · 3:58'),
        findsOneWidget,
      );
      expect(find.text('From the network · Vinyl Vault'), findsOneWidget);
      expect(find.text('88% match to “Tidewater”'), findsOneWidget);
      expect(find.byKey(const ValueKey('lead-cover-tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('lead-cover-art')), findsNothing);
      // Then the sections, in order.
      expect(find.text('30-SECOND PREVIEW'), findsOneWidget);
      expect(find.text('Deezer'), findsOneWidget);
      expect(find.text('iTunes'), findsOneWidget);
      expect(find.text('Tap to hear 30 seconds'), findsNWidgets(2));
      expect(find.text('Open elsewhere'), findsOneWidget);
      expect(find.text('Copy title'), findsOneWidget);
      expect(
        find.text('Open on MusicBrainz'),
        findsNothing,
        reason: 'Open elsewhere carries MusicBrainz',
      );
      double top(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(top('30-SECOND PREVIEW'), lessThan(top('Open elsewhere')));
      expect(top('Open elsewhere'), lessThan(top('Copy title')));
    });

    testWidgets('no seed title: "88% match"; no similarity (a lead reopened '
        'from a job): no match line; no peer name: "From the network"', (
      tester,
    ) async {
      await pumpSheet(tester, seedTitle: null);
      expect(find.text('88% match'), findsOneWidget);
      await closeSheet(tester);

      await pumpSheet(
        tester,
        lead: leadOf(netRow(similarity: 0, peerName: null)),
        seedTitle: 'Tidewater',
      );
      expect(find.text('From the network'), findsOneWidget);
      expect(find.textContaining('match'), findsNothing);
    });

    testWidgets('the header reads the row as it is sent: a peer\'s year of 0 '
        'is no year', (tester) async {
      await pumpSheet(tester, lead: leadOf({...netRow(), 'year': 0}));
      expect(
        find.text('The Quiet Assembly · Static Bloom · 3:58'),
        findsOneWidget,
      );
      expect(find.textContaining('· 0 ·'), findsNothing);
    });

    testWidgets('opening asks no catalogue — only where files land, from the '
        "user's own server", (tester) async {
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester, activate: false);
      // Nothing was read before it opened; it read the listing (activate)
      // and the destination afresh.
      expect(resolveCount(), 0);
      expect(fake.count('GET', _dest), greaterThanOrEqualTo(1));
      final before = fake.count('GET', _dest);
      await closeSheet(tester);
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      expect(
        fake.count('GET', _dest),
        before + 1,
        reason: 'read again with every open',
      );
      expect(resolveCount(), 0);
      expect(
        fake.requests.map((r) => r.url.host).toSet(),
        {'music.example'},
        reason: "only the user's own server",
      );
    });

    testWidgets('it opens at 0.62 of the screen; dragged up it grows to 0.94 '
        'and its sections scroll under the pinned header', (tester) async {
      stubKeepBlock(height: 1600);
      await pumpSheet(tester);
      final sheet = find.byKey(const ValueKey('network-lead-sheet'));
      expect(tester.getTopLeft(sheet).dy, closeTo(844 * (1 - 0.62), 1.5));

      // The first drag grows the sheet, the next scrolls what it holds.
      await tester.drag(find.text('30-SECOND PREVIEW'), const Offset(0, -400));
      await tester.pumpAndSettle();
      final sheetTop = tester.getTopLeft(sheet).dy;
      expect(sheetTop, closeTo(844 * (1 - 0.94), 1.5));
      await tester.dragFrom(const Offset(195, 600), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(sheet).dy, sheetTop);
      final header = find.byKey(const ValueKey('network-lead-header'));
      expect(tester.getTopLeft(header).dy, closeTo(sheetTop + 22, 1));
      expect(
        tester.getTopLeft(find.text('30-SECOND PREVIEW')).dy,
        lessThan(tester.getBottomLeft(header).dy),
        reason: 'scrolled under the header',
      );
    });

    testWidgets('closing stops the clip (the song it paused comes back)', (
      tester,
    ) async {
      await pumpSheet(tester);
      await closeSheet(tester);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsNothing);
      expect(preview.ends, [PreviewEnd.sheetClosed]);
    });

    testWidgets('while open it holds the fast poll, and lets go as it closes', (
      tester,
    ) async {
      fake.addJob(
        repaired(),
        plugin: 'youtube',
        state: 'running',
        choice: {'url': 'https://www.youtube.com/watch?v=aaaaaaaaaa1'},
        progress: 0.4,
      );
      stubKeepBlock();
      await pumpSheet(tester);
      expect(jobs.anyLive, isTrue);
      expect(jobs.pollBeat, DiscoveryJobsController.kFastBeat);
      await closeSheet(tester);
      // No Discover page in this rig, and the controller counts as on it
      // by default: back to Discover's beat.
      expect(jobs.pollBeat, DiscoveryJobsController.kDiscoverBeat);
    });
  });

  group('30-SECOND PREVIEW', () {
    testWidgets('a press asks the plug-in (looking up, presses ignored), '
        'then plays its clip: "0:12 of 0:30 · …", the match, the '
        'attribution and the store link; a press stops it, the next plays '
        'it again without asking again', (tester) async {
      final semantics = tester.ensureSemantics();
      fake.previews['deezer'] = deezerClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester);
      expect(
        find.bySemanticsLabel(RegExp('^Play the Deezer preview')),
        findsOneWidget,
      );

      await tapKey(tester, 'lead-preview-deezer');
      expect(find.text('Looking up…'), findsOneWidget);
      expect(
        fake.resolves('deezer'),
        [
          {'recommendation': repaired()},
        ],
        reason: 'exactly {recommendation}, the row repaired',
      );
      expect(
        fake.resolves('deezer').single['recommendation']['isrc'],
        'USRC17607839',
      );
      expect(fake.resolves('deezer').single['recommendation']['source'], 'p2p');
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1), reason: 'ignored');
      expect(preview.plays, isEmpty);

      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(preview.plays.single.provider, 'deezer');
      expect(
        preview.plays.single.url.toString(),
        'https://cdns-preview.dzcdn.net/stream/paper-satellites.mp3',
      );
      expect(leadActions, 1, reason: 'the first lead action pins the seed');
      // Before the clip knows its length: the answer's 30 s.
      expect(
        find.text('0:00 of 0:30 · Paper Satellites · The Quiet Assembly'),
        findsOneWidget,
      );
      preview.emit(
        const PreviewClipState(
          provider: 'deezer',
          phase: PreviewPhase.playing,
          position: Duration(seconds: 12),
          duration: Duration(seconds: 30),
        ),
      );
      await frames(tester, 2);
      expect(
        find.text('0:12 of 0:30 · Paper Satellites · The Quiet Assembly'),
        findsOneWidget,
      );
      expect(find.text('match 97%'), findsOneWidget);
      expect(find.text('Preview from Deezer'), findsOneWidget);
      expect(find.byTooltip('Open in Deezer'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Stop the Deezer preview')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.ends, [PreviewEnd.stopped]);
      expect(
        find.text('Paper Satellites · The Quiet Assembly'),
        findsOneWidget,
        reason: 'what it matched stays',
      );
      expect(find.byTooltip('Open in Deezer'), findsOneWidget);

      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.plays, hasLength(2));
      expect(fake.resolves('deezer'), hasLength(1), reason: 'not asked again');
      expect(leadActions, 1, reason: 'once a sheet');
      semantics.dispose();
    });

    testWidgets('no preview found disables the row for the sheet', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      expect(find.text('No preview found'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('lead-preview-itunes')))
            .opacity,
        0.45,
      );
      expect(
        find.bySemanticsLabel(RegExp('iTunes preview')),
        findsNothing,
        reason: 'no button to a screen reader',
      );
      await tapKey(tester, 'lead-preview-itunes');
      expect(fake.resolves('itunes'), hasLength(1));
      expect(preview.plays, isEmpty);
      semantics.dispose();
    });

    testWidgets('busy (429) and unavailable (502, a timeout, a clip that '
        'would not load) ask again on the next press', (tester) async {
      await pumpSheet(tester);
      fake.refuse['/plugins/deezer/resolve'] = (429, 'too many lookups');
      await tapKey(tester, 'lead-preview-deezer');
      expect(find.text('Busy — try again in a minute'), findsOneWidget);

      fake.refuse['/plugins/deezer/resolve'] = (
        502,
        'plug-in deezer could not resolve this recommendation',
      );
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(2));
      expect(find.text('Unavailable right now'), findsOneWidget);

      // The clip itself fails: unavailable, and the next press asks afresh.
      fake.refuse.clear();
      fake.previews['deezer'] = deezerClip();
      preview.outcome = PreviewPlayOutcome.failed;
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(3));
      expect(preview.plays, hasLength(1));
      expect(find.text('Unavailable right now'), findsOneWidget);

      preview.outcome = PreviewPlayOutcome.playing;
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(4));
      expect(preview.plays, hasLength(2));
      expect(
        find.text('0:00 of 0:30 · Paper Satellites · The Quiet Assembly'),
        findsOneWidget,
      );
    });

    testWidgets('a clip that breaks while playing reads unavailable', (
      tester,
    ) async {
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      preview.emit(
        const PreviewClipState(provider: 'deezer', phase: PreviewPhase.failed),
      );
      await frames(tester);
      expect(find.text('Unavailable right now'), findsOneWidget);
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(2), reason: 'asked afresh');
    });

    testWidgets('a plug-in gone on a press (404): its row goes, the gate is '
        'read again, and the user is told', (tester) async {
      await pumpSheet(tester);
      final listings = fake.count('GET', _listing);
      fake.refuse['/plugins/deezer/resolve'] = (404, 'no plug-in deezer');
      await tapKey(tester, 'lead-preview-deezer');
      expect(find.byKey(const ValueKey('lead-preview-deezer')), findsNothing);
      expect(find.text('iTunes'), findsOneWidget);
      expect(toasts, ['That option was just switched off on this server.']);
      expect(fake.count('GET', _listing), listings + 1);
      expect(
        find.byKey(const ValueKey('lead-preview-deezer')),
        findsNothing,
        reason: 'gone for the sheet, whatever the listing says now',
      );
    });

    testWidgets("the header takes a preview's cover, Deezer's before "
        "iTunes'", (tester) async {
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      expect(
        coverUrl(tester),
        'https://is1-ssl.mzstatic.com/image/100x100bb.jpg',
      );
      await tapKey(tester, 'lead-preview-deezer');
      expect(
        coverUrl(tester),
        'https://e-cdns-images.dzcdn.net/images/cover/250x250.jpg',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('one clip at a time: another row switches (no stop between: '
        'the song stays paused)', (tester) async {
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      await tapKey(tester, 'lead-preview-itunes');
      expect([for (final p in preview.plays) p.provider], ['deezer', 'itunes']);
      expect(preview.ends, isEmpty);
      expect(find.text('Tap to hear 30 seconds'), findsNothing);
      expect(
        find.text('Paper Satellites · The Quiet Assembly'),
        findsOneWidget,
        reason: "Deezer's row is back to what it matched",
      );
      expect(find.text('match 90%'), findsOneWidget);
      expect(find.text('Provided courtesy of iTunes'), findsOneWidget);
    });

    testWidgets('a store link ends the clip as leaving the app, then opens; '
        'one that will not open says so', (tester) async {
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      await tester.tap(find.byTooltip('Open in Apple Music'));
      await frames(tester);
      expect(launched.single.toString(), itunesClip()['link']);
      expect(preview.ends, [PreviewEnd.leftApp]);
      expect(endsAtLaunch, [1], reason: 'ended before it launched');
      expect(toasts, isEmpty);

      launchOk = false;
      await tester.tap(find.byTooltip('Open in Apple Music'));
      await frames(tester);
      expect(toasts, ["Couldn't open that link"]);
      expect(preview.resumed, isEmpty, reason: 'no clip held the song');

      // …and while a clip plays: the song it paused comes back (the user
      // never left).
      await tapKey(tester, 'lead-preview-itunes');
      expect(preview.plays, hasLength(2));
      await tester.tap(find.byTooltip('Open in Apple Music'));
      await frames(tester);
      expect(preview.ends.last, PreviewEnd.leftApp);
      expect(preview.resumed, [FakePreviewPlayer.kFakeHold]);
      expect(toasts, ["Couldn't open that link", "Couldn't open that link"]);
    });

    testWidgets('while its clip loads: a ring, read as Stop, and a press '
        'stops it', (tester) async {
      final semantics = tester.ensureSemantics();
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      preview.emit(
        const PreviewClipState(provider: 'deezer', phase: PreviewPhase.loading),
      );
      await frames(tester, 2);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lead-preview-deezer')),
          matching: find.byType(KeepRing),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Stop the Deezer preview')),
        findsOneWidget,
      );

      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.ends, [PreviewEnd.stopped]);
      expect(preview.plays, hasLength(1));
      semantics.dispose();
    });

    // A lookup can outlive what tells the sheet to keep quiet: what it
    // found then waits for a press. The real player ends a playing clip for
    // a call or the output dropping (preview_player_test); here the fake
    // stands in for those ends.
    final quiet = <String, (bool, Future<void> Function(WidgetTester))>{
      'the app went to the background': (
        false,
        (_) async => preview.appVisible = false,
      ),
      'a call': (true, (_) => preview.end(PreviewEnd.interrupted)),
      'the output dropped': (true, (_) => preview.end(PreviewEnd.outputLost)),
      'a store link opened': (
        false,
        (t) async {
          await t.tap(find.byTooltip('Open in Apple Music'));
          await frames(t);
        },
      ),
    };
    for (final MapEntry(key: what, value: (playing, happen)) in quiet.entries) {
      testWidgets('a lookup that outlives $what plays nothing it found: the '
          'row waits for a press', (tester) async {
        fake.previews['deezer'] = deezerClip();
        fake.previews['itunes'] = itunesClip();
        await pumpSheet(tester);
        await tapKey(tester, 'lead-preview-itunes');
        if (!playing) await tapKey(tester, 'lead-preview-itunes'); // stopped
        fake.resolveGates['deezer'] = Completer<void>();
        await tapKey(tester, 'lead-preview-deezer');
        expect(find.text('Looking up…'), findsOneWidget);

        await happen(tester);
        fake.resolveGates.remove('deezer')!.complete();
        await frames(tester);
        expect([for (final p in preview.plays) p.provider], ['itunes']);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('lead-preview-line-deezer')),
              )
              .data,
          'Paper Satellites · The Quiet Assembly',
          reason: 'found, not playing',
        );

        preview.appVisible = true;
        await tapKey(tester, 'lead-preview-deezer');
        expect(
          [for (final p in preview.plays) p.provider],
          ['itunes', 'deezer'],
        );
        expect(fake.resolves('deezer'), hasLength(1));
      });
    }

    testWidgets('a lookup that answers after the sheet closed plays nothing', (
      tester,
    ) async {
      fake.previews['deezer'] = deezerClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      expect(find.text('Looking up…'), findsOneWidget);
      await closeSheet(tester);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(preview.plays, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lookup that answers after another row was pressed plays '
        'nothing: the row pressed last plays', (tester) async {
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      await tapKey(tester, 'lead-preview-itunes');
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect([for (final p in preview.plays) p.provider], ['itunes']);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('lead-preview-line-deezer')),
            )
            .data,
        'Paper Satellites · The Quiet Assembly',
        reason: 'found, waiting for a press',
      );
    });

    testWidgets('a clip that would not play keeps its store link and the '
        'attribution Apple asks for beside it', (tester) async {
      fake.previews['itunes'] = itunesClip();
      preview.outcome = PreviewPlayOutcome.failed;
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      expect(find.text('Unavailable right now'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lead-preview-link-itunes')),
        findsOneWidget,
      );
      expect(find.text('Provided courtesy of iTunes'), findsOneWidget);

      // …and while it is asked again.
      fake.resolveGates['itunes'] = Completer<void>();
      await tapKey(tester, 'lead-preview-itunes');
      expect(find.text('Looking up…'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lead-preview-link-itunes')),
        findsOneWidget,
      );
      expect(find.text('Provided courtesy of iTunes'), findsOneWidget);
      fake.resolveGates.remove('itunes')!.complete();
      await frames(tester);
    });

    testWidgets('a lookup that outlives the other clip ending on its own '
        'still plays', (tester) async {
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      fake.resolveGates['deezer'] = Completer<void>();
      await tapKey(tester, 'lead-preview-deezer');
      await preview.end(PreviewEnd.completed);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect([for (final p in preview.plays) p.provider], ['itunes', 'deezer']);
    });

    for (final theme in AppTheme.values) {
      testWidgets("${theme.name}: a row's second line reads at 4.5:1 on its "
          'card', (tester) async {
        VelvetColors.setActive(paletteFor(theme));
        addTearDown(() => VelvetColors.setActive(paletteFor(AppTheme.dark)));
        await pumpSheet(tester);
        final line = tester.widget<Text>(
          find.byKey(const ValueKey('lead-preview-line-deezer')),
        );
        final a = line.style!.color!.computeLuminance();
        final b = VelvetColors.card.computeLuminance();
        final ratio = ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('a preview plug-in other than Deezer or iTunes goes by its '
        'title', (tester) async {
      fake.listing = {
        'plugins': [
          {
            'name': 'clipper',
            'title': 'Clip Box',
            'capabilities': ['preview'],
            'scopes': ['song'],
          },
        ],
        'jobs': {'allowed': true},
      };
      await pumpSheet(tester);
      expect(find.text('Clip Box'), findsOneWidget);
      expect(find.text('Tap to hear 30 seconds'), findsOneWidget);
    });

    test('row names and store names', () {
      expect(
        [
          for (final n in ['deezer', 'itunes', 'clipper'])
            previewProviderLabel(DiscoveryPlugin(name: n, title: 'Clip Box')),
        ],
        ['Deezer', 'iTunes', 'Clip Box'],
      );
      expect(
        [
          for (final n in ['deezer', 'itunes', 'clipper'])
            previewStoreName(DiscoveryPlugin(name: n, title: 'Clip Box')),
        ],
        ['Deezer', 'Apple Music', 'Clip Box'],
      );
    });
  });

  group('KEEP A COPY', () {
    testWidgets('while where files land is still asked: its label and a '
        'skeleton where the block goes; once the gate is ready, the block, '
        'handed what it needs', (tester) async {
      stubKeepBlock();
      fake.destinationGate = Completer<void>();
      await pumpSheet(tester);
      expect(find.text('KEEP A COPY'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-skeleton')), findsOneWidget);
      expect(find.byKey(const ValueKey('stub-keep-block')), findsNothing);

      fake.destinationGate!.complete();
      fake.destinationGate = null;
      await frames(tester);
      expect(find.byKey(const ValueKey('keep-skeleton')), findsNothing);
      expect(find.text('youtube block'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('KEEP A COPY')).dy,
        lessThan(tester.getTopLeft(find.text('youtube block')).dy),
      );
      expect(
        tester.getTopLeft(find.text('30-SECOND PREVIEW')).dy,
        lessThan(tester.getTopLeft(find.text('KEEP A COPY')).dy),
      );
      final slot = slots.last;
      expect(identical(slot.jobs, jobs), isTrue);
      expect(slot.lead.raw, repaired());
      expect(slot.lead.title, 'Paper Satellites');
      expect(slot.autoSearch, isFalse);
    });

    testWidgets('left out, never greyed: youtube not listed, a store build, '
        'no upload right, no library', (tester) async {
      Future<void> expectNone(String why) async {
        expect(find.text('KEEP A COPY'), findsNothing, reason: why);
        expect(find.text('youtube block'), findsNothing, reason: why);
        expect(find.text('30-SECOND PREVIEW'), findsOneWidget, reason: why);
        await closeSheet(tester);
      }

      stubKeepBlock();
      fake = FakePluginServer()..listLeadPlugins(youtube: false);
      await pumpSheet(tester);
      await expectNone('not listed');

      fake = FakePluginServer()..listLeadPlugins();
      youtubeShown = false;
      await pumpSheet(tester);
      await expectNone('a store build');
      youtubeShown = true;

      server.noUpload = true;
      await pumpSheet(tester);
      await expectNone('no upload right');
      server.noUpload = false;

      fake.destination = {...fake.destination, 'destination': null};
      await pumpSheet(tester);
      await expectNone('no library');
      expect(slots, isEmpty);
    });

    testWidgets("the block's lead actions pin once; a refusal on a press "
        'takes the section away, reads the gate again and says why', (
      tester,
    ) async {
      stubKeepBlock();
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester);
      slots.last.onLeadAction();
      slots.last.onLeadAction();
      await tapKey(tester, 'lead-preview-deezer');
      expect(leadActions, 1);

      final listings = fake.count('GET', _listing);
      slots.last.onRefused(
        'Adding songs was just turned off for your account.',
      );
      await frames(tester);
      expect(find.text('KEEP A COPY'), findsNothing);
      expect(find.text('youtube block'), findsNothing);
      expect(toasts, ['Adding songs was just turned off for your account.']);
      expect(fake.count('GET', _listing), listings + 1);
    });

    testWidgets('an add it started is toasted once the sheet closes: '
        '"Adding … from YouTube" with View while it runs', (tester) async {
      stubKeepBlock();
      await pumpSheet(tester);
      final job = DiscoveryJob.fromServerMap(
        fake.addJob(
          repaired(),
          plugin: 'youtube',
          state: 'running',
          choice: {'url': 'https://www.youtube.com/watch?v=abc123def45'},
        ),
      )!;
      slots.last.onStarted(job);
      expect(toasts, isEmpty, reason: 'not while the sheet is open');
      await closeSheet(tester);
      expect(toasts, ['Adding Paper Satellites from YouTube']);
      expect(actions.single.$2, 'View');
      actions.single.$3();
      expect(copies, ['copies']);
    });

    testWidgets('…and with its ending once it already ended', (tester) async {
      stubKeepBlock();
      await pumpSheet(tester);
      final job = DiscoveryJob.fromServerMap(
        fake.addJob(
          repaired(),
          plugin: 'youtube',
          state: 'done',
          result: {
            'skipped': 'owned',
            'existing': {'vpath': 'copies', 'filepath': 'copies/a.mp3'},
          },
        ),
      )!;
      slots.last.onStarted(job);
      await closeSheet(tester);
      expect(toasts, ['Already in your library']);
      expect(actions, isEmpty);
    });
  });

  group('Open elsewhere, MusicBrainz, Copy title', () {
    testWidgets('Open elsewhere hands its sheet the repaired row; the clip '
        'plays on while it is open', (tester) async {
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      await tapKey(tester, 'lead-elsewhere');
      expect(elsewhere.single.raw, repaired());
      expect(elsewhere.single.title, 'Paper Satellites');
      expect(preview.ends, isEmpty);
    });

    testWidgets("Open elsewhere's links end a clip as leaving the app before "
        'they open', (tester) async {
      // The real sub-sheet over this one.
      DiscoveryKeepRoutes.reset();
      fake.links = [
        {
          'id': 'bandcamp-search',
          'label': 'Search Bandcamp',
          'url': 'https://bandcamp.com/search?q=Paper%20Satellites',
          'kind': 'search',
        },
      ];
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      await tapKey(tester, 'lead-elsewhere');
      await frames(tester, 6);
      expect(
        fake.calls('POST', '/plugins/links/resolve').single.body,
        contains('USRC17607839'),
      );
      await tester.tap(find.text('Bandcamp'));
      await frames(tester);
      expect(launched.single.toString(), fake.links.single['url']);
      expect(preview.ends, [PreviewEnd.leftApp]);
      expect(endsAtLaunch, [1]);

      // A screen reader's (or Switch Access's) activation opens it too.
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(
        find.byKey(const ValueKey('elsewhere-link-bandcamp-search')),
      );
      expect(node, isSemantics(label: 'Bandcamp', hasTapAction: true));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await frames(tester);
      expect(launched, hasLength(2));
      handle.dispose();
    });

    testWidgets('without the links plug-in: Open on MusicBrainz for a row '
        'naming its recording — the clip ends first; none without one', (
      tester,
    ) async {
      fake.listing = {
        'plugins': [FakePluginServer.deezerPlugin],
        'jobs': {'allowed': true},
      };
      await pumpSheet(tester);
      expect(find.text('Open elsewhere'), findsNothing);
      await tapKey(tester, 'lead-musicbrainz');
      expect(
        launched.single.toString(),
        'https://musicbrainz.org/recording/$_mbid',
      );
      expect(preview.ends, [PreviewEnd.leftApp]);
      expect(endsAtLaunch, [1]);
      launchOk = false;
      await tapKey(tester, 'lead-musicbrainz');
      expect(toasts, ["Couldn't open that link"]);
      await closeSheet(tester);

      await pumpSheet(tester, lead: leadOf(netRow(mbid: null)));
      expect(find.text('Open on MusicBrainz'), findsNothing);
      expect(find.text('Open elsewhere'), findsNothing);
      expect(find.text('Copy title'), findsOneWidget);
    });

    testWidgets('Copy title: "Artist - Title" on the clipboard, and says so', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tapKey(tester, 'lead-copy-title');
      expect(clipboard, 'The Quiet Assembly - Paper Satellites');
      expect(toasts, ['Copied to clipboard']);
    });

    testWidgets('no preview plug-ins: no PREVIEW section', (tester) async {
      fake.listing = {
        'plugins': [
          {
            'name': 'links',
            'title': 'Open elsewhere',
            'capabilities': ['links'],
            'scopes': ['song'],
          },
        ],
        'jobs': {'allowed': true},
      };
      await pumpSheet(tester);
      expect(find.text('30-SECOND PREVIEW'), findsNothing);
      expect(find.text('Open elsewhere'), findsOneWidget);
    });
  });

  // A sheet opened from Peer Recommendations, over the one preview player
  // the page plays on too (mStream plan §2 item 15: one window for every
  // network lead, its previews shared with the page).
  group('beside Peer Recommendations', () {
    String? lineOf(WidgetTester tester, String plugin) => tester
        .widget<Text>(find.byKey(ValueKey('lead-preview-line-$plugin')))
        .data;

    testWidgets('a page-owned clip never reads as playing on the sheet', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final page = Object();
      await pumpSheet(tester);
      preview.emit(
        PreviewClipState(
          provider: 'deezer',
          phase: PreviewPhase.playing,
          position: const Duration(seconds: 12),
          duration: const Duration(seconds: 30),
          owner: page,
        ),
      );
      await frames(tester, 2);
      expect(find.text('Tap to hear 30 seconds'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(RegExp('^Play the Deezer preview')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Stop the Deezer preview')),
        findsNothing,
      );

      // …nor its loading, nor its failing: a row that found its clip
      // keeps what it matched.
      fake.previews['deezer'] = deezerClip();
      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.plays.single.owner, isA<NetworkPreviews>());
      for (final phase in [PreviewPhase.loading, PreviewPhase.failed]) {
        preview.emit(
          PreviewClipState(provider: 'deezer', phase: phase, owner: page),
        );
        await frames(tester, 2);
        expect(
          lineOf(tester, 'deezer'),
          'Paper Satellites · The Quiet Assembly',
          reason: phase.name,
        );
      }
      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.plays, hasLength(2), reason: 'a press plays it again');
      expect(fake.resolves('deezer'), hasLength(1));
      semantics.dispose();
    });

    testWidgets('closing the sheet leaves a page clip playing', (
      tester,
    ) async {
      final page = Object();
      final playing = PreviewClipState(
        provider: 'deezer',
        phase: PreviewPhase.playing,
        owner: page,
      );
      await pumpSheet(tester);
      preview.emit(playing);
      await frames(tester, 2);
      final before = preview.endCount;
      await closeSheet(tester);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsNothing);
      expect(preview.ends, isEmpty);
      expect(preview.endCount, before);
      expect(preview.endCalls.single.reason, PreviewEnd.sheetClosed);
      expect(preview.endCalls.single.owner, isA<NetworkPreviews>());
      expect(preview.state.value, playing);
    });

    testWidgets('closing the sheet with nothing playing does not move '
        'endCount; with its own clip playing, it ends it', (tester) async {
      await pumpSheet(tester);
      final before = preview.endCount;
      await closeSheet(tester);
      expect(
        preview.ends,
        [PreviewEnd.sheetClosed],
        reason: 'it still frees the clip player',
      );
      expect(preview.endCount, before, reason: "nobody's lookup silenced");

      fake.previews['deezer'] = deezerClip();
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      await tapKey(tester, 'lead-preview-deezer');
      await closeSheet(tester);
      expect(preview.ends, [PreviewEnd.sheetClosed, PreviewEnd.sheetClosed]);
      expect(preview.endCount, before + 1);
      expect(preview.state.value, PreviewClipState.idle);
    });

    testWidgets('a stored found answer seeds the row: stopped, a press plays '
        'it with no resolve', (tester) async {
      final store = PreviewAnswers()
        ..put('lead-1', 'deezer', answerOf(deezerClip()))
        ..put('lead-2', 'itunes', null);
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      expect(lineOf(tester, 'deezer'), 'Paper Satellites · The Quiet Assembly');
      expect(find.text('match 97%'), findsOneWidget);
      expect(find.text('Preview from Deezer'), findsOneWidget);
      expect(find.byTooltip('Open in Deezer'), findsOneWidget);
      expect(
        coverUrl(tester),
        'https://e-cdns-images.dzcdn.net/images/cover/250x250.jpg',
      );
      expect(
        lineOf(tester, 'itunes'),
        'Tap to hear 30 seconds',
        reason: "another lead's answer is not this one's",
      );

      await tapKey(tester, 'lead-preview-deezer');
      expect(resolveCount(), 0);
      expect(preview.plays.single.provider, 'deezer');
      expect(preview.plays.single.url.toString(), deezerClip()['url']);
      expect(preview.plays.single.owner, isA<NetworkPreviews>());
      expect(leadActions, 1);
      expect(
        lineOf(tester, 'deezer'),
        '0:00 of 0:30 · Paper Satellites · The Quiet Assembly',
      );
    });

    testWidgets('a stored none reads No preview found', (tester) async {
      final store = PreviewAnswers()..put('lead-1', 'itunes', null);
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      expect(find.text('No preview found'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('lead-preview-itunes')))
            .opacity,
        0.45,
      );
      await tapKey(tester, 'lead-preview-itunes');
      expect(resolveCount(), 0);
      expect(preview.plays, isEmpty);
      expect(lineOf(tester, 'deezer'), 'Tap to hear 30 seconds');
    });

    testWidgets('a 200 answer (found and none) is written to the store; a 429 '
        'or 502 is not', (tester) async {
      final store = PreviewAnswers();
      var told = 0;
      store.addListener(() => told++);
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));

      fake.refuse['/plugins/deezer/resolve'] = (429, 'too many lookups');
      await tapKey(tester, 'lead-preview-deezer');
      expect(find.text('Busy — try again in a minute'), findsOneWidget);
      fake.refuse['/plugins/deezer/resolve'] = (
        502,
        'plug-in deezer could not resolve this recommendation',
      );
      await tapKey(tester, 'lead-preview-deezer');
      expect(find.text('Unavailable right now'), findsOneWidget);
      expect(store.length, 0);
      expect(told, 0);

      fake.refuse.clear();
      await tapKey(tester, 'lead-preview-deezer');
      expect(
        store.of('lead-1', 'deezer')!.found!.url.toString(),
        deezerClip()['url'],
      );
      await tapKey(tester, 'lead-preview-itunes');
      expect(find.text('No preview found'), findsOneWidget);
      expect(store.of('lead-1', 'itunes')!.none, isTrue);
      expect(told, 2);
      expect(fake.resolves('deezer'), hasLength(3));
      expect(fake.resolves('itunes'), hasLength(1));
    });

    testWidgets('a lookup that answers after the sheet closed still tells '
        'the store, and plays nothing', (tester) async {
      final store = PreviewAnswers();
      fake.previews['deezer'] = deezerClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      await tapKey(tester, 'lead-preview-deezer');
      await closeSheet(tester);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(store.of('lead-1', 'deezer')?.found, isNotNull);
      expect(preview.plays, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a press re-checks the store', (tester) async {
      final store = PreviewAnswers();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      expect(lineOf(tester, 'deezer'), 'Tap to hear 30 seconds');
      // The page answers while the sheet is open.
      store
        ..put('lead-1', 'deezer', answerOf(deezerClip()))
        ..put('lead-1', 'itunes', null);
      await frames(tester, 2);

      await tapKey(tester, 'lead-preview-deezer');
      expect(resolveCount(), 0);
      expect(preview.plays.single.provider, 'deezer');
      expect(
        lineOf(tester, 'deezer'),
        '0:00 of 0:30 · Paper Satellites · The Quiet Assembly',
      );
      expect(leadActions, 1);

      await tapKey(tester, 'lead-preview-itunes');
      expect(resolveCount(), 0);
      expect(find.text('No preview found'), findsOneWidget);
      expect(preview.plays, hasLength(1));
      expect(preview.ends, isEmpty, reason: "Deezer's clip plays on");
    });

    testWidgets('a shared answer whose clip fails reads unavailable; the next '
        'press asks the plug-in again, and its 200 replaces the answer', (
      tester,
    ) async {
      // The page's answer, its signed CDN address expired since.
      final stale = {
        ...deezerClip(),
        'url': 'https://cdns-preview.dzcdn.net/stream/expired.mp3',
      };
      final store = PreviewAnswers()..put('lead-1', 'deezer', answerOf(stale));
      var told = 0;
      store.addListener(() => told++);
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      preview.outcome = PreviewPlayOutcome.failed;
      await tapKey(tester, 'lead-preview-deezer');
      expect(resolveCount(), 0);
      expect(preview.plays.single.url.toString(), stale['url']);
      expect(lineOf(tester, 'deezer'), 'Unavailable right now');
      expect(
        store.of('lead-1', 'deezer'),
        isNull,
        reason: 'the visit forgets the dead address (the page asks again)',
      );
      expect(told, 1);

      preview.outcome = PreviewPlayOutcome.playing;
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(
        store.of('lead-1', 'deezer')!.found!.url.toString(),
        deezerClip()['url'],
        reason: 'the page plays the new address too',
      );
      expect(preview.plays.last.url.toString(), deezerClip()['url']);
      expect(
        lineOf(tester, 'deezer'),
        '0:00 of 0:30 · Paper Satellites · The Quiet Assembly',
      );

      // The clip breaking while it plays: the same.
      preview.emit(
        const PreviewClipState(provider: 'deezer', phase: PreviewPhase.failed),
      );
      await frames(tester);
      expect(lineOf(tester, 'deezer'), 'Unavailable right now');
      expect(store.of('lead-1', 'deezer'), isNull);
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(2));
      expect(preview.plays, hasLength(3));
    });

    testWidgets('a clip the row found itself that fails: the visit forgets '
        'it too, and the next press asks again, as it does with no shared '
        'answers', (tester) async {
      final store = PreviewAnswers();
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      preview.outcome = PreviewPlayOutcome.failed;
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(store.of('lead-1', 'deezer'), isNull, reason: 'kept, then forgotten');
      expect(lineOf(tester, 'deezer'), 'Unavailable right now');

      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(2));
      expect(preview.plays, hasLength(2));
      expect(lineOf(tester, 'deezer'), 'Unavailable right now');

      // A clip that plays is kept, and replayed with no lookup.
      preview.outcome = PreviewPlayOutcome.playing;
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(3));
      await tapKey(tester, 'lead-preview-deezer'); // stops it
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(3), reason: 'found: replayed');
      expect(preview.plays, hasLength(4));
    });

    // The page's answer for Deezer, its signed CDN address expired since.
    Map<String, dynamic> expiredClip() => {
      ...deezerClip(),
      'url': 'https://cdns-preview.dzcdn.net/stream/expired.mp3',
    };

    /// A sheet over a stored expired clip, pressed once: the clip fails and
    /// the row reads unavailable. The plug-in would answer the live clip.
    Future<PreviewAnswers> failStoredClip(WidgetTester tester) async {
      final store = PreviewAnswers()
        ..put('lead-1', 'deezer', answerOf(expiredClip()));
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      preview.outcome = PreviewPlayOutcome.failed;
      await tapKey(tester, 'lead-preview-deezer');
      expect(resolveCount(), 0);
      expect(preview.plays.single.url.toString(), expiredClip()['url']);
      expect(lineOf(tester, 'deezer'), 'Unavailable right now');
      expect(store.of('lead-1', 'deezer'), isNull, reason: 'forgotten');
      preview.outcome = PreviewPlayOutcome.playing;
      return store;
    }

    for (final (status, words, line) in [
      (429, 'too many lookups', 'Busy — try again in a minute'),
      (
        502,
        'plug-in deezer could not resolve this recommendation',
        'Unavailable right now',
      ),
    ]) {
      testWidgets('a re-ask after a failed shared clip that answers $status '
          'stores nothing: the press after it asks again rather than replay '
          'the dead address', (tester) async {
        final store = await failStoredClip(tester);
        fake.refuse['/plugins/deezer/resolve'] = (status, words);
        await tapKey(tester, 'lead-preview-deezer');
        expect(fake.resolves('deezer'), hasLength(1));
        expect(lineOf(tester, 'deezer'), line);
        expect(
          store.of('lead-1', 'deezer'),
          isNull,
          reason: 'the dead address is gone, and a failure is never stored',
        );

        await tapKey(tester, 'lead-preview-deezer');
        expect(fake.resolves('deezer'), hasLength(2), reason: 'asked again');
        expect(preview.plays, hasLength(1), reason: 'nothing replayed');
        expect(lineOf(tester, 'deezer'), line);
      });
    }

    // Round 3's W4: the URL-keyed mark lived in one sheet, so a new sheet
    // over the lead (and the page) replayed the dead address once more.
    testWidgets('a sheet opened over the lead after its clip failed is not '
        'seeded with the dead address: it reads Tap to hear, and its press '
        "asks the plug-in and plays the new clip; another surface's failure "
        'leaves the new answer alone', (tester) async {
      final store = await failStoredClip(tester);
      await closeSheet(tester);
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      expect(lineOf(tester, 'deezer'), 'Tap to hear 30 seconds');
      expect(find.text('Preview from Deezer'), findsNothing);

      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(preview.plays, hasLength(2));
      expect(preview.plays.last.url.toString(), deezerClip()['url']);
      expect(
        store.of('lead-1', 'deezer')!.found!.url.toString(),
        deezerClip()['url'],
      );

      preview.emit(
        PreviewClipState(
          provider: 'deezer',
          phase: PreviewPhase.failed,
          owner: Object(),
        ),
      );
      await frames(tester, 2);
      expect(store.of('lead-1', 'deezer'), isNotNull);
    });

    testWidgets('a 200 after a failed shared clip and a busy re-ask replaces '
        'the answer: its clip plays, and the next press replays the new '
        'address with no lookup', (tester) async {
      final store = await failStoredClip(tester);
      fake.refuse['/plugins/deezer/resolve'] = (429, 'too many lookups');
      await tapKey(tester, 'lead-preview-deezer');
      expect(find.text('Busy — try again in a minute'), findsOneWidget);

      fake.refuse.clear();
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(2));
      expect(
        store.of('lead-1', 'deezer')!.found!.url.toString(),
        deezerClip()['url'],
        reason: 'the page plays the new address too',
      );
      expect(preview.plays, hasLength(2));
      expect(preview.plays.last.url.toString(), deezerClip()['url']);
      expect(
        lineOf(tester, 'deezer'),
        '0:00 of 0:30 · Paper Satellites · The Quiet Assembly',
      );

      await tapKey(tester, 'lead-preview-deezer'); // stops it
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(2), reason: 'no lookup');
      expect(preview.plays, hasLength(3));
      expect(preview.plays.last.url.toString(), deezerClip()['url']);
    });

    testWidgets('a new address stored since the clip failed (the page '
        'answered afresh) plays on the next press with no lookup', (
      tester,
    ) async {
      final store = await failStoredClip(tester);
      fake.refuse['/plugins/deezer/resolve'] = (429, 'too many lookups');
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));

      // The plug-ins were read afresh and the page asked again.
      store
        ..clear()
        ..put('lead-1', 'deezer', answerOf(deezerClip()));
      await frames(tester, 2);
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(preview.plays, hasLength(2));
      expect(preview.plays.last.url.toString(), deezerClip()['url']);
    });

    testWidgets('a re-ask after a failed shared clip that finds none: the '
        'visit reads none, the row No preview found', (tester) async {
      final store = await failStoredClip(tester);
      var told = 0;
      store.addListener(() => told++);
      fake.previews.remove('deezer');
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(store.of('lead-1', 'deezer')!.none, isTrue, reason: 'the page');
      expect(told, 1);
      expect(find.text('No preview found'), findsOneWidget);
      expect(find.text('Preview from Deezer'), findsNothing);
      expect(find.byTooltip('Open in Deezer'), findsNothing);

      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(preview.plays, hasLength(1));
    });

    /// The app's preview player over a song side and a clip of the test's
    /// in place of the fake one (whose install puts the fake back).
    ({PreviewPlayer player, FakePreviewPort port, FakePreviewClip clip})
    realEngine({FakePreviewPort? on}) {
      final port = on ?? FakePreviewPort();
      final clip = FakePreviewClip();
      final player = PreviewPlayer.withPort(port, makeClip: () => clip);
      PreviewPlayer.instance = player;
      return (player: player, port: port, clip: clip);
    }

    // Round 3's W4 again: the real engine tells the rows of a clip that
    // would not load only after its play returns (FakePreviewPlayer tells
    // them before), when the row reads unavailable already. Forgotten only
    // there, the dead address stayed in the visit's answers: the same
    // sheet replayed it on every press, asking nobody, and a sheet opened
    // later and the page replayed it too.
    testWidgets('on the real engine, a shared clip that would not load is '
        'forgotten: the next press asks again, a re-ask that gives the dead '
        'address back is never replayed without a lookup, and a sheet '
        'opened after is not seeded', (tester) async {
      final engine = realEngine();
      final clip = engine.clip;
      final dead = Uri.parse(expiredClip()['url'] as String);
      final live = Uri.parse(deezerClip()['url'] as String);
      final store = PreviewAnswers()
        ..put('lead-1', 'deezer', answerOf(expiredClip()));
      // The server's resolve cache still gives the dead address back.
      fake.previews['deezer'] = expiredClip();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      expect(lineOf(tester, 'deezer'), 'Paper Satellites · The Quiet Assembly');

      clip.loadError = StateError('403 from the CDN');
      await tapKey(tester, 'lead-preview-deezer');
      expect(resolveCount(), 0);
      expect(clip.loads, [dead]);
      expect(lineOf(tester, 'deezer'), 'Unavailable right now');
      expect(store.of('lead-1', 'deezer'), isNull, reason: 'forgotten');

      for (var i = 1; i <= 2; i++) {
        clip.loadError = StateError('403 from the CDN');
        await tapKey(tester, 'lead-preview-deezer');
        expect(fake.resolves('deezer'), hasLength(i), reason: 'asked again');
        expect(clip.loads, hasLength(i + 1));
        expect(clip.loads.last, dead);
        expect(lineOf(tester, 'deezer'), 'Unavailable right now');
        expect(store.of('lead-1', 'deezer'), isNull);
      }
      expect(engine.player.state.value.phase, PreviewPhase.failed);

      // A sheet opened now reads Tap to hear, and its press asks and plays
      // the live address.
      await closeSheet(tester);
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      expect(lineOf(tester, 'deezer'), 'Tap to hear 30 seconds');
      fake.previews['deezer'] = deezerClip();
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(3));
      expect(clip.loads.last, live);
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(
        lineOf(tester, 'deezer'),
        '0:00 of 0:30 · Paper Satellites · The Quiet Assembly',
      );
      expect(store.of('lead-1', 'deezer')!.found!.url, live);

      // A clip that breaks while it plays is forgotten the same way.
      clip.breakDown();
      await frames(tester);
      expect(lineOf(tester, 'deezer'), 'Unavailable right now');
      expect(store.of('lead-1', 'deezer'), isNull);
      expect(tester.takeException(), isNull);
      await closeSheet(tester);
    });

    testWidgets('on the real engine, a clip the row found itself that would '
        'not load is not kept for the visit: each press asks again', (
      tester,
    ) async {
      final engine = realEngine();
      final store = PreviewAnswers();
      fake.previews['deezer'] = expiredClip();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      for (var i = 1; i <= 2; i++) {
        engine.clip.loadError = StateError('403 from the CDN');
        await tapKey(tester, 'lead-preview-deezer');
        expect(fake.resolves('deezer'), hasLength(i));
        expect(engine.clip.loads, hasLength(i));
        expect(store.of('lead-1', 'deezer'), isNull, reason: 'kept, then forgotten');
        expect(lineOf(tester, 'deezer'), 'Unavailable right now');
      }
      await closeSheet(tester);
    });

    testWidgets('on the real engine with no shared answers (More like '
        "this, #237's sheet): a clip that would not load reads unavailable "
        'and every press asks again', (tester) async {
      final engine = realEngine();
      fake.previews['deezer'] = expiredClip();
      await pumpSheet(tester);
      for (var i = 1; i <= 2; i++) {
        engine.clip.loadError = StateError('403 from the CDN');
        await tapKey(tester, 'lead-preview-deezer');
        expect(fake.resolves('deezer'), hasLength(i));
        expect(engine.clip.loads, hasLength(i));
        expect(lineOf(tester, 'deezer'), 'Unavailable right now');
      }
      fake.previews['deezer'] = deezerClip();
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(3));
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      await tapKey(tester, 'lead-preview-deezer'); // stops it
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(3), reason: 'found: replayed');
      expect(engine.clip.loads, hasLength(4));
      await closeSheet(tester);
    });

    // Round 3's W1 on #237's path: the sheet's own lifecycle observer ends
    // no flow (it only keeps a lookup still out quiet), so the engine's own
    // watch ends its clip as the app is hidden, a microtask after the
    // binding told it.
    testWidgets("the app sent to the background ends the sheet's clip "
        'through the app port\'s own watch: no "used after being disposed", '
        'the song back, and a clip after the return is watched afresh', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final engine = realEngine(on: BindingPreviewPort());
      final port = engine.port;
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester);
      for (var round = 1; round <= 2; round++) {
        await tapKey(tester, 'lead-preview-deezer');
        expect(engine.player.state.value.phase, PreviewPhase.playing);
        expect(port.pauses, round);
        backgroundApp(tester);
        await frames(tester, 2);
        expect(tester.takeException(), isNull);
        expect(engine.player.state.value, PreviewClipState.idle);
        expect(port.plays, round, reason: 'backgrounded brings the song back');
        // No frame is drawn in the background: the row is read once back.
        foregroundApp(tester);
        await frames(tester, 2);
        expect(tester.takeException(), isNull);
        expect(lineOf(tester, 'deezer'), 'Paper Satellites · The Quiet Assembly');
      }
      expect(fake.resolves('deezer'), hasLength(1));
      await closeSheet(tester);
    });

    testWidgets("a page press while the sheet animates closed over its own "
        "clip: the page's clip plays once it resolves, and the sheet's close "
        'neither ends it nor brings the song back between', (tester) async {
      final port = FakePreviewPort();
      final clip = FakePreviewClip();
      final player = PreviewPlayer.withPort(port, makeClip: () => clip);
      PreviewPlayer.instance = player; // the fake's install puts it back
      final leads = parseLeads(tasteJson());
      final pageLead = leads.first;
      final pageClip = PluginPreview(
        provider: 'deezer',
        url: Uri.parse('https://cdn.example/page-lead.mp3'),
        title: pageLead.title,
        artist: pageLead.artist,
      );
      final asked = <Completer<PluginPreview?>>[];
      final page = PeerRecsPreviews(
        resolve: (_, _) {
          final c = Completer<PluginPreview?>();
          asked.add(c);
          return c.future;
        },
        provider: () => const DiscoveryPlugin(
          name: 'deezer',
          title: 'Preview on Deezer',
          capabilities: [kCapPreview],
        ),
        timer: timers.call,
        watchLifecycle: false,
      );
      addTearDown(page.dispose);

      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      expect(player.state.value.phase, PreviewPhase.playing);
      expect(player.state.value.owner, isA<NetworkPreviews>());
      expect(port.pauses, 1);

      // The barrier tapped: the sheet animates away, still built.
      await tester.tapAt(const Offset(195, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsOneWidget);

      // A card's circle on the page under it.
      unawaited(page.press(pageLead, leads));
      await tester.pump();
      expect(page.status, PeerClipStatus.resolving);
      expect(asked, hasLength(1));
      clip.emitPosition(const Duration(seconds: 3)); // the sheet's clip ticks
      await frames(tester, 10);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsNothing);
      expect(page.status, PeerClipStatus.resolving);
      expect(port.plays, 0, reason: 'the song stays paused');

      asked.single.complete(pageClip);
      await frames(tester);
      expect(page.status, PeerClipStatus.playing);
      expect(clip.loads.last, pageClip.url);
      expect(player.state.value.owner, same(page));
      expect(port.pauses, 1);
      expect(port.plays, 0);

      await page.stop();
      await frames(tester);
      expect(port.plays, 1, reason: 'the page brings it back once');
      await player.end(PreviewEnd.sheetClosed);
    });

    testWidgets('openPeerLead opens the sheet and completes after it closes; '
        'reset() puts it back', (tester) async {
      final store = PreviewAnswers()..put('lead-1', 'itunes', null);
      await pumpSheet(
        tester,
        viaPeerRoute: true,
        answers: (store: store, leadKey: 'lead-1'),
      );
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsOneWidget);
      expect(find.text('88% match to “Tidewater”'), findsOneWidget);
      expect(
        find.text('No preview found'),
        findsOneWidget,
        reason: 'the answers reached it',
      );
      expect(peerClosed, 0, reason: 'open still');
      await closeSheet(tester);
      expect(peerClosed, 1);

      final opened = <String>[];
      DiscoveryKeepRoutes.openPeerLead =
          (_, _, lead, {seedTitle, answers}) async =>
              opened.add('${lead.title} $seedTitle ${answers?.leadKey}');
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      expect(opened, ['Paper Satellites Tidewater lead-1']);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsNothing);
      expect(peerClosed, 2);

      DiscoveryKeepRoutes.reset();
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsOneWidget);
    });

    testWidgets('the header names the peer by its label', (tester) async {
      // A default-named peer: the strip's label ("mStream · 3f9a", taste
      // generation 3's peer.label) before its announced name.
      final row = {
        ...netRow(),
        'peer': {'endpointId': 'ab' * 32, 'name': 'mStream', 'label': 'mStream · 3f9a'},
      };
      await pumpSheet(tester, lead: leadOf(row), viaPeerRoute: true);
      expect(find.text('From the network · mStream · 3f9a'), findsOneWidget);
      expect(find.text('From the network · mStream'), findsNothing);
      await closeSheet(tester);

      // A blank label (or none: More like this's rows) falls back to the name.
      final blank = {
        ...netRow(),
        'peer': {'endpointId': 'ab' * 32, 'name': 'mStream', 'label': '  '},
      };
      await pumpSheet(tester, lead: leadOf(blank), viaPeerRoute: true);
      expect(find.text('From the network · mStream'), findsOneWidget);
    });
  });

  // The preview player watches the app only from a play on and the song
  // only once a clip has loaded; before then the rows watch both
  // themselves (mStream plan §2 items 13–14: the main player always wins,
  // and the app going to the background ends a preview even before its
  // clip loads).
  group('before a clip of the sheet sounds', () {
    String? lineOf(WidgetTester tester, String plugin) => tester
        .widget<Text>(find.byKey(ValueKey('lead-preview-line-$plugin')))
        .data;

    const found = 'Paper Satellites · The Quiet Assembly';

    /// The app's preview player over a song side and a clip of the test's
    /// (the fake's install puts the fake back).
    ({PreviewPlayer player, FakePreviewPort port, FakePreviewClip clip})
    realEngine(FakePreviewPort port) {
      final clip = FakePreviewClip();
      final player = PreviewPlayer.withPort(port, makeClip: () => clip);
      PreviewPlayer.instance = player;
      return (player: player, port: port, clip: clip);
    }

    testWidgets('the song paused at the press and started by the user while '
        'the row is looked up: the clip it finds never plays, and the song '
        'plays on', (tester) async {
      final engine = realEngine(FakePreviewPort(songPlaying: false));
      final port = engine.port;
      fake.previews['deezer'] = deezerClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      expect(lineOf(tester, 'deezer'), 'Looking up…');

      port.userPlay(); // Play on a headset, the lock screen, CarPlay
      await frames(tester, 2);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(engine.clip.loads, isEmpty);
      expect(port.pauses, 0);
      expect(port.playingNow, isTrue);
      expect(engine.player.state.value, PreviewClipState.idle);
      expect(lineOf(tester, 'deezer'), found, reason: 'found, not playing');

      // A press now plays it, pausing the song as any press does.
      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 1);
      await closeSheet(tester);
      expect(port.plays, 1, reason: 'the sheet closing brings it back');
    });

    testWidgets('the song paused at the press and started by the user while '
        "the row's clip loads: the clip stops before it pauses the song", (
      tester,
    ) async {
      final engine = realEngine(FakePreviewPort(songPlaying: false));
      final port = engine.port;
      final store = PreviewAnswers()
        ..put('lead-1', 'deezer', answerOf(deezerClip()));
      engine.clip.holdLoads = true;
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      await tapKey(tester, 'lead-preview-deezer');
      expect(engine.player.state.value.phase, PreviewPhase.loading);

      port.userPlay();
      await frames(tester, 2);
      expect(engine.clip.pendingLoads, 0, reason: 'the load was stopped');
      expect(engine.player.state.value, PreviewClipState.idle);
      expect(engine.clip.playCalls, 0);
      expect(port.pauses, 0);
      expect(port.plays, 0, reason: 'nothing brings the song back for it');
      expect(port.playingNow, isTrue);
      expect(lineOf(tester, 'deezer'), found);
      expect(store.of('lead-1', 'deezer'), isNotNull, reason: 'kept');
      expect(resolveCount(), 0);
      await closeSheet(tester);
    });

    testWidgets('the song paused at the press, a clip of the sheet played '
        "over it and ended while another row is looked up: the user's Play "
        'then keeps that row quiet too', (tester) async {
      preview.songPlaying = false;
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      expect(preview.watchingSong, isTrue);
      fake.resolveGates['deezer'] = Completer<void>();
      await tapKey(tester, 'lead-preview-deezer');
      await preview.complete(); // the iTunes clip played out
      await frames(tester, 2);
      expect(preview.watchingSong, isTrue, reason: 'deezer is still asked');
      preview.startSong();
      await frames(tester, 2);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect([for (final p in preview.plays) p.provider], ['itunes']);
      expect(lineOf(tester, 'deezer'), found);
      expect(preview.watchingSong, isFalse);
    });

    testWidgets('the song a clip of the sheet paused comes back as it ends '
        "while another row is looked up: no start of the user's, so that "
        'row plays once it answers', (tester) async {
      final engine = realEngine(FakePreviewPort());
      final port = engine.port;
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      expect(port.pauses, 1);
      fake.resolveGates['deezer'] = Completer<void>();
      await tapKey(tester, 'lead-preview-deezer'); // the song is paused now
      engine.clip.finish();
      await frames(tester, 2);
      expect(port.plays, 1, reason: 'the iTunes clip played out');
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(engine.clip.loads, [
        Uri.parse(itunesClip()['url'] as String),
        Uri.parse(deezerClip()['url'] as String),
      ]);
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 2);
      await closeSheet(tester);
    });

    testWidgets('the song watch is there only while a press made with the '
        'song paused is on its way, and a clip already playing is the '
        "preview player's to end", (tester) async {
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      await pumpSheet(tester);
      // The song playing at the press: the preview player watches it.
      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.watchingSong, isFalse);
      await tapKey(tester, 'lead-preview-deezer'); // stops it

      preview.songPlaying = false;
      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.watchingSong, isTrue, reason: 'kept while it plays');
      await tapKey(tester, 'lead-preview-deezer'); // stops it
      expect(preview.watchingSong, isFalse);

      // A lookup that answers 429 lets go of it.
      fake.refuse['/plugins/itunes/resolve'] = (429, 'too many lookups');
      await tapKey(tester, 'lead-preview-itunes');
      expect(lineOf(tester, 'itunes'), 'Busy — try again in a minute');
      expect(preview.watchingSong, isFalse);
      fake.refuse.clear();

      // The user starting the song over a clip of the sheet that plays:
      // the sheet asks no end of its own.
      await tapKey(tester, 'lead-preview-deezer');
      expect(preview.watchingSong, isTrue);
      final before = preview.endCalls.length;
      preview.startSong();
      await frames(tester, 2);
      expect(preview.endCalls, hasLength(before));
      expect(preview.watchingSong, isFalse);

      // Closing the sheet lets go of it.
      preview.songPlaying = false;
      await tapKey(tester, 'lead-preview-deezer'); // stops it
      fake.resolveGates['itunes'] = Completer<void>();
      await tapKey(tester, 'lead-preview-itunes');
      expect(preview.watchingSong, isTrue);
      await closeSheet(tester);
      expect(preview.watchingSong, isFalse);
      fake.resolveGates.remove('itunes')!.complete();
      await frames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the app sent to the background and back while the row is '
        'looked up: the clip it finds never plays, and the song is not '
        'paused', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final engine = realEngine(BindingPreviewPort());
      final port = engine.port;
      fake.previews['deezer'] = deezerClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      expect(lineOf(tester, 'deezer'), 'Looking up…');

      backgroundApp(tester);
      await frames(tester, 2);
      foregroundApp(tester);
      await frames(tester, 2);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(engine.clip.loads, isEmpty);
      expect(port.pauses, 0);
      expect(engine.player.state.value, PreviewClipState.idle);
      expect(lineOf(tester, 'deezer'), found, reason: 'waits for a press');

      await tapKey(tester, 'lead-preview-deezer');
      expect(fake.resolves('deezer'), hasLength(1));
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 1);
      await closeSheet(tester);
    });

    testWidgets('a passing inactive state (a system sheet, the app '
        'switcher) keeps the lookup: its clip plays once it answers', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      fake.previews['deezer'] = deezerClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect([for (final p in preview.plays) p.provider], ['deezer']);
    });

    // The song watch does not hear a cast started from the TV's own remote
    // (only its flag goes on, and a cast's flag can flicker). The clip the
    // lookup then finds pauses the cast, and its end brings it back: that
    // resume is no start of the user's.
    testWidgets('while casting, the song paused at the press and started '
        "from the TV's own remote while the row is looked up: the song a "
        'clip of the sheet paused comes back as it ends while another row '
        'is looked up, and that row plays once it answers', (tester) async {
      final engine = realEngine(
        FakePreviewPort(songPlaying: false, casting: true),
      );
      final port = engine.port;
      fake.previews['deezer'] = deezerClip();
      fake.previews['itunes'] = itunesClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-deezer');
      expect(lineOf(tester, 'deezer'), 'Looking up…');
      port.startsByItself(); // the TV's own remote: no command
      await frames(tester, 2);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 1, reason: 'the clip paused the cast');

      fake.resolveGates['itunes'] = Completer<void>();
      await tapKey(tester, 'lead-preview-itunes');
      expect(lineOf(tester, 'itunes'), 'Looking up…');
      engine.clip.finish();
      await frames(tester, 2);
      expect(port.plays, 1, reason: 'the Deezer clip played out');
      fake.resolveGates.remove('itunes')!.complete();
      await frames(tester);
      expect(engine.clip.loads, [
        Uri.parse(deezerClip()['url'] as String),
        Uri.parse(itunesClip()['url'] as String),
      ]);
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 2);
      await closeSheet(tester);
      expect(port.plays, 2, reason: 'the sheet closing brings it back');
    });

    testWidgets('the song paused at the press, a clip of the sheet played '
        'over it and ended while another row is looked up (the real preview '
        "player): the user's Play then keeps that row quiet", (tester) async {
      final engine = realEngine(FakePreviewPort(songPlaying: false));
      final port = engine.port;
      final store = PreviewAnswers()
        ..put('lead-1', 'itunes', answerOf(itunesClip()));
      fake.previews['deezer'] = deezerClip();
      fake.resolveGates['deezer'] = Completer<void>();
      await pumpSheet(tester, answers: (store: store, leadKey: 'lead-1'));
      await tapKey(tester, 'lead-preview-itunes');
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 0, reason: 'the song was paused already');
      await tapKey(tester, 'lead-preview-deezer');
      expect(lineOf(tester, 'deezer'), 'Looking up…');
      engine.clip.finish();
      await frames(tester, 2);
      expect(engine.player.state.value, PreviewClipState.idle);
      expect(port.plays, 0, reason: 'nothing to bring back');

      port.userPlay();
      await frames(tester, 2);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(engine.clip.loads, [Uri.parse(itunesClip()['url'] as String)]);
      expect(port.pauses, 0);
      expect(port.playingNow, isTrue);
      expect(lineOf(tester, 'deezer'), found);
      expect(port.listeners, 0);
      await closeSheet(tester);
    });

    // A press made while a clip of the sheet runs arms no watch, though
    // that clip has paused the song: its end brings the song back, and with
    // the flag going on after the Play, a watch would hear that flag as the
    // user starting the song.
    testWidgets('the song playing at the press and paused by its clip, '
        'another row looked up meanwhile: the song back as that clip ends is '
        "no start of the user's, and the row plays once it answers (the "
        "song's flag going on after the Play, as the app's does)", (
      tester,
    ) async {
      final engine = realEngine(_LateFlagPort());
      final port = engine.port;
      fake.previews['itunes'] = itunesClip();
      fake.previews['deezer'] = deezerClip();
      await pumpSheet(tester);
      await tapKey(tester, 'lead-preview-itunes');
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 1);
      fake.resolveGates['deezer'] = Completer<void>();
      await tapKey(tester, 'lead-preview-deezer');
      expect(lineOf(tester, 'deezer'), 'Looking up…');

      engine.clip.finish();
      await frames(tester, 2);
      expect(port.plays, 1, reason: 'the iTunes clip played out');
      expect(port.playingNow, isTrue);
      fake.resolveGates.remove('deezer')!.complete();
      await frames(tester);
      expect(engine.clip.loads, [
        Uri.parse(itunesClip()['url'] as String),
        Uri.parse(deezerClip()['url'] as String),
      ]);
      expect(engine.player.state.value.phase, PreviewPhase.playing);
      expect(port.pauses, 2);
      await closeSheet(tester);
      expect(port.plays, 2, reason: 'the sheet closing brings it back');
    });
  });

  group('the route', () {
    testWidgets('DiscoveryKeepRoutes.openNetworkLead opens the sheet, '
        '(Choose another) with the search asked to start', (tester) async {
      stubKeepBlock();
      await pumpSheet(tester, viaRoute: true, autoSearch: true);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsOneWidget);
      expect(find.text('88% match to “Tidewater”'), findsOneWidget);
      expect(slots.last.autoSearch, isTrue);
    });

    testWidgets('tests can stand in for it, and reset() puts it back', (
      tester,
    ) async {
      final opened = <String>[];
      DiscoveryKeepRoutes.openNetworkLead =
          (
            _,
            _,
            lead, {
            seedTitle,
            autoSearch = false,
            avoidUrl,
            onLeadAction,
          }) => opened.add('${lead.title} $seedTitle $autoSearch');
      await pumpSheet(tester, viaRoute: true);
      expect(opened, ['Paper Satellites Tidewater false']);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsNothing);
      DiscoveryKeepRoutes.reset();
      await tester.tap(find.byKey(const ValueKey('open')));
      await frames(tester, 8);
      expect(find.byKey(const ValueKey('network-lead-sheet')), findsOneWidget);
    });
  });

  test('openOutside ends a clip as leaving the app, then launches', () async {
    final preview = FakePreviewPlayer.install();
    final order = <String>[];
    elsewhereLaunch = (uri) async {
      order.add('launch ${preview.ends}');
      return true;
    };
    expect(await openOutside(Uri.parse('https://example.org/a')), isTrue);
    expect(order, ['launch [PreviewEnd.leftApp]']);
  });

  test('openOutside: a link that does not open — false, or a throw that '
      'still reaches the caller — gives the song back', () async {
    final port = FakePreviewPort();
    final previous = PreviewPlayer.instance;
    final player = PreviewPlayer.withPort(port, makeClip: FakePreviewClip.new);
    PreviewPlayer.instance = player;
    addTearDown(() => PreviewPlayer.instance = previous);
    final clip = Uri.parse('https://cdn.example/30s.mp3');
    final link = Uri.parse('https://example.org/a');

    await player.play(provider: 'itunes', url: clip);
    expect([port.pauses, port.plays], [1, 0]);
    elsewhereLaunch = (_) async => false;
    expect(await openOutside(link), isFalse);
    expect(port.plays, 1);

    await player.play(provider: 'itunes', url: clip);
    expect(port.pauses, 2);
    elsewhereLaunch = (_) async => throw StateError('no browser');
    await expectLater(openOutside(link), throwsStateError);
    expect(port.plays, 2);

    await player.play(provider: 'itunes', url: clip);
    elsewhereLaunch = (_) async => true;
    expect(await openOutside(link), isTrue);
    expect(port.plays, 2, reason: 'left the app: stays paused');
  });
}
