import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/ytdl_errors.dart';
import '../../util/ytdl_layout.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_card_parts.dart';
import 'ytdl_draft.dart';

/// The action bar pinned under the result card (spec §3, §5, §6, §8): the
/// "MP3 ▾" chip with its anchored format menu, and the amber Add button —
/// "Add to library", "Add here" in the explorer sheet while the song goes
/// into the folder on screen, an outlined "Add anyway" over a name clash on
/// 6.30+, "Starting…" while the hub runs the mkdir and the POST, "Try
/// again" after "FFmpeg is not available yet". Above them, the line a
/// refused add or a blocked button reads, always an icon and words.
///
/// It rides on the keyboard (the screen resizes for it), and at large text
/// it stacks: the chip on its own line above a full-width button.
class YtdlActionBar extends StatelessWidget {
  final YtdlDraft draft;

  /// The explorer's folder sheet: "Add here", and a lost library's line
  /// without "Pick another library".
  final bool sheet;

  /// The chip, so a clash panel's "Change format" opens the same menu.
  final GlobalKey<YtdlFormatChipState> formatKey;

  /// Add was tapped (the caller adds, then drops focus or closes).
  final VoidCallback onAdd;

  /// "Choose a folder…" after a folder could not be made.
  final VoidCallback? onChooseFolder;

  const YtdlActionBar({
    super.key,
    required this.draft,
    required this.formatKey,
    required this.onAdd,
    this.sheet = false,
    this.onChooseFolder,
  });

  YtdlDraft get _d => draft;

  /// Text this large stacks the bar (the Narrow360 board's 200% frame).
  static bool stacks(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) > 16 * 1.3;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _d,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final message = _message(context, l);
    final chip = YtdlFormatChip(key: formatKey, draft: _d);
    final button = _d.block == YtdlBlock.convertOff ? null : _button(l);
    final stacked = stacks(context);
    final buttons = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chip,
              if (button != null) ...[
                const SizedBox(height: 6),
                SizedBox(width: double.infinity, child: button),
              ],
            ],
          )
        : Row(
            children: [
              chip,
              if (button != null) ...[
                const SizedBox(width: 10),
                Expanded(child: button),
              ],
            ],
          );
    return ColoredBox(
      color: VelvetColors.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The line sits over the bar, under the list (the ServerStates
          // board), so the bar itself keeps its height.
          if (message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: message,
            ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: VelvetColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: buttons,
          ),
        ],
      ),
    );
  }

  /// "Add to library" and its states.
  Widget _button(AppLocalizations l) {
    final starting = _d.addPhase == YtdlAddPhase.starting;
    final retry = _d.addFailure?.problem == YtdlProblem.ffmpegNotReady;
    final enabled = !starting && _d.block == YtdlBlock.none;
    final here =
        sheet && _d.subLayout == kYtdlLayoutTop && _d.justThisSong == null;
    final label = starting
        ? l.discoverJobStarting
        : retry
        ? l.discoverPageRetry
        : _d.addAnyway
        ? l.ytdlAddAnyway
        : here
        ? l.ytdlAddHere
        : l.ytdlAddToLibrary;
    final outlined = enabled && _d.addAnyway && !retry;
    final Color fill;
    final Color ink;
    if (starting) {
      fill = VelvetColors.raised;
      ink = VelvetColors.textPrimary;
    } else if (!enabled) {
      fill = VelvetColors.raised;
      ink = VelvetColors.helper;
    } else if (outlined) {
      fill = Colors.transparent;
      ink = VelvetColors.textPrimary;
    } else {
      fill = keepFill();
      ink = VelvetColors.onPrimary;
    }
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onAdd : null,
      child: Material(
        key: const ValueKey('ytdl-add'),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: outlined
              ? BorderSide(color: VelvetColors.border2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: enabled ? onAdd : null,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: kYtdlHit),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (starting) ...[
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 16,
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

  /// The line above the buttons: a refused add (the error tone), or why
  /// the button waits ("Already adding to this folder", uploads off). The
  /// card already says the rest (looking up, a clash, a folder the account
  /// can't make, a bad year, the offline banner).
  Widget? _message(BuildContext context, AppLocalizations l) {
    final err = keepTone(VelvetColors.error);
    Widget error(String text, {List<Widget> links = const []}) => Column(
      key: const ValueKey('ytdl-add-error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YtdlStatusLine(icon: Icons.error_outline, color: err, text: text),
        if (links.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: links,
            ),
          ),
      ],
    );
    final f = _d.addFailure;
    if (f != null) {
      switch (f.problem) {
        case YtdlProblem.ffmpegNotReady:
          return error(l.ytdlErrFfmpeg);
        case YtdlProblem.uploadsOff:
          return error(l.ytdlErrUploadsOff);
        case YtdlProblem.libraryGone:
          final name = ytdlGoneLibrary(f, _d.target.directory);
          return error(
            sheet
                ? l.ytdlErrLibraryGoneSheet(name)
                : l.ytdlErrLibraryGone(name),
          );
        case YtdlProblem.noRoute:
          return error(l.ytdlErrNoRoute);
        case YtdlProblem.badFormat:
          return _formatOff(l, err);
        case YtdlProblem.badRequest:
          return error(l.ytdlErrBadRequest);
        case YtdlProblem.mkdirFailed:
          return error(
            l.ytdlErrMkdir(f.detail ?? ''),
            links: [
              YtdlOutlinedPill(
                l.discoverPageRetry,
                key: const ValueKey('ytdl-mkdir-retry'),
                onTap: onAdd,
              ),
              YtdlTextLink(
                l.ytdlChooseFolderLink,
                key: const ValueKey('ytdl-mkdir-choose'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onTap: onChooseFolder,
              ),
            ],
          );
        case YtdlProblem.mkdirOff:
          // The noMkdir panel on the card offers the ways on.
          break;
        case YtdlProblem.ytdlpMissing:
          return error(l.ytdlYtdlpMissing);
        case YtdlProblem.offline:
          return error(l.ytdlErrAddOffline);
        case YtdlProblem.serverError:
        case YtdlProblem.lookupFailed:
        case YtdlProblem.timedOut:
          return error(l.ytdlErrServer);
        case YtdlProblem.other:
          final words = ytdlServerWords(f);
          return error(words == null ? l.ytdlErrServer : l.ytdlErrOther(words));
      }
    }
    switch (_d.block) {
      case YtdlBlock.alreadyAdding:
        return YtdlStatusLine(
          key: const ValueKey('ytdl-already-adding'),
          icon: Icons.info_outline,
          color: VelvetColors.textSecondary,
          text: l.ytdlAlreadyAdding,
        );
      case YtdlBlock.uploadsOff:
        return error(l.ytdlErrUploadsOff);
      default:
        return null;
    }
  }

  /// "This server doesn't save Opus any more · pick another" — the link
  /// opens the format menu (the remembered format has reset).
  Widget _formatOff(AppLocalizations l, Color err) => Row(
    key: const ValueKey('ytdl-add-error'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(Icons.error_outline, size: 16, color: err),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${l.ytdlErrFormatOff(ytdlFormatName(_d.failedCodec ?? ''))} · ',
                style: TextStyle(color: err, fontSize: 13, height: 18 / 13),
              ),
              YtdlTextLink(
                l.ytdlErrPickAnother,
                key: const ValueKey('ytdl-pick-another'),
                fontSize: 13,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onTap: () => formatKey.currentState?.open(),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// The format chip ("MP3 ▾", read "Format, MP3"): opens the anchored menu
/// and remembers the pick for the server. Highlighted while its menu is up.
/// [YtdlFormatChipState.open] lets a clash panel's "Change format" open it.
class YtdlFormatChip extends StatefulWidget {
  final YtdlDraft draft;
  const YtdlFormatChip({super.key, required this.draft});

  @override
  State<YtdlFormatChip> createState() => YtdlFormatChipState();
}

class YtdlFormatChipState extends State<YtdlFormatChip> {
  bool _open = false;

  Future<void> open() async {
    if (_open) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final d = widget.draft;
    setState(() => _open = true);
    // The face sits centred in its 48 px band: lift exactly that.
    final face = Size(box.size.width, 44);
    final origin = box.localToGlobal(Offset(0, (box.size.height - 44) / 2));
    final picked = await showYtdlFormatMenu(
      context,
      anchor: origin & face,
      formats: d.formats,
      chosen: d.format,
      server: d.owner.server.displayName,
      anchorFace: chipFace(ytdlFormatName(d.format), open: true),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null && picked != d.format) await d.setFormat(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = ytdlFormatName(widget.draft.format);
    return Semantics(
      button: true,
      label: l.ytdlA11yFormat(name),
      excludeSemantics: true,
      onTap: open,
      child: KeepHitArea(
        key: const ValueKey('ytdl-format'),
        minHeight: kYtdlHit,
        onTap: open,
        child: chipFace(name, open: _open),
      ),
    );
  }

  /// The chip as drawn: 44 px, radius 22; while its menu is up, a 1.5 px
  /// primary edge on a primary-dim fill (drawn again over the menu's scrim).
  static Widget chipFace(String name, {required bool open}) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
    decoration: BoxDecoration(
      color: open
          ? Color.alphaBlend(VelvetColors.primaryDim, VelvetColors.bg)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: open ? VelvetColors.primary : VelvetColors.border2,
        width: open ? 1.5 : 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            color: VelvetColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_drop_down, size: 20, color: VelvetColors.textPrimary),
      ],
    ),
  );
}

/// The format menu (spec §5, the FormatMenu board), anchored above
/// [anchor] (a global rect; below it when there is more room there), 300
/// px wide: "Best audio the video has, saved as", one 56 px row per format
/// the server has on — its name, its helper, a tick on [chosen] — and
/// "Remembered for {server}". Works over a sheet too. [anchorFace] is
/// drawn over the scrim at [anchor] (the chip, lit while its menu is up).
/// Returns the pick, or null when dismissed.
Future<String?> showYtdlFormatMenu(
  BuildContext context, {
  required Rect anchor,
  required List<String> formats,
  required String chosen,
  required String server,
  Widget? anchorFace,
}) {
  final nav = Navigator.of(context, rootNavigator: true);
  final overlay = nav.overlay?.context.findRenderObject();
  // The rect in the root overlay's own space (it fills the screen).
  final local = overlay is RenderBox
      ? overlay.globalToLocal(anchor.topLeft) & anchor.size
      : anchor;
  return nav.push(
    _YtdlMenuRoute(
      anchor: local,
      anchorFace: anchorFace,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      menu: _YtdlFormatMenu(formats: formats, chosen: chosen, server: server),
    ),
  );
}

class _YtdlMenuRoute extends PopupRoute<String> {
  final Rect anchor;
  final Widget menu;
  final Widget? anchorFace;

  @override
  final String? barrierLabel;

  _YtdlMenuRoute({
    required this.anchor,
    required this.menu,
    required this.barrierLabel,
    this.anchorFace,
  });

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.4);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final face = anchorFace;
    return Stack(
      children: [
        if (face != null)
          Positioned(
            left: anchor.left,
            top: anchor.top,
            height: anchor.height,
            // Drawn only: a tap there falls through to the scrim and closes.
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Material(
                  type: MaterialType.transparency,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: face,
                  ),
                ),
              ),
            ),
          ),
        CustomSingleChildLayout(
          delegate: _MenuLayout(
            anchor: anchor,
            padding: media.padding,
            insets: media.viewInsets,
          ),
          child: menu,
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

/// Above the anchor with 8 px between, unless there is more room below;
/// at most 300 px wide, kept 16 px inside the screen's sides, as tall as
/// the room allows (the menu scrolls past that).
class _MenuLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final EdgeInsets padding;
  final EdgeInsets insets;
  _MenuLayout({
    required this.anchor,
    required this.padding,
    required this.insets,
  });

  static const double _gap = 8;
  static const double _side = 16;

  double _above() => anchor.top - padding.top - _gap * 2;
  double _below(Size size) =>
      size.height - insets.bottom - padding.bottom - anchor.bottom - _gap * 2;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final room = math.max(_above(), _below(size));
    return BoxConstraints(
      maxWidth: math.min(300, size.width - _side * 2),
      maxHeight: math.max(0, room),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = anchor.left.clamp(
      _side,
      math.max(_side, size.width - child.width - _side),
    );
    final up = _above() >= _below(size) || _above() >= child.height;
    final y = up ? anchor.top - _gap - child.height : anchor.bottom + _gap;
    return Offset(x.toDouble(), y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor || old.padding != padding || old.insets != insets;
}

class _YtdlFormatMenu extends StatelessWidget {
  final List<String> formats;
  final String chosen;
  final String server;
  const _YtdlFormatMenu({
    required this.formats,
    required this.chosen,
    required this.server,
  });

  static String? _help(AppLocalizations l, String codec) => switch (codec) {
    'mp3' => l.ytdlFormatMp3Help,
    'm4a' => l.ytdlFormatM4aHelp,
    'opus' => l.ytdlFormatOpusHelp,
    'flac' => l.ytdlFormatFlacHelp,
    'wav' => l.ytdlFormatWavHelp,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final radius = BorderRadius.circular(12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        key: const ValueKey('ytdl-format-menu'),
        color: VelvetColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: VelvetColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Text(
                  l.ytdlFormatMenuTitle,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
              ),
              for (final codec in formats) _item(context, l, codec),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 6),
                color: VelvetColors.border,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: YtdlHelper(l.ytdlFormatRemembered(server)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, AppLocalizations l, String codec) {
    final on = codec == chosen;
    final help = _help(l, codec);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      button: true,
      child: InkWell(
        key: ValueKey('ytdl-format-$codec'),
        onTap: () => Navigator.of(context).pop(codec),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ytdlFormatName(codec),
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 20 / 15,
                      ),
                    ),
                    if (help != null)
                      Text(
                        help,
                        style: TextStyle(
                          color: VelvetColors.textSecondary,
                          fontSize: 13,
                          height: 18 / 13,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 20,
                child: on
                    ? Icon(Icons.check, size: 20, color: keepInk())
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The number pad's missing return key on iPhone (spec §9): a "Done" bar
/// over the keyboard while the Year field has focus.
class YtdlDoneBar extends StatelessWidget {
  final YtdlDraft draft;
  const YtdlDoneBar({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final year = draft.focusFor(YtdlField.year);
    return ListenableBuilder(
      listenable: year,
      builder: (context, _) {
        if (defaultTargetPlatform != TargetPlatform.iOS || !year.hasFocus) {
          return const SizedBox.shrink();
        }
        final l = AppLocalizations.of(context);
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: VelvetColors.card,
            border: Border(top: BorderSide(color: VelvetColors.border)),
          ),
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: const ValueKey('ytdl-ios-done'),
            onPressed: year.unfocus,
            child: Text(
              l.done,
              style: TextStyle(
                color: keepInk(),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
