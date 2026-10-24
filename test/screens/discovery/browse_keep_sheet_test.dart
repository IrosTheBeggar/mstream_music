// The Keep a copy sheet entered while browsing a connected server (the
// phone spec's §6, its RecSheets boards): what each door passes and the
// three shapes it opens in (V-page, V-item, V-menu); album focus with the
// artist's own albums counted; the song sheet whose chips append as its
// tags and its album's credit arrive; the new artist focus with only the
// missing and the left-out line; the sticky Add (only here — Discover's
// sheets keep theirs inline); a refused start as one plain line; the
// connected server not answering; the start toast with View; large text,
// and the colours Light and Velvet draw with.

import 'dart:async';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/screens/discovery/peer_sheets.dart'
    show BrowseKeepSheet, showBrowseKeepSheet;
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';

import 'browse_keep_sheet_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseSheetHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<void> frames(WidgetTester tester, [int n = 6]) =>
      BrowseSheetHarness.frames(tester, n);

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await frames(tester);
  }

  double topOf(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  group('album focus', () {
    testWidgets('from the page pill (V-page): Listen without Open album, '
        'Album and Artist with their sizes, the path, Add album pinned', (
      tester,
    ) async {
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      expect(tester.takeException(), isNull);

      // The header names the album, its credit and the server.
      expect(find.text('Borrowed Tapes'), findsOneWidget);
      expect(
        find.text('Boukmanflow · 2019 · 3 songs · 0:29'),
        findsOneWidget,
      );
      expect(find.text('Stage Peer B online'), findsOneWidget);
      // Listen: Play album and Queue album; the album is behind the sheet.
      expect(find.text('Play album'), findsOneWidget);
      expect(find.text('Queue album'), findsOneWidget);
      expect(find.text('Open album'), findsNothing);
      // Never the Discover sheet's extras.
      expect(find.textContaining('Browse '), findsNothing);
      expect(find.text('Download to this phone'), findsNothing);
      expect(find.text('Open elsewhere'), findsNothing);
      // Album chosen; Artist counts THEIR albums and the ones you have.
      expect(find.text('3 songs'), findsOneWidget);
      expect(find.text('3 albums · you have 1'), findsOneWidget);
      expect(
        line('Files go to copies › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
      // The Add sits in the pinned bar, under the scrolling body.
      final bar = find.byKey(const ValueKey('keep-add-bar'));
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.text('Add album')),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: bar, matching: find.byType(SingleChildScrollView)),
        findsNothing,
        reason: 'pinned, not scrolled',
      );
      // Its pill in words only: ⊞ is the queue's (the page's Add All).
      expect(
        tester
            .widget<KeepPill>(
              find.descendant(
                of: bar,
                matching: find.byKey(const ValueKey('keep-start')),
              ),
            )
            .icon,
        isNull,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(Icon)),
        findsNothing,
      );

      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final body = h.lastStart();
      expect(body['scope'], 'album');
      expect(body['recommendation'], {
        'source': 'federation',
        'peer': peerB,
        'album': 'Borrowed Tapes',
        'albumArtist': 'Boukmanflow',
        'artist': 'Boukmanflow',
        'year': 2019,
      });
      expect(body.containsKey('landing'), isFalse);
      // The job's line takes the card; the bar goes with the idle state.
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });

    testWidgets('from a card (V-item): Open album › in Listen', (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.albumCard());
      expect(find.text('Open album'), findsOneWidget);
      expect(find.text('Play album'), findsOneWidget);
    });

    testWidgets('a compilation: the lone Album chip, the whole album under '
        'its credit', (tester) async {
      await h.pumpHost(tester);
      final comp = h.album(
        'Night Market Sampler',
        credit: 'Various Artists',
        year: 2024,
        compilation: true,
        artists: const ['Color Out', 'Boukmanflow', 'ALM'],
      );
      await h.open(tester, h.albumCard(comp));
      expect(find.byKey(const ValueKey('keep-chip-album')), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-chip-artist')), findsNothing);
      expect(find.text('3 songs'), findsOneWidget, reason: 'asked by credit');
      expect(
        line('Files go to copies › Various Artists › Night Market Sampler'),
        findsOneWidget,
      );
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final rec = h.lastStart()['recommendation'] as Map;
      expect(rec['albumArtist'], 'Various Artists');
      expect(rec.containsKey('artist'), isFalse);
      expect(rec['compilation'], isTrue);
    });

    testWidgets('Artist chosen: only the missing ticked, the left-out line, '
        'one folder per album, Add 2 albums', (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      await tapKey(tester, 'keep-chip-artist');
      expect(find.text("Only the 2 albums you don't have"), findsOneWidget);
      expect(
        find.text(
          'Leaves out Night Market Sampler: Boukmanflow only appears on '
          'it. Songs outside an album stay out too.',
        ),
        findsOneWidget,
      );
      expect(
        line('Files go to copies › Boukmanflow › one folder per album'),
        findsOneWidget,
      );
      expect(find.text('Add 2 albums'), findsOneWidget);
      // The left-out line sits right above the path.
      expect(
        topOf(tester, find.byKey(const ValueKey('keep-left-out'))),
        lessThan(topOf(tester, find.byKey(const ValueKey('keep-destination')))),
      );
    });
    testWidgets("another server's live copy of this album: \"Copying from "
        'Stage Peer C", Add album comes back when it ends; no bar', (
      tester,
    ) async {
      h.fake.addJob(
        {
          'source': 'federation',
          'peer': peerC,
          'album': 'Borrowed Tapes',
          'albumArtist': 'Boukmanflow',
          'artist': 'Boukmanflow',
          'year': 2019,
        },
        scope: 'album',
        state: 'running',
        progress: 0.5,
        statusText: '1 of 3 songs · 2.0 MB',
      );
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      expect(find.text('Copying from Stage Peer C'), findsOneWidget);
      expect(
        find.text('Add album comes back when that copy ends'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });

    testWidgets("the page's own lookup failed: the sheet asks afresh and shows "
        'the copy there is — never Add for an album already yours', (
      tester,
    ) async {
      final r = h.albumPage();
      h.fake.addJob(
        Map<String, dynamic>.of(r.lead),
        scope: 'album',
        state: 'done',
        result: {
          'scope': 'album',
          'songs': {'total': 3, 'copied': [{}, {}, {}], 'skipped': [], 'failed': []},
          'counts': {'total': 3, 'copied': 3, 'skipped': 0, 'failed': 0},
          'stopped': null,
        },
      );
      await h.pumpHost(tester);
      h.fake.refuse['/lookup/batch'] = (503, 'busy');
      await h.marks.ask([r.lead]);
      expect(h.marks.knows(r.lead), isFalse, reason: 'the page drew no marks');
      h.fake.refuse.remove('/lookup/batch');
      await h.open(tester, r);
      expect(find.text('In your collection'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });
  });

  for (final theme in AppTheme.values) {
    testWidgets("${theme.name}: the left-out line reads at 4.5:1 on the card", (
      tester,
    ) async {
      VelvetColors.setActive(paletteFor(theme));
      await h.pumpHost(tester);
      await h.open(tester, h.artistPage());
      final words = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('keep-left-out')),
          matching: find.byType(Text),
        ),
      );
      expect(
        _contrast(words.style!.color!, VelvetColors.card),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  group('Listen', () {
    testWidgets('Play album from a card: the sheet closes first, the album\'s '
        'songs still answer and play — never "couldn\'t load"', (
      tester,
    ) async {
      final played = <List<String>>[];
      BrowseKeepSheet.play = (songs) async =>
          played.add([for (final s in songs) s.data!]);
      final gate = Completer<void>();
      await h.pumpHost(tester);
      unawaited(
        showBrowseKeepSheet(
          h.host!,
          h.albumCard(),
          marks: h.marks,
          fetch: (s, location, body) async {
            if (location.endsWith('/db/album-songs')) await gate.future;
            return h.facts.call(s, location, body);
          },
          track: h.facts.track,
        ),
      );
      await frames(tester, 10);
      await tapKey(tester, 'browse-keep-play-album');
      await frames(tester, 10);
      expect(find.byKey(const ValueKey('browse-keep-sheet')), findsNothing,
          reason: 'closed while the songs are still out');
      gate.complete();
      await frames(tester, 10);
      expect(played.single, hasLength(3));
      expect(h.toasts.where((t) => t.contains("Couldn't load")), isEmpty);
    });

    testWidgets('Queue album from the page pill: the page\'s own songs, '
        'nothing asked again', (tester) async {
      final queued = <int>[];
      BrowseKeepSheet.queue = (songs) async {
        queued.add(songs.length);
        return songs.length;
      };
      final page = [h.song(), h.song(title: 'Rooftop Cypher', file: '01 - Rooftop Cypher.mp3')];
      await h.pumpHost(tester);
      await h.open(
        tester,
        BrowseKeepRequest.album(
          h.album('Borrowed Tapes'),
          variant: KeepVariant.page,
          songs: page,
        )!,
      );
      await tapKey(tester, 'browse-keep-queue-album');
      await frames(tester, 10);
      expect(queued, [2]);
      expect(h.toasts, contains('2 songs added to queue'));
    });
  });

  group('artist focus', () {
    testWidgets('header, no Listen, no chips; only the missing, the left-out '
        'line, the path; the confirm names what it copies', (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.artistPage());
      expect(tester.takeException(), isNull);
      expect(find.text('Boukmanflow'), findsOneWidget);
      expect(find.text('Artist · 4 albums on Stage Peer B'), findsOneWidget);
      expect(find.text('LISTEN'), findsNothing);
      expect(find.byKey(const ValueKey('keep-chip-artist')), findsNothing);
      expect(find.text("Only the 2 albums you don't have"), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-left-out')), findsOneWidget);
      expect(find.text('Add 2 albums'), findsOneWidget);
      // The page's own answer: the peer is not asked again.
      expect(
        h.facts.asked.where(
          (a) => a.startsWith('peer-1') && a.contains('artists-albums'),
        ),
        isEmpty,
      );

      await tapKey(tester, 'keep-start');
      expect(find.text('Copy 2 albums from Stage Peer B?'), findsOneWidget);
      await tester.tap(find.text('Copy 2 albums'));
      await frames(tester, 8);
      expect(h.lastStart()['scope'], 'artist-missing');
      expect(h.lastStart()['recommendation'], {
        'source': 'federation',
        'peer': peerB,
        'artist': 'Boukmanflow',
      });
    });

    testWidgets('unticked: Add every album, the every-album question',
        (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.artistPage());
      await tapKey(tester, 'keep-only-missing');
      expect(find.text('Add every album'), findsOneWidget);
      await tapKey(tester, 'keep-start');
      expect(
        find.text('Copy every album by Boukmanflow from Stage Peer B?'),
        findsOneWidget,
      );
    });

    testWidgets('nothing missing: no box, Add every album', (tester) async {
      h.facts.libraryAlbums['boukmanflow'] = [
        'Borrowed Tapes',
        'Harbour Lights',
        'Second Shift',
      ];
      await h.pumpHost(tester);
      await h.open(tester, h.artistPage());
      expect(find.byKey(const ValueKey('keep-only-missing')), findsNothing);
      expect(find.text('Add every album'), findsOneWidget);
    });

    testWidgets('theirs = 0: one line, no path, no Add', (tester) async {
      await h.pumpHost(tester);
      final r = BrowseKeepRequest.artistPage(
        ArtistContext(
          server: h.peer,
          name: 'Lantern Choir',
          albums: h.facts.peerAlbums['lantern choir']!,
        ),
      )!;
      await h.open(tester, r);
      expect(
        find.text(
          'Lantern Choir only appears on albums here, so there is no artist '
          'copy.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-destination')), findsNothing);
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });
  });

  group('the song sheet (V-menu)', () {
    testWidgets('from an album-page row: the header and Keep a copy only; '
        'This song · Album (the page credit) · Artist (theirs)', (
      tester,
    ) async {
      await h.pumpHost(tester);
      final r = BrowseKeepRequest.song(h.song(), albumCredit: 'Boukmanflow')!;
      await h.open(tester, r);
      expect(find.text('Late Train Verse'), findsOneWidget);
      expect(find.text('Boukmanflow  ·  Borrowed Tapes'), findsOneWidget);
      expect(find.text('MP3  ·  0:08'), findsOneWidget);
      // V-menu: nothing of the menu that just closed.
      expect(find.text('LISTEN'), findsNothing);
      expect(find.text('Add next'), findsNothing);
      expect(find.text('This song'), findsOneWidget);
      expect(find.text('0:08 · MP3'), findsOneWidget);
      expect(find.text('3 songs'), findsOneWidget);
      expect(find.text('3 albums · you have 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-chip-folder')), findsNothing);
      expect(find.text('Add song'), findsOneWidget);
      // The page knew the credit: no tags read.
      expect(h.facts.count('track'), 0);
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final body = h.lastStart();
      expect(body.containsKey('scope'), isFalse);
      expect((body['recommendation'] as Map)['filepath'],
          '$tapesDir/02 - Late Train Verse.mp3');
    });

    testWidgets('from an explorer file row with no tags: This song · Folder, '
        'then Album and Artist append once its tags answer', (tester) async {
      await h.pumpHost(tester);
      h.facts.trackGate = Completer<void>();
      final row = h.song(tagged: false);
      final r = BrowseKeepRequest.song(
        row,
        folder: FolderRef.parentOf(row.data),
      )!;
      await h.open(tester, r);
      expect(find.text('02 - Late Train Verse.mp3'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-chip-song')), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsNothing);
      expect(find.byKey(const ValueKey('keep-chip-artist')), findsNothing);
      expect(find.byKey(const ValueKey('keep-chip-folder')), findsOneWidget);
      // The Folder chip names its folder until counted.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('keep-chip-folder')),
          matching: find.text('Borrowed Tapes'),
        ),
        findsOneWidget,
      );
      h.facts.trackGate!.complete();
      await frames(tester, 10);
      expect(find.text('Late Train Verse'), findsOneWidget);
      expect(find.text('Boukmanflow  ·  Borrowed Tapes'), findsOneWidget);
      for (final c in ['song', 'album', 'artist', 'folder']) {
        expect(find.byKey(ValueKey('keep-chip-$c')), findsOneWidget, reason: c);
      }
      expect(h.facts.count('track'), 1, reason: 'one metadata read');
      // Nothing counted on a page view: only once Folder is chosen.
      expect(h.facts.count('recursive'), 0);
      await tapKey(tester, 'keep-chip-folder');
      await frames(tester);
      expect(h.facts.count('recursive'), 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('keep-chip-folder')),
          matching: find.text('3 songs'),
        ),
        findsOneWidget,
      );
      expect(find.text('Where it lands'), findsOneWidget);
      expect(find.text('Add folder · 3 songs'), findsOneWidget);
      // The header stays the song's.
      expect(find.text('Late Train Verse'), findsOneWidget);
    });

    testWidgets('a Recent row whose tags name no credit: the album list names '
        'it, and Album appears', (tester) async {
      h.facts.trackTags.clear();
      await h.pumpHost(tester);
      final r = BrowseKeepRequest.song(h.song())!;
      await h.open(tester, r);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-chip-folder')), findsNothing);
      await tapKey(tester, 'keep-chip-album');
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final rec = h.lastStart()['recommendation'] as Map;
      expect(rec['albumArtist'], 'Boukmanflow');
      expect(h.lastStart()['scope'], 'album');
    });

    // Rule 1, credits that disagree mean no Album: Split Series' songs each
    // name their own half's album artist ("ALM"), and its album list says
    // they disagree (album_artist null).
    DisplayItem splitSong() => h.song(
      title: 'One',
      file: '01 - One.mp3',
      artist: 'ALM',
      album: 'Split Series',
      dir: 'music/ALM/Split Series',
      year: 2022,
      albumArtist: 'ALM',
    );
    void splitListing() {
      h.facts.peerAlbums['alm'] = [
        {
          'name': 'Split Series',
          'year': 2022,
          'album_artist': null,
          'artists': ['ALM', 'Night Owl Radio'],
          'compilation': false,
          'track_count': 2,
        },
      ];
    }

    testWidgets("a song of an album page whose songs disagree: no Album, "
        "whatever the song's own album-artist says", (tester) async {
      splitListing();
      await h.pumpHost(tester);
      await h.open(
        tester,
        BrowseKeepRequest.song(splitSong(), pageCredit: AlbumCredit.disagree)!,
      );
      expect(find.byKey(const ValueKey('keep-chip-song')), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsNothing);
      expect(h.facts.count('track'), 0, reason: 'the page said: nothing read');
    });

    testWidgets("a Recent row of Split Series: the album list's word beats "
        "the song's own album-artist — no Album", (tester) async {
      splitListing();
      await h.pumpHost(tester);
      await h.open(tester, BrowseKeepRequest.song(splitSong())!);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsNothing);
      expect(find.byKey(const ValueKey('keep-chip-artist')), findsOneWidget);
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final rec = h.lastStart()['recommendation'] as Map;
      expect(rec.containsKey('albumArtist'), isFalse);
    });

    testWidgets("an explorer row whose own credit the album list contradicts: "
        "the list's credit keys Album", (tester) async {
      await h.pumpHost(tester);
      final row = h.song(albumArtist: 'Boukmanflow & Friends');
      await h.open(
        tester,
        BrowseKeepRequest.song(row, folder: FolderRef.parentOf(row.data))!,
      );
      await tapKey(tester, 'keep-chip-album');
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final rec = h.lastStart()['recommendation'] as Map;
      expect([h.lastStart()['scope'], rec['albumArtist']], ['album', 'Boukmanflow']);
    });

    testWidgets("Album waits for the album list, then appears once: the "
        "song's own credit stands when the list names no such album", (
      tester,
    ) async {
      h.facts.peerAlbums['boukmanflow'] = const [];
      final gate = Completer<void>();
      final call = h.facts.call;
      await h.pumpHost(tester);
      unawaited(
        showBrowseKeepSheet(
          h.host!,
          BrowseKeepRequest.song(h.song(albumArtist: 'Boukmanflow'))!,
          marks: h.marks,
          fetch: (s, location, body) async {
            if (location.endsWith('/db/artists-albums') && s.isFederated) {
              await gate.future;
            }
            return call(s, location, body);
          },
          track: h.facts.track,
        ),
      );
      await frames(tester, 10);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsNothing,
          reason: 'held until the list answers');
      gate.complete();
      await frames(tester, 10);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsOneWidget);
      await tapKey(tester, 'keep-chip-album');
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final rec = h.lastStart()['recommendation'] as Map;
      expect(rec['albumArtist'], 'Boukmanflow');
    });

    testWidgets('a compilation song: Album asked again by its credit, never '
        'the track artist', (tester) async {
      h.facts.trackTags.clear();
      await h.pumpHost(tester);
      final row = h.song(
        title: 'Track 2',
        file: '02.mp3',
        album: 'Night Market Sampler',
        dir: 'music/Various Artists/Night Market Sampler',
        year: 2024,
      );
      await h.open(tester, BrowseKeepRequest.song(row)!);
      expect(find.byKey(const ValueKey('keep-chip-album')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('keep-chip-album')),
          matching: find.text('3 songs'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a song by an artist who only appears there: Artist "0 '
        'albums", choosing it says so — no path, no Add', (tester) async {
      await h.pumpHost(tester);
      final row = h.song(
        title: 'Lanterns',
        file: '02.mp3',
        artist: 'Lantern Choir',
        album: 'Night Market Sampler',
        dir: 'music/Various Artists/Night Market Sampler',
      );
      await h.open(
        tester,
        BrowseKeepRequest.song(row, albumCredit: 'Various Artists')!,
      );
      expect(find.text('0 albums'), findsOneWidget);
      await tapKey(tester, 'keep-chip-artist');
      expect(
        find.text(
          'Lantern Choir only appears on albums here, so there is no artist '
          'copy.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });
  });

  testWidgets("the queue: a track of Stage Peer C's, downloaded or not — the "
      "song sheet on ITS server, the tags' credit appending Album", (
    tester,
  ) async {
    h.facts.trackTags['$tapesDir/01 - Rooftop Cypher.mp3'] = {
      'title': 'Rooftop Cypher',
      'artist': 'Boukmanflow',
      'album': 'Borrowed Tapes',
      'year': 2019,
      'duration': 12,
      'album-artist': 'Boukmanflow',
    };
    await h.pumpHost(tester);
    final item = MediaItem(
      id: 'x',
      title: 'Rooftop Cypher',
      artist: 'Boukmanflow',
      album: 'Borrowed Tapes',
      duration: const Duration(seconds: 12),
      extras: {
        'server': 'peer-4',
        'path': '/$tapesDir/01 - Rooftop Cypher.mp3',
        'localPath': '/data/media/peer-4/01 - Rooftop Cypher.mp3',
        'artUrl': 'http://home.local/album-art/tapes.jpg',
      },
    );
    await h.open(tester, BrowseKeepRequest.queued(item, h.peerOther)!);
    expect(find.text('Stage Peer C online'), findsOneWidget);
    // Its cover is the queue's own.
    expect(
      find.byKey(const ValueKey('browse-keep-queue-cover')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('keep-chip-album')), findsOneWidget);
    expect(find.text('Add song'), findsOneWidget);
    await tapKey(tester, 'keep-start');
    await frames(tester, 8);
    final rec = h.lastStart()['recommendation'] as Map;
    expect(rec['peer'], peerC);
    expect(rec['filepath'], '$tapesDir/01 - Rooftop Cypher.mp3');
  });

  testWidgets('the Folder chip reads as the folder and everything in it, then '
      'its songs', (tester) async {
    final handle = tester.ensureSemantics();
    await h.pumpHost(tester);
    final row = h.song();
    await h.open(
      tester,
      BrowseKeepRequest.song(row, folder: FolderRef.parentOf(row.data))!,
    );
    final chip = find.byKey(const ValueKey('keep-chip-folder'));
    expect(
      tester.getSemantics(chip),
      isSemantics(label: 'Folder: Borrowed Tapes and everything in it'),
    );
    await tapKey(tester, 'keep-chip-folder');
    await frames(tester);
    expect(
      tester.getSemantics(chip),
      isSemantics(label: 'Folder: Borrowed Tapes, 3 songs', isChecked: true),
    );
    handle.dispose();
  });

  group('refusals, the server offline, the toast', () {
    testWidgets('429: the server\'s sentence, verbatim, as one plain line '
        'under the path; Add stays', (tester) async {
      h.fake.startAnswer = (
        429,
        {
          'error':
              'you have 20 jobs queued or running — wait for some to finish '
              '(the limit is 20)',
        },
      );
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final err = find.textContaining('you have 20 jobs queued');
      expect(err, findsOneWidget);
      expect(
        tester.widget<Text>(err).style?.color,
        keepTone(VelvetColors.warning),
      );
      expect(
        topOf(tester, find.byKey(const ValueKey('keep-destination'))),
        lessThan(topOf(tester, err)),
      );
      expect(find.text('Add album'), findsOneWidget);
    });

    testWidgets('403: the gate read again, the card one plain line',
        (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      h.fake.startAnswer = (403, {'error': 'Uploading Disabled'});
      h.home.noUpload = true;
      await tapKey(tester, 'keep-start');
      await frames(tester, 10);
      expect(find.text("Your account can't add files to this server"),
          findsOneWidget);
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });

    testWidgets('a refused copy has no Retry', (tester) async {
      h.fake.addJob(
        {
          'source': 'federation',
          'peer': peerB,
          'album': 'Borrowed Tapes',
          'albumArtist': 'Boukmanflow',
          'artist': 'Boukmanflow',
          'year': 2019,
        },
        scope: 'album',
        state: 'done',
        result: {
          'scope': 'album',
          'songs': {'total': 0, 'copied': [], 'skipped': [], 'failed': []},
          'counts': {'total': 0, 'copied': 0, 'skipped': 0, 'failed': 0},
          'stopped': 'refused',
          'peer': peerB,
        },
      );
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      expect(find.text('Stopped'), findsOneWidget);
      expect(
        find.textContaining("does not allow copies with your server's key"),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-retry')), findsNothing);
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });

    testWidgets('the server not answering: the error dot, facts blank, Add '
        'live and uncounted', (tester) async {
      h.facts.peerDown = true;
      await h.pumpHost(tester);
      await h.open(
        tester,
        BrowseKeepRequest.song(h.song(), albumCredit: 'Boukmanflow')!,
      );
      expect(find.text('Stage Peer B not answering'), findsOneWidget);
      final dot = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('peer-sheet-server')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (dot.decoration as BoxDecoration).color,
        keepTone(VelvetColors.error),
      );
      expect(find.text('Add song'), findsOneWidget);
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.fake.calls('POST', jobsPath), hasLength(1),
          reason: 'nothing is disabled for offline');
    });

    testWidgets('a start toasted once the sheet closes, with View: the Copies '
        'sheet of your server', (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      Navigator.of(h.host!).pop();
      await frames(tester, 8);
      expect(h.toasts, ['Copying Borrowed Tapes from Stage Peer B']);
      expect(h.toastActions.single.$2, 'View');
      h.toastActions.single.$3();
      expect(h.opened, ['copies']);
    });

    const tapesAlbum = {
      'source': 'federation',
      'peer': peerB,
      'album': 'Borrowed Tapes',
      'albumArtist': 'Boukmanflow',
      'artist': 'Boukmanflow',
      'year': 2019,
    };
    const allOwned = {
      'scope': 'album',
      'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': []},
      'counts': {'total': 3, 'copied': 0, 'skipped': 3, 'failed': 0},
      'peer': peerB,
    };

    testWidgets('a copy that ended as it started (every song already '
        'yours): its ending once the sheet closes, never "Copying …"', (
      tester,
    ) async {
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      final done = h.fake.addJob(
        tapesAlbum,
        scope: 'album',
        state: 'done',
        result: {...allOwned},
      );
      h.fake.startAnswer = (202, {'job': done, 'created': true});
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(find.text('Already yours'), findsOneWidget);
      Navigator.of(h.host!).pop();
      await frames(tester, 8);
      expect(h.toasts, ['Already in your library']);
      expect(h.toastActions, isEmpty);
      // Told once: the next read of the list says nothing more.
      await h.jobs.refreshJobs();
      await frames(tester);
      expect(h.toasts, ['Already in your library']);
    });

    testWidgets('a copy that ended while the sheet was open: the poll told '
        'it, and the sheet closing says nothing more', (tester) async {
      CopiesHub().l10n = () => lookupAppLocalizations(const Locale('en'));
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final started = h.fake.jobs.first;
      expect(started['state'], 'queued');
      started['state'] = 'done';
      started['result'] = {...allOwned};
      await h.jobs.refreshJobs();
      await frames(tester, 8);
      expect(h.toasts, ['Already in your library']);
      Navigator.of(h.host!).pop();
      await frames(tester, 8);
      expect(h.toasts, ['Already in your library']);
      expect(h.toastActions, isEmpty);
    });

    testWidgets('New seeds never shows: a copy that failed for a re-paired '
        'server has no verb here', (tester) async {
      final j = h.fake.addJob(
        {
          'source': 'federation',
          'peer': peerB,
          'album': 'Borrowed Tapes',
          'albumArtist': 'Boukmanflow',
          'artist': 'Boukmanflow',
          'year': 2019,
        },
        scope: 'album',
        state: 'failed',
      );
      j['error'] = 'this server is no longer paired with that peer';
      await h.pumpHost(tester);
      await h.open(tester, h.albumPage());
      expect(find.text('Copy failed'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-new-seeds')), findsNothing);
      expect(find.byKey(const ValueKey('keep-retry')), findsNothing);
    });
  });

  group('large text and themes', () {
    for (final (name, w, hgt) in const [
      ('360 × 780', 360.0, 780.0),
      ('390 × 844', 390.0, 844.0),
    ]) {
      testWidgets('2.0× on $name: album, artist and song sheets — nothing '
          'overflows, Add in reach', (tester) async {
        await h.pumpHost(tester, width: w, height: hgt, textScale: 2);
        for (final r in [
          h.albumPage(),
          h.artistPage(),
          BrowseKeepRequest.song(h.song(), albumCredit: 'Boukmanflow')!,
        ]) {
          await h.open(tester, r);
          expect(tester.takeException(), isNull);
          final bar = find.byKey(const ValueKey('keep-add-bar'));
          expect(bar, findsOneWidget);
          expect(tester.getBottomLeft(bar).dy, lessThanOrEqualTo(hgt));
          Navigator.of(h.host!).pop();
          await frames(tester, 8);
        }
      });
    }

    testWidgets('long names: the title takes two lines, never overflows',
        (tester) async {
      await h.pumpHost(tester, width: 360, height: 780, textScale: 1.3);
      final a = h.album(
        'Free Instrumentals Vol. 9 (Deluxe Remastered Edition)',
        credit: 'The Boukmanflow Collective & Friends',
      );
      await h.open(tester, h.albumPage(a));
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(
        find.text('Free Instrumentals Vol. 9 (Deluxe Remastered Edition)'),
      );
      expect(title.maxLines, 2);
    });

    for (final theme in [AppTheme.light, AppTheme.velvet]) {
      testWidgets('${theme.name}: the sheet, the pinned Add and the chosen '
          'chip draw with the palette\'s readable roles', (tester) async {
        VelvetColors.setActive(paletteFor(theme));
        await h.pumpHost(tester);
        await h.open(tester, h.albumPage());
        expect(tester.takeException(), isNull);
        final bar = tester.widget<Container>(
          find.byKey(const ValueKey('keep-add-bar')),
        );
        expect((bar.decoration as BoxDecoration).color, VelvetColors.surface);
        final fill = find.descendant(
          of: find.byKey(const ValueKey('keep-start')),
          matching: find.byType(Material),
        );
        expect(tester.widget<Material>(fill.first).color, keepFill());
        expect(
          _contrast(VelvetColors.onPrimary, keepFill()),
          greaterThanOrEqualTo(4.5),
        );
        final change = tester.widget<Text>(find.text('Change'));
        expect(change.style?.color, keepInk());
        expect(
          _contrast(keepInk(), VelvetColors.surface),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  testWidgets('screen reader: the header reads as one node, the chips as a '
      'group, the pinned Add last', (tester) async {
    final handle = tester.ensureSemantics();
    await h.pumpHost(tester);
    await h.open(tester, h.albumPage());
    final header = tester.getSemantics(
      find.byKey(const ValueKey('browse-keep-header')),
    );
    expect(header.label, contains('Borrowed Tapes'));
    expect(header.label, contains('Stage Peer B online'));
    expect(header, isSemantics(isHeader: true));
    expect(
      topOf(tester, find.text('Add album')),
      greaterThan(topOf(tester, find.text('Change'))),
    );
    handle.dispose();
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
