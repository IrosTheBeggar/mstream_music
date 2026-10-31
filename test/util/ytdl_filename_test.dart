// lib/util/ytdl_filename.dart — the file name the server's yt-dlp gives a
// YouTube download (`-o '%(title)s.%(ext)s' --restrict-filenames`),
// predicted on the phone for "about One_More_Time.mp3" and the name check.
//
// Three tables pin the port of sanitize_filename(restricted=True):
//  - [fixtures]: every name the real yt-dlp 2026.08.19 produced for the
//    build's fixture titles (copied, not read from disk);
//  - [oracle]: more titles run through the same real yt-dlp for this port
//    (combining marks and NFD input, Arabic harakat, Devanagari, Hangul,
//    NBSP, zero-width joiner, variation selectors, the NFKC forms);
//  - [derived]: cases taken from the algorithm (yt-dlp's code with Python's
//    NFKC) and not run through yt-dlp itself.
// Then the extension map, the drop-letters flag and the middle ellipsis.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/ytdl_filename.dart';

const fixtures = <(String, String)>[
  ('One More Time', 'One_More_Time'),
  ('Gorillaz - Feel Good Inc. (Official Video) [HD]', 'Gorillaz_-_Feel_Good_Inc._Official_Video_HD'),
  ('Кино – Группа крови', '_'),
  ('Sweater Weather (Official Video)', 'Sweater_Weather_Official_Video'),
  ('Daft Punk - Around the World (Official Audio)', 'Daft_Punk_-_Around_the_World_Official_Audio'),
  ('Beyoncé - Déjà Vu', 'Beyonce_-_Deja_Vu'),
  ('Mötley Crüe – Kickstart My Heart', 'Motley_Crue_Kickstart_My_Heart'),
  ('Björk: Army of Me', 'Bjork_-_Army_of_Me'),
  ('Live at 12:34:56 - full set', 'Live_at_12_34_56_-_full_set'),
  ('Track 1:23', 'Track_1_23'),
  ('-Leading dash', '-Leading_dash'),
  ('--Double leading', '--Double_leading'),
  ('Foo - _Bar', 'Foo_-__Bar'),
  ('  spaced  out  ', 'spaced_out'),
  ('AC/DC - Back In Black', 'AC_DC_-_Back_In_Black'),
  ('What?! Why?', 'What_Why'),
  ('"Quoted" title', 'Quoted_title'),
  ('A|B*C<D>E', 'A_B_C_D_E'),
  ('Ｆｕｌｌｗｉｄｔｈ ＡＢＣ', 'Fullwidth_ABC'),
  ('ﬁligree ligature', 'filigree_ligature'),
  ('Æon Flux Œuvre ß', 'AEon_Flux_OEuvre_ss'),
  ('Sigur Rós – Hoppípolla', 'Sigur_Ros_Hoppipolla'),
  ('米津玄師 - Lemon', 'Lemon'),
  ('Lemon / 米津玄師', 'Lemon'),
  ('official髭男dism - Pretender', 'official_dism_-_Pretender'),
  ('Ελληνικά - τραγούδι', '_'),
  ('Rock & Roll (feat. Someone) [2011 Remaster]', 'Rock_Roll_feat._Someone_2011_Remaster'),
  ('..dots.at.start', '..dots.at.start'),
  ('_underscores_', '_underscores_'),
  ('100% Pure #1 \$hit {x} `y` ^z ;w ,v', '100%_Pure_1_hit_x_y_z_w_v'),
  ('Tab\u{9}here', 'Tabhere'),
  ('emoji \u{1F3B5} song', 'emoji_song'),
  ('Café del Mar – Energy 52', 'Cafe_del_Mar_Energy_52'),
  ('Naïve façade', 'Naive_facade'),
  ('Ø Ð Þ ð þ', 'O_D_TH_o_th'),
  ('İstanbul ı', 'stanbul'),
  ('a  -  b', 'a_-_b'),
  ('x — y – z', 'x_y_z'),
  ('Ñandú', 'Nandu'),
  ('Über Ärger Öl', 'Uber_Arger_Ol'),
  ('مرحبا - عمرو دياب', '_'),
  ('שלום - שיר', '_'),
  ('Song (Lyrics) | Artist', 'Song_Lyrics_Artist'),
  ('Hello: World: Again', 'Hello_-_World_-_Again'),
  ('2:00 AM', '2_00_AM'),
];

const oracle = <(String, String)>[
  ('Cafe\u{301} au lait', 'Cafe_au_lait'),
  ('Ma\u{304}ori', 'M_ori'),
  ('Vie\u{323}\u{302}t Nam', 'Vi_t_Nam'),
  ('Viê\u{323}t', 'Vi_t'),
  ('م\u{64E}ر\u{652}ح\u{64E}ب\u{64B}ا Hi', 'Hi'),
  ('A\u{64E}B', 'AB'),
  ('नमस\u{94D}त\u{947} Namaste', 'Namaste'),
  ('안녕 Hello \u{1100}\u{1161}', 'Hello'),
  ('No\u{A0}Break', 'No_Break'),
  ('Zero\u{200D}Width', 'ZeroWidth'),
  ('Heart \u{2764}\u{FE0F} Song', 'Heart_Song'),
  ('\u{2764}\u{FE0F}', '_'),
  ('Wait… What', 'Wait..._What'),
  ('Brand\u{2122} Song', 'BrandTM_Song'),
  ('𝐁𝐨𝐥𝐝 Text', 'Bold_Text'),
  ('Final Fantasy Ⅶ', 'Final_Fantasy_VII'),
  ('① First', '1_First'),
  ('１２\u{FF1A}３４ Ｌｉｖｅ', '12_34_Live'),
  ('x² + y²', 'x2_+_y2'),
  ('½ Price', '1_2_Price'),
  ('สว\u{E31}สด\u{E35} Thai', 'Thai'),
  ('A\u{FE0F}B ℹ\u{FE0F} Info', 'AB_i_Info'),
  ('\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} Family', 'Family'),
  ('Ae\u{303}\u{301} Pho\u{31B}\u{309} o\u{302}\u{301}', 'A_Ph'),
];

const derived = <(String, String)>[
  ('Absolute \u{212A} zero', 'Absolute_K_zero'), // Kelvin sign
  ('\u{212B}ngström', 'Angstrom'), // Ångström sign
  ('\u{24C2}usic ①②③', 'Music_123'),
  ('⑴ ⒈ \u{249C}', '1_1._a'),
  ('xa\u{336}\u{304}y', 'x_y'), // an overlay mark does not block the macron
  ('aſ\u{307}b', 'a_b'), // long s + dot above is ṡ under NFKC
  ('a\u{D800}b', 'ab'), // a lone surrogate is category C
  ('a\u{1D455}b', 'ab'), // a hole in the math letters is unassigned
  ('𝟎𝟘 𝔸', '00_A'),
  ('\u{1F130}\u{1F131} \u{1F110}', 'AB_A'),
  ('No. \u{2116} 1 \u{2122} \u{2120}', 'No._No_1_TM_SM'),
  ('Room 10½', 'Room_101_2'),
  ('ﬀﬃﬄﬅ', 'ffffifflst'),
  ('Na\u{308}\u{304}ive', 'N_ive'), // ä + macron is ǟ
  ('Song ~ 100% @ home = +1', 'Song_~_100%_@_home_=_+1'),
  ('trailing -_ :', 'trailing'),
  (': leading colon', 'leading_colon'),
  ('Ellipsis…', 'Ellipsis...'),
  ('Ｓｏｎｇ\u{FF08}Ｌｉｖｅ\u{FF09}', 'Song_Live'),
  ('Vertical\u{FE19} forms\u{FE30}', 'Vertical..._forms..'),
  ('Ĳsselmeer ǅ', 'IJsselmeer_D'),
  ('ᵀᴴᴱ small caps', 'THE_small_caps'),
  ('H₂O x²', 'H2O_x2'),
];

void main() {
  group('ytdlpRestrictedName matches the real yt-dlp', () {
    for (final (title, stem) in fixtures) {
      test('fixture: $title', () => expect(ytdlpRestrictedName(title), stem));
    }
    for (final (title, stem) in oracle) {
      test('extra: $title', () => expect(ytdlpRestrictedName(title), stem));
    }
  });

  group('ytdlpRestrictedName: cases derived from the algorithm', () {
    for (final (title, stem) in derived) {
      test(title, () => expect(ytdlpRestrictedName(title), stem));
    }

    test('nothing left is "_"; nothing to start with is nothing', () {
      expect(ytdlpRestrictedName(''), '');
      expect(ytdlpRestrictedName('???'), '_');
      expect(ytdlpRestrictedName('   '), '_');
    });

    test('a timestamp keeps its digits apart; any other colon reads as "_-"', () {
      expect(ytdlpRestrictedName('1:2:3'), '1_2_3');
      expect(ytdlpRestrictedName('Ratio 16:9 and A:B'), 'Ratio_16_9_and_A_-B');
    });
  });

  group('ytdlOutputExtension and ytdlPredictedFileName', () {
    test('aac and m4b land as .m4a; the rest name their own extension', () {
      expect(ytdlOutputExtension('aac'), 'm4a');
      expect(ytdlOutputExtension('m4b'), 'm4a');
      for (final codec in ['mp3', 'm4a', 'opus', 'ogg', 'flac', 'wav']) {
        expect(ytdlOutputExtension(codec), codec);
      }
    });

    test('the raw title, restricted, with the extension', () {
      expect(ytdlPredictedFileName('One More Time', 'mp3'), 'One_More_Time.mp3');
      expect(ytdlPredictedFileName('Кино – Группа крови', 'mp3'), '_.mp3');
      expect(ytdlPredictedFileName('Gorillaz - Feel Good Inc. (Official Video) [HD]', 'aac'),
          'Gorillaz_-_Feel_Good_Inc._Official_Video_HD.m4a');
      expect(ytdlPredictedFileName('Sweater Weather (Official Video)', 'opus'),
          'Sweater_Weather_Official_Video.opus');
    });
  });

  group('ytdlNameDropsLetters', () {
    test('letters outside A–Z that are not transliterated are dropped', () {
      for (final title in [
        'Кино – Группа крови',
        '米津玄師 - Lemon',
        'official髭男dism - Pretender',
        'İstanbul',
        'Māori',
        'Ma\u{304}ori', // composes to ā first
        'Viê\u{323}t',
        '안녕 Hello',
        'Ελληνικά',
      ]) {
        expect(ytdlNameDropsLetters(title), isTrue, reason: title);
      }
    });

    test('ASCII, transliterated letters and NFKC letters drop nothing', () {
      for (final title in [
        'One More Time',
        'Beyoncé - Déjà Vu',
        'Cafe\u{301} au lait',
        'Ø Ð Þ ð þ ß Æ Œ',
        'ﬁligree',
        '𝐁𝐨𝐥𝐝 Text',
        'Ｆｕｌｌｗｉｄｔｈ',
        'Nº ª',
        'Heart \u{2764}\u{FE0F} \u{1F3B5}',
        '12:34 — ½ ™',
        '',
      ]) {
        expect(ytdlNameDropsLetters(title), isFalse, reason: title);
      }
    });
  });

  group('ytdlMiddleEllipsis', () {
    const gorillaz = 'Gorillaz_-_Feel_Good_Inc._Official_Video_HD.mp3';

    test('the FoundCleaned name: start, ellipsis, eight characters and the extension', () {
      expect(ytdlMiddleEllipsis(gorillaz, 33), 'Gorillaz_-_Feel_Good…Video_HD.mp3');
    });

    test('a name that fits is unchanged', () {
      expect(ytdlMiddleEllipsis(gorillaz, gorillaz.length), gorillaz);
      expect(ytdlMiddleEllipsis(gorillaz, 100), gorillaz);
      expect(ytdlMiddleEllipsis('_.mp3', 5), '_.mp3');
    });

    test('a short limit still shows how the name starts and keeps the extension', () {
      for (var max = 8; max < gorillaz.length; max++) {
        final cut = ytdlMiddleEllipsis(gorillaz, max);
        expect(cut.length, max, reason: '$max');
        expect(cut.endsWith('.mp3'), isTrue, reason: cut);
        expect(cut.contains('…'), isTrue, reason: cut);
        expect(cut.startsWith('G'), isTrue, reason: cut);
      }
      expect(ytdlMiddleEllipsis(gorillaz, 15), 'Gorilla…_HD.mp3');
    });

    test('limits smaller than the extension keep what fits of the end', () {
      expect(ytdlMiddleEllipsis(gorillaz, 3), '…p3');
      expect(ytdlMiddleEllipsis(gorillaz, 1), '…');
      expect(ytdlMiddleEllipsis(gorillaz, 0), '');
    });

    test('no extension: a dot far back is part of the name', () {
      expect(ytdlMiddleEllipsis('abcdefghijklmnopqrstuvwxyz', 10), 'abcde…wxyz');
      expect(ytdlMiddleEllipsis('Mr.Brightside_The_Killers_Official', 12), 'Mr.Bri…icial');
    });

    test('counts code points, never splitting an emoji', () {
      final cut = ytdlMiddleEllipsis('\u{1F3B5}' * 12, 7);
      expect(cut.runes.length, 7);
      expect(cut, '\u{1F3B5}\u{1F3B5}\u{1F3B5}…\u{1F3B5}\u{1F3B5}\u{1F3B5}');
    });
  });
}
