/// Where one Add from YouTube stands, as this phone knows it (design spec
/// §6). The server tells it little — a 200 with no id, then an anonymous
/// tracker entry that disappears 30 s after it settles — so several states
/// are the phone admitting what it cannot see.
enum YtdlJobState {
  /// Tapped: the mkdir (when one is needed) or the POST is in flight.
  starting,

  /// The POST timed out; the hub looks for an unclaimed tracker entry that
  /// matches for 2 minutes ("Starting… the server hasn't answered yet").
  startUnsure,

  /// 2 minutes passed with no match ("Not sure it started" · Check again).
  notSureStarted,

  /// Check again found nothing ("Not found on the server" · Add again).
  notFound,

  /// Claimed a tracker entry ([YtdlJob.pid]) and it is downloading.
  adding,

  /// Finished: its download record was found, or its entry completed.
  added,

  /// The entry ended in `error` and the predicted file name is already in
  /// the folder: 6.30+ refuses a name clash after the whole download.
  failedClash,

  /// The entry ended in `error`, and nothing says why.
  failed,

  /// The entry vanished unseen (the app was away past its 30 s) and the
  /// server has no record of it.
  notSureFinished,

  /// Refused before the server took it — the mkdir, a 403, ffmpeg, a 404, a
  /// 400 … — with the reason in [YtdlJob.problem].
  startFailed;

  static YtdlJobState? parse(dynamic v) =>
      v is String ? YtdlJobState.values.asNameMap()[v] : null;

  /// Still in the hub's hands: polled, and counted as "Adding".
  bool get open => this == starting || this == startUnsure || this == adding;
}

/// One add, from the tap until the user dismisses its row. Persisted with
/// its server (Server.ytdlJobs, as [toJson]) so a row survives the app
/// being closed while the server works.
///
/// The identity fields are fixed at the tap; the hub moves [state] and
/// fills in what the server reveals as it goes. Times on the phone's clock
/// are for display only — they are never compared with the server's.
class YtdlJob {
  /// Made on the phone, unique across this server's jobs.
  final String id;

  /// The canonical link sent (util/ytdl_link.dart) — what the tracker's
  /// `url` and the record's `origin` equal.
  final String url;

  /// The folder as POSTed: '/Music/Daft Punk/Discovery/'.
  final String directory;

  /// The `outputCodec` sent: mp3, m4a, opus, ogg, flac, wav (aac).
  final String codec;

  /// The tags as sent: title / artist / album / year, non-empty only.
  final Map<String, String> tags;

  /// What the row calls it: the edited title, else the video's own.
  final String title;

  /// The video's thumbnail URL, when the lookup had one.
  final String? cover;

  /// `<restricted raw title>.<ext>` (util/ytdl_filename.dart): the name
  /// yt-dlp will give the file, for the clash check and the highlight.
  final String predictedName;

  final DateTime createdAt;

  YtdlJobState state;

  /// From the claimed tracker entry; [serverStart] is its `startTime` (ms,
  /// server clock).
  int? pid;
  int? serverStart;

  /// When the phone saw it settle.
  DateTime? endedAt;

  /// Hidden from the list ("Hidden. The server keeps going."), and whether
  /// the user has seen its outcome (the home's "failed" / "Added" counts).
  bool hidden;
  bool seen;

  /// [startFailed]'s reason: a YtdlProblem name (util/ytdl_errors.dart),
  /// and the server's words for `other`.
  String? problem;
  String? problemDetail;

  /// From the download record (6.30+): `<vpath>/<relativePath>`, the size,
  /// and the library's track id.
  String? filepath;
  int? bytes;
  int? trackId;

  /// The download record's id this job settled with: a record answers for
  /// one job only, across restarts too.
  int? recordId;

  YtdlJob({
    required this.id,
    required this.url,
    required this.directory,
    required this.codec,
    this.tags = const {},
    required this.title,
    this.cover,
    required this.predictedName,
    required this.createdAt,
    this.state = YtdlJobState.starting,
    this.pid,
    this.serverStart,
    this.endedAt,
    this.hidden = false,
    this.seen = false,
    this.problem,
    this.problemDetail,
    this.filepath,
    this.bytes,
    this.trackId,
    this.recordId,
  });

  /// Polled, and counted as "Adding" (see [YtdlJobState.open]).
  bool get open => state.open;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'directory': directory,
        'codec': codec,
        'tags': tags,
        'title': title,
        'cover': cover,
        'predictedName': predictedName,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'state': state.name,
        'pid': pid,
        'serverStart': serverStart,
        'endedAt': endedAt?.millisecondsSinceEpoch,
        'hidden': hidden,
        'seen': seen,
        'problem': problem,
        'problemDetail': problemDetail,
        'filepath': filepath,
        'bytes': bytes,
        'trackId': trackId,
        'recordId': recordId,
      };

  /// Reads what [toJson] wrote. Throws [FormatException] for an entry with
  /// no id, link or folder — nothing could be matched or shown for it; see
  /// [tryFromJson].
  ///
  /// A state this build does not know (written by a newer one) loads as a
  /// "not sure" state rather than dropping the row or polling forever:
  /// [YtdlJobState.notSureFinished] when it had claimed an entry (so it
  /// started), else [YtdlJobState.notSureStarted], whose Check again asks
  /// the server.
  factory YtdlJob.fromJson(Map json) {
    final id = json['id'];
    final url = json['url'];
    final directory = json['directory'];
    if (id is! String || id.isEmpty || url is! String || directory is! String) {
      throw const FormatException('a YouTube job needs an id, a link and a folder');
    }
    final pid = _int(json['pid']);
    final rawTags = json['tags'];
    String str(String key) => json[key] is String ? json[key] as String : '';
    return YtdlJob(
      id: id,
      url: url,
      directory: directory,
      codec: str('codec'),
      tags: {
        if (rawTags is Map)
          for (final e in rawTags.entries)
            if (e.key is String && e.value is String) e.key as String: e.value as String,
      },
      title: str('title'),
      cover: _str(json['cover']),
      predictedName: str('predictedName'),
      createdAt: _time(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      state: YtdlJobState.parse(json['state']) ??
          (pid != null ? YtdlJobState.notSureFinished : YtdlJobState.notSureStarted),
      pid: pid,
      serverStart: _int(json['serverStart']),
      endedAt: _time(json['endedAt']),
      hidden: json['hidden'] == true,
      seen: json['seen'] == true,
      problem: _str(json['problem']),
      problemDetail: _str(json['problemDetail']),
      filepath: _str(json['filepath']),
      bytes: _int(json['bytes']),
      trackId: _int(json['trackId']),
      recordId: _int(json['recordId']),
    );
  }

  /// [YtdlJob.fromJson], or null for an entry it cannot read.
  static YtdlJob? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    try {
      return YtdlJob.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  static int? _int(dynamic v) => v is int ? v : null;
  static String? _str(dynamic v) => v is String ? v : null;
  static DateTime? _time(dynamic v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
}
