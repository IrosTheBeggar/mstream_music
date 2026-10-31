// auto_dj_quick_config.dart — Auto DJ's split button and its quick config.
//
// The mini player's and the queue header's Auto DJ button is two buttons in
// one pill: the label starts or stops the DJ as it always has, and the
// chevron opens quick config, a popover with what people reach for while
// music plays — Play from, Sonic similarity (on or off, Drift | Stay close)
// and Smart filters — and the way to the whole Auto DJ screen. It opens away
// from its bar, up from the mini player and down from the queue header, and
// dims everything but that bar. Every change applies at once, through the
// same steps as the Auto DJ screen's sheets.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart';
import 'package:rxdart/rxdart.dart' show MergeStream;

import '../l10n/app_localizations.dart';
import '../media/audio_stuff.dart' show FanOutSitOut, SonicDrop;
import '../objects/mood_filter.dart';
import '../objects/server.dart';
import '../screens/auto_dj.dart' show AutoDJScreen;
import '../screens/auto_dj_sheets.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/log_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/auto_dj_play_from.dart';
import '../util/fan_out_readout.dart';
import '../util/server_tree.dart';
import 'mood_filter_sheet.dart' show MoodChoices, moodLabels;
import 'queue_list.dart' show toggleAutoDJ;

/// Past this many servers, Play from moves to a page of its own.
const kQuickConfigInlineServers = 4;

/// The bar an [AutoDjSplitButton] sits in — the mini player, the queue
/// header. Quick config opens away from it and leaves it undimmed.
class AutoDjAnchorBar extends StatefulWidget {
  const AutoDjAnchorBar({super.key, required this.child});

  final Widget child;

  /// Where the bar around [context] is on screen, or null outside one.
  static Rect? rectOf(BuildContext context) {
    final bar = context.findAncestorStateOfType<_AutoDjAnchorBarState>();
    return bar == null ? null : _globalRect(bar.context);
  }

  @override
  State<AutoDjAnchorBar> createState() => _AutoDjAnchorBarState();
}

class _AutoDjAnchorBarState extends State<AutoDjAnchorBar> {
  @override
  Widget build(BuildContext context) => widget.child;
}

Rect? _globalRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

typedef QuickConfigOpener = Future<void> Function(BuildContext context,
    {required Rect button, required Rect bar, required bool above});

/// The Auto DJ button: its label starts or stops the DJ and is lit while it
/// runs; its chevron opens quick config. One widget for both places it
/// appears — the mini player and the queue header — because they are the
/// same control, and a word reads faster than a glyph nobody has learned.
class AutoDjSplitButton extends StatefulWidget {
  const AutoDjSplitButton(
      {super.key, this.menuAbove = false, this.on, this.onToggle, this.onOpen});

  /// Quick config opens above the bar (the mini player) rather than below it
  /// (the queue header). The chevron points that way, and flips while open.
  final bool menuAbove;

  /// Whether the DJ is on: the audio handler's state unless given.
  final Stream<bool>? on;

  /// [toggleAutoDJ] unless given.
  final VoidCallback? onToggle;

  /// [showAutoDjQuickConfig] unless given.
  final QuickConfigOpener? onOpen;

  @override
  State<AutoDjSplitButton> createState() => _AutoDjSplitButtonState();
}

class _AutoDjSplitButtonState extends State<AutoDjSplitButton> {
  late final Stream<bool> _on = widget.on ??
      MediaManager()
          .audioHandler
          .customState
          .map((s) => s?.autoDJState != null)
          .distinct();
  bool _open = false;

  Future<void> _openQuickConfig() async {
    final button = _globalRect(context);
    if (button == null || _open) return;
    final bar = AutoDjAnchorBar.rectOf(context) ?? button;
    setState(() => _open = true);
    try {
      await (widget.onOpen ?? showAutoDjQuickConfig)(context,
          button: button, bar: bar, above: widget.menuAbove);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<bool>(
      stream: _on,
      builder: (context, snap) {
        final on = snap.data ?? false;
        final ink = on ? VelvetColors.primary : VelvetColors.appBarText;
        // Points where quick config opens; flips while it is open.
        final up = widget.menuAbove != _open;
        return Material(
          color: on ? VelvetColors.primaryDim : Colors.transparent,
          shape: StadiumBorder(
              side: BorderSide(
                  color: on ? VelvetColors.primary : VelvetColors.border2)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 34,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Semantics(
                button: true,
                toggled: on,
                child: InkWell(
                  key: const ValueKey('auto-dj-split-toggle'),
                  onTap: widget.onToggle ?? () => toggleAutoDJ(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                    child: Center(
                      child: Text(l.autoDjTitle,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ink)),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 7),
                color: on
                    ? VelvetColors.primary.withValues(alpha: 0.5)
                    : VelvetColors.border2,
              ),
              Tooltip(
                message: l.autoDjQuickSettings,
                child: Semantics(
                  button: true,
                  expanded: _open,
                  child: InkWell(
                    key: const ValueKey('auto-dj-split-chevron'),
                    onTap: _openQuickConfig,
                    child: Container(
                      width: 38,
                      alignment: Alignment.center,
                      color: _open
                          ? (on
                              ? VelvetColors.primary.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.12))
                          : null,
                      child: Icon(up ? Icons.expand_less : Icons.expand_more,
                          size: 20, color: ink),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Quick config against [button]'s right edge, [above] or below [bar], over
/// everything but the bar. All Auto DJ settings opens the screen where the
/// Auto DJ card does, on the navigator around [context].
Future<void> showAutoDjQuickConfig(BuildContext context,
    {required Rect button, required Rect bar, required bool above}) {
  final navigator = Navigator.of(context);
  final root = Navigator.of(context, rootNavigator: true);
  return root.push(_QuickConfigRoute(
    button: button,
    bar: bar,
    above: above,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    themes: InheritedTheme.capture(from: context, to: root.context),
    openSettings: () => navigator.push(
        MaterialPageRoute<void>(builder: (_) => const AutoDJScreen())),
  ));
}

class _QuickConfigRoute extends PopupRoute<void> {
  _QuickConfigRoute({
    required this.button,
    required this.bar,
    required this.above,
    required this.barrierLabel,
    required this.themes,
    required this.openSettings,
  });

  final Rect button;
  final Rect bar;
  final bool above;
  final CapturedThemes themes;
  final VoidCallback openSettings;

  @override
  final String? barrierLabel;

  // The page paints the scrim itself, with the bar left out of it; the
  // barrier only catches the tap that closes quick config.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      themes.wrap(_QuickConfigLayout(
          button: button,
          bar: bar,
          above: above,
          animation: animation,
          openSettings: openSettings));
}

class _QuickConfigLayout extends StatelessWidget {
  const _QuickConfigLayout({
    required this.button,
    required this.bar,
    required this.above,
    required this.animation,
    required this.openSettings,
  });

  final Rect button;
  final Rect bar;
  final bool above;
  final Animation<double> animation;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final width = math.min(318.0, size.width - 16);
    final right = (size.width - button.right)
        .clamp(8.0, math.max(8.0, size.width - width - 8))
        .toDouble();
    final roomAbove = bar.top - media.padding.top - 16;
    final roomBelow = size.height - bar.bottom - media.padding.bottom - 16;
    // The side asked for, unless only the other has room.
    final up = above
        ? roomAbove >= 280 || roomAbove >= roomBelow
        : !(roomBelow >= 280 || roomBelow >= roomAbove);
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: FadeTransition(
            opacity: fade,
            child: CustomPaint(painter: _ScrimPainter(bar)),
          ),
        ),
      ),
      Positioned(
        right: right,
        width: width,
        top: up ? null : bar.bottom + 8,
        bottom: up ? size.height - bar.top + 8 : null,
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(fade),
            alignment: up ? Alignment.bottomRight : Alignment.topRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: math.max(160.0, up ? roomAbove : roomBelow)),
              child: _LiveQuickConfig(openSettings: openSettings),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Dims the screen around [hole], the bar quick config came from.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRect(hole),
        Paint()..color = Colors.black.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

/// [AutoDjQuickConfig] on the live state: the session, its settings, the
/// servers, their tunnels and flags — rebuilt when any of them moves.
class _LiveQuickConfig extends StatefulWidget {
  const _LiveQuickConfig({required this.openSettings});

  final VoidCallback openSettings;

  @override
  State<_LiveQuickConfig> createState() => _LiveQuickConfigState();
}

class _LiveQuickConfigState extends State<_LiveQuickConfig> {
  final _handler = MediaManager().audioHandler;
  StreamSubscription<Object?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = MergeStream<Object?>([
      _handler.customState,
      AutoDJManager().changeStream,
      ServerManager().serverListStream,
      ServerManager().tunnelTransitions,
      ServerManager().capabilityChanges,
    ]).listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dj = _handler.customState.valueOrNull?.autoDJState as Server?;
    final set = autoDjPlayFromSet();
    return AutoDjQuickConfig(
      // A federated peer counts, but not one hidden or no longer listed.
      servers: serversGrouped(ServerManager().serverList)
          .where((s) => s.isSelectable)
          .toList(),
      chosen: dj == null || set.contains(dj) ? set : [dj, ...set],
      home: dj ?? autoDjPlayFrom(),
      sitOut: _handler.multiServerSitOut,
      // A tunnel server counts as taking part from the moment the session
      // is armed, but it can only answer once its tunnel is up.
      connecting: (s) =>
          dj != null &&
          fanOutConnecting([s], ServerManager().tunnelServes).isNotEmpty,
      sonicDrop: dj != null ? _handler.sonicDrop : null,
      onOpenSettings: () {
        Navigator.of(context).pop();
        widget.openSettings();
      },
    );
  }
}

/// Quick config itself: the main page — Play from, Sonic similarity, Smart
/// filters, and the way to the whole screen — and the Play from and Smart
/// filters pages it opens. What it shows comes in, or from [AutoDJManager];
/// each change goes out through an on… callback, which applies it as the
/// Auto DJ screen's sheets do unless given (a VM test has no audio handler).
class AutoDjQuickConfig extends StatefulWidget {
  const AutoDjQuickConfig({
    super.key,
    required this.servers,
    required this.chosen,
    required this.home,
    required this.sitOut,
    required this.connecting,
    this.sonicDrop,
    this.onPlayFrom,
    this.onSonic,
    this.onMood,
    this.onOpenSettings,
  });

  /// Every server Play from may offer, grouped (a peer under its parent).
  final List<Server> servers;

  /// The servers Play from names now, the DJ's own among them while it runs.
  final List<Server> chosen;

  /// The server the session runs on.
  final Server? home;

  /// Why a server would sit out of a session across several, or null.
  final FanOutSitOut? Function(Server) sitOut;

  /// Whether a server taking part is still on its way.
  final bool Function(Server) connecting;

  /// Why the running session dropped sonic picks, if it did.
  final SonicDrop? sonicDrop;

  final Future<void> Function(List<Server> set)? onPlayFrom;
  final Future<void> Function(
      {required bool on, required SonicAnchorMode anchor})? onSonic;
  final Future<void> Function(MoodFilter mood)? onMood;
  final VoidCallback? onOpenSettings;

  @override
  State<AutoDjQuickConfig> createState() => _AutoDjQuickConfigState();
}

enum _Page { main, servers, mood }

class _AutoDjQuickConfigState extends State<AutoDjQuickConfig> {
  _Page _page = _Page.main;
  late Set<String> _ticked = _names(widget.chosen);
  final _serversScroll = ScrollController();
  StreamSubscription<int>? _mgrSub;

  static Set<String> _names(List<Server> servers) =>
      {for (final s in servers) s.localname};

  @override
  void initState() {
    super.initState();
    _mgrSub = AutoDJManager().changeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AutoDjQuickConfig old) {
    super.didUpdateWidget(old);
    // A change comes back as the new Play from; until it does, the boxes
    // show what was tapped.
    final now = _names(widget.chosen);
    if (!setEquals(now, _names(old.chosen))) _ticked = now;
  }

  @override
  void dispose() {
    _mgrSub?.cancel();
    _serversScroll.dispose();
    super.dispose();
  }

  bool _isTicked(Server s) => _ticked.contains(s.localname);

  /// The servers ticked, in the list's order.
  List<Server> get _set => widget.servers.where(_isTicked).toList();

  bool get _allTicked => widget.servers.every(_isTicked);

  /// The one server left ticked when there has to be one: the server the
  /// session runs on, if the list has it.
  Server get _one => widget.servers.contains(widget.home)
      ? widget.home!
      : widget.servers.first;

  /// Applies a change, logging rather than throwing when saving it fails:
  /// it has taken effect for this run either way.
  void _run(Future<void> Function() change) {
    unawaited(change().catchError((Object e) {
      appLog('[dj] quick config: saving a setting failed: $e');
    }));
  }

  void _applyPlayFrom() {
    final set = _set;
    if (set.isEmpty) return;
    final apply = widget.onPlayFrom ??
        (List<Server> s) =>
            applyPlayFrom(set: s, listed: widget.servers, home: widget.home);
    _run(() => apply(set));
  }

  void _toggle(Server s) {
    setState(() {
      if (!_ticked.remove(s.localname)) _ticked.add(s.localname);
    });
    _applyPlayFrom();
  }

  /// Every server, or — when every one is ticked already — back to [_one].
  void _toggleAll() {
    setState(() {
      if (_allTicked) {
        final keep = _one;
        _ticked
          ..clear()
          ..add(keep.localname);
      } else {
        _ticked.addAll(widget.servers.map((s) => s.localname));
      }
    });
    _applyPlayFrom();
  }

  void _setSonic({required bool on, SonicAnchorMode? anchor}) {
    final mgr = AutoDJManager();
    final apply = widget.onSonic ??
        ({required bool on, required SonicAnchorMode anchor}) => applySonic(
            on: on, match: mgr.sonicMinSimilarity, anchor: anchor);
    _run(() => apply(on: on, anchor: anchor ?? mgr.sonicAnchorMode));
  }

  void _setMood(MoodFilter mood) {
    final apply = widget.onMood ?? AutoDJManager().setMood;
    _run(() => apply(mood));
  }

  void _go(_Page page) => setState(() => _page = page);

  // ── pieces ─────────────────────────────────────────────────────────

  Widget _divider({double indent = 0}) => Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: indent,
      color: VelvetColors.border);

  String _summary(AppLocalizations l) =>
      widget.servers.length > 1 && _allTicked
          ? l.autoDjAllServers
          : l.autoDjServerCount(_set.length);

  Widget _serverRow(AppLocalizations l, Server s, int count) {
    final ticked = _isTicked(s);
    return AutoDjCheckRow(
      key: ValueKey('quick-config-server-${s.localname}'),
      minHeight: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      label: serverLabel(s),
      checked: ticked,
      trailing: playFromStatus(l,
          ticked: ticked,
          count: count,
          why: widget.sitOut(s),
          connecting: widget.connecting(s),
          fontSize: 12.5),
      // The last one ticked stays: the DJ needs a server to play from.
      onTap: ticked && count == 1 ? null : () => _toggle(s),
    );
  }

  Widget _playFromList(AppLocalizations l) {
    final count = _set.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Row(children: [
              Expanded(
                child: Text(l.autoDjPlayFrom.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: VelvetColors.textSecondary)),
              ),
              Text(_summary(l),
                  style: TextStyle(
                      fontSize: 12, color: VelvetColors.textSecondary)),
            ]),
          ),
          for (final s in widget.servers) _serverRow(l, s, count),
        ],
      ),
    );
  }

  Widget _playFromRow(AppLocalizations l) {
    final set = _set;
    final taking = set.where((s) => widget.sitOut(s) == null).length;
    return _NavRow(
      key: const ValueKey('quick-config-play-from'),
      title: l.autoDjPlayFrom,
      value: _allTicked
          ? l.autoDjAllServers
          : set.map(autoDjServerName).join(' · '),
      warning: set.length > 1 && taking < set.length
          ? l.autoDjServersTakingPart(taking, set.length)
          : null,
      onTap: () => _go(_Page.servers),
    );
  }

  Widget _sonic(AppLocalizations l) {
    final mgr = AutoDJManager();
    final blocked = autoDjSonicBlocked(l, widget.home);
    final on = blocked == null && mgr.sonicSimilarityEnabled;
    final drop = on ? widget.sonicDrop : null;
    final value = switch ((blocked, drop)) {
      (final String why, _) => Text(why,
          style:
              TextStyle(fontSize: 12.5, color: VelvetColors.textSecondary)),
      (_, final SonicDrop d) => _warningLine(sonicDropLabel(l, d)),
      _ => Text(
          on
              ? l.autoDjPercent((mgr.sonicMinSimilarity * 100).round())
              : l.commonOff,
          style: TextStyle(
              fontSize: 12.5,
              color: on ? VelvetColors.primary : VelvetColors.textSecondary)),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.autoDjSonicTitle,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: blocked == null
                              ? VelvetColors.textPrimary
                              : VelvetColors.textSecondary)),
                  const SizedBox(height: 2),
                  value,
                ],
              ),
            ),
            Semantics(
              label: l.autoDjSonicTitle,
              child: Switch(
                key: const ValueKey('quick-config-sonic'),
                value: on,
                onChanged: blocked == null ? (v) => _setSonic(on: v) : null,
                activeThumbColor: VelvetColors.primary,
                inactiveThumbColor: VelvetColors.textSecondary,
              ),
            ),
          ]),
          if (on) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SegmentedButton<SonicAnchorMode>(
                key: const ValueKey('quick-config-anchor'),
                segments: [
                  ButtonSegment(
                      value: SonicAnchorMode.rolling,
                      label: Text(l.autoDjDrift)),
                  ButtonSegment(
                      value: SonicAnchorMode.locked,
                      label: Text(l.autoDjStayClose)),
                ],
                selected: {mgr.sonicAnchorMode},
                showSelectedIcon: false,
                onSelectionChanged: (set) =>
                    _setSonic(on: true, anchor: set.first),
                style: autoDjSegmentStyle(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moodRow(AppLocalizations l) {
    final mgr = AutoDJManager();
    final blocked =
        autoDjMoodBlocked(l, home: widget.home, set: widget.chosen);
    final mood = mgr.activeMoodFilter;
    return _NavRow(
      key: const ValueKey('quick-config-mood'),
      title: l.autoDjMoodTitle,
      value: blocked ??
          (mood == null ? l.autoDjAny : moodLabels(l, mood).join(' · ')),
      valueColor: blocked == null && mood != null
          ? VelvetColors.primary
          : VelvetColors.textSecondary,
      onTap: blocked == null ? () => _go(_Page.mood) : null,
    );
  }

  Widget _settingsLink(AppLocalizations l) => InkWell(
        key: const ValueKey('quick-config-settings'),
        onTap: widget.onOpenSettings,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
            child: Row(children: [
              Expanded(
                child: Text(l.autoDjAllSettings,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.primary)),
              ),
              Icon(Icons.arrow_forward, size: 20, color: VelvetColors.primary),
            ]),
          ),
        ),
      );

  Widget _pageHeader(String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Row(children: [
          IconButton(
            key: const ValueKey('quick-config-back'),
            icon: const Icon(Icons.arrow_back, size: 22),
            color: VelvetColors.textPrimary,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => _go(_Page.main),
          ),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary)),
          ),
          ?trailing,
        ]),
      );

  // ── pages ──────────────────────────────────────────────────────────

  Widget _mainPage(AppLocalizations l) {
    final showPlayFrom = widget.servers.length > 1 || widget.chosen.length > 1;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showPlayFrom) ...[
            if (widget.servers.length > kQuickConfigInlineServers)
              _playFromRow(l)
            else
              _playFromList(l),
            _divider(),
          ],
          _sonic(l),
          _divider(),
          _moodRow(l),
          _divider(),
          _settingsLink(l),
        ],
      ),
    );
  }

  Widget _serversPage(AppLocalizations l) {
    final count = _set.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageHeader(l.autoDjPlayFrom,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(_summary(l),
                  style: TextStyle(
                      fontSize: 12, color: VelvetColors.textSecondary)),
            )),
        _divider(),
        AutoDjCheckRow(
          key: const ValueKey('quick-config-all'),
          minHeight: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          label: Text(l.autoDjAllServers,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textPrimary)),
          checked: _allTicked,
          onTap: _toggleAll,
        ),
        _divider(indent: 16),
        // About five and a half rows: the one cut off says there is more.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 44 * 5.5 + 6),
            child: Scrollbar(
              controller: _serversScroll,
              thumbVisibility: true,
              child: ListView(
                controller: _serversScroll,
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 6),
                children: [
                  for (final s in widget.servers) _serverRow(l, s, count),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _moodPage(AppLocalizations l) {
    final mgr = AutoDJManager();
    // Off, it starts at the level last picked.
    final value =
        mgr.activeMoodFilter ?? MoodFilter(level: mgr.moodFilter.level);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageHeader(l.autoDjMoodTitle,
            trailing: TextButton(
              key: const ValueKey('quick-config-mood-clear'),
              onPressed: value == MoodFilter.empty
                  ? null
                  : () => _setMood(MoodFilter.empty),
              style:
                  TextButton.styleFrom(foregroundColor: VelvetColors.primary),
              child: Text(l.clear),
            )),
        _divider(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: MoodChoices(value: value, onChanged: _setMood),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      explicitChildNodes: true,
      label: l.autoDjQuickSettings,
      child: Material(
        color: VelvetColors.raised,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: VelvetColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: switch (_page) {
          _Page.main => _mainPage(l),
          _Page.servers => _serversPage(l),
          _Page.mood => _moodPage(l),
        },
      ),
    );
  }
}

Widget _warningLine(String text) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.warning_amber_rounded, size: 14, color: VelvetColors.warning),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: VelvetColors.warning)),
      ),
    ]);

/// A row that opens one of quick config's pages: its title, what it is set
/// to — and a warning — and a chevron. Off, its reason stands in the value.
class _NavRow extends StatelessWidget {
  const _NavRow({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
    this.warning,
    this.onTap,
  });

  final String title;
  final String value;
  final Color? valueColor;
  final String? warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? VelvetColors.textPrimary
                              : VelvetColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: valueColor ?? VelvetColors.textSecondary)),
                  if (warning case final w?) ...[
                    const SizedBox(height: 2),
                    _warningLine(w),
                  ],
                ],
              ),
            ),
            if (enabled)
              Icon(Icons.chevron_right,
                  size: 22, color: VelvetColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}
