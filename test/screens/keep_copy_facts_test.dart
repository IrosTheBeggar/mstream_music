// The Keep a copy sheets' facts and small helpers: what "Only the albums
// you don't have" counts (album NAMES, src/db/name-key.js's folding, never
// counts), an album's length and year, an empty answer that names no
// album, a connected server that does not answer, what each album song
// files under (a path's slots read from it) — and the colour roles the
// canvas added (text in the primary's place, the fill under an on-primary
// label) in each palette, the clock and the format, a path's slot words
// and their note.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/keep_copy_facts.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/discover_jobs.dart';

import 'discovery_keep_fixtures.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  late Server own;
  late Server peer;
  late FakeFacts facts;

  setUp(() {
    own = Server('http://home.local', null, null, 'JWT', 'home');
    peer = Server('federated://home/1', null, null, null, 'peer-1')
      ..federationParent = 'home'
      ..federationPeerId = 1
      ..parentServer = own;
    facts = FakeFacts();
  });

  Future<KeepFacts> load({
    String album = 'Borrowed Tapes',
    String artist = 'Boukmanflow',
    String? albumArtist,
    bool wantArtist = true,
  }) async {
    final l = KeepFactsLoader(
      peer: peer,
      own: own,
      album: album,
      artist: artist,
      albumArtist: albumArtist,
      wantArtist: wantArtist,
      fetch: facts.call,
    )..load();
    expect(l.loading, isTrue);
    await l.albumSongs();
    for (var i = 0; i < 10 && l.loading; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(l.loading, isFalse);
    final f = l.facts;
    l.dispose();
    return f;
  }

  test('the album through the peer: its songs, length and year', () async {
    final f = await load();
    expect(f.albumSongCount, 3);
    expect(f.albumLength, const Duration(seconds: 29));
    expect(f.albumYear, 2019);
    expect(f.peerFailed, isFalse);
    expect(
      [for (final s in f.albumSongs!) s.server],
      everyElement(same(peer)),
      reason: 'Play album / Queue album stream through the peer',
    );
    expect(
      f.albumSongs!.first.data,
      '/peerlib/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3',
    );
  });

  test("missing is by album NAME: case, spaces and quote styles fold; the "
      'singles entry never counts', () async {
    facts.peerAlbums['boukmanflow'] = [
      'Borrowed Tapes',
      'OLD  gold',
      'Second Wind',
      'Rock ’n’ Roll',
    ];
    facts.libraryAlbums['boukmanflow'] = ['Old Gold', "Rock 'n' Roll"];
    final f = await load();
    expect(
      f.peerAlbums,
      hasLength(4),
      reason: 'the null-named singles left out',
    );
    expect(f.missing, ['Borrowed Tapes', 'Second Wind']);
    expect(f.libraryHas('Borrowed Tapes'), isFalse);
    expect(f.libraryHas('old gold'), isTrue);
  });

  test('an empty album answer names no album: no song count', () async {
    final f = await load(album: 'Nothing Here');
    expect(f.albumSongs, isEmpty);
    expect(f.albumSongCount, isNull);
    expect(f.albumLength, isNull);
  });

  test("a compilation's album is asked by its album artist, whole; no artist "
      'lists', () async {
    final f = await load(
      album: 'Block Party Comp',
      artist: 'Peer Kim',
      albumArtist: 'Various Artists',
      wantArtist: false,
    );
    expect(f.albumSongCount, 4);
    expect(facts.asked.map((a) => a.$2), ['/api/v1/db/album-songs']);
    expect(facts.asked.single.$3, {
      'album': 'Block Party Comp',
      'album_artist': 'Various Artists',
    });
  });

  test('a connected server that does not answer: peerFailed, the library '
      "list still answers ('you have 3')", () async {
    facts.peerDown = true;
    final f = await load();
    expect(f.peerFailed, isTrue);
    expect(f.albumSongs, isNull);
    expect(f.peerAlbums, isNull);
    expect(f.libraryAlbums, hasLength(3));
    expect(f.missing, isNull, reason: 'no peer list: nothing to compare');
  });

  test("each album song as a copy files it: the ARTIST tag as written, the "
      "year, a genre only when the listing tells the file's", () async {
    facts.albums['Borrowed Tapes'] = [
      songOf(
        'peerlib/a/1.mp3',
        'One',
        'Boukmanflow',
        'Borrowed Tapes',
        9,
        genres: ['Hip-Hop'],
      ),
      songOf(
        'peerlib/a/2.mp3',
        'Two',
        'Boukmanflow',
        'Borrowed Tapes',
        9,
        artistDisplay: 'Boukmanflow feat. ALM',
        genres: ['Hip-Hop', 'Rap'],
      ),
      songOf(
        'peerlib/a/3.mp3',
        'Three',
        'Boukmanflow',
        'Borrowed Tapes',
        9,
        year: null,
      ),
    ];
    final f = await load();
    final songs = f.layoutSongs!;
    expect(
      [for (final s in songs) s.artist],
      ['Boukmanflow', 'Boukmanflow feat. ALM', 'Boukmanflow'],
    );
    expect([for (final s in songs) s.year], [2019, 2019, null]);
    // "Hip-Hop/Rap" is two genres in the library, one folder on a copy.
    expect([for (final s in songs) s.genre], ['Hip-Hop', null, null]);
    expect(f.genreOf('peerlib/a/1.mp3'), 'Hip-Hop');
    expect(f.genreOf('/peerlib/a/1.mp3'), 'Hip-Hop');
    expect(f.genreOf('peerlib/a/2.mp3'), isNull);
    expect(f.genreOf('peerlib/elsewhere.mp3'), isNull);
    expect(f.genreOf(null), isNull);
    // The ARTIST tag as written, for a copy of that one song.
    expect(f.artistOf('peerlib/a/2.mp3'), 'Boukmanflow feat. ALM');
    expect(f.artistOf('/peerlib/a/1.mp3'), 'Boukmanflow');
    expect(f.artistOf('peerlib/elsewhere.mp3'), isNull);
    // The artist's albums on the peer, with their years (by name).
    expect(f.peerAlbumYears, {'borrowed tapes': 2019});
    expect(const KeepFacts().layoutSongs, isNull, reason: 'not answered yet');
  });

  test("a path's slot words and the one note under it", () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(keepSlotWord(en, LayoutSlot.artist), '‹artist›');
    expect(keepSlotNote(en, const [], scope: kScopeAlbum), isNull);
    expect(
      keepSlotNote(en, const [LayoutSlot.artist], scope: kScopeAlbum),
      "‹artist› comes from each song's own tags, so these songs can land in "
      'more than one folder.',
    );
    expect(
      keepSlotNote(en, const [
        LayoutSlot.artist,
        LayoutSlot.year,
      ], scope: kScopeAlbum),
      "‹artist›, ‹year› come from each song's own tags, so these songs can "
      'land in more than one folder.',
    );
    expect(
      keepSlotNote(en, const [
        LayoutSlot.artist,
        LayoutSlot.genre,
      ], scope: kScopeAlbum),
      "‹artist›, ‹genre› come from each song's own tags, so these songs can "
      'land in more than one folder (a song with none leaves that folder '
      'out).',
    );
    expect(
      keepSlotNote(en, const [LayoutSlot.genre], scope: kScopeArtist),
      "‹genre› comes from each song's own tags, so these songs can land in "
      'more than one folder (a song with none leaves that folder out).',
    );
    // One song lands in one folder: its own words.
    expect(
      keepSlotNote(en, const [LayoutSlot.genre], scope: kScopeSong),
      "‹genre› comes from the song's own tags (a song with none leaves that "
      'folder out).',
    );
    expect(
      keepPathText(en, [
        'copies',
        'From friends',
        '${slotMark(LayoutSlot.artist)} (live)',
      ]),
      'copies › From friends › ‹artist› (live)',
    );
    // Every language names each slot and lists them in its note.
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final words = [for (final s in LayoutSlot.values) keepSlotWord(l, s)];
      expect(words.toSet(), hasLength(3), reason: '$locale');
      final note = keepSlotNote(l, LayoutSlot.values, scope: kScopeAlbum)!;
      for (final w in words) {
        expect(note, contains(w), reason: '$locale');
      }
      expect(
        keepSlotNote(l, const [LayoutSlot.year], scope: kScopeAlbum),
        contains(words[1]),
      );
      final song = keepSlotNote(l, const [LayoutSlot.genre], scope: kScopeSong);
      expect(song, contains(words[2]), reason: '$locale');
      expect(
        song,
        isNot(keepSlotNote(l, const [LayoutSlot.genre], scope: kScopeAlbum)),
        reason: '$locale: one song lands in one folder',
      );
    }
  });

  group('colour roles', () {
    tearDown(() => VelvetColors.setActive(paletteFor(AppTheme.dark)));

    test('Dark: amber text and fill', () {
      VelvetColors.setActive(paletteFor(AppTheme.dark));
      expect(keepInk(), VelvetColors.primary);
      expect(keepFill(), VelvetColors.primary);
    });

    test("Velvet: the accent where the violet would not read, the violet's "
        'darker shade under white', () {
      VelvetColors.setActive(paletteFor(AppTheme.velvet));
      expect(keepInk(), VelvetColors.accent);
      expect(keepFill(), VelvetColors.primaryHover);
      expect(_contrast(Colors.white, keepFill()), greaterThanOrEqualTo(4.5));
    });

    test('Light: amber darkened for text; statuses darkened to 4.5:1', () {
      VelvetColors.setActive(paletteFor(AppTheme.light));
      expect(keepFill(), VelvetColors.primary, reason: 'black on amber reads');
      expect(
        _contrast(keepInk(), VelvetColors.surface),
        greaterThanOrEqualTo(4.5),
      );
      for (final c in [
        VelvetColors.success,
        VelvetColors.warning,
        VelvetColors.error,
      ]) {
        expect(
          _contrast(keepTone(c), VelvetColors.card),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  test('the clock and the format', () {
    expect(keepClock(const Duration(seconds: 8)), '0:08');
    expect(keepClock(const Duration(minutes: 41, seconds: 7)), '41:07');
    expect(
      keepClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(keepFormatOf('peerlib/a/b/02 - Late Train Verse.mp3'), 'MP3');
    expect(keepFormatOf('x/y.flac'), 'FLAC');
    expect(keepFormatOf('x.y/z'), isNull);
    expect(keepFormatOf(null), isNull);
  });
}
