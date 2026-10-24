// The phone's folder and artist ports replayed against golden values from
// the mStream server's own engines (federation-copy.js planFolder,
// landingFor, planArtistAlbums; destination.js layoutLead) and the webapp's
// left-out line (discover-jobs.js artistLeftOut), over generated inputs —
// test/util/fixtures/discover_folder_gold.json, made by
// discover_folder_gold.mjs from the mStream checkout — so the server, the
// webapp and the phone cannot drift.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/discover_jobs.dart';
import 'package:mstream_music/util/plan_artist_albums.dart';

void main() {
  final gold = jsonDecode(File('test/util/fixtures/discover_folder_gold.json').readAsStringSync()) as Map;
  final supported = (gold['supported'] as Map).cast<String, bool>();

  test('planFolder: the same songs, in the same order, in the same folders; the same left out, with why', () {
    for (final f in gold['folders'] as List) {
      final plan = planFolder(f['listing'], f['folder'], supported: supported);
      expect([for (final s in plan.songs) [s.filepath, s.relDir]],
          [for (final s in f['songs'] as List) [s['filepath'], s['relDir']]],
          reason: '${f['folder']} ${f['listing']}');
      expect([for (final s in plan.skipped) [s.from, s.why]],
          [for (final s in f['skipped'] as List) [s['from'], s['why']]],
          reason: '${f['folder']}');
    }
  });

  test("layoutLead: the layout's leading literal folders", () {
    for (final l in gold['leads'] as List) {
      expect(layoutLead(l['layout']).folders, l['folders'], reason: '${l['layout']}');
    }
  });

  test("landingFor: as on the server (the base, the layout's lead, its path inside the peer's library) and into a folder", () {
    var mirrored = 0;
    for (final c in gold['landings'] as List) {
      final mirror = folderTarget(vpath: 'copies', base: c['base'], layout: c['layout'], folder: c['folder']);
      // A path the copy would refuse is refused here before the server
      // would land it: only the ones the phone draws are compared.
      if (mirror.valid) {
        mirrored++;
        expect(mirror.target.relDir, c['mirror'], reason: '${c['folder']} under ${c['base']} / ${c['layout']}');
      }
      final into = folderTarget(
          vpath: 'copies', base: c['base'], layout: c['layout'], folder: c['folder'],
          landing: {'vpath': 'music', 'path': c['intoPath']});
      expect([into.valid, into.target.library, into.target.relDir], [true, c['intoVpath'], c['into']], reason: '${c['intoPath']}');
    }
    expect(mirrored, greaterThan((gold['landings'] as List).length * 3 ~/ 4), reason: 'most of the cases are drawn');
  });

  test("planArtistAlbums and the left-out line: the artist's own albums, the missing, what is left out", () {
    List<List<Object?>> rows(List<PlannedAlbum> l) => [for (final a in l) [a.name, a.year, a.trackCount, a.albumArtist]];
    List<List<Object?>> goldRows(List l) => [for (final a in l) [a['name'], a['year'], a['trackCount'], a['albumArtist']]];
    for (final c in gold['artists'] as List) {
      final listing = {'albums': c['albums']};
      final p = planArtistAlbums(listing, c['artist']);
      expect(rows(p.plan), goldRows(c['plan']), reason: '${c['artist']} ${c['albums']}');
      expect([for (final a in p.skipped) [a.name, a.why]], [for (final a in c['skipped'] as List) [a['name'], a['why']]]);
      // The server's keys (nameKey'd there) as they are.
      final keys = {for (final k in c['localKeys'] as List) k as String};
      expect(rows(planArtistAlbums(listing, c['artist'], localKeys: keys, onlyMissing: true).plan), goldRows(c['missing']));
      final left = artistLeftOut(listing, c['artist']);
      final want = c['leftOut'] as Map?;
      if (want == null) {
        expect(left, isNull, reason: '${c['albums']}');
      } else {
        expect([left!.albums, left.singles, left.one, left.many], [
          want['albums'],
          want['singles'],
          (want['albums'] as List).length == 1 ? (want['albums'] as List).single : null,
          (want['albums'] as List).length > 1 ? (want['albums'] as List).length : 0,
        ]);
      }
    }
  });
}
