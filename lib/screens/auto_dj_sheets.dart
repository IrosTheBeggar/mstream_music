// The Auto DJ screen's sheets, one per row, in one chrome: the handle; the
// title with its value beside it (amber while it shapes the picks) and any
// switch; close; then Clear and Done. Done applies, and closing the sheet any
// other way changes nothing. First song is the exception: a tap applies it.
//
// The Mood row opens the browse lists' own mood sheet (mood_filter_sheet.dart),
// which already has this shape.

import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoLocalizations,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData,
        CupertinoTimerPicker,
        CupertinoTimerPickerMode,
        DefaultCupertinoLocalizations;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../media/audio_stuff.dart'
    show AudioPlayerHandler, FanOutSitOut, SonicDrop;
import '../objects/genre_source.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/log_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/auto_dj_play_from.dart';
import '../util/auto_dj_values.dart';
import '../util/server_tree.dart';
import '../util/server_version.dart';
import '../widgets/federation_widgets.dart';
import '../widgets/star_rating.dart';

Future<T?> showAutoDjSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: builder,
    );

/// Apply a sheet's choice, then close it — closed even when saving fails: the
/// choice has already taken effect for this run, and a sheet left open would
/// say nothing. The failure goes to the log.
Future<void> _applyThenClose(
    BuildContext context, Future<void> Function() apply) async {
  // This sheet's own route, popped once: a second Done tap, or a close,
  // during the save must not pop the screen underneath.
  final route = ModalRoute.of(context);
  try {
    await apply();
  } catch (e) {
    appLog('[dj] saving an Auto DJ setting failed: $e');
  } finally {
    if (context.mounted && route != null && route.isCurrent) {
      Navigator.of(context).pop();
    }
  }
}

/// How a value reads: [neutral] for Any, Off or a session setting, [active]
/// while it shapes the picks, [warning] when something is wrong.
enum AutoDjTone { neutral, active, warning }

Color autoDjToneColor(AutoDjTone tone) => switch (tone) {
      AutoDjTone.neutral => VelvetColors.textSecondary,
      AutoDjTone.active => VelvetColors.primary,
      AutoDjTone.warning => VelvetColors.warning,
    };

/// Why a server sits out of a session across several, in at most four words.
String sitOutLabel(AppLocalizations l, FanOutSitOut why) => switch (why) {
      FanOutSitOut.discoveryOff => l.autoDjDiscoveryOff,
      FanOutSitOut.scanning => l.autoDjStillScanning,
      FanOutSitOut.olderServer =>
        l.autoDjNeedsServer(paramFloorLabel(ServerParam.similarToVector)),
      FanOutSitOut.noMood => l.autoDjNoMoodData,
      FanOutSitOut.otherModel => l.autoDjOtherModel,
      FanOutSitOut.unreachable => l.autoDjUnreachable,
    };

/// Why sonic similarity can't run from [home], or null when it can: the
/// server predates it, its scan has not produced vectors yet (mStream #879),
/// or discovery is off there. The Auto DJ screen's row and quick config.
String? autoDjSonicBlocked(AppLocalizations l, Server? home) {
  if (sonicKnownUnsupported(ServerVersion.tryParse(home?.serverVersion))) {
    return l.autoDjNeedsServer(paramFloorLabel(ServerParam.similarTo));
  }
  if (home?.discoveryOn == true && home?.discoveryReady == false) {
    return l.autoDjStillScanning;
  }
  return home?.sonicUsable == true ? null : l.autoDjDiscoveryOff;
}

/// Why a running session had to drop sonic similarity.
String sonicDropLabel(AppLocalizations l, SonicDrop drop) => switch (drop) {
      SonicDrop.tooStrict => l.autoDjTooStrict,
      SonicDrop.scanning => l.autoDjStillScanning,
      SonicDrop.discoveryOff => l.autoDjDiscoveryOff,
    };

/// Why a mood can't narrow the picks of a session on [set] run from [home],
/// or null when it can. A peer's flags can't be read, so its mood flag is
/// pinned off; with several servers the mood holds where one taking part
/// can filter by it.
String? autoDjMoodBlocked(AppLocalizations l,
    {required Server? home, required List<Server> set}) {
  final several = set.length > 1;
  if (!several && home?.isFederated == true) return l.autoDjNotOnPeers;
  final can = several
      ? set.any((s) => s.moodFiltersAvailable == true)
      : home?.moodFiltersAvailable == true;
  return can ? null : l.autoDjNoMoodData;
}

/// A server's name without the scheme: "music.home.arpa", "laptop.local:3000".
/// A peer's is already a name.
String autoDjServerName(Server s) => s.isFederated
    ? s.displayName
    : s.displayName
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');

/// A server's name in a list: a peer hangs off its parent, which
/// [serversGrouped] places right above it.
Widget serverLabel(Server s, {TextStyle? style}) {
  final base = style ??
      TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: VelvetColors.textPrimary);
  return Text.rich(
    TextSpan(children: [
      if (s.isFederated)
        TextSpan(
            text: '$kPeerBranch ',
            style: base.copyWith(color: VelvetColors.textTertiary)),
      TextSpan(text: autoDjServerName(s)),
    ]),
    style: base,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

// ── chrome ─────────────────────────────────────────────────────────────

Widget _handle() => Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: VelvetColors.border2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

class _TitleRow extends StatelessWidget {
  const _TitleRow(
      {required this.title, this.value, this.tone = AutoDjTone.active, this.toggle});

  final String title;
  final String? value;
  final AutoDjTone tone;
  final Widget? toggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: SizedBox(
        height: 52,
        child: Row(children: [
          Expanded(
            // The title gives way first; the value (55%, ± 8 BPM, 2:00–6:00)
            // is cut short only once it alone fills the row — an hour-long
            // length at a large text size.
            child: LayoutBuilder(
              builder: (context, box) => Row(children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: VelvetColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: (box.maxWidth - 8).clamp(0, double.infinity)),
                    child: Text(value!,
                        key: const ValueKey('auto-dj-sheet-value'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: autoDjToneColor(tone),
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
          ),
          if (toggle != null) ...[toggle!, const SizedBox(width: 4)],
          IconButton(
            icon: Icon(Icons.close, color: VelvetColors.textSecondary),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onDone, this.clearable = false, this.onClear});

  final VoidCallback onDone;
  final bool clearable;

  /// Null draws Clear off: there is nothing to clear.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        if (clearable) ...[
          Expanded(
            child: FedButton(l.clear,
                key: const ValueKey('auto-dj-sheet-clear'),
                kind: FedButtonKind.muted,
                height: 44,
                onPressed: onClear),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 2,
          child: FedButton(l.done,
              key: const ValueKey('auto-dj-sheet-done'),
              height: 44,
              onPressed: onDone),
        ),
      ]),
    );
  }
}

/// The chrome around a sheet whose content fits without a list of its own.
/// No [onDone] draws no buttons: a tap in the content applies.
class AutoDjSheet extends StatelessWidget {
  const AutoDjSheet({
    super.key,
    required this.title,
    this.value,
    this.tone = AutoDjTone.active,
    this.toggle,
    required this.child,
    this.onDone,
    this.clearable = false,
    this.onClear,
  });

  final String title;
  final String? value;
  final AutoDjTone tone;
  final Widget? toggle;
  final Widget child;
  final VoidCallback? onDone;
  final bool clearable;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            _TitleRow(title: title, value: value, tone: tone, toggle: toggle),
            // The content scrolls when the screen is short (a phone on its
            // side); the title and the buttons stay.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: child,
              ),
            ),
            if (onDone != null)
              _BottomBar(onDone: onDone!, clearable: clearable, onClear: onClear)
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// A switch for a sheet's title row, named for screen readers.
Widget _titleSwitch(String label, bool value, ValueChanged<bool> onChanged,
        {Key? key}) =>
    Semantics(
      label: label,
      child: Switch(
        key: key,
        value: value,
        onChanged: onChanged,
        activeThumbColor: VelvetColors.primary,
        inactiveThumbColor: VelvetColors.textSecondary,
      ),
    );

Widget _slider({
  required double value,
  required double min,
  required double max,
  required int divisions,
  required String label,
  required String Function(double) spoken,
  ValueChanged<double>? onChanged,
  Key? key,
}) =>
    Builder(
      builder: (context) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: VelvetColors.primary,
          inactiveTrackColor: VelvetColors.border,
          thumbColor: VelvetColors.primary,
          overlayColor: VelvetColors.primaryDim,
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
        ),
        child: MergeSemantics(
          child: Semantics(
            label: label,
            child: Slider(
              key: key,
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              // What the title row shows, not the slider's raw percentage.
              semanticFormatterCallback: spoken,
            ),
          ),
        ),
      ),
    );

/// The mood sheet's segment look: the chosen one amber with black ink.
ButtonStyle autoDjSegmentStyle() => SegmentedButton.styleFrom(
      selectedBackgroundColor: VelvetColors.primary,
      selectedForegroundColor: VelvetColors.onPrimary,
      foregroundColor: VelvetColors.textPrimary,
      side: BorderSide(color: VelvetColors.border2),
      textStyle: const TextStyle(fontSize: 14),
    );

/// A row of servers to choose whose setting a sheet edits (All servers
/// only). A dot marks one that has something set.
class _ServerChips extends StatelessWidget {
  const _ServerChips(
      {required this.servers,
      required this.selected,
      required this.isSet,
      required this.onSelected});

  final List<Server> servers;
  final Server selected;
  final bool Function(Server) isSet;
  final ValueChanged<Server> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 8, children: [
        for (final s in servers)
          _ServerChip(
            server: s,
            selected: s == selected,
            isSet: isSet(s),
            onTap: () => onSelected(s),
          ),
      ]),
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip(
      {required this.server,
      required this.selected,
      required this.isSet,
      required this.onTap});

  final Server server;
  final bool selected;
  final bool isSet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? VelvetColors.primary : VelvetColors.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('auto-dj-server-chip-${server.localname}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        // 44 px to touch, 36 px drawn.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? VelvetColors.primaryDim : null,
              border: Border.all(
                  color: selected ? VelvetColors.primary : VelvetColors.border2,
                  width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(autoDjServerName(server),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              ),
              if (isSet) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: VelvetColors.primary, shape: BoxShape.circle),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// A sheet's text field: filled a step lighter than the sheet, no outline
/// until it has focus.
InputDecoration _fieldDecoration({String? hint, Widget? prefix}) {
  final shape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefix,
    isDense: true,
    filled: true,
    fillColor: VelvetColors.raised,
    border: shape,
    enabledBorder: shape,
    disabledBorder: shape,
    focusedBorder: shape.copyWith(
        borderSide: BorderSide(color: VelvetColors.primary, width: 1.5)),
  );
}

/// A section header inside a sheet: sentence case, over a card.
Widget _sheetHeader(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: VelvetColors.textSecondary)),
    );

Widget _check() => Icon(Icons.check, size: 22, color: VelvetColors.primary);

Widget _spinner(double size) => SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
          strokeWidth: 2, color: VelvetColors.primary),
    );

Widget _warning(String reason, {double fontSize = 15}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.warning_amber_rounded,
          size: fontSize + 1, color: VelvetColors.warning),
      const SizedBox(width: 6),
      Flexible(
        child: Text(reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, color: VelvetColors.warning)),
      ),
    ]);

/// A disabled choice's reason, at the right of its row.
Widget _reason(String reason, {double fontSize = 15}) => Text(reason,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: fontSize, color: VelvetColors.textSecondary));

/// A server's part in a session across [count] servers, at the right of its
/// Play from row: nothing while it takes part, a spinner while it is on its
/// way, else [why] it sits out — amber when it is [ticked], plain when it
/// would sit out if it were. A server ticked alone says nothing: on its own
/// it needs none of this.
Widget? playFromStatus(AppLocalizations l,
    {required bool ticked,
    required int count,
    required FanOutSitOut? why,
    required bool connecting,
    double fontSize = 15}) {
  if (ticked && count < 2) return null;
  if (why != null) {
    return ticked
        ? _warning(sitOutLabel(l, why), fontSize: fontSize)
        : _reason(sitOutLabel(l, why), fontSize: fontSize);
  }
  if (ticked && connecting) return _spinner(16);
  return null;
}

/// A 52 px choice in a sheet's list: a name and, at the right, the check,
/// a status or a reason.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow(
      {super.key,
      required this.label,
      this.trailing,
      this.selected = false,
      this.onTap});

  final Widget label;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
            // The name keeps at least 40% of the row; a long reason gives way.
            child: LayoutBuilder(
              builder: (context, box) => Row(children: [
                Expanded(child: label),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
                    child: trailing!,
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row in a checklist: the box, a name and, at the right, a status or a
/// reason — 52 px in a sheet, [minHeight] where space is tighter (quick
/// config).
class AutoDjCheckRow extends StatelessWidget {
  const AutoDjCheckRow(
      {super.key,
      required this.label,
      required this.checked,
      this.trailing,
      this.onTap,
      this.minHeight = 52,
      this.padding = const EdgeInsets.fromLTRB(14, 0, 12, 0)});

  final Widget label;
  final bool checked;
  final Widget? trailing;

  /// Null holds the box as it is, drawn faint.
  final VoidCallback? onTap;

  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: padding,
              // The name keeps at least 40% of the row; a long reason gives
              // way.
              child: LayoutBuilder(
                builder: (context, box) => Row(children: [
                  Opacity(
                    opacity: onTap == null ? 0.5 : 1,
                    // FedCheckRow's box.
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: checked
                            ? VelvetColors.primary
                            : Colors.transparent,
                        border: checked
                            ? null
                            : Border.all(color: VelvetColors.textDim, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: checked
                          ? Icon(Icons.check,
                              size: 16, color: VelvetColors.onPrimary)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: label),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
                      child: trailing!,
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Play from ──────────────────────────────────────────────────────────

/// Play from becomes [set] — servers out of [listed], the ones on offer, in
/// their order — run from [home] while that can lead: the Play from sheet's
/// Done, and each tick in quick config.
Future<void> applyPlayFrom(
    {required List<Server> set,
    required List<Server> listed,
    required Server? home}) async {
  if (set.isEmpty) return;
  final mgr = AutoDJManager();
  final handler = MediaManager().audioHandler;
  // The session runs on one of them: the server it is on now while that can
  // lead the others, else one that can.
  final next =
      resolvePlayFromHome(set, home, (s) => fanOutHomeBlocked(s) == null)!;
  final names = {for (final s in listed) s.localname};
  await mgr.setPlayFrom(
      // Ticking every server is All servers, which takes in the ones added
      // later. With one server there is no list, and nothing to change.
      all: listed.length > 1 ? listed.every(set.contains) : mgr.playFromAll,
      servers: [
        ...set.map((s) => s.localname),
        // One the list can't show — a peer hidden, or missing from its
        // parent's list for now — keeps its place, to take part once back.
        for (final n in mgr.playFromServers)
          if (!names.contains(n)) n,
      ],
      home: next.localname);
  if (set.length > 1) {
    // The session's seed travels as a sound, so several servers run on
    // sonic picks — and a session that had dropped them gets another go.
    if (!mgr.sonicSimilarityEnabled) await mgr.setSonicSimilarityEnabled(true);
    if (handler.sonicDrop != null) {
      unawaited(handler.customAction('retrySonic'));
    }
  }
  // A session running somewhere else starts afresh on the home. One that is
  // already there carries on, asking whichever servers are ticked now.
  final dj = handler.autoDJServer;
  if (dj != null && dj != next) {
    unawaited(handler.customAction('setAutoDJ', {'autoDJServer': next}));
  }
}

/// Where the music comes from: any set of servers — one is a plain session
/// on it, several fan every pick out across them — and, under the list, the
/// folders of each one ticked.
class PlayFromSheet extends StatefulWidget {
  const PlayFromSheet(
      {super.key,
      required this.servers,
      required this.chosen,
      required this.home,
      required this.sitOut,
      required this.connecting,
      this.changes});

  /// Every server the picker may offer, grouped (a peer under its parent).
  final List<Server> servers;

  /// The servers Play from names now.
  final List<Server> chosen;

  /// The server the session runs on: the DJ's while it is on.
  final Server? home;

  /// Why a server would sit out of a session across several, or null when
  /// it would take part — the running session's own drops included. A
  /// server not reached yet has no reason: nothing is known against it.
  final FanOutSitOut? Function(Server) sitOut;

  /// Whether a server taking part is still on its way: the session is on
  /// and the server's tunnel is not up yet.
  final bool Function(Server) connecting;

  /// Fires when what [sitOut] or [connecting] says may have changed — a
  /// tunnel coming up or dropping, a server's flags arriving — so the rows
  /// follow while the sheet is open.
  final Stream<Object?>? changes;

  @override
  State<PlayFromSheet> createState() => _PlayFromSheetState();
}

class _PlayFromSheetState extends State<PlayFromSheet> {
  late final Set<String> _ticked = {
    for (final s in widget.chosen) s.localname,
    // Never none in the list: the DJ needs a server to play from.
    if (!widget.servers.any(widget.chosen.contains) &&
        widget.servers.isNotEmpty)
      _one.localname,
  };
  late final Map<String, Map<String, bool>> _paths = {
    for (final s in {...widget.servers, ...widget.chosen, ?widget.home})
      s.localname: Map.of(s.autoDJPaths),
  };
  StreamSubscription<Object?>? _changesSub;

  @override
  void initState() {
    super.initState();
    _changesSub = widget.changes?.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    super.dispose();
  }

  AudioPlayerHandler get _handler => MediaManager().audioHandler;

  bool _isTicked(Server s) => _ticked.contains(s.localname);

  /// The servers ticked, in the list's order.
  List<Server> get _set => widget.servers.where(_isTicked).toList();

  bool get _allTicked => widget.servers.every(_isTicked);

  /// The one server left ticked when there has to be one: the server the
  /// session runs on, if the list has it.
  Server get _one => widget.servers.contains(widget.home)
      ? widget.home!
      : widget.servers.first;

  void _toggle(Server s) => setState(() {
        if (!_ticked.remove(s.localname)) _ticked.add(s.localname);
      });

  /// Every server, or — when every one is ticked already — back to [_one].
  void _toggleAll() => setState(() {
        if (_allTicked) {
          final keep = _one;
          _ticked
            ..clear()
            ..add(keep.localname);
        } else {
          _ticked.addAll(widget.servers.map((s) => s.localname));
        }
      });

  Widget? _status(AppLocalizations l, Server s, int count) => playFromStatus(l,
      ticked: _isTicked(s),
      count: count,
      why: widget.sitOut(s),
      connecting: widget.connecting(s));

  List<Server> get _folderServers => [
        for (final s in _set)
          if (s.autoDJPaths.length > 1) s,
      ];

  Widget _folders(Server s) {
    final draft = _paths[s.localname]!;
    final on = draft.values.where((v) => v).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sheetHeader(autoDjServerName(s)),
      FedCard(children: [
        for (final e in draft.entries)
          FedSwitchRow(
            key: ValueKey('auto-dj-folder-${s.localname}-${e.key}'),
            title: e.key,
            value: e.value,
            // The last folder still on can't go: the server would have
            // nothing to draw from.
            onChanged: e.value && on == 1
                ? null
                : (v) => setState(() => draft[e.key] = v),
          ),
      ]),
    ]);
  }

  Future<void> _done() => _applyThenClose(context, () async {
    var pathsChanged = false;
    for (final s in {...widget.servers, ...widget.chosen, ?widget.home}) {
      final draft = _paths[s.localname]!;
      final same = draft.length == s.autoDJPaths.length &&
          draft.entries.every((e) => s.autoDJPaths[e.key] == e.value);
      if (!same) {
        s.autoDJPaths = Map.of(draft);
        pathsChanged = true;
      }
    }
    if (pathsChanged) {
      ServerManager().callAfterEditServer();
      unawaited(_handler.customAction('forceAutoDJRefresh'));
    }
    await applyPlayFrom(set: _set, listed: widget.servers, home: widget.home);
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final servers = widget.servers;
    final count = _set.length;
    return AutoDjSheet(
      title: l.autoDjPlayFrom,
      onDone: _done,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (servers.length > 1)
          FedCard(children: [
            AutoDjCheckRow(
              key: const ValueKey('auto-dj-play-from-all'),
              label: Text(l.autoDjAllServers,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: VelvetColors.textPrimary)),
              checked: _allTicked,
              onTap: _toggleAll,
            ),
            for (final s in servers)
              AutoDjCheckRow(
                key: ValueKey('auto-dj-play-from-${s.localname}'),
                label: serverLabel(s),
                checked: _isTicked(s),
                trailing: _status(l, s, count),
                // The last one ticked stays: the DJ needs a server to play
                // from.
                onTap: _isTicked(s) && count == 1 ? null : () => _toggle(s),
              ),
          ]),
        for (final s in _folderServers) _folders(s),
      ]),
    );
  }
}

// ── First song ─────────────────────────────────────────────────────────

/// What Start does with nothing queued. A tap applies it.
class FirstSongSheet extends StatelessWidget {
  const FirstSongSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mgr = AutoDJManager();
    Widget row(EmptyQueueStart v, IconData icon, String label) => Semantics(
          selected: mgr.emptyQueueStart == v,
          child: FedRow(
            key: ValueKey('auto-dj-first-song-${v.name}'),
            icon: icon,
            title: label,
            trailing: mgr.emptyQueueStart == v ? _check() : null,
            onTap: () =>
                _applyThenClose(context, () => mgr.setEmptyQueueStart(v)),
          ),
        );
    return AutoDjSheet(
      title: l.autoDjFirstSong,
      child: FedCard(children: [
        row(EmptyQueueStart.ask, Icons.help_outline, l.autoDjStartAskShort),
        row(EmptyQueueStart.random, Icons.casino, l.autoDjFirstSongRandom),
        row(EmptyQueueStart.pick, Icons.library_music_outlined,
            l.autoDjFirstSongChoose),
        row(EmptyQueueStart.recent, Icons.history, l.autoDjRecentlyPlayed),
      ]),
    );
  }
}

// ── Sonic similarity ───────────────────────────────────────────────────

/// Sonic similarity's settings: the sheet's Done, and quick config's switch
/// and Drift | Stay close.
Future<void> applySonic(
    {required bool on,
    required double match,
    required SonicAnchorMode anchor}) async {
  final mgr = AutoDJManager();
  final wasOn = mgr.sonicSimilarityEnabled;
  final changed = on != wasOn ||
      match != mgr.sonicMinSimilarity ||
      anchor != mgr.sonicAnchorMode;
  await mgr.setSonic(enabled: on, minSimilarity: match, anchor: anchor);
  final handler = MediaManager().audioHandler;
  if (wasOn && !on) {
    // Webapp parity (clearSonicAnchors): switching it off drops the session
    // anchors — rolling history and the locked pin.
    unawaited(handler.customAction('clearSonicSession'));
    // Several servers run on sonic picks: without them Play from is back to
    // the one the session runs on.
    final home = handler.autoDJServer ?? autoDjPlayFrom();
    if (mgr.multiServerEnabled && home != null) {
      await mgr.setPlayFrom(
          all: false, servers: [home.localname], home: home.localname);
    }
  }
  // A session that dropped sonic tries again with the new settings.
  if (changed) unawaited(handler.customAction('retrySonic'));
}

class SonicSheet extends StatefulWidget {
  const SonicSheet({super.key});

  @override
  State<SonicSheet> createState() => _SonicSheetState();
}

class _SonicSheetState extends State<SonicSheet> {
  final _mgr = AutoDJManager();
  late bool _on = _mgr.sonicSimilarityEnabled;
  late double _match = _mgr.sonicMinSimilarity.clamp(0.30, 0.80);
  late SonicAnchorMode _anchor = _mgr.sonicAnchorMode;

  Future<void> _done() => _applyThenClose(
      context, () => applySonic(on: _on, match: _match, anchor: _anchor));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AutoDjSheet(
      title: l.autoDjSonicTitle,
      value: _on ? l.autoDjPercent((_match * 100).round()) : l.commonOff,
      tone: _on ? AutoDjTone.active : AutoDjTone.neutral,
      toggle: _titleSwitch(l.autoDjSonicTitle, _on,
          (v) => setState(() => _on = v),
          key: const ValueKey('auto-dj-sonic-switch')),
      onDone: _done,
      child: Opacity(
        opacity: _on ? 1 : 0.4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Raw cosine threshold; the useful band in practice — the webapp's
          // slider covers the same range.
          _slider(
            key: const ValueKey('auto-dj-sonic-slider'),
            value: _match,
            min: 0.30,
            max: 0.80,
            divisions: 50,
            label: l.autoDjSonicTitle,
            spoken: (v) => l.autoDjPercent((v * 100).round()),
            onChanged: _on ? (v) => setState(() => _match = v) : null,
          ),
          const SizedBox(height: 8),
          SegmentedButton<SonicAnchorMode>(
            key: const ValueKey('auto-dj-sonic-anchor'),
            segments: [
              ButtonSegment(
                  value: SonicAnchorMode.rolling, label: Text(l.autoDjDrift)),
              ButtonSegment(
                  value: SonicAnchorMode.locked,
                  label: Text(l.autoDjStayClose)),
            ],
            selected: {_anchor},
            showSelectedIcon: false,
            onSelectionChanged: _on
                ? (set) => setState(() => _anchor = set.first)
                : null,
            style: autoDjSegmentStyle(),
          ),
        ]),
      ),
    );
  }
}

// ── Tempo ──────────────────────────────────────────────────────────────

class TempoSheet extends StatefulWidget {
  const TempoSheet({super.key});

  @override
  State<TempoSheet> createState() => _TempoSheetState();
}

class _TempoSheetState extends State<TempoSheet> {
  final _mgr = AutoDJManager();
  late bool _on = _mgr.bpmContinuityEnabled;
  late int _bpm = _mgr.bpmTolerance;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AutoDjSheet(
      title: l.autoDjTempo,
      value: _on ? l.autoDjBpmTolerance(_bpm) : l.commonOff,
      tone: _on ? AutoDjTone.active : AutoDjTone.neutral,
      toggle: _titleSwitch(l.autoDjTempo, _on, (v) => setState(() => _on = v),
          key: const ValueKey('auto-dj-tempo-switch')),
      onDone: () => _applyThenClose(
          context, () => _mgr.setTempo(enabled: _on, tolerance: _bpm)),
      child: Opacity(
        opacity: _on ? 1 : 0.4,
        child: _slider(
          key: const ValueKey('auto-dj-tempo-slider'),
          value: _bpm.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          label: l.autoDjTempo,
          spoken: (v) => l.autoDjBpmTolerance(v.round()),
          onChanged: _on ? (v) => setState(() => _bpm = v.round()) : null,
        ),
      ),
    );
  }
}

// ── Batch ──────────────────────────────────────────────────────────────

/// How many songs one Auto DJ turn queues (random-songs' `limit`).
class BatchSheet extends StatefulWidget {
  const BatchSheet({super.key});

  @override
  State<BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<BatchSheet> {
  late int _n = AutoDJManager().songsPerFetch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const max = AutoDJManager.maxSongsPerFetch;
    return AutoDjSheet(
      title: l.autoDjBatch,
      value: l.autoDjSongsPerFetchValue(_n),
      tone: AutoDjTone.neutral,
      onDone: () => _applyThenClose(
          context, () => AutoDJManager().setSongsPerFetch(_n)),
      child: _slider(
        key: const ValueKey('auto-dj-batch-slider'),
        value: _n.toDouble(),
        min: 1,
        max: max.toDouble(),
        divisions: max - 1,
        label: l.autoDjBatch,
        spoken: (v) => l.autoDjSongsPerFetchValue(v.round()),
        onChanged: (v) => setState(() => _n = v.round()),
      ),
    );
  }
}

// ── Length ─────────────────────────────────────────────────────────────

/// "Any", "2:00+", "Under 6:00" or "2:00–6:00": the rails mean "no limit".
String autoDjLengthValue(AppLocalizations l, int minSec, int maxSec) {
  final hasMin = minSec > AutoDJManager.durationFloorSec;
  final hasMax = maxSec < AutoDJManager.durationCeilSec;
  if (hasMin && hasMax) {
    return l.autoDjLengthBetween(fmtTrackLength(minSec), fmtTrackLength(maxSec));
  }
  if (hasMin) return l.autoDjLengthOver(fmtTrackLength(minSec));
  if (hasMax) return l.autoDjLengthUnder(fmtTrackLength(maxSec));
  return l.autoDjAny;
}

/// The language's own timer-wheel labels, but for a short hour unit: the
/// wheel draws that label in a fixed ~50 px, and "Stunden", "godzin" and
/// "heures" were cut off. Numbers, minutes and seconds come from [_base]; the
/// wheel reads nothing else from CupertinoLocalizations.
class _TimerWheelLabels extends DefaultCupertinoLocalizations {
  const _TimerWheelLabels(this._base, this._hour);

  final CupertinoLocalizations _base;
  final String _hour;

  static LocalizationsDelegate<CupertinoLocalizations> delegate(
          CupertinoLocalizations base, String hour) =>
      _TimerWheelLabelsDelegate(_TimerWheelLabels(base, hour));

  @override
  String timerPickerHour(int hour) => _base.timerPickerHour(hour);
  @override
  String timerPickerMinute(int minute) => _base.timerPickerMinute(minute);
  @override
  String timerPickerSecond(int second) => _base.timerPickerSecond(second);
  @override
  String timerPickerHourLabel(int hour) => _hour;
  @override
  List<String> get timerPickerHourLabels => [_hour];
  @override
  String timerPickerMinuteLabel(int minute) =>
      _base.timerPickerMinuteLabel(minute) ?? '';
  @override
  List<String> get timerPickerMinuteLabels => _base.timerPickerMinuteLabels;
  @override
  String timerPickerSecondLabel(int second) =>
      _base.timerPickerSecondLabel(second) ?? '';
  @override
  List<String> get timerPickerSecondLabels => _base.timerPickerSecondLabels;
}

class _TimerWheelLabelsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _TimerWheelLabelsDelegate(this._labels);

  final _TimerWheelLabels _labels;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(_labels);

  @override
  bool shouldReload(_TimerWheelLabelsDelegate old) =>
      !identical(old._labels._base, _labels._base) ||
      old._labels._hour != _labels._hour;
}

/// Shortest and Longest, each set on a timer wheel (hours, minutes, seconds)
/// that opens under its row, one at a time. 0:00:00 is no limit on that side.
class LengthSheet extends StatefulWidget {
  const LengthSheet({super.key});

  @override
  State<LengthSheet> createState() => _LengthSheetState();
}

enum _LengthBound { shortest, longest }

class _LengthSheetState extends State<LengthSheet> {
  static const _ceil = AutoDJManager.durationCeilSec;

  /// The wheels' top: 23:59:59.
  static const _wheelMax = _ceil - 1;

  final _mgr = AutoDJManager();
  // 0 is no limit, on both sides: the bottom of either wheel.
  late int _min = _mgr.activeDurationBounds?.min ?? 0;
  late int _max = _mgr.activeDurationBounds?.max ?? 0;
  late bool _unknown =
      _mgr.activeDurationBounds != null && _mgr.allowUnknownDuration;
  _LengthBound? _open;
  // Bumped by Clear: a wheel only takes its value when it is built.
  int _cleared = 0;

  bool get _any => _min == 0 && _max == 0;

  /// What Done keeps: the pair in order, a longest of 0 as no maximum.
  (int, int) get _window {
    final hi = _max == 0 ? _ceil : _max;
    return _min <= hi ? (_min, hi) : (hi, _min);
  }

  Widget _row(AppLocalizations l, _LengthBound b, String title, int sec) {
    final open = _open == b;
    return _ChoiceRow(
      key: ValueKey('auto-dj-length-${b.name}'),
      label: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: VelvetColors.textPrimary)),
      selected: open,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text(sec == 0 ? l.autoDjAny : fmtTrackLength(sec),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: open
                      ? VelvetColors.primary
                      : sec == 0
                          ? VelvetColors.textSecondary
                          : VelvetColors.textPrimary)),
        ),
        const SizedBox(width: 4),
        ExcludeSemantics(
          child: Icon(open ? Icons.expand_less : Icons.expand_more,
              size: 18, color: VelvetColors.textTertiary),
        ),
      ]),
      onTap: () => setState(() => _open = open ? null : b),
    );
  }

  Widget _wheel(_LengthBound b, int sec) => CupertinoTheme(
        // The app's own colours, in either palette, not Cupertino's.
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: VelvetColors.primary,
          textTheme: CupertinoTextThemeData(
            pickerTextStyle:
                TextStyle(fontSize: 21, color: VelvetColors.textPrimary),
          ),
        ),
        child: Localizations.override(
          context: context,
          delegates: [
            _TimerWheelLabels.delegate(CupertinoLocalizations.of(context),
                AppLocalizations.of(context).autoDjWheelHours),
          ],
          child: CupertinoTimerPicker(
            key: ValueKey('auto-dj-length-wheel-${b.name}-$_cleared'),
            mode: CupertinoTimerPickerMode.hms,
            initialTimerDuration: Duration(seconds: sec.clamp(0, _wheelMax)),
            onTimerDurationChanged: (d) => setState(() {
              if (b == _LengthBound.shortest) {
                _min = d.inSeconds;
              } else {
                _max = d.inSeconds;
              }
            }),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (lo, hi) = _window;
    return AutoDjSheet(
      title: l.autoDjDurationRange,
      value: autoDjLengthValue(l, lo, hi),
      tone: _any ? AutoDjTone.neutral : AutoDjTone.active,
      clearable: true,
      onClear: _any
          ? null
          : () => setState(() {
                _min = 0;
                _max = 0;
                _unknown = false;
                _cleared++;
              }),
      onDone: () => _applyThenClose(
          context,
          () => _mgr.setDurationFilter(
              minSec: lo, maxSec: hi, allowUnknown: !_any && _unknown)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FedCard(children: [
          _row(l, _LengthBound.shortest, l.autoDjLengthShortest, _min),
          if (_open == _LengthBound.shortest) _wheel(_LengthBound.shortest, _min),
          _row(l, _LengthBound.longest, l.autoDjLengthLongest, _max),
          if (_open == _LengthBound.longest) _wheel(_LengthBound.longest, _max),
        ]),
        const SizedBox(height: 8),
        // Always drawn, so nothing jumps; it means nothing without a limit.
        FedCard(children: [
          FedSwitchRow(
            key: const ValueKey('auto-dj-length-unknown'),
            title: l.autoDjIncludeUnknown,
            value: !_any && _unknown,
            onChanged: _any ? null : (v) => setState(() => _unknown = v),
          ),
        ]),
      ]),
    );
  }
}

// ── Rating ─────────────────────────────────────────────────────────────

/// The minimum rating, per server. Ratings are per user, and a peer is
/// reached with a key that has none, so [servers] never holds one.
class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key, required this.servers, required this.initial});

  /// Whose ratings are edited; chips choose between them when there are two
  /// or more (All servers).
  final List<Server> servers;
  final Server initial;

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  late Server _target = widget.initial;
  late final Map<String, int?> _draft = {
    for (final s in widget.servers) s.localname: s.autoDJminRating,
  };

  int? get _rating => _draft[_target.localname];

  /// A rating in words, for the title and for screen readers.
  String _words(AppLocalizations l, int? r) =>
      r == null || r <= 0 ? l.autoDjAny : l.autoDjRatingValue(fmtStars(r));

  /// One step of the stars: a half star where Settings allows half-star
  /// ratings, else a whole one — the same steps the stars take by touch.
  int get _step => SettingsManager().ratingAllowHalf ? 1 : 2;

  void _set(int? r) => setState(() =>
      _draft[_target.localname] = r == null || r <= 0 ? null : r.clamp(1, 10));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rating = _rating;
    return AutoDjSheet(
      title: l.autoDjRating,
      value: _words(l, rating),
      tone: rating == null ? AutoDjTone.neutral : AutoDjTone.active,
      clearable: true,
      onClear: rating == null
          ? null
          : () => setState(() => _draft[_target.localname] = null),
      onDone: () {
        var changed = false;
        for (final s in widget.servers) {
          final v = _draft[s.localname];
          if (v != s.autoDJminRating) {
            s.autoDJminRating = v;
            changed = true;
          }
        }
        if (changed) {
          ServerManager().callAfterEditServer();
          MediaManager().audioHandler.customAction('forceAutoDJRefresh');
        }
        Navigator.of(context).pop();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.servers.length > 1)
          _ServerChips(
            servers: widget.servers,
            selected: _target,
            isSet: (s) => _draft[s.localname] != null,
            onSelected: (s) => setState(() => _target = s),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          // Five unlabelled stars mean nothing to a screen reader: it gets
          // one adjustable control that says the rating in words.
          child: Semantics(
            label: l.autoDjRating,
            value: _words(l, rating),
            increasedValue:
                rating == 10 ? null : _words(l, (rating ?? 0) + _step),
            decreasedValue: rating == null ? null : _words(l, rating - _step),
            onIncrease: rating == 10 ? null : () => _set((rating ?? 0) + _step),
            onDecrease: rating == null ? null : () => _set(rating - _step),
            child: ExcludeSemantics(
              child: Center(
                child: StarRating(
                  key: const ValueKey('auto-dj-rating-stars'),
                  rating: rating,
                  size: 44,
                  onRate: _set,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Genres ─────────────────────────────────────────────────────────────

bool _genreKindKnownUnsupported(Server s) => paramKnownUnsupported(
    ServerVersion.tryParse(s.serverVersion), ServerParam.genreSource);

/// The kind of genre link [s]'s Auto DJ filter is narrowed to as sent: all
/// of them on a server known to predate random-songs' `genreSource`, whose
/// key is stripped before it goes, whatever is stored.
GenreSource genreKindSent(Server s) => _genreKindKnownUnsupported(s)
    ? GenreSource.both
    : s.autoDJGenreSource;

/// Whether the Genres sheet offers Generated | Tags | Mixed for [s]: it has
/// genres of both kinds ([sources], what it said it has, null until it
/// answers) and isn't known too old to be asked for one.
bool genreKindOffered(Server s, GenreSources? sources) =>
    (sources?.offersChoice ?? false) && !_genreKindKnownUnsupported(s);

class _GenreDraft {
  _GenreDraft(this.mode, this.genres, this.source);
  String mode; // 'whitelist' | 'blacklist'
  final List<String> genres;
  GenreSource source;
}

/// Only or Skip, which kind of genre (Generated, Tags or Mixed) and which
/// genres — per server, from that server's own list.
class GenresSheet extends StatefulWidget {
  const GenresSheet({super.key, required this.servers, required this.initial});

  /// Whose genres are edited; chips choose between them when there are two
  /// or more (All servers).
  final List<Server> servers;
  final Server initial;

  @override
  State<GenresSheet> createState() => _GenresSheetState();
}

class _GenresSheetState extends State<GenresSheet> {
  late Server _target = widget.initial;
  String _query = '';
  late final Map<String, _GenreDraft> _drafts = {
    for (final s in widget.servers)
      s.localname: _GenreDraft(
          s.autoDJGenreMode,
          s.autoDJGenreEnabled ? List.of(s.autoDJGenres) : <String>[],
          s.autoDJGenreSource),
  };
  // Only servers the user touched are written back: a server whose filter
  // was switched off keeps its stored list unless it is edited here.
  final Set<String> _touched = {};
  // Lists by server and kind (_listKey); what each server says it has.
  final Map<String, List<String>> _available = {};
  final Map<String, GenreSources?> _sources = {};
  // What each server had chosen when its list was first shown, and when its
  // kind changed: those lead the list, so ticking more doesn't reorder it
  // under the finger and a genre ticked under another kind stays in view.
  final Map<String, List<String>> _pinned = {};
  final Map<String, bool> _failed = {};
  final Set<String> _loading = {};

  _GenreDraft get _draft => _drafts[_target.localname]!;

  static String _listKey(Server s, GenreSource source) =>
      '${s.localname}|${source.name}';

  bool _offersSource(Server s) => genreKindOffered(s, _sources[s.localname]);

  /// The kind [s]'s list shows: the draft's, or all of them where there is
  /// no choice — or until the server has said whether there is one.
  GenreSource _listed(Server s) =>
      _offersSource(s) ? _drafts[s.localname]!.source : GenreSource.both;

  final _sheet = DraggableScrollableController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load(_target);
    // Searching wants the room: the sheet grows to its full height.
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && _sheet.isAttached) {
        _sheet.animateTo(0.95,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _sheet.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Loads the list [s] shows now. Its first answer says what kinds the
  /// server has, which can change that: a stored Generated or Tags then
  /// loads its own list.
  Future<void> _load(Server s) async {
    final source = _listed(s);
    final key = _listKey(s, source);
    if (_available.containsKey(key) || _loading.contains(key)) return;
    setState(() {
      _loading.add(key);
      _failed.remove(key);
    });
    try {
      final r = await ApiManager().getGenres(useThisServer: s, source: source);
      if (!mounted) return;
      setState(() {
        _available[key] = r.genres
            .map((g) => (g['name'] ?? '').toString())
            .where((g) => g.isNotEmpty)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _sources[s.localname] = r.sources;
        _loading.remove(key);
      });
      if (_listed(s) != source) unawaited(_load(s));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed[key] = true;
        _loading.remove(key);
      });
    }
  }

  void _edit(void Function(_GenreDraft d) change) => setState(() {
        change(_draft);
        _touched.add(_target.localname);
      });

  void _done() {
    var changed = false;
    for (final s in widget.servers) {
      final d = _drafts[s.localname]!;
      // What the list showed is what the filter matches: the chosen kind
      // where the server offers the choice, every kind where it doesn't — so
      // a Generated or Tags left from when it did can't go on narrowing picks
      // with no switch to show it. A server that never answered keeps its own.
      final kind = _sources.containsKey(s.localname) ? _listed(s) : d.source;
      if (_touched.contains(s.localname)) {
        s.autoDJGenres = List.of(d.genres);
        s.autoDJGenreMode = d.mode;
        s.autoDJGenreEnabled = d.genres.isNotEmpty;
      } else if (kind == s.autoDJGenreSource) {
        continue;
      }
      s.autoDJGenreSource = kind;
      changed = true;
    }
    if (changed) {
      ServerManager().callAfterEditServer();
      MediaManager().audioHandler.customAction('forceAutoDJRefresh');
    }
    Navigator.of(context).pop();
  }

  /// One line saying why there are no rows, in the list's place.
  Widget _message(String text, {Color? color}) => SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color ?? VelvetColors.textSecondary)),
        ),
      );

  Widget _list(AppLocalizations l) {
    final key = _target.localname;
    final listKey = _listKey(_target, _listed(_target));
    if (_loading.contains(listKey)) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
            child: CircularProgressIndicator(color: VelvetColors.primary)),
      );
    }
    final chosen = _draft.genres;
    final available = _available[listKey] ?? const <String>[];
    // Chosen first — including ones the server no longer reports, so they
    // can still be let go — as of when the list was first shown, so ticking
    // doesn't move rows under the finger, and unticking the last one doesn't
    // take the rows away.
    final pinned = _pinned.putIfAbsent(key, () => List.of(chosen));
    final failed = _failed[listKey] == true;
    if (pinned.isEmpty && chosen.isEmpty) {
      if (failed) {
        return _message(l.autoDjGenreLoadError, color: VelvetColors.error);
      }
      if (available.isEmpty) return _message(l.autoDjGenresNone);
    }
    final q = _query.trim().toLowerCase();
    bool matches(String g) => q.isEmpty || g.toLowerCase().contains(q);
    final pinnedSet = pinned.toSet();
    final chosenSet = chosen.toSet();
    final rows = [
      ...pinned.where(matches),
      ...available.where((g) => !pinnedSet.contains(g) && matches(g)),
    ];
    if (rows.isEmpty) {
      return failed
          ? _message(l.autoDjGenreLoadError, color: VelvetColors.error)
          : _message(l.autoDjNoMatches);
    }
    final full = chosen.length >= AutoDJManager.maxGenres;
    final list = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: VelvetColors.border),
        itemBuilder: (context, i) {
          final g = rows[i];
          final on = chosenSet.contains(g);
          return FedCheckRow(
            key: ValueKey('auto-dj-genre-$g'),
            label: g,
            value: on,
            // Same cap the server Joi-validates at, so an over-long list
            // can't 400 the whole random-songs request.
            onChanged: !on && full
                ? null
                : (v) => _edit((d) {
                      if (v) {
                        d.genres.add(g);
                      } else {
                        d.genres.remove(g);
                      }
                    }),
          );
        },
      ),
    );
    if (!failed) return list;
    // The pinned rows stay, so they can still be let go, under why the rest
    // of the list is missing.
    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(l.autoDjGenreLoadError,
              textAlign: TextAlign.center,
              style: TextStyle(color: VelvetColors.error)),
        ),
      ),
      list,
    ]);
  }

  /// Generated | Tags | Mixed: which of the server's genre links the list
  /// shows and the filter matches. The chosen genres stay ticked, and in
  /// view: the new kind's list need not hold them.
  Widget _sourceSwitch(AppLocalizations l) {
    // One line each, shrunk rather than broken mid-word where a translation
    // is long ("Сгенерированные" on a narrow phone).
    Widget label(String text) =>
        FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
    return Semantics(
      label: l.genreSourceLabel,
      child: SegmentedButton<GenreSource>(
        key: const ValueKey('auto-dj-genre-source'),
        segments: [
          ButtonSegment(
              value: GenreSource.model, label: label(l.genreSourceGenerated)),
          ButtonSegment(value: GenreSource.tag, label: label(l.genreSourceTags)),
          ButtonSegment(
              value: GenreSource.both, label: label(l.genreSourceMixed)),
        ],
        selected: {_draft.source},
        showSelectedIcon: false,
        onSelectionChanged: (set) {
          _edit((d) {
            d.source = set.first;
            final pinned = _pinned.putIfAbsent(_target.localname, () => []);
            pinned.addAll(d.genres.where((g) => !pinned.contains(g)));
          });
          _load(_target);
        },
        style: autoDjSegmentStyle(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final full = _draft.genres.length >= AutoDJManager.maxGenres;
    // Above the keyboard, so Done stays in reach. Only the title and the
    // buttons are fixed: the chips, Only | Skip and the search scroll with
    // the list, so a short space (a small phone with the keyboard up) never
    // squeezes the sheet past its parts — and the search grows the sheet.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        controller: _sheet,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => SafeArea(
          top: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _handle(),
            _TitleRow(
              title: l.autoDjGenres,
              value: full ? l.autoDjMax(AutoDJManager.maxGenres) : null,
              tone: AutoDjTone.warning,
            ),
            Expanded(
              child: CustomScrollView(controller: controller, slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.servers.length > 1)
                          _ServerChips(
                            servers: widget.servers,
                            selected: _target,
                            isSet: (s) =>
                                _drafts[s.localname]!.genres.isNotEmpty,
                            onSelected: (s) {
                              setState(() => _target = s);
                              _load(s);
                            },
                          ),
                        SegmentedButton<String>(
                          key: const ValueKey('auto-dj-genre-mode'),
                          segments: [
                            ButtonSegment(
                                value: 'whitelist',
                                label: Text(l.autoDjGenresOnly)),
                            ButtonSegment(
                                value: 'blacklist',
                                label: Text(l.autoDjGenresSkip)),
                          ],
                          selected: {_draft.mode},
                          showSelectedIcon: false,
                          onSelectionChanged: (set) =>
                              _edit((d) => d.mode = set.first),
                          style: autoDjSegmentStyle(),
                        ),
                        if (_offersSource(_target)) ...[
                          const SizedBox(height: 10),
                          _sourceSwitch(l),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('auto-dj-genre-search'),
                          focusNode: _searchFocus,
                          decoration: _fieldDecoration(
                              hint: l.browserSearch,
                              prefix: const Icon(Icons.search)),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ],
                    ),
                  ),
                ),
                _list(l),
              ]),
            ),
            _BottomBar(
              onDone: _done,
              clearable: true,
              onClear: _draft.genres.isEmpty
                  ? null
                  : () => _edit((d) => d.genres.clear()),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Skip words ─────────────────────────────────────────────────────────

/// Words that keep a song out: matched against its title, artist, album
/// and file path, on the phone (audio_stuff's autoDJ retry loop).
class SkipWordsSheet extends StatefulWidget {
  const SkipWordsSheet({super.key});

  @override
  State<SkipWordsSheet> createState() => _SkipWordsSheetState();
}

class _SkipWordsSheetState extends State<SkipWordsSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final List<String> _words = AutoDJManager().keywordFilterEnabled
      ? List.of(AutoDJManager().keywordFilterWords)
      : <String>[];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _full => _words.length >= AutoDJManager.maxKeywords;

  bool get _canAdd {
    final w = _ctrl.text.trim().toLowerCase();
    return w.isNotEmpty &&
        !_full &&
        !_words.any((x) => x.toLowerCase() == w);
  }

  void _add() {
    if (!_canAdd) return;
    setState(() => _words.add(_ctrl.text.trim()));
    _ctrl.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      // The field sits above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AutoDjSheet(
        title: l.autoDjSkipWords,
        value: _full ? l.autoDjMax(AutoDJManager.maxKeywords) : null,
        tone: AutoDjTone.warning,
        clearable: true,
        onClear: _words.isEmpty ? null : () => setState(_words.clear),
        // A word typed but not yet added counts: Done applies what is shown.
        onDone: () => _applyThenClose(context, () {
          if (_canAdd) _words.add(_ctrl.text.trim());
          return AutoDJManager().setKeywords(_words);
        }),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            // Named for screen readers (merged into the field's own node);
            // on screen the sheet's title says it. The + sits beside it, not
            // inside, so it stays a button of its own.
            Expanded(
              child: MergeSemantics(
                child: Semantics(
                  label: l.autoDjSkipWords,
                  child: TextField(
                    key: const ValueKey('auto-dj-skip-words-field'),
                    controller: _ctrl,
                    focusNode: _focus,
                    autofocus: true,
                    enabled: !_full,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: _fieldDecoration(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('auto-dj-skip-words-add'),
              icon: const Icon(Icons.add),
              color: VelvetColors.primary,
              tooltip: l.add,
              onPressed: _canAdd ? _add : null,
            ),
          ]),
          if (_words.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final w in _words)
                InputChip(
                  key: ValueKey('auto-dj-skip-word-$w'),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(w,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 13)),
                  ),
                  backgroundColor: VelvetColors.raised,
                  side: BorderSide(color: VelvetColors.border),
                  deleteIconColor: VelvetColors.textSecondary,
                  onDeleted: () => setState(() => _words.remove(w)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
