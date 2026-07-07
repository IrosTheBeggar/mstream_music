import 'package:connectivity_plus/connectivity_plus.dart';

/// Best-effort "is a usable network up right now?" probe.
///
/// [lanOnly] restricts the answer to LAN-capable transports (Wi-Fi /
/// ethernet). That is the right question for anything that must reach a
/// device on the local network (a cast session, a renderer): when Wi-Fi
/// blips, phones fail over to mobile data within seconds, so an any-network
/// probe reports online while the LAN — and everything on it — is
/// unreachable. Leave it false for internet streaming, where any transport
/// serves.
///
/// Fails OPEN (a broken probe counts as online) so callers that loop while
/// offline can never wait forever on a probe error.
Future<bool> hasConnectivity({bool lanOnly = false}) async {
  try {
    final r = await Connectivity().checkConnectivity();
    if (lanOnly) {
      return r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet);
    }
    return r.any((c) => c != ConnectivityResult.none);
  } catch (_) {
    return true;
  }
}
