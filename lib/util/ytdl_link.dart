/// What a pasted YouTube link is, and the one URL the phone sends for it.
///
/// The server's `/api/v1/ytdl` routes take a URL whose host is youtube.com,
/// a subdomain of it, or youtu.be (mStream src/api/ytdl.js), then keep its
/// scheme, host and path with only the `v` parameter (sanitizeYoutubeUrl).
/// A youtu.be, /shorts/, /live/ or /embed/ link has no `v`, so the server
/// answers 400 "missing video ID" — the phone rewrites those to a watch
/// link first. The URL it sends is one sanitizeYoutubeUrl leaves as it is,
/// so the job list's `url` and the download record's `origin` match it
/// character for character.
library;

enum YtdlLinkKind {
  /// Nothing typed (or only whitespace).
  empty,

  /// No YouTube link in the text, or one that names no video (a channel).
  notYoutube,

  /// A playlist link with no video in it.
  playlist,

  /// One video: [YtdlLink.url] is what the server gets.
  video,
}

class YtdlLink {
  final YtdlLinkKind kind;

  /// Canonical URL sent to the server (video only): `<scheme>://<host>/watch?v=<id>`,
  /// host lower-cased, default port dropped, every other query param and the fragment dropped.
  /// Equals what the server's sanitizeYoutubeUrl() produces from it, so the job list's `url`
  /// and the download record's `origin` match it by string equality.
  final String? url;
  final String? videoId;

  /// youtu.be / shorts / live / embed / youtube-nocookie → rewritten to https://www.youtube.com/watch?v=ID
  final bool shortForm;

  /// typed without a scheme ("YouTube.com/watch?v=…") → https:// added and host lower-cased
  final bool schemeAdded;

  /// a /live/ID link
  final bool live;

  /// a watch link that also names a playlist (list=) — "Just this video, not the playlist."
  final bool inPlaylist;

  const YtdlLink._(
    this.kind, {
    this.url,
    this.videoId,
    this.shortForm = false,
    this.schemeAdded = false,
    this.live = false,
    this.inPlaylist = false,
  });

  static const YtdlLink _empty = YtdlLink._(YtdlLinkKind.empty);
  static const YtdlLink _notYoutube = YtdlLink._(YtdlLinkKind.notYoutube);

  /// For the helper line: `youtube.com/watch?v=<id>` (host minus a leading "www.", no scheme).
  String get shown {
    final u = url;
    if (u == null) return '';
    final bare = u.substring(u.indexOf('://') + 3);
    return bare.startsWith('www.') ? bare.substring(4) : bare;
  }

  @override
  String toString() => 'YtdlLink($kind, $url)';
}

/// A YouTube host inside free text: "youtu.be", "youtube.com" or a
/// subdomain of either it or youtube-nocookie.com, with an optional scheme,
/// port and path. Not when it is the tail of a longer name
/// ("notyoutube.com") or sits inside another link's path.
final RegExp _candidate = RegExp(
  r'(?<![\w.@/-])(https?://)?((?:[a-z0-9-]+\.)*(?:youtube\.com|youtu\.be|youtube-nocookie\.com))'
  r'(?![a-z0-9-]|\.[a-z0-9])(:\d+)?([/?#][^\s<>"]*)?',
  caseSensitive: false,
);

/// Punctuation a link in a sentence ends with that is not part of it.
final RegExp _trailingPunctuation = RegExp(r'''[.,;:!?)\]}>'"»”’]+$''');

final RegExp _videoId = RegExp(r'^[A-Za-z0-9_-]{6,}$');

/// First link in [text] (with or without a scheme). Empty/whitespace → empty.
/// Text with no youtube.com / youtu.be / youtube-nocookie.com link → notYoutube.
/// /playlist?list=… (no v) → playlist. A video id must match ^[A-Za-z0-9_-]{6,}$ else notYoutube.
YtdlLink parseYtdlLink(String text) {
  if (text.trim().isEmpty) return YtdlLink._empty;
  final m = _candidate.firstMatch(text);
  if (m == null) return YtdlLink._notYoutube;
  final schemeAdded = m[1] == null;
  final raw = m[0]!.replaceFirst(_trailingPunctuation, '');
  final uri = Uri.tryParse(schemeAdded ? 'https://$raw' : raw);
  if (uri == null) return YtdlLink._notYoutube;

  // Uri lower-cases the scheme and the host and drops a default port, as
  // the WHATWG parser behind the server's `new URL()` does.
  final host = uri.host;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final query = uri.queryParametersAll;
  final v = query['v']?.first;
  final inPlaylist = (query['list']?.first ?? '').isNotEmpty;

  YtdlLink rewritten(String? id, {bool live = false}) {
    if (id == null || !_videoId.hasMatch(id)) return YtdlLink._notYoutube;
    return YtdlLink._(
      YtdlLinkKind.video,
      url: 'https://www.youtube.com/watch?v=$id',
      videoId: id,
      shortForm: true,
      schemeAdded: schemeAdded,
      live: live,
      inPlaylist: inPlaylist,
    );
  }

  if (host == 'youtu.be' || host == 'www.youtu.be') {
    return rewritten(segments.isEmpty ? null : segments.first);
  }
  final first = segments.isEmpty ? '' : segments.first;
  final second = segments.length > 1 ? segments[1] : null;
  if (host == 'youtube-nocookie.com' || host.endsWith('.youtube-nocookie.com')) {
    // Only embeds live there; the server refuses the host, so even a
    // watch link on it is sent as www.youtube.com.
    return rewritten(first == 'embed' ? second : (first == 'watch' ? v : null));
  }
  switch (first) {
    case 'shorts' || 'embed':
      return rewritten(second);
    case 'live':
      return rewritten(second, live: true);
    case 'playlist':
      return inPlaylist
          ? const YtdlLink._(YtdlLinkKind.playlist)
          : YtdlLink._notYoutube;
    case 'watch' when segments.length == 1:
      if (v == null) {
        return inPlaylist
            ? const YtdlLink._(YtdlLinkKind.playlist)
            : YtdlLink._notYoutube;
      }
      if (!_videoId.hasMatch(v)) return YtdlLink._notYoutube;
      // Scheme and host kept (music.youtube.com stays itself, http stays
      // http), a port only when it is not the scheme's own.
      final port = uri.hasPort ? ':${uri.port}' : '';
      return YtdlLink._(
        YtdlLinkKind.video,
        url: '${uri.scheme}://$host$port/watch?v=$v',
        videoId: v,
        schemeAdded: schemeAdded,
        inPlaylist: inPlaylist,
      );
  }
  return YtdlLink._notYoutube;
}
