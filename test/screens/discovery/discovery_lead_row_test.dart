// A lead row on More like this (the design canvas's Main and Degraded
// boards): the network-lead sheet's way in — one button, the network's
// globe, the meter alone at its end, at least 56 tall — and today's row
// for every other lead, unchanged: the lead glyph, the MusicBrainz
// link-out when the row names a recording, and a tap that copies.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/screens/discover_screen.dart';
import 'package:mstream_music/screens/discovery/discovery_lead_row.dart';

const _mbid = '0f3e9b1c-7a2d-4c55-9e11-2b6f0d8a4c11';

/// The canvas's lead, as the per-song P2P route hands it out.
DiscoveryLead netLead({
  String artist = 'The Quiet Assembly',
  String? peerName = 'Vinyl Vault',
  String? mbid = _mbid,
}) => DiscoveryLead.fromServerMap({
  'artist': artist,
  'title': 'Paper Satellites',
  'album': 'Static Bloom',
  'similarity': 0.88,
  'recordingMbid': ?mbid,
  'peer': {'endpointId': 'ab' * 32, 'name': ?peerName},
})!;

void main() {
  late int taps;
  late int musicBrainz;

  setUp(() {
    taps = 0;
    musicBrainz = 0;
  });

  Future<void> pumpRow(
    WidgetTester tester,
    DiscoveryLead lead, {
    required bool opensSheet,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          body: ListView(
            children: [
              DiscoveryLeadRow(
                lead: lead,
                opensSheet: opensSheet,
                onTap: () => taps++,
                onOpenMusicBrainz: () => musicBrainz++,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double rowHeight(WidgetTester tester) =>
      tester.getSize(find.byType(ListTile)).height;

  group('sheet mode', () {
    testWidgets('the globe, "Artist · Peer", the meter alone — no '
        'MusicBrainz link however the row names a recording', (tester) async {
      await pumpRow(tester, netLead(), opensSheet: true);
      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.byIcon(Icons.travel_explore), findsNothing);
      expect(find.text('Paper Satellites'), findsOneWidget);
      expect(find.text('The Quiet Assembly · Vinyl Vault'), findsOneWidget);
      expect(find.byType(MatchMeter), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
      expect(find.byTooltip('Open on MusicBrainz'), findsNothing);
    });

    testWidgets('the whole row is one button: a tap anywhere opens', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, netLead(), opensSheet: true);
      expect(
        tester.getSemantics(find.byType(ListTile)),
        isSemantics(isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byType(MatchMeter));
      await tester.tap(find.text('Paper Satellites'));
      expect(taps, 2);
      expect(musicBrainz, 0);
      handle.dispose();
    });

    testWidgets('at least 56 tall — a one-line row too', (tester) async {
      await pumpRow(tester, netLead(), opensSheet: true);
      expect(rowHeight(tester), greaterThanOrEqualTo(56));
      await pumpRow(
        tester,
        netLead(artist: '', peerName: null),
        opensSheet: true,
      );
      expect(find.text('Paper Satellites'), findsOneWidget);
      expect(rowHeight(tester), greaterThanOrEqualTo(56));
    });

    testWidgets('200 % text: nothing overflows', (tester) async {
      await pumpRow(tester, netLead(), opensSheet: true, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('copy mode (today\'s row)', () {
    testWidgets('the lead glyph, the MusicBrainz link-out beside the meter, '
        'and a tap that copies', (tester) async {
      await pumpRow(tester, netLead(), opensSheet: false);
      expect(find.byIcon(Icons.travel_explore), findsOneWidget);
      expect(find.byIcon(Icons.public), findsNothing);
      expect(find.text('The Quiet Assembly · Vinyl Vault'), findsOneWidget);
      expect(find.byTooltip('Open on MusicBrainz'), findsOneWidget);
      expect(find.byType(MatchMeter), findsOneWidget);
      await tester.tap(find.byTooltip('Open on MusicBrainz'));
      expect(musicBrainz, 1);
      expect(taps, 0);
      await tester.tap(find.text('Paper Satellites'));
      expect(taps, 1);
    });

    testWidgets('no link-out without a recording; its height as before', (
      tester,
    ) async {
      await pumpRow(tester, netLead(mbid: null), opensSheet: false);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
      // A dense two-line list tile, as the row always was.
      expect(rowHeight(tester), 64);
    });
  });
}
