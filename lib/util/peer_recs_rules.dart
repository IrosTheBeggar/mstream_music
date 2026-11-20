import 'package:flutter/foundation.dart' show immutable;

import '../objects/discovery.dart';
import '../objects/discovery_plugins.dart';
import '../objects/peer_recs.dart';
import 'discover_badges.dart' show nameKey;

/// The Peer Recommendations page's pure rules (mStream
/// docs/peer-recommendations-plan.md §3.5, §5): the peer strip as items, the
/// poll cadence, what an Add's answer means, when an Add has landed (R4),
/// the page's taste bodies (R1, R2), which state the page draws, and the
/// preview helpers (provider, 429 wait, lead key, earned art, Preview all's
/// next lead, Copy). Ports mStream webapp/alpha/peer-recs.js and the page
/// parts of webapp/alpha/discovery-page.js. No widgets, no I/O, no timers —
/// the controller and the previews wire it to the app.

/// R6: the strip polls every 15 s, every 3 s while a row it shows is being
/// added or one of this page's own Adds is still out.
const Duration kPeerPoll = Duration(seconds: 15),
    kPeerPollFast = Duration(seconds: 3);

/// R1: the page's own limits — a full seed batch, 32 leads.
const TasteLimits kPeerRecsLimits = TasteLimits(seeds: 12, network: 32);

final RegExp _endpointId = RegExp(r'^[0-9a-f]{64}$');

/// An endpoint id as the wire carries it: 64 lower-case hex, nothing else
/// (the webapp's isEndpointId) — checked before a tap selects or Adds.
bool isEndpointId(String? v) => v != null && _endpointId.hasMatch(v);

// ── the peer strip (webapp PR.stripItems) ───────────────────────────────

enum PeerItemKind { all, peer, add }

/// An add item's drawn state: "Adding…", "Try again" or "No room"; null on
/// the item is the plain "+".
enum PeerAddView { adding, failed, noRoom }

/// What a tap on an item does: select its tab, POST its Add, or nothing.
enum PeerItemAct { tab, add, none }

/// One item of the peer strip: All, a shelf peer (a tab), or — for an admin
/// — a peer it may Add. [label], [monogram] and [hue] are the server's,
/// verbatim; All carries none of them (the view draws its own word).
@immutable
class PeerStripItem {
  final PeerItemKind kind;

  /// The peer's endpoint id; null on All.
  final String? id;
  final String label;
  final String monogram;
  final int hue;
  final bool online;
  final bool selected;
  final PeerAddView? state;
  final PeerItemAct act;

  const PeerStripItem({
    required this.kind,
    this.id,
    this.label = '',
    this.monogram = '',
    this.hue = 0,
    this.online = false,
    this.selected = false,
    this.state,
    required this.act,
  });

  /// Every field joined: what a redraw compares (two items with the same
  /// signature draw the same).
  String get signature => [
        kind.name,
        id ?? '',
        label,
        monogram,
        '$hue',
        '$online',
        '$selected',
        state?.name ?? '',
        act.name,
      ].join('\u0000');

  @override
  String toString() => 'PeerStripItem(${signature.replaceAll('\u0000', ' | ')})';
}

/// A page-local Add state, and how many polls the page had sent when it
/// was set (stamped at the press and again when the POST answers).
typedef PeerLocalAdd = ({PeerAddView state, int poll});

/// The strip: its [items]; the [selected] tab to keep (null = All); whether
/// the selected peer left the shelf ([fallback]: select All and re-ask,
/// R5); and the [local] Add states that still stand, for the caller to
/// keep.
typedef PeerStrip = ({
  List<PeerStripItem> items,
  String? selected,
  bool fallback,
  Map<String, PeerLocalAdd> local,
});

/// The peers answer [view] as the strip draws it (webapp PR.stripItems):
/// All first (selected when [selected] is null), then the shelf rows in the
/// server's order, then — only when the caller may Add — the other rows in
/// the server's order, each with its Add state.
///
/// An add item shows a [local] entry while it stands — until a poll sent
/// after the entry was stamped answers: `!(poll != null && poll >
/// entry.poll)` — and the server's Add state after that (adding or done →
/// "Adding…", failed `no-room` → "No room", any other failure → "Try
/// again"). Its act is [PeerItemAct.add] for "+" and "Try again", nothing
/// for "Adding…" and "No room". A shelf row's Add state is ignored (the
/// server stamps it there too).
///
/// [view] null (the first poll still out): All alone, with [selected] and
/// [local] as they were. A [selected] peer that is no longer a shelf row
/// (offline still is one) falls back to All.
PeerStrip peerStripItems(PeerView? view,
    {String? selected,
    Map<String, PeerLocalAdd> local = const {},
    int? poll}) {
  PeerStripItem all(bool on) =>
      PeerStripItem(kind: PeerItemKind.all, selected: on, act: PeerItemAct.tab);
  if (view == null) {
    return (
      items: List.unmodifiable([all(selected == null)]),
      selected: selected,
      fallback: false,
      local: Map.of(local),
    );
  }
  final shelf = [
    for (final r in view.peers)
      if (r.onShelf) r
  ];
  final addable = [
    for (final r in view.peers)
      if (!r.onShelf && view.canAdd) r
  ];
  final fallback =
      selected != null && !shelf.any((r) => r.endpointId == selected);
  final keep = fallback ? null : selected;
  final kept = <String, PeerLocalAdd>{};
  final items = <PeerStripItem>[all(keep == null)];
  for (final r in shelf) {
    items.add(PeerStripItem(
      kind: PeerItemKind.peer,
      id: r.endpointId,
      label: r.label,
      monogram: r.monogram,
      hue: r.hue,
      online: r.online,
      selected: r.endpointId == keep,
      act: PeerItemAct.tab,
    ));
  }
  for (final r in addable) {
    final mine = local[r.endpointId];
    final PeerAddView? state;
    if (mine != null && !(poll != null && poll > mine.poll)) {
      kept[r.endpointId] = mine;
      state = mine.state;
    } else {
      state = _serverAdd(r.add);
    }
    items.add(PeerStripItem(
      kind: PeerItemKind.add,
      id: r.endpointId,
      label: r.label,
      monogram: r.monogram,
      hue: r.hue,
      online: r.online,
      state: state,
      act: state == null || state == PeerAddView.failed
          ? PeerItemAct.add
          : PeerItemAct.none,
    ));
  }
  return (
    items: List.unmodifiable(items),
    selected: keep,
    fallback: fallback,
    local: kept,
  );
}

/// An addable row's state from the server's Add state (webapp
/// PR.serverAddState; plan §5.6).
PeerAddView? _serverAdd(PeerAddState? add) {
  if (add == null) return null;
  switch (add.state) {
    case PeerAddKind.adding:
    case PeerAddKind.done: // not yet a shelf row: it lands on the next poll
      return PeerAddView.adding;
    case PeerAddKind.failed:
      return add.noRoom ? PeerAddView.noRoom : PeerAddView.failed;
  }
}

/// R6: the wait before the next poll — fast while any own Add POST is out
/// ([posting]) or an item shows "Adding…"; "Try again" and "No room" do not
/// hurry it (webapp PR.pollDelay).
Duration peerPollDelay(List<PeerStripItem> items, int posting) =>
    posting > 0 || items.any((i) => i.state == PeerAddView.adding)
        ? kPeerPollFast
        : kPeerPoll;

// ── Add (webapp PR.addOutcome) ──────────────────────────────────────────

enum PeerAddOutcome { adding, landed, noRoom, failed, gone, notAllowed }

/// What an Add's answer means for the strip (plan §5.6): the outcome, the
/// local state to draw until the next poll (null = drop it), and whether to
/// poll at once rather than on the cadence. Only the status and the stored
/// state are read; the server's words are never drawn.
///
///   202                         adding      "Adding…"
///   200 done                    landed      "Adding…" until the shelf row shows; poll now
///   200 adding                  adding      "Adding…"
///   200 failed no-room          noRoom      "No room", inert
///   200 failed, any other code  failed      "Try again"
///   404 / 409                   gone        the row goes; poll now
///   403 / 405                   notAllowed  canAdd comes back false; poll now
///   anything else (400, 401, 5xx, 0, a 200 with no state) failed "Try again"
({PeerAddOutcome outcome, PeerAddView? local, bool pollNow}) peerAddOutcome(
    PeerAddAnswer a) {
  final s = a.state;
  if (a.status == 202) {
    return (outcome: PeerAddOutcome.adding, local: PeerAddView.adding, pollNow: false);
  }
  if (a.status == 200 && s != null) {
    switch (s.state) {
      case PeerAddKind.done:
        return (outcome: PeerAddOutcome.landed, local: PeerAddView.adding, pollNow: true);
      case PeerAddKind.adding:
        return (outcome: PeerAddOutcome.adding, local: PeerAddView.adding, pollNow: false);
      case PeerAddKind.failed:
        if (s.noRoom) {
          return (outcome: PeerAddOutcome.noRoom, local: PeerAddView.noRoom, pollNow: false);
        }
    }
  }
  if (a.status == 404 || a.status == 409) {
    return (outcome: PeerAddOutcome.gone, local: null, pollNow: true);
  }
  if (a.status == 403 || a.status == 405) {
    return (outcome: PeerAddOutcome.notAllowed, local: null, pollNow: true);
  }
  return (outcome: PeerAddOutcome.failed, local: PeerAddView.failed, pollNow: false);
}

// ── R4 (webapp PR.landed, PR.emptied) ───────────────────────────────────

bool _held(PeerRow? r) =>
    r != null && (r.onShelf || r.add?.state == PeerAddKind.done);
bool _failed(PeerRow? r) => r?.add?.state == PeerAddKind.failed;

/// R4, between the peers answer the strip was drawn from ([prev], null
/// before the first) and the new one ([next]): [ids] are the [posted] ids
/// (this page's own Adds) now held — on the shelf, or their Add done — that
/// were not held before; [failed] those whose Add has just failed (the
/// caller stops tracking both). Re-ask when one landed, or when the page
/// shows "No peers yet" ([showingNoPeers]) and `shelf.searchable` went from
/// 0 to more. A rotation or another admin's Add only moves the strip.
({bool reask, List<String> ids, List<String> failed}) peerLanded(
    PeerView? prev, PeerView next, Set<String> posted,
    {required bool showingNoPeers}) {
  final ids = <String>[];
  final failed = <String>[];
  for (final id in posted) {
    final was = prev?.row(id);
    final now = next.row(id);
    if (_held(now) && !_held(was)) {
      ids.add(id);
    } else if (_failed(now) && !_failed(was)) {
      failed.add(id);
    }
  }
  final grew = (prev?.searchable ?? 0) == 0 && next.searchable > 0;
  return (
    reask: ids.isNotEmpty || (showingNoPeers && grew),
    ids: ids,
    failed: failed,
  );
}

/// Plan §2 item 18: `shelf.searchable` went from more to 0 — the shelf
/// emptied under the page, so the page asks again for its "No peers yet".
/// Nothing before the first answer.
bool peerEmptied(PeerView? prev, PeerView next) =>
    prev != null && prev.searchable > 0 && next.searchable == 0;

// ── requests (webapp DP.buildRequests page branch, DP.batchRequest) ─────

/// The longest pin path the route takes (its Joi `string().max(2048)`).
const int _pinPathMax = 2048;

/// [paths] as the route's `pin` takes them (webapp DP.buildRequests and
/// DP.seedPins): every leading '/' off for the check, an empty, an
/// over-long or a repeated path skipped, at most [kTastePinMax], in order.
/// Each comes back as an app path ('/'-prefixed), which
/// [TasteRequest.toJson] strips.
List<String> _pinsOf(Iterable<String> paths) {
  final pins = <String>[];
  final seen = <String>{};
  for (final raw in paths) {
    if (pins.length >= kTastePinMax) break;
    final path = raw.replaceFirst(_leadingSlashes, '');
    if (path.isEmpty || path.length > _pinPathMax || !seen.add(path)) {
      continue;
    }
    pins.add('/$path');
  }
  return pins;
}

final RegExp _leadingSlashes = RegExp(r'^/+');

/// R1, the page's ask for a new batch: the network alone, its own
/// [kPeerRecsLimits], never new-artists-only, a walk on a random seed too
/// (`networkOnRandomSeed`), [pins] (the open's now playing, the user's
/// picks), and the tab's [peer] as `networkPeers` (none for All). Never
/// moods: any mood filter makes the server leave the network out.
TasteRequest peerRecsRequest(
    {required int window,
    List<String> pins = const [],
    List<String>? exclude,
    String? peer}) {
  final pin = _pinsOf(pins);
  return TasteRequest(
    window: window,
    pin: pin.isEmpty ? null : pin,
    exclude: exclude,
    sources: const {TasteSource.network},
    limit: kPeerRecsLimits,
    newArtistsOnly: false,
    networkPeers: peer == null ? null : [peer],
    networkOnRandomSeed: true,
  );
}

/// The batch's seeds as pins (webapp DP.seedPins): every seed's path, in
/// order, as an app path ('/'-prefixed; [TasteRequest.toJson] strips it),
/// non-empty, at most 2048 chars without its leading '/', de-duplicated, at
/// most [kTastePinMax] — a random pick included.
List<String> peerBatchPins(TasteResponse batch) =>
    _pinsOf([for (final s in batch.seeds) s.filepath]);

/// R2/R4/R5, a re-ask on the batch on screen (webapp DP.batchRequest): the
/// R1 body pinned to every seed of the batch's first answer (its random
/// pick too: the page walks the network on it) with `limit.seeds` = their
/// count, so the server draws no seed of its own and the chips stay true;
/// the tab's [peer] as `networkPeers`. Null when the batch has no seed with
/// a path (the caller then asks a new batch).
TasteRequest? peerRecsBatchRequest(TasteResponse batch,
    {required int window, List<String>? exclude, String? peer}) {
  final pins = peerBatchPins(batch);
  if (pins.isEmpty) return null;
  return TasteRequest(
    window: window,
    pin: pins,
    exclude: exclude,
    sources: const {TasteSource.network},
    limit: TasteLimits(seeds: pins.length, network: kPeerRecsLimits.network),
    newArtistsOnly: false,
    networkPeers: peer == null ? null : [peer],
    networkOnRandomSeed: true,
  );
}

/// An answer with no pick left (webapp DP.noPickLeft): no seed at all on a
/// random or scan-pending answer — the random fallback found no song
/// outside the visit's exclusions. With passed picks in the ask, the page
/// clears them and asks once more.
bool peerNoPickLeft(TasteResponse r) =>
    r.seeds.isEmpty &&
    (r.seedSource == TasteSeedSource.random || r.notAnalyzed);

// ── state (webapp DP.networkState / DP.stateOf, page branch) ────────────

enum PeerRecsState { loading, failed, scanPending, noPeers, nothingNew, ready }

/// Which state the page draws for the answer [shown] (webapp
/// DP.networkState, DP.stateOf; plan §2 item 18):
///   - a 403 with the flags still on ([disabled]) → scan pending (phone
///     Discover's rule);
///   - no answer → [loading] while one is out, else failed ("Try again");
///   - no seed analyzed, or the reason `scan-pending` → scan pending;
///   - no network section (a random answer with p2p off) → failed;
///   - leads → ready: rows win over any reason;
///   - the reason `error` → failed;
///   - `empty-shelf` / `no-compatible`, or a shelf with nothing searchable
///     ([peers]) → "No peers yet";
///   - else "Nothing new".
/// A random answer with a network section is never "nothing finished" here:
/// the page walks the network on the pick (DP:1508).
PeerRecsState peerRecsStateOf(
    {required TasteResponse? shown,
    required bool loading,
    required bool disabled,
    PeerView? peers}) {
  if (disabled) return PeerRecsState.scanPending;
  if (shown == null) {
    return loading ? PeerRecsState.loading : PeerRecsState.failed;
  }
  final net = shown.network;
  if (shown.notAnalyzed || net?.reason == NetworkReason.scanPending) {
    return PeerRecsState.scanPending;
  }
  if (net == null) return PeerRecsState.failed;
  if (net.results.isNotEmpty) return PeerRecsState.ready;
  if (net.reason == NetworkReason.error) return PeerRecsState.failed;
  if (net.reason == NetworkReason.emptyShelf ||
      net.reason == NetworkReason.noCompatible ||
      peers?.searchable == 0) {
    return PeerRecsState.noPeers;
  }
  return PeerRecsState.nothingNew;
}

// ── previews (webapp PR.previewProvider … PR.copyListText) ──────────────

/// A page clip's state: asking the plug-in, waiting out a 429, loading the
/// clip, playing it, paused by the user; idle when none.
enum PeerClipStatus { idle, resolving, waiting, loading, playing, paused }

/// A card's play circle: none drawn (no provider), ready, busy (resolving,
/// waiting, loading), the live clip playing or paused, or muted (no preview
/// this visit — drawn, inert).
enum PeerCircle { hidden, idle, busy, playing, paused, muted }

/// Where the live clip is, for the band's hairline.
typedef PeerClipProgress = ({Duration position, Duration length});

/// The one plug-in that previews for the page (plan §2 item 12): the first
/// in the listing's order that can run here and has the preview capability.
/// There is no second: a miss is "No preview". (The webapp reads only the
/// listing-level flag; the phone also skips a plug-in that cannot run, as
/// the sheet's rows do.)
DiscoveryPlugin? peerPreviewProvider(PluginListing? listing) {
  for (final p in listing?.plugins ?? const <DiscoveryPlugin>[]) {
    if (p.available &&
        p.name.trim().isNotEmpty &&
        p.hasCapability(kCapPreview)) {
      return p;
    }
  }
  return null;
}

/// Plan §5.5: how long a 429 waits before its one retry — the providers'
/// own limiters (deezer 40 calls / 5 s, itunes 18 / min).
Duration peerRetryDelay(String plugin) => plugin == kItunesPlugin
    ? const Duration(seconds: 60)
    : const Duration(seconds: 5);

/// Plan §5.3: one lead across answers and tabs — the live clip, the visit's
/// preview answers, the sheet it is open in. The peer's endpoint id and the
/// snapshot's export id; without an export id, the folded artist, title and
/// album (nameKey, mStream src/db/name-key.js). Earned art is keyed on the
/// tile key, not on this.
String peerLeadKey(DiscoveryLead lead) {
  final id = lead.endpointId ?? '';
  final exportId = lead.exportId;
  if (exportId != null && exportId.isNotEmpty) return '$id\u0000$exportId';
  return '$id\u0000${nameKey(lead.artist)}|${nameKey(lead.title)}|'
      '${nameKey(lead.album)}';
}

/// Plan §2 item 10: a preview's artwork stands in for the tile of every
/// lead sharing [lead]'s tile key only when it is https and the preview
/// found the lead's own album — nameKey-equal album (the lead's non-empty)
/// and artist.
bool peerArtMatches(DiscoveryLead lead, PluginPreview p) {
  final art = p.artwork;
  if (art == null || !art.isScheme('https') || art.host.isEmpty) return false;
  final album = nameKey(lead.album);
  return album.isNotEmpty &&
      nameKey(p.album) == album &&
      nameKey(p.artist) == nameKey(lead.artist);
}

/// Preview all's next lead: the first index after [index] (-1 = from the
/// top) whose lead is not skipped (the visit's "No preview" leads), else -1
/// (the end).
int peerNextIndex(List<DiscoveryLead> list, int index,
    bool Function(DiscoveryLead) skip) {
  for (var i = index >= 0 ? index + 1 : 0; i < list.length; i++) {
    if (!skip(list[i])) return i;
  }
  return -1;
}

/// Plan §5.7: "Artist - Title", the title alone when the artist is blank,
/// the artist alone when the title is — trimmed, as sent (no case fold).
/// [DiscoveryLead.copyText] has the same shape but trims nothing (nor does
/// the parser's text check), so the page uses this.
String peerCopyText(DiscoveryLead lead) {
  final artist = lead.artist.trim();
  final title = lead.title.trim();
  if (artist.isEmpty) return title;
  return title.isEmpty ? artist : '$artist - $title';
}

/// Copy list: [leads] in order, one line each, empty lines dropped, no
/// trailing newline.
String peerCopyListText(List<DiscoveryLead> leads) => leads
    .map(peerCopyText)
    .where((line) => line.isNotEmpty)
    .join('\n');
