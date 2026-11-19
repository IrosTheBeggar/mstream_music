import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../media/preview_player.dart';
import '../../objects/discovery_plugins.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discovery_plugins_api.dart';
import 'elsewhere_sheet.dart' show openOutside;
import 'keep_copy_ui.dart';
import 'keep_toast.dart';

/// The network-lead sheet's 30-SECOND PREVIEW (the design canvas's
/// NetworkSheet board and its Degraded preview outcomes): one row per
/// preview plug-in the user's own server lists (Deezer, iTunes, any other),
/// each asked only when the user presses it — nothing reaches a catalogue
/// before that — and played on the preview player (media/preview_player.dart),
/// which pauses the song while a clip plays and brings it back after.
///
/// A row reads "Tap to hear 30 seconds" until pressed, "Looking up…" while
/// its plug-in is asked, then what the catalogue matched with its
/// attribution (shown as the catalogue sends it) and a link to its store
/// page; while its clip plays, "0:12 of 0:30 · …" in a ring around Stop.
/// "No preview found" disables the row for the sheet's life; "Busy — try
/// again in a minute" (429) and "Unavailable right now" (any other failure,
/// the clip's own included) ask again on the next press. A plug-in the
/// server no longer offers this caller (403 / 404) takes its row away.
/// One clip at a time: pressing another row switches, the song staying
/// paused in between.

/// A preview row's name: the catalogues by their own names, any other
/// preview plug-in by its listing title.
String previewProviderLabel(DiscoveryPlugin plugin) => switch (plugin.name) {
  kDeezerPlugin => 'Deezer',
  kItunesPlugin => 'iTunes',
  _ => plugin.title,
};

/// Where a preview's store link opens ("Open in Apple Music").
String previewStoreName(DiscoveryPlugin plugin) => switch (plugin.name) {
  kDeezerPlugin => 'Deezer',
  kItunesPlugin => 'Apple Music',
  _ => plugin.title,
};

/// How one preview row reads.
enum PreviewRowState {
  /// Never pressed: "Tap to hear 30 seconds".
  idle,

  /// Its plug-in is being asked: "Looking up…", presses ignored.
  lookingUp,

  /// Its clip is loading: a ring; a press stops it.
  loading,

  /// Its clip plays: "0:12 of 0:30 · …"; a press stops it.
  playing,

  /// A clip was found and is not playing: what it matched; a press plays it
  /// again without asking the plug-in again.
  stopped,

  /// The plug-in found none: "No preview found", disabled.
  none,

  /// 429: "Busy — try again in a minute"; a press asks again.
  busy,

  /// The plug-in did not answer, or the clip would not load or broke while
  /// playing: "Unavailable right now"; a press asks again.
  unavailable,
}

enum _Lookup { idle, lookingUp, found, none, busy, unavailable }

/// One sheet's previews: what each plug-in answered, and the press that
/// asks it and plays its clip. Lives as long as the sheet; the sheet ends
/// the preview player's flow as it closes.
class NetworkPreviews extends ChangeNotifier {
  /// [recommendation] is sent to each preview plug-in as it is (the sheet's
  /// repaired one). [onPress] runs on every press that asks or plays (the
  /// sheet pins Discover's seed); [onGone] when a plug-in answered 403 or
  /// 404 (its row is gone; the sheet reads the gate again and says so).
  NetworkPreviews({
    required this.api,
    required this.recommendation,
    this.onPress,
    this.onGone,
  }) : _player = PreviewPlayer() {
    _clip = _player.state.value;
    _sub = _player.state.listen(_onClip);
  }

  final DiscoveryPluginsApi api;
  final Map<String, dynamic> recommendation;
  final VoidCallback? onPress;
  final void Function(String plugin)? onGone;
  final PreviewPlayer _player;

  final Map<String, _Lookup> _lookups = {};
  final Map<String, PluginPreview> _found = {};
  final Set<String> _gone = {};
  late PreviewClipState _clip;
  StreamSubscription<PreviewClipState>? _sub;

  /// The row pressed last: a clip found for any other once it answers is
  /// not played.
  String? _wanted;
  bool _disposed = false;

  /// The preview player's state as last told.
  PreviewClipState get clip => _clip;

  /// The clip [plugin] found, once it answered with one.
  PluginPreview? previewOf(String plugin) => _found[plugin];

  /// [plugin] answered 403 or 404: its row is gone for the sheet's life.
  bool isGone(String plugin) => _gone.contains(plugin);

  /// The header's cover: Deezer's (250 px) once it answered with one, else
  /// iTunes' (100 px), else any other's.
  Uri? get artwork {
    for (final name in [kDeezerPlugin, kItunesPlugin, ..._found.keys]) {
      final art = _found[name]?.artwork;
      if (art != null) return art;
    }
    return null;
  }

  /// How [plugin]'s row reads now: what its plug-in answered, and whether
  /// the preview player is loading or playing its clip.
  PreviewRowState stateOf(String plugin) {
    final lookup = _lookups[plugin] ?? _Lookup.idle;
    if (lookup == _Lookup.none) return PreviewRowState.none;
    if (lookup == _Lookup.lookingUp) return PreviewRowState.lookingUp;
    if (_clip.provider == plugin) {
      if (_clip.phase == PreviewPhase.loading) return PreviewRowState.loading;
      if (_clip.phase == PreviewPhase.playing) return PreviewRowState.playing;
    }
    return switch (lookup) {
      _Lookup.found => PreviewRowState.stopped,
      _Lookup.busy => PreviewRowState.busy,
      _Lookup.unavailable => PreviewRowState.unavailable,
      _ => PreviewRowState.idle,
    };
  }

  /// A press on [plugin]'s row: stops its clip while it loads or plays;
  /// otherwise plays the clip it found, or asks the plug-in first (never
  /// while it is being asked, nor once it found none).
  Future<void> press(DiscoveryPlugin plugin) async {
    final name = plugin.name;
    if (_disposed || _gone.contains(name)) return;
    switch (stateOf(name)) {
      case PreviewRowState.loading:
      case PreviewRowState.playing:
        _wanted = null;
        await _player.end(PreviewEnd.stopped);
        return;
      case PreviewRowState.lookingUp:
      case PreviewRowState.none:
        return;
      case PreviewRowState.stopped:
        onPress?.call();
        _wanted = name;
        await _play(name, _found[name]!);
        return;
      case PreviewRowState.idle:
      case PreviewRowState.busy:
      case PreviewRowState.unavailable:
        onPress?.call();
        _wanted = name;
        await _ask(name);
    }
  }

  Future<void> _ask(String name) async {
    _set(name, _Lookup.lookingUp);
    PluginPreview? found;
    try {
      found = await api.preview(name, recommendation);
    } on DiscoveryPluginsException catch (e) {
      if (_disposed) return;
      if (e.absent) {
        _gone.add(name);
        _lookups.remove(name);
        if (_wanted == name) _wanted = null;
        notifyListeners();
        onGone?.call(name);
        return;
      }
      _set(name, e.status == 429 ? _Lookup.busy : _Lookup.unavailable);
      return;
    }
    if (_disposed) return;
    if (found == null) {
      _found.remove(name);
      _set(name, _Lookup.none);
      return;
    }
    _found[name] = found;
    _set(name, _Lookup.found);
    // Pressed something else since (or stopped): this one waits.
    if (_wanted == name) await _play(name, found);
  }

  Future<void> _play(String name, PluginPreview preview) async {
    final out = await _player.play(provider: name, url: preview.url);
    if (_disposed) return;
    if (out == PreviewPlayOutcome.failed) _set(name, _Lookup.unavailable);
  }

  void _onClip(PreviewClipState s) {
    if (_disposed) return;
    _clip = s;
    // The clip would not load or broke while playing: the row reads
    // unavailable, and its next press asks the plug-in again.
    final provider = s.provider;
    if (s.phase == PreviewPhase.failed &&
        provider != null &&
        _lookups[provider] == _Lookup.found) {
      _lookups[provider] = _Lookup.unavailable;
    }
    notifyListeners();
  }

  void _set(String name, _Lookup lookup) {
    if (_disposed) return;
    _lookups[name] = lookup;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

/// A match tag ("match 97%"): 11/600 in [tone] on a tint of it — on a
/// preview row and on a YouTube upload.
class LeadMatchTag extends StatelessWidget {
  final String label;
  final Color tone;
  const LeadMatchTag(this.label, {super.key, required this.tone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: tone,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 16 / 11,
      ),
    ),
  );
}

/// The 30-SECOND PREVIEW section: its label and a card of [plugins]' rows
/// (a row whose plug-in went away is left out; with none left, nothing).
class NetworkPreviewSection extends StatelessWidget {
  final NetworkPreviews previews;
  final List<DiscoveryPlugin> plugins;
  const NetworkPreviewSection({
    super.key,
    required this.previews,
    required this.plugins,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = [
      for (final p in plugins)
        if (!previews.isGone(p.name)) p,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('lead-previews'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeepSheetLabel(l.discoverLeadPreviewLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: VelvetColors.card,
              borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
              border: Border.all(color: VelvetColors.border),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, p) in rows.indexed) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: VelvetColors.border,
                        ),
                      ),
                    _PreviewRow(previews: previews, plugin: p),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final NetworkPreviews previews;
  final DiscoveryPlugin plugin;
  const _PreviewRow({required this.previews, required this.plugin});

  Future<void> _openStore(BuildContext context, Uri link) async {
    final l = AppLocalizations.of(context);
    var ok = false;
    try {
      ok = await openOutside(link);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      KeepToast.show(context, l.discoverToastLinkFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = plugin.name;
    final label = previewProviderLabel(plugin);
    final state = previews.stateOf(name);
    final preview = previews.previewOf(name);
    final clip = previews.clip;
    final sounding =
        state == PreviewRowState.playing || state == PreviewRowState.loading;
    final matched =
        preview != null && (sounding || state == PreviewRowState.stopped);
    final length = clip.duration ?? Duration(seconds: preview?.seconds ?? 30);

    final what = [?preview?.title, ?preview?.artist].join(' · ');
    final (String? line2, Color? line2Color) = switch (state) {
      PreviewRowState.idle => (l.discoverLeadPreviewTap, null),
      PreviewRowState.lookingUp => (l.discoverLeadPreviewLookingUp, null),
      PreviewRowState.none => (l.discoverLeadPreviewNone, null),
      PreviewRowState.busy => (
        l.discoverLeadPreviewBusy,
        keepTone(VelvetColors.warning),
      ),
      PreviewRowState.unavailable => (l.discoverLeadPreviewUnavailable, null),
      PreviewRowState.playing => (
        [
          l.discoverLeadPreviewProgress(
            keepClock(clip.position),
            keepClock(length),
          ),
          if (what.isNotEmpty) what,
        ].join(' · '),
        null,
      ),
      PreviewRowState.loading ||
      PreviewRowState.stopped => (what.isEmpty ? null : what, null),
    };
    final match = matched ? preview.match : null;
    final attribution = matched ? preview.attribution : null;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The tag goes under the name when both do not fit (large text, a
        // long word for "match").
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // A row that is a button names its plug-in in its label.
            ExcludeSemantics(
              excluding: state != PreviewRowState.none,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: state == PreviewRowState.none
                      ? VelvetColors.textTertiary
                      : VelvetColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 20 / 15,
                ),
              ),
            ),
            if (match != null)
              LeadMatchTag(
                l.discoverLeadMatchPill((match * 100).round()),
                tone: keepTone(VelvetColors.success),
              ),
          ],
        ),
        if (line2 != null)
          Text(
            line2,
            key: ValueKey('lead-preview-line-$name'),
            style: TextStyle(
              color: line2Color ?? VelvetColors.textSecondary,
              fontSize: 13,
              height: 17 / 13,
            ),
          ),
        if (attribution != null && attribution.isNotEmpty)
          Text(
            attribution,
            style: TextStyle(
              color: keepQuiet(VelvetColors.textTertiary),
              fontSize: 11,
              height: 15 / 11,
            ),
          ),
      ],
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            _PlayDisc(
              state: state,
              progress:
                  state == PreviewRowState.playing && length > Duration.zero
                  ? clip.position.inMilliseconds / length.inMilliseconds
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: text),
          ],
        ),
      ),
    );

    final Widget main;
    if (state == PreviewRowState.none) {
      // Nothing to press: read as text, not a button.
      main = Opacity(
        key: ValueKey('lead-preview-$name'),
        opacity: 0.45,
        child: IgnorePointer(child: body),
      );
    } else {
      final pressable = state != PreviewRowState.lookingUp;
      main = MergeSemantics(
        key: ValueKey('lead-preview-$name'),
        child: Semantics(
          button: true,
          enabled: pressable,
          label: sounding
              ? l.discoverLeadPreviewStopA11y(label)
              : l.discoverLeadPreviewPlayA11y(label),
          child: InkWell(
            onTap: pressable ? () => unawaited(previews.press(plugin)) : null,
            splashColor: VelvetColors.primaryDim,
            child: body,
          ),
        ),
      );
    }

    final link = state == PreviewRowState.none ? null : preview?.link;
    return Row(
      children: [
        Expanded(child: main),
        if (link != null)
          IconButton(
            key: ValueKey('lead-preview-link-$name'),
            tooltip: l.discoverLeadPreviewOpenIn(previewStoreName(plugin)),
            onPressed: () => unawaited(_openStore(context, link)),
            icon: Icon(
              Icons.open_in_new,
              size: 18,
              color: VelvetColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// A row's 40 px disc: Play, Stop inside a ring of how far the clip has
/// played, or a still ring while it is asked or loads.
class _PlayDisc extends StatelessWidget {
  final PreviewRowState state;

  /// How far the playing clip is, 0..1.
  final double? progress;
  const _PlayDisc({required this.state, this.progress});

  @override
  Widget build(BuildContext context) {
    final ink = keepInk();
    final sounding =
        state == PreviewRowState.playing || state == PreviewRowState.loading;
    final Widget glyph = switch (state) {
      PreviewRowState.lookingUp ||
      PreviewRowState.loading => KeepRing(size: 20, color: ink),
      PreviewRowState.playing => Icon(Icons.stop, size: 22, color: ink),
      PreviewRowState.none => Icon(
        Icons.play_arrow,
        size: 22,
        color: VelvetColors.textTertiary,
      ),
      _ => Icon(Icons.play_arrow, size: 22, color: ink),
    };
    final p = progress;
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        foregroundPainter: p == null ? null : _ProgressRing(p, ink),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sounding ? VelvetColors.primaryDim : VelvetColors.raised,
          ),
          alignment: Alignment.center,
          child: glyph,
        ),
      ),
    );
  }
}

class _ProgressRing extends CustomPainter {
  final double fraction;
  final Color color;
  _ProgressRing(this.fraction, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final r = (size.shortestSide - stroke) / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: r),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ProgressRing old) =>
      old.fraction != fraction || old.color != color;
}
