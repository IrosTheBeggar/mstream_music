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

import '../../media/preview_fakes.dart';
import '../discovery_fixtures.dart';
import '../discovery_plugin_fakes.dart';

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
  /// [open], else showNetworkLeadSheet) for [lead], at 390 × 844.
  Future<void> pumpSheet(
    WidgetTester tester, {
    DiscoveryLead? lead,
    String? seedTitle = 'Tidewater',
    bool activate = true,
    bool viaRoute = false,
    bool autoSearch = false,
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
                  if (viaRoute) {
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
}
