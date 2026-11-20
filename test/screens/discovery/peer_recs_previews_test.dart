// The Peer Recommendations page's clip session (lib/screens/discovery/
// peer_recs_previews.dart) over a resolve the test answers, manual timers,
// and the preview player: FakePreviewPlayer for most, the real engine over
// FakePreviewPort / FakePreviewClip where a load in flight or a held flow
// matters. Each test cites the webapp test it ports (mStream
// test/unit/webapp-discovery-panel.test.mjs ":n", webapp-peer-recs-clip
// .test.mjs "clip :n", webapp/alpha/vp.js "vp.js:n").

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/preview_player.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/screens/discovery/peer_recs_previews.dart';
import 'package:mstream_music/screens/discovery/preview_answers.dart';
import 'package:mstream_music/util/discovery_plugins_api.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';

import '../../media/preview_fakes.dart';
import '../discovery_plugin_fakes.dart' show FakeTimer, FakeTimers, settle;
import 'peer_recs_fixtures.dart';

const DiscoveryPlugin _deezer = DiscoveryPlugin(
    name: kDeezerPlugin,
    title: 'Preview on Deezer',
    capabilities: [kCapPreview]);
const DiscoveryPlugin _itunes = DiscoveryPlugin(
    name: kItunesPlugin,
    title: 'Preview on iTunes',
    capabilities: [kCapPreview]);

/// One resolve the session sent, answered when the test says.
class _Ask {
  _Ask(this.plugin, this.rec);
  final String plugin;
  final Map<String, dynamic> rec;
  final Completer<PluginPreview?> answer = Completer<PluginPreview?>();
  String get title => rec['title'] as String;
}

class _Resolver {
  final List<_Ask> asks = [];

  Future<PluginPreview?> call(String plugin, Map<String, dynamic> rec) {
    final a = _Ask(plugin, rec);
    asks.add(a);
    return a.answer.future;
  }

  List<String> get titles => [for (final a in asks) a.title];
  List<_Ask> get open => [
        for (final a in asks)
          if (!a.answer.isCompleted) a,
      ];

  /// The oldest open resolve answers 200 with [p] (null: no preview).
  Future<void> answer(PluginPreview? p) async {
    open.first.answer.complete(p);
    await settle();
  }

  /// The oldest open resolve fails with [status] (0: no answer).
  Future<void> fail(int status) async {
    open.first.answer
        .completeError(DiscoveryPluginsException(status, 'HTTP $status'));
    await settle();
  }
}

/// [l]'s clip from [provider], matching its album (https art by default);
/// [signed] stands for the signature a CDN address carries (a fresh
/// answer's differs from an expired one's).
PluginPreview clipOf(DiscoveryLead l,
        {String provider = kDeezerPlugin,
        String? artwork = 'https://cdn.example/cover.jpg',
        String? album,
        String? signed}) =>
    PluginPreview(
      provider: provider,
      url: Uri.parse('https://cdn.example/${Uri.encodeComponent(l.title)}.mp3'
          '${signed == null ? '' : '?sig=$signed'}'),
      title: l.title,
      artist: l.artist,
      album: album ?? l.album,
      attribution: 'Preview from $provider',
      link: Uri.parse('https://store.example/${Uri.encodeComponent(l.title)}'),
      artwork: artwork == null ? null : Uri.parse(artwork),
      match: 1,
    );

void main() {
  late FakePreviewPlayer engine;
  late FakeTimers timers;
  late _Resolver resolver;
  late DiscoveryPlugin? provider;
  late int misses;
  late int refusals;
  late List<PeerClipStatus> statusAtCallback;

  final all = parseLeads(tasteJson());
  DiscoveryLead lead(String title) => all.firstWhere((l) => l.title == title);
  final saltRoad = lead('Salt Road');
  final breakwater = lead('Breakwater');
  final signal = lead('Signal Fires');
  final harbor = lead('Harbor Lights');
  final glass = lead('Glass Season');
  final quiet = lead('Quiet Engine');
  String keyOf(DiscoveryLead l) => peerLeadKey(l);

  setUp(() {
    engine = FakePreviewPlayer.install();
    timers = FakeTimers();
    resolver = _Resolver();
    provider = _deezer;
    misses = 0;
    refusals = 0;
    statusAtCallback = [];
  });

  late PeerRecsPreviews previews;

  PeerRecsPreviews make({PreviewAnswers? answers}) {
    late PeerRecsPreviews p;
    p = PeerRecsPreviews(
      resolve: resolver.call,
      provider: () => provider,
      answers: answers,
      timer: timers.call,
      watchLifecycle: false,
      onMiss: () {
        misses++;
        statusAtCallback.add(p.status);
      },
      onRefused: () {
        refusals++;
        statusAtCallback.add(p.status);
      },
    );
    addTearDown(p.dispose);
    return previews = p;
  }

  Future<void> press(DiscoveryLead l, [List<DiscoveryLead>? list]) async {
    unawaited(previews.press(l, list ?? all));
    await settle();
  }

  Future<void> previewAll(List<DiscoveryLead> list) async {
    unawaited(previews.previewAll(list));
    await settle();
  }

  /// [l] pressed and its clip playing (fake engine).
  Future<void> playing(DiscoveryLead l, [List<DiscoveryLead>? list]) async {
    await press(l, list);
    await resolver.answer(clipOf(l));
    expect(previews.status, PeerClipStatus.playing);
  }

  Future<void> emit(PreviewClipState s) async {
    engine.emit(s);
    await settle();
  }

  /// The page's own clip, [seconds] in.
  PreviewClipState at(int seconds) => PreviewClipState(
      provider: kDeezerPlugin,
      phase: PreviewPhase.playing,
      position: Duration(seconds: seconds),
      duration: const Duration(seconds: 30),
      owner: previews);

  List<FakeTimer> live(Duration d) =>
      [for (final t in timers.made) if (t.isActive && t.delay == d) t];

  Iterable<({PreviewEnd reason, Object? owner})> ourEnds() =>
      engine.endCalls.where((c) => identical(c.owner, previews));

  /// The real engine over a scripted song side and clip, as the app's
  /// PreviewPlayer; every flow ended and the fake put back afterwards.
  ({PreviewPlayer player, FakePreviewPort port, FakePreviewClip clip})
      realEngine({bool holdLoads = false, bool songPlaying = true}) {
    final port = FakePreviewPort(songPlaying: songPlaying);
    final clip = FakePreviewClip()..holdLoads = holdLoads;
    final player = PreviewPlayer.withPort(port, makeClip: () => clip);
    final previous = PreviewPlayer.instance;
    PreviewPlayer.instance = player;
    addTearDown(() async {
      await player.end(PreviewEnd.sheetClosed);
      PreviewPlayer.instance = previous;
    });
    return (player: player, port: port, clip: clip);
  }

  group('provider and resolve', () {
    test('no provider → hidden circles, no resolve (panel :3246)', () async {
      provider = null;
      make();
      for (final l in all) {
        expect(previews.circleOf(l), PeerCircle.hidden);
      }
      await press(signal);
      await previewAll(all);
      expect(resolver.asks, isEmpty);
      expect(previews.status, PeerClipStatus.idle);
      expect(previews.providerPlugin, isNull);

      // A lead with no recommendation to send has no circle either, and
      // Preview all passes it by.
      provider = _deezer;
      final odd = DiscoveryLead.fromServerMap(
          leadJson(title: 'Odd One', exportId: 42))!;
      expect(odd.recommendation, isNull);
      expect(previews.circleOf(odd), PeerCircle.hidden);
      expect(previews.circleOf(signal), PeerCircle.idle);
      await press(odd);
      expect(resolver.asks, isEmpty);
      await previewAll([odd, signal]);
      expect(resolver.titles, ['Signal Fires']);
    });

    test('a press: one resolve with {recommendation: lead.recommendation}, '
        'then play(owner, holdOnComplete:false); the attribution is the '
        "answer's (panel :3202, clip :346)", () async {
      make();
      await press(signal);
      expect(previews.status, PeerClipStatus.resolving);
      expect(previews.circleOf(signal), PeerCircle.busy);
      expect(previews.live, same(signal));
      expect(resolver.asks.single.plugin, kDeezerPlugin);
      expect(resolver.asks.single.rec, signal.recommendation);
      expect(engine.plays, isEmpty, reason: 'nothing plays before it answers');

      final clip = deezerPreview();
      await resolver.answer(clip);
      final play = engine.plays.single;
      expect(play.provider, kDeezerPlugin);
      expect(play.url, clip.url);
      expect(play.owner, same(previews));
      expect(play.holdOnComplete, isFalse);
      expect(previews.status, PeerClipStatus.playing);
      expect(previews.circleOf(signal), PeerCircle.playing);
      expect(previews.preview?.attribution, 'Preview from Deezer');
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin)?.found,
          same(clip));
      expect(previews.chain, isFalse);
      expect(engine.pauses, 0);
      expect(previews.progress.value.length, const Duration(seconds: 30));

      await emit(at(12));
      expect(previews.progress.value.position, const Duration(seconds: 12));
    });

    test('a press during a flight queues; a newer one replaces it; sent '
        '300 ms after (clip :357, :369)', () async {
      make();
      await press(saltRoad);
      await press(breakwater);
      await press(signal);
      expect(resolver.titles, ['Salt Road'], reason: 'one in flight');
      expect(previews.live, same(signal));

      await resolver.answer(clipOf(saltRoad));
      expect(engine.plays, isEmpty, reason: 'Salt Road is no longer the clip');
      expect(previews.answers.of(keyOf(saltRoad), kDeezerPlugin)?.found,
          isNotNull, reason: 'a stale 200 is still kept for the visit');
      expect(resolver.titles, ['Salt Road'], reason: 'not yet');
      final queue = live(const Duration(milliseconds: 300));
      expect(queue, hasLength(1));

      queue.single.fire();
      await settle();
      expect(resolver.titles, ['Salt Road', 'Signal Fires'],
          reason: 'Breakwater was replaced');
      await resolver.answer(clipOf(signal));
      expect(engine.plays.single.url, clipOf(signal).url);
    });
  });

  group('429 and failures', () {
    test('429 → waiting 5 s (deezer) → one retry → plays; itunes waits 60 s '
        '(clip :381, :390)', () async {
      make();
      await press(signal);
      await resolver.fail(429);
      expect(previews.status, PeerClipStatus.waiting);
      expect(previews.circleOf(signal), PeerCircle.busy);
      expect(misses, 0);
      final wait = live(const Duration(seconds: 5));
      expect(wait, hasLength(1));

      wait.single.fire();
      await settle();
      expect(resolver.titles, ['Signal Fires', 'Signal Fires']);
      await resolver.answer(clipOf(signal));
      expect(previews.status, PeerClipStatus.playing);
      expect(engine.plays, hasLength(1));

      await previews.stop();
      provider = _itunes;
      previews.providerCheck();
      await press(harbor);
      await resolver.fail(429);
      expect(resolver.asks.last.plugin, kItunesPlugin);
      expect(live(const Duration(seconds: 60)), hasLength(1));
      expect(live(const Duration(seconds: 5)), isEmpty);
    });

    test('a second 429 or a transport error → failed: onMiss after idle, '
        'not remembered, the next press asks again (clip :405)', () async {
      make();
      await press(signal);
      await resolver.fail(429);
      live(const Duration(seconds: 5)).single.fire();
      await settle();
      await resolver.fail(429);
      expect(previews.status, PeerClipStatus.idle);
      expect(misses, 1);
      expect(statusAtCallback, [PeerClipStatus.idle]);
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin), isNull);
      expect(previews.circleOf(signal), PeerCircle.idle);
      expect(live(const Duration(seconds: 5)), isEmpty, reason: 'once only');

      await press(signal);
      expect(resolver.asks, hasLength(3));
      await resolver.fail(0);
      expect(previews.status, PeerClipStatus.idle);
      expect(misses, 2);

      await press(signal);
      await resolver.fail(502);
      expect(misses, 3);
      await press(signal);
      expect(resolver.asks, hasLength(5), reason: 'never remembered');
      expect(engine.plays, isEmpty);
    });

    // Round 3's W4: a found answer whose clip would not play (a Deezer
    // address that expired) used to be replayed on every press.
    test('a clip that would not play: failed for this press, onMiss once, '
        'and the visit forgets its answer, so the next press asks again and '
        'plays the new one; a clip that plays is kept; in Preview all a '
        'failed clip ends the chain and is forgotten too', () async {
      make();
      var told = 0;
      previews.answers.addListener(() => told++);
      engine.outcome = PreviewPlayOutcome.failed;
      await press(signal);
      await resolver.answer(clipOf(signal, signed: 'expired'));
      expect(previews.status, PeerClipStatus.idle);
      expect(misses, 1);
      expect(previews.circleOf(signal), PeerCircle.idle);
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin), isNull,
          reason: 'the dead address is forgotten');
      expect(told, 2, reason: 'kept, then forgotten');

      engine.outcome = PreviewPlayOutcome.playing;
      await press(signal);
      expect(resolver.asks, hasLength(2), reason: 'asked again');
      await resolver.answer(clipOf(signal, signed: 'fresh'));
      expect(previews.status, PeerClipStatus.playing);
      expect(engine.plays.last.url, clipOf(signal, signed: 'fresh').url);
      await previews.stop();
      await press(signal);
      expect(resolver.asks, hasLength(2), reason: 'a clip that played is kept');
      expect(engine.plays, hasLength(3));
      await previews.stop();

      engine.outcome = PreviewPlayOutcome.failed;
      await previewAll([signal, harbor]);
      expect(previews.status, PeerClipStatus.idle);
      expect(previews.chain, isFalse);
      expect(resolver.asks, hasLength(2), reason: 'Harbor Lights never asked');
      expect(misses, 1, reason: 'Preview all ends quietly');
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin), isNull);
    });

    test('a stored clip that breaks while it plays (the real engine): the '
        'visit forgets its answer; the next press asks again', () async {
      final rig = realEngine();
      final store = PreviewAnswers()
        ..put(keyOf(harbor), kDeezerPlugin, clipOf(harbor, signed: 'expired'));
      make(answers: store);
      await press(harbor);
      expect(resolver.asks, isEmpty, reason: "the store's answer plays");
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.clip.loads.single, clipOf(harbor, signed: 'expired').url);

      rig.clip.breakDown();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(misses, 1);
      expect(store.of(keyOf(harbor), kDeezerPlugin), isNull);

      await press(harbor);
      expect(resolver.titles, ['Harbor Lights']);
      await resolver.answer(clipOf(harbor, signed: 'fresh'));
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.clip.loads.last, clipOf(harbor, signed: 'fresh').url);
      expect(store.of(keyOf(harbor), kDeezerPlugin)!.found!.url,
          clipOf(harbor, signed: 'fresh').url);
    });

    test('a stored clip that would not load (the real engine), and one that '
        'failed after another lead was pressed: each is forgotten; an answer '
        'given since at another address stays', () async {
      final rig = realEngine(holdLoads: true);
      final store = PreviewAnswers()
        ..put(keyOf(harbor), kDeezerPlugin, clipOf(harbor, signed: 'expired'))
        ..put(keyOf(signal), kDeezerPlugin, clipOf(signal, signed: 'expired'));
      make(answers: store);
      await press(harbor);
      expect(previews.status, PeerClipStatus.loading);
      rig.clip.failLoad(StateError('403 from the CDN'));
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(store.of(keyOf(harbor), kDeezerPlugin), isNull);

      // Signal Fires' clip loads; another lead is pressed and asked for
      // meanwhile; then Signal Fires' clip breaks.
      await press(signal);
      rig.clip.finishLoad();
      await settle();
      expect(previews.status, PeerClipStatus.playing);
      await press(glass);
      expect(previews.live, same(glass));
      expect(rig.player.state.value.phase, PreviewPhase.paused);
      rig.clip.breakDown();
      await settle();
      expect(store.of(keyOf(signal), kDeezerPlugin), isNull,
          reason: "a dead address, whoever's session it was");

      // A failure for an address the store no longer holds leaves the new
      // answer alone.
      store.put(keyOf(signal), kDeezerPlugin, clipOf(signal, signed: 'fresh'));
      expect(store.forget(keyOf(signal), kDeezerPlugin,
          clipOf(signal, signed: 'expired').url), isFalse);
      expect(store.of(keyOf(signal), kDeezerPlugin)!.found!.url,
          clipOf(signal, signed: 'fresh').url);
    });

    test('403/404 → the answers and earned art are forgotten, idle, then '
        'onRefused (clip :543)', () async {
      make();
      await playing(signal);
      expect(previews.cardArt(harbor), isNotNull);
      expect(previews.answers.length, 1);

      await press(breakwater);
      expect(engine.pauses, 1, reason: 'Signal Fires silenced at once');
      await resolver.fail(403);
      expect(previews.answers.length, 0);
      expect(previews.cardArt(signal), isNull);
      expect(previews.bandArt(harbor), isNull);
      expect(previews.status, PeerClipStatus.idle);
      expect(refusals, 1);
      expect(statusAtCallback, [PeerClipStatus.idle]);
      expect(misses, 0);
      expect(ourEnds().map((c) => c.reason), [PreviewEnd.stopped],
          reason: "the page's paused flow ends");

      await press(breakwater);
      await resolver.fail(404);
      expect(refusals, 2);
      expect(previews.status, PeerClipStatus.idle);
    });
  });

  group('none and shared answers', () {
    test('preview null → none for the visit: muted, store none, onMiss on a '
        'single press (clip :420)', () async {
      make();
      await press(signal);
      await resolver.answer(null);
      expect(previews.circleOf(signal), PeerCircle.muted);
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin)?.none, isTrue);
      expect(previews.status, PeerClipStatus.idle);
      expect(misses, 1);
      expect(statusAtCallback, [PeerClipStatus.idle]);

      await press(signal);
      expect(resolver.asks, hasLength(1), reason: 'muted: inert');
      expect(engine.plays, isEmpty);
    });

    test('an answered lead (or one the sheet answered) plays with no '
        'resolve (panel :3541, :3552, clip :678-805)', () async {
      final store = PreviewAnswers();
      make(answers: store);
      // What a sheet's Deezer row found for Harbor Lights.
      store.put(keyOf(harbor), kDeezerPlugin, clipOf(harbor));
      await press(harbor);
      expect(resolver.asks, isEmpty);
      expect(engine.plays.single.url, clipOf(harbor).url);
      expect(previews.status, PeerClipStatus.playing);

      // The page's own answer, pressed again after a stop.
      await previews.stop();
      await playing(signal);
      expect(resolver.asks, hasLength(1));
      await previews.stop();
      await press(signal);
      expect(resolver.asks, hasLength(1));
      expect(engine.plays, hasLength(3));

      // A sheet's none: muted, nothing asked.
      store.put(keyOf(glass), kDeezerPlugin, null);
      await press(glass);
      expect(resolver.asks, hasLength(1));
      expect(previews.circleOf(glass), PeerCircle.muted);
    });

    test('a store none written by someone else notifies the page at once: '
        'the circle reads muted', () async {
      make();
      var notes = 0;
      previews.addListener(() => notes++);
      previews.answers.put(keyOf(harbor), kDeezerPlugin, null);
      expect(notes, 1);
      expect(previews.circleOf(harbor), PeerCircle.muted);

      // Another plug-in's none is not the provider's.
      previews.answers.put(keyOf(glass), kItunesPlugin, null);
      expect(notes, 2);
      expect(previews.circleOf(glass), PeerCircle.idle);
    });
  });

  group('toggle, switch and gen fence', () {
    test("the live lead's circle pauses then resumes; while resolving it "
        'stops (clip :573)', () async {
      make();
      await playing(signal);
      await press(signal);
      expect(engine.pauses, 1);
      expect(previews.status, PeerClipStatus.paused);
      expect(previews.circleOf(signal), PeerCircle.paused);
      await press(signal);
      expect(engine.resumes, 1);
      expect(previews.status, PeerClipStatus.playing);

      // The band's ⏸ / ▶ is the same toggle.
      await previews.toggle();
      await settle();
      expect(previews.status, PeerClipStatus.paused);
      await previews.toggle();
      await settle();
      expect(previews.status, PeerClipStatus.playing);
      expect(resolver.asks, hasLength(1));

      await press(breakwater);
      expect(previews.circleOf(breakwater), PeerCircle.busy);
      await press(breakwater);
      expect(previews.status, PeerClipStatus.idle);
      expect(ourEnds().map((c) => c.reason), [PreviewEnd.stopped]);
      await resolver.answer(clipOf(breakwater));
      expect(engine.plays, hasLength(1), reason: 'stopped: nothing plays');

      // The band's ⏸ on a clip still asked for stops it too.
      await press(glass);
      await previews.toggle();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
    });

    test('a refused pause or resume leaves the status as it was', () async {
      make();
      await playing(signal);
      // Still loading as the engine sees it: no pause.
      await emit(PreviewClipState(
          provider: kDeezerPlugin,
          phase: PreviewPhase.loading,
          owner: previews));
      await press(signal);
      expect(engine.pauses, 0);
      expect(previews.status, PeerClipStatus.playing);

      await emit(at(3));
      await press(signal);
      expect(previews.status, PeerClipStatus.paused);
      engine.appVisible = false;
      await press(signal);
      expect(engine.resumes, 0);
      expect(previews.status, PeerClipStatus.paused);
    });

    test('another lead while one plays: pause at once, resolve, play '
        '(switch), the song never resumed between (clip :181-343)', () async {
      final rig = realEngine();
      make();
      await press(signal);
      await resolver.answer(clipOf(signal));
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.port.pauses, 1, reason: 'the song paused once it loaded');
      expect(rig.player.state.value.owner, same(previews));

      await press(harbor);
      expect(rig.clip.pauses, 1, reason: 'silenced at once');
      expect(rig.player.state.value.phase, PreviewPhase.paused);
      expect(previews.status, PeerClipStatus.resolving);
      expect(rig.port.plays, 0);

      await resolver.answer(clipOf(harbor));
      expect(rig.player.state.value.phase, PreviewPhase.playing);
      expect(rig.clip.loads.last, clipOf(harbor).url);
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.port.pauses, 1);
      expect(rig.port.plays, 0, reason: 'the song stayed paused');

      await previews.stop();
      await settle();
      expect(rig.port.plays, 1, reason: '✕ brings it back once');
    });

    test('a switch landing during a load pauses it', () async {
      final rig = realEngine(holdLoads: true);
      make();
      await press(signal);
      await resolver.answer(clipOf(signal));
      expect(rig.player.state.value.phase, PreviewPhase.loading);
      expect(previews.status, PeerClipStatus.loading);
      expect(previews.circleOf(signal), PeerCircle.busy);

      await press(harbor);
      expect(previews.status, PeerClipStatus.resolving);
      expect(rig.clip.pauses, 0, reason: 'nothing sounds yet');

      rig.clip.finishLoad();
      await settle();
      expect(rig.port.pauses, 1);
      expect(rig.clip.pauses, 1, reason: 'Signal Fires landed: paused');
      expect(rig.player.state.value.phase, PreviewPhase.paused);
      expect(previews.status, PeerClipStatus.resolving);
      expect(previews.live, same(harbor));

      await resolver.answer(clipOf(harbor));
      rig.clip.finishLoad();
      await settle();
      expect(rig.player.state.value.phase, PreviewPhase.playing);
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.port.plays, 0);
      await previews.stop();
      await settle();
      expect(rig.port.plays, 1);
    });

    test('the gen fence: an answer after stop or leave plays nothing; '
        'endCount moved → nothing; app hidden → nothing (clip :523)', () async {
      make();
      await press(signal);
      await previews.stop();
      await resolver.answer(clipOf(signal));
      expect(engine.plays, isEmpty);
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin), isNotNull);

      await press(harbor);
      await previews.leave(PreviewEnd.stopped);
      await resolver.answer(clipOf(harbor));
      expect(engine.plays, isEmpty);

      // A link opened while it was asked (an end with no flow).
      await press(glass);
      await engine.end(PreviewEnd.leftApp);
      await resolver.answer(clipOf(glass));
      expect(engine.plays, isEmpty);
      expect(previews.status, PeerClipStatus.idle);

      engine.appVisible = false;
      await press(quiet);
      await resolver.answer(clipOf(quiet));
      expect(engine.plays, isEmpty);
      expect(previews.status, PeerClipStatus.idle);
      expect(misses, 0, reason: 'none of these is a miss');
    });
  });

  group('preempted', () {
    final sheet = Object();

    test("another owner's live state while our press resolves → idle; the "
        'answer is stored, nothing plays, no end call (vp.js:2285-2292)',
        () async {
      make();
      await press(signal);
      await emit(PreviewClipState(
          provider: kItunesPlugin, phase: PreviewPhase.playing, owner: sheet));
      expect(previews.status, PeerClipStatus.idle);
      expect(previews.live, isNull);
      await resolver.answer(clipOf(signal));
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin), isNotNull);
      expect(engine.plays, isEmpty);
      expect(ourEnds(), isEmpty);
    });

    test('… while our press waits out a 429 → idle; the timer sends nothing',
        () async {
      make();
      await press(signal);
      await resolver.fail(429);
      final wait = timers.made.last;
      expect(previews.status, PeerClipStatus.waiting);
      await emit(PreviewClipState(
          provider: kDeezerPlugin, phase: PreviewPhase.loading, owner: sheet));
      expect(previews.status, PeerClipStatus.idle);
      wait.fire();
      await settle();
      expect(resolver.asks, hasLength(1));
      expect(ourEnds(), isEmpty);
    });

    test('an idle or owner-less state while resolving (no engine flow) is not '
        'a preemption', () async {
      make();
      await press(signal);
      await emit(PreviewClipState.idle);
      await emit(const PreviewClipState(
          provider: kDeezerPlugin, phase: PreviewPhase.playing));
      expect(previews.status, PeerClipStatus.resolving);
      await resolver.answer(clipOf(signal));
      expect(engine.plays, hasLength(1));
      expect(previews.status, PeerClipStatus.playing);
    });
  });

  // The web claims the aside at the press (vp.js asideClaim): the page's
  // clip wins over a sheet's still running, and a session asked while the
  // song was paused ends if the user starts it first (asideMainPlaying).
  group('claimed at the press', () {
    final sheet = Object();
    final sheetClip = Uri.parse('https://cdn.example/sheet-row.mp3');

    test("a sheet's clip still running (the sheet animating closed): taken "
        "over at once; its ticks and its close leave the page's press "
        'alone; the answer plays as a switch, the song never resumed '
        'between', () async {
      final rig = realEngine();
      make();
      unawaited(rig.player
          .play(provider: kItunesPlugin, url: sheetClip, owner: sheet));
      await settle();
      expect(rig.port.pauses, 1);

      await press(signal);
      expect(previews.status, PeerClipStatus.resolving);
      expect(rig.player.state.value.owner, same(previews));
      expect(rig.player.state.value.phase, PreviewPhase.held);
      expect(rig.clip.playing, isFalse, reason: "the sheet's clip silenced");

      // A tick of the sheet's clip, then the sheet's dispose.
      rig.clip.emitPosition(const Duration(seconds: 3));
      await settle();
      expect(previews.status, PeerClipStatus.resolving);
      final ends = rig.player.endCount;
      await rig.player.end(PreviewEnd.sheetClosed, owner: sheet);
      await settle();
      expect(rig.player.endCount, ends, reason: 'not the sheet\'s flow now');
      expect(rig.port.plays, 0);
      expect(previews.status, PeerClipStatus.resolving);

      await resolver.answer(clipOf(signal));
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.clip.loads.last, clipOf(signal).url);
      expect(rig.player.state.value.owner, same(previews));
      expect(rig.port.pauses, 1, reason: "the sheet's pause held throughout");
      expect(rig.port.plays, 0);
      expect(misses, 0);

      await previews.stop();
      await settle();
      expect(rig.port.plays, 1, reason: '✕ brings the song back once');
    });

    test("… with no tick before the sheet's close: the endCount fence does "
        'not drop the press', () async {
      final rig = realEngine();
      make();
      unawaited(rig.player
          .play(provider: kItunesPlugin, url: sheetClip, owner: sheet));
      await settle();
      await press(harbor);
      await rig.player.end(PreviewEnd.sheetClosed, owner: sheet);
      await settle();
      expect(previews.status, PeerClipStatus.resolving);
      await resolver.answer(clipOf(harbor));
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.clip.loads.last, clipOf(harbor).url);
      expect(rig.port.plays, 0);
    });

    test('a claimed flow the answer finds none for: the session ends and the '
        "song the sheet paused comes back", () async {
      final rig = realEngine();
      make();
      unawaited(rig.player
          .play(provider: kItunesPlugin, url: sheetClip, owner: sheet));
      await settle();
      await press(glass);
      await rig.player.end(PreviewEnd.sheetClosed, owner: sheet);
      await resolver.answer(null);
      expect(previews.status, PeerClipStatus.idle);
      expect(misses, 1);
      expect(rig.player.state.value, PreviewClipState.idle);
      expect(rig.port.plays, 1);
    });

    test('the fake engine: a press claims a live foreign flow, never its own '
        'or an idle one', () async {
      make();
      await press(signal);
      expect(engine.claims, isEmpty, reason: 'nothing ran');
      await resolver.answer(clipOf(signal));
      await previews.stop();
      await emit(PreviewClipState(
          provider: kItunesPlugin, phase: PreviewPhase.playing, owner: sheet));
      await press(harbor);
      expect(engine.claims, [previews]);
      expect(engine.state.value.owner, same(previews));
      expect(previews.status, PeerClipStatus.resolving);
      await resolver.answer(clipOf(harbor));
      expect(previews.status, PeerClipStatus.playing);
      expect(engine.plays.last.url, clipOf(harbor).url);
      await press(glass);
      expect(engine.claims, [previews], reason: 'its own flow is a switch');
    });

    test('the song paused at the press and started while it is asked: idle '
        'with no play; the answer is kept and never pauses the song',
        () async {
      final rig = realEngine(songPlaying: false);
      make();
      await press(signal);
      expect(previews.status, PeerClipStatus.resolving);
      rig.port.userPlay();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(rig.player.endCount, 0, reason: 'no flow of ours to end');

      await resolver.answer(clipOf(signal));
      expect(rig.port.pauses, 0);
      expect(rig.player.state.value, PreviewClipState.idle);
      expect(rig.clip.loads, isEmpty);
      expect(previews.answers.of(keyOf(signal), kDeezerPlugin), isNotNull);
      expect(misses, 0);

      // Started with no command (a park pick landing) counts too.
      rig.port.userPause();
      await press(harbor);
      rig.port.startsByItself();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
    });

    test('… while it waits out a 429: the wait sends nothing, nothing '
        'pauses the song', () async {
      final rig = realEngine(songPlaying: false);
      make();
      await press(signal);
      await resolver.fail(429);
      expect(previews.status, PeerClipStatus.waiting);
      final wait = live(const Duration(seconds: 5)).single;
      rig.port.userPlay();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      wait.fire();
      await settle();
      expect(resolver.asks, hasLength(1));
      expect(rig.port.pauses, 0);
      expect(rig.clip.loads, isEmpty);
    });

    test('… while its clip loads: the load is dropped, the song plays on and '
        'is never paused', () async {
      final rig = realEngine(songPlaying: false, holdLoads: true);
      make();
      previews.answers.put(keyOf(signal), kDeezerPlugin, clipOf(signal));
      await press(signal);
      expect(previews.status, PeerClipStatus.loading);
      rig.port.userPlay();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(rig.clip.pendingLoads, 0, reason: 'the load was interrupted');
      expect(rig.player.state.value, PreviewClipState.idle);
      expect(rig.port.pauses, 0);
      expect(rig.port.playingNow, isTrue);
    });

    test('control: the song playing at the press, a Play while it is asked '
        'changes nothing; the clip plays and pauses the song once', () async {
      final rig = realEngine();
      make();
      await press(signal);
      rig.port.userPlay();
      await settle();
      expect(previews.status, PeerClipStatus.resolving);
      await resolver.answer(clipOf(signal));
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.port.pauses, 1);
    });

    test('the watch is let go once the clip plays (the engine watches the '
        'song from then on), and when the session ends', () async {
      engine.songPlaying = false;
      make();
      await press(signal);
      expect(engine.watchingSong, isTrue);
      await resolver.answer(clipOf(signal));
      expect(previews.status, PeerClipStatus.playing);
      expect(engine.watchingSong, isFalse);
      engine.startSong();
      await settle();
      expect(previews.status, PeerClipStatus.playing,
          reason: "the engine's own watch ends a clip that plays");

      await previews.stop();
      engine.songPlaying = false;
      await press(harbor);
      expect(engine.watchingSong, isTrue);
      await previews.stop();
      expect(engine.watchingSong, isFalse);
      await resolver.answer(clipOf(harbor)); // kept; nothing plays

      // A press with a flow of ours already running leaves it to the engine.
      await playing(glass);
      await press(quiet);
      expect(engine.watchingSong, isFalse);
    });
  });

  group('backgrounded', () {
    test('backgrounded while resolving or waiting → idle (backgrounded); '
        'returning plays nothing', () async {
      make();
      await press(signal);
      previews.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      previews.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await resolver.answer(clipOf(signal));
      expect(engine.plays, isEmpty);

      await press(harbor);
      await resolver.fail(429);
      final wait = timers.made.last;
      previews.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      wait.fire();
      await settle();
      expect(resolver.asks, hasLength(2));

      // A clip of ours ends as backgrounded.
      await playing(glass);
      previews.didChangeAppLifecycleState(AppLifecycleState.detached);
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(ourEnds().map((c) => c.reason), [PreviewEnd.backgrounded]);
      expect(misses, 0);
    });

    test('inactive is ignored', () async {
      make();
      await press(signal);
      previews.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await settle();
      expect(previews.status, PeerClipStatus.resolving);
      await resolver.answer(clipOf(signal));
      expect(engine.plays, hasLength(1));
    });

    test("watchLifecycle: the app's own lifecycle is heard, and let go of on "
        'dispose', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      addTearDown(() =>
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final watching = PeerRecsPreviews(
          resolve: resolver.call,
          provider: () => provider,
          timer: timers.call);
      unawaited(watching.press(signal, all));
      await settle();
      expect(watching.status, PeerClipStatus.resolving);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle();
      expect(watching.status, PeerClipStatus.idle);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      watching.dispose();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await settle();
      expect(watching.status, PeerClipStatus.idle);
    });

    // Round 3's W1: the page observes the binding from its start, so it is
    // told the app is hidden ahead of the engine's own watch (an
    // AppLifecycleListener made at the clip's play); ending its clip there
    // stops that watch while the binding is still telling its observers.
    testWidgets('the app sent to the background during a page clip (inactive, '
        'hidden, paused in one go, the real lifecycle watch): the clip ends '
        'as backgrounded with no listener used once disposed; back in '
        'front, a press plays again and ends the same way', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final port = BindingPreviewPort();
      final clip = FakePreviewClip();
      final player = PreviewPlayer.withPort(port, makeClip: () => clip);
      final previous = PreviewPlayer.instance;
      PreviewPlayer.instance = player;
      addTearDown(() => PreviewPlayer.instance = previous);
      final page = PeerRecsPreviews(
          resolve: resolver.call,
          provider: () => provider,
          timer: timers.call);
      addTearDown(page.dispose);

      unawaited(page.press(signal, all));
      await tester.pump();
      resolver.open.single.answer.complete(clipOf(signal));
      await tester.pump();
      expect(page.status, PeerClipStatus.playing);
      expect(player.state.value.owner, same(page));
      expect(port.pauses, 1);

      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(page.status, PeerClipStatus.idle);
      expect(player.state.value, PreviewClipState.idle);
      expect(clip.playing, isFalse);
      expect(port.plays, 1, reason: 'backgrounded brings the song back');

      foregroundApp(tester);
      await tester.pump();
      unawaited(page.press(signal, all));
      await tester.pump();
      expect(resolver.asks, hasLength(1), reason: 'the kept answer plays');
      expect(page.status, PeerClipStatus.playing);
      backgroundApp(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(page.status, PeerClipStatus.idle);
      expect(player.state.value, PreviewClipState.idle);
      foregroundApp(tester);
      await player.end(PreviewEnd.sheetClosed);
    });
  });

  group('Preview all', () {
    test('from the top, skipping none; holdOnComplete; completion → the next '
        'resolve; the song never resumed until the end; last → '
        'end(completed) (panel :3283, :3315)', () async {
      final rig = realEngine();
      make();
      final list = [saltRoad, breakwater, signal];
      previews.answers.put(keyOf(saltRoad), kDeezerPlugin, null);
      await previewAll(list);
      expect(previews.chain, isTrue);
      expect(resolver.titles, ['Breakwater'], reason: 'Salt Road has none');
      await resolver.answer(clipOf(breakwater));
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.port.pauses, 1);

      rig.clip.finish();
      await settle();
      expect(rig.player.state.value.phase, PreviewPhase.held);
      expect(resolver.titles, ['Breakwater', 'Signal Fires']);
      expect(previews.live, same(signal));
      expect(rig.port.plays, 0, reason: 'held between two clips');

      await resolver.answer(clipOf(signal));
      expect(previews.status, PeerClipStatus.playing);
      expect(rig.port.pauses, 1, reason: 'the first pause kept');
      expect(rig.port.plays, 0);

      rig.clip.finish();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(previews.chain, isFalse);
      expect(rig.player.state.value, PreviewClipState.idle);
      expect(rig.port.plays, 1, reason: 'the end brings the song back once');
    });

    test('each chain step calls keepHeld while the engine is held: _start, '
        'every send, every 429 wait', () async {
      make();
      await previewAll([saltRoad, breakwater]);
      await resolver.answer(clipOf(saltRoad));
      expect(engine.plays.single.holdOnComplete, isTrue);
      expect(engine.keepHelds, 0);

      await engine.complete();
      await settle();
      expect(engine.state.value.phase, PreviewPhase.held);
      expect(resolver.titles, ['Salt Road', 'Breakwater']);
      expect(engine.keepHelds, 2, reason: 'the start and its send');

      await resolver.fail(429);
      expect(previews.status, PeerClipStatus.waiting);
      expect(engine.keepHelds, 3, reason: 'the wait');
      timers.made.last.fire();
      await settle();
      expect(engine.keepHelds, 4, reason: 'the retry');
      await resolver.answer(clipOf(breakwater));
      expect(engine.plays.last.holdOnComplete, isTrue);
      expect(previews.status, PeerClipStatus.playing);
    });

    test('none → skipped; failed → the chain ends (panel :3324)', () async {
      make();
      await previewAll([saltRoad, breakwater, signal, harbor]);
      await resolver.answer(clipOf(saltRoad));
      await engine.complete();
      await settle();
      await resolver.answer(null);
      expect(previews.circleOf(breakwater), PeerCircle.muted);
      expect(previews.live, same(signal), reason: 'passed on quietly');
      expect(misses, 0);
      await resolver.fail(0);
      expect(previews.status, PeerClipStatus.idle);
      expect(previews.chain, isFalse);
      expect(resolver.titles, ['Salt Road', 'Breakwater', 'Signal Fires'],
          reason: 'no run into the limiter');
      expect(misses, 0, reason: 'Preview all ends quietly');
      expect(ourEnds().map((c) => c.reason), [PreviewEnd.stopped]);
    });

    test('pressed while running → stop', () async {
      make();
      await previewAll(all);
      expect(previews.chain, isTrue);
      await previewAll(all);
      expect(previews.status, PeerClipStatus.idle);
      await resolver.answer(clipOf(saltRoad));
      expect(engine.plays, isEmpty);

      // Nothing left with a preview: nothing starts.
      for (final l in all) {
        previews.answers.put(keyOf(l), kDeezerPlugin, null);
      }
      await previewAll(all);
      expect(previews.status, PeerClipStatus.idle);
      expect(resolver.asks, hasLength(1));
    });

    test('a new answer drawn mid-chain → it plays out, no advance '
        '(panel :3340)', () async {
      make();
      await previewAll(all);
      await resolver.answer(clipOf(saltRoad));
      previews.listChanged(all.sublist(6));
      expect(previews.chain, isFalse);
      expect(previews.status, PeerClipStatus.playing);
      await engine.complete();
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(resolver.asks, hasLength(1));
      expect(ourEnds().map((c) => c.reason), [PreviewEnd.completed]);
    });
  });

  group('prefetch (clip :442, :473)', () {
    test('chain only, past 20 s, once per clip, for the next lead not yet '
        'known none', () async {
      make();
      final list = [saltRoad, breakwater, signal, harbor];
      previews.answers.put(keyOf(breakwater), kDeezerPlugin, null);
      await previewAll(list);
      await resolver.answer(clipOf(saltRoad));
      await emit(at(19));
      expect(resolver.asks, hasLength(1));
      await emit(at(20));
      expect(resolver.titles, ['Salt Road', 'Signal Fires']);
      await resolver.answer(clipOf(signal));
      await emit(at(25));
      expect(resolver.asks, hasLength(2), reason: 'once per clip');
      expect(previews.live, same(saltRoad));

      // A single press never asks ahead.
      await previews.stop();
      await press(saltRoad);
      await emit(at(21));
      expect(resolver.asks, hasLength(2));
    });

    test('never for a lead already answered (found or none), never while a '
        'resolve is out, queued or waiting', () async {
      make();
      previews.answers.put(keyOf(saltRoad), kDeezerPlugin, clipOf(saltRoad));
      previews.answers.put(keyOf(breakwater), kDeezerPlugin, clipOf(breakwater));
      await previewAll([saltRoad, breakwater]);
      await emit(at(22));
      expect(resolver.asks, isEmpty, reason: 'answered already');
      await previews.stop();

      // A resolve still out (a press made before Preview all).
      await press(glass);
      await previewAll([saltRoad, signal]);
      expect(previews.live, same(saltRoad));
      await emit(at(22));
      expect(resolver.titles, ['Glass Season'], reason: 'one in flight');
      await resolver.answer(clipOf(glass));
      await previews.stop();

      // A press queued behind a flight, its timer running.
      await press(quiet);
      await press(harbor);
      await resolver.answer(clipOf(quiet));
      expect(live(const Duration(milliseconds: 300)), hasLength(1));
      await previewAll([saltRoad, signal]);
      await emit(at(22));
      expect(resolver.titles, ['Glass Season', 'Quiet Engine'],
          reason: 'the queue runs');
    });

    test('a 200 is stored, found or none; a 429, 403 or transport error '
        'stores nothing and is never retried', () async {
      make();
      final list = [saltRoad, breakwater, signal, harbor, glass];
      previews.answers.put(keyOf(saltRoad), kDeezerPlugin, clipOf(saltRoad));
      await previewAll(list);
      await emit(at(20));
      await resolver.answer(null);
      expect(previews.answers.of(keyOf(breakwater), kDeezerPlugin)?.none,
          isTrue);
      expect(previews.status, PeerClipStatus.playing);
      expect(misses, 0);

      await engine.complete();
      await settle();
      expect(previews.live, same(signal), reason: 'Breakwater passed by');
      await resolver.answer(clipOf(signal));
      await emit(at(20));
      expect(resolver.titles.last, 'Harbor Lights');
      await resolver.answer(clipOf(harbor));
      expect(previews.answers.of(keyOf(harbor), kDeezerPlugin)?.found,
          isNotNull);

      await engine.complete();
      await settle();
      expect(previews.live, same(harbor));
      expect(resolver.asks, hasLength(3), reason: 'Harbor Lights from the store');
      await emit(at(20));
      expect(resolver.titles.last, 'Glass Season');
      await resolver.fail(429);
      expect(previews.answers.of(keyOf(glass), kDeezerPlugin), isNull);
      expect(live(const Duration(seconds: 5)), isEmpty, reason: 'no retry');
      expect(previews.status, PeerClipStatus.playing);
      await emit(at(25));
      expect(resolver.asks, hasLength(4));

      // A 403 and no answer: nothing kept, nothing told.
      await previews.stop();
      await previewAll([saltRoad, quiet]);
      await emit(at(20));
      await resolver.fail(403);
      expect(previews.answers.of(keyOf(quiet), kDeezerPlugin), isNull);
      expect(refusals, 0);
      expect(previews.status, PeerClipStatus.playing);
      await previews.stop();
      await previewAll([saltRoad, quiet]);
      await emit(at(20));
      await resolver.fail(0);
      expect(previews.answers.of(keyOf(quiet), kDeezerPlugin), isNull);
      expect(previews.answers.of(keyOf(saltRoad), kDeezerPlugin), isNotNull);
      expect(previews.status, PeerClipStatus.playing);
    });

    test('a press made while a prefetch is out queues behind it and is sent '
        '300 ms after', () async {
      make();
      previews.answers.put(keyOf(saltRoad), kDeezerPlugin, clipOf(saltRoad));
      await previewAll([saltRoad, breakwater]);
      await emit(at(20));
      expect(resolver.titles, ['Breakwater']);
      await press(glass);
      expect(resolver.titles, ['Breakwater'], reason: 'queued');
      expect(previews.live, same(glass));
      await resolver.answer(clipOf(breakwater));
      final queue = live(const Duration(milliseconds: 300));
      expect(queue, hasLength(1));
      queue.single.fire();
      await settle();
      expect(resolver.titles, ['Breakwater', 'Glass Season']);
    });

    test('a prefetch never plays', () async {
      make();
      previews.answers.put(keyOf(saltRoad), kDeezerPlugin, clipOf(saltRoad));
      await previewAll([saltRoad, breakwater]);
      await emit(at(20));
      await resolver.answer(clipOf(breakwater));
      expect(engine.plays, hasLength(1));
      expect(previews.live, same(saltRoad));
      expect(previews.status, PeerClipStatus.playing);
    });
  });

  group('band and external ends', () {
    test("⏭: the next lead of the clip's own list after its index "
        '(panel :3403)', () async {
      make();
      previews.answers.put(keyOf(harbor), kDeezerPlugin, null);
      await playing(signal);
      expect(previews.hasNext, isTrue);
      // Another answer drawn: ⏭ still walks the clip's own list.
      previews.listChanged([quiet]);
      unawaited(previews.next());
      await settle();
      expect(previews.live, same(glass), reason: 'Harbor Lights has none');
      expect(resolver.titles.last, 'Glass Season');
      expect(previews.chain, isFalse);
      await resolver.answer(clipOf(glass));
      expect(previews.status, PeerClipStatus.playing);
      expect(engine.plays.last.url, clipOf(glass).url);

      await previews.stop();
      expect(previews.hasNext, isFalse);
      final last = all.last;
      await playing(last);
      expect(previews.hasNext, isFalse);
      unawaited(previews.next());
      await settle();
      expect(previews.live, same(last));
    });

    test('an external end (songStarted, a sheet row took the clip) → idle, '
        'no end call (panel :3380)', () async {
      make();
      await playing(signal);
      await engine.end(PreviewEnd.songStarted);
      await settle();
      expect(previews.status, PeerClipStatus.idle);
      expect(ourEnds(), isEmpty);

      await press(signal);
      expect(previews.status, PeerClipStatus.playing);
      await emit(PreviewClipState(
          provider: kItunesPlugin,
          phase: PreviewPhase.loading,
          owner: Object()));
      expect(previews.status, PeerClipStatus.idle);
      expect(ourEnds(), isEmpty);
      expect(misses, 0);
    });
  });

  group('earned art and provider', () {
    test('earned art: https only, album + artist match, spread by tile.key; '
        'cards deezer-only, band any; from sheet answers too (panel :3267, '
        'clip :498)', () async {
      make();
      previews.listChanged(all);
      final cover = Uri.parse('https://cdn.example/cover.jpg');
      await playing(signal);
      expect(previews.cardArt(signal), cover);
      expect(previews.cardArt(harbor), cover, reason: 'one album, one tile');
      expect(previews.bandArt(harbor), cover);
      expect(previews.cardArt(saltRoad), isNull);

      // http art, or another album: nothing anywhere.
      await press(saltRoad);
      await resolver.answer(
          clipOf(saltRoad, artwork: 'http://cdn.example/cover.jpg'));
      expect(previews.cardArt(saltRoad), isNull);
      await press(glass);
      await resolver.answer(clipOf(glass, album: 'Undertow (Deluxe)'));
      expect(previews.cardArt(glass), isNull);
      expect(previews.cardArt(quiet), isNull);

      // A sheet's Deezer answer earns it as well.
      previews.answers.put(keyOf(glass), kDeezerPlugin, clipOf(glass));
      expect(previews.cardArt(quiet), cover);

      // With iTunes previewing: the band takes its cover, the cards never.
      await previews.stop();
      provider = _itunes;
      previews.providerCheck();
      final breakwaterArt = clipOf(breakwater,
          provider: kItunesPlugin, artwork: 'https://cdn.example/100.jpg');
      await press(breakwater);
      await resolver.answer(breakwaterArt);
      expect(previews.cardArt(breakwater), isNull);
      expect(previews.bandArt(saltRoad), breakwaterArt.artwork);
    });

    test("a provider change clears the visit's answers, keeps the art",
        () async {
      make();
      await playing(signal);
      previews.answers.put(keyOf(harbor), kDeezerPlugin, null);
      expect(previews.answers.length, 2);
      var notes = 0;
      previews.addListener(() => notes++);

      previews.providerCheck();
      expect(notes, 0, reason: 'the same provider');
      expect(previews.answers.length, 2);

      provider = _itunes;
      previews.providerCheck();
      expect(previews.answers.length, 0);
      expect(notes, greaterThan(0));
      expect(previews.cardArt(harbor), isNotNull);
      expect(previews.circleOf(harbor), isNot(PeerCircle.muted));
    });
  });

  group('leaving', () {
    test('leave(stopped) / leave(sheetClosed) end only our flow (panel :3797)',
        () async {
      make();
      await playing(signal);
      await previews.leave(PreviewEnd.stopped);
      expect(previews.status, PeerClipStatus.idle);
      expect(ourEnds().map((c) => c.reason), [PreviewEnd.stopped]);
      expect(engine.ends, [PreviewEnd.stopped]);

      await playing(harbor);
      await previews.leave(PreviewEnd.sheetClosed);
      expect(ourEnds().map((c) => c.reason),
          [PreviewEnd.stopped, PreviewEnd.sheetClosed]);
      expect(engine.ends, [PreviewEnd.stopped, PreviewEnd.sheetClosed]);

      // A sheet's clip plays on as the page is popped under it; the pop
      // still asks to free the player (another owner's: ignored).
      final sheet = Object();
      await emit(PreviewClipState(
          provider: kItunesPlugin, phase: PreviewPhase.playing, owner: sheet));
      await previews.leave(PreviewEnd.sheetClosed);
      expect(ourEnds().last.reason, PreviewEnd.sheetClosed);
      expect(engine.ends, hasLength(2), reason: "the sheet's clip plays on");
      expect(engine.state.value.owner, same(sheet));
    });

    test('dispose leaves the store usable: a later put does not throw',
        () async {
      final store = PreviewAnswers();
      make(answers: store);
      await press(signal);
      previews.dispose();
      await resolver.answer(clipOf(signal));
      expect(store.of(keyOf(signal), kDeezerPlugin), isNotNull,
          reason: 'a 200 is the visit\'s even once the page is gone');
      store.put(keyOf(harbor), kDeezerPlugin, null);
      expect(store.length, 2);
      expect(engine.plays, isEmpty);
    });
  });
}
