/// Parsed result of `GET /api/v1/lyrics`.
///
/// The server returns two typed containers — `lyrics` (plain text) and
/// `syncedLyrics` (raw LRC) — each shaped `{ default: int, lyrics: [ { lang,
/// source, data } ] }`. Today each holds 0 or 1 entry; we read the `default`
/// index. Availability is advertised separately on song metadata
/// (`has-lyrics`), so this payload is only fetched on demand when the user opens
/// the lyrics page.
class LyricsResult {
  /// Plain-text lyrics, ready to render as-is (null when the server has none).
  final String? plainText;

  /// Raw LRC (`[mm:ss.xx]line…`) when the server has a synced version.
  final String? syncedLrc;

  const LyricsResult({this.plainText, this.syncedLrc});

  factory LyricsResult.fromJson(Map<String, dynamic> json) => LyricsResult(
        plainText: _pickData(json['lyrics']),
        syncedLrc: _pickData(json['syncedLyrics']),
      );

  /// True when neither container carried any usable text.
  bool get isEmpty => _blank(plainText) && _blank(syncedLrc);

  /// True when the only lyrics available are time-synced (so [displayText] is
  /// the LRC stripped down to plain lines).
  bool get isSynced => _blank(plainText) && !_blank(syncedLrc);

  /// Text to show: the plain lyrics when present, otherwise the synced LRC with
  /// its `[mm:ss.xx]` timestamps and `[idtag:value]` headers stripped. Null when
  /// there's nothing to show.
  String? get displayText {
    if (!_blank(plainText)) return plainText!.trim();
    if (!_blank(syncedLrc)) return stripLrc(syncedLrc!);
    return null;
  }

  /// Pulls the `default` entry's `data` out of one `{ default, lyrics:[…] }`
  /// container, tolerating a missing/short list or a non-string `data`.
  static String? _pickData(dynamic container) {
    if (container is! Map) return null;
    final list = container['lyrics'];
    if (list is! List || list.isEmpty) return null;
    final i = container['default'] is int ? container['default'] as int : 0;
    final entry = (i >= 0 && i < list.length) ? list[i] : list.first;
    final data = entry is Map ? entry['data'] : null;
    return (data is String && data.trim().isNotEmpty) ? data : null;
  }

  /// Flattens synced LRC to plain text: drops `[idtag:value]` metadata headers
  /// and removes inline `[mm:ss.xx]` time tags, keeping each line's words. Blank
  /// lines within the song are preserved; leading/trailing blanks are trimmed.
  static String stripLrc(String lrc) {
    final timeTag = RegExp(r'\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]');
    final headerTag = RegExp(r'^\[[a-zA-Z#]+:.*\]$');
    final lines = <String>[];
    for (final raw in lrc.split('\n')) {
      final line = raw.trim();
      if (headerTag.hasMatch(line)) continue; // [ar:…], [ti:…], [length:…], …
      lines.add(line.replaceAll(timeTag, '').trim());
    }
    return lines.join('\n').trim();
  }

  static bool _blank(String? s) => s == null || s.trim().isEmpty;
}
