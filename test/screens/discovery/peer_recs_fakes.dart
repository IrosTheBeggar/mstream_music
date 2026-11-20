// Shared fakes for the Peer Recommendations page's tests (owned by piece I
// of the phone build plan; every other piece imports this read-only).
//
// FakePeerRecs scripts the page's four dependencies — the taste route, the
// peers poll, an Add and R7's re-ping — and records what each was asked.
// Each call is answered at once by its `auto` (or queued) answer, or held on
// a Completer the test completes itself. makeController wires them into a
// PeerRecsController with FakeTimers (the test fires each poll) and no
// lifecycle watch (the test calls didChangeAppLifecycleState).

import 'dart:async';

import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/peer_recs.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/peer_recs_controller.dart';

import '../discovery_plugin_fakes.dart';
import 'peer_recs_fixtures.dart';

/// A server whose flags offer the page (plan §2 item 2): discovery, the
/// network, taste generation 3 and the peers route.
Server peerRecsServer({bool on = true}) =>
    Server('http://music.example', null, null, 'JWT', 'home')
      ..discoveryAvailable = true
      ..discoveryTasteAvailable = true
      ..discoveryP2pAvailable = true
      ..peerRecsAvailable = on;

/// A taste answer as the route's fetch returns it.
DiscoveryFetchResult<TasteResponse> tasteOk(Map<String, dynamic> json) =>
    DiscoveryFetchResult.ok(parseTaste(json));

/// The taste route refused (a 403).
const DiscoveryFetchResult<TasteResponse> tasteRefused =
    DiscoveryFetchResult.disabled();

/// No taste answer (transport, 5xx).
const DiscoveryFetchResult<TasteResponse> tasteFailed =
    DiscoveryFetchResult.error();

/// A peers poll's 200.
PeersAnswer peersOk(Map<String, dynamic> json) =>
    PeersAnswer(200, parsePeers(json));

/// An Add's answer: [status] and, for a body, its state and code.
PeerAddAnswer addAnswer(int status, [String? state, String? code]) =>
    PeerAddAnswer(
        status,
        state == null
            ? null
            : PeerAddState.fromServerMap({'state': state, 'code': code}));

/// The page's routes and its re-ping, scripted.
class FakePeerRecs {
  FakePeerRecs({Server? server}) : server = server ?? peerRecsServer();

  final Server server;

  // ── taste ──

  /// Every taste request, in order.
  final List<TasteRequest> requests = [];

  /// The held taste calls, in order (when [auto] is null).
  final List<Completer<DiscoveryFetchResult<TasteResponse>>> pending = [];

  /// Answers every taste call at once when set.
  DiscoveryFetchResult<TasteResponse> Function(TasteRequest)? auto;

  Future<DiscoveryFetchResult<TasteResponse>> taste(Server s, TasteRequest r) {
    requests.add(r);
    final a = auto;
    if (a != null) return Future.value(a(r));
    final c = Completer<DiscoveryFetchResult<TasteResponse>>();
    pending.add(c);
    return c.future;
  }

  /// The bodies sent, as JSON.
  List<Map<String, dynamic>> get bodies =>
      [for (final r in requests) r.toJson()];

  /// Answer the oldest held taste call still out.
  void answerTaste(DiscoveryFetchResult<TasteResponse> r) =>
      pending.firstWhere((c) => !c.isCompleted).complete(r);

  // ── peers ──

  /// Peers polls sent.
  int polls = 0;

  /// Answers queued for the next polls, oldest first; then [peersAuto];
  /// else the poll is held in [peersPending].
  final List<PeersAnswer> peersQueue = [];
  PeersAnswer Function()? peersAuto;
  final List<Completer<PeersAnswer>> peersPending = [];

  Future<PeersAnswer> peers() {
    polls++;
    if (peersQueue.isNotEmpty) return Future.value(peersQueue.removeAt(0));
    final a = peersAuto;
    if (a != null) return Future.value(a());
    final c = Completer<PeersAnswer>();
    peersPending.add(c);
    return c.future;
  }

  // ── Add ──

  /// Every Add posted, by endpoint id.
  final List<String> adds = [];
  final List<PeerAddAnswer> addQueue = [];
  PeerAddAnswer Function(String id)? addAuto;
  final List<Completer<PeerAddAnswer>> addPending = [];

  Future<PeerAddAnswer> add(String id) {
    adds.add(id);
    if (addQueue.isNotEmpty) return Future.value(addQueue.removeAt(0));
    final a = addAuto;
    if (a != null) return Future.value(a(id));
    final c = Completer<PeerAddAnswer>();
    addPending.add(c);
    return c.future;
  }

  // ── R7's re-ping ──

  /// Re-pings sent.
  int repings = 0;

  /// False: the server does not answer (off, as on the web).
  bool repingAnswers = true;

  /// The page's flag after an answered re-ping; null leaves it as it is.
  bool? repingPeerRecs;

  /// Holds every re-ping until the test completes its entry in
  /// [repingWaits].
  bool holdRepings = false;
  final List<Completer<void>> repingWaits = [];

  Future<bool> reping(Server s) async {
    repings++;
    if (holdRepings) {
      final c = Completer<void>();
      repingWaits.add(c);
      await c.future;
    }
    if (!repingAnswers) return false;
    final on = repingPeerRecs;
    if (on != null) s.peerRecsAvailable = on;
    return true;
  }

  // ── the window and the clock ──

  /// The phone's remembered window (SettingsManager in the app), and every
  /// save.
  int stored = kTasteDefaultWindow;
  final List<int> saves = [];
  DateTime clock = DateTime.utc(2026, 11, 19, 12);

  final FakeTimers timers = FakeTimers();

  /// A controller over these fakes: FakeTimers, no lifecycle watch.
  PeerRecsController makeController({String? pinAtOpen, Server? server}) =>
      PeerRecsController(
        server: server ?? this.server,
        fetchPeers: peers,
        postAdd: add,
        fetch: taste,
        reping: reping,
        readWindow: () => stored,
        saveWindow: (w) {
          stored = w;
          saves.add(w);
        },
        now: () => clock,
        pinAtOpen: pinAtOpen,
        timer: timers.call,
        watchLifecycle: false,
      );
}
