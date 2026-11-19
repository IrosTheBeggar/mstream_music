// lib/util/network_sheet_gate.dart — what the network-lead sheet holds and
// whether a "From the network" row's tap opens it: PREVIEW from the preview
// plug-ins, KEEP A COPY from the jobs controller's YouTube gate as it is
// (no second gate chain), Open elsewhere from the links plug-in; a section
// that cannot work is left out, and a row with nothing to offer keeps its
// copy tap.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/discover_copy_gate.dart';
import 'package:mstream_music/util/network_sheet_gate.dart';

Map<String, dynamic> plugin(
  String name, {
  List<String> caps = const ['preview'],
  List<String> scopes = const ['song'],
  bool? available,
  String? title,
}) => {
  'name': name,
  'title': title ?? name,
  'capabilities': caps,
  'scopes': scopes,
  'available': ?available,
};

PluginListing listing({
  bool links = true,
  bool copy = true,
  List<Map<String, dynamic>> extra = const [],
  bool jobsAllowed = true,
}) => PluginListing.fromServerMap({
  'plugins': [
    if (links) plugin('links', caps: ['links']),
    if (copy)
      plugin(
        'federation-copy',
        caps: ['acquire'],
        scopes: ['song', 'album', 'artist', 'artist-missing', 'folder'],
      ),
    ...extra,
  ],
  'jobs': {'allowed': jobsAllowed},
});

final youtube = plugin('youtube', caps: ['acquire', 'lookup']);

DestinationView dest() => DestinationView.fromServerMap({
  'destination': {
    'vpath': 'demo',
    'base': '',
    'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
    'source': 'default',
  },
  'saved': null,
  'libraries': [
    {'vpath': 'demo', 'template': null},
  ],
  'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
  'variables': ['ARTIST', 'ALBUM', 'YEAR', 'GENRE', 'ALBUMARTIST', 'PEER'],
});

const ready = CopyGate(CopyGateStatus.ready);
const unknown = CopyGate(CopyGateStatus.unknown);

/// A recommendation the plug-in routes take (its shape does not matter
/// here: only whether there is one).
const rec = <String, dynamic>{'artist': 'A', 'title': 'T', 'source': 'p2p'};

List<String> names(NetworkSheetSections s) => [
  for (final p in s.previews) p.name,
];

void main() {
  group('networkSheetSections', () {
    test('plug-ins off, or the listing not read: nothing but Copy title', () {
      for (final (on, l) in [
        (false, listing()),
        (null, listing()),
        (true, null),
      ]) {
        final s = networkSheetSections(
          pluginsAvailable: on,
          listing: l,
          youtubeGate: ready,
          buildShowsYoutube: true,
        );
        expect(
          [names(s), s.youtube, s.links, s.any],
          [<String>[], YoutubeBlock.hidden, false, false],
          reason: '$on $l',
        );
      }
    });

    test('PREVIEW: every preview plug-in that can run, Deezer then iTunes '
        'then the rest; Open elsewhere from the links plug-in', () {
      final s = networkSheetSections(
        pluginsAvailable: true,
        listing: listing(
          extra: [
            plugin('spotify-clips', title: 'Clips'),
            plugin('itunes'),
            plugin('deezer'),
            plugin('broken', available: false),
            plugin('youtube-links', caps: ['links']),
          ],
        ),
        youtubeGate: const CopyGate(
          CopyGateStatus.hidden,
          CopyGateBlock.notListed,
        ),
        buildShowsYoutube: true,
      );
      expect(names(s), ['deezer', 'itunes', 'spotify-clips']);
      expect(s.links, isTrue);
      expect(s.youtube, YoutubeBlock.hidden);
      expect(s.any, isTrue);
    });

    test('KEEP A COPY reads the YouTube gate as it is: ready shows, unknown '
        'holds its place, every refusal — its one-line ones too — leaves '
        'it out', () {
      for (final (gate, block) in [
        (ready, YoutubeBlock.ready),
        (unknown, YoutubeBlock.unknown),
        (
          const CopyGate(CopyGateStatus.hidden, CopyGateBlock.notListed),
          YoutubeBlock.hidden,
        ),
        (
          const CopyGate(CopyGateStatus.hidden, CopyGateBlock.jobsNotAllowed),
          YoutubeBlock.hidden,
        ),
        (
          const CopyGate(CopyGateStatus.line, CopyGateBlock.noUpload),
          YoutubeBlock.hidden,
        ),
        (
          const CopyGate(CopyGateStatus.line, CopyGateBlock.noLibrary),
          YoutubeBlock.hidden,
        ),
      ]) {
        expect(youtubeBlockOf(gate), block, reason: '$gate');
        final s = networkSheetSections(
          pluginsAvailable: true,
          listing: listing(links: false, extra: [youtube]),
          youtubeGate: gate,
          buildShowsYoutube: true,
        );
        expect(s.youtube, block, reason: '$gate');
        expect(s.any, block != YoutubeBlock.hidden, reason: '$gate');
      }
    });

    test('a build that does not show YouTube: no block, whatever the gate '
        'says', () {
      final s = networkSheetSections(
        pluginsAvailable: true,
        listing: listing(links: false, extra: [youtube]),
        youtubeGate: ready,
        buildShowsYoutube: false,
      );
      expect(s.youtube, YoutubeBlock.hidden);
      expect(s.any, isFalse);
    });

    test("the controller's real gate for YouTube, through copyGate", () {
      CopyGate gate({bool? noUpload = false, DestinationView? d}) => copyGate(
        pluginsAvailable: true,
        listing: listing(extra: [youtube]),
        destination: d,
        noUpload: noUpload,
        plugin: kYoutubePlugin,
      );
      YoutubeBlock block(CopyGate g) => networkSheetSections(
        pluginsAvailable: true,
        listing: listing(extra: [youtube]),
        youtubeGate: g,
        buildShowsYoutube: true,
      ).youtube;
      expect(block(gate(d: dest())), YoutubeBlock.ready);
      expect(block(gate()), YoutubeBlock.unknown, reason: 'destination asked');
      expect(
        block(gate(noUpload: true, d: dest())),
        YoutubeBlock.hidden,
        reason: 'no upload right: hidden, never a line on this sheet',
      );
    });
  });

  group('networkLeadTap', () {
    final some = networkSheetSections(
      pluginsAvailable: true,
      listing: listing(),
      youtubeGate: ready,
      buildShowsYoutube: true,
    );

    test('the sheet: plug-ins on, the listing read, a sendable row, '
        'something to offer', () {
      expect(
        networkLeadTap(
          pluginsAvailable: true,
          listing: listing(),
          sections: some,
          sendable: rec,
        ),
        NetworkLeadTap.sheet,
      );
    });

    test('otherwise the copy', () {
      for (final (why, tap) in [
        (
          'plug-ins off',
          networkLeadTap(
            pluginsAvailable: false,
            listing: listing(),
            sections: some,
            sendable: rec,
          ),
        ),
        (
          'plug-ins unknown',
          networkLeadTap(
            pluginsAvailable: null,
            listing: listing(),
            sections: some,
            sendable: rec,
          ),
        ),
        (
          'listing not read',
          networkLeadTap(
            pluginsAvailable: true,
            listing: null,
            sections: some,
            sendable: rec,
          ),
        ),
        (
          'row not sendable',
          networkLeadTap(
            pluginsAvailable: true,
            listing: listing(),
            sections: some,
            sendable: null,
          ),
        ),
        (
          'nothing to offer',
          networkLeadTap(
            pluginsAvailable: true,
            listing: listing(links: false),
            sections: NetworkSheetSections.none,
            sendable: rec,
          ),
        ),
      ]) {
        expect(tap, NetworkLeadTap.copy, reason: why);
      }
    });
  });
}
