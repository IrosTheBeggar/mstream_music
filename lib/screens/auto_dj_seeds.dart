// The Auto DJ's Seeds page (design E; boards E-SeedsDrift and E-SeedsClose):
// Drift | Stay close at the top, one line under it saying what the choice
// does, then the More like and Less like lists, each ending in Add song, and
// last a checkbox: "Clear pins when the queue is cleared".
//
// More like holds the songs the DJ's picks are drawn towards, Less like the
// ones they are steered away from. In Drift the DJ keeps More like moving
// (a pick joins as it starts playing, the oldest unpinned row leaves) and
// quick skips can teach Less like, whose unpinned rows expire; a pin keeps a
// row where it is. Stay close holds both lists still: every row shows pinned
// and its pin is locked until Drift gives the user's own pins back. The
// user's own edits (Add song, a row's move to the other list, Remove) work in
// either mode, as long as the list can take the song. The user's pins outlive
// the queue, Stop/Start and app restarts, and in Stay close so does every row
// the page shows; with the checkbox ticked, clearing the queue (or replacing
// it) removes the rows shown pinned from both lists too, which in Stay close
// is every row.
//
// Split as quick config is: AutoDjSeedsView takes the seeds, the mode and
// on… callbacks and touches nothing else, so it is tested on plain values;
// AutoDjSeedsScreen is the live page around it, which reads the audio
// handler's seeds surface and hands the edits back to it.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/play_event.dart';
import '../objects/server.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/media.dart';
import '../singletons/play_history.dart';
import '../singletons/server_list.dart';
import '../singletons/track_capture.dart';
import '../theme/velvet_theme.dart';
import '../util/auto_dj_recent.dart';
import '../util/auto_dj_seed_facts.dart';
import '../util/auto_dj_seeds.dart';
import '../widgets/auto_dj_add_song_sheet.dart';
import '../widgets/federation_widgets.dart' show FedCard;
import '../widgets/seed_art.dart';
import 'auto_dj.dart' show AutoDJScreen;
import 'auto_dj_sheets.dart' show autoDjSegmentStyle;

/// The Seeds page, live: the session's seeds as the audio handler shows them
/// (its seedsStream), the mode and the checkbox from [AutoDJManager], and
/// every change sent back through the handler, which owns the lists, or the
/// manager, which owns the setting.
///
/// What the page may offer also hangs on the DJ's state, Play from and the
/// servers' flags: whether any server in scope takes Less like songs, and
/// which servers' songs each list can use ([AudioPlayerHandler.seedAddServers],
/// read at every build, a plain call). So it redraws on the handler's
/// customState (which also tells of a server dropped from the session's
/// fan-out), the manager's changes and the servers' capability changes as
/// well as on the seeds. Add song and a row's move still ask again when
/// tapped, since the answer can change after the page's last build: a tap
/// whose list can no longer use the song does nothing and draws the page
/// again, with that control off. The queue and the play history are read
/// only when Add song opens.
class AutoDjSeedsScreen extends StatefulWidget {
  const AutoDjSeedsScreen({super.key, this.overAutoDj = false});

  /// Whether the page was opened over the Auto DJ screen, from its Seeds
  /// row. A pick from the library drops both routes to reach the library, so
  /// the way back puts the Auto DJ screen back under the page, and Back from
  /// the page still leads there. Quick config opens the page straight over
  /// the home, with no route under it to put back: over the library, or over
  /// the open player from the queue's header, which the home opens again
  /// ([TrackCapture.onHomeCovered]).
  final bool overAutoDj;

  @override
  State<AutoDjSeedsScreen> createState() => _AutoDjSeedsScreenState();
}

class _AutoDjSeedsScreenState extends State<AutoDjSeedsScreen> {
  // The library pick this page armed last. Opened again another way while
  // it is still armed (quick config, the Auto DJ screen), the page drops it,
  // as Sonic path does: left armed, it would catch the next library tap
  // after the page closes. Another feature's pick is left alone.
  static TrackCaptureRequest? _armed;

  final List<StreamSubscription<dynamic>> _subs = [];

  // Set while Add song gathers what its sheet offers, so a second tap in
  // that moment can't open a second sheet.
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    // The way back from a pick has cleared it by now, so this drops only a
    // pick the user walked away from. Once the frame is built: the page is
    // built with its route, and the home's banner, which listens to the
    // pick, can't be marked for a rebuild in the middle of that.
    final pending = TrackCapture.pending;
    if (pending != null && identical(pending, _armed)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(TrackCapture.pending, pending)) TrackCapture.cancel();
      });
    }
    final handler = MediaManager().audioHandler;
    void redraw(dynamic _) {
      if (mounted) setState(() {});
    }

    _subs
      ..add(handler.seedsStream.listen(redraw))
      ..add(handler.customState.listen(redraw))
      ..add(AutoDJManager().changeStream.listen(redraw))
      ..add(ServerManager().capabilityChanges.listen(redraw));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // Add song for [list]. The song picked joins it pinned, as the user's own
  // row; the handler decides where it lands (held aside while the DJ is
  // off) and does nothing when the list has filled up meanwhile.
  Future<void> _add(SeedList list) async {
    if (_adding) return;
    _adding = true;
    try {
      final handler = MediaManager().audioHandler;
      // The servers whose songs the list can use right now, the home first,
      // asked again: the answer can change between the page's last build and
      // the tap. Every section offers only their songs, and the field
      // searches the first of them. With none left the sheet doesn't open,
      // and the page is drawn again from the new answer, so Add song shows
      // off.
      final servers = handler.seedAddServers(list);
      if (servers.isEmpty) {
        if (mounted) setState(() {});
        return;
      }
      final eligible = {for (final s in servers) s.localname};
      final seeds = handler.seedsStream.value;
      final less = list == SeedList.lessLike;
      // Only the rows of the list the song is for: a song in the other list
      // stays on offer, and adding it moves it over.
      final taken = {
        for (final s in less ? seeds.lessLike : seeds.moreLike) s.key,
      };
      final queue = handler.queue.value;
      final index = handler.playbackState.value.queueIndex;
      final upNext = upNextFacts(queue, index,
          eligible: eligible.contains, taken: taken);
      // Less like's Skipped opens with the song playing now, the one the user
      // may be about to skip, by Up next's rules for a row: a server song on
      // one of those servers that the list doesn't hold yet.
      final playing = less
          ? playingFacts(queue, index,
              eligible: eligible.contains, taken: taken)
          : null;
      List<PlayEvent> events;
      try {
        events = await PlayHistory().events();
      } catch (_) {
        // No history to read: the sheet still has Up next and the search.
        events = const [];
      }
      if (!mounted) return;
      final song = await showAutoDjAddSongSheet(context,
          searchServer: servers.first,
          upNext: upNext,
          playing: playing,
          skipped: less
              ? recentlySkippedIn(events, eligible, exclude: taken)
              : const [],
          recent: recentlyPlayedIn(events, eligible, exclude: taken),
          taken: taken,
          onPickFromLibrary: () => _pickFromLibrary(list, servers));
      // Added even if the page was left while a pick from the history was
      // being checked: the pick was the user's, and the lists outlive the
      // page.
      if (song != null) handler.seedAdd(list, song);
    } finally {
      _adding = false;
    }
  }

  // Add song's "Pick a song from the library": the library pick Sonic path's
  // Browse library arms (TrackCapture), for [list]. [servers] are the ones
  // whose songs the list can use, asked when Add song was tapped. As in
  // Sonic path, the pick is on the server being browsed, the library left
  // where the user was in it, when it is one of them; only when it isn't is
  // the pick on the first of them, which the library then opens on. As with
  // the sheet's own picks, that answer holds through the browse: seedAdd's
  // capacity check is the only one when the track lands.
  //
  // The page drops back to the library, whose banner names the list, along
  // with the Auto DJ screen under it ([AutoDjSeedsScreen.overAutoDj]). A
  // track tapped there joins [list] as a pick in the sheet does; that, or
  // the banner's Cancel, puts back what was there, this page on top, which
  // stays over the Auto DJ screen for the next pick too. The Auto DJ screen
  // put back shows its Seeds row, which the user may have scrolled to.
  void _pickFromLibrary(SeedList list, List<Server> servers) {
    if (!mounted) return;
    final manager = ServerManager();
    final browsed = manager.currentServer?.localname;
    final server = servers.firstWhere((s) => s.localname == browsed,
        orElse: () => servers.first);
    if (server.localname != browsed) {
      final i = manager.serverList
          .indexWhere((s) => s.localname == server.localname);
      if (i >= 0) unawaited(manager.changeCurrentServer(i));
    }
    final overAutoDj = widget.overAutoDj;
    TrackCapture.arm(_armed = TrackCaptureRequest(
      server: server,
      bannerLabel: (l) => list == SeedList.lessLike
          ? l.autoDjSeedPickBannerLess
          : l.autoDjSeedPickBannerMore,
      returnStack: [
        if (overAutoDj) (_) => const AutoDJScreen(revealSeeds: true),
        (_) => AutoDjSeedsScreen(overAutoDj: overAutoDj),
      ],
      // Runs once this page is gone: the handler only.
      onPicked: (item) => MediaManager()
          .audioHandler
          .seedAdd(list, seedFactsFromItem(item)),
    ));
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // A row's "Less like this" / "More like this": the row [key] moved to the
  // other list. As Add song does, it asks again whether that list can use the
  // row's server (and, into Less like, whether a server takes Less like songs
  // at all), since the answers can change after the page's last build, and a
  // row moved where no pick can use it would go out to no server. Refused,
  // the page is drawn again from the new answers, so the item shows off.
  void _move(String key) {
    final handler = MediaManager().audioHandler;
    final seeds = handler.seedsStream.value;
    final more = seeds.has(SeedList.moreLike, key);
    final row = (more ? seeds.moreLike : seeds.lessLike)
        .where((s) => s.key == key)
        .firstOrNull;
    final to = more ? SeedList.lessLike : SeedList.moreLike;
    if (row != null &&
        (!more || handler.seedsTakeNegatives) &&
        handler.seedAddServers(to).any((s) => s.localname == row.server)) {
      handler.seedMove(key);
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final handler = MediaManager().audioHandler;
    final mgr = AutoDJManager();
    return AutoDjSeedsView(
      seeds: handler.seedsStream.value,
      mode: mgr.sonicAnchorMode,
      takesNegatives: handler.seedsTakeNegatives,
      addServers: {
        for (final list in SeedList.values)
          list: {for (final s in handler.seedAddServers(list)) s.localname},
      },
      clearPinsOnQueueClear: mgr.clearPinsOnQueueClear,
      onMode: (mode) => unawaited(handler.setSeedMode(mode)),
      onPin: handler.seedPin,
      onMove: _move,
      onRemove: handler.seedRemove,
      onAdd: (list) => unawaited(_add(list)),
      onClearPinsOnQueueClear: (v) =>
          unawaited(mgr.setClearPinsOnQueueClear(v)),
    );
  }
}

/// The Seeds page drawn from plain values: [seeds] (the view the handler
/// shows, More like and Less like oldest first, listed newest first here, as
/// the Seeds rows' art tiles are), the [mode], whether a server in scope
/// takes Less like songs ([takesNegatives]), which servers' songs each list
/// can use ([addServers]) and the checkbox ([clearPinsOnQueueClear]). It
/// changes nothing itself: every control reports through its callback, so it
/// is tested without a handler.
///
/// In Stay close ([SonicAnchorMode.locked]) every row shows pinned and the
/// pins are locked, drawn amber all the same. While no server takes Less like
/// songs, the line "Needs a newer server" sits under the Less like header and
/// the parts of that card that do nothing are dimmed: each row's art, title
/// and artist, and pin, which is inert, and Add song, which is off. Each
/// row's ⋮ is drawn as anywhere else and still works, so rows that got in
/// earlier (an older lane, a server whose flags changed) can be moved out or
/// removed; and More like's "Less like this" is off. Add song, and a move,
/// are off while the list they fill can't take a row ([AutoDjSeeds.canAdd]:
/// eight rows, all shown pinned), and while it can't use the song's server
/// ([addServers]). Remove is always there. The checkbox works in either
/// mode, whatever the servers take.
class AutoDjSeedsView extends StatelessWidget {
  const AutoDjSeedsView({
    super.key,
    required this.seeds,
    required this.mode,
    required this.takesNegatives,
    this.addServers,
    required this.clearPinsOnQueueClear,
    required this.onMode,
    required this.onPin,
    required this.onMove,
    required this.onRemove,
    required this.onAdd,
    required this.onClearPinsOnQueueClear,
  });

  final AutoDjSeeds seeds;
  final SonicAnchorMode mode;
  final bool takesNegatives;

  /// For each list, the localnames of the servers whose songs it can use
  /// (AudioPlayerHandler.seedAddServers): Add song is off while a list's set
  /// is empty, and a row's move goes only to a list whose set holds the row's
  /// server. A list missing from the map takes none. Null puts no limit on
  /// either list.
  final Map<SeedList, Set<String>>? addServers;

  /// "Clear pins when the queue is cleared", as stored.
  final bool clearPinsOnQueueClear;

  /// Drift or Stay close chosen.
  final ValueChanged<SonicAnchorMode> onMode;

  /// The row [key] in [list] pinned or unpinned.
  final void Function(SeedList list, String key, bool pinned) onPin;

  /// The row [key] moved to the other list ("More like this" / "Less like
  /// this").
  final ValueChanged<String> onMove;

  /// The row [key] removed from [list].
  final void Function(SeedList list, String key) onRemove;

  /// Add song tapped under [list].
  final ValueChanged<SeedList> onAdd;

  /// The checkbox ticked (true) or cleared.
  final ValueChanged<bool> onClearPinsOnQueueClear;

  bool get _stayClose => mode == SonicAnchorMode.locked;

  // Stay close shows every row pinned. The mode is the manager's, and the
  // lists freeze with it; reading both keeps a row from showing unpinned
  // under Stay close in the moment before they agree.
  bool _shownPinned(AutoDjSeed s) => _stayClose || seeds.shownPinned(s);

  // Whether [list] can use a song from [server].
  bool _takesFrom(SeedList list, String server) {
    final allowed = addServers;
    return allowed == null || (allowed[list]?.contains(server) ?? false);
  }

  // Whether [list] can use a song from any server.
  bool _takesAny(SeedList list) {
    final allowed = addServers;
    return allowed == null || (allowed[list]?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.autoDjSeeds)),
      // SafeArea(bottom: true) keeps the last card clear of the system
      // gesture bar on edge-to-edge devices, as on the Auto DJ screen.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _modeChoice(l),
            _hint(context, l),
            _header(l.autoDjMoreLike),
            _list(SeedList.moreLike),
            _header(l.autoDjLessLike, tight: !takesNegatives),
            if (!takesNegatives)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(l.autoDjNeedsNewerServer,
                    key: const ValueKey('auto-dj-seeds-less-reason'),
                    style: TextStyle(
                        fontSize: 13, color: VelvetColors.textSecondary)),
              ),
            _list(SeedList.lessLike),
            // A card of its own under the lists, standing off the card above
            // as each header does: it says what becomes of the pins in both.
            const SizedBox(height: 20),
            FedCard(
              key: const ValueKey('auto-dj-seeds-clear-pins-card'),
              children: [
                _ClearPinsRow(
                  key: const ValueKey('auto-dj-seeds-clear-pins'),
                  value: clearPinsOnQueueClear,
                  onChanged: onClearPinsOnQueueClear,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Drift | Stay close, the full width, named as one group for screen
  /// readers.
  Widget _modeChoice(AppLocalizations l) => Semantics(
        container: true,
        label: l.autoDjSeedMode,
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<SonicAnchorMode>(
            key: const ValueKey('auto-dj-seeds-mode'),
            segments: [
              ButtonSegment(
                  value: SonicAnchorMode.rolling, label: Text(l.autoDjDrift)),
              ButtonSegment(
                  value: SonicAnchorMode.locked,
                  label: Text(l.autoDjStayClose)),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (set) {
              if (set.first != mode) onMode(set.first);
            },
            style: autoDjSegmentStyle(),
          ),
        ),
      );

  /// What the mode does, under the choice. A live region, so a screen reader
  /// says the new words when the mode changes, and two lines tall whichever
  /// shows, so the lists below stay put when the shorter one does.
  Widget _hint(BuildContext context, AppLocalizations l) {
    final line = MediaQuery.textScalerOf(context).scale(13) * 17 / 13;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 2 * line),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Text(
            _stayClose ? l.autoDjSeedsStayCloseHint : l.autoDjSeedsDriftHint,
            key: const ValueKey('auto-dj-seeds-hint'),
            style: TextStyle(
                fontSize: 13,
                height: 17 / 13,
                color: VelvetColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// A list's header, sentence case as on the Auto DJ screen. [tight] when
  /// a reason line follows it, which sits close under it.
  Widget _header(String text, {bool tight = false}) => Padding(
        padding: EdgeInsets.fromLTRB(14, 20, 14, tight ? 2 : 8),
        child: Semantics(
          header: true,
          headingLevel: 2,
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textSecondary)),
        ),
      );

  /// [list]'s card: its rows, newest first, then Add song.
  Widget _list(SeedList list) {
    final more = list == SeedList.moreLike;
    final rows = more ? seeds.moreLike : seeds.lessLike;
    // Less like while no server in scope can use it: its pins and its Add
    // song inert and dimmed with the rows' art and names, each row's ⋮ live.
    final inert = !more && !takesNegatives;
    // A row's move lands in the other list: Less like takes it only while a
    // server can use it, either list only while it can take a row, and only
    // a song from a server whose songs it can use.
    final other = more ? SeedList.lessLike : SeedList.moreLike;
    final otherTakes = (!more || takesNegatives) && seeds.canAdd(other);
    final canAdd = !inert && seeds.canAdd(list) && _takesAny(list);
    return FedCard(
      key: ValueKey('auto-dj-seeds-list-${list.name}'),
      children: [
        for (final s in rows.reversed)
          _SeedRow(
            key: ValueKey('auto-dj-seed-${list.name}-${s.key}'),
            seed: s,
            list: list,
            shownPinned: _shownPinned(s),
            pinnable: !_stayClose && !inert,
            dim: inert,
            canMove: otherTakes && _takesFrom(other, s.server),
            onPin: (pinned) => onPin(list, s.key, pinned),
            onMove: () => onMove(s.key),
            onRemove: () => onRemove(list, s.key),
          ),
        _AddSongRow(
          key: ValueKey('auto-dj-seeds-add-${list.name}'),
          enabled: canAdd,
          dim: !canAdd,
          onTap: () => onAdd(list),
        ),
      ],
    );
  }
}

enum _RowAction { move, remove }

/// One seed: art, title, artist, the pin and the ⋮ menu.
///
/// The pin is one toggle, "Pin <title>", on while the row shows pinned. A
/// locked pin ([pinnable] false: Stay close, or a Less like card no server
/// can use) is drawn as it stands, amber when shown pinned, and taps do
/// nothing; the icon carries its own colour, so the button's disabled state
/// doesn't grey it. [dim] draws the art, the names and the pin dimmed, one
/// layer each, and leaves the ⋮ as it is: the dimmed Less like card's rows
/// can still be moved out or removed.
class _SeedRow extends StatelessWidget {
  const _SeedRow({
    super.key,
    required this.seed,
    required this.list,
    required this.shownPinned,
    required this.pinnable,
    required this.dim,
    required this.canMove,
    required this.onPin,
    required this.onMove,
    required this.onRemove,
  });

  final AutoDjSeed seed;
  final SeedList list;
  final bool shownPinned;
  final bool pinnable;
  final bool dim;
  final bool canMove;
  final ValueChanged<bool> onPin;
  final VoidCallback onMove;
  final VoidCallback onRemove;

  Widget _dimmed(Widget part) =>
      dim ? Opacity(opacity: 0.38, child: part) : part;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = seedTitle(seed.song);
    final artist = seed.song.artist;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(children: [
          _dimmed(SeedArt(song: seed.song, size: 40)),
          const SizedBox(width: 12),
          Expanded(
            child: _dimmed(MergeSemantics(
              child: Column(
                key: const ValueKey('auto-dj-seed-names'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: VelvetColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  if (artist != null && artist.trim().isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 13)),
                  ],
                ],
              ),
            )),
          ),
          _dimmed(_pin(l, title)),
          _menu(l, title),
        ]),
      ),
    );
  }

  Widget _pin(AppLocalizations l, String title) => MergeSemantics(
        child: Semantics(
          label: l.autoDjSeedPin(title),
          toggled: shownPinned,
          child: IconButton(
            key: const ValueKey('auto-dj-seed-pin'),
            icon: shownPinned
                ? Icon(Icons.push_pin, size: 20, color: VelvetColors.primary)
                : Icon(Icons.push_pin_outlined,
                    size: 20, color: VelvetColors.textSecondary),
            onPressed: pinnable ? () => onPin(!seed.pinned) : null,
          ),
        ),
      );

  // The ⋮ menu, styled as the YouTube download rows' is, with design B's
  // items (B-RowMenu): move to the other list, then Remove, which is always
  // there.
  Widget _menu(AppLocalizations l, String title) {
    final toLess = list == SeedList.moreLike;
    return PopupMenuButton<_RowAction>(
      key: const ValueKey('auto-dj-seed-menu'),
      tooltip: l.autoDjSeedMenu(title),
      icon: Icon(Icons.more_vert, size: 22, color: VelvetColors.textSecondary),
      color: VelvetColors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: VelvetColors.border),
      ),
      itemBuilder: (_) => [
        _menuItem(
            _RowAction.move,
            toLess ? Icons.thumb_down : Icons.thumb_up,
            toLess ? l.autoDjLessLikeThis : l.autoDjMoreLikeThis,
            enabled: canMove,
            key: const ValueKey('auto-dj-seed-move')),
        _menuItem(_RowAction.remove, Icons.close, l.mainRemove,
            key: const ValueKey('auto-dj-seed-remove')),
      ],
      onSelected: (action) => switch (action) {
        _RowAction.move => onMove(),
        _RowAction.remove => onRemove(),
      },
    );
  }
}

/// A ⋮ menu item as B-RowMenu draws it: a 20 px icon in the secondary
/// colour, then the label. An item that is off greys its label; the menu
/// dims the icon itself, as it does any disabled item's.
PopupMenuItem<T> _menuItem<T>(T value, IconData icon, String label,
        {bool enabled = true, Key? key}) =>
    PopupMenuItem<T>(
      key: key,
      value: value,
      enabled: enabled,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Icon(icon, size: 20, color: VelvetColors.textSecondary),
        const SizedBox(width: 14),
        // Flexible: a long label at a large text size wraps inside the menu
        // instead of running past it.
        Flexible(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 15,
                color: enabled
                    ? VelvetColors.textPrimary
                    : VelvetColors.textTertiary),
          ),
        ),
      ]),
    );

/// A list's last row: + Add song, in amber. Off ([enabled] false) it does
/// nothing and says so to a screen reader; [dim] draws it dimmed: a list that
/// is full or can use no server's songs, or the Less like card no server can
/// use.
class _AddSongRow extends StatelessWidget {
  const _AddSongRow({
    super.key,
    required this.enabled,
    required this.dim,
    required this.onTap,
  });

  final bool enabled;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          Icon(Icons.add, size: 22, color: VelvetColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(l.autoDjAddSong,
                style: TextStyle(
                    color: VelvetColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: dim ? Opacity(opacity: 0.38, child: row) : row,
        ),
      ),
    );
  }
}

/// The page's last row, in a card of its own: a checkbox, "Clear pins when
/// the queue is cleared". The whole row flips it, and a screen reader hears
/// one checkbox with its name and state. Ticked it is drawn in amber, cleared
/// in the outline the app's other checkboxes have.
class _ClearPinsRow extends StatelessWidget {
  const _ClearPinsRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MergeSemantics(
      child: InkWell(
        // The box is the row's one keyboard stop; the row takes the taps.
        canRequestFocus: false,
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  key: const ValueKey('auto-dj-seeds-clear-pins-box'),
                  value: value,
                  activeColor: VelvetColors.primary,
                  checkColor: VelvetColors.onPrimary,
                  side: BorderSide(color: VelvetColors.textSecondary, width: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => onChanged(v ?? !value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.autoDjClearPinsOnQueueClear,
                    style: TextStyle(
                        fontSize: 15, color: VelvetColors.textPrimary)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
