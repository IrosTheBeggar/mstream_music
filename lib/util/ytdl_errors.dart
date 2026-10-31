import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'ytdl_api.dart';

/// Why a lookup, an add or a folder-make failed, as the screen words it
/// (design spec §8 "States"). Decided by the status and the server's
/// `{error}` text only — the routes carry no error codes.
enum YtdlProblem {
  /// "yt-dlp is not installed" (6.30+) · "Error - failed to find yt-dlp"
  /// (6.29 and older).
  ytdlpMissing,

  /// The add's 500 "FFmpeg is not available yet": the ping said ready and the
  /// route disagreed. The caller re-pings.
  ffmpegNotReady,

  /// The add's 403 ("Uploading Disabled").
  uploadsOff,

  /// mkdir's 403 ("Create Folder Disabled").
  mkdirOff,

  /// The folder an add needed could not be made — any mkdir failure but a
  /// 403, a lost library or no connection (spec §8 "mkdir failed": "Couldn't
  /// make the folder “Discovery”." with Try again and Choose a folder…).
  /// Set by the hub, never by a classifier; [YtdlFailure.detail] is the
  /// folder's name.
  mkdirFailed,

  /// A 404 with the server's words: the library named in the folder is gone,
  /// or this account lost it ("Library 'X' not found" / "User does not have
  /// access to path X"). [YtdlFailure.detail] is the library's name when the
  /// words name it.
  libraryGone,

  /// A 404 with no `{error}`: the server has no such route (Express's own
  /// HTML page). Every supported server has the YouTube routes, so this is
  /// practically unreachable — but it must not read as a lost library.
  noRoute,

  /// The add's 400 naming `outputCodec`: the server turned the format off.
  /// The remembered format resets.
  badFormat,

  /// Any other Joi 400 (its message starts with the quoted field) or the
  /// "missing video ID" 400. Raw Joi text is never shown.
  badRequest,

  /// A bare 500 "Server Error" from the add or mkdir (an unhandled throw:
  /// for the add, most likely a folder that is not there).
  serverError,

  /// The lookup's 500 "Server Error": yt-dlp exited non-zero (private,
  /// age-restricted, blocked for the server). The route keeps the reason.
  lookupFailed,

  /// The client's bound ran out.
  timedOut,

  /// No answer at all, not a timeout.
  offline,

  /// Anything else: shown as "The server said: “…”" with
  /// [YtdlFailure.detail].
  other,
}

/// A classified failure. [detail] is the words to quote for
/// [YtdlProblem.other] — the server's `{error}`, or `HTTP <status>` when it
/// sent none; null only for something that was not an answer at all (a
/// thrown error that is not a [YtdlApiException]). For
/// [YtdlProblem.libraryGone] it is the library's name when the server's
/// words carry it; for [YtdlProblem.mkdirFailed] the folder's name; null
/// for every other problem.
class YtdlFailure {
  final YtdlProblem problem;
  final String? detail;

  const YtdlFailure(this.problem, [this.detail]);

  @override
  bool operator ==(Object other) =>
      other is YtdlFailure && other.problem == problem && other.detail == detail;

  @override
  int get hashCode => Object.hash(problem, detail);

  @override
  String toString() =>
      'YtdlFailure(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// [error] from [YtdlApi.add] (POST /api/v1/ytdl/).
YtdlFailure classifyYtdlAdd(Object error) {
  final api = _answered(error);
  if (api == null) return _unanswered(error);
  if (_ytdlpMissing(api)) return const YtdlFailure(YtdlProblem.ytdlpMissing);
  switch (api.status) {
    case 403:
      return const YtdlFailure(YtdlProblem.uploadsOff);
    case 404:
      return _notFound(api);
    case 400:
      if (api.message.contains('outputCodec')) {
        return const YtdlFailure(YtdlProblem.badFormat);
      }
      return _badRequest(api);
    case 500:
      if (_ffmpegNotReady(api)) {
        return const YtdlFailure(YtdlProblem.ffmpegNotReady);
      }
      if (_bareServerError(api)) {
        return const YtdlFailure(YtdlProblem.serverError);
      }
  }
  return _other(api);
}

/// [error] from [YtdlApi.metadata] (GET /api/v1/ytdl/metadata). The route
/// has no upload or ffmpeg gate, so a 403 or a 404 with words is quoted.
YtdlFailure classifyYtdlLookup(Object error) {
  final api = _answered(error);
  if (api == null) return _unanswered(error);
  if (_ytdlpMissing(api)) return const YtdlFailure(YtdlProblem.ytdlpMissing);
  if (api.status == 404 && !api.fromServer) {
    return const YtdlFailure(YtdlProblem.noRoute);
  }
  // Any 400 here is about the link: the query takes nothing else.
  if (api.status == 400) return const YtdlFailure(YtdlProblem.badRequest);
  // yt-dlp exiting non-zero is a plain throw on the server; a 500 without
  // words, or a 200 this client could not read, reads the same way.
  if ((api.status == 500 && _bareServerError(api)) ||
      (api.status >= 200 && api.status <= 299)) {
    return const YtdlFailure(YtdlProblem.lookupFailed);
  }
  return _other(api);
}

/// [error] from [YtdlApi.mkdir] (POST /api/v1/file-explorer/mkdir).
YtdlFailure classifyYtdlMkdir(Object error) {
  final api = _answered(error);
  if (api == null) return _unanswered(error);
  switch (api.status) {
    case 403:
      return const YtdlFailure(YtdlProblem.mkdirOff);
    case 404:
      return _notFound(api);
    case 400:
      return _badRequest(api);
    case 500:
      // A file in the way of the folder.
      if (_bareServerError(api)) {
        return const YtdlFailure(YtdlProblem.serverError);
      }
  }
  return _other(api);
}

/// [error] when it is the server's answer; null when there was none.
YtdlApiException? _answered(Object error) =>
    error is YtdlApiException && !error.timedOut && error.status != 0
        ? error
        : null;

/// The failures every route shares: no answer, or not an answer at all.
YtdlFailure _unanswered(Object error) {
  if (error is YtdlApiException) {
    return YtdlFailure(
        error.timedOut ? YtdlProblem.timedOut : YtdlProblem.offline);
  }
  // YtdlApi wraps its transport's throws; these are here for a caller that
  // did not go through it.
  if (error is TimeoutException) return const YtdlFailure(YtdlProblem.timedOut);
  if (error is SocketException || error is http.ClientException) {
    return const YtdlFailure(YtdlProblem.offline);
  }
  return const YtdlFailure(YtdlProblem.other);
}

bool _ytdlpMissing(YtdlApiException e) {
  if (!e.fromServer) return false;
  final m = e.message.toLowerCase();
  return m.contains('yt-dlp') &&
      (m.contains('not installed') || m.contains('failed to find'));
}

bool _ffmpegNotReady(YtdlApiException e) =>
    e.fromServer && e.message.toLowerCase().startsWith('ffmpeg is not available');

/// The server's catch-all ("Server Error"), or a 500 with no words at all.
bool _bareServerError(YtdlApiException e) =>
    !e.fromServer || e.message.trim() == 'Server Error';

/// The library name in vpath.js's two 404s.
final RegExp _libraryNotFound = RegExp(r"^Library '(.+)' not found$");
final RegExp _noAccess = RegExp(r'^User does not have access to path (.+)$');

YtdlFailure _notFound(YtdlApiException e) {
  if (!e.fromServer) return const YtdlFailure(YtdlProblem.noRoute);
  final m = e.message.trim();
  final name = (_libraryNotFound.firstMatch(m) ?? _noAccess.firstMatch(m))
      ?.group(1);
  return YtdlFailure(YtdlProblem.libraryGone, name);
}

/// Joi's own message starts with the quoted field (`"url" must be …`,
/// `"metadata.year" must be a string`); the add's sanitizer says "Invalid
/// YouTube URL - missing video ID". A 400 with no words is taken as the
/// same. Anything else — "Not A Directory" — is quoted.
YtdlFailure _badRequest(YtdlApiException e) {
  final m = e.message.trim();
  if (!e.fromServer || m.startsWith('"') || m.contains('missing video ID')) {
    return const YtdlFailure(YtdlProblem.badRequest);
  }
  return _other(e);
}

YtdlFailure _other(YtdlApiException e) => YtdlFailure(YtdlProblem.other,
    e.fromServer ? e.message : 'HTTP ${e.status}');
