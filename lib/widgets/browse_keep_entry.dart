import 'dart:async';

import 'package:flutter/semantics.dart' show FocusSemanticEvent;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery_plugins.dart';
import '../objects/metadata.dart';
import '../objects/server.dart';
import '../screens/discovery/browse_copy_marks.dart';
import '../screens/discovery/discovery_jobs_controller.dart';
import '../screens/discovery/keep_copy_ui.dart';
import '../screens/discovery/peer_sheets.dart' show showBrowseKeepSheet;
import '../singletons/api.dart';
import '../theme/velvet_theme.dart';
import '../util/browse_keep_leads.dart';
import '../util/discover_badges.dart';
import '../util/discover_jobs.dart';
import 'keep_folder_glyph.dart';

/// How a browse way in opens the Keep sheet: one door for all of them
/// (peer_sheets.dart's showBrowseKeepSheet), so the pill, a card's ⋯, a
/// menu row and the queue's pane all open the same sheet the same way.
/// [marks] is the opener page's own lookup holder (the sheet reads the
/// request's state from it, and asks it again once it closes).
typedef BrowseKeepOpener = Future<void> Function(
    BuildContext context, BrowseKeepRequest request,
    {BrowseCopyMarks? marks});

/// Every browse way in to Keep a copy opens its sheet through [open], and
/// focus goes back to what opened it when the sheet closes (the phone
/// spec's focus return): the opener's own node while it is still there,
/// else the one a rebuilt opener registered under the request's stable key
/// ([KeepFocusAnchor], `{peerId}|{kind}|…`), else the page's header —
/// never the page's root.
class BrowseKeepEntry {
  BrowseKeepEntry._();

  /// The sheet itself; tests put theirs in.
  static BrowseKeepOpener opener = _sheet;

  static Future<void> _sheet(BuildContext context, BrowseKeepRequest r,
          {BrowseCopyMarks? marks}) =>
      showBrowseKeepSheet(context, r, marks: marks);

  /// Put the real sheet back (tests).
  static void reset() => opener = _sheet;

  /// The openers registered under each stable key, the latest last: two
  /// mounted at once (an album page's ⋮ and the queue's grip for the same
  /// song) each keep their place, and one going leaves the other.
  static final Map<String, List<FocusNode>> _anchors = {};

  /// The latest still-mounted opener registered under [key].
  static FocusNode? anchorOf(String key) {
    final nodes = _anchors[key];
    if (nodes == null) return null;
    for (final n in nodes.reversed) {
      if (_live(n)) return n;
    }
    return null;
  }

  /// [n] is still where focus can go: its Focus mounted (a node keeps its
  /// context after its Focus unmounts, even after it is disposed) and it
  /// may take focus.
  static bool _live(FocusNode? n) =>
      n != null && (n.context?.mounted ?? false) && n.canRequestFocus;

  /// Open [request]'s sheet from [context] with the page's [marks]; once it
  /// closes the page's mark of the opener ([markRec], when the page keys it
  /// apart from the request — a card's) is asked again (the sheet asks the
  /// request's own), [closed] runs (the page reads its gate again) and focus
  /// goes back to [from], the anchor of the request's key, or [fallback].
  static Future<void> open(
    BuildContext context,
    BrowseKeepRequest request, {
    BrowseCopyMarks? marks,
    Map<String, dynamic>? markRec,
    FocusNode? from,
    FocusNode? fallback,
    VoidCallback? closed,
  }) async {
    await opener(context, request, marks: marks);
    if (marks != null &&
        markRec != null &&
        BrowseCopyMarks.keyOf(markRec) != BrowseCopyMarks.keyOf(request.lead)) {
      unawaited(marks.reask(markRec));
    }
    closed?.call();
    // After the frame the closed sheet hands the page back in: what is
    // there then (a gate read again may have turned the pill into plain
    // text, its node gone).
    FocusNode? live(FocusNode? n) => _live(n) ? n : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final to = live(from) ?? anchorOf(request.focusKey) ?? live(fallback);
      if (to == null) return;
      to.requestFocus();
      // A screen reader's own focus follows (TalkBack moves only on the
      // event).
      to.context?.findRenderObject()?.sendSemanticsEvent(
          const FocusSemanticEvent());
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}

/// A focus node an opener of the Keep sheet carries, registered under its
/// stable key so focus finds it again after a poll rebuilt the opener
/// (BrowseKeepEntry.open). [builder] hands the node to the control.
class KeepFocusAnchor extends StatefulWidget {
  /// The opener's key (BrowseKeepRequest.focusKey); null registers nothing.
  final String? focusKey;
  final Widget Function(BuildContext context, FocusNode node) builder;
  const KeepFocusAnchor({super.key, this.focusKey, required this.builder});

  @override
  State<KeepFocusAnchor> createState() => _KeepFocusAnchorState();
}

class _KeepFocusAnchorState extends State<KeepFocusAnchor> {
  late final FocusNode _node = FocusNode(debugLabel: 'keep ${widget.focusKey}');

  void _attach(String? key) {
    if (key == null) return;
    final nodes = BrowseKeepEntry._anchors.putIfAbsent(key, () => []);
    nodes
      ..remove(_node)
      ..add(_node);
  }

  void _detach(String? key) {
    if (key == null) return;
    final nodes = BrowseKeepEntry._anchors[key];
    if (nodes == null) return;
    nodes.remove(_node);
    if (nodes.isEmpty) BrowseKeepEntry._anchors.remove(key);
  }

  @override
  void initState() {
    super.initState();
    _attach(widget.focusKey);
  }

  @override
  void didUpdateWidget(KeepFocusAnchor old) {
    super.didUpdateWidget(old);
    if (old.focusKey != widget.focusKey) {
      _detach(old.focusKey);
      _attach(widget.focusKey);
    }
  }

  @override
  void dispose() {
    _detach(widget.focusKey);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _node);
}

// ── the words a state reads in ───────────────────────────────────────────

/// A copy's state in sentence case — the page pill's word ([menu] false)
/// or a menu row's sub-line ([menu]: "Waiting for a free slot", where the
/// pill says "Waiting"). "Copying 2 of 3" once the copy says how far it
/// is, counted in songs as the cover badge counts them.
String keepStateWord(AppLocalizations l, CopyMarker m, {bool menu = false}) =>
    switch (m.kind) {
      CopyMarkerKind.waiting =>
        menu ? l.discoverJobQueued : l.browseKeepPillWaiting,
      CopyMarkerKind.copying => m.done != null && m.total != null
          ? l.browseKeepPillCopyingCount(m.done!, m.total!)
          : l.discoverJobCopying,
      CopyMarkerKind.stopping => l.discoverJobStopping,
      CopyMarkerKind.inCollection => l.discoverJobInCollection,
      CopyMarkerKind.alreadyYours => l.discoverJobOwned,
      CopyMarkerKind.skipped => l.browseKeepPillSkipped,
      CopyMarkerKind.stopped => l.discoverJobStopped,
      CopyMarkerKind.refused => l.browseKeepPillRefused,
      CopyMarkerKind.failed => l.discoverJobFailed,
    };

/// The "Keep a copy…" menu row's sub-line (the track sheet's, the folder
/// sheet's), the first that holds: the album page's album copy running
/// ([albumLive], the album's name, its job: "Copying Borrowed Tapes · 2 of
/// 3"); the item's own copy ([own]: the song's, a folder row's folder
/// copy); else where a copy goes — "To your server, from Stage Peer B".
String keepMenuSub(
  AppLocalizations l, {
  required String peer,
  CopyMarker? own,
  ({String name, DiscoveryJob job})? albumLive,
}) {
  final album = albumLive;
  if (album != null && album.job.live) {
    final counts = copyingCounts(album.job, album: album.name);
    return counts == null
        ? l.browseKeepCopyingOf(album.name)
        : l.browseKeepCopyingOfCount(album.name, counts.$1, counts.$2);
  }
  if (own != null) return keepStateWord(l, own, menu: true);
  return l.browseKeepRowSub(peer);
}

/// Where [job] puts its files, for a screen reader ("copies/Boukmanflow/
/// Borrowed Tapes"): a folder copy's own landing — where it landed, once
/// it says — and every other scope by its recommendation's tags and the
/// place pinned on it at start; a per-song slot reads as its word, an
/// artist copy ends "one folder per album". Null when it names no place.
String? keepJobInto(AppLocalizations l, DiscoveryJob job) {
  final landed = job.view.folderLanded;
  if (landed != null && landed.isNotEmpty) return landed;
  final rec = job.recommendation;
  final d = job.destination;
  final scope = jobScope(job);
  final folderOwn = scope == kScopeFolder &&
      landingMode(job.landing) == FolderLanding.folder;
  if (d == null && !folderOwn) return null;
  final t = scopeTarget(
    vpath: d?.vpath,
    base: d?.base,
    layout: d?.layout,
    scope: scope,
    tags: {
      'artist': rec['artist'],
      'album': rec['album'],
      'year': rec['year'],
      'albumartist': rec['albumArtist'],
    },
    landing: job.landing,
    folder: rec['filepath'] is String ? rec['filepath'] as String : null,
    peerName: job.peerName,
  );
  if (!t.valid) return null;
  final crumbs = [
    for (final c in t.crumbs) slotText(c, (s) => keepSlotWord(l, s)),
    if (t.perAlbum) l.discoverKeepFolderPerAlbum,
  ];
  return crumbs.isEmpty ? null : crumbs.join('/');
}

/// What a menu's Keep row knows of its item's copy when the menu opens:
/// the page's marks said ([marker], none: no copy), or they did not and the
/// row asks one lookup itself ([KeepMenuState.ask]).
class KeepMenuState {
  final bool known;
  final CopyMarker? marker;

  /// The album page's album copy (its album's name and its job): while it
  /// runs, the row says that first.
  final ({String name, DiscoveryJob job})? album;

  const KeepMenuState.known(this.marker, {this.album}) : known = true;
  const KeepMenuState.ask({this.album})
      : known = false,
        marker = null;

  /// How a menu row reads an untagged song's tags (tests answer it).
  static Future<MusicMetadata?> Function(Server peer, String filepath)
      readTags = (peer, filepath) =>
          ApiManager().fetchTrackMetadata(peer, filepath);

  /// The menu row's own ask for a song row's [request]: its copy keyed as
  /// the Keep sheet starts it — an untagged row (an explorer file with the
  /// metadata setting off) by its tags, read first, never by its file name.
  static Future<CopyMarker?> lookupSong(
      DiscoveryJobsController jobs, BrowseKeepRequest request) async {
    var rec = request.lead;
    final path = rec['filepath'];
    if (path is String &&
        !rec.containsKey('artist') &&
        !rec.containsKey('album')) {
      final m = await readTags(request.peer, path);
      if (m != null && (m.title ?? '').trim().isNotEmpty) {
        rec = songLeadFor(request.peer, path, m);
      }
    }
    return lookup(jobs, rec, kScopeSong);
  }

  /// One lookup of [rec] for its [scope]'s copy (a song's, a folder's) —
  /// the menu row's own ask when no page said. Null: no copy, or no
  /// answer.
  static Future<CopyMarker?> lookup(DiscoveryJobsController jobs,
      Map<String, dynamic> rec, String scope) async {
    final out = await jobs.lookup([rec]);
    final found = out == null || out.isEmpty ? null : out.first;
    if (found == null) return null;
    final held = jobsBySlot(found.jobs);
    return scope == kScopeFolder
        ? pageFolderMarker(held)
        : pageSongMarker(
            song: held[jobSlot(kCopyPlugin, kScopeSong)],
            filepath: rec['filepath'] as String?,
          );
  }
}

/// The "Keep a copy…" row a song's or a folder's menu gains on a connected
/// server (the track sheet's, the folder sheet's): Keep a copy's glyph in
/// gold, the title, and the sub-line ([keepMenuSub]) — "To your server,
/// from Stage Peer B" or the item's own state. With no page to say, it asks
/// once ([ask]) and the sub-line updates once. A screen reader hears "Keep
/// a copy of {title}…" with the sub-line as its value.
class KeepMenuRow extends StatefulWidget {
  /// "Keep a copy of Late Train Verse…" / "Keep a copy of the folder …".
  final String label;
  final String peerName;
  final KeepMenuState state;

  /// The row's own ask, when [state] is not known.
  final Future<CopyMarker?> Function()? ask;
  final VoidCallback onTap;

  const KeepMenuRow({
    super.key,
    required this.label,
    required this.peerName,
    required this.state,
    this.ask,
    required this.onTap,
  });

  @override
  State<KeepMenuRow> createState() => _KeepMenuRowState();
}

class _KeepMenuRowState extends State<KeepMenuRow> {
  CopyMarker? _asked;

  @override
  void initState() {
    super.initState();
    final ask = widget.ask;
    if (!widget.state.known && ask != null) {
      unawaited(ask().then((m) {
        if (mounted && m != null) setState(() => _asked = m);
      }).catchError((_) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final st = widget.state;
    final sub = keepMenuSub(l,
        peer: widget.peerName,
        own: st.known ? st.marker : _asked,
        albumLive: st.album);
    // One node: its name, the sub-line as its value, the tap on it.
    return Semantics(
      key: const ValueKey('browse-keep-menu-row'),
      container: true,
      button: true,
      label: widget.label,
      value: sub,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: ListTile(
        leading: KeepFolderGlyph(size: 24, color: keepInk()),
        title: Text(l.browseKeepButton,
            style: TextStyle(color: VelvetColors.textPrimary)),
        subtitle: Text(sub,
            style: TextStyle(fontSize: 13, color: VelvetColors.textSecondary)),
        onTap: widget.onTap,
      ),
    );
  }
}
