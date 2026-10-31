import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show FocusNode, TextEditingController, TextEditingValue, TextSelection;

import '../../l10n/app_localizations.dart';
import '../../objects/ytdl_job.dart';
import '../../singletons/ytdl_hub.dart';
import '../../util/discover_jobs.dart' show pathCrumbs;
import '../../util/ytdl_api.dart';
import '../../util/ytdl_errors.dart';
import '../../util/ytdl_filename.dart';
import '../../util/ytdl_guess.dart';
import '../../util/ytdl_layout.dart';
import '../../util/ytdl_link.dart';
import 'ytdl_crumbs.dart';

/// Where the result card's lookup stands (spec §3 Lookup, §8 States).
enum YtdlLookupState {
  idle,
  loading,
  slow,
  found,
  failed,
  timedOut,
  ytdlpMissing,
  offline,
}

enum YtdlField { title, artist, album, year }

/// The new-folder check (BUILD NOTES): whether the folders on the path are
/// there, and the listing the name check reads.
enum YtdlCheckState { idle, checking, known, unknown }

enum YtdlAddPhase { idle, starting, failed }

/// Why Add is disabled ([none] = enabled). [offline]: the lookup found no
/// connection. [ytdlpMissing]: the server has no downloader — an add would
/// be refused the same way. [convertOff]: the server's audio conversion is
/// off (a re-ping after "FFmpeg is not available yet" said so) — spec §8:
/// the button goes and [YtdlServerState.entryAllowed] is false, so the
/// home card hides; the screen or sheet stays, and the lookup still works.
/// It comes before [noLink]: the folder sheet's bar shows with no card, and
/// an empty field or a playlist must not bring the button back.
enum YtdlBlock {
  none,
  lookingUp,
  alreadyAdding,
  clashOlder,
  mkdirBlocked,
  yearInvalid,
  uploadsOff,
  noLink,
  invalidLayout,
  offline,
  ytdlpMissing,
  convertOff,
}

/// What a new-folder check found ([YtdlDraft.checkTarget]): [state] known
/// or unknown; [newSegments] the indexes into the target's segments that
/// will be made ("new"; "1 new folder will be made: Discovery"); [deepest]
/// the deepest folder that listed; [files] the target's own listing (the
/// name check), null unless the target listed.
class YtdlFolderCheck {
  final YtdlCheckState state;
  final Set<int> newSegments;
  final String? deepest;
  final List<String>? files;

  const YtdlFolderCheck({
    required this.state,
    this.newSegments = const {},
    this.deepest,
    this.files,
  });

  @override
  String toString() => 'YtdlFolderCheck(${state.name}, new $newSegments)';
}

/// Where a tag field's value came from, for its helper line.
enum YtdlFieldSource {
  music,
  videoTitle,
  videoTitleCleaned,
  youtubeArtist,

  /// The lookup's release date outside the music tier (a premiere's, a
  /// scheduled upload's): the year of an ordinary video.
  videoRelease,
  edited,
  blank,
}

/// A destination: a library and a layout under it. [kind] is the choice
/// in "Where new songs land" that made it ('artistAlbum', 'artist', 'top',
/// 'discover', 'library', 'custom'), or 'folder': a folder that is there,
/// [base] its folders below the library — the explorer's folder, "Save to
/// … instead", "Choose a folder…" — with [layout] the subfolders under it.
/// [base] is also Discover's base folders when [kind] is 'discover'.
class YtdlChoice {
  final String library;
  final String layout;
  final String kind;
  final String base;

  const YtdlChoice(
      {required this.library,
      required this.layout,
      required this.kind,
      this.base = ''});

  /// The folder [directory] ('/Music/Daft Punk/'), with [layout] under it.
  factory YtdlChoice.folder(String directory, {String layout = ''}) {
    final crumbs = pathCrumbs(directory);
    return YtdlChoice(
      library: crumbs.isEmpty ? '' : crumbs.first,
      layout: layout,
      kind: 'folder',
      base: crumbs.skip(1).join('/'),
    );
  }

  bool get isFolder => kind == 'folder';

  /// A folder choice's folder: '/Music/Daft Punk/'.
  String get folderPath =>
      '/${[library, ...pathCrumbs(base)].join('/')}/';

  @override
  bool operator ==(Object other) =>
      other is YtdlChoice &&
      other.library == library &&
      other.layout == layout &&
      other.kind == kind &&
      other.base == base;

  @override
  int get hashCode => Object.hash(library, layout, kind, base);

  @override
  String toString() => 'YtdlChoice($kind, $library, "$base", "$layout")';
}

/// A lost library's name for "You can't add files to “Music” any more":
/// the server's words when they named it, else [directory]'s first folder.
String ytdlGoneLibrary(YtdlFailure failure, String directory) {
  final named = failure.detail;
  if (named != null && named.isNotEmpty) return named;
  final crumbs = pathCrumbs(directory);
  return crumbs.isEmpty ? '' : crumbs.first;
}

final RegExp _bareStatus = RegExp(r'^HTTP \d+$');

/// The server's own words to quote for [YtdlProblem.other] ("The server
/// said: “…”"); null when it sent none (`HTTP 502`) — show "Something went
/// wrong on the server." then.
String? ytdlServerWords(YtdlFailure failure) {
  if (failure.problem != YtdlProblem.other) return null;
  final d = failure.detail?.trim();
  if (d == null || d.isEmpty || _bareStatus.hasMatch(d)) return null;
  return d;
}

final RegExp _fourDigits = RegExp(r'^\d{4}$');

/// Everything the result card, the screen and the explorer's folder sheet
/// show and do for one link (spec §3–§7): the paste field, the lookup, the
/// tags and where each came from, the destination and its new-folder and
/// name checks, the format, and the add.
///
/// One per server for the screen and one per explorer folder, kept for the
/// session ([YtdlServerState.screenDraft] / [YtdlServerState.folderDraft]):
/// leaving early loses nothing, and a lookup still running fills it. The ✕
/// ([clear]) discards it.
///
/// It listens to its [owner] and passes its changes on: the remembered
/// destination, the presets, the libraries and a re-ping's flags move
/// [target] and [block], and the new-folder check follows.
class YtdlDraft extends ChangeNotifier {
  YtdlDraft(this.owner, {this.folder}) {
    owner.addListener(_ownerChanged);
    link.addListener(_onLinkText);
    for (final f in YtdlField.values) {
      final c = TextEditingController();
      c.addListener(() => _fieldChanged(f));
      _controllers[f] = c;
      _focus[f] = FocusNode();
      _lastText[f] = '';
    }
  }

  final YtdlServerState owner;

  /// The explorer folder the sheet adds into ('/Music/Daft Punk/'); null =
  /// the home screen.
  final String? folder;

  bool get isFolderSheet => folder != null;

  /// A lookup starts this long after typing stops (a paste looks up at
  /// once); after [kSlowAfter] it reads as slow and "Enter details
  /// yourself" unlocks Add. The new-folder check runs [kCheckAfter] after
  /// the path settles.
  static const Duration kLookupDebounce = Duration(milliseconds: 400);
  static const Duration kSlowAfter = Duration(seconds: 8);
  static const Duration kCheckAfter = Duration(milliseconds: 600);

  final TextEditingController link = TextEditingController();
  final Map<YtdlField, TextEditingController> _controllers = {};
  final Map<YtdlField, FocusNode> _focus = {};
  final Map<YtdlField, String> _lastText = {};

  bool _attached = false;
  bool _disposed = false;

  // link + lookup
  String _linkText = '';
  bool _settingLink = false;
  String? _cardUrl;
  YtdlLink? _parsed;
  String? _parsedFor;
  int _rid = 0;
  Timer? _lookupTimer;
  Timer? _slowTimer;
  YtdlLookupState _lookup = YtdlLookupState.idle;
  YtdlMetadata? _meta;
  YtdlFailure? _lookupFailure;

  // tags
  YtdlGuess _guess = YtdlGuess.none;
  YtdlGuess? _late;
  bool _manual = false;
  bool _tagsOpen = false;
  YtdlField? _focusRequest;
  final Set<YtdlField> _edited = {};
  bool _filling = false;
  final Set<int> _restored = {};
  bool _stripRestored = false;
  bool _swapped = false;

  // destination
  YtdlChoice? _justThisSong;

  /// The video [_justThisSong] belongs to; null = set before any link, so
  /// the next one's.
  String? _justFor;
  String _subLayout = kYtdlLayoutTop;

  // new-folder + name check
  YtdlCheckState _check = YtdlCheckState.idle;
  String? _checkDir;
  int _checkRid = 0;
  Timer? _checkTimer;
  Future<void>? _checking;
  Set<int> _newSegments = const {};
  String? _deepest;
  List<String>? _files;

  // add
  YtdlAddPhase _addPhase = YtdlAddPhase.idle;
  YtdlFailure? _addFailure;
  String? _failedCodec;
  bool _uploadsRefused = false;

  YtdlHub get _hub => owner.hub;

  // ── showing ─────────────────────────────────────────────────────────────

  /// The screen or sheet showing this draft: its failures show inline
  /// (spec §6 failure routing), and on the screen what settles is seen.
  bool get attached => _attached;

  void attach() {
    if (_attached) return;
    _attached = true;
    // The sheet needs the tier for its name check and live note; the
    // screen asks it with the rest (onScreenOpened).
    if (isFolderSheet) unawaited(owner.probeTier());
    if (_lookup == YtdlLookupState.offline) retryLookup();
    _notify();
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    _notify();
  }

  /// The app came back to the front: a lookup that found no connection
  /// runs again ("the lookup runs when you're back").
  void resumed() {
    if (_lookup == YtdlLookupState.offline) retryLookup();
  }

  // ── link (spec §3) ──────────────────────────────────────────────────────

  YtdlLink get parsed {
    final text = link.text;
    if (_parsedFor != text) {
      _parsedFor = text;
      _parsed = parseYtdlLink(text);
    }
    return _parsed!;
  }

  /// From the field's onChanged (the field's listener does the same): a
  /// new video looks up 400 ms after typing stops.
  void linkChanged() => _onLinkText();

  /// Drives the "Paste from clipboard" chip: asks whether there is text,
  /// reading none (no Android toast, no iOS prompt until the tap).
  Future<bool> clipboardHasText() async {
    try {
      return await _hub.clipboardHasText();
    } catch (_) {
      return false;
    }
  }

  /// Fills the field from the clipboard and looks up at once.
  Future<void> pasteFromClipboard() async {
    String? text;
    try {
      text = await _hub.clipboardText();
    } catch (_) {
      return;
    }
    if (_disposed || text == null || text.trim().isEmpty) return;
    _settingLink = true;
    link.value = TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
    _settingLink = false;
    _onLinkText(immediate: true);
  }

  /// ✕ "Clear link": the whole draft goes — the link, the lookup, the
  /// edits, a just-this-song path.
  void clear() {
    _settingLink = true;
    link.clear();
    _settingLink = false;
    _linkText = '';
    _cardUrl = null;
    _resetCard();
    _justThisSong = null;
    _justFor = null;
    _subLayout = kYtdlLayoutTop;
    _dropFailure();
    _afterChange();
  }

  void _onLinkText({bool immediate = false}) {
    if (_settingLink || _disposed) return;
    final text = link.text;
    if (text == _linkText && !immediate) return;
    _linkText = text;
    final p = parsed;
    final url = p.kind == YtdlLinkKind.video ? p.url : null;
    if (url != _cardUrl) {
      // Another video (or none): the card starts again.
      _resetCard();
      _cardUrl = url;
      // A just-this-song path is its song's (spec §4): another video drops
      // it; one set before any link is the first video's.
      if (_justThisSong != null && url != null) {
        if (_justFor == null) {
          _justFor = url;
        } else if (_justFor != url) {
          _justThisSong = null;
          _justFor = null;
        }
      }
      if (url != null) {
        if (immediate) {
          _startLookup();
        } else {
          _lookupTimer = _hub.timer(kLookupDebounce, _startLookup);
        }
      }
    } else if (immediate &&
        url != null &&
        (_lookupTimer != null || _lookup == YtdlLookupState.offline)) {
      // A paste looks up at once — and pasting the link of a lookup that
      // found no connection asks again.
      _startLookup();
    }
    _afterChange();
  }

  // ── lookup (spec §3, §8) ────────────────────────────────────────────────

  YtdlLookupState get lookup => _lookup;
  YtdlMetadata? get meta => _meta;

  /// Why the lookup failed (failed / timedOut / ytdlpMissing / offline).
  YtdlFailure? get lookupFailure => _lookupFailure;

  /// The tags as read from the lookup; [YtdlGuess.none] until one is used.
  YtdlGuess get guess => _guess;

  bool get manual => _manual;

  /// "Enter details yourself" / "Enter details": the tags open, and Add no
  /// longer waits for the lookup.
  void enterManually() {
    _manual = true;
    openTags(focus: YtdlField.title);
  }

  /// "Try again": the lookup once more (also after "yt-dlp missing", which
  /// otherwise shows at once for the session).
  void retryLookup() => _startLookup(force: true);

  /// An answer came after the user typed: "Details found for this video ·
  /// Use them".
  bool get lateAnswer => _late != null;

  /// "Use them": the late answer fills only the fields nobody edited.
  void useLateAnswer() {
    final g = _late;
    if (g == null) return;
    _late = null;
    _useGuess(g);
    _afterChange();
  }

  void _startLookup({bool force = false}) {
    _lookupTimer?.cancel();
    _lookupTimer = null;
    _slowTimer?.cancel();
    final url = _cardUrl;
    if (url == null || _disposed) return;
    final rid = ++_rid;
    _lookupFailure = null;
    if (owner.ytdlpMissing && !force) {
      _lookup = YtdlLookupState.ytdlpMissing;
      _lookupFailure = const YtdlFailure(YtdlProblem.ytdlpMissing);
      _afterChange();
      return;
    }
    _lookup = YtdlLookupState.loading;
    _slowTimer = _hub.timer(kSlowAfter, () {
      if (rid != _rid || _lookup != YtdlLookupState.loading) return;
      _lookup = YtdlLookupState.slow;
      _notify();
    });
    _afterChange();
    unawaited(_runLookup(rid, url));
  }

  Future<void> _runLookup(int rid, String url) async {
    try {
      final m = await owner.api.metadata(url);
      if (_disposed || rid != _rid) return;
      _slowTimer?.cancel();
      owner.ytdlpMissing = false;
      _meta = m;
      _lookup = YtdlLookupState.found;
      final g = ytdlGuess(
          title: m.title, artist: m.artist, album: m.album, year: m.year);
      if (_edited.isEmpty) {
        _useGuess(g);
      } else {
        _late = g;
      }
      _afterChange();
    } catch (e) {
      if (_disposed || rid != _rid) return;
      _slowTimer?.cancel();
      final f = classifyYtdlLookup(e);
      _lookupFailure = f;
      _lookup = switch (f.problem) {
        YtdlProblem.ytdlpMissing => YtdlLookupState.ytdlpMissing,
        YtdlProblem.timedOut => YtdlLookupState.timedOut,
        YtdlProblem.offline => YtdlLookupState.offline,
        _ => YtdlLookupState.failed,
      };
      if (f.problem == YtdlProblem.ytdlpMissing) owner.ytdlpMissing = true;
      _afterChange();
    }
  }

  /// [g] becomes the card's reading: every field nobody edited takes its
  /// value. The YouTube-artist tier opens the tags by itself (spec §3).
  void _useGuess(YtdlGuess g) {
    _guess = g;
    _restored.clear();
    _stripRestored = false;
    _swapped = false;
    final (title, artist) = _guessPair();
    _fillUnedited(YtdlField.title, title);
    _fillUnedited(YtdlField.artist, artist);
    _fillUnedited(YtdlField.album, g.album);
    _fillUnedited(YtdlField.year, g.year);
    if (g.tier == YtdlTier.youtubeArtist) _tagsOpen = true;
  }

  // ── tags (spec §3 Result card) ──────────────────────────────────────────

  bool get tagsOpen => _tagsOpen;

  /// "Edit tags" (or a bracket warning's link): the fields open; [focus]
  /// is asked of the UI ([takeFocusRequest]) once the field is built.
  void openTags({YtdlField? focus}) {
    _tagsOpen = true;
    _focusRequest = focus;
    _notify();
  }

  /// "Edit tags" tapped again: the fields close; what they hold stays.
  void closeTags() {
    if (!_tagsOpen) return;
    _tagsOpen = false;
    _focusRequest = null;
    _notify();
  }

  /// The field [openTags] asked to focus, once (the UI calls this after
  /// building the fields and focuses it).
  YtdlField? takeFocusRequest() {
    final f = _focusRequest;
    _focusRequest = null;
    return f;
  }

  TextEditingController controllerFor(YtdlField f) => _controllers[f]!;
  FocusNode focusFor(YtdlField f) => _focus[f]!;

  /// Typed in by the user.
  bool edited(YtdlField f) => _edited.contains(f);

  String _text(YtdlField f) => _controllers[f]!.text;

  YtdlFieldSource sourceOf(YtdlField f) {
    if (_edited.contains(f)) return YtdlFieldSource.edited;
    if (_text(f).trim().isEmpty) return YtdlFieldSource.blank;
    final g = _guess;
    switch (f) {
      case YtdlField.title:
        if (_swapped) return YtdlFieldSource.videoTitle;
        if (_noiseOut) return YtdlFieldSource.videoTitleCleaned;
        return g.tier == YtdlTier.music
            ? YtdlFieldSource.music
            : YtdlFieldSource.videoTitle;
      case YtdlField.artist:
        // Swapped, the artist holds the title's half — cleaned, if noise
        // came out of it.
        if (_swapped) {
          return _noiseOut
              ? YtdlFieldSource.videoTitleCleaned
              : YtdlFieldSource.videoTitle;
        }
        return switch (g.tier) {
          YtdlTier.music => YtdlFieldSource.music,
          YtdlTier.split => _splitOut
              ? YtdlFieldSource.videoTitle
              : YtdlFieldSource.youtubeArtist,
          _ => YtdlFieldSource.youtubeArtist,
        };
      case YtdlField.album:
        // An album only ever comes with the music tier.
        return YtdlFieldSource.music;
      case YtdlField.year:
        return g.tier == YtdlTier.music
            ? YtdlFieldSource.music
            : YtdlFieldSource.videoRelease;
    }
  }

  /// A noise fragment (not the split) is still out of the title.
  bool get _noiseOut {
    final g = _guess;
    for (var i = 0; i < g.fragments.length; i++) {
      if (g.fragments[i].kind == YtdlCut.noise && !_restored.contains(i)) {
        return true;
      }
    }
    return false;
  }

  /// Fragment indexes put back (restore chips, the split, Undo all).
  Set<int> get restored => Set.unmodifiable(_restored);

  int get _splitIndex =>
      _guess.fragments.indexWhere((f) => f.kind == YtdlCut.split);
  bool get _splitOut =>
      _guess.tier == YtdlTier.split && !_restored.contains(_splitIndex);

  /// A restore chip: the fragment goes back into the title (the split
  /// gives the artist back to YouTube's).
  void restore(int fragmentIndex) {
    if (fragmentIndex < 0 ||
        fragmentIndex >= _guess.fragments.length ||
        _restored.contains(fragmentIndex)) {
      return;
    }
    _changeGuess(() {
      if (fragmentIndex == _splitIndex) _swapped = false;
      _restored.add(fragmentIndex);
    });
  }

  bool get artistStripRestored => _stripRestored;

  /// "↶ VEVO" shows: a suffix was stripped from YouTube's artist and the
  /// artist field holds it (the YouTube-artist tier, or the split undone),
  /// unedited.
  bool get canRestoreArtistStrip =>
      _guess.artistStrip != null &&
      !_stripRestored &&
      !_edited.contains(YtdlField.artist) &&
      (_guess.tier == YtdlTier.youtubeArtist ||
          (_guess.tier == YtdlTier.split && !_splitOut));

  void restoreArtistStrip() {
    if (_guess.artistStrip == null || _stripRestored) return;
    _changeGuess(() => _stripRestored = true);
  }

  /// "Cleaned from “…” · Undo all".
  bool get canUndoAll =>
      _guess.cleaned && _restored.length < _guess.fragments.length;

  void undoAll() {
    if (!canUndoAll) return;
    _changeGuess(() {
      _swapped = false;
      _restored.addAll(List.generate(_guess.fragments.length, (i) => i));
    });
  }

  /// "Swap artist and title" (split tier, for "Title - Artist").
  bool get canSwap => _splitOut;

  /// The title and artist are swapped: the restore chips hide (spec §3,
  /// the FoundCleaned board) — a piece put back would land in the artist.
  bool get swapped => _swapped;

  void swap() {
    if (!canSwap) return;
    final t = _text(YtdlField.title);
    final a = _text(YtdlField.artist);
    final te = _edited.contains(YtdlField.title);
    final ae = _edited.contains(YtdlField.artist);
    _swapped = !_swapped;
    _fill(YtdlField.title, a);
    _fill(YtdlField.artist, t);
    _mark(YtdlField.title, ae);
    _mark(YtdlField.artist, te);
    _afterChange();
  }

  /// The title and artist the guess gives now (restores, strip, swap).
  (String, String) _guessPair() {
    final title = _guess.titleWith(_restored);
    final artist = _artistValue();
    return _swapped ? (artist, title) : (title, artist);
  }

  String _artistValue() {
    final g = _guess;
    final youtube = _stripRestored ? g.youtubeArtistRaw.trim() : g.youtubeArtist;
    return switch (g.tier) {
      YtdlTier.music => g.artist,
      YtdlTier.split => _splitOut ? g.artistWith(_restored) : youtube,
      YtdlTier.youtubeArtist => youtube,
      YtdlTier.none => '',
    };
  }

  /// [change] the guess's restores; a field whose guessed value moved
  /// takes the new one (an edit there gives way: the user asked for it).
  void _changeGuess(void Function() change) {
    final (t0, a0) = _guessPair();
    change();
    final (t1, a1) = _guessPair();
    if (t1 != t0) {
      _fill(YtdlField.title, t1);
      _mark(YtdlField.title, false);
    }
    if (a1 != a0) {
      _fill(YtdlField.artist, a1);
      _mark(YtdlField.artist, false);
    }
    _afterChange();
  }

  /// Non-empty and not four digits.
  bool get yearInvalid {
    final y = _text(YtdlField.year).trim();
    return y.isNotEmpty && !_fourDigits.hasMatch(y);
  }

  /// The fields as the layout reads them (trimmed).
  YtdlTags get tags => YtdlTags(
        artist: _text(YtdlField.artist).trim(),
        album: _text(YtdlField.album).trim(),
        year: _text(YtdlField.year).trim(),
      );

  /// The title field, else the video's own title.
  String get displayTitle {
    final t = _text(YtdlField.title).trim();
    return t.isNotEmpty ? t : (_meta?.title ?? '');
  }

  /// What POST /ytdl writes: non-empty fields only, the year only as four
  /// digits.
  Map<String, String> get metadataToSend {
    final out = <String, String>{};
    final title = _text(YtdlField.title).trim();
    final t = tags;
    if (title.isNotEmpty) out['title'] = title;
    if (t.artist.isNotEmpty) out['artist'] = t.artist;
    if (t.album.isNotEmpty) out['album'] = t.album;
    if (_fourDigits.hasMatch(t.year)) out['year'] = t.year;
    return out;
  }

  void _fieldChanged(YtdlField f) {
    if (_disposed) return;
    final text = _controllers[f]!.text;
    if (text == _lastText[f]) return;
    _lastText[f] = text;
    if (!_filling) _edited.add(f);
    _afterChange();
  }

  void _fill(YtdlField f, String value) {
    final c = _controllers[f]!;
    if (c.text == value) return;
    // Known before the controller tells its listeners: no edit, no echo.
    _lastText[f] = value;
    _filling = true;
    c.value = TextEditingValue(
        text: value, selection: TextSelection.collapsed(offset: value.length));
    _filling = false;
  }

  void _fillUnedited(YtdlField f, String value) {
    if (!_edited.contains(f)) _fill(f, value);
  }

  void _mark(YtdlField f, bool edited) =>
      edited ? _edited.add(f) : _edited.remove(f);

  // ── destination ─────────────────────────────────────────────────────────

  /// The screen: the remembered choice unless a just-this-song one is set.
  /// The folder sheet: the folder on screen with [subLayout] under it.
  YtdlChoice get choice {
    final j = _justThisSong;
    if (j != null) return j;
    final f = folder;
    if (f != null) return YtdlChoice.folder(f, layout: _subLayout);
    return owner.rememberedChoice;
  }

  YtdlChoice? get justThisSong => _justThisSong;

  /// "Use for this song": SAVES TO shows "Just this song" · Undo; the
  /// remembered choice comes back once the song is sent or cleared, or
  /// another video replaces it.
  void useForThisSong(YtdlChoice c) {
    _justThisSong = c;
    _justFor = _cardUrl;
    _dropFailure();
    _afterChange();
  }

  void undoJustThisSong() {
    if (_justThisSong == null) return;
    _justThisSong = null;
    _justFor = null;
    _afterChange();
  }

  /// "Where new songs land" › Save: remembered for the server (and for
  /// this song), and the toast "Saved · new songs land in …".
  Future<void> saveChoice(YtdlChoice c) async {
    await owner.rememberDestination(
        library: c.library, layout: c.layout, kind: c.kind, base: c.base);
    if (_disposed) return;
    _justThisSong = null;
    _justFor = null;
    _dropFailure();
    _afterChange();
    final l = _hub.l10n();
    if (l != null) {
      _hub.showToast(l.ytdlToastSaved(ytdlSamplePath(l, c)), success: true);
    }
  }

  /// The folder sheet's subfolders under the folder on screen ('' = Right
  /// here). Never remembered (spec §7).
  String get subLayout => _subLayout;

  void setSubLayout(String layout) {
    if (layout == _subLayout) return;
    _subLayout = layout;
    _dropFailure();
    _afterChange();
  }

  /// A folder sheet opened afresh: its subfolder choice starts at Right
  /// here — the choice lasts for one sheet (spec §7); the link, the lookup
  /// and the edits stay. Not while the last sheet's add is still starting:
  /// it goes where it was sent, and the draft resets when it answers.
  void sheetOpened() {
    if (_addPhase == YtdlAddPhase.starting) return;
    setSubLayout(kYtdlLayoutTop);
  }

  /// Where the song lands, from the current tags and [choice].
  YtdlTarget get target => targetFor(choice);

  /// Where the song would land under [c] with the current tags — a choice
  /// not applied yet: the Where sheet's preview, the folder sheet's
  /// "Sort into subfolders" page (`YtdlChoice.folder(folder!, layout: …)`).
  /// Check it with [checkTarget].
  YtdlTarget targetFor(YtdlChoice c) {
    if (c.isFolder) {
      return ytdlFolderTarget(
          currentPath: c.folderPath, layout: c.layout, tags: tags);
    }
    return ytdlTarget(
      vpath: c.library,
      base: c.kind == 'discover' ? c.base : '',
      layout: c.layout,
      tags: tags,
    );
  }

  /// No tags to build folders from (a lookup that failed, nothing typed)
  /// and so nothing below the library: the path reads "Music › file" with
  /// "No tags yet, so it goes into the library's top folder." (spec §8).
  /// False when the song still goes into a folder (the sheet's folder, a
  /// layout's literal or Discover's base folders): show [target]'s crumbs.
  bool get lookupBlank {
    if (_lookup == YtdlLookupState.idle ||
        _lookup == YtdlLookupState.loading ||
        _lookup == YtdlLookupState.slow) {
      return false;
    }
    final t = tags;
    if (t.artist.isNotEmpty || t.album.isNotEmpty || t.year.isNotEmpty) {
      return false;
    }
    final at = target;
    return at.valid && at.segments.isEmpty;
  }

  // ── new-folder + name check (BUILD NOTES) ───────────────────────────────

  YtdlCheckState get check => _check;

  /// Indexes into [target]'s segments that will be made ("new").
  Set<int> get newSegments => _newSegments;

  /// "Couldn't check this folder": a file in the way, or nothing listed.
  bool get checkUnknown => _check == YtdlCheckState.unknown;

  /// The deepest folder on the path that listed ("Save to … instead").
  String? get deepestExisting => _deepest;

  /// The predicted file name is in the target folder's listing.
  bool get clash {
    final files = _files;
    final name = predictedName.toLowerCase();
    return _check == YtdlCheckState.known &&
        _newSegments.isEmpty &&
        files != null &&
        name.isNotEmpty &&
        files.any((f) => f.toLowerCase() == name);
  }

  /// A server before 6.30 adopts and re-tags a same-name file: blocked.
  bool get clashBlocks => clash && owner.tier != YtdlServerTier.full;

  /// 6.30+ refuses it after the download: "Add anyway", outlined.
  bool get addAnyway => clash && owner.tier == YtdlServerTier.full;

  /// The account may not make folders: noMkdir, or a mkdir refused this
  /// session (spec §8 mkdir off).
  bool get mayNotMkdir => owner.server.noMkdir == true || owner.mkdirRefused;

  /// The folder sheet's "Right here": the folder the explorer is showing,
  /// sent unchanged with no mkdir (spec §7).
  bool get _rightHere =>
      isFolderSheet && _justThisSong == null && _subLayout == kYtdlLayoutTop;

  /// The account may not make folders and one is new or unchecked: the
  /// three choices instead (spec §8 mkdir off). Never posts into an
  /// unchecked folder for this account — save the folder sheet's "Right
  /// here", the explorer's own folder, which needs none made.
  bool get mkdirBlocked =>
      mayNotMkdir &&
      !_rightHere &&
      (_newSegments.isNotEmpty || checkUnknown);

  /// "Save to Music › Daft Punk instead · Just this song".
  void saveToDeepestInstead() {
    final d = _deepest;
    if (d == null) return;
    useForThisSong(YtdlChoice.folder(d));
  }

  /// "Top of the library", just this song.
  void useTopOfLibrary() => useForThisSong(
      YtdlChoice(library: choice.library, layout: kYtdlLayoutTop, kind: 'top'));

  /// "Choose a folder…"'s answer ('/Music/Daft Punk/'), just this song.
  void useFolder(String directory) =>
      useForThisSong(YtdlChoice.folder(directory));

  /// Something changed: a new path is checked [kCheckAfter] after it
  /// settles, and listeners hear.
  void _afterChange() {
    if (_disposed) return;
    _scheduleCheck();
    _notify();
  }

  /// The owner changed (presets loaded, the remembered choice saved, a
  /// re-ping's flags, a job moved): a path it moved is checked again, and
  /// listeners hear.
  void _ownerChanged() => _afterChange();

  void _scheduleCheck() {
    final t = target;
    final dir = _cardUrl != null && t.valid ? t.directory : null;
    if (dir == _checkDir) return;
    _checkDir = dir;
    final rid = ++_checkRid;
    _checkTimer?.cancel();
    _checkTimer = null;
    _checking = null;
    _newSegments = const {};
    _deepest = null;
    _files = null;
    if (dir == null) {
      _check = YtdlCheckState.idle;
      return;
    }
    _check = YtdlCheckState.checking;
    _checkTimer = _hub.timer(kCheckAfter, () {
      _checkTimer = null;
      _checking = _runCheck(rid, t);
    });
  }

  /// The path checked again at once, after an add that ran a mkdir
  /// failed. What the last check found stands until a listing answers: a
  /// re-check that lists nothing (no connection) changes nothing, and one
  /// for a path since left is dropped.
  void _recheck() {
    final t = target;
    if (_cardUrl == null || !t.valid || _checkDir != t.directory) return;
    final rid = _checkRid;
    unawaited(_walk(t, () => _disposed || rid != _checkRid).then((found) {
      if (found == null || found.state != YtdlCheckState.known) return;
      _check = found.state;
      _newSegments = found.newSegments;
      _deepest = found.deepest;
      _files = found.files;
      _notify();
    }));
  }

  /// The check for the path now, at once (the add waits for it).
  Future<void> _checkNow() {
    final out = _checking;
    if (out != null) return out;
    _checkTimer?.cancel();
    _checkTimer = null;
    final t = target;
    return _checking = _runCheck(_checkRid, t);
  }

  /// The check answered for [directory] (not for a path the target has
  /// since left).
  bool _checkedFor(String directory) =>
      _checkDir == directory &&
      (_check == YtdlCheckState.known || _check == YtdlCheckState.unknown);

  /// Wait until the check has answered for the target as it is now — a
  /// lookup answer or a tag typed during "Starting…" moves it, and the
  /// add must never post into a path it did not check. False when it
  /// kept moving.
  Future<bool> _awaitCheck() async {
    for (var i = 0; i < 4; i++) {
      final t = target;
      if (!t.valid) return false;
      if (_checkedFor(t.directory)) return true;
      if (_checkDir != t.directory) _scheduleCheck();
      await _checkNow();
      if (_disposed) return false;
    }
    final t = target;
    return t.valid && _checkedFor(t.directory);
  }

  Future<void> _runCheck(int rid, YtdlTarget t) async {
    final found = await _walk(t, () => _disposed || rid != _checkRid);
    if (found == null) return;
    _check = found.state;
    _newSegments = found.newSegments;
    _deepest = found.deepest;
    _files = found.files;
    _notify();
  }

  /// The new-folder check for [t] without touching this draft's own
  /// ([check], [newSegments] …): for a choice not applied yet ([targetFor])
  /// — the "Sort into subfolders" page's "1 new folder will be made:
  /// Discovery", the Where sheet's "new" tags under "Same as Discover".
  /// The caller drops an answer for a path it has since left. Unknown for
  /// a target that isn't valid.
  Future<YtdlFolderCheck> checkTarget(YtdlTarget t) async {
    if (!t.valid) return const YtdlFolderCheck(state: YtdlCheckState.unknown);
    return await _walk(t, () => _disposed) ??
        const YtdlFolderCheck(state: YtdlCheckState.unknown);
  }

  /// List the target; on any error walk up until a listing works. The
  /// folder below the one that listed is new when that listing has no
  /// folder of its name (ignoring case) — and every folder after it too; a
  /// file of that name, or a folder that would not list, or no listing at
  /// all, is unknown. The target's own listing feeds the name check — and
  /// when the target won't list but the explorer is showing it (the folder
  /// sheet's Right here), the rows already loaded do (spec §7): an older
  /// server would re-tag the same-name file they show. Null once [stale]
  /// says the answer is no longer wanted.
  Future<YtdlFolderCheck?> _walk(YtdlTarget t, bool Function() stale) async {
    final segments = t.segments;
    for (var depth = segments.length; depth >= 0; depth--) {
      final dir = _dirOf(t.library, segments.take(depth));
      final YtdlListing listing;
      try {
        listing = await owner.api.list(dir);
      } catch (_) {
        if (stale()) return null;
        final shown = depth == segments.length
            ? _hub.explorerFiles(owner.server, dir)
            : null;
        if (shown != null) {
          return YtdlFolderCheck(
              state: YtdlCheckState.known, deepest: dir, files: shown);
        }
        continue;
      }
      if (stale()) return null;
      if (depth == segments.length) {
        return YtdlFolderCheck(
            state: YtdlCheckState.known, deepest: dir, files: listing.files);
      }
      final next = segments[depth].toLowerCase();
      final there = listing.directories.any((d) => d.toLowerCase() == next) ||
          listing.files.any((f) => f.toLowerCase() == next);
      return YtdlFolderCheck(
        state: there ? YtdlCheckState.unknown : YtdlCheckState.known,
        newSegments: there
            ? const {}
            : {for (var i = depth; i < segments.length; i++) i},
        deepest: dir,
      );
    }
    if (stale()) return null;
    return const YtdlFolderCheck(state: YtdlCheckState.unknown);
  }

  static String _dirOf(String library, Iterable<String> segments) =>
      segments.isEmpty ? '/$library/' : '/$library/${segments.join('/')}/';

  // ── file name ───────────────────────────────────────────────────────────

  /// "about One_More_Time.mp3": yt-dlp's restricted name of the video's
  /// own title in the chosen format; '' without a lookup.
  String get predictedName {
    final raw = _meta?.title ?? '';
    return raw.isEmpty ? '' : ytdlPredictedFileName(raw, format);
  }

  /// "letters outside A–Z are dropped from file names".
  bool get dropsLetters {
    final raw = _meta?.title ?? '';
    return raw.isNotEmpty && ytdlNameDropsLetters(raw);
  }

  // ── format (spec §5) ────────────────────────────────────────────────────

  List<String> get formats => owner.formats;
  String get format => owner.format;

  /// Remembered for the server.
  Future<void> setFormat(String codec) async {
    _dropFailure();
    await owner.rememberFormat(codec);
    _afterChange();
  }

  // ── add (spec §6) ───────────────────────────────────────────────────────

  /// [YtdlAddPhase.failed] exactly while [addFailure] is set.
  YtdlAddPhase get addPhase => _addPhase;

  /// The failure the screen or sheet shows inline (it was showing when it
  /// arrived, with this link on the card). A lost library's name:
  /// [ytdlGoneLibrary]. [YtdlProblem.mkdirFailed]: "Couldn't make the
  /// folder “{detail}”." with Try again and Choose a folder… (spec §8).
  YtdlFailure? get addFailure => _addFailure;

  /// No failure shows any more; the button is back from "Try again".
  void _dropFailure() {
    _addFailure = null;
    if (_addPhase == YtdlAddPhase.failed) _addPhase = YtdlAddPhase.idle;
  }

  /// The format the failed add asked for ("This server doesn't save Opus
  /// any more"); the remembered one has already reset.
  String? get failedCodec => _failedCodec;

  /// An open job adds this link to this folder — this draft's own add too,
  /// once the hub holds it: [block] leaves that one out while it starts.
  bool get alreadyAdding {
    final url = _cardUrl;
    final t = target;
    return url != null && t.valid && owner.isAdding(url, t.directory);
  }

  YtdlBlock get block {
    if (owner.server.transcodeAvailable == false) return YtdlBlock.convertOff;
    if (parsed.kind != YtdlLinkKind.video) return YtdlBlock.noLink;
    if (_lookup == YtdlLookupState.offline) return YtdlBlock.offline;
    if (_lookup == YtdlLookupState.ytdlpMissing) return YtdlBlock.ytdlpMissing;
    if (!_manual &&
        (_lookup == YtdlLookupState.idle ||
            _lookup == YtdlLookupState.loading ||
            _lookup == YtdlLookupState.slow)) {
      return YtdlBlock.lookingUp;
    }
    if (owner.server.noUpload == true || _uploadsRefused) {
      return YtdlBlock.uploadsOff;
    }
    // While this draft's add starts, the open job is its own: "Starting…"
    // says so (spec §3: the note is for an earlier add).
    if (_addPhase != YtdlAddPhase.starting && alreadyAdding) {
      return YtdlBlock.alreadyAdding;
    }
    if (!target.valid) return YtdlBlock.invalidLayout;
    if (yearInvalid) return YtdlBlock.yearInvalid;
    if (mkdirBlocked) return YtdlBlock.mkdirBlocked;
    if (clashBlocks) return YtdlBlock.clashOlder;
    return YtdlBlock.none;
  }

  /// Add to library / Add here. Waits for the new-folder check, then the
  /// hub runs the mkdir (a folder new or unknown, and the account may make
  /// folders; never for the sheet's "Right here") and the POST. True when
  /// the server took it (or may have: a timed-out POST is looked for) —
  /// the draft resets: field cleared, tags closed, lookup idle,
  /// just-this-song dropped, focus gone; the remembered choice stays.
  ///
  /// The add posts only into the path its check answered for: when the
  /// target moves while it waits (the lookup answers, a tag is typed), the
  /// new path is checked first; one that never settles is treated as
  /// unchecked — made first when the account may, refused under noMkdir.
  /// A failure shows inline only while this surface shows the same link;
  /// otherwise (another link pasted, ✕, the screen gone) it is a
  /// "Couldn't add" row and toast.
  Future<bool> add() async {
    if (_addPhase == YtdlAddPhase.starting || block != YtdlBlock.none) {
      return false;
    }
    _addPhase = YtdlAddPhase.starting;
    _addFailure = null;
    _notify();
    final checked = await _awaitCheck();
    if (_disposed) return false;
    final rightHere = _rightHere;
    // An add of this link to this folder that started while the check
    // ran (the other surface's): this one's own job isn't held yet.
    if (block != YtdlBlock.none ||
        alreadyAdding ||
        (!checked && !rightHere && mayNotMkdir)) {
      _addPhase = YtdlAddPhase.idle;
      _afterChange();
      return false;
    }
    final url = _cardUrl!;
    final t = target;
    final codec = format;
    final makeFolder = !rightHere &&
        !mayNotMkdir &&
        (_newSegments.isNotEmpty || checkUnknown || !checked);
    final firstNew = _newSegments.isEmpty
        ? null
        : _newSegments.reduce((a, b) => a < b ? a : b);
    final outcome = await owner.start(YtdlStartRequest(
      url: url,
      directory: t.directory,
      codec: codec,
      metadata: metadataToSend,
      title: displayTitle,
      cover: _meta?.thumbnail,
      predictedName: predictedName,
      mkdir: makeFolder ? t.directory : null,
      mkdirFolder:
          makeFolder && firstNew != null && firstNew < t.segments.length
              ? t.segments[firstNew]
              : null,
      origin: isFolderSheet ? 'folder:$folder' : 'screen',
      inline: () => _attached && !_disposed && _cardUrl == url,
    ));
    if (_disposed) return outcome.ok || outcome.timedOut;
    if (outcome.ok || outcome.timedOut) {
      // A link changed while it started is a new card: it stays.
      if (_cardUrl == url) {
        _resetAfterSend();
      } else {
        _addPhase = YtdlAddPhase.idle;
        if (_justFor == url) {
          _justThisSong = null;
          _justFor = null;
        }
        _afterChange();
      }
      return true;
    }
    final failure = outcome.failure;
    if (failure?.problem == YtdlProblem.uploadsOff) _uploadsRefused = true;
    // The mkdir ran: the folders may be there now, all or some, whether it
    // failed (its answer lost after the server made them) or the add after
    // it did. No "new" tag outlives them.
    if (makeFolder) _recheck();
    if (outcome.job?.state == YtdlJobState.startFailed ||
        failure == null ||
        _cardUrl != url) {
      // Routed to a row and a toast: the surface was gone, or shows
      // another link now.
      _addPhase = YtdlAddPhase.idle;
    } else {
      _addPhase = YtdlAddPhase.failed;
      _addFailure = failure;
      _failedCodec = codec;
    }
    _afterChange();
    return false;
  }

  void _resetAfterSend() {
    _settingLink = true;
    link.clear();
    _settingLink = false;
    _linkText = '';
    _cardUrl = null;
    _resetCard();
    _justThisSong = null;
    _justFor = null;
    _subLayout = kYtdlLayoutTop;
    _addPhase = YtdlAddPhase.idle;
    _addFailure = null;
    for (final n in _focus.values) {
      n.unfocus();
    }
    _afterChange();
  }

  /// Everything that belongs to one video: the lookup, the tags and their
  /// edits, an inline failure.
  void _resetCard() {
    _lookupTimer?.cancel();
    _lookupTimer = null;
    _slowTimer?.cancel();
    _slowTimer = null;
    _rid++;
    _lookup = YtdlLookupState.idle;
    _meta = null;
    _lookupFailure = null;
    _guess = YtdlGuess.none;
    _late = null;
    _manual = false;
    _tagsOpen = false;
    _focusRequest = null;
    _restored.clear();
    _stripRestored = false;
    _swapped = false;
    for (final f in YtdlField.values) {
      _fill(f, '');
    }
    _edited.clear();
    _dropFailure();
  }

  // ── plumbing ────────────────────────────────────────────────────────────

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    owner.removeListener(_ownerChanged);
    _lookupTimer?.cancel();
    _slowTimer?.cancel();
    _checkTimer?.cancel();
    link.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focus.values) {
      n.dispose();
    }
    super.dispose();
  }
}

final RegExp _token = RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}');

/// [c] as a path with sample words for its variables: "Music › Artist ›
/// Album" (the Saved toast; the preview before a link is pasted). A folder
/// choice reads its own folders.
String ytdlSamplePath(AppLocalizations l, YtdlChoice c) {
  String word(String name) => switch (name.toUpperCase()) {
        'ARTIST' || 'ALBUMARTIST' => l.torrentArtistLabel,
        'ALBUM' => l.torrentAlbumLabel,
        'YEAR' => l.torrentYearLabel,
        _ => '',
      };
  final folders = c.layout
      .replaceAllMapped(_token, (m) => word(m[1]!))
      .split(RegExp(r'[/\\]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  return ytdlPathText([
    c.library,
    if (c.isFolder || c.kind == 'discover') ...pathCrumbs(c.base),
    ...folders,
  ]);
}
