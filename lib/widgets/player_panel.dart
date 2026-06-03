import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../objects/player_layout.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/ambient_color.dart';
import 'more_actions_sheet.dart';
import 'queue_list.dart';
import 'waveform_progress.dart';

/// Ink color for content on top of the amber accent button (a dark espresso,
/// straight from the design — `#1a1206`).
const Color _kAmberInk = Color(0xFF1A1206);

/// A Spotify/Apple-Music-style player panel pinned to the bottom of the
/// screen. Collapsed it shows a mini-player (art + title + play/pause).
/// Dragged up — or tapped — it expands into a full "Now Playing" view whose
/// layout the user picks in Settings (Small / Medium / Large / XL), with the
/// queue beneath it.
///
/// The parent holds a `GlobalKey<PlayerPanelState>` and, from the system back
/// handler, calls [PlayerPanelState.collapse] so Back collapses the panel
/// before it pops the route.
class PlayerPanel extends StatefulWidget {
  /// Height of the collapsed mini-player. The parent reserves this much
  /// bottom padding on the body so list content clears the bar.
  static const double kCollapsedHeight = 104.0;

  final double collapsedHeight;
  const PlayerPanel({Key? key, this.collapsedHeight = kCollapsedHeight})
      : super(key: key);

  @override
  PlayerPanelState createState() => PlayerPanelState();
}

class PlayerPanelState extends State<PlayerPanel>
    with SingleTickerProviderStateMixin {
  // 0.0 = fully collapsed (mini-player), 1.0 = fully expanded (now-playing).
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  double _dragExtent = 1.0;

  bool get isExpanded => _ctrl.value > 0.5;

  void expand() => _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
  void collapse() => _ctrl.animateTo(0.0, curve: Curves.easeOutCubic);
  void toggle() => isExpanded ? collapse() : expand();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragExtent <= 0) return;
    _ctrl.value =
        (_ctrl.value - (d.primaryDelta ?? 0) / _dragExtent).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0; // px/s, negative = upward fling
    if (v < -300) {
      expand();
    } else if (v > 300) {
      collapse();
    } else {
      _ctrl.value > 0.5 ? expand() : collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Bottom system inset (gesture/3-button nav bar). On Android 15 the app
        // is forced edge-to-edge, so we reserve this space ourselves now that
        // the panel replaced the Scaffold's bottomNavigationBar slot.
        final pad = MediaQuery.of(context).viewPadding.bottom;
        final topPad = MediaQuery.of(context).viewPadding.top;
        final maxH = constraints.maxHeight;
        final minH = widget.collapsedHeight + pad;
        _dragExtent = (maxH - minH).clamp(1.0, double.infinity);

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value.clamp(0.0, 1.0);
            final top = (1 - t) * (maxH - minH);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  height: maxH,
                  child: _ExpandedPanel(
                    t: t,
                    bottomInset: pad,
                    topInset: topPad,
                    onDragUpdate: _onDragUpdate,
                    onDragEnd: _onDragEnd,
                    onCollapse: collapse,
                  ),
                ),
                if (t < 0.999)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: minH,
                    child: IgnorePointer(
                      ignoring: t > 0.4,
                      child: Transform.translate(
                        // Lift the bar up as the sheet expands so it rises into
                        // the now-playing view rather than staying pinned to the
                        // bottom (Material "container transform").
                        offset: Offset(0, -t * (maxH - minH) * 0.45),
                        child: Opacity(
                          // Front-loaded fade (gone by ~40%) so it doesn't
                          // muddily overlap the incoming content — the rise
                          // already separates them spatially.
                          opacity: (1 - t / 0.4).clamp(0.0, 1.0),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: pad),
                            child: _MiniPlayer(
                              onTap: expand,
                              onDragUpdate: _onDragUpdate,
                              onDragEnd: _onDragEnd,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded sheet: ambient background + (layout-switched) now-playing top + queue.
// ---------------------------------------------------------------------------

class _ExpandedPanel extends StatelessWidget {
  final double t;
  final double bottomInset;
  final double topInset;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onCollapse;
  const _ExpandedPanel({
    required this.t,
    required this.bottomInset,
    required this.topInset,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onCollapse,
  });

  Widget _top(PlayerLayout layout) {
    switch (layout) {
      case PlayerLayout.small:
        return _TopSmall(onCollapse: onCollapse);
      case PlayerLayout.large:
        return _TopLarge(onCollapse: onCollapse);
      case PlayerLayout.xl:
        return _TopXL(onCollapse: onCollapse);
      case PlayerLayout.medium:
        return _TopMedium(onCollapse: onCollapse);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VelvetColors.surface,
      elevation: 12,
      child: Stack(
        children: [
          // Album-art ambient wash (glows in from bottom-right), only visible
          // as the panel expands — the collapsed mini-player stays glow-free.
          Positioned.fill(child: _AmbientLayer(opacity: t)),
          Positioned.fill(
            child: Opacity(
              // Fade the now-playing in slightly after the mini-player starts
              // lifting away, so the swap reads as one motion (fade-through).
              opacity: ((t - 0.1) / 0.9).clamp(0.0, 1.0),
              // Background (Material + ambient) stays edge-to-edge; only the
              // content is inset above the system nav bar.
              child: Padding(
                padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
                child: Column(
                  children: [
                    // The now-playing block doubles as the drag handle; the
                    // queue below scrolls independently. Which block renders is
                    // driven live by the Settings layout choice.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: onDragUpdate,
                      onVerticalDragEnd: onDragEnd,
                      child: StreamBuilder<PlayerLayout>(
                        stream: SettingsManager().playerLayoutStream,
                        initialData: SettingsManager().playerLayout,
                        builder: (context, snap) =>
                            _top(snap.data ?? PlayerLayout.medium),
                      ),
                    ),
                    // NB: deliberately not const — these read theme colours
                    // from the global VelvetColors palette, and a const child is
                    // skipped on rebuild, so it would keep stale text colours
                    // until its own stream next ticked after a theme switch.
                    QueueHeader(),
                    Expanded(child: QueueList()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared header: grab handle + NOW PLAYING + collapse / more.
// ---------------------------------------------------------------------------

class _SheetHeader extends StatelessWidget {
  final VoidCallback onCollapse;
  const _SheetHeader({required this.onCollapse});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha:0.28),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 24),
                color: VelvetColors.textPrimary,
                tooltip: l.goBack,
                onPressed: onCollapse,
              ),
              Expanded(
                child: Text(
                  'NOW PLAYING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 2.3,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 22),
                color: VelvetColors.textPrimary,
                tooltip: l.mainMore,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: VelvetColors.surface,
                    builder: (_) => MoreActionsSheet(parentContext: context),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Layout MEDIUM — art-left banner + slim seek bar (design "Banner", default).
// ---------------------------------------------------------------------------

class _TopMedium extends StatelessWidget {
  final VoidCallback onCollapse;
  const _TopMedium({required this.onCollapse});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(onCollapse: onCollapse),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final item = snap.data;
              final url = item?.extras?['artUrl'] as String?;
              final year = item?.extras?['year']?.toString();
              return Row(
                children: [
                  _albumArt(url, size: 92, radius: 8),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                height: 1.1,
                                color: VelvetColors.textPrimary)),
                        const SizedBox(height: 3),
                        Text(_artistAlbum(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                color: VelvetColors.textSecondary)),
                        if (year != null && year.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(year,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  letterSpacing: 0.3,
                                  color: VelvetColors.textTertiary)),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: _Scrubber(wave: false),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: _TransportControls(playSize: 46),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Layout LARGE — centered medium art + waveform (design "Compact").
// ---------------------------------------------------------------------------

class _TopLarge extends StatelessWidget {
  final VoidCallback onCollapse;
  const _TopLarge({required this.onCollapse});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final art = (w * 0.5).clamp(120.0, 178.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(onCollapse: onCollapse),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 2, 28, 0),
          child: StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final url = snap.data?.extras?['artUrl'] as String?;
              return Center(child: _albumArt(url, size: art, radius: 9));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final item = snap.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: VelvetColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(_artistAlbum(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: VelvetColors.textSecondary)),
                ],
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 10, 22, 0),
          child: _Scrubber(wave: true, waveHeight: 30),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 6, 22, 12),
          child: _TransportControls(playSize: 52),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Layout XL — full hero album art + waveform (design "Current").
// ---------------------------------------------------------------------------

class _TopXL extends StatelessWidget {
  final VoidCallback onCollapse;
  const _TopXL({required this.onCollapse});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final art = (w * 0.56).clamp(150.0, 240.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(onCollapse: onCollapse),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
          child: StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final url = snap.data?.extras?['artUrl'] as String?;
              return Center(
                  child: _albumArt(url, size: art, radius: 10, glowBlur: 38));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: StreamBuilder<MediaItem?>(
            stream: MediaManager().audioHandler.mediaItem,
            builder: (context, snap) {
              final item = snap.data;
              final year = item?.extras?['year']?.toString();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.12,
                          color: VelvetColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(_artistAlbum(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          color: VelvetColors.textSecondary)),
                  if (year != null && year.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(year,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            letterSpacing: 0.3,
                            color: VelvetColors.textTertiary)),
                  ],
                ],
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: _Scrubber(wave: true, waveHeight: 38),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 6, 18, 12),
          child: _TransportControls(playSize: 56, sideSize: 28),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Layout SMALL — slim pill + inline controls, queue dominates (design "Slim").
// ---------------------------------------------------------------------------

class _TopSmall extends StatelessWidget {
  final VoidCallback onCollapse;
  const _TopSmall({required this.onCollapse});

  @override
  Widget build(BuildContext context) {
    final handler = MediaManager().audioHandler;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(onCollapse: onCollapse),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: VelvetColors.raised,
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<MediaItem?>(
            stream: handler.mediaItem,
            builder: (context, snap) {
              final item = snap.data;
              final url = item?.extras?['artUrl'] as String?;
              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                        width: 44,
                        height: 44,
                        child: url != null
                            ? Image.network(url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _fallback(20))
                            : _fallback(20)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: VelvetColors.textPrimary)),
                        if (item?.artist != null)
                          Text(item!.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: VelvetColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 24),
                    color: VelvetColors.textPrimary,
                    onPressed: handler.skipToPrevious,
                  ),
                  StreamBuilder<bool>(
                    stream: handler.playbackState
                        .map((s) => s.playing)
                        .distinct(),
                    builder: (context, snap) {
                      final playing = snap.data ?? false;
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: VelvetColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          color: _kAmberInk,
                          onPressed: playing ? handler.pause : handler.play,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 24),
                    color: VelvetColors.textPrimary,
                    onPressed: handler.skipToNext,
                  ),
                ],
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 2, 22, 8),
          child: _Scrubber(wave: false, showTimes: false, slimHeight: 10),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared transport row: shuffle · prev · play(amber) · next · repeat.
// Repeat cycles none → all → one to match the design.
// ---------------------------------------------------------------------------

class _TransportControls extends StatelessWidget {
  final double playSize;
  final double sideSize;
  const _TransportControls({
    this.playSize = 46,
    this.sideSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final handler = MediaManager().audioHandler;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        StreamBuilder<AudioServiceShuffleMode>(
          stream: handler.playbackState.map((s) => s.shuffleMode).distinct(),
          builder: (context, snap) {
            final on = snap.data == AudioServiceShuffleMode.all;
            return IconButton(
              icon: Icon(Icons.shuffle, size: 20),
              color: on ? VelvetColors.primary : VelvetColors.textTertiary,
              onPressed: () => handler.setShuffleMode(on
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all),
            );
          },
        ),
        IconButton(
          iconSize: sideSize,
          icon: const Icon(Icons.skip_previous),
          color: VelvetColors.textPrimary,
          onPressed: handler.skipToPrevious,
        ),
        StreamBuilder<bool>(
          stream: handler.playbackState.map((s) => s.playing).distinct(),
          builder: (context, snap) {
            final playing = snap.data ?? false;
            return Container(
              width: playSize,
              height: playSize,
              decoration: BoxDecoration(
                color: VelvetColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: VelvetColors.primary.withValues(alpha:0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: IconButton(
                iconSize: playSize * 0.5,
                padding: EdgeInsets.zero,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                color: _kAmberInk,
                onPressed: playing ? handler.pause : handler.play,
              ),
            );
          },
        ),
        IconButton(
          iconSize: sideSize,
          icon: const Icon(Icons.skip_next),
          color: VelvetColors.textPrimary,
          onPressed: handler.skipToNext,
        ),
        StreamBuilder<AudioServiceRepeatMode>(
          stream: handler.playbackState.map((s) => s.repeatMode).distinct(),
          builder: (context, snap) {
            final mode = snap.data ?? AudioServiceRepeatMode.none;
            final on = mode != AudioServiceRepeatMode.none;
            return IconButton(
              icon: Icon(
                  mode == AudioServiceRepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  size: 20),
              color: on ? VelvetColors.primary : VelvetColors.textTertiary,
              onPressed: () {
                final next = mode == AudioServiceRepeatMode.none
                    ? AudioServiceRepeatMode.all
                    : mode == AudioServiceRepeatMode.all
                        ? AudioServiceRepeatMode.one
                        : AudioServiceRepeatMode.none;
                handler.setRepeatMode(next);
              },
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scrubber: a waveform (Large/XL) or slim seek bar (Medium/Small), with an
// optional mono time row.
// ---------------------------------------------------------------------------

class _Scrubber extends StatelessWidget {
  final bool wave;
  final double waveHeight;
  final bool showTimes;
  final double slimHeight;
  const _Scrubber({
    this.wave = false,
    this.waveHeight = 30,
    this.showTimes = true,
    this.slimHeight = 16,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_MediaPos>(
      stream: _mediaPosStream(),
      builder: (context, snap) {
        final item = snap.data?.item;
        final pos = snap.data?.position ?? Duration.zero;
        final dur = item?.duration;
        final ratio = (dur == null || dur.inMilliseconds == 0)
            ? 0.0
            : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
        void seek(double f) => MediaManager().audioHandler.seek(
            Duration(milliseconds: ((dur?.inMilliseconds ?? 0) * f).toInt()));

        final scrub = wave
            ? WaveformProgress(
                height: waveHeight,
                progress: ratio,
                seed: item?.id,
                onSeek: dur == null ? null : seek)
            : _SeekBar(
                ratio: ratio, height: slimHeight, onSeek: dur == null ? null : seek);

        if (!showTimes) return scrub;

        final right = dur == null
            ? ''
            : (wave ? '-${_fmt(_remaining(dur, pos))}' : _fmt(dur));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            scrub,
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(pos),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: VelvetColors.primary)),
                Text(right,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: VelvetColors.textTertiary)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Thin amber seek bar with a draggable knob (design "ProgressBar").
class _SeekBar extends StatelessWidget {
  final double ratio;
  final double height;
  final ValueChanged<double>? onSeek;
  const _SeekBar({required this.ratio, this.height = 16, this.onSeek});

  @override
  Widget build(BuildContext context) {
    final r = ratio.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        void handle(double dx) => onSeek?.call((dx / w).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => handle(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => handle(d.localPosition.dx),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // track
                Positioned(
                  left: 0,
                  right: 0,
                  top: height / 2 - 2,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // fill
                Positioned(
                  left: 0,
                  top: height / 2 - 2,
                  height: 4,
                  width: w * r,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: VelvetColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // knob
                Positioned(
                  left: (w * r) - 5,
                  top: height / 2 - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: VelvetColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: VelvetColors.primary.withValues(alpha:0.2),
                            blurRadius: 0,
                            spreadRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Album-art ambient background (glows from bottom-right, expanded-only).
// ---------------------------------------------------------------------------

class _AmbientLayer extends StatefulWidget {
  final double opacity;
  const _AmbientLayer({required this.opacity});

  @override
  State<_AmbientLayer> createState() => _AmbientLayerState();
}

class _AmbientLayerState extends State<_AmbientLayer> {
  StreamSubscription<String?>? _sub;
  String? _url;
  Color? _seed;

  @override
  void initState() {
    super.initState();
    _sub = MediaManager()
        .audioHandler
        .mediaItem
        .map((m) => m?.extras?['artUrl'] as String?)
        .distinct()
        .listen(_onUrl);
  }

  Future<void> _onUrl(String? url) async {
    _url = url;
    if (url == null) {
      if (mounted) setState(() => _seed = null);
      return;
    }
    // Prefer the vibrant swatch (Spotify-style); fall back to the dominant
    // field colour when the art has no saturated region. The gradient (and its
    // anchor) is built in build() so it tracks the chosen layout live.
    final seed = await dominantAlbumColor(url, vibrant: true) ??
        await dominantAlbumColor(url);
    if (!mounted || url != _url) return;
    setState(() => _seed = seed);
  }

  // Left-aligned art (banner / slim pill) reads best with the glow entering
  // from the top-left corner; centred art (compact / hero) wants top-centre.
  Alignment _ambientCenter(PlayerLayout layout) {
    switch (layout) {
      case PlayerLayout.small:
      case PlayerLayout.medium:
        return Alignment.topLeft;
      case PlayerLayout.large:
      case PlayerLayout.xl:
        return Alignment.topCenter;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: StreamBuilder<PlayerLayout>(
          stream: SettingsManager().playerLayoutStream,
          initialData: SettingsManager().playerLayout,
          builder: (context, snap) {
            final seed = _seed;
            final grad = seed == null
                ? null
                : ambientGradient(seed,
                    base: VelvetColors.surface,
                    vibrant: true,
                    center: _ambientCenter(snap.data ?? PlayerLayout.medium));
            return AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              decoration: BoxDecoration(gradient: grad),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsed mini-player (no album-art glow, per the design).
// ---------------------------------------------------------------------------

class _MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  const _MiniPlayer({
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  Widget _btn(IconData icon, VoidCallback onPressed, {bool active = false}) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 36),
      color: active ? VelvetColors.primary : VelvetColors.appBarText,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final handler = MediaManager().audioHandler;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Material(
        color: VelvetColors.appBarBg,
        elevation: 10,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lip / grab handle — signals the bar can be pulled up.
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 5),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Title · artist + position / duration.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 3),
              child: StreamBuilder<_MediaPos>(
                stream: _mediaPosStream(),
                builder: (context, snap) {
                  final item = snap.data?.item;
                  final pos = snap.data?.position ?? Duration.zero;
                  final dur = item?.duration;
                  return SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item == null
                                ? ''
                                : (item.artist == null
                                    ? item.title
                                    : '${item.title}  ·  ${item.artist}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: VelvetColors.appBarText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dur == null
                              ? _fmt(pos)
                              : '${_fmt(pos)} / ${_fmt(dur)}',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              color: VelvetColors.appBarTextSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Seekable waveform (the "original" mStream bottom-bar scrubber).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: StreamBuilder<_MediaPos>(
                stream: _mediaPosStream(),
                builder: (context, snap) {
                  final item = snap.data?.item;
                  final pos = snap.data?.position ?? Duration.zero;
                  final dur = item?.duration;
                  final ratio = (dur == null || dur.inMilliseconds == 0)
                      ? 0.0
                      : (pos.inMilliseconds / dur.inMilliseconds)
                          .clamp(0.0, 1.0);
                  return WaveformProgress(
                    height: 18,
                    progress: ratio,
                    seed: item?.id,
                    onSeek: dur == null
                        ? null
                        : (f) => handler.seek(Duration(
                            milliseconds: (dur.inMilliseconds * f).toInt())),
                  );
                },
              ),
            ),
            // Transport row — flat icons like the original bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _btn(Icons.skip_previous, handler.skipToPrevious),
                    StreamBuilder<bool>(
                      stream: handler.playbackState
                          .map((s) => s.playing)
                          .distinct(),
                      builder: (context, snap) {
                        final playing = snap.data ?? false;
                        return _btn(playing ? Icons.pause : Icons.play_arrow,
                            playing ? handler.pause : handler.play);
                      },
                    ),
                    _btn(Icons.skip_next, handler.skipToNext),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    StreamBuilder<AudioServiceShuffleMode>(
                      stream: handler.playbackState
                          .map((s) => s.shuffleMode)
                          .distinct(),
                      builder: (context, snap) {
                        final on = snap.data == AudioServiceShuffleMode.all;
                        return _btn(
                            Icons.shuffle,
                            () => handler.setShuffleMode(on
                                ? AudioServiceShuffleMode.none
                                : AudioServiceShuffleMode.all),
                            active: on);
                      },
                    ),
                    StreamBuilder<AudioServiceRepeatMode>(
                      stream: handler.playbackState
                          .map((s) => s.repeatMode)
                          .distinct(),
                      builder: (context, snap) {
                        final mode = snap.data ?? AudioServiceRepeatMode.none;
                        final on = mode != AudioServiceRepeatMode.none;
                        return _btn(
                            mode == AudioServiceRepeatMode.one
                                ? Icons.repeat_one
                                : Icons.repeat, () {
                          final next = mode == AudioServiceRepeatMode.none
                              ? AudioServiceRepeatMode.all
                              : mode == AudioServiceRepeatMode.all
                                  ? AudioServiceRepeatMode.one
                                  : AudioServiceRepeatMode.none;
                          handler.setRepeatMode(next);
                        }, active: on);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 38, minHeight: 36),
                      color: VelvetColors.appBarTextSecondary,
                      tooltip: l.mainMore,
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: VelvetColors.surface,
                        builder: (_) => MoreActionsSheet(parentContext: context),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers.
// ---------------------------------------------------------------------------

Widget _albumArt(String? url,
    {required double size, double radius = 8, double glowBlur = 22}) {
  Widget fallback() => _fallback(size * 0.5);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha:0.5),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.13)),
        BoxShadow(
            color: VelvetColors.primary.withValues(alpha:0.18),
            blurRadius: glowBlur,
            spreadRadius: -4),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url != null
          ? Image.network(url,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback())
          : fallback(),
    ),
  );
}

Widget _fallback(double size) => Container(
      color: VelvetColors.raised,
      child:
          Icon(Icons.music_note, color: VelvetColors.textSecondary, size: size),
    );

String _artistAlbum(MediaItem? item) {
  if (item == null) return '';
  final a = item.artist, al = item.album;
  if (a != null && al != null) return '$a · $al';
  return a ?? al ?? '';
}

Duration _remaining(Duration dur, Duration pos) {
  final r = dur - pos;
  return r.isNegative ? Duration.zero : r;
}

class _MediaPos {
  final MediaItem? item;
  final Duration position;
  const _MediaPos(this.item, this.position);
}

Stream<_MediaPos> _mediaPosStream() =>
    Rx.combineLatest2<MediaItem?, Duration, _MediaPos>(
      MediaManager().audioHandler.mediaItem,
      MediaManager().audioHandler.positionStream,
      (item, pos) => _MediaPos(item, pos),
    );

String _fmt(Duration d) {
  final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
}
