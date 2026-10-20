import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../singletons/app_messenger.dart';
import '../../widgets/player_panel.dart';

/// The copy surfaces' toast (the design canvas's PhoneCopies /
/// PhoneElsewhere / PhoneDestination boards): one floating line, 16 px from
/// the sides and 8 px above the docked mini player, on #323232 with
/// #EEEEEE text (every palette), radius 10.
///
/// It is drawn in the ROOT overlay, above every route, so a sheet that stays
/// open (the Copies sheet's "Already finished", the picker's "Saved", Open
/// elsewhere's "Couldn't open that link") hosts it in the standard slot
/// rather than hiding it under its own barrier the way a Scaffold's
/// SnackBar would be. One at a time: a new toast replaces the one showing.
///
/// [KeepToast.debugSink] catches them instead (tests); without a context and
/// before the app's navigator is up, a toast is dropped.
class KeepToast {
  KeepToast._();

  /// How long one shows.
  static const Duration kShowFor = Duration(seconds: 4);

  /// Set by tests: every toast lands here instead of on screen.
  static void Function(String message, {bool success})? debugSink;

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// Show [message] ([success] leads it with a green check: "Saved · …").
  /// [context] picks the overlay; without one the app's root navigator's.
  static void show(
    BuildContext? context,
    String message, {
    bool success = false,
  }) {
    final sink = debugSink;
    if (sink != null) {
      sink(message, success: success);
      return;
    }
    OverlayState? overlay;
    if (context != null && context.mounted) {
      overlay = Overlay.maybeOf(context, rootOverlay: true);
    }
    overlay ??= rootNavigatorKey.currentState?.overlay;
    if (overlay == null || !overlay.mounted) return;
    dismiss();
    final entry = OverlayEntry(
      builder: (ctx) => _KeepToastView(message: message, success: success),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(kShowFor, dismiss);
  }

  /// Take the toast down now (a tap on it, or the next toast).
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }

  /// Whether one is up (tests).
  static bool get showing => _entry != null;
}

class _KeepToastView extends StatelessWidget {
  final String message;
  final bool success;
  const _KeepToastView({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: PlayerPanel.kCollapsedHeight + mq.viewPadding.bottom + 8,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: GestureDetector(
          onTap: KeepToast.dismiss,
          // An overlay entry has no Material above it: this one sets the
          // text's ground.
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              key: const ValueKey('keep-toast'),
              decoration: BoxDecoration(
                color: const Color(0xFF323232),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    if (success) ...[
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Color(0xFF34D399),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFEEEEEE),
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
