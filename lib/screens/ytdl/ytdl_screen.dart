import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/server.dart';
import '../../singletons/server_list.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../auto_dj_sheets.dart' show autoDjServerName;
import 'ytdl_action_bar.dart';
import 'ytdl_card_parts.dart';
import 'ytdl_draft.dart';
import 'ytdl_lists.dart';
import 'ytdl_paste_card.dart';
import 'ytdl_result_card.dart';

/// Add from YouTube (spec §3): paste a link, check what the server read,
/// see where it lands, Add. A pushed route like Add torrent, so it covers
/// the home stack and the mini-player; the action bar sits at the bottom
/// and rides on the keyboard.
///
/// The screen shows its server's draft ([YtdlServerState.screenDraft]),
/// kept for the session: leaving mid-lookup or with an unsent card loses
/// nothing. Under the card, ADDING, NEEDS A LOOK and ADDED ([YtdlLists]).
/// Nothing autofocuses; after a 200 the field clears and focus drops, so
/// the keyboard goes down and the new ADDING row shows.
class YtdlScreen extends StatefulWidget {
  final Server server;

  /// Opened from the explorer strip's "Details": scroll to NEEDS A LOOK.
  final bool openNeedsLook;

  const YtdlScreen({
    super.key,
    required this.server,
    this.openNeedsLook = false,
  });

  /// ADDING, NEEDS A LOOK and ADDED under the card, with the anchor the
  /// screen scrolls to — a seam so a test can stand in for the lists.
  @visibleForTesting
  static Widget Function(
    YtdlServerState state,
    GlobalKey needsLookAnchor, {
    required bool showEmpty,
  })
  listsBuilder = _lists;

  static Widget _lists(
    YtdlServerState state,
    GlobalKey anchor, {
    required bool showEmpty,
  }) =>
      YtdlLists(state: state, needsLookAnchor: anchor, showEmpty: showEmpty);

  @visibleForTesting
  static void resetListsBuilder() => listsBuilder = _lists;

  @override
  State<YtdlScreen> createState() => _YtdlScreenState();
}

class _YtdlScreenState extends State<YtdlScreen> {
  late final YtdlServerState _st = YtdlHub().stateFor(widget.server);
  late final YtdlDraft _d = _st.screenDraft;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _savesKey = GlobalKey(debugLabel: 'ytdl-saves');
  final GlobalKey<YtdlFormatChipState> _formatKey = GlobalKey();
  final GlobalKey _needsLook = GlobalKey(debugLabel: 'ytdl-needs-look');

  late bool _revealNeedsLook = widget.openNeedsLook;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _d.attach();
    _st.addListener(_stateMoved);
    // After the first frame: opening marks outcomes seen, which notifies
    // the home card and the explorer strip — still mounted under this
    // route, and in the middle of a build right now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_st.onScreenOpened());
    });
  }

  @override
  void dispose() {
    _st.removeListener(_stateMoved);
    _d.detach();
    _scroll.dispose();
    super.dispose();
  }

  /// A re-ping turned the feature off for this server (conversion off,
  /// uploads off): the screen goes, saying why (spec §8) — its own route,
  /// with whatever is open over it (the format menu, a destination sheet);
  /// popping the top route would close only that.
  void _stateMoved() {
    if (_closing || !mounted || _st.entryAllowed) return;
    final route = ModalRoute.of(context);
    final nav = route?.navigator;
    if (route == null || nav == null || !route.isActive) return;
    _closing = true;
    final why = ytdlEntryOffReason(AppLocalizations.of(context), _st.server);
    if (why != null) YtdlHub().showToast(why);
    nav.popUntil((r) => r == route);
    nav.pop();
  }

  /// "Details" from the strip: NEEDS A LOOK, once, after the first build.
  /// The list builds every child (a column, not a lazy list), so the
  /// header is there however tall the card is; with no header (nothing
  /// needs a look) nothing scrolls, and nothing waits to scroll later.
  void _afterBuild(Duration _) {
    if (!_revealNeedsLook || !mounted) return;
    _revealNeedsLook = false;
    final ctx = _needsLook.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
  }

  Future<void> _add() async {
    final ok = await _d.add();
    if (ok && mounted) FocusScope.of(context).unfocus();
  }

  void _where() => YtdlSheets.where(context, _d);

  void _chooseFolder() => ytdlChooseFolder(context, _d);

  void _changeFormat() => _formatKey.currentState?.open();

  /// "Add from YouTube" over the server's name, only with more than one
  /// server of the user's own.
  Widget _title(AppLocalizations l) {
    final own = ServerManager().serverList.where((s) => !s.isFederated);
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: ios
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(l.ytdlTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (own.length > 1)
          Text(
            autoDjServerName(_st.server),
            key: const ValueKey('ytdl-server-name'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: VelvetColors.appBarTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 16 / 12,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: VelvetColors.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: _title(l)),
      body: ListenableBuilder(
        listenable: _d,
        builder: (context, _) {
          if (_revealNeedsLook) {
            WidgetsBinding.instance.addPostFrameCallback(_afterBuild);
          }
          final card = YtdlResultCard.showsFor(_d);
          final bar = card && _d.lookup != YtdlLookupState.ytdlpMissing;
          final bottom = bar ? 0.0 : MediaQuery.paddingOf(context).bottom;
          return Column(
            children: [
              Expanded(
                // Every child built, not lazily: the NEEDS A LOOK anchor
                // under a tall card, and a focused tag field scrolled far
                // off, both stay in the tree.
                child: SingleChildScrollView(
                  key: const ValueKey('ytdl-list'),
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      YtdlPasteCard(draft: _d, onChange: _where),
                      if (_st.tier == YtdlServerTier.full) ...[
                        const SizedBox(height: 12),
                        YtdlLimitsLine(state: _st),
                      ],
                      if (card) ...[
                        const SizedBox(height: 12),
                        YtdlResultCard(
                          draft: _d,
                          savesKey: _savesKey,
                          onChange: _where,
                          onChooseFolder: _chooseFolder,
                          onChangeFormat: _changeFormat,
                        ),
                      ],
                      // The lists own the empty state (the Empty board),
                      // shown only while no card is up.
                      YtdlScreen.listsBuilder(
                        _st,
                        _needsLook,
                        showEmpty: !card,
                      ),
                    ],
                  ),
                ),
              ),
              if (bar)
                SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      YtdlActionBar(
                        draft: _d,
                        formatKey: _formatKey,
                        onAdd: _add,
                        onChooseFolder: _chooseFolder,
                      ),
                      YtdlDoneBar(draft: _d),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
