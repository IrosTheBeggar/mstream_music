// How a failed lookup, add or folder-make is read (design spec §8 "Errors"
// and the build plan's YtdlProblem table): by status and the server's
// `{error}` text, exactly as mStream words them (src/api/ytdl.js,
// src/util/vpath.js, src/api/file-explorer.js, the Joi messages, the
// terminal "Server Error" handler) — and for the older servers' wording
// ("Error - failed to find yt-dlp"). A JSON 404 (a lost library) is told
// from Express's own HTML 404 (no such route); no answer is a timeout or
// offline; anything unrecognised is quoted.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mstream_music/util/ytdl_api.dart';
import 'package:mstream_music/util/ytdl_errors.dart';

/// The server's answer with its words.
YtdlApiException said(int status, String words) =>
    YtdlApiException(status, words, fromServer: true);

/// An answer with no `{error}` (an HTML page, an empty body).
YtdlApiException bare(int status) => YtdlApiException(status, '');

const timedOut = YtdlApiException(0, '', timedOut: true);
const noAnswer = YtdlApiException(0, '');

const f = YtdlFailure.new;

void main() {
  group('the add', () {
    final rows = <(YtdlApiException, YtdlFailure)>[
      // yt-dlp: 6.30+ wording and the older one.
      (said(500, 'yt-dlp is not installed'), f(YtdlProblem.ytdlpMissing)),
      (said(500, 'Error - failed to find yt-dlp'), f(YtdlProblem.ytdlpMissing)),
      // The stale-flag fallback.
      (said(500, 'FFmpeg is not available yet'), f(YtdlProblem.ffmpegNotReady)),
      // Uploads off: the two gates, and the federation wall.
      (said(403, 'Uploading Disabled'), f(YtdlProblem.uploadsOff)),
      (said(403, 'Forbidden'), f(YtdlProblem.uploadsOff)),
      // A 404 naming the library (vpath.js), with the name pulled out.
      (said(404, "Library 'Music' not found"), f(YtdlProblem.libraryGone, 'Music')),
      (said(404, 'User does not have access to path Music'),
          f(YtdlProblem.libraryGone, 'Music')),
      (said(404, "Library 'Old Vinyl' not found"),
          f(YtdlProblem.libraryGone, 'Old Vinyl')),
      (said(404, 'something else not found'), f(YtdlProblem.libraryGone)),
      // Express's own 404: no such route.
      (bare(404), f(YtdlProblem.noRoute)),
      // A format the server turned off: Joi names the field.
      (said(400, '"outputCodec" must be one of [mp3, flac, wav, ogg, aac, m4a, m4b, opus]'),
          f(YtdlProblem.badFormat)),
      // Every other validation 400, and the sanitizer's.
      (said(400, '"url" must be a valid uri with a scheme matching the http|https pattern'),
          f(YtdlProblem.badRequest)),
      (said(400, '"url" failed custom validation because URL must be a YouTube link'),
          f(YtdlProblem.badRequest)),
      (said(400, '"url" is required'), f(YtdlProblem.badRequest)),
      (said(400, '"metadata.year" must be a string'), f(YtdlProblem.badRequest)),
      (said(400, '"foo" is not allowed'), f(YtdlProblem.badRequest)),
      (said(400, 'Invalid YouTube URL - missing video ID'), f(YtdlProblem.badRequest)),
      (bare(400), f(YtdlProblem.badRequest)),
      // A 400 that is not about the request's shape is quoted.
      (said(400, 'Not A Directory'), f(YtdlProblem.other, 'Not A Directory')),
      // The catch-all: most likely a folder that is not there.
      (said(500, 'Server Error'), f(YtdlProblem.serverError)),
      (bare(500), f(YtdlProblem.serverError)),
      // Anything else is quoted — the server's words, or the status.
      (said(500, 'disk full'), f(YtdlProblem.other, 'disk full')),
      (said(429, 'slow down'), f(YtdlProblem.other, 'slow down')),
      (bare(502), f(YtdlProblem.other, 'HTTP 502')),
      (timedOut, f(YtdlProblem.timedOut)),
      (noAnswer, f(YtdlProblem.offline)),
    ];
    for (final (e, want) in rows) {
      test('${e.status} “${e.message}” → $want', () {
        expect(classifyYtdlAdd(e), want);
      });
    }
  });

  group('the lookup', () {
    final rows = <(YtdlApiException, YtdlFailure)>[
      (said(500, 'yt-dlp is not installed'), f(YtdlProblem.ytdlpMissing)),
      (said(500, 'Error - failed to find yt-dlp'), f(YtdlProblem.ytdlpMissing)),
      // yt-dlp exited non-zero: the route keeps the reason.
      (said(500, 'Server Error'), f(YtdlProblem.lookupFailed)),
      (bare(500), f(YtdlProblem.lookupFailed)),
      // A 200 this client could not read.
      (bare(200), f(YtdlProblem.lookupFailed)),
      // Any 400 is about the link.
      (said(400, 'Invalid YouTube URL - missing video ID'), f(YtdlProblem.badRequest)),
      (said(400, '"url" is required'), f(YtdlProblem.badRequest)),
      (said(400, '"url" failed custom validation because URL must be a YouTube link'),
          f(YtdlProblem.badRequest)),
      (bare(400), f(YtdlProblem.badRequest)),
      (bare(404), f(YtdlProblem.noRoute)),
      // The lookup has no upload gate and names no library: quoted.
      (said(403, 'Forbidden'), f(YtdlProblem.other, 'Forbidden')),
      (said(404, "Library 'Music' not found"),
          f(YtdlProblem.other, "Library 'Music' not found")),
      (said(500, 'FFmpeg is not available yet'),
          f(YtdlProblem.other, 'FFmpeg is not available yet')),
      (bare(503), f(YtdlProblem.other, 'HTTP 503')),
      (timedOut, f(YtdlProblem.timedOut)),
      (noAnswer, f(YtdlProblem.offline)),
    ];
    for (final (e, want) in rows) {
      test('${e.status} “${e.message}” → $want', () {
        expect(classifyYtdlLookup(e), want);
      });
    }
  });

  group('mkdir', () {
    final rows = <(YtdlApiException, YtdlFailure)>[
      (said(403, 'Create Folder Disabled'), f(YtdlProblem.mkdirOff)),
      (said(404, "Library 'Music' not found"), f(YtdlProblem.libraryGone, 'Music')),
      (said(404, 'User does not have access to path Music'),
          f(YtdlProblem.libraryGone, 'Music')),
      (bare(404), f(YtdlProblem.noRoute)),
      // A file in the way of the folder.
      (said(500, 'Server Error'), f(YtdlProblem.serverError)),
      (bare(500), f(YtdlProblem.serverError)),
      (said(400, '"directory" is required'), f(YtdlProblem.badRequest)),
      (said(500, 'EACCES'), f(YtdlProblem.other, 'EACCES')),
      (timedOut, f(YtdlProblem.timedOut)),
      (noAnswer, f(YtdlProblem.offline)),
    ];
    for (final (e, want) in rows) {
      test('${e.status} “${e.message}” → $want', () {
        expect(classifyYtdlMkdir(e), want);
      });
    }
  });

  group('words are matched as the server sends them', () {
    test('yt-dlp texts are matched loosely, other words exactly', () {
      expect(classifyYtdlAdd(said(500, 'YT-DLP is not installed')),
          f(YtdlProblem.ytdlpMissing));
      expect(classifyYtdlAdd(said(500, '  Server Error  ')),
          f(YtdlProblem.serverError));
      expect(classifyYtdlAdd(said(500, 'Server Error: boom')),
          f(YtdlProblem.other, 'Server Error: boom'));
    });

    test('a status-less body never reads as a server sentence', () {
      // An HTML 500 that happens to mention yt-dlp is not the route speaking.
      expect(classifyYtdlLookup(const YtdlApiException(500, '')),
          f(YtdlProblem.lookupFailed));
      expect(classifyYtdlAdd(const YtdlApiException(403, '')),
          f(YtdlProblem.uploadsOff));
    });
  });

  group('errors that did not come through YtdlApi', () {
    test('a raw timeout, socket or client failure', () {
      for (final classify in [classifyYtdlAdd, classifyYtdlLookup, classifyYtdlMkdir]) {
        expect(classify(TimeoutException('slow')), f(YtdlProblem.timedOut));
        expect(classify(const SocketException('no route')), f(YtdlProblem.offline));
        expect(classify(http.ClientException('reset')), f(YtdlProblem.offline));
      }
    });

    test('anything else is "other" with no words to quote', () {
      expect(classifyYtdlAdd(StateError('bug')), f(YtdlProblem.other));
      expect(classifyYtdlAdd(StateError('bug')).detail, isNull);
    });
  });

  test('a failure equals another with the same problem and detail', () {
    expect(f(YtdlProblem.libraryGone, 'Music'), f(YtdlProblem.libraryGone, 'Music'));
    expect(f(YtdlProblem.libraryGone, 'Music'),
        isNot(f(YtdlProblem.libraryGone, 'Jazz')));
    expect(f(YtdlProblem.other).hashCode, f(YtdlProblem.other).hashCode);
    expect('${f(YtdlProblem.other, 'x')}', 'YtdlFailure(other: x)');
  });
}
