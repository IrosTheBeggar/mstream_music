// lib/util/ytdl_layout.dart — where an Add from YouTube song lands. Golden
// values for every board that draws a path: FoundMusic, FoundCleaned
// ("Music › Gorillaz", ALBUM missing), ChannelGuess, the LinkStates panels,
// YearTrap's bracket traps ("()", "Discovery ()") and the dangling
// "Gorillaz -", WhereCustom's three errors ({{TITLE}}, {{GENRE}},
// "Singles: 2024"), Top of the library, Same as Discover's base folders,
// and the explorer sheet's Right here and Album subfolder. The layout is
// rendered by the Discover picker's engine (discover_jobs.dart), which its
// own test holds to the server's.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/ytdl_layout.dart';

const daftPunk = YtdlTags(artist: 'Daft Punk', album: 'Discovery', year: '2001');
const gorillaz = YtdlTags(artist: 'Gorillaz');
const libraryLayout = '{{ARTIST}}/{{ALBUM}} ({{YEAR}})';

void expectTarget(
  YtdlTarget t, {
  required List<String> crumbs,
  required String directory,
  List<String> missing = const [],
  List<String> never = const [],
  YtdlTrap? trap,
}) {
  expect(t.valid, isTrue, reason: '$t');
  expect(t.error, isNull);
  expect(t.crumbs, crumbs);
  expect(t.library, crumbs.first);
  expect(t.segments, crumbs.sublist(1));
  expect(t.relDir, crumbs.sublist(1).join('/'));
  expect(t.directory, directory);
  expect(t.missingVars, missing);
  expect(t.neverVars, never);
  expect(t.trap, trap);
}

void main() {
  group('the presets', () {
    test('constants', () {
      expect(kYtdlVars, ['ARTIST', 'ALBUMARTIST', 'ALBUM', 'YEAR']);
      expect(kYtdlNeverVars, ['GENRE', 'PEER', 'SERVERFOLDER']);
      expect(kYtdlLayoutArtistAlbum, '{{ALBUMARTIST}}/{{ALBUM}}');
      expect(kYtdlLayoutArtist, '{{ALBUMARTIST}}');
      expect(kYtdlLayoutAlbum, '{{ALBUM}}');
      expect(kYtdlLayoutTop, '');
      for (final l in [kYtdlLayoutArtistAlbum, kYtdlLayoutArtist, kYtdlLayoutAlbum, kYtdlLayoutTop]) {
        expect(ytdlLayoutCheck(l).valid, isTrue, reason: l);
      }
    });

    test('FoundMusic: Artist / Album → Music › Daft Punk › Discovery', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: kYtdlLayoutArtistAlbum, tags: daftPunk),
        crumbs: ['Music', 'Daft Punk', 'Discovery'],
        directory: '/Music/Daft Punk/Discovery/',
      );
    });

    test('FoundCleaned: no album → Music › Gorillaz, ALBUM left out, never an "Album ()" folder', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: kYtdlLayoutArtistAlbum, tags: gorillaz),
        crumbs: ['Music', 'Gorillaz'],
        directory: '/Music/Gorillaz/',
        missing: ['ALBUM'],
      );
    });

    test('ChannelGuess and LinkStates 10: Music › TheNeighbourhood, Music › Кино', () {
      expectTarget(
        ytdlTarget(
            vpath: 'Music',
            layout: kYtdlLayoutArtistAlbum,
            tags: const YtdlTags(artist: 'TheNeighbourhood')),
        crumbs: ['Music', 'TheNeighbourhood'],
        directory: '/Music/TheNeighbourhood/',
        missing: ['ALBUM'],
      );
      expectTarget(
        ytdlTarget(
            vpath: 'Music', layout: kYtdlLayoutArtistAlbum, tags: const YtdlTags(artist: 'Кино')),
        crumbs: ['Music', 'Кино'],
        directory: '/Music/Кино/',
        missing: ['ALBUM'],
      );
    });

    test('LinkStates 7: no tags yet → the library\'s top folder', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: kYtdlLayoutArtistAlbum, tags: const YtdlTags()),
        crumbs: ['Music'],
        directory: '/Music/',
        missing: ['ALBUMARTIST', 'ALBUM'],
      );
    });

    test('Artist: ALBUMARTIST is the Artist field', () {
      expectTarget(
        ytdlTarget(vpath: 'Mixes', layout: kYtdlLayoutArtist, tags: daftPunk),
        crumbs: ['Mixes', 'Daft Punk'],
        directory: '/Mixes/Daft Punk/',
      );
    });

    test('Top of the library: no folders, no previewTarget', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: kYtdlLayoutTop, tags: daftPunk),
        crumbs: ['Music'],
        directory: '/Music/',
      );
    });

    test('a tag that cannot be a folder name is folded, as the server folds it', () {
      expectTarget(
        ytdlTarget(
            vpath: 'Music',
            layout: kYtdlLayoutArtistAlbum,
            tags: const YtdlTags(artist: 'AC/DC', album: 'Back In Black?')),
        crumbs: ['Music', 'AC-DC', 'Back In Black-'],
        directory: '/Music/AC-DC/Back In Black-/',
      );
    });
  });

  group('Same as Discover: the account\'s base folders come first', () {
    test('Music › From Discover › Daft Punk › Discovery', () {
      expectTarget(
        ytdlTarget(
            vpath: 'Music',
            base: 'From Discover',
            layout: kYtdlLayoutArtistAlbum,
            tags: daftPunk),
        crumbs: ['Music', 'From Discover', 'Daft Punk', 'Discovery'],
        directory: '/Music/From Discover/Daft Punk/Discovery/',
      );
    });

    test('several base folders, either separator', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', base: r'Added\ From Discover /', layout: kYtdlLayoutAlbum, tags: daftPunk),
        crumbs: ['Music', 'Added', 'From Discover', 'Discovery'],
        directory: '/Music/Added/From Discover/Discovery/',
      );
    });

    test('Top of the library with a base folder is the base folder', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', base: 'From Discover', layout: '', tags: daftPunk),
        crumbs: ['Music', 'From Discover'],
        directory: '/Music/From Discover/',
      );
    });

    test('a base folder the server would refuse makes no target', () {
      final t = ytdlTarget(vpath: 'Music', base: '..', layout: '', tags: daftPunk);
      expect(t.valid, isFalse);
      expect(t.error, 'traversal');
      expect(t.directory, '');
      expect(t.crumbs, ['Music']);
      final u = ytdlTarget(vpath: 'Music', base: '..', layout: kYtdlLayoutArtist, tags: daftPunk);
      expect(u.valid, isFalse);
      expect(u.error, 'traversal');
    });
  });

  group('YearTrap: folders an empty variable leaves as brackets', () {
    test('no album, no year: Music › Gorillaz › ()', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: libraryLayout, tags: gorillaz),
        crumbs: ['Music', 'Gorillaz', '()'],
        directory: '/Music/Gorillaz/()/',
        missing: ['ALBUM', 'YEAR'],
        trap: const YtdlTrap(YtdlTrapKind.emptyFolder, '()'),
      );
    });

    test('album, no year: Music › Daft Punk › Discovery ()', () {
      expectTarget(
        ytdlTarget(
            vpath: 'Music',
            layout: libraryLayout,
            tags: const YtdlTags(artist: 'Daft Punk', album: 'Discovery')),
        crumbs: ['Music', 'Daft Punk', 'Discovery ()'],
        directory: '/Music/Daft Punk/Discovery ()/',
        missing: ['YEAR'],
        trap: const YtdlTrap(YtdlTrapKind.missingYear, 'Discovery ()'),
      );
    });

    test('every tag: no trap', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: libraryLayout, tags: daftPunk),
        crumbs: ['Music', 'Daft Punk', 'Discovery (2001)'],
        directory: '/Music/Daft Punk/Discovery (2001)/',
      );
    });

    test('a dangling separator: Music › Gorillaz -', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: '{{ARTIST}} - {{ALBUM}}', tags: gorillaz),
        crumbs: ['Music', 'Gorillaz -'],
        directory: '/Music/Gorillaz -/',
        missing: ['ALBUM'],
        trap: const YtdlTrap(YtdlTrapKind.other, 'Gorillaz -'),
      );
    });

    test('square brackets, a leading separator, a year left dangling', () {
      expect(ytdlTarget(vpath: 'Music', layout: '{{ARTIST}}/[{{YEAR}}]', tags: gorillaz).trap,
          const YtdlTrap(YtdlTrapKind.emptyFolder, '[]'));
      expect(ytdlTarget(vpath: 'Music', layout: '{{ALBUM}} - {{ARTIST}}', tags: gorillaz).trap,
          const YtdlTrap(YtdlTrapKind.other, '- Gorillaz'));
      expect(
          ytdlTarget(
                  vpath: 'Music',
                  layout: '{{ALBUM}} - {{YEAR}}',
                  tags: const YtdlTags(album: 'Discovery'))
              .trap,
          const YtdlTrap(YtdlTrapKind.missingYear, 'Discovery -'));
      expect(
          ytdlTarget(vpath: 'Music', layout: '{{ARTIST}} - {{ALBUM}}', tags: const YtdlTags())
              .trap,
          const YtdlTrap(YtdlTrapKind.emptyFolder, '-'));
    });

    test('a never-variable that empties a folder is a trap too', () {
      final t = ytdlTarget(vpath: 'Music', layout: '{{ALBUM}} ({{GENRE}})', tags: daftPunk);
      expect(t.trap, const YtdlTrap(YtdlTrapKind.other, 'Discovery ()'));
      expect(t.neverVars, ['GENRE']);
    });

    test('brackets typed as text, with nothing emptied in that folder, are the user\'s own', () {
      expect(ytdlTarget(vpath: 'Music', layout: '{{ARTIST}}/Singles ()', tags: gorillaz).trap,
          isNull);
      expect(ytdlTarget(vpath: 'Music', layout: '{{ARTIST}}/{{ALBUM}}', tags: gorillaz).trap,
          isNull, reason: 'an emptied folder is dropped, not a trap');
    });
  });

  group('WhereCustom: a layout typed by hand', () {
    test('{{ARTIST}}/Singles → Music › Daft Punk › Singles', () {
      expect(ytdlLayoutCheck('{{ARTIST}}/Singles').valid, isTrue);
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: '{{ARTIST}}/Singles', tags: daftPunk),
        crumbs: ['Music', 'Daft Punk', 'Singles'],
        directory: '/Music/Daft Punk/Singles/',
      );
    });

    test('error 1: Unknown variable {{TITLE}}, the token as typed', () {
      final c = ytdlLayoutCheck('{{ARTIST}}/{{TITLE}}');
      expect(c.valid, isFalse);
      expect(c.issue, YtdlLayoutIssue.unknownVariable);
      expect(c.token, '{{TITLE}}');
      expect(ytdlLayoutCheck('{{artist}}/{{ title }}').token, '{{ title }}');
      final t = ytdlTarget(vpath: 'Music', layout: '{{ARTIST}}/{{TITLE}}', tags: daftPunk);
      expect(t.valid, isFalse);
      expect(t.error, 'unknown_variable');
      expect(t.directory, '');
    });

    test('error 2: {{GENRE}} is always empty for YouTube songs (PEER and SERVERFOLDER too)', () {
      final c = ytdlLayoutCheck('{{GENRE}}/{{ARTIST}}');
      expect(c.issue, YtdlLayoutIssue.neverVariable);
      expect(c.token, '{{GENRE}}');
      expect(ytdlLayoutCheck('{{ARTIST}}/{{ peer }}').token, '{{ peer }}');
      expect(ytdlLayoutCheck('{{SERVERFOLDER}}').issue, YtdlLayoutIssue.neverVariable);
    });

    test('error 3: "Singles: 2024" — a folder name can\'t contain : * ? " < > or |', () {
      final c = ytdlLayoutCheck('Singles: 2024');
      expect(c.issue, YtdlLayoutIssue.badChars);
      expect(c.token, ':');
      for (final bad in ['a*b', 'a?b', 'a"b', 'a<b', 'a>b', 'a|b', '{{ARTIST}} | Live']) {
        expect(ytdlLayoutCheck(bad).issue, YtdlLayoutIssue.badChars, reason: bad);
      }
      final t = ytdlTarget(vpath: 'Music', layout: 'Singles: 2024', tags: daftPunk);
      expect(t.valid, isFalse);
      expect(t.error, 'bad_chars');
    });

    test('the allow-list runs after validateLayout, the literal check last', () {
      expect(ytdlLayoutCheck('{{TITLE}}/{{GENRE}}').issue, YtdlLayoutIssue.unknownVariable);
      expect(ytdlLayoutCheck('{{GENRE}}: x').issue, YtdlLayoutIssue.neverVariable);
    });

    test('the engine\'s own refusals come back as engine, with its check', () {
      for (final (layout, code) in [
        ('{ARTIST}', 'unbalanced_braces'),
        ('/{{ARTIST}}', 'absolute_template'),
        ('C:', 'drive_letter'),
        ('../{{ARTIST}}', 'traversal'),
        ('~/{{ARTIST}}', 'home_string'),
      ]) {
        final c = ytdlLayoutCheck(layout);
        expect(c.issue, YtdlLayoutIssue.engine, reason: layout);
        expect(c.engine?.error, code, reason: layout);
      }
    });

    test('an empty layout passes here: callers treat it as Top of the library', () {
      final c = ytdlLayoutCheck('');
      expect(c.valid, isTrue);
      expect(c.issue, YtdlLayoutIssue.none);
      expect(c.token, isNull);
    });
  });

  group('a library layout that names a never-variable still renders', () {
    test('{{GENRE}}/{{ARTIST}}: GENRE left out, listed apart from missingVars', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: '{{GENRE}}/{{ARTIST}}', tags: daftPunk),
        crumbs: ['Music', 'Daft Punk'],
        directory: '/Music/Daft Punk/',
        never: ['GENRE'],
      );
    });

    test('{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}} and {{SERVERFOLDER}}', () {
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: '{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}', tags: gorillaz),
        crumbs: ['Music', 'Gorillaz'],
        directory: '/Music/Gorillaz/',
        missing: ['ALBUM'],
        never: ['PEER'],
      );
      expectTarget(
        ytdlTarget(vpath: 'Music', layout: '{{SERVERFOLDER}}', tags: daftPunk),
        crumbs: ['Music'],
        directory: '/Music/',
        never: ['SERVERFOLDER'],
      );
    });
  });

  group('the explorer sheet: under the folder on screen', () {
    test('Right here keeps currentPath unchanged', () {
      expectTarget(
        ytdlFolderTarget(currentPath: '/Music/Daft Punk/', layout: kYtdlLayoutTop, tags: daftPunk),
        crumbs: ['Music', 'Daft Punk'],
        directory: '/Music/Daft Punk/',
      );
      expectTarget(
        ytdlFolderTarget(currentPath: '/Music/', layout: '', tags: daftPunk),
        crumbs: ['Music'],
        directory: '/Music/',
      );
    });

    test('ExplorerSubfolders: Album → /Music/Daft Punk/Discovery/', () {
      expectTarget(
        ytdlFolderTarget(currentPath: '/Music/Daft Punk/', layout: kYtdlLayoutAlbum, tags: daftPunk),
        crumbs: ['Music', 'Daft Punk', 'Discovery'],
        directory: '/Music/Daft Punk/Discovery/',
      );
    });

    test('Artist / Album under the folder', () {
      expectTarget(
        ytdlFolderTarget(
            currentPath: '/Music/Daft Punk/', layout: kYtdlLayoutArtistAlbum, tags: daftPunk),
        crumbs: ['Music', 'Daft Punk', 'Daft Punk', 'Discovery'],
        directory: '/Music/Daft Punk/Daft Punk/Discovery/',
      );
    });

    test('nothing to fill the subfolder: the song lands right here', () {
      expectTarget(
        ytdlFolderTarget(currentPath: '/Music/Daft Punk/', layout: kYtdlLayoutAlbum, tags: gorillaz),
        crumbs: ['Music', 'Daft Punk'],
        directory: '/Music/Daft Punk/',
        missing: ['ALBUM'],
      );
    });

    test('the folder on screen is taken as it is, even a name a base folder could not be', () {
      expectTarget(
        ytdlFolderTarget(currentPath: '/Music/~Odd C: Folder/', layout: kYtdlLayoutAlbum, tags: daftPunk),
        crumbs: ['Music', '~Odd C: Folder', 'Discovery'],
        directory: '/Music/~Odd C: Folder/Discovery/',
      );
    });

    test('the same checks and traps as the home screen', () {
      final bad = ytdlFolderTarget(currentPath: '/Music/', layout: 'Singles: 2024', tags: daftPunk);
      expect(bad.valid, isFalse);
      expect(bad.error, 'bad_chars');
      final unknown =
          ytdlFolderTarget(currentPath: '/Music/', layout: '{{TITLE}}', tags: daftPunk);
      expect(unknown.valid, isFalse);
      expect(unknown.error, 'unknown_variable');
      final trap = ytdlFolderTarget(
          currentPath: '/Music/Daft Punk/', layout: '{{ALBUM}} ({{YEAR}})', tags: const YtdlTags(album: 'Discovery'));
      expect(trap.directory, '/Music/Daft Punk/Discovery ()/');
      expect(trap.trap, const YtdlTrap(YtdlTrapKind.missingYear, 'Discovery ()'));
    });
  });
}
