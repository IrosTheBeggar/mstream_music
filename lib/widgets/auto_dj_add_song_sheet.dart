// The Seeds page's Add song sheet (board A-AddSong): a search field at the
// top, then the songs coming up in the queue (Up next), for Less like the
// song playing now and the ones skipped lately (Skipped), and the ones this
// phone played lately (Recently played) while fewer than two characters are
// typed, and the search's hits from two on. A tap on a row picks that song
// for the list the sheet was opened from. When the page asks for it, a
// "Pick a song from the library" row under the header hands the pick to the
// library instead, as Sonic path's Browse library does.
//
// It is modelled on SongPickerSheet, without that sheet's Random song row:
// a seed is a song the user means, and a random one would teach the DJ
// nothing. The field stays at the top of a draggable sheet, so the keyboard
// never covers it, and it does not take focus by itself, since the first
// thing the sheet shows is the suggestions under it. Everything it lists is
// handed in by the page, which knows the servers whose songs the list can
// use. Only the search and the check of a pick from the play history ask a
// server, and a test stands in for both.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../objects/play_event.dart';
import '../objects/server.dart';
import '../screens/auto_dj_sheets.dart' show showAutoDjSheet;
import '../singletons/api.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/auto_dj_seed_facts.dart';
import '../util/auto_dj_seeds.dart';
import 'seed_art.dart';

// What a tap in the sheet picked, and whether it came from the play history,
// the one source that can name a song the library no longer has. No song:
// the user chose to pick one from the library instead.
typedef _Pick = ({TrackFacts? song, bool fromHistory});

/// Opens the Add song sheet and answers the song picked, or null when the
/// sheet was closed without a pick or the pick was refused.
///
/// [searchServer] is the server the field searches: the first server the
/// list's songs may come from (the session's home while it may). [upNext]
/// and [recent] are the suggestions, Up next and Recently played, each hidden
/// when empty. [taken] holds the [seedKey] of every row in the list the song
/// is for, and such a song shows but can't be picked. A song in the other list
/// stays pickable: adding it moves it over.
///
/// Less like's sheet also gets a Skipped section between the two, hidden when
/// empty: [playing], the song playing now, which the user may be about to
/// skip, then [skipped], the songs skipped lately. More like's sheet passes
/// neither. Each section leaves out a song an earlier one shows: Skipped
/// drops Up next's songs, and Recently played drops Up next's and Skipped's.
///
/// A song from the play history (Recently played, and Skipped after the
/// playing row) is checked with the server first ([exists], by default
/// ApiManager.trackExists on the song's own server), because a song played
/// weeks ago may have been moved or deleted since, and a dead seed costs the
/// DJ its sonic match on every pick while it stays. When the server says it
/// is gone, the pick is refused with a snackbar on [context]'s page; a server
/// that can't say (an error, an older server) gets the benefit of the doubt,
/// as the Auto DJ start's Recently played does. Up next, the playing row and
/// the search hits come from the live queue and library and are taken as
/// they are.
///
/// With [onPickFromLibrary], a "Pick a song from the library" row sits under
/// the header: a tap closes the sheet, answers null, and then runs it, for
/// the page to hand the pick to the library the way Sonic path's Browse
/// library does.
Future<TrackFacts?> showAutoDjAddSongSheet(
  BuildContext context, {
  required Server searchServer,
  required List<TrackFacts> upNext,
  required List<TrackFacts> recent,
  required Set<String> taken,
  TrackFacts? playing,
  List<TrackFacts> skipped = const [],
  Future<List<DisplayItem>> Function(Server, String)? search,
  Future<bool?> Function(TrackFacts song)? exists,
  VoidCallback? onPickFromLibrary,
}) async {
  final pick = await showAutoDjSheet<_Pick>(
    context,
    (_) => _AddSongSheet(
      searchServer: searchServer,
      upNext: upNext,
      playing: playing,
      skipped: skipped,
      recent: recent,
      taken: taken,
      search: search ?? ApiManager().fetchSongSearch,
      library: onPickFromLibrary != null,
    ),
  );
  if (pick == null) return null;
  final song = pick.song;
  if (song == null) {
    // Run once the sheet is gone, so the page leaves for the library from
    // under no sheet of its own.
    onPickFromLibrary?.call();
    return null;
  }
  if (pick.fromHistory && await (exists ?? _trackExists)(song) == false) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).autoDjSonicSeedFailed)));
    }
    return null;
  }
  return song;
}

// Whether [song]'s server still has it. A server that has left the list can't
// be asked and can't serve the song either, so its song counts as gone.
Future<bool?> _trackExists(TrackFacts song) async {
  final owner = ServerManager().byLocalname(song.server);
  if (owner == null) return false;
  return ApiManager().trackExists(owner, song.path);
}

class _AddSongSheet extends StatefulWidget {
  const _AddSongSheet({
    required this.searchServer,
    required this.upNext,
    required this.playing,
    required this.skipped,
    required this.recent,
    required this.taken,
    required this.search,
    required this.library,
  });

  final Server searchServer;
  final List<TrackFacts> upNext;
  final TrackFacts? playing;
  final List<TrackFacts> skipped;
  final List<TrackFacts> recent;
  final Set<String> taken;
  final Future<List<DisplayItem>> Function(Server, String) search;

  /// Whether to offer "Pick a song from the library" under the header.
  final bool library;

  @override
  State<_AddSongSheet> createState() => _AddSongSheetState();
}

class _AddSongSheetState extends State<_AddSongSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;

  // Bumped by every search and by every return to the suggestions, so an
  // answer that comes back for a term no longer in the field is dropped.
  int _reqId = 0;

  // The latest answer's songs and the term it answers. Typing on keeps them
  // in place until the next answer lands, rather than blanking the list on
  // every key, and "No matches" is said only of the term in the field.
  List<TrackFacts> _hits = const [];
  String? _answered;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String get _term => _ctrl.text.trim();

  void _onChanged(String _) {
    _debounce?.cancel();
    if (_term.length < 2) {
      // Back to the suggestions at once: there is nothing to wait for, and a
      // search still out is for a term that is gone.
      _reqId++;
      setState(() {
        _hits = const [];
        _answered = null;
      });
      return;
    }
    // From two characters the field asks the server, once typing pauses.
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final term = _term;
    if (term.length < 2) return;
    final rid = ++_reqId;
    List<DisplayItem> hits;
    try {
      hits = await widget.search(widget.searchServer, term);
    } catch (_) {
      // The real search answers nothing on any failure; one that throws
      // reads the same way.
      hits = const [];
    }
    if (!mounted || rid != _reqId) return;
    setState(() {
      _hits = [for (final h in hits) seedFactsFromItem(h)];
      _answered = term;
    });
  }

  void _pick(TrackFacts song, {bool fromHistory = false}) =>
      Navigator.of(context).pop<_Pick>((song: song, fromHistory: fromHistory));

  bool _taken(TrackFacts song) =>
      widget.taken.contains(seedKey(song.server, song.path));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _titleRow(context, l),
          if (widget.library) _libraryRow(l),
          _field(l),
          Expanded(child: _body(context, l, scroll)),
        ],
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: VelvetColors.border2,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _titleRow(BuildContext context, AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
        child: SizedBox(
          height: 52,
          child: Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                headingLevel: 1,
                child: Text(l.autoDjAddSong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(
              key: const ValueKey('auto-dj-add-song-close'),
              icon: Icon(Icons.close, color: VelvetColors.textSecondary),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        ),
      );

  // "Pick a song from the library", drawn as the Seeds page's own Add song
  // row is, with Sonic path's Browse library icon. A tap answers no song;
  // the page takes it from there.
  Widget _libraryRow(AppLocalizations l) => MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            key: const ValueKey('auto-dj-add-song-library'),
            onTap: () => Navigator.of(context)
                .pop<_Pick>((song: null, fromHistory: false)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  Icon(Icons.library_music_outlined,
                      size: 22, color: VelvetColors.primary),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(l.autoDjAddSongFromLibrary,
                        style: TextStyle(
                            color: VelvetColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _field(AppLocalizations l) {
    final edge = OutlineInputBorder(
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      // Named for screen readers (merged into the field's own node); on
      // screen it shows only the placeholder, which a screen reader skips,
      // since the name already says it.
      child: MergeSemantics(
        child: Semantics(
          label: l.autoDjSearchSongs,
          child: TextField(
            key: const ValueKey('auto-dj-add-song-search'),
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (_) => _search(),
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
            cursorColor: VelvetColors.primary,
            decoration: InputDecoration(
              hint: ExcludeSemantics(
                child: Text(l.pathSearchSong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: VelvetColors.textTertiary, fontSize: 15)),
              ),
              isDense: true,
              filled: true,
              fillColor: VelvetColors.raised,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon:
                  Icon(Icons.search, size: 20, color: VelvetColors.textSecondary),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 44),
              border: edge,
              enabledBorder: edge,
              focusedBorder: edge.copyWith(
                  borderSide:
                      BorderSide(color: VelvetColors.primary, width: 1.5)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, AppLocalizations l, ScrollController scroll) {
    // Room under the last row for the system bar and an open keyboard, so
    // every row can be scrolled into view.
    final padding = EdgeInsets.only(
        bottom: 24 +
            MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom);
    final term = _term;
    if (term.length >= 2) {
      if (_hits.isNotEmpty) {
        final hits = _hits;
        return ListView.builder(
          controller: scroll,
          padding: padding,
          itemCount: hits.length,
          itemBuilder: (_, i) => _SongRow(
            key: ValueKey('auto-dj-add-song-hit-$i'),
            song: hits[i],
            taken: _taken(hits[i]),
            onTap: () => _pick(hits[i]),
          ),
        );
      }
      // Still a list, so the sheet drags from anywhere in it.
      return ListView(controller: scroll, padding: padding, children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _answered == term
                ? Text(l.discoverNothingFound,
                    key: const ValueKey('auto-dj-add-song-none'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 13))
                : SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: VelvetColors.primary),
                  ),
          ),
        ),
      ]);
    }
    final upNext = widget.upNext;
    // A song shows once, in the first section that has it: a song coming up
    // needs no check with the server, and the playing row none either.
    final shown = {for (final s in upNext) seedKey(s.server, s.path)};
    final skipped = <({TrackFacts song, bool fromHistory})>[
      for (final p in [
        if (widget.playing case final now?) (song: now, fromHistory: false),
        for (final s in widget.skipped) (song: s, fromHistory: true),
      ])
        if (shown.add(seedKey(p.song.server, p.song.path))) p,
    ];
    final recent = [
      for (final s in widget.recent)
        if (shown.add(seedKey(s.server, s.path))) s,
    ];
    return ListView(controller: scroll, padding: padding, children: [
      if (upNext.isNotEmpty) ...[
        _header(l.autoDjUpNext),
        for (var i = 0; i < upNext.length; i++)
          _SongRow(
            key: ValueKey('auto-dj-add-song-upnext-$i'),
            song: upNext[i],
            taken: _taken(upNext[i]),
            onTap: () => _pick(upNext[i]),
          ),
      ],
      if (skipped.isNotEmpty) ...[
        _header(l.autoDjSkipped),
        for (var i = 0; i < skipped.length; i++)
          _SongRow(
            key: ValueKey('auto-dj-add-song-skipped-$i'),
            song: skipped[i].song,
            taken: _taken(skipped[i].song),
            onTap: () => _pick(skipped[i].song,
                fromHistory: skipped[i].fromHistory),
          ),
      ],
      if (recent.isNotEmpty) ...[
        _header(l.autoDjRecentlyPlayed),
        for (var i = 0; i < recent.length; i++)
          _SongRow(
            key: ValueKey('auto-dj-add-song-recent-$i'),
            song: recent[i],
            taken: _taken(recent[i]),
            onTap: () => _pick(recent[i], fromHistory: true),
          ),
      ],
    ]);
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Semantics(
          header: true,
          headingLevel: 2,
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  height: 16 / 13,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textSecondary)),
        ),
      );
}

/// One song the sheet offers: art, title, artist and a +. A song the list
/// already holds ([taken]) is drawn dimmed with a check in place of the +,
/// and a tap does nothing, so a search that finds it still says it exists.
class _SongRow extends StatelessWidget {
  const _SongRow({
    super.key,
    required this.song,
    required this.taken,
    required this.onTap,
  });

  final TrackFacts song;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final artist = song.artist;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          SeedArt(song: song, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(seedTitle(song),
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
          ),
          const SizedBox(width: 12),
          Icon(taken ? Icons.check : Icons.add,
              size: 22, color: VelvetColors.textSecondary),
        ]),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: !taken,
        child: InkWell(
          onTap: taken ? null : onTap,
          child: taken ? Opacity(opacity: 0.38, child: row) : row,
        ),
      ),
    );
  }
}
