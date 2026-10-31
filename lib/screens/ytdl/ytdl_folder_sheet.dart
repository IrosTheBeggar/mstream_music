import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/server.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart' show pathCrumbs;
import '../../util/ytdl_layout.dart';
import '../discovery/destination_pieces.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_action_bar.dart';
import 'ytdl_card_parts.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart';
import 'ytdl_paste_card.dart';
import 'ytdl_result_card.dart';

/// "Add from YouTube here" in the explorer (spec §7): the paste bar and the
/// result card in a sheet that adds into [currentPath] ('/Music/Daft
/// Punk/') — "Add here" sends that folder unchanged, with no mkdir. "Sort
/// into subfolders…" turns the sheet to a second page that picks folders
/// under it (never remembered: every sheet starts at Right here).
///
/// Scroll-controlled, at most 89% of the screen, lifted by the keyboard;
/// it opens with the keyboard down. It stays open showing "Starting…"
/// until the POST answers, closes on 200, and shows a refusal inside.
/// Dragged down while starting, the hub carries on and the outcome reaches
/// the folder strip. Each folder keeps its own draft for the session.
///
/// "Choose a folder…" (an account that can't make folders after all, a
/// folder that couldn't be made) never opens a sheet on top of this one
/// (spec §1): this sheet goes, the folder picker comes, and this sheet
/// comes back with the pick applied — or as it was, when cancelled.
///
/// The feature gone for [server] (a re-ping turned uploads or conversion
/// off — after a menu offering it was built, or while the picker was up)
/// opens nothing, and says why.
Future<void> showYtdlFolderSheet(
  BuildContext context,
  Server server,
  String currentPath,
) async {
  final st = YtdlHub().stateFor(server);
  // A new sheet starts at Right here; the round trip through the picker
  // comes back as it left.
  st.folderDraft(currentPath).sheetOpened();
  for (;;) {
    if (!context.mounted) return;
    if (!st.entryAllowed) {
      final why = ytdlEntryOffReason(AppLocalizations.of(context), server);
      if (why != null) YtdlHub().showToast(why);
      return;
    }
    final gone = Completer<void>();
    final exit = await showModalBottomSheet<YtdlFolderSheetExit>(
      context: context,
      useRootNavigator: true,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.89,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          YtdlFolderSheet(server: server, currentPath: currentPath, gone: gone),
    );
    if (exit != YtdlFolderSheetExit.chooseFolder) return;
    // Once it has slid away and let go of its draft: the picker never
    // shows over it, and the sheet coming back attaches after it.
    await gone.future;
    if (!context.mounted) return;
    await ytdlChooseFolder(context, st.folderDraft(currentPath));
  }
}

/// Why the folder sheet closed, when it isn't simply done.
enum YtdlFolderSheetExit {
  /// "Choose a folder…": the picker takes its place, then it comes back.
  chooseFolder,
}

/// The sheet's body ([showYtdlFolderSheet]).
class YtdlFolderSheet extends StatefulWidget {
  final Server server;
  final String currentPath;

  /// Completes once the sheet has left the tree.
  final Completer<void>? gone;

  const YtdlFolderSheet({
    super.key,
    required this.server,
    required this.currentPath,
    this.gone,
  });

  @override
  State<YtdlFolderSheet> createState() => _YtdlFolderSheetState();
}

class _YtdlFolderSheetState extends State<YtdlFolderSheet> {
  late final YtdlServerState _st = YtdlHub().stateFor(widget.server);
  late final YtdlDraft _d = _st.folderDraft(widget.currentPath);

  final GlobalKey _savesKey = GlobalKey(debugLabel: 'ytdl-sheet-saves');
  final GlobalKey<YtdlFormatChipState> _formatKey = GlobalKey();

  bool _subfolders = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _d.attach();
    _st.addListener(_stateMoved);
  }

  @override
  void dispose() {
    _st.removeListener(_stateMoved);
    _d.detach();
    final gone = widget.gone;
    if (gone != null && !gone.isCompleted) gone.complete();
    super.dispose();
  }

  /// A re-ping turned the feature off: the sheet closes, saying why.
  void _stateMoved() {
    if (_closing || !mounted || _st.entryAllowed) return;
    _close(why: ytdlEntryOffReason(AppLocalizations.of(context), _st.server));
  }

  /// Closes this sheet's own route — and whatever is open over it (the
  /// format menu, opened while "Starting…" ran): popping the top route
  /// would close only that.
  void _close({String? why, YtdlFolderSheetExit? exit}) {
    if (_closing || !mounted) return;
    final route = ModalRoute.of(context);
    final nav = route?.navigator;
    if (route == null || nav == null || !route.isActive) return;
    _closing = true;
    if (why != null) YtdlHub().showToast(why);
    nav.popUntil((r) => r == route);
    nav.pop(exit);
  }

  Future<void> _add() async {
    final ok = await _d.add();
    if (ok && mounted) _close();
  }

  /// The picker in this sheet's place ([showYtdlFolderSheet]).
  void _chooseFolder() => _close(exit: YtdlFolderSheetExit.chooseFolder);

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      // Back on the second page goes back to the first.
      canPop: !_subfolders,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _subfolders) setState(() => _subfolders = false);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SafeArea(
          top: false,
          child: _subfolders
              ? YtdlSubfoldersPage(
                  draft: _d,
                  onBack: () => setState(() => _subfolders = false),
                  // The page previews folders under the one on screen: a
                  // folder chosen for this song gives way to them.
                  onDone: (layout) {
                    _d.undoJustThisSong();
                    _d.setSubLayout(layout);
                    setState(() => _subfolders = false);
                  },
                  onEditTags: (layout, field) {
                    _d.undoJustThisSong();
                    _d.setSubLayout(layout);
                    setState(() => _subfolders = false);
                    _d.openTags(focus: field);
                  },
                )
              : _first(context),
        ),
      ),
    );
  }

  Widget _first(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (before, after) = ytdlAround(l.ytdlSheetInto);
    return ListenableBuilder(
      listenable: _d,
      builder: (context, _) {
        final card = YtdlResultCard.showsFor(_d);
        final bar = _d.lookup != YtdlLookupState.ytdlpMissing || !card;
        return Column(
          key: const ValueKey('ytdl-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DestGrabHandle(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.ytdlTitle,
                          style: TextStyle(
                            color: VelvetColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 22 / 18,
                          ),
                        ),
                        YtdlCrumbLine(
                          crumbs: pathCrumbs(widget.currentPath),
                          prefix: before,
                          suffix: after,
                          style: DefaultTextStyle.of(context).style.merge(
                            TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 13,
                              height: 18 / 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('ytdl-sheet-close'),
                    tooltip: l.close,
                    onPressed: () => _close(),
                    icon: Icon(Icons.close, color: VelvetColors.textSecondary),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    YtdlPasteCard(draft: _d, landsIn: false),
                    if (card) ...[
                      const SizedBox(height: 12),
                      YtdlResultCard(
                        draft: _d,
                        savesKey: _savesKey,
                        sheet: true,
                        onChooseFolder: _chooseFolder,
                        onChangeFormat: () => _formatKey.currentState?.open(),
                        onSortSubfolders: () =>
                            setState(() => _subfolders = true),
                      ),
                    ] else if (_st.tier == YtdlServerTier.full) ...[
                      const SizedBox(height: 12),
                      YtdlLimitsLine(state: _st),
                    ],
                  ],
                ),
              ),
            ),
            if (bar) ...[
              YtdlActionBar(
                draft: _d,
                sheet: true,
                formatKey: _formatKey,
                onAdd: _add,
                onChooseFolder: _chooseFolder,
              ),
              YtdlDoneBar(draft: _d),
            ],
          ],
        );
      },
    );
  }
}

/// The folder sheet's second page, "Sort into subfolders" (spec §7, the
/// ExplorerSubfolders board): the folder on screen as a locked crumb, the
/// choices Right here · Album · Artist / Album · Custom (the allow-list and
/// the literal-character check of the Where sheet's editor), and the
/// preview — where the song lands under the choice not applied yet, with
/// "1 new folder will be made: Discovery". Back cancels; Done applies.
class YtdlSubfoldersPage extends StatefulWidget {
  final YtdlDraft draft;
  final VoidCallback onBack;
  final ValueChanged<String> onDone;

  /// The preview's bracket warning: apply [layout], back to the first page
  /// with [field] focused.
  final void Function(String layout, YtdlField field) onEditTags;

  const YtdlSubfoldersPage({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onDone,
    required this.onEditTags,
  });

  @override
  State<YtdlSubfoldersPage> createState() => _YtdlSubfoldersPageState();
}

enum _Sub { here, album, artistAlbum, custom }

class _YtdlSubfoldersPageState extends State<YtdlSubfoldersPage> {
  late _Sub _sub;
  late final TextEditingController _custom;
  final FocusNode _customFocus = FocusNode(debugLabel: 'ytdl-sub-custom');

  /// The new-folder check of the previewed path, and the path it is for.
  YtdlFolderCheck? _check;
  String? _checkFor;
  Timer? _checkTimer;

  /// The preview as read out: it follows the screen [kYtdlSpeakAfter]
  /// after the last change, so a screen reader hears where the song lands
  /// once, not on every keystroke (spec §9). [_spokenBad]: the words are
  /// the refusal's — one state's words never carry over to the other.
  String? _spoken;
  String? _spokenNext;
  bool? _spokenBad;
  Timer? _speakTimer;

  YtdlDraft get _d => widget.draft;

  @override
  void initState() {
    super.initState();
    final now = _d.subLayout;
    _sub = switch (now) {
      kYtdlLayoutTop => _Sub.here,
      kYtdlLayoutAlbum => _Sub.album,
      kYtdlLayoutArtistAlbum => _Sub.artistAlbum,
      _ => _Sub.custom,
    };
    _custom = TextEditingController(text: _sub == _Sub.custom ? now : '');
    _custom.addListener(_moved);
    _d.addListener(_moved);
    _recheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speak();
  }

  @override
  void dispose() {
    _d.removeListener(_moved);
    _checkTimer?.cancel();
    _speakTimer?.cancel();
    _custom.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  /// The choice, the custom layout or the draft (a lookup landing, a tag
  /// typed) moved: the preview follows, and a path it moved to is checked.
  void _moved() {
    if (!mounted) return;
    setState(() {});
    _recheck();
    _speak();
  }

  /// The preview's words are read [kYtdlSpeakAfter] after they settle.
  void _speak() {
    if (!mounted) return;
    final m = _model(AppLocalizations.of(context), _target);
    if (_spoken == null) {
      _spoken = _spokenNext = m.words;
      _spokenBad = m.bad;
      return;
    }
    if (m.bad != _spokenBad) {
      // From a path to the refusal or back: what was read no longer says
      // what the preview shows. Nothing is read until the new words settle.
      _spoken = '';
      _spokenBad = m.bad;
    }
    if (m.words != _spokenNext) {
      _spokenNext = m.words;
      _speakTimer?.cancel();
      _speakTimer = YtdlHub().timer(kYtdlSpeakAfter, () {
        if (mounted) setState(() => _spoken = _spokenNext);
      });
    }
  }

  /// The previewed target under the choice on this page; null while the
  /// custom layout is refused.
  YtdlTarget? get _target => _refusal == null
      ? _d.targetFor(YtdlChoice.folder(_d.folder!, layout: _layout))
      : null;

  void _recheck() => _scheduleCheck(_target);

  String get _layout => switch (_sub) {
    _Sub.here => kYtdlLayoutTop,
    _Sub.album => kYtdlLayoutAlbum,
    _Sub.artistAlbum => kYtdlLayoutArtistAlbum,
    _Sub.custom => _custom.text.trim(),
  };

  /// The custom layout's refusal, or null.
  YtdlLayoutCheck? get _refusal {
    if (_sub != _Sub.custom) return null;
    final c = ytdlLayoutCheck(_custom.text.trim());
    return c.valid ? null : c;
  }

  /// Check [t]'s folders [YtdlDraft.kCheckAfter] after it settles; an
  /// answer for a path since left is dropped.
  void _scheduleCheck(YtdlTarget? t) {
    final dir = t != null && t.valid ? t.directory : null;
    if (dir == _checkFor) return;
    _checkFor = dir;
    _check = null;
    _checkTimer?.cancel();
    if (dir == null) return;
    _checkTimer = YtdlHub().timer(YtdlDraft.kCheckAfter, () async {
      final c = await _d.checkTarget(t!);
      if (!mounted || _checkFor != dir) return;
      setState(() => _check = c);
      _speak();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final refusal = _refusal;
    final target = _target;
    return Column(
      key: const ValueKey('ytdl-subfolders'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DestGrabHandle(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 16, 0),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('ytdl-sub-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back, color: VelvetColors.textPrimary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l.ytdlSubfoldersTitle,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 22 / 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _here(l),
                ),
                ..._choices(l),
                if (_sub == _Sub.custom)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(50, 0, 16, 4),
                    child: _editor(l, refusal),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _preview(l, target),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: VelvetColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          alignment: AlignmentDirectional.centerEnd,
          child: _done(l, enabled: refusal == null),
        ),
      ],
    );
  }

  /// "Music › Daft Punk ›" on a locked pill, "The folder you're in".
  Widget _here(AppLocalizations l) {
    final crumbs = pathCrumbs(_d.folder!);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Semantics(
          label: '${l.ytdlA11yLocked}, ${ytdlSpokenPath(l, crumbs)}',
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: VelvetColors.raised,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: VelvetColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${ytdlPathText(crumbs)}$kYtdlCrumbSep'.trimRight(),
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        YtdlHelper(l.ytdlSubfoldersHere, color: VelvetColors.textSecondary),
      ],
    );
  }

  List<Widget> _choices(AppLocalizations l) {
    Widget option(_Sub s, String label, String sub, {bool mono = true}) =>
        DestLayoutOption(
          key: ValueKey('ytdl-sub-${s.name}'),
          label: label,
          sub: sub,
          mono: mono,
          hint: mono ? null : sub,
          selected: _sub == s,
          onTap: () {
            setState(() => _sub = s);
            if (s == _Sub.custom) _customFocus.requestFocus();
            _recheck();
            _speak();
          },
        );
    return [
      option(
        _Sub.here,
        l.ytdlSubfoldersRightHere,
        l.ytdlSubfoldersNone,
        mono: false,
      ),
      option(_Sub.album, l.torrentAlbumLabel, kYtdlLayoutAlbum),
      option(
        _Sub.artistAlbum,
        l.discoverDestPresetArtistAlbum,
        kYtdlLayoutArtistAlbum,
      ),
      option(
        _Sub.custom,
        l.discoverDestPresetCustom,
        l.discoverDestCustomSub,
        mono: false,
      ),
    ];
  }

  /// Custom: the field, the four variables (inserted at the caret, ticked
  /// once used), its refusal, the help line.
  Widget _editor(AppLocalizations l, YtdlLayoutCheck? refusal) {
    final warn = keepTone(VelvetColors.warning);
    final radius = BorderRadius.circular(7);
    OutlineInputBorder edge(Color c, double w) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: c, width: w),
    );
    final text = _custom.text;
    String insertLabel(String v) => switch (v) {
      'ARTIST' => l.discoverDestInsertArtist,
      'ALBUMARTIST' => l.discoverDestInsertAlbumArtist,
      'ALBUM' => l.discoverDestInsertAlbum,
      _ => l.discoverDestInsertYear,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: l.discoverDestCustomField,
          child: TextField(
            key: const ValueKey('ytdl-sub-custom-field'),
            controller: _custom,
            focusNode: _customFocus,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            cursorColor: VelvetColors.primary,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: VelvetColors.raised,
              hintText: l.discoverDestCustomSub,
              hintStyle: TextStyle(color: VelvetColors.helper, fontSize: 14),
              constraints: const BoxConstraints(minHeight: kYtdlHit),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: refusal != null
                  ? edge(warn, 2)
                  : edge(VelvetColors.border, 1),
              focusedBorder: refusal != null
                  ? edge(warn, 2)
                  : edge(VelvetColors.primary, 1.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          label: l.ytdlA11yInsertVariable,
          container: true,
          child: Wrap(
            spacing: 8,
            children: [
              for (final v in kYtdlVars)
                DestVarChip(
                  key: ValueKey('ytdl-var-$v'),
                  token: v,
                  label: text.contains(destToken(v))
                      ? l.ytdlA11yVarUsed(insertLabel(v))
                      : insertLabel(v),
                  used: text.contains(destToken(v)),
                  minHit: kYtdlHit,
                  onTap: () =>
                      destInsertVar(_custom, _customFocus, destToken(v)),
                ),
            ],
          ),
        ),
        if (refusal != null) ...[
          const SizedBox(height: 2),
          YtdlStatusLine(
            key: const ValueKey('ytdl-sub-custom-error'),
            icon: Icons.warning_amber_rounded,
            color: warn,
            fontSize: 12,
            live: false,
            text: _refusalText(l, refusal),
          ),
        ],
        const SizedBox(height: 4),
        YtdlHelper(l.ytdlCustomHelp, color: VelvetColors.textSecondary),
      ],
    );
  }

  String _refusalText(AppLocalizations l, YtdlLayoutCheck c) {
    final vars = kYtdlVars.join(', ');
    return switch (c.issue) {
      YtdlLayoutIssue.unknownVariable => l.discoverDestErrUnknownVar(
        c.token ?? '',
        vars,
      ),
      YtdlLayoutIssue.neverVariable => l.ytdlErrNeverVar(c.token ?? '', vars),
      YtdlLayoutIssue.badChars => l.ytdlErrBadChars,
      YtdlLayoutIssue.engine =>
        c.engine == null
            ? l.discoverDestErrGeneric
            : destLayoutProblem(l, c.engine!, kYtdlVars),
      YtdlLayoutIssue.none => '',
    };
  }

  /// What the preview shows and says for [t]: the refusal ([bad]), or
  /// "“One More Time” lands at", the path with its new folders, and the
  /// notes under it.
  _SubPreview _model(AppLocalizations l, YtdlTarget? t) {
    if (t == null || !t.valid) {
      return _SubPreview.bad(l.discoverDestFixLayout);
    }
    final check = _check;
    final fresh = check == null
        ? const <int>[]
        : (check.newSegments.toList()..sort());
    final title = _d.displayTitle;
    final trap = t.trap;
    final newAt = {for (final i in fresh) i + 1};
    final trapAt = {
      if (trap != null && t.segments.contains(trap.folder))
        t.segments.indexOf(trap.folder) + 1,
    };
    final file = _d.predictedName.isEmpty ? null : _d.predictedName;
    final label =
        title.isEmpty ? l.ytdlWhereLandsAtSample : l.ytdlWhereLandsAt(title);
    final notes = <(String, Key?)>[
      if (fresh.isNotEmpty)
        (
          l.ytdlSubfoldersNew(
            fresh.length,
            [for (final i in fresh) t.segments[i]].join(', '),
          ),
          const ValueKey('ytdl-sub-new'),
        ),
      if (t.missingVars.isNotEmpty)
        (
          l.discoverDestMissing(
            t.missingVars.map((v) => '{{$v}}').join(', '),
          ),
          null,
        ),
    ];
    final trapWords = trap == null
        ? null
        : switch (trap.kind) {
            YtdlTrapKind.emptyFolder => l.ytdlTrapEmpty(trap.folder),
            YtdlTrapKind.missingYear => l.ytdlTrapNoYear(trap.folder),
            YtdlTrapKind.other => l.ytdlTrapOther(trap.folder),
          };
    final path = ytdlSpokenPath(l, t.crumbs,
        newAt: newAt, trapAt: trapAt, file: file);
    return _SubPreview(
      label: label,
      crumbs: t.crumbs,
      newAt: newAt,
      trapAt: trapAt,
      file: file,
      notes: notes,
      trap: trap,
      trapWords: trapWords,
      words: [
        '$label $path.',
        for (final n in notes) n.$1,
        ?trapWords,
      ].join(' '),
    );
  }

  /// Where the song lands under the choice on this page, or why it can't
  /// say. One live region either way, at the same place in the tree (a
  /// live region that appears is read at once: swapping one for another
  /// as a token is half typed would read the refusal mid-word). Its words
  /// are [_spoken], read [kYtdlSpeakAfter] after the preview settles; the
  /// bracket warning's link stays a button of its own beside it.
  Widget _preview(AppLocalizations l, YtdlTarget? t) {
    final m = _model(l, t);
    final note = TextStyle(
      color: VelvetColors.textSecondary,
      fontSize: 12,
      height: 16 / 12,
    );
    final trap = m.trap;
    final Widget shown;
    if (m.bad) {
      shown = YtdlStatusLine(
        icon: Icons.warning_amber_rounded,
        color: keepTone(VelvetColors.warning),
        textColor: VelvetColors.textPrimary,
        fontSize: 14,
        live: false,
        text: m.words,
      );
    } else {
      shown = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.label,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
          const SizedBox(height: 2),
          YtdlCrumbs(
            crumbs: m.crumbs,
            newAt: m.newAt,
            trapAt: m.trapAt,
            file: m.file,
            style: const TextStyle(fontSize: 14, height: 20 / 14),
          ),
          for (final (words, key) in m.notes) ...[
            const SizedBox(height: 6),
            Text(words, key: key, style: note),
          ],
          if (trap != null) ...[
            const SizedBox(height: 6),
            YtdlStatusLine(
              icon: Icons.warning_amber_rounded,
              color: keepTone(VelvetColors.warning),
              textColor: VelvetColors.textPrimary,
              fontSize: 12,
              live: false,
              text: m.trapWords!,
            ),
          ],
        ],
      );
    }
    return YtdlGround(
      color: VelvetColors.raised,
      child: Container(
        key: const ValueKey('ytdl-sub-preview'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: m.bad
              ? VelvetColors.warning.withValues(alpha: 0.08)
              : VelvetColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: m.bad
              ? Border.all(color: VelvetColors.warning.withValues(alpha: 0.45))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.bad) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: VelvetColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              key: const ValueKey('ytdl-sub-preview-body'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drawn at once; read once it has settled.
                  Semantics(
                    key: const ValueKey('ytdl-sub-preview-spoken'),
                    container: true,
                    liveRegion: true,
                    label: _spoken ?? m.words,
                    excludeSemantics: true,
                    child: shown,
                  ),
                  if (!m.bad && trap != null) _trapLink(l, trap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The bracket warning's link: apply the layout, back to the first page
  /// with the field that fills the folder focused.
  Widget _trapLink(AppLocalizations l, YtdlTrap trap) {
    final (link, field) = switch (trap.kind) {
      YtdlTrapKind.missingYear => (l.ytdlTrapAddYear, YtdlField.year),
      YtdlTrapKind.emptyFolder ||
      YtdlTrapKind.other => (l.ytdlEditTags, YtdlField.album),
    };
    return YtdlTextLink(
      link,
      key: const ValueKey('ytdl-sub-trap-link'),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      onTap: () => widget.onEditTags(_layout, field),
    );
  }

  Widget _done(AppLocalizations l, {required bool enabled}) {
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        key: const ValueKey('ytdl-sub-done'),
        color: enabled ? keepFill() : VelvetColors.raised,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? () => widget.onDone(_layout) : null,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kYtdlHit,
              minWidth: 120,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Center(
              widthFactor: 1,
              child: Text(
                l.done,
                style: TextStyle(
                  color: enabled ? VelvetColors.onPrimary : VelvetColors.helper,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Sort into subfolders" preview for one state of the page: the path
/// and its notes, or the refusal ([bad], [words] its line) — and [words],
/// what the live region reads.
class _SubPreview {
  final bool bad;
  final String label;
  final List<String> crumbs;
  final Set<int> newAt;
  final Set<int> trapAt;
  final String? file;
  final List<(String, Key?)> notes;
  final YtdlTrap? trap;
  final String? trapWords;
  final String words;

  const _SubPreview({
    required this.label,
    required this.crumbs,
    required this.newAt,
    required this.trapAt,
    required this.file,
    required this.notes,
    required this.trap,
    required this.trapWords,
    required this.words,
  }) : bad = false;

  const _SubPreview.bad(this.words)
      : bad = true,
        label = '',
        crumbs = const [],
        newAt = const {},
        trapAt = const {},
        file = null,
        notes = const [],
        trap = null,
        trapWords = null;
}
