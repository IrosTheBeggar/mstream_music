// lib/util/ytdl_guess.dart — reading a YouTube lookup into tags.
//
// First the four title readers ported from the server
// (src/discovery-plugins/plugins/youtube.js): the server's own test values
// (test/unit/discovery-youtube.test.mjs), then a table of answers the
// server's code gave under Node for harder titles (nested and mismatched
// brackets, NEL, a "- Topic" title), so Discover and the phone read a title
// the same way. Then the phone's guess (spec §3 Auto-fill) on the spec's
// sample videos: the tier, the fragments it cut and how putting them back
// rebuilds the title and the artist, YouTube's artist and its strips, the
// year, and the phone's deliberate differences from the server.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/ytdl_guess.dart';

const noise = YtdlCut.noise;
const cut = YtdlCut.split;

Set<int> all(YtdlGuess g) => {for (var i = 0; i < g.fragments.length; i++) i};

/// What the server's own code made of each title: cleanTitle, then
/// splitArtistTitle of that, isTopicChannel and channelArtist of the title.
const serverAnswers = <(String, String, (String, String)?, bool, String?)>[
  ('Gorillaz - Feel Good Inc. (Official Video) [HD]', 'Gorillaz - Feel Good Inc.', ('Gorillaz', 'Feel Good Inc.'), false, 'Gorillaz - Feel Good Inc. (Official Video) [HD]'),
  ('Sweater Weather (Official Video)', 'Sweater Weather', null, false, 'Sweater Weather (Official Video)'),
  ('Кино – Группа крови', 'Кино – Группа крови', ('Кино', 'Группа крови'), false, 'Кино – Группа крови'),
  ('Daft Punk - Around the World (Official Audio)', 'Daft Punk - Around the World', ('Daft Punk', 'Around the World'), false, 'Daft Punk - Around the World (Official Audio)'),
  ('Song (Official Video (HD))', 'Song )', null, false, 'Song (Official Video (HD))'),
  ('Song (Official Video]', 'Song', null, false, 'Song (Official Video]'),
  ('Song [Lyrics] (Live)', 'Song (Live)', null, false, 'Song [Lyrics] (Live)'),
  ('Song - Official HD Music Video', 'Song', null, false, 'Song - Official HD Music Video'),
  ('Song : Audio Only', 'Song', null, false, 'Song : Audio Only'),
  ('Song — visualiser', 'Song', null, false, 'Song — visualiser'),
  ('Song (Full Song)', 'Song', null, false, 'Song (Full Song)'),
  ('Song [4K Remastered]', 'Song', null, false, 'Song [4K Remastered]'),
  ('Artist: Song Name', 'Artist: Song Name', null, false, 'Artist: Song Name'),
  ('A - B - C', 'A - B - C', ('A', 'B - C'), false, 'A - B - C'),
  ('Artist -Song', 'Artist -Song', null, false, 'Artist -Song'),
  ('  Spaced   -   Out  (Audio)  ', 'Spaced - Out', ('Spaced', 'Out'), false, 'Spaced   -   Out  (Audio)'),
  ('Neon Harbor - Topic', 'Neon Harbor - Topic', ('Neon Harbor', 'Topic'), true, 'Neon Harbor'),
  ('Neon Harbor-Topic', 'Neon Harbor-Topic', null, true, 'Neon Harbor'),
  ('Neon Harbor - topic ', 'Neon Harbor - topic', ('Neon Harbor', 'topic'), true, 'Neon Harbor - topic'),
  ('- Topic', '- Topic', null, true, null),
  ('Song\u0085(Official Audio)', 'Song\u0085', null, false, 'Song\u0085(Official Audio)'),
  ('Videogame (Lyric)', 'Videogame', null, false, 'Videogame (Lyric)'),
  ('Song (Explicit)', 'Song', null, false, 'Song (Explicit)'),
  ('Song (Clean)', 'Song', null, false, 'Song (Clean)'),
  ('Song (Official Live Video)', 'Song', null, false, 'Song (Official Live Video)'),
  ('Song (Live)', 'Song (Live)', null, false, 'Song (Live)'),
  ('【MV】米津玄師 - Lemon', '【MV】米津玄師 - Lemon', ('【MV】米津玄師', 'Lemon'), false, '【MV】米津玄師 - Lemon'),
  ('Song (MV)', 'Song (MV)', null, false, 'Song (MV)'),
  ('Artist - Song ft. Other (Official Video)', 'Artist - Song ft. Other', ('Artist', 'Song ft. Other'), false, 'Artist - Song ft. Other (Official Video)'),
  ('Song (Official Video) - Lyrics', 'Song', null, false, 'Song (Official Video) - Lyrics'),
  ('Song | HD Video', 'Song', null, false, 'Song | HD Video'),
  ('Song (HQ Audio) [1080p]', 'Song', null, false, 'Song (HQ Audio) [1080p]'),
];

/// Titles in [serverAnswers] the phone reads differently on purpose:
/// (Official Live Video) keeps "(Live)" and [4K Remastered] "[Remastered]",
/// 【MV】 and (MV) are noise, "ft." becomes "(feat. …)".
const phoneDiffers = {
  'Song (Official Live Video)',
  'Song [4K Remastered]',
  '【MV】米津玄師 - Lemon',
  'Song (MV)',
  'Artist - Song ft. Other (Official Video)',
};

void main() {
  group('the server\'s title readers: its own test values', () {
    test('edition noise goes, the song stays', () {
      expect(cleanTitle('Neon Harbor - Salt & Static (Official Audio)'),
          'Neon Harbor - Salt & Static');
      expect(cleanTitle('Salt & Static [Official Music Video] (HD)'), 'Salt & Static');
      expect(cleanTitle('Salt & Static | Official Lyric Video'), 'Salt & Static');
      expect(cleanTitle('Salt & Static - Lyrics'), 'Salt & Static');
      expect(cleanTitle('Salt & Static (2019 Remaster)'), 'Salt & Static (2019 Remaster)',
          reason: "remaster is the scorer's business, not noise");
    });

    test('"Artist - Title" splits; a title without a dash does not', () {
      expect(splitArtistTitle('Neon Harbor - Salt & Static'),
          (artist: 'Neon Harbor', title: 'Salt & Static'));
      expect(splitArtistTitle('Neon Harbor – Salt & Static'),
          (artist: 'Neon Harbor', title: 'Salt & Static'));
      expect(splitArtistTitle('Salt & Static'), isNull);
    });

    test("Topic channels are YouTube's own release audio", () {
      expect(isTopicChannel('Neon Harbor - Topic'), isTrue);
      expect(isTopicChannel('Neon Harbor'), isFalse);
      expect(channelArtist('Neon Harbor - Topic'), 'Neon Harbor');
      expect(channelArtist(''), isNull);
    });

    test('toCandidates reads a result split: the cleaned title, then the split', () {
      final cleaned = cleanTitle('Neon Harbor - Salt & Static (Official Audio)');
      expect(cleaned, 'Neon Harbor - Salt & Static');
      expect(splitArtistTitle(cleaned), (artist: 'Neon Harbor', title: 'Salt & Static'));
    });

    test('null and blanks read as empty, as String(x || "") does', () {
      expect(cleanTitle(null), '');
      expect(cleanTitle(''), '');
      expect(splitArtistTitle(null), isNull);
      expect(isTopicChannel(null), isFalse);
      expect(channelArtist(null), isNull);
    });
  });

  group("the server's title readers: answers its code gave for harder titles", () {
    for (final (title, cleaned, split, topic, artist) in serverAnswers) {
      test(title, () {
        expect(cleanTitle(title), cleaned);
        final s = splitArtistTitle(cleaned);
        expect(s == null ? null : (s.artist, s.title), split);
        expect(isTopicChannel(title), topic);
        expect(channelArtist(title), artist);
      });
    }

    test("the phone's guess cleans and splits as the server does where it makes no change of its own", () {
      for (final (title, cleaned, split, _, _) in serverAnswers) {
        if (phoneDiffers.contains(title)) continue;
        final g = ytdlGuess(title: title, artist: 'Uploader');
        if (split == null) {
          expect(g.tier, YtdlTier.youtubeArtist, reason: title);
          expect(g.title, cleaned, reason: title);
        } else {
          expect(g.tier, YtdlTier.split, reason: title);
          expect((g.artist, g.title), split, reason: title);
        }
      }
    });
  });

  group('the music tier: the lookup had an album', () {
    test('"One More Time": tags as given, the title cleaned (nothing to clean)', () {
      final g = ytdlGuess(
          title: 'One More Time', artist: 'Daft Punk', album: 'Discovery', year: 2001);
      expect(g.tier, YtdlTier.music);
      expect(g.title, 'One More Time');
      expect(g.artist, 'Daft Punk');
      expect(g.album, 'Discovery');
      expect(g.year, '2001');
      expect(g.fragments, isEmpty);
      expect(g.cleaned, isFalse);
      expect(g.rawTitle, 'One More Time');
      expect(g.youtubeArtistRaw, 'Daft Punk');
      expect(g.youtubeArtist, 'Daft Punk');
      expect(g.artistStrip, isNull);
      expect(g.artistAgrees, isFalse);
      expect(g.titleWith({}), 'One More Time');
      expect(g.artistWith({}), 'Daft Punk');
    });

    test('a music track never splits, and its title is still cleaned', () {
      final g = ytdlGuess(
          title: 'Daft Punk - One More Time (Official Audio)',
          artist: 'Daft Punk',
          album: 'Discovery');
      expect(g.tier, YtdlTier.music);
      expect(g.title, 'Daft Punk - One More Time');
      expect(g.artist, 'Daft Punk');
      expect(g.fragments, [const YtdlFragment('(Official Audio)', noise)]);
    });
  });

  group('the split tier: "Artist - Title" in the video title', () {
    test('"Gorillaz - Feel Good Inc. (Official Video) [HD]" (FoundCleaned)', () {
      final g = ytdlGuess(
          title: 'Gorillaz - Feel Good Inc. (Official Video) [HD]', artist: 'Gorillaz');
      expect(g.tier, YtdlTier.split);
      expect(g.title, 'Feel Good Inc.');
      expect(g.artist, 'Gorillaz');
      expect(g.album, '');
      expect(g.year, '');
      expect(g.artistAgrees, isTrue, reason: 'matches the artist YouTube lists');
      expect(g.cleaned, isTrue);
      expect(g.fragments, [
        const YtdlFragment('-', cut),
        const YtdlFragment('(Official Video)', noise),
        const YtdlFragment('[HD]', noise),
      ]);
    });

    test('"Кино – Группа крови": the en dash splits, the separator is the chip', () {
      final g = ytdlGuess(title: 'Кино – Группа крови', artist: 'Кино');
      expect(g.tier, YtdlTier.split);
      expect(g.artist, 'Кино');
      expect(g.title, 'Группа крови');
      expect(g.fragments, [const YtdlFragment('–', cut)]);
      expect(g.artistAgrees, isTrue);
    });

    test('"matches the artist YouTube lists" ignores case, and needs an artist', () {
      expect(ytdlGuess(title: 'GORILLAZ - Feel Good Inc.', artist: 'gorillaz').artistAgrees,
          isTrue);
      expect(ytdlGuess(title: 'Gorillaz - Feel Good Inc.', artist: 'Some Uploader').artistAgrees,
          isFalse);
      expect(ytdlGuess(title: 'Gorillaz - Feel Good Inc.').artistAgrees, isFalse);
      // YouTube's artist after its strips is what is compared.
      expect(ytdlGuess(title: 'Gorillaz - Feel Good Inc.', artist: 'GorillazVEVO').artistAgrees,
          isTrue);
    });

    test('several artists stay one string', () {
      final g = ytdlGuess(title: 'Daft Punk, Pharrell Williams - Get Lucky', artist: 'Daft Punk');
      expect(g.artist, 'Daft Punk, Pharrell Williams');
      expect(g.title, 'Get Lucky');
      final h = ytdlGuess(title: 'Lily Allen & Giggs - Something\'s Not Right');
      expect(h.artist, 'Lily Allen & Giggs');
    });

    test('a colon splits too, spaced; an unspaced dash does not', () {
      expect(ytdlGuess(title: 'Björk : Army of Me').artist, 'Björk');
      expect(ytdlGuess(title: 'Artist -Song').tier, YtdlTier.youtubeArtist);
    });
  });

  group("the YouTube-artist tier: no album, no split", () {
    test('"Sweater Weather (Official Video)" by "TheNeighbourhoodVEVO" (ChannelGuess)', () {
      final g = ytdlGuess(
          title: 'Sweater Weather (Official Video)', artist: 'TheNeighbourhoodVEVO');
      expect(g.tier, YtdlTier.youtubeArtist);
      expect(g.title, 'Sweater Weather');
      expect(g.artist, 'TheNeighbourhood');
      expect(g.youtubeArtistRaw, 'TheNeighbourhoodVEVO');
      expect(g.youtubeArtist, 'TheNeighbourhood');
      expect(g.artistStrip, 'VEVO');
      expect(g.fragments, [const YtdlFragment('(Official Video)', noise)]);
      expect(g.artistAgrees, isFalse);
    });

    test('"X - Topic" loses " - Topic", any spacing, any case', () {
      for (final raw in ['Daft Punk - Topic', 'Daft Punk-Topic', 'Daft Punk -  topic']) {
        final g = ytdlGuess(title: 'One More Time', artist: raw);
        expect(g.artist, 'Daft Punk', reason: raw);
        expect(g.artistStrip, '- Topic', reason: raw);
      }
    });

    test('a trailing VEVO goes with or without a space before it', () {
      expect(ytdlGuess(title: 'Song', artist: 'Taylor Swift VEVO').artist, 'Taylor Swift');
      expect(ytdlGuess(title: 'Song', artist: 'TaylorSwiftVevo').artist, 'TaylorSwift');
      expect(ytdlGuess(title: 'Song', artist: 'VEVO').artistStrip, isNull,
          reason: 'nothing would be left');
    });

    test('a trailing word "Official" goes; a leading one never does', () {
      final g = ytdlGuess(title: 'Pretender', artist: 'Official髭男dism');
      expect(g.artist, 'Official髭男dism');
      expect(g.artistStrip, isNull);
      final h = ytdlGuess(title: 'Song', artist: 'Daft Punk Official');
      expect(h.artist, 'Daft Punk');
      expect(h.artistStrip, 'Official');
      expect(ytdlGuess(title: 'Song', artist: 'BLACKPINK - Official').artist, 'BLACKPINK');
      expect(ytdlGuess(title: 'Song', artist: 'Unofficial').artistStrip, isNull);
      expect(ytdlGuess(title: 'Song', artist: 'Official').artist, 'Official');
    });

    test('no artist at all is still this tier, with the artist empty', () {
      final g = ytdlGuess(title: 'Sweater Weather (Official Video)');
      expect(g.tier, YtdlTier.youtubeArtist);
      expect(g.artist, '');
      expect(g.youtubeArtistRaw, '');
    });
  });

  group('no lookup', () {
    test('YtdlGuess.none is empty', () {
      const g = YtdlGuess.none;
      expect(g.tier, YtdlTier.none);
      expect([g.rawTitle, g.title, g.artist, g.album, g.year, g.youtubeArtist], everyElement(''));
      expect(g.fragments, isEmpty);
      expect(g.cleaned, isFalse);
      expect(g.titleWith({0}), '');
      expect(g.artistWith({0}), '');
    });

    test('nothing in the answer is the none tier', () {
      expect(ytdlGuess().tier, YtdlTier.none);
      expect(ytdlGuess(title: '  ', artist: '', album: null).tier, YtdlTier.none);
      expect(ytdlGuess(year: 2001).year, '2001');
      expect(ytdlGuess(year: 2001).tier, YtdlTier.none);
    });
  });

  group('the year: four digits or nothing', () {
    test('an int or a string', () {
      expect(ytdlGuess(title: 'x', album: 'A', year: 2001).year, '2001');
      expect(ytdlGuess(title: 'x', album: 'A', year: '2001').year, '2001');
      expect(ytdlGuess(title: 'x', album: 'A', year: ' 2001 ').year, '2001');
    });

    test('anything else is dropped', () {
      for (final y in [null, '', '01', '20011', '2001-03-12', 'MMI', 2001.5, 12, '٢٠٠١']) {
        expect(ytdlGuess(title: 'x', album: 'A', year: y).year, '', reason: '$y');
      }
    });
  });

  group("the phone's own cleaning", () {
    test('a noise group that also says Live keeps "(Live)"; restoring puts the group back', () {
      final g = ytdlGuess(title: 'Sweater Weather (Official Live Video)', artist: 'X');
      expect(g.title, 'Sweater Weather (Live)');
      expect(g.fragments, [const YtdlFragment('(Official Live Video)', noise)]);
      expect(g.titleWith({0}), 'Sweater Weather (Official Live Video)');
    });

    test('Remix, Remaster(ed) and Version keep their words; the noise and its separators go', () {
      expect(ytdlGuess(title: 'Song (Official Remix Video)').title, 'Song (Remix)');
      expect(ytdlGuess(title: 'Song (Remastered 2009 - Official Audio)').title,
          'Song (Remastered 2009)');
      expect(ytdlGuess(title: 'Song [Live at Wembley | Official Music Video]').title,
          'Song [Live at Wembley]');
      expect(ytdlGuess(title: 'Song (Extended Version) (Official Audio)').title,
          'Song (Extended Version)');
      expect(ytdlGuess(title: 'Song (Live - Acoustic Version - Official Video)').title,
          'Song (Live - Acoustic Version)');
      expect(ytdlGuess(title: 'Song [4K Remastered]').title, 'Song [Remastered]');
    });

    test('a group left with only "Version" goes whole, as the server drops it', () {
      final g = ytdlGuess(title: 'Song (Clean Version)');
      expect(g.title, 'Song');
      expect(g.fragments, [const YtdlFragment('(Clean Version)', noise)]);
    });

    test('a group with no noise word stays', () {
      expect(ytdlGuess(title: 'Song [Live]').title, 'Song [Live]');
      expect(ytdlGuess(title: 'Song [2011 Remaster]').title, 'Song [2011 Remaster]');
      expect(ytdlGuess(title: 'Song [2011 Remaster]').fragments, isEmpty);
      expect(ytdlGuess(title: 'Song (Radio Edit)').title, 'Song (Radio Edit)');
    });

    test('【…】 groups follow the bracket rule, and MV is noise', () {
      final g = ytdlGuess(title: '【MV】米津玄師 - Lemon', artist: '米津玄師');
      expect(g.tier, YtdlTier.split);
      expect(g.artist, '米津玄師');
      expect(g.title, 'Lemon');
      expect(g.fragments, [const YtdlFragment('【MV】', noise), const YtdlFragment('-', cut)]);
      expect(ytdlGuess(title: 'Lemon【公式MV】').title, 'Lemon');
      expect(ytdlGuess(title: 'Lemon【初音ミク】').title, 'Lemon【初音ミク】');
      expect(ytdlGuess(title: 'Song (MV)').title, 'Song');
      expect(ytdlGuess(title: 'Song [M/V]').title, 'Song');
      expect(ytdlGuess(title: 'Song - Official MV').title, 'Song');
      expect(ytdlGuess(title: 'Mvula (Live)').title, 'Mvula (Live)', reason: 'MV is a word');
    });

    test('a trailing "feat." / "ft." / "featuring" credit becomes "(feat. X)"', () {
      expect(ytdlGuess(title: 'Get Lucky feat. Pharrell Williams').title,
          'Get Lucky (feat. Pharrell Williams)');
      expect(ytdlGuess(title: 'Get Lucky ft. Pharrell Williams').title,
          'Get Lucky (feat. Pharrell Williams)');
      expect(ytdlGuess(title: 'Get Lucky Featuring Pharrell Williams, Nile Rodgers').title,
          'Get Lucky (feat. Pharrell Williams, Nile Rodgers)');
      expect(ytdlGuess(title: 'Get Lucky feat Pharrell').title, 'Get Lucky (feat. Pharrell)');
      // After the split: the credit at the end of the title half.
      final g = ytdlGuess(
          title: 'Daft Punk - Get Lucky ft. Pharrell Williams (Official Audio)',
          artist: 'Daft Punk');
      expect(g.artist, 'Daft Punk');
      expect(g.title, 'Get Lucky (feat. Pharrell Williams)');
    });

    test('a credit in brackets, not at the end, or on the artist side is left alone', () {
      expect(ytdlGuess(title: 'Get Lucky (feat. Pharrell)').title, 'Get Lucky (feat. Pharrell)');
      expect(ytdlGuess(title: 'Get Lucky feat. Pharrell (Radio Edit)').title,
          'Get Lucky feat. Pharrell (Radio Edit)');
      final g = ytdlGuess(title: 'Daft Punk ft. Pharrell - Get Lucky');
      expect(g.artist, 'Daft Punk ft. Pharrell');
      expect(g.title, 'Get Lucky');
      expect(ytdlGuess(title: '6 ft under').title, '6 ft under', reason: '"ft" needs its dot');
      expect(ytdlGuess(title: 'Feat. Nobody').title, 'Feat. Nobody');
    });
  });

  group('putting fragments back', () {
    final gorillaz = ytdlGuess(
        title: 'Gorillaz - Feel Good Inc. (Official Video) [HD]', artist: 'Gorillaz');

    test('each chip puts its own piece back in place', () {
      expect(gorillaz.titleWith({1}), 'Feel Good Inc. (Official Video)');
      expect(gorillaz.titleWith({2}), 'Feel Good Inc. [HD]');
      expect(gorillaz.titleWith({1, 2}), 'Feel Good Inc. (Official Video) [HD]');
    });

    test('undoing the split puts the artist back in the title and YouTube\'s artist in the field', () {
      expect(gorillaz.titleWith({0}), 'Gorillaz - Feel Good Inc.');
      expect(gorillaz.artistWith({0}), 'Gorillaz');
      expect(gorillaz.artistWith({}), 'Gorillaz');
      final g = ytdlGuess(title: 'Кино – Группа крови', artist: 'Kino Official');
      expect(g.artistWith({}), 'Кино');
      expect(g.artistWith({0}), 'Kino', reason: "YouTube's artist, stripped");
      expect(g.titleWith({0}), 'Кино – Группа крови');
    });

    test('Undo all is the video\'s own title', () {
      expect(gorillaz.titleWith(all(gorillaz)), 'Gorillaz - Feel Good Inc. (Official Video) [HD]');
      final feat = ytdlGuess(title: 'Daft Punk - Get Lucky ft. Pharrell', artist: 'Daft Punk');
      expect(feat.title, 'Get Lucky (feat. Pharrell)');
      expect(feat.titleWith(all(feat)), 'Daft Punk - Get Lucky ft. Pharrell');
    });

    test('a fragment on the artist side goes back into the artist', () {
      final g = ytdlGuess(title: '【MV】米津玄師 - Lemon', artist: '米津玄師');
      expect(g.artistWith({0}), '【MV】米津玄師');
      expect(g.titleWith({0}), 'Lemon');
      expect(g.titleWith({1}), '米津玄師 - Lemon');
    });

    test('a trailing "- Official Video" is one fragment, even around a removed group', () {
      final g = ytdlGuess(title: 'Song - Official Video (HD)');
      expect(g.title, 'Song');
      expect(g.fragments, [
        const YtdlFragment('- Official Video', noise),
        const YtdlFragment('(HD)', noise),
      ]);
      expect(g.titleWith({0}), 'Song - Official Video');
      expect(g.titleWith({1}), 'Song (HD)');
      final h = ytdlGuess(title: 'Song - (HD) Official Video');
      expect(h.title, 'Song');
      expect(h.titleWith({1}), 'Song (HD)');
      expect(h.titleWith(all(h)), 'Song - (HD) Official Video');
    });

    test('indexes that are not fragments change nothing', () {
      expect(gorillaz.titleWith({7}), 'Feel Good Inc.');
      expect(ytdlGuess(title: 'One More Time', album: 'Discovery').titleWith({0}),
          'One More Time');
    });

    test('outside the split tier the artist does not move', () {
      final g = ytdlGuess(title: 'Sweater Weather (Official Video)', artist: 'TheNeighbourhoodVEVO');
      expect(g.artistWith({0}), 'TheNeighbourhood');
    });
  });
}
