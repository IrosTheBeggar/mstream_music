import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../objects/server.dart';
import '../../singletons/log_manager.dart';
import '../../util/federation_admin_api.dart';
import '../../util/p2p_admin_api.dart';

/// Everything the P2P Network screens show for one server: the admin
/// verdict, the sidecar's status, the catalog of servers heard (with the
/// federation-request rows that decide each entry's relationship chip),
/// and — for anyone signed in — the downloaded libraries the Discover
/// panel searches. Polls every ten seconds while the main screen is up,
/// the way the webapp's card does: gossip fills the catalog and the mesh
/// weaves in over a minute, and nobody should have to mash refresh.
class P2pController extends ChangeNotifier {
  final Server server;
  final P2pAdminApi api;
  final FederationAdminApi fedApi;

  FederationAccess? access;
  P2pStatus? status;
  P2pCatalog catalog = P2pCatalog.empty;
  List<FederationRequest> requests = const [];
  List<P2pHeldLibrary> held = const [];

  /// The newest line of the sidecar's activity ring, for the status card.
  P2pActivityEntry? latestActivity;
  bool showIncompatible = false;
  bool loading = true;
  Object? error;
  List<String>? libraries;
  Timer? _poll;

  P2pController(this.server, {P2pAdminApi? api, FederationAdminApi? fedApi})
      : api = api ?? P2pAdminApi(server),
        fedApi = fedApi ?? FederationAdminApi(server);

  bool get isAdmin => access == FederationAccess.admin;
  bool get enabled => status?.enabled == true;

  /// The member-readable answer to "is the network on": the ping flag the
  /// app already persists, refreshed on every server switch.
  bool get memberSeesOn => server.discoveryP2pAvailable == true;

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
      appLog('[p2p] admin status on ${server.localname}: $e');
    } catch (e) {
      error = e;
      appLog('[p2p] admin status on ${server.localname} failed: $e');
    }
    if (isAdmin && enabled) {
      await Future.wait([_loadCatalog(), _loadRequests(), _loadLatestActivity()]);
    } else {
      catalog = P2pCatalog.empty;
      requests = const [];
    }
    await _loadHeld();
    loading = false;
    notifyListeners();
  }

  Future<void> _loadCatalog() async {
    try {
      catalog = await api.catalog(includeIncompatible: showIncompatible);
    } catch (e) {
      appLog('[p2p] catalog on ${server.localname} failed: $e');
    }
  }

  Future<void> _loadRequests() async {
    try {
      requests = (await fedApi.requests()).requests;
    } catch (e) {
      // A build without the request engine, or federation off: chips
      // simply stay quiet.
      requests = const [];
    }
  }

  Future<void> _loadLatestActivity() async {
    try {
      final a = await api.activity(since: 0);
      latestActivity = a.entries.isEmpty ? null : a.entries.last;
    } catch (_) {
      // A build without the activity ring: the card keeps its link only.
    }
  }

  Future<void> _loadHeld() async {
    if (!memberSeesOn && !enabled) {
      held = const [];
      return;
    }
    try {
      held = await fetchHeldLibraries(server);
    } catch (e) {
      appLog('[p2p] held libraries on ${server.localname} failed: $e');
    }
  }

  Future<void> refreshCatalog() async {
    await Future.wait([_loadCatalog(), _loadRequests(), _loadHeld()]);
    notifyListeners();
  }

  Future<void> toggleIncompatible() async {
    showIncompatible = !showIncompatible;
    await _loadCatalog();
    notifyListeners();
  }

  void startPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (isAdmin && enabled) load(quiet: true);
    });
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  P2pFederationState relationship(P2pPeer p) =>
      federationStateFor(requests, p.endpointId);

  P2pPeer? peerById(String endpointId) {
    for (final p in catalog.peers) {
      if (p.endpointId == endpointId) return p;
    }
    return null;
  }

  /// The server's own libraries, for the share-back list of a request.
  Future<List<String>> loadLibraries() async {
    final have = libraries;
    if (have != null) return have;
    final got = await fedApi.libraries();
    libraries = got;
    return got;
  }

  /// The consent screen's one button: enable (downloading the sidecar
  /// first when the build has none), then the name and description the
  /// screen collected, then reload.
  Future<P2pEnableResult> join({
    required String name,
    required String description,
    required bool acceptRequests,
  }) async {
    final result =
        await api.setEnabled(true, acceptFederationRequests: acceptRequests);
    final current = status;
    if (name.trim().isNotEmpty && name.trim() != current?.serverName) {
      try {
        await api.setName(name);
      } catch (e) {
        appLog('[p2p] setName after join failed: $e');
      }
    }
    if (description.trim() != (current?.serverDescription ?? '')) {
      try {
        await api.setDescription(description);
      } catch (e) {
        appLog('[p2p] setDescription after join failed: $e');
      }
    }
    await load(quiet: true);
    return result;
  }

  Future<void> leave() async {
    await api.setEnabled(false);
    await load(quiet: true);
  }
}
