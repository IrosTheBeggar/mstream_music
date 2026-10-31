import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart'
    show kMaxLayoutLength, kMaxPathLength, foldBase, pathCrumbs;
import '../../util/ytdl_filename.dart';
import '../../util/ytdl_layout.dart';
import '../../util/ytdl_link.dart';
import '../discovery/destination_pieces.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart';

/// "Change" on the Add from YouTube screen: where new songs land (spec §4,
/// the WhereSheet / WhereCustom / YearTrap boards). A library and a layout
/// under it — Artist / Album, Artist, Top of the library, Same as Discover
/// (the account's own Discover destination, read only), the library's own
/// layout, or Custom (held to the YouTube allow-list as it is typed) —
/// kept on this phone for the server ([YtdlDraft.saveChoice]) or used for
/// the song on the card only ([YtdlDraft.useForThisSong]). Closing it any
/// other way drops what changed. The account destination is never written.
///
/// The preview is of the choice being edited, not the one applied: the
/// draft renders it with the card's tags ([YtdlDraft.targetFor]) and checks
/// which of its folders are new ([YtdlDraft.checkTarget]). Before a link is
/// pasted it reads with sample words ("Music › Artist › Album ›
/// Video_title.mp3"). A folder an empty tag leaves as brackets ("()",
/// "Discovery ()") is warned about, with a link that closes the sheet,
/// keeps the choice for this song and opens the card's field that fills it.
Future<void> showYtdlWhereSheet(BuildContext context, YtdlDraft draft) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.89,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => YtdlWhereSheet(draft: draft),
    );

/// The variables a layout reads ("{{ ALBUM }}" too, as the engine does).
final RegExp _token = RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}');

/// A layout's folders as typed, edges trimmed, empty ones dropped.
List<String> _folders(String layout) => layout
    .split(RegExp(r'[/\\]+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// How long the preview waits after the last change before it is read out
/// (spec §9: a polite live region, after 800 ms without typing).
const Duration _kSpeakAfter = Duration(milliseconds: 800);

/// The sheet's body ([showYtdlWhereSheet] opens it) for the screen's
/// [draft]: what it edits is applied only by Save or Use for this song.
class YtdlWhereSheet extends StatefulWidget {
  final YtdlDraft draft;
  const YtdlWhereSheet({super.key, required this.draft});

  @override
  State<YtdlWhereSheet> createState() => _YtdlWhereSheetState();
}

class _YtdlWhereSheetState extends State<YtdlWhereSheet> {
  /// The library the chips pick (Discover's own stands in while "Same as
  /// Discover" is chosen, and this one comes back with any other layout).
  late String _library;

  /// 'artistAlbum' | 'artist' | 'top' | 'discover' | 'library' | 'custom'.
  late String _kind;

  /// Custom's field: the layout while Custom is chosen; what was typed
  /// stays while a preset is chosen.
  final TextEditingController _custom = TextEditingController();
  final FocusNode _customFocus = FocusNode();
  String _customTyped = '';

  /// The choice the form last took from the draft: while the form still
  /// holds it, a new remembered choice (the presets answering) moves it.
  late YtdlChoice _synced;

  bool _saving = false;

  /// The preview's new-folder check: the directory it is for, and the
  /// crumb indexes it found new (crumb = segment + 1).
  String? _checkDir;
  Set<int> _newAt = const {};
  Timer? _checkTimer;

  /// The preview as read out: it follows the screen [_kSpeakAfter] after
  /// the last change, so a screen reader hears where the song lands once,
  /// not on every keystroke.
  String? _spoken;
  String? _spokenNext;
  Timer? _speakTimer;

  YtdlDraft get draft => widget.draft;
  YtdlServerState get st => draft.owner;

  @override
  void initState() {
    super.initState();
    _take(_opening);
    draft.addListener(_onDraft);
    _custom.addListener(_onCustomTyping);
    _customFocus.addListener(_onFocus);
    // "Same as Discover" and "Library layout" come from the account; read
    // once per session (the screen asks too).
    unawaited(st.loadPresets());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _afterChange();
  }

  @override
  void dispose() {
    draft.removeListener(_onDraft);
    _custom.removeListener(_onCustomTyping);
    _customFocus.removeListener(_onFocus);
    _checkTimer?.cancel();
    _speakTimer?.cancel();
    _custom.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  // ── the form ──────────────────────────────────────────────────────────

  /// What the sheet opens on: the choice in force — a just-this-song one
  /// too — unless that is a folder ("Save to … instead", "Choose a
  /// folder…"), which no layout here names: the remembered one then.
  YtdlChoice get _opening {
    final c = draft.choice;
    return c.isFolder ? st.rememberedChoice : c;
  }

  void _take(YtdlChoice c) {
    _synced = c;
    _kind = c.kind;
    _library = c.kind == 'discover' ? st.library : c.library;
    if (c.kind == 'custom') _setCustom(c.layout);
  }

  void _setCustom(String layout) {
    _customTyped = layout;
    if (_custom.text != layout) _custom.text = layout;
  }

  /// Discover's destination for "Same as Discover": the account's own
  /// (source 'user'), or, until the presets answer, the remembered copy
  /// the sheet opened on.
  ({String vpath, String base, String layout})? get _discover {
    final d = st.discoverDestination;
    if (d != null) return (vpath: d.vpath, base: d.base, layout: d.layout);
    if (!st.presetsLoaded && _synced.kind == 'discover') {
      return (
        vpath: _synced.library,
        base: _synced.base,
        layout: _synced.layout,
      );
    }
    return null;
  }

  /// The chosen library's own layout, offered when it is set and none of
  /// the presets above it (still offered on the library it was saved for);
  /// until the presets answer, the remembered copy.
  String? get _template {
    final saved = _synced.kind == 'library' && _synced.library == _library;
    final t = st.libraryTemplates[_library] ??
        (!st.presetsLoaded && saved ? _synced.layout : null);
    if (t == null || t.trim().isEmpty) return null;
    final dupe = t == kYtdlLayoutArtistAlbum || t == kYtdlLayoutArtist;
    return dupe && !saved ? null : t;
  }

  /// The choice the form holds.
  YtdlChoice get _choice {
    switch (_kind) {
      case 'artistAlbum':
        return YtdlChoice(
            library: _library, layout: kYtdlLayoutArtistAlbum, kind: _kind);
      case 'artist':
        return YtdlChoice(
            library: _library, layout: kYtdlLayoutArtist, kind: _kind);
      case 'top':
        return YtdlChoice(
            library: _library, layout: kYtdlLayoutTop, kind: _kind);
      case 'discover':
        final d = _discover;
        if (d != null) {
          return YtdlChoice(
              library: d.vpath, layout: d.layout, kind: _kind, base: d.base);
        }
      case 'library':
        final t = _template;
        if (t != null) {
          return YtdlChoice(library: _library, layout: t, kind: _kind);
        }
    }
    return YtdlChoice(library: _library, layout: _custom.text, kind: 'custom');
  }

  /// Custom's own check, as typed (null while another layout is chosen or
  /// the field is empty).
  YtdlLayoutCheck? get _customCheck =>
      _kind == 'custom' && _custom.text.isNotEmpty
          ? ytdlLayoutCheck(_custom.text)
          : null;

  bool get _customEmpty => _kind == 'custom' && _custom.text.trim().isEmpty;

  /// Where the edited choice lands, and whether it may be used.
  YtdlTarget get _target => draft.targetFor(_choice);

  bool _valid(YtdlTarget t) =>
      !_customEmpty && (_customCheck?.valid ?? true) && t.valid;

  /// Saved here is a change from what this server remembers; used for this
  /// song, a change from what the card has now.
  bool _canSave(YtdlTarget t) =>
      _valid(t) && !_saving && _choice != st.rememberedChoice;
  bool _canUse(YtdlTarget t) =>
      _valid(t) && !_saving && _choice != draft.choice;

  bool get _mayNotMkdir => st.server.noMkdir == true || st.mkdirRefused;

  /// Before a link is pasted — or while it is looked up with nothing typed
  /// — there are no tags: the preview reads with sample words.
  bool get _sample {
    if (draft.parsed.kind != YtdlLinkKind.video) return true;
    final waiting = !draft.manual &&
        (draft.lookup == YtdlLookupState.idle ||
            draft.lookup == YtdlLookupState.loading ||
            draft.lookup == YtdlLookupState.slow);
    final t = draft.tags;
    return waiting && t.artist.isEmpty && t.album.isEmpty && t.year.isEmpty;
  }

  void _edit(void Function() change) {
    setState(change);
    _afterChange();
  }

  void _pickLibrary(String vpath) => _edit(() {
        final template = _template;
        _library = vpath;
        // A library's own layout leaving with it stays the layout, in
        // Custom's field (the Discover sheet does the same).
        if (_kind == 'library' && _template == null && template != null) {
          _kind = 'custom';
          _setCustom(template);
        }
      });

  void _pickLayout(String kind) => _edit(() => _kind = kind);

  /// Custom chosen: its field opens with the keyboard up, holding the
  /// layout chosen until now when nothing was typed in it.
  void _pickCustom() {
    if (_kind == 'custom') {
      _customFocus.requestFocus();
      return;
    }
    _edit(() {
      final was = _choice;
      if (_custom.text.isEmpty && was.layout.isNotEmpty) {
        _setCustom(was.kind == 'discover'
            ? foldBase(was.base, was.layout)
            : was.layout);
      }
      _kind = 'custom';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _kind == 'custom') _customFocus.requestFocus();
    });
  }

  void _onCustomTyping() {
    if (!mounted || _custom.text == _customTyped) return;
    _customTyped = _custom.text;
    _edit(() {});
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  /// The draft moved (a lookup answered, the presets came in, a re-ping):
  /// a form nobody touched follows the choice in force; a preset that went
  /// away leaves its layout in Custom's field.
  void _onDraft() {
    if (!mounted) return;
    if (!st.entryAllowed) {
      _close();
      return;
    }
    final open = _opening;
    if (open != _synced && _choice == _synced) _take(open);
    if (_kind == 'discover' && _discover == null) {
      _kind = 'custom';
      _setCustom(_synced.kind == 'discover'
          ? foldBase(_synced.base, _synced.layout)
          : _custom.text);
    }
    if (_kind == 'library' && _template == null) {
      _kind = 'custom';
      if (_synced.kind == 'library') _setCustom(_synced.layout);
    }
    setState(() {});
    _afterChange();
  }

  void _close() {
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final c = _choice;
    setState(() => _saving = true);
    await draft.saveChoice(c);
    if (!mounted) return;
    setState(() => _saving = false);
    _close();
  }

  void _useForThisSong() {
    final c = _choice;
    _close();
    draft.useForThisSong(c);
  }

  /// A bracket warning's link: the sheet closes, the choice holds for this
  /// song (as "Use for this song" does), and the card opens [field].
  void _fillTag(YtdlField field) {
    final c = _choice;
    _close();
    if (c != draft.choice) draft.useForThisSong(c);
    draft.openTags(focus: field);
  }

  // ── the preview's check and voice ─────────────────────────────────────

  /// Something moved: the preview's folders are checked again
  /// [YtdlDraft.kCheckAfter] after they settle (a path the card has
  /// checked already is taken from it), and the preview is read again
  /// [_kSpeakAfter] after it settles.
  void _afterChange() {
    if (!mounted) return;
    final t = _target;
    final sample = _sample;
    final dir =
        !sample && _valid(t) && t.segments.isNotEmpty ? t.directory : null;
    if (dir != _checkDir) {
      _checkDir = dir;
      _newAt = const {};
      _checkTimer?.cancel();
      _checkTimer = null;
      if (dir != null) {
        if (draft.check == YtdlCheckState.known &&
            draft.target.directory == dir) {
          _newAt = {for (final i in draft.newSegments) i + 1};
        } else {
          _checkTimer = st.hub.timer(YtdlDraft.kCheckAfter, () async {
            _checkTimer = null;
            final found = await draft.checkTarget(t);
            // An answer for a path the form has since left is dropped.
            if (!mounted || _checkDir != dir) return;
            setState(() => _newAt = {for (final i in found.newSegments) i + 1});
            _afterChange();
          });
        }
      }
    }
    final words = _model(AppLocalizations.of(context)).spoken;
    if (_spoken == null) {
      _spoken = _spokenNext = words;
    } else if (words != _spokenNext) {
      _spokenNext = words;
      _speakTimer?.cancel();
      _speakTimer = st.hub.timer(_kSpeakAfter, () {
        if (mounted) setState(() => _spoken = _spokenNext);
      });
    }
  }

  /// What the preview shows for the form as it is.
  _Preview _model(AppLocalizations l) {
    final c = _choice;
    final t = _target;
    if (_customEmpty) {
      return _Preview.blocked(l.discoverDestCustomEmpty, warn: false);
    }
    if (!_valid(t)) {
      return _Preview.blocked(t.error == 'path_too_long'
          ? l.discoverDestPathTooLong(kMaxPathLength)
          : l.discoverDestFixLayout);
    }
    final sample = _sample;
    final base = c.kind == 'discover' ? pathCrumbs(c.base) : const <String>[];
    final List<String> crumbs;
    final Set<int> slots;
    if (sample) {
      String word(String name) => switch (name.toUpperCase()) {
            'ARTIST' || 'ALBUMARTIST' => l.torrentArtistLabel,
            'ALBUM' => l.torrentAlbumLabel,
            'YEAR' => l.torrentYearLabel,
            _ => '',
          };
      final folders = [
        for (final f in _folders(c.layout))
          (f.replaceAllMapped(_token, (m) => word(m[1]!)).trim(),
              _token.hasMatch(f)),
      ].where((f) => f.$1.isNotEmpty).toList();
      crumbs = [c.library, ...base, for (final f in folders) f.$1];
      slots = {
        for (var i = 0; i < folders.length; i++)
          if (folders[i].$2) 1 + base.length + i,
      };
    } else {
      crumbs = t.crumbs;
      // A folder a variable filled reads as a slot; the layout's own
      // words and Discover's base folders read as typed.
      final literal = {
        for (final f in _folders(c.layout))
          if (!_token.hasMatch(f)) f,
      };
      slots = {
        for (var i = 1 + base.length; i < crumbs.length; i++)
          if (!literal.contains(crumbs[i])) i,
      };
    }
    final trap = sample ? null : t.trap;
    final trapAt = <int>{};
    if (trap != null) {
      final i = crumbs.lastIndexOf(trap.folder);
      if (i > 0) trapAt.add(i);
    }
    final named = sample ? '' : draft.predictedName;
    final file = named.isNotEmpty
        ? named
        : '${l.ytdlSampleFileStem}.${ytdlOutputExtension(draft.format)}';
    final title = sample ? '' : draft.displayTitle;
    final label =
        title.isEmpty ? l.ytdlWhereLandsAtSample : l.ytdlWhereLandsAt(title);
    final newAt = sample ? const <int>{} : _newAt;
    final notes = <(String, Key)>[
      if (sample)
        (l.ytdlWhereSampleNote, const ValueKey('ytdl-where-sample-note'))
      else if (trap == null && title.isNotEmpty)
        (l.ytdlWhereFileNote(title), const ValueKey('ytdl-where-file-note')),
      if (!sample && trap == null && t.missingVars.isNotEmpty)
        (
          l.discoverDestMissing(t.missingVars.map(destToken).join(', ')),
          const ValueKey('ytdl-where-missing'),
        ),
      if (t.neverVars.isNotEmpty)
        (
          l.ytdlWhereAlwaysEmpty(t.neverVars.map(destToken).join(', ')),
          const ValueKey('ytdl-where-never'),
        ),
    ];
    final String? trapWords = trap == null
        ? null
        : switch (trap.kind) {
            YtdlTrapKind.emptyFolder => l.ytdlTrapEmpty(trap.folder),
            YtdlTrapKind.missingYear => l.ytdlTrapNoYear(trap.folder),
            YtdlTrapKind.other => l.ytdlTrapOther(trap.folder),
          };
    final path = ytdlSpokenPath(l, crumbs,
        newAt: newAt, trapAt: trapAt, file: file);
    return _Preview(
      label: label,
      crumbs: crumbs,
      slots: slots,
      newAt: newAt,
      trapAt: trapAt,
      file: file,
      notes: notes,
      trap: trap,
      trapWords: trapWords,
      spoken: [
        '$label $path.',
        for (final n in notes) n.$1,
        ?trapWords,
      ].join(' '),
    );
  }

  /// The field a bracket warning's link opens: the year for a missing
  /// year, the album for a folder left with nothing in it, else the first
  /// empty tag.
  YtdlField _fieldFor(YtdlTrap trap) {
    final t = draft.tags;
    return switch (trap.kind) {
      YtdlTrapKind.missingYear => YtdlField.year,
      YtdlTrapKind.emptyFolder => YtdlField.album,
      YtdlTrapKind.other => t.artist.isEmpty
          ? YtdlField.artist
          : t.album.isEmpty
              ? YtdlField.album
              : YtdlField.year,
    };
  }

  // ── drawing ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // The keyboard up (Custom's field): the subtitle goes and the preview
    // keeps to the path, two lines, pinned over the form (WhereCustom).
    final typing = bottomInset > 0;
    final t = _target;
    final model = _model(l);
    final preview = _preview(l, model, compact: typing);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          key: const ValueKey('ytdl-where-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DestGrabHandle(),
            _header(l),
            if (typing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: preview,
              ),
            Flexible(
              child: LayoutBuilder(
                builder: (context, box) => _form(
                  l,
                  typing ? null : preview,
                  destReveal(context, box.maxHeight),
                ),
              ),
            ),
            _footer(l, t),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l.ytdlWhereTitle,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 24 / 18,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('ytdl-where-close'),
              tooltip: l.close,
              onPressed: _close,
              icon: Icon(Icons.close, color: VelvetColors.textPrimary),
            ),
          ],
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: VelvetColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            height: 13 / 11,
          ),
        ),
      );

  TextStyle get _note => TextStyle(
        color: VelvetColors.helper,
        fontSize: 12,
        height: 16 / 12,
      );

  /// The preview card: where the song lands, or why it can't say.
  Widget _preview(AppLocalizations l, _Preview m, {required bool compact}) {
    final blocked = m.blocked;
    if (blocked != null) {
      final warn = m.warn;
      final tone = keepTone(VelvetColors.warning);
      return Container(
        key: const ValueKey('ytdl-where-preview'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: warn
              ? VelvetColors.warning.withValues(alpha: 0.08)
              : VelvetColors.raised,
          border: warn
              ? Border.all(color: VelvetColors.warning.withValues(alpha: 0.45))
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            children: [
              Icon(
                warn ? Icons.warning_amber_rounded : Icons.folder_outlined,
                size: 18,
                color: warn ? tone : VelvetColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  blocked,
                  key: const ValueKey('ytdl-where-preview-blocked'),
                  style: TextStyle(
                    color: warn
                        ? VelvetColors.textPrimary
                        : VelvetColors.textSecondary,
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final trap = m.trap;
    return DestPreviewShell(
      key: const ValueKey('ytdl-where-preview'),
      compact: compact,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      icon: Icon(
        Icons.folder_outlined,
        size: 18,
        color: VelvetColors.textSecondary,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Read once, after the preview settles; drawn at once.
          Semantics(
            container: true,
            liveRegion: true,
            label: _spoken ?? m.spoken,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      m.label,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                  ),
                _PreviewPath(
                  key: const ValueKey('ytdl-where-path'),
                  crumbs: m.crumbs,
                  slots: m.slots,
                  newAt: m.newAt,
                  trapAt: m.trapAt,
                  file: m.file,
                  maxLines: compact ? 2 : null,
                ),
                if (!compact)
                  for (final (words, key) in m.notes)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(words, key: key, style: _note),
                    ),
              ],
            ),
          ),
          if (!compact && trap != null)
            _trapPanel(l, m.trapWords!, trap),
        ],
      ),
    );
  }

  /// The bracket warning (YearTrap): amber, with the link that fills the
  /// folder.
  Widget _trapPanel(AppLocalizations l, String words, YtdlTrap trap) {
    final ink = keepInk();
    final link = trap.kind == YtdlTrapKind.missingYear
        ? l.ytdlTrapAddYear
        : l.ytdlEditTags;
    final field = _fieldFor(trap);
    return Container(
      key: const ValueKey('ytdl-where-trap'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: VelvetColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: VelvetColors.warning.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: keepTone(VelvetColors.warning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Read with the preview above.
                ExcludeSemantics(
                  child: Text(
                    words,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: link,
                  onTap: () => _fillTag(field),
                  excludeSemantics: true,
                  child: KeepHitArea(
                    minHeight: 48,
                    onTap: () => _fillTag(field),
                    child: Text(
                      link,
                      key: const ValueKey('ytdl-where-trap-link'),
                      style: TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(AppLocalizations l, Widget? preview, EdgeInsets reveal) {
    final libraries = st.server.autoDJPaths.keys.toList();
    final discover = _discover;
    final template = _template;
    return SingleChildScrollView(
      key: const ValueKey('ytdl-where-form'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (preview != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                l.ytdlWhereSub(st.server.displayName),
                style: TextStyle(
                  color: VelvetColors.textSecondary,
                  fontSize: 13,
                  height: 18 / 13,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: preview,
            ),
          ],
          if (_mayNotMkdir)
            Padding(
              key: const ValueKey('ytdl-where-nomkdir'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: VelvetColors.helper,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.ytdlWhereNoMkdir, style: _note)),
                ],
              ),
            ),
          // One library: nothing to pick, no section (spec §4).
          if (libraries.length > 1) ...[
            _label(l.discoverDestLibrary),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _kind == 'discover' && discover != null
                  ? _lockedLibrary(l, discover.vpath)
                  : Wrap(
                      spacing: 8,
                      children: [
                        for (final lib in libraries)
                          DestLibraryChip(
                            key: ValueKey('ytdl-where-library-$lib'),
                            name: lib,
                            selected: lib == _library,
                            minHit: 48,
                            onTap: _saving ? null : () => _pickLibrary(lib),
                          ),
                      ],
                    ),
            ),
          ],
          _label(l.discoverDestLayout),
          _option(
            'artistAlbum',
            l.discoverDestPresetArtistAlbum,
            kYtdlLayoutArtistAlbum,
          ),
          _option('artist', l.torrentArtistLabel, kYtdlLayoutArtist),
          _option('top', l.ytdlLayoutTop, l.ytdlLayoutTopSub, mono: false),
          if (discover != null)
            _option(
              'discover',
              l.ytdlLayoutDiscover,
              foldBase(discover.base, discover.layout),
            ),
          if (template != null)
            _option('library', l.discoverDestPresetLibrary, template),
          DestLayoutOption(
            key: const ValueKey('ytdl-where-layout-custom'),
            label: l.discoverDestPresetCustom,
            sub: l.discoverDestCustomSub,
            mono: false,
            hint: l.discoverDestCustomSub,
            selected: _kind == 'custom',
            onTap: _saving ? null : _pickCustom,
          ),
          if (_kind == 'custom') _customEditor(l, reveal),
        ],
      ),
    );
  }

  Widget _option(String kind, String label, String sub, {bool mono = true}) =>
      DestLayoutOption(
        key: ValueKey('ytdl-where-layout-$kind'),
        label: label,
        sub: sub,
        mono: mono,
        selected: _kind == kind,
        onTap: _saving ? null : () => _pickLayout(kind),
      );

  /// "Same as Discover" fixes the library: Discover's, read only.
  Widget _lockedLibrary(AppLocalizations l, String vpath) => Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            label: l.ytdlA11yLocked,
            child: DestLibraryChip(
              key: const ValueKey('ytdl-where-library-locked'),
              name: vpath,
              selected: true,
              locked: true,
              minHit: 48,
            ),
          ),
          Text(l.ytdlWhereSetByDiscover, style: _note),
        ],
      );

  /// Custom's field under its row: the layout as typed, the YouTube check's
  /// words under it, the four variables to insert at the caret, and how a
  /// layout reads.
  Widget _customEditor(AppLocalizations l, EdgeInsets reveal) {
    final check = _customCheck;
    final vars = kYtdlVars.join(', ');
    final String? problem = check == null
        ? null
        : switch (check.issue) {
            YtdlLayoutIssue.none => null,
            YtdlLayoutIssue.unknownVariable =>
              l.discoverDestErrUnknownVar(check.token ?? '', vars),
            YtdlLayoutIssue.neverVariable =>
              l.ytdlErrNeverVar(check.token ?? '', vars),
            YtdlLayoutIssue.badChars => l.ytdlErrBadChars,
            YtdlLayoutIssue.engine =>
              destLayoutProblem(l, check.engine!, kYtdlVars),
          };
    final bad = problem != null;
    final focused = _customFocus.hasFocus;
    final room = kMaxLayoutLength - _custom.text.length;
    return Padding(
      key: const ValueKey('ytdl-where-custom-editor'),
      // Under the row's name: past the radio and its gap.
      padding: const EdgeInsets.only(left: 34, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.symmetric(
                horizontal: bad ? 11 : (focused ? 11.5 : 12),
              ),
              decoration: BoxDecoration(
                color: VelvetColors.raised,
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                border: Border.all(
                  color: bad
                      ? keepTone(VelvetColors.warning)
                      : focused
                          ? VelvetColors.primary
                          : VelvetColors.border2,
                  width: bad ? 2 : (focused ? 1.5 : 1),
                ),
              ),
              child: Semantics(
                label: l.discoverDestCustomField,
                child: TextField(
                  key: const ValueKey('ytdl-where-custom'),
                  controller: _custom,
                  focusNode: _customFocus,
                  enabled: !_saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(kMaxLayoutLength),
                  ],
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  cursorColor: VelvetColors.primary,
                  // Room for the variables under it when the keyboard is up.
                  scrollPadding: reveal,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: kYtdlLayoutArtistAlbum,
                    hintStyle: TextStyle(
                      color: VelvetColors.helper,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          if (problem != null)
            destErrorLine(
              problem,
              const ValueKey('ytdl-where-custom-error'),
              warning: true,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Semantics(
              label: l.ytdlA11yInsertVariable,
              container: true,
              explicitChildNodes: true,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final v in kYtdlVars) _varChip(l, v, room),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(l.ytdlCustomHelp, style: _note),
          ),
        ],
      ),
    );
  }

  Widget _varChip(AppLocalizations l, String name, int room) {
    final words = switch (name) {
      'ARTIST' => l.discoverDestInsertArtist,
      'ALBUMARTIST' => l.discoverDestInsertAlbumArtist,
      'ALBUM' => l.discoverDestInsertAlbum,
      _ => l.discoverDestInsertYear,
    };
    final used = RegExp('\\{\\{\\s*$name\\s*\\}\\}', caseSensitive: false)
        .hasMatch(_custom.text);
    final token = destToken(name);
    return DestVarChip(
      key: ValueKey('ytdl-where-var-$name'),
      token: name,
      label: used ? l.ytdlA11yVarUsed(words) : words,
      used: used,
      minHit: 48,
      // Off while saving, or with no room left for it.
      onTap: _saving || token.length > room
          ? null
          : () => destInsertVar(_custom, _customFocus, token),
    );
  }

  Widget _footer(AppLocalizations l, YtdlTarget t) {
    final canUse = _canUse(t);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: VelvetColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Semantics(
            container: true,
            button: true,
            enabled: canUse,
            onTap: canUse ? _useForThisSong : null,
            excludeSemantics: true,
            label: l.ytdlWhereUseForSong,
            child: KeepHitArea(
              minHeight: 48,
              onTap: canUse ? _useForThisSong : null,
              child: Padding(
                key: const ValueKey('ytdl-where-use'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l.ytdlWhereUseForSong,
                  style: TextStyle(
                    color: canUse ? keepInk() : VelvetColors.helper,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          DestSaveButton(
            label: l.save,
            busy: _saving,
            enabled: _canSave(t),
            onTap: () => unawaited(_save()),
            valueKey: const ValueKey('ytdl-where-save'),
            minHit: 48,
          ),
        ],
      ),
    );
  }
}

/// The preview card's words for one state of the form.
class _Preview {
  final String label;
  final List<String> crumbs;
  final Set<int> slots;
  final Set<int> newAt;
  final Set<int> trapAt;
  final String file;
  final List<(String, Key)> notes;
  final YtdlTrap? trap;
  final String? trapWords;
  final String spoken;

  /// Why the preview can't say where the song lands (Custom empty, a
  /// layout refused); [warn] draws it amber.
  final String? blocked;
  final bool warn;

  const _Preview({
    required this.label,
    required this.crumbs,
    required this.slots,
    required this.newAt,
    required this.trapAt,
    required this.file,
    required this.notes,
    required this.trap,
    required this.trapWords,
    required this.spoken,
  })  : blocked = null,
        warn = false;

  const _Preview.blocked(String words, {this.warn = true})
      : blocked = words,
        spoken = words,
        label = '',
        crumbs = const [],
        slots = const {},
        newAt = const {},
        trapAt = const {},
        file = '',
        notes = const [],
        trap = null,
        trapWords = null;
}

/// The preview's path (the boards' crumbs): it breaks only at the ›
/// separators, a folder a variable fills reads as a slot (italic), a folder
/// that will be made carries a "new" tag, a folder an empty tag left as
/// brackets is drawn in the warning tone, and the file name ends it — its
/// stem italic, cut in the middle when it would not fit a line. Read aloud
/// by the card around it.
class _PreviewPath extends StatelessWidget {
  final List<String> crumbs;
  final Set<int> slots;
  final Set<int> newAt;
  final Set<int> trapAt;
  final String file;
  final int? maxLines;

  const _PreviewPath({
    super.key,
    required this.crumbs,
    required this.slots,
    required this.newAt,
    required this.trapAt,
    required this.file,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: VelvetColors.textPrimary,
      fontSize: 14,
      height: 20 / 14,
    );
    final sep = base.copyWith(color: VelvetColors.helper);
    final quiet = base.copyWith(color: VelvetColors.textSecondary);
    return LayoutBuilder(builder: (context, box) {
      // Measured as drawn, in the face the line is drawn in.
      final face = DefaultTextStyle.of(context).style.merge(quiet);
      final shown = _fit(
        file,
        (s) => _fileSpan(s, face),
        box.maxWidth,
        Directionality.of(context),
        MediaQuery.textScalerOf(context),
      );
      final spans = <InlineSpan>[];
      for (var i = 0; i < crumbs.length; i++) {
        if (i > 0) spans.add(TextSpan(text: kYtdlCrumbSep, style: sep));
        final style = trapAt.contains(i)
            ? base.copyWith(
                color: keepTone(VelvetColors.warning),
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              )
            : slots.contains(i)
                ? base.copyWith(fontStyle: FontStyle.italic)
                : base;
        final text = ytdlIsolate(destHold(crumbs[i]));
        if (newAt.contains(i)) {
          // The folder and its tag as one piece: a line never breaks
          // between them.
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: Text(text, style: style)),
                const SizedBox(width: 5),
                const _NewTag(),
              ],
            ),
          ));
        } else {
          spans.add(TextSpan(text: text, style: style));
        }
      }
      spans.add(TextSpan(text: kYtdlCrumbSep, style: sep));
      spans.add(_fileSpan(shown, quiet));
      return Text.rich(
        TextSpan(children: spans),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    });
  }

  /// The file name: its stem italic, one unbreakable run (a cut name never
  /// breaks at its ellipsis either), the extension upright.
  static InlineSpan _fileSpan(String name, TextStyle style) {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: destHold(stem).replaceAll('…', '…\u2060'),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
        if (dot > 0) TextSpan(text: name.substring(dot)),
      ],
    );
  }

  /// [name] whole when it fits one line of [width], else cut in the middle
  /// (the extension kept) to the longest that does.
  static String _fit(
    String name,
    InlineSpan Function(String) draw,
    double width,
    TextDirection direction,
    TextScaler scaler,
  ) {
    bool fits(String s) {
      final tp = TextPainter(
        text: draw(s),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      // A pixel's slack for the line's own rounding.
      final ok = tp.width <= width - 1;
      tp.dispose();
      return ok;
    }

    if (!width.isFinite || fits(name)) return name;
    var lo = 8, hi = name.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (fits(ytdlMiddleEllipsis(name, mid))) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return ytdlMiddleEllipsis(name, lo);
  }
}

/// The boards' "new" tag: outlined in the primary's ink, round ends.
class _NewTag extends StatelessWidget {
  const _NewTag();

  @override
  Widget build(BuildContext context) {
    final ink = keepInk();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: ink),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        AppLocalizations.of(context).ytdlNewTag,
        style: TextStyle(
          color: ink,
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.normal,
        ),
      ),
    );
  }
}
