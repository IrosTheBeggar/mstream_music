// The Discover page's formatters (screens/discovery/discovery_widgets.dart):
// the "last played 8 months ago" scale, the album play facts, and the
// app-bar subtitle per seed source (plan §2.1–§2.2, §2.8).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/screens/discovery/discovery_widgets.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 10, 5, 12);

  group('discoveryAgo: calendar days, then months, then years', () {
    test('today and yesterday by the calendar, not by 24 h', () {
      expect(discoveryAgo(l, DateTime(2026, 10, 5, 0, 5), now), 'today');
      expect(discoveryAgo(l, DateTime(2026, 10, 4, 23, 50), now), 'yesterday');
      expect(discoveryAgo(l, DateTime(2026, 10, 4, 1), now), 'yesterday');
    });

    test('days under a month, months under a year, then years', () {
      expect(discoveryAgo(l, DateTime(2026, 10, 1), now), '4 days ago');
      expect(discoveryAgo(l, DateTime(2026, 9, 6), now), '29 days ago');
      expect(discoveryAgo(l, DateTime(2026, 9, 5), now), '1 month ago');
      expect(discoveryAgo(l, DateTime(2026, 2, 1), now), '8 months ago');
      expect(discoveryAgo(l, DateTime(2025, 10, 4), now), '1 year ago');
      // 30-day months reach 12 at day 360, before a year has passed.
      expect(discoveryAgo(l, DateTime(2025, 10, 10), now), '1 year ago',
          reason: '360 days, not "12 months ago"');
      expect(discoveryAgo(l, DateTime(2025, 10, 8), now), '1 year ago',
          reason: '362 days');
      expect(discoveryAgo(l, DateTime(2025, 10, 11), now), '11 months ago',
          reason: '359 days');
      expect(discoveryAgo(l, DateTime(2023, 1, 1), now), '3 years ago');
    });

    test('a timestamp from the future (clock skew) reads as today', () {
      expect(discoveryAgo(l, DateTime(2026, 10, 6), now), 'today');
    });
  });

  group('discoveryPlayLabel', () {
    TasteTrack t({int? plays, DateTime? last}) =>
        TasteTrack('music/a.mp3', 0.8, null, const [],
            playCount: plays, lastPlayed: last);

    test('never played is a claim the server made', () {
      expect(discoveryPlayLabel(l, t(plays: 0), now), 'never played');
      expect(discoveryPlayLabel(l, t(), now), isNull,
          reason: 'the server did not say');
    });

    test('a played row says when', () {
      expect(
          discoveryPlayLabel(l, t(plays: 3, last: DateTime(2026, 2, 1)), now),
          'last played 8 months ago');
    });
  });

  group('discoveryAlbumLabel', () {
    test('unplayed, partly played, or just the song count', () {
      expect(discoveryAlbumLabel(l, TasteAlbum('A', playedTracks: 0)),
          'never played');
      expect(
          discoveryAlbumLabel(
              l, TasteAlbum('A', playedTracks: 2, scopedTracks: 12)),
          '2 of 12 played');
      expect(discoveryAlbumLabel(l, TasteAlbum('A', trackCount: 11)),
          '11 songs');
      expect(discoveryAlbumLabel(l, TasteAlbum('A')), isNull);
    });
  });

  group('discoverySubtitle', () {
    TasteSeed seed(String h, {String? outcome = 'completed', bool pinned = false}) =>
        TasteSeed(h, 'music/$h.mp3', null, outcome: outcome, pinned: pinned);

    test('history: finished vs listened to — no window (the bar owns it)',
        () {
      expect(
          discoverySubtitle(
              l,
              TasteResponse(
                  window: 30,
                  seedSource: TasteSeedSource.history,
                  seeds: [seed('a'), seed('b')])),
          'based on 2 songs you finished');
      expect(
          discoverySubtitle(
              l,
              TasteResponse(
                  window: 0,
                  seedSource: TasteSeedSource.history,
                  seeds: [seed('a'), seed('b', outcome: 'stopped')])),
          'based on 2 songs you listened to');
    });

    test('a pin alongside history is not counted as history', () {
      expect(
          discoverySubtitle(
              l,
              TasteResponse(
                  window: 7,
                  seedSource: TasteSeedSource.history,
                  seeds: [seed('p', outcome: null, pinned: true), seed('a')])),
          'based on 1 song you finished');
    });

    test('counters, pins only, and the random fallback', () {
      expect(
          discoverySubtitle(
              l,
              TasteResponse(
                  seedSource: TasteSeedSource.counters, seeds: [seed('a')])),
          'based on the songs you play most');
      expect(
          discoverySubtitle(
              l,
              TasteResponse(
                  seedSource: TasteSeedSource.pinned,
                  seeds: [seed('p', pinned: true)])),
          'based on songs you picked');
      expect(
          discoverySubtitle(
              l,
              TasteResponse(
                  seedSource: TasteSeedSource.random,
                  fallback: true,
                  seeds: [seed('r', outcome: null)])),
          'nothing finished yet · a random pick instead');
      expect(discoverySubtitle(l, null), isNull);
    });
  });

  group('discoveryWidenedNote', () {
    TasteSeed seed(String h) =>
        TasteSeed(h, 'music/$h.mp3', null, outcome: 'completed');

    test('names the window asked for when the server reached further back',
        () {
      expect(
          discoveryWidenedNote(
              l,
              TasteResponse(
                  window: 0,
                  widenedFrom: 30,
                  seedSource: TasteSeedSource.history,
                  seeds: [seed('a')])),
          'Nothing in the last 30 days, so these come from further back.');
    });

    test('none when not widened, or for a random pick', () {
      expect(
          discoveryWidenedNote(
              l,
              TasteResponse(
                  window: 30,
                  seedSource: TasteSeedSource.history,
                  seeds: [seed('a')])),
          isNull);
      expect(
          discoveryWidenedNote(
              l,
              TasteResponse(
                  window: 0,
                  widenedFrom: 30,
                  seedSource: TasteSeedSource.random,
                  fallback: true,
                  seeds: [seed('r')])),
          isNull);
      expect(discoveryWidenedNote(l, null), isNull);
    });
  });

  test('every locale renders the new counts with the number', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final t = lookupAppLocalizations(locale);
      for (final f in <String Function(int)>[
        t.discoverPageWindowDays,
        t.discoverPageAgoMonths,
        t.discoverPageAgoYears,
        t.discoverPageSongsCount,
        t.discoverPageAlbumsCount,
        t.discoverPageServersSearched,
        t.discoverPageUseThese,
        t.discoverPageSubFinished,
        t.discoverPageSubListened,
      ]) {
        expect(f(21), contains('21'), reason: '$locale ${f(21)}');
        expect(f(0), contains('0'), reason: '$locale ${f(0)}');
      }
    }
  });
}
