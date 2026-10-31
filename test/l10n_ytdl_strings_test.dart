// Add from YouTube's English strings (the ytdl… keys) and the existing keys
// the feature reuses.
//
// The design's copy is final, so these pin the parts an ARB edit breaks most
// easily: the curly quotes around titles and folder names, the ' · ' and ' › '
// separators, a path read aloud one folder at a time ("Music, then Daft Punk,
// then Discovery, a new folder"), the result card's one-sentence summary and
// the count forms. They also read app_en.arb itself: every ytdl key has a
// description and declares exactly the placeholders its message uses, and no
// message says "download", which means saving to this phone everywhere else
// in the app. Until the translations land every locale shows these in
// English; the count check runs in every locale so a translation that drops
// the number fails here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  /// A path read aloud the way the screen builds it: folder by folder with
  /// ytdlCrumbThen, the last one marked new when [lastIsNew].
  String spoken(List<String> crumbs, {bool lastIsNew = false}) {
    final parts = [
      ...crumbs.take(crumbs.length - 1),
      lastIsNew ? en.ytdlCrumbNew(crumbs.last) : crumbs.last,
    ];
    return parts.skip(1).fold(parts.first, en.ytdlCrumbThen);
  }

  group('the app_en.arb entries', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final keys = [
      for (final k in arb.keys)
        if (k.startsWith('ytdl')) k,
    ];

    test('every ytdl key has a description and declares the placeholders it uses',
        () {
      expect(keys.length, greaterThan(150));
      final argument = RegExp(r'\{\s*([A-Za-z_]\w*)\s*[},]');
      for (final k in keys) {
        final meta = arb['@$k'] as Map<String, dynamic>?;
        expect(meta?['description'], isA<String>(), reason: k);
        final declared =
            ((meta?['placeholders'] as Map<String, dynamic>?) ?? const {})
                .keys
                .toSet();
        final used = {
          for (final m in argument.allMatches(arb[k] as String)) m[1]!,
        };
        expect(used, declared, reason: k);
      }
    });

    test('no message says download, and apostrophes stay straight', () {
      // These name the server's own downloader, not the user's action.
      const namesTheDownloader = {
        'ytdlYtdlpMissing',
        'ytdlLookupTimedOut',
        'ytdlErrNoRoute',
      };
      for (final k in keys) {
        final message = arb[k] as String;
        if (!namesTheDownloader.contains(k)) {
          expect(message.toLowerCase(), isNot(contains('download')), reason: k);
        }
        expect(message, isNot(contains('’')), reason: k);
      }
    });
  });

  group('the words on screen', () {
    test('titles, folder names and file names sit in curly quotes', () {
      expect(en.ytdlCleanedFrom('Gorillaz - Feel Good Inc. (Official Video) [HD]'),
          'Cleaned from “Gorillaz - Feel Good Inc. (Official Video) [HD]”');
      expect(en.ytdlWhereLandsAt('One More Time'), '“One More Time” lands at');
      expect(en.ytdlWhereFileNote('One More Time'),
          'The file name comes from the video title; your library shows “One More Time”.');
      expect(en.ytdlToastAdded('One More Time', 'Daft Punk › Discovery'),
          'Added “One More Time” to Daft Punk › Discovery');
      expect(en.ytdlCouldntAdd('Around the World'), 'Couldn\'t add “Around the World”');
      expect(en.ytdlStripAdding('One More Time'), 'Adding “One More Time”…');
      expect(en.ytdlErrLibraryGone('Music'),
          'You can\'t add files to “Music” any more. Pick another library.');
      expect(en.ytdlErrLibraryGoneSheet('Music'), 'You can\'t add files to “Music” any more.');
      expect(en.ytdlErrMkdir('Discovery'), 'Couldn\'t make the folder “Discovery”.');
      expect(en.ytdlErrOther('Not A Directory'), 'The server said: “Not A Directory”');
      expect(en.ytdlNoMkdirNew('Discovery'),
          '“Discovery” doesn\'t exist yet and your account can\'t make folders.');
      expect(en.ytdlClash('_.mp3'),
          'Something like “_.mp3” looks to be in this folder already. '
          'The server won\'t replace it, so this would likely fail.');
      expect(en.ytdlClashOlder('_.mp3'),
          'A file named “_.mp3” is already in this folder. '
          'This server would re-tag that file instead of adding a new one.');
      expect(en.ytdlTrapEmpty('()'),
          'Nothing to fill this folder, so it\'s named “()”. '
          'Add an album and year, or pick another layout.');
      expect(en.ytdlTrapNoYear('Discovery ()'),
          'No year for this song, so the folder reads “Discovery ()”. '
          'The file still gets YouTube\'s upload year as its tag.');
      expect(en.ytdlHelpYoutubeArtistStripped('VEVO'),
          'From YouTube\'s artist field, “VEVO” removed — check it');
      expect(en.ytdlBlankArtistGuess('TheNeighbourhoodVEVO'),
          'Blank: the file gets YouTube\'s own artist guess, often the raw channel '
          'name (here “TheNeighbourhoodVEVO”).');
    });

    test('variable tokens pass through untouched', () {
      const vars = 'ARTIST, ALBUMARTIST, ALBUM, YEAR';
      expect(en.ytdlErrNeverVar('{{GENRE}}', vars),
          '{{GENRE}} is always empty for YouTube songs. Use ARTIST, ALBUMARTIST, ALBUM, YEAR.');
      expect(en.ytdlWhereAlwaysEmpty('{{GENRE}}'),
          'Always empty for YouTube songs, so left out: {{GENRE}}');
      expect(en.ytdlErrBadChars, 'A folder name can\'t contain : * ? " < > or |.');
    });

    test('lines that carry a path or a link', () {
      expect(en.ytdlLandsIn('Music › Artist › Album'), 'Lands in Music › Artist › Album');
      expect(en.ytdlSheetInto('Music › Daft Punk'), 'Into Music › Daft Punk');
      expect(en.ytdlSaveToInstead('Music › Daft Punk'), 'Save to Music › Daft Punk instead');
      expect(en.ytdlToastSaved('Music › Artist › Album'),
          'Saved · new songs land in Music › Artist › Album');
      expect(en.ytdlLinkShortSent('youtube.com/watch?v=FGBhQbmPwH8'),
          'Short link: sent as youtube.com/watch?v=FGBhQbmPwH8');
      expect(en.ytdlLinkSentAs('youtube.com/watch?v=FGBhQbmPwH8'),
          'Sent as youtube.com/watch?v=FGBhQbmPwH8');
      expect(en.ytdlFileAbout('One_More_Time.mp3'), 'about One_More_Time.mp3');
      expect(en.ytdlFileAboutLettersDropped('_.mp3'),
          'about _.mp3 · letters outside A–Z are dropped from file names');
      expect(en.ytdlFormatRemembered('Home server'), 'Remembered for Home server');
      expect(en.ytdlWhereSub('Home server'),
          'Kept on this phone for Home server · Discover copies keep their own setting.');
      expect(en.ytdlErrFormatOff('Opus'), 'This server doesn\'t save Opus any more');
      expect(en.ytdlRestoreSplit('-'), 'Split at -');
    });

    test('counts', () {
      expect(en.ytdlHomeAdding(1), 'Adding 1');
      expect(en.ytdlHomeAdded(2), 'Added 2');
      expect(en.ytdlRowAdding(2, 'MP3'), 'Adding · 2 min · MP3');
      expect(en.ytdlStripAddingCount(1), 'Adding 1 video…');
      expect(en.ytdlStripAddingCount(2), 'Adding 2 videos…');
      expect(en.ytdlSubfoldersNew(1, 'Discovery'), '1 new folder will be made: Discovery');
      expect(en.ytdlSubfoldersNew(2, 'Daft Punk, Discovery'),
          '2 new folders will be made: Daft Punk, Discovery');
    });

    test('the limits line is one string', () {
      expect(en.ytdlLimits,
          'One video per link · the server stops at 500 MB or after an hour · '
          'no live streams or playlists');
    });
  });

  group('read aloud', () {
    test('a path is read one folder at a time, a new folder named as such', () {
      expect(spoken(['Music', 'Daft Punk', 'Discovery']),
          'Music, then Daft Punk, then Discovery');
      expect(spoken(['Music', 'TheNeighbourhood'], lastIsNew: true),
          'Music, then TheNeighbourhood, a new folder');
      expect(spoken(['Music']), 'Music');
    });

    test('a preview path ends in its file, brackets read as words', () {
      expect(
          en.ytdlCrumbFile(
              spoken(['Music', 'Gorillaz', en.ytdlCrumbEmptyBrackets]),
              'Gorillaz_-_Feel_Good_Inc._Official_Video_HD.mp3'),
          'Music, then Gorillaz, then empty brackets, '
          'file Gorillaz_-_Feel_Good_Inc._Official_Video_HD.mp3');
      expect(
          en.ytdlCrumbFile(
              spoken(['Music', 'Daft Punk', en.ytdlCrumbWithEmptyBrackets('Discovery')]),
              'One_More_Time.mp3'),
          'Music, then Daft Punk, then Discovery with empty brackets, file One_More_Time.mp3');
    });

    test('the result card is one sentence', () {
      final details = [
        en.ytdlSummaryBy('One More Time', 'Daft Punk'),
        en.ytdlSummaryAlbum('Discovery'),
        '2001',
      ].join(', ');
      expect(
          en.ytdlSummary(details, en.ytdlSourceMusic,
              spoken(['Music', 'Daft Punk', 'Discovery'], lastIsNew: true)),
          'One More Time, by Daft Punk, album Discovery, 2001. Tags from YouTube Music. '
          'Saves to Music, then Daft Punk, then Discovery, a new folder.');
      expect(
          en.ytdlSummary(
              [en.ytdlSummaryBy('Sweater Weather', 'TheNeighbourhood'), en.ytdlSummaryNoAlbum]
                  .join(', '),
              en.ytdlSourceChannel,
              spoken(['Music', 'TheNeighbourhood'], lastIsNew: true)),
          'Sweater Weather, by TheNeighbourhood, no album. '
          'Artist may be the channel name — check it. '
          'Saves to Music, then TheNeighbourhood, a new folder.');
    });

    test('labels', () {
      expect(en.ytdlA11yFormat('MP3'), 'Format, MP3');
      expect(en.ytdlA11yPutBack('(Official Video)'), 'Put back (Official Video)');
      expect(en.ytdlA11yPutBack('VEVO'), 'Put back VEVO');
      expect(en.ytdlA11yMoreFor('One More Time'), 'More for One More Time');
      expect(en.ytdlA11yVarUsed(en.discoverDestInsertAlbum), 'Insert album, used');
      expect(en.ytdlA11yUpTo('Music'), 'Up to Music');
    });
  });

  test('the reused keys still say what the design needs', () {
    expect(en.discoverCopiesFailed(1), '1 failed');
    expect(en.discoverDestErrUnknownVar('{{TITLE}}', 'ARTIST, ALBUMARTIST, ALBUM, YEAR'),
        'Unknown variable {{TITLE}}. Use ARTIST, ALBUMARTIST, ALBUM, YEAR.');
    expect(en.discoverDestMissing('{{ALBUM}}'),
        'No value for this song, so left out of the path: {{ALBUM}}');
    expect(en.discoverDestFixLayout, 'Fix the layout to see where files land');
    expect(en.discoverDestLibrary, 'Library');
    expect(en.discoverDestLayout, 'Layout');
    expect(en.discoverDestPresetArtistAlbum, 'Artist / Album');
    expect(en.discoverDestPresetLibrary, 'Library layout');
    expect(en.discoverDestPresetCustom, 'Custom');
    expect(en.discoverDestCustomSub, 'Type your own path');
    expect(en.discoverDestCustomField, 'Custom layout');
    expect(en.discoverDestInsertArtist, 'Insert artist');
    expect(en.discoverDestInsertAlbumArtist, 'Insert album artist');
    expect(en.discoverDestInsertAlbum, 'Insert album');
    expect(en.discoverDestInsertYear, 'Insert year');
    expect(en.torrentArtistLabel, 'Artist');
    expect(en.torrentAlbumLabel, 'Album');
    expect(en.torrentYearLabel, 'Year');
    expect(en.discoverKeepChange, 'Change');
    expect(en.discoverPageRetry, 'Try again');
    expect(en.discoverJobStarting, 'Starting…');
    expect(en.federationDismiss, 'Dismiss');
    expect(en.discoverCheckAgain, 'Check again');
    expect(en.discoverJobAddAgain, 'Add again');
    expect(en.discoverJobAddToQueue, 'Add to queue');
    expect(en.storageUseThisFolder, 'Use this folder');
    expect(en.save, 'Save');
    expect(en.close, 'Close');
    expect(en.cancel, 'Cancel');
    expect(en.done, 'Done');
  });

  test('every locale keeps the number in a count of 21 and of 0', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final t = lookupAppLocalizations(locale);
      for (final f in <String Function(int)>[
        t.ytdlHomeAdding,
        t.ytdlHomeAdded,
        t.ytdlStripAddingCount,
        (n) => t.ytdlSubfoldersNew(n, 'Discovery'),
        (n) => t.ytdlRowAdding(n, 'MP3'),
      ]) {
        expect(f(21), contains('21'), reason: '$locale ${f(21)}');
        expect(f(0), contains('0'), reason: '$locale ${f(0)}');
      }
    }
  });
}
