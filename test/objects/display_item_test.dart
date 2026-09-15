import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';

void main() {
  group('DisplayItem album facts', () {
    test('an album item carries no year or album artist until a list sets them',
        () {
      final item = DisplayItem(null, 'Solo', 'album', 'Solo', null, null);
      expect(item.albumArtist, isNull);
      expect(item.year, isNull);
      item.albumArtist = 'Ann';
      item.year = 2001;
      expect(item.albumArtist, 'Ann');
      expect(item.year, 2001);
    });
  });

  group('DisplayItem artist line', () {
    DisplayItem track(MusicMetadata m) {
      final item = DisplayItem(null, 'x', 'file', '/x.mp3', null, null);
      item.metadata = m;
      return item;
    }

    test('shows the ARTIST tag as written when the server sends it', () {
      final item = track(MusicMetadata.fromServerMap({
        'artist': 'Ann',
        'artist-display': 'Ann feat. Bob',
        'title': 'Together',
        'hash': 'h',
      }));
      expect((item.getSubText() as Text).data, 'Ann feat. Bob');
    });

    test('falls back to the primary artist on an older server', () {
      final item =
          track(MusicMetadata.fromServerMap({'artist': 'Ann', 'hash': 'h'}));
      expect((item.getSubText() as Text).data, 'Ann');
    });

    test('an explicit subtext still wins (search rows keep their context)', () {
      final item = DisplayItem(null, 'x', 'file', '/x.mp3', null, 'a lyric line');
      item.metadata = MusicMetadata.fromServerMap(
          {'artist': 'Ann', 'artist-display': 'Ann feat. Bob', 'hash': 'h'});
      expect((item.getSubText() as Text).data, 'a lyric line');
    });

    test('the local filter matches the display string too', () {
      final item = track(MusicMetadata.fromServerMap({
        'artist': 'Ann',
        'artist-display': 'Ann feat. Bob',
        'title': 'Together',
        'hash': 'h',
      }));
      expect(item.matchesQuery('bob'), isTrue);
      expect(item.matchesQuery('carl'), isFalse);
    });
  });
}
