import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One CASTV2 protocol message. All the messages this client sends/receives use
/// a STRING (JSON) payload, so we model just that.
class CastMessage {
  final String sourceId;
  final String destinationId;
  final String namespace;
  final String payload; // JSON text

  CastMessage({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    required this.payload,
  });
}

/// A framed CASTV2 channel: a TLS socket to a Chromecast (port 8009) that speaks
/// length-prefixed `CastMessage` protobufs.
///
/// CastMessage is a flat proto, so we hand-encode/decode it (no protobuf codegen
/// dependency). Wire layout: a 4-byte big-endian length, then the serialized
/// message. The Chromecast presents a self-signed cert, so the TLS handshake
/// accepts any certificate (the device is identified by mDNS on the LAN, and the
/// content auth is mStream's own — this leg is LAN-local).
class CastChannel {
  SecureSocket? _socket;
  final StreamController<CastMessage> _messages =
      StreamController<CastMessage>.broadcast();
  final BytesBuilder _pending = BytesBuilder();
  Uint8List _acc = Uint8List(0);

  Stream<CastMessage> get messages => _messages.stream;
  bool get isOpen => _socket != null;

  Future<void> connect(InternetAddress host, int port,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final s = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => true, // Chromecast uses a self-signed cert
      timeout: timeout,
    );
    _socket = s;
    s.listen(_onData,
        onError: (_) => _close(), onDone: _close, cancelOnError: true);
  }

  void send(CastMessage m) {
    final sock = _socket;
    if (sock == null) return;
    final body = _encode(m);
    final header = ByteData(4)..setUint32(0, body.length, Endian.big);
    sock.add(header.buffer.asUint8List());
    sock.add(body);
  }

  void _onData(Uint8List data) {
    // Reassemble length-prefixed frames across packet boundaries.
    _acc = Uint8List.fromList([..._acc, ...data]);
    while (_acc.length >= 4) {
      final len = ByteData.sublistView(_acc, 0, 4).getUint32(0, Endian.big);
      if (_acc.length < 4 + len) break;
      final frame = _acc.sublist(4, 4 + len);
      _acc = _acc.sublist(4 + len);
      final msg = _decode(frame);
      if (msg != null && !_messages.isClosed) _messages.add(msg);
    }
  }

  void _close() {
    final s = _socket;
    _socket = null;
    s?.destroy();
    if (!_messages.isClosed) _messages.close();
  }

  Future<void> close() async {
    _close();
    _pending.clear();
  }

  // ── CastMessage protobuf (cast_channel.proto) ──
  // 1 protocol_version (enum), 2 source_id, 3 destination_id, 4 namespace,
  // 5 payload_type (enum), 6 payload_utf8.
  static Uint8List _encode(CastMessage m) {
    final b = BytesBuilder();
    _tag(b, 1, 0);
    _varint(b, 0); // protocol_version = CASTV2_1_0
    _strField(b, 2, m.sourceId);
    _strField(b, 3, m.destinationId);
    _strField(b, 4, m.namespace);
    _tag(b, 5, 0);
    _varint(b, 0); // payload_type = STRING
    _strField(b, 6, m.payload);
    return b.toBytes();
  }

  static CastMessage? _decode(Uint8List buf) {
    var i = 0;
    String src = '', dst = '', ns = '', payload = '';
    int readVarint() {
      var shift = 0, result = 0;
      while (i < buf.length) {
        final byte = buf[i++];
        result |= (byte & 0x7f) << shift;
        if (byte & 0x80 == 0) break;
        shift += 7;
      }
      return result;
    }

    while (i < buf.length) {
      final tag = readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      if (wire == 2) {
        final len = readVarint();
        if (i + len > buf.length) return null;
        final s = utf8.decode(buf.sublist(i, i + len), allowMalformed: true);
        i += len;
        if (field == 2) src = s;
        if (field == 3) dst = s;
        if (field == 4) ns = s;
        if (field == 6) payload = s;
      } else if (wire == 0) {
        readVarint(); // enum/varint field we don't need
      } else if (wire == 5) {
        i += 4;
      } else if (wire == 1) {
        i += 8;
      } else {
        return null; // unknown wire type
      }
    }
    return CastMessage(
        sourceId: src, destinationId: dst, namespace: ns, payload: payload);
  }

  static void _tag(BytesBuilder b, int field, int wire) =>
      _varint(b, (field << 3) | wire);

  static void _varint(BytesBuilder b, int v) {
    var value = v;
    while (value > 0x7f) {
      b.addByte((value & 0x7f) | 0x80);
      value >>= 7;
    }
    b.addByte(value & 0x7f);
  }

  static void _strField(BytesBuilder b, int field, String s) {
    final bytes = utf8.encode(s);
    _tag(b, field, 2);
    _varint(b, bytes.length);
    b.add(bytes);
  }
}
