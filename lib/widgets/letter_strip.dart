// Vertical A-Z scrubber overlaid on the right edge of a list/grid.
//
// Tap or drag a letter to jump to the first item whose displayed
// text starts with that letter. Letters with no matching items
// render dim but still snap to the nearest present letter when
// touched, so no input is dead.
//
// UX details borrowed from polished community impls (azlistview &
// friends):
//   * Floating letter bubble overlay during interaction (iOS-contacts
//     pattern) — anchored near the finger via Overlay/OverlayEntry,
//     updated with markNeedsBuild rather than recreated per frame.
//   * Haptic tick (selectionClick) when the active letter changes,
//     not on every drag pixel.
//   * Hit region wider than the visible strip — finger comfort.
//   * Subtle background tint on the strip while active — gives it
//     "weight" during interaction.
//   * jumpTo (instant) not animateTo — scrubbing should track the
//     finger, not chase it.
//
// Index work is decoupled from scroll mechanics: this widget emits
// "jump to item N" via [onJump] and the parent decides the actual
// scroll offset, so the same strip works above a ListView, a
// GridView, or anything else with a ScrollController.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../objects/display_item.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';

class LetterStrip extends StatefulWidget {
  // Hide the strip when the list is short enough that quick-scrolling
  // isn't useful — the user can just thumb-scroll. Reads from the
  // user's setting so it can be tuned at runtime (Settings → Browse
  // → "Letter scrubber threshold"). Public so other widgets (notably
  // the browser's row builders) can mirror the cutoff: small lists,
  // with no letter strip, are free to wrap long titles.
  static int get minItemsToShow => SettingsManager().letterStripThreshold;

  /// Width of the strip's hit region (the visible letters are narrower, but the
  /// gesture area extends left for an easier touch target).
  static const double hitWidth = 40;

  /// Width of the *visible* strip (right-aligned within [hitWidth]). Rows reserve
  /// this much on their right so content clears the letters; the extra
  /// [hitWidth] − [visibleWidth] of touch margin stays tappable but transparent,
  /// so trailing controls can sit right up against the visible strip.
  static const double visibleWidth = 24;

  final List<DisplayItem> items;
  final void Function(int itemIndex) onJump;

  const LetterStrip({
    super.key,
    required this.items,
    required this.onJump,
  });

  @override
  State<LetterStrip> createState() => _LetterStripState();
}

class _LetterStripState extends State<LetterStrip> {

  // '#' catches digits, punctuation, and non-Latin starting chars so
  // the strip stays a fixed 27 cells regardless of dataset.
  static const _letters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', //
    'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', //
    'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  Map<String, int> _firstIndexByLetter = const {};
  // Two letters tracked separately so taps on empty letters are
  // honest: strip highlight follows the finger, bubble shows the
  // actual destination. They match for present letters and diverge
  // for empty ones (e.g. finger on 'Q' in a library with no Q
  // albums → strip shows Q, bubble + scroll go to the nearest
  // present letter).
  // Drives the strip highlight. A ValueNotifier (not setState) so a drag tick
  // rebuilds only the strip subtree via a ValueListenableBuilder — not the whole
  // widget (the LayoutBuilder / GestureDetector and all 27 cells from scratch).
  final ValueNotifier<String?> _touched = ValueNotifier<String?>(null);
  // Destination letter shown in the floating bubble. Read only by the overlay
  // (refreshed via markNeedsBuild), so it stays a plain field — no rebuild.
  String? _snapped;
  Offset _fingerGlobalPos = Offset.zero;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _firstIndexByLetter = _buildIndex(widget.items);
  }

  @override
  void didUpdateWidget(LetterStrip old) {
    super.didUpdateWidget(old);
    _firstIndexByLetter = _buildIndex(widget.items);
  }

  @override
  void dispose() {
    _hideOverlay();
    _touched.dispose();
    super.dispose();
  }

  static Map<String, int> _buildIndex(List<DisplayItem> items) {
    final map = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final letter = _firstLetter(items[i]);
      map.putIfAbsent(letter, () => i);
    }
    return map;
  }

  // Mirrors DisplayItem.getText's fallback chain so the letter the
  // strip indexes by matches what the user actually sees on the row.
  static String _firstLetter(DisplayItem item) {
    String text;
    if (item.metadata?.title != null) {
      text = item.metadata!.title!;
    } else if (item.type == 'file' || item.type == 'localFile') {
      text = item.data?.split('/').last ?? item.name;
    } else {
      text = item.name;
    }
    if (text.isEmpty) return '#';
    final c = text[0].toUpperCase();
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ? c : '#';
  }

  int? _nearestIndex(String letter) {
    if (_firstIndexByLetter.containsKey(letter)) {
      return _firstIndexByLetter[letter];
    }
    final pos = _letters.indexOf(letter);
    if (pos == -1) return null;
    for (var d = 1; d < _letters.length; d++) {
      final after = pos + d;
      if (after < _letters.length &&
          _firstIndexByLetter.containsKey(_letters[after])) {
        return _firstIndexByLetter[_letters[after]];
      }
      final before = pos - d;
      if (before >= 0 &&
          _firstIndexByLetter.containsKey(_letters[before])) {
        return _firstIndexByLetter[_letters[before]];
      }
    }
    return null;
  }

  void _showOverlay(BuildContext context) {
    if (_overlay != null) return;
    _overlay = OverlayEntry(builder: _buildBubble);
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildBubble(BuildContext context) {
    // Bubble sits to the LEFT of the finger so the finger isn't
    // occluding it. Clamp so it never spills past the left edge on
    // narrow screens.
    final screenW = MediaQuery.of(context).size.width;
    final left = (_fingerGlobalPos.dx - 110).clamp(16.0, screenW - 96.0);
    final top = (_fingerGlobalPos.dy - 40).clamp(40.0, double.infinity);
    return Positioned(
      left: left,
      top: top,
      // IgnorePointer so the overlay can't steal gestures from the
      // strip we're trying to drive.
      child: IgnorePointer(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: VelvetColors.primary,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _snapped ?? '',
              style: TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTouch(
      Offset localPos, Offset globalPos, double height, BuildContext context) {
    final perLetter = height / _letters.length;
    final i =
        (localPos.dy / perLetter).floor().clamp(0, _letters.length - 1);
    final touched = _letters[i];

    final itemIndex = _nearestIndex(touched);
    if (itemIndex == null) return;
    // Derive the snapped letter from the actual landed item rather
    // than re-running the nearest-letter search — keeps strip and
    // bubble guaranteed consistent with the scroll target.
    final snapped = _firstLetter(widget.items[itemIndex]);

    _fingerGlobalPos = globalPos;
    final snappedChanged = snapped != _snapped;
    // Only [_touched] drives a rebuild (the strip highlight). [_snapped] feeds
    // the overlay bubble, refreshed below via markNeedsBuild — not setState.
    if (touched != _touched.value) _touched.value = touched;
    if (snappedChanged) _snapped = snapped;

    // Haptic only when we actually move to a new section — crossing
    // empty letters that snap to the same destination should feel
    // silent, not buzz repeatedly.
    if (snappedChanged) {
      HapticFeedback.selectionClick();
    }

    if (_overlay == null) {
      _showOverlay(context);
    } else {
      _overlay!.markNeedsBuild();
    }

    widget.onJump(itemIndex);
  }

  void _clearActive() {
    _touched.value = null; // ValueNotifier no-ops if already null
    _snapped = null;
    _hideOverlay();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty ||
        widget.items.length < LetterStrip.minItemsToShow) {
      return SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) =>
              _handleTouch(d.localPosition, d.globalPosition, h, context),
          onTapUp: (_) => _clearActive(),
          onTapCancel: _clearActive,
          onVerticalDragStart: (d) =>
              _handleTouch(d.localPosition, d.globalPosition, h, context),
          onVerticalDragUpdate: (d) =>
              _handleTouch(d.localPosition, d.globalPosition, h, context),
          onVerticalDragEnd: (_) => _clearActive(),
          onVerticalDragCancel: _clearActive,
          // Outer SizedBox = hit region (40 wide); inner Container =
          // visible strip (24 wide, right-aligned). Gives the finger
          // ~16px of extra reach to the left of the letters without
          // pushing the visible strip away from the edge.
          child: SizedBox(
            width: LetterStrip.hitWidth,
            child: Align(
              alignment: Alignment.centerRight,
              // Rebuild only the strip (tint + active cell) as the finger moves,
              // via [_touched] — not the enclosing LayoutBuilder/GestureDetector.
              child: ValueListenableBuilder<String?>(
                valueListenable: _touched,
                builder: (context, touched, _) {
                  final active = touched != null;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 120),
                    width: LetterStrip.visibleWidth,
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? VelvetColors.surface.withValues(alpha: 0.7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _letters.map((letter) {
                        final present =
                            _firstIndexByLetter.containsKey(letter);
                        final isActive = letter == touched;
                        return Text(
                          letter,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isActive ? FontWeight.w900 : FontWeight.w600,
                            color: isActive
                                ? VelvetColors.primary
                                : (present
                                    ? VelvetColors.textPrimary
                                    : VelvetColors.textTertiary),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
