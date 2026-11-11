import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../widgets/player_panel.dart';
import 'keep_copy_ui.dart' show keepInkOn;

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
/// A toast may carry one action ([KeepToast.show]'s `action`: a copy's
/// start toast offers "View", the Copies sheet): a 44 pt text button at its
/// right, outside the tap that dismisses it, announced to a screen reader;
/// while the screen reader navigates (MediaQuery.accessibleNavigation) a
/// toast with an action stays until it is closed (its ✕) or replaced.
///
/// [KeepToast.debugSink] catches them instead (tests) — and
/// [KeepToast.debugActionSink] the action of one that has one; without a
/// context and before the app's navigator is up, a toast is dropped.
class KeepToast {
  KeepToast._();

  /// How long one shows.
  static const Duration kShowFor = Duration(seconds: 4);

  /// The toast's ground, every palette.
  static const Color kGround = Color(0xFF323232);

  /// Set by tests: every toast lands here instead of on screen.
  static void Function(String message, {bool success})? debugSink;

  /// Set by tests beside [debugSink]: a toast's action, its label and what
  /// it does.
  static void Function(String message, String action, VoidCallback onAction)?
      debugActionSink;

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// Show [message] ([success] leads it with a green check: "Saved · …").
  /// [action] / [onAction] add its one button ("View"); a tap on it takes
  /// the toast down and runs [onAction]. [context] picks the overlay;
  /// without one the app's root navigator's.
  static void show(
    BuildContext? context,
    String message, {
    bool success = false,
    String? action,
    VoidCallback? onAction,
  }) {
    final act = action != null && onAction != null;
    final sink = debugSink;
    if (sink != null) {
      sink(message, success: success);
      if (act) debugActionSink?.call(message, action, onAction);
      return;
    }
    OverlayState? overlay;
    if (context != null && context.mounted) {
      overlay = Overlay.maybeOf(context, rootOverlay: true);
    }
    overlay ??= rootNavigatorKey.currentState?.overlay;
    if (overlay == null || !overlay.mounted) return;
    dismiss();
    final ctx = overlay.context;
    final held =
        act && (MediaQuery.maybeOf(ctx)?.accessibleNavigation ?? false);
    final entry = OverlayEntry(
      builder: (_) => _KeepToastView(
        message: message,
        success: success,
        action: act ? action : null,
        onAction: act ? onAction : null,
        closable: held,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    if (!held) _timer = Timer(kShowFor, dismiss);
    if (act) {
      // An action toast is no live region (it would be read twice): it is
      // announced once, here.
      final view = View.maybeOf(ctx);
      if (view != null) {
        unawaited(SemanticsService.sendAnnouncement(
          view,
          message,
          Directionality.maybeOf(ctx) ?? TextDirection.ltr,
        ));
      }
    }
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
  final String? action;
  final VoidCallback? onAction;

  /// It stays until closed: a ✕ of its own.
  final bool closable;

  const _KeepToastView({
    required this.message,
    required this.success,
    this.action,
    this.onAction,
    this.closable = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final act = action;
    return Positioned(
      left: 16,
      right: 16,
      bottom: PlayerPanel.kCollapsedHeight + mq.viewPadding.bottom + 8,
      child: Semantics(
        liveRegion: act == null,
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
                color: KeepToast.kGround,
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
                // With a button at its right, the button's own 44 pt band
                // makes the toast's height.
                padding: act == null && !closable
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                    : const EdgeInsets.fromLTRB(16, 4, 4, 4),
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: act == null && !closable ? 0 : 10,
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFFEEEEEE),
                            fontSize: 14,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                    if (act != null)
                      TextButton(
                        key: const ValueKey('keep-toast-action'),
                        onPressed: () {
                          KeepToast.dismiss();
                          onAction?.call();
                        },
                        style: TextButton.styleFrom(
                          // The primary's ink as it reads on the toast's
                          // own ground (Light's amber too).
                          foregroundColor: keepInkOn(KeepToast.kGround),
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(act),
                      ),
                    if (closable)
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          key: const ValueKey('keep-toast-close'),
                          tooltip: AppLocalizations.of(context).close,
                          padding: EdgeInsets.zero,
                          onPressed: KeepToast.dismiss,
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: Color(0xFFEEEEEE),
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
