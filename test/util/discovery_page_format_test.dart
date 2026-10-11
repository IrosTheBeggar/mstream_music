// Discover's formatters (screens/discovery/discovery_widgets.dart and the
// controller's row builders): the seeds sheet's "finished 8 months ago"
// scale, the window label, the listing's section headers and the song
// rows' "Artist · Album" line — none of which carries a count or a
// percentage (plan §2.13, the play-now page).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/screens/discovery/discovery_listing.dart';
import 'package:mstream_music/screens/discovery/discovery_page_controller.dart';
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

  test('the window label: days, or All time', () {
    expect(discoveryWindowLabel(l, 30), '30 days');
    expect(discoveryWindowLabel(l, 1), '1 day');
    expect(discoveryWindowLabel(l, 0), 'All time');
  });

  group('discoverySectionLabel', () {
    DisplayItem header(DiscoverySection s, {String? name}) =>
        DisplayItem(null, 'fallback', 'section', s.name, null, name);

    test('the library and the connected servers, by who answered', () {
      expect(discoverySectionLabel(l, header(DiscoverySection.albumsLibrary)),
          'Albums from your library');
      expect(discoverySectionLabel(l, header(DiscoverySection.songsLibrary)),
          'Songs from your library');
      expect(
          discoverySectionLabel(
              l, header(DiscoverySection.albumsPeers, name: "Sam's server")),
          "Albums from Sam's server");
      expect(
          discoverySectionLabel(
              l, header(DiscoverySection.songsPeers, name: "Sam's server")),
          "Songs from Sam's server");
      expect(discoverySectionLabel(l, header(DiscoverySection.albumsPeers)),
          'Albums from connected servers');
      expect(discoverySectionLabel(l, header(DiscoverySection.songsPeers)),
          'Songs from connected servers');
    });

    test('an unknown key falls back to the item name', () {
      expect(
          discoverySectionLabel(
              l, DisplayItem(null, 'Other', 'section', 'nope', null, null)),
          'Other');
    });

    test('every locale names the one server it was given', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final t = lookupAppLocalizations(locale);
        expect(t.discoverPageAlbumsPeer('Zed'), contains('Zed'),
            reason: '$locale');
        expect(t.discoverPageSongsPeer('Zed'), contains('Zed'),
            reason: '$locale');
      }
    });
  });

  test('a song row\'s second line is "Artist · Album", nothing else', () {
    expect(discoveryRowSubtext('Moderat', 'II'), 'Moderat · II');
    expect(discoveryRowSubtext('Moderat', null), 'Moderat');
    expect(discoveryRowSubtext(' ', 'II'), 'II');
    expect(discoveryRowSubtext(null, ''), isNull);
  });

  test('every locale renders the counts the seeds sheet keeps', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final t = lookupAppLocalizations(locale);
      for (final f in <String Function(int)>[
        t.discoverPageWindowDays,
        t.discoverPageAgoMonths,
        t.discoverPageAgoYears,
        t.discoverPageUseThese,
      ]) {
        expect(f(21), contains('21'), reason: '$locale ${f(21)}');
        expect(f(0), contains('0'), reason: '$locale ${f(0)}');
      }
    }
  });
}
