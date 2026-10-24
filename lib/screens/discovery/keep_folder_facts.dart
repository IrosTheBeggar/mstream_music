import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../objects/display_item.dart';
import '../../objects/metadata.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../theme/velvet_theme.dart';
import '../../util/browse_keep_leads.dart' show FolderRef;
import '../../util/discover_jobs.dart';

/// What Keep a copy's folder focus shows beside its landings: the folder
/// counted ("9 songs · 3 subfolders", the first files, the cap line), the
/// songs' tags for "By your layout", and — for "Into a folder…" — the
/// folders of the user's own library.
///
/// Asked only from the sheet, never on a page view, headless (no browser
/// loading bar): the count is ONE recursive listing through the connected
/// server ([Server.apiUri] rewrites the peer's virtual Server onto the
/// parent's proxy), planned as the copy plans it ([planFolder]); the tags
/// ONE metadata batch through it, for at most [kFolderTagsMax] songs; the
/// folders a listing of the user's own server per folder opened. Nothing
/// here blocks Add: the copy asks the peer itself.

/// The most songs "By your layout" reads tags for; past it the path draws
/// every tag as a slot.
const int kFolderTagsMax = 100;

/// A connected server's recursive listing of [directory] (its paths), or a
/// throw. Tests inject theirs.
typedef FolderListFetch = Future<List<String>> Function(
    Server server, String directory);

/// The full metadata of [filepaths] on [server], keyed by path (no leading
/// slash); empty when the server did not answer. Tests inject theirs.
typedef FolderTagsFetch = Future<Map<String, MusicMetadata>> Function(
    Server server, List<String> filepaths);

/// The folders in [directory] of the user's own [server], by name, or a
/// throw (one that does not exist answers an error). Tests inject theirs.
typedef OwnFoldersFetch = Future<List<String>> Function(
    Server server, String directory);

/// What a folder's facts are so far.
class KeepFolderFacts {
  /// The folder as the copy will take it ([planFolder]: its songs in path
  /// order, what it leaves out); null until counted.
  final FolderPlan? plan;

  /// The count failed (the connected server did not answer): "Couldn't
  /// count its songs". Nothing asks again by itself.
  final bool countFailed;

  /// "By your layout"'s tags, one per song in [plan]'s order
  /// ([folderSongTags]); null until read, and when none were — past
  /// [kFolderTagsMax] songs, or no answer.
  final List<FolderSongTags>? tags;

  /// The tags read is over, whatever it found.
  final bool tagsRead;

  const KeepFolderFacts({
    this.plan,
    this.countFailed = false,
    this.tags,
    this.tagsRead = false,
  });

  bool get counted => plan != null;

  /// The songs the copy takes; null until counted.
  List<FolderSong>? get songs => plan?.songs;

  /// "3 songs · no subfolders": null until counted.
  ({int songs, int subfolders})? get counts =>
      plan == null ? null : folderCounts(plan!.songs);

  /// More songs than one copy takes here ([cap]: the listing's
  /// `jobs.maxFolderSongs`; none from an older server, which says so when
  /// the job fails).
  bool overCap(int? cap) =>
      cap != null && plan != null && plan!.songs.length > cap;

  KeepFolderFacts _with({
    FolderPlan? plan,
    bool? countFailed,
    List<FolderSongTags>? tags,
    bool? tagsRead,
  }) =>
      KeepFolderFacts(
        plan: plan ?? this.plan,
        countFailed: countFailed ?? this.countFailed,
        tags: tags ?? this.tags,
        tagsRead: tagsRead ?? this.tagsRead,
      );
}

/// Loads [KeepFolderFacts] for one sheet: [peer] is the connected server's
/// virtual Server, [folder] the pressed folder. [supported] is the own
/// server's supportedAudioFiles when known (the copy leaves out what it does
/// not play); without it the count is the peer's own list — near enough.
class KeepFolderFactsLoader extends ChangeNotifier {
  final Server peer;
  final FolderRef folder;
  final Map<String, bool>? supported;
  final FolderListFetch _list;
  final FolderTagsFetch _tags;

  KeepFolderFactsLoader({
    required this.peer,
    required this.folder,
    this.supported,
    FolderListFetch? list,
    FolderTagsFetch? tags,
  })  : _list = list ?? ApiManager().recursiveListing,
        _tags = tags ?? ApiManager().fetchTrackMetadataBatch;

  KeepFolderFacts facts = const KeepFolderFacts();
  Map<String, MusicMetadata> _metadata = const {};
  Future<void>? _counting;
  Future<void>? _reading;
  bool _disposed = false;

  bool get counting => _counting != null && !facts.counted && !facts.countFailed;
  bool get readingTags => _reading != null && !facts.tagsRead;

  /// Count the folder: once (the sheet opening in folder focus, or the
  /// Folder chip first chosen); later calls join it.
  Future<void> count() => _counting ??= _count();

  Future<void> _count() async {
    try {
      final paths = await _list(peer, folder.path);
      if (_disposed) return;
      facts = facts._with(
          plan: planFolder(paths, folder.filepath, supported: supported));
    } catch (_) {
      if (_disposed) return;
      facts = facts._with(countFailed: true);
    }
    _notify();
  }

  /// The counted songs, once counted (null when the count failed) — what
  /// Play folder and Add to queue take.
  Future<List<FolderSong>?> songs() async {
    await count();
    return facts.songs;
  }

  /// "By your layout" chosen the first time: read the songs' tags once, for
  /// at most [kFolderTagsMax] songs (past it, none: every tag a slot).
  Future<void> readTags() => _reading ??= _readTags();

  Future<void> _readTags() async {
    await count();
    final songs = facts.songs;
    if (_disposed) return;
    if (songs == null || songs.isEmpty || songs.length > kFolderTagsMax) {
      facts = facts._with(tagsRead: true);
      _notify();
      return;
    }
    final read = await _tags(peer, [for (final s in songs) s.filepath]);
    if (_disposed) return;
    _metadata = read;
    facts = facts._with(
      tagsRead: true,
      tags: read.isEmpty
          ? null
          : List.unmodifiable([
              for (final s in songs) _tagsOf(s.filepath, read[s.filepath]),
            ]),
    );
    _notify();
  }

  static FolderSongTags _tagsOf(String filepath, MusicMetadata? m) =>
      folderSongTags(
        filepath,
        artist: m?.artist,
        artistDisplay: m?.artistDisplay,
        year: m?.year,
        genres: m?.genres ?? const [],
        album: m?.album,
        albumArtist: m?.albumArtist,
      );

  /// The counted songs as rows on the connected server (Play folder, Add to
  /// queue), in path order, with their tags when "By your layout" read them;
  /// null until counted.
  List<DisplayItem>? get songRows {
    final songs = facts.songs;
    if (songs == null) return null;
    return [
      for (final s in songs)
        DisplayItem(
          peer,
          s.filepath.split('/').last,
          'file',
          '/${s.filepath}',
          Icon(Icons.music_note, color: VelvetColors.accent),
          null,
        )..metadata = _metadata[s.filepath],
    ];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The folders of one folder of the user's own library ([names],
/// alphabetical), or [missing]: it does not exist yet — "No subfolders
/// here", and the note that the first file creates it.
class OwnFolders {
  final List<String> names;
  final bool missing;
  const OwnFolders(this.names, {this.missing = false});
}

/// "Into a folder…"'s folder list: the user's own server's library [vpath],
/// folder by folder as the user goes in, each asked once per sheet.
class OwnFolderLister extends ChangeNotifier {
  final Server own;
  final OwnFoldersFetch _fetch;

  OwnFolderLister({required this.own, OwnFoldersFetch? fetch})
      : _fetch = fetch ?? ApiManager().ownFolderListing;

  final Map<String, OwnFolders> _known = {};
  final Map<String, Future<OwnFolders>> _asking = {};
  bool _disposed = false;

  /// The folder's path on the own server's file explorer: '/copies' for the
  /// library's root, '/copies/Borrowed Tapes' below it.
  static String directoryOf(String vpath, String path) {
    final folders = normalizePeerPath(path);
    return folders.isEmpty ? '/$vpath' : '/$vpath/$folders';
  }

  /// What is known of [path] in [vpath] ('' its root): null while it is
  /// asked (the list reads "Looking up…") — asking it the first time.
  OwnFolders? folders(String vpath, String path) {
    final key = directoryOf(vpath, path);
    final have = _known[key];
    if (have != null) return have;
    unawaited(load(vpath, path));
    return null;
  }

  /// Ask [path] in [vpath] once (later calls join it).
  Future<OwnFolders> load(String vpath, String path) {
    final key = directoryOf(vpath, path);
    final have = _known[key];
    if (have != null) return Future.value(have);
    return _asking[key] ??= () async {
      OwnFolders out;
      try {
        out = OwnFolders(List.unmodifiable(await _fetch(own, key)));
      } catch (_) {
        out = const OwnFolders([], missing: true);
      }
      _asking.remove(key);
      if (!_disposed) {
        _known[key] = out;
        notifyListeners();
      }
      return out;
    }();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
