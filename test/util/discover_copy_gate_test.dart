// lib/util/discover_copy_gate.dart — when Keep a copy shows, and which
// scopes it offers. All five conditions or hidden, never greyed; inside a
// sheet a missing upload right or no library reads as one plain line. The
// same gate for the network-lead sheet's YouTube add (plugin: youtube), and
// the Copies list on a server whose only plug-in for it is that add.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/discover_copy_gate.dart';

PluginListing listing({
  bool jobsAllowed = true,
  List<String> scopes = const ['song', 'album', 'artist', 'artist-missing', 'folder'],
  bool copy = true,
  Map<String, dynamic>? youtube,
}) =>
    PluginListing.fromServerMap({
      'plugins': [
        {'name': 'links', 'title': 'Open elsewhere', 'capabilities': ['links'], 'scopes': ['song']},
        if (copy) {'name': 'federation-copy', 'title': 'Add to your collection', 'capabilities': ['acquire'], 'scopes': scopes},
        ?youtube,
      ],
      'jobs': {'allowed': jobsAllowed},
    });

/// The youtube plug-in as the server lists it (youtube.js: acquire + lookup,
/// the song scope), with [over] on top.
Map<String, dynamic> yt([Map<String, dynamic> over = const {}]) => {
      'name': 'youtube',
      'title': 'YouTube',
      'capabilities': ['acquire', 'lookup'],
      'scopes': ['song'],
      ...over,
    };

DestinationView dest({bool none = false}) => DestinationView.fromServerMap({
      'destination': none ? null : {'vpath': 'demo', 'base': '', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}', 'source': 'default'},
      'saved': null,
      'libraries': none ? [] : [{'vpath': 'demo', 'template': null}],
      'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
      'variables': ['ARTIST', 'ALBUM', 'YEAR', 'GENRE', 'ALBUMARTIST', 'PEER'],
    });

void main() {
  group('copyGate', () {
    test('all five: ready', () {
      final g = copyGate(pluginsAvailable: true, listing: listing(), destination: dest(), noUpload: false);
      expect([g.status, g.block, g.ready, g.shown, g.wordingKey], [CopyGateStatus.ready, null, true, true, null]);
    });

    test('plug-ins off, copy plug-in absent, scope not listed, jobs not allowed: hidden, no line', () {
      for (final (gate, block) in [
        (copyGate(pluginsAvailable: false, listing: listing(), destination: dest()), CopyGateBlock.pluginsOff),
        (copyGate(pluginsAvailable: null, listing: listing(), destination: dest()), CopyGateBlock.pluginsOff),
        (copyGate(pluginsAvailable: true, listing: listing(copy: false), destination: dest()), CopyGateBlock.notListed),
        (copyGate(pluginsAvailable: true, listing: listing(scopes: ['song']), destination: dest(), scope: 'album'), CopyGateBlock.noScope),
        (copyGate(pluginsAvailable: true, listing: listing(jobsAllowed: false), destination: dest()), CopyGateBlock.jobsNotAllowed),
      ]) {
        expect([gate.status, gate.block, gate.shown, gate.wordingKey], [CopyGateStatus.hidden, block, false, null], reason: '$block');
      }
    });

    test('never Folder, even when the server lists it', () {
      final g = copyGate(pluginsAvailable: true, listing: listing(), destination: dest(), scope: 'folder');
      expect([g.status, g.block], [CopyGateStatus.hidden, CopyGateBlock.noScope]);
    });

    test("uploads off: one line, worded apart from no library; noUpload wins over a null destination", () {
      final off = copyGate(pluginsAvailable: true, listing: listing(), destination: dest(none: true), noUpload: true);
      expect([off.status, off.block, off.shown, off.wordingKey], [CopyGateStatus.line, CopyGateBlock.noUpload, true, kKeepUploadsOffKey]);
      // even before the destination answers
      expect(copyGate(pluginsAvailable: true, listing: listing(), noUpload: true).block, CopyGateBlock.noUpload);
      final noLib = copyGate(pluginsAvailable: true, listing: listing(), destination: dest(none: true), noUpload: false);
      expect([noLib.status, noLib.block, noLib.wordingKey], [CopyGateStatus.line, CopyGateBlock.noLibrary, kKeepNoLibraryKey]);
      // a server too old to say noUpload: the null destination reads as no library
      expect(copyGate(pluginsAvailable: true, listing: listing(), destination: dest(none: true)).block, CopyGateBlock.noLibrary);
    });

    test('still asking: unknown (draw nothing yet); could not ask: hidden', () {
      expect(copyGate(pluginsAvailable: true).status, CopyGateStatus.unknown);
      expect(copyGate(pluginsAvailable: true, listing: listing()).status, CopyGateStatus.unknown);
      final noList = copyGate(pluginsAvailable: true, listingFailed: true);
      expect([noList.status, noList.block], [CopyGateStatus.hidden, CopyGateBlock.unavailable]);
      final noDest = copyGate(pluginsAvailable: true, listing: listing(), destinationFailed: true);
      expect([noDest.status, noDest.block], [CopyGateStatus.hidden, CopyGateBlock.unavailable]);
    });

    test('the Copies list needs plug-ins, the copy plug-in, jobs and uploads — not a destination', () {
      expect(copiesListVisible(pluginsAvailable: true, listing: listing(), noUpload: false), isTrue);
      expect(copiesListVisible(pluginsAvailable: true, listing: listing()), isTrue);
      expect(copiesListVisible(pluginsAvailable: true, listing: listing(), noUpload: true), isFalse);
      expect(copiesListVisible(pluginsAvailable: true, listing: listing(jobsAllowed: false)), isFalse);
      expect(copiesListVisible(pluginsAvailable: true, listing: listing(copy: false)), isFalse);
      expect(copiesListVisible(pluginsAvailable: false, listing: listing()), isFalse);
      expect(copiesListVisible(pluginsAvailable: true), isFalse);
    });

    test('the YouTube add (plugin: youtube): listed with acquire, lookup and the song, jobs, uploads, a library — or hidden, or one line', () {
      CopyGate g(PluginListing l, {DestinationView? d, bool? noUpload = false, String scope = 'song'}) =>
          copyGate(pluginsAvailable: true, listing: l, destination: d ?? dest(), noUpload: noUpload, scope: scope, plugin: kYoutubePlugin);
      final ready = g(listing(copy: false, youtube: yt()));
      expect([ready.status, ready.block], [CopyGateStatus.ready, null]);
      expect(g(listing(youtube: yt())).ready, isTrue, reason: 'beside the copy plug-in');
      for (final (gate, block, why) in [
        (g(listing()), CopyGateBlock.notListed, 'not listed'),
        (g(listing(youtube: yt({'capabilities': ['acquire']}))), CopyGateBlock.notListed, 'no lookup: no pick to send'),
        (g(listing(youtube: yt({'capabilities': ['lookup']}))), CopyGateBlock.notListed, 'no acquire'),
        (g(listing(youtube: yt({'scopes': ['album']}))), CopyGateBlock.notListed, 'no song scope'),
        (g(listing(youtube: yt({'available': false}))), CopyGateBlock.notListed, 'its probe failed (no yt-dlp)'),
        (g(listing(youtube: yt()), scope: 'album'), CopyGateBlock.noScope, 'a scope it lacks'),
        (g(listing(youtube: yt(), jobsAllowed: false)), CopyGateBlock.jobsNotAllowed, 'the jobs gate'),
        (copyGate(pluginsAvailable: false, listing: listing(youtube: yt()), destination: dest(), plugin: kYoutubePlugin), CopyGateBlock.pluginsOff, 'plug-ins off'),
      ]) {
        expect([gate.status, gate.block], [CopyGateStatus.hidden, block], reason: why);
      }
      final off = g(listing(youtube: yt()), noUpload: true);
      expect([off.status, off.block, off.wordingKey], [CopyGateStatus.line, CopyGateBlock.noUpload, kKeepUploadsOffKey]);
      final noLib = g(listing(youtube: yt()), d: dest(none: true));
      expect([noLib.status, noLib.block], [CopyGateStatus.line, CopyGateBlock.noLibrary]);
      expect(copyGate(pluginsAvailable: true, listing: listing(youtube: yt()), plugin: kYoutubePlugin).status, CopyGateStatus.unknown,
          reason: 'the destination still being asked');
      // The copy plug-in's own gate is untouched by YouTube's.
      expect(copyGate(pluginsAvailable: true, listing: listing(copy: false, youtube: yt()), destination: dest()).block, CopyGateBlock.notListed);
    });

    test('a server whose only plug-in for Copies is the YouTube add has Copies — on a build that shows YouTube', () {
      final only = listing(copy: false, youtube: yt());
      expect(copiesListVisible(pluginsAvailable: true, listing: only, youtube: true), isTrue);
      expect(copiesListVisible(pluginsAvailable: true, listing: only), isFalse, reason: 'a store build');
      expect(copiesListVisible(pluginsAvailable: true, listing: listing(copy: false, youtube: yt({'capabilities': ['acquire']})), youtube: true), isFalse,
          reason: 'not the add the phone makes');
      expect(copiesListVisible(pluginsAvailable: true, listing: listing(copy: false, youtube: yt(), jobsAllowed: false), youtube: true), isFalse);
      expect(copiesListVisible(pluginsAvailable: true, listing: only, noUpload: true, youtube: true), isFalse);
      expect(copiesListVisible(pluginsAvailable: false, listing: only, youtube: true), isFalse);
      expect(copiesListVisible(pluginsAvailable: true, listing: listing(), youtube: true), isTrue, reason: 'the copy plug-in alone, as before');
    });
  });

  group('offeredCopyScopes', () {
    final copy = listing().copy;
    const row = {'title': 'Late Train Verse', 'artist': 'Boukmanflow', 'album': 'Borrowed Tapes', 'albumArtist': null};

    test('a song row: this song, album, artist, only missing — never folder', () {
      expect(offeredCopyScopes(row, copy), ['song', 'album', 'artist', 'artist-missing']);
    });

    test('album needs the album and an artist or album artist; artist scopes need the artist', () {
      expect(offeredCopyScopes({...row, 'artist': null}, copy), ['song'],
          reason: 'with a null artist the peer would hand back every album of that name');
      expect(offeredCopyScopes({...row, 'artist': '  '}, copy), ['song'], reason: 'a blank artist is no artist');
      expect(offeredCopyScopes({...row, 'artist': null, 'albumArtist': 'Various Artists'}, copy), ['song', 'album']);
      expect(offeredCopyScopes({...row, 'album': null}, copy), ['song', 'artist', 'artist-missing']);
    });

    test('an album card: no song; a compilation card offers the album only', () {
      expect(offeredCopyScopes(row, copy, card: true), ['album', 'artist', 'artist-missing']);
      expect(offeredCopyScopes({...row, 'albumArtist': 'Various Artists'}, copy, card: true, compilation: true), ['album']);
    });

    test('only what the server lists', () {
      expect(offeredCopyScopes(row, listing(scopes: ['song', 'album']).copy), ['song', 'album']);
      expect(offeredCopyScopes(row, null), isEmpty);
    });
  });

  // Keep a copy while browsing a connected server (the phone spec's "the
  // gate on the phone"): Folder only from that server's file explorer; the
  // browse rule offers Album only with the album's known credit.
  group('browsing a connected server', () {
    test('Folder only from the file explorer — Discover and every other browse view never', () {
      final explorer = copyGate(pluginsAvailable: true, listing: listing(), destination: dest(), scope: 'folder', entry: KeepEntry.explorer);
      expect(explorer.ready, isTrue);
      for (final entry in [KeepEntry.discover, KeepEntry.browse]) {
        final g = copyGate(pluginsAvailable: true, listing: listing(), destination: dest(), scope: 'folder', entry: entry);
        expect([g.status, g.block], [CopyGateStatus.hidden, CopyGateBlock.noScope], reason: '$entry');
      }
      // an older server: no folder in its scopes, no folder way in
      final old = copyGate(pluginsAvailable: true, listing: listing(scopes: ['song', 'album', 'artist', 'artist-missing']), destination: dest(), scope: 'folder', entry: KeepEntry.explorer);
      expect([old.status, old.block], [CopyGateStatus.hidden, CopyGateBlock.noScope]);
      // the rest of the gate reads as for every scope
      expect(copyGate(pluginsAvailable: true, listing: listing(), destination: dest(none: true), noUpload: true, scope: 'folder', entry: KeepEntry.explorer).status,
          CopyGateStatus.line);
    });

    test('the browse rule: Album only with a known credit (never the track artist); no artist copy of Various Artists; Folder from an explorer file row', () {
      final copy = listing().copy;
      const song = {'artist': 'Boukmanflow', 'title': 'Late Train Verse', 'album': 'Borrowed Tapes'};
      expect(offeredCopyScopes(song, copy), ['song', 'album', 'artist', 'artist-missing'],
          reason: "Discover's rule: the track artist names the album");
      expect(offeredCopyScopes(song, copy, browse: true), ['song', 'artist', 'artist-missing'],
          reason: 'browsing: no credit known yet, no Album');
      expect(offeredCopyScopes({...song, 'albumArtist': 'Boukmanflow'}, copy, browse: true), ['song', 'album', 'artist', 'artist-missing']);
      expect(offeredCopyScopes({...song, 'albumArtist': 'Boukmanflow'}, copy, browse: true, folder: true),
          ['song', 'album', 'artist', 'artist-missing', 'folder']);
      expect(offeredCopyScopes({...song, 'albumArtist': 'Various Artists', 'artist': 'Various Artists'}, copy, browse: true),
          ['song', 'album'], reason: 'no one\'s own albums');
      expect(offeredCopyScopes(song, copy, folder: true), ['song', 'album', 'artist', 'artist-missing'],
          reason: 'never Folder from Discover');
      expect(offeredCopyScopes({...song, 'albumArtist': 'Boukmanflow'}, listing(scopes: ['song', 'album']).copy, browse: true, folder: true), ['song', 'album'],
          reason: 'limited to what the server lists');
      // an album focus from a card: no song
      expect(offeredCopyScopes(const {'album': 'Night Market Sampler', 'albumArtist': 'Various Artists'}, copy, browse: true, card: true, compilation: true), ['album']);
    });
  });
}
