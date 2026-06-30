import 'package:rxdart/rxdart.dart';

import '../singletons/log_manager.dart';

/// Captured stdout/stderr of the bundled mStream server — the "Server" view in
/// the Diagnostics screen. Mirrors [LogManager]'s bounded ring buffer; lines are
/// run through the same [LogManager.redact] rules so an iroh pairing code or a
/// stream-URL token can never leak into a shared log. No extra timestamp is
/// added — mStream's own lines are already ISO-stamped.
class ServerLog {
  ServerLog._();
  static final ServerLog _instance = ServerLog._();
  factory ServerLog() => _instance;

  static const int _maxLines = 2000;
  final List<String> _lines = <String>[];

  late final BehaviorSubject<List<String>> _stream =
      BehaviorSubject<List<String>>.seeded(const <String>[]);
  Stream<List<String>> get stream => _stream.stream;
  List<String> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  void add(String message) {
    for (final raw in message.split('\n')) {
      if (raw.isEmpty) continue;
      _lines.add(LogManager.redact(raw));
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

  String dump() => _lines.join('\n');
}
