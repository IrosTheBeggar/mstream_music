// util/discover_jobs.dart's folder half — what a connected server's folder
// copy takes (planFolder) and where it lands (scopeTarget's folder rule:
// as on the server, into a folder, by your layout) — held to the webapp's
// cases (mStream test/unit/webapp-discover-jobs.test.mjs: "planFolder",
// "scopeTarget, scope folder", "by your layout", "layoutLead",
// "maxFolderSongs"), which hold the webapp to federation-copy's own
// planFolder and landingFor. The values below are the server's answers for
// the same inputs. Plus the phone's job half: isKeepCopy, JobKind.folder,
// a folder copy's row (its landed folder, the files it left out), and a
// refused one with no Retry.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/discover_jobs.dart';

const folder = 'music/Boukmanflow/Borrowed Tapes';
const tapes = ['01 - Rooftop Cypher.mp3', '02 - Late Train Verse.mp3', '03 - Corner Store Loop.mp3'];
final boukmanflow = [
  for (final f in tapes) 'music/Boukmanflow/Borrowed Tapes/$f',
  for (final f in ['01 - Tide.mp3', '02 - Pier.mp3', '03 - Lamps.mp3']) 'music/Boukmanflow/Harbour Lights/$f',
  for (final f in ['01 - Clock In.mp3', '02 - Break.mp3', '03 - Clock Out.mp3']) 'music/Boukmanflow/Second Shift/$f',
];
const supported = {'mp3': true, 'flac': true, 'm3u': false};
const dest = (vpath: 'copies', base: '', layout: '{{ALBUMARTIST}}/{{ALBUM}}');
const lead = 'From friends/{{ALBUMARTIST}}/{{ALBUM}}';

List<FolderSong> planned(List<String> listing, String folder) =>
    planFolder(listing, folder, supported: supported).songs;

/// A path's crumbs as read, each slot as its variable ("‹ARTIST›").
List<String> crumbsOf(ScopeTarget t) => [
      for (final c in t.crumbs)
        slotText(c, (s) => switch (s) {
              LayoutSlot.artist => '‹ARTIST›',
              LayoutSlot.year => '‹YEAR›',
              LayoutSlot.genre => '‹GENRE›',
              LayoutSlot.serverFolder => '‹SERVERFOLDER›',
              LayoutSlot.albumArtist => '‹ALBUMARTIST›',
            }),
    ];

ScopeTarget at({
  Object? landing,
  String folder = folder,
  List<FolderSong>? songs,
  bool counted = true,
  List<FolderSongTags>? tags,
  String? base,
  String? layout,
}) =>
    scopeTarget(
      vpath: dest.vpath,
      base: base ?? dest.base,
      layout: layout ?? dest.layout,
      scope: kScopeFolder,
      landing: landing,
      folder: folder,
      folderSongs: counted ? (songs ?? planned(boukmanflow, folder)) : null,
      folderTags: tags,
      peerName: 'Stage Peer B',
    );

void main() {
  group('planFolder: what a folder copy takes is what federation-copy takes', () {
    const ignored = [
      r'$recycle.bin', '#recycle', '@recycle', '@recently-snapshot', '#snapshot',
      '.git', 'lost+found', '.stfolder', '.stversions', 'system volume information',
    ];
    final listing = <Object?>[
      ...boukmanflow.reversed,
      'music/Boukmanflow/Borrowed Tapes/CD 10/01 - x.mp3',
      'music/Boukmanflow/Borrowed Tapes/CD 2/01 - x.mp3',
      '/music/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3',
      'music\\Boukmanflow\\Borrowed Tapes\\04 - Back.flac',
      'music/Other/x.mp3',
      'music/Boukmanflow/Borrowed Tapes/../../Other/y.mp3',
      'music/Boukmanflow/Borrowed Tapesque/z.mp3',
      for (final d in ignored) 'music/Boukmanflow/Borrowed Tapes/${d.toUpperCase()}/a.mp3',
      'music/Boukmanflow/Borrowed Tapes/.hidden/a.mp3',
      'music/Boukmanflow/Borrowed Tapes/.cover.mp3',
      'music/Boukmanflow/Borrowed Tapes/...Trilogy/a.mp3',
      'music/Boukmanflow/Borrowed Tapes/notes.txt',
      'music/Boukmanflow/Borrowed Tapes/list.M3U',
      'music/Boukmanflow/Borrowed Tapes/LOUD.MP3',
      'music/Boukmanflow/Borrowed Tapes/AC:DC?/x.mp3',
      'music/Boukmanflow/Borrowed Tapes/ . /./y.mp3',
      '',
      null,
      42,
    ];

    test('the songs, their order and their folders, and what is left out with why', () {
      final p = planFolder(listing, folder, supported: supported);
      expect([for (final s in p.songs) if (s.relDir.isEmpty) s.filepath.split('/').last],
          [...tapes, '04 - Back.flac', 'LOUD.MP3', 'y.mp3'],
          reason: 'path order; an extension in any case; a "." is no folder');
      expect([for (final s in p.songs) if (s.relDir.startsWith('CD')) s.relDir], ['CD 2', 'CD 10'],
          reason: 'path order counts numbers as numbers');
      expect(p.songs.any((s) => s.relDir == 'AC-DC-'), isTrue, reason: "a peer's folder name made safe");
      expect(p.songs.any((s) => s.filepath.endsWith('/...Trilogy/a.mp3') && s.relDir == 'Trilogy'), isTrue,
          reason: 'a name that starts with dots is a name (its folder made safe)');
      expect(p.songs.where((s) => s.filepath.endsWith('01 - Rooftop Cypher.mp3')), hasLength(1),
          reason: 'one entry per path');
      int why(String w) => p.skipped.where((x) => x.why == w).length;
      // outside: the other albums' six, Other, the climb, a folder whose name
      // only starts the same
      expect([why('outside'), why('ignored'), why('unsupported')], [9, ignored.length + 2, 2]);
      expect(
        [for (final x in planFolder(listing, 'music/Boukmanflow', supported: supported).skipped) if (x.why == 'outside') x.from],
        ['music/Other/x.mp3', 'music/Boukmanflow/Borrowed Tapes/../../Other/y.mp3'],
      );
      final none = planFolder(null, folder);
      expect([none.songs, none.skipped], [isEmpty, isEmpty]);
    });

    test("path order is ICU's (the server's and the webapp's localeCompare, numeric, base): spaces, then punctuation and symbols, then numbers, then letters", () {
      // node: paths.sort((a, b) => a.localeCompare(b, undefined,
      // {numeric: true, sensitivity: 'base'})) — federation-copy planFolder's
      // sort — for these names, each "music/A/{name}.mp3".
      const names = ['2001 - Middle', '(Live) Encore', '[1999] First', '_x', '-x', '~ana', 'Ana', 'ana 2', 'ana 10', 'Éclair', 'eclair', 'Zed', 'zebra', 'a b', 'a-b', 'ab', 'a_b', 'a.b', 'Straße', 'strasse', 'Œuvre', 'oeuvre z', 'Ångström', '#1 Hits', r'$money', '@home', '01 Intro', '1 Intro', '10 Outro', 'Ça va', 'Ñandú', 'ø', 'Łódź', 'CD 2', 'CD 10', 'cd 1'];
      const icu = ['_x', '-x', '(Live) Encore', '[1999] First', '@home', '#1 Hits', '~ana', r'$money', '01 Intro', '1 Intro', '10 Outro', '2001 - Middle', 'a b', 'a_b', 'a-b', 'a.b', 'ab', 'ana 2', 'ana 10', 'Ana', 'Ångström', 'Ça va', 'cd 1', 'CD 2', 'CD 10', 'Éclair', 'eclair', 'Łódź', 'Ñandú', 'ø', 'oeuvre z', 'Œuvre', 'Straße', 'strasse', 'zebra', 'Zed'];
      final p = planFolder([for (final n in names) 'music/A/$n.mp3'], 'music/A');
      expect([for (final s in p.songs) s.filepath.substring('music/A/'.length, s.filepath.length - 4)], icu);
    });

    test('the folder in any spelling is the same folder; without the supported list every file is taken', () {
      final want = planFolder(listing, folder, supported: supported).songs;
      for (final f in ['/$folder/', 'music\\Boukmanflow\\Borrowed Tapes']) {
        expect(planFolder(listing, f, supported: supported).songs, want, reason: f);
      }
      final all = planFolder(listing, folder);
      expect(all.skipped.where((x) => x.why == 'unsupported'), isEmpty);
      expect(all.songs.any((s) => s.filepath.endsWith('notes.txt')), isTrue);
    });

    test("isSupportedAudioFile reads the ping's map as the server reads its config", () {
      expect(
        [for (final n in ['a.mp3', 'a.MP3', 'dir/a.flac', 'a.m3u', 'a', 'a.', '.mp3', 'a.tar.mp3', '', null]) isSupportedAudioFile(n, supported)],
        [true, true, true, false, false, false, true, true, false, false],
      );
      expect(isSupportedAudioFile('a.mp3', null), isFalse, reason: 'no map: nothing is known to play');
    });

    test('folderCounts: its songs, and every subfolder on their way down, counted once', () {
      expect(folderCounts(planned(boukmanflow, 'music/Boukmanflow')), (songs: 9, subfolders: 3));
      expect(folderCounts(planned(boukmanflow, folder)), (songs: 3, subfolders: 0));
      final discs = ['music/A/Box/CD1/1.mp3', 'music/A/Box/CD1/2.mp3', 'music/A/Box/CD2/1.mp3', 'music/A/top.mp3'];
      expect(folderCounts(planned(discs, 'music/A')), (songs: 4, subfolders: 3), reason: 'Box, Box/CD1, Box/CD2');
      expect(folderCounts(null), (songs: 0, subfolders: 0));
    });
  });

  group('layoutLead: the leading folders every copy lands in whatever its tags, and the rest as typed', () {
    test('the cases', () {
      final cases = {
        'From friends/{{ARTIST}}': ('From friends', '{{ARTIST}}'),
        ' a / b \\{{ALBUM}}/x': ('a/b', '{{ALBUM}}/x'),
        'plain/only': ('plain/only', ''),
        '{{ARTIST}}/{{ALBUM}}': ('', '{{ARTIST}}/{{ALBUM}}'),
        ' /From friends/{{ARTIST}}': ('From friends', '{{ARTIST}}'),
        'a//b/{{ALBUM}}': ('a/b', '{{ALBUM}}'),
        'Copy of {{SERVERFOLDER}}': ('', 'Copy of {{SERVERFOLDER}}'),
        'a}/b': ('', 'a}/b'),
        '': ('', ''),
      };
      for (final e in cases.entries) {
        final l = layoutLead(e.key);
        expect((l.folders, l.rest), e.value, reason: e.key);
      }
      expect(layoutLead(null).folders, '');
    });
  });

  group('scopeTarget, scope folder: as on the connected server', () {
    test('the library, then the folder inside the peer library, its own name kept, never through the layout', () {
      final p = at();
      expect([p.valid, p.landing, p.target.library, crumbsOf(p), p.target.relDir, p.slots, p.perAlbum, p.straightIn],
          [true, FolderLanding.mirror, 'copies', ['copies', 'Boukmanflow', 'Borrowed Tapes'], 'Boukmanflow/Borrowed Tapes', isEmpty, false, null]);
      expect(p.files, const FolderFiles(tapes, 0));
      expect(crumbsOf(at(layout: '{{GENRE}}/{{ARTIST}} - {{YEAR}}')), ['copies', 'Boukmanflow', 'Borrowed Tapes'],
          reason: 'no slot, no layout folder');
      expect(at(landing: const {}).landing, FolderLanding.mirror, reason: 'an empty landing is none');
    });

    // The user's call (2026-10-23): a layout that keeps copies in a folder
    // of its own keeps a mirrored folder there too.
    test('under the base folder and the layout\'s leading folders: "copies › From friends › Boukmanflow › Borrowed Tapes"', () {
      expect(crumbsOf(at(layout: lead)), ['copies', 'From friends', 'Boukmanflow', 'Borrowed Tapes']);
      final both = at(base: ' Mirror / ', layout: ' a / b \\{{ALBUM}}/x');
      expect([crumbsOf(both), both.target.base, both.rendered, both.target.relDir],
          [['copies', 'Mirror', 'a', 'b', 'Boukmanflow', 'Borrowed Tapes'], 'Mirror', 'a/b/Boukmanflow/Borrowed Tapes', 'Mirror/a/b/Boukmanflow/Borrowed Tapes']);
      expect(crumbsOf(at(layout: 'Only/literal')), ['copies', 'Only', 'literal', 'Boukmanflow', 'Borrowed Tapes'],
          reason: 'a layout of folders alone leads with all of them');
      final root = at(folder: '/music/', layout: lead);
      expect([root.valid, crumbsOf(root), root.target.relDir], [true, ['copies', 'From friends'], 'From friends'],
          reason: "the library's root: what the base and the lead give, nothing of the peer's");
      final bare = at(folder: 'music');
      expect([bare.valid, crumbsOf(bare), bare.target.relDir], [true, ['copies'], '']);
      final onlyBase = at(folder: 'music', base: 'Mirror');
      expect([onlyBase.valid, crumbsOf(onlyBase), onlyBase.rendered], [true, ['copies', 'Mirror'], '']);
    });

    test("is federation-copy landingFor's mirror, folder for folder (the server's answers)", () {
      final cases = {
        'music/AC:DC?/Back*In|Black': 'AC-DC-/Back-In-Black',
        'music/../..//./etc/ ~Ana ': 'etc/-Ana',
        'music\\Win\\Dir': 'Win/Dir',
        ' . /music/A': 'A',
        r'music/$HOME/x': '-/x',
      };
      for (final e in cases.entries) {
        final p = at(folder: e.key, songs: const []);
        expect([p.valid, p.target.relDir], [true, e.value], reason: e.key);
        expect(at(folder: e.key, songs: const [], layout: lead, base: 'a/b').target.relDir, 'a/b/From friends/${e.value}');
      }
    });

    test('a place the copy would refuse is refused here: past the length cap, a base folder that climbs', () {
      final long = at(folder: 'music/${'a' * 200}/${'b' * 200}/${'c' * 200}', songs: const []);
      expect([long.valid, long.target.field, long.target.error, long.files], [false, 'landing', 'path_too_long', null]);
      final base = at(base: '../up');
      expect([base.valid, base.target.field, base.target.error], [false, 'base', 'traversal']);
    });

    test('the file list: at most three, a subfolder\'s files with their folder first, then how many more', () {
      final all = at(folder: 'music/Boukmanflow', songs: planned(boukmanflow, 'music/Boukmanflow'));
      expect(all.files, FolderFiles([for (final f in tapes) 'Borrowed Tapes/$f'], 6));
      expect(kFolderFileLines, 3);
      expect(at(songs: planned(boukmanflow.sublist(0, 2), folder)).files, FolderFiles(tapes.sublist(0, 2), 0));
      expect(at(songs: const []).files, const FolderFiles([], 0));
      expect(at(counted: false).files, isNull, reason: 'not counted yet: no list');
      expect(folderFiles(const [FolderSong('music/A/bad:name?.mp3', relDir: 'CD 1')]), const FolderFiles(['CD 1/bad-name-.mp3'], 0),
          reason: 'the name the copy writes the file under');
      expect(folderFiles(const [FolderSong('music/A/CD 1/x.mp3', relDir: 'CD 1')], flat: true), const FolderFiles(['x.mp3'], 0));
    });
  });

  group('scopeTarget, scope folder: into a folder…', () {
    test("the library and folder chosen, the pressed folder's files straight in — said when that folder is not named as the pressed one", () {
      final sam = at(landing: const {'vpath': 'copies', 'path': 'From Sam'});
      expect([sam.valid, sam.landing, sam.target.library, crumbsOf(sam)], [true, FolderLanding.folder, 'copies', ['copies', 'From Sam']]);
      expect(sam.straightIn, (folder: 'From Sam', name: 'Borrowed Tapes'));
      expect(sam.files, const FolderFiles(tapes, 0));
      // the default: a new folder named as the pressed one keeps the name —
      // case aside
      expect(at(landing: const {'path': 'Borrowed Tapes'}).straightIn, isNull);
      expect(at(landing: const {'vpath': 'copies', 'path': 'From Sam/borrowed  tapes'}).straightIn, isNull);
      expect(at(landing: const {'path': 'Borrowed Tapes'}).target.library, 'copies', reason: "no library chosen: the destination's");
      // the library's root: the line names the library
      final root = at(landing: const {'vpath': 'music', 'path': ''});
      expect([root.valid, root.target.library, crumbsOf(root), root.straightIn], [true, 'music', ['music'], (folder: 'music', name: 'Borrowed Tapes')]);
      expect(at(landing: const {'vpath': 'music'}).landing, FolderLanding.folder, reason: "a library alone is its root (validateLanding)");
      // neither the base folder nor the layout's lead: the folder is the one chosen
      expect(crumbsOf(at(landing: const {'path': ' Inbox \\ From Sam '}, base: 'Mirror', layout: lead)), ['copies', 'Inbox', 'From Sam']);
      final bad = at(landing: const {'path': '../up'});
      expect([bad.valid, bad.target.field, bad.target.error, bad.crumbs, bad.files, bad.straightIn], [false, 'landing', 'traversal', ['copies'], null, null]);
    });

    test("Into a folder…'s first place, the wire's shape and the mode it reads as", () {
      const d = CollectionDestination(vpath: 'copies', layout: '{{ALBUMARTIST}}/{{ALBUM}}');
      expect(folderIntoDefault(d, '/$folder/'), (vpath: 'copies', path: 'Borrowed Tapes'));
      expect([folderIntoDefault(d, 'music/~Ana').path, folderIntoDefault(d, 'music/Tapes {2019}').path, folderIntoDefault(null, 'music/x').vpath],
          ['-Ana', 'Tapes {2019}', null], reason: 'made safe as a mirror writes it; a brace kept, for the sheet\'s note');
      expect(
        [for (final l in <Object?>[null, const {}, const {'tags': true}, const {'tags': false}, const {'path': ''}, const {'vpath': 'music'}, const {'vpath': null, 'path': 'x'}]) landingMode(l)],
        [FolderLanding.mirror, FolderLanding.mirror, FolderLanding.tags, FolderLanding.mirror, FolderLanding.folder, FolderLanding.folder, FolderLanding.folder],
      );
      expect(
        [folderLanding(FolderLanding.mirror), folderLanding(FolderLanding.tags), folderLanding(FolderLanding.folder, vpath: 'copies', path: 'From Sam'), folderLanding(FolderLanding.folder, vpath: 'music'), folderLanding(FolderLanding.folder)],
        [null, {'tags': true}, {'vpath': 'copies', 'path': 'From Sam'}, {'vpath': 'music', 'path': ''}, {'vpath': null, 'path': ''}],
      );
      for (final mode in FolderLanding.values) {
        expect(landingMode(folderLanding(mode, vpath: 'copies', path: 'x')), mode);
      }
      // as a start's body carries it: no null library (the route refuses one)
      expect(
        [wireLanding(null), wireLanding(const {'tags': true}), wireLanding(const {'vpath': null, 'path': 'x'}), wireLanding(const {'vpath': 'music', 'path': ''}), wireLanding(const {'vpath': 'music'})],
        [null, {'tags': true}, {'path': 'x'}, {'vpath': 'music', 'path': ''}, {'vpath': 'music', 'path': ''}],
      );
    });
  });

  group('scopeTarget, scope folder, by your layout: the folder rule', () {
    FolderSongTags md(String filepath,
            {String artist = 'Boukmanflow',
            String? display,
            String album = 'Borrowed Tapes',
            int year = 2019,
            List<String> genres = const ['Hip-Hop'],
            String? credit = 'Boukmanflow'}) =>
        folderSongTags(filepath,
            artist: artist,
            artistDisplay: display ?? artist,
            year: year,
            genres: genres,
            album: album,
            albumArtist: credit);
    final tapesMd = [for (final f in tapes) md('$folder/$f')];
    final albumsMd = [
      ...tapesMd,
      for (final f in ['01 - Tide.mp3', '02 - Pier.mp3']) md('music/Boukmanflow/Harbour Lights/$f', album: 'Harbour Lights', year: 2021),
      md('music/Boukmanflow/Second Shift/01 - Clock In.mp3', album: 'Second Shift', year: 2023),
    ];
    final sampler = [
      for (final (artist, title) in [('Color Out', 'Lantern Street'), ('Boukmanflow', 'Night Market Cypher'), ('ALM', 'Paper Lanterns')])
        md('music/Various Artists/Night Market Sampler/$title.mp3', artist: artist, album: 'Night Market Sampler', year: 2024, credit: 'Various Artists'),
    ];
    FolderSongTags noCredit(FolderSongTags t) => FolderSongTags(
        artist: t.artist, year: t.year, genre: t.genre, serverFolder: t.serverFolder, album: t.album);
    ScopeTarget tagged(List<FolderSongTags>? tags, {String? layout, String folder = folder, List<FolderSong>? songs}) => at(
          landing: const {'tags': true},
          folder: folder,
          tags: tags,
          layout: layout,
          songs: songs ?? [for (final t in tags ?? const <FolderSongTags>[]) FolderSong('$folder/x${tags!.indexOf(t)}.mp3')],
        );

    test('folderSongTags: a metadata batch entry as the copy files it', () {
      final t = folderSongTags('$folder/a.mp3',
          artist: 'Boukmanflow', artistDisplay: 'Boukmanflow feat. ALM', year: 2019, genres: const ['Hip-Hop'], album: 'Borrowed Tapes', albumArtist: 'Boukmanflow');
      expect([t.artist, t.year, t.genre, t.serverFolder, t.album, t.albumArtist],
          ['Boukmanflow feat. ALM', 2019, 'Hip-Hop', 'Boukmanflow/Borrowed Tapes', 'Borrowed Tapes', 'Boukmanflow']);
      final none = folderSongTags('music/x.mp3');
      expect([none.artist, none.year, none.genre, none.serverFolder, none.album, none.albumArtist], [null, null, null, '', null, null],
          reason: 'a path the peer has no row for');
      expect(folderSongTags('music/a.mp3', genres: const ['Hip-Hop', 'Rap']).genre, isNull, reason: 'a split tag is unknown');
    });

    test('every song agrees: the album folder by name, and its files ("copies › Boukmanflow › Borrowed Tapes")', () {
      final songs = [for (final f in tapes) FolderSong('$folder/$f')];
      final p = tagged(tapesMd, songs: songs);
      expect([p.valid, p.landing, crumbsOf(p), p.slots, p.perAlbum, p.target.relDir],
          [true, FolderLanding.tags, ['copies', 'Boukmanflow', 'Borrowed Tapes'], isEmpty, false, 'Boukmanflow/Borrowed Tapes']);
      expect(p.files, const FolderFiles(tapes, 0), reason: 'by name alone: every song files by the layout');
      final inDisc = tagged(tapesMd, songs: [for (final f in tapes) FolderSong('$folder/CD 1/$f', relDir: 'CD 1')]);
      expect(inDisc.files, const FolderFiles(tapes, 0), reason: 'a subfolder on the peer is no folder here: the layout files it');
      expect(crumbsOf(tagged(tapesMd, layout: lead)), ['copies', 'From friends', 'Boukmanflow', 'Borrowed Tapes']);
      expect(crumbsOf(tagged(tapesMd, layout: '{{GENRE}}/{{ARTIST}} - {{ALBUM}} ({{YEAR}})')), ['copies', 'Hip-Hop', 'Boukmanflow - Borrowed Tapes (2019)']);
      expect(crumbsOf(tagged(tapesMd, layout: '{{SERVERFOLDER}}')), ['copies', 'Boukmanflow', 'Borrowed Tapes'],
          reason: 'the folder they all sit in on the server');
    });

    test('albums disagree: the folder that names an album, and every one after it, is "one folder per album" — no file list', () {
      final p = tagged(albumsMd, folder: 'music/Boukmanflow');
      expect([crumbsOf(p), p.perAlbum, p.files, p.target.relDir.isNotEmpty], [['copies', 'Boukmanflow'], true, null, true]);
      expect(crumbsOf(tagged(albumsMd, layout: '{{ARTIST}}/{{YEAR}}/{{ALBUM}}')), ['copies', 'Boukmanflow'], reason: "{{YEAR}} is each album's too");
      expect(crumbsOf(tagged(albumsMd, layout: 'From friends/{{SERVERFOLDER}}')), ['copies', 'From friends']);
      final shared = tagged(albumsMd, layout: '{{ALBUMARTIST}}');
      expect([crumbsOf(shared), shared.perAlbum, shared.files!.lines.length, shared.files!.more], [['copies', 'Boukmanflow'], false, 3, 3],
          reason: 'a layout that names no album: every album shares the folder');
    });

    test("a compilation: {{ARTIST}} a slot; {{ALBUMARTIST}} the songs' own credit when every one names it, drawn as {{ARTIST}} when none does, else its own slot", () {
      final credited = tagged(sampler);
      expect([crumbsOf(credited), credited.slots, credited.files!.lines.length], [['copies', 'Various Artists', 'Night Market Sampler'], isEmpty, 3]);
      final old = tagged([for (final t in sampler) noCredit(t)]);
      expect([crumbsOf(old), old.slots, old.files], [['copies', '‹ARTIST›', 'Night Market Sampler'], [LayoutSlot.artist], null],
          reason: 'an older peer: "copies › ‹artist› › Night Market Sampler"');
      // one song without the credit files under its artist, the others
      // under theirs: the album credit's own slot, as the webapp's
      final some = tagged([...sampler.sublist(0, 2), noCredit(sampler[2])]);
      expect([crumbsOf(some), some.slots], [['copies', '‹ALBUMARTIST›', 'Night Market Sampler'], [LayoutSlot.albumArtist]]);
      final one = tagged([sampler[0], noCredit(sampler[1]), noCredit(sampler[2])]);
      expect([crumbsOf(one), one.slots], [['copies', '‹ALBUMARTIST›', 'Night Market Sampler'], [LayoutSlot.albumArtist]],
          reason: 'one song of three naming a credit: still the slot');
      expect(crumbsOf(tagged([for (final t in tapesMd) noCredit(t)])), ['copies', 'Boukmanflow', 'Borrowed Tapes'],
          reason: 'the songs agree on their artist and name no credit: the artist is the credit');
      final mixed = tagged([...tapesMd.sublist(0, 2), md('$folder/x.mp3', credit: 'Various Artists')]);
      expect([crumbsOf(mixed), mixed.files], [['copies', '‹ALBUMARTIST›', 'Borrowed Tapes'], null],
          reason: 'credits that disagree: a slot, never the folder of one — though every song is by Boukmanflow');
      expect(crumbsOf(tagged(sampler, layout: '{{ALBUMARTIST}}/{{ARTIST}}')), ['copies', 'Various Artists', '‹ARTIST›']);
      expect(crumbsOf(tagged([...tapesMd.sublist(0, 2), md('$folder/x.mp3', credit: 'Various Artists')], layout: '{{ARTIST}}/{{ALBUM}}')),
          ['copies', 'Boukmanflow', 'Borrowed Tapes'], reason: 'a layout that names no credit: no slot');
    });

    test('{{YEAR}}, {{GENRE}}, {{SERVERFOLDER}}: the value every song agrees on, else a slot — the genre only where every song\'s is known', () {
      final years = tagged([...tapesMd.sublist(0, 2), md('$folder/x.mp3', year: 2020)], layout: '{{ALBUMARTIST}}/{{ALBUM}} ({{YEAR}})');
      expect([crumbsOf(years), years.slots, years.files], [['copies', 'Boukmanflow', 'Borrowed Tapes (‹YEAR›)'], [LayoutSlot.year], null]);
      expect(crumbsOf(tagged([...tapesMd.sublist(0, 2), md('$folder/x.mp3', genres: const [])], layout: '{{GENRE}}/{{ALBUM}}')), ['copies', '‹GENRE›', 'Borrowed Tapes']);
      expect(crumbsOf(tagged([...tapesMd.sublist(0, 2), md('$folder/x.mp3', genres: const ['Hip-Hop', 'Rap'])], layout: '{{GENRE}}/{{ALBUM}}')), ['copies', '‹GENRE›', 'Borrowed Tapes'],
          reason: 'a split tag is unknown');
      expect(crumbsOf(tagged([for (final f in tapes) md('$folder/$f', genres: const ['Hip-Hop', 'Rap'])], layout: '{{GENRE}}/{{ALBUM}}')), ['copies', '‹GENRE›', 'Borrowed Tapes'],
          reason: 'every song unknown alike is still unknown — never a folder that drops out');
      final discs = tagged([md('$folder/CD1/a.mp3'), md('$folder/CD2/a.mp3')], layout: '{{ALBUMARTIST}}/{{SERVERFOLDER}}');
      expect([crumbsOf(discs), discs.slots], [['copies', 'Boukmanflow', '‹SERVERFOLDER›'], [LayoutSlot.serverFolder]]);
      final artists = tagged([...tapesMd.sublist(0, 2), md('$folder/x.mp3', display: 'Boukmanflow feat. ALM')], layout: '{{ARTIST}}/{{ALBUM}}');
      expect(crumbsOf(artists), ['copies', '‹ARTIST›', 'Borrowed Tapes'], reason: 'the artist tag as written');
    });

    test('no tags (past 100 songs, or no answer): every tag variable a slot, and "one folder per album"', () {
      final p = tagged(null, folder: 'music/Night Owl Radio Archive', songs: planned(boukmanflow, 'music/Boukmanflow'));
      expect([crumbsOf(p), p.slots, p.perAlbum, p.files], [['copies', '‹ARTIST›'], [LayoutSlot.artist], true, null]);
      expect(crumbsOf(tagged(const [], layout: 'From friends/{{GENRE}}/{{ALBUM}}')), ['copies', 'From friends', '‹GENRE›'],
          reason: 'an empty answer is none');
    });

    test("the layout's refusals come through", () {
      final bad = tagged(tapesMd, layout: '{{ARTST}}/{{ALBUM}}');
      expect([bad.valid, bad.target.field, bad.target.error, bad.landing, bad.files], [false, 'layout', 'unknown_variable', FolderLanding.tags, null]);
    });
  });

  group("a folder copy as the phone's job", () {
    DiscoveryJob job(Map<String, dynamic> m) => DiscoveryJob.fromServerMap({'id': 1, 'plugin': 'federation-copy', ...m})!;
    Map<String, dynamic> result({int copied = 11, int skipped = 1, int failed = 0, String? stopped, String? landed = 'copies/Boukmanflow/Borrowed Tapes'}) => {
          'scope': 'folder',
          'folder': {'path': folder, 'name': 'Borrowed Tapes', 'landed': landed},
          'layout': landed == null ? 'tags' : 'mirror',
          'songs': {'total': copied + skipped + failed, 'copied': [], 'skipped': [], 'failed': []},
          'counts': {'total': copied + skipped + failed, 'copied': copied, 'skipped': skipped, 'failed': failed},
          'skippedFiles': [
            {'from': '$folder/notes.txt', 'why': 'unsupported'},
            {'from': '$folder/.cover.jpg', 'why': 'ignored'},
          ],
          'stopped': stopped,
          'peer': {'id': 1, 'name': 'Stage Peer B'},
        };

    test('isKeepCopy: Discover\'s copies and a folder with whatever landing; no landing on another scope, no choice, no other plug-in', () {
      expect(isKeepCopy(job({})), isTrue);
      expect(isKeepCopy(job({'params': {'scope': 'album'}})), isTrue);
      expect(isKeepCopy(job({'params': {'scope': 'folder'}})), isTrue);
      expect(isKeepCopy(job({'params': {'scope': 'folder', 'landing': {'vpath': 'music', 'path': 'mine'}}})), isTrue);
      expect(isKeepCopy(job({'params': {'scope': 'folder', 'landing': {'tags': true}}})), isTrue);
      expect(isKeepCopy(job({'params': {'scope': 'album', 'landing': {'tags': true}}})), isFalse);
      expect(isKeepCopy(job({'params': {'choice': {'url': 'https://x'}}})), isFalse);
      expect(isKeepCopy(job({'plugin': 'youtube'})), isFalse);
      expect(isKeepCopy(job({'params': {'scope': 'genre'}})), isFalse);
      expect(isKeepCopy(null), isFalse);
      // Discover's own markers still never read a folder copy
      expect(isDiscoverCopy(job({'params': {'scope': 'folder'}})), isFalse);
      expect(kDiscoverJobScopes.contains(kScopeFolder), isFalse);
      expect(kKeepJobScopes, [...kDiscoverJobScopes, kScopeFolder]);
    });

    test('where its files are: its landing once it copied any; with none copied, the folder the songs it found share — never a landing it never made', () {
      Map<String, dynamic> found(List<Object?> at, {String? landed = 'copies/Borrowed Tapes', bool truncated = false}) => {
            ...result(copied: 0, skipped: at.length, landed: landed),
            'songs': {
              'total': at.length,
              'copied': [],
              'skipped': [for (final a in at) {'from': '$folder/x.mp3', 'why': 'owned', 'at': a}],
              'failed': [],
            },
            if (truncated) 'truncated': true,
          };
      String? at(Map<String, dynamic> r) => job({'state': 'done', 'params': {'scope': 'folder'}, 'result': r}).view.folderFilesAt;

      expect(at(result()), 'copies/Boukmanflow/Borrowed Tapes', reason: 'it copied: where it landed');
      // The live walk's job #1: into copies › Borrowed Tapes, all already in
      // copies/Boukmanflow/Borrowed Tapes.
      expect(at(found([for (final f in tapes) 'copies/Boukmanflow/Borrowed Tapes/$f'])), 'copies/Boukmanflow/Borrowed Tapes');
      expect(at(found(['copies/ALM/a.mp3', 'copies/First Transmission/b.mp3'])), 'copies', reason: 'the folder they share');
      expect(at(found(['copies/Borrowed Tapes/01.mp3'])), 'copies/Borrowed Tapes', reason: 'a file already at the path (exists) is there');
      expect(at(found(['music/Boukmanflow/a.mp3', 'copies/Boukmanflow/b.mp3'])), isNull, reason: 'two libraries: no one folder');
      expect(at(found(['copies/ALM/a.mp3', null])), isNull, reason: 'one it cannot place');
      expect(at(found(['a.mp3'])), isNull, reason: 'no library');
      expect(at(found(['copies/ALM/a.mp3'], truncated: true)), isNull, reason: 'the list stopped short of naming them all');
      expect(at(found(['copies/ALM/a.mp3'], landed: null)), isNull, reason: 'by your layout: no one folder, as before');
      expect(at(found(const [])), isNull, reason: 'nothing found');
    });

    test('its kind, its title, its own landing', () {
      final j = job({'recommendation': {'filepath': folder, 'title': 'Borrowed Tapes', 'peer': {'id': 1}}, 'params': {'scope': 'folder', 'landing': {'vpath': null, 'path': 'From Sam'}}});
      expect([jobKind(j), jobTitle(j), j.landing], [JobKind.folder, 'Borrowed Tapes', {'vpath': null, 'path': 'From Sam'}]);
      expect(folderTitle(const {'filepath': 'music/Boukmanflow/Borrowed Tapes'}), 'Borrowed Tapes', reason: 'no title: the last folder');
    });

    test('in your collection: where its files went (folder.landed) and the files it left out', () {
      final r = jobRowState(job({'state': 'done', 'params': {'scope': 'folder'}, 'result': result()}));
      expect([r.kind, r.tag, r.landed, r.skippedFiles], [JobRowKind.copiedMany, JobPhrase.inCollection, 'copies/Boukmanflow/Borrowed Tapes', 2]);
      expect(manyParts(result()), const [JobText(JobPhrase.copiedCount, count: 11), JobText(JobPhrase.ownedCount, count: 1)]);
      final byTags = jobRowState(job({'state': 'done', 'params': {'scope': 'folder', 'landing': {'tags': true}}, 'result': result(landed: null)}));
      expect(byTags.landed, isNull, reason: 'filed by the layout: each song went its own way');
      final running = jobRowState(job({'state': 'running', 'params': {'scope': 'folder'}, 'statusText': '2 of 3 songs · 4.1 MB', 'result': result()}));
      expect([running.kind, running.skippedFiles], [JobRowKind.running, 2]);
      expect(jobRowState(job({'state': 'done'})).skippedFiles, 0, reason: 'every other copy');
    });

    test('done is not kept: nothing copied with failures is a failure (Retry); stopped by the peer has Retry; refused has none', () {
      expect(jobRowState(job({'state': 'done', 'params': {'scope': 'folder'}, 'result': result(copied: 0, skipped: 0, failed: 3)})).actions, [JobAction.retry]);
      final peer = jobRowState(job({'state': 'done', 'params': {'scope': 'folder'}, 'result': result(copied: 1, stopped: 'peer')}));
      expect([peer.kind, peer.actions], [JobRowKind.stopped, [JobAction.retry]]);
      final refused = jobRowState(job({'state': 'done', 'params': {'scope': 'folder'}, 'result': result(copied: 0, skipped: 0, stopped: 'refused')}));
      expect([refused.kind, refused.leadPhrase, refused.actions], [JobRowKind.stopped, JobPhrase.stoppedRefused, isEmpty]);
      expect(wantsAttention(job({'state': 'done', 'params': {'scope': 'folder'}, 'result': result(copied: 0, skipped: 0, stopped: 'refused')})), isTrue,
          reason: 'it stays in the Copies list until cleared');
    });
  });

  group("maxFolderSongs: the cap the plug-in listing names", () {
    test('a whole number from jobs.maxFolderSongs; none (an older server) is null — no cap known', () {
      PluginListing listing(Object? jobs) => PluginListing.fromServerMap({'plugins': const [], 'jobs': jobs});
      expect([for (final j in [{'allowed': true, 'maxFolderSongs': 1000}, {'allowed': true, 'maxFolderSongs': '250'}, {'allowed': true, 'maxFolderSongs': 12.7}]) listing(j).maxFolderSongs],
          [1000, 250, 12]);
      expect([for (final j in <Object?>[{'allowed': true}, {'maxFolderSongs': 0}, {'maxFolderSongs': -5}, {'maxFolderSongs': 'lots'}, {'maxFolderSongs': null}, null]) listing(j).maxFolderSongs],
          [null, null, null, null, null, null]);
      expect(PluginListing.fromServerMap(const {'plugins': []}).maxFolderSongs, isNull);
      expect(listing({'allowed': true, 'maxFolderSongs': 1000}).jobsAllowed, isTrue);
    });
  });
}
