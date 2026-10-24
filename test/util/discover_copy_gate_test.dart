// lib/util/discover_copy_gate.dart — when Keep a copy shows, and which
// scopes it offers. All five conditions or hidden, never greyed; inside a
// sheet a missing upload right or no library reads as one plain line.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/discover_copy_gate.dart';

PluginListing listing({bool jobsAllowed = true, List<String> scopes = const ['song', 'album', 'artist', 'artist-missing', 'folder'], bool copy = true}) =>
    PluginListing.fromServerMap({
      'plugins': [
        {'name': 'links', 'title': 'Open elsewhere', 'capabilities': ['links'], 'scopes': ['song']},
        if (copy) {'name': 'federation-copy', 'title': 'Add to your collection', 'capabilities': ['acquire'], 'scopes': scopes},
      ],
      'jobs': {'allowed': jobsAllowed},
    });

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
