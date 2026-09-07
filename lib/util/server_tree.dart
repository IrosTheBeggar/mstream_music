import '../objects/server.dart';

/// The server list in display order: every server in its stored order, with
/// each federated peer moved to sit directly under the parent it is reached
/// through. The stored list appends peers as the reconcile finds them, so
/// without this a peer lands after servers that have nothing to do with it
/// and the relationship is only legible from its "via" line. A peer whose
/// parent is not in the list at all (a record that outlived its parent)
/// keeps its place at the end. Pure; unit-tested.
List<Server> serversGrouped(List<Server> stored) {
  final out = <Server>[];
  final placed = <Server>{};
  for (final s in stored) {
    if (s.isFederated) continue;
    out.add(s);
    placed.add(s);
    for (final p in stored) {
      if (p.isFederated && p.federationParent == s.localname) {
        out.add(p);
        placed.add(p);
      }
    }
  }
  for (final s in stored) {
    if (!placed.contains(s)) out.add(s);
  }
  return out;
}

/// The glyph that draws a peer as a branch off the row above it.
const String kPeerBranch = '\u2514';
