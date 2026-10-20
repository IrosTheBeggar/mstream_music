import 'dart:async';

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
/// add files to, a base folder inside it, and a layout — Artist / Album,
/// Server / Artist / Album, the chosen library's own Path Template when it
/// has one. The preview renders where the sheet's song would land as the
/// user types (the server's own layout engine, ported). "Use the library
/// default" saves none.
///
/// States: loading (still blocks; Save off), the default in force (tag
/// "library default"), a saved one ("yours"), saving (inputs locked), a
/// refusal (the server's words under the field), no library that takes
/// files, uploads off, and a read that failed (Try again).

/// The song a preview renders.
class DestinationPreviewSong {
  final String title;
  final String artist;
  final String? album;
  final String? albumArtist;
  final int? year;

  /// The file's path on the connected server (its name is kept).
  final String? filepath;
  const DestinationPreviewSong({
    required this.title,
    required this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.filepath,
  });

  factory DestinationPreviewSong.ofLead(DiscoveryLead lead) =>
      DestinationPreviewSong(
        title: lead.title,
        artist: lead.artist,
        album: lead.album,
        albumArtist: lead.albumArtist,
        year: lead.year,
        filepath: lead.filepath,
      );
}

/// The "Artist / Album" preset when the server names no default layout:
/// by the album's credit (the server's own default), so a compilation copied
/// whole stays in one folder; ALBUMARTIST falls back to the song's artist.
/// The picker takes the server's [DestinationView.defaultLayout] first.
const String kLayoutArtistAlbum = kDefaultCopyLayout;

/// The "Server / Artist / Album" preset, by the album's credit too.
const String kLayoutServerArtistAlbum = '{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}';

Future<void> showDestinationSheet(
  BuildContext context,
  DiscoveryJobsController jobs, {
  DestinationPreviewSong? song,
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
  builder: (_) => DestinationSheet(jobs: jobs, song: song, peerName: peerName),
);

class DestinationSheet extends StatefulWidget {
  final DiscoveryJobsController jobs;
  final DestinationPreviewSong? song;
  final String peerName;
  const DestinationSheet({
    super.key,
    required this.jobs,
    this.song,
    this.peerName = '',
  });

  @override
  State<DestinationSheet> createState() => _DestinationSheetState();
}

/// Which input a refusal names.
enum _Field { base, layout, other }

class _DestinationSheetState extends State<DestinationSheet> {
  final TextEditingController _base = TextEditingController();
  String? _vpath;
  String? _layout;
  CollectionDestination? _from;

  /// The server's words for the last refused save, and the input they name.
  String? _saveError;
  _Field? _saveErrorField;

  DiscoveryJobsController get jobs => widget.jobs;

  @override
  void initState() {
    super.initState();
    _sync(force: true);
    jobs.addListener(_onJobs);
    _base.addListener(_onTyping);
    // What the server holds now (it may have changed on another device).
    if (!jobs.savingDestination) unawaited(jobs.loadDestination());
  }

  @override
  void dispose() {
    jobs.removeListener(_onJobs);
    _base.removeListener(_onTyping);
    _base.dispose();
    super.dispose();
  }

  void _onJobs() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  /// The text as last seen (a focus or selection change notifies too).
  String _typed = '';

  void _onTyping() {
    if (!mounted || _base.text == _typed) return;
    _typed = _base.text;
    setState(() {
      if (_saveErrorField == _Field.base) {
        _saveError = null;
        _saveErrorField = null;
      }
    });
  }

  /// The form takes the server's destination: the first time it is known,
  /// and again whenever it changes while nothing was edited (or [force]).
  void _sync({bool force = false}) {
    final d = jobs.destination?.destination;
    if (d == null || identical(d, _from)) return;
    // An edit in progress is kept; Save or Close settles it.
    if (!force && _from != null && _dirty) return;
    _from = d;
    _vpath = d.vpath;
    _layout = d.layout;
    _typed = d.base;
    if (_base.text != d.base) _base.text = d.base;
  }

  bool get _dirty {
    final d = _from;
    if (d == null) return false;
    return _vpath != d.vpath ||
        _layout != d.layout ||
        normalizeBase(_base.text).base != normalizeBase(d.base).base ||
        !normalizeBase(_base.text).valid;
  }

  /// The account's own destination is in force (not the library default).
  static bool _mine(DestinationView view) {
    final d = view.destination;
    if (d == null) return false;
    return d.source == 'user' || (d.source == null && view.saved != null);
  }

  _Field _fieldOf(String words) {
    final w = words.toLowerCase();
    if (w.contains('base')) return _Field.base;
    if (w.contains('layout') || w.contains('template')) return _Field.layout;
    return _Field.other;
  }

  String _landing(CollectionDestination d) =>
      [d.vpath, ...pathCrumbs(normalizeBase(d.base).base)].join(' › ');

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
      preview = _preview(l);
      body = _form(l, view);
      footer = _footer(l, view);
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
            _header(l, tag, tagMine),
            Divider(height: 1, thickness: 1, color: VelvetColors.border),
            ?preview,
            Flexible(child: body),
            ?footer,
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l, String? tag, bool mine) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 4, 10),
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

  /// Where the sheet's song would land, or why the preview waits.
  Widget? _preview(AppLocalizations l) {
    final song = widget.song;
    if (song == null) return null;
    final t = previewTarget(
      vpath: _vpath,
      base: _base.text,
      layout: _layout,
      tags: {
        'artist': song.artist,
        'album': song.album,
        'year': song.year,
        'albumartist': song.albumArtist,
      },
      peerName: widget.peerName,
      fileName: song.filepath ?? song.title,
    );
    final Widget content;
    final Widget icon;
    if (!t.valid) {
      icon = Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: keepTone(VelvetColors.warning),
      );
      content = Text(
        t.field == 'base' ? l.discoverDestFixBase : l.discoverDestFixLayout,
        key: const ValueKey('destination-preview-invalid'),
        style: TextStyle(
          color: VelvetColors.textSecondary,
          fontSize: 13,
          height: 18 / 13,
        ),
      );
    } else {
      icon = Icon(
        Icons.folder_outlined,
        size: 16,
        color: VelvetColors.textSecondary,
      );
      final crumbs = [...t.crumbs, t.file];
      final soft = TextStyle(color: VelvetColors.textSecondary);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.discoverDestLandsAt(song.title),
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
                  TextSpan(text: _hold(crumbs[i])),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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

  Widget _errorLine(String words, Key key) => Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 14,
              color: keepTone(VelvetColors.error),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              words,
              style: TextStyle(
                color: keepTone(VelvetColors.error),
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _form(AppLocalizations l, DestinationView view) {
    final saving = jobs.savingDestination;
    final vpath = _vpath ?? view.destination!.vpath;
    final libs = [
      ...view.libraries,
      if (!view.libraries.any((w) => w.vpath == vpath)) WritableLibrary(vpath),
    ];
    final template = libs
        .firstWhere(
          (w) => w.vpath == vpath,
          orElse: () => WritableLibrary(vpath),
        )
        .template;
    final layout = _layout ?? view.destination!.layout;
    // "Artist / Album" is the server's own default (by the album's credit
    // since the compilations change), so a fresh account's layout matches
    // it and no "Your current layout" appears beside it.
    final artistAlbum = view.defaultLayout.trim().isNotEmpty
        ? view.defaultLayout
        : kLayoutArtistAlbum;
    final presets = <(String, String)>[
      (l.discoverDestPresetArtistAlbum, artistAlbum),
      if (artistAlbum != kLayoutServerArtistAlbum)
        (l.discoverDestPresetServer, kLayoutServerArtistAlbum),
      if (template != null &&
          template.trim().isNotEmpty &&
          template != artistAlbum &&
          template != kLayoutServerArtistAlbum)
        (l.discoverDestPresetLibrary, template),
    ];
    if (!presets.any((p) => p.$2 == layout)) {
      presets.add((l.discoverDestPresetCurrent, layout));
    }
    final baseCheck = normalizeBase(_base.text);
    final baseBad = !baseCheck.valid || _saveErrorField == _Field.base;
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
                  _LibraryChip(
                    key: ValueKey('destination-library-${lib.vpath}'),
                    name: lib.vpath,
                    selected: lib.vpath == vpath,
                    onTap: saving
                        ? null
                        : () => setState(() {
                            _vpath = lib.vpath;
                            _saveError = null;
                            _saveErrorField = null;
                          }),
                  ),
              ],
            ),
          ),
          _label(l.discoverDestBase),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.symmetric(horizontal: baseBad ? 11 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                border: Border.all(
                  color: baseBad
                      ? keepTone(VelvetColors.error)
                      : VelvetColors.border2,
                  width: baseBad ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$vpath /',
                    style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      label: l.discoverDestBase,
                      child: TextField(
                        key: const ValueKey('destination-base'),
                        controller: _base,
                        enabled: !saving,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(
                          color: VelvetColors.textPrimary,
                          fontSize: 15,
                        ),
                        cursorColor: VelvetColors.primary,
                        scrollPadding: const EdgeInsets.only(bottom: 120),
                        // The box around it is the field's frame: none of
                        // the theme's own borders or fill inside it.
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintText: l.discoverDestBaseHint,
                          hintStyle: TextStyle(
                            color: VelvetColors.textTertiary,
                            fontSize: 15,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_saveErrorField == _Field.base && _saveError != null)
            _errorLine(_saveError!, const ValueKey('destination-base-error'))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                l.discoverDestBaseHelp(vpath),
                style: TextStyle(
                  color: VelvetColors.textSecondary,
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
            ),
          _label(l.discoverDestLayout),
          for (final p in presets)
            _LayoutOption(
              key: ValueKey('destination-layout-${p.$2}'),
              label: p.$1,
              template: p.$2,
              selected: p.$2 == layout,
              onTap: saving
                  ? null
                  : () => setState(() {
                      _layout = p.$2;
                      if (_saveErrorField == _Field.layout) {
                        _saveError = null;
                        _saveErrorField = null;
                      }
                    }),
            ),
          if (_saveErrorField == _Field.layout && _saveError != null)
            _errorLine(_saveError!, const ValueKey('destination-layout-error')),
          if (_saveErrorField == _Field.other && _saveError != null)
            _errorLine(_saveError!, const ValueKey('destination-save-error')),
          const SizedBox(height: 8),
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
    final canSave = !loading && !saving && d != null && _dirty;
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
              final layout = _layout;
              if (v == null || layout == null) return;
              unawaited(
                _save(
                  CollectionDestination(
                    vpath: v,
                    base: _base.text.trim(),
                    layout: layout,
                  ),
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
/// 10; the chosen one primary-dim with a 1.5 px primary edge and a check.
class _LibraryChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback? onTap;
  const _LibraryChip({
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

/// One layout: a radio, its name, the template in monospace.
class _LayoutOption extends StatelessWidget {
  final String label;
  final String template;
  final bool selected;
  final VoidCallback? onTap;
  const _LayoutOption({
    super.key,
    required this.label,
    required this.template,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    button: true,
    label: label,
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
                      template,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 16 / 11,
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
            _cap(l.discoverDestBase),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _Block(height: 48, radius: 7),
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
