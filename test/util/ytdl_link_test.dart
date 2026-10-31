// lib/util/ytdl_link.dart — what a pasted YouTube link is, and the one URL
// the phone sends for it. Each rewrite case of spec §3 "Links are rewritten
// on the phone" and each panel of the LinkStates board has a test here.
//
// The URL the phone sends must be one the server's sanitizeYoutubeUrl()
// (mStream src/api/ytdl.js) leaves untouched, so the job list's `url` and
// the download record's `origin` match it by string equality. Every
// expected URL below was checked against the server's own code under Node
// (new URL(), the route's host rule and sanitizeYoutubeUrl): each is a
// fixed point of it, and for a watch link the server would take as typed,
// it is also exactly what the server makes of the raw input. [sanitize]
// mirrors that function on Dart's Uri so the property is asserted here too.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/ytdl_link.dart';

/// mStream's sanitizeYoutubeUrl: scheme, host, port, path and fragment kept,
/// the query replaced by its first `v` (Uri, like the WHATWG parser,
/// lower-cases the host and drops a default port).
String sanitize(String url) {
  final u = Uri.parse(url);
  final v = u.queryParametersAll['v']?.first;
  if (v == null || v.isEmpty) {
    throw const FormatException('Invalid YouTube URL - missing video ID');
  }
  return u.replace(queryParameters: {'v': v}).toString();
}

/// The server's host rule (youtubeUrlSchema): youtube.com, a subdomain of
/// it, or youtu.be.
bool serverTakesHost(String url) {
  final host = Uri.parse(url).host;
  return host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtu.be';
}

void expectVideo(
  String input, {
  required String url,
  required String id,
  bool shortForm = false,
  bool schemeAdded = false,
  bool live = false,
  bool inPlaylist = false,
}) {
  final link = parseYtdlLink(input);
  expect(link.kind, YtdlLinkKind.video, reason: input);
  expect(link.url, url, reason: input);
  expect(link.videoId, id, reason: input);
  expect(link.shortForm, shortForm, reason: '$input shortForm');
  expect(link.schemeAdded, schemeAdded, reason: '$input schemeAdded');
  expect(link.live, live, reason: '$input live');
  expect(link.inPlaylist, inPlaylist, reason: '$input inPlaylist');
  expect(serverTakesHost(url), isTrue, reason: '$url passes the route');
  expect(sanitize(url), url, reason: '$url is what the server records');
}

void main() {
  group('nothing, or not a video', () {
    test('empty and whitespace are empty', () {
      expect(parseYtdlLink('').kind, YtdlLinkKind.empty);
      expect(parseYtdlLink('   \n\t').kind, YtdlLinkKind.empty);
      expect(parseYtdlLink('').url, isNull);
      expect(parseYtdlLink('').shown, '');
    });

    test('LinkStates 1: another site is not a YouTube link', () {
      final link = parseYtdlLink('https://vimeo.com/76979871');
      expect(link.kind, YtdlLinkKind.notYoutube);
      expect(link.url, isNull);
      expect(link.videoId, isNull);
      expect(parseYtdlLink('just some words').kind, YtdlLinkKind.notYoutube);
    });

    test('a look-alike host is not YouTube', () {
      for (final input in [
        'https://notyoutube.com/watch?v=FGBhQbmPwH8',
        'https://youtube.com.evil.example/watch?v=FGBhQbmPwH8',
        'https://evil.example/youtube.com/watch?v=FGBhQbmPwH8',
        'https://youtube.co/watch?v=FGBhQbmPwH8',
      ]) {
        expect(parseYtdlLink(input).kind, YtdlLinkKind.notYoutube,
            reason: input);
      }
    });

    test('a YouTube page that names no video is notYoutube', () {
      for (final input in [
        'https://www.youtube.com/',
        'https://www.youtube.com/@daftpunk',
        'https://www.youtube.com/channel/UCx',
        'https://youtu.be/',
        'youtube.com',
      ]) {
        expect(parseYtdlLink(input).kind, YtdlLinkKind.notYoutube,
            reason: input);
      }
    });

    test('a video id must be six or more of A–Z a–z 0–9 _ -', () {
      expect(parseYtdlLink('https://www.youtube.com/watch?v=abc').kind,
          YtdlLinkKind.notYoutube);
      expect(parseYtdlLink('https://www.youtube.com/watch?v=FGBh%20QbmPwH8').kind,
          YtdlLinkKind.notYoutube);
      expect(parseYtdlLink('https://youtu.be/ab*cdef').kind,
          YtdlLinkKind.notYoutube);
      expect(parseYtdlLink('https://www.youtube.com/watch?v=').kind,
          YtdlLinkKind.notYoutube);
      expectVideo('https://www.youtube.com/watch?v=abc_-1',
          url: 'https://www.youtube.com/watch?v=abc_-1', id: 'abc_-1');
    });

    test('LinkStates 4: a playlist with no video is a playlist', () {
      final link = parseYtdlLink(
          'https://www.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG');
      expect(link.kind, YtdlLinkKind.playlist);
      expect(link.url, isNull);
      expect(link.shown, '');
      expect(parseYtdlLink('https://www.youtube.com/watch?list=PLx0sYbCqOb8T').kind,
          YtdlLinkKind.playlist);
      expect(parseYtdlLink('https://music.youtube.com/playlist?list=OLAK5uy_k').kind,
          YtdlLinkKind.playlist);
      expect(parseYtdlLink('https://www.youtube.com/playlist').kind,
          YtdlLinkKind.notYoutube);
    });
  });

  group('watch links keep their scheme and host', () {
    test('a plain watch link goes as it is', () {
      expectVideo('https://www.youtube.com/watch?v=FGBhQbmPwH8',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
      expectVideo('https://www.youtube.com/watch?v=GCdwKhTtNNw',
          url: 'https://www.youtube.com/watch?v=GCdwKhTtNNw', id: 'GCdwKhTtNNw');
    });

    test('music.youtube.com keeps its host, and loses si=', () {
      expectVideo('https://music.youtube.com/watch?v=FGBhQbmPwH8&si=Rk3vT0',
          url: 'https://music.youtube.com/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
      expectVideo('https://m.youtube.com/watch?v=HyHNuVaZJ-k',
          url: 'https://m.youtube.com/watch?v=HyHNuVaZJ-k', id: 'HyHNuVaZJ-k');
    });

    test('http stays http', () {
      expectVideo('http://www.youtube.com/watch?v=FGBhQbmPwH8',
          url: 'http://www.youtube.com/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
    });

    test('the host is lower-cased and the default port dropped, as new URL() does', () {
      expectVideo('https://WWW.YouTube.com:443/watch?v=FGBhQbmPwH8&t=42s#frag',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
      expectVideo('http://youtube.com:80/watch?v=FGBhQbmPwH8',
          url: 'http://youtube.com/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
      expectVideo('https://youtube.com:8443/watch?v=FGBhQbmPwH8',
          url: 'https://youtube.com:8443/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
    });

    test('only v is kept, the first one, wherever it stands', () {
      expectVideo(
          'https://www.youtube.com/watch?feature=share&v=FGBhQbmPwH8&t=1',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8');
      expectVideo('https://www.youtube.com/watch?v=FGBhQbmPwH8&v=other12345',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
    });

    test('/watch/ with a trailing slash goes as /watch', () {
      expectVideo('https://www.youtube.com/watch/?v=HyHNuVaZJ-k',
          url: 'https://www.youtube.com/watch?v=HyHNuVaZJ-k', id: 'HyHNuVaZJ-k');
    });

    test('a watch link the server would take as typed comes out as the server makes it', () {
      for (final input in [
        'https://www.youtube.com/watch?v=FGBhQbmPwH8',
        'https://music.youtube.com/watch?v=FGBhQbmPwH8&si=Rk3vT0',
        'http://www.youtube.com/watch?v=FGBhQbmPwH8',
        'http://youtube.com:80/watch?v=FGBhQbmPwH8',
        'https://youtube.com:8443/watch?v=FGBhQbmPwH8',
        'https://www.youtube.com/watch?feature=share&v=FGBhQbmPwH8&list=PL123',
        'https://www.youtube.com/watch?v=FGBhQbmPwH8&v=other12345',
        'https://m.youtube.com/watch?v=HyHNuVaZJ-k',
      ]) {
        expect(parseYtdlLink(input).url, sanitize(input), reason: input);
      }
    });

    test('LinkStates 5: a video in a playlist is just the video', () {
      expectVideo('https://www.youtube.com/watch?v=FGBhQbmPwH8&list=OLAK5uy_kVQ2',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          inPlaylist: true);
      expectVideo('https://youtu.be/FGBhQbmPwH8?list=OLAK5uy_kVQ2',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true,
          inPlaylist: true);
    });
  });

  group('short forms are rewritten to a watch link', () {
    test('LinkStates 2: youtu.be/ID (si= and all) → www.youtube.com/watch?v=ID', () {
      expectVideo('https://youtu.be/FGBhQbmPwH8?si=Rk3vT0',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true);
      expect(parseYtdlLink('https://youtu.be/FGBhQbmPwH8?si=Rk3vT0').shown,
          'youtube.com/watch?v=FGBhQbmPwH8');
      expectVideo('https://youtu.be/HyHNuVaZJ-k?si=a81Bq',
          url: 'https://www.youtube.com/watch?v=HyHNuVaZJ-k',
          id: 'HyHNuVaZJ-k',
          shortForm: true);
      // The http short link is sent as https too: it is a new link.
      expectVideo('http://youtu.be/kN0gRuPpa01',
          url: 'https://www.youtube.com/watch?v=kN0gRuPpa01',
          id: 'kN0gRuPpa01',
          shortForm: true);
    });

    test('/shorts/ID, on www or m., goes to www', () {
      expectVideo('https://www.youtube.com/shorts/FGBhQbmPwH8?feature=share',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true);
      expectVideo('https://m.youtube.com/shorts/FGBhQbmPwH8',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true);
    });

    test('LinkStates 6: /live/ID is a live link, rewritten', () {
      expectVideo('https://www.youtube.com/live/jfKfPfyJRdk',
          url: 'https://www.youtube.com/watch?v=jfKfPfyJRdk',
          id: 'jfKfPfyJRdk',
          shortForm: true,
          live: true);
      expectVideo('https://www.youtube.com/live/jfKfPfyJRdk?si=x',
          url: 'https://www.youtube.com/watch?v=jfKfPfyJRdk',
          id: 'jfKfPfyJRdk',
          shortForm: true,
          live: true);
    });

    test('/embed/ID and youtube-nocookie.com/embed/ID', () {
      expectVideo('https://www.youtube.com/embed/FGBhQbmPwH8?start=10',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true);
      expectVideo('https://www.youtube-nocookie.com/embed/FGBhQbmPwH8',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true);
      // The server refuses the nocookie host, so the link must change.
      expect(serverTakesHost('https://www.youtube-nocookie.com/embed/x'), isFalse);
    });
  });

  group('the first link in what was pasted, with or without a scheme', () {
    test('LinkStates 3: typed without https → scheme added, host lower-cased', () {
      final link = parseYtdlLink('YouTube.com/watch?v=FGBhQbmPwH8');
      expectVideo('YouTube.com/watch?v=FGBhQbmPwH8',
          url: 'https://youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          schemeAdded: true);
      expect(link.shown, 'youtube.com/watch?v=FGBhQbmPwH8');
    });

    test('youtu.be/ID typed bare is short and scheme-added', () {
      expectVideo('youtu.be/FGBhQbmPwH8',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true,
          schemeAdded: true);
      expectVideo('www.youtube.com/watch?v=FGBhQbmPwH8',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          schemeAdded: true);
    });

    test('a share message: the link is found, the full stop after it is not part of it', () {
      expectVideo('Check this out https://youtu.be/HyHNuVaZJ-k?si=a81Bq. so good',
          url: 'https://www.youtube.com/watch?v=HyHNuVaZJ-k',
          id: 'HyHNuVaZJ-k',
          shortForm: true);
      expectVideo('(https://www.youtube.com/watch?v=FGBhQbmPwH8)',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8', id: 'FGBhQbmPwH8');
      expectVideo('  https://youtu.be/FGBhQbmPwH8  \n',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true);
    });

    test('the first YouTube link wins, past a link to another site', () {
      expectVideo(
          'https://vimeo.com/1 then https://youtu.be/FGBhQbmPwH8 and https://youtu.be/HyHNuVaZJ-k',
          url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
          id: 'FGBhQbmPwH8',
          shortForm: true);
    });
  });

  group('shown, for the helper line', () {
    test('host minus www., no scheme', () {
      expect(parseYtdlLink('https://www.youtube.com/watch?v=FGBhQbmPwH8').shown,
          'youtube.com/watch?v=FGBhQbmPwH8');
      expect(parseYtdlLink('https://music.youtube.com/watch?v=FGBhQbmPwH8').shown,
          'music.youtube.com/watch?v=FGBhQbmPwH8');
      expect(parseYtdlLink('https://youtube.com:8443/watch?v=FGBhQbmPwH8').shown,
          'youtube.com:8443/watch?v=FGBhQbmPwH8');
      expect(parseYtdlLink('https://www.youtube.com/live/jfKfPfyJRdk').shown,
          'youtube.com/watch?v=jfKfPfyJRdk');
      expect(parseYtdlLink('https://vimeo.com/76979871').shown, '');
    });
  });
}
