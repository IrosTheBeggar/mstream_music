import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'settings.dart';

/// App-wide informational logging for non-cast subsystems. Routed through
/// `print()` so the main() print-Zone tees it into the in-app buffer (redacted,
/// gated by the logging toggle) AND forwards it to the console / logcat — one
/// path, no double entry. Use for happy-path activity (server calls, playback,
/// startup) so the Diagnostics screen shows a real trail, not just errors.
void appLog(String message) {
  // The print Zone in main() tees this into the in-app diagnostic buffer
  // (redacted, gated by the logging toggle) AND forwards it to the console.
  // This is the app's info-logging entry point — print here is deliberate.
  // ignore: avoid_print
  print(message);
}

/// In-app diagnostic log buffer. Captures `print()` output (via a custom print
/// Zone installed in main()), the cast subsystem's `castLog()`, and uncaught
/// errors into a bounded ring buffer that the user can view, copy and share from
/// the Diagnostics screen.
///
/// Secrets are redacted AT CAPTURE TIME (tokens / jwt / passwords masked), so
/// the buffer — and therefore anything the user copies or shares — never
/// contains credentials, even though stream URLs and servers.json carry them.
/// (The raw line still goes to the console / `adb logcat` for developers; only
/// the user-facing in-app copy is scrubbed.)
class LogManager {
  LogManager._();
  static final LogManager _instance = LogManager._();
  factory LogManager() => _instance;

  // Ring buffer cap — enough to cover a repro session without unbounded growth.
  static const int _maxLines = 2000;
  final List<String> _lines = <String>[];

  // Emits the capped line list on every change so the Diagnostics screen
  // refreshes live while it's open.
  late final BehaviorSubject<List<String>> _stream =
      BehaviorSubject<List<String>>.seeded(const <String>[]);
  Stream<List<String>> get stream => _stream.stream;
  List<String> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  bool get _enabled => SettingsManager().diagnosticsLogging;

  /// Append a log entry: split into lines, timestamp + redact each, append, and
  /// trim to the cap. No-op while logging is disabled. MUST NOT call print()
  /// itself — it's fed from the print Zone and would recurse.
  void add(String message) {
    if (!_enabled) return;
    final stamp = _stamp();
    for (final raw in message.split('\n')) {
      if (raw.isEmpty) continue;
      _lines.add('$stamp ${_redactSecrets(raw)}');
    }
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
    if (!_stream.isClosed) _stream.add(List.unmodifiable(_lines));
  }

  void clear() {
    _lines.clear();
    if (!_stream.isClosed) _stream.add(const <String>[]);
  }

  /// The whole buffer as text (chronological), for copy / share.
  String dump() => _lines.join('\n');

  String _stamp() {
    final t = DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    String p3(int n) => n.toString().padLeft(3, '0');
    return '${p2(t.hour)}:${p2(t.minute)}:${p2(t.second)}.${p3(t.millisecond)}';
  }

  /// Mask credentials that legitimately appear in URLs / JSON we log: the
  /// `token=` query param on stream/art URLs, and `jwt` / `password` /
  /// `x-access-token` values in bodies or headers.
  static String _redactSecrets(String s) {
    var out = s;
    out = out.replaceAllMapped(
        RegExp(r'(token=)[^&\s"\)\]]+', caseSensitive: false),
        (m) => '${m[1]}***');
    out = out.replaceAllMapped(
        RegExp(
            r'("?(?:jwt|password|x-access-token)"?\s*[:=]\s*"?)([^",}\s&]+)',
            caseSensitive: false),
        (m) => '${m[1]}***');
    // iroh pairing-code envelope (mstr<V>:..., embeds the connect secret) and the
    // loopback auth token (__lt=...) — credentials that must never reach the
    // shareable diagnostics buffer or logcat if a future line interpolates them.
    out = out.replaceAll(
        RegExp(r'mstr\d*:[A-Za-z0-9_\-]+', caseSensitive: false), 'mstr:***');
    out = out.replaceAllMapped(
        RegExp(r'(__lt=)[^&\s"\)\]]+', caseSensitive: false), (m) => '${m[1]}***');
    return out;
  }
}
