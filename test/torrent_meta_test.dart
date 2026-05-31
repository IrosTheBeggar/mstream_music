import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/torrent_meta.dart';

void main() {
  group('parseMusicTorrentName', () {
    test('Artist - Album (1973)', () {
      final m = parseMusicTorrentName(
          'Pink Floyd - The Dark Side of the Moon (1973)');
      expect(m.artist, 'Pink Floyd');
      expect(m.album, 'The Dark Side of the Moon');
      expect(m.year, '1973');
      expect(m.confidence, 'high');
    });

    test('Artist - Album [2020]', () {
      final m = parseMusicTorrentName('Tame Impala - The Slow Rush [2020]');
      expect(m.artist, 'Tame Impala');
      expect(m.album, 'The Slow Rush');
      expect(m.year, '2020');
      expect(m.confidence, 'high');
    });

    test('Artist - YEAR - Album', () {
      final m = parseMusicTorrentName('Miles Davis - 1959 - Kind of Blue');
      expect(m.artist, 'Miles Davis');
      expect(m.album, 'Kind of Blue');
      expect(m.year, '1959');
      expect(m.confidence, 'high');
    });

    test('Artist - Album - YEAR', () {
      final m = parseMusicTorrentName('Radiohead - In Rainbows - 2007');
      expect(m.artist, 'Radiohead');
      expect(m.album, 'In Rainbows');
      expect(m.year, '2007');
      expect(m.confidence, 'high');
    });

    test('dot-separated', () {
      final m = parseMusicTorrentName('Radiohead.OK.Computer.1997');
      expect(m.artist, 'Radiohead');
      expect(m.album, 'OK Computer');
      expect(m.year, '1997');
      expect(m.confidence, 'high');
    });

    test('strips quality tags before parsing', () {
      final m =
          parseMusicTorrentName('Daft Punk - Discovery (2001) [FLAC] [24bit]');
      expect(m.artist, 'Daft Punk');
      expect(m.album, 'Discovery');
      expect(m.year, '2001');
      expect(m.confidence, 'high');
    });

    test('bare "Artist - Album" is low confidence', () {
      final m = parseMusicTorrentName('Some Artist - Some Album');
      expect(m.artist, 'Some Artist');
      expect(m.album, 'Some Album');
      expect(m.year, '');
      expect(m.confidence, 'low');
    });

    test('unparseable falls back to album/none', () {
      final m = parseMusicTorrentName('JustABareName');
      expect(m.artist, '');
      expect(m.album, 'JustABareName');
      expect(m.confidence, 'none');
    });

    test('empty input', () {
      expect(parseMusicTorrentName('').confidence, 'none');
    });

    test('hyphenated artist not split on its own dash', () {
      final m = parseMusicTorrentName('Jay-Z - The Blueprint (2001)');
      expect(m.artist, 'Jay-Z');
      expect(m.album, 'The Blueprint');
      expect(m.year, '2001');
      expect(m.confidence, 'high');
    });

    test('hyphenated artist AC-DC', () {
      final m = parseMusicTorrentName('AC-DC - Back in Black (1980)');
      expect(m.artist, 'AC-DC');
      expect(m.album, 'Back in Black');
      expect(m.year, '1980');
      expect(m.confidence, 'high');
    });

    test('strips bare trailing tags + trailing space-separated year', () {
      final m = parseMusicTorrentName('Boards of Canada - Geogaddi 2002 FLAC');
      expect(m.artist, 'Boards of Canada');
      expect(m.album, 'Geogaddi');
      expect(m.year, '2002');
      expect(m.confidence, 'high');
    });

    test('strips a bare trailing tag with no year', () {
      final m = parseMusicTorrentName('Some Band - Some Album FLAC');
      expect(m.artist, 'Some Band');
      expect(m.album, 'Some Album');
      expect(m.year, '');
      expect(m.confidence, 'low');
    });
  });

  group('sanitizeTorrentSegment', () {
    test('replaces path separators', () {
      expect(sanitizeTorrentSegment('AC/DC'), 'AC-DC');
    });
    test('strips leading/trailing dots + whitespace', () {
      expect(sanitizeTorrentSegment('  ..Album..  '), 'Album');
    });
    test('null -> empty', () {
      expect(sanitizeTorrentSegment(null), '');
    });
    test('traversal dots collapse to empty', () {
      expect(sanitizeTorrentSegment('..'), '');
      expect(sanitizeTorrentSegment('...'), '');
    });
  });

  group('template resolution', () {
    const meta = TorrentMeta('Pink Floyd', 'Animals', '1977', 'high');

    test('{{ARTIST}}/{{ALBUM}}', () {
      expect(resolveTorrentTemplate('{{ARTIST}}/{{ALBUM}}', meta),
          'Pink Floyd/Animals');
    });
    test('template with year', () {
      expect(resolveTorrentTemplate('{{ARTIST}}/{{YEAR}} - {{ALBUM}}', meta),
          'Pink Floyd/1977 - Animals');
    });
    test('sanitizes substituted values', () {
      expect(
          resolveTorrentTemplate('{{ARTIST}}/{{ALBUM}}',
              const TorrentMeta('AC/DC', 'Back in Black', '1980', 'high')),
          'AC-DC/Back in Black');
    });
    test('computeTorrentPath legacy fallback (no template)', () {
      expect(computeTorrentPath(null, meta), 'Pink Floyd/Animals');
    });
    test('computeTorrentPath legacy with album only', () {
      expect(
          computeTorrentPath(
              null, const TorrentMeta('', 'Solo Album', '', 'none')),
          'Solo Album');
    });
    test('traversal metadata sanitizes to empty path', () {
      expect(
          resolveTorrentTemplate('{{ARTIST}}/{{ALBUM}}',
              const TorrentMeta('..', '..', '', 'high')),
          '');
    });
    test('drops dangling separator from a partially-empty template', () {
      expect(
          resolveTorrentTemplate('{{ARTIST}} - {{ALBUM}}',
              const TorrentMeta('Artist', '', '', 'high')),
          'Artist');
    });
    test('all-empty template segment is dropped, not kept as "-"', () {
      expect(
          resolveTorrentTemplate('{{ARTIST}} - {{ALBUM}}',
              const TorrentMeta('', '', '', 'none')),
          '');
    });
  });

  group('splitTorrentPath', () {
    test('artist/album', () {
      final s = splitTorrentPath('Pink Floyd/Animals');
      expect(s.subPath, 'Pink Floyd');
      expect(s.directoryName, 'Animals');
    });
    test('single segment', () {
      final s = splitTorrentPath('Album');
      expect(s.subPath, '');
      expect(s.directoryName, 'Album');
    });
    test('nested', () {
      final s = splitTorrentPath('A/B/C');
      expect(s.subPath, 'A/B');
      expect(s.directoryName, 'C');
    });
    test('drops .. segments (no traversal)', () {
      final s = splitTorrentPath('a/../b');
      expect(s.subPath, 'a');
      expect(s.directoryName, 'b');
    });
    test('bare .. collapses to empty', () {
      final s = splitTorrentPath('..');
      expect(s.subPath, '');
      expect(s.directoryName, '');
    });
    test('backslash separators split, .. dropped', () {
      final s = splitTorrentPath(r'..\..\secret');
      expect(s.subPath, '');
      expect(s.directoryName, 'secret');
    });
    test('absolute path neutralized to relative', () {
      final s = splitTorrentPath('/etc/passwd');
      expect(s.subPath, 'etc');
      expect(s.directoryName, 'passwd');
    });
  });

  group('extractTorrentName', () {
    test('reads the info-dict name', () {
      expect(extractTorrentName(utf8.encode('d4:infod4:name8:My Albumee')),
          'My Album');
    });
    test('no name in info dict -> empty', () {
      expect(extractTorrentName(utf8.encode('d4:infod6:lengthi42eee')), '');
    });
    test('no info dict -> empty', () {
      expect(extractTorrentName(utf8.encode('not a torrent at all')), '');
    });
    test('oversized length guard -> empty', () {
      expect(extractTorrentName(utf8.encode('d4:infod4:name9999:x')), '');
    });
    test('truncated buffer -> empty', () {
      expect(extractTorrentName(utf8.encode('d4:infod4:name50:short')), '');
    });
  });
}
