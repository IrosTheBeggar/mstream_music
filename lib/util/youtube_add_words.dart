/// A YouTube add's own words, read into what the phone shows: the youtube
/// plug-in's status lines and failure sentences (mStream
/// src/discovery-plugins/plugins/youtube.js run(), src/util/yt-dlp.js
/// startDownload and failureReason, src/discovery-plugins/destination.js
/// destinationForJob and renderTarget), the jobs route's queue-cap 429, and
/// two ports the phone needs before it asks anything: the link check a
/// chosen upload must pass (youtube.js isYouTubeUrl) and the phrase the
/// search asks for (src/discovery-plugins/recommendation.js searchPhrase).
///
/// Pure: no Flutter, no I/O. The l10n side is
/// screens/discovery/youtube_add_ui.dart. The server's texts carry no codes,
/// so these read its sentences; a sentence none of them knows keeps the
/// server's own words (a step) or reads as "Something went wrong" with the
/// words under Details (a failure).
library;

/// A running YouTube add's step, from its `statusText`.
enum YoutubeStep {
  /// "reading the chosen upload": the pick's full record is fetched.
  checking,

  /// "searching YouTube for “…”": a job started without a pick.
  searching,

  /// "downloading “…” from …", then "42% of “…”".
  fetching,

  /// "tagging".
  tagging,

  /// "adding to your library".
  filing,
}

final RegExp _searching = RegExp(r'^searching YouTube for ', caseSensitive: false);
final RegExp _downloading = RegExp(r'^downloading “', caseSensitive: false);
final RegExp _percentOf = RegExp(r'^(\d{1,3})% of “', caseSensitive: false);

/// The step a running add's [statusText] names, and — while fetching — the
/// percentage its text carries ("42% of “…”", 0–100). A step of null is a
/// text this port does not know (a newer server): the line shows it as the
/// server wrote it.
({YoutubeStep? step, int? percent}) youtubeStepOf(String? statusText) {
  final t = (statusText ?? '').trim();
  final lower = t.toLowerCase();
  if (lower == 'reading the chosen upload') {
    return (step: YoutubeStep.checking, percent: null);
  }
  if (_searching.hasMatch(t)) return (step: YoutubeStep.searching, percent: null);
  if (_downloading.hasMatch(t)) return (step: YoutubeStep.fetching, percent: null);
  final pct = _percentOf.firstMatch(t);
  if (pct != null) {
    return (
      step: YoutubeStep.fetching,
      percent: int.parse(pct[1]!).clamp(0, 100),
    );
  }
  if (lower == 'tagging') return (step: YoutubeStep.tagging, percent: null);
  if (lower == 'adding to your library') {
    return (step: YoutubeStep.filing, percent: null);
  }
  return (step: null, percent: null);
}

/// Why a YouTube add failed, as the job line words it.
enum YoutubeFailureKind {
  /// yt-dlp or ffmpeg is missing on the server.
  broken,

  /// The search's best upload scored under the bar ([YoutubeFailure.percent]).
  notClose,

  /// The search found nothing ([YoutubeFailure.query]).
  noResults,

  /// The pick is a live stream.
  live,

  /// The upload is past the server's size cap ([YoutubeFailure.sizeMb] when
  /// the words name it).
  tooBig,

  /// The pick could not be read, or YouTube no longer serves it.
  unreadable,

  /// The download ran past the server's 30 minutes.
  tooLong,

  /// YouTube refused the download (a bot check, rate limiting, a yt-dlp too
  /// old for YouTube's player, an exit with no file).
  refused,

  /// The recommendation has no artist or title to search for.
  noTitle,

  /// The account lost its upload right.
  uploadsOff,

  /// No library takes the account's files (any more).
  noLibrary,

  /// The destination's base or layout no longer validates, or rendered an
  /// unusable path for this song.
  layout,

  /// The account that asked was deleted while the job waited.
  accountGone,

  /// Words this port does not know.
  other,
}

/// A failed YouTube add's reason, and what its line offers.
class YoutubeFailure {
  final YoutubeFailureKind kind;

  /// [YoutubeFailureKind.notClose]: the best score, as a whole percentage.
  final int? percent;

  /// [YoutubeFailureKind.noResults]: what was searched for.
  final String? query;

  /// [YoutubeFailureKind.tooBig]: the server's cap in MB, when named.
  final int? sizeMb;

  const YoutubeFailure(this.kind, {this.percent, this.query, this.sizeMb});

  /// Another upload may be the song: the line offers "Choose another" (the
  /// search again, landing on its candidates).
  bool get choosesAnother => switch (kind) {
        YoutubeFailureKind.notClose ||
        YoutubeFailureKind.noResults ||
        YoutubeFailureKind.live ||
        YoutubeFailureKind.tooBig ||
        YoutubeFailureKind.unreadable =>
          true,
        _ => false,
      };

  /// The same start again may work: the line offers Retry. Never for what
  /// only the account or the server's admin can change (no title, no
  /// upload right, no library, a deleted account), nor for a pick that can
  /// never be the song (a live stream, one past the size cap).
  bool get retries => switch (kind) {
        YoutubeFailureKind.broken ||
        YoutubeFailureKind.notClose ||
        YoutubeFailureKind.noResults ||
        YoutubeFailureKind.unreadable ||
        YoutubeFailureKind.tooLong ||
        YoutubeFailureKind.refused ||
        YoutubeFailureKind.layout ||
        YoutubeFailureKind.other =>
          true,
        _ => false,
      };

  @override
  bool operator ==(Object other) =>
      other is YoutubeFailure &&
      other.kind == kind &&
      other.percent == percent &&
      other.query == query &&
      other.sizeMb == sizeMb;

  @override
  int get hashCode => Object.hash(kind, percent, query, sizeMb);

  @override
  String toString() => 'YoutubeFailure($kind, percent: $percent, query: $query, sizeMb: $sizeMb)';
}

RegExp _i(String source) => RegExp(source, caseSensitive: false);

final RegExp _downloadFailed = _i(r'^YouTube download failed: (.*)$');
final RegExp _pickUnread = _i(r'^the chosen upload could not be read: (.*)$');
final RegExp _broken = _i(r'yt-dlp is not installed|ffmpeg is not available');
final RegExp _noTitle = _i(r'no artist or title to search for');
final RegExp _accountGone = _i(r'account that asked for this .*no longer exists');
final RegExp _uploadsOff = _i(r'uploads are disabled');
final RegExp _noLibrary =
    _i(r'no library to download into|may no longer put files into library');
final RegExp _layout = _i(r'layout rendered an unusable path|no longer validates');
final RegExp _notClose = _i(r'^Nothing matched closely enough \(best score ([\d.]+)');
final RegExp _noResults = _i(r'^YouTube returned no results for “(.*)”');
final RegExp _pickLive = _i(r'chosen upload is a live stream');
final RegExp _capMb = _i(r'(\d+)\s*MB size cap');

/// A failed YouTube add's [error] (the job's `error`, the server's
/// sentence) read into its kind.
///
/// The two sentences that wrap yt-dlp's own words — "YouTube download
/// failed: …" and "the chosen upload could not be read: …" — are read
/// first, by what the wrapped words say (yt-dlp.js failureReason), so a
/// video title or a yt-dlp message can never pass for one of the server's
/// own reasons; the rest by the server's sentences, first match wins.
YoutubeFailure youtubeFailureOf(String? error) {
  final e = (error ?? '').trim();
  final failed = _downloadFailed.firstMatch(e);
  if (failed != null) return _downloadFailure(failed[1]!);
  final unread = _pickUnread.firstMatch(e);
  if (unread != null) {
    return _ytdlpReason(unread[1]!) == 'live'
        ? const YoutubeFailure(YoutubeFailureKind.live)
        : const YoutubeFailure(YoutubeFailureKind.unreadable);
  }
  if (_broken.hasMatch(e)) return const YoutubeFailure(YoutubeFailureKind.broken);
  if (_noTitle.hasMatch(e)) return const YoutubeFailure(YoutubeFailureKind.noTitle);
  if (_accountGone.hasMatch(e)) {
    return const YoutubeFailure(YoutubeFailureKind.accountGone);
  }
  if (_uploadsOff.hasMatch(e)) {
    return const YoutubeFailure(YoutubeFailureKind.uploadsOff);
  }
  if (_noLibrary.hasMatch(e)) return const YoutubeFailure(YoutubeFailureKind.noLibrary);
  if (_layout.hasMatch(e)) return const YoutubeFailure(YoutubeFailureKind.layout);
  final close = _notClose.firstMatch(e);
  if (close != null) {
    final score = double.tryParse(close[1]!);
    return YoutubeFailure(
      YoutubeFailureKind.notClose,
      percent: score == null || !score.isFinite
          ? null
          : (score.clamp(0.0, 1.0) * 100).round(),
    );
  }
  final none = _noResults.firstMatch(e);
  if (none != null) {
    return YoutubeFailure(YoutubeFailureKind.noResults, query: none[1]);
  }
  if (_pickLive.hasMatch(e)) return const YoutubeFailure(YoutubeFailureKind.live);
  return const YoutubeFailure(YoutubeFailureKind.other);
}

/// "YouTube download failed: …": the words after the colon are startDownload's
/// own refusals (the size cap, the 30-minute clock, a live stream) or
/// yt-dlp's error line.
YoutubeFailure _downloadFailure(String inner) {
  switch (_ytdlpReason(inner)) {
    case 'too-big':
      final mb = _capMb.firstMatch(inner);
      return YoutubeFailure(YoutubeFailureKind.tooBig,
          sizeMb: mb == null ? null : int.tryParse(mb[1]!));
    case 'too-long':
      return const YoutubeFailure(YoutubeFailureKind.tooLong);
    case 'live':
      return const YoutubeFailure(YoutubeFailureKind.live);
    case 'unavailable':
      return const YoutubeFailure(YoutubeFailureKind.unreadable);
    default:
      return const YoutubeFailure(YoutubeFailureKind.refused);
  }
}

final RegExp _ytServerSide = _i(
    r'not a bot|rate-?limited|try again later|requested format is not available|HTTP Error 403|nsig|signature extraction|unable to extract|no video formats');
final RegExp _ytLive = _i(
    r'live event will begin|premieres? in|does not pass filter \(!?is_live\)|is a live stream');
final RegExp _ytTooBig = _i(r'larger than max-filesize|size cap');
final RegExp _ytTooLong = _i(r'took longer than');
final RegExp _ytExists = _i(r'already exists');
final RegExp _ytUnavailable = _i(
    r'video unavailable|private video|video is private|has been removed|no longer available|not available in your country|not made this video available|members[- ]only|join this channel|channel.s members|premium members|requires payment|drm protected|confirm your age|age[- ]restricted|terminated|copyright');

/// mStream's failureReason (src/util/yt-dlp.js), ported: 'live',
/// 'too-big', 'too-long', 'exists', 'unavailable', or null — the bot
/// check, rate limiting and a yt-dlp too old for YouTube's player read
/// first, as null, because their words can mention an unavailable stream
/// and are the server's problem, not the video's.
String? _ytdlpReason(String text) {
  if (text.isEmpty) return null;
  if (_ytServerSide.hasMatch(text)) return null;
  if (_ytLive.hasMatch(text)) return 'live';
  if (_ytTooBig.hasMatch(text)) return 'too-big';
  if (_ytTooLong.hasMatch(text)) return 'too-long';
  if (_ytExists.hasMatch(text)) return 'exists';
  if (_ytUnavailable.hasMatch(text)) return 'unavailable';
  return null;
}

final RegExp _queueCap = _i(r'you have (\d+) jobs queued or running');

/// How many jobs the jobs route's 429 says the account has waiting or
/// running ("you have 20 jobs queued or running — wait for some to finish
/// (the limit is 20)"), or null when its words do not say.
int? youtubeQueueCap(String message) {
  final m = _queueCap.firstMatch(message);
  return m == null ? null : int.tryParse(m[1]!);
}

final RegExp _videoId = RegExp(r'^[A-Za-z0-9_-]+$');
final RegExp _youtubeHost = RegExp(r'^(www\.|m\.|music\.)?youtube\.com$');
final RegExp _shortOrLive = RegExp(r'^/(shorts|live)/([^/]+)$');

/// mStream's isYouTubeUrl (src/discovery-plugins/plugins/youtube.js),
/// ported: an http(s) link on YouTube's own hosts to a watch page, a short
/// or a live page (or a youtu.be link) — the only `choice` the jobs route
/// takes. A candidate whose link fails it is never offered: the start would
/// be refused.
bool isYouTubeUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || (u.scheme != 'https' && u.scheme != 'http')) return false;
  final host = u.host.toLowerCase();
  final path = u.path;
  if (host == 'youtu.be') {
    return path.length > 1 && _videoId.hasMatch(path.substring(1));
  }
  if (!_youtubeHost.hasMatch(host)) return false;
  if (path == '/watch') {
    final List<String> v;
    try {
      v = u.queryParametersAll['v'] ?? const [];
    } on FormatException {
      return false;
    }
    return v.isNotEmpty && _videoId.hasMatch(v.first);
  }
  final m = _shortOrLive.firstMatch(path);
  return m != null && _videoId.hasMatch(m[2]!);
}

/// mStream's searchPhrase (src/discovery-plugins/recommendation.js),
/// ported: "Artist Title", what the YouTube search asks for — each part
/// trimmed, as the route's schema trims it before the plug-in reads it.
/// Empty when neither is known. What the card says it will search for until
/// the server's own `lookup.query` arrives.
String youtubeSearchPhrase(Map rec) => [rec['artist'], rec['title']]
    .whereType<String>()
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .join(' ');
