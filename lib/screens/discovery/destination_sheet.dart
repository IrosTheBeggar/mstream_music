import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart';
import 'discovery_jobs_controller.dart';
import 'keep_copy_ui.dart';
import 'keep_toast.dart';

/// "Change" on the Keep card: where copies land (the design canvas's
/// PhoneDestination board). One setting for the account, shared by every
/// copy (`PUT /discovery/collection/destination`): a library the account may
/// add files to, and a layout — Artist / Album, Server / Artist / Album, Same
/// folders as the server, the chosen library's own Path Template when it has
/// one, or Custom: one typed by hand (plain folders, the variables, or both),
/// held to the server's own validator (ported) as it is typed. The preview
/// renders where the sheet's song would land as the user types (the server's
/// own layout engine, ported) — or says the server would refuse that song's
/// path for its length, which a layout the server takes can still make.
/// "Use the library default" saves none.
///
/// No base folder here: a Custom layout's own folders do its work. The
/// webapp and the terminal keep one on the same setting; the sheet holds it
/// as the start of the layout ([foldBase]: "From peers" and Artist / Album
/// open as Custom's "From peers/{{ALBUMARTIST}}/{{ALBUM}}", the files in the
/// same place), and saves no base folder (base ''). A folder whose name a
/// layout reads as a variable ("{{PEER}}", [bracedFolder]) is named under
/// the field, and Save waits until it is renamed or a preset is chosen.
///
/// States: loading (still blocks; Save off), the default in force (tag
/// "library default"), a saved one ("yours"), saving (inputs locked), a
/// refusal (the server's words under the field), no library that takes
/// files, uploads off, and a read that failed (Try again).

/// The song a preview renders.
class DestinationPreviewSong {
  final String title;

  /// The file's ARTIST tag as written ("A feat. B") when this phone can
  /// tell it, else the row's artist.
  final String artist;
  final String? album;
  final String? albumArtist;
  final int? year;

  /// The genre the file carries, when this phone can tell it (the album's
  /// listing on the connected server); null draws the genre's slot.
  final String? genre;

  /// The file's path on the connected server (its name is kept; its folders
  /// there are {{SERVERFOLDER}}).
  final String? filepath;
  const DestinationPreviewSong({
    required this.title,
    required this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.genre,
    this.filepath,
  });

  /// [artist] and [genre]: the file's own, when this phone can tell them.
  factory DestinationPreviewSong.ofLead(
    DiscoveryLead lead, {
    String? artist,
    String? genre,
  }) => DestinationPreviewSong(
    title: lead.title,
    artist: artist ?? lead.artist,
    album: lead.album,
    albumArtist: lead.albumArtist,
    year: lead.year,
    genre: genre,
    filepath: lead.filepath,
  );
}

/// A connected server's folder copied "By your layout" (Keep a copy's folder
/// landing), previewed in a song's place: where its songs land by their own
/// tags ([folderTarget]'s tags rule) — the folder's path there ([folder], no
/// leading slash), its [name], the songs the copy takes and their tags once
/// read (null until then: the path shows slots).
class DestinationPreviewFolder {
  final String folder;
  final String name;
  final List<FolderSong>? songs;
  final List<FolderSongTags>? tags;
  const DestinationPreviewFolder({
    required this.folder,
    required this.name,
    this.songs,
    this.tags,
  });
}

/// The "Artist / Album" preset when the server names no default layout:
/// by the album's credit (the server's own default), so a compilation copied
/// whole stays in one folder; ALBUMARTIST falls back to the song's artist.
/// The picker takes the server's [DestinationView.defaultLayout] first.
const String kLayoutArtistAlbum = kDefaultCopyLayout;

/// The "Server / Artist / Album" preset, by the album's credit too.
const String kLayoutServerArtistAlbum = '{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}';

/// The "Same folders as the server" preset: each song in the folders it sits
/// in on the connected server, that server's library left out.
const String kLayoutServerFolders = '{{SERVERFOLDER}}';

Future<void> showDestinationSheet(
  BuildContext context,
  DiscoveryJobsController jobs, {
  DestinationPreviewSong? song,
  DestinationPreviewFolder? folder,
  String peerName = '',
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: VelvetColors.surface,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.89,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => DestinationSheet(
    jobs: jobs,
    song: song,
    folder: folder,
    peerName: peerName,
  ),
);

class DestinationSheet extends StatefulWidget {
  final DiscoveryJobsController jobs;
  final DestinationPreviewSong? song;

  /// Opened from a folder's "By your layout": the preview renders the folder
  /// by the folder rule instead of one song ([song] is then unused).
  final DestinationPreviewFolder? folder;
  final String peerName;
  const DestinationSheet({
    super.key,
    required this.jobs,
    this.song,
    this.folder,
    this.peerName = '',
  });

  @override
  State<DestinationSheet> createState() => _DestinationSheetState();
}

/// Which input a refusal names.
enum _Field { layout, other }

class _DestinationSheetState extends State<DestinationSheet> {
  String? _vpath;
  String? _layout;
  CollectionDestination? _from;

  /// Custom is chosen: its field's text is the layout. What was typed stays
  /// in the field while a preset is chosen.
  bool _customChosen = false;
  final TextEditingController _custom = TextEditingController();
  final FocusNode _customFocus = FocusNode();

  /// What Custom's field held when a library's own layout moved into it
  /// (leaving that library): back in that library with the layout
  /// untouched, the field holds it again.
  String? _customBefore;

  /// The server's words for the last refused save, and the input they name.
  String? _saveError;
  _Field? _saveErrorField;

  DiscoveryJobsController get jobs => widget.jobs;

  @override
  void initState() {
    super.initState();
    _sync(force: true);
    jobs.addListener(_onJobs);
    _custom.addListener(_onCustomTyping);
    // What the server holds now (it may have changed on another device).
    if (!jobs.savingDestination) unawaited(jobs.loadDestination());
  }

  @override
  void dispose() {
    jobs.removeListener(_onJobs);
    _custom.removeListener(_onCustomTyping);
    _custom.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _onJobs() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  /// Custom's text as last seen (a focus or selection change notifies too).
  String _customTyped = '';

  void _onCustomTyping() {
    if (!mounted || _custom.text == _customTyped) return;
    _customTyped = _custom.text;
    setState(() => _dropError(_Field.layout));
  }

  /// Puts [layout] in Custom's field as the form's own (not an edit: a
  /// refusal under it stays).
  void _setCustom(String layout) {
    _customTyped = layout;
    if (_custom.text != layout) _custom.text = layout;
  }

  void _dropError(_Field field) {
    if (_saveErrorField != field) return;
    _saveError = null;
    _saveErrorField = null;
  }

  /// The form takes the server's destination: the first time it is known,
  /// and again whenever it changes while nothing was edited (or [force]).
  void _sync({bool force = false}) {
    final view = jobs.destination;
    final d = view?.destination;
    if (view == null || d == null || identical(d, _from)) return;
    // An edit in progress is kept; Save or Close settles it.
    if (!force && _from != null && _dirty) return;
    _from = d;
    _vpath = d.vpath;
    // A base folder set elsewhere comes in front of the layout.
    final layout = foldBase(d.base, d.layout);
    _layout = layout;
    // A layout that is none of the presets opens in Custom's field, and so
    // does one with a base folder in front: never a preset, even when the
    // whole of it reads as one.
    _customChosen = layout != d.layout || !_isPreset(view, d.vpath, layout);
    if (_customChosen) _setCustom(layout);
  }

  /// The layout the form holds: Custom's text while Custom is chosen, else
  /// the chosen preset. It is saved with no base folder.
  String? get _chosenLayout => _customChosen ? _custom.text : _layout;

  /// A base folder set elsewhere, folded into the layout as it opened, is
  /// no edit; a preset of the same text over one whose name a layout reads
  /// as a variable is (the server's name, not that folder).
  bool get _dirty {
    final d = _from;
    if (d == null) return false;
    return _vpath != d.vpath ||
        _chosenLayout != foldBase(d.base, d.layout) ||
        (!_customChosen && bracedFolder(d.base) != null);
  }

  /// Custom's field holds the layout as the sheet opened it.
  bool get _asOpened {
    final d = _from;
    return d != null &&
        _customChosen &&
        _custom.text == foldBase(d.base, d.layout);
  }

  /// The folder of a base folder set elsewhere that Custom's field still
  /// holds as it opened, when its name has a brace ([bracedFolder]): a
  /// layout reads it as a variable or refuses it, so saved as it is, the
  /// files would land elsewhere.
  String? get _heldBraces => _asOpened ? bracedFolder(_from!.base) : null;

  /// Custom's text is empty or would be refused, or still holds a base
  /// folder a layout cannot: Save waits for it.
  bool get _customBlocks =>
      _customChosen &&
      (!validateLayout(_custom.text).valid || _heldBraces != null);

  /// The layout presets for [vpath]'s library, in order: Artist / Album
  /// (the server's own default, by the album's credit since the
  /// compilations change, so a fresh account's layout is this one), Server
  /// / Artist / Album, Same folders as the server (when the server offers
  /// {{SERVERFOLDER}}: one from before it would refuse the layout), then the
  /// library's own Path Template when it has one that is none of them. Any
  /// other layout is Custom's.
  static List<(String Function(AppLocalizations), String)> _presets(
    DestinationView view,
    String vpath,
  ) {
    final artistAlbum = view.defaultLayout.trim().isNotEmpty
        ? view.defaultLayout
        : kLayoutArtistAlbum;
    final template = view.libraries
        .firstWhere(
          (w) => w.vpath == vpath,
          orElse: () => WritableLibrary(vpath),
        )
        .template;
    return [
      ((l) => l.discoverDestPresetArtistAlbum, artistAlbum),
      if (artistAlbum != kLayoutServerArtistAlbum)
        ((l) => l.discoverDestPresetServer, kLayoutServerArtistAlbum),
      if (artistAlbum != kLayoutServerFolders &&
          _variables(view).contains('SERVERFOLDER'))
        ((l) => l.discoverDestPresetServerFolders, kLayoutServerFolders),
      if (template != null &&
          template.trim().isNotEmpty &&
          template != artistAlbum &&
          template != kLayoutServerArtistAlbum &&
          template != kLayoutServerFolders)
        ((l) => l.discoverDestPresetLibrary, template),
    ];
  }

  static bool _isPreset(DestinationView view, String vpath, String? layout) =>
      _presets(view, vpath).any((p) => p.$2 == layout);

  /// The variables Custom offers: the server's, as far as the phone's
  /// layout engine knows them (all of them when the server names none).
  static List<String> _variables(DestinationView view) {
    final known = [
      for (final v in view.variables)
        if (kLayoutVars.contains(v)) v,
    ];
    return known.isEmpty ? kLayoutVars : known;
  }

  static String _token(String name) => '{{$name}}';

  /// Custom chosen: its field opens with the keyboard up, and scrolls into
  /// view with the variables under it (its scrollPadding).
  void _pickCustom() {
    if (_customChosen) {
      _customFocus.requestFocus();
      return;
    }
    setState(() {
      _customChosen = true;
      _dropError(_Field.layout);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _customChosen) _customFocus.requestFocus();
    });
  }

  /// A variable button: {{NAME}} where the caret is (over the selection,
  /// at the end when the field never had one), the caret after it. A button
  /// with no room left for its token is off (the field's own limit sees
  /// only the keyboard).
  void _insertVar(String name) {
    final token = _token(name);
    final v = _custom.value;
    final s = v.selection;
    final start = s.isValid ? s.start : v.text.length;
    final end = s.isValid ? s.end : v.text.length;
    _custom.value = TextEditingValue(
      text: v.text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _customFocus.requestFocus();
  }

  /// The validator's refusal in words (the server's codes, one table); an
  /// unknown variable named as it was typed.
  String _layoutProblem(
    AppLocalizations l,
    LayoutCheck check,
    List<String> vars,
  ) => switch (check.error) {
    'unknown_variable' => l.discoverDestErrUnknownVar(
      check.token ?? _token(check.variable ?? ''),
      vars.join(', '),
    ),
    'unbalanced_braces' => l.discoverDestErrBraces(_token('ARTIST')),
    'absolute_template' || 'absolute_path' => l.discoverDestErrAbsolute,
    'traversal' => l.discoverDestErrTraversal,
    'empty_path' => l.discoverDestErrEmpty,
    'home_string' => l.discoverDestErrHome,
    'drive_letter' || 'drive_letter_segment' => l.discoverDestErrDrive,
    'template_too_long' => l.discoverDestErrTooLong(kMaxLayoutLength),
    'invalid_chars' => l.discoverDestErrControl,
    _ => l.discoverDestErrGeneric,
  };

  /// A variable button's name for a screen reader ("Insert artist"), with
  /// the name it shows when the words do not already say it: Voice Control
  /// finds a button by what it shows.
  String _insertLabel(AppLocalizations l, String name) {
    final words = switch (name) {
      'ARTIST' => l.discoverDestInsertArtist,
      'ALBUM' => l.discoverDestInsertAlbum,
      'YEAR' => l.discoverDestInsertYear,
      'GENRE' => l.discoverDestInsertGenre,
      'ALBUMARTIST' => l.discoverDestInsertAlbumArtist,
      'PEER' => l.discoverDestInsertPeer,
      'SERVERFOLDER' => l.discoverDestInsertServerFolder,
      _ => _token(name),
    };
    return words.toLowerCase().contains(name.toLowerCase())
        ? words
        : '$words, $name';
  }

  /// The account's own destination is in force (not the library default).
  static bool _mine(DestinationView view) {
    final d = view.destination;
    if (d == null) return false;
    return d.source == 'user' || (d.source == null && view.saved != null);
  }

  _Field _fieldOf(String words) {
    final w = words.toLowerCase();
    if (w.contains('layout') || w.contains('template')) return _Field.layout;
    return _Field.other;
  }

  /// Where every copy lands whatever its tags: the library and the
  /// layout's own leading folders that name no variable — so a base folder
  /// folded into the layout reads as it did ("copies › From peers"). [d] is
  /// the server's answer to a save, and the phone saves no base folder.
  String _landing(CollectionDestination d) => [
    d.vpath,
    ...d.layout
        .split(RegExp(r'[/\\]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .takeWhile((s) => !s.contains('{')),
  ].join(' › ');

  Future<void> _save(CollectionDestination? value) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _saveError = null;
      _saveErrorField = null;
    });
    final ok = await jobs.saveDestination(value);
    if (!mounted) return;
    if (ok) {
      _sync(force: true);
      unawaited(SettingsManager().markDiscoverKeepNoteSeen());
      final d = jobs.destination?.destination;
      if (d != null) {
        KeepToast.show(
          context,
          l.discoverToastSaved(_landing(d)),
          success: true,
        );
      }
      setState(() {});
      return;
    }
    final words = jobs.destinationError;
    if (jobs.destinationErrorFromServer && words != null) {
      setState(() {
        _saveError = words;
        _saveErrorField = _fieldOf(words);
      });
    } else {
      KeepToast.show(context, l.discoverKeepStartFailed);
    }
  }

  // ── drawing ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // The keyboard up: the header keeps to its title and the preview to the
    // path (two lines at most), so the field being typed in keeps its room.
    final typing = bottomInset > 0;
    final view = jobs.destination;
    final d = view?.destination;
    final Widget body;
    Widget? preview;
    Widget? footer;
    String? tag;
    var tagMine = false;
    if (view == null && jobs.destinationFailed) {
      final words = jobs.destinationError;
      body = _BlockCard(
        key: const ValueKey('destination-failed'),
        icon: Icons.warning_amber_rounded,
        iconColor: keepTone(VelvetColors.warning),
        title: l.discoverDestLoadFailed,
        sub: jobs.destinationErrorFromServer ? words : null,
        pill: KeepPill(
          l.discoverPageRetry,
          key: const ValueKey('destination-try-again'),
          icon: Icons.refresh,
          primary: true,
          onTap: () => unawaited(jobs.loadDestination()),
        ),
      );
    } else if (view == null) {
      preview = const _PreviewSkeleton();
      body = _FormSkeleton(label: l.discoverDestLoading);
      footer = _footer(l, null, loading: true);
    } else if (d == null) {
      final uploadsOff = jobs.server.noUpload == true;
      body = _BlockCard(
        key: ValueKey(
          uploadsOff ? 'destination-uploads-off' : 'destination-no-library',
        ),
        icon: uploadsOff ? Icons.block : Icons.folder_off_outlined,
        iconColor: VelvetColors.textSecondary,
        title: uploadsOff ? l.discoverKeepUploadsOff : l.discoverKeepNoLibrary,
        pill: KeepPill(
          l.close,
          key: const ValueKey('destination-close-blocked'),
          onTap: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      tagMine = _mine(view);
      tag = tagMine ? l.discoverDestTagYours : l.discoverDestTagDefault;
      preview = _preview(l, compact: typing);
      body = _form(l, view);
      footer = _footer(l, view);
    }

    return Padding(
      // The sheet lifts above the keyboard; the header, the preview and the
      // footer stay, the form scrolls the field into view.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          key: const ValueKey('destination-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _GrabHandle(),
            _header(l, tag, tagMine, compact: typing),
            Divider(height: 1, thickness: 1, color: VelvetColors.border),
            ?preview,
            Flexible(child: body),
            ?footer,
          ],
        ),
      ),
    );
  }

  Widget _header(
    AppLocalizations l,
    String? tag,
    bool mine, {
    bool compact = false,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(16, compact ? 0 : 4, 4, compact ? 2 : 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l.discoverDestTitle,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 22 / 16,
                      ),
                    ),
                  ),
                  if (tag != null)
                    Container(
                      key: ValueKey(
                        mine
                            ? 'destination-tag-yours'
                            : 'destination-tag-default',
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: VelvetColors.border2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mine) ...[
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: VelvetColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 12,
                                height: 16 / 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (!compact)
                Text(
                  l.discoverDestSub,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 13,
                    height: 18 / 13,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('destination-close'),
          tooltip: l.close,
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, color: VelvetColors.textSecondary),
        ),
      ],
    ),
  );

  /// Where the sheet's song would land, or why the preview waits. While
  /// the keyboard is up ([compact]) it keeps to the path, two lines at most.
  Widget? _preview(AppLocalizations l, {bool compact = false}) {
    final song = widget.song;
    final folder = widget.folder;
    if (song == null && folder == null) return null;
    // The song's own values ([scopeTarget]'s song scope), its own folders on
    // the connected server among them: a genre the phone cannot tell stands
    // as a slot where the server puts the file's, so the path is never
    // shallower than the one written. No base folder: one set elsewhere is
    // the start of the layout — and the layout as it opened is drawn as the
    // server holds it, so that folder reads as the Keep card reads it,
    // whatever a layout would make of its name. A folder copy by the layout
    // ([folder]) files each of its songs by its own tags: the folder rule.
    final opened = _asOpened ? _from : null;
    final st = folder != null
        ? scopeTarget(
            vpath: _vpath,
            base: opened?.base,
            layout: opened?.layout ?? _chosenLayout,
            scope: kScopeFolder,
            landing: const {'tags': true},
            folder: folder.folder,
            folderSongs: folder.songs,
            folderTags: folder.tags,
            peerName: widget.peerName,
          )
        : scopeTarget(
            vpath: _vpath,
            base: opened?.base,
            layout: opened?.layout ?? _chosenLayout,
            tags: {
              'artist': song!.artist,
              'album': song.album,
              'year': song.year,
              'genre': song.genre,
              'albumartist': song.albumArtist,
            },
            serverFolder: serverFolderOf(song.filepath),
            peerName: widget.peerName,
            fileName: song.filepath ?? song.title,
          );
    final t = st.target;
    final quiet = TextStyle(
      color: VelvetColors.textSecondary,
      fontSize: 13,
      height: 18 / 13,
    );
    final lines = compact ? 2 : null;
    final cut = compact ? TextOverflow.ellipsis : null;
    final Widget content;
    final Widget icon;
    if (_customChosen && _custom.text.isEmpty) {
      icon = Icon(
        Icons.folder_outlined,
        size: 16,
        color: VelvetColors.textSecondary,
      );
      content = Text(
        l.discoverDestCustomEmpty,
        key: const ValueKey('destination-preview-empty'),
        maxLines: lines,
        overflow: cut,
        style: quiet,
      );
    } else if (!t.valid) {
      icon = Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: keepTone(VelvetColors.warning),
      );
      // A path too long for this song is no fault of the layout's (its
      // field shows none, Save takes it): the preview says what is wrong.
      content = Text(
        t.tooLong
            ? l.discoverDestPathTooLong(kMaxPathLength)
            : l.discoverDestFixLayout,
        key: ValueKey(
          t.tooLong
              ? 'destination-preview-too-long'
              : 'destination-preview-invalid',
        ),
        maxLines: lines,
        overflow: cut,
        style: quiet,
      );
    } else {
      icon = Icon(
        Icons.folder_outlined,
        size: 16,
        color: VelvetColors.textSecondary,
      );
      // A folder's songs land in its folders, no one file named; past the
      // first folder that names an album, one folder per album.
      final crumbs = folder != null ? st.crumbs : [...st.crumbs, t.file];
      // One song lands in one folder: the note in a song's words.
      final slots = keepSlotNote(
        l,
        st.slots,
        scope: folder != null ? kScopeFolder : kScopeSong,
      );
      final soft = TextStyle(color: VelvetColors.textSecondary);
      final note = TextStyle(
        color: VelvetColors.textSecondary,
        fontSize: 12,
        height: 16 / 12,
      );
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Text(
              l.discoverDestLandsAt(folder?.name ?? song!.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          Text.rich(
            key: const ValueKey('destination-preview'),
            maxLines: lines,
            overflow: cut,
            TextSpan(
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 13,
                height: 18 / 13,
              ),
              children: [
                // A segment never breaks inside itself: the line breaks
                // only between the › separators.
                for (var i = 0; i < crumbs.length; i++) ...[
                  if (i > 0) TextSpan(text: ' › ', style: soft),
                  ...keepCrumbSpans(l, crumbs[i], hold: _hold),
                ],
                if (st.perAlbum) ...[
                  TextSpan(text: ' › ', style: soft),
                  TextSpan(
                    text: _hold(l.discoverKeepFolderPerAlbum),
                    style: soft,
                  ),
                ],
              ],
            ),
          ),
          if (!compact && slots != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                slots,
                key: const ValueKey('destination-preview-slots'),
                style: note,
              ),
            ),
          if (!compact && t.missingVars.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.discoverDestMissing(t.missingVars.map(_token).join(', ')),
                key: const ValueKey('destination-preview-missing'),
                style: note,
              ),
            ),
        ],
      );
    }
    return Container(
      margin: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: icon),
            const SizedBox(width: 10),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: VelvetColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        height: 14 / 11,
      ),
    ),
  );

  /// A refusal under its input: the server's words in the error tone,
  /// announced; or the validator's as typed in the [warning] tone, read in
  /// its place after the field (announced, it would talk over the typing).
  Widget _errorLine(String words, Key key, {bool warning = false}) => Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: Semantics(
      liveRegion: !warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              warning ? Icons.warning_amber_rounded : Icons.error_outline,
              size: 14,
              color: keepTone(
                warning ? VelvetColors.warning : VelvetColors.error,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              words,
              style: TextStyle(
                color: keepTone(
                  warning ? VelvetColors.warning : VelvetColors.error,
                ),
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// The form, knowing its own height: a field being typed in asks the
  /// form to show no more around its line than fits ([_reveal]).
  Widget _form(AppLocalizations l, DestinationView view) => LayoutBuilder(
    builder: (context, box) =>
        _formIn(l, view, _reveal(context, box.maxHeight)),
  );

  /// What a field being typed in brings into view around its line: its
  /// box's top edge, and under it up to 120 px (the variables under
  /// Custom's) — less when the form is short (the keyboard up, large text),
  /// so the field itself is never cut.
  static EdgeInsets _reveal(BuildContext context, double height) {
    const top = 16.0;
    final line = MediaQuery.textScalerOf(context).scale(24);
    return EdgeInsets.only(
      top: top,
      bottom: (height - top - line).clamp(0.0, 120.0),
    );
  }

  Widget _formIn(AppLocalizations l, DestinationView view, EdgeInsets reveal) {
    final saving = jobs.savingDestination;
    final vpath = _vpath ?? view.destination!.vpath;
    final libs = [
      ...view.libraries,
      if (!view.libraries.any((w) => w.vpath == vpath)) WritableLibrary(vpath),
    ];
    final layout = _layout ?? view.destination!.layout;
    final presets = _presets(view, vpath);
    return SingleChildScrollView(
      key: const ValueKey('destination-form'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label(l.discoverDestLibrary),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final lib in libs)
                  KeepLibraryChip(
                    key: ValueKey('destination-library-${lib.vpath}'),
                    name: lib.vpath,
                    selected: lib.vpath == vpath,
                    onTap: saving
                        ? null
                        : () => setState(() {
                            _vpath = lib.vpath;
                            if (!_customChosen &&
                                !_isPreset(view, lib.vpath, layout)) {
                              // A library's own layout that leaves with it
                              // stays the layout, in Custom's field.
                              _customBefore = _custom.text;
                              _customChosen = true;
                              _setCustom(layout);
                            } else if (_customChosen &&
                                _custom.text == layout &&
                                _heldBraces == null &&
                                _isPreset(view, lib.vpath, layout)) {
                              // Back with it untouched: its preset again,
                              // and Custom's field as it was (never over a
                              // base folder a layout reads as a variable).
                              _customChosen = false;
                              _setCustom(_customBefore ?? _custom.text);
                              _customBefore = null;
                            }
                            _saveError = null;
                            _saveErrorField = null;
                          }),
                  ),
              ],
            ),
          ),
          _label(l.discoverDestLayout),
          for (final p in presets)
            _LayoutOption(
              key: ValueKey('destination-layout-${p.$2}'),
              label: p.$1(l),
              sub: p.$2,
              selected: !_customChosen && p.$2 == layout,
              onTap: saving
                  ? null
                  : () => setState(() {
                      _layout = p.$2;
                      _customChosen = false;
                      _dropError(_Field.layout);
                    }),
            ),
          _LayoutOption(
            key: const ValueKey('destination-custom-option'),
            label: l.discoverDestPresetCustom,
            sub: l.discoverDestCustomSub,
            mono: false,
            hint: l.discoverDestCustomSub,
            selected: _customChosen,
            onTap: saving ? null : _pickCustom,
          ),
          // Custom's editor puts a refusal right under its field.
          if (_customChosen)
            _customEditor(l, view, saving, reveal)
          else if (_saveErrorField == _Field.layout && _saveError != null)
            _errorLine(_saveError!, const ValueKey('destination-layout-error')),
          if (_saveErrorField == _Field.other && _saveError != null)
            _errorLine(_saveError!, const ValueKey('destination-save-error')),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Custom's field, under its row: the layout as typed (under it the
  /// server's refusal, else the validator's words as typed), the variables
  /// to insert at the caret, and how a layout reads.
  Widget _customEditor(
    AppLocalizations l,
    DestinationView view,
    bool saving,
    EdgeInsets reveal,
  ) {
    final vars = _variables(view);
    final check = validateLayout(_custom.text);
    final held = _heldBraces;
    final problem = _custom.text.isEmpty
        ? null
        : !check.valid
        ? _layoutProblem(l, check, vars)
        : held == null
        ? null
        : l.discoverDestErrBaseBraces(held);
    final refusal = _saveErrorField == _Field.layout ? _saveError : null;
    final refused = refusal != null;
    final bad = problem != null || refused;
    final room = kMaxLayoutLength - _custom.text.length;
    return Padding(
      key: const ValueKey('destination-custom-editor'),
      // Under the row's name: past the radio and its gap.
      padding: const EdgeInsets.only(left: 34, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.symmetric(horizontal: bad ? 11 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                border: Border.all(
                  color: !bad
                      ? VelvetColors.border2
                      : keepTone(
                          refused ? VelvetColors.error : VelvetColors.warning,
                        ),
                  width: bad ? 2 : 1,
                ),
              ),
              child: Semantics(
                label: l.discoverDestCustomField,
                child: TextField(
                  key: const ValueKey('destination-custom'),
                  controller: _custom,
                  focusNode: _customFocus,
                  enabled: !saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  textInputAction: TextInputAction.done,
                  // The server's own cap on a layout.
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(kMaxLayoutLength),
                  ],
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 14,
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
                    hintText: l.discoverDestCustomHint(
                      '${_token('ARTIST')}/${_token('ALBUM')}',
                    ),
                    hintStyle: TextStyle(
                      color: VelvetColors.textTertiary,
                      fontSize: 14,
                    ),
                    // The example with variables comes last: never cut.
                    hintMaxLines: 2,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          if (refused)
            _errorLine(refusal, const ValueKey('destination-layout-error'))
          else if (problem != null)
            _errorLine(
              problem,
              const ValueKey('destination-custom-invalid'),
              warning: true,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final v in vars)
                  _VarChip(
                    key: ValueKey('destination-var-$v'),
                    token: _token(v),
                    label: _insertLabel(l, v),
                    // Off while saving, or with no room left for it.
                    onTap: saving || _token(v).length > room
                        ? null
                        : () => _insertVar(v),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              l.discoverDestCustomHelp,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(
    AppLocalizations l,
    DestinationView? view, {
    bool loading = false,
  }) {
    final saving = jobs.savingDestination;
    final d = view?.destination;
    final canSave =
        !loading && !saving && d != null && _dirty && !_customBlocks;
    final ink = keepInk();
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: VelvetColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        spacing: 8,
        children: [
          if (view != null && _mine(view))
            Semantics(
              button: true,
              enabled: !saving,
              child: KeepHitArea(
                onTap: saving ? null : () => unawaited(_save(null)),
                child: Padding(
                  key: const ValueKey('destination-use-default'),
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Text(
                    l.discoverDestUseDefault,
                    style: TextStyle(
                      color: saving ? VelvetColors.textTertiary : ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 1),
          _SaveButton(
            label: saving ? l.discoverDestSaving : l.save,
            busy: saving,
            enabled: canSave,
            onTap: () {
              final v = _vpath;
              final layout = _chosenLayout;
              if (v == null || layout == null) return;
              // No base folder: one set elsewhere went into the layout (a
              // preset chosen over it leaves it behind).
              unawaited(
                _save(
                  CollectionDestination(vpath: v, base: '', layout: layout),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// [s] as one unbreakable run: no-break spaces, and a word joiner after
/// each hyphen ("01 - Rooftop Cypher.mp3" would otherwise break after its
/// dash).
String _hold(String s) =>
    s.replaceAll(' ', '\u00A0').replaceAll('-', '-\u2060');

// ── pieces ────────────────────────────────────────────────────────────────

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    child: Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: VelvetColors.border2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// A library choice (FedChipRow's chip in the canvas's size): 40 px, radius
/// 10, a 44 px band, at least 96 wide; the chosen one primary-dim with a
/// 1.5 px primary edge and a check. Keep a copy's "Into a folder…" lists the
/// libraries with it too.
class KeepLibraryChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback? onTap;
  const KeepLibraryChip({
    super.key,
    required this.name,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      // The hit band leaves itself out of semantics: the tap is the chip's.
      onTap: onTap,
      child: KeepHitArea(
        onTap: onTap,
        child: Material(
          color: selected ? VelvetColors.primaryDim : Colors.transparent,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? VelvetColors.primary : VelvetColors.border2,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 16, color: VelvetColors.textPrimary),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One layout: a radio, its name, and under it the template in monospace
/// (Custom's line in the plain face, read as its [hint]).
class _LayoutOption extends StatelessWidget {
  final String label;
  final String sub;
  final bool mono;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;
  const _LayoutOption({
    super.key,
    required this.label,
    required this.sub,
    this.mono = true,
    this.hint,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    button: true,
    label: label,
    hint: hint,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      splashColor: VelvetColors.primaryDim,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? VelvetColors.primary
                        : VelvetColors.textSecondary,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VelvetColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 15,
                        height: 20 / 15,
                      ),
                    ),
                    Text(
                      sub,
                      style: mono
                          ? TextStyle(
                              color: VelvetColors.textSecondary,
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 16 / 11,
                            )
                          : TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 12,
                              height: 16 / 12,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A variable Custom inserts at its caret: the token in monospace on a
/// 32 px chip, a 44 px target, named for a screen reader ("Insert artist").
class _VarChip extends StatelessWidget {
  final String token;
  final String label;
  final VoidCallback? onTap;
  const _VarChip({
    super.key,
    required this.token,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: KeepHitArea(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: VelvetColors.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VelvetColors.border2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                token,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onTap == null
                      ? VelvetColors.textTertiary
                      : VelvetColors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Save: an outline in tertiary until there is something to save, then the
/// primary fill; a ring while the PUT is out.
class _SaveButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  const _SaveButton({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = enabled && !busy;
    final fg = on ? VelvetColors.onPrimary : VelvetColors.textTertiary;
    return Semantics(
      button: true,
      enabled: on,
      child: KeepHitArea(
        onTap: on ? onTap : null,
        child: Container(
          key: const ValueKey('destination-save'),
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on ? keepFill() : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: on ? null : Border.all(color: VelvetColors.border2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// No library, uploads off, a failed read: one card, one pill.
class _BlockCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? sub;
  final Widget pill;
  const _BlockCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.sub,
    required this.pill,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        color: VelvetColors.card,
        border: Border.all(color: VelvetColors.border),
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VelvetColors.raised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 15,
              height: 20 / 15,
            ),
          ),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          pill,
        ],
      ),
    ),
  );
}

class _Block extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _Block({this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    height: 72,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: VelvetColors.border2,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (w, top) in const [
                (120.0, 0.0),
                (230.0, 10.0),
                (150.0, 8.0),
              ])
                Padding(
                  padding: EdgeInsets.only(top: top),
                  child: Container(
                    width: w,
                    height: 10,
                    decoration: BoxDecoration(
                      color: VelvetColors.border2,
                      borderRadius: BorderRadius.circular(5),
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

class _FormSkeleton extends StatelessWidget {
  final String label;
  const _FormSkeleton({required this.label});

  Widget _cap(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: VelvetColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey('destination-loading'),
      label: label,
      container: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _cap(l.discoverDestLibrary),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Block(width: 96, height: 40, radius: 10),
                  SizedBox(width: 8),
                  _Block(width: 88, height: 40, radius: 10),
                ],
              ),
            ),
            _cap(l.discoverDestLayout),
            for (final w in const [110.0, 180.0])
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    const _Block(width: 20, height: 20, radius: 10),
                    const SizedBox(width: 14),
                    _Block(width: w, height: 12, radius: 6),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
