import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../objects/server.dart';
import '../../singletons/log_manager.dart';
import '../../singletons/server_list.dart';
import '../../util/federation_admin_api.dart';
import '../../util/federation_ticket.dart';

/// Everything the Federation screens show for one parent server, loaded
/// through the admin routes: the access verdict, the endpoint status, the
/// keys (tickets minted), the admin's peer rows, the pairing requests, the
/// server's libraries. The member-readable half — the peers themselves —
/// lives in [ServerManager] (its mirror of `/api/v1/federation/peers`),
/// and this notifier re-fires whenever that list changes.
class FederationController extends ChangeNotifier {
  final Server parent;
  final FederationAdminApi api;

  FederationAccess? access;
  FederationStatus? status;
  List<FederationKey> keys = const [];
  List<FederationPeerRow> peerRows = const [];
  List<FederationRequest> requests = const [];
  bool acceptRequests = false;

  /// Whether this server's build answers the requests routes (V67).
  bool requestsSupported = true;
  List<String>? libraries;
  FederationTicket? clipboardTicket;
  bool loading = true;
  Object? error;

  StreamSubscription<List<Server>>? _peersSub;

  FederationController(this.parent, {FederationAdminApi? api})
      : api = api ?? FederationAdminApi(parent) {
    _peersSub =
        ServerManager().serverListStream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    super.dispose();
  }

  bool get isAdmin => access == FederationAccess.admin;
  bool get enabled => status?.enabled == true;
  bool get available => status?.available != false;

  /// The peers the app holds for [parent] that its admin still lists —
  /// hidden ones included (they are still readable; the picker just does
  /// not offer them).
  List<Server> get peers => ServerManager()
      .federatedChildren(parent)
      .where((p) => !p.federationMissing)
      .toList();

  FederationPeerRow? rowFor(Server peer) {
    for (final r in peerRows) {
      if (r.id == peer.federationPeerId) return r;
    }
    return null;
  }

  int get pendingInbound => requests.where((r) => r.awaitingAnswer).length;

  /// Load (or reload) everything. A failed status call decides the access
  /// verdict when its status code says so; a transport failure leaves the
  /// verdict unknown and surfaces [error] — the member half still renders.
  Future<void> load({bool quiet = false}) async {
    if (!quiet) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      status = await api.status();
      access = FederationAccess.admin;
      error = null;
    } on FederationAdminException catch (e) {
      final verdict = e.access;
      if (verdict != null) {
        access = verdict;
        error = null;
      } else {
        error = e;
      }
      appLog('[federation] admin status on ${parent.localname}: $e');
    } catch (e) {
      error = e;
      appLog('[federation] admin status on ${parent.localname} failed: $e');
    }
    if (isAdmin && enabled) {
      await Future.wait([_loadKeys(), _loadPeerRows(), _loadRequests()]);
    } else {
      keys = const [];
      peerRows = const [];
      requests = const [];
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _loadKeys() async {
    try {
      keys = await api.keys();
    } catch (e) {
      appLog('[federation] keys on ${parent.localname} failed: $e');
    }
  }

  Future<void> _loadPeerRows() async {
    try {
      peerRows = await api.peers();
    } catch (e) {
      appLog('[federation] peer rows on ${parent.localname} failed: $e');
    }
  }

  Future<void> _loadRequests() async {
    try {
      final r = await api.requests();
      requests = r.requests;
      acceptRequests = r.acceptRequests;
      requestsSupported = true;
      // Keep the home banner and the alerts in step with what was just
      // read (an accept here clears the banner before the next ping).
      ServerManager().setFederationInbox(parent, pendingInbound);
    } on FederationAdminException catch (e) {
      if (e.status == 404) requestsSupported = false;
      appLog('[federation] requests on ${parent.localname}: $e');
    } catch (e) {
      appLog('[federation] requests on ${parent.localname} failed: $e');
    }
  }

  Future<void> refreshKeys() async {
    await _loadKeys();
    notifyListeners();
  }

  Future<void> refreshRequests() async {
    await _loadRequests();
    notifyListeners();
  }

  /// The admin's peer rows AND the app's mirror of the list (the parent
  /// re-reads `/api/v1/federation/peers` so a peer added or removed here
  /// shows up in the picker without waiting for the next ping).
  Future<void> refreshPeers() async {
    await Future.wait([
      _loadPeerRows(),
      ServerManager().refreshFederatedPeers(parent),
    ]);
    notifyListeners();
  }

  /// The server's libraries by name, fetched once per screen life.
  Future<List<String>> loadLibraries() async {
    final have = libraries;
    if (have != null) return have;
    final got = await api.libraries();
    libraries = got;
    return got;
  }

  Future<void> setEnabled(bool on) async {
    await api.setEnabled(on);
    await load(quiet: true);
  }

  Future<void> setAcceptRequests(bool on) async {
    await api.setAcceptRequests(on);
    acceptRequests = on;
    notifyListeners();
    await _loadRequests();
    notifyListeners();
  }

  /// A federation ticket on the clipboard, if any — the banner on the
  /// screen. Read on open and on resume; never acted on without a tap.
  Future<void> checkClipboard() async {
    if (!isAdmin || !enabled) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      final found = text == null ? null : FederationTicket.parse(text).ticket;
      if ((found?.raw) != (clipboardTicket?.raw)) {
        clipboardTicket = found;
        notifyListeners();
      }
    } catch (_) {
      // No clipboard access (some platforms deny it in the background).
    }
  }

  void dismissClipboard() {
    clipboardTicket = null;
    notifyListeners();
  }
}
