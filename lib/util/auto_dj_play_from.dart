import '../objects/server.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/server_list.dart';

/// The server Auto DJ starts on: the Auto DJ screen's Play from choice
/// ([stored], a [Server.localname]) while it is still a server the picker
/// offers, else [current] — the one being browsed. Pure; unit-tested.
Server? resolvePlayFrom(
    String? stored, Iterable<Server> servers, Server? current) {
  if (stored != null) {
    for (final s in servers) {
      if (s.localname == stored && s.isSelectable) return s;
    }
  }
  return current;
}

/// [resolvePlayFrom] on the live server list: where Start, the queue's Auto
/// DJ button and CarPlay arm the DJ.
Server? autoDjPlayFrom() => resolvePlayFrom(AutoDJManager().playFromServer,
    ServerManager().serverList, ServerManager().currentServer);
