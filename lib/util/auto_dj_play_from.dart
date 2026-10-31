import '../media/audio_stuff.dart' show AudioPlayerHandler, FanOutSitOut;
import '../objects/server.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/server_list.dart';
import 'server_tree.dart';

/// The server Auto DJ starts on when Play from names one: the Auto DJ
/// screen's choice ([stored], a [Server.localname]) while it is still a
/// server the picker offers, else [current] — the one being browsed. Pure;
/// unit-tested.
Server? resolvePlayFrom(
    String? stored, Iterable<Server> servers, Server? current) {
  if (stored != null) {
    for (final s in servers) {
      if (s.localname == stored && s.isSelectable) return s;
    }
  }
  return current;
}

/// The servers Auto DJ plays from, in the order of [offered] (the picker's
/// list, grouped): every server it offers with [all], else the ones [chosen]
/// names that it still offers — a peer the user hid, or its parent stopped
/// listing, sits out until it is back. None left (nothing chosen yet, or
/// every chosen server gone) is [fallback] alone, the server Start would use.
/// Pure; unit-tested.
List<Server> resolvePlayFromSet(
    {required bool all,
    required Iterable<String> chosen,
    required Iterable<Server> offered,
    Server? fallback}) {
  final names = chosen.toSet();
  final out = [
    for (final s in offered)
      if (s.isSelectable && (all || names.contains(s.localname))) s,
  ];
  return out.isEmpty ? [?fallback] : out;
}

/// Which of [set] a session runs on — its home: where its seed is read and
/// its own picks come from when the others can't answer. Alone, the one
/// server. With several the seed travels as a sound, so the home has to run
/// sonic similarity itself ([canLead]): [preferred] while it is one of them
/// and can, else the first that can — else [preferred] (or the first)
/// anyway, and the screen says why nobody else is asked. Pure; unit-tested.
Server? resolvePlayFromHome(
    List<Server> set, Server? preferred, bool Function(Server) canLead) {
  if (set.length < 2) return set.firstOrNull ?? preferred;
  final mine = set.contains(preferred) ? preferred : null;
  if (mine != null && canLead(mine)) return mine;
  return set.where(canLead).firstOrNull ?? mine ?? set.first;
}

/// Why a session across several servers can't run from [home], or null when
/// it can: the seed travels as a sound, so its home must run sonic
/// similarity itself — discovery on with vectors ready — and be new enough
/// to send a vector seed. A mood only narrows which other servers answer, so
/// it doesn't count here.
FanOutSitOut? fanOutHomeBlocked(Server home) {
  final why = AudioPlayerHandler.sitOutReason(home, const {});
  if (why != null) return why;
  if (home.sonicUsable) return null;
  return home.discoveryReady == false
      ? FanOutSitOut.scanning
      : FanOutSitOut.discoveryOff;
}

/// [resolvePlayFromSet] on the live lists: the servers Play from names.
List<Server> autoDjPlayFromSet() {
  final mgr = AutoDJManager();
  final sm = ServerManager();
  return resolvePlayFromSet(
    all: mgr.playFromAll,
    chosen: [...mgr.playFromServers, ?mgr.playFromServer],
    offered: serversGrouped(sm.serverList),
    fallback:
        resolvePlayFrom(mgr.playFromServer, sm.serverList, sm.currentServer),
  );
}

/// Play from's home on the live lists ([resolvePlayFromHome]): where Start,
/// the queue's Auto DJ button and CarPlay arm the DJ.
Server? autoDjPlayFrom() {
  final mgr = AutoDJManager();
  final sm = ServerManager();
  return resolvePlayFromHome(
      autoDjPlayFromSet(),
      resolvePlayFrom(mgr.playFromServer, sm.serverList, sm.currentServer),
      (s) => fanOutHomeBlocked(s) == null);
}
