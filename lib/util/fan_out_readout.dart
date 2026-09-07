import '../objects/server.dart';

/// The fan-out candidates that can't answer yet: their transport is a tunnel
/// that [serves] says is not live — dialing after the session was armed, or
/// reconnecting. They count as taking part (the session keeps them as tunnel
/// targets), so the readout names how many are still on their way rather
/// than let the first pick look short. Pure; unit-tested.
List<Server> fanOutConnecting(
    Iterable<Server> candidates, bool Function(Server) serves) {
  return [
    for (final s in candidates)
      if (s.isIrohTransport && !serves(s)) s,
  ];
}
