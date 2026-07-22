import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../cast_log.dart';
import 'cast_channel.dart';

/// Playback state reported by the Chromecast receiver.
enum CastPlayerState { idle, buffering, playing, paused, finished, unknown }

/// A pure-Dart CASTV2 sender for the Default Media Receiver (app `CC1AD845`),
/// good enough to stream audio: connect → launch the receiver → CONNECT to the
/// app → LOAD a URL → PLAY/PAUSE/SEEK/STOP, polling MEDIA_STATUS for position.
///
/// We control the LOAD media object (contentId + contentType), so audio streams
/// get a real `audio/*` type — which the off-the-shelf video-oriented Dart cast
/// libraries don't allow.
class ChromecastSender {
  ChromecastSender(this.host, this.port);

  final InternetAddress host;
  final int port;

  // Well-known namespaces.
  static const _nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const _nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const _nsReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const _nsMedia = 'urn:x-cast:com.google.cast.media';
  static const _defaultMediaReceiver = 'CC1AD845';
  static const _senderId = 'sender-0';
  static const _platformReceiver = 'receiver-0';

  final CastChannel _ch = CastChannel();
  StreamSubscription<CastMessage>? _sub;
  Timer? _heartbeat;
  Timer? _poll;
  int _requestId = 1;

  String? _transportId; // the launched media app's session transport
  int? _mediaSessionId; // the loaded media's session

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _state = StreamController<CastPlayerState>.broadcast();
  final _lost = StreamController<String>.broadcast();

  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration> get durationStream => _duration.stream;
  Stream<CastPlayerState> get stateStream => _state.stream;
  Stream<String> get lostStream => _lost.stream;

  bool get isReady => _transportId != null;

  /// TLS connect, open the platform connection, launch the media receiver, and
  /// CONNECT to the launched app. Completes once the app transport is known.
  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) async {
    await _ch.connect(host, port);
    _sub = _ch.messages.listen(_onMessage,
        onError: (e) => _fail('cast channel error: $e'),
        onDone: () => _fail('cast connection closed'));
    _sendJson(_nsConnection, _platformReceiver, {'type': 'CONNECT'});
    _heartbeat = Timer.periodic(const Duration(seconds: 5),
        (_) => _sendJson(_nsHeartbeat, _platformReceiver, {'type': 'PING'}));
    _sendJson(_nsReceiver, _platformReceiver, {
      'type': 'LAUNCH',
      'appId': _defaultMediaReceiver,
      'requestId': _nextId(),
    });
    // Wait for the receiver to report the launched app's transportId.
    final done = Completer<void>();
    final t = Timer(timeout, () {
      if (!done.isCompleted) done.completeError(TimeoutException('LAUNCH'));
    });
    void check() {
      if (_transportId != null && !done.isCompleted) done.complete();
    }
    // The transportId is set in _onReceiverStatus; poll for it (cheap) so we
    // don't depend on a particular event ordering.
    final p = Timer.periodic(const Duration(milliseconds: 100), (_) => check());
    try {
      await done.future;
    } finally {
      t.cancel();
      p.cancel();
    }
  }

  /// LOAD [url] with an explicit [contentType] (e.g. `audio/mpeg`). Metadata
  /// drives the device's now-playing card.
  Future<void> load({
    required String url,
    required String contentType,
    String? title,
    String? artist,
    String? album,
    String? artUrl,
    Duration startAt = Duration.zero,
    bool autoplay = true,
  }) async {
    final tid = _transportId;
    if (tid == null) return;
    _sendJson(_nsMedia, tid, {
      'type': 'LOAD',
      'requestId': _nextId(),
      'autoplay': autoplay,
      'currentTime': startAt.inMilliseconds / 1000.0,
      'media': {
        'contentId': url,
        'streamType': 'BUFFERED',
        'contentType': contentType,
        'metadata': {
          'metadataType': 3, // MusicTrackMediaMetadata
          if (title != null) 'title': title,
          if (artist != null) 'artist': artist,
          if (album != null) 'albumName': album,
          if (artUrl != null) 'images': [
            {'url': artUrl}
          ],
        },
      },
    });
  }

  Future<void> play() => _mediaCommand('PLAY');
  Future<void> pause() => _mediaCommand('PAUSE');
  Future<void> stopMedia() => _mediaCommand('STOP');

  Future<void> seek(Duration position) async {
    final tid = _transportId, mid = _mediaSessionId;
    if (tid == null || mid == null) return;
    _sendJson(_nsMedia, tid, {
      'type': 'SEEK',
      'mediaSessionId': mid,
      'currentTime': position.inMilliseconds / 1000.0,
      'requestId': _nextId(),
    });
  }

  Future<void> setVolume(double level) async {
    _sendJson(_nsReceiver, _platformReceiver, {
      'type': 'SET_VOLUME',
      'volume': {'level': level.clamp(0.0, 1.0)},
      'requestId': _nextId(),
    });
  }

  Future<void> _mediaCommand(String type) async {
    final tid = _transportId, mid = _mediaSessionId;
    if (tid == null || mid == null) return;
    _sendJson(_nsMedia, tid,
        {'type': type, 'mediaSessionId': mid, 'requestId': _nextId()});
  }

  void _getMediaStatus() {
    final tid = _transportId, mid = _mediaSessionId;
    if (tid == null || mid == null) return;
    _sendJson(_nsMedia, tid,
        {'type': 'GET_STATUS', 'mediaSessionId': mid, 'requestId': _nextId()});
  }

  void _onMessage(CastMessage m) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(m.payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (data['type']) {
      case 'PING':
        _sendJson(_nsHeartbeat, m.sourceId, {'type': 'PONG'});
        break;
      case 'RECEIVER_STATUS':
        _onReceiverStatus(data);
        break;
      case 'MEDIA_STATUS':
        _onMediaStatus(data);
        break;
    }
  }

  void _onReceiverStatus(Map<String, dynamic> data) {
    final apps = (data['status']?['applications'] as List?) ?? const [];
    final media = apps.cast<Map<String, dynamic>>().where((a) =>
        (a['namespaces'] as List?)
            ?.any((n) => n['name'] == _nsMedia) ??
        a['appId'] == _defaultMediaReceiver);
    if (media.isEmpty) return;
    final tid = media.first['transportId'] as String?;
    if (tid != null && tid != _transportId) {
      _transportId = tid;
      // Open a virtual connection to the app, then ask for its media status.
      _sendJson(_nsConnection, tid, {'type': 'CONNECT'});
      _getMediaStatus();
      if (!_state.isClosed) _state.add(CastPlayerState.buffering);
    }
  }

  void _onMediaStatus(Map<String, dynamic> data) {
    final list = (data['status'] as List?)?.cast<Map<String, dynamic>>();
    if (list == null || list.isEmpty) return;
    final s = list.first;
    final mid = s['mediaSessionId'];
    if (mid is int) {
      final firstTime = _mediaSessionId == null;
      _mediaSessionId = mid;
      if (firstTime) _startPolling();
    }
    final ct = s['currentTime'];
    if (ct is num && !_position.isClosed) {
      _position.add(Duration(milliseconds: (ct * 1000).round()));
    }
    final dur = s['media']?['duration'];
    if (dur is num && dur > 0 && !_duration.isClosed) {
      _duration.add(Duration(milliseconds: (dur * 1000).round()));
    }
    final playerState = s['playerState'] as String?;
    final idleReason = s['idleReason'] as String?;
    if (!_state.isClosed) {
      _state.add(switch (playerState) {
        'PLAYING' => CastPlayerState.playing,
        'PAUSED' => CastPlayerState.paused,
        'BUFFERING' => CastPlayerState.buffering,
        'IDLE' =>
          idleReason == 'FINISHED' ? CastPlayerState.finished : CastPlayerState.idle,
        _ => CastPlayerState.unknown,
      });
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _getMediaStatus());
  }

  void _sendJson(String namespace, String dest, Map<String, dynamic> payload) {
    _ch.send(CastMessage(
      sourceId: _senderId,
      destinationId: dest,
      namespace: namespace,
      payload: jsonEncode(payload),
    ));
  }

  int _nextId() => _requestId++;

  void _fail(String reason) {
    castLog('Chromecast sender: $reason');
    if (!_lost.isClosed) _lost.add(reason);
  }

  Future<void> dispose() async {
    _heartbeat?.cancel();
    _poll?.cancel();
    await _sub?.cancel();
    // Best-effort: stop the receiver app so the device returns to idle.
    final tid = _transportId;
    if (tid != null) {
      _sendJson(_nsReceiver, _platformReceiver,
          {'type': 'STOP', 'sessionId': tid, 'requestId': _nextId()});
    }
    await _ch.close();
    for (final c in [_position, _duration, _state, _lost]) {
      if (!c.isClosed) await c.close();
    }
  }
}
