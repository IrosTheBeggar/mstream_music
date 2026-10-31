import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart' show pathCrumbs;
import '../../util/ytdl_api.dart';
import '../discovery/destination_pieces.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart';

/// "Choose a folder" for an account that can't make folders (spec §8
/// mkdir off, the NoMkdir board's frame 2) or after a folder couldn't be
/// made (§8 mkdir failed): browse the folders that exist on the draft's
/// server and pick one, for this song only. It opens at
/// [startAt] when given, else at the deepest folder on the song's path
/// that listed ([YtdlDraft.deepestExisting]: "Music › Daft Punk", with
/// "Music" to go up, as the board draws it), else at the draft's folder or
/// library ([ytdlChooseFolderStart]); it returns the folder
/// ('/Music/Daft Punk/'), or null when cancelled or when the feature goes
/// away while it is open; the caller applies it with [YtdlDraft.useFolder].
///
/// Each folder is listed as it is opened (`POST /file-explorer`, its
/// subfolders only); a crumb goes back up. "Use this folder" takes the
/// one on screen once it has listed — it is there.
Future<String?> showYtdlChooseFolderSheet(
  BuildContext context,
  YtdlDraft draft, {
  String? startAt,
}) =>
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.89,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => YtdlChooseFolderSheet(
        draft: draft,
        startAt: startAt ?? ytdlChooseFolderStart(draft),
      ),
    );

/// Where "Choose a folder" opens for [draft] when the caller names no
/// folder: the deepest folder on the song's path that listed, else the
/// folder the choice in force names, else its library.
String ytdlChooseFolderStart(YtdlDraft draft) {
  final deepest = draft.deepestExisting;
  if (deepest != null) return deepest;
  final c = draft.choice;
  return c.isFolder ? c.folderPath : '/${c.library}/';
}

/// [crumbs] as a directory: '/Music/Daft Punk/'.
String _dirOf(List<String> crumbs) => '/${crumbs.join('/')}/';

/// The sheet's body ([showYtdlChooseFolderSheet] opens it): pops with the
/// folder picked, or nothing.
class YtdlChooseFolderSheet extends StatefulWidget {
  final YtdlDraft draft;

  /// The folder it opens on: '/Music/' or deeper.
  final String startAt;

  const YtdlChooseFolderSheet({
    super.key,
    required this.draft,
    required this.startAt,
  });

  @override
  State<YtdlChooseFolderSheet> createState() => _YtdlChooseFolderSheetState();
}

class _YtdlChooseFolderSheetState extends State<YtdlChooseFolderSheet> {
  late List<String> _crumbs;

  /// The folder on screen as it listed; null while it lists or after it
  /// failed ([_failed]).
  YtdlListing? _listing;
  bool _failed = false;

  /// Each listing asked is numbered: an answer for a folder since left is
  /// dropped.
  int _rid = 0;

  final ScrollController _crumbScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _crumbs = pathCrumbs(widget.startAt);
    unawaited(_list());
    _showDeepest();
    widget.draft.addListener(_onDraft);
  }

  @override
  void dispose() {
    widget.draft.removeListener(_onDraft);
    _crumbScroll.dispose();
    super.dispose();
  }

  /// A re-ping turned the feature off (the draft passes on its state's
  /// news): the sheet goes with nothing picked, before the screen under it
  /// closes itself.
  void _onDraft() {
    if (!mounted || widget.draft.owner.entryAllowed) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop();
  }

  Future<void> _list() async {
    final rid = ++_rid;
    final dir = _dirOf(_crumbs);
    setState(() {
      _listing = null;
      _failed = false;
    });
    try {
      final listing = await widget.draft.owner.api.list(dir);
      if (!mounted || rid != _rid) return;
      setState(() => _listing = listing);
    } catch (_) {
      if (!mounted || rid != _rid) return;
      setState(() => _failed = true);
    }
  }

  void _open(List<String> crumbs) {
    _crumbs = crumbs;
    unawaited(_list());
    _showDeepest();
  }

  /// A path longer than its line scrolls to its end: the folder on screen
  /// stays in view.
  void _showDeepest() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_crumbScroll.hasClients) return;
        _crumbScroll.jumpTo(_crumbScroll.position.maxScrollExtent);
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final listing = _listing;
    final Widget body;
    if (_failed) {
      body = _status(
        key: const ValueKey('ytdl-choose-failed'),
        icon: Icons.error_outline,
        tone: keepTone(VelvetColors.error),
        words: l.ytdlCheckFailed,
        action: KeepPill(
          l.discoverPageRetry,
          key: const ValueKey('ytdl-choose-retry'),
          icon: Icons.refresh,
          onTap: () => unawaited(_list()),
        ),
      );
    } else if (listing == null) {
      body = const _Skeleton();
    } else {
      final folders = [...listing.directories]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      body = folders.isEmpty
          ? _status(
              key: const ValueKey('ytdl-choose-empty'),
              icon: Icons.folder_off_outlined,
              tone: VelvetColors.helper,
              words: l.ytdlChooseEmpty,
            )
          : ListView(
              key: const ValueKey('ytdl-choose-list'),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final f in folders) _row(f),
              ],
            );
    }
    return SafeArea(
      top: false,
      child: Column(
        key: const ValueKey('ytdl-choose-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DestGrabHandle(),
          _header(l),
          // Why only folders that are there — for an account that can't
          // make folders (the NoMkdir board). After a folder that couldn't
          // be made the error already said why, and the account may.
          if (widget.draft.mayNotMkdir)
            Padding(
              key: const ValueKey('ytdl-choose-sub'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                l.ytdlChooseSub,
                style: TextStyle(
                  color: VelvetColors.textSecondary,
                  fontSize: 13,
                  height: 18 / 13,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _crumbRow(l),
          Flexible(child: body),
          _footer(l),
        ],
      ),
    );
  }

  Widget _header(AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l.ytdlChooseTitle,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 24 / 18,
                      ),
                    ),
                  ),
                  _JustThisSong(label: l.ytdlJustThisSong),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('ytdl-choose-close'),
              tooltip: l.close,
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: VelvetColors.textPrimary),
            ),
          ],
        ),
      );

  /// Where the sheet is: the folders above as links up (the primary's ink),
  /// the one on screen plain. One line, scrolled to its end when long.
  Widget _crumbRow(AppLocalizations l) {
    final ink = keepInk();
    final sep = TextStyle(color: VelvetColors.helper, fontSize: 14);
    final parts = <Widget>[];
    for (var i = 0; i < _crumbs.length; i++) {
      final name = ytdlIsolate(_crumbs[i]);
      if (i > 0) parts.add(Text('›', style: sep));
      final last = i == _crumbs.length - 1;
      parts.add(last
          ? Padding(
              key: const ValueKey('ytdl-choose-here'),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                name,
                style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Semantics(
              container: true,
              button: true,
              label: l.ytdlA11yUpTo(_crumbs[i]),
              onTap: () => _open(_crumbs.sublist(0, i + 1)),
              excludeSemantics: true,
              child: KeepHitArea(
                minHeight: 48,
                onTap: () => _open(_crumbs.sublist(0, i + 1)),
                child: Padding(
                  key: ValueKey('ytdl-choose-up-$i'),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ));
    }
    return Container(
      key: const ValueKey('ytdl-choose-crumbs'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 16),
      child: Semantics(
        label: l.ytdlA11yFolderPath,
        container: true,
        explicitChildNodes: true,
        // As tall as a crumb's hit band wherever the sheet is: the folder
        // on screen alone (at the library) would shrink it to its words.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 18,
                color: VelvetColors.textSecondary,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: SingleChildScrollView(
                  controller: _crumbScroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: parts,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A folder: 56 px, its icon, its name, a chevron in.
  Widget _row(String name) => Semantics(
        container: true,
        button: true,
        label: name,
        onTap: () => _open([..._crumbs, name]),
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('ytdl-choose-folder-$name'),
          onTap: () => _open([..._crumbs, name]),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 12,
                top: 6,
                bottom: 6,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 22,
                    color: VelvetColors.textSecondary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ytdlIsolate(name),
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 15,
                        height: 20 / 15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: VelvetColors.helper,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  /// No folders here, or the listing failed: an icon and the words, and
  /// what to do about it.
  Widget _status({
    required Key key,
    required IconData icon,
    required Color tone,
    required String words,
    Widget? action,
  }) =>
      SingleChildScrollView(
        child: Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: tone),
              const SizedBox(height: 8),
              Text(
                words,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VelvetColors.textSecondary,
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 8), action],
            ],
          ),
        ),
      );

  Widget _footer(AppLocalizations l) {
    final ink = keepInk();
    final listing = _listing;
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
            label: l.cancel,
            onTap: () => Navigator.of(context).pop(),
            excludeSemantics: true,
            child: KeepHitArea(
              minHeight: 48,
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                key: const ValueKey('ytdl-choose-cancel'),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  l.cancel,
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // The folder on screen, once it listed: it is there.
          DestSaveButton(
            label: l.storageUseThisFolder,
            busy: false,
            enabled: listing != null,
            onTap: () => Navigator.of(context).pop(_dirOf(_crumbs)),
            valueKey: const ValueKey('ytdl-choose-use'),
            minHit: 48,
          ),
        ],
      ),
    );
  }
}

/// The outlined "Just this song" tag beside the title: what is picked here
/// is for the song on the card only.
class _JustThisSong extends StatelessWidget {
  final String label;
  const _JustThisSong({required this.label});

  @override
  Widget build(BuildContext context) {
    final ink = keepInk();
    return Container(
      key: const ValueKey('ytdl-choose-just'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: ink),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ink,
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// While a folder lists: three still rows in the folders' shape.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        key: const ValueKey('ytdl-choose-loading'),
        label: AppLocalizations.of(context).ytdlChooseLoading,
        container: true,
        // A short sheet (large text) shows what fits.
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final w in const [120.0, 150.0, 190.0])
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: VelvetColors.raised,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 14),
                      KeepSkeleton(width: w, height: 12),
                    ],
                  ),
                ),
              ),
          ],
          ),
        ),
      );
}
