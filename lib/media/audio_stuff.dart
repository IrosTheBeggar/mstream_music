import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, HttpClient, HttpHeaders, Platform;
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart'
    show AudioSession, AudioSessionConfiguration, AudioInterruptionType;
import 'package:just_audio/just_audio.dart';
import 'package:mstream_music/main.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:wifi_lock_shim/wifi_lock_shim.dart';
import 'playback_backend.dart';
import 'dynamics_equalizer.dart';
import 'eq_output_router.dart';
import 'local_playback_backend.dart';
import 'dlna_playback_backend.dart';
import 'chromecast_playback_backend.dart';
import 'local_media_server.dart';
import 'auto_browse.dart';
import 'cast_origin.dart' show rebindLoopbackArt;
import 'output_devices.dart' show isExternalOutput;
import 'cast_log.dart';
import 'cast_target.dart';
import 'transport_log.dart';
import '../native/iroh_tunnel.dart';
import '../objects/server.dart';
import '../objects/metadata.dart';
import '../objects/mood_filter.dart';
import '../objects/play_event.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/cast_manager.dart';
import '../singletons/app_messenger.dart';
import '../singletons/downloads.dart';
import '../singletons/log_manager.dart';
import '../singletons/play_tracker.dart';
import '../singletons/queue_store.dart';
import '../singletons/settings.dart';
import '../singletons/server_capabilities.dart';
import '../singletons/api.dart';
import '../singletons/server_list.dart';
import '../singletons/tunnel_policy.dart';
import '../singletons/visualizer_audio.dart';
import '../objects/display_item.dart';
import '../util/camelot.dart';
import '../util/server_version.dart';
import '../util/seed_vector.dart';
import '../util/session_model_cache.dart';
import '../util/queue_actions.dart';
import '../util/connectivity_probe.dart';
import '../util/stream_url.dart';
import '../util/auto_dj_play_from.dart';
import '../util/auto_dj_seeds.dart';
import '../util/auto_dj_skips.dart';
import '../util/auto_dj_wire.dart';
import '../util/track_facts.dart';

/// What the queue's end does: stop (the normal end, or the user's intent is
/// pause); park waiting for a deferred Auto DJ pick while the tunnel is down;
/// or retry the pick right now when the tunnel is serving and the earlier
/// failure was transient. See [AudioPlayerHandler.queueEndAction].
enum QueueEndAction { stop, park, retryPick }

/// What a media-button toggle (play/pause key) does — see
/// [AudioPlayerHandler.mediaToggleAction].
enum MediaToggleAction { play, pause, ignore }

/// An [AudioHandler] for playing a list of podcast episodes.
/// What [AudioPlayerHandler.healAction] decided the tunnel heal should do:
/// [run] it now, [rearm] the re-check timer and look again shortly, or [drop]
/// this trigger entirely.
enum HealAction { run, rearm, drop }

/// What to do after a tunnel-heal resume failed: try again later, or stop
/// blaming the tunnel and let the failing track take the ordinary skip walk.
enum ResumeFailureAction { rearm, skipTrack }

/// What [AudioPlayerHandler.directAuthAction] decided about a failed track
/// from a direct peer whose own tunnel is serving: [probe] its stream URL for
/// a status first; then [refresh] the guest ticket through the parent and
/// re-seed (a 401/403), [skip] a source the peer says is gone (a 404),
/// [backoff] and reload when the peer is at its concurrent-stream cap (a
/// 429 with a short Retry-After — the streams a run of skips left behind
/// close on their own within moments), give the peer up for the day when
/// its [quota] is spent (a 429 whose Retry-After reaches past
/// [AudioPlayerHandler.kDirectBusyMaxWait]: nothing a wait could fix), or
/// [walk] the ordinary retry/skip path.
enum DirectAuthAction { probe, refresh, skip, backoff, quota, walk }

/// A direct peer's answer to a one-byte range request on a stream URL: the
/// HTTP status (null when nothing answered in time) and, with a 429, the
/// `Retry-After` it sent.
typedef StreamProbe = ({int? status, Duration? retryAfter});

/// [AudioPlayerHandler.directAuthAction]'s verdict on a probed track, the
/// probe it rests on and, after a refresh, what the parent said.
typedef DirectAuthVerdict = ({
  DirectAuthAction action,
  DirectAccessOutcome? outcome,
  StreamProbe probe
});

/// A quick skip as [AudioPlayerHandler.skipToNext] judged it, before its
/// seek: the song's seed [key], the lane ([epoch]) it happened in, whether
/// the Next moved [forward] through the queue, whether the skip was
/// [learned] (it changed the negatives a pick sends), the fetch of its
/// vector ([vectors]) when it joined Less like in a session across several
/// servers, and whether a vector cached for it was already going to another
/// server the next pick asks before the skip ([vectorWasSent]), so that its
/// landing again teaches that server nothing.
typedef _QuickSkip = ({
  String key,
  int epoch,
  bool forward,
  bool learned,
  Future<void>? vectors,
  bool vectorWasSent,
});

/// Whether a direct peer that answered 429 has room for the track after all:
/// [room] to reload into, [none] after the wait (or for the day), or [moot]
/// when the recovery lost its purpose while waiting.
enum DirectPeerRoom { room, none, moot }

/// Why an Auto DJ session is picking without sonic similarity (see
/// [AudioPlayerHandler.sonicDrop]): nothing was within the match, the scan has
/// not reached the seed yet, or discovery was switched off server-side.
enum SonicDrop { tooStrict, scanning, discoveryOff }

/// Why a server is not taking part in a multi-server Auto DJ session (see
/// [AudioPlayerHandler.multiServerSitOut]). [unreachable] covers a server
/// that has never reported its flags though it has had the chance (not a
/// Quick Connect one still waiting for its tunnel), and one dropped this
/// session for a reason the screen has no better word for.
enum FanOutSitOut {
  discoveryOff,
  scanning,
  olderServer,
  noMood,
  otherModel,
  unreachable,
}

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject<List<MediaItem>>();
  // Playback is delegated to a swappable backend so casting can move audio
  // off-device without changing the queue / Auto-DJ / shuffle / repeat logic
  // here. The active backend lives in a BehaviorSubject; the handler's derived
  // streams switchMap over it so existing listeners auto-resubscribe when the
  // backend swaps (see positionStream and _init). The local just_audio backend
  // is persistent (reused when switching back from a cast device); remote
  // backends are built per-session and disposed on switch-away.
  // Build the EQ pipeline only if the user has it enabled — a plain player is
  // the default (see LocalPlaybackBackend). SettingsManager().load() runs
  // before this handler is constructed (main.dart), so eqEnabled is populated.
  // On Android 9+ the ten-band DynamicsProcessing engine replaces the
  // pipelined five-band effect (DynamicsEqualizer.supported, probed in
  // main.dart before this runs): it sits on the audio session instead, so
  // the player is always plain there.
  late final LocalPlaybackBackend _localBackend = LocalPlaybackBackend(
      withEqualizer:
          SettingsManager().eqEnabled && !DynamicsEqualizer.supported,
      dynamicsEqualizer:
          DynamicsEqualizer.supported ? DynamicsEqualizer() : null);
  late final BehaviorSubject<PlaybackBackend> _backendSubject =
      BehaviorSubject<PlaybackBackend>.seeded(_localBackend);
  PlaybackBackend get _backend => _backendSubject.value;

  // Serializes cast-target switches so rapid re-selection can't interleave two
  // _switchBackend calls (racing on _backend / dispose).
  Future<void> _switchChain = Future<void>.value();

  // Completes when _init() has finished seeding the backend + applying saved EQ.
  // restoreQueue() (fired in parallel from QueueStore.init once the server list
  // loads) awaits this so its setSources() can't race _init's seed/EQ on the
  // single just_audio player — concurrent loads abort each other with
  // "Loading interrupted".
  final Completer<void> _initialized = Completer<void>();

  // Android-only native equalizer, exposed for the EQ screen. Lives on the
  // local backend (null on non-Android / remote backends). eq_screen.dart
  // reads this via MediaManager().audioHandler.equalizer.
  AndroidEqualizer? get equalizer => _backend.equalizer;

  /// The ten-band engine (Android 9+), or null where the five-band
  /// AndroidEqualizer above is the engine. Lives on the local backend for
  /// the app's life; the EQ screen reads it through LiveEqAudio.
  DynamicsEqualizer? get dynamicsEqualizer => _localBackend.dynamicsEqualizer;

  /// Per-output EQ curves (ten-band engine only): follows the audio route
  /// and swaps the engine's gains; null where the engine is the five-band
  /// one, which has no fixed layout to store a curve in.
  late final EqOutputRouter? eqOutputs = dynamicsEqualizer == null
      ? null
      : EqOutputRouter(
          port: PluginRoutePort(),
          store: SettingsEqOutputStore(),
          applyGains: _applyRoutedEqGains,
          readGains: () => dynamicsEqualizer?.gains ?? const [],
        );

  Future<void> _applyRoutedEqGains(List<double> gains) async {
    final dyn = dynamicsEqualizer;
    if (dyn == null) return;
    await dyn.setGains(gains);
    await SettingsManager().setEqDynamicsGains(gains);
  }

  int? get index => _backend.currentIndex;

  /// Live playback position of the active backend (read by QueueStore so the
  /// saved snapshot carries the exact spot in the current track).
  Duration get position => _backend.position;

  Stream<Duration> get positionStream =>
      _backendSubject.switchMap((b) => b.positionStream);

  // Every user seek, as it is issued. The play tracker listens so the
  // position jump that follows is not mistaken for listening (and a scrub
  // back to the start is not mistaken for a repeat).
  final StreamController<Duration> _seekEvents =
      StreamController<Duration>.broadcast();
  Stream<Duration> get seekEvents => _seekEvents.stream;

  // Every transport command, numbered (media/transport_log.dart): the
  // preview player reads it to tell whether anyone touched the song a clip
  // paused. Each verb notes itself as its first statement.
  final TransportLog transport = TransportLog();

  // Android audio session id of the active backend. The visualizer's
  // real-audio capture attaches a Visualizer to THIS session — the
  // global output mix (session 0) is blocked for normal apps on modern
  // Android. Null until a source has loaded (or while casting).
  int? get androidAudioSessionId => _backend.androidAudioSessionId;

  Server? autoDJServer;

  dynamic jsonAutoDJIgnoreList;

  // One toast per session for an Auto-DJ auth failure (401/403) — every
  // queue-end retriggers autoDJ, and each would re-toast otherwise.
  bool _autoDJAuthWarned = false;

  /// Why this session dropped sonic similarity and is picking without it, or
  /// null while it hasn't. The Auto DJ screen shows it on the Sonic similarity
  /// row, in place of the toast that used to say so. Session state: a new
  /// lane clears it, and so does 'retrySonic' — the screen's Sonic similarity
  /// sheet, after the user loosens the match to try again.
  SonicDrop? sonicDrop;

  // Bumped by 'retrySonic' (the sonic settings changed): a pick that went out
  // under the old ones and is told "nothing within the range" was asking about
  // a threshold that is no longer set, so its verdict must not stand.
  int _sonicGen = 0;

  // ── Auto DJ seeds (design E) ───────────────────────────────────────────
  //
  // The session's More like and Less like lists: what the Seeds page shows
  // and edits, what a pick sends as its positive and negative sonic seeds,
  // and what quick skips teach. The rules are the pure model's
  // (util/auto_dj_seeds.dart); this block only holds the sets, keeps their
  // clocks and tells the page. The page's own surface (seedsStream, seeds,
  // the edits, setSeedMode, seedServers) sits with the other public Auto DJ
  // getters, next to multiServerSitOut.

  // The LIVE set: the one the engine reads and feeds. Every new lane in
  // Drift starts it over except for what the user keeps
  // ([AutoDjSeeds.carryOver]): the rows they pinned, in both lists, and the
  // unpinned Less like rows with their clocks; the DJ's own unpinned picks
  // go. In Stay close every row it shows stays. Before the first arm it
  // stands at AutoDjSeeds.empty, with the rows a launch took back in
  // ([loadPinnedSeeds]).
  AutoDjSeeds _seeds = AutoDjSeeds.empty;

  // The rows the page adds while the DJ is off, or on before its lane's
  // first pick ([_lanePicked]), held aside so the resets at Start
  // (setAutoDJ's fresh session, then the seeded start's own clear) and a
  // Play from here can't wipe them. The lane's first pick merges them into
  // [_seeds] and lets this go. Until then the page shows the two merged
  // ([seeds]) and new rows land here. Null while nothing is held.
  AutoDjSeeds? _pendingSeeds;

  // Whether this lane's first pick has run, and so taken in the rows held
  // aside ([_pendingSeeds]). Every lane edge clears it: a queue clear keeps
  // the DJ armed on a lane that has not picked yet, and the Start from the
  // empty queue then clears once more, which would wipe a row added to the
  // live set meanwhile. Set at the pick's merge.
  bool _lanePicked = false;

  // A whole-queue teardown is under way ([_guardedClear]: a clear, or the
  // removal of the server the whole queue belonged to). Its reset opens the
  // new lane at once, but the old rows stay in the queue until the player
  // has stopped, and just_audio re-emits the playing index on every event
  // meanwhile. A pick started in that window would be the new lane's first:
  // its blend would take the row being thrown away into More like, and its
  // answer would land in the emptied queue. So no pick starts until the
  // teardown is done ([shouldTopUpAutoDJ], [_autoDJPick]).
  bool _clearingQueue = false;

  // The song this lane's start blended into More like (Drift's blend,
  // [blendsOnLaneStart]), by its seed key ([seedKey]), while no server has
  // judged it as a seed. Nothing checks that the DJ's server can seed from
  // the song the user just put on (a new album still being scanned, a track
  // the analyser can't read, one deleted since it was downloaded). So when a
  // body that carried it is refused and no probe can say which row the
  // server meant, it is the row taken out ([blendCulprit]), and the rows it
  // joined keep the lane's sonic similarity. Null again once a body that
  // carried it is taken, once a server refuses it ([_dropSeedCulprits]), and
  // at every lane edge ([_resetAutoDJSession], [restoreAutoDJ]).
  String? _laneBlendKey;

  // The same song, by its seed key, for the whole lane: a server taking it
  // as a seed changes nothing here. A quick skip of it, while it is the
  // user's own row and More like holds it unpinned, takes it out of More
  // like as a quick-skipped DJ pick leaves, and learns nothing from it
  // ([quickSkipsBlend], [_judgeQuickSkip]). Null at every lane edge.
  String? _laneBlendedSong;

  // That song once the user quick-skipped it out of More like. The DJ never
  // served it, so no ignoreList holds it, and it is no seed any more:
  // nothing else would keep the next pick from bringing it straight back.
  // So both pick routes pass over it for the rest of the lane
  // ([isSkippedBlend], [fanOutRecentKeys]). Null at every lane edge.
  TrackFacts? _laneSkippedBlend;

  // Whether this Stay close lane has had something to stay close to: a More
  // like row its requests can carry (the rows carried over from earlier
  // lanes count: Stay close keeps every row it shows, their anchors
  // included), or the one song it admitted to start ([stayCloseAdmission]).
  // Until then a Stay close pick admits one song; after it nothing is
  // added, so a row the user removes stays removed, and with every row gone
  // the picks send no positives until the user adds a song, switches the
  // mode or a new lane starts. One exception: a lane that has not admitted a
  // song of its own ([_stayCloseAdmitted]) and whose last row it could carry
  // a server then refused looks for its one song again ([_dropSeedCulprits],
  // [stayCloseReleases]). Cleared at every lane edge
  // ([_resetAutoDJSession], [restoreAutoDJ], the clearSonicSession action)
  // and by a switch into Stay close.
  bool _stayCloseAnchored = false;

  // Whether this Stay close lane has taken in its one song ([stayCloseAdmit]).
  // After it nothing more comes in, not even when a server refuses that
  // song; before it, a refusal of the last row the lane could carry lets it
  // look for its song again ([_dropSeedCulprits]). Cleared wherever
  // [_stayCloseAnchored] is.
  bool _stayCloseAdmitted = false;

  // What the stored rows were at the last save ([pinnedSeedsSignature]):
  // set once this run has taken the stored rows back in ([loadPinnedSeeds]),
  // and null until then, when nothing is saved: the save hook runs the load
  // first instead, once a server is known and the user has pinned a row
  // ([_savePinnedSeeds]).
  String? _pinnedSeedsSaved;

  // The page's view of the seeds, re-sent after every change. A stream of its
  // own, never customState: CarPlay re-pushes its modes on every customState
  // event, and the seeds change on nearly every track.
  final BehaviorSubject<AutoDjSeeds> _seedsSubject =
      BehaviorSubject<AutoDjSeeds>.seeded(AutoDjSeeds.empty);

  // Fires when the next unpinned Less like row runs out of time, so the page
  // never lists an expired row. One timer for both sets, re-armed by
  // [_publishSeeds], and none while the lists are frozen. A timer can sleep
  // through a backgrounded app; the picks prune for themselves as well.
  Timer? _seedExpiry;

  // The minute tick while the DJ is on and a Less like row can run out: it
  // drops the expired rows and tells the page only when one went. It backs
  // up [_seedExpiry], whose one-shot wait runs on the monotonic clock while
  // the rows' clocks are wall time, so a device that slept or had its clock
  // set would otherwise list an expired row until the next pick.
  Timer? _seedPruneTick;

  // The key ([trackKey]) of the row the index listener last saw playing.
  // just_audio re-emits the current index on every sequence and playback
  // event, so a pick joins More like only when the playing row changes: a
  // push on each re-emission would lift the playing pick above every row
  // added after it.
  String? _lastSeedPushKey;

  // This lane's stamp on the DJ rows it queues (extras 'djLane'). Only a row
  // of this lane joins More like when it starts playing. DJ rows restored
  // from an earlier run, or left by an earlier lane, still say djPick; the
  // old ring never took them either, since only this lane's own queueing
  // fed it. New at every reset.
  String _djLaneId = const Uuid().v4();

  // The More like rows a server refused as seeds (gone from its library, or
  // not analysed yet) that the page shows pinned: the user's own pins, and
  // in Stay close every row, its anchor included ([AutoDjSeeds.culprits]).
  // They stay listed, theirs to remove, but are out of every request for the
  // rest of the lane. In Drift an engine row found that way is dropped
  // instead ([_dropSeedCulprits]). Seed keys ([seedKey]). Cleared with the
  // lane, by 'retrySonic' and a mode switch ([_retrySonicBookkeeping]) and
  // by the clearSonicSession action, after which they get another try; a
  // removed server's keys go with it.
  final Set<String> _seedUnusable = {};

  // The Less like vectors being fetched ([_ensureNegativeVectors]), by seed
  // key, each with the lane it was asked for: one call per row at a time,
  // however many edits and picks ask for it meanwhile. A fetch from an
  // earlier lane never holds up this lane's, and its answer is thrown away.
  final Map<String, ({int epoch, Future<void> done})> _negativeVectorFetches =
      {};

  // The model of the vector the last pick across several servers sent as
  // its seed, which every server it asked answers in: a Less like row's
  // cached vector reaches those servers only in that model
  // ([AutoDjSeeds.negativesFor]). Lane state; null until such a pick runs.
  String? _fanOutSeedModel;

  /// A new, empty seed set in the stored mode: frozen in Stay close. Every
  /// pending set is made here, so its frozen flag matches
  /// [AutoDJManager.sonicAnchorMode] from the start; the live set takes the
  /// stored mode at every lane edge ([_carriedSeeds]); [setSeedMode] keeps
  /// both in step after that.
  AutoDjSeeds _freshSeeds() => AutoDjSeeds.fresh(
      frozen: AutoDJManager().sonicAnchorMode == SonicAnchorMode.locked,
      now: DateTime.now());

  /// The live set as a new lane starts it, in the stored mode
  /// ([AutoDjSeeds.carryOver]). In Drift: the rows the user pinned and the
  /// unpinned Less like rows (with their clocks) carried over, the DJ's own
  /// unpinned picks gone. In Stay close: every row the page shows, as it
  /// is, its clock still paused.
  AutoDjSeeds _carriedSeeds() => _seeds.carryOver(DateTime.now(),
      frozen: AutoDJManager().sonicAnchorMode == SonicAnchorMode.locked);

  /// The seeds as the page shows them at [now]: the live set, merged with the
  /// held-aside one while it is held ([AutoDjSeeds.merge]).
  AutoDjSeeds _seedsView(DateTime now) {
    final pending = _pendingSeeds;
    return pending == null ? _seeds : _seeds.merge(pending, now: now);
  }

  /// Store the seed sets and tell the page, after any change to either: drop
  /// the Less like rows whose time ran out (in Drift only, since Stay close
  /// stops the clocks), emit the view, save the pins when they changed
  /// ([_savePinnedSeeds]), and re-arm [_seedExpiry] for the next row due,
  /// and [_seedPruneTick] while the DJ is on. It also runs after every
  /// change of [autoDJServer], which starts and stops the tick.
  void _publishSeeds() {
    final now = DateTime.now();
    final drift = AutoDJManager().sonicAnchorMode == SonicAnchorMode.rolling;
    if (drift) {
      _seeds = _seeds.prune(now);
      final pending = _pendingSeeds;
      if (pending != null) _pendingSeeds = pending.prune(now);
    }
    final view = _seedsView(now);
    _seedsSubject.add(view);
    _savePinnedSeeds(view);
    _seedExpiry?.cancel();
    _seedExpiry = null;
    DateTime? due;
    if (drift) {
      for (final s in [_seeds, ?_pendingSeeds]) {
        final next = s.nextExpiry;
        if (next != null && (due == null || next.isBefore(due))) due = next;
      }
    }
    if (due != null && autoDJServer != null) {
      _seedPruneTick ??=
          Timer.periodic(const Duration(minutes: 1), (_) => _pruneSeeds());
    } else {
      _seedPruneTick?.cancel();
      _seedPruneTick = null;
    }
    if (due == null) return;
    final wait = due.difference(now);
    _seedExpiry = Timer(wait.isNegative ? Duration.zero : wait, _publishSeeds);
  }

  /// What auto_dj.json keeps of [view] (the page's view: the live set merged
  /// with the rows held aside; [AutoDjSeeds.storedRows]: in Drift the rows
  /// the user pinned, in Stay close every row it shows) saved for the next
  /// launch with when the lists froze ([AutoDJManager.setPinnedSeeds]), when
  /// it changed since the last save ([pinnedSeedsToSave]). Only once this run
  /// has taken the stored rows back in ([loadPinnedSeeds], which sets the
  /// baseline): until then the file holds rows this run never read, and the
  /// manager writes every key it holds. In Drift a change that only adds or
  /// drops unpinned rows, a pick that starts playing, writes nothing; a
  /// switch of mode writes when it changes what the file keeps.
  ///
  /// A pin the user makes before any load, with a server known, runs the
  /// load instead ([pinsLoadOwed]), whose own publish then saves it: a run
  /// that launched with no server (a fresh install) has no other load unless
  /// the DJ is armed, and its pins would be lost at the next launch.
  void _savePinnedSeeds(AutoDjSeeds view) {
    if (pinsLoadOwed(view,
        saved: _pinnedSeedsSaved,
        serversKnown: ServerManager().serverList.isNotEmpty)) {
      unawaited(loadPinnedSeeds());
      return;
    }
    final save = pinnedSeedsToSave(view, saved: _pinnedSeedsSaved);
    if (save == null) return;
    _pinnedSeedsSaved = save.signature;
    unawaited(
        AutoDJManager().setPinnedSeeds(save.rows, frozenAt: save.frozenAt));
  }

  /// The seed rows auto_dj.json kept from an earlier run
  /// ([AutoDJManager.pinnedSeeds]) taken back in, once per run
  /// ([loadStoredPins]): those of the servers the app still has, at most the
  /// newest eight of each list in Drift and sixteen in Stay close, where its
  /// one song can carry More like past eight ([restorablePinnedRows]), at the
  /// oldest end of the live lists, a song already there keeping its row
  /// ([AutoDjSeeds.withPinnedRows]), in the stored mode. In Drift only the
  /// stored pins come back; in Stay close every stored row, with its own pin,
  /// its clock paused since the stored lists froze
  /// ([AutoDJManager.seedsFrozenAt]). From here on a change to what the file
  /// keeps is saved ([_savePinnedSeeds]); the first save comes only when the
  /// page's rows differ from the stored ones (a row filtered out or capped, a
  /// row pinned before this ran, a file of the other mode).
  ///
  /// Main calls it at launch, once the server list has landed, whether or
  /// not the DJ comes back on; setAutoDJ calls it when it arms the DJ, since
  /// a headless boot (Android Auto, media resumption) never runs main's
  /// restore; and the save hook calls it at the user's first pin of a run
  /// whose earlier calls found no server ([_savePinnedSeeds]). While the
  /// server list is still empty it does nothing and leaves the load to a
  /// later call: with no server known every pin would read as one of a
  /// deleted server, and the next save would lose them all. A lane already
  /// running takes the rows as they are: the rows held aside and the Stay
  /// close flag ([_stayCloseAnchored]) are left alone.
  Future<void> loadPinnedSeeds() async {
    final mgr = AutoDJManager();
    await mgr.load();
    if (_pinnedSeedsSaved != null || ServerManager().serverList.isEmpty) {
      return;
    }
    final load = loadStoredPins(_seeds, mgr.pinnedSeeds,
        knownServer: (s) => ServerManager().byLocalname(s) != null,
        frozen: mgr.sonicAnchorMode == SonicAnchorMode.locked,
        frozenAt: mgr.seedsFrozenAt,
        now: DateTime.now());
    _pinnedSeedsSaved = load.saved;
    _seeds = load.seeds;
    _publishSeeds();
    if (mgr.pinnedSeeds.isNotEmpty) {
      appLog('[dj] seeds: ${mgr.pinnedSeeds.length} row(s) stored, '
          '${_seeds.storedRows.length} kept now '
          '(${_seeds.frozen ? 'stay close' : 'drift'})');
    }
    // The Less like rows among them have no vector yet. Nothing while the DJ
    // is off or the session is on one server.
    unawaited(_ensureNegativeVectors());
  }

  /// Drop the Less like rows whose time ran out (Drift only) and tell the
  /// page, only when one did. A pick runs this before it reads the seeds and
  /// again before each body it builds, so a request never carries an expired
  /// row however late the timers fire; the minute tick runs it too.
  void _pruneSeeds() {
    if (AutoDJManager().sonicAnchorMode != SonicAnchorMode.rolling) return;
    final now = DateTime.now();
    final pending = _pendingSeeds;
    if (!identical(_seeds.prune(now), _seeds) ||
        (pending != null && !identical(pending.prune(now), pending))) {
      _publishSeeds();
    }
  }

  /// What 'retrySonic' does, shared with [setSeedMode]: the sonic settings
  /// changed, so a pick that went out under the old ones can't have its
  /// verdict stand, and a session that dropped sonic gets another go. So do
  /// the rows set aside after a server refused them ([_seedUnusable]): a
  /// scan that caught up, or a match the user loosened, may have changed
  /// that.
  void _retrySonicBookkeeping() {
    _sonicGen++;
    _seedUnusable.clear();
    if (sonicDrop != null) {
      sonicDrop = null;
      customState.add(CustomEvent(autoDJServer));
    }
  }

  /// The playing row ([index]) joins More like when it is a DJ pick of this
  /// lane that just started, in Drift, while the DJ is on: the session's
  /// seeds are what it has played. The index listener calls this before its
  /// top-up, because a pick builds its seeds before its first await, and the
  /// batch fetched as the last row starts must already carry that row, as
  /// the old ring did when it took picks as they were queued.
  ///
  /// Once per row ([_lastSeedPushKey]), and the key moves on in either mode,
  /// so a row that started in Stay close is not pushed by a later switch to
  /// Drift. Into the live set only, never a song in Less like (the model
  /// keeps those out), and whether sonic similarity is on or off, so turning
  /// it on mid-lane finds the lane's sound already there.
  void _seedPushOnPlay(int? index) {
    final q = queue.value;
    if (index == null || index < 0 || index >= q.length) return;
    final item = q[index];
    final key = _trackKey(item);
    if (key == _lastSeedPushKey) return;
    _lastSeedPushKey = key;
    if (autoDJServer == null ||
        AutoDJManager().sonicAnchorMode != SonicAnchorMode.rolling ||
        item.extras?['djLane'] != _djLaneId) {
      return;
    }
    final next = _seeds.pushPick(trackFactsFor(item), now: DateTime.now());
    if (identical(next, _seeds)) return;
    _seeds = next;
    _publishSeeds();
  }

  // Session-only: the Camelot anchor for harmonic mixing. Locked on
  // the first DJ-picked song with a recognised key (after that, every
  // subsequent pick uses the anchor's 6 Camelot neighbours, keeping
  // the session musically coherent rather than drifting). Reset on
  // every new-lane event (see _resetAutoDJSession).
  String? _camelotAnchor;

  // Bumped by _resetAutoDJSession; autoDJ() captures it per call and drops a
  // response that comes back under a different value. A request is nearly
  // always in flight during a session (every advance onto the last row fires
  // the top-up), so without this a queue clear gets repopulated by the
  // landing pick — which also overwrites the just-reset ignoreList and
  // hands the new lane a dead session's sonic verdicts, quietly undoing the
  // reset it raced. The same check is what keeps a late pick from
  // dereferencing autoDJServer after the DJ was switched off.
  int _djSessionEpoch = 0;

  // The queue's generation, for the re-roll (design E). Bumped ONLY by a
  // learned quick skip: one that changed the Less like negatives a server
  // the next pick may ask would be sent. Every DJ row queued ahead, and any
  // pick still out, was chosen without that negative, so a pick built under
  // an older generation is stale: it is dropped where it would queue and
  // run again (see autoDJ()). Never the epoch above, whose reset would wipe
  // the ignoreList, the anchors and the deferred pick on every skip.
  int _djQueueGen = 0;

  // The last [_djQueueGen] a re-roll settled. A pick of a newer generation
  // that lands replaces the stale picks ahead rather than adding to them
  // ([_landReroll]); a re-roll is owed while this is behind.
  int _rerolledGen = 0;

  /// Start a new Auto-DJ "lane": forget everything the session learned from
  /// the queue it was working, and invalidate any in-flight pick.
  ///
  /// Webapp parity — resetAnchors() there wipes the same set whenever a
  /// manual (non-DJ) pick becomes current while the DJ is on. The mobile
  /// equivalents of "the user steered somewhere new" all funnel through
  /// here: setAutoDJ off / on / server switch, a queue clear (which
  /// playFromHere also routes through), and a server removal that empties
  /// the queue. In Drift the next pick then anchors on whatever the user
  /// plays, beside the seeds they pinned (below), not on the dead session's
  /// picks; in Stay close every row the page shows stays (below).
  ///
  /// The stored sonic seed is deliberately NOT cleared here: setAutoDJ
  /// resets BEFORE _startAutoDJFromSeed reads the seed, so clearing it in
  /// this helper would break every seeded start. The clear path consumes it
  /// separately (see _doClearPlaylist).
  ///
  /// The seeds start over too, except for what the user keeps
  /// ([AutoDjSeeds.carryOver]). In Drift the rows they pinned stay, in both
  /// lists, and so do the unpinned Less like rows, each with its 30-minute
  /// clock as it was; the DJ's own unpinned picks (the opener among them)
  /// go, and the lane's first pick blends in the song playing then
  /// ([blendsOnLaneStart]). In Stay close every row the page shows stays as
  /// it is: the user's pins, an earlier lane's anchor, the picks frozen from
  /// Drift and the skips, their clocks still paused. The live set takes the
  /// stored mode, a new lane stamp, so no row queued before this point ever
  /// joins it, no refused rows carried over, and a Stay close lane looks for
  /// its one song to start again ([_stayCloseAnchored]), which the rows it
  /// carried over and can still use give it at once. The rows the Seeds page
  /// holds aside are left alone: every Start resets (setAutoDJ's fresh
  /// session, then a seeded start's own clear), and they join at the lane's
  /// first pick instead. Until that pick, the page's new rows are held aside
  /// as well ([_lanePicked]).
  ///
  /// [clearPins]: the user cleared a queue with the Seeds page's box ticked
  /// ([clearsPinsOnClear]), so the rows the page shows pinned go as well,
  /// from the live and the held-aside set and from the stored list
  /// ([AutoDjSeeds.withoutPinned]). In Drift those are the user's pins: the
  /// picks start over as at any new lane, and the unpinned skips keep their
  /// clocks. In Stay close every row shows pinned, so both lists empty, and
  /// the next lane takes in one song to start.
  ///
  /// A re-roll the old lane's skips asked for is settled here as well: the
  /// new lane's queue owes nothing to them, and its rows are not theirs to
  /// replace.
  void _resetAutoDJSession({bool clearPins = false}) {
    _djSessionEpoch++;
    jsonAutoDJIgnoreList = null;
    _camelotAnchor = null;
    _multiServerExcluded.clear();
    _multiServerExcludedWhy.clear();
    _multiServerIgnore.clear();
    _fanOutDeclined.clear();
    _sonicNotReadyLogged = false;
    _autoDJAuthWarned = false; // fresh lane, fresh warning budget
    sonicDrop = null;
    _clearDeferredPick();
    _seeds = _carriedSeeds();
    if (clearPins) {
      // The rows shown pinned: in Stay close every row, the held-aside set's
      // too (frozen with the mode), so a row the user unpinned there in
      // Drift goes as well.
      _seeds = _seeds.withoutPinned();
      final pending = _pendingSeeds;
      if (pending != null) {
        final rest = pending.withoutPinned();
        _pendingSeeds = rest.isEmpty ? null : rest;
      }
      // Written here, not left to the save at the publish below: a run that
      // never took the stored rows back in saves nothing, and the stored
      // ones must go all the same. The box reads true only once the
      // manager's load has run, so this never writes over a file unread.
      unawaited(AutoDJManager().setPinnedSeeds(const []));
      if (_pinnedSeedsSaved != null) {
        _pinnedSeedsSaved = pinnedSeedsSignature(const []);
      }
      appLog('[dj] queue cleared — the seeds shown pinned go with it');
    }
    _lanePicked = false;
    _laneBlendKey = null;
    _laneBlendedSong = null;
    _laneSkippedBlend = null;
    _stayCloseAnchored = false;
    _stayCloseAdmitted = false;
    _seedUnusable.clear();
    _lastSeedPushKey = null;
    _djLaneId = const Uuid().v4();
    _negativeVectorFetches.clear();
    _fanOutSeedModel = null;
    _rerolledGen = _djQueueGen;
    _rerollOnSeek = false;
    _rerollStale = null;
    _publishSeeds();
  }

  // The repeat mode requested by the UI / Android Auto, and the source of truth
  // for the published PlaybackState: it preserves all of none/all/one (and
  // 'group', which the backend collapses to 'all'), so a client that cycles
  // none→all→one→none can always get back to none. The backend honours the
  // mapped BackendRepeat — including a true single-track loop for 'one'.
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  AudioPlayerHandler() {
    // Complete _initialized when _init() finishes (success or failure) so a
    // parallel restoreQueue() never issues setSources() while _init's seed/EQ
    // are still loading. whenComplete guarantees it even if _init throws, so
    // restoreQueue can't hang.
    _init().whenComplete(() {
      if (!_initialized.isCompleted) _initialized.complete();
    });
  }

  /// The backend says which row is playing ([index]): on every move, and
  /// again on every sequence and playback event, since just_audio re-emits
  /// it. A DJ pick that started joins More like, the queue-end top-up fires,
  /// the keep-offline window slides and now-playing follows. The index
  /// listener runs this, and so does a re-roll's drop, for a move that its
  /// reorder hold swallowed ([_dropRerolled]).
  void _onCurrentIndex(int? index) {
    // A reorder re-points the backend's currentIndex without playback
    // advancing, so skip the Auto-DJ top-up (and the now-playing re-emit) —
    // otherwise dragging the playing track to the last slot would append a
    // spurious Auto-DJ track.
    if (_reordering || _rebuilding || _restoring) return;
    // A DJ pick that just started joins More like BEFORE the top-up below
    // builds the next fetch's seeds (see _seedPushOnPlay).
    _seedPushOnPlay(index);
    if (shouldTopUpAutoDJ(
        index: index,
        queueLength: queue.value.length,
        state: _backend.processingState,
        inFailureWalk: _skipPending || _failedSkips > 0,
        clearing: _clearingQueue)) {
      autoDJ();
    }
    if (index != null && index >= 0 && index < queue.value.length) {
      final item = queue.value[index];
      if (item.id != _lastPlayLoggedId) {
        _lastPlayLoggedId = item.id;
        appLog('[play] track ${index + 1}/${queue.value.length}: '
            '${item.title}');
      }
      // Keep-queue-offline: the cap caches a window of tracks AHEAD of the
      // playing one, so advancing slides that window — sweep to pull in
      // whatever just entered it. No-op when the setting is off, the cap is
      // unlimited (window = whole queue, already swept on the queue change),
      // or everything in range is on disk.
      unawaited(DownloadManager().autoDownloadQueue(queue.value));
      _playFromLocalCopy(index, item);
    }
    _emitCurrentMediaItem();
  }

  Future<void> _init() async {
    // Configure the platform audio session for music playback. Without this,
    // focus is requested with default attributes and Android is more likely to
    // classify a transient loss (a call, a nav prompt, a notification ding) as
    // a permanent one — which pauses playback and never auto-resumes. Declaring
    // music attributes makes focus/duck/resume behave deterministically.
    //
    // We deliberately do NOT add an interruption *handler* here: just_audio
    // wires that up internally (handleInterruptions defaults to true) and
    // auto-pauses/resumes around calls and nav prompts. A second handler would
    // double-fire and fight its resume. That listener stays logging-only, so a
    // "stopped after a call and never came back" report is diagnosable.
    //
    // Becoming-noisy is the exception, and it needs US. just_audio subscribes
    // to it too, but calls pause() on the PLAYER — which never reaches this
    // handler's pause() and so never clears _playIntent. The player stops while
    // the handler still believes playback is wanted, and every revive path here
    // ends with `if (_playIntent) play()`. Getting out of a car is exactly when
    // those fire (network change, tunnel re-bind, re-seed), so the music came
    // back a minute later on the phone's own speaker. Routing through pause()
    // records the intent, which is what actually makes it stay stopped. The
    // duplicate pause underneath is harmless — both want the same thing.
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((event) {
        appLog('[audio] interruption '
            '${event.begin ? 'begin' : 'end'} type=${event.type}');
        // Remembered as a TIMESTAMP, not a flag: Android never delivers the
        // matching `end` for a permanent loss (6 begins, 0 ends across two
        // drive logs), so a boolean would stick and disable every later
        // auto-resume. The auto URL rebuild reads it (it must not blast
        // audio over a call); play() and the window elapsing clear it.
        if (!event.begin) {
          _interruptedAt = null;
        } else if (event.type != AudioInterruptionType.duck &&
            identical(_backend, _localBackend)) {
          _interruptedAt = DateTime.now();
        }
      });
      session.becomingNoisyEventStream.listen((_) {
        // Local playback only. On a cast the audio is coming out of the
        // renderer, not this phone — unplugging the phone's headphones or
        // walking away from its car stereo says nothing about the TV that is
        // actually playing.
        if (!identical(_backend, _localBackend)) return;
        appLog('[audio] output disconnected — pausing');
        _outputLostAt = DateTime.now();
        unawaited(pause());
      });
      session.devicesChangedEventStream.listen((event) {
        // A new output the user can hear (earbuds after the car, the car
        // again) makes the next toggle theirs again. The built-in speaker
        // "appearing" is only the route falling back and keeps the window.
        final added = event.devicesAdded
            .where((d) => d.isOutput && isExternalOutput(d.type))
            .map((d) => d.type.name)
            .toList();
        if (added.isEmpty) return;
        if (_outputLostAt != null) {
          appLog('[audio] output connected (${added.join(', ')}) — '
              'media toggles are live again');
        }
        _outputLostAt = null;
      });
    } catch (e) {
      appLog('[audio] audio session configure failed: $e');
    }

    // For Android 11, record the most recent item so it can be resumed.
    mediaItem
        .whereType<MediaItem>()
        .listen((item) => _recentSubject.add([item]));
    // Broadcast media item changes (with duration if it's known yet).
    // These derived streams switchMap over the active backend so they keep
    // working across a cast backend swap — the new backend's streams are
    // subscribed automatically and the old ones cancelled.
    _backendSubject
        .switchMap((b) => b.currentIndexStream)
        .listen(_onCurrentIndex);
    // Tunnel-follows-queue: keep a tunnel up for every tunnel-carried server
    // the queue holds a song from, and let each go when none of its songs
    // remain. Recomputed on every queue edit. This is what makes a queue from
    // a Quick Connect server connect in the background while the default
    // stays selected — and, with more than one tunnel server queued, keeps
    // all of them reachable.
    queue.listen((items) {
      // The item's OWN server, not its transport: a federated peer's songs
      // ride its parent's tunnel on the proxy path and the peer's own once it
      // is direct, and the manager is where that decision lives.
      final servers = <String, Server>{};
      for (final it in items) {
        final s = _serverFor(it);
        if (s != null) servers[s.localname] = s;
      }
      ServerManager().setQueueIrohServers(servers.values);
      // Keep-queue-offline: sweep every queue change for tracks to download.
      // No-op unless the setting is on; DownloadManager dedupes (in-flight,
      // once-per-session, already-on-disk). Lives here — not main.dart — so
      // headless sessions (Android Auto + Auto-DJ top-ups) sweep too.
      //
      // Skipped mid-restore. restoreQueue publishes the queue BEFORE the load
      // parks the spot, so at this instant the window centres on the fresh
      // player's index 0. On a deep restore (saved at track 50, cap 10) that
      // fetches tracks 1-10, and by the time they land the window has moved to
      // 50 and evicts every one of them — a full cap's worth of cellular data
      // spent on files deleted on arrival. The restore's own load fires this
      // again from the currentIndex listener once the spot is real.
      if (!_restoring) unawaited(DownloadManager().autoDownloadQueue(items));
    });
    // duration usually arrives via durationStream after the source
    // loads. Re-emit the current MediaItem with the duration filled in
    // so the BottomBar progress formula stops dividing by 1.
    _backendSubject
        .switchMap((b) => b.durationStream)
        .listen((_) => _emitCurrentMediaItem());
    // Propagate backend state changes to AudioService clients.
    _backendSubject
        .switchMap((b) => b.changeStream)
        .listen((_) => _broadcastState());
    // On-device playback errors arrive on the backend's dedicated errorStream
    // (just_audio's error channel), NOT as errors on changeStream — recover the
    // iroh mid-stream-drop case from here.
    _backendSubject.switchMap((b) => b.errorStream).listen(_onPlaybackError);
    // Tunnel-follows-the-DJ: while a multi-server session is armed, every
    // server it may ask is a tunnel target (ServerManager._tunnelTargets) —
    // a Quick Connect server or a direct peer answers only over a live
    // tunnel, and nothing else would dial one for a server that is neither
    // browsed nor queued. The manager reads the set live; only the mode's
    // edges (and arm / disarm, see setAutoDJ) have to nudge the reconcile.
    ServerManager().djFanOutServers = _djFanOutServers;
    AutoDJManager().changeStream.listen((_) {
      final mgr = AutoDJManager();
      final on = mgr.multiServerEnabled;
      final moodSet = mgr.activeMoodFilter != null;
      final servers = _fanOutChoice(mgr);
      if (on != _fanOutWasOn) {
        _fanOutWasOn = on;
        _fanOutMoodWasSet = moodSet;
        _fanOutServersWere = servers;
        unawaited(ServerManager()
            .ensureTunnels(reason: on ? 'dj-fanout' : 'dj-fanout-off'));
      } else if (on && moodSet != _fanOutMoodWasSet) {
        // A mood narrows who may answer (canJoinMultiServer), so setting or
        // clearing one moves the targets too.
        _fanOutMoodWasSet = moodSet;
        _fanOutServersWere = servers;
        unawaited(ServerManager().ensureTunnels(reason: 'dj-mood'));
      } else if (on && servers != _fanOutServersWere) {
        // So does a server joining or leaving Play from.
        _fanOutServersWere = servers;
        unawaited(ServerManager().ensureTunnels(reason: 'dj-fanout'));
      }
    });
    // The iroh supervisor re-dials a dropped tunnel forever on the same
    // loopback port, so a dead server coming back flips this status to
    // connected without any app-side event: the phone's network never changed
    // (the connectivity listener stays silent) and the error-time recovery
    // timed out long ago. This transition is the only signal that playback
    // parked by the outage can resume.
    // Per tunnel, not the strip's single value: with two tunnels the parked
    // track's server could come back while the strip keeps showing the other
    // one's state, and that edge must not be lost.
    ServerManager().tunnelTransitions.listen((t) {
      if (t.from == IrohTunnelStatus.connected) return;
      if (t.to == IrohTunnelStatus.connected) {
        // A real edge: whatever verdict suspended the heal is stale now.
        _healSuspended = false;
        _onTunnelReconnected();
      }
    });
    // Stop the service when playback reaches the end of the queue.
    _backendSubject.switchMap((b) => b.processingStateStream).listen((state) {
      // Transitions only (a few lines per track). Without them the drive logs
      // could not tell "playing from the buffer" from "buffering on a dead
      // tunnel" during the 30s the native status still says connected.
      if (state != _lastLoggedProcState) {
        final prev = _lastLoggedProcState;
        _lastLoggedProcState = state;
        if (state == BackendProcessingState.buffering) {
          _bufferingSince ??= DateTime.now(); // logged on the way out
        } else {
          final since = _bufferingSince;
          _bufferingSince = null;
          if (prev == BackendProcessingState.buffering &&
              state == BackendProcessingState.ready) {
            // A weak link flaps buffering↔ready every few seconds; only a
            // stall long enough to hear gets a line, so the 2000-line log
            // ring keeps the tunnel lifecycle instead of the flaps.
            final stall = since == null ? null : DateTime.now().difference(since);
            if (stall != null && stall >= const Duration(seconds: 3)) {
              appLog('[play] rebuffered ${stall.inSeconds}s');
            }
          } else {
            appLog('[play] state → ${state.name}');
          }
        }
      }
      if (state == BackendProcessingState.completed) {
        // Log the context so a "stopped on its own" report can be told apart
        // from a genuine end-of-queue stop: how far into the track we were vs.
        // its duration, and where we were in the queue.
        final dj = autoDJServer;
        final action = queueEndAction(
            onLocalBackend: identical(_backend, _localBackend),
            isIrohDJ: dj != null && dj.isIrohTransport,
            djPickPending: _djPickPending,
            playIntent: _playIntent,
            tunnelServes: dj != null && ServerManager().tunnelServes(dj),
            pickInFlight: _djInFlight);
        appLog('[play] completed → ${action.name} '
            'pos=${_backend.position.inSeconds}s/'
            '${_backend.duration?.inSeconds ?? '?'}s '
            'index=${_backend.currentIndex} of ${queue.value.length}');
        switch (action) {
          case QueueEndAction.park:
            _parkForDeferredPick();
          case QueueEndAction.retryPick:
            _retryPickAtQueueEnd();
          case QueueEndAction.stop:
            stop();
        }
      }
      // Playback just parked (idle with tracks still queued). The tunnel may
      // ALREADY be connected — a status edge that landed while this load was
      // still running is spent, and no further edge is coming — so the park is
      // its own trigger. Fully guarded by _onTunnelReconnected itself (local
      // backend, no intentional stop, iroh server, tunnelServes, and the 10s
      // per-server cooldown), so a park with a genuinely dead tunnel costs one
      // predicate and nothing else.
      if (state == BackendProcessingState.idle &&
          queue.value.isNotEmpty &&
          !_intentionalStop) {
        _onTunnelReconnected();
      }
      // A track that loads clears the skip-budget AND the HTTP retry budget,
      // and lifts any network-stall pause — so the guards only trip on a genuine
      // run of failures, not after a recovery.
      if (state == BackendProcessingState.ready) {
        _failedSkips = 0;
        _httpRetries = 0;
        _networkStalled = false;
        _tunnelLoadFailures = 0;
        _healResumeFailures = 0;
        _healSuspended = false;
        // Only a DIFFERENT track reaching ready clears the local-copy retry
        // guard. Clearing it on every ready reopens the loop it exists to
        // stop: a corrupt-but-LOADABLE file (valid header, damaged tail)
        // reaches ready, clears the guard, fails mid-track, and re-seeds
        // forever.
        if (_localRetryKey != null &&
            _localRetryKey != _trackKey(_itemAt(_backend.currentIndex))) {
          _localRetryKey = null;
        }
        // A track actually loaded — the live player state is the truth now;
        // stop overriding reads with the failed-restore park.
        _restoreSpot = null;
        // ...and the launch snapshot's spot has been loaded or left behind.
        _snapshotSpot = null;
        // Its position is a real one too, not a finished queue's last sample.
        _finishedTrack = null;
        // Saved EQ gains can only be pushed once a source has loaded (the
        // equalizer's parameters resolve on activation), so apply them here
        // on the first ready after init/restore or an EQ-toggle rebuild.
        if (_eqGainsPending && equalizer != null) unawaited(_pushSavedGains());
      }
      // Any fresh load re-resolves its source from the current extras
      // (_uriFor), so the loaded-source-predates-download-patch marker is
      // done (see onTrackDownloaded / _updateWifiLock).
      if (state == BackendProcessingState.loading) {
        _currentSourcePredatesPatch = false;
      }
    });
    // A remote backend that loses its renderer mid-cast (TV off, Wi-Fi drop)
    // emits here; fall back to local playback at the same spot + a toast.
    _backendSubject
        .switchMap((b) => b.rendererLostStream)
        .listen(_onRendererLost);
    // Route cast-target selection (from the picker) to a backend swap.
    CastManager().onTargetSelected = _switchToTarget;
    try {
      // Seed the backend with whatever is already in the queue
      // (typically empty on cold start).
      await _backend.setSources(queue.value);
    } catch (e) {
      castLog('Error seeding playback backend', error: e);
    }
    await _applySavedEqualizer();
    try {
      await eqOutputs?.start();
    } catch (e) {
      appLog('[eq] outputs: $e');
    }
  }

  // Apply persisted EQ state. setEnabled is immediate; band gains can only be
  // pushed once a source has loaded (the equalizer's parameters resolve on
  // activation), so we just arm _eqGainsPending here and the processingState
  // 'ready' handler pushes them on first load. This never blocks _init or the
  // _switchChain toggle on an idle player (where parameters never resolves).
  Future<void> _applySavedEqualizer([AndroidEqualizer? target]) async {
    final dyn = dynamicsEqualizer;
    if (dyn != null) {
      // Ten-band engine: gains first, so they ride along with the attach the
      // enable triggers once the player's session is known.
      await dyn.setGains(SettingsManager().eqDynamicsGains);
      await dyn.setLimiter(SettingsManager().eqLimiter);
      await dyn.setEnabled(SettingsManager().eqEnabled);
      return;
    }
    final eq = target ?? equalizer;
    if (eq == null) return;
    try {
      await eq.setEnabled(SettingsManager().eqEnabled);
    } catch (e) {
      appLog('[eq] enable error: $e');
    }
    _eqGainsPending =
        SettingsManager().eqEnabled && SettingsManager().eqBandGains.isNotEmpty;
  }

  // Push saved band gains onto the active equalizer once a source has loaded
  // (driven by the 'ready' handler, where parameters resolves immediately —
  // the timeout is only a safety net). Leaves _eqGainsPending set if it can't
  // apply yet (no equalizer / not loaded), so a later ready retries.
  bool _eqGainsPending = false;
  Future<void> _pushSavedGains() async {
    final eq = equalizer;
    if (eq == null) return;
    final saved = SettingsManager().eqBandGains;
    if (saved.isEmpty) {
      _eqGainsPending = false;
      return;
    }
    try {
      final params = await eq.parameters.timeout(const Duration(seconds: 3));
      // Clamp to this device's range: gains saved on another phone (a
      // restored config) can exceed it, and an out-of-range setBandLevel
      // throws — leaving the apply half done and retrying on every ready.
      final lo = params.minDecibels;
      final hi = params.maxDecibels;
      for (var i = 0; i < params.bands.length && i < saved.length; i++) {
        await params.bands[i].setGain(saved[i].clamp(lo, hi));
      }
      _eqGainsPending = false;
    } catch (e) {
      appLog('[eq] gain apply error: $e');
    }
  }

  /// Settings › Reset: the saved EQ is already back to its defaults (off,
  /// flat, limiter on) — bring the live engine along. The ten-band engine
  /// keeps its last gains until told, so the EQ screen and a later enable
  /// would bring the old curve back; the five-band one is rebuilt plain by
  /// turning it off.
  Future<void> resetEqualizer({required bool wasOn}) async {
    final dyn = dynamicsEqualizer;
    if (dyn != null) {
      await dyn.setGains(List<double>.filled(DynamicsEqualizer.bandCount, 0));
      await dyn.setLimiter(SettingsManager().eqLimiter);
    }
    if (wasOn) await setEqEnabled(false);
  }

  /// Toggle the native EQ on or off. just_audio fixes the audio pipeline at
  /// player construction, so this rebuilds the local player WITH or WITHOUT
  /// the EQ effect (LocalPlaybackBackend.rebuildPlayer) and carries playback
  /// across at the same spot. Serialized through _switchChain so it can't
  /// interleave with a cast switch, error recovery, or the launch restore.
  /// Called by the EQ screen.
  Future<void> setEqEnabled(bool enabled) {
    _switchChain = _switchChain
        .then((_) => _doSetEqEnabled(enabled))
        .catchError((Object e) => appLog('[eq] toggle failed: $e'));
    return _switchChain;
  }

  Future<void> _doSetEqEnabled(bool enabled) async {
    // Don't race _init's seed/EQ on the single player (the same gate
    // restoreQueue waits on). Runs serialized on _switchChain — see above.
    await _initialized.future;

    // Ten-band engine: the effect lives on the audio session, not in the
    // player's pipeline, so there is nothing to rebuild — attach or release
    // in place (the engine waits for a session if there is none yet), then
    // persist. Casting needs no special case: the local player keeps its
    // session id, and the engine follows it on return.
    final dyn = dynamicsEqualizer;
    if (dyn != null) {
      if (enabled) {
        await dyn.setGains(SettingsManager().eqDynamicsGains);
        await dyn.setLimiter(SettingsManager().eqLimiter);
      }
      await dyn.setEnabled(enabled);
      await SettingsManager().setEqEnabled(enabled);
      return;
    }

    // Casting: the local backend is inactive. Rebuild it so it's correct when
    // the user returns to the phone, but leave the active (cast) backend
    // untouched. No re-seed here — _switchBackend re-seeds the local backend
    // with fresh URLs on every return-to-local anyway, and loading sources
    // now would just bake soon-stale tunnel ports into a parked player.
    if (!identical(_backend, _localBackend)) {
      await _localBackend.rebuildPlayer(withEqualizer: enabled);
      await SettingsManager().setEqEnabled(enabled);
      if (enabled) await _applySavedEqualizer(_localBackend.equalizer);
      return;
    }

    // Local backend active — carry position / index / play + shuffle/repeat
    // across the rebuild (the new player starts empty). _reviveSpot: a parked
    // failed-restore spot must survive the rebuild, not be replaced by the
    // never-loaded player's index 0.
    final spot = _reviveSpot();
    final wasShuffle = _localBackend.shuffleEnabled;
    final wasRepeat = _localBackend.repeat;

    // _rebuilding suppresses the currentIndexStream Auto-DJ top-up, the
    // now-playing re-emit, and state broadcasts while the swap is mid-flight:
    // the old player's dispose-time events would otherwise be read through
    // the NEW empty player and publish a transient bogus `error` state (queue
    // non-empty + idle + no intentional stop) to the media session.
    _rebuilding = true;
    try {
      await _localBackend.pause();
      await _localBackend.rebuildPlayer(withEqualizer: enabled);
      // Re-emit IMMEDIATELY (same instance): the switchMap-derived streams
      // must rebind to the NEW player before its first load — a failed
      // re-seed below would otherwise leave the handler deaf forever on the
      // disposed player's closed streams, and the re-seed's 'loading' event
      // (which clears the WifiLock predates-patch marker) would go
      // unobserved. Player streams replay current state on subscribe, so the
      // early rebind loses nothing.
      _backendSubject.add(_localBackend);
      // Persist only after the rebuild succeeds, so a thrown rebuild can't
      // leave the setting saying "on" with no pipeline attached.
      await SettingsManager().setEqEnabled(enabled);
      // Enable EQ + arm the saved-gains apply BEFORE the re-seed, so the
      // gains are already pending when the new source's first 'ready' fires.
      if (enabled) await _applySavedEqualizer();
      await _localBackend.setShuffleEnabled(wasShuffle);
      await _localBackend.setRepeat(wasRepeat);
      try {
        final fresh = _queueWithFreshUrls();
        if (fresh.isNotEmpty) {
          await _loadAtSpot(_localBackend, fresh, spot);
          // Live _playIntent, not a captured wasPlaying: a pause (or play)
          // landing during the network-bound load must win — the same
          // post-await doctrine as every revive path.
          if (_playIntent) unawaited(_localBackend.play());
        }
      } catch (e) {
        // _loadAtSpot already parked the spot and logged the cause; the new
        // player is empty, so without that park the next revive / snapshot
        // save would land on track 1 / 0:00 instead of the user's spot.
        appLog('[eq] re-seed after EQ toggle failed: $e');
      }
      // The rebuilt player has a new audio-session id — re-point the
      // visualizer's real-audio capture (no-op unless actively tapping).
      unawaited(VisualizerAudio().reattachSession());
    } finally {
      _rebuilding = false;
    }
    _broadcastState();
    _emitCurrentMediaItem();
  }

  /// Pushed for exactly one event as the queue empties, purely to overwrite
  /// the platform session's metadata. Never meant to be READ as a track — the
  /// null that follows it immediately is the value in-app consumers see.
  ///
  /// Both fields are SET rather than left empty or null, because the media
  /// card renders whatever it is handed: an empty title made One UI fall back
  /// to "mStream Plus is running", and a null artist printed the literal word
  /// "null" underneath it.
  ///
  /// English, like the Auto DJ notices in this file — the handler has no
  /// BuildContext and no locale of its own, and plumbing one in for a single
  /// placeholder is more machinery than the string is worth.
  static const MediaItem _blankNowPlaying =
      MediaItem(id: '', title: 'No media loaded', artist: '');

  void _emitCurrentMediaItem() {
    if (_reordering || _rebuilding || _restoring) return;
    if (queue.value.isEmpty) {
      // Nothing queued is nothing playing. This used to return early, which
      // left the last track's title, artist and art standing on every
      // now-playing surface — the player bar, the expanded player, the
      // system notification and the lock screen — after the queue was
      // cleared. The three flags above already cover the windows where the
      // queue is EMPTY IN TRANSIT (a restore before its publish, a
      // transcode-URL rebuild, a reorder), so reaching here means the queue
      // is genuinely empty rather than mid-swap.
      //
      // TWO events, deliberately. audio_service drops a null mediaItem on the
      // floor (audio_service.dart:1023, `if (mediaItem == null) return`), so
      // null alone cleared the in-app surfaces and left the last track's
      // title and art sitting on the notification and lock screen — verified
      // in the shade after a clear. A blank item IS forwarded, and
      // overwriting is the only way to clear those while the service stays
      // foreground, which it must: androidStopForegroundOnPause is false so
      // One UI can't reap it across a pause.
      //
      // The null that follows is what every in-app consumer already reads as
      // "nothing playing", so no call site has to learn what a blank item
      // means and .value settles on null before any listener runs.
      //
      // Guarded on something actually showing: this also runs on duration
      // ticks, and an empty queue must not push a blank item at the platform
      // over and over.
      if (mediaItem.valueOrNull != null) mediaItem.add(_blankNowPlaying);
      mediaItem.add(null);
      return;
    }
    // A failed launch restore parks a spot the backend never reached — show
    // THAT track as now-playing, not track 1. Spot FIRST: the failed load
    // leaves the backend's currentIndex at 0 (not null), so an index-first
    // read never falls through. Cleared on ready / user navigation.
    final i = (_restoreSpot?.index ?? index ?? 0)
        .clamp(0, queue.value.length - 1);
    final item = queue.value[i];
    final dur = _backend.duration;
    mediaItem.add(dur != null ? item.copyWith(duration: dur) : item);
    _topUpExtras(item);
  }

  // Tracks we have already asked the server about this session, as
  // server\u0000path. This method runs on every duration tick, so without it a
  // track whose fetch comes back empty is re-requested several times a second.
  final Set<String> _extrasToppedUp = {};

  /// Fill in what an OLD queue entry never stored.
  ///
  /// Queue items are persisted with the extras they were built from, so a
  /// track queued by a build that wrote fewer keys keeps that shape forever —
  /// and until [queueExtras] existed, Auto DJ wrote its own shorter map. Those
  /// items play fine but have no hasLyrics, bitrate, sampleRate or format, so
  /// the now-playing badges and Song Info show a thinner track than the same
  /// file added by hand.
  ///
  /// Rather than back-fill the whole queue at restore — hundreds of requests
  /// racing the tunnel that may not be up yet — each track tops itself up as
  /// it becomes current: one small request, at a moment the server is
  /// demonstrably reachable, for the one item anything is about to read.
  /// Fire-and-forget; a failure just leaves the item as it was.
  void _topUpExtras(MediaItem m) {
    final e = m.extras;
    // hasLyrics is written unconditionally by queueExtras, so its ABSENCE
    // (not its value) is what marks an entry as predating it.
    if (e == null || e.containsKey('hasLyrics')) return;
    final serverName = e['server'] as String?;
    final path = e['path'] as String?;
    if (serverName == null || path == null) return; // local file
    if (!_extrasToppedUp.add('$serverName\u0000$path')) return;
    final server = ServerManager().byLocalname(serverName);
    if (server == null) return;
    () async {
      final meta = await ApiManager().fetchTrackMetadata(server, path);
      if (meta == null) return;
      final patched =
          patchQueueExtras(queue.value, serverName: serverName, path: path, meta: meta);
      if (patched == null) return;
      appLog('[queue] topped up metadata for ${path.split('/').last}');
      queue.add(patched);
      _emitCurrentMediaItem();
    }();
  }

  /// The queue with every copy of [serverName]+[path] that predates
  /// [queueExtras] given the full key set, or null when nothing needed it.
  ///
  /// The item's OWN extras are spread last on purpose: djPick, djSonic, a
  /// localPath from a finished download and a rating the user changed while
  /// the track sat in the queue all outrank a freshly fetched copy. Only the
  /// keys that were never there get added. Pure; unit-tested.
  static List<MediaItem>? patchQueueExtras(List<MediaItem> queue,
      {required String serverName,
      required String path,
      required MusicMetadata meta}) {
    var changed = false;
    final patched = queue.map((m) {
      final e = m.extras;
      if (e == null ||
          e['server'] != serverName ||
          e['path'] != path ||
          e.containsKey('hasLyrics')) {
        return m;
      }
      changed = true;
      return m.copyWith(extras: {
        ...queueExtras(meta,
            server: serverName, path: path, artUrl: e['artUrl'] as String?),
        ...e,
      });
    }).toList();
    return changed ? patched : null;
  }

  /// Switch playback to a [CastTarget] chosen in the cast picker. Builds the
  /// matching backend (the persistent local just_audio backend, or a fresh
  /// DLNA session) and hands it the current queue + position so playback
  /// continues on the new device. Wired to CastManager.onTargetSelected.
  Future<void> _switchToTarget(CastTarget target, bool visualizer) {
    _switchChain = _switchChain
        .then((_) => _doSwitchToTarget(target, visualizer))
        .catchError((Object e) {
      castLog('Cast backend switch failed', error: e);
    });
    return _switchChain;
  }

  Future<void> _doSwitchToTarget(CastTarget target, bool visualizer) async {
    final PlaybackBackend next;
    if (target.isLocal) {
      next = _localBackend;
    } else if (target.kind == CastTargetKind.dlna) {
      next = DlnaPlaybackBackend(udn: target.id);
    } else if (target.kind == CastTargetKind.chromecast) {
      // visualizer = stream the on-device visualizer (video) instead of audio.
      next = ChromecastPlaybackBackend(
          deviceId: target.id, visualizer: visualizer);
    } else {
      return;
    }
    if (identical(next, _backend)) return;
    // A visualizer cast makes the phone the renderer's byte origin (on-device
    // HLS transcode served by LocalMediaServer) — the WifiLock heuristics need
    // to know, and the backend itself doesn't expose it.
    _castVisualizer = !target.isLocal && visualizer;
    await _switchBackend(next);
  }

  // Carry the current position / index / playing state + shuffle/repeat to the
  // new backend, make it active (switchMap re-subscribes the derived streams),
  // resume, then tear down the previous backend if it was a per-session remote
  // one (the local backend is persistent and reused).
  Future<void> _switchBackend(PlaybackBackend next) async {
    final prev = _backend;
    // _reviveSpot when leaving the LOCAL player: a parked failed load leaves
    // its index reading 0, so casting while parked would start the renderer
    // at track 1 — and the cast's own `ready` then clears the park, laundering
    // the loss into something no revive can undo. A remote backend has no
    // park concept, so it keeps reporting for itself.
    final fromLocal = identical(prev, _localBackend);
    final spot = fromLocal ? _reviveSpot() : null;
    final pos = spot?.position ?? prev.position;
    final idx = spot?.index ?? prev.currentIndex ?? 0;
    final wasPlaying = prev.playing;
    // The switch carries the AUDIBLE state, so the intent must follow it:
    // playback started from a renderer's own remote never went through
    // handler.play(), and a stale intent=false would make every intent-gated
    // resume (skip-after-error, recoveries) land paused mid-listen after
    // returning to the phone.
    _playIntent = wasPlaying;

    await prev.pause();

    await next.setShuffleEnabled(prev.shuffleEnabled);
    await next.setRepeat(prev.repeat);
    // Returning to the phone must re-derive queue URLs (the auto rebuild is
    // skipped while casting; a tunnel restart mid-cast leaves stale loopback
    // ports in the stored ids). Cast backends re-resolve per track instead.
    // initialIndex so the load starts where the user IS. The follow-up seek
    // stays: a cast backend takes its position from that seek (its setSources
    // deliberately ignores initialPosition) and carries the play state into
    // the load so the renderer auto-plays when its media is ready. Not routed
    // through _loadAtSpot — parking a local-playback spot on a switch TO a
    // renderer would be meaningless, and the local arm's own revive paths
    // already cover the way back. Clamped: a queue edit racing the switch can
    // leave idx past the end, and an out-of-range initialIndex kills the load.
    final items = identical(next, _localBackend)
        ? _queueWithFreshUrls()
        : queue.value;
    await next.setSources(items,
        initialIndex: items.isEmpty ? null : idx.clamp(0, items.length - 1),
        initialPosition: items.isEmpty ? null : pos);
    _backendSubject.add(next);
    if (queue.value.isNotEmpty) {
      // Carry the play state into the load: a renderer then auto-plays when its
      // media is ready (no load-paused-then-race-play), and we don't await the
      // local backend's play() — whose future only completes on pause/stop, so
      // awaiting it here used to block the switch and leave the cast session
      // connected until the user hit pause.
      await next.seek(pos, index: idx, play: wasPlaying);
    }
    _broadcastState();

    // The remote backends swallow load/connection errors internally (so they
    // never throw here); detect a failed cast by whether playback actually
    // starts. If the renderer is unreachable / a Cast session won't connect /
    // the media is unplayable, fall back to local so playback isn't left
    // silently dead, and surface a toast.
    final isRemote = !identical(next, _localBackend);
    if (isRemote && wasPlaying && queue.value.isNotEmpty) {
      final started = await _awaitRemoteStart(next);
      if (!started) {
        await _fallBackToLocal(prev, next, pos, idx);
        return;
      }
    }

    if (!identical(prev, _localBackend)) {
      // Chromecast → Chromecast (device change or visualizer toggle): the Cast
      // session is app-global, shared by both backend instances — the outgoing
      // one must not end the session the new one just loaded media on.
      if (prev is ChromecastPlaybackBackend &&
          next is ChromecastPlaybackBackend) {
        prev.prepareCastToCastHandoff(next);
      }
      await prev.dispose();
    }
    // Switched back to the phone — tear down the local file server (no-op if it
    // was never started). A remote→remote switch keeps it up for the new one.
    if (identical(next, _localBackend)) {
      await LocalMediaServer().stop();
    }
  }

  // True once a freshly-activated remote backend actually starts (reaches
  // ready/playing) within a timeout; false if it stays stuck loading (renderer
  // unreachable / session won't connect / unplayable media).
  Future<bool> _awaitRemoteStart(PlaybackBackend backend) async {
    bool started(BackendProcessingState s) =>
        s == BackendProcessingState.ready ||
        s == BackendProcessingState.completed;
    if (started(backend.processingState)) return true;
    try {
      await backend.processingStateStream
          .firstWhere(started)
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      appLog('[cast] remote start timed out (12s)');
      return false;
    }
  }

  // A cast failed to start — resume on the phone at the same spot, tear down
  // the failed (and abandoned previous) remote backend, and tell CastManager
  // so the UI reverts to "This device" and shows a message.
  Future<void> _fallBackToLocal(PlaybackBackend prev, PlaybackBackend failed,
      Duration pos, int idx) async {
    appLog('[cast] cast failed to start — back to this phone '
        'at track ${idx + 1}, ${pos.inSeconds}s');
    try {
      await failed.pause();
    } catch (_) {}
    await _reseedLocalAfterCastLoss(
      pos: pos,
      idx: idx,
      // The LIVE intent, not a literal true: a pause landing during the
      // 12s remote-start wait must win (the post-await doctrine every other
      // revive path follows) — not blast audio on the phone anyway.
      play: _playIntent,
      dispose: [
        if (!identical(failed, _localBackend)) failed,
        if (!identical(prev, _localBackend) && !identical(prev, failed)) prev,
      ],
      message: "Couldn't play on the cast device — back on this phone",
    );
  }

  // A remote renderer dropped offline *during* playback (not at switch time —
  // that's _fallBackToLocal). Resume on the phone at the current spot and tell
  // CastManager (reverts the UI to "This device" + toast). Serialized through
  // _switchChain so it can't interleave with a user-initiated target switch.
  void _onRendererLost(String message) {
    _switchChain = _switchChain.then((_) async {
      final failed = _backend;
      if (identical(failed, _localBackend)) return; // already recovered
      final pos = failed.position;
      final idx = failed.currentIndex ?? 0;
      final wasPlaying = failed.playing;
      appLog('[cast] renderer lost mid-cast — back to this phone at '
          'track ${idx + 1}, ${pos.inSeconds}s (playing=$wasPlaying)');
      await _reseedLocalAfterCastLoss(
          pos: pos, idx: idx, play: wasPlaying, dispose: [failed], message: message);
    }).catchError((Object e) {
      castLog('Renderer-lost fallback failed', error: e);
    });
  }

  /// Shared tail of every lost/failed-cast fallback: reseed the LOCAL backend
  /// with the queue (URLs refreshed — see [_queueWithFreshUrls]) and park/play
  /// at [pos]/[idx], then — in a `finally`, so a reseed fighting a dead server
  /// can't skip it — hand the subject over, dispose the remote [dispose]
  /// backends (leaking one leaves its tickers + session listeners running),
  /// stop the LAN file server, and surface [message]. The subject swap sits in
  /// the `finally` too: after a THROWING reseed the handler must still point
  /// at the local backend (whose errorStream recovery owns dead-server
  /// handling), and on the happy path swapping after the load means the
  /// switchMap listeners replay a loaded player, not a stale idle one.
  Future<void> _reseedLocalAfterCastLoss({
    required Duration pos,
    required int idx,
    required bool play,
    required List<PlaybackBackend> dispose,
    required String message,
  }) async {
    try {
      final items = _queueWithFreshUrls();
      if (items.isNotEmpty) {
        await _loadAtSpot(_localBackend, items, (index: idx, position: pos));
        // play && _playIntent, not the captured flag alone: this load is
        // network-bound and can run for seconds, and a pause landing inside
        // that window must win. Same post-await doctrine as every other
        // revive path here.
        if (play && _playIntent) unawaited(_localBackend.play());
      }
    } finally {
      _backendSubject.add(_localBackend);
      _broadcastState();
      for (final b in dispose) {
        await b.dispose();
      }
      await LocalMediaServer().stop();
      CastManager().reportCastFailed(message);
    }
  }

  /// The queue with every stream URL re-derived against the CURRENT tunnel /
  /// transcode state, updating the queue subject when anything changed. The
  /// auto rebuild is skipped while casting (cast loads re-resolve per track),
  /// so this is the deferred catch-up every return-to-local must run: after a
  /// tunnel restart mid-cast the stored ids still carry the OLD loopback
  /// port/token, and seeding just_audio with those fails on a tunnel that
  /// LOOKS healthy (tunnelServes == true), which sidesteps the iroh recovery.
  List<MediaItem> _queueWithFreshUrls() {
    final q = queue.value;
    if (q.isEmpty) return q;
    final rebuilt =
        q.map((m) => _withRebuiltArt(_withRebuiltUrl(m))).toList();
    var changed = false;
    for (int i = 0; i < q.length; i++) {
      if (!identical(rebuilt[i], q[i])) changed = true;
    }
    if (!changed) return q;
    appLog('[queue] stream URLs refreshed on return to local playback');
    queue.add(rebuilt);
    return rebuilt;
  }

  // just_audio surfaced a playback error (local stream path only — remote
  // backends report failures via rendererLostStream). The split, keyed on the
  // FAILED track's iroh server (the tunnel "follows playback", so it may not be
  // the browsed server):
  //  • iroh source whose tunnel is NOT live for it yet — launch, a cross-server
  //    queue advance that needs a tunnel switch, or a mid-stream drop → recover in
  //    place (ensure that server's tunnel, then re-seed + resume), don't skip;
  //  • anything else (local/HTTP source, or an iroh source whose tunnel IS up and
  //    it still failed = bad source) → warn and skip to the next track.
  void _onPlaybackError(Object error) {
    if (!identical(_backend, _localBackend)) return;
    // Diagnostic: capture the error class + where we were, so a network-blip
    // stop can be distinguished from a genuinely-unplayable source in the logs.
    appLog('[play] playback error ($error) '
        'index=${_localBackend.currentIndex} '
        'failedSkips=$_failedSkips/${queue.value.length}');
    // One error-handler at a time: while a recover or skip is in flight, ignore
    // further errors (a burst for one failure, or the wrap-around after a skip).
    // Whatever's playing when it finishes re-decides on its own fresh error.
    if (_recoveringPlayback || _skipPending) return;
    final idx = _localBackend.currentIndex;
    final q = queue.value;
    final failed = (idx != null && idx >= 0 && idx < q.length) ? q[idx] : null;
    // The track that just died may already be ON DISK. onTrackDownloaded
    // patches extras only — no live source surgery — so anything downloaded
    // AFTER the queue was seeded keeps streaming from its original source
    // until something reloads it. When that stream dies offline, reloading is
    // exactly the recovery: _uriFor re-resolves from extras and picks the
    // file. Must be tried BEFORE the iroh branch below, which parks playback
    // waiting for the very network the local copy exists to make unnecessary.
    if (_recoverFromLocalCopy(failed)) return;
    // Reaching here on a guarded track whose file is still present means the
    // disk copy was already tried and failed: the FILE is bad, not the
    // network. Parking on the tunnel would wait on a source this track
    // doesn't need, in silence, while the rest of a downloaded queue sits
    // there playable. Falling through hands it to _recoverHttpError, which
    // reads a decode/format failure as an unplayable source and skips.
    final badLocalCopy = _localRetryKey != null &&
        _localRetryKey == _trackKey(failed) &&
        failed?.extras?['localPath'] != null;
    final itemServer = failed == null ? null : _serverFor(failed);
    if (!badLocalCopy &&
        itemServer != null &&
        itemServer.isIrohTransport &&
        !ServerManager().tunnelServes(itemServer)) {
      // The tunnel isn't live for this track's iroh server — point it there and
      // resume rather than skipping. (If it IS serving this server and the track
      // still failed, that's a bad source → falls through to skip below.)
      _recoverIrohPlayback(itemServer);
      return;
    }
    // A direct peer whose own tunnel IS serving answered the load with a
    // refusal, not silence. The player's error text cannot say which
    // (ExoPlayer folds everything into "Source error"; iOS names a 4xx but
    // not whether it was the token), and a guest token the peer has stopped
    // honouring is the parent's to renew — so ask the loopback for the
    // status first and let the answer pick the path (FEDERATION_PLAN 8a).
    // Only the browse layer used to notice a 401; the playback path skipped
    // the track, and with a run of the peer's tracks queued, the whole run.
    if (!badLocalCopy &&
        failed != null &&
        itemServer != null &&
        directAuthAction(
              isDirect: itemServer.isDirect,
              tunnelServes: ServerManager().tunnelServes(itemServer),
              sinceLastRecovery: _sinceRecovery(itemServer),
              probed: false,
            ) ==
            DirectAuthAction.probe) {
      _recoverDirectAuth(itemServer, failed, error);
      return;
    }
    // The tunnel claims to be serving this server and the load still died.
    // The shim only flips to reconnecting once the QUIC connection's close
    // actually arrives, so a link that went away underneath it keeps
    // reporting connected — and nothing forces the issue, because the heal
    // fires on a status TRANSITION that never comes. Count these; past a
    // couple, ask for ground truth.
    if (itemServer != null &&
        itemServer.isIrohTransport &&
        ServerManager().tunnelServes(itemServer)) {
      unawaited(_noteTunnelLoadFailure(itemServer));
    }
    // Non-iroh source failed → hand off to _recoverHttpError, which (with an
    // async connectivity probe) pauses-and-holds on a real outage, retries a
    // transient blip in place, or skips a genuinely bad source.
    _recoverHttpError(error);
  }

  // Consecutive load failures against a tunnel that says it is connected.
  // Reset by the `ready` handler — anything loading at all means the path
  // works. Deliberately not reset by a recovery starting: the whole point is
  // to notice a RUN of failures the recoveries could not fix.
  int _tunnelLoadFailures = 0;
  static const int _kTunnelFailuresBeforeProbe = 3;

  /// Returns true only when this failure triggered the probe AND the probe
  /// cleared the path — the failures are the source's own.
  Future<bool> _noteTunnelLoadFailure(Server server) async {
    if (++_tunnelLoadFailures < _kTunnelFailuresBeforeProbe) return false;
    _tunnelLoadFailures = 0;
    appLog('[iroh] $_kTunnelFailuresBeforeProbe loads failed against a '
        'tunnel reporting connected — checking whether it really is');
    return ServerManager().reverifyTunnel(server);
  }

  // Consecutive heal resumes that failed (reset by `ready`, like the load
  // counter above): the heal's own bound, see healResumeFailureAction.
  int _healResumeFailures = 0;
  // Set when the heal hands a track to the skip walk: the path is fine and
  // the failures are the sources' own, so the heal stays out — every park
  // during the walk would otherwise re-trigger it (the idle transition is
  // its own trigger), re-seeding each failing track twice more before the
  // probe hands it off again. Lifted by a track loading, or by a real
  // tunnel edge, whose verdict supersedes this one.
  bool _healSuspended = false;
  static const int kMaxHealResumeFailures = 6;

  /// After a heal resume failed: keep re-arming while the path itself may be
  /// the problem; hand the track to the skip walk once the probe has cleared
  /// the path (the failures are the source's — an expired credential, a file
  /// the server no longer has — and no amount of re-seeding fixes those); and
  /// after [kMaxHealResumeFailures] regardless, so a probe that never ran
  /// (rate-limited, or another one in flight) cannot keep the loop alive.
  /// Before this the heal re-seeded the same track every ~14 s for as long as
  /// a serving tunnel and an idle player coexisted, and its own "probe passed
  /// — the failures were not the path" verdict changed nothing. Pure;
  /// unit-tested.
  static ResumeFailureAction healResumeFailureAction(
          {required bool pathVerified, required int failures}) =>
      pathVerified || failures >= kMaxHealResumeFailures
          ? ResumeFailureAction.skipTrack
          : ResumeFailureAction.rearm;

  // The TRACK whose local copy we already re-seeded for — identity, never an
  // index: a removal above the marked row slides a different track underneath
  // it, and that track's disk recovery would then be denied, parking an iroh
  // track on the tunnel with its file sitting on disk. Which is precisely the
  // incident this whole recovery exists to prevent.
  //
  // Without the guard at all, a corrupt-but-present file would error,
  // re-seed, error again forever. Cleared when a different track loads, on
  // explicit user navigation, and when a fresh download replaces the file.
  String? _localRetryKey;

  /// Stable identity for [m] across queue edits and URL rebuilds. Server
  /// localname + library path is the real identity; `id` is the fallback for
  /// a purely local item that has no server path, and is stable for exactly
  /// the items this guard covers ([_withRebuiltUrl] never rewrites an item
  /// carrying a localPath).
  static String? _trackKey(MediaItem? m) {
    if (m == null) return null;
    final path = m.extras?['path'] as String?;
    if (path == null) return m.id;
    return '${m.extras?['server'] as String? ?? ''}\u0000$path';
  }

  /// The same identity for callers outside the handler (the play tracker
  /// keys its sessions on it).
  static String? trackKey(MediaItem? m) => _trackKey(m);

  MediaItem? _itemAt(int? idx) {
    final q = queue.value;
    return (idx != null && idx >= 0 && idx < q.length) ? q[idx] : null;
  }

  /// True when [failed] is on disk and a reload has been scheduled, so the
  /// caller should stop: the file plays with no network at all.
  ///
  /// Only tried once per track — a second failure on the same track means the
  /// file itself is bad, and falls through to the normal recovery/skip path.
  bool _recoverFromLocalCopy(MediaItem? failed) {
    if (_recoveringPlayback || failed == null) return false;
    final key = _trackKey(failed);
    if (key == null || _localRetryKey == key) return false;
    final localPath = failed.extras?['localPath'] as String?;
    if (localPath == null || !File(localPath).existsSync()) return false;
    _localRetryKey = key;
    // Deliberately does NOT touch _failedSkips. The budget only ever grows in
    // _skipFailedTrack, so zeroing it here couldn't protect this recovery
    // from anything — it could only erase skips already accrued, and that
    // erases the terminal "Can't play these tracks" stop: a whole queue of
    // present-but-unplayable files (a captive portal answering a download
    // sweep with 200 + HTML makes one) would re-seed and skip forever
    // instead of stopping.
    _recoveringPlayback = true;
    appLog('[play] source failed but the track is downloaded — '
        'reloading from disk');
    _switchChain = _switchChain
        .then((_) => _reseedLocalAtSpot())
        .catchError((Object e) {
      appLog('[play] local-copy recovery failed: $e');
    }).whenComplete(() => _recoveringPlayback = false);
    return true;
  }

  // Resume after an iroh playback error whose tunnel isn't live yet: a mid-stream
  // drop (the supervisor reconnects the same loopback port) or a launch where the
  // tunnel wasn't up when the queue was restored. The tunnel target is owned by
  // the queue listener (this server's songs are queued); just await it for
  // [server], then re-seed (URLs rebuilt on the (re)bind) + resume with the user's
  // play intent. Per-server debounced + guarded so a failing source can't spin.
  bool _recoveringPlayback = false;
  // Per-server cooldown (keyed by localname) so a persistently-failing server
  // can't spin on recovery.
  final Map<String, DateTime> _lastRecoveryByServer = {};
  void _recoverIrohPlayback(Server server) {
    if (_recoveringPlayback) return;
    final now = DateTime.now();
    final last = _lastRecoveryByServer[server.localname];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    // A transport drop isn't a bad source — don't let it eat the skip budget.
    _failedSkips = 0;
    _recoveringPlayback = true;
    _lastRecoveryByServer[server.localname] = now;
    // The tunnel target is owned by the queue listener (this server's songs are
    // queued, so it's already the target); just wait for it and re-seed.
    _switchChain = _switchChain.then((_) async {
      if (queue.value.isEmpty) return;
      final ready = await ServerManager()
          .awaitTunnelReady(server: server, caller: 'playback');
      if (!ready) {
        // Parked. The tunnel's next `→ connected` edge (from the supervisor
        // or the retry loop's fresh dial) fires _onTunnelReconnected.
        appLog('[play] iroh recovery: tunnel not ready for '
            '${server.localname} — parked until it reconnects');
        return;
      }
      // Spot read AFTER the wait, not before: awaitTunnelReady re-arms its
      // deadline for as long as a dial is in flight and can run tens of
      // seconds, so a skip or seek landing in that window is the newer truth.
      // Same post-await doctrine as the play-intent reads below.
      // _reviveSpot: a launch-restore whose load failed parks at the SAVED
      // spot — the never-loaded backend would report track 1 / 0:00.
      final spot = _reviveSpot();
      // Rebuild URLs against the now-live tunnel ourselves rather than reusing
      // queue.value: a hard restart may have changed the port/token, and the
      // concurrent rebuild-on-(re)bind might not have refreshed queue.value yet —
      // _withRebuiltUrl uses the current effectiveBaseUrl, so these are always live.
      final fresh = queue.value
          .map((m) => _withRebuiltArt(_withRebuiltUrl(m)))
          .toList();
      queue.add(fresh);
      await _loadAtSpot(_localBackend, fresh, spot);
      // Resume with the user's intent: a mid-stream drop while playing resumes
      // playing; a launch-time recovery (never played) stays paused. Never
      // over a call (the interruption window).
      if (_playIntent && !_recentlyInterrupted) {
        unawaited(_localBackend.play());
      }
    }).catchError((Object e) {
      castLog('iroh playback recovery failed', error: e);
    }).whenComplete(() => _recoveringPlayback = false);
  }

  Duration? _sinceRecovery(Server s) {
    final t = _lastRecoveryByServer[s.localname];
    return t == null ? null : DateTime.now().difference(t);
  }

  /// The gap inside which a second 401/403 from the same direct peer is not
  /// renewed again: a token the parent renewed seconds ago cannot have
  /// lapsed, so the walk owns it. The probe itself (one ranged GET) runs on
  /// every failure — a 429 inside the gap is still the cap, and used to be
  /// walked blind (Galaxy, 2026-10-20: three retries into the cap and a
  /// skip, 8 s after the previous track's backoff). Shares the iroh
  /// recovery's per-server cooldown.
  static const Duration kDirectAuthRecoveryGap = Duration(seconds: 10);

  /// A direct peer at its concurrent-stream cap (the federation key's
  /// `maxStreams`, which a guest shares with the parent) answers 429 until
  /// the streams already open close — a few seconds after a run of skips.
  /// Re-probe after the peer's own Retry-After (this long without one),
  /// this many times, before the walk.
  static const Duration kDirectBusyBackoff = Duration(seconds: 3);
  static const int kDirectBusyAttempts = 3;

  /// A 429 whose Retry-After is longer than this is not the stream cap but
  /// the key's daily transfer quota (the peer sends the seconds to UTC
  /// midnight): nothing a wait could fix today.
  static const Duration kDirectBusyMaxWait = Duration(seconds: 60);

  /// What to do about a failed track from a direct peer. Pure; unit-tested.
  ///
  /// Two calls per failure. With [probed] false it says whether the loopback
  /// is worth asking at all ([DirectAuthAction.probe]): the peer is direct
  /// and its tunnel reports serving (a tunnel that is down is the iroh
  /// recovery's case). With [probed] true it says what the answer means:
  /// 401/403 → [DirectAuthAction.refresh] (the guest token is no longer
  /// honoured — the parent can renew it), unless a recovery ran inside
  /// [kDirectAuthRecoveryGap]; 404/410 → [DirectAuthAction.skip] (the peer
  /// says the file is gone); 429 → [DirectAuthAction.backoff], or
  /// [DirectAuthAction.quota] when its [retryAfter] reaches past
  /// [kDirectBusyMaxWait]; anything else — a 2xx now, a 5xx, no answer — →
  /// [DirectAuthAction.walk], the ordinary retry/skip path with its
  /// connectivity probe.
  static DirectAuthAction directAuthAction({
    required bool isDirect,
    required bool tunnelServes,
    required Duration? sinceLastRecovery,
    required bool probed,
    int? probedStatus,
    Duration? retryAfter,
  }) {
    if (!isDirect || !tunnelServes) return DirectAuthAction.walk;
    if (!probed) return DirectAuthAction.probe;
    switch (probedStatus) {
      case 401:
      case 403:
        final renewedJustNow = sinceLastRecovery != null &&
            sinceLastRecovery < kDirectAuthRecoveryGap;
        return renewedJustNow
            ? DirectAuthAction.walk
            : DirectAuthAction.refresh;
      case 404:
      case 410:
        return DirectAuthAction.skip;
      case 429:
        return retryAfter != null && retryAfter > kDirectBusyMaxWait
            ? DirectAuthAction.quota
            : DirectAuthAction.backoff;
      default:
        return DirectAuthAction.walk;
    }
  }

  /// The delay a `Retry-After` header asks for: null when absent, or not in
  /// the delay-seconds form the peer sends. Pure; unit-tested.
  static Duration? retryAfterOf(String? header) {
    final secs = int.tryParse(header?.trim() ?? '');
    return secs == null || secs < 0 ? null : Duration(seconds: secs);
  }

  /// Ask a direct peer's own loopback what it makes of [url] right now: the
  /// HTTP status of a one-byte range request (null when nothing answered
  /// within the tunnel probe's timeouts) and the Retry-After a 429 carried.
  /// The player's error text cannot be trusted for this, and the answer
  /// decides whether the guest token lapsed or the peer is merely full.
  static Future<StreamProbe> probeStreamStatus(String url) async {
    final client = HttpClient()
      ..connectionTimeout = TunnelTiming.probeLoopbackTimeout;
    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(TunnelTiming.probeLoopbackTimeout);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final resp =
          await req.close().timeout(TunnelTiming.probeResponseTimeout);
      final status = resp.statusCode;
      final retryAfter =
          retryAfterOf(resp.headers.value(HttpHeaders.retryAfterHeader));
      // Nothing to read past the status; a body that never ends must not
      // hold the decision.
      unawaited(resp.drain<void>().catchError((_) {}));
      return (status: status, retryAfter: retryAfter);
    } catch (e) {
      // The URL carries the token, so the error is named by kind only.
      appLog('[play] stream probe got no answer (${e.runtimeType})');
      return (status: null, retryAfter: null);
    } finally {
      client.close(force: true);
    }
  }

  /// A direct peer's parked or failed track: ask its loopback whether the
  /// guest token still holds, and renew it through the parent when it does
  /// not (FEDERATION_PLAN 8a). The probe is on [item]'s URL as it would be
  /// built NOW, not the one the player tried: a ticket renewed under a
  /// playing item (the in-place swap leaves it alone) makes the fresh URL
  /// fine and the stale one a 401, and then a reload with fresh URLs is the
  /// whole fix. Returns the verdict, the probe it rests on and, after a
  /// refresh, what the parent said; the caller reloads. [sinceLastRecovery]
  /// is the caller's reading of the gap from BEFORE it stamped the cooldown.
  Future<DirectAuthVerdict> _renewLapsedGuestToken(
      Server server, MediaItem item,
      {Duration? sinceLastRecovery}) async {
    final name = server.localname;
    final probe = await probeStreamStatus(_withRebuiltUrl(item).id);
    final action = directAuthAction(
      isDirect: server.isDirect,
      tunnelServes: ServerManager().tunnelServes(server),
      sinceLastRecovery: sinceLastRecovery,
      probed: true,
      probedStatus: probe.status,
      retryAfter: probe.retryAfter,
    );
    appLog('[play] direct peer answered ${probe.status ?? 'nothing'} for the '
        'failed track → ${action.name} for=$name');
    if (action != DirectAuthAction.refresh) {
      return (action: action, outcome: null, probe: probe);
    }
    appLog('[play] direct auth lapsed for=$name (http ${probe.status}) — '
        'refreshing the guest ticket');
    // A lapsed token is not a bad source: the budget is the walk's.
    _failedSkips = 0;
    final outcome = await ServerManager().onDirectAuthRejected(server);
    switch (outcome) {
      case DirectAccessOutcome.issued:
        break;
      case DirectAccessOutcome.denied:
        appLog('[play] direct access withdrawn for=$name — the proxy '
            'takes over');
      case DirectAccessOutcome.unchanged:
      case DirectAccessOutcome.failed:
      case DirectAccessOutcome.skipped:
        appLog('[play] guest ticket not renewed (${outcome.name}) '
            'for=$name — the walk takes the track');
    }
    return (action: action, outcome: outcome, probe: probe);
  }

  // Recover from a load that a direct peer's own tunnel refused
  // (FEDERATION_PLAN 8a), when the error callback gets there first (iOS;
  // on Android the idle park usually lands a moment earlier and the tunnel
  // heal runs the same renewal — see _onTunnelReconnected). On the chain:
  // probe, and on a 401/403 renew the guest ticket through the parent and
  // re-seed at the spot — playing again with the user's intent, and through
  // the proxy when the parent declined. A 404 skips; anything else hands
  // the original error to the ordinary walk once the chain is free. Guarded
  // like the iroh recovery: one at a time, and one renewal per server per
  // [kDirectAuthRecoveryGap].
  void _recoverDirectAuth(Server server, MediaItem failed, Object error) {
    if (_recoveringPlayback) return;
    _recoveringPlayback = true;
    // Read the gap BEFORE stamping it, or every renewal would look recent.
    final since = _sinceRecovery(server);
    _lastRecoveryByServer[server.localname] = DateTime.now();
    Object? followUp;
    var skip = false;
    _switchChain = _switchChain.then((_) async {
      if (queue.value.isEmpty || !identical(_backend, _localBackend)) return;
      final verdict = await _renewLapsedGuestToken(server, failed,
          sinceLastRecovery: since);
      switch (verdict.action) {
        case DirectAuthAction.refresh:
          switch (verdict.outcome) {
            case DirectAccessOutcome.issued:
            case DirectAccessOutcome.denied:
              // Every URL against the transport that is live now: the
              // peer's loopback with the new token, or the parent's proxy.
              await _reloadFreshAtSpot();
            case DirectAccessOutcome.unchanged:
            case DirectAccessOutcome.failed:
            case DirectAccessOutcome.skipped:
            case null:
              followUp = error;
          }
        case DirectAuthAction.skip:
          skip = true;
        case DirectAuthAction.backoff:
        case DirectAuthAction.quota:
          // The peer is full, or spent for the day: not the source's fault
          // and not the tunnel's, so neither budget is touched. Room again
          // → reload at the spot; otherwise the skip walk, bounded by the
          // queue, takes the track — three blind retries into the cap, the
          // walk's old opening, only added three more hits on it.
          switch (await _directPeerRoom(server, failed, verdict)) {
            case DirectPeerRoom.room:
              await _reloadFreshAtSpot();
            case DirectPeerRoom.none:
              skip = true;
            case DirectPeerRoom.moot:
              return;
          }
        case DirectAuthAction.walk:
        case DirectAuthAction.probe:
          // Answered, and not about the token: count it against the
          // tunnel as any other load failure, then walk.
          unawaited(_noteTunnelLoadFailure(server));
          followUp = error;
      }
    }).catchError((Object e) {
      castLog('direct-auth recovery failed', error: e);
      followUp = error;
    }).whenComplete(() {
      _recoveringPlayback = false;
      if (skip) {
        _skipPending = true;
        _switchChain = _switchChain
            .then((_) => _skipFailedTrack(error))
            .catchError((Object e) => castLog(
                'skip-to-next after a direct peer refusal failed',
                error: e))
            .whenComplete(() => _skipPending = false);
      } else if (followUp != null) {
        _recoverHttpError(followUp!);
      }
    });
  }

  /// Reload every URL against the transport that is live now, at the spot,
  /// and resume where the user still wants playback.
  Future<void> _reloadFreshAtSpot() async {
    final spot = _reviveSpot();
    final fresh =
        queue.value.map((m) => _withRebuiltArt(_withRebuiltUrl(m))).toList();
    queue.add(fresh);
    await _loadAtSpot(_localBackend, fresh, spot);
    if (_playIntent && !_recentlyInterrupted) {
      unawaited(_localBackend.play());
    }
  }

  /// A direct peer that answered 429 for [item]: at its stream cap, re-probe
  /// after each Retry-After (the peer sends 5 s; [kDirectBusyBackoff] without
  /// one) up to [kDirectBusyAttempts] times; with its daily quota spent, say
  /// so once and give the track up — every track of the peer's answers the
  /// same until UTC midnight, and the skip walk is bounded by the queue.
  Future<DirectPeerRoom> _directPeerRoom(
      Server server, MediaItem item, DirectAuthVerdict verdict) async {
    final name = server.localname;
    if (verdict.action == DirectAuthAction.quota) {
      final left = verdict.probe.retryAfter ?? Duration.zero;
      appLog("[play] direct peer's daily transfer quota is spent (resets in "
          '${left.inHours}h${left.inMinutes % 60}m) for=$name — skipping '
          'its tracks');
      _showPlaybackErrorToast(
          '${server.displayName} has reached its daily transfer limit — '
          'try again tomorrow.',
          debounce: true);
      return DirectPeerRoom.none;
    }
    var probe = verdict.probe;
    for (var i = 1; i <= kDirectBusyAttempts; i++) {
      final wait = probe.retryAfter ?? kDirectBusyBackoff;
      appLog('[play] direct peer busy (http ${probe.status}) for=$name — '
          'retry $i/$kDirectBusyAttempts in ${wait.inSeconds}s');
      await Future<void>.delayed(wait);
      if (queue.value.isEmpty || !identical(_backend, _localBackend)) {
        return DirectPeerRoom.moot;
      }
      probe = await probeStreamStatus(_withRebuiltUrl(item).id);
      if (probe.status != 429) break;
    }
    final status = probe.status;
    if (status != null && status >= 200 && status < 300) {
      appLog('[play] direct peer has room again (http $status) for=$name — '
          'reloading at the spot');
      return DirectPeerRoom.room;
    }
    appLog('[play] direct peer still busy (http $status) for=$name — '
        'skipping the track');
    return DirectPeerRoom.none;
  }

  // Consecutive failed tracks since one last loaded (reset on a `ready` state).
  int _failedSkips = 0;
  // True while a skip is chained/running — collapses an error burst into one skip
  // and keeps the before/after index read uncontended.
  bool _skipPending = false;
  DateTime? _lastErrorToast;
  // Collapse a run of failures into one toast (a long unplayable stretch
  // shouldn't fire a snackbar per track).
  static const Duration _kErrorToastGap = Duration(seconds: 4);

  // ── HTTP transient-error retry (resume-at-position) ──
  // A plain-HTTP source that drops mid-stream (a network blip, screen-off Wi-Fi
  // park, cellular handoff) used to skip immediately — and a queue-wide blip
  // stopped everything. Instead we retry the SAME track at the same spot a few
  // times with backoff before giving up. The counter resets to 0 when any track
  // actually loads (`ready`), so it bounds total retry effort during a real
  // outage: the first failing track retries, the rest skip fast.
  static const int _kMaxHttpRetries = 3;
  int _httpRetries = 0;
  // Set when a queue-wide network failure has PAUSED (not stopped) playback, so
  // a later connectivity-regained event (onNetworkRegained) resumes it. Cleared
  // when a track loads again.
  bool _networkStalled = false;

  // A source failed to play — warn (debounced) and skip to the next track, bounded
  // so an entirely-unplayable queue stops instead of looping (notably under
  // repeat-all). Serialized via _switchChain by the caller; local backend only.
  Future<void> _skipFailedTrack(Object error) async {
    if (!identical(_backend, _localBackend)) return; // switched to a renderer meanwhile
    final q = queue.value;
    if (q.isEmpty) return;
    castLog('playback error — skipping track', error: error);
    _failedSkips++;
    if (_failedSkips >= q.length) {
      // Tried every track once and none loaded. The error string can't tell a
      // 404 from a network drop on Android (ExoPlayer reports both as a generic
      // "Source error"), so probe the actual network: no connectivity → a real
      // outage, PAUSE (don't stop) and arm onNetworkRegained to resume when it
      // returns; connectivity present → the sources/server are bad, so stop.
      _failedSkips = 0;
      if (!await hasConnectivity()) {
        _showPlaybackErrorToast(
            'Lost the connection — paused. Resumes when you’re back online.');
        await _localBackend.pause();
        _networkStalled = true;
      } else {
        _showPlaybackErrorToast(
            "Can't play these tracks — check the files or server.");
        _intentionalStop = true;
        await _localBackend.stop();
      }
      _broadcastState();
      return;
    }
    _showPlaybackErrorToast('Skipping a track that won’t play.', debounce: true);
    final before = _localBackend.currentIndex;
    // seekToNext()'s Future completes only after _player.currentIndex is updated,
    // so the post-await read reliably reflects the new position.
    await _localBackend.seekToNext(); // shuffle/repeat-aware
    if (_localBackend.currentIndex == before) {
      // No-op → end of the queue with no repeat. Probe the network (the error
      // string can't distinguish outage from bad source on Android): no
      // connectivity → pause + arm self-heal so the user's spot survives;
      // otherwise stop.
      _failedSkips = 0;
      if (!await hasConnectivity()) {
        await _localBackend.pause();
        _networkStalled = true;
      } else {
        _intentionalStop = true;
        await _localBackend.stop();
      }
      _broadcastState();
      return;
    }
    // Resume only if the user still wants playback: an upcoming track can
    // fail while PAUSED (preload), and the skip must not blast audio over a
    // deliberate pause.
    if (_playIntent) unawaited(_localBackend.play());
  }

  void _showPlaybackErrorToast(String message, {bool debounce = false}) {
    if (debounce) {
      final now = DateTime.now();
      if (_lastErrorToast != null &&
          now.difference(_lastErrorToast!) < _kErrorToastGap) {
        return;
      }
      _lastErrorToast = now;
    }
    showGlobalSnack(message);
  }

  // Recover from a non-iroh playback error. The decision needs an async
  // connectivity probe, so it runs serialized on _switchChain + guarded by
  // _recoveringPlayback / _skipPending (an error burst can't spin up concurrent
  // recoveries):
  //  • clearly bad source (404 / format / missing file) → skip now;
  //  • NO network (a real outage) → pause-and-hold + arm onNetworkRegained so we
  //    self-heal when it returns. This is the key fix: relying on the retry/skip
  //    counters to climb never paused, because a brief `ready` from the preload
  //    buffer kept resetting _httpRetries, so it spun in retries forever;
  //  • network up but the track errored (a transient blip) → retry the SAME track
  //    at its spot, bounded by _kMaxHttpRetries; once spent it's a bad source → skip.
  void _recoverHttpError(Object error) {
    if (_recoveringPlayback || _skipPending) return;
    // Clearly bad/unplayable source → skip now (no network probe / retry needed).
    if (!_isTransientNetworkError(error)) {
      _skipPending = true;
      _switchChain = _switchChain
          .then((_) => _skipFailedTrack(error))
          .catchError((Object e) =>
              castLog('skip-to-next after playback error failed', error: e))
          .whenComplete(() => _skipPending = false);
      return;
    }
    _recoveringPlayback = true;
    // Set when the retry's own reload threw: the walk continues from
    // whenComplete, once the flag is released (see below).
    Object? followUp;
    _switchChain = _switchChain.then((_) async {
      if (queue.value.isEmpty || !identical(_backend, _localBackend)) return;
      // No network → an outage: pause-and-hold and let onNetworkRegained resume
      // us when it's back, instead of churning retries/skips that all fail.
      if (!await hasConnectivity()) {
        appLog('[play] network outage — pausing at '
            'track ${(_localBackend.currentIndex ?? 0) + 1}; '
            'will self-heal when connectivity returns');
        _httpRetries = 0;
        _failedSkips = 0;
        _networkStalled = true;
        _showPlaybackErrorToast(
            'Lost the connection — paused. Resumes when you’re back online.');
        await _localBackend.pause();
        _broadcastState();
        return;
      }
      // Network is up but the track errored — a transient blip. Retry the SAME
      // track at its spot (bounded); once retries are spent it's a genuinely bad
      // source → skip.
      if (_httpRetries < _kMaxHttpRetries) {
        _httpRetries++;
        final attempt = _httpRetries;
        // 0s, then 1s, 2s — first retry immediate so a momentary blip recovers
        // fast; later ones give the connection a moment.
        await Future<void>.delayed(Duration(seconds: attempt - 1));
        if (queue.value.isEmpty || !identical(_backend, _localBackend)) return;
        // Read the spot AFTER the backoff so a skip/seek during the wait is
        // honoured, and load DIRECTLY at it (initialIndex/Position) so the
        // now-playing UI doesn't flash track 0 on the reload. _reviveSpot: a
        // failed launch restore parks at the SAVED spot, not the backend's 0.
        final spot = _reviveSpot();
        final pos = spot.position;
        final idx = spot.index;
        appLog('[play] network error — retry $attempt/$_kMaxHttpRetries');
        final snapshot = _snapshotSpot; // before the load: ready clears it
        // Fresh URLs, not queue.value: a tunnel that rebuilt during the
        // backoff has a new port and token, and retrying the stale ones just
        // burns the bounded budget against addresses that cannot work.
        try {
          await _localBackend.setSources(_queueWithFreshUrls(),
              initialIndex: idx, initialPosition: pos);
        } catch (e) {
          // A dead source can fail INSIDE setSources. The player's error
          // event for it then lands while this recovery still holds the
          // flag and is dropped as "already recovering", so nothing would
          // follow this retry — on the rig the walk sat at retry 1 until
          // the tunnel heal happened to re-seed (which it no longer does
          // once it has handed a track to the walk). Carry on from here.
          appLog('[play] retry $attempt did not load: $e');
          followUp = e;
          return;
        }
        // A launch restore that failed is retried here too.
        await _settleSnapshotSpot(_localBackend, idx, spot, snapshot);
        if (_playIntent) unawaited(_localBackend.play());
      } else {
        await _skipFailedTrack(error);
      }
    }).catchError((Object e) {
      castLog('http error recovery failed', error: e);
    }).whenComplete(() {
      _recoveringPlayback = false;
      final next = followUp;
      if (next != null) _recoverHttpError(next);
    });
  }

  // Resume after a queue-wide network stall when connectivity returns. Wired to
  // the app's connectivity listener (main.dart). No-op unless we actually paused
  // on a network outage (_networkStalled); resumes the current track at its spot
  // with the user's play intent.
  void onNetworkRegained() {
    if (!identical(_backend, _localBackend)) return;
    if (!_networkStalled || _recoveringPlayback) return;
    if (queue.value.isEmpty) return;
    _networkStalled = false;
    _httpRetries = 0;
    _recoveringPlayback = true;
    appLog('[play] connectivity back — resuming after network stall');
    // Keep-queue-offline: failed auto-downloads un-mark themselves, and this
    // is exactly the moment a retry can succeed — re-sweep (cheap no-op when
    // the setting is off or nothing needs fetching).
    unawaited(DownloadManager().autoDownloadQueue(queue.value));
    _switchChain = _switchChain
        .then((_) => _reseedLocalAtSpot())
        .catchError((Object e) {
      castLog('network-regained resume failed', error: e);
    }).whenComplete(() => _recoveringPlayback = false);
  }

  /// Load [items] into [backend] starting AT [spot], and park that spot if
  /// the load throws.
  ///
  /// Two rules in one, because they are the same rule. A player must never be
  /// asked to start at track 1 while the user is somewhere else — just_audio
  /// defaults a source list to index 0, so `setSources(items)` followed by a
  /// `seek` is a load of the WRONG track that only reaches the right one if
  /// it succeeds. And a load that fails must not be left REPORTING track 1
  /// afterwards, because everything downstream believes it.
  ///
  /// Both halves come from one incident. A tunnel died mid-drive, the URL
  /// rebuild loaded index 0, that load threw, and the session was stranded on
  /// the one track in a 102-item queue that wasn't downloaded — the offline
  /// cap keeps a window AHEAD of the playing track, so track 1 was the first
  /// thing evicted. Ten minutes of silence, with the track the user was
  /// actually on sitting on disk the whole time. Loading at the spot would
  /// have played it with no network at all.
  ///
  /// The spot is parked, not merely remembered: [_restoreSpot] is what
  /// [_reviveSpot] and the queue snapshot both read, so parking keeps the
  /// position true for the next revive AND stops queue.json persisting the
  /// loss within a second of the failure.
  Future<void> _loadAtSpot(PlaybackBackend backend, List<MediaItem> items,
      ({int index, Duration position}) spot) async {
    final idx = spot.index.clamp(0, items.length - 1);
    final snapshot = _snapshotSpot; // before the load: reaching ready clears it
    try {
      await backend.setSources(items,
          initialIndex: idx, initialPosition: spot.position);
    } catch (e) {
      _restoreSpot = (index: idx, position: spot.position);
      appLog('[play] load failed — spot parked (track ${idx + 1} @ '
          '${spot.position.inSeconds}s): $e');
      rethrow;
    }
    await _settleSnapshotSpot(backend, idx, spot, snapshot);
  }

  /// The queue position the app considers current: the parked spot when a load
  /// failed, else the backend's own index. Read by the offline cache window —
  /// an errored player reports 0, and a window recentred on that bogus 0
  /// evicts the downloads sitting AHEAD of the user, which is precisely the
  /// offline copy they need when the network is the thing that broke.
  int get logicalQueueIndex {
    final q = queue.value;
    if (q.isEmpty) return 0;
    // A park wins — that is the whole point — but otherwise read the ACTIVE
    // backend, not _reviveSpot's local one. During a cast the local player
    // sits frozen at the switch-time index while the renderer advances, so
    // _reviveSpot would peg the download window to a stale spot: nothing
    // ahead of the real position prefetches, and files around it get evicted
    // as "outside the window" — the exact wrong-side eviction this getter
    // exists to prevent, just moved into the cast arm.
    final parked = _restoreSpot;
    final i = parked != null ? parked.index : (_backend.currentIndex ?? 0);
    return i.clamp(0, q.length - 1);
  }

  /// Key (server + path, the sweep's) of the track the local player is
  /// pulling from the network right now, so keep-queue-offline does not pull
  /// the same bytes beside it — on a federated peer that was a third of the
  /// key's shared bandwidth, and the copy landed after the track had ended.
  String? get streamingTrackKey {
    if (!identical(_backend, _localBackend) ||
        _localBackend.processingState == BackendProcessingState.idle) {
      return null;
    }
    final item = _itemAt(_localBackend.currentIndex);
    if (item == null || !_streamsFromNetwork(item)) return null;
    final s = item.extras?['server'], p = item.extras?['path'];
    return s is String && p is String ? s + p : null;
  }

  /// Reload the local backend at its current spot, with every URL re-derived
  /// against the live tunnel/transcode state, then resume if the user still
  /// wants playback. The revive primitive for a parked player: once just_audio
  /// goes idle (a playback error tears the platform player down) a bare play()
  /// silently no-ops — only a re-seed brings audio back. _playIntent is read
  /// AFTER the load on purpose: setSources is network-bound (seconds over a
  /// just-reconnected tunnel) and a pause landing mid-load must win over the
  /// recovery that scheduled us. Callers serialize on _switchChain and hold
  /// _recoveringPlayback.
  Future<void> _reseedLocalAtSpot() async {
    if (!identical(_backend, _localBackend)) return;
    final fresh = _queueWithFreshUrls();
    if (fresh.isEmpty) return;
    final spot = _reviveSpot();
    final idx = spot.index.clamp(0, fresh.length - 1);
    // A queue that played out left the player on its last track's END, and
    // loading there completes at once: the track starts over instead, unless
    // another one follows it (shouldReviveFromTop). Decided here rather than
    // in play() so it is read with the spot itself, after whatever the chain
    // ran first, and so every revive of a finished queue gets the same answer.
    final finished = _finishedTrack;
    final fromTop = shouldReviveFromTop(
        queueFinished: finished != null,
        onFinishedTrack: finished == _trackKey(fresh[idx]),
        spotParked: _restoreSpot != null,
        index: idx,
        queueLength: fresh.length,
        shuffle: _localBackend.shuffleEnabled,
        repeat: _localBackend.repeat);
    if (fromTop) {
      appLog('[play] the queue had ended — '
          'track ${idx + 1} starts from the top');
    }
    final snapshot = _snapshotSpot; // before the load: reaching ready clears it
    // Load DIRECTLY at the spot (initialIndex/Position) so the now-playing UI
    // doesn't flash track 0 on the reload.
    await _localBackend.setSources(fresh,
        initialIndex: idx,
        initialPosition: fromTop ? Duration.zero : spot.position);
    // The spot can be the launch snapshot's, loaded here because the restore
    // could not reach the server.
    if (!fromTop) await _settleSnapshotSpot(_localBackend, idx, spot, snapshot);
    if (_playIntent && !_recentlyInterrupted) {
      unawaited(_localBackend.play());
    }
  }

  // Resume playback parked by an iroh server outage, fired on the tunnel's
  // not-connected → connected transition (listener in _init). The supervisor
  // heals a dropped tunnel in place — same loopback port — so the stored URLs
  // still look current and _ensureActiveTunnel's rebuild-on-restart never
  // runs; without this hook nothing reloads the player when the server
  // returns. Only touches a player that is actually parked: local backend,
  // idle without a deliberate stop, current track owned by the served server.
  // One-shot re-check for a connected edge that arrived while a transient
  // guard blocked the heal. The status subject emits on change only, so a
  // consumed edge never re-fires on its own — dropping it would park playback
  // until the user taps play.
  Timer? _tunnelHealRetry;
  /// What the tunnel heal should do when it runs. Pure; unit-tested.
  ///
  /// [HealAction.rearm] rather than [HealAction.drop] for a player that isn't
  /// parked YET is the whole point. The heal's original trigger was a single
  /// edge — the tunnel status going not-connected → connected — and that
  /// stream only emits on CHANGE. So an edge that lands while a load is still
  /// in flight used to be swallowed by a bare `return`, and if that load then
  /// failed, the player parked with the tunnel already connected and no
  /// further edge coming. Nothing retried, ever.
  ///
  /// That is the seven-and-a-half minutes of silence in the incident log: the
  /// bind at 18:21:14 fired the heal while the reload was still running, the
  /// reload threw at 18:21:17, and nothing automatic happened again until a
  /// hard rebuild produced a fresh edge at 18:29:19.
  static HealAction healAction({
    required bool onLocalBackend,
    required bool intentionalStop,
    required bool recovering,
    required bool skipPending,
    required BackendProcessingState processingState,
    required bool queueEmpty,
    bool healSuspended = false,
  }) {
    if (!onLocalBackend || intentionalStop || queueEmpty) return HealAction.drop;
    // The probe has cleared the path and the skip walk owns the failures.
    if (healSuspended) return HealAction.drop;
    // A recovery in flight will finish; re-check after it does.
    if (recovering || skipPending) return HealAction.rearm;
    // Not parked yet. It may still park (a load in flight can fail), and no
    // second edge is coming, so keep watching rather than dropping the edge.
    if (processingState != BackendProcessingState.idle) return HealAction.rearm;
    return HealAction.run;
  }

  void _onTunnelReconnected() {
    _tunnelHealRetry?.cancel();
    _tunnelHealRetry = null;
    // A pick owed from the outage comes first: the queue may have ENDED while
    // the tunnel was down (parked on `completed`, not idle — healAction alone
    // would only re-arm forever). The pick appends the next track and, when
    // the park held the play intent, seeks to it and plays. A failing retry
    // re-sets the pending flag and the 11s re-arm brings us back here,
    // bounded by kMaxDeferredPickFailures and the park timer.
    final dj = autoDJServer;
    if (dj != null &&
        shouldRetryDeferredPick(
            pending: _djPickPending,
            tunnelServes: ServerManager().tunnelServes(dj),
            onLocalBackend: identical(_backend, _localBackend),
            intentionalStop: _intentionalStop,
            failures: _deferredPickFailures)) {
      if (_djInFlight) {
        // A pick is already running (an index re-emission beat the status
        // edge to the tunnel); it lands with the park-derived resume below.
        _rearmTunnelHeal();
        return;
      }
      final parked = _stillParked;
      _djPickPending = false;
      appLog('[dj] tunnel back — retrying the deferred pick'
          '${parked ? ' and resuming' : ''}');
      // No flags: whether the landing pick resumes is decided by the park
      // (see _queueAutoDJSong), so a pick started by someone else resumes too.
      unawaited(autoDJ());
      if (parked) {
        _rearmTunnelHeal();
        return;
      }
    }
    final q = queue.value;
    switch (healAction(
      onLocalBackend: identical(_backend, _localBackend),
      intentionalStop: _intentionalStop,
      recovering: _recoveringPlayback,
      skipPending: _skipPending,
      processingState: _localBackend.processingState,
      queueEmpty: q.isEmpty,
      healSuspended: _healSuspended,
    )) {
      case HealAction.drop:
        return;
      case HealAction.rearm:
        _rearmTunnelHeal();
        return;
      case HealAction.run:
        break;
    }
    // _reviveSpot: after a failed launch restore the backend reads index 0 --
    // a mixed queue whose track 1 isn't iroh would never pass the gate below
    // even though the PARKED track's server just healed.
    final idx = _reviveSpot().index;
    final item = (idx >= 0 && idx < q.length) ? q[idx] : null;
    final server = item == null ? null : _serverFor(item);
    if (server == null || !server.isIrohTransport) return;
    if (!ServerManager().tunnelServes(server)) return;
    // Shares the error-time recovery's per-server budget so a flapping tunnel
    // (connected↔reconnecting) can't spin reloads against a dying server.
    final now = DateTime.now();
    final last = _lastRecoveryByServer[server.localname];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      _rearmTunnelHeal();
      return;
    }
    _lastRecoveryByServer[server.localname] = now;
    _recoveringPlayback = true;
    appLog('[play] iroh tunnel back — resuming parked playback');
    // Keep-queue-offline: same retry moment as onNetworkRegained — a queued
    // iroh track's download URL only works while the tunnel serves.
    unawaited(DownloadManager().autoDownloadQueue(queue.value));
    var handOff = false;
    _switchChain = _switchChain.then((_) async {
      // Re-check the park under the chain: something queued ahead of us (a
      // backend switch, a user play) may already have revived the player.
      if (_localBackend.processingState != BackendProcessingState.idle) return;
      // A direct peer's park is the heal's first on Android: the idle state
      // lands a moment before the error callback, so _onPlaybackError finds
      // this recovery already running and steps aside. A guest token the
      // peer stopped honouring would then be re-seeded as-is (Galaxy S25,
      // 2026-09-18: three 401s, a silent player until the poll renewed) —
      // ask the loopback first and renew before the reload (FEDERATION_PLAN
      // 8a). A peer at its stream cap gets the same wait as the error path
      // — re-seeding straight into the 429, three times over, was this
      // branch ignoring that verdict (2026-10-20) — and one spent for the
      // day is skipped. Anything else leaves the heal as it was.
      if (server.isDirect) {
        final parked = item!;
        final verdict = await _renewLapsedGuestToken(server, parked);
        if (verdict.action == DirectAuthAction.backoff ||
            verdict.action == DirectAuthAction.quota) {
          switch (await _directPeerRoom(server, parked, verdict)) {
            case DirectPeerRoom.room:
              break;
            case DirectPeerRoom.none:
              handOff = true;
              return;
            case DirectPeerRoom.moot:
              return;
          }
        }
      }
      await _reseedLocalAtSpot();
    }).catchError((Object e) async {
      // appLog, not castLog: no cast is involved, and the incident log this
      // fix came from was tagged [cast] with no cast in sight.
      appLog('[play] tunnel-reconnect resume failed: $e');
      // Count it HERE. _onPlaybackError's counter sits behind its
      // "one recovery at a time" early return, and every failure after the
      // first is produced BY a recovery holding that flag — so the counter
      // there oscillates 0↔1 and the ground-truth probe never fires. This
      // loop is the one that ran every 11s for the whole incident; it is
      // exactly the run of failures worth probing on.
      final pathVerified = await _noteTunnelLoadFailure(server);
      switch (healResumeFailureAction(
          pathVerified: pathVerified, failures: ++_healResumeFailures)) {
        case ResumeFailureAction.rearm:
          // Try again rather than leaving the player parked. Bounded by the
          // tunnelServes gate, the 10s per-server cooldown, the single
          // _tunnelHealRetry slot and the failure bound above, so a flapping
          // tunnel gets ~one attempt per 10-11s and a revived player fails
          // the idle guard and stops.
          _rearmTunnelHeal();
        case ResumeFailureAction.skipTrack:
          // The tunnel is fine (or has had its chances): this track will not
          // load through it, so it takes the ordinary skip walk — bounded by
          // the queue length, ending in the outage-vs-bad-source decision —
          // instead of being re-seeded forever.
          appLog('[play] tunnel fine, track still fails — skipping it '
              'instead of re-parking ($_healResumeFailures resumes failed); '
              'heal suspended until a track loads');
          _healResumeFailures = 0;
          _healSuspended = true;
          _skipPending = true;
          _switchChain = _switchChain
              .then((_) => _skipFailedTrack(e))
              .catchError((Object e2) =>
                  castLog('skip after a failed heal resume failed', error: e2))
              .whenComplete(() => _skipPending = false);
      }
    }).whenComplete(() {
      _recoveringPlayback = false;
      if (!handOff) return;
      // The path is fine and the peer has said no: the skip walk owns the
      // track, and the heal stays out of the walk (as after the probe's
      // own hand-off above).
      _healSuspended = true;
      _skipPending = true;
      _switchChain = _switchChain
          .then((_) => _skipFailedTrack(StateError('direct peer refused')))
          .catchError((Object e) =>
              castLog('skip after a refused heal resume failed', error: e))
          .whenComplete(() => _skipPending = false);
    });
  }

  // Check the parked state again once the blocking guard has had time to
  // clear (the cooldown runs 10s; recoveries always finish). Terminates: a
  // healed player fails the idle guard and a still-dead tunnel fails
  // tunnelServes, and neither of those re-arms.
  void _rearmTunnelHeal() {
    _tunnelHealRetry =
        Timer(const Duration(seconds: 11), _onTunnelReconnected);
  }

  // Heuristic: does this error look like a clearly bad/unplayable source (skip
  // now) vs something worth retrying (a network/transport blip)? Best-effort and
  // platform-limited: on Android ExoPlayer reports almost everything — INCLUDING
  // 404s — as a generic "(0) Source error" and doesn't forward the real cause to
  // Dart, so most failures fall through to "retry" (bounded by _kMaxHttpRetries).
  // The needles below mainly catch iOS/web, where the message is richer. The real
  // outage-vs-bad-source decision for the END state is made by hasConnectivity().
  static bool _isTransientNetworkError(Object error) {
    final s = error.toString().toLowerCase();
    // Clear "bad/unplayable source" signals → not transient (skip, don't retry).
    const badSource = [
      'response code: 4', // 4xx (404/403/401…)
      'unsupported', 'no suitable', 'decoder', 'unrecognized',
      'malformed', 'file not found', 'does not exist',
    ];
    for (final m in badSource) {
      if (s.contains(m)) return false;
    }
    // Everything else (network/transport, generic "Source error") → retry.
    return true;
  }

  // Re-seed the inherited customState with a typed CustomEvent default (it
  // carries the AutoDJ server). Deliberately shadows BaseAudioHandler.customState.
  @override
  // ignore: overridden_fields
  BehaviorSubject<dynamic> customState =
      BehaviorSubject<dynamic>.seeded(CustomEvent(null));

  // True only while a queue reorder is rewiring the backend's source list.
  // moveAudioSource emits transient currentIndex values, so re-deriving the
  // now-playing MediaItem from queue.value[currentIndex] mid-reorder briefly
  // resolves to the *moved* item and flashes its art / title / waveform. The
  // playing track never changes during a reorder, so we hold the last good
  // MediaItem instead.
  bool _reordering = false;
  // True only while _doSetEqEnabled rebuilds the local player; suppresses the
  // currentIndexStream Auto-DJ top-up during the re-emit's index replay.
  bool _rebuilding = false;
  // True while the launch restore's load is in flight. The queue is published
  // BEFORE the sources are seeded (restoreQueue has to, so a transport command
  // racing the restore sees the tracks), which leaves a window where the queue
  // is the restored one but the fresh player still reads index 0. Everything
  // that derives now-playing from those two would resolve to track 1 for that
  // window — the log, the notification, the lock screen, Android Auto — and
  // flash the wrong track on every open before snapping to the real spot.
  bool _restoring = false;

  // Last item id logged by the [play] track-change diagnostic, so repeated
  // currentIndex emits for the same track don't spam the log.
  String? _lastPlayLoggedId;

  @override
  Future<void> skipToQueueItem(int index) async {
    transport.note('skipToQueueItem');
    // Then default implementations of skipToNext and skipToPrevious provided by
    // the [QueueHandler] mixin will delegate to this method.
    // >= : an index equal to the length is off the end, not the last row.
    if (index < 0 || index >= queue.value.length) return;
    // Explicit navigation supersedes a failed-restore park -- without this a
    // stale spot would hijack the next re-seed back to the old track.
    _restoreSpot = null;
    _releasePark(); // explicit navigation supersedes a queue-end park too
    // Deliberately re-tapping a track that failed from disk is a request to
    // try it again, so don't let the one-attempt guard deny it.
    _localRetryKey = null;
    // A bare seek on an IDLE player is swallowed. just_audio's idle stub
    // records the index and broadcasts it — so it even looks like it worked in
    // the logs — but there is no platform player to move, and the next revive
    // re-reads the backend's own index and loads somewhere else entirely.
    // Seen in the car: three taps on the Android Auto queue, three silent
    // relocations back to track 1. Park the choice, then re-seed at it.
    if (identical(_backend, _localBackend) &&
        _backend.processingState == BackendProcessingState.idle &&
        queue.value.isNotEmpty) {
      // Parked even when a recovery is already running and we can't start our
      // own: that one finishes wherever it was headed, and this is what sends
      // the NEXT one to the track the user actually asked for.
      _restoreSpot = (index: index, position: Duration.zero);
      if (_recoveringPlayback) return;
      appLog('[play] track tapped on an idle player — '
          're-seeding at track ${index + 1}');
      _recoveringPlayback = true;
      _switchChain = _switchChain
          .then((_) => _reseedLocalAtSpot())
          .catchError(
              (Object e) => appLog('[play] tapped-track re-seed failed: $e'))
          .whenComplete(() => _recoveringPlayback = false);
      return _switchChain;
    }
    // This jumps to the beginning of the queue item at newIndex.
    _backend.seek(Duration.zero, index: index);
  }

  /// Reinstate a persisted queue at launch WITHOUT auto-playing: seed the queue
  /// + backend sources, park playback at [index]/[position] paused, and restore
  /// shuffle/repeat. Used by QueueStore.init() so the app reopens exactly where
  /// it left off. No-op for an empty list.
  Future<void> restoreQueue(List<MediaItem> items, int index, Duration position,
      {bool shuffle = false,
      AudioServiceRepeatMode repeat = AudioServiceRepeatMode.none}) async {
    if (items.isEmpty) return;
    // Wait for _init() to finish seeding the backend + applying EQ before our
    // own setSources(), so the two don't issue concurrent loads on the player
    // (which abort each other → "Loading interrupted", losing the restore).
    await _initialized.future;
    _intentionalStop = false;
    // Set BEFORE the queue is published, not inside the chained closure. The
    // publish is what wakes the queue listener and the now-playing derivation,
    // and at that instant the fresh player still reads index 0 — so the flag
    // has to already be up. It also closes the window a busy _switchChain
    // would otherwise open between the publish and the load. Cleared in the
    // closure's finally, which always runs: every link of the chain ends in a
    // catchError, so the chain always completes.
    _restoring = true;
    queue.add(items.toList());
    // Serialized on _switchChain: the re-seed paths (reload-on-play, tunnel
    // heal) chain their loads there, and an un-serialized restore load racing
    // one of them makes the two setSources abort each other ("Loading
    // interrupted"), losing the saved spot.
    final int i = index.clamp(0, items.length - 1);
    final done = _switchChain.then((_) async {
      try {
        // Whichever load is handed this spot checks it against the track's
        // real length once it has one (restoredAtTrackEnd): the one below,
        // or a later revive's when this one fails and parks it.
        _snapshotSpot = (index: i, position: position);
        try {
        // No play call after it: the restore deliberately opens PAUSED at the
        // saved spot rather than blasting audio on launch.
          await _loadAtSpot(_backend, items, (index: i, position: position));
        } catch (e) {
          // A dead-server cold start (offline, stale tunnel loopback) makes
          // the load throw AFTER the queue is published. _loadAtSpot has
          // parked the spot, so the revive paths re-seed THERE (not at
          // track 1) and the next snapshot save doesn't persist the loss.
          // Swallowed rather than rethrown because repeat/shuffle below are
          // player-level flags that still apply without sources.
          appLog('[queue] restore load failed: $e');
        }
        try {
          _repeatMode = repeat;
          // Guarded the same way setShuffleMode/setRepeatMode guard these
          // very calls: the backend can reject them outright when nothing is
          // loaded (a cold headless bind), which is precisely the state a
          // failed restore load leaves behind. Unguarded, the throw escapes
          // the closure and skips restoreQueue's closing emit/broadcast — and
          // since every broadcast during the load was suppressed,
          // playbackState keeps its boot queueIndex of null, so the next
          // snapshot save persists index 0 and the following launch opens on
          // track 1 at 0:00. The exact loss this series exists to prevent.
          await _backend.setRepeat(_backendRepeat(repeat));
          if (shuffle) await _backend.setShuffleEnabled(true);
        } catch (e) {
          appLog('[queue] restore repeat/shuffle failed: $e');
        }
      } finally {
        // finally around the WHOLE body: anything escaping either inner
        // catch would otherwise leave this latched and suppress every
        // now-playing update for the rest of the session. Cleared before the
        // emit/broadcast at the end of restoreQueue, which publishes the REAL
        // spot.
        _restoring = false;
      }
    });
    _switchChain = done.catchError((_) {});
    await done;
    _emitCurrentMediaItem();
    _broadcastState();
  }

  /// Whether a load that has just succeeded put the LAUNCH SNAPSHOT's spot at
  /// the END of its track, going by the length the player measured. Pure;
  /// unit-tested.
  ///
  /// The snapshot already drops a saved position at or past the end
  /// ([QueueStore.clampResumePositionMs]), but it can only judge one against
  /// a length it has. A position saved with none — the queue item carried no
  /// duration, and the player had not measured that track either — reaches
  /// the load as it was written. It happens: play a queue out, remove its
  /// last row, and the row left current is saved under the removed track's
  /// end, which a shorter file the server has no tags for is already past.
  ///
  /// The load then parks on the last sample: ready, paused, and one Play
  /// away from completing on the spot. On a queue's last track that Play
  /// ends the queue instead of starting anything, and only the one after it
  /// is heard.
  ///
  /// [snapshot] is the spot the snapshot named ([_snapshotSpot]) and [loaded]
  /// the one this load was given: only the snapshot's own spot is judged.
  /// The restore is not always what loads it. With the server out of reach
  /// at launch — a tunnel still dialling is enough — the restore's load
  /// fails, the spot is parked, and a retry, the tunnel coming up or the
  /// first Play loads it later. A spot the player really stood on (a stop,
  /// or a reload that failed, a moment before a track's end) is somewhere to
  /// resume and is left alone.
  ///
  /// The guard is the snapshot's own, so a track opens the same way whether
  /// or not its length was stored. False when the player has no length
  /// either (a transcode's stream has none): nothing to judge against.
  static bool restoredAtTrackEnd({
    required ({int index, Duration position}) loaded,
    required ({int index, Duration position})? snapshot,
    required Duration? duration,
  }) =>
      snapshot != null &&
      loaded == snapshot &&
      loaded.position.inMilliseconds > 0 &&
      QueueStore.clampResumePositionMs(
              loaded.position.inMilliseconds, duration?.inMilliseconds) ==
          0;

  // The spot the launch snapshot named, from the restore until a load
  // reaches ready. It is the one spot the session holds that no player has
  // stood on, so the one whose position can lie past the end of its track.
  // A load that can be handed it reads this BEFORE loading — reaching ready
  // clears it — and settles the spot afterwards ([_settleSnapshotSpot]).
  ({int index, Duration position})? _snapshotSpot;

  /// A load at [spot] has succeeded. When that was the snapshot's spot and
  /// the track turns out to end there, move to the track's start
  /// ([restoredAtTrackEnd]).
  ///
  /// Called by the load itself, before it lets anything play, and not from
  /// the ready listener: a play issued right behind the load would race the
  /// seek there, and at the end of a track the play wins by completing.
  Future<void> _settleSnapshotSpot(
      PlaybackBackend backend,
      int idx,
      ({int index, Duration position}) spot,
      ({int index, Duration position})? snapshot) async {
    if (!restoredAtTrackEnd(
        loaded: spot, snapshot: snapshot, duration: backend.duration)) {
      return;
    }
    appLog('[queue] restored at the end of track ${idx + 1} — '
        'it opens at its start');
    try {
      await backend.seek(Duration.zero, index: idx);
    } catch (e) {
      appLog('[queue] restore rewind failed: $e');
    }
  }

  // Where a FAILED launch-restore load intended to park. Read by the revive
  // paths (they load here instead of the never-loaded backend's index 0) and
  // by QueueStore's snapshot writes (so a background save can't persist
  // track-1/0:00 over the real spot); cleared once any track reaches ready —
  // from then on the live player state is the truth.
  ({int index, Duration position})? _restoreSpot;
  ({int index, Duration position})? get restoreSpot => _restoreSpot;

  // The spot a revive/retry should load at: the parked failed-restore spot
  // when one is pending, else the backend's live position. The parked index
  // is clamped against the LIVE queue -- edits while parked can shrink it,
  // and an out-of-range index kills a reload (media3 throws on setSources'
  // initialIndex and silently no-ops the seek).
  ({int index, Duration position}) _reviveSpot() {
    final s = _restoreSpot;
    if (s == null) {
      return (
        index: _localBackend.currentIndex ?? 0,
        position: _localBackend.position
      );
    }
    final n = queue.value.length;
    return n == 0 ? s : (index: s.index.clamp(0, n - 1), position: s.position);
  }

  // The track the queue ENDED on ([_trackKey]), from the stop that followed
  // until the player is given a position again: a load reaching ready, or a
  // scrub. Null the rest of the time.
  //
  // While it is set, the position the idle player reports is not somewhere
  // to resume. just_audio hands its idle stand-in the spot the platform
  // player was released at, and for a queue that played out that is the last
  // track's final sample — see [shouldReviveFromTop] for what a re-seed does
  // with it. The track rather than a flag, because the row can be removed, or
  // the queue cleared and refilled, before the next Play, and the same stale
  // position then sits under a track it never belonged to.
  String? _finishedTrack;

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    queue.add(queue.value..add(mediaItem));
    // The backend extracts the playable URI (local backend) or builds renderer
    // metadata (cast backend) from the item itself. The offline-file detection
    // (File.existsSync + Uri.file) from the server-download-folder PR now lives
    // in LocalPlaybackBackend._uriFor.
    await _backend.addSource(mediaItem);
    appLog('[queue] add: ${mediaItem.title} (now ${queue.value.length})');
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    if (mediaItems.isEmpty) return;
    final wasEmpty = queue.value.isEmpty;
    // ONE queue emission + ONE backend call for the whole batch. Appending a
    // big folder per-item re-ran every whole-queue listener (iroh scan,
    // keep-queue-offline sweep) and a platform round-trip per track — O(N²)
    // work that stalled the UI on large "Add all"s.
    queue.add(queue.value..addAll(mediaItems));
    // Batch-adding onto an empty IDLE player: park now-playing on track 1
    // before the backend append. just_audio's idle stub emits an index for
    // the appended batch — observed landing on the LAST row — and without a
    // parked spot the now-playing surfaces and a later play()'s re-seed both
    // follow it ("added a folder, and it opened on the last song"). The spot
    // is the existing failed-restore machinery: read first by
    // _emitCurrentMediaItem and _reviveSpot, overwritten by an explicit tap
    // (skipToQueueItem's idle park — playFromHere's jump still wins), and
    // cleared when a real load reaches ready. Parked BEFORE addSources so
    // the stub emission's own now-playing emit already reads it.
    if (wasEmpty &&
        _backend.processingState == BackendProcessingState.idle) {
      _restoreSpot = (index: 0, position: Duration.zero);
    }
    await _backend.addSources(mediaItems);
    appLog('[queue] add ${mediaItems.length} tracks '
        '(now ${queue.value.length})');
  }

  // The user's intended play state, tracked across just_audio errors (which flip
  // the backend's `playing` to false). A recovery uses this so a launch-time
  // re-seed resumes PAUSED rather than autoplaying on open.
  bool _playIntent = false;

  // ── Auto DJ across a tunnel outage ──
  // A pick was due but the tunnel wasn't serving (or the POST failed); the
  // tunnel's connected edge retries it (_onTunnelReconnected).
  bool _djPickPending = false;
  // One "random-songs failed" line per outage — the player's index
  // re-emissions re-fire the pick every ~30s.
  bool _djFailLogged = false;
  int _deferredPickFailures = 0;
  // The queue ended while a pick was pending: paused with the play intent
  // kept, so the retried pick resumes playback (see queueEndAction).
  bool _parkedForDJ = false;
  Timer? _parkTimer;
  // When an audio-focus interruption began (see the session listener).
  DateTime? _interruptedAt;
  // When the audio output went away (becoming-noisy: the car's Bluetooth, a
  // headset); null once a new output appears or the user plays in the app.
  // Gates media-button toggles — see click().
  DateTime? _outputLostAt;
  BackendProcessingState? _lastLoggedProcState;
  DateTime? _bufferingSince;

  bool get _recentlyInterrupted {
    final t = _interruptedAt;
    return t != null &&
        DateTime.now().difference(t) < TunnelTiming.interruptionWindow;
  }

  void _clearDeferredPick() {
    _djPickPending = false;
    _djFailLogged = false;
    _deferredPickFailures = 0;
    _releasePark();
  }

  /// Leave the queue-end park without forgetting that a pick is owed: the
  /// user moved on (play/pause/skip/seek), so the tunnel's return must
  /// neither re-seek them nor stop them thirty minutes later.
  void _releasePark() {
    _parkedForDJ = false;
    _parkTimer?.cancel();
    _parkTimer = null;
  }

  /// True while the park is real: the local player is still sitting at the
  /// completed last row, paused. Anything else means the user moved on.
  bool get _stillParked =>
      _parkedForDJ &&
      identical(_backend, _localBackend) &&
      _localBackend.processingState == BackendProcessingState.completed &&
      !_localBackend.playing;

  /// The queue ended while an Auto DJ pick is owed to a tunnel outage: hold
  /// the spot instead of stopping. The BACKEND's pause, not the handler's —
  /// _playIntent must survive so the retried pick can resume — and the
  /// foreground service stays up (bounded by parkMax). stop() used to run
  /// here unconditionally, which set _intentionalStop and made healAction
  /// discard every later tunnel-back edge: an outage-drained queue looked
  /// exactly like the user pressing stop.
  void _parkForDeferredPick() {
    _parkedForDJ = true;
    unawaited(_localBackend.pause());
    _broadcastState();
    _parkTimer?.cancel();
    _parkTimer = Timer(TunnelTiming.parkMax, () {
      _parkTimer = null;
      // Only a park that is still real gets stopped: if the user queued an
      // album and pressed play meanwhile, this must not cut it off.
      if (!_stillParked) {
        _parkedForDJ = false;
        return;
      }
      appLog('[play] parked ${TunnelTiming.parkMax.inMinutes} min waiting '
          'for the tunnel — stopping');
      _parkedForDJ = false;
      stop();
    });
    unawaited(ServerManager()
        .ensureTunnels(verify: true, reason: 'queue-end-park'));
  }

  /// The queue ended with a pick owed although the tunnel IS serving (the
  /// earlier POST failed transiently, or an in-place reconnect has since
  /// healed): try once, now, and stop as before if it fails — never a silent
  /// park with nothing scheduled. The park flag makes the landing pick resume.
  void _retryPickAtQueueEnd() {
    _parkedForDJ = true;
    unawaited(_localBackend.pause());
    _broadcastState();
    unawaited(() async {
      await autoDJ();
      if (!_djPickPending) return; // landed; the park-derived resume ran
      // The tunnel SAID it was serving and the pick still failed. On real
      // cellular the native status can read connected for ~70s after the
      // link dies (Galaxy S25, airplane mode), so this is most often the
      // dead-but-connected window, not a broken server: park (bounded) and
      // ask the tunnel for ground truth — a failed probe rebuilds it, and the
      // resulting connected edge retries the pick and resumes.
      appLog('[dj] queue-end retry failed — parking and re-checking the tunnel');
      _parkForDeferredPick();
      final dj = autoDJServer;
      if (dj != null) unawaited(ServerManager().reverifyTunnel(dj));
    }());
  }

  /// Whether a currentIndex emission landing on the LAST queue row should
  /// fire the Auto-DJ top-up.
  ///
  /// The index alone is not enough: an IDLE player's stub emissions also land
  /// there without any playback behind them — a batch "Add all" onto a
  /// fresh-boot player emitted the last index, the DJ appended a pick, the
  /// idle player emitted the NEW last index, and the loop appended eleven
  /// picks in nine seconds while the now-playing surface flashed through
  /// them (the "skipping every few seconds" report). Requiring a real
  /// playback session keeps both legitimate triggers: advancing INTO the
  /// last track (ready), and the queue finishing on it (completed — the
  /// infinite-play top-up). The idle arm/empty-queue starts don't come
  /// through here at all; setAutoDJ drives those explicitly.
  ///
  /// [inFailureWalk] suppresses the top-up while the failed-track skip walk
  /// is live (_skipPending, or a non-zero skip budget). Without it the walk
  /// and the DJ feed each other unboundedly when streams are broken but the
  /// random-songs API is fine (transcode down, media mount lost): each skip
  /// lands on the last row with a non-idle (loading) state → pick appended →
  /// pick fails → skip — and BOTH of the walk's exits chase the growing
  /// queue: `_failedSkips >= q.length` never catches up (each cycle
  /// increments both by one), and seekToNext never reaches the end because a
  /// fresh pick is always ahead. Starved of picks, the walk terminates
  /// through its own end-of-queue outage-vs-bad-source logic, and any track
  /// reaching `ready` clears the budget and re-enables the DJ.
  ///
  /// [clearing] suppresses it while a queue clear is under way: the clear
  /// has opened the new lane, but the old rows wait in the queue until the
  /// player has stopped, and a top-up then would open the new lane on the
  /// row being thrown away ([_clearingQueue]). Pure; unit-tested.
  static bool shouldTopUpAutoDJ({
    required int? index,
    required int queueLength,
    required BackendProcessingState state,
    required bool inFailureWalk,
    required bool clearing,
  }) =>
      index != null &&
      queueLength > 0 &&
      index == queueLength - 1 &&
      state != BackendProcessingState.idle &&
      !inFailureWalk &&
      !clearing;

  /// What the queue's end does. Park only when a pick is actually owed to a
  /// tunnel outage AND playback is wanted AND this backend/server pair can be
  /// healed by the tunnel coming back: the local player with an iroh Auto DJ
  /// server. A cast session or an HTTP DJ server has no tunnel edge to wait
  /// for, so parking would be a silent 30-minute wait — strictly worse than
  /// today's stop. Pure; unit-tested.
  ///
  /// With the tunnel already serving there is no edge to wait for, so the
  /// pick is retried on the spot ([QueueEndAction.retryPick]) — unless one is
  /// already in flight, which lands on its own and resumes from the park.
  static QueueEndAction queueEndAction({
    required bool onLocalBackend,
    required bool isIrohDJ,
    required bool djPickPending,
    required bool playIntent,
    required bool tunnelServes,
    required bool pickInFlight,
  }) {
    // A pick still in flight is owed too: it lands with the park-derived
    // resume, or fails and sets the pending flag for the tunnel's edge. On
    // a Galaxy the last track ended 3s after its top-up POST went out.
    final owed = djPickPending || pickInFlight;
    if (!(onLocalBackend && isIrohDJ && owed && playIntent)) {
      return QueueEndAction.stop;
    }
    if (pickInFlight) return QueueEndAction.park;
    if (tunnelServes) return QueueEndAction.retryPick;
    return QueueEndAction.park;
  }

  /// Whether an Auto DJ pick should wait for the tunnel instead of POSTing
  /// at a loopback that cannot answer. Pure; unit-tested.
  static bool shouldDeferDJPick(
          {required bool isIroh, required bool tunnelServes}) =>
      isIroh && !tunnelServes;

  /// Whether the tunnel-back heal should retry a deferred pick. Pure;
  /// unit-tested.
  static bool shouldRetryDeferredPick({
    required bool pending,
    required bool tunnelServes,
    required bool onLocalBackend,
    required bool intentionalStop,
    required int failures,
  }) =>
      pending &&
      tunnelServes &&
      onLocalBackend &&
      !intentionalStop &&
      failures < kMaxDeferredPickFailures;

  /// A deferred pick that keeps failing against a serving tunnel is the
  /// server's problem, not the path's; stop retrying after this many.
  static const int kMaxDeferredPickFailures = 5;

  /// After an output loss, how long a media-button toggle that would start
  /// playback is treated as the old output's late PAUSE rather than the
  /// user's request. Head units keep their remote-control link up for a few
  /// seconds after the audio link drops (11s in the drive log).
  static const Duration kOutputLostToggleWindow = Duration(seconds: 30);

  /// Whether play() must re-seed the local player instead of issuing a bare
  /// backend.play(): just_audio parked idle (a playback error tears the
  /// platform player down) with tracks still queued, so a bare play() would
  /// silently no-op. Never while a recovery is in flight — it re-seeds itself
  /// and reads the play intent when it does. Pure; unit-tested.
  static bool shouldReseedOnPlay({
    required bool onLocalBackend,
    required BackendProcessingState processingState,
    required bool queueEmpty,
    required bool recovering,
  }) =>
      onLocalBackend &&
      processingState == BackendProcessingState.idle &&
      !queueEmpty &&
      !recovering;

  /// Whether a re-seed of the idle local player starts its track from the
  /// top instead of at the position the player kept.
  ///
  /// When the queue plays out the handler stops, and the idle player is left
  /// on the track that finished, holding that track's END as its position.
  /// A re-seed loads at the spot the player reports, so pressing Play after
  /// the last song loaded the last instant of it: ready, completed in the
  /// same breath, stopped again, and nothing to hear (emulator, 2026-11-16).
  /// The Auto DJ park in play() already says what was meant — "replay the
  /// last track from the top" — and this is that rule for the queue end that
  /// stops.
  ///
  /// It is deliberately no wider than the dead end. Wherever another track
  /// comes after the finished one, loading at its end is what moves playback
  /// on, and each of these was seen doing so before this existed:
  ///
  ///  * tracks queued after the end: Play goes straight to the first of them
  ///    rather than through the finished song again;
  ///  * shuffle: every load deals a fresh order with the loaded row first, so
  ///    the rest of the queue follows in a new shuffle;
  ///  * repeat all wraps to the first row, and repeat one starts the same
  ///    track over, which is the replay by another road.
  ///
  /// So neither mode is special-cased here; they decide whether anything
  /// follows, and only a queue with nothing after its finished track is
  /// started from the top.
  ///
  /// [onFinishedTrack] is false when the row the player points at is no
  /// longer the track that finished — that row was removed, or the queue was
  /// cleared and refilled. The position kept is then another track's end and
  /// means nothing here: tapping a song after clearing a finished queue loaded
  /// the new song AT the old one's end and stopped just the same. From the
  /// top, whatever follows. (Both edits now zero the kept position
  /// themselves — [removalDropsKeptPosition], the clear — so that every
  /// reader sees it; this is the net under them.)
  ///
  /// [spotParked] always wins. A parked spot ([_restoreSpot]) is a place
  /// someone chose — a tapped row, a failed restore's saved position — and
  /// [_reviveSpot] already returns it over the player's own. (A saved
  /// position that proves to be the END of its track once loaded is the
  /// load's to settle: [restoredAtTrackEnd].) Pure; unit-tested.
  static bool shouldReviveFromTop({
    required bool queueFinished,
    required bool onFinishedTrack,
    required bool spotParked,
    required int index,
    required int queueLength,
    required bool shuffle,
    required BackendRepeat repeat,
  }) {
    if (!queueFinished || spotParked) return false;
    if (!onFinishedTrack) return true;
    final anotherFollows = repeat != BackendRepeat.off ||
        (queueLength > 1 && (shuffle || index < queueLength - 1));
    return !anotherFollows;
  }

  /// A cold boot's play must keep the process alive while the restore runs.
  ///
  /// The service boots headless — a widget tap, a Bluetooth key, the
  /// media-resumption chip, Android Auto — with no activity, and audio_service
  /// takes the service into the foreground (startForeground plus its wake
  /// lock) only when `playing` flips to true. Until then the process is
  /// cached, and One UI freezes a cached process TEN seconds after it starts
  /// (Galaxy S25, 2026-09-21: `am_freeze` at +10 s, thawed nine minutes later
  /// by a tap on the widget; the tunnel had dialed in 0.3 s, but nothing ran
  /// to see it). A restore that dials a Quick Connect tunnel first can take
  /// longer than that, and the wait below allows a minute. So: flip
  /// `playing` now — the transition the real play makes seconds later — which
  /// also lands inside the short window in which Android lets a background
  /// app start a foreground service after a user-driven event.
  ///
  /// The processing state is left alone on purpose: audio_service stops the
  /// service on a transition INTO idle, so a "loading" that fell back to idle
  /// would tear down exactly what this is meant to keep. Android only: iOS
  /// has no freezer, and its Now Playing surfaces would show a false
  /// "playing" for the wait.
  void _holdForRestore() {
    final held =
        restoreHoldState(playbackState.value, isAndroid: Platform.isAndroid);
    if (held == null) return;
    appLog('[play] holding the service in the foreground for the restore');
    playbackState.add(held);
  }

  /// After the wait, the truth again: the backend's state. With
  /// androidStopForegroundOnPause off the service stays in the foreground on
  /// the way back to paused, so a restore that never settled leaves a paused
  /// notification, not a stuck "playing" one. A restore still landing
  /// broadcasts for itself once it has.
  void _releaseRestoreHold() {
    if (_rebuilding || _restoring) return;
    _broadcastState();
  }

  /// Pure: the state to publish while a play waits for the queue restore,
  /// or null when nothing should change (not Android, or already playing).
  static PlaybackState? restoreHoldState(PlaybackState current,
      {required bool isAndroid}) {
    if (!isAndroid || current.playing) return null;
    return current.copyWith(playing: true);
  }

  // Completes when the launch queue restore has settled — restored, nothing
  // to restore (feature off / no snapshot / empty), or failed. Signalled by
  // QueueStore.init(); play() awaits it on a cold boot so a transport command
  // that beats the restore doesn't no-op on an empty player.
  final Completer<void> _restoreSettled = Completer<void>();
  Future<void> get queueRestoreSettled => _restoreSettled.future;
  void markQueueRestoreSettled() {
    if (!_restoreSettled.isCompleted) _restoreSettled.complete();
  }

  /// Bring Auto DJ back up on [server] after a restart — armed only.
  ///
  /// Deliberately NOT the setAutoDJ custom action: that one fills an empty
  /// queue and calls autoDJ(autoPlay: true), so restoring through it would
  /// start playing music every time the app is opened. "Remembered as on"
  /// means the toggle is on; the DJ then engages by itself at the next
  /// queue-end top-up, exactly as it would have before the restart.
  ///
  /// A no-op once anything has already armed the DJ, so a user toggle that
  /// beats the launch restore wins.
  void restoreAutoDJ(Server server) {
    if (autoDJServer != null) return;
    autoDJServer = server;
    // The lane's seeds as a reset would start them, though nothing else is
    // reset here, in the stored mode (main loads the mode before it calls
    // this). Main has just taken the stored rows back in (loadPinnedSeeds).
    // In Drift the rows the user pinned stay and so do the unpinned skips,
    // the picks go, and the first pick blends in the queue's playing row
    // ([_lanePicked] is cleared below). In Stay close the load's frozen set
    // stays as it is, every row it shows. Rows held aside on the Seeds page
    // join at the first pick, as at any start, and so do the ones added
    // until then. A Stay close lane looks for its one song again.
    _seeds = _carriedSeeds();
    _lanePicked = false;
    _laneBlendKey = null;
    _laneBlendedSong = null;
    _laneSkippedBlend = null;
    _stayCloseAnchored = false;
    _stayCloseAdmitted = false;
    _publishSeeds();
    // A multi-server session's fan-out servers are tunnel targets from the
    // moment the DJ is armed — this path arms too, so it nudges too (the
    // mode's own edge fired while nothing was armed yet).
    _reconcileFanOutTunnels('dj-restore');
    customState.add(CustomEvent(autoDJServer));
    appLog('[autodj] restored on ${server.localname}');
  }

  // Cold-boot resume race: a PLAY from the media-resumption chip, Bluetooth,
  // or Android Auto can reach a headless-booted service before QueueStore has
  // restored the saved queue — a bare play on an empty player silently no-ops
  // (the reseed net needs a non-empty queue). Trigger the restore ourselves
  // (both calls are idempotent; on a headless boot no widget may ever run
  // main.dart's initState trigger) and wait for it to settle. Bounded: the
  // settle can legitimately take tens of seconds (loadServerList dials an
  // iroh tunnel first), but a wedged startup must not hold the transport
  // forever.
  Future<void> _awaitQueueRestore() {
    unawaited(ServerManager()
        .ensureLoaded()
        .then((_) => QueueStore().init())
        .catchError((Object e) => appLog('[play] restore trigger failed: $e')));
    return queueRestoreSettled.timeout(const Duration(seconds: 60),
        onTimeout: () =>
            appLog('[play] queue restore never settled — playing as-is'));
  }

  @override
  Future<void> play() async {
    transport.note('play');
    appLog('[play] play');
    _playIntent = true;
    _intentionalStop = false;
    _interruptedAt = null; // the user wants audio; an old interruption is moot
    _outputLostAt = null; // …and wherever it comes out is their choice now
    if (_parkedForDJ) {
      // The user pressed play on a parked queue end: leave the park (a pick
      // landing later appends without hijacking them) and replay the last
      // track from the top, which is what the old completed→stop→play did.
      final wasParked = _stillParked;
      _releasePark();
      if (wasParked) {
        final idx = _localBackend.currentIndex;
        if (idx != null) await _localBackend.seek(Duration.zero, index: idx);
      }
    }
    if (queue.value.isEmpty && !_restoreSettled.isCompleted) {
      _holdForRestore();
      try {
        await _awaitQueueRestore();
      } finally {
        _releaseRestoreHold();
      }
      // The wait can run tens of seconds — a pause/stop that arrived during
      // it must win, not be overridden by this stale play when the restored
      // queue comes up. (pause() and stop() both clear _playIntent.)
      if (!_playIntent) return;
      // The restore parks paused at the saved spot; fall through so the bare
      // play (or the reseed net, if the restore load failed) resumes it.
    }
    if (shouldReseedOnPlay(
        onLocalBackend: identical(_backend, _localBackend),
        processingState: _backend.processingState,
        queueEmpty: queue.value.isEmpty,
        recovering: _recoveringPlayback)) {
      appLog('[play] play on an idle player — re-seeding sources');
      _recoveringPlayback = true;
      _switchChain = _switchChain
          .then((_) => _reseedLocalAtSpot())
          .catchError((Object e) => castLog('re-seed on play failed', error: e))
          .whenComplete(() => _recoveringPlayback = false);
      return _switchChain;
    }
    return _backend.play();
  }

  @override
  Future<void> pause() {
    transport.note('pause');
    appLog('[play] pause');
    _playIntent = false;
    _releasePark(); // their intent wins; a landing pick appends only
    return _backend.pause();
  }

  /// Media buttons. audio_service folds every external PLAY / PAUSE /
  /// PLAY_PAUSE / HEADSETHOOK key into this one toggle (only its own
  /// notification buttons carry an explicit play or pause), so a head unit's
  /// explicit PAUSE on ignition-off reaches us as "toggle". That PAUSE rides
  /// the remote-control link, which outlives the audio link by seconds; when
  /// it lands after the audio drop has already paused us, the toggle used to
  /// un-pause onto the phone's own speaker (drive log 2026-08-31: output
  /// disconnected 19:23:38, play 19:23:49). Inside the window after an output
  /// loss, a toggle that would START playback is ignored; a new output device
  /// or the user's own play in the app ends the window early. Playing → pause
  /// is always honoured.
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button != MediaButton.media) return super.click(button);
    final lost = _outputLostAt;
    final sinceLost = lost == null ? null : DateTime.now().difference(lost);
    switch (mediaToggleAction(
        playing: playbackState.valueOrNull?.playing ?? false,
        sinceOutputLost: sinceLost)) {
      case MediaToggleAction.pause:
        appLog('[audio] media button → pause');
        await pause();
      case MediaToggleAction.play:
        appLog('[audio] media button → play');
        await play();
      case MediaToggleAction.ignore:
        appLog('[audio] media button toggle ignored — output lost '
            '${sinceLost!.inSeconds}s ago (a late PAUSE from the old output)');
    }
  }

  /// Pure: what a media-button toggle does. [sinceOutputLost] is null when no
  /// output has been lost, or a new one has appeared since.
  static MediaToggleAction mediaToggleAction({
    required bool playing,
    required Duration? sinceOutputLost,
  }) {
    if (playing) return MediaToggleAction.pause;
    if (sinceOutputLost != null && sinceOutputLost < kOutputLostToggleWindow) {
      return MediaToggleAction.ignore;
    }
    return MediaToggleAction.play;
  }

  // Every Next, numbered; the newest one whose seek is still out (null once
  // it is back), and when it was pressed. A Next pressed while one is out
  // lands on a row the player hasn't left yet, or on one barely begun (a
  // cast loads the next song over the network, its position still the last
  // song's), so it is not judged again; and the last seek of the burst to
  // come back starts the one re-roll the burst asked for. Bounded by
  // [_skipBurstWindow], so a seek that never comes back can't leave every
  // later Next unjudged.
  int _skipSeq = 0;
  int? _skipSeekOut;
  DateTime? _skipSeekAt;
  static const Duration _skipBurstWindow = Duration(seconds: 10);

  // A learned quick skip asked for a re-roll, which the burst's last seek
  // to come back starts ([_afterSkipSeek]). Lane state.
  bool _rerollOnSeek = false;

  // The stale picks the owed re-roll is there to replace, by song
  // ([rerollStaleKeys]): the DJ rows after the row the learned skip lands
  // on, named when the skip is learned and again from the row it did land
  // on as the re-roll starts ([_nameStalePicks]). A re-roll that lands after
  // the user went back to an earlier row takes out only these, never the
  // rows after the one playing then, which are songs already heard. Null
  // when no skip named them; the re-roll then takes the nearest rows it
  // may. Lane state, and let go when the re-roll is settled.
  Set<String>? _rerollStale;

  /// Names the stale picks the owed re-roll replaces ([_rerollStale]): the
  /// DJ rows it may drop ([rerollDroppable]) after row [landing], the one
  /// the learned skip lands on.
  void _nameStalePicks(int landing) {
    final q = queue.value;
    _rerollStale = rerollStaleKeys(q, _rerollDroppable(q, landing));
  }

  @override
  Future<void> skipToNext() async {
    transport.note('skipToNext');
    _restoreSpot = null; // user navigation supersedes a failed-restore park
    _releasePark();
    // A quick skip is judged now, before the seek: once the player has
    // moved, its position, its duration and the play tracker's session all
    // belong to the next song.
    final now = DateTime.now();
    final since = _skipSeekAt;
    final inBurst = _skipSeekOut != null &&
        since != null &&
        now.difference(since) < _skipBurstWindow;
    final skip = inBurst ? null : _judgeQuickSkip();
    final seq = ++_skipSeq;
    _skipSeekOut = seq;
    _skipSeekAt = now;
    final backend = _backend;
    final before = backend.currentIndex;
    // Not awaited, as before: a cast loads the next song over the network,
    // and the buttons, the lock screen and the car return at once.
    unawaited(() async {
      try {
        await backend.seekToNext();
      } catch (e) {
        appLog('[play] next failed: $e');
      }
      if (_skipSeekOut == seq) _skipSeekOut = null;
      await _afterSkipSeek(skip, backend: backend, before: before);
    }());
  }

  /// The Next about to happen, judged before its seek. A quick skip of a DJ
  /// pick ([isQuickSkip]: heard for a second or more but short of a play,
  /// and the Next moves to another row) while the DJ is on in Drift changes
  /// the seeds: the song leaves More like, unless the user pinned it there,
  /// and with Learn from skips on (sonic similarity on, and a server in
  /// scope that takes negatives) it joins Less like
  /// ([AutoDjSeeds.quickSkip]). Stay close changes nothing, since both lists
  /// stand frozen.
  ///
  /// The song this lane's start blended into More like ([_laneBlendedSong])
  /// is, as the user's own row, no DJ pick, but a quick skip of it takes it
  /// out of More like all the same while More like holds it unpinned.
  /// Nothing is learned from it, Learn from skips or not, and the lane's
  /// picks pass over it from then on ([_laneSkippedBlend]). A DJ pick the
  /// start blended in keeps the rule above ([quickSkipsBlend]).
  ///
  /// The skip is LEARNED when that changed the negatives a server the next
  /// pick may ask would be sent, and the Next moves forward through the
  /// queue ([skipMovesForward]). Every pick queued ahead, and any still out,
  /// was chosen without the new negative, so [_djQueueGen] moves on and
  /// they are re-rolled. That happens here, before the seek, so a top-up the
  /// seek's own index emission fires already carries the negative and the
  /// new generation. Under shuffle, or on a wrap from the last row, the
  /// lists still change but nothing is re-rolled; a skip that is not
  /// learned leaves the queue as it is.
  ///
  /// Heard time is the play tracker's, which leaves seeks and pauses out,
  /// when its open session is this row's; else the player's position, since
  /// the tracker starts only with the app's window and a car or a headset
  /// can skip before that. The duration is the session's, else the
  /// player's, else the row's. Null when the seeds hear nothing of it.
  _QuickSkip? _judgeQuickSkip() {
    final mgr = AutoDJManager();
    if (autoDJServer == null ||
        mgr.sonicAnchorMode != SonicAnchorMode.rolling) {
      return null;
    }
    final cur = _backend.currentIndex;
    final item = _itemAt(cur);
    if (cur == null || item == null) return null;
    final session = PlayTracker().openSession;
    final own = session != null && session.key == _trackKey(item);
    final heardMs = own ? session.playedMs : _backend.position.inMilliseconds;
    final durationMs = (own ? session.track.durationMs : null) ??
        _backend.duration?.inMilliseconds ??
        item.duration?.inMilliseconds;
    final djPick = item.extras?['djPick'] == true;
    final song = trackFactsFor(item);
    final key = seedKey(song.server, song.path);
    final blended = quickSkipsBlend(
        key: key,
        blended: _laneBlendedSong,
        isDjPick: djPick,
        unpinnedInMoreLike:
            _seeds.moreLike.any((s) => s.key == key && !s.pinned));
    if (!isQuickSkip(
        djPick: djPick || blended,
        heardMs: heardMs,
        durationMs: durationMs,
        hasNext: _backend.hasNext)) {
      return null;
    }
    // A Less like row whose time ran out goes first, so that its going is
    // not taken for this skip's doing.
    _pruneSeeds();
    final sentBefore = _negativesInScope();
    // A re-skip of a Less like song whose vector the other servers were
    // already being sent: its vector coming back is no news to them.
    final vectorWasSent = _vectorSentElsewhere(key);
    final learn = !blended &&
        mgr.learnFromSkips &&
        mgr.sonicSimilarityEnabled &&
        seedsTakeNegatives;
    final next = _seeds.quickSkip(song, learn: learn, now: DateTime.now());
    if (!identical(next, _seeds)) {
      _seeds = next;
      _publishSeeds();
    }
    // The blended song out of More like: no seed, and never served, so the
    // lane's picks pass over it from here on.
    final blendLeft = blended && !_seeds.has(SeedList.moreLike, key);
    if (blendLeft) _laneSkippedBlend = song;
    final forward = skipMovesForward(
        index: cur,
        queueLength: queue.value.length,
        shuffle: _backend.shuffleEnabled);
    final learned = forward && _negativesInScope() != sentBefore;
    if (learned) {
      _djQueueGen++;
      // A forward Next lands on the next row: the picks after it are the
      // ones chosen without this negative.
      _nameStalePicks(cur + 1);
    }
    // The other servers of a session across several take the song as its
    // vector, which a new row doesn't have yet: asked of the song's own
    // server now, while the seek runs.
    final joined = learn && _seeds.has(SeedList.lessLike, key);
    final vectors =
        joined && mgr.multiServerEnabled ? _ensureNegativeVectors() : null;
    appLog('[dj] quick skip after ${heardMs ~/ 1000}s: ${item.title}'
        '${blendLeft ? ' — the blended song leaves More like' : ''}'
        '${joined ? ' — less like it' : ''}'
        '${learned ? ', re-rolling the picks ahead' : ''}');
    return (
      key: key,
      epoch: _djSessionEpoch,
      forward: forward,
      learned: learned,
      vectors: vectors,
      vectorWasSent: vectorWasSent,
    );
  }

  /// A Next's seek is back: [backend] moved on from row [before]. A quick
  /// skip ([skip]) whose song joined Less like in a session across several
  /// servers waits a few seconds for its vector, so the re-roll carries the
  /// song to the servers that don't hold it; a skip that changed nothing
  /// only because the song's own server takes no negatives is learned once
  /// that vector reaches another server that does.
  ///
  /// The re-roll a learned skip asked for then starts, from the last seek of
  /// the burst to come back, so the pick reads the row the burst ended on
  /// for its tempo and key windows and its Drift fallback, not the rejected
  /// one. Only when that seek moved forward, and while the re-roll is still
  /// owed: a pick already out takes it over (autoDJ() runs once more when
  /// that pick is done), and a lane started since owes nothing. A skip that
  /// was not learned starts nothing.
  Future<void> _afterSkipSeek(_QuickSkip? skip,
      {required PlaybackBackend backend, required int? before}) async {
    var learned = skip?.learned ?? false;
    final vectors = skip?.vectors;
    if (skip != null && vectors != null) {
      await vectors.timeout(const Duration(seconds: 3), onTimeout: () {});
      if (learnedOnceVectorLands(
          learned: learned,
          forward: skip.forward,
          sameLane: skip.epoch == _djSessionEpoch,
          sentBefore: skip.vectorWasSent,
          sentNow: _vectorSentElsewhere(skip.key))) {
        learned = true;
        _djQueueGen++;
        if (before != null) _nameStalePicks(before + 1);
        appLog('[dj] quick skip learned once its vector came back — '
            're-rolling the picks ahead');
      }
    }
    if (learned && skip?.epoch == _djSessionEpoch) _rerollOnSeek = true;
    if (_skipSeekOut != null || !_rerollOnSeek) return;
    _rerollOnSeek = false;
    final moved = identical(_backend, backend) &&
        (backend.currentIndex ?? -1) > (before ?? -1);
    if (!moved || autoDJServer == null || _rerolledGen >= _djQueueGen) return;
    // The row the seek landed on is the one playing now: a DJ pick of this
    // lane joins More like before the pick reads the seeds, as it would at
    // the index listener's top-up, whichever of the two the player
    // delivered first. Once per row, so the listener's turn adds nothing.
    if (!_reordering && !_rebuilding && !_restoring) {
      _seedPushOnPlay(backend.currentIndex);
    }
    // The picks it replaces, named again while the row the burst ended on
    // is the one playing: it may land after the user has gone back to rows
    // already heard, and those are not its to take. A pick already out that
    // takes the re-roll over replaces these too, and a later learned skip
    // names its own.
    final landed = backend.currentIndex;
    if (landed != null) _nameStalePicks(landed);
    unawaited(autoDJ());
  }

  /// The Less like negatives the next pick would send, as one comparable
  /// value ([negativesSnapshot], which leaves their order out, as the
  /// servers do): for each server it would send them to
  /// ([_negativeTargets]), its own songs as paths and, in a session across
  /// several servers, the other servers' songs as their vectors in the model
  /// the session's seed was last in ([_fanOutSeedModel]). Empty while sonic
  /// similarity is off, since no negative goes out then. A quick skip that
  /// changes it is a learned one.
  String _negativesInScope() {
    final mgr = AutoDJManager();
    if (!mgr.sonicSimilarityEnabled) return '';
    final model = mgr.multiServerEnabled ? _fanOutSeedModel : null;
    return negativesSnapshot({
      for (final s in _negativeTargets())
        s.localname: _seeds.negativesFor(s.localname, modelId: model),
    });
  }

  /// The servers the next pick would send Less like negatives to
  /// ([negativeTargets]): the DJ's own, and in a session across several the
  /// servers it may ask ([multiServerCandidates]), each when it takes them.
  /// Not every server of the session: one that sits every pick out (dropped
  /// this session, or without mood scores while a mood is set) is sent
  /// nothing, so what it would be sent changes no pick, and a skip that only
  /// changes that re-rolls nothing. The others are sent theirs only by a
  /// pick that goes across the servers; one that can't (Stay close with no
  /// More like row it can carry, sonic similarity dropped for the session,
  /// a DJ server with nothing to seed from) asks the DJ's own server alone,
  /// with its own songs, and the rest wait for the next pick that does.
  List<Server> _negativeTargets() => negativeTargets(
      dj: autoDJServer,
      multiServer: AutoDJManager().multiServerEnabled,
      candidates: multiServerCandidates());

  /// Whether the Less like row [key]'s cached vector is among the negatives
  /// a server other than the song's own would be sent ([_negativeTargets]),
  /// in the model the session's seed was last in, else the row's own: what
  /// makes a quick skip of a song whose server takes no negatives count
  /// after all.
  bool _vectorSentElsewhere(String key) {
    final mgr = AutoDJManager();
    if (!mgr.sonicSimilarityEnabled || !mgr.multiServerEnabled) return false;
    final row = _seeds.lessLike.where((s) => s.key == key).firstOrNull;
    final vector = row?.vector;
    if (row == null || vector == null) return false;
    final model = _fanOutSeedModel ?? row.vectorModel;
    return _negativeTargets().any((s) =>
        s.localname != row.server &&
        _seeds
            .negativesFor(s.localname, modelId: model)
            .vectors
            .contains(vector));
  }

  /// Past this far into a song, Previous starts it over; within it, Previous
  /// goes to the song before. 3 s is Android's own player's default
  /// (Media3's maxSeekToPreviousPosition), and Spotify's and the desktop
  /// players' too.
  static const previousRestartWindow = Duration(seconds: 3);

  /// When the last Previous started its song over, so a second press goes
  /// back even while a cast renderer's position still reads the old spot.
  /// A user seek clears it.
  DateTime? _previousRestartedAt;

  /// Whether a Previous at [position] starts the song over rather than going
  /// to the one before: past [previousRestartWindow], unless a Previous
  /// started it over within that window already ([restartedAt]). The press
  /// that follows a restart goes back, however stale [position] reads.
  /// Pure; unit-tested.
  static bool previousRestarts({
    required Duration position,
    required DateTime now,
    DateTime? restartedAt,
  }) {
    final pressedAgain = restartedAt != null &&
        now.difference(restartedAt) < previousRestartWindow;
    return !pressedAgain && position > previousRestartWindow;
  }

  @override
  Future<void> skipToPrevious() async {
    transport.note('skipToPrevious');
    _restoreSpot = null; // user navigation supersedes a failed-restore park
    _releasePark();
    final now = DateTime.now();
    final restarts = previousRestarts(
        position: _backend.position,
        now: now,
        restartedAt: _previousRestartedAt);
    _previousRestartedAt = restarts ? now : null;
    if (restarts) {
      _seekTo(Duration.zero);
    } else {
      _backend.seekToPrevious();
    }
  }

  @override
  Future<void> seek(Duration position) {
    transport.note('seek');
    _previousRestartedAt = null; // a scrub after a restart is a new spot
    return _seekTo(position);
  }

  Future<void> _seekTo(Duration position) {
    // A manual scrub supersedes the parked position (keep nothing: the next
    // re-seed should read the live player, which this seek just updated).
    _restoreSpot = null;
    // ...and a finished queue's end: the position is one the user picked now.
    _finishedTrack = null;
    _releasePark();
    _seekEvents.add(position);
    return _backend.seek(position);
  }

  // True while the handler itself is tearing playback down (user stop, cleared
  // queue, unplayable-queue give-up), so _broadcastState can tell a deliberate
  // idle apart from just_audio's error-induced idle. Cleared only at the
  // explicit restart entry points (play / restoreQueue) — NOT from observed
  // backend states, where a straggler ready event racing a stop could clear it
  // early and turn the stop's own idle into a bogus 'error' broadcast.
  bool _intentionalStop = false;

  @override
  Future<void> stop() async {
    transport.note('stop');
    appLog('[play] stop');
    _playIntent = false;
    _intentionalStop = true;
    // A stop that finds the local player COMPLETED is the queue having played
    // out, whoever sent it: the queue-end listener, the queue-end park giving
    // up its wait, or the user while it is parked there. Noted before the
    // backend goes idle — after that an ended queue and a stop in the middle
    // of a track look the same, and only one of them should start its track
    // over on the next play (shouldReviveFromTop).
    if (identical(_backend, _localBackend) &&
        _localBackend.processingState == BackendProcessingState.completed) {
      _finishedTrack = _trackKey(_itemAt(_localBackend.currentIndex));
    }
    _clearDeferredPick();
    // Don't touch the tunnel here: it follows the QUEUE, not the play/stop state,
    // so a stopped-but-still-queued iroh song keeps its tunnel (the queue listener
    // tears it down when the iroh songs are actually removed/cleared).
    await _backend.stop();
    await super.stop();
  }

  // Honor the requested mode: Android Auto and the lock screen send an absolute
  // target (not a toggle), and the in-app buttons already pass the desired mode.
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    // A transport toggle from Android Auto / the lock screen must never throw
    // out of the handler if the backend rejects the call (e.g. nothing loaded
    // yet on a cold headless bind); still re-broadcast the (unchanged) state.
    try {
      await _backend
          .setShuffleEnabled(shuffleMode == AudioServiceShuffleMode.all);
    } catch (e) {
      appLog('[audio] setShuffleMode failed: $e');
    }
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    try {
      await _backend.setRepeat(_backendRepeat(repeatMode));
    } catch (e) {
      appLog('[audio] setRepeatMode failed: $e');
    }
    _broadcastState();
  }

  // Map the audio_service repeat mode to what the backend models. 'group' has
  // no queue-group concept here, so it behaves as 'all'.
  static BackendRepeat _backendRepeat(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return BackendRepeat.one;
      case AudioServiceRepeatMode.none:
        return BackendRepeat.off;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return BackendRepeat.all;
    }
  }

  // ── Android Auto browsing (delegated to AutoBrowse). The native AudioService
  // IS the MediaBrowserService that Auto binds; these answer its browse/play
  // calls. They run headless (no UI), so AutoBrowse must self-bootstrap and
  // never throw — see auto_browse.dart.
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
          [Map<String, dynamic>? options]) =>
      AutoBrowse.children(parentMediaId);

  @override
  Future<MediaItem?> getMediaItem(String mediaId) =>
      AutoBrowse.mediaItem(mediaId);

  @override
  Future<void> playFromMediaId(String mediaId,
          [Map<String, dynamic>? extras]) =>
      AutoBrowse.play(mediaId);

  @override
  Future<List<MediaItem>> search(String query,
          [Map<String, dynamic>? extras]) =>
      AutoBrowse.search(query);

  // Google Assistant "play <X> on mStream" — advertised to the system via
  // MediaAction.playFromSearch in _broadcastState's systemActions.
  @override
  Future<void> playFromSearch(String query,
          [Map<String, dynamic>? extras]) =>
      AutoBrowse.playFromSearch(query);

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    await super.removeQueueItem(mediaItem);
    // TODO: See removeQueueItemAt
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    _restoreSpot = null; // row indices shift -- a parked index would lie
    // Read before anything moves: is this the row the stopped player is on?
    final dropsPosition = removalDropsKeptPosition(
        onLocalBackend: identical(_backend, _localBackend),
        processingState: _backend.processingState,
        currentIndex: _backend.currentIndex,
        removed: index);
    await super.removeQueueItemAt(index);
    // Update the queue BEFORE the backend. removeSourceAt makes the backend emit
    // its new currentIndex, and the currentIndexStream listener re-derives the
    // now-playing item as queue.value[index]. If the queue still held the
    // removed item, the wrong row would briefly render as the active/playing row
    // (a flash in the accent colour) before correcting — same root cause as the
    // reorder flash. Reordering keeps the queue and the emitted index in sync.
    queue.add(queue.value..removeAt(index));
    await _backend.removeSourceAt(index);
    if (dropsPosition) await _forgetKeptPosition();
  }

  /// Whether removing the row at [removed] takes the stopped player's kept
  /// position with it. Pure; unit-tested.
  ///
  /// A stopped local player still reports the position it was released at,
  /// and just_audio's idle stand-in keeps that through playlist edits: take
  /// away the row it is on and another row slides under the same position.
  /// After a queue has played out it is the finished track's END. The row
  /// left behind showed it on screen and was saved under it, so the app
  /// reopened that track partway in — or, for a shorter track with no length
  /// stored, past its own end ([restoredAtTrackEnd]).
  ///
  /// A player that is not idle has a real source loaded and moves itself,
  /// and another backend is not ours to seek.
  static bool removalDropsKeptPosition({
    required bool onLocalBackend,
    required BackendProcessingState processingState,
    required int? currentIndex,
    required int removed,
  }) =>
      onLocalBackend &&
      processingState == BackendProcessingState.idle &&
      currentIndex == removed;

  /// Zero the position the stopped local player kept: the row it belonged to
  /// is gone (removed, or cleared with the rest), and nothing else resets it
  /// — the idle stand-in only ever moves its index.
  Future<void> _forgetKeptPosition() async {
    _finishedTrack = null; // the end it marked was that row's
    if (!identical(_backend, _localBackend)) return;
    try {
      await _localBackend.seek(Duration.zero);
    } catch (e) {
      appLog('[queue] could not reset the stopped position: $e');
    }
  }

  /// The queue without [localname]'s items, plus the backend index playback
  /// should land on afterwards: the current item's new position when it
  /// survives, else the first survivor after it, else the last survivor.
  /// Returns null when no queued item belongs to [localname]. Pure; unit-tested.
  static ({List<MediaItem> keep, int newIndex, bool currentSurvives})?
      queueWithoutServer(
          List<MediaItem> queue, String localname, int currentIndex) {
    final keep = <MediaItem>[];
    int? newIndex;
    var currentSurvives = false;
    for (var i = 0; i < queue.length; i++) {
      final m = queue[i];
      if (m.extras?['server'] == localname) continue;
      if (i == currentIndex) {
        currentSurvives = true;
        newIndex = keep.length;
      } else if (i > currentIndex && !currentSurvives) {
        newIndex ??= keep.length;
      }
      keep.add(m);
    }
    if (keep.length == queue.length) return null;
    return (
      keep: keep,
      newIndex: keep.isEmpty ? 0 : (newIndex ?? keep.length - 1),
      currentSurvives: currentSurvives,
    );
  }

  /// Drop every queue item belonging to [localname] — its server was deleted.
  /// Downloaded copies stay on disk but leave the queue with the rest: their
  /// server context (ratings, art, URL re-resolution) went with the server.
  /// If the playing track was the server's, playback moves to the next
  /// surviving track (its stream URL just died with the server anyway).
  /// Serialized on _switchChain like every other local-backend load: this
  /// runs from a user deleting a server, which can land while a recovery
  /// re-seed is in flight, and two overlapping setSources wedge just_audio
  /// (see the rebuildTranscodeUrls customAction). Returns the chained future
  /// so ServerManager.removeServer still awaits the real work.
  Future<void> removeServerQueueItems(String localname) {
    final done = _switchChain.then((_) => _removeServerQueueItems(localname));
    _switchChain = done.catchError((_) {});
    return done;
  }

  Future<void> _removeServerQueueItems(String localname) async {
    // Its seeds go first, from the live and the held-aside set, pinned or
    // not: nothing else can resolve their paths, and a dead path in a body
    // costs the pick its sonic seeds. First, so the DJ branch and the early
    // returns below can't skip it; a server can own seeds and no queued row
    // (an Add song from search, a frozen row). By the localname, since the
    // server has already left the server list.
    _seeds = _seeds.withoutServer(localname);
    final pending = _pendingSeeds;
    if (pending != null) _pendingSeeds = pending.withoutServer(localname);
    _seedUnusable.removeWhere((k) => k.startsWith(seedKey(localname, '')));
    _publishSeeds();
    if (autoDJServer?.localname == localname) {
      // Auto-DJ would keep topping the queue back up from the deleted server.
      autoDJServer = null;
      _reconcileFanOutTunnels('dj-off');
      // Forget it too, or the next launch would try to restore a server that
      // no longer exists.
      unawaited(AutoDJManager().setEnabledServer(null));
      // Drop the session state and any in-flight pick with it — a response
      // landing after this would re-plant the dead session's anchors and
      // null-deref autoDJServer trying to queue the track.
      _resetAutoDJSession();
      customState.add(CustomEvent(autoDJServer));
    }
    final q = queue.value;
    if (q.isEmpty) return;
    final cur = (_backend.currentIndex ?? 0).clamp(0, q.length - 1);
    final plan = queueWithoutServer(q, localname, cur);
    if (plan == null) return;
    appLog('[queue] server $localname removed — dropping '
        '${q.length - plan.keep.length} of its queued track(s)');
    _restoreSpot = null; // row indices shift — a parked index would lie
    if (plan.keep.isEmpty) {
      // The whole queue belonged to it: same teardown as clearPlaylist,
      // including dropping the now-playing metadata and starting a new
      // Auto-DJ lane — the DJ can be armed on a DIFFERENT server than the
      // deleted one, and its session state described a queue that no
      // longer exists. Held back from picks like any clear, so the armed DJ
      // queues nothing into the emptied queue. Never a user clear: the pins
      // stay.
      await _guardedClear(clearPins: false);
      return;
    }
    final pos = plan.currentSurvives ? _backend.position : Duration.zero;
    final wasPlaying = _backend.playing;
    final wasShuffle = _backend.shuffleEnabled;
    final wasRepeat = _backend.repeat;
    _reordering = true;
    try {
      queue.add(plan.keep);
      // plan.newIndex is the surviving position, so parking it on a failure is
      // right even though the removal cleared the old park above (row indices
      // shifted; the pre-removal one would have lied).
      await _loadAtSpot(
          _backend, plan.keep, (index: plan.newIndex, position: pos));
      if (wasPlaying) unawaited(_backend.play());
      // setSources rebuilds the playlist; re-apply shuffle/repeat so the
      // removal doesn't silently drop them (mirrors the transcode reload).
      await _backend.setShuffleEnabled(wasShuffle);
      await _backend.setRepeat(wasRepeat);
    } finally {
      _reordering = false;
    }
    _emitCurrentMediaItem();
    _broadcastState();
  }

  /// Empty the queue: a new Auto DJ lane. [userClear] is false only for the
  /// seeded start's own clear ([_startAutoDJFromSeed]); every
  /// 'clearPlaylist' action is the user's (Clear queue, and every play that
  /// replaces the queue, playFromHere and the rest).
  Future<void> _doClearPlaylist({bool userClear = true}) async {
    appLog('[queue] cleared');
    // Whether the Seeds page's box takes the pins with this clear, decided
    // before anything else, while the queue still holds what the user threw
    // away: a clear of theirs, of a queue that held a row.
    final clearPins = clearsPinsOnClear(
        userClear: userClear,
        queueHadRows: queue.value.isNotEmpty,
        setting: AutoDJManager().clearPinsOnQueueClear);
    // A cleared queue is a new Auto-DJ lane — the user threw the old one
    // away. The DJ stays ARMED and adds nothing here (no start menu, no
    // surprise pick): it resumes from a clean slate when the user queues
    // something, via the queue-end listener. Reset FIRST, synchronously —
    // an in-flight pick can land during the awaits below, and it must
    // already see the new epoch to be discarded. And no pick starts until
    // the queue is empty ([_clearingQueue]).
    await _guardedClear(clearPins: clearPins);
  }

  /// The whole-queue teardown, from the new lane's reset to the empty
  /// queue, with [_clearingQueue] holding every pick back until it is done:
  /// a clear ([_doClearPlaylist]) and the removal of the server the whole
  /// queue belonged to ([_removeServerQueueItems]). Both run on the switch
  /// chain, so they never overlap and one flag is enough.
  Future<void> _guardedClear({required bool clearPins}) async {
    _clearingQueue = true;
    try {
      await _clearQueueAfterReset(clearPins: clearPins);
    } finally {
      _clearingQueue = false;
    }
  }

  /// The body of [_guardedClear]; call that, never this.
  Future<void> _clearQueueAfterReset({required bool clearPins}) async {
    _resetAutoDJSession(clearPins: clearPins);
    // The one-shot sonic seed is spent with the lane (webapp resetAnchors
    // "the seed is consumed" semantics). This is also what ends a seeded
    // start's use of it: _startAutoDJFromSeed reads the path into a local
    // before its own clearPlaylist lands here, so the opener still plays —
    // but the stored value never outlives the session it opened. A stale
    // one used to hijack any later empty-queue setAutoDJ (Android Auto's
    // Shuffle All replayed the last seed song instead of shuffling).
    unawaited(AutoDJManager().clearSonicSeed());
    _restoreSpot = null; // the queue the spot described is gone
    _intentionalStop = true;
    await _backend.stop();
    await super.stop();
    // The queue BEFORE the sources, as removeQueueItemAt does. Clearing the
    // sources makes the player emit a null index, and the now-playing
    // re-derived from that against a queue that still had its rows was row
    // 1 — handed to the media session a millisecond ahead of the blank item.
    // audio_service applies each update on a thread of its own, so the two
    // could land in either order, and the session then kept row 1 (on the
    // emulator, 3 clears of 15 with the sources cleared first and the
    // position reset below in place).
    queue.add(queue.value..clear());
    await _backend.clearSources();
    // ...and the position the stop left behind goes with them: with nothing
    // loaded the panel went on showing it.
    await _forgetKeptPosition();
    // Explicit, not left to the currentIndex listener: clearSources may or
    // may not emit an index change, and "did the notification keep the old
    // song's art" should not depend on which.
    _emitCurrentMediaItem();
    _broadcastState();
  }

  @override
  customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'clearPlaylist':
        // Serialized like every other load-class operation. AutoBrowse.play →
        // playFromHere → clearPlaylist means a car-UI tap can drop this
        // stop + clearSources on top of an in-flight recovery re-seed, and a
        // load torn down inside just_audio's activation window is what wedged
        // the player during the incident this series came from. Callers that
        // await customAction still see the clear COMPLETE before they queue
        // their new items, so play-from-here ordering is unchanged.
        final cleared = _switchChain.then((_) => _doClearPlaylist());
        _switchChain = cleared.catchError((_) {});
        await cleared;
        break;
      case 'moveQueueItem':
        // Drag-to-reorder. [to] is the post-removal target index
        // (ReorderableListView convention). Reorder the queue list first, then
        // the backend's source list, so the backend's current-index emit lands
        // against the already-updated queue.
        _restoreSpot = null; // row indices shift -- a parked index would lie
        final from = extras?['from'];
        final to = extras?['to'];
        if (from is int && to is int) {
          final q = queue.value;
          if (from >= 0 &&
              from < q.length &&
              to >= 0 &&
              to < q.length &&
              from != to) {
            final item = q.removeAt(from);
            q.insert(to, item);
            queue.add(q);
            // Hold the now-playing item steady while the backend rewires its
            // source order, so its art/title/waveform don't flash the moved
            // track as the backend's currentIndex transiently re-points.
            _reordering = true;
            try {
              await _backend.moveSource(from, to);
            } finally {
              _reordering = false;
            }
            _broadcastState();
          }
        }
        break;
      case 'updateRating':
        {
          // A track was (un)rated in the UI. Patch the new rating into the
          // matching queue items' extras and the now-playing item, so every
          // view that reads extras['rating'] (Song Info, the player readout)
          // reflects it and the persisted queue keeps it across a restart. The
          // server-side write is the rateSong POST; this only keeps the
          // in-memory queue / item in sync.
          final fp = extras?['filepath'] as String?;
          final srv = extras?['server'] as String?;
          if (fp != null) {
            final target = fp.startsWith('/') ? fp.substring(1) : fp;
            final newRating = (extras?['rating'] as num?)?.toInt();
            // Match the source server too (when supplied): a mixed-server queue
            // can carry the same path on two servers, and only the one that was
            // actually rated should change.
            bool hit(MediaItem m) {
              if (srv != null && m.extras?['server'] != srv) return false;
              final p = m.extras?['path'] as String?;
              return p != null &&
                  (p.startsWith('/') ? p.substring(1) : p) == target;
            }
            MediaItem patched(MediaItem m) =>
                m.copyWith(extras: {...?m.extras, 'rating': newRating});
            var changed = false;
            final nq = queue.value.map((m) {
              if (hit(m)) {
                changed = true;
                return patched(m);
              }
              return m;
            }).toList();
            if (changed) queue.add(nq);
            final cur = mediaItem.value;
            if (cur != null && hit(cur)) mediaItem.add(patched(cur));
          }
        }
        break;
      case 'forceAutoDJRefresh':
        customState.add(CustomEvent(autoDJServer));
        break;
      case 'retrySonic':
        // The sonic settings changed (the Auto DJ screen's Sonic similarity
        // sheet): a session that dropped sonic gets another go with them.
        _retrySonicBookkeeping();
        break;
      case 'clearSonicSession':
        // "New lane" for the sonic seeds alone (Discover's start, which
        // names its own seed): the live More like and Less like carry over
        // as at any new lane, in the stored mode ([_carriedSeeds]). In Drift
        // that keeps the user's pins and the unpinned skips with their
        // clocks and drops the DJ's picks, so the next pick anchors fresh
        // rather than on the DJ's stale picks (webapp
        // resetAnchors/clearSonicAnchors semantics). In Stay close every row
        // it shows stays, and the lane looks for its one song again: the
        // kept rows it can carry anchor it at once, and it takes in a song
        // only when none of them is usable. Switching sonic similarity off
        // no longer sends this: the seeds wait for it to come back on within
        // the lane.
        _seeds = _carriedSeeds();
        _seedUnusable.clear();
        _stayCloseAnchored = false;
        _stayCloseAdmitted = false;
        _publishSeeds();
        break;
      case 'setAutoDJ':
        final nextDJ = extras?['autoDJServer'] as Server?;
        // A federated peer hosts the DJ like any other server: random-songs
        // is on the federation allowlist (mStream #946), its filepath seeds
        // resolve on the peer, and its picks stream the way its browsed
        // tracks do — through the parent's proxy or the peer's own tunnel.
        // A re-arm on the SAME server (a settings-screen rebuild, the queue
        // header toggling it back on) is not a new session. Only a real
        // change resets the session state — and only a real change is allowed
        // to take the queue, below.
        final freshSession = autoDJServer == null || autoDJServer != nextDJ;
        if (freshSession) _resetAutoDJSession();
        autoDJServer = nextDJ;
        // After the assignment: the seeds' minute tick runs only while the
        // DJ is on, and the page's offers follow the DJ's server.
        _publishSeeds();
        // The pins an app restart keeps join at the arm too: a headless boot
        // (Android Auto, media resumption) never runs main's launch restore,
        // and its lanes would go without them. Once per run, so a no-op
        // after main's call; the DJ's server came out of the loaded list.
        if (nextDJ != null) unawaited(loadPinnedSeeds());
        _reconcileFanOutTunnels(nextDJ == null ? 'dj-off' : 'dj-fanout');
        // Remembered across restarts. Every toggle path funnels through here,
        // so this is the one place that has to record it.
        unawaited(AutoDJManager().setEnabledServer(nextDJ?.localname));
        // And Play from holds it from now on, whichever path armed it (a
        // Discover play, Android Auto's Shuffle All): the DJ's own server is
        // always one the screen names, and the one it runs on.
        if (nextDJ != null) {
          unawaited(AutoDJManager().setPlayFromHome(nextDJ.localname));
        }

        customState.add(CustomEvent(autoDJServer));

        if (freshSession && await _startAutoDJFromSeed()) break;

        if (queue.value.isEmpty ||
            queue.value.length == 1 ||
            index == queue.value.length - 1) {
          if (queue.value.isEmpty) {
            await autoDJ(autoPlay: true);
            // A second fetch only when the first left the queue one deep —
            // the lookahead the queue-end top-up needs. A batch (songs per
            // fetch above 1) already provides it.
            if (queue.value.length < 2) autoDJ();
          } else if (index == queue.value.length - 1 &&
              _backend.processingState == BackendProcessingState.idle) {
            autoDJ(autoPlay: true, incrementIndex: true);
          } else {
            autoDJ();
          }
        }

        break;
      case 'startAutoDJFromSeed':
        // The armed-DJ counterpart of the seeded arm above: the DJ is already
        // on, the queue was cleared under it (a clear keeps it armed but adds
        // nothing, see _doClearPlaylist), and the user has just named an
        // opening song from the empty-queue prompt. Re-arming on the same
        // server is not a fresh session, so setAutoDJ would never read the
        // seed — this does, with the same guards (armed, empty queue, seed
        // from the DJ's own server). A seed that cannot open is dropped
        // rather than left to hijack a later arm.
        if (!await _startAutoDJFromSeed()) {
          unawaited(AutoDJManager().clearSonicSeed());
          return false;
        }
        return true;
      case 'rebuildTranscodeUrls':
        // Serialized with every other local-backend load. Two setSources
        // overlapping does NOT merely interrupt the older one: an interrupt
        // landing inside just_audio's platform-activation window throws out of
        // setPlatform() itself, leaving _active stuck true, _platform a
        // permanently-errored future and the event subscriptions cancelled —
        // after which every later load/play rethrows "Loading interrupted"
        // instantly until stop(), an EQ rebuild, or process death. Observed
        // on-device: a tunnel bind fired this rebuild while the reconnect
        // reseed was chaining, both threw, and playback was dead for the rest
        // of the drive. The chain is what makes that unreachable.
        final rebuild = _switchChain.then((_) => _rebuildTranscodeUrls(
            upcomingOnly: extras?['upcomingOnly'] == true,
            auto: extras?['auto'] == true));
        _switchChain = rebuild.catchError((_) {});
        await rebuild;
        break;
    }
  }

  // Resolve a queue item's server from the localname stored in its extras.
  Server? _serverFor(MediaItem m) =>
      ServerManager().byLocalname(m.extras?['server'] as String?);

  /// Re-derive [m]'s stream URL under the CURRENT transcode settings. Returns
  /// the same instance when nothing changes, so callers can detect a no-op.
  /// Downloaded items are left alone — they play from the local copy, so their
  /// URL is irrelevant.
  MediaItem _withRebuiltUrl(MediaItem m) {
    // A downloaded copy plays from disk, so its URL is irrelevant — while the
    // file is there. One that vanished (storage cleared, the folder pruned)
    // falls back to the stored URL at load time, so it is rebuilt like a
    // streaming item; left alone it would carry a dead port or, for a
    // direct peer, an expired guest token.
    if (hasLocalCopy(m)) return m;
    final path = m.extras?['path'] as String?;
    final server = _serverFor(m);
    if (path == null || server == null) return m; // local-only / unknown server
    final newId = buildServerStreamUrl(server, path);
    return sameStreamUrl(newId, m.id) ? m : m.copyWith(id: newId);
  }

  /// Re-derive [m]'s album-art URL against the live tunnel (items whose bytes
  /// ride a tunnel — an iroh server's, or a federated peer's through its
  /// parent; downloaded items included). Same instance when nothing changes.
  MediaItem _withRebuiltArt(MediaItem m) {
    final server = _serverFor(m);
    if (server == null || !server.isIrohTransport) return m;
    return rebindLoopbackArt(m, server);
  }

  /// Whether [m] plays from a downloaded copy that is actually on disk.
  static bool hasLocalCopy(MediaItem m) {
    final localPath = m.extras?['localPath'];
    return localPath is String && File(localPath).existsSync();
  }

  /// Whether an "upcoming only" rebuild really should leave the current item
  /// alone. The option exists to keep a track that is PLAYING from reloading
  /// mid-song (buffering counts; so does a finished queue, where there is
  /// nothing upcoming and nothing to restart). Anything else has nothing to
  /// protect and may be the very URL that needs the change — a direct peer's
  /// renewed guest token, a tunnel that came up under a parked player, a
  /// queue restored at launch and sitting paused on the parent's proxy URL
  /// while the peer's own tunnel arrives: idle after a failed load, never
  /// started, still loading, or loaded but paused (the reload keeps the
  /// spot and stays paused, so nothing is heard). Pure; unit-tested.
  static bool protectsCurrentTrack(
      {required bool upcomingOnly,
      required BackendProcessingState state,
      required bool playing}) {
    if (!upcomingOnly) return false;
    return switch (state) {
      BackendProcessingState.completed => true,
      BackendProcessingState.ready ||
      BackendProcessingState.buffering =>
        playing,
      BackendProcessingState.idle || BackendProcessingState.loading => false,
    };
  }

  /// The URI the CURRENT item actually plays from: the downloaded file when
  /// one exists (mirroring LocalPlaybackBackend's source resolution), else the
  /// stream URL re-derived against the live tunnel / transcode state —
  /// `mediaItem.value.id` can carry a stale loopback port/token after a tunnel
  /// restart. Used by the visualizer's audio sidecar to decode what's playing.
  Uri? currentPlayableUri() {
    final m = mediaItem.value;
    if (m == null) return null;
    final localPath = m.extras?['localPath'] as String?;
    if (localPath != null && File(localPath).existsSync()) {
      return Uri.file(localPath);
    }
    return Uri.tryParse(_withRebuiltUrl(m).id);
  }

  /// Rebuild queue stream URLs after a transcode-setting change ([auto] false)
  /// or a tunnel (re)connect ([auto] true, fired by ServerManager).
  ///
  /// [upcomingOnly] leaves the current track playing and only swaps the
  /// not-yet-played tracks; otherwise the whole queue reloads at the current
  /// index/position (the current track briefly re-buffers). No-op when no URL
  /// actually changes (e.g. nothing to convert, or transcoding unavailable).
  Future<void> _rebuildTranscodeUrls(
      {required bool upcomingOnly, bool auto = false}) async {
    // An auto rebuild must not touch an active cast: the cast backends
    // re-resolve every track's URL at load time (irohProxyUri rebinds to the
    // live tunnel), so the reload is unnecessary — and issuing it mid-session
    // clobbers the Cast SDK's own suspend/resume recovery (observed
    // on-device: zombie TV + double audio after a Wi-Fi blip). A user-driven
    // transcode change still applies while casting.
    if (auto && !identical(_backend, _localBackend)) {
      appLog('[queue] auto URL rebuild skipped while casting');
      return;
    }
    final q = queue.value;
    if (q.isEmpty) return;
    // The BACKEND's live index, for the upcomingOnly branch alone: that branch
    // does source-list surgery against the player's own list, so it has to
    // address the same indices the player does. The full branch below reloads
    // everything and wants the LOGICAL spot instead.
    final cur = (_backend.currentIndex ?? 0).clamp(0, q.length - 1);

    final protectCurrent = protectsCurrentTrack(
        upcomingOnly: upcomingOnly,
        state: _backend.processingState,
        playing: _backend.playing);
    if (upcomingOnly && !protectCurrent) {
      appLog('[queue] upcoming-only rebuild widened to the current track '
          '(${_backend.processingState.name}'
          '${_backend.playing ? '' : ', paused'})');
    }
    if (protectCurrent) {
      final rebuilt = <MediaItem>[];
      bool changed = false;
      for (int i = 0; i < q.length; i++) {
        if (i <= cur) {
          rebuilt.add(q[i]);
        } else {
          final nm = _withRebuiltUrl(q[i]);
          if (!identical(nm, q[i])) changed = true;
          rebuilt.add(nm);
        }
      }
      if (!changed) return;
      _reordering = true;
      try {
        // Swap the upcoming sources without touching the playing one: drop them
        // from the end, then re-append the rebuilt versions in the same order.
        for (int i = q.length - 1; i > cur; i--) {
          await _backend.removeSourceAt(i);
        }
        for (int i = cur + 1; i < rebuilt.length; i++) {
          await _backend.addSource(rebuilt[i]);
        }
        queue.add(rebuilt);
      } finally {
        _reordering = false;
      }
    } else {
      final rebuilt = q.map(_withRebuiltUrl).toList();
      bool changed = false;
      for (int i = 0; i < q.length; i++) {
        if (!identical(rebuilt[i], q[i])) changed = true;
      }
      // Album art carries the loopback port + token too, and (unlike the
      // stream URL) it matters for DOWNLOADED items — the notification and
      // lock screen fetch it. Rebind it; when nothing else changed, publish
      // the art without a player reload.
      final withArt = rebuilt.map(_withRebuiltArt).toList();
      bool artChanged = false;
      for (int i = 0; i < q.length; i++) {
        if (!identical(withArt[i], rebuilt[i])) artChanged = true;
      }
      if (!changed) {
        if (artChanged) {
          appLog('[queue] album-art URLs rebound to the live tunnel');
          queue.add(withArt);
          _emitCurrentMediaItem();
        }
        return;
      }
      // _reviveSpot, not the backend's index: this runs on a tunnel re-bind,
      // which is exactly when a previous load may have failed and left the
      // player reporting track 1. Reading that back would relocate the
      // session again, one rebuild at a time.
      final spot = _reviveSpot();
      appLog('[queue] stream URLs rebuilt — reloading at track '
          '${spot.index + 1}${auto ? ' (auto)' : ''}');
      // `playing` is FALSE on an error-parked player, so an auto rebuild
      // after a tunnel bind would reload the track and sit silent. _playIntent
      // is the user's actual intent (cleared by pause/stop, false at boot), so
      // OR-ing it in resumes only where playback was genuinely wanted.
      // …and not over an audio-focus interruption (a call): the rebuild's
      // resume used to re-request focus mid-call (log: 19:30:43 → 19:30:47).
      final wasPlaying =
          _backend.playing || (auto && _playIntent && !_recentlyInterrupted);
      final wasShuffle = _backend.shuffleEnabled;
      final wasRepeat = _backend.repeat;
      _reordering = true;
      try {
        queue.add(withArt);
        await _loadAtSpot(_backend, withArt, spot);
        // Re-read the intent AFTER the load: the load is network-bound and can
        // run for seconds over a fresh tunnel, and a pause landing inside that
        // window must win over what we captured before it. Same doctrine as
        // _reseedLocalAtSpot and _doSetEqEnabled.
        if (wasPlaying && _playIntent) unawaited(_backend.play());
        // setSources rebuilds the playlist; re-apply shuffle/repeat so a
        // transcode change doesn't silently drop them (mirrors restoreQueue).
        await _backend.setShuffleEnabled(wasShuffle);
        await _backend.setRepeat(wasRepeat);
      } finally {
        _reordering = false;
      }
    }
    _emitCurrentMediaItem();
    _broadcastState();
  }

  /// The queue with every copy of [serverName]+[path] patched to play from
  /// [localPath], or null when nothing needed patching (not queued, or every
  /// copy already carries this exact path). A copy holding a DIFFERENT
  /// localPath is re-patched — after a storage-location change the old path
  /// is stale and the re-download landed somewhere new. Untouched items keep
  /// their instances. Pure; unit-tested.
  static List<MediaItem>? patchDownloadedTrack(List<MediaItem> queue,
      {required String serverName,
      required String path,
      required String localPath}) {
    var changed = false;
    final patched = queue.map((m) {
      final e = m.extras;
      if (e == null ||
          e['server'] != serverName ||
          e['path'] != path ||
          e['localPath'] == localPath) {
        return m;
      }
      changed = true;
      return m.copyWith(extras: {...e, 'localPath': localPath});
    }).toList();
    return changed ? patched : null;
  }

  /// A finished download for [serverName]+[path] landed at [localPath]: mark
  /// the queued copies of that track as local. Extras-only ON PURPOSE — no
  /// live source surgery (removing/re-adding loaded sources mid-play races
  /// un-serialized queue edits, re-rolls shuffle order, and can trip the
  /// completed→stop teardown). The patched extras are what every fresh LOAD
  /// reads (LocalPlaybackBackend._uriFor at setSources; resolveRendererUri
  /// when a cast session (re)seeds), so: the badge lights up now, the
  /// snapshot persists it, restores / re-seeds / return-to-local reloads and
  /// the next cast session play from disk — and if an already-loaded
  /// streaming source dies offline, the retry re-seed lands on the file
  /// within seconds. Sources already loaded (local playlist, live cast item
  /// list) finish their session streaming — except an upcoming local one,
  /// which _playFromLocalCopy reloads from disk the moment its turn comes.
  /// Synchronous — no awaits between reading and publishing the queue, so it
  /// can't interleave with anything.
  void onTrackDownloaded(String serverName, String path, String localPath) {
    final patched = patchDownloadedTrack(queue.value,
        serverName: serverName, path: path, localPath: localPath);
    if (patched == null) return;
    appLog('[queue] download landed — queued copies of '
        '${path.split('/').last} marked local');
    // A new file on disk retires any "already tried it, the copy is bad"
    // verdict against this track — the copy it was about is gone.
    if (_localRetryKey != null &&
        _localRetryKey == '$serverName\u0000$path') {
      _localRetryKey = null;
    }
    // The PLAYING track keeps streaming its already-loaded source until the
    // next load, but its extras now say "local" — hold the WifiLock until a
    // fresh load actually reads the file (cleared on `loading`), or the
    // screen-off power-save stall the lock prevents comes right back.
    if (identical(_backend, _localBackend) &&
        _backend.processingState != BackendProcessingState.idle) {
      final q = queue.value;
      final cur = _backend.currentIndex ?? 0;
      if (cur >= 0 && cur < q.length && !identical(patched[cur], q[cur])) {
        _currentSourcePredatesPatch = true;
      }
    }
    queue.add(patched);
    _updateWifiLock();
  }

  // A download that landed after the playlist was built left this track's
  // source streaming (onTrackDownloaded patches extras only). Its turn is
  // the one moment a reload costs nothing audible — the track has barely
  // begun — so it reloads from disk here (a track on disk for nine minutes
  // streamed and stalled seven times, 2026-10-20). Not under shuffle: a
  // fresh playlist re-rolls the order and brings played tracks back.
  bool _localSwapPending = false;

  void _playFromLocalCopy(int index, MediaItem item) {
    if (!identical(_backend, _localBackend) ||
        _localSwapPending ||
        _recoveringPlayback ||
        _skipPending ||
        _localBackend.shuffleEnabled ||
        !_localBackend.streamsDespiteLocalCopy(index, item)) {
      return;
    }
    _localSwapPending = true;
    appLog('[play] ${item.title} is on disk — reloading from the local copy');
    _switchChain = _switchChain.then((_) async {
      if (!identical(_backend, _localBackend) ||
          _localBackend.currentIndex != index ||
          !_localBackend.streamsDespiteLocalCopy(index, item)) {
        return;
      }
      // A copy that turns out unplayable takes the bad-file path on its
      // next error instead of another reload (see _recoverFromLocalCopy).
      _localRetryKey = _trackKey(item);
      _reordering = true;
      try {
        await _reseedLocalAtSpot();
      } finally {
        _reordering = false;
      }
      _emitCurrentMediaItem();
      _broadcastState();
    }).catchError((Object e) {
      appLog('[play] local-copy reload failed: $e');
    }).whenComplete(() => _localSwapPending = false);
  }

  // True while the CURRENT item's extras say "local" but its loaded source
  // was created before the download landed and still streams. Only consulted
  // by the WifiLock heuristics; cleared when any fresh load starts.
  bool _currentSourcePredatesPatch = false;

  /// The processing state to publish for the backend's [state]. A deliberate
  /// teardown (intentional stop, or nothing queued) passes `idle` through —
  /// audio_service stops the Android service on every published
  /// non-idle→idle transition, which is exactly right there. But just_audio
  /// also flips to `idle` on ANY playback error; publishing that would let
  /// audio_service stopSelf() while the UI activity is unbound (backgrounded /
  /// swiped away), destroying the FlutterEngine before the error recovery in
  /// _onPlaybackError can run. An unintentional idle with tracks still queued
  /// publishes `error` instead, keeping the service (and notification) alive.
  static AudioProcessingState publishProcessingState(
      BackendProcessingState state,
      {required bool intentionalStop,
      required bool queueEmpty}) {
    switch (state) {
      case BackendProcessingState.idle:
        return (intentionalStop || queueEmpty)
            ? AudioProcessingState.idle
            : AudioProcessingState.error;
      case BackendProcessingState.loading:
        return AudioProcessingState.loading;
      case BackendProcessingState.buffering:
        return AudioProcessingState.buffering;
      case BackendProcessingState.ready:
        return AudioProcessingState.ready;
      case BackendProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Broadcasts the current state to all clients.
  /// Whether the Android WifiLock should be held: the phone is actively
  /// moving audio bytes over the network. Either the local player is playing
  /// a network source, or a cast renderer is being fed FROM the phone (iroh
  /// LAN relay, local-file serve, visualizer HLS — LocalMediaServer moves
  /// every byte, so radio power-save starves the TV just the same; a
  /// plain-HTTP cast streams renderer-direct and doesn't need it). Never for
  /// on-disk files and never while paused, stopped, or parked — a silent
  /// player holding a full-power Wi-Fi lock for hours is a battery bug, and
  /// the tunnel heal works without it. Pure; unit-tested.
  static bool shouldHoldWifiLock({
    required bool playing,
    required bool onLocalBackend,
    required BackendProcessingState processingState,
    required bool itemIsNetworkSource,
    required bool castRelaysViaPhone,
  }) {
    if (!playing) return false;
    if (castRelaysViaPhone) return true;
    return onLocalBackend &&
        itemIsNetworkSource &&
        processingState != BackendProcessingState.idle &&
        processingState != BackendProcessingState.completed;
  }

  // Whether the LOCAL backend actually pulls [item] over the network. Mirrors
  // LocalPlaybackBackend._uriFor: a downloaded track plays from disk only
  // while its file still exists — gone (SD ejected, folder cleared) it falls
  // back to streaming the id, which needs the lock like any other stream.
  static bool _streamsFromNetwork(MediaItem item) {
    if (!item.id.startsWith('http://') && !item.id.startsWith('https://')) {
      return false;
    }
    final localPath = item.extras?['localPath'] as String?;
    return localPath == null || !File(localPath).existsSync();
  }

  // Whether a cast renderer fetches [item] FROM THE PHONE rather than from a
  // server. Mirrors resolveRendererUri (cast_origin.dart): a local-only file
  // is served by LocalMediaServer, an iroh track is relayed through its proxy
  // (or disk-served); only a plain-HTTP server track goes renderer-direct.
  bool _phoneIsCastOrigin(MediaItem item) {
    final localPath = item.extras?['localPath'] as String?;
    final isNetwork =
        item.id.startsWith('http://') || item.id.startsWith('https://');
    if (!isNetwork && localPath != null && File(localPath).existsSync()) {
      return true;
    }
    return _serverFor(item)?.isIrohTransport ?? false;
  }

  // True while the active cast backend streams the on-device visualizer: the
  // phone transcodes and serves the HLS itself, so it is the renderer's byte
  // origin regardless of where the track's audio came from. Set on every cast
  // switch; only consulted while a cast backend is active.
  bool _castVisualizer = false;

  // Re-evaluated on every state broadcast (play/pause, track change, backend
  // swap, processing-state moves all land there); the shim dedupes, so only
  // actual transitions cross the platform channel.
  void _updateWifiLock() {
    final q = queue.value;
    final idx = _backend.currentIndex ?? 0;
    final item = (idx >= 0 && idx < q.length) ? q[idx] : null;
    final onLocal = identical(_backend, _localBackend);
    unawaited(WifiLockShim.setHeld(shouldHoldWifiLock(
      playing: _backend.playing,
      onLocalBackend: onLocal,
      processingState: _backend.processingState,
      // _currentSourcePredatesPatch: extras say "local" but the loaded source
      // still streams (download landed mid-track) — keep the lock honest.
      itemIsNetworkSource: item != null &&
          (_streamsFromNetwork(item) || _currentSourcePredatesPatch),
      castRelaysViaPhone: !onLocal &&
          item != null &&
          (_castVisualizer || _phoneIsCastOrigin(item)),
    )));
  }

  void _broadcastState() {
    // Mid-rebuild reads go through the NEW empty player and would publish a
    // bogus transient `error`; _doSetEqEnabled broadcasts once it's done.
    // Mid-restore they'd publish queueIndex 0 to the media session, which is
    // the same wrong-track flash one layer down; restoreQueue broadcasts once
    // it has landed.
    if (_rebuilding || _restoring) return;
    _updateWifiLock();
    final playing = _backend.playing;
    final AudioServiceShuffleMode shuffle = _backend.shuffleEnabled == true
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;

    // Emit the exact requested mode (_repeatMode); the backend's BackendRepeat
    // collapses 'group' to 'all', so reading it back would lose information.
    // This keeps none/all/one distinct for clients that cycle through them.
    final AudioServiceRepeatMode repeat = _repeatMode;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        // Lets Google Assistant route "play <X> on mStream" to playFromSearch.
        MediaAction.playFromSearch,
        // Enables the OS shuffle / repeat remote commands (lock screen,
        // CarPlay's Now Playing draws its shuffle and repeat buttons from
        // them). Both handler methods exist and are safe headless.
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
      },
      shuffleMode: shuffle,
      repeatMode: repeat,
      androidCompactActionIndices: [0, 1, 3],
      processingState: publishProcessingState(_backend.processingState,
          intentionalStop: _intentionalStop,
          queueEmpty: queue.value.isEmpty),
      playing: playing,
      updatePosition: _backend.position,
      bufferedPosition: _backend.bufferedPosition,
      speed: _backend.speed,
      queueIndex: _backend.currentIndex,
    ));
  }

  /// Discover's "start a session" from a song on [server] (its [path] and a
  /// display [title]; [chosen] when the user started from a song they could
  /// see, false for a random draw): a new queue, then the DJ opening on that
  /// song ([_startAutoDJFromSeed]).
  ///
  /// The clear comes first. A queue clear spends any one-shot seed, so a
  /// stale one never takes over a later start ([_doClearPlaylist]); stored
  /// before it, the song was gone by the time the DJ looked, and the session
  /// opened on a random song instead. Then the seed, marked [chosen] so Stay
  /// close adds the song to More like, pinned, as Choose and Recently played
  /// do (a random draw adds nothing). Then the DJ: a fresh arm (off, or on
  /// another server) reads the seed in setAutoDJ; on the same server
  /// setAutoDJ is no new session and never reads it, so the armed DJ starts
  /// from it directly, as the empty-queue prompt does.
  Future<void> startSessionFromSong(
      {required Server server,
      required String path,
      required String title,
      required bool chosen}) async {
    await customAction('clearSonicSession');
    await customAction('clearPlaylist');
    await AutoDJManager().setSonicSeed(
        path: path, title: title, server: server.localname, chosen: chosen);
    if (autoDJServer != null && autoDJServer == server) {
      await customAction('startAutoDJFromSeed');
    } else {
      await customAction('setAutoDJ', {'autoDJServer': server});
    }
  }

  /// Open an Auto DJ session ON its seed song: replace the queue with the
  /// seed, play it, and pull its first followers. Returns false when there is
  /// no usable seed, leaving the caller's ordinary top-up path to run.
  ///
  /// A seed means "start the session from this song", and until now it only
  /// ever steered which songs got PICKED — the session opened on something
  /// merely similar and the song the user actually named never played.
  ///
  /// Taking the queue is the point, so it is guarded twice over: the caller
  /// only offers a genuinely fresh arm, and a seed is an explicit,
  /// individually-cleared choice, not a default.
  Future<bool> _startAutoDJFromSeed() async {
    final server = autoDJServer;
    final mgr = AutoDJManager();
    // ONLY opens an empty queue. With tracks already queued the DJ takes its
    // cue from those — replacing them with a seed would throw away a queue the
    // user built, which is never what arming the DJ meant.
    if (queue.value.isNotEmpty) return false;
    // Filepaths are per-library — a seed picked on another server names
    // nothing here.
    final path =
        mgr.sonicSeedServer == server?.localname ? mgr.sonicSeedPath : null;
    // Whether the user chose this song (Recently played, Choose) rather than
    // Random drawing it: Stay close adds a chosen one to More like (below).
    // Read with the path, before the first await: the clear below empties
    // the stored seed, the mark with it.
    final chosen = path != null && mgr.sonicSeedChosen;
    if (server == null || path == null) return false;
    // Only the path and a display title are persisted, so the row is
    // reconstructed and buildServerFileMediaItem fetches the rest (it also
    // resolves a downloaded copy, which a seed track may well have).
    // In the browse rows' form, with the leading slash: that is what a
    // downloaded copy is filed under, and what a play of it is recorded as.
    final MediaItem? seed = await buildServerFileMediaItem(DisplayItem(
        server,
        mgr.sonicSeedTitle ?? path.split('/').last,
        'file',
        '/$path',
        null,
        null));
    if (seed == null) return false;
    // Same order as playFromHere — the one flow in the app that replaces a
    // queue and starts it. The clear also CONSUMES the stored seed (it is a
    // one-shot opener; see _doClearPlaylist) — [path] and [seed] are already
    // in hand above, and the follow-up picks anchor on the seed song all the
    // same, as a More like row (below) or as the playing track.
    //
    // The start's own clear, not the user's: it never takes the pins with it
    // (the Seeds page's box counts only a clear of theirs), though a row
    // queued during the await above would make this queue look like one
    // they threw away. On _switchChain, exactly as the 'clearPlaylist'
    // action runs it.
    final cleared =
        _switchChain.then((_) => _doClearPlaylist(userClear: false));
    _switchChain = cleared.catchError((_) {});
    await cleared;
    // The lane the clear just started. A Stop, a server switch or another
    // clear while the opener is being queued starts another, or leaves the
    // DJ off, and the opener is no row of either.
    final lane = _djSessionEpoch;
    await addQueueItem(seed);
    // After the clear, whose reset would wipe what this adds, and before the
    // seek, whose index emission can already fire the first follower's
    // top-up. Only while the lane is still the clear's: a Stop or another
    // clear while the opener was being queued would otherwise leave a row
    // for a lane that is gone, or one held aside for the NEXT Start.
    //
    // Drift: the opener is the lane's first More like row, unpinned, so it
    // rotates out like a played pick. Not a DJ pick, so the index listener
    // never pushes it, and the first pick's blend finds it there
    // ([blendsOnLaneStart]).
    //
    // Stay close: a song the user chose comes in as Add song brings one,
    // pinned, the newest More like row ([addsChosenSong]): held aside, since
    // the clear's lane has not picked yet, so the first follower's merge
    // takes it in and that request carries it beside the rows Stay close
    // kept. A Random opener adds nothing. Then the first follower admits the
    // opener (by then the playing track, since the clear consumed the stored
    // seed) as the lane's one song only when the lane has nothing to stay
    // close to and the request can carry it ([stayCloseAdmit]), unless a
    // server then refuses every such row before the lane took in a song:
    // then the next pick takes in the song playing ([stayCloseReleases]).
    if (lane == _djSessionEpoch && autoDJServer != null) {
      final drift = mgr.sonicAnchorMode == SonicAnchorMode.rolling;
      if (drift) {
        final next = _seeds.pushPick(trackFactsFor(seed),
            origin: SeedOrigin.opener, now: DateTime.now());
        if (!identical(next, _seeds)) {
          _seeds = next;
          _publishSeeds();
        }
      } else if (addsChosenSong(
          stayClose: !drift,
          chosen: chosen,
          canAdd: seeds.canAdd(SeedList.moreLike))) {
        seedAdd(SeedList.moreLike, trackFactsFor(seed));
        appLog('[dj] stay close: the chosen first song joins More like');
      }
    }
    await skipToQueueItem(0);
    // NOT awaited: just_audio's play() future completes only when playback
    // pauses or stops (see LocalPlaybackBackend.seek). Awaited, the follower
    // fetch below slept until the seed track ENDED — or until the next queue
    // clear stopped the player, at which point it woke under the new lane's
    // epoch and refilled the queue the user had just emptied (simulator,
    // 2026-09-17: clear → four picks back within 10 ms).
    unawaited(play());
    // Followers, not a first pick: the seed IS track one. At least two more
    // so the session feels underway before the queue-end top-up takes over.
    // The first fetch is awaited so a failure surfaces here and not in a
    // detached future; a second rides along behind it only when the first
    // was a single pick — a batch already puts the session underway.
    await autoDJ();
    if (queue.value.length < 3) unawaited(autoDJ());
    return true;
  }

  // ── Multi-server picking ────────────────────────────────────────
  //
  // A single-server session seeds from a FILEPATH, which names a row on the
  // server that holds it and means nothing anywhere else. A multi-server
  // session seeds from the VECTOR behind that path, so every server can
  // answer "something like this" out of its own library.
  //
  // Servers that can't take part are dropped for the rest of the session
  // rather than retried every pick: too old, discovery off, or indexed with
  // a different embedding model — read up front from federation/health
  // ([_fanOutModels]); the server's own refusal (a 400, because comparing
  // across model spaces returns confident nonsense) stays as the backstop.
  final Set<String> _multiServerExcluded = {};
  // Why each of [_multiServerExcluded] was dropped, for the Auto DJ screen.
  final Map<String, FanOutSitOut> _multiServerExcludedWhy = {};

  /// The server [localname] dropped from this session's fan-out for [why].
  /// What reads the drops as it builds hears of it through customState, as
  /// of the DJ's other state: the Auto DJ screen's Play from sit-outs, and
  /// the Seeds page's offers ([seedAddServers]), which would otherwise show
  /// a server's songs on offer until a tap asked again. Only when something
  /// changed: a server dropped again for the same reason tells nobody
  /// anything new.
  void _dropFromFanOut(String localname, FanOutSitOut why) {
    final newReason = _multiServerExcludedWhy[localname] != why;
    _multiServerExcludedWhy[localname] = why;
    if (_multiServerExcluded.add(localname) || newReason) {
      customState.add(CustomEvent(autoDJServer));
    }
  }

  // Which model each server answers in, by localname — the handshake mStream
  // #929 expects before a vector is sent, cached so a session pays one GET
  // per server every few minutes rather than one per pick.
  final SessionModelCache _fanOutModels = SessionModelCache();

  // The last multi-server setting the tunnel reconcile was told about, so
  // only its edges cost a reconcile (AutoDJManager notifies on every change).
  bool _fanOutWasOn = false;
  bool _fanOutMoodWasSet = false;
  String _fanOutServersWere = '';

  /// Play from's servers as one comparable value: All servers, or the
  /// localnames chosen in any order.
  static String _fanOutChoice(AutoDJManager mgr) => mgr.playFromAll
      ? '*'
      : ([...mgr.playFromServers]..sort()).join('\n');

  /// What the multi-server session may ask right now, for the tunnel
  /// manager: nothing unless the DJ is armed with the mode on. Servers whose
  /// discovery flag is still unknown are included — a Quick Connect server
  /// never reached has no flags yet, and its tunnel coming up is exactly
  /// what lets the capability refresh learn them.
  Iterable<Server> _djFanOutServers() {
    if (autoDJServer == null || !AutoDJManager().multiServerEnabled) {
      return const <Server>[];
    }
    return _fanOutCandidates(allowUnknownDiscovery: true);
  }

  /// Whether [localname] is one of this session's servers ([inFanOut] on
  /// the live Play from).
  bool _inSession(String localname) {
    final mgr = AutoDJManager();
    return inFanOut(localname,
        all: mgr.playFromAll,
        chosen: mgr.playFromServers,
        dj: autoDJServer?.localname);
  }

  /// [fanOutCandidates] on the live state: the server list, Play from, this
  /// session's drops and the mood.
  List<Server> _fanOutCandidates({bool allowUnknownDiscovery = false}) {
    final mgr = AutoDJManager();
    return fanOutCandidates(ServerManager().serverList,
        all: mgr.playFromAll,
        chosen: mgr.playFromServers,
        dj: autoDJServer?.localname,
        excluded: _multiServerExcluded,
        allowUnknownDiscovery: allowUnknownDiscovery,
        moodSet: mgr.activeMoodFilter != null);
  }

  /// The servers out of [servers] that a session across several may ask:
  /// the ones Play from names — every one with [all], else those in
  /// [chosen], and always the DJ's own ([dj], a localname) — that may take
  /// part ([canJoinMultiServer]). A server left out of Play from is never
  /// asked, however able. Pure; unit-tested.
  static List<Server> fanOutCandidates(Iterable<Server> servers,
          {required bool all,
          required Iterable<String> chosen,
          required String? dj,
          required Set<String> excluded,
          bool allowUnknownDiscovery = false,
          bool moodSet = false}) =>
      [
        for (final s in servers)
          if (inFanOut(s.localname, all: all, chosen: chosen, dj: dj) &&
              canJoinMultiServer(s, excluded,
                  allowUnknownDiscovery: allowUnknownDiscovery,
                  moodSet: moodSet))
            s,
      ];

  /// Whether [localname] is one of a session's servers: every server with
  /// [all], else the ones [chosen] names — and always the DJ's own ([dj]).
  /// Pure; unit-tested.
  static bool inFanOut(String localname,
          {required bool all,
          required Iterable<String> chosen,
          required String? dj}) =>
      all || localname == dj || chosen.contains(localname);

  /// The playing track as an anchor for a session across several servers:
  /// its [path] and [server], when that server is one of the session's
  /// ([inSession]) — any of them, the DJ's own included. Null for a track
  /// from elsewhere, or one with no server behind it (a local file). Pure;
  /// unit-tested.
  static ({String path, String server})? fanOutCurrentSeed(
      {String? path,
      Object? server,
      required bool Function(String) inSession}) {
    final p = _normSonicPath(path);
    if (p == null || server is! String || !inSession(server)) return null;
    return (path: p, server: server);
  }

  /// Re-evaluate the tunnel targets after something changed what the session
  /// may ask (arm, disarm, an exclusion). No-op while the mode is off: the
  /// session never contributed a target then, and the mode's own edge is
  /// handled where it is observed (see _init).
  void _reconcileFanOutTunnels(String reason) {
    if (!AutoDJManager().multiServerEnabled) return;
    unawaited(ServerManager().ensureTunnels(reason: reason));
  }

  // Each OTHER server's ignoreList, by localname (the DJ's own server keeps
  // using [jsonAutoDJIgnoreList], shared with the single-server path). The
  // list is server-issued track ids, so it only means anything back on the
  // server that issued it: one shared list would exclude unrelated tracks
  // everywhere else and lose the cooldown wherever the winner moved. Only
  // the winner's list advances — the other servers' picks were never played.
  final Map<String, dynamic> _multiServerIgnore = {};

  /// Servers that could contribute to a multi-server session right now: the
  /// ones Play from names that may take part.
  List<Server> multiServerCandidates() => _fanOutCandidates();

  /// Whether [s] may take part in a multi-server session: not dropped this
  /// session ([excluded]), not a peer the user hid or its parent stopped
  /// listing, discovery on with vectors to answer from, and a version not
  /// known to predate the vector seed. A federated peer qualifies like any
  /// other server — random-songs and the embeddings route are on the
  /// federation allowlist (mStream #946) and its picks stream the way a
  /// browsed peer track does. The raw engine flags decide (Server.discoveryOn
  /// / discoveryReady), not the UI flag a peer carries pinned: a server that
  /// says discovery is off, or on with nothing analysed yet (mStream #879),
  /// sits out. One that has never reported passes only with
  /// [allowUnknownDiscovery] (the tunnel targets, where reaching it is what
  /// fills the flags in) — or when it is a peer, whose federation/health
  /// answer the model handshake reads before anything is sent. While a mood
  /// is set ([moodSet]) it must also be able to filter by it
  /// (Server.moodFiltersAvailable, pinned off for a peer): any other server
  /// would answer from outside the mood. Pure; unit-tested.
  static bool canJoinMultiServer(Server s, Set<String> excluded,
          {bool allowUnknownDiscovery = false, bool moodSet = false}) =>
      sitOutReason(s, excluded,
          allowUnknownDiscovery: allowUnknownDiscovery, moodSet: moodSet) ==
      null;

  /// Why [s] may not take part ([canJoinMultiServer]'s rules), or null when
  /// it may. [why] names the reason a server in [excluded] was dropped.
  /// Pure; unit-tested.
  static FanOutSitOut? sitOutReason(Server s, Set<String> excluded,
      {Map<String, FanOutSitOut> why = const {},
      bool allowUnknownDiscovery = false,
      bool moodSet = false}) {
    if (excluded.contains(s.localname)) {
      return why[s.localname] ?? FanOutSitOut.unreachable;
    }
    if (!s.isSelectable) return FanOutSitOut.unreachable;
    final on = s.discoveryOn;
    if (on == false) return FanOutSitOut.discoveryOff;
    if (s.discoveryReady == false) return FanOutSitOut.scanning;
    if (on == null && !s.isFederated && !allowUnknownDiscovery) {
      return FanOutSitOut.unreachable;
    }
    if (moodSet) {
      final mood = s.moodFiltersAvailable;
      if (mood == false) return FanOutSitOut.noMood;
      if (mood == null && !allowUnknownDiscovery) return FanOutSitOut.noMood;
    }
    if (crossServerSeedKnownUnsupported(
        ServerVersion.tryParse(s.serverVersion))) {
      return FanOutSitOut.olderServer;
    }
    return null;
  }

  /// [sitOutReason] as the Auto DJ screen shows it, [tunnelUp] saying whether
  /// a server's tunnel is live. A Quick Connect server nothing has dialed
  /// yet has had no chance to report its flags: it is on its way, not
  /// unreachable, so — as for the tunnel targets — flags it never reported
  /// don't count against it until its tunnel is up. The pick itself stays
  /// strict ([multiServerCandidates]). Pure; unit-tested.
  static FanOutSitOut? shownSitOut(Server s, Set<String> excluded,
          {Map<String, FanOutSitOut> why = const {},
          required bool Function(Server) tunnelUp,
          bool moodSet = false}) =>
      sitOutReason(s, excluded,
          why: why,
          allowUnknownDiscovery: s.isIrohTransport && !tunnelUp(s),
          moodSet: moodSet);

  /// Why [s] is not taking part in a multi-server session right now, or null
  /// when it is — the Auto DJ screen's Play from sheet, by each server.
  FanOutSitOut? multiServerSitOut(Server s) => shownSitOut(
      s, _multiServerExcluded,
      why: _multiServerExcludedWhy,
      tunnelUp: ServerManager().tunnelServes,
      moodSet: AutoDJManager().activeMoodFilter != null);

  // ── Auto DJ seeds: the Seeds page's surface ────────────────────────────
  //
  // What the Seeds page, the Auto DJ screen's Seeds row and quick config read
  // and do (the sets themselves sit with the sonic fields). Every edit goes
  // through the pure model and ends in _publishSeeds, so [seedsStream] hears
  // of it. What the page may offer also hangs on the DJ's state, Play from
  // and the servers' flags ([seedServers], [seedsTakeNegatives],
  // [seedAddServers]), so it rebuilds on customState, AutoDJManager's
  // changes and ServerManager's capabilityChanges as well.

  /// The seeds as the page shows them ([seeds]), re-sent on every change: an
  /// edit, a mode switch, a lane edge, a pick that starts playing, a skip, a
  /// row running out of time.
  ValueStream<AutoDjSeeds> get seedsStream => _seedsSubject.stream;

  /// The seeds as the page shows them: the live set, merged with the rows
  /// held aside (the DJ off, or on before its lane's first pick), until that
  /// pick takes them in. So those rows never vanish at Start.
  AutoDjSeeds get seeds => _seedsView(DateTime.now());

  /// [song] added to [list] by the user (Add song), pinned. It lands in the
  /// held-aside set while one is held, or in a new one while the DJ is off
  /// or its lane has not picked yet ([seedAddHeldAside]), since Start, a
  /// seeded start's own clear and a Play from here all reset the live set;
  /// otherwise in the live set. Nothing happens when the list the page shows
  /// can't take a row ([AutoDjSeeds.canAdd], the test that disables Add
  /// song), so an add held aside can't push a row out of the merged view
  /// either.
  void seedAdd(SeedList list, TrackFacts song) {
    final now = DateTime.now();
    if (!_seedsView(now).canAdd(list)) return;
    final pending = _pendingSeeds;
    if (seedAddHeldAside(
        held: pending != null,
        armed: autoDJServer != null,
        lanePicked: _lanePicked)) {
      _pendingSeeds =
          (pending ?? _freshSeeds()).addManual(list, song, now: now);
    } else {
      _seeds = _seeds.addManual(list, song, now: now);
    }
    _publishSeeds();
    // A session across several servers sends a Less like song to the
    // servers that don't hold it as its vector, fetched now.
    if (list == SeedList.lessLike) unawaited(_ensureNegativeVectors());
  }

  /// The row [key] removed from [list] by the user, in whichever of the
  /// held-aside and the live set hold it there (both, when both do).
  void seedRemove(SeedList list, String key) =>
      _editSeeds(list, key, (s) => s.remove(list, key));

  /// The row [key] moved by the user to the other list, where it is pinned.
  /// It moves out of the list the page shows it in, in each set that holds it
  /// there; a set that already has it in the other list is left to the
  /// merge, where the held-aside row wins. Nothing happens when the other
  /// list can't take a row, the test that disables the menu item.
  void seedMove(String key) {
    final now = DateTime.now();
    final view = _seedsView(now);
    final SeedList from;
    if (view.has(SeedList.moreLike, key)) {
      from = SeedList.moreLike;
    } else if (view.has(SeedList.lessLike, key)) {
      from = SeedList.lessLike;
    } else {
      return;
    }
    final to =
        from == SeedList.moreLike ? SeedList.lessLike : SeedList.moreLike;
    if (!view.canAdd(to)) return;
    _editSeeds(from, key, (s) => s.move(key, now: now));
    // As for Add song: a row moved into Less like needs its vector.
    if (to == SeedList.lessLike) unawaited(_ensureNegativeVectors());
  }

  /// The row [key] in [list] pinned or unpinned by the user, in whichever set
  /// holds it there. Stay close keeps every stored pin as it is until Drift
  /// gives them back ([AutoDjSeeds.setPinned]).
  void seedPin(SeedList list, String key, bool pinned) {
    final now = DateTime.now();
    _editSeeds(list, key, (s) => s.setPinned(list, key, pinned, now: now));
  }

  // [edit] applied to each set that holds [key] in [list] (the held-aside
  // one, the live one, or both), then the page told when anything changed.
  void _editSeeds(
      SeedList list, String key, AutoDjSeeds Function(AutoDjSeeds) edit) {
    var changed = false;
    final pending = _pendingSeeds;
    if (pending != null && pending.has(list, key)) {
      final next = edit(pending);
      changed |= !identical(next, pending);
      _pendingSeeds = next;
    }
    if (_seeds.has(list, key)) {
      final next = edit(_seeds);
      changed |= !identical(next, _seeds);
      _seeds = next;
    }
    if (changed) _publishSeeds();
  }

  /// Drift or Stay close, from the Seeds page. The mode is stored
  /// ([AutoDJManager.setSonicAnchorMode]), the live and the held-aside set
  /// both freeze or thaw with it, and, as after any change to the sonic
  /// settings, a session that dropped sonic gets another go
  /// ([_retrySonicBookkeeping]). The page is told once. Nothing happens when
  /// the mode is already [mode].
  Future<void> setSeedMode(SonicAnchorMode mode) async {
    final mgr = AutoDJManager();
    if (mgr.sonicAnchorMode == mode) return;
    // The setter stores the mode before its first await, so the sets below
    // and the prune in _publishSeeds already see the new one. Only the write
    // to disk is waited for, last, so the page hears of the switch at once.
    final saved = mgr.setSonicAnchorMode(mode);
    final now = DateTime.now();
    final lock = mode == SonicAnchorMode.locked;
    _seeds = lock ? _seeds.freeze(now) : _seeds.thaw(now);
    final pending = _pendingSeeds;
    if (pending != null) {
      _pendingSeeds = lock ? pending.freeze(now) : pending.thaw(now);
    }
    // Into Stay close: the lane stays close to the rows it froze, and with
    // none its next pick takes in one song to start ([_stayCloseAnchored]).
    if (lock) {
      _stayCloseAnchored = false;
      _stayCloseAdmitted = false;
    }
    _retrySonicBookkeeping();
    _publishSeeds();
    await saved;
  }

  /// The servers a seed may come from right now, the home first: the DJ's
  /// own server (Play from's home while the DJ is off), or, in a session
  /// across several servers, every server of the session ([_inSession]; Play
  /// from's set while the DJ is off) that the picker still offers. The Seeds
  /// page reads it, through [seedAddServers], as it builds and when Add song
  /// opens, so it is a plain call, not a stream.
  List<Server> seedServers() {
    final dj = autoDJServer;
    if (!AutoDJManager().multiServerEnabled) {
      final home = dj ?? autoDjPlayFrom();
      return [?home];
    }
    if (dj == null) {
      final home = autoDjPlayFrom();
      return [
        ?home,
        for (final s in autoDjPlayFromSet())
          if (s.localname != home?.localname) s,
      ];
    }
    return [
      dj,
      for (final s in ServerManager().serverList)
        if (s.localname != dj.localname &&
            s.isSelectable &&
            _inSession(s.localname))
          s,
    ];
  }

  /// Whether a server a seed may come from ([seedServers]) takes Less like
  /// negatives ([Server.lessLikeUsable]). While none does, the Seeds page
  /// dims its Less like card and the Auto DJ screen its Learn from skips row,
  /// and no skip is learned.
  bool get seedsTakeNegatives => seedServers().any((s) => s.lessLikeUsable);

  /// The servers a seed may come from ([seedServers], the home first) whose
  /// songs the lane can use in [list], which is what Add song offers and a
  /// row's move into [list] needs ([seedAddServersFor]): every one while the
  /// DJ is off; for More like the DJ's own server and, across several
  /// servers, the ones the fan-out may take a vector from; for Less like the
  /// ones the next pick sends negatives to ([_negativeTargets]) and, across
  /// several servers, the ones whose songs' vectors go to another server
  /// there that takes them. Another server's Less like rows go out only on a
  /// pick across the servers, so a pick that can't go across them leaves
  /// them waiting for the next one that does. A plain call, cheap enough for
  /// the page's build.
  List<Server> seedAddServers(SeedList list) => seedAddServersFor(
      list, seedServers(),
      dj: autoDJServer?.localname,
      multiServer: AutoDJManager().multiServerEnabled,
      canSeed: (s) => canJoinMultiServer(s, _multiServerExcluded),
      negativeTargets: _negativeTargets());

  /// Every song in a random-songs answer with its own similarity. A batch
  /// answer (mStream #966) carries `sonic.similarities` aligned with `songs`;
  /// a server from before batches reports only the first song's `similarity`.
  /// A song without a score competes with -1, so it never beats a scored one.
  ///
  /// [avoided]: the server flagged the song as like one of the Less like
  /// negatives the body carried (mStream #1108, `lessLike.avoided`). That
  /// list is aligned with `songs` as the server sent them, so it is read by
  /// the song's own index there: a row that is not an object is skipped
  /// here, and pairing the flags by output position would move them onto
  /// the wrong songs. False when the echo, the list, the entry or its bool is
  /// missing, as from a server that took no negatives. Pure; unit-tested.
  static List<({Map<String, dynamic> song, double similarity, bool avoided})>
      scoredSongs(Map<String, dynamic> decoded) {
    final songs = decoded['songs'];
    if (songs is! List) return const [];
    final sonic = decoded['sonic'];
    final sims = sonic is Map ? sonic['similarities'] : null;
    final single = sonic is Map ? sonic['similarity'] : null;
    final echo = decoded['lessLike'];
    final flags = echo is Map ? echo['avoided'] : null;
    final out =
        <({Map<String, dynamic> song, double similarity, bool avoided})>[];
    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      if (song is! Map) continue;
      var sim = -1.0;
      if (sims is List && i < sims.length && sims[i] is num) {
        sim = (sims[i] as num).toDouble();
      } else if (i == 0 && single is num) {
        sim = single.toDouble();
      }
      out.add((
        song: Map<String, dynamic>.from(song),
        similarity: sim,
        avoided: flags is List && i < flags.length && flags[i] == true,
      ));
    }
    return out;
  }

  /// The [n] best of [items] by [similarity], best first. Equal scores keep
  /// their order — List.sort is not stable, so the order is pinned by index —
  /// which is what lets the server asked first win a tie.
  ///
  /// With [avoided], every song it flags ranks after every song it doesn't,
  /// whatever their scores, and by similarity among themselves. Each server
  /// ranks its own answer that way, its avoided songs last; a merge across
  /// servers by cosine alone would throw that away, and a song like one the
  /// user skipped on one server would beat a clean one from another.
  /// Pure; unit-tested.
  static List<T> bestBySimilarity<T>(
      List<T> items, double Function(T) similarity, int n,
      {bool Function(T)? avoided}) {
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      if (avoided != null) {
        final x = avoided(a.$2);
        if (x != avoided(b.$2)) return x ? 1 : -1;
      }
      final c = similarity(b.$2).compareTo(similarity(a.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed.take(n < 1 ? 1 : n)) e.$2];
  }

  // The reasons the fan-out has already explained this session, so a session
  // that keeps running single-server says why once, not per pick.
  final Set<String> _fanOutDeclined = {};

  // Once per session: sonic wanted on a server whose scan has not produced
  // vectors yet (see _autoDJPick).
  bool _sonicNotReadyLogged = false;

  /// The multi-server pick is not running this time, for [reason]. Logged the
  /// first time each reason comes up in a session: otherwise a mode switched
  /// on that quietly does nothing is indistinguishable from the mode working.
  bool _fanOutDecline(String reason) {
    if (_fanOutDeclined.add(reason)) {
      appLog('[dj] multi-server: not this pick — $reason');
    }
    return false;
  }

  /// The embedding of every live Less like row that has none, fetched from
  /// the server that holds its song, one path per call, since one dead or
  /// unanalysed path costs the embeddings route the whole batch. A session
  /// across several servers sends a Less like song to the servers that don't
  /// hold it as this vector (`lessLikeVectors`, [AutoDjSeeds.negativesFor]),
  /// so each answer is cached on its row ([AutoDjSeeds.withVector]) while
  /// the lane and the row are still there. A row whose vector never comes
  /// is just not sent to them.
  ///
  /// Only while the DJ is on with the mode on: a single-server body sends
  /// paths alone. Asked whenever a row can have come in without one: a quick
  /// skip, Add song and a move into Less like, the lane's first pick (which
  /// takes in the rows held aside), and the start of every pick across
  /// several servers. A row whose fetch is running is not asked again. The
  /// future completes when every fetch this call started or found running
  /// is done, and never fails.
  Future<void> _ensureNegativeVectors() {
    if (autoDJServer == null || !AutoDJManager().multiServerEnabled) {
      return Future<void>.value();
    }
    final epoch = _djSessionEpoch;
    final waits = <Future<void>>[];
    for (final row in _seeds.lessLike) {
      if (row.vector != null) continue;
      final running = _negativeVectorFetches[row.key];
      if (running != null && running.epoch == epoch) {
        waits.add(running.done);
        continue;
      }
      final owner = _seedOwner(row.server);
      if (owner == null) continue;
      final done = _fetchNegativeVector(owner, row.key, row.wirePath, epoch);
      _negativeVectorFetches[row.key] = (epoch: epoch, done: done);
      waits.add(done);
    }
    if (waits.isEmpty) return Future<void>.value();
    return Future.wait(waits).then((_) {});
  }

  /// One Less like row's vector ([_ensureNegativeVectors]): [wirePath] on
  /// [owner], cached on the row [key] when it comes back in lane [epoch].
  Future<void> _fetchNegativeVector(
      Server owner, String key, String wirePath, int epoch) async {
    try {
      final got = await ApiManager().fetchEmbeddings(owner, [wirePath]);
      if (got == null || epoch != _djSessionEpoch) return;
      final vector = seedVectorBase64(got.vectors, got.dim);
      if (vector == null || !_seeds.has(SeedList.lessLike, key)) return;
      final next = _seeds.withVector(key, vector, got.modelId);
      if (identical(next, _seeds)) return;
      _seeds = next;
      _publishSeeds();
    } catch (e) {
      verboseLog('[dj] less like vector from ${owner.localname} failed: $e');
    } finally {
      if (_negativeVectorFetches[key]?.epoch == epoch) {
        _negativeVectorFetches.remove(key);
      }
    }
  }

  /// Average the seed tracks' embeddings into one unit vector.
  ///
  /// Fetched from the server that OWNS each seed — that's the whole point:
  /// the anchor may hold tracks from several servers, and averaging them is
  /// what makes the session one session rather than several running side by
  /// side. Each of [seeds] names its server ([fanOutSeeds]); one whose
  /// server is gone is skipped ([_seedOwner]). Null when nothing usable came
  /// back, which drops this pick to the single-server path rather than
  /// playing something unrelated. [foreign]: a vector came from another
  /// server than the DJ's own — a sound the single-server path, which seeds
  /// by filepath, can't carry.
  ///
  /// Each server says of each of its paths whether it has the song's vector,
  /// has the song but not analysed yet, or has no such song
  /// ([ApiManager.readEmbeddings]). The paths it says it can't use (gone,
  /// not analysed) leave the lane's requests ([_dropSeedCulprits]), a path
  /// asked about alone as well. One dead path costs its server's whole batch
  /// (the route's uniform 404 names none), so only such a batch is asked
  /// again one path at a time, and the paths that answer serve this pick.
  /// A server that did not answer (a timeout, a dropped connection) or
  /// answered about itself (discovery off) sat this pick out, as before:
  /// nothing of it is marked, and it is not asked again, which would only
  /// make the pick wait out the same silence twice. [epoch] is the lane the
  /// pick belongs to: a later lane's seeds are not this pick's to change.
  Future<({String modelId, String base64, bool foreign})?> _multiServerSeed(
      List<({String server, String path})> seeds,
      {required int epoch}) async {
    if (seeds.isEmpty) return null;
    final byServer = <Server, List<String>>{};
    for (final s in seeds) {
      final owner = _seedOwner(s.server);
      if (owner == null) continue;
      byServer.putIfAbsent(owner, () => []).add(s.path);
    }

    String? modelId;
    int? dim;
    var foreign = false;
    final vectors = <Float32List>[];
    final refused = <String>{};
    for (final entry in byServer.entries) {
      final paths = entry.value;
      var read = await ApiManager().readEmbeddings(entry.key, paths);
      if (read.someGone && paths.length > 1) {
        read = EmbeddingsReading.ofProbes(await Future.wait([
          for (final p in paths) ApiManager().readEmbeddings(entry.key, [p]),
        ]));
      }
      for (var i = 0; i < paths.length; i++) {
        if (read.refuses(i)) {
          refused.add(seedKey(entry.key.localname, paths[i]));
        }
      }
      final got = read.found;
      if (got == null) continue;
      // Mixing model spaces would average vectors that mean different
      // things — worse than using fewer seeds.
      if (modelId == null) {
        modelId = got.modelId;
        dim = got.dim;
      } else if (got.modelId != modelId || got.dim != dim) {
        appLog('[dj] seed from ${entry.key.localname} is model '
            '${got.modelId}, session is $modelId — skipped');
        continue;
      }
      vectors.addAll(got.vectors);
      if (entry.key.localname != autoDJServer?.localname) foreign = true;
      // The answer names the owner's model space — that server's handshake
      // is done without a health call.
      _fanOutModels.record(entry.key.localname, got.modelId, DateTime.now());
    }
    if (refused.isNotEmpty && epoch == _djSessionEpoch) {
      _dropSeedCulprits(refused, 'gone or not analysed on their server');
    }
    if (modelId == null || dim == null) return null;
    // The mean of near-opposite anchors can collapse to zero; the server
    // would refuse it, so don't spend the round trip (null here).
    final base64 = seedVectorBase64(vectors, dim);
    if (base64 == null) return null;
    return (modelId: modelId, base64: base64, foreign: foreign);
  }

  /// The server a seed's song is on, by the localname its row (or the
  /// fallback anchor) names. Null once that server is gone, removed or
  /// renamed: the seed is skipped then, never handed to the DJ's own server
  /// the way the old owners map did, since its path names nothing there and
  /// one such path 404s that server's whole embeddings batch.
  Server? _seedOwner(String localname) =>
      ServerManager().byLocalname(localname);

  /// Whether the single-server body can carry the More like row [s]: one on
  /// the DJ's own server ([dj], a localname), the only one that can read its
  /// path, and never one a server refused this lane ([_seedUnusable]).
  bool _carriedHere(AutoDjSeed s, String dj) =>
      !_seedUnusable.contains(s.key) && s.server == dj;

  /// Whether a pick across several servers can carry the More like row [s]
  /// ([seedCarriedAcross]): never one a server refused this lane, and one on
  /// any server of the session that is still there and can hand out its
  /// song's vector at all (discovery on and scanned, not dropped this
  /// session, new enough). A row on a server that never could would hold
  /// off Stay close's one song, and Drift's fallback to the playing track,
  /// for the whole lane.
  bool _carriedAcross(AutoDjSeed s, String dj) => seedCarriedAcross(s,
      dj: dj,
      owner: _seedOwner,
      inSession: _inSession,
      canSeed: (owner) => canJoinMultiServer(owner, _multiServerExcluded),
      unusable: _seedUnusable);

  /// Whether the route a pick tries first can carry [s]: the pick across
  /// several servers when the session spans them ([_carriedAcross]), else
  /// the single-server body ([_carriedHere]). Stay close judges its lane by
  /// it: the rows it has to stay close to and the song it would take in
  /// ([stayCloseAdmit]), and what is left after a server refuses a row
  /// ([_dropSeedCulprits]).
  bool _seedCarried(AutoDjSeed s, String dj) =>
      AutoDJManager().multiServerEnabled
          ? _carriedAcross(s, dj)
          : _carriedHere(s, dj);

  /// An anchor row (the song a Stay close lane admitted to start) on another
  /// server than the DJ's is the cross-server pick's alone. When that pick
  /// can't carry it — nobody to ask, no vector from its server — Drift lets
  /// it go, so a row nothing can send stops holding off Drift's fallback to
  /// the explicit seed or the playing track. Only an anchor the engine
  /// admitted: one the user pinned stays theirs, and so does an anchor on
  /// the DJ's own server, which the single-server body still carries (a
  /// network blip or a timeout must not move it).
  ///
  /// Nothing while the lists are frozen: Stay close never takes a row out.
  /// The anchor stays listed, the single-server pick falls back for itself
  /// alone while it can't be carried ([stayCloseFallsBack]), and the user
  /// removes it if they want it gone.
  void _dropForeignAnchor(String why) {
    if (_seeds.frozen) return;
    final dj = autoDJServer?.localname;
    final gone = [
      for (final s in _seeds.moreLike)
        if (s.origin == SeedOrigin.anchor && !s.pinned && s.server != dj) s,
    ];
    if (gone.isEmpty) return;
    _seeds = _seeds.withoutKeys({for (final s in gone) s.key});
    _publishSeeds();
    appLog('[dj] multi-server: let go of the anchor on '
        '${gone.map((s) => s.server).toSet().join(', ')} — $why');
  }

  /// The More like rows [keys] that a server refused as sonic seeds: gone
  /// from its library, or not analysed yet ([why] says how it showed). A row
  /// the page shows pinned stays on it but leaves this lane's requests
  /// ([_seedUnusable]); any other row is dropped ([AutoDjSeeds.culprits]).
  /// In Drift that drops an engine row (a pick, the opener, an anchor), the
  /// way the old ring let such a path rotate out, and keeps a row the user
  /// pinned, since it is theirs to remove. In Stay close every row shows
  /// pinned, so the engine takes none out: a dead row stays listed and
  /// unusable until the user removes it. Nor does a lane that took in its
  /// one song take another in its place ([_stayCloseAdmitted]). But a lane
  /// that has not, whose last row it could carry this set aside (a row it
  /// carried over, a song the user added, that the server turned down), had
  /// nothing to stay close to after all: it looks for its one song again,
  /// and its next pick takes in the explicit seed or the playing track
  /// beside the refused rows ([stayCloseReleases]). The user's removals
  /// never come through here, so a list the user emptied stays empty. Keys
  /// that name no More like row (a fallback seed, a row the user removed
  /// meanwhile) are passed over. A server has judged the song this lane's
  /// start blended in when [keys] name it, so a later refusal no probe
  /// explains is no longer laid on it ([_laneBlendKey]). Every caller checks
  /// the pick's lane first, so a late answer never touches a newer lane.
  /// Returns whether any row was dropped or newly set aside.
  bool _dropSeedCulprits(Set<String> keys, String why) {
    if (keys.contains(_laneBlendKey)) _laneBlendKey = null;
    final verdict = _seeds.culprits(keys);
    final setAside = [
      for (final k in verdict.setAside)
        if (_seedUnusable.add(k)) k,
    ];
    if (verdict.drop.isEmpty && setAside.isEmpty) return false;
    if (verdict.drop.isNotEmpty) {
      _seeds = _seeds.withoutKeys(verdict.drop);
      _publishSeeds();
    }
    appLog('[dj] sonic seed(s) $why — ${verdict.drop.length} dropped'
        '${setAside.isNotEmpty ? ', ${setAside.length} kept out of requests' : ''}');
    final dj = autoDJServer?.localname;
    if (_stayCloseAnchored &&
        setAside.isNotEmpty &&
        dj != null &&
        stayCloseReleases(
            frozen: _seeds.frozen,
            admitted: _stayCloseAdmitted,
            anyUsable: _seeds.moreLike.any((s) => _seedCarried(s, dj)))) {
      _stayCloseAnchored = false;
      appLog('[dj] stay close: no row left to stay close to — the next pick '
          'takes in one song');
    }
    return true;
  }

  /// Which of the More like [rows] a single-server body carried made
  /// [server] refuse it: its 404 "Track not found" ([gone]) and its 400
  /// "not analyzed yet" name no path. The rows at fault leave the lane's
  /// requests ([_dropSeedCulprits]). True when any was found, and the pick
  /// goes again without them; false hands the failure back: the pick lays
  /// it on the song its lane's start blended in when the body carried that
  /// song ([blendCulprit]), and otherwise to the usual handling, which costs
  /// this pick, or the session, its sonic seeds.
  ///
  /// One row sent is the one at fault. Of several, each is asked about on
  /// its own, all at once and only on this failure, so at most eight calls:
  /// after a 404, whether the server still has the track, where only its
  /// "no" counts (a question it can't answer keeps the row); after a 400,
  /// what the embeddings route says of it ([ApiManager.readEmbeddings]),
  /// where only "not analysed yet" and "no such track" count. A probe that
  /// timed out, or that the route answered about itself, blames no row.
  /// [epoch] is the lane the pick belongs to: a later lane's seeds are not
  /// this pick's to change.
  Future<bool> _healSonicSeeds(
      Server server, List<({String server, String path})> rows,
      {required bool gone, required int epoch}) async {
    if (rows.isEmpty) return false;
    final Set<String> faulty;
    if (rows.length == 1) {
      faulty = {seedKey(rows.single.server, rows.single.path)};
    } else if (gone) {
      final there = await Future.wait(
          [for (final r in rows) ApiManager().trackExists(server, r.path)]);
      faulty = {
        for (var i = 0; i < rows.length; i++)
          if (there[i] == false) seedKey(rows[i].server, rows[i].path),
      };
    } else {
      final read = await Future.wait([
        for (final r in rows) ApiManager().readEmbeddings(server, [r.path]),
      ]);
      faulty = {
        for (var i = 0; i < rows.length; i++)
          if (read[i].refuses(0)) seedKey(rows[i].server, rows[i].path),
      };
    }
    if (epoch != _djSessionEpoch || faulty.isEmpty) return false;
    _dropSeedCulprits(faulty,
        '${gone ? 'not found' : 'not analysed'} on ${server.localname}');
    // The rows at fault are out of the next body whatever that found to
    // change (a row the user removed meanwhile is out already), so the
    // attempt that follows always sends less than this one did.
    return true;
  }

  /// One pick, chosen across the eligible servers Play from names.
  ///
  /// Returns false when the session can't run this way right now (no seed, no
  /// eligible servers, nobody answered) — the caller then falls back to the
  /// ordinary single-server pick, so switching this on can never leave the
  /// queue empty where it would otherwise have filled.
  ///
  /// [seeds] are the pick's positive seeds, each with the server holding it
  /// ([fanOutSeeds]).
  ///
  /// [epoch] is the lane this pick belongs to (see [_djSessionEpoch]): a
  /// clear or a server switch while the servers are being asked makes the
  /// answer worthless, so it is dropped — false, and the caller checks the
  /// epoch itself before falling back. [gen] is the queue generation the
  /// pick was built under ([_djQueueGen]): a learned quick skip meanwhile
  /// makes the answer stale in the same way, and the pick is run again.
  Future<bool> _autoDJMultiServer(List<({String server, String path})> seeds,
      {required int epoch,
      required int gen,
      bool autoPlay = false,
      bool incrementIndex = false}) async {
    // Less like rows still without the vector the other servers take them
    // as: asked for now, for this pick if they come back in time, else for
    // the next one.
    unawaited(_ensureNegativeVectors());
    // A seed from another server than the DJ's is a sound the single-server
    // pick can't carry (it seeds by filepath), so any one server able to
    // answer is worth asking; with every seed the DJ's own, it takes two. A
    // seed whose server is gone counts for neither: nobody can read it.
    final foreignSeed = seeds.any((s) =>
        _seedOwner(s.server) != null && s.server != autoDJServer?.localname);
    final candidates = multiServerCandidates();
    if (candidates.isEmpty || (candidates.length < 2 && !foreignSeed)) {
      if (candidates.isEmpty) _dropForeignAnchor('nobody to ask');
      return _fanOutDecline('${candidates.length} eligible server(s) in Play '
          'from — the others lack discovery'
          '${AutoDJManager().activeMoodFilter != null ? ', mood filtering' : ''}'
          ' or a new enough version');
    }

    // A candidate whose tunnel is dialing right now — the session's targets
    // were just registered (see _djFanOutServers), or a drop is being
    // re-dialed — gets a few seconds rather than being passed over; usually
    // only the first pick after the mode came on pays this. A tunnel that is
    // down with no dial in flight is not waited for: its retry timer owns it,
    // and the server simply does not answer this pick.
    final dialing = candidates.where((s) {
      if (!s.isIrohTransport || ServerManager().tunnelServes(s)) return false;
      final st = ServerManager().tunnelStatusOf(s);
      return st == IrohTunnelStatus.connecting ||
          st == IrohTunnelStatus.reconnecting;
    }).toList();
    if (dialing.isNotEmpty) {
      verboseLog('[dj] multi-server: ${dialing.length} tunnel(s) still '
          'dialing — waiting briefly');
      await Future.wait(dialing.map((s) => ServerManager().awaitTunnelReady(
          server: s,
          timeout: const Duration(seconds: 8),
          extendWhileDialing: false,
          caller: 'dj-fanout')));
      if (epoch != _djSessionEpoch || gen != _djQueueGen) return false;
    }

    final seed = await _multiServerSeed(seeds, epoch: epoch);
    if (epoch != _djSessionEpoch || gen != _djQueueGen) return false;
    if (seed == null) {
      _dropForeignAnchor('no vector for it');
      return _fanOutDecline('no vector for the anchor (not analysed yet, or '
          'its server did not answer)');
    }
    // The model every server below answers in, and so the one a Less like
    // row's cached vector has to be in to reach them.
    _fanOutSeedModel = seed.modelId;

    // The model handshake, before anything is sent: every candidate's model
    // space, from federation/health (the anchors' owners already answered it
    // with their vectors), cached for a few minutes. A server indexed with
    // another model is dropped for the session — only a rescan changes that
    // — and one with no model to offer right now (discovery off there,
    // nothing analysed yet, not answering) sits this pick out and is asked
    // again after a while. Webapp parity (mStream #946), and what #929 asks
    // of a caller: reaching the server's model-mismatch 400 means a bug.
    final unknownModel = candidates
        .where((s) => _fanOutModels.lookup(s.localname, DateTime.now()) == null)
        .toList();
    if (unknownModel.isNotEmpty) {
      await Future.wait(unknownModel.map((s) async {
        final health = await ApiManager().fetchFederationHealth(s);
        _fanOutModels.record(s.localname, health?.modelId, DateTime.now());
        // Once per server per cache life: the drive log's only record of the
        // handshake, so a server that keeps sitting out can be explained.
        appLog(health == null
            ? '[dj] ${s.localname}: no health answer — sits this pick out'
            : health.modelId == null
                ? '[dj] ${s.localname}: no discovery model right now — sits '
                    'this pick out'
                : '[dj] ${s.localname} answers in model ${health.modelId} '
                    '(${health.analyzedCount} analysed)');
      }));
      if (epoch != _djSessionEpoch || gen != _djQueueGen) return false;
    }
    final eligible = <Server>[];
    for (final s in candidates) {
      final model = _fanOutModels.lookup(s.localname, DateTime.now())?.modelId;
      if (model == seed.modelId) {
        eligible.add(s);
      } else if (model == null) {
        verboseLog('[dj] ${s.localname} has no discovery model to answer '
            'with right now — sits this pick out');
      } else {
        _dropFromFanOut(s.localname, FanOutSitOut.otherModel);
        appLog('[dj] ${s.localname} indexes model $model, the session is '
            '${seed.modelId} — dropped from this session');
        _reconcileFanOutTunnels('dj-fanout');
      }
    }
    // Nothing to gain over the single-server pick when the DJ's own server
    // is the only one left and the seed is its own: that path seeds by
    // filepath, which the server can exclude from its own pool. A sound from
    // another server is one that path can't carry, so the DJ's server alone
    // still answers it here. One OTHER server alone is still a session worth
    // running — the DJ's may be the one with nothing to say.
    if (eligible.isEmpty ||
        (eligible.length == 1 &&
            eligible.first.localname == autoDJServer?.localname &&
            !seed.foreign)) {
      return _fanOutDecline(eligible.isEmpty
          ? 'no server answers in the seed\'s model space right now'
          : 'only the DJ\'s own server is in the seed\'s model space');
    }

    final mgr = AutoDJManager();
    // The mood every server below is asked under (libraryFilters sends it to
    // each, as candidates are only servers that can filter by it).
    final mood = mgr.activeMoodFilter;

    // What no server may answer with: the playing track, the picks just
    // played, everything queued after it, the More like rows, the seeds
    // themselves and the blended song the user quick-skipped
    // ([_laneSkippedBlend]), keyed "<localname>|<path>" because a path only
    // names a row on the server that holds it ([fanOutRecentKeys]). A vector
    // seed carries no hashes for the server to exclude on its own (the
    // filepath form's seeds are dropped from the pool server-side), and
    // ignoreList is only a soft cooldown that yields to the full pool once
    // it covers every candidate — so this guard lives here, and a server
    // offering a repeat is simply passed over.
    final skippedBlend = _laneSkippedBlend;
    final recent = fanOutRecentKeys(queue.value, index,
        moreLike: _seeds.moreLike,
        seeds: seeds,
        avoid: [
          if (skippedBlend != null)
            (server: skippedBlend.server, path: skippedBlend.path),
        ]);

    // Every server is asked at once — a session that waited for each in turn
    // would stall the queue on the slowest one. A server that times out or
    // errors simply doesn't compete for this pick.
    //
    // A server answers with a random row from its pool, so when every
    // answer is a repeat or blocked the ask is repeated a couple of times
    // with each server's own returned ignoreList fed back (the way the
    // single-server loop retries) before the pick is left to that loop —
    // otherwise a strict slider, whose pools are small, would keep turning
    // the session single-server. The fed-back lists stay transient: only
    // the winner's cooldown advances (below), its pick is the one played.
    final retryLists = <String, dynamic>{
      for (final s in eligible) s.localname: _ignoreListFor(s),
    };
    const maxAsks = 3;
    List<
        ({
          Server server,
          Map<String, dynamic> decoded,
          Map<String, dynamic> song,
          double similarity,
          bool avoided,
        })> scored = const [];
    var answered = 0;
    for (var ask = 0; ask < maxAsks && scored.isEmpty; ask++) {
      // A server dropped mid-pick (a model-space refusal) is not asked again.
      final round = eligible
          .where((s) => !_multiServerExcluded.contains(s.localname))
          .toList();
      if (round.isEmpty) return _fanOutDecline('every server was dropped');
      // A Less like row that ran out while the last round was out is not
      // sent in this one.
      _pruneSeeds();
      final answers = await Future.wait(round.map((server) async {
        // The Less like negatives this server takes (mStream #1108): its own
        // songs as paths, the other servers' as their vectors cached in the
        // session's model, which is the one this server answers in.
        final negatives = mgr.sonicSimilarityEnabled && server.lessLikeUsable
            ? _seeds.negativesFor(server.localname, modelId: seed.modelId)
            : null;
        final payload = <String, dynamic>{
          'ignoreList': retryLists[server.localname] ?? const [],
          'similarToVector': seed.base64,
          'similarToModelId': seed.modelId,
          'minSimilarity': mgr.sonicMinSimilarity,
          if (negatives != null)
            ...lessLikeParams(
                paths: negatives.paths,
                vectors: negatives.vectors,
                modelId: seed.modelId),
          // Each server's own library rules — rating, vpaths, genre — plus
          // the app-level ones that mean the same everywhere.
          ...mgr.libraryFilters(server),
          // Every server is asked for the whole batch; the best across all
          // of them are queued below.
          ...mgr.batchParams,
        };
        final filtered = ServerCapabilities().filter(server, payload);
        try {
          final res = await http
              .post(
                server.apiUri('/api/v1/db/random-songs'),
                headers: {
                  'Content-Type': 'application/json',
                  'x-access-token': server.authToken ?? '',
                },
                body: jsonEncode(filtered.body),
              )
              .timeout(const Duration(seconds: 12));
          if (res.statusCode > 299) {
            // A model-space refusal is permanent for this session: the
            // library is indexed with a different model and rescanning is
            // the only cure, so stop asking rather than burning a request
            // per pick.
            if (res.statusCode == 400 &&
                res.body.contains('Sonic seed is from model')) {
              // The handshake above should have caught this; a stale cache
              // (a rescan under a new model) still ends here.
              _dropFromFanOut(server.localname, FanOutSitOut.otherModel);
              _fanOutModels.record(server.localname, null, DateTime.now());
              appLog('[dj] ${server.localname} indexes a different embedding '
                  'model — dropped from this session');
              _reconcileFanOutTunnels('dj-fanout');
            } else {
              // A schema rejection names the key (the single-server loop's
              // learner): the next round sends a body without it. When the
              // key is the vector seed itself the server cannot take part
              // at all, so it is dropped for the session rather than
              // re-asked — and 400'd — on every pick.
              final learned =
                  ServerCapabilities().noteRejection(server, res.body);
              if (learned == 'similarToVector' ||
                  learned == 'similarToModelId') {
                _dropFromFanOut(server.localname, FanOutSitOut.olderServer);
                appLog('[dj] ${server.localname} does not take a vector '
                    'seed — dropped from this session');
                _reconcileFanOutTunnels('dj-fanout');
              }
            }
            return null;
          }
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          _logLessLikeEcho(server, decoded);
          final offered = scoredSongs(decoded);
          if (offered.isEmpty) return null;
          // An answer that does not echo the mood was picked from outside it
          // (the server lost its scores since it said it could filter, or
          // refused the key): it does not compete, however close it is. The
          // webapp's rule for a cross-server pick (mStream #1096).
          if (mood != null && !moodEchoFits(decoded['moods'], mood)) {
            verboseLog('[dj] ${server.localname} answered without the mood '
                '— passed over');
            return null;
          }
          // Whatever this answer's fate, the server has now seen its own
          // picks: its list is what a repeated round sends it.
          if (decoded['ignoreList'] is List) {
            retryLists[server.localname] = decoded['ignoreList'];
          }
          // Each song competes on its own. The ones this session may not
          // play — keyword-blocked, or a repeat of what is playing or
          // anchoring — are passed over; a server whose whole answer is
          // passed over still counts as having answered. A song keeps the
          // avoided flag read at its own place in the answer.
          final usable = <({
            Map<String, dynamic> song,
            double similarity,
            bool avoided
          })>[];
          var repeats = 0;
          for (final c in offered) {
            if (mgr.isKeywordBlocked(c.song)) continue;
            final path = _normSonicPath(c.song['filepath'] as String?);
            if (path == null || recent.contains('${server.localname}|$path')) {
              repeats++;
              continue;
            }
            usable.add(c);
          }
          if (repeats > 0) {
            verboseLog('[dj] ${server.localname} offered $repeats track(s) '
                'already in play or in the anchor — passed over');
          }
          return (server: server, decoded: decoded, usable: usable);
        } catch (e) {
          verboseLog('[dj] ${server.localname} did not answer: $e');
          return null;
        }
      }));
      // A learned quick skip while the servers were out: their answers were
      // chosen without its negative (the caller runs the pick again).
      if (epoch != _djSessionEpoch || gen != _djQueueGen) return false;
      final got = answers.nonNulls.toList();
      answered = got.length;
      // Nobody answered — asking again would not change that.
      if (got.isEmpty) break;
      scored = [
        for (final a in got)
          for (final c in a.usable)
            (
              server: a.server,
              decoded: a.decoded,
              song: c.song,
              similarity: c.similarity,
              avoided: c.avoided,
            ),
      ];
      if (scored.isEmpty && ask + 1 < maxAsks) {
        verboseLog('[dj] multi-server: every answer was a repeat or blocked '
            '— asking again (${ask + 2}/$maxAsks)');
      }
    }
    if (scored.isEmpty) {
      // Per pick, not per session: a round where nobody answered, or every
      // answer was a repeat, is worth a line each time.
      appLog('[dj] multi-server: not this pick — $answered answered, none '
          'usable after $maxAsks asks');
      return false;
    }

    // Best matches win. The whole reason for asking everyone is that one of
    // them holds something closer to the seed than the DJ's own server does
    // — and with a batch, one server may well supply all of it. A song a
    // server flagged as like a Less like row comes only after every clean
    // one, as it does in that server's own answer.
    final chosen = bestBySimilarity(scored, (c) => c.similarity,
        mgr.songsPerFetch, avoided: (c) => c.avoided);
    final best = chosen.first;
    final avoidedQueued = chosen.where((c) => c.avoided).length;

    appLog('[dj] multi-server: $answered/${eligible.length} answered, '
        '${scored.length} usable, queueing ${chosen.length}; best '
        '${best.similarity.toStringAsFixed(4)} from ${best.server.localname}'
        '${avoidedQueued > 0 ? '; $avoidedQueued like a Less like row' : ''}');

    // Only the cooldowns of servers whose songs are being queued advance —
    // the others' answers were not played. A contributing server's list also
    // carries the ids of its songs that lost to a better match elsewhere; the
    // cooldown is soft variety, and they cycle back out. The DJ's own server
    // shares its list with the single-server path, so a fallback pick later
    // continues the same cooldown rather than starting a fresh one.
    final advanced = <String>{};
    for (final c in chosen) {
      if (!advanced.add(c.server.localname)) continue;
      if (c.server.localname == autoDJServer?.localname) {
        jsonAutoDJIgnoreList = c.decoded['ignoreList'];
      } else {
        _multiServerIgnore[c.server.localname] = c.decoded['ignoreList'];
      }
    }

    // A pick landed: the same bookkeeping the single-server path does on a
    // working response — nothing is owed, and the outage log re-arms.
    _djPickPending = false;
    _djFailLogged = false;
    _deferredPickFailures = 0;
    _autoDJAuthWarned = false;

    await _queueAutoDJSongs(
        [for (final c in chosen) (song: c.song, source: c.server)],
        epoch: epoch,
        gen: gen,
        autoPlay: autoPlay,
        incrementIndex: incrementIndex,
        sonicPick: true);
    return true;
  }

  /// The server's word on the Less like negatives a body carried (mStream
  /// #1108): how many it used and how many it ignored (a path it can't
  /// resolve, a vector in another model), the similarity a song had to reach
  /// to count as like one, and how many of the songs it answered with did.
  /// For the verbose log only. A server that took none sends no echo.
  static void _logLessLikeEcho(Server server, Map<String, dynamic> decoded) {
    final echo = decoded['lessLike'];
    if (echo is! Map) return;
    final flags = echo['avoided'];
    final like = flags is List ? flags.where((a) => a == true).length : 0;
    verboseLog('[dj] ${server.localname} less like: used ${echo['used']}, '
        'ignored ${echo['ignored']}, threshold ${echo['threshold']}; '
        '$like of ${flags is List ? flags.length : 0} answered like one');
  }

  /// The ignoreList to send [server]: the DJ's own server uses the list the
  /// single-server path maintains, every other server its own.
  dynamic _ignoreListFor(Server server) {
    if (server.localname == autoDJServer?.localname) {
      return jsonAutoDJIgnoreList ?? const [];
    }
    return _multiServerIgnore[server.localname] ?? const [];
  }

  // True while an autoDJ() fetch is in flight — overlapping runs share the
  // ignoreList (it only updates after the response), so two concurrent POSTs
  // can queue the same track twice on a narrow pool (sonic-locked / genre
  // filter / small library). The empty-queue start path provably overlaps:
  // its first pick's index-0 emit satisfies the last-item check in the
  // currentIndexStream listener while the explicit follow-up call runs.
  bool _djInFlight = false;

  /// Fetch and queue one Auto-DJ pick. Overlapping calls are dropped — safe,
  /// because every trigger (the follow-up call, the next last-item index
  /// emit) re-fires the top-up once the in-flight run lands.
  ///
  /// The one trigger that does not come back by itself is a learned quick
  /// skip's re-roll: the skip's own call is dropped while a pick is out, and
  /// that pick, chosen without the new negative, is thrown away where it
  /// would queue, or has just landed stale. So a call during which the
  /// queue's generation moved runs once more when it is done, while the
  /// re-roll is still owed and the lane the same. A deferred or failed pick
  /// is left to the tunnel's return or the next top-up instead, which land
  /// as the re-roll. It can't loop: a run is followed by another only when a
  /// further learned skip came while it was out.
  Future<void> autoDJ(
      {bool autoPlay = false, bool incrementIndex = false}) async {
    if (_djInFlight) return;
    _djInFlight = true;
    final epoch = _djSessionEpoch;
    final gen = _djQueueGen;
    try {
      await _autoDJPick(autoPlay: autoPlay, incrementIndex: incrementIndex);
    } finally {
      _djInFlight = false;
      if (shouldRerunPick(
          genAtEntry: gen,
          gen: _djQueueGen,
          rerolledGen: _rerolledGen,
          sameLane: _djSessionEpoch == epoch,
          armed: autoDJServer != null,
          pickPending: _djPickPending)) {
        unawaited(autoDJ());
      }
    }
  }

  Future<void> _autoDJPick(
      {bool autoPlay = false, bool incrementIndex = false}) async {
    if (autoDJServer == null) return;
    // Mid-clear, the queue still holds the rows being thrown away: a pick
    // now would open the new lane on them ([_clearingQueue]). The armed DJ
    // resumes once the user queues something, as after any clear.
    if (_clearingQueue) return;
    // The lane this call belongs to — checked when each response lands.
    final epoch = _djSessionEpoch;

    // The tunnel isn't serving the DJ server (an outage, or a dial in
    // flight): wait briefly rather than POSTing at a dead loopback. Not ready
    // → remember that a pick is owed; the tunnel's connected edge retries it
    // (_onTunnelReconnected), and a queue that ends meanwhile parks instead
    // of stopping (queueEndAction).
    final dj = autoDJServer!;
    if (shouldDeferDJPick(
        isIroh: dj.isIrohTransport,
        tunnelServes: ServerManager().tunnelServes(dj))) {
      // Owed from THIS moment, not from when the wait gives up: a track that
      // ends inside the 12s wait (a short track, a seek to the end — seen on
      // a Galaxy: completed 11s after the top-up started) would otherwise
      // reach the queue end with nothing pending and stop instead of park.
      // Cleared only by a pick that lands.
      _djPickPending = true;
      final ready = await ServerManager().awaitTunnelReady(
          server: dj,
          timeout: const Duration(seconds: 12),
          extendWhileDialing: false,
          caller: 'dj');
      if (epoch != _djSessionEpoch) return;
      if (!ready) {
        if (!_djFailLogged) {
          _djFailLogged = true;
          appLog('[dj] tunnel not serving ${dj.localname} — '
              'pick deferred until it is back');
        }
        return;
      }
    }

    // The rows the Seeds page held aside (the DJ off, or on before this
    // lane's first pick) join the lane here, at its first pick, before
    // anything reads the seeds: every start passes through this point, and
    // an import any earlier would be wiped by the resets a start runs
    // (setAutoDJ's fresh session, then a seeded start's own clear).
    if (_pendingSeeds case final pending?) {
      _seeds = _seeds.merge(pending, now: DateTime.now());
      _pendingSeeds = null;
      _publishSeeds();
      // The Less like rows among them have no vector yet.
      unawaited(_ensureNegativeVectors());
    }
    // Whether this is the lane's first pick: every lane edge clears the flag
    // (a new queue, Stop/Start, a server switch), and so does the launch
    // restore. Read before the flag is set just below. A pick that deferred
    // in the tunnel wait returned before this, so its retry is still first.
    final laneStart = !_lanePicked;
    // From here on the live set is the lane's to keep: the page's next rows
    // go straight into it.
    _lanePicked = true;
    // A Less like row whose time ran out goes before any body is built.
    _pruneSeeds();
    // The queue generation this pick is built under, taken where its seeds
    // are read: after the tunnel wait, so a pick that waited across a
    // learned skip, and so already carries its negative, is not thrown away
    // as stale.
    final gen = _djQueueGen;

    final mgr = AutoDJManager();
    Map<String, dynamic>? lastDecoded;

    // BPM/key continuity reads the currently playing item once per
    // call. If extras don't carry bpm/musicalKey (e.g. a localFile or
    // a browse hit without metadata), the windows aren't sent and the
    // server picks freely.
    final currentItem = (index != null &&
            index! >= 0 &&
            index! < queue.value.length)
        ? queue.value[index!]
        : null;
    final rawBpm = currentItem?.extras?['bpm'];
    final currentBpm = rawBpm is num ? rawBpm.round() : null;
    final currentKey = currentItem?.extras?['musicalKey'] as String?;

    // If harmonic mixing is on and we have no anchor yet, try to
    // seed it from the currently playing item's key. Otherwise the
    // first DJ pick locks the anchor (see _queueAutoDJSong below).
    if (mgr.harmonicMixingEnabled && _camelotAnchor == null) {
      final seed = toCamelotCode(currentKey);
      if (seed != null) _camelotAnchor = seed;
    }

    // Drift's blend: at the lane's first pick the song playing joins More
    // like, unpinned, beside the pins the lane carried over, so a new queue
    // (Stop/Start, a server switch, the first pick after a restart too)
    // steers the picks with the music just put on, not the pins alone. It
    // rotates out like any DJ pick. Here, before the seeds are read below,
    // so this very request carries it. Only a song the route the pick tries
    // first can carry (never a local file), not one in Less like, not one
    // More like holds already (a pin, a seeded start's opener, a carried
    // row), and not a DJ pick of this lane, which joins as it starts
    // playing ([blendsOnLaneStart]). Whether or not sonic similarity is on,
    // like every push. Nothing checks that the server can seed from it, so
    // the lane remembers it until a server has ([_laneBlendKey]).
    if (laneStart && currentItem != null) {
      final now = DateTime.now();
      final playing = trackFactsFor(currentItem);
      final row =
          AutoDjSeed(song: playing, origin: SeedOrigin.opener, addedAt: now);
      if (blendsOnLaneStart(
          drift: mgr.sonicAnchorMode == SonicAnchorMode.rolling,
          laneStart: laneStart,
          usable: _seedCarried(row, dj.localname),
          inLessLike: _seeds.has(SeedList.lessLike, row.key),
          alreadyMoreLike: _seeds.has(SeedList.moreLike, row.key),
          isDjPick: currentItem.extras?['djLane'] == _djLaneId)) {
        final next =
            _seeds.pushPick(playing, origin: SeedOrigin.opener, now: now);
        if (!identical(next, _seeds)) {
          _seeds = next;
          if (next.has(SeedList.moreLike, row.key)) {
            _laneBlendKey = row.key;
            _laneBlendedSong = row.key;
          }
          _publishSeeds();
          appLog('[dj] seeds: the song playing joins More like at the lane '
              'start');
        }
      }
    }

    // Sonic similarity: constrain the pick pool to tracks within the
    // session's vibe — server-side, via `similarTo` + `minSimilarity` on
    // random-songs itself. The sonic pool is a HARD base constraint there
    // (the BPM/key waterfall relaxes WITHIN it, and ignoreList / rating /
    // genre filters compose as usual). The seeds are the session's More like
    // rows (util/auto_dj_seeds.dart). In Drift they are the DJ picks it has
    // played, the song playing at the lane's start (the blend above) and the
    // user's pins, averaged by the server into the session's centroid as the
    // webapp's rolling anchor is; with no row the request can carry, the
    // explicit seed, else the playing track. In Stay close they are the rows
    // frozen in place, every one kept from lane to lane, with one song
    // admitted to start a lane that has nothing to stay close to, and none
    // after it. A cold start on an empty queue has no anchor and stays plain
    // random until the first pick plays.
    // Dropped after a failure earlier this session (see the degradation
    // below), so skip building the params at all — that also keeps the error
    // branch from thinking sonic is still in play.
    final sonicEnabled = mgr.sonicSimilarityEnabled &&
        autoDJServer!.sonicUsable &&
        sonicDrop == null;
    // Discovery on but nothing analysed yet (mStream #879): the mode is
    // wanted and the server would only 400. Say so once per session — a
    // sonic switch that is on while picks come out random needs explaining.
    if (mgr.sonicSimilarityEnabled &&
        autoDJServer!.discoveryOn == true &&
        autoDJServer!.discoveryReady == false &&
        !_sonicNotReadyLogged) {
      _sonicNotReadyLogged = true;
      appLog('[dj] sonic off: ${autoDJServer!.localname} has discovery on '
          'but nothing analysed yet — picks stay random until the scan gets '
          'there');
    }
    // A song in Less like never anchors a pick, as a fallback or as the
    // Stay close anchor: the server keeps a positive that is also a negative
    // and ignores the negative.
    String? unlessLessLike(String server, String? path) => path != null &&
            _seeds.has(SeedList.lessLike, seedKey(server, path))
        ? null
        : path;
    // The explicit seed ("start the session here") only counts when it was
    // picked from the DJ server — filepaths are per-library. Same rule for
    // the playing track on the single-server route.
    final explicitSeed = unlessLessLike(dj.localname,
        mgr.sonicSeedServer == dj.localname ? mgr.sonicSeedPath : null);
    final curServer = currentItem?.extras?['server'];
    final curPath = currentItem?.extras?['path'] as String?;
    final sonicCurrent = curServer == dj.localname
        ? unlessLessLike(dj.localname, curPath)
        : null;
    // A session across several servers takes the playing track from any of
    // them: its sound travels as a vector read from the server holding it,
    // so the first pick follows what was playing rather than opening on a
    // random track from the DJ's own server.
    final playingAcross = mgr.multiServerEnabled
        ? fanOutCurrentSeed(
            path: curPath, server: curServer, inSession: _inSession)
        : null;
    final fanOutCurrent = playingAcross == null ||
            unlessLessLike(playingAcross.server, playingAcross.path) == null
        ? null
        : playingAcross;
    // Which More like rows a request can carry ([_carriedHere],
    // [_carriedAcross]): never one a server refused this lane, and only on a
    // server that can read its path. The single-server body takes the DJ's
    // own; a session across several takes those of any of its servers that
    // can hand out its song's vector at all.
    bool carriedHere(AutoDjSeed s) => _carriedHere(s, dj.localname);
    bool carriedAcross(AutoDjSeed s) => _carriedAcross(s, dj.localname);
    // Stay close anchors on its frozen More like. A lane with nothing to stay
    // close to — no row the request can carry, the rows it carried over
    // included (Stay close keeps every row it shows, an earlier lane's song
    // among them, and a chosen first song came in pinned at the start when
    // More like had room) —
    // gets ONE song to start: the explicit seed, else the playing track, the
    // very pin the old lazy lock took at this spot, so a Stay close lane
    // opens as it always did. A row it carried and can't use (one on a
    // server this lane doesn't ask) stays listed beside it. Judged by the
    // route the pick tries
    // first ([_seedCarried]), the song as well as the rows, and carried by
    // this same request: a playing track on a server of the session that
    // can't hand out its vector is no song to stay close to, and the lane
    // keeps looking until one it can carry plays ([stayCloseAdmit]). After
    // that nothing is added ([_stayCloseAnchored], set on every such pick
    // before the song is taken in): a row the user removes or moves stays
    // gone, and with no row left the picks send no positives, ignoring sonic
    // similarity until the user adds a song, switches the mode or a new lane
    // starts. Only a lane whose last row it could carry a server refused,
    // before it took in a song of its own, looks again ([_dropSeedCulprits]).
    // A cold start with neither song stays plain random and admits at the
    // next call, from the then-playing pick. Rows on servers that just did
    // not answer this pick anchor the lane all the same: the single-server
    // body falls back for the pick instead ([stayCloseFallsBack]).
    if (sonicEnabled && mgr.sonicAnchorMode == SonicAnchorMode.locked) {
      final pin = sonicPin(
          own: explicitSeed ?? sonicCurrent,
          dj: dj.localname,
          elsewhere: fanOutCurrent);
      // The explicit seed has no queue row in hand (it is only read here
      // when a seeded start could not open on it), so its row is its path
      // and stored title; the playing track's is its queue row.
      final seedPath = _normSonicPath(explicitSeed);
      final song = pin == null
          ? null
          : seedPath != null
              ? TrackFacts(
                  server: dj.localname,
                  path: '/$seedPath',
                  title: mgr.sonicSeedTitle)
              : trackFactsFor(currentItem!);
      final admission = stayCloseAdmit(_seeds,
          anchored: _stayCloseAnchored,
          song: song,
          usable: (s) => _seedCarried(s, dj.localname),
          now: DateTime.now());
      _stayCloseAnchored = admission.anchored;
      // Anchored only by an admission that took: a refused one (a song
      // already in a list) added nothing, so the lane is still looking for
      // its one song. A full More like takes it in past eight.
      if (admission.admitted && song != null) {
        _seeds = admission.seeds;
        _stayCloseAdmitted = true;
        _publishSeeds();
        if (song.server != dj.localname) {
          appLog('[dj] multi-server: anchored on the playing track on '
              '${song.server}');
        }
      }
    }
    // The sonic settings these params are built from: a verdict on them only
    // stands while they are still the ones set (see [_sonicGen]).
    final sonicGen = _sonicGen;

    // Multi-server first, when it's on and there is a sonic seed to carry —
    // from ANY server: a session that has wandered onto peers still has
    // anchors, just not local ones. It returns false whenever it can't run
    // — no seed, too few eligible servers, nobody answered — and the
    // ordinary single-server pick below then runs, so switching this on can
    // never leave the queue empty where it would otherwise have filled.
    if (mgr.multiServerEnabled) {
      // The More like rows of every server the session can ask, each with
      // its server — what a cross-server seed averages over — else, in
      // Drift, the explicit seed or the playing track on any of them.
      final across = usableSeeds(_seeds.moreLike, carriedAcross);
      final seeds = fanOutSeeds(
          enabled: sonicEnabled,
          mode: mgr.sonicAnchorMode,
          rows: across,
          dj: dj.localname,
          seedPath: explicitSeed,
          current: fanOutCurrent ??
              (sonicCurrent == null
                  ? null
                  : (server: dj.localname, path: sonicCurrent)));
      if (seeds.isNotEmpty) {
        // Drift's last resort, so only with no row or explicit seed.
        if (across.isEmpty && seeds.first.server != dj.localname) {
          appLog('[dj] multi-server: seeded by the playing track on '
              '${seeds.first.server}');
        }
        final picked = await _autoDJMultiServer(seeds,
            epoch: epoch,
            gen: gen,
            autoPlay: autoPlay,
            incrementIndex: incrementIndex);
        // The lane changed while the servers were being asked: neither the
        // cross-server pick nor a single-server fallback belongs to it now
        // (same rule as the response check further down).
        if (epoch != _djSessionEpoch) return;
        // Nor after a learned quick skip: the fallback below would spend a
        // request on seeds and negatives from before it (autoDJ() runs the
        // pick again).
        if (gen != _djQueueGen) return;
        if (picked) return;
      }
    }

    // The single-server body carries only what the DJ's own server can
    // resolve: a filepath names a row on the server holding it, and every
    // discovery route answers a uniform 404 for one it can't — so another
    // server's path in this body would stop the session with "Track not
    // found". With every row on other servers Drift falls back the way it
    // does on a cold start: the explicit seed, else the playing track (both
    // already restricted to the DJ's server above). Built after the fan-out,
    // whose heals may have taken rows out, and again after a heal below.
    // [rows] are the More like rows the fields carry: none when they carry
    // a fallback, which is no row. Stay close falls back the same way, for
    // this pick only and without a row, when its frozen rows all sit on
    // servers the pick across them could not get a vector from this time (a
    // tunnel down, a timeout): its list is the same when they answer again.
    // [oneOff] says the fields are that fallback: what the server says of
    // its anchor is about this pick, not about the session's seeds.
    ({
      Map<String, dynamic>? fields,
      List<({String server, String path})> rows,
      bool oneOff,
    }) singleServerSonic() {
      final rows = usableSeeds(_seeds.moreLike, carriedHere);
      final stranded = stayCloseFallsBack(
          multiServer: mgr.multiServerEnabled,
          locked: mgr.sonicAnchorMode == SonicAnchorMode.locked,
          anyHere: rows.isNotEmpty,
          anyAcross: _seeds.moreLike.any(carriedAcross));
      final fields = sonicParams(
        enabled: sonicEnabled,
        mode: stranded ? SonicAnchorMode.rolling : mgr.sonicAnchorMode,
        history: [for (final r in rows) r.path],
        seedPath: explicitSeed,
        currentPath: sonicCurrent,
        minSimilarity: mgr.sonicMinSimilarity,
      );
      return (
        fields: fields,
        rows: fields == null ? const [] : rows,
        oneOff: stranded && fields != null,
      );
    }

    var sonic = singleServerSonic();

    // Keyword filter is client-side (the server doesn't see it).
    // Retry up to 5 times if responses get blocked, using the
    // updated ignoreList from the server so we don't pick the same
    // rejected track twice. After 5 blocks accept the last response
    // anyway — mirrors the webapp's fallback so the queue doesn't
    // stall forever on an over-aggressive filter.
    // Whether the attempt in hand carried the sonic keys — what its picks are
    // badged by — and whether this pick has to go without them.
    var sentSonic = false;
    var sonicOffThisPick = false;
    for (var attempt = 0; attempt < 5; attempt++) {
      // Left out once this session has dropped it (see [sonicDrop]).
      final fields = sonic.fields;
      sentSonic = fields != null && sonicDrop == null && !sonicOffThisPick;
      // The More like rows this attempt carries, for the heal below.
      final sentRows =
          sentSonic ? sonic.rows : const <({String server, String path})>[];
      // A Less like row whose time ran out while an earlier attempt was out
      // is not sent in this one.
      _pruneSeeds();
      final payload = <String, dynamic>{
        'ignoreList': jsonAutoDJIgnoreList ?? [],
        if (sentSonic) ...fields,
        // The Less like negatives (mStream #1108): the DJ server's own songs
        // as paths. Beside the sonic fields, never inside them: they go out
        // on a pick that dropped its positive seeds too, which the server
        // takes, and never with a minSimilarity, which without a seed is a
        // 400 that loses the pick (lessLikeParams).
        if (mgr.sonicSimilarityEnabled && autoDJServer!.lessLikeUsable)
          ...lessLikeParams(
              paths: _seeds.negativesFor(autoDJServer!.localname).paths),
        // Rating, vpaths, genre and track length — shared with the
        // "Surprise me" opener so the two can't drift apart again.
        ...mgr.libraryFilters(autoDJServer!),
        // Songs per fetch (mStream #966). Stripped by the capability filter
        // for a server known to predate it.
        ...mgr.batchParams,
      };
      if (mgr.bpmContinuityEnabled && currentBpm != null && currentBpm > 0) {
        payload['bpmRanges'] =
            _bpmWindows(currentBpm, mgr.bpmTolerance);
        payload['bpmRangesWide'] =
            _bpmWindows(currentBpm, mgr.bpmTolerance + 2);
        // Require tagged tracks so the waterfall doesn't fall back
        // to BPM-unknown picks when our windows return nothing.
        payload['requireBpm'] = true;
      }
      if (mgr.harmonicMixingEnabled) {
        if (_camelotAnchor != null) {
          payload['musicalKeys'] = camelotNeighbours(_camelotAnchor!);
        }
        // Always prefer tagged tracks when harmonic mode is on —
        // even without an anchor, the first pick should be keyed so
        // we can lock the anchor for the rest of the session.
        payload['requireMusicalKey'] = true;
      }

      Map<String, dynamic> decoded;
      try {
        // Bounded like every other headless fetch so a black-hole server (e.g.
        // a Shuffle All started from Android Auto, which awaits this) can't hang
        // forever; the catch below treats the TimeoutException as a network
        // error and bails silently.
        // Drop anything this server is known not to accept before sending.
        // mStream validates with Joi and no allowUnknown, so one unrecognised
        // key 400s the WHOLE request — a single new parameter would otherwise
        // take Auto DJ out entirely on an older server.
        final filtered =
            ServerCapabilities().filter(autoDJServer!, payload);
        if (filtered.dropped.isNotEmpty) {
          appLog('[dj] dropped for this server: '
              '${filtered.dropped.join(", ")}');
        }
        var sent = filtered.body;
        var res = await http.post(
          autoDJServer!.apiUri('/api/v1/db/random-songs'),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': autoDJServer?.authToken ?? '',
          },
          body: jsonEncode(sent),
        ).timeout(const Duration(seconds: 15));
        // The lane changed while the request was out (a queue clear, the DJ
        // off or on another server): nothing in its answer belongs to the
        // new one — not a learned rejection, which would be filed against
        // whatever server the DJ is on now, and least of all a sonic verdict.
        if (epoch != _djSessionEpoch) return;
        // A rejection names the offending key, so learn it and go again
        // without it. Bounded by the payload size and terminating by
        // construction: every pass removes one key the last body carried,
        // permanently for this session, so it cannot loop — a key inside a
        // value (a `moods` filter's `threshold` on a server from before it)
        // cannot be removed, so it does not retry at all
        // (ServerCapabilities.retryWithout). Only "is not allowed" retries — an auth
        // failure or a bad value returns null and falls through to the normal
        // error handling below, because resending a smaller body there would
        // fail again with less information.
        //
        // The BODY is the signal, not the status. mStream answered a schema
        // rejection with 403 up to and including 6.11.0 and with 400 from
        // 6.12.0 (server.js: "That's 400 Bad Request, not 403 Forbidden"),
        // and both carry the same `"<key>" is not allowed` message. Gating on
        // 400 meant the learner — the half of this that is authoritative,
        // since the version table is only a pre-filter — was inert on exactly
        // the older servers it exists for. Verified against a live 6.11.0 and
        // a live 6.22.0.
        while (res.statusCode > 299) {
          final learned = ServerCapabilities()
              .retryWithout(autoDJServer!, res.body, sent);
          if (learned == null) break;
          // Logged because the learner is otherwise invisible: a parameter
          // silently dropped for the rest of the session looks exactly like a
          // filter that does nothing, and the only clue is a "dropped" line
          // whose cause has already scrolled past.
          appLog('[dj] server rejected "$learned" (HTTP ${res.statusCode}) '
              '— retrying without it');
          sent = ServerCapabilities().filter(autoDJServer!, payload).body;
          res = await http.post(
            autoDJServer!.apiUri('/api/v1/db/random-songs'),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': autoDJServer?.authToken ?? '',
            },
            body: jsonEncode(sent),
          ).timeout(const Duration(seconds: 15));
          if (epoch != _djSessionEpoch) return; // as above
        }
        if (res.statusCode > 299) {
          appLog('[dj] random-songs HTTP ${res.statusCode} — pick skipped');
          // Sonic mode fails LOUD by the server's contract: the pool is a
          // hard promise ("only songs within X of the vibe"), so an empty
          // pool or an unanalyzed seed stops the session with an
          // explanation instead of silently playing outside the range
          // (webapp parity — it discriminates on the error message too).
          if (sentSonic) {
            String serverMsg = '';
            try {
              final b = jsonDecode(res.body);
              if (b is Map && b['error'] is String) serverMsg = b['error'];
            } catch (_) {}
            final lower = serverMsg.toLowerCase();
            // Self-heal a dead seed row (hardening the webapp lacks). A seed
            // the server can't use — gone from its library (the uniform 404
            // "Track not found") or not analysed yet (400) — names no path,
            // and a pinned or Stay close row never rotates out the way the
            // old ring's paths did, so one dead row would cost every later
            // pick its sonic seeds. When this body carried More like rows,
            // the ones at fault leave the lane's requests and this same
            // pick goes again with what is left: Drift falls back as on a
            // cold start, and Stay close, which keeps them listed, sends its
            // rows still usable, or no positive at all, since its lane
            // admits nothing after its one song; a lane that had not taken
            // in its song yet takes it in at its next pick instead
            // ([_dropSeedCulprits]). When no probe can say which row it was
            // (a server from before the embeddings route, a probe that
            // timed out), the song this lane's start blended in is the one
            // taken out, if the body carried it ([blendCulprit]): no server
            // has judged it, and the rows it joined went out without it
            // before. Only a failure no row explains — the body carried a
            // fallback, or the probe found nothing and no blended song rode
            // along — goes on below, and so does one whose rows left would
            // send the very seeds just refused ([sonicFieldsDiffer]).
            final gone =
                res.statusCode == 404 && lower.contains('track not found');
            if ((gone || lower.contains('analyzed')) && sentRows.isNotEmpty) {
              var healed = await _healSonicSeeds(autoDJServer!, sentRows,
                  gone: gone, epoch: epoch);
              if (epoch != _djSessionEpoch) return;
              if (gen != _djQueueGen) return; // a learned skip: run again
              final blend = blendCulprit(
                  healed: healed, blend: _laneBlendKey, sent: sentRows);
              if (blend != null) {
                _dropSeedCulprits(
                    {blend},
                    'presumed ${gone ? 'not found' : 'not analysed'} on '
                    '${autoDJServer!.localname} (the song blended in at the '
                    'lane start; no probe could tell)');
                // Out of the next body whatever that found to change (a row
                // the user removed meanwhile is out already), as a heal's
                // rows are.
                healed = true;
              }
              if (healed) {
                sonic = singleServerSonic();
                // With the lane's one row out, Drift falls back to the song
                // playing, which can be that very row (the blend, a seeded
                // start's opener): the same seeds again would only be
                // refused again, so this answer stands for that body too.
                if (sonicFieldsDiffer(fields, sonic.fields)) continue;
              }
            }
            // The three ways sonic can fail while the request itself is
            // fine. All used to `return` — no pick, and with the queue-end
            // top-up being the only caller that meant silence until the user
            // intervened. A constraint the server cannot satisfy should cost
            // the CONSTRAINT, not the music: drop the sonic keys for this
            // session and take the same pick without them.
            //
            // Still says so, because a session that quietly stopped honouring
            // "only songs that sound like this" would be lying about what it
            // is doing — on the Auto DJ screen's Sonic similarity row
            // ([sonicDrop]), which is where the user goes to loosen it.
            SonicDrop? drop;
            if (lower.contains('similarity range')) {
              drop = SonicDrop.tooStrict;
            } else if (lower.contains('analyzed')) {
              drop = SonicDrop.scanning;
            } else if (lower.contains('discovery is disabled')) {
              // requireIndex() answers this for both "the feature is off"
              // and "it is on but there is no index yet", the same status on
              // purpose so an anonymous prober cannot tell configuration from
              // failure. I briefly toasted the second reading here. Measuring
              // against a live server killed it: with collectDiscoveryData on,
              // discovery.db is created at boot AND by the admin toggle, so
              // getIndex() is never null and the no-index case does not arise
              // in normal operation.
              //
              // Which leaves the first reading — switched off since our last
              // ping — and that stays silent: the user made that change
              // themselves, so being told is noise. The genuinely-unscanned
              // library never reaches here anyway; it answers 400 "Sonic seed
              // track has not been analyzed yet", which the branch above
              // already explains.
              drop = SonicDrop.discoveryOff;
            }
            // The anchor names a track the server no longer has (moved or
            // deleted since it played — an opener from Recently played), and
            // it is no row a heal could take out (the explicit seed, the
            // playing track): this pick goes without it rather than not at
            // all.
            if (drop == null && gone) {
              sonicOffThisPick = true;
              continue;
            }
            if (drop != null) {
              // A Stay close pick that fell back to the playing track for
              // itself alone ([stayCloseFallsBack]) asked about that track,
              // not about the session's frozen seeds: no match around it, or
              // a track not analysed yet, costs only this pick its sonic
              // keys, so the seeds pick up again once their servers answer.
              // Discovery switched off is the server's, whatever was asked.
              final oneOff = sonic.oneOff && drop != SonicDrop.discoveryOff;
              if (sonicGen == _sonicGen && !oneOff) {
                appLog('[dj] sonic dropped for this session — ${drop.name}');
                sonicDrop = drop;
                customState.add(CustomEvent(autoDJServer));
              } else {
                // The sonic settings changed while this pick was out, so the
                // verdict is about ones no longer set (or it was about a
                // one-pick fallback, above): this pick goes without sonic,
                // and the next is built with the new settings.
                sonicOffThisPick = true;
              }
              // The seeds stay: these verdicts are about the threshold or
              // the server, not the seed songs (a row at fault was taken out
              // above), so loosening the match resumes on the same seeds.
              // Retry this same pick without the constraint. Bounded by the
              // enclosing attempt loop, and cannot spin: with [sonicDrop] or
              // sonicOffThisPick set the next pass builds a payload that no
              // longer carries it.
              continue;
            }
          }
          // An expired/rotated JWT kills Auto DJ permanently and used to do it
          // in total silence — infinite play just stopped. Tell the user once.
          //
          // Not for a schema rejection wearing a 403: pre-6.12 servers answer
          // validation failures with that status, and telling someone to
          // re-login over a parameter they never typed sends them to fix the
          // one thing that is not wrong. The loop above already retried those
          // to exhaustion, so anything still carrying a not-allowed body here
          // is a key we cannot drop, not an expired session.
          if ((res.statusCode == 401 || res.statusCode == 403) &&
              parseNotAllowedKey(res.body) == null &&
              !_autoDJAuthWarned) {
            _autoDJAuthWarned = true;
            _showPlaybackErrorToast(
                'Auto DJ stopped — the server session expired. '
                'Re-login in Manage Servers.');
          }
          return;
        }
        decoded = jsonDecode(res.body) as Map<String, dynamic>;
        _logLessLikeEcho(autoDJServer!, decoded);
        // The server took a body that carried the song this lane's start
        // blended in, so it can seed from that song: a row like any other
        // from here on ([_laneBlendKey]).
        if (carriesBlend(_laneBlendKey, sentRows)) _laneBlendKey = null;
        // A working pick re-arms the auth warning: the once-per-session flag
        // exists to collapse queue-end retrigger spam of ONE expiry episode,
        // not to silence a NEW expiry after a recovery.
        _autoDJAuthWarned = false;
        _djPickPending = false;
        _djFailLogged = false;
        _deferredPickFailures = 0;
      } catch (e) {
        // Network error → bail without a toast (an offline queue-end is
        // normal). Logged once per outage — the player's index re-emissions
        // re-fire this every ~30s — and remembered, so the tunnel's return
        // retries it instead of leaving the queue one track short.
        if (!_djFailLogged) {
          _djFailLogged = true;
          appLog('[dj] random-songs failed: $e');
        }
        _djPickPending = true;
        _deferredPickFailures++;
        // Parked on this pick and the tunnel still claims to serve: ask for
        // ground truth now rather than waiting up to a minute for the idle
        // timeout to flip the status (see _retryPickAtQueueEnd).
        if (_parkedForDJ &&
            dj.isIrohTransport &&
            ServerManager().tunnelServes(dj)) {
          unawaited(ServerManager().reverifyTunnel(dj));
        }
        return;
      }

      // The lane changed while the request was out — the queue was cleared,
      // or the DJ was switched off / to another server. Drop the pick:
      // landing it would smuggle a dead-session track into the fresh queue
      // and overwrite the just-reset ignoreList with the old session's.
      if (epoch != _djSessionEpoch) return;
      // A learned quick skip while it was out: this answer was chosen
      // without the skip's negative, so it is dropped and its ignoreList
      // with it (none of its songs is queued), and autoDJ() runs the pick
      // again as the re-roll.
      if (gen != _djQueueGen) return;

      jsonAutoDJIgnoreList = decoded['ignoreList'];
      final songs = _songsOf(decoded);
      if (songs.isEmpty) return;

      lastDecoded = decoded;

      // A batch keeps whatever part of it passes the keyword filter, and
      // never the blended song the user quick-skipped in this lane
      // ([_laneSkippedBlend]); only an answer blocked in full is retried.
      final skippedKey = _skippedBlendKey();
      final accepted = [
        for (final s in songs)
          if (!mgr.isKeywordBlocked(s) &&
              !isSkippedBlend(s, autoDJServer!.localname, skippedKey))
            s,
      ];
      if (accepted.isNotEmpty) {
        await _queueAutoDJSongs(
            [for (final s in accepted) (song: s, source: autoDJServer!)],
            epoch: epoch,
            gen: gen,
            autoPlay: autoPlay,
            incrementIndex: incrementIndex,
            sonicPick: sentSonic);
        return;
      }
      // Otherwise loop — the updated ignoreList means the next call
      // returns different candidates.
    }

    if (lastDecoded != null) {
      // Every retry was blocked in full: take the last answer whole rather
      // than stall the session (webapp parity — the server's fallback chain
      // has already exhausted the alternatives). Whole but for the blended
      // song the user quick-skipped, while anything else is left.
      final last = _songsOf(lastDecoded);
      final skippedKey = _skippedBlendKey();
      final rest = [
        for (final s in last)
          if (!isSkippedBlend(s, autoDJServer!.localname, skippedKey)) s,
      ];
      await _queueAutoDJSongs(
          [
            for (final s in rest.isEmpty ? last : rest)
              (song: s, source: autoDJServer!),
          ],
          epoch: epoch,
          gen: gen,
          autoPlay: autoPlay,
          incrementIndex: incrementIndex,
          sonicPick: sentSonic);
    }
  }

  /// The seed key of the blended song the user quick-skipped in this lane
  /// ([_laneSkippedBlend]), which the single-server picks pass over; null
  /// when there is none.
  String? _skippedBlendKey() {
    final s = _laneSkippedBlend;
    return s == null ? null : seedKey(s.server, s.path);
  }

  /// The song rows of a random-songs answer — one before mStream #966, up to
  /// `limit` since — skipping anything that is not an object.
  static List<Map<String, dynamic>> _songsOf(Map<String, dynamic> decoded) {
    final songs = decoded['songs'];
    if (songs is! List) return const [];
    return songs.whereType<Map<String, dynamic>>().toList();
  }

  /// Queue a batch in the server's order (best first). The flags belong to
  /// the FIRST song — it is the one a seek lands on and playback starts from;
  /// the rest simply follow it in the queue.
  ///
  /// [epoch] and [gen] are the lane and the queue generation the pick was
  /// built under, tested again before every song, the lane first: a clear
  /// that lands mid-batch gets none of the rest and owes nothing, and a
  /// learned quick skip mid-batch stops it too, the pick being run again
  /// (autoDJ()). A pick whose generation no re-roll has settled yet IS the
  /// re-roll: it takes the stale picks ahead out as its songs come in, and
  /// queues one for each rather than adding a batch ([_landReroll]).
  Future<void> _queueAutoDJSongs(
      List<({Map<String, dynamic> song, Server source})> picks,
      {required int epoch,
      required int gen,
      bool autoPlay = false,
      bool incrementIndex = false,
      bool sonicPick = false}) async {
    if (epoch != _djSessionEpoch || gen != _djQueueGen) return;
    var batch = picks;
    if (_rerolledGen < gen) {
      final count = await _landReroll(picks.length, epoch: epoch, gen: gen);
      if (count == null) return;
      batch = picks.take(count).toList();
    }
    var first = true;
    for (final p in batch) {
      if (epoch != _djSessionEpoch) return;
      if (gen != _djQueueGen) return;
      await _queueAutoDJSong(p.song,
          autoPlay: first && autoPlay,
          incrementIndex: first && incrementIndex,
          sonicPick: sonicPick,
          source: p.source);
      first = false;
    }
  }

  /// A re-roll landing: a pick of a learned skip's generation [gen], which
  /// no re-roll has settled yet. The stale picks ahead go now, as their
  /// replacements arrive, never before: dropped first and refilled later, a
  /// refill that failed for a moment could leave only the playing row, and
  /// the queue would end where the old rows would still have played.
  ///
  /// The rows that may go ([rerollDroppable]) are the DJ's picks after the
  /// playing row that are neither on the phone nor on their way there, and
  /// none under shuffle; of those, only the stale picks the skip named as
  /// the re-roll started ([_rerollStale]), when it named them. The nearest
  /// go first, one for each of the pick's [picks] songs at most. Then as
  /// many songs are queued as rows went, or every one when the playing row
  /// is now the last, as at any top-up; with nothing to drop and rows still
  /// ahead, none, and the pick is spent ([rerollQueueCount]). Either way the
  /// re-roll is settled.
  ///
  /// Returns how many of the songs to queue, or null when the pick went
  /// stale while the rows were going: the lane changed, or a further learned
  /// skip came (the pick then runs again).
  Future<int?> _landReroll(int picks,
      {required int epoch, required int gen}) async {
    final q = queue.value;
    // The row the user sees playing: a failed restore's parked spot, while
    // there is one, whatever the idle player reads.
    final current = _restoreSpot?.index ?? _backend.currentIndex;
    var dropped = 0;
    // A first look, so a re-roll with nothing to replace doesn't wait on
    // the chain; the rows themselves are chosen when the drop runs.
    if (current != null &&
        current >= 0 &&
        current < q.length &&
        rerollDrops(q, _rerollDroppable(q, current),
                picks: picks, stale: _rerollStale)
            .isNotEmpty) {
      // On the chain, like every other edit of the backend's list, so a
      // reload, a restore or a cast switch can't land in the middle of it.
      final drop =
          _switchChain.then((_) => _dropRerolled(picks, epoch: epoch));
      _switchChain = drop.catchError((_) => 0);
      dropped = await drop;
      if (epoch != _djSessionEpoch) return null;
      if (gen != _djQueueGen) return null;
    }
    _rerolledGen = gen;
    _rerollStale = null;
    final now = _restoreSpot?.index ?? _backend.currentIndex;
    final count = rerollQueueCount(
        picks: picks,
        dropped: dropped,
        atEnd: now == null || now >= queue.value.length - 1);
    appLog(dropped == 0 && count == 0
        ? '[dj] re-roll: nothing ahead can be replaced — the queue stays'
        : '[dj] re-roll: $dropped stale pick(s) ahead replaced, '
            'queueing $count');
    return count;
  }

  /// [rerollDroppable] on the live state: the queue's downloaded copies, the
  /// transfers under way, and the player's shuffle.
  List<int> _rerollDroppable(List<MediaItem> q, int current) =>
      rerollDroppable(q, current,
          onDisk: hasLocalCopy,
          inFlight: DownloadManager().isInFlight,
          shuffle: _backend.shuffleEnabled);

  /// The stale picks a landing re-roll of [picks] songs takes out of the
  /// queue ([_landReroll]), on [_switchChain]. They are chosen here, when
  /// the drop's turn comes ([rerollDrops]: the rows it may drop after the
  /// one playing now, the nearest first, only the ones the skip named): a
  /// URL rebuild or a reseed that ran ahead of it on the chain swaps every
  /// row for a new one, so rows taken any earlier would be found nowhere,
  /// and the skip's re-roll spent with nothing replaced. Each is then found
  /// again by identity when its turn comes, and passed over once a re-roll
  /// may no longer drop it: it is gone, a second Next has reached it, or its
  /// file landed or started coming meanwhile. Each goes the way
  /// removeQueueItemAt takes a row, the queue first and then the backend,
  /// one at a time, and the queue is never put back from a copy: a Play next
  /// or Add to queue landing meanwhile stays where it went.
  ///
  /// Under the reorder hold, so a removal's index re-emission neither tops
  /// up nor re-derives now-playing halfway; a move the hold swallowed (a
  /// Next pressed meanwhile) is played out once at the end
  /// ([_onCurrentIndex]). Stops when the lane changes. Returns how many rows
  /// went, and never throws.
  Future<int> _dropRerolled(int picks, {required int epoch}) async {
    final indexBefore = _backend.currentIndex;
    var dropped = 0;
    _reordering = true;
    try {
      final now = queue.value;
      final at = _restoreSpot?.index ?? _backend.currentIndex;
      final stale = epoch != _djSessionEpoch ||
              at == null ||
              at < 0 ||
              at >= now.length
          ? const <MediaItem>[]
          : [
              for (final i in rerollDrops(now, _rerollDroppable(now, at),
                  picks: picks, stale: _rerollStale))
                now[i],
            ];
      for (final m in stale) {
        if (epoch != _djSessionEpoch) break;
        final q = queue.value;
        final i = q.indexWhere((x) => identical(x, m));
        final current = _restoreSpot?.index ?? _backend.currentIndex;
        if (i < 0 ||
            current == null ||
            !_rerollDroppable(q, current).contains(i)) {
          continue;
        }
        queue.add(q..removeAt(i));
        dropped++;
        await _backend.removeSourceAt(i);
      }
    } catch (e) {
      appLog('[dj] re-roll: taking a stale pick out failed: $e');
    } finally {
      _reordering = false;
    }
    final index = _backend.currentIndex;
    if (index != indexBefore) _onCurrentIndex(index);
    return dropped;
  }

  /// [source] is the server the pick came FROM, which is only the DJ's own
  /// server in a single-server session — a multi-server session draws from
  /// whichever server answered best, and the stream URL, album art and the
  /// queue item's `server` extra all have to name that one or the track won't
  /// play.
  Future<void> _queueAutoDJSong(Map<String, dynamic> song,
      {bool autoPlay = false,
      bool incrementIndex = false,
      bool sonicPick = false,
      Server? source}) async {
    final from = source ?? autoDJServer!;
    final metadata = (song['metadata'] as Map?) ?? const {};
    final filepath = song['filepath'] as String?;
    if (filepath == null) return; // skip a degenerate random-songs row

    // Transcode-aware stream URL (honors the /transcode endpoint + codec/bitrate
    // when transcoding is on), shared with browse / queue-restore / recursive.
    final mediaUrl = buildServerStreamUrl(from, filepath);

    final artUrl = metadata['album-art'] != null
        ? buildAlbumArtUrl(from, metadata['album-art'] as String,
            compress: 'l')
        : null;

    // Parse the raw server map once so the genre / disc / key wire quirks are
    // handled in one place (MusicMetadata.fromServerMap) — the same path that
    // browse-added items take.
    final meta = MusicMetadata.fromServerMap(metadata);
    final item = MediaItem(
      id: mediaUrl,
      title: meta.title ?? filepath.split('/').last,
      album: meta.album,
      // The ARTIST tag as written when the server sends it (6.28+); the
      // primary artist otherwise. Song Info reads the primary from extras.
      artist: meta.artistDisplay ?? meta.artist,
      genre: meta.genreLabel,
      // Duration from the server payload (browse-added parity). Without it a
      // restore of an Auto-DJ track can't clamp a saved at-the-end position
      // (see QueueStore.clampResumePositionMs) — reopening then seeks past
      // the end, completes, and playback "won't start".
      duration: meta.duration,
      // Artwork for the notification / lock screen / Android Auto (see
      // buildServerFileMediaItem — artUri mirrors extras['artUrl']).
      artUri: artUrl == null ? null : Uri.parse(artUrl),
      extras: {
        // The same map a browse-added track gets (queueExtras) — the source
        // server for Share Playlist's multi-server detection, the rating, the
        // bpm + key the next DJ pick's continuity payload reads, and the
        // Song Info fields a hand-rolled map here used to drop.
        ...queueExtras(meta,
            server: from.localname, path: filepath, artUrl: artUrl),
        // Queue-transparency badge (persisted with the queue): this row was
        // chosen by Auto DJ, and whether the sonic pool shaped the pick —
        // the queue row renders the matching icon so DJ additions are
        // distinguishable from user-queued tracks.
        'djPick': true,
        'djSonic': sonicPick,
        // The lane that queued it: only its own picks join its More like
        // as they play (see [_djLaneId]).
        'djLane': _djLaneId,
      },
    );

    // Lock the Camelot anchor on the first keyed DJ pick of the
    // session. Subsequent calls in autoDJ() will use the anchor's
    // neighbours rather than re-deriving from each newly-played
    // song's key (which would drift across the session).
    if (AutoDJManager().harmonicMixingEnabled && _camelotAnchor == null) {
      final code = toCamelotCode(metadata['musical-key'] as String?);
      if (code != null) _camelotAnchor = code;
    }

    // Whether this pick resumes a parked queue end is a property of the PARK,
    // not of the caller's flags: the pick that lands may be one an index
    // re-emission started (no flags) while the tunnel-back retry was dropped
    // by _djInFlight. Read before the append (the append can move a completed
    // player to ready) and re-checked after it (the user may have moved on).
    final wasParked = _stillParked;
    // Awaited: just_audio delivers the insert to the platform only after its
    // own bookkeeping, while a seek gets there after one await — an unawaited
    // add followed by seek(index + 1) reached ExoPlayer with an index past the
    // end (IllegalSeekPositionException) and left the darwin player's index
    // out of range.
    // Tolerant of the platform insert throwing (Android's known just_audio
    // IllegalArgumentException on concatenatingInsertAll): the item is already
    // in the queue subject by then, and an unawaited add used to let the pick
    // proceed regardless — awaiting it must not turn that into an aborted
    // pick with no resume.
    try {
      await addQueueItem(item);
    } catch (e) {
      appLog('[dj] queue insert threw (continuing): $e');
    }
    final resume = wasParked && _parkedForDJ;
    _releasePark();

    if ((incrementIndex || resume) && queue.value.isNotEmpty) {
      final last = queue.value.length - 1;
      final target = (index != null ? index! + 1 : last).clamp(0, last);
      try {
        await _backend.seek(Duration.zero, index: target);
      } catch (e) {
        appLog('[dj] seek to the new pick failed: $e');
      }
    }
    if (autoPlay) {
      await play();
    } else if (resume && _playIntent && !_recentlyInterrupted) {
      // The backend's play, not the handler's: this is automatic, so it must
      // not erase the interruption window the way a user's play does.
      appLog('[dj] pick landed — resuming the parked queue');
      unawaited(_localBackend.play());
    }
  }

  /// The `similarTo`/`minSimilarity` fields for a single-server random-songs
  /// body, or null when sonic mode is off or nothing anchors the pick.
  ///
  /// [history] is the session's More like rows that body can carry, oldest
  /// first ([usableSeeds]); the server averages them into the session's
  /// centroid, at most eight, the newest kept. In either mode they come
  /// first. With none, Drift falls back as the webapp's auto-dj.js
  /// buildSonicParams does: the explicit seed song, else the playing track.
  /// A lane's first pick rarely needs it: the song playing has just joined
  /// More like there (Drift's blend, [blendsOnLaneStart]). So it serves a
  /// pick that finds no row this body can carry: the user removed them, a
  /// server refused them, eight pins elsewhere left the blend no room, or
  /// the song playing is a local file or on another server and only the
  /// explicit seed is left. Stay close has no fallback: its
  /// anchor is a row, the one song a lane with nothing to stay close to
  /// admits before this is built, and with no row this body can carry (a
  /// cold start on an empty queue, a lane whose rows sit elsewhere, one
  /// whose rows the user removed) the pick goes without sonic similarity.
  /// Pure; unit-tested.
  static Map<String, dynamic>? sonicParams({
    required bool enabled,
    SonicAnchorMode mode = SonicAnchorMode.rolling,
    required List<String> history,
    String? seedPath,
    String? currentPath,
    required double minSimilarity,
  }) {
    if (!enabled) return null;
    final rows = [for (final p in history) ?_normSonicPath(p)];
    if (rows.isNotEmpty) {
      return {
        'similarTo': rows.length <= 8 ? rows : rows.sublist(rows.length - 8),
        'minSimilarity': minSimilarity,
      };
    }
    if (mode == SonicAnchorMode.locked) return null;
    final anchor = _normSonicPath(seedPath) ?? _normSonicPath(currentPath);
    if (anchor == null) return null;
    return {
      'similarTo': [anchor],
      'minSimilarity': minSimilarity,
    };
  }

  /// The seeds a pick across several servers averages into its vector, each
  /// with the server that holds it, since a path is read only there: the
  /// same policy as [sonicParams]. The More like rows the session can carry
  /// ([rows], oldest first, at most eight, the newest kept) come first. With
  /// none, Drift falls back to the explicit seed song, on the DJ's server
  /// ([dj]), else the playing track on whichever of the session's servers
  /// holds it ([current], see [fanOutCurrentSeed]); Stay close has no
  /// fallback. Empty when sonic mode is off or nothing anchors the pick.
  /// Pure; unit-tested.
  static List<({String server, String path})> fanOutSeeds({
    required bool enabled,
    SonicAnchorMode mode = SonicAnchorMode.rolling,
    required List<({String server, String path})> rows,
    required String dj,
    String? seedPath,
    ({String server, String path})? current,
  }) {
    if (!enabled) return const [];
    final carried = [
      for (final r in rows)
        if (_normSonicPath(r.path) case final p? when r.server.isNotEmpty)
          (server: r.server, path: p),
    ];
    if (carried.isNotEmpty) {
      return carried.length <= 8
          ? carried
          : carried.sublist(carried.length - 8);
    }
    if (mode == SonicAnchorMode.locked) return const [];
    final seed = _normSonicPath(seedPath);
    if (seed != null) return [(server: dj, path: seed)];
    final playing = _normSonicPath(current?.path);
    if (current == null || playing == null || current.server.isEmpty) {
      return const [];
    }
    return [(server: current.server, path: playing)];
  }

  /// Stay close's one song for a lane with nothing to stay close to yet (no
  /// More like row its request can carry, [stayCloseAdmission]): [own] — the
  /// explicit seed, else the playing track, both on the DJ's server ([dj])
  /// and so carried by either route — else the playing track on another of a
  /// multi-server session's servers ([elsewhere], see [fanOutCurrentSeed]),
  /// which only the cross-server pick can carry. The pick admits it as a row
  /// ([AutoDjSeeds.admitAnchor]) when its request can carry that row
  /// ([stayCloseAdmit]): the server holding it must hand out vectors.
  /// Null leaves the pick plain random until something plays to anchor on.
  /// Pure; unit-tested.
  static ({String path, String server})? sonicPin(
      {String? own,
      required String dj,
      ({String path, String server})? elsewhere}) {
    final mine = _normSonicPath(own);
    if (mine != null) return (path: mine, server: dj);
    return elsewhere;
  }

  /// Seed paths on the wire never carry a leading slash (they resolve via
  /// getVPathInfo server-side); queue extras' paths do. Normalize at every
  /// write/build point, like the webapp's _normSonicPath.
  static String? _normSonicPath(String? p) {
    if (p == null) return null;
    final s = p.startsWith('/') ? p.substring(1) : p;
    return s.isEmpty ? null : s;
  }

  // BPM continuity windows: one centered on the current tempo, one
  // at half-tempo, one at double. The server OR-s these together so
  // a 120-BPM source matches tracks at 112–128, 56–64, or 232–248
  // (with tolerance=8). Half/double cover the common DJ practice
  // of mixing across octaves.
  static List<Map<String, int>> _bpmWindows(int bpm, int tolerance) {
    final half = (bpm / 2).round();
    final dbl = bpm * 2;
    return [
      {'min': bpm - tolerance, 'max': bpm + tolerance},
      {'min': half - tolerance, 'max': half + tolerance},
      {'min': dbl - tolerance, 'max': dbl + tolerance},
    ];
  }
}
