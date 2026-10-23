// Keep a copy on Discover's connected servers, drawn through the real
// Browser (the design canvas's PhoneSongSheet, PhoneAlbumSheet,
// PhoneKeepStates, PhoneDiscover and PhoneLargeText boards): the song
// sheet a long-press on a connected server's row opens, the album sheet a
// long-press or the ⋯ on its album card opens, the Keep card in every
// state, the markers on rows and cards, the Copies strip with its counts,
// what hides it all, and large text / German.
//
// The plug-in API is the scripted fake behind the real
// DiscoveryPluginsApi; the sheets' facts (album-songs, artists-albums) are
// a scripted fetch; nothing touches the network or the audio service.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/screens/discovery/keep_copy_card.dart';
import 'package:mstream_music/screens/discovery/keep_copy_facts.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

import 'discovery_keep_fixtures.dart';

const _jobs = '/plugins/federation-copy/jobs';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = KeepHarness();

  setUpAll(mockPathProvider);
  setUp(() => h.setUp());
  tearDown(() {
    BrowserManager().closeAlbumDetail();
    ServerManager().currentServer = null;
    h.tearDown();
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) =>
      KeepHarness.pumpFor(tester, n);

  Future<void> openSongSheet(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await frames(tester, 8);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await frames(tester);
  }

  Map<String, dynamic> lastStart() =>
      jsonDecode(h.fake.calls('POST', _jobs).last.body) as Map<String, dynamic>;

  double topOf(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  /// A line as read, its no-break spaces (a path segment never breaks
  /// inside itself) read as spaces.
  Finder line(String text) => find.byWidgetPredicate(
    (w) =>
        w is RichText && w.text.toPlainText().replaceAll('\u00A0', ' ') == text,
  );

  group('the song sheet: long-press a connected server\'s row', () {
    testWidgets('the listen verbs, the album and the artist, Keep a copy, Open '
        'elsewhere, Browse the server, and Download to this phone last', (
      tester,
    ) async {
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Corner Store Loop');
      expect(tester.takeException(), isNull);

      // Header: the row, its format and length, its server answering.
      expect(find.text('Boukmanflow  ·  Borrowed Tapes'), findsOneWidget);
      expect(find.text('MP3  ·  0:09'), findsOneWidget);
      expect(find.text('Stage Peer B online'), findsOneWidget);
      // Listen.
      expect(find.text('Add next'), findsOneWidget);
      expect(find.text('Play now'), findsOneWidget);
      // The album and the artist, asked through the connected server.
      expect(
        find.text('2019 · 3 songs · 0:29 · not in your library'),
        findsOneWidget,
      );
      expect(find.text('Open album'), findsOneWidget);
      expect(find.text('Queue album'), findsOneWidget);
      expect(find.text('1 album · 3 songs'), findsOneWidget);
      expect(find.text('Open artist'), findsOneWidget);
      // Keep a copy: three choices with their sizes, where files land, one
      // pill named for the choice.
      expect(find.text('KEEP A COPY'), findsOneWidget);
      expect(find.text('This song'), findsOneWidget);
      expect(find.text('0:09 · MP3'), findsOneWidget);
      expect(find.text('3 songs'), findsOneWidget);
      expect(find.text('1 album · you have 3'), findsOneWidget);
      expect(
        line('Files go to copies › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
      expect(find.text('Add song'), findsOneWidget);
      // Then Open elsewhere, Browse, and the phone download last.
      expect(find.text('Open elsewhere'), findsOneWidget);
      expect(find.text('Browse Stage Peer B'), findsOneWidget);
      expect(find.text('Download to this phone'), findsOneWidget);
      expect(find.text('For offline play on this device'), findsOneWidget);
      expect(
        find.text('Download'),
        findsNothing,
        reason: 'the old Download is renamed',
      );
      expect(
        topOf(tester, find.text('Add song')),
        lessThan(topOf(tester, find.text('Open elsewhere'))),
      );
      expect(
        topOf(tester, find.text('Browse Stage Peer B')),
        lessThan(topOf(tester, find.text('Download to this phone'))),
      );
      // No previews on a connected server's row.
      expect(find.textContaining('preview', findRichText: true), findsNothing);

      // The facts went through the peer, the library's list to the own server.
      final asked = h.facts.asked.map((a) => '${a.$1} ${a.$2}').toList();
      expect(
        asked,
        containsAll([
          'peer-1 /api/v1/db/album-songs',
          'peer-1 /api/v1/db/artists-albums',
          'home /api/v1/db/artists-albums',
        ]),
      );
      final album = h.facts.asked.firstWhere(
        (a) => a.$2.endsWith('album-songs'),
      );
      expect(album.$3, {'album': 'Borrowed Tapes', 'artist': 'Boukmanflow'});

      // Open elsewhere hands the row to its sheet.
      await tapText(tester, 'Open elsewhere');
      expect(h.openedElsewhere, ['Corner Store Loop']);
      // Change opens the destination picker.
      await tester.tap(find.byKey(const ValueKey('keep-change')));
      await frames(tester);
      expect(h.openedDestination, ['change']);
    });

    testWidgets("a library row keeps the track sheet", (tester) async {
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Cirrus');
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('KEEP A COPY'), findsNothing);
      expect(find.text('Download to this phone'), findsNothing);
    });

    testWidgets(
      'Add song sends the row unchanged, then the card follows its job: '
      'waiting, Cancel, stopped with Add again',
      (tester) async {
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await tapText(tester, 'Add song');
        final body = lastStart();
        expect(body['recommendation'], equals(h.lead('Late Train Verse').raw));
        expect(
          body.containsKey('scope'),
          isFalse,
          reason: 'a song job has none',
        );
        expect(find.text('Waiting for a free slot'), findsOneWidget);
        expect(find.text('Starts on its own'), findsOneWidget);
        expect(
          find.text('Add song'),
          findsNothing,
          reason: "the job's line replaces the pill",
        );

        await tester.tap(find.byKey(const ValueKey('keep-cancel')));
        await frames(tester);
        expect(h.fake.count('POST', '/cancel'), 1);
        expect(find.text('Stopped · nothing was copied'), findsOneWidget);
        expect(find.text('You cancelled it'), findsOneWidget);
        await tapText(tester, 'Add again');
        expect(h.fake.calls('POST', _jobs), hasLength(2));
        expect(
          lastStart()['recommendation'],
          equals(h.lead('Late Train Verse').raw),
        );
        expect(find.text('Waiting for a free slot'), findsOneWidget);
      },
    );

    testWidgets('starting: the pill is busy and ignores taps', (tester) async {
      h.fake.startGate = Completer<void>();
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      await tapText(tester, 'Add song');
      final pill = find.byKey(const ValueKey('keep-start'));
      expect(
        find.descendant(
          of: pill,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Add song'));
      await tester.pump();
      expect(h.fake.calls('POST', _jobs), hasLength(1));
      h.fake.startGate!.complete();
      await frames(tester);
      expect(find.text('Waiting for a free slot'), findsOneWidget);
    });

    testWidgets("refused at start: the server's words inline, the pill stays", (
      tester,
    ) async {
      h.fake.refuse[_jobs] = (403, 'Uploading Disabled');
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      await tapText(tester, 'Add song');
      expect(find.text('Uploading Disabled'), findsOneWidget);
      expect(find.text('Add song'), findsOneWidget);

      h.fake.refuse[_jobs] = (
        429,
        'you have 20 jobs queued or running — wait for some to finish (the limit is 20)',
      );
      await tapText(tester, 'Add song');
      expect(
        find.text(
          'you have 20 jobs queued or running — wait for some to finish (the limit is 20)',
        ),
        findsOneWidget,
      );
      expect(find.text('Uploading Disabled'), findsNothing);
    });

    testWidgets('Album: its pill, sent with scope album', (tester) async {
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      await tapText(tester, 'Album');
      expect(find.text('Add album'), findsOneWidget);
      await tapText(tester, 'Add album');
      final body = lastStart();
      expect(body['scope'], 'album');
      expect(body['recommendation'], equals(h.lead('Late Train Verse').raw));
    });

    testWidgets(
      "Artist: only the albums you don't have (by name), no question for "
      'one; unticked, every album asks first',
      (tester) async {
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await tapText(tester, 'Artist');
        expect(find.text("Only the 1 album you don't have"), findsOneWidget);
        // One album missing: "Files go to" names it (state 09).
        expect(
          line('Files go to copies › Boukmanflow › Borrowed Tapes'),
          findsOneWidget,
        );
        expect(find.text('Add 1 album'), findsOneWidget);

        // Unticked: every album, asked first.
        await tester.tap(find.byKey(const ValueKey('keep-only-missing')));
        await frames(tester);
        expect(find.text('Add every album'), findsOneWidget);
        expect(
          line('Files go to copies › Boukmanflow › one folder per album'),
          findsOneWidget,
        );
        await tapText(tester, 'Add every album');
        expect(find.text('Copy 1 album from Stage Peer B?'), findsOneWidget);
        expect(
          find.text(
            'They land on your server in copies › Boukmanflow, one folder per album. Songs you already have are skipped.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel').last);
        await frames(tester);
        expect(
          h.fake.calls('POST', _jobs),
          isEmpty,
          reason: 'Cancel asks nothing',
        );
        await tapText(tester, 'Add every album');
        await tester.tap(find.text('Copy 1 album'));
        await frames(tester);
        expect(lastStart()['scope'], 'artist');
      },
    );

    testWidgets("Add 1 album starts at once with scope artist-missing", (
      tester,
    ) async {
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      await tapText(tester, 'Artist');
      await tapText(tester, 'Add 1 album');
      expect(find.byType(AlertDialog), findsNothing);
      expect(lastStart()['scope'], 'artist-missing');
    });

    testWidgets(
      'choosing Artist past the fold brings the pill back into view',
      (tester) async {
        // A phone's height: the sheet (87 %) no longer holds it all.
        await h.pumpDiscover(tester, height: 844);
        await tester.scrollUntilVisible(
          find.text('Late Train Verse'),
          200,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.pump();
        await openSongSheet(tester, 'Late Train Verse');
        final scroll = find
            .ancestor(
              of: find.byKey(const ValueKey('keep-copy')),
              matching: find.byType(Scrollable),
            )
            .first;
        final view = tester.getRect(scroll);
        final pos = tester.state<ScrollableState>(scroll).position;
        // The chips' bottom edge on the sheet's: the pill out of sight.
        final chip = find.byKey(const ValueKey('keep-chip-artist'));
        pos.jumpTo(
          (pos.pixels + tester.getRect(chip).bottom - view.bottom).clamp(
            pos.minScrollExtent,
            pos.maxScrollExtent,
          ),
        );
        await tester.pump();
        final pill = find.byKey(const ValueKey('keep-start'));
        expect(
          tester.getRect(pill).top,
          greaterThanOrEqualTo(view.bottom),
          reason: 'the pill starts below the fold',
        );
        await tester.tap(chip);
        await frames(tester, 8);
        expect(find.text("Only the 1 album you don't have"), findsOneWidget);
        expect(find.text('Add 1 album'), findsOneWidget);
        expect(
          tester.getRect(pill).bottom,
          lessThanOrEqualTo(view.bottom + 0.5),
          reason: 'the sheet scrolled the pill back into view',
        );
      },
    );

    testWidgets(
      "a compilation's song: Album lands under the album's credit, Artist "
      "under the song's own artist",
      (tester) async {
        h.peersAnswer = () => keepPeersPayload(extraB: compilationRows());
        await h.pumpDiscover(tester);
        await tester.ensureVisible(find.text('Block Rocker'));
        await tester.pump();
        await openSongSheet(tester, 'Block Rocker');
        await tapText(tester, 'Album');
        expect(
          line('Files go to copies › Various Artists › Block Party Comp'),
          findsOneWidget,
        );
        await tapText(tester, 'Artist');
        // The artist walk copies Peer Kim's own albums, by their own tags.
        expect(
          line('Files go to copies › Peer Kim › one folder per album'),
          findsOneWidget,
        );
      },
    );

    testWidgets('only-missing of several albums asks first, with the count', (
      tester,
    ) async {
      h.facts.peerAlbums['boukmanflow'] = [
        'Borrowed Tapes',
        'Second Wind',
        'Old Gold',
      ];
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      await tapText(tester, 'Artist');
      // Old Gold is in the library by name: two are missing.
      expect(find.text('3 albums · you have 3'), findsOneWidget);
      expect(find.text("Only the 2 albums you don't have"), findsOneWidget);
      await tapText(tester, 'Add 2 albums');
      expect(find.text('Copy 2 albums from Stage Peer B?'), findsOneWidget);
      await tester.tap(find.text('Copy 2 albums'));
      await frames(tester);
      expect(lastStart()['scope'], 'artist-missing');
    });

    testWidgets(
      'the server not answering: its line says so, the sizes stay blank, '
      'Keep still starts',
      (tester) async {
        h.facts.peerDown = true;
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(find.text('Stage Peer B not answering'), findsOneWidget);
        expect(find.text('3 songs'), findsNothing);
        expect(
          find.text('0:08 · MP3'),
          findsNothing,
          reason: 'This song keeps no size either (state 05)',
        );
        expect(find.text('you have 3 albums'), findsOneWidget);
        expect(find.text('2019 · not in your library'), findsOneWidget);
        await tapText(tester, 'Add song');
        expect(h.fake.calls('POST', _jobs), hasLength(1));
      },
    );

    testWidgets(
      'loading facts: the sizes wait as placeholders, the pill works',
      (tester) async {
        h.facts.gate = Completer<void>();
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(
          find.byKey(const ValueKey('keep-skeleton')),
          findsNWidgets(3),
          reason: 'This song, Album and Artist wait alike (state 04)',
        );
        expect(find.text('0:08 · MP3'), findsNothing);
        expect(find.text('3 songs'), findsNothing);
        expect(find.text('Add song'), findsOneWidget);
        h.facts.gate!.complete();
        await frames(tester);
        expect(find.byKey(const ValueKey('keep-skeleton')), findsNothing);
        expect(find.text('3 songs'), findsOneWidget);
        expect(find.text('0:08 · MP3'), findsOneWidget);
      },
    );
  });

  group('hidden, never greyed', () {
    testWidgets(
      "plug-ins off: the sheet keeps its verbs; no Keep a copy, no Open "
      'elsewhere, no strip, nothing asked',
      (tester) async {
        h.setUp(plugins: false);
        await h.pumpDiscover(tester);
        expect(
          find.byKey(const ValueKey('discovery-copies-strip')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('discovery-copies-held')),
          findsNothing,
        );
        await openSongSheet(tester, 'Late Train Verse');
        expect(find.text('Add next'), findsOneWidget);
        expect(find.text('Download to this phone'), findsOneWidget);
        expect(find.text('KEEP A COPY'), findsNothing);
        expect(find.text('Open elsewhere'), findsNothing);
        expect(h.fake.requests, isEmpty);
      },
    );

    testWidgets("uploads off: one line instead of the card", (tester) async {
      h.setUp(noUpload: true);
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      expect(find.text('KEEP A COPY'), findsOneWidget);
      expect(
        find.text("Your account can't add files to this server"),
        findsOneWidget,
      );
      expect(find.text('Add song'), findsNothing);
      expect(find.text('This song'), findsNothing);
    });

    testWidgets('no library takes new files: its line', (tester) async {
      h.fake.destination = {
        ...h.fake.destination,
        'destination': null,
        'libraries': [],
      };
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      expect(
        find.text('No library on your server takes new files'),
        findsOneWidget,
      );
      expect(find.text('Add song'), findsNothing);
    });

    testWidgets('jobs not allowed: no card and no label', (tester) async {
      h.fake.listing = {
        ...h.fake.listing,
        'jobs': {'allowed': false},
      };
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      expect(find.text('KEEP A COPY'), findsNothing);
      expect(
        find.text('Open elsewhere'),
        findsOneWidget,
        reason: 'the links plug-in is not a copy',
      );
    });

    testWidgets('only the scopes the server lists: song only; never Folder', (
      tester,
    ) async {
      h.fake.listing = {
        'plugins': [
          {
            'name': 'federation-copy',
            'title': 'Add to your collection',
            'capabilities': ['acquire'],
            'scopes': ['song', 'folder'],
          },
        ],
        'jobs': {'allowed': true},
      };
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      expect(find.text('This song'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsNothing);
      expect(find.byKey(const ValueKey('keep-chip-artist')), findsNothing);
      expect(
        find.text('Open elsewhere'),
        findsNothing,
        reason: 'the links plug-in is not listed',
      );
    });
  });

  group('the Keep card, every state', () {
    testWidgets('each state its line and its verbs', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 9000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final states = keepStates(h.fake);
      final page = h.makePage();
      addTearDown(page.dispose);
      final leads = [
        for (final s in states) DiscoveryLead.fromServerMap(s.row)!,
      ];
      await page.jobs.activate();
      await page.jobs.setRows(leads);
      final peer = h.peer(1, 'Stage Peer B');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < states.length; i++)
                  KeyedSubtree(
                    key: ValueKey('state-${states[i].name}'),
                    child: KeepCopySection(
                      jobs: page.jobs,
                      lead: leads[i],
                      facts: KeepFactsLoader.forLead(
                        leads[i],
                        peer: peer,
                        own: h.server,
                      )..load(),
                      peerName: 'Stage Peer B',
                      initialChoice: states[i].choice,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);

      Finder inState(String state, Finder f) => find.descendant(
        of: find.byKey(ValueKey('state-$state')),
        matching: f,
      );
      void has(
        String state,
        List<String> texts, {
        List<String> buttons = const [],
        List<String> not = const [],
      }) {
        for (final t in [...texts, ...buttons]) {
          expect(
            inState(state, find.text(t)),
            findsOneWidget,
            reason: '$state: "$t"',
          );
        }
        for (final t in not) {
          expect(
            inState(state, find.text(t)),
            findsNothing,
            reason: '$state: no "$t"',
          );
        }
      }

      const verbs = [
        'Retry',
        'Add again',
        'Play',
        'Add to queue',
        'Cancel',
        'New seeds',
      ];
      List<String> others(List<String> keep) => [
        for (final v in verbs)
          if (!keep.contains(v)) v,
      ];
      void state(
        String name,
        List<String> texts, [
        List<String> buttons = const [],
      ]) => has(name, texts, buttons: buttons, not: others(buttons));

      state(
        'queued',
        ['Waiting for a free slot', 'Starts on its own'],
        ['Cancel'],
      );
      state(
        'running',
        ['Copying', '1 of 3 songs · 7.4 MB · Late Train Verse'],
        ['Cancel'],
      );
      expect(
        inState('running', find.byKey(const ValueKey('keep-bar'))),
        findsOneWidget,
      );
      state('stopping', [
        'Stopping…',
        '1 of 3 songs · 7.4 MB · Late Train Verse',
      ]);
      state(
        'done one song',
        [
          'In your collection',
          'copies / Boukmanflow / Borrowed Tapes / 02 - Late Train Verse.mp3',
        ],
        ['Play', 'Add to queue'],
      );
      state(
        'done many',
        [
          'In your collection',
          '1 album · 1 copied · 1 already yours · 1 failed · 2 albums left out',
        ],
        ['Retry'],
      );
      state(
        'already yours',
        [
          'Already yours',
          'Your library has this song · copies / Boukmanflow / Borrowed Tapes / 02 - Late Train Verse.mp3',
        ],
        ['Play', 'Add to queue'],
      );
      state(
        'skipped exists',
        [
          'Skipped · a file is already there',
          'A file is already at copies / Boukmanflow / Borrowed Tapes / 02 - Late Train Verse.mp3 · nothing was overwritten',
        ],
        ['Retry'],
      );
      state(
        'stopped quota',
        ['Stopped', "Stage Peer B's transfer limit stopped it · 1 copied"],
        ['Retry'],
      );
      state(
        'stopped busy',
        [
          'Stopped',
          'Stage Peer B is serving too many streams right now · 1 copied · 1 already yours',
        ],
        ['Retry'],
      );
      state(
        'stopped peer',
        ['Stopped', 'Stage Peer B went away · 1 copied · 1 failed'],
        ['Retry'],
      );
      state('stopped refused', [
        'Stopped',
        "Stage Peer B does not allow copies with your server's key · nothing copied",
      ]);
      state(
        'failed',
        ['Copy failed', 'Stage Peer B no longer has this file'],
        ['Retry'],
      );
      state(
        'failed nothing copied',
        ['Copy failed', 'Nothing copied · 3 failed'],
        ['Retry'],
      );
      state('failed re-paired', ['Copy failed'], ['New seeds']);
      state(
        'cancelled nothing',
        ['Stopped · nothing was copied', 'You cancelled it'],
        ['Add again'],
      );
      state(
        'cancelled some',
        [
          'Stopped · 2 copied',
          'You cancelled it · the 2 songs stay in your collection',
        ],
        ['Add again'],
      );
      state('nothing to copy', [
        'You have it all',
        'Nothing to copy from Stage Peer B',
      ]);
      state('only a guest', [
        'Nothing of theirs to copy',
        "Artist 18 only appears as a guest on Stage Peer B's albums",
      ]);
      state('from another server', [
        'Copying from Stage Peer C',
        '1 of 1 songs · Rooftop Cypher',
        'Add album comes back when that copy ends',
      ]);
      // No pill while a job speaks for the choice.
      expect(find.byKey(const ValueKey('keep-start')), findsNothing);

      // Retry sends the same row and scope again.
      final before = h.fake.calls('POST', _jobs).length;
      await tester.tap(inState('stopped quota', find.text('Retry')));
      await frames(tester);
      expect(h.fake.calls('POST', _jobs), hasLength(before + 1));
      expect(lastStart()['scope'], 'album');
      expect(lastStart()['recommendation'], equals(states[7].row));
    });
  });

  group('the album sheet: long-press or ⋯ on a connected server\'s album', () {
    testWidgets(
      'album focus: Play / Queue / Open album, Album | Artist with Album '
      'chosen, Add album sends the best row with scope album',
      (tester) async {
        await h.pumpDiscover(tester);
        await tester.longPress(find.text('Borrowed Tapes').first);
        await frames(tester, 8);
        expect(tester.takeException(), isNull);
        expect(
          find.text('Boukmanflow · 2019 · 3 songs · 0:29'),
          findsOneWidget,
        );
        expect(find.text('Stage Peer B online'), findsOneWidget);
        expect(find.text('LISTEN'), findsOneWidget);
        expect(find.text('Play album'), findsOneWidget);
        expect(find.text('Queue album'), findsOneWidget);
        expect(find.text('Open album'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('keep-chip-song')),
          findsNothing,
          reason: 'no This song from a card',
        );
        expect(find.byKey(const ValueKey('keep-chip-album')), findsOneWidget);
        expect(find.byKey(const ValueKey('keep-chip-artist')), findsOneWidget);
        expect(find.text('Download to this phone'), findsNothing);
        await tapText(tester, 'Add album');
        final body = lastStart();
        expect(body['scope'], 'album');
        expect(
          body['recommendation'],
          equals(h.lead('Late Train Verse').raw),
          reason: "the card's best row, unchanged",
        );
        expect(find.text('Waiting for a free slot'), findsOneWidget);
      },
    );

    testWidgets(
      "the ⋯ opens the same sheet; the cover's tap still opens the album",
      (tester) async {
        await h.pumpDiscover(tester);
        final more = find
            .byKey(const ValueKey('album-card-more-Borrowed Tapes'))
            .first;
        expect(
          tester.getTopLeft(more).dy,
          greaterThanOrEqualTo(
            tester.getBottomLeft(find.text('Borrowed Tapes').first).dy - 30,
          ),
          reason: 'the ⋯ sits in the text block, not over the cover',
        );
        await tester.tap(more);
        await frames(tester, 8);
        expect(find.text('Play album'), findsOneWidget);
        Navigator.of(tester.element(find.text('Play album'))).pop();
        await frames(tester);
        // A tap on the cover opens the album.
        final card = find
            .ancestor(
              of: find.text('Borrowed Tapes').first,
              matching: find.byType(InkWell),
            )
            .first;
        await tester.tapAt(tester.getTopLeft(card) + const Offset(40, 40));
        await frames(tester);
        expect(BrowserManager().albumDetail?.name, 'Borrowed Tapes');
        expect(BrowserManager().albumDetail?.server?.federationPeerId, 1);
      },
    );

    testWidgets(
      'a compilation is one card under its album artist; its sheet offers '
      'the album only, whole, and sends the row unchanged',
      (tester) async {
        h.peersAnswer = () => keepPeersPayload(extraB: compilationRows());
        await h.pumpDiscover(tester);
        expect(find.text('Block Party Comp'), findsOneWidget);
        expect(find.text('Various Artists'), findsOneWidget);
        await tester.longPress(find.text('Block Party Comp'));
        await frames(tester, 8);
        expect(find.byKey(const ValueKey('keep-chip-artist')), findsNothing);
        expect(find.text('4 songs'), findsOneWidget, reason: 'the whole album');
        final asked = h.facts.asked.firstWhere(
          (a) =>
              a.$2.endsWith('album-songs') &&
              a.$3['album'] == 'Block Party Comp',
        );
        expect(asked.$3['album_artist'], 'Various Artists');
        expect(asked.$3.containsKey('artist'), isFalse);
        await tapText(tester, 'Add album');
        final body = lastStart();
        expect(body['scope'], 'album');
        expect(body['recommendation'], equals(h.lead('Block Rocker').raw));
        expect(
          (body['recommendation'] as Map)['albumArtist'],
          'Various Artists',
        );
      },
    );

    testWidgets('every album with its count unknown asks with the artist', (
      tester,
    ) async {
      h.facts.peerDown = true;
      await h.pumpDiscover(tester);
      await tester.longPress(find.text('Borrowed Tapes').first);
      await frames(tester, 8);
      expect(find.text('Stage Peer B not answering'), findsOneWidget);
      await tapText(tester, 'Artist');
      await tapText(tester, 'Add every album');
      expect(
        find.text('Copy every album by Boukmanflow from Stage Peer B?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Copy every album'));
      await frames(tester);
      expect(lastStart()['scope'], 'artist');
    });
  });

  group('album rows (the album grid off)', () {
    tearDown(
      () => unawaited(
        SettingsManager().setAlbumGrid(true).catchError((Object _) {}),
      ),
    );

    testWidgets(
      "a connected server's album row: its copy's word leads its line, a "
      'long-press opens the album sheet',
      (tester) async {
        unawaited(
          SettingsManager().setAlbumGrid(false).catchError((Object _) {}),
        );
        h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          scope: 'album',
          state: 'queued',
        );
        await h.pumpDiscover(tester);
        expect(
          find.byKey(const ValueKey('album-card-more-Borrowed Tapes')),
          findsNothing,
        );
        expect(find.text('waiting'), findsWidgets);
        await tester.longPress(find.text('Peer Sessions'));
        await frames(tester, 8);
        expect(find.text('Play album'), findsOneWidget);
        expect(find.text('Add album'), findsOneWidget);
      },
    );

    testWidgets("an album row's copy says how far it is: 'copying 2 of 3'", (
      tester,
    ) async {
      unawaited(
        SettingsManager().setAlbumGrid(false).catchError((Object _) {}),
      );
      h.fake.addJob(
        keepRow('Late Train Verse', track: '02 - '),
        scope: 'album',
        state: 'running',
        progress: 0.45,
        statusText: '2 of 3 songs · 7.4 MB · Late Train Verse',
      );
      await h.pumpDiscover(tester);
      expect(find.text('copying 2 of 3'), findsOneWidget, reason: 'the row');
      expect(
        find.text('copying…'),
        findsNWidgets(2),
        reason: 'its song rows never count',
      );
    });
  });

  group('the page: markers and the Copies strip', () {
    testWidgets(
      "a row's glyph and word with its strip; a card's 'copying 2 of 3'; "
      "another server's copy marks nothing",
      (tester) async {
        h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          scope: 'album',
          state: 'running',
          progress: 0.45,
          statusText: '2 of 3 songs · 7.4 MB · Late Train Verse',
        );
        h.fake.addJob(
          keepRow(
            'Afterimage',
            artist: 'Color Out',
            album: 'Peer Sessions',
            duration: 11,
          ),
          state: 'failed',
        )['error'] = 'Stage Peer B no longer has this file';
        await h.pumpDiscover(tester);
        expect(
          find.byKey(const ValueKey('discovery-row-marker-copying')),
          findsNWidgets(2),
          reason: 'both of B\'s Borrowed Tapes rows',
        );
        expect(
          find.byKey(const ValueKey('discovery-row-copy-strip')),
          findsNWidgets(2),
        );
        expect(
          find.byKey(const ValueKey('discovery-row-marker-failed')),
          findsOneWidget,
        );
        expect(find.text('failed'), findsOneWidget);
        expect(
          find.textContaining('%'),
          findsNothing,
          reason: 'no percentages on the page',
        );
        // Stage Peer C's Rooftop Cypher shares the album key: no marker.
        final c = find.ancestor(
          of: find.text('Rooftop Cypher'),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(of: c, matching: find.textContaining('copying')),
          findsNothing,
        );
        // The marker word leads in the primary text; the row's own
        // "Artist · Album" stays secondary, as on its unmarked neighbours.
        final marked = find
            .byKey(const ValueKey('discovery-row-marker-copying'))
            .first;
        final word = tester.widget<Text>(
          find.descendant(of: marked, matching: find.text('copying…')),
        );
        expect(word.style!.color, VelvetColors.textPrimary);
        expect(word.style!.fontWeight, FontWeight.w500);
        final rest = tester.widget<Text>(
          find.descendant(
            of: marked,
            matching: find.text('· Boukmanflow · Borrowed Tapes'),
          ),
        );
        expect(rest.style!.color, VelvetColors.textSecondary);
        // The cards: B's says how far it is; C's says nothing.
        expect(find.text('copying 2 of 3'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('discovery-card-badge-copying')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the strip counts what runs or waits and what failed; a tap opens '
      'Copies',
      (tester) async {
        h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          state: 'running',
          progress: 0.2,
          statusText: 'copying',
        );
        h.fake.addJob(
          keepRow('Corner Store Loop', track: '03 - '),
          state: 'queued',
        );
        h.fake.addJob(
          keepRow('Afterimage', artist: 'Color Out', album: 'Peer Sessions'),
          state: 'failed',
        );
        await h.pumpDiscover(tester);
        expect(find.text('Copying 2'), findsOneWidget);
        expect(find.text('1 failed'), findsOneWidget);
        final strip = find.byKey(const ValueKey('discovery-copies-strip'));
        expect(
          topOf(tester, strip),
          greaterThan(
            topOf(tester, find.byKey(const ValueKey('discovery-config-bar'))),
          ),
        );
        await tester.tap(strip);
        await frames(tester);
        expect(h.openedCopies, ['copies']);
      },
    );

    testWidgets('only failures: their part alone', (tester) async {
      h.fake.addJob(
        keepRow('Afterimage', artist: 'Color Out', album: 'Peer Sessions'),
        state: 'failed',
      );
      await h.pumpDiscover(tester);
      expect(find.text('1 failed'), findsOneWidget);
      expect(find.textContaining('Copying'), findsNothing);
    });

    testWidgets('nothing live or failed: no strip', (tester) async {
      h.fake.addJob(
        keepRow('Late Train Verse', track: '02 - '),
        state: 'done',
        result: {
          'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/02.mp3'},
        },
      );
      await h.pumpDiscover(tester);
      expect(
        find.byKey(const ValueKey('discovery-copies-strip')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('discovery-copies-held')), findsNothing);
      expect(
        find.text('in your collection'),
        findsOneWidget,
        reason: 'the kept row reads so until the next ask drops it',
      );
    });

    testWidgets(
      "while the visit's first job list is out the strip's place is held: "
      'it lands without moving the page',
      (tester) async {
        h.fake.listGate = Completer<void>();
        h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          state: 'running',
          progress: 0.2,
          statusText: 'copying',
        );
        await h.pumpDiscover(tester);
        expect(
          find.byKey(const ValueKey('discovery-copies-held')),
          findsOneWidget,
        );
        final header = find.text('ALBUMS FROM YOUR LIBRARY');
        final before = topOf(tester, header);
        h.fake.listGate!.complete();
        await frames(tester);
        expect(
          find.byKey(const ValueKey('discovery-copies-held')),
          findsNothing,
        );
        expect(find.text('Copying 1'), findsOneWidget);
        expect(topOf(tester, header), before);
      },
    );
  });

  group('large text and German', () {
    testWidgets(
      'the song sheet at 1.3× in German on 360 px: everything wraps or '
      'ellipsizes, nothing overflows',
      (tester) async {
        await h.pumpDiscover(
          tester,
          width: 360,
          height: 2400,
          textScale: 1.3,
          locale: const Locale('de'),
        );
        await openSongSheet(tester, 'Late Train Verse');
        expect(tester.takeException(), isNull);
        expect(find.text('KOPIE BEHALTEN'), findsOneWidget);
        expect(find.text('Titel hinzufügen'), findsOneWidget);
        expect(find.text('Auf dieses Telefon laden'), findsOneWidget);
        await tapText(tester, 'Künstler');
        expect(tester.takeException(), isNull);
        expect(find.text('Nur das 1 Album, das dir fehlt'), findsOneWidget);
        expect(find.text('1 Album hinzufügen'), findsOneWidget);
      },
    );

    testWidgets('the album sheet and the strip at 1.3× in German', (
      tester,
    ) async {
      h.fake.addJob(
        keepRow('Late Train Verse', track: '02 - '),
        scope: 'album',
        state: 'running',
        progress: 0.3,
        statusText: '1 of 3 songs · 7.4 MB',
      );
      h.fake.addJob(
        keepRow('Afterimage', artist: 'Color Out', album: 'Peer Sessions'),
        state: 'failed',
      );
      await h.pumpDiscover(
        tester,
        width: 360,
        height: 2400,
        textScale: 1.3,
        locale: const Locale('de'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1 wird kopiert'), findsOneWidget);
      expect(find.text('1 fehlgeschlagen'), findsOneWidget);
      expect(find.text('kopiert 1 von 3'), findsOneWidget);
      await tester.longPress(find.text('Borrowed Tapes').first);
      await frames(tester, 8);
      expect(tester.takeException(), isNull);
      expect(find.text('Album abspielen'), findsOneWidget);
      expect(find.text('Wird kopiert'), findsOneWidget);
    });
  });

  // A finished wider copy speaks for the narrower choices (the user's
  // report, 2026-10-20): "Add 1 album" — only the albums you don't have —
  // copied Borrowed Tapes, and the Album choice still offered "Add album".
  group('a finished wider copy speaks for Album and This song', () {
    const tapes = 'peerlib/Boukmanflow/Borrowed Tapes';
    const threeSongs = [
      '01 - Rooftop Cypher.mp3',
      '02 - Late Train Verse.mp3',
      '03 - Corner Store Loop.mp3',
    ];
    Map<String, dynamic> landed(String file) => {
      'from': '$tapes/$file',
      'vpath': 'copies',
      'filepath': 'copies/Boukmanflow/Borrowed Tapes/$file',
      'trackId': 1,
      'bytes': 1000,
    };
    Map<String, dynamic> failedSong(String file) => {
      'from': '$tapes/$file',
      'error': 'Stage Peer B answered 500',
    };

    /// federation-copy's artist result: Borrowed Tapes walked with these
    /// songs (or not walked at all), and the albums it left out.
    Map<String, dynamic> walkResult(
      String scope, {
      List<Map<String, dynamic>> copied = const [],
      List<Map<String, dynamic>> failed = const [],
      List<Map<String, dynamic>> left = const [],
      bool walked = true,
      Map<String, Object> peer = peerB,
    }) {
      final songs = {
        'total': copied.length + failed.length,
        'copied': copied,
        'skipped': <Map<String, dynamic>>[],
        'failed': failed,
      };
      List<Map<String, dynamic>> tag(List<Map<String, dynamic>> l) => [
        for (final e in l) {'album': 'Borrowed Tapes', ...e},
      ];
      return {
        'scope': scope,
        'artist': {'name': 'Boukmanflow'},
        'albums': [
          if (walked)
            {
              'name': 'Borrowed Tapes',
              'year': 2019,
              'songs': songs,
              'bytes': 0,
              'stopped': null,
            },
        ],
        'skippedAlbums': left,
        'songs': walked
            ? {...songs, 'copied': tag(copied), 'failed': tag(failed)}
            : {'total': 0, 'copied': [], 'skipped': [], 'failed': []},
        'counts': {
          'total': walked ? copied.length + failed.length : 0,
          'copied': walked ? copied.length : 0,
          'skipped': 0,
          'failed': walked ? failed.length : 0,
        },
        'stopped': null,
        'peer': {'id': peer['id'], 'name': peer['name']},
      };
    }

    Map<String, dynamic> lateRow() =>
        keepRow('Late Train Verse', track: '02 - ', similarity: 0.95);

    Finder inCard(Finder f) =>
        find.descendant(of: find.byKey(const ValueKey('keep-copy')), matching: f);
    Future<void> chip(WidgetTester tester, String scope) async {
      final f = find.byKey(ValueKey('keep-chip-$scope'));
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await frames(tester);
    }

    testWidgets(
      "the report: once 'Add 1 album' copied Borrowed Tapes, Album reads "
      'in your collection (no Add album), and so does This song',
      (tester) async {
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await chip(tester, 'artist');
        await tapText(tester, 'Add 1 album');
        expect(lastStart()['scope'], 'artist-missing');
        final job = h.fake.jobs.first;
        job['state'] = 'done';
        job['progress'] = 1.0;
        job['finishedAt'] = 1760900009000;
        job['result'] = walkResult(
          'artist-missing',
          copied: [for (final f in threeSongs) landed(f)],
          left: [
            {'name': 'Night Market', 'year': 2018, 'why': 'owned'},
          ],
        );
        h.timers.active!.fire();
        await frames(tester, 10);
        expect(tester.takeException(), isNull);

        await chip(tester, 'album');
        expect(inCard(find.text('In your collection')), findsOneWidget);
        expect(inCard(find.text('3 copied')), findsOneWidget);
        expect(inCard(find.text('Add album')), findsNothing);
        expect(find.byKey(const ValueKey('keep-start')), findsNothing);

        await chip(tester, 'song');
        expect(inCard(find.text('In your collection')), findsOneWidget);
        expect(
          inCard(
            find.text(
              'copies / Boukmanflow / Borrowed Tapes / 02 - Late Train Verse.mp3',
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('keep-play')), findsOneWidget);
        expect(inCard(find.text('Add song')), findsNothing);
        final starts = h.fake.calls('POST', _jobs).length;

        // The album sheet (the card) reads the same.
        Navigator.of(tester.element(find.byKey(const ValueKey('keep-copy')))).pop();
        await frames(tester);
        await tester.longPress(find.text('Borrowed Tapes').first);
        await frames(tester, 8);
        expect(find.text('Play album'), findsOneWidget);
        expect(inCard(find.text('In your collection')), findsOneWidget);
        expect(inCard(find.text('3 copied')), findsOneWidget);
        expect(inCard(find.text('Add album')), findsNothing);
        expect(h.fake.calls('POST', _jobs), hasLength(starts));
        // The start's toast (shown once the song sheet closed) runs out.
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'left out as already owned: Album reads "Already yours" alone; This '
      'song still offers Add song (an album by name is not this song)',
      (tester) async {
        h.fake.addJob(
          lateRow(),
          scope: 'artist-missing',
          state: 'done',
          result: walkResult(
            'artist-missing',
            walked: false,
            left: [
              {'name': 'Borrowed Tapes', 'year': 2019, 'why': 'owned'},
            ],
          ),
        );
        await h.pumpDiscover(tester);
        await tester.longPress(find.text('Borrowed Tapes').first);
        await frames(tester, 8);
        expect(inCard(find.text('Already yours')), findsOneWidget);
        expect(inCard(find.textContaining('left out')), findsNothing);
        expect(inCard(find.text('Add album')), findsNothing);
        Navigator.of(tester.element(find.byKey(const ValueKey('keep-copy')))).pop();
        await frames(tester);

        await openSongSheet(tester, 'Late Train Verse');
        expect(inCard(find.text('Add song')), findsOneWidget);
        await chip(tester, 'album');
        expect(inCard(find.text('Already yours')), findsOneWidget);
      },
    );

    testWidgets(
      "a wider copy's failure for this album: its Retry copies the album, "
      'never the whole artist again',
      (tester) async {
        h.fake.addJob(
          lateRow(),
          scope: 'artist',
          state: 'done',
          result: walkResult(
            'artist',
            failed: [for (final f in threeSongs) failedSong(f)],
          ),
        );
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await chip(tester, 'album');
        expect(inCard(find.text('Copy failed')), findsOneWidget);
        expect(inCard(find.text('Nothing copied · 3 failed')), findsOneWidget);
        await tapText(tester, 'Retry');
        expect(lastStart()['scope'], 'album');
        expect(lastStart()['recommendation'], equals(h.lead('Late Train Verse').raw));
        expect(inCard(find.text('Waiting for a free slot')), findsOneWidget);
      },
    );

    testWidgets(
      'a wider copy that ran somewhere else: its Retry names where this '
      'album goes now, and sends that place',
      (tester) async {
        const layout = '{{ALBUMARTIST}}/{{ALBUM}}';
        h.fake.addJob(
          lateRow(),
          scope: 'artist',
          state: 'done',
          result: walkResult(
            'artist',
            failed: [for (final f in threeSongs) failedSong(f)],
          ),
        )['params'] = {
          'scope': 'artist',
          'destination': {'vpath': 'copies', 'base': 'Old', 'layout': layout},
        };
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await chip(tester, 'album');
        expect(inCard(find.text('Copy failed')), findsOneWidget);
        expect(
          inCard(
            line(
              'Retry adds to copies › Boukmanflow › Borrowed Tapes, your saved place now',
            ),
          ),
          findsOneWidget,
          reason: "the album choice's path, not the artist copy's",
        );
        await tapText(tester, 'Retry');
        expect(lastStart()['scope'], 'album');
        expect(lastStart()['destination'], {
          'vpath': 'copies',
          'base': '',
          'layout': layout,
        });
        expect(inCard(find.text('Waiting for a free slot')), findsOneWidget);
      },
    );

    testWidgets(
      "another server's finished artist copy says nothing here: Album "
      'offers Add album',
      (tester) async {
        h.fake.addJob(
          keepRow('Rooftop Cypher', track: '01 - ', similarity: 0.6, peer: peerC),
          scope: 'artist-missing',
          state: 'done',
          result: walkResult(
            'artist-missing',
            copied: [for (final f in threeSongs) landed(f)],
            peer: peerC,
          ),
        );
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await chip(tester, 'album');
        expect(inCard(find.text('Add album')), findsOneWidget);
        expect(inCard(find.text('In your collection')), findsNothing);
        await chip(tester, 'song');
        expect(inCard(find.text('Add song')), findsOneWidget);
      },
    );

    testWidgets(
      "the choice's own album job wins when newer; the wider copy's word "
      'when the album job ended first, whatever its id',
      (tester) async {
        final wider = h.fake.addJob(
          lateRow(),
          scope: 'artist-missing',
          state: 'done',
          result: walkResult(
            'artist-missing',
            copied: [for (final f in threeSongs) landed(f)],
          ),
        );
        final own = h.fake.addJob(
          lateRow(),
          scope: 'album',
          state: 'done',
          result: {
            'scope': 'album',
            'songs': {
              'total': 3,
              'copied': [],
              'skipped': [
                for (final f in threeSongs)
                  {'from': '$tapes/$f', 'why': 'owned', 'at': 'copies/x/$f'},
              ],
              'failed': [],
            },
            'counts': {'total': 3, 'copied': 0, 'skipped': 3, 'failed': 0},
            'stopped': null,
            'peer': peerB,
          },
        );
        wider['finishedAt'] = 1760900001000;
        own['finishedAt'] = 1760900002000;
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await chip(tester, 'album');
        expect(inCard(find.text('Already yours')), findsOneWidget);
        expect(inCard(find.text('3 already yours')), findsOneWidget);
        expect(inCard(find.text('3 copied')), findsNothing);
        Navigator.of(tester.element(find.byKey(const ValueKey('keep-copy')))).pop();
        await frames(tester);

        // The album job ended before the artist copy did: its word.
        own['finishedAt'] = 1760900000500;
        await h.jobs.refreshLookups();
        await frames(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await chip(tester, 'album');
        expect(inCard(find.text('In your collection')), findsOneWidget);
        expect(inCard(find.text('3 copied')), findsOneWidget);
      },
    );

    testWidgets('a live album job of its own always wins', (tester) async {
      h.fake.addJob(
        lateRow(),
        scope: 'artist-missing',
        state: 'done',
        result: walkResult(
          'artist-missing',
          copied: [for (final f in threeSongs) landed(f)],
        ),
      )['finishedAt'] = 1760900009000;
      h.fake.addJob(lateRow(), scope: 'album', state: 'queued');
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      await chip(tester, 'album');
      expect(inCard(find.text('Waiting for a free slot')), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-cancel')), findsOneWidget);
      expect(inCard(find.text('In your collection')), findsNothing);
    });

    testWidgets(
      "the album sheet reads every row of its card: an artist copy another "
      "row holds speaks for the card's Album choice, as the card's marker does",
      (tester) async {
        // The card's best row names a featured artist: its artist key is
        // not the copy's, so only the card's other rows hold the copy.
        h.peersAnswer = () => keepPeersPayload(
          extraB: [
            keepRow(
              'Borrowed Intro',
              artist: 'Boukmanflow feat. Ola',
              albumArtist: 'Boukmanflow',
              track: '00 - ',
              similarity: 0.99,
            ),
          ],
        );
        addTearDown(() => h.peersAnswer = keepPeersPayload);
        h.fake.addJob(
          lateRow(),
          scope: 'artist-missing',
          state: 'done',
          result: walkResult(
            'artist-missing',
            copied: [for (final f in threeSongs) landed(f)],
          ),
        );
        await h.pumpDiscover(tester);
        expect(
          h.jobs.choiceJob(h.lead('Borrowed Intro'), 'album'),
          isNull,
          reason: 'the best row alone holds no such copy',
        );
        await tester.longPress(find.text('Borrowed Tapes').first);
        await frames(tester, 8);
        expect(find.text('Play album'), findsOneWidget);
        expect(inCard(find.text('In your collection')), findsOneWidget);
        expect(inCard(find.text('3 copied')), findsOneWidget);
        expect(inCard(find.text('Add album')), findsNothing);
      },
    );
  });

  // Where files land moved while the card was open (another device, the
  // webapp): the card reads it again as it opens, every start sends the
  // place it showed, and the server's 409 destination_changed starts
  // nothing — the card redraws the path and says so in one line.
  group('where files land moved while the card was open', () {
    const layout = '{{ALBUMARTIST}}/{{ALBUM}}';
    const moved =
        'Where files land changed since this opened. Check the path above and add again.';
    const movedRetry =
        'Where files land changed since this opened. Check the path above and try again.';
    const here = {'vpath': 'copies', 'base': '', 'layout': layout};
    Map<String, dynamic> place(String base) => {
      'vpath': 'copies',
      'base': base,
      'layout': layout,
      'source': 'user',
    };
    void saveElsewhere(Map<String, dynamic>? destination) =>
        h.fake.destination = {
          ...h.fake.destination,
          'destination': destination,
        };
    Finder inCard(Finder f) => find.descendant(
      of: find.byKey(const ValueKey('keep-copy')),
      matching: f,
    );

    testWidgets(
      'the card reads it again as it opens: the last one known at once, the '
      'answer once it lands, and Add sends that place',
      (tester) async {
        await h.pumpDiscover(tester);
        final reads = h.fake.count('GET', '/collection/destination');
        h.fake.holdReads = true;
        saveElsewhere(place('From peers'));
        await openSongSheet(tester, 'Late Train Verse');
        expect(h.fake.count('GET', '/collection/destination'), reads + 1);
        expect(
          line('Files go to copies › Boukmanflow › Borrowed Tapes'),
          findsOneWidget,
          reason: 'drawn at once from the last one known',
        );
        h.fake.heldReads.single.complete();
        await frames(tester);
        expect(
          line(
            'Files go to copies › From peers › Boukmanflow › Borrowed Tapes',
          ),
          findsOneWidget,
        );
        await tapText(tester, 'Add song');
        expect(lastStart()['destination'], {
          'vpath': 'copies',
          'base': 'From peers',
          'layout': layout,
        });
        expect(find.text('Waiting for a free slot'), findsOneWidget);
      },
    );

    testWidgets(
      'a start refused because the place moved: the path redrawn, one '
      'warning line, nothing started; Add then sends the new place',
      (tester) async {
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(
          line('Files go to copies › Boukmanflow › Borrowed Tapes'),
          findsOneWidget,
        );
        saveElsewhere(place('From peers'));
        await tapText(tester, 'Add song');
        expect(lastStart()['destination'], {
          'vpath': 'copies',
          'base': '',
          'layout': layout,
        });
        expect(h.fake.jobs, isEmpty, reason: 'nothing started');
        expect(find.text('Waiting for a free slot'), findsNothing);
        expect(
          line(
            'Files go to copies › From peers › Boukmanflow › Borrowed Tapes',
          ),
          findsOneWidget,
        );
        expect(inCard(find.text(moved)), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(moved)).style!.color,
          keepTone(VelvetColors.warning),
        );
        expect(find.byKey(const ValueKey('keep-error')), findsNothing);
        expect(
          find.textContaining('destination', findRichText: true),
          findsNothing,
          reason: "the server's code is never shown",
        );
        expect(find.text('Add song'), findsOneWidget);

        await tapText(tester, 'Add song');
        expect(lastStart()['destination']['base'], 'From peers');
        expect(find.text('Waiting for a free slot'), findsOneWidget);
        expect(find.text(moved), findsNothing);
      },
    );

    testWidgets(
      'a refusal that says nowhere: the card gives way to "no library takes '
      'new files"',
      (tester) async {
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        saveElsewhere(null);
        await tapText(tester, 'Add song');
        expect(h.fake.jobs, isEmpty);
        expect(
          find.text('No library on your server takes new files'),
          findsOneWidget,
        );
        expect(find.text('Add song'), findsNothing);
        expect(find.text(moved), findsNothing);
      },
    );

    testWidgets(
      'a copy that ran somewhere else: the card names where Retry adds now, '
      'and Retry sends that place; one that ran here names nothing',
      (tester) async {
        final failed = h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          state: 'failed',
        );
        failed['error'] = 'Stage Peer B went away';
        failed['params'] = {'destination': place('Old')};
        final cancelled = h.fake.addJob(
          keepRow('Corner Store Loop', track: '03 - '),
          state: 'cancelled',
        );
        cancelled['params'] = {
          'destination': {'vpath': 'copies', 'base': '', 'layout': layout},
        };
        await h.pumpDiscover(tester);

        await openSongSheet(tester, 'Corner Store Loop');
        expect(inCard(find.text('Add again')), findsOneWidget);
        expect(find.textContaining('adds to'), findsNothing);
        Navigator.of(
          tester.element(find.byKey(const ValueKey('keep-copy'))),
        ).pop();
        await frames(tester);

        await openSongSheet(tester, 'Late Train Verse');
        expect(inCard(find.text('Copy failed')), findsOneWidget);
        // Its crumbs hold together as "Files go to"'s do.
        expect(
          inCard(
            line(
              'Retry adds to copies › Boukmanflow › Borrowed Tapes, your saved place now',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Borrowed\u00A0Tapes, your saved place now'),
          findsOneWidget,
        );
        await tapText(tester, 'Retry');
        expect(lastStart()['destination'], {
          'vpath': 'copies',
          'base': '',
          'layout': layout,
        });
        expect(find.text('Waiting for a free slot'), findsOneWidget);
      },
    );

    testWidgets(
      'a copy pinned to nowhere ran somewhere else too: the card names where '
      'Retry adds now, and Retry sends that place',
      (tester) async {
        final failed = h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          state: 'failed',
        );
        failed['error'] = 'no library to copy into';
        failed['params'] = {'destination': null};
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(inCard(find.text('Copy failed')), findsOneWidget);
        expect(
          inCard(
            line(
              'Retry adds to copies › Boukmanflow › Borrowed Tapes, your saved place now',
            ),
          ),
          findsOneWidget,
        );
        await tapText(tester, 'Retry');
        expect(lastStart()['destination'], here);
        expect(find.text('Waiting for a free slot'), findsOneWidget);
      },
    );

    testWidgets(
      'a cancelled copy that ran somewhere else: the card names where Add '
      'again adds now, and Add again sends that place',
      (tester) async {
        final cancelled = h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          state: 'cancelled',
        );
        cancelled['params'] = {'destination': place('Old')};
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(inCard(find.text('Add again')), findsOneWidget);
        expect(
          inCard(
            line(
              'Add again adds to copies › Boukmanflow › Borrowed Tapes, your saved place now',
            ),
          ),
          findsOneWidget,
        );
        await tapText(tester, 'Add again');
        expect(lastStart()['destination'], here);
        expect(find.text('Waiting for a free slot'), findsOneWidget);
      },
    );

    testWidgets(
      "Retry on a job's line refused because the place moved: nothing "
      'started, the new path drawn above one warning line, never the '
      "server's words; the next Retry sends the new place",
      (tester) async {
        final failed = h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          state: 'failed',
        );
        failed['error'] = 'Stage Peer B went away';
        failed['params'] = {'destination': here};
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(find.textContaining('adds to'), findsNothing, reason: 'it ran here');
        expect(
          find.byKey(const ValueKey('keep-destination')),
          findsNothing,
          reason: "the job's line stands in for it",
        );
        saveElsewhere(place('From peers'));
        await tapText(tester, 'Retry');
        expect(lastStart()['destination'], here);
        expect(h.fake.jobs, hasLength(1), reason: 'nothing started');
        expect(inCard(find.text('Copy failed')), findsOneWidget);
        final warning = find.byKey(const ValueKey('keep-moved'));
        expect(
          find.descendant(of: warning, matching: find.text(movedRetry)),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.text(movedRetry)).style!.color,
          keepTone(VelvetColors.warning),
        );
        expect(find.byKey(const ValueKey('keep-error')), findsNothing);
        expect(
          find.textContaining('destination', findRichText: true),
          findsNothing,
          reason: "the server's words are never shown",
        );
        // The path the warning points at, just above it.
        final path = line(
          'Files go to copies › From peers › Boukmanflow › Borrowed Tapes',
        );
        expect(path, findsOneWidget);
        expect(topOf(tester, path), lessThan(topOf(tester, warning)));
        expect(
          find.textContaining('adds to'),
          findsNothing,
          reason: '"Files go to" says where while the warning stands',
        );

        await tapText(tester, 'Retry');
        expect(lastStart()['destination']['base'], 'From peers');
        expect(find.text('Waiting for a free slot'), findsOneWidget);
        expect(warning, findsNothing);
      },
    );

    testWidgets(
      'a refusal that said nowhere leaves no warning behind: a place a later '
      'read brings back is drawn without it',
      (tester) async {
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        saveElsewhere(null);
        await tapText(tester, 'Add song');
        expect(
          find.text('No library on your server takes new files'),
          findsOneWidget,
        );
        // Another card opening, say: the place is back.
        saveElsewhere(place('From peers'));
        await h.jobs.loadDestination();
        await frames(tester);
        expect(
          line(
            'Files go to copies › From peers › Boukmanflow › Borrowed Tapes',
          ),
          findsOneWidget,
        );
        expect(find.text('Add song'), findsOneWidget);
        expect(find.byKey(const ValueKey('keep-moved')), findsNothing);
        expect(find.text(moved), findsNothing);
      },
    );

    testWidgets('Change, on the path the warning points at, lets it go', (
      tester,
    ) async {
      await h.pumpDiscover(tester);
      await openSongSheet(tester, 'Late Train Verse');
      saveElsewhere(place('From peers'));
      await tapText(tester, 'Add song');
      expect(find.text(moved), findsOneWidget);
      final opened = h.openedDestination.length;
      await tester.tap(find.byKey(const ValueKey('keep-change')));
      await frames(tester);
      expect(h.openedDestination, hasLength(opened + 1));
      expect(find.text(moved), findsNothing);
      expect(find.text('Add song'), findsOneWidget);
    });

    testWidgets(
      'Add every album sends the place its question named, even when a read '
      'lands while the question is open: refused, nothing started',
      (tester) async {
        await h.pumpDiscover(tester);
        h.fake.holdReads = true;
        saveElsewhere(place('From peers'));
        await openSongSheet(tester, 'Late Train Verse');
        await tapText(tester, 'Artist');
        await tester.tap(find.byKey(const ValueKey('keep-only-missing')));
        await frames(tester);
        expect(
          line('Files go to copies › Boukmanflow › one folder per album'),
          findsOneWidget,
          reason: 'the last one known, the read still out',
        );
        await tapText(tester, 'Add every album');
        expect(
          find.text(
            'They land on your server in copies › Boukmanflow, one folder per album. Songs you already have are skipped.',
          ),
          findsOneWidget,
        );
        // The card's read lands behind the question.
        h.fake.holdReads = false;
        for (final r in h.fake.heldReads) {
          r.complete();
        }
        await frames(tester);
        expect(
          line(
            'Files go to copies › From peers › Boukmanflow › one folder per album',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Copy 1 album'));
        await frames(tester);
        expect(lastStart()['scope'], 'artist');
        expect(lastStart()['destination'], here, reason: 'what the question named');
        expect(h.fake.jobs, isEmpty, reason: 'nothing started');
        expect(inCard(find.text(moved)), findsOneWidget);
      },
    );

    testWidgets(
      "the album sheet's Album, and a compilation card's, send the place the "
      'card drew',
      (tester) async {
        h.peersAnswer = () => keepPeersPayload(extraB: compilationRows());
        addTearDown(() => h.peersAnswer = keepPeersPayload);
        saveElsewhere(place('From peers'));
        await h.pumpDiscover(tester);
        await tester.longPress(find.text('Borrowed Tapes').first);
        await frames(tester, 8);
        expect(
          line(
            'Files go to copies › From peers › Boukmanflow › Borrowed Tapes',
          ),
          findsOneWidget,
        );
        await tapText(tester, 'Add album');
        expect(lastStart()['scope'], 'album');
        expect(lastStart()['destination'], {
          'vpath': 'copies',
          'base': 'From peers',
          'layout': layout,
        });
        Navigator.of(
          tester.element(find.byKey(const ValueKey('keep-copy'))),
        ).pop();
        await frames(tester);

        await tester.longPress(find.text('Block Party Comp'));
        await frames(tester, 8);
        expect(
          line(
            'Files go to copies › From peers › Various Artists › Block Party Comp',
          ),
          findsOneWidget,
        );
        await tapText(tester, 'Add album');
        expect(
          (lastStart()['recommendation'] as Map)['albumArtist'],
          'Various Artists',
        );
        expect(lastStart()['destination'], {
          'vpath': 'copies',
          'base': 'From peers',
          'layout': layout,
        });
        // The first start's toast (shown once its sheet closed) runs out.
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'a live copy already covering the song answers even a place that '
      'moved: the card follows it, no warning',
      (tester) async {
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        saveElsewhere(place('From peers'));
        h.fake.existing = h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - '),
          state: 'running',
          progress: 0.3,
        );
        await tapText(tester, 'Add song');
        expect(lastStart()['destination'], here);
        expect(inCard(find.text('Copying')), findsOneWidget);
        expect(find.byKey(const ValueKey('keep-moved')), findsNothing);
        expect(find.byKey(const ValueKey('keep-error')), findsNothing);
      },
    );
  });

  group('a path that cannot promise one folder: each song files under its own '
      'tags', () {
    const artistNote =
        "‹artist› comes from each song's own tags, so these songs can land "
        'in more than one folder.';
    const yearNote =
        "‹year› comes from each song's own tags, so these songs can land in "
        'more than one folder.';
    const genreNote =
        "‹genre› comes from each song's own tags, so these songs can land in "
        'more than one folder (a song with none leaves that folder out).';
    void useLayout(String layout, {String base = ''}) => h.fake.destination = {
      ...h.fake.destination,
      'destination': {
        'vpath': 'copies',
        'base': base,
        'layout': layout,
        'source': 'user',
      },
    };
    Finder inCard(Finder f) => find.descendant(
      of: find.byKey(const ValueKey('keep-copy')),
      matching: f,
    );

    /// The span that draws [text] inside the widget keyed [key].
    TextSpan? spanOf(WidgetTester tester, String key, String text) {
      TextSpan? found;
      for (final rich in tester.widgetList<RichText>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(RichText),
        ),
      )) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text == text) found = span;
          return found == null;
        });
        if (found != null) break;
      }
      return found;
    }

    Future<void> openSampler(WidgetTester tester) async {
      h.peersAnswer = () => keepPeersPayload(extraB: nightMarketRows());
      await h.pumpDiscover(tester);
      await tester.ensureVisible(find.text('Night Market Sampler').first);
      await tester.pump();
    }

    testWidgets(
      "Night Market Sampler with From friends/{{ARTIST}}: the album card's "
      '"Files go to" says copies › From friends › ‹artist› and why — never '
      "the one row's artist, before its songs answer and after",
      (tester) async {
        useLayout('From friends/{{ARTIST}}');
        h.facts.gate = Completer<void>();
        await openSampler(tester);
        await tester.longPress(find.text('Night Market Sampler').first);
        await frames(tester, 8);
        // A compilation: the slot before the listing answers.
        expect(
          line('Files go to copies › From friends › ‹artist›'),
          findsOneWidget,
        );
        expect(find.text(artistNote), findsOneWidget);
        h.facts.gate!.complete();
        await frames(tester);
        expect(find.text('3 songs'), findsOneWidget);
        expect(
          line('Files go to copies › From friends › ‹artist›'),
          findsOneWidget,
          reason: 'Color Out, Boukmanflow and ALM: three folders',
        );
        expect(
          inCard(find.textContaining('Boukmanflow', findRichText: true)),
          findsNothing,
          reason: "the bug: 'copies › From friends › Boukmanflow'",
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('keep-destination')),
            matching: find.text(artistNote),
          ),
          findsOneWidget,
        );
        // Drawn quiet and italic, as the picker's slot is.
        final slot = spanOf(tester, 'keep-destination', '‹artist›');
        expect(slot?.style?.fontStyle, FontStyle.italic);
        expect(slot?.style?.color, VelvetColors.textSecondary);
        expect(
          spanOf(tester, 'keep-destination', 'From friends')?.style?.color,
          VelvetColors.textPrimary,
          reason: "the layout's own folder reads as a folder",
        );
      },
    );

    testWidgets(
      "the compilation's song sheet: This song lands under its own artist; "
      'Album under the slot',
      (tester) async {
        useLayout('From friends/{{ARTIST}}');
        await openSampler(tester);
        await tester.longPress(find.text('Lantern Row'));
        await frames(tester, 8);
        expect(
          line('Files go to copies › From friends › Boukmanflow'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('keep-slot-note')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('keep-chip-album')));
        await frames(tester);
        expect(
          line('Files go to copies › From friends › ‹artist›'),
          findsOneWidget,
        );
        expect(find.text(artistNote), findsOneWidget);
        // {{ALBUMARTIST}} is the album's credit: one folder, no slot.
        useLayout('{{ALBUMARTIST}}/{{ALBUM}}');
        await h.jobs.loadDestination();
        await frames(tester);
        expect(
          line('Files go to copies › Various Artists › Night Market Sampler'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('keep-slot-note')), findsNothing);
      },
    );

    testWidgets(
      "one artist's album: the year once every song agrees; mixed years "
      'are the slot',
      (tester) async {
        useLayout('{{ARTIST}}/{{YEAR}}');
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(line('Files go to copies › Boukmanflow › 2019'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('keep-chip-album')));
        await frames(tester);
        expect(line('Files go to copies › Boukmanflow › 2019'), findsOneWidget);
        expect(find.byKey(const ValueKey('keep-slot-note')), findsNothing);
        Navigator.of(
          tester.element(find.byKey(const ValueKey('keep-copy'))),
        ).pop();
        await frames(tester);

        h.facts.albums['Borrowed Tapes'] = [
          for (final (i, y) in [2019, 2020, 2019].indexed)
            songOf(
              'peerlib/Boukmanflow/Borrowed Tapes/0${i + 1}.mp3',
              'Song $i',
              'Boukmanflow',
              'Borrowed Tapes',
              9,
              year: y,
            ),
        ];
        await openSongSheet(tester, 'Late Train Verse');
        expect(
          line('Files go to copies › Boukmanflow › 2019'),
          findsOneWidget,
          reason: "This song: the song's own year",
        );
        await tester.tap(find.byKey(const ValueKey('keep-chip-album')));
        await frames(tester);
        expect(
          line('Files go to copies › Boukmanflow › ‹year›'),
          findsOneWidget,
        );
        expect(find.text(yearNote), findsOneWidget);
      },
    );

    testWidgets(
      "the genre: a song's own when the album's listing tells it, else the "
      'slot; every album, and the question that names the path',
      (tester) async {
        useLayout('{{GENRE}}/{{ARTIST}}/{{ALBUM}}');
        h.facts.genres['Late Train Verse'] = ['Hip-Hop'];
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(
          line('Files go to copies › Hip-Hop › Boukmanflow › Borrowed Tapes'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('keep-slot-note')), findsNothing);
        // The album's other songs carry no genre the phone can tell.
        await tester.tap(find.byKey(const ValueKey('keep-chip-album')));
        await frames(tester);
        expect(
          line('Files go to copies › ‹genre› › Boukmanflow › Borrowed Tapes'),
          findsOneWidget,
        );
        expect(find.text(genreNote), findsOneWidget);
        // Every album: the genre before the album's folder is the slot.
        await tester.tap(find.byKey(const ValueKey('keep-chip-artist')));
        await frames(tester);
        await tester.tap(find.byKey(const ValueKey('keep-only-missing')));
        await frames(tester);
        expect(
          line(
            'Files go to copies › ‹genre› › Boukmanflow › one folder per album',
          ),
          findsOneWidget,
        );
        expect(find.text(genreNote), findsOneWidget);
        await tester.ensureVisible(find.text('Add every album'));
        await tester.pump();
        await tester.tap(find.text('Add every album'));
        await frames(tester);
        expect(
          find.text(
            'They land on your server in copies › ‹genre› › Boukmanflow, one '
            'folder per album. Songs you already have are skipped.\n\n'
            '$genreNote',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel').last);
        await frames(tester);
      },
    );

    testWidgets(
      'Retry on a copy that ran somewhere else names where it adds now, the '
      'slot and its note with it',
      (tester) async {
        const layout = 'From friends/{{ARTIST}}';
        useLayout(layout);
        final failed = h.fake.addJob(
          nightMarketRows().first,
          scope: 'album',
          state: 'failed',
        );
        failed['error'] = 'Stage Peer B went away';
        failed['params'] = {
          'scope': 'album',
          'destination': {'vpath': 'copies', 'base': 'Old', 'layout': layout},
        };
        await openSampler(tester);
        await tester.longPress(find.text('Night Market Sampler').first);
        await frames(tester, 8);
        expect(inCard(find.text('Copy failed')), findsOneWidget);
        expect(
          inCard(
            line(
              'Retry adds to copies › From friends › ‹artist›, your saved '
              'place now',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('keep-again-slot-note')),
            matching: find.text(artistNote),
          ),
          findsOneWidget,
        );
        expect(
          spanOf(tester, 'keep-job', '‹artist›')?.style?.fontStyle,
          FontStyle.italic,
        );
      },
    );

    testWidgets(
      "a song whose ARTIST tag names a guest: This song lands under the tag "
      'as written, Album under the slot',
      (tester) async {
        useLayout('From friends/{{ARTIST}}');
        h.facts.albums['Borrowed Tapes'] = featuredTapes();
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        expect(
          line('Files go to copies › From friends › Boukmanflow feat. ALM'),
          findsOneWidget,
          reason: "the file's tag, not the row's Boukmanflow",
        );
        expect(find.byKey(const ValueKey('keep-slot-note')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('keep-chip-album')));
        await frames(tester);
        expect(
          line('Files go to copies › From friends › ‹artist›'),
          findsOneWidget,
        );
        expect(find.text(artistNote), findsOneWidget);
      },
    );

    testWidgets(
      'every album under a layout that names no album: one folder for them '
      'all, said so in the question',
      (tester) async {
        useLayout('From friends/{{ARTIST}}');
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await tester.tap(find.byKey(const ValueKey('keep-chip-artist')));
        await frames(tester);
        await tester.tap(find.byKey(const ValueKey('keep-only-missing')));
        await frames(tester);
        expect(
          line('Files go to copies › From friends › Boukmanflow'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Add every album'));
        await tester.pump();
        await tester.tap(find.text('Add every album'));
        await frames(tester);
        expect(
          find.text(
            'They land on your server in copies › From friends › '
            'Boukmanflow. Songs you already have are skipped.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel').last);
        await frames(tester);
      },
    );

    testWidgets(
      "an every-album copy's Retry names where it adds now as Files go to "
      'does: one folder per album under it',
      (tester) async {
        const layout = '{{ARTIST}}/{{ALBUM}}';
        useLayout(layout);
        // Borrowed Tapes is already here: no only-missing box, every album.
        h.facts.libraryAlbums['boukmanflow'] = [
          ...h.facts.libraryAlbums['boukmanflow']!,
          'Borrowed Tapes',
        ];
        final failed = h.fake.addJob(
          keepRow('Late Train Verse', track: '02 - ', similarity: 0.95),
          scope: 'artist',
          state: 'failed',
        );
        failed['error'] = 'Stage Peer B went away';
        failed['params'] = {
          'scope': 'artist',
          'destination': {'vpath': 'copies', 'base': 'Old', 'layout': layout},
        };
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await tester.tap(find.byKey(const ValueKey('keep-chip-artist')));
        await frames(tester);
        expect(inCard(find.text('Copy failed')), findsOneWidget);
        expect(
          inCard(
            line(
              'Retry adds to copies › Boukmanflow › one folder per album, '
              'your saved place now',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('keep-again-slot-note')),
          findsNothing,
        );
      },
    );

    testWidgets(
      "the one album an only-missing copy takes: its folder carries the "
      "year the connected server's album list gives it",
      (tester) async {
        useLayout('{{ARTIST}}/{{YEAR}}/{{ALBUM}}');
        h.facts.peerAlbums['boukmanflow'] = ['Borrowed Tapes', 'B-Sides'];
        h.facts.albumYears['B-Sides'] = 2017;
        h.facts.libraryAlbums['boukmanflow'] = [
          ...h.facts.libraryAlbums['boukmanflow']!,
          'Borrowed Tapes',
        ];
        await h.pumpDiscover(tester);
        await openSongSheet(tester, 'Late Train Verse');
        await tester.tap(find.byKey(const ValueKey('keep-chip-artist')));
        await frames(tester);
        expect(find.text("Only the 1 album you don't have"), findsOneWidget);
        expect(
          line('Files go to copies › Boukmanflow › 2017 › B-Sides'),
          findsOneWidget,
          reason: "not this row's 2019: B-Sides is another album",
        );
      },
    );
  });
}
