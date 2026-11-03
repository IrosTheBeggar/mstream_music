import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/ytdl_hub.dart';
import '../../theme/velvet_theme.dart';
import '../../util/ytdl_link.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_card_parts.dart';
import 'ytdl_crumbs.dart';
import 'ytdl_draft.dart';

/// The paste card (spec §3, the Empty board): the link field with its link
/// icon, hint and clear ✕; what the phone made of the link (a short link
/// rewritten, a scheme added, not YouTube, a playlist); the "Paste from
/// clipboard" chip while the field is empty; and on the screen the
/// "Lands in Music › Artist › Album · MP3 · Change" line.
///
/// Nothing autofocuses: the screen opens with the keyboard down, because
/// the clipboard chip is the main path. The chip asks only whether the
/// clipboard has text, which reads none (no Android toast, no iOS prompt
/// until it is tapped).
class YtdlPasteCard extends StatefulWidget {
  final YtdlDraft draft;

  /// The lands-in line (the screen; the folder sheet's subtitle says where).
  final bool landsIn;

  /// The lands-in line's "Change": "Where new songs land".
  final VoidCallback? onChange;

  const YtdlPasteCard({
    super.key,
    required this.draft,
    this.landsIn = true,
    this.onChange,
  });

  @override
  State<YtdlPasteCard> createState() => _YtdlPasteCardState();
}

class _YtdlPasteCardState extends State<YtdlPasteCard>
    with WidgetsBindingObserver {
  final FocusNode _focus = FocusNode(debugLabel: 'ytdl-link');
  bool _hasClip = false;
  bool _wasEmpty = true;

  YtdlDraft get _d => widget.draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_refresh);
    _d.link.addListener(_linkMoved);
    _wasEmpty = _d.link.text.isEmpty;
    _checkClipboard();
  }

  @override
  void didUpdateWidget(YtdlPasteCard old) {
    super.didUpdateWidget(old);
    if (old.draft != widget.draft) {
      old.draft.link.removeListener(_linkMoved);
      widget.draft.link.addListener(_linkMoved);
      _wasEmpty = widget.draft.link.text.isEmpty;
      _checkClipboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _d.link.removeListener(_linkMoved);
    _focus.dispose();
    super.dispose();
  }

  /// Back in front: something may have been copied meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// The field emptied (✕, a send): the chip may show again.
  void _linkMoved() {
    final empty = _d.link.text.isEmpty;
    if (empty && !_wasEmpty) _checkClipboard();
    _wasEmpty = empty;
  }

  Future<void> _checkClipboard() async {
    if (_d.link.text.isNotEmpty) return;
    final has = await _d.clipboardHasText();
    if (!mounted || has == _hasClip) return;
    setState(() => _hasClip = has);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _d,
      builder: (context, _) {
        final p = _d.parsed;
        final empty = _d.link.text.isEmpty;
        final bad =
            p.kind == YtdlLinkKind.notYoutube ||
            p.kind == YtdlLinkKind.playlist;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VelvetColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(l, bad: bad, empty: empty),
              ..._linkLines(l, p),
              if (empty && _hasClip) ...[
                const SizedBox(height: 6),
                _clipChip(l),
              ],
              if (widget.landsIn) ...[
                const SizedBox(height: 2),
                _landsIn(context, l, showJust: p.kind != YtdlLinkKind.video),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _field(AppLocalizations l, {required bool bad, required bool empty}) {
    final focused = _focus.hasFocus;
    final radius = BorderRadius.circular(7);
    final edge = bad
        ? keepTone(VelvetColors.error)
        : focused
        ? VelvetColors.primary
        : VelvetColors.border;
    return Container(
      height: kYtdlHit,
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: radius,
      ),
      // The edge is drawn over the field, so the 48 px clear button keeps
      // its whole height inside a 48 px field.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: edge, width: focused && !bad ? 1.5 : 1),
      ),
      padding: const EdgeInsetsDirectional.only(start: 12),
      child: Row(
        children: [
          Icon(Icons.link, size: 20, color: VelvetColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: l.ytdlA11yLinkField,
              child: TextField(
                key: const ValueKey('ytdl-link'),
                controller: _d.link,
                focusNode: _focus,
                onChanged: (_) => _d.linkChanged(),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 1,
                style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
                cursorColor: VelvetColors.primary,
                // The field is the box drawn around it: no theme fill or edge.
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l.ytdlPasteHint,
                  hintStyle: TextStyle(
                    color: VelvetColors.helper,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          if (!empty)
            SizedBox.square(
              dimension: kYtdlHit,
              child: IconButton(
                key: const ValueKey('ytdl-clear'),
                tooltip: l.ytdlA11yClearLink,
                onPressed: () {
                  _d.clear();
                  _focus.unfocus();
                },
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: VelvetColors.textSecondary,
                ),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// What the phone made of the link: a refusal in the error tone (icon and
  /// words), or the quiet line naming the link the server gets.
  List<Widget> _linkLines(AppLocalizations l, YtdlLink p) {
    Widget line(Widget child) =>
        Padding(padding: const EdgeInsets.fromLTRB(2, 6, 2, 0), child: child);
    switch (p.kind) {
      case YtdlLinkKind.notYoutube:
      case YtdlLinkKind.playlist:
        final err = keepTone(VelvetColors.error);
        return [
          line(
            YtdlStatusLine(
              key: const ValueKey('ytdl-link-error'),
              icon: Icons.error_outline,
              color: err,
              fontSize: 12,
              text: p.kind == YtdlLinkKind.playlist
                  ? l.ytdlLinkPlaylist
                  : l.ytdlLinkNotYoutube,
            ),
          ),
        ];
      case YtdlLinkKind.video:
        final sent = p.shortForm
            ? l.ytdlLinkShortSent(p.shown)
            : p.schemeAdded
            ? l.ytdlLinkSentAs(p.shown)
            : null;
        return [if (sent != null) line(YtdlHelper(sent))];
      case YtdlLinkKind.empty:
        return const [];
    }
  }

  Widget _clipChip(AppLocalizations l) => Semantics(
    button: true,
    onTap: () => _d.pasteFromClipboard(),
    child: KeepHitArea(
      key: const ValueKey('ytdl-paste'),
      minHeight: kYtdlHit,
      onTap: () => _d.pasteFromClipboard(),
      // 40 px drawn, taller once its words wrap (200% text at 360 dp):
      // a fixed height would cut the second line off.
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 14, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VelvetColors.border2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.content_paste,
              size: 18,
              color: VelvetColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l.ytdlPasteFromClipboard,
                style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// "Lands in Music › Artist › Album · MP3 · Change": the rule new songs
  /// follow, in sample words (the card's SAVES TO names this song's path).
  /// The path is cut at its start when it does not fit (spec §9). A
  /// just-this-song choice made before any link says so here ([showJust]);
  /// once a card shows, its SAVES TO carries the tag.
  Widget _landsIn(
    BuildContext context,
    AppLocalizations l, {
    required bool showJust,
  }) {
    final (before, after) = ytdlAround(l.ytdlLandsIn);
    // The theme's face, so the line measures what it draws.
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        color: VelvetColors.textSecondary,
        fontSize: 13,
        height: 18 / 13,
      ),
    );
    final just = showJust && _d.justThisSong != null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        YtdlCrumbLine(
          crumbs: ytdlSampleCrumbs(l, _d.choice),
          style: style,
          prefix: before,
          suffix: '$after · ${ytdlFormatName(_d.format)} ·',
        ),
        if (just) ...[
          const SizedBox(width: 6),
          YtdlTag(l.ytdlJustThisSong),
          YtdlTextLink(
            l.ytdlUndo,
            key: const ValueKey('ytdl-just-undo'),
            fontSize: 13,
            padding: const EdgeInsetsDirectional.only(start: 8, end: 6),
            onTap: _d.undoJustThisSong,
          ),
        ],
        YtdlTextLink(
          l.discoverKeepChange,
          key: const ValueKey('ytdl-lands-change'),
          fontSize: 13,
          padding: const EdgeInsetsDirectional.only(start: 6, end: 8),
          onTap: widget.onChange,
        ),
      ],
    );
  }
}

/// The limits line under the paste card, on 6.30 and later only (older
/// servers have none of these limits).
class YtdlLimitsLine extends StatelessWidget {
  final YtdlServerState state;
  const YtdlLimitsLine({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.tier != YtdlServerTier.full) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('ytdl-limits'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: YtdlHelper(AppLocalizations.of(context).ytdlLimits),
    );
  }
}
