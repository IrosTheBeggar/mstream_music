import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../media/preview_player.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../util/discovery_plugins_api.dart' show DiscoveryPluginsException;
import '../../util/peer_recs_rules.dart';
import 'discovery_jobs_controller.dart' show JobsTimerFactory;
import 'preview_answers.dart';

/// A preview plug-in's resolve (DiscoveryPluginsApi.preview): the clip, or
/// null when it found none. Every other outcome throws
/// [DiscoveryPluginsException] (429 the catalogue's budget, 403 / 404 the
/// plug-in gone, 0 no answer).
typedef PreviewResolve = Future<PluginPreview?> Function(
    String plugin, Map<String, dynamic> recommendation);

// Why a clip did not come: none (the plug-in found no preview, kept for the
// visit) or failed (this press only: a second 429, no answer, the clip
// would not play).
enum _Miss { none, failed }

/// The Peer Recommendations page's clip session (mStream plan §2 items
/// 13–15 and §5.5; the webapp's vp.js discover.clip and m.js peerRecsOnClip):
/// one lead's 30-second preview at a time, played on the app's
/// PreviewPlayer as its owner.
///
/// A card's play circle asks the page's one preview plug-in (the first in
/// the listing that can preview, plan §2 item 12) only when it is pressed,
/// one resolve in flight: a press made meanwhile waits for it, a newer one
/// taking its place, and is sent [queueDelay] after it. A 429 waits
/// ([peerRetryDelay]) and is asked once more, then is "No preview" for that
/// press only; `preview: null` is "No preview" for the visit. Every 200 goes
/// into [answers], which the network-lead sheets the page opens share
/// (their answers come back the same way). A found clip that would not
/// load or broke while playing (an expired address) is forgotten there, so
/// the next press asks again. A 403 / 404 forgets the visit's answers and
/// earned art and tells [onRefused].
///
/// Preview all plays the list from the top, past the leads with no
/// preview, holding the song's pause from the first clip to the last; past
/// 20 s into a clip it asks the next lead ahead once. The band pauses,
/// resumes, skips (⏭) and stops (✕) the session.
///
/// The engine's own rules stand: the song pauses once a clip has loaded
/// and comes back only when nobody touched it. Another owner taking the
/// engine (a sheet's preview row), the song starting, a call, a link
/// opening end the session here with no end of ours. The page ends it as
/// it is covered or popped ([leave]), and the app going to the background
/// ends it even before a clip loads. A press claims the engine as the web's
/// does: a sheet's clip still running (the sheet animating closed) is taken
/// over at once, and with the song paused, the user starting it before the
/// clip plays ends the session.
class PeerRecsPreviews extends ChangeNotifier with WidgetsBindingObserver {
  /// [resolve] asks a preview plug-in ([PreviewResolve]); [provider] is the
  /// page's preview plug-in now (peerPreviewProvider over the jobs
  /// listing), read on every use. [answers] are the visit's (a fresh store
  /// when none is given); never disposed here. [timer] makes the queue's
  /// and the 429 waits' timers (tests fire them). [watchLifecycle] false
  /// leaves the app's lifecycle to the caller ([didChangeAppLifecycleState];
  /// tests). [onRefused] runs once the session is idle after a resolve
  /// answered 403 / 404; [onMiss] once a single press found no clip (none,
  /// or failed).
  PeerRecsPreviews({
    required this._resolve,
    required this._provider,
    PreviewAnswers? answers,
    JobsTimerFactory? timer,
    this.queueDelay = const Duration(milliseconds: 300),
    this.watchLifecycle = true,
    this.onRefused,
    this.onMiss,
  })  : answers = answers ?? PreviewAnswers(),
        _timer = timer ?? Timer.new,
        _engine = PreviewPlayer() {
    _providerName = _provider()?.name;
    this.answers.addListener(_onAnswers);
    _sub = _engine.state.listen((_) => _onEngine());
    _attachLifecycle();
  }

  /// The visit's preview answers, shared with the sheets the page opens
  /// (mStream plan §2 item 15). Never disposed: a sheet that outlives the
  /// visit may still write into it.
  final PreviewAnswers answers;

  /// How long a queued press waits after the resolve in flight (webapp
  /// CLIP_QUEUE_MS).
  final Duration queueDelay;
  final bool watchLifecycle;
  final VoidCallback? onRefused;
  final VoidCallback? onMiss;

  /// How far into a Preview all clip the next lead is asked ahead (plan
  /// §5.5; webapp m.js peerRecsOnClip).
  static const Duration prefetchAt = Duration(seconds: 20);

  final PreviewResolve _resolve;
  final DiscoveryPlugin? Function() _provider;
  final JobsTimerFactory _timer;
  final PreviewPlayer _engine;
  StreamSubscription<PreviewClipState>? _sub;
  bool _observing = false;
  bool _disposed = false;

  PeerClipStatus _status = PeerClipStatus.idle;
  DiscoveryLead? _live;
  String? _liveKey;
  PluginPreview? _preview;
  bool _chain = false;

  // The clip's own list and its place in it (⏭, Preview all).
  List<DiscoveryLead> _list = const [];
  int _index = -1;

  // Bumped by every start and every end of a session: whatever comes back
  // from an await to another number is no longer the clip's.
  int _gen = 0;

  // The engine runs a flow this session played (its clip, paused or held),
  // and the session number whose play it is. The answer its last play of
  // ours played (none for a flow a press took over) is what the visit
  // forgets when that clip fails.
  bool _engineFlow = false;
  int _flowGen = -1;
  ({String key, String plugin, Uri url})? _flowClip;

  // One resolve in flight, a press's or the prefetch's; the press queued
  // behind it and the timer that sends it; a 429's wait.
  bool _flight = false;
  ({int gen, int attempt})? _queued;
  Timer? _queueTimer;
  Timer? _retry;

  // The song starting, heard from a press made while it was paused and the
  // engine did not watch it (PreviewPlayer.flowWatchesSong), until the
  // session's clip plays.
  StreamSubscription<void>? _songWatch;

  // The list index the prefetch last asked ahead for.
  int _prefetched = -1;

  String? _providerName;

  // The leads drawn now (listChanged): what a stored answer earns art for.
  List<DiscoveryLead> _leads = const [];

  // Earned art (plan §2 item 10): tile key → preview plug-in → artwork.
  final Map<String, Map<String, Uri>> _art = {};

  // Each lead's repaired recommendation and lead key, made once
  // (DiscoveryLead.recommendation repairs the row on every read).
  final Expando<({Map<String, dynamic>? rec, String key})> _facts =
      Expando('peer-recs-lead');

  final ValueNotifier<PeerClipProgress> _progress =
      ValueNotifier((position: Duration.zero, length: Duration.zero));

  // ── what the page draws ──────────────────────────────────────────────

  PeerClipStatus get status => _status;

  /// A session runs: a clip is asked for, waited on, loading, playing or
  /// paused.
  bool get isLive => _status != PeerClipStatus.idle;

  /// The session's lead, while one runs.
  DiscoveryLead? get live => _live;

  /// The live clip's answer (the band's attribution and store link), once
  /// it is loading or playing.
  PluginPreview? get preview => _preview;

  /// The session is Preview all's.
  bool get chain => _chain;

  /// ⏭ has a lead to go to: one after the clip's in its own list, past
  /// those with no preview.
  bool get hasNext => isLive && peerNextIndex(_list, _index, _skip) != -1;

  /// The live clip's position and length; only the band's hairline listens
  /// (no page rebuild per tick).
  ValueListenable<PeerClipProgress> get progress => _progress;

  /// The page's preview plug-in now, or null (no circles, no Preview all).
  DiscoveryPlugin? get providerPlugin => _provider();

  /// [lead]'s play circle: none without a provider or a sendable
  /// recommendation; muted (drawn, inert) once the provider found no
  /// preview for it this visit; the live clip's state while it is the
  /// session's lead; else ready.
  PeerCircle circleOf(DiscoveryLead lead) {
    final p = providerPlugin;
    final facts = _factsOf(lead);
    if (p == null || facts.rec == null) return PeerCircle.hidden;
    if (answers.of(facts.key, p.name)?.none == true) return PeerCircle.muted;
    if (isLive && facts.key == _liveKey) {
      return switch (_status) {
        PeerClipStatus.playing => PeerCircle.playing,
        PeerClipStatus.paused => PeerCircle.paused,
        _ => PeerCircle.busy,
      };
    }
    return PeerCircle.idle;
  }

  /// A card's earned art (plan §2 item 10): a Deezer preview's cover of the
  /// album [lead]'s tile stands for, this visit. Cards take Deezer's 250 px
  /// only (a logged phone deviation).
  Uri? cardArt(DiscoveryLead lead) => _artOf(lead)?[kDeezerPlugin];

  /// The band's earned art for [lead]: Deezer's, else any preview's.
  Uri? bandArt(DiscoveryLead lead) {
    final art = _artOf(lead);
    if (art == null || art.isEmpty) return null;
    return art[kDeezerPlugin] ?? art.values.first;
  }

  // ── what the page does ───────────────────────────────────────────────

  /// A card's play circle (webapp clipToggle): the live lead's pauses,
  /// resumes, or drops a clip still on its way; any other lead's starts a
  /// clip of its own, with [list] after it for ⏭. Muted and hidden circles
  /// do nothing.
  Future<void> press(DiscoveryLead lead, List<DiscoveryLead> list) async {
    if (_disposed) return;
    final circle = circleOf(lead);
    if (circle == PeerCircle.hidden || circle == PeerCircle.muted) return;
    if (isLive && _keyOf(lead) == _liveKey) return _toggleLive();
    await _start(lead, list, index: _indexIn(list, lead), chain: false);
  }

  /// Preview all: [list] from the top, past the leads with no preview this
  /// visit; pressed while it runs, it stops.
  Future<void> previewAll(List<DiscoveryLead> list) async {
    if (_disposed) return;
    if (_chain && isLive) return stop();
    if (providerPlugin == null) return;
    final first = peerNextIndex(list, -1, _skip);
    if (first == -1) return;
    await _start(list[first], list, index: first, chain: true);
  }

  /// The band's ⏸ / ▶; while the clip is still on its way, a stop.
  Future<void> toggle() => _toggleLive();

  /// The band's ⏭: the next lead of the clip's own list after its place,
  /// past those with no preview; Preview all goes on from there.
  Future<void> next() async {
    if (_disposed || !isLive) return;
    final n = peerNextIndex(_list, _index, _skip);
    if (n == -1) return;
    await _start(_list[n], _list, index: n, chain: _chain);
  }

  /// The band's ✕: the session ends, and the song comes back if the engine
  /// may bring it back.
  Future<void> stop() => _endSession(PreviewEnd.stopped);

  /// The page is covered or one of its own sheets opens
  /// ([PreviewEnd.stopped]), or it is popped ([PreviewEnd.sheetClosed],
  /// which also frees the clip player when no flow of ours runs). Only this
  /// page's flow is ended.
  Future<void> leave(PreviewEnd reason) async {
    final flow = _engineFlow;
    await _endSession(reason);
    if (reason == PreviewEnd.sheetClosed && !flow) {
      await _engine.end(PreviewEnd.sheetClosed, owner: this);
    }
  }

  /// A new answer is drawn ([leads]): Preview all plays its clip out and
  /// stops there, never running on into another list (webapp m.js
  /// peerRecsShow); the art the visit's answers earn now covers [leads].
  void listChanged(List<DiscoveryLead> leads) {
    if (_disposed) return;
    _leads = List.of(leads, growable: false);
    var changed = _earnFromStore(_leads);
    if (_chain) {
      _chain = false;
      changed = true;
    }
    if (changed) _notify();
  }

  /// The plug-in listing moved: when another plug-in previews now, the
  /// visit's answers were the old one's and are forgotten (webapp
  /// clipProviderCheck). Earned art stays: it is the album's.
  void providerCheck() {
    if (_disposed) return;
    final now = providerPlugin?.name;
    if (now == _providerName) return;
    _providerName = now;
    answers.clear();
    _notify();
  }

  // ── the session ──────────────────────────────────────────────────────

  Future<void> _toggleLive() async {
    if (_disposed) return;
    // The clip has ended (the engine holds the flow for Preview all's next
    // clip), though its state has not reached the page yet: there is
    // nothing to pause or play on, so the chain goes on or ends.
    if (_clipEnded) {
      _advance();
      return;
    }
    final gen = _gen;
    switch (_status) {
      case PeerClipStatus.idle:
        return;
      case PeerClipStatus.playing:
        // The status moves only when the engine said it did (webapp
        // clipPause). A clip that completed as it was paused has ended all
        // the same.
        if (await _engine.pause(owner: this) &&
            gen == _gen &&
            _status == PeerClipStatus.playing) {
          if (_clipEnded) {
            _advance();
          } else {
            _status = PeerClipStatus.paused;
            _notify();
          }
        }
      case PeerClipStatus.paused:
        if (await _engine.resume(owner: this) &&
            gen == _gen &&
            _status == PeerClipStatus.paused) {
          _status = PeerClipStatus.playing;
          _notify();
        }
      case PeerClipStatus.resolving:
      case PeerClipStatus.waiting:
      case PeerClipStatus.loading:
        await stop();
    }
  }

  /// A new clip for [lead] (webapp clipStart): the one before it is
  /// silenced at once, its flow and the song's pause kept, and this one
  /// plays from the visit's answers or once its resolve answers.
  Future<void> _start(DiscoveryLead lead, List<DiscoveryLead> list,
      {required int index, required bool chain}) async {
    if (_disposed) return;
    final gen = ++_gen;
    _halt();
    _prefetched = -1;
    _live = lead;
    _liveKey = _keyOf(lead);
    _list = List.of(list, growable: false);
    _index = index;
    _chain = chain;
    _status = PeerClipStatus.resolving;
    _preview = null;
    _setProgress(Duration.zero, Duration.zero);
    _notify();
    if (_engineFlow) {
      final s = _engine.state.value;
      if (!_ours(s) || !_running(s)) {
        // That flow is over already (its last state is on its way here).
        _engineFlow = false;
      } else if (s.phase == PreviewPhase.playing) {
        await _engine.pause(owner: this);
        if (gen != _gen || _disposed) return;
      } else if (s.phase == PreviewPhase.held) {
        _engine.keepHeld(owner: this);
      }
    }
    final ownFlow = _engineFlow;
    if (!ownFlow) {
      // Another surface's clip still runs (a sheet's row, the sheet
      // animating closed): the press takes its flow over at once, the song
      // staying paused, so that sheet's end as it closes no longer reaches
      // this clip (webapp asideClaim at clipStart). It is no play of this
      // session's: its progress is not the band's.
      final s = _engine.state.value;
      if (_running(s) && !_ours(s) && _engine.claim(owner: this)) {
        _engineFlow = true;
        _flowGen = -1;
        _flowClip = null;
      }
    }
    // The song is paused and the engine does not watch it
    // (PreviewPlayer.flowWatchesSong): no flow runs, or the flow's first
    // clip still loads with no pause of the song taken over (this press
    // came while it loads, or took over a sheet's that still loaded). The
    // user starting it before the clip plays ends the session, and the clip
    // never pauses it (webapp asideMainPlaying, a session asked while it
    // was paused). While the engine watches it, its own watch ends the flow
    // instead, and this one would hear the engine bringing the song back
    // (a clip of the flow failing) as the user starting it.
    if (!_engine.flowWatchesSong && !_engine.songPlaying) _watchSong(gen);
    final p = providerPlugin;
    if (p == null || _recOf(lead) == null) return _settle(gen, _Miss.none);
    final stored = answers.of(_liveKey!, p.name);
    if (stored != null) {
      final found = stored.found;
      return found == null
          ? _settle(gen, _Miss.none)
          : _play(gen, p.name, found);
    }
    _ask(gen, 0);
  }

  // One resolve in flight (webapp clipAsk): a press made meanwhile, or
  // while the queue's timer runs, waits; a newer one takes its place.
  void _ask(int gen, int attempt) {
    if (_flight || _queueTimer != null) {
      _queued = (gen: gen, attempt: attempt);
      _pump();
      return;
    }
    unawaited(_send(gen, attempt));
  }

  // The queued press goes [queueDelay] after the flight, if still the
  // clip's (webapp clipPump).
  void _pump() {
    if (_disposed || _flight || _queueTimer != null || _queued == null) {
      return;
    }
    _queueTimer = _timer(queueDelay, () {
      _queueTimer = null;
      if (_disposed) return;
      final q = _queued;
      _queued = null;
      if (q != null && q.gen == _gen) {
        unawaited(_send(q.gen, q.attempt));
      } else {
        _pump();
      }
    });
  }

  /// Asks the provider about the clip's lead (webapp clipSend). A 200 is
  /// kept for the visit even when another clip took over; the rest is the
  /// clip's only while it still is.
  Future<void> _send(int gen, int attempt) async {
    if (_disposed) return;
    if (gen != _gen) {
      _pump();
      return;
    }
    final lead = _live;
    final key = _liveKey;
    final p = providerPlugin;
    final rec = lead == null ? null : _recOf(lead);
    if (lead == null || key == null || p == null || rec == null) {
      unawaited(_settle(gen, _Miss.none));
      _pump();
      return;
    }
    final stored = answers.of(key, p.name);
    if (stored != null) {
      final found = stored.found;
      unawaited(found == null
          ? _settle(gen, _Miss.none)
          : _play(gen, p.name, found));
      _pump();
      return;
    }
    _keepHeld();
    // An end asked for while it is looked up (a link opened, the app sent
    // to the background, a call, the song started) means quiet: what it
    // finds is kept, and plays on the next press (network_preview_rows.dart
    // does the same).
    final ends = _engine.endCount;
    var answered = false;
    PluginPreview? found;
    Object? error;
    _flight = true;
    try {
      found = await _resolve(p.name, rec);
      answered = true;
    } catch (e) {
      error = e;
    } finally {
      _flight = false;
    }
    if (answered) answers.put(key, p.name, found);
    if (!_disposed && gen == _gen) {
      final refused = error is DiscoveryPluginsException ? error : null;
      if (answered && found == null) {
        unawaited(_settle(gen, _Miss.none));
      } else if (answered && found != null) {
        if (_engine.endCount == ends && _engine.appVisible) {
          unawaited(_play(gen, p.name, found));
        } else {
          unawaited(_endSession(PreviewEnd.stopped));
        }
      } else if (refused != null && refused.absent) {
        // The plug-ins are not there for this account any more (webapp
        // clipReset, then 'off').
        answers.clear();
        _art.clear();
        await _endSession(PreviewEnd.stopped);
        if (!_disposed) onRefused?.call();
      } else if (refused != null && refused.status == 429 && attempt == 0) {
        _status = PeerClipStatus.waiting;
        _keepHeld();
        _notify();
        _retry = _timer(peerRetryDelay(p.name), () {
          _retry = null;
          if (!_disposed && gen == _gen) _ask(gen, 1);
        });
      } else {
        // A second 429, no answer, anything else: this press only.
        unawaited(_settle(gen, _Miss.failed));
      }
    }
    _pump();
  }

  /// Preview all's one look ahead (webapp clipPrefetch): the answer goes
  /// into the visit's, nothing plays. Never while a resolve is out, queued
  /// or waited on, never for a lead already answered, never retried.
  Future<void> _prefetch(DiscoveryLead lead) async {
    final p = providerPlugin;
    final facts = _factsOf(lead);
    final rec = facts.rec;
    if (p == null || rec == null) return;
    if (answers.of(facts.key, p.name) != null) return;
    if (_flight || _retry != null || _queued != null || _queueTimer != null) {
      return;
    }
    var answered = false;
    PluginPreview? found;
    _flight = true;
    try {
      found = await _resolve(p.name, rec);
      answered = true;
    } catch (_) {
      // A 429, a refusal, no answer: nothing is kept, nothing retried.
    } finally {
      _flight = false;
    }
    if (answered) answers.put(facts.key, p.name, found);
    _pump();
  }

  /// The clip plays [found] (webapp clipPlay); a preview of the lead's own
  /// album and artist earns the art of every card with its tile key.
  Future<void> _play(int gen, String plugin, PluginPreview found) async {
    if (_disposed || gen != _gen) return;
    final lead = _live;
    final key = _liveKey;
    if (lead != null) _earn(lead, plugin, found);
    _status = PeerClipStatus.loading;
    _preview = found;
    _engineFlow = true;
    _flowGen = gen;
    _flowClip = key == null ? null : (key: key, plugin: plugin, url: found.url);
    _setProgress(Duration.zero, Duration(seconds: found.seconds));
    _notify();
    final out = await _engine.play(
        provider: plugin, url: found.url, owner: this, holdOnComplete: _chain);
    // A clip that would not load is dead wherever it is kept, whoever was
    // pressed since: the visit forgets it, so the next press on this page
    // or on a sheet asks again (the visit outlives the page's dispose).
    if (out == PreviewPlayOutcome.failed && key != null) {
      answers.forget(key, plugin, found.url);
    }
    if (_disposed) return;
    if (gen != _gen) {
      // Another lead was pressed while this one loaded: it is silenced as
      // a switch would silence it, the flow and the song's pause kept.
      final s = _engine.state.value;
      if (out == PreviewPlayOutcome.playing &&
          _ours(s) &&
          s.phase == PreviewPhase.playing) {
        await _engine.pause(owner: this);
      }
      return;
    }
    if (out == PreviewPlayOutcome.failed) {
      _engineFlow = false;
      await _settle(gen, _Miss.failed);
    } else if (out == PreviewPlayOutcome.playing) {
      // The engine watches the song from here on.
      _unwatchSong();
      if (_status == PeerClipStatus.loading) {
        _status = PeerClipStatus.playing;
        _notify();
      }
    }
  }

  /// No clip for this press (webapp clipSettle and m.js peerRecsOnClip):
  /// Preview all passes a lead with none and ends on a failed one (no run
  /// into the provider's limiter); a single press ends and says so.
  Future<void> _settle(int gen, _Miss miss) async {
    if (_disposed || gen != _gen) return;
    if (_chain && miss == _Miss.none) {
      _advance();
      return;
    }
    final single = !_chain;
    await _endSession(PreviewEnd.stopped);
    if (single && !_disposed) onMiss?.call();
  }

  /// Preview all's next lead, at once, so the song stays paused across the
  /// hand-off; past the last (or once the list moved on), the end.
  void _advance() {
    final n = peerNextIndex(_list, _index, _skip);
    if (n == -1 || !_chain) {
      unawaited(_endSession(PreviewEnd.completed));
      return;
    }
    unawaited(_start(_list[n], _list, index: n, chain: true));
  }

  /// The session ends: everything of it stops at once, and the engine's
  /// flow of ours ends for [reason] (the song comes back if it may).
  Future<void> _endSession(PreviewEnd reason) async {
    _reset();
    if (_engineFlow) {
      _engineFlow = false;
      await _engine.end(reason, owner: this);
    }
  }

  // The engine's flow ended without us (another owner took it, the song
  // started, a call, a link): the session is over, with no end of ours.
  void _drop() {
    _engineFlow = false;
    _reset();
  }

  void _reset() {
    _gen++;
    _halt();
    final was = isLive;
    _status = PeerClipStatus.idle;
    _live = null;
    _liveKey = null;
    _preview = null;
    _chain = false;
    _list = const [];
    _index = -1;
    _prefetched = -1;
    _setProgress(Duration.zero, Duration.zero);
    if (was) _notify();
  }

  // The 429's wait, the queued press and the song watch, dropped. The
  // queue's timer runs on, so the next press still goes [queueDelay] after
  // the last flight.
  void _halt() {
    _retry?.cancel();
    _retry = null;
    _queued = null;
    _unwatchSong();
  }

  /// Session [gen] hears the song starting while its clip is still on its
  /// way (asked, waited on, loading): the session ends with no play, and
  /// nothing brings the song back for it. What its resolve brings is kept.
  void _watchSong(int gen) {
    _unwatchSong();
    _songWatch = _engine.songStarts.listen((_) {
      if (_disposed || gen != _gen) return;
      switch (_status) {
        case PeerClipStatus.resolving:
        case PeerClipStatus.waiting:
        case PeerClipStatus.loading:
          unawaited(_endSession(PreviewEnd.songStarted));
        case PeerClipStatus.playing:
        case PeerClipStatus.paused:
        case PeerClipStatus.idle:
          _unwatchSong();
      }
    });
  }

  void _unwatchSong() {
    final watch = _songWatch;
    _songWatch = null;
    if (watch != null) unawaited(watch.cancel());
  }

  /// The engine's state moved. It is read from the engine, never from the
  /// event: the stream delivers later than the state is set, so an event
  /// can be stale.
  void _onEngine() {
    if (_disposed) return;
    final s = _engine.state.value;
    final ours = _ours(s);
    // Another owner took the engine (a sheet's preview row), whether or not
    // a clip of ours had started: the session is over, and what its resolve
    // brings is kept but never played (webapp: the window's tile preempts
    // the page's clip, vp.js clipHandlers stopped).
    if (isLive && _running(s) && s.owner != null && !ours) {
      _drop();
      return;
    }
    if (_engineFlow) {
      if (!ours) {
        _drop();
        return;
      }
      final current = _flowGen == _gen;
      switch (s.phase) {
        case PreviewPhase.held:
          if (_clipEnded) _advance();
        case PreviewPhase.failed:
          // The clip would not load or broke while playing: the visit
          // forgets its answer (an expired address), whether or not it is
          // still the session's.
          _engineFlow = false;
          final dead = _flowClip;
          _flowClip = null;
          if (dead != null) answers.forget(dead.key, dead.plugin, dead.url);
          if (current) unawaited(_settle(_gen, _Miss.failed));
        case PreviewPhase.playing:
        case PreviewPhase.paused:
          if (current) {
            _setProgress(s.position,
                s.duration ?? Duration(seconds: _preview?.seconds ?? 30));
          }
        case PreviewPhase.idle:
        case PreviewPhase.loading:
          break;
      }
    }
    if (_chain &&
        _status == PeerClipStatus.playing &&
        _engineFlow &&
        _flowGen == _gen &&
        ours &&
        s.phase == PreviewPhase.playing &&
        s.position >= prefetchAt &&
        _prefetched != _index) {
      _prefetched = _index;
      final n = peerNextIndex(_list, _index, _skip);
      if (n != -1) unawaited(_prefetch(_list[n]));
    }
  }

  /// A stored answer, whoever wrote it (this page, a sheet's row): the
  /// circles read the store, so the page redraws at once, and a found clip
  /// of the lead's own album earns its art (webapp dmSharePreview).
  void _onAnswers() {
    if (_disposed) return;
    _earnFromStore([..._leads, ..._list]);
    notifyListeners();
  }

  bool _earnFromStore(Iterable<DiscoveryLead> leads) {
    final p = providerPlugin;
    if (p == null) return false;
    var earned = false;
    for (final lead in leads) {
      final found = answers.of(_keyOf(lead), p.name)?.found;
      if (found != null && _earn(lead, p.name, found)) earned = true;
    }
    return earned;
  }

  bool _earn(DiscoveryLead lead, String plugin, PluginPreview found) {
    final key = lead.tile?.key;
    if (key == null || key.isEmpty || !peerArtMatches(lead, found)) {
      return false;
    }
    final art = found.artwork!;
    final byPlugin = _art.putIfAbsent(key, () => {});
    if (byPlugin[plugin] == art) return false;
    byPlugin[plugin] = art;
    return true;
  }

  Map<String, Uri>? _artOf(DiscoveryLead lead) {
    final key = lead.tile?.key;
    return key == null || key.isEmpty ? null : _art[key];
  }

  /// The session's clip played to its end in a play that asked to hold:
  /// the engine holds this session's flow while the band still reads
  /// playing, or paused (a clip that completed as the band paused it ended
  /// all the same, and cannot play on).
  bool get _clipEnded {
    final s = _engine.state.value;
    return _engineFlow &&
        _flowGen == _gen &&
        _ours(s) &&
        s.phase == PreviewPhase.held &&
        (_status == PeerClipStatus.playing || _status == PeerClipStatus.paused);
  }

  void _keepHeld() {
    final s = _engine.state.value;
    if (_ours(s) && s.phase == PreviewPhase.held) {
      _engine.keepHeld(owner: this);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────

  bool _ours(PreviewClipState s) => identical(s.owner, this);

  static bool _running(PreviewClipState s) => switch (s.phase) {
        PreviewPhase.loading ||
        PreviewPhase.playing ||
        PreviewPhase.paused ||
        PreviewPhase.held =>
          true,
        PreviewPhase.idle || PreviewPhase.failed => false,
      };

  ({Map<String, dynamic>? rec, String key}) _factsOf(DiscoveryLead lead) =>
      _facts[lead] ??= (rec: lead.recommendation, key: peerLeadKey(lead));

  String _keyOf(DiscoveryLead lead) => _factsOf(lead).key;
  Map<String, dynamic>? _recOf(DiscoveryLead lead) => _factsOf(lead).rec;

  /// Preview all and ⏭ pass a lead the provider found no preview for this
  /// visit, and one with no recommendation to send (no circle).
  bool _skip(DiscoveryLead lead) {
    final facts = _factsOf(lead);
    if (facts.rec == null) return true;
    final p = providerPlugin;
    return p != null && answers.of(facts.key, p.name)?.none == true;
  }

  int _indexIn(List<DiscoveryLead> list, DiscoveryLead lead) {
    final i = list.indexOf(lead);
    if (i != -1) return i;
    final key = _keyOf(lead);
    return list.indexWhere((l) => _keyOf(l) == key);
  }

  void _setProgress(Duration position, Duration length) {
    if (_disposed) return;
    _progress.value = (position: position, length: length);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── the app's lifecycle ──────────────────────────────────────────────

  void _attachLifecycle() {
    if (!watchLifecycle) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // No binding (a plain unit test): the caller drives the lifecycle.
    }
  }

  /// Plan §2 item 14: the app going to the background ends the session,
  /// even one still asking or waiting out a 429 (the engine watches the
  /// app only from a play on), so nothing starts once the user is back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_disposed && isLive) {
          unawaited(_endSession(PreviewEnd.backgrounded));
        }
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        return;
    }
  }

  /// Stops listening (the engine, the answers, the app). It ends nothing on
  /// the engine (the page calls [leave] first) and never disposes
  /// [answers].
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _gen++;
    _halt();
    _queueTimer?.cancel();
    _queueTimer = null;
    unawaited(_sub?.cancel());
    _sub = null;
    answers.removeListener(_onAnswers);
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _progress.dispose();
    super.dispose();
  }
}
