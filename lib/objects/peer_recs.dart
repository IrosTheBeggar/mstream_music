import 'package:flutter/foundation.dart' show immutable;

/// Models for the Peer Recommendations page's own routes (mStream
/// docs/peer-recommendations-plan.md §3.2): the peer strip's
/// `GET /api/v1/discovery/p2p/peers` and an admin's
/// `POST /api/v1/admin/discovery/p2p/peer-dbs/add`. What the server stamps
/// (a peer's label, monogram and hue) is kept verbatim and never computed
/// here; every state is keyed on the endpoint id, never on a label (a newly
/// announced twin can change one). Parsers are defensive: a malformed row
/// is dropped, never thrown on.

final RegExp _endpointId = RegExp(r'^[0-9a-f]{64}$');

/// `GET /api/v1/discovery/p2p/peers`, parsed (mStream plan §3.2).
@immutable
class PeerView {
  /// Whether this caller may Add a peer here (an admin, not locked out, from
  /// an allowed address). Read from the route alone, never inferred from
  /// the account's admin flag.
  final bool canAdd;

  /// The shelf's unblocked snapshots in any model, and those the page can
  /// search (listed as shelf rows). 0 when the answer does not say.
  final int held;
  final int searchable;

  /// Whether the p2p stack is running (false on the stage: it never starts).
  final bool running;

  /// The rows in the server's order (shelf rows first, online first; then
  /// an admin's addable rows), a bad endpoint id or a repeated one dropped.
  final List<PeerRow> peers;

  const PeerView({
    this.canAdd = false,
    this.held = 0,
    this.searchable = 0,
    this.running = false,
    this.peers = const [],
  });

  /// Null for anything but a map; a missing `shelf` reads as zeros.
  static PeerView? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final shelf = m['shelf'];
    final rows = m['peers'];
    final seen = <String>{};
    final peers = <PeerRow>[];
    if (rows is List) {
      for (final r in rows) {
        final row = PeerRow.fromServerMap(r);
        if (row != null && seen.add(row.endpointId)) peers.add(row);
      }
    }
    return PeerView(
      canAdd: m['canAdd'] == true,
      held: shelf is Map ? _whole(shelf['held']) : 0,
      searchable: shelf is Map ? _whole(shelf['searchable']) : 0,
      running: shelf is Map && shelf['running'] == true,
      peers: List.unmodifiable(peers),
    );
  }

  /// The row of [endpointId], or null.
  PeerRow? row(String endpointId) {
    for (final p in peers) {
      if (p.endpointId == endpointId) return p;
    }
    return null;
  }
}

/// One peers-route row (mStream src/state/discovery-peer-view.js
/// buildPeerView): a shelf peer, or — for an admin only — a peer it may
/// Add, with that Add's state.
@immutable
class PeerRow {
  /// 64 lower-case hex exactly, as the wire sends it (no folding; the
  /// webapp's isEndpointId) — any other id drops the row.
  final String endpointId;

  /// The peer's announced name; '' when absent.
  final String name;

  /// The strip's label, verbatim: the row's `label` when it is not blank,
  /// else the trimmed [name] (the webapp's labelOf).
  final String label;

  /// The badge's letters, verbatim; '' draws none.
  final String monogram;

  /// The badge's hue, an integer 0..359 (the webapp's hueOf: anything but a
  /// finite number is 0).
  final int hue;
  final bool online;
  final bool onShelf;
  final bool pinned;

  /// The snapshot's track count; never drawn.
  final int? rowCount;

  /// The Add state the server holds for this peer (admins only; stamped on
  /// shelf rows too, which the strip ignores); null when there is none.
  final PeerAddState? add;

  const PeerRow({
    required this.endpointId,
    this.name = '',
    this.label = '',
    this.monogram = '',
    this.hue = 0,
    this.online = false,
    this.onShelf = false,
    this.pinned = false,
    this.rowCount,
    this.add,
  });

  static PeerRow? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final id = m['endpointId'];
    if (id is! String || !_endpointId.hasMatch(id)) return null;
    final name = m['name'] is String ? m['name'] as String : '';
    final label = m['label'];
    final rowCount = m['rowCount'];
    return PeerRow(
      endpointId: id,
      name: name,
      label: label is String && label.trim().isNotEmpty ? label : name.trim(),
      monogram: m['monogram'] is String ? m['monogram'] as String : '',
      hue: _hue(m['hue']),
      online: m['online'] == true,
      onShelf: m['onShelf'] == true,
      pinned: m['pinned'] == true,
      rowCount: rowCount is num && rowCount.isFinite && rowCount >= 0
          ? rowCount.toInt()
          : null,
      add: PeerAddState.fromServerMap(m['add']),
    );
  }
}

/// A server-stamped hue as an integer 0..359; anything but a finite number
/// is 0 (the webapp's hueOf: `((Math.round(v) % 360) + 360) % 360`, with
/// JS rounding — a half goes up).
int _hue(dynamic v) {
  if (v is! num || !v.isFinite) return 0;
  return ((v + 0.5).floorToDouble() % 360).toInt();
}

/// An Add's state on the wire (mStream src/state/discovery-peer-add.js).
enum PeerAddKind { adding, done, failed }

/// One Add state: [state], the failure [code] when it failed (`no-room`,
/// `no-disk`, `offline`, `bad-snapshot`, `gone`, `failed` — shown only as
/// "No room" or "Try again", never as the server's words), and when the
/// server set it.
@immutable
class PeerAddState {
  final PeerAddKind state;
  final String? code;
  final DateTime? at;

  const PeerAddState(this.state, {this.code, this.at});

  /// A failed Add that found no room on the shelf: drawn "No room", inert.
  bool get noRoom => state == PeerAddKind.failed && code == 'no-room';

  /// Null for anything but a map with a known `state`.
  static PeerAddState? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final s = m['state'];
    final state = s is String ? PeerAddKind.values.asNameMap()[s] : null;
    if (state == null) return null;
    final code = m['code'];
    final at = m['at'];
    return PeerAddState(
      state,
      code: code is String ? code : null,
      at: at is String ? DateTime.tryParse(at)?.toUtc() : null,
    );
  }
}

/// A peers poll's outcome: [status] 200 with [view], or the HTTP status
/// (0 = no answer); never thrown.
@immutable
class PeersAnswer {
  final int status;
  final PeerView? view;
  const PeersAnswer(this.status, [this.view]);
}

/// An Add's outcome: [status] (0 = no answer) and, for a 200/202 body, its
/// state.
@immutable
class PeerAddAnswer {
  final int status;
  final PeerAddState? state;
  const PeerAddAnswer(this.status, [this.state]);
}

/// A shelf count: a whole number ≥ 0, else 0 (the webapp's searchableOf
/// reads only an integer).
int _whole(dynamic v) =>
    v is num && v.isFinite && v == v.roundToDouble() && v >= 0 ? v.toInt() : 0;
