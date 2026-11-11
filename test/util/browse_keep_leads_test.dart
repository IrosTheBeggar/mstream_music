// util/browse_keep_leads.dart — Keep a copy while browsing a connected
// server: the recommendation each way in sends (built as Discover's rows
// are sent, so the server keys them alike), the folder a way in names, the
// album page's credit in its three states, the queue's rule, and what the
// Keep sheet is opened with.

import 'dart:async';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';

Server home() => Server('http://home.local:3000', null, null, 'JWT', 'home');

Server peerOf(Server parent, {int id = 1, String name = 'Stage Peer B', String localname = 'peer-1'}) =>
    Server('federated://home/$id', null, null, null, localname)
      ..federationParent = parent.localname
      ..federationPeerId = id
      ..federationPeerName = name
      ..parentServer = parent;

MusicMetadata tags(String title,
        {String artist = 'Boukmanflow',
        String? display,
        String album = 'Borrowed Tapes',
        String? albumArtist,
        int? year = 2019,
        double? seconds = 8,
        String? art}) =>
    MusicMetadata(artist, album, title, 2, 1, year, 'hash', null, art,
        artistDisplay: display, durationSeconds: seconds, albumArtist: albumArtist);

DisplayItem fileRow(Server? s, String path, [MusicMetadata? m]) =>
    DisplayItem(s, path.split('/').last, 'file', path, null, null)..metadata = m;

DisplayItem albumItem(Server? s, String? name,
        {String? credit, AlbumCredit state = AlbumCredit.unknown, int? year, bool? compilation, List<String> artists = const []}) =>
    DisplayItem(s, name ?? 'SINGLES', 'album', name, null, null)
      ..albumArtist = credit
      ..creditState = state
      ..year = year
      ..compilation = compilation
      ..artists = artists;

void main() {
  late Server own;
  late Server peer;
  setUp(() {
    own = home();
    peer = peerOf(own);
  });

  group('a usable connected server', () {
    test('a peer its server still lists, not hidden, its parent linked — never the own server', () {
      expect(isKeepPeer(peer), isTrue);
      expect(isKeepPeer(own), isFalse);
      expect(isKeepPeer(null), isFalse);
      expect(isKeepPeer(peerOf(own)..federationMissing = true), isFalse);
      expect(isKeepPeer(peerOf(own)..federationHidden = true), isFalse);
      expect(isKeepPeer(peerOf(own)..parentServer = null), isFalse);
      expect(keepPeerOf(peer), {'id': 1, 'name': 'Stage Peer B'});
    });
  });

  group('FolderRef: a folder below its library root', () {
    test('any spelling; never a library root or the top', () {
      final f = FolderRef.of('/music/Boukmanflow/Borrowed Tapes/')!;
      expect([f.path, f.name, f.library, f.filepath, f.segments],
          ['/music/Boukmanflow/Borrowed Tapes', 'Borrowed Tapes', 'music', 'music/Boukmanflow/Borrowed Tapes', ['music', 'Boukmanflow', 'Borrowed Tapes']]);
      expect(FolderRef.of('music\\Boukmanflow'), FolderRef.of('/music/Boukmanflow'));
      expect([FolderRef.of('/music/'), FolderRef.of('/'), FolderRef.of(''), FolderRef.of(null)], [null, null, null, null]);
    });

    test("a file's folder, none at its library's root", () {
      expect(FolderRef.parentOf('/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3')!.path, '/music/Boukmanflow/Borrowed Tapes');
      expect(FolderRef.parentOf('/music/loose.mp3'), isNull);
    });

    test('its recommendation: the source, the peer, the path with no leading slash, its name', () {
      expect(FolderRef.of('/music/Boukmanflow/Borrowed Tapes')!.rec(peer), {
        'source': 'federation',
        'peer': {'id': 1, 'name': 'Stage Peer B'},
        'filepath': 'music/Boukmanflow/Borrowed Tapes',
        'title': 'Borrowed Tapes',
      });
    });
  });

  group('the recommendations each way in sends', () {
    test("a song row: as Discover's rows are sent — the primary artist, the path with no leading slash, the album's credit when known", () {
      final row = fileRow(peer, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
          tags('Late Train Verse', display: 'Boukmanflow feat. ALM', art: 'abc.jpg'));
      expect(songLeadOf(row), {
        'source': 'federation',
        'peer': {'id': 1, 'name': 'Stage Peer B'},
        'filepath': 'music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
        'title': 'Late Train Verse',
        'artist': 'Boukmanflow',
        'album': 'Borrowed Tapes',
        'year': 2019,
        'duration': 8.0,
        'albumArt': 'abc.jpg',
      });
      expect(songLeadOf(row, albumCredit: 'Boukmanflow')!['albumArtist'], 'Boukmanflow', reason: "the album page's known credit");
      final s2 = fileRow(peer, '/music/Various Artists/Night Market Sampler/x.mp3', tags('Night Market Cypher', albumArtist: 'Various Artists'));
      expect(songLeadOf(s2)!.containsKey('albumArtist'), isFalse,
          reason: "the song's own album-artist is only the sheet's candidate (a split album's half names its own)");
      final split = fileRow(peer, '/music/ALM/Split Series/01.mp3', tags('One', artist: 'ALM', album: 'Split Series', albumArtist: 'ALM'));
      expect(songLeadOf(split, albumCredit: 'Night Owl Radio')!['albumArtist'], 'Night Owl Radio',
          reason: "the page's resolved credit wins over the song's own tag");
    });

    test('an untagged row is its path and file name until the sheet reads its tags; a year the route would refuse is left out', () {
      final bare = fileRow(peer, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3');
      expect(songLeadOf(bare), {
        'source': 'federation',
        'peer': {'id': 1, 'name': 'Stage Peer B'},
        'filepath': 'music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
        'title': '02 - Late Train Verse.mp3',
      });
      final merged = songLeadFor(peer, bare.data!, tags('Late Train Verse'));
      expect([merged['title'], merged['artist']], ['Late Train Verse', 'Boukmanflow']);
      expect(songLeadOf(fileRow(peer, '/music/a.mp3', tags('A', year: 19)))!.containsKey('year'), isFalse);
    });

    test('nothing off a connected server, and nothing for a folder row', () {
      expect(songLeadOf(fileRow(own, '/music/a.mp3', tags('A'))), isNull);
      expect(songLeadOf(DisplayItem(peer, 'x', 'directory', '/music/x', null, null)), isNull);
    });

    test("an album: its credit as albumArtist and — unless a compilation — as artist; the card's says compilation", () {
      final tapes = albumItem(peer, 'Borrowed Tapes', credit: 'Boukmanflow', state: AlbumCredit.known, year: 2019, compilation: false);
      expect(albumLeadOf(tapes), {
        'source': 'federation',
        'peer': {'id': 1, 'name': 'Stage Peer B'},
        'album': 'Borrowed Tapes',
        'albumArtist': 'Boukmanflow',
        'artist': 'Boukmanflow',
        'year': 2019,
      });
      final sampler = albumItem(peer, 'Night Market Sampler', credit: 'Various Artists', state: AlbumCredit.known, compilation: true);
      final card = albumLeadOf(sampler, card: true)!;
      expect([card['albumArtist'], card.containsKey('artist'), card['compilation']], ['Various Artists', false, true],
          reason: 'a compilation copies whole under its credit');
    });

    test('no album without a known credit: credits that disagree, nothing said, the singles bucket; a resolved one is given', () {
      expect(albumLeadOf(albumItem(peer, 'Split Series', state: AlbumCredit.disagree)), isNull);
      expect(albumLeadOf(albumItem(peer, 'Borrowed Tapes', credit: 'Boukmanflow')), isNull,
          reason: 'a credit nothing vouched for (state unknown) is not used');
      expect(albumLeadOf(albumItem(peer, null, credit: 'Boukmanflow', state: AlbumCredit.known)), isNull);
      expect(albumLeadOf(albumItem(peer, 'Borrowed Tapes'), credit: 'Boukmanflow')!['albumArtist'], 'Boukmanflow');
      expect(albumLeadOf(albumItem(own, 'Borrowed Tapes', credit: 'Boukmanflow', state: AlbumCredit.known)), isNull);
    });

    test("a compilation as the webapp reads one: Various Artists whatever the listing says, the listing's word, a credit none of its artists carries", () {
      // An untagged sampler lists compilation: false (the server's flag is
      // MAX(tag_compilation)): its Various Artists credit still says so.
      expect(albumIsCompilation(albumItem(peer, 'x', compilation: false), 'Various Artists'), isTrue);
      expect(albumIsCompilation(albumItem(peer, 'x'), 'Various Artists'), isTrue);
      expect(albumIsCompilation(albumItem(peer, 'x', compilation: true), 'Boukmanflow'), isTrue);
      expect(albumIsCompilation(albumItem(peer, 'x', artists: ['ALM', 'Color Out']), 'DJ Mix'), isTrue);
      expect(albumIsCompilation(albumItem(peer, 'x', compilation: false, artists: ['ALM', 'Color Out']), 'DJ Mix'), isTrue,
          reason: 'a credit none of its artists is, whatever the flag');
      expect(albumIsCompilation(albumItem(peer, 'x', artists: ['Boukmanflow']), 'boukmanflow'), isFalse);
      expect(albumIsCompilation(albumItem(peer, 'x'), 'Boukmanflow'), isFalse, reason: 'artists that say nothing say nothing');
      // An album page's own songs stand in for a listing that named none (a
      // page opened from search or Discover).
      expect(albumIsCompilation(albumItem(peer, 'x'), 'DJ Kool Mix', artists: ['ALM', 'Color Out']), isTrue);
      expect(albumIsCompilation(albumItem(peer, 'x'), 'Boukmanflow', artists: ['Boukmanflow']), isFalse);
      expect(albumIsCompilation(albumItem(peer, 'x'), 'Boukmanflow', artists: ['', '  ']), isFalse);
    });

    test("an unflagged card credited to Various Artists (webapp D2): Album whole, no artist, compilation true — its lookup rec too", () {
      final sampler = albumItem(peer, 'Night Market Sampler',
          credit: 'Various Artists', state: AlbumCredit.known, year: 2024, compilation: false, artists: ['Color Out', 'Boukmanflow', 'ALM']);
      final card = BrowseKeepRequest.album(sampler, variant: KeepVariant.item)!;
      expect([card.lead['albumArtist'], card.lead.containsKey('artist'), card.lead['compilation'], card.compilation],
          ['Various Artists', false, true, true]);
      expect(albumLeadOf(sampler)!.containsKey('artist'), isFalse, reason: "the page's and the card's lookup rec");
    });

    test("an album page whose songs all name Various Artists, as artist and album-artist (webapp D2)", () {
      final page = albumItem(peer, 'Night Market Sampler', credit: 'Various Artists', state: AlbumCredit.known);
      final req = BrowseKeepRequest.album(page, variant: KeepVariant.page, artists: ['Various Artists'])!;
      expect([req.lead['albumArtist'], req.lead.containsKey('artist'), req.compilation], ['Various Artists', false, true]);
      // A DJ mix opened from search: its songs' artists are not its credit.
      final mix = albumItem(peer, 'Night Mix', credit: 'DJ Kool Mix', state: AlbumCredit.known);
      final mixed = BrowseKeepRequest.album(mix, variant: KeepVariant.page, artists: ['ALM', 'Color Out'])!;
      expect([mixed.lead.containsKey('artist'), mixed.compilation], [false, true]);
      final own = BrowseKeepRequest.album(mix, variant: KeepVariant.page, artists: ['DJ Kool Mix'])!;
      expect([own.lead['artist'], own.compilation], ['DJ Kool Mix', false]);
    });

    test('an artist: the name alone; never Various Artists', () {
      expect(artistLeadOf(ArtistContext(server: peer, name: 'Boukmanflow')), {
        'source': 'federation',
        'peer': {'id': 1, 'name': 'Stage Peer B'},
        'artist': 'Boukmanflow',
      });
      expect(artistLeadOf(ArtistContext(server: peer, name: 'various  artists')), isNull);
      expect(artistLeadOf(ArtistContext(server: own, name: 'Boukmanflow')), isNull);
    });

    test("a queued track: its extras — the path with no leading slash, the primary artist, the album's credit when the queue kept one", () {
      final item = MediaItem(
        id: 'http://x/stream',
        title: 'Rooftop Cypher',
        artist: 'Boukmanflow feat. ALM',
        album: 'Borrowed Tapes',
        duration: const Duration(milliseconds: 12500),
        extras: {'server': 'peer-1', 'path': '/music/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3', 'artist': 'Boukmanflow', 'year': 2019, 'albumArtist': 'Boukmanflow'},
      );
      expect(queueLeadOf(item, peer), {
        'source': 'federation',
        'peer': {'id': 1, 'name': 'Stage Peer B'},
        'filepath': 'music/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3',
        'title': 'Rooftop Cypher',
        'artist': 'Boukmanflow',
        'album': 'Borrowed Tapes',
        'year': 2019,
        'duration': 12.5,
      });
      final req = BrowseKeepRequest.queued(item..extras!['artUrl'] = 'http://home/art/r.jpg', peer)!;
      expect([req.songCredit, req.coverUrl, req.lead.containsKey('albumArtist')], ['Boukmanflow', 'http://home/art/r.jpg', false],
          reason: "the credit the queue kept is the song's own: the sheet's candidate, never the recommendation's");
      final old = MediaItem(id: 'x', title: 'T', artist: 'Ann', extras: {'server': 'peer-1', 'path': '/music/t.mp3'});
      expect(queueLeadOf(old, peer)['artist'], 'Ann', reason: 'an entry from an older build: its artist is the primary one');
      final pathless = MediaItem(id: 'y', title: 'T', extras: {'server': 'peer-1'});
      expect(queueLeadOf(pathless, peer).containsKey('filepath'), isFalse);
    });

    test('leadOfRec: any recommendation as the Keep card reads it, a title or none', () {
      final album = leadOfRec(albumLeadOf(albumItem(peer, 'Borrowed Tapes', credit: 'Boukmanflow', state: AlbumCredit.known, year: 2019))!);
      expect([album.title, album.album, album.albumArtist, album.artist, album.year, album.peerId, album.peerName, album.source],
          ['', 'Borrowed Tapes', 'Boukmanflow', 'Boukmanflow', 2019, 1, 'Stage Peer B', 'federation']);
      final folder = leadOfRec(FolderRef.of('/music/Boukmanflow/Borrowed Tapes')!.rec(peer));
      expect([folder.title, folder.filepath], ['Borrowed Tapes', 'music/Boukmanflow/Borrowed Tapes']);
    });
  });

  group("the queue's Keep a copy…", () {
    final servers = <String, Server>{};
    Server? byLocalname(String name) => servers[name];
    MediaItem queued(Map<String, dynamic>? extras) => MediaItem(id: 'x', title: 'T', extras: extras);

    setUp(() {
      servers
        ..clear()
        ..['home'] = own
        ..['peer-1'] = peer
        ..['peer-2'] = (peerOf(own, id: 2, localname: 'peer-2')..federationMissing = true);
    });

    test("a connected server's track yes — downloaded to this phone too; a phone file, the own server's track, a peer no longer listed no", () {
      expect(queueKeepPeer(queued({'server': 'peer-1', 'path': '/music/a.mp3'}), byLocalname: byLocalname), same(peer));
      expect(queueKeepPeer(queued({'server': 'peer-1', 'path': '/music/a.mp3', 'localPath': '/data/media/peer-1/music/a.mp3'}), byLocalname: byLocalname),
          same(peer), reason: 'a download is still that server\'s song');
      expect(queueKeepPeer(queued({'path': '/sdcard/Morning Tape.mp3', 'localPath': '/sdcard/Morning Tape.mp3'}), byLocalname: byLocalname), isNull,
          reason: 'a file on this phone has no server');
      expect(queueKeepPeer(queued({'server': 'home', 'path': '/music/a.mp3'}), byLocalname: byLocalname), isNull);
      expect(queueKeepPeer(queued({'server': 'peer-2', 'path': '/music/a.mp3'}), byLocalname: byLocalname), isNull);
      expect(queueKeepPeer(queued({'server': 'gone', 'path': '/music/a.mp3'}), byLocalname: byLocalname), isNull);
      expect(queueKeepPeer(queued(null), byLocalname: byLocalname), isNull);
      expect(queueKeepPeer(queued({'server': 'peer-1'}), byLocalname: byLocalname), isNull,
          reason: 'a track with no path there names nothing to copy');
      expect(queueKeepPeer(queued({'server': 'peer-1', 'path': ''}), byLocalname: byLocalname), isNull);
    });

    test("and only while the song scope's gate is open on its own server", () {
      final item = queued({'server': 'peer-1', 'path': '/music/a.mp3'});
      expect(queueKeepPeer(item, byLocalname: byLocalname, gateOpen: (_) => false), isNull);
      Server? asked;
      expect(queueKeepPeer(item, byLocalname: byLocalname, gateOpen: (p) {
        asked = p;
        return true;
      }), same(peer));
      expect(asked, same(peer));
    });
  });

  group("the album page's credit: known, disagree, unknown", () {
    List<DisplayItem> songs(List<String?> credits, {String artist = 'Boukmanflow'}) => [
          for (var i = 0; i < credits.length; i++)
            fileRow(peer, '/music/x/$i.mp3', tags('T$i', artist: artist, albumArtist: credits[i])),
        ];

    test('1. the opener: a listing that named the credit, or said its rows disagree; a Discover card that knew it', () {
      expect(AlbumCreditResolver.fromOpener(albumItem(peer, 'Borrowed Tapes', credit: 'Boukmanflow', state: AlbumCredit.known)),
          const ResolvedCredit.known('Boukmanflow'));
      expect(AlbumCreditResolver.fromOpener(albumItem(peer, 'Split Series', state: AlbumCredit.disagree)), ResolvedCredit.disagree);
      expect(AlbumCreditResolver.fromOpener(albumItem(peer, 'Night Market Sampler', credit: 'Various Artists')),
          const ResolvedCredit.known('Various Artists'), reason: "a Discover card's credit");
      final hit = albumItem(peer, 'Borrowed Tapes')
        ..creditHint = 'Boukmanflow'
        ..yearHint = 2019;
      expect(AlbumCreditResolver.fromOpener(hit), isNull, reason: "a search hit's album_artist is a hint, never the credit alone");
      expect(AlbumCreditResolver.fromOpener(albumItem(peer, null, credit: 'Boukmanflow')), ResolvedCredit.unknown,
          reason: 'the singles bucket is no album, whatever its listing says');
    });

    test("2. the songs' own album-artist: all agree → known as the first spells it; two differ → disagree; one lacks it → go on", () {
      expect(AlbumCreditResolver.fromSongs(songs(['Boukmanflow', 'boukmanflow ', 'BOUKMANFLOW'])), const ResolvedCredit.known('Boukmanflow'));
      expect(AlbumCreditResolver.fromSongs(songs(['ALM', 'Night Owl Radio'])), ResolvedCredit.disagree);
      expect(AlbumCreditResolver.fromSongs(songs(['Boukmanflow', null])), isNull);
      expect(AlbumCreditResolver.fromSongs(const []), isNull);
    });

    test("3. the peer's album list: exactly one of the page's name and year gives its credit (null: disagree); none, several or an older server → unknown", () {
      final answer = {
        'albums': [
          {'name': 'Borrowed Tapes', 'year': 2019, 'year_min': 2019, 'year_max': 2019, 'album_artist': 'Boukmanflow'},
          {'name': 'Split Series', 'year': 2022, 'album_artist': null},
          {'name': 'Harbour Lights', 'year': 2021, 'album_artist': 'Boukmanflow'},
          {'name': 'Harbour Lights', 'year': 2009, 'album_artist': 'The Harbour Band'},
          {'name': 'Old Shape', 'year': 2001},
          {'name': 'Twin', 'year': 2005, 'album_artist': 'Boukmanflow'},
          {'name': 'Twin', 'year': 2006, 'album_artist': 'boukmanflow'},
          {'name': 'Blank', 'year': 2007, 'album_artist': '  '},
          {'name': 'Yearless', 'album_artist': 'Boukmanflow'},
          {'name': 'Sampler', 'year': 2024, 'album_artist': 'Various Artists', 'compilation': true},
          {'name': null, 'album_artist': 'Boukmanflow'},
        ],
      };
      ResolvedCredit r(String album, {int? year, String? hint}) =>
          AlbumCreditResolver.fromArtistAlbums(answer, album: album, year: year, hint: hint);
      expect(r('borrowed tapes', year: 2019), const ResolvedCredit.known('Boukmanflow'));
      expect(r('Borrowed Tapes', year: 2020), ResolvedCredit.unknown, reason: 'outside its years');
      expect(r('Split Series'), ResolvedCredit.disagree);
      expect(r('Harbour Lights'), ResolvedCredit.unknown, reason: 'two of that name: no guess');
      expect(r('Harbour Lights', year: 2021), const ResolvedCredit.known('Boukmanflow'));
      expect(r('Harbour Lights', hint: 'The Harbour Band'), const ResolvedCredit.known('The Harbour Band'),
          reason: "a hint only tells two matches apart");
      expect(r('Harbour Lights', hint: 'Nobody'), ResolvedCredit.unknown);
      expect(r('Harbour Lights', hint: 'Boukmanflow'), const ResolvedCredit.known('Boukmanflow'));
      expect(r('Twin', hint: 'Boukmanflow'), ResolvedCredit.unknown,
          reason: 'a hint naming both of two matches tells them apart no more than none does');
      expect(r('Old Shape'), ResolvedCredit.unknown, reason: 'a server too old to name credits says nothing');
      expect(r('Blank'), ResolvedCredit.disagree, reason: 'a blank credit is no credit');
      expect(r('Yearless', year: 2015), const ResolvedCredit.known('Boukmanflow'),
          reason: 'an album naming no year holds any (as the webapp matches)');
      expect([r('Sampler').credit, r('Sampler').compilation, r('Borrowed Tapes').compilation], ['Various Artists', true, false],
          reason: "the matched album's own word that it is a compilation rides along");
      expect(r('Missing'), ResolvedCredit.unknown);
      expect(AlbumCreditResolver.fromArtistAlbums(null, album: 'x'), ResolvedCredit.unknown);
    });

    test('resolve: the opener, then the songs, then one read of the peer by the first song\'s artist; the answer stored on the album', () async {
      final asked = <(Server, String, Map<String, dynamic>)>[];
      Future<dynamic> post(Server s, String location, Map<String, dynamic> body) async {
        asked.add((s, location, body));
        return {
          'albums': [
            {'name': 'Borrowed Tapes', 'year': 2019, 'album_artist': 'Boukmanflow'},
          ],
        };
      }

      final resolver = AlbumCreditResolver(post: post);
      final listed = albumItem(peer, 'Split Series', state: AlbumCredit.disagree);
      expect(await resolver.resolve(listed, songs(['ALM'])), ResolvedCredit.disagree);
      expect(asked, isEmpty);

      final fromSongs = albumItem(peer, 'Night Market Sampler');
      expect(await resolver.resolve(fromSongs, songs(['Various Artists', 'Various Artists'], artist: 'Color Out')),
          const ResolvedCredit.known('Various Artists'));
      expect([fromSongs.creditState, fromSongs.albumArtist], [AlbumCredit.known, 'Various Artists'], reason: 'Back reuses it');
      expect(asked, isEmpty);

      final hit = albumItem(peer, 'Borrowed Tapes')..yearHint = 2019;
      expect(await resolver.resolve(hit, songs([null, null])), const ResolvedCredit.known('Boukmanflow'));
      expect(asked.single.$2, '/api/v1/db/artists-albums');
      expect(asked.single.$3, {'artist': 'Boukmanflow'});
      expect(identical(asked.single.$1, peer), isTrue, reason: 'asked of the connected server');
      expect(hit.creditState, AlbumCredit.known);
    });

    test("resolve: the list's word that the album is a compilation is stored with its credit", () async {
      final resolver = AlbumCreditResolver(post: (_, _, _) async => {
            'albums': [
              {'name': 'Night Market Sampler', 'year': 2024, 'album_artist': 'Various Artists', 'compilation': true},
            ],
          });
      final hit = albumItem(peer, 'Night Market Sampler')..yearHint = 2024;
      await resolver.resolve(hit, songs([null], artist: 'Color Out'));
      expect([hit.albumArtist, hit.compilation], ['Various Artists', true]);
    });

    test('resolve: a failed read, or no answer in 8 s, is unknown', () async {
      final failing = AlbumCreditResolver(post: (_, _, _) async => throw Exception('down'));
      final a = albumItem(peer, 'Borrowed Tapes');
      expect(await failing.resolve(a, songs([null])), ResolvedCredit.unknown);
      expect(a.creditState, AlbumCredit.unknown);
      final never = Completer<dynamic>();
      final slow = AlbumCreditResolver(post: (_, _, _) => never.future, timeout: const Duration(milliseconds: 10));
      expect(await slow.resolve(albumItem(peer, 'Borrowed Tapes'), songs([null])), ResolvedCredit.unknown);
      expect(await slow.resolve(albumItem(peer, 'Borrowed Tapes'), const []), ResolvedCredit.unknown,
          reason: 'no song to name an artist: nothing to ask');
    });
  });

  group('what the Keep sheet is opened with', () {
    test('an album: the page pill leaves out Open album; a card is V-item; no request without a credit', () {
      final tapes = albumItem(peer, 'Borrowed Tapes', credit: 'Boukmanflow', state: AlbumCredit.known, year: 2019);
      final page = BrowseKeepRequest.album(tapes, variant: KeepVariant.page)!;
      expect([page.subject, page.variant, page.hidden, page.initialScope, page.compilation, page.peerName, page.peerId],
          [KeepSubject.album, KeepVariant.page, {KeepHiddenLink.openAlbum}, 'album', false, 'Stage Peer B', 1]);
      expect(identical(page.own, own), isTrue, reason: "the jobs, gate and destination are the parent's");
      expect(page.focusKey, '1|album|Borrowed Tapes|Boukmanflow');
      expect(page.lead.containsKey('compilation'), isFalse);
      final card = BrowseKeepRequest.album(tapes, variant: KeepVariant.item)!;
      expect([card.hidden, card.lead['compilation']], [isEmpty, false]);
      expect(BrowseKeepRequest.album(albumItem(peer, 'Split Series', state: AlbumCredit.disagree), variant: KeepVariant.page), isNull);
    });

    test('a song from an explorer row carries its Folder chip; an artist its page\'s own answer; a folder its FolderRef; a queued track its server', () {
      final row = fileRow(peer, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', tags('Late Train Verse'));
      final song = BrowseKeepRequest.song(row, folder: FolderRef.parentOf(row.data))!;
      expect([song.subject, song.variant, song.folder!.name, song.initialScope, song.focusKey],
          [KeepSubject.song, KeepVariant.menu, 'Borrowed Tapes', 'song', '1|song|music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3']);
      expect(song.discoveryLead.title, 'Late Train Verse');

      // The song's own album-artist: the sheet's candidate off an album page;
      // on one, the page's word alone.
      final split = fileRow(peer, '/music/ALM/Split Series/01.mp3', tags('One', artist: 'ALM', album: 'Split Series', albumArtist: 'ALM'));
      final recent = BrowseKeepRequest.song(split)!;
      expect([recent.songCredit, recent.pageCredit, recent.lead.containsKey('albumArtist')], ['ALM', null, false]);
      final onPage = BrowseKeepRequest.song(split, pageCredit: AlbumCredit.disagree)!;
      expect([onPage.songCredit, onPage.pageCredit, onPage.lead.containsKey('albumArtist')], [null, AlbumCredit.disagree, false]);
      final known = BrowseKeepRequest.song(split, albumCredit: 'Split Crew', pageCredit: AlbumCredit.known)!;
      expect([known.songCredit, known.pageCredit, known.lead['albumArtist']], [null, null, 'Split Crew']);
      final resolving = BrowseKeepRequest.song(split, pageCredit: null)!;
      expect(resolving.songCredit, 'ALM', reason: 'a page still resolving lets the sheet find the credit');

      final ctx = ArtistContext(server: peer, name: 'Boukmanflow', albums: const [
        {'name': 'Borrowed Tapes', 'album_artist': 'Boukmanflow'},
        {'name': null, 'album_artist': 'Boukmanflow'},
      ]);
      final artist = BrowseKeepRequest.artistPage(ctx)!;
      expect([artist.subject, artist.variant, artist.hidden, identical(artist.artist, ctx), artist.focusKey],
          [KeepSubject.artist, KeepVariant.page, isEmpty, true, '1|artist|Boukmanflow']);
      expect([ctx.albumCount, ctx.namesCredits], [1, true]);

      final f = FolderRef.of('/music/Boukmanflow/Borrowed Tapes')!;
      final folder = BrowseKeepRequest.ofFolder(f, peer, variant: KeepVariant.menu)!;
      expect([folder.subject, folder.initialScope, folder.lead['filepath'], folder.focusKey],
          [KeepSubject.folder, 'folder', 'music/Boukmanflow/Borrowed Tapes', '1|folder|/music/Boukmanflow/Borrowed Tapes']);
      expect(BrowseKeepRequest.ofFolder(f, own, variant: KeepVariant.page), isNull);

      final queued = BrowseKeepRequest.queued(
          MediaItem(id: 'x', title: 'Rooftop Cypher', extras: {'server': 'peer-1', 'path': '/music/r.mp3', 'artist': 'Boukmanflow'}), peer)!;
      expect([queued.subject, queued.variant, queued.lead['filepath']], [KeepSubject.song, KeepVariant.menu, 'music/r.mp3']);
    });
  });
}
