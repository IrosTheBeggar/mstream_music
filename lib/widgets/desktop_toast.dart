import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/velvet_theme.dart';

/// Desktop corner toasts — the Windows / VS Code / Slack convention: a compact
/// card in the bottom-right, floating over content, stacked and auto-dismissed.
/// Replaces SnackBars on desktop, which render full-width across the window
/// bottom and covered the Now Playing bar. [showGlobalSnack] routes here when
/// a host is mounted; the host lives in DesktopShell, positioned just above
/// the bar so transport controls are never obscured.
class DesktopToasts {
  DesktopToasts._();
  static final DesktopToasts instance = DesktopToasts._();

  final ValueNotifier<List<ToastEntry>> entries =
      ValueNotifier<List<ToastEntry>>(const []);
  int _nextId = 0;
  int _hosts = 0;

  /// Whether a [DesktopToastHost] is mounted (i.e. the desktop shell is up).
  /// When false — phone layout, or a narrow desktop window — callers should
  /// fall back to a regular SnackBar.
  bool get hasHost => _hosts > 0;

  void show(String message) {
    final t = ToastEntry(_nextId++, message);
    entries.value = [...entries.value, t];
    // A beat longer than SnackBar's 4s default: corner toasts are further from
    // the user's focus than a bottom-center bar, so give them time to be seen.
    t.timer = Timer(const Duration(seconds: 5), () => dismiss(t));
  }

  void dismiss(ToastEntry t) {
    t.timer?.cancel();
    if (!entries.value.contains(t)) return;
    entries.value = [
      for (final e in entries.value)
        if (!identical(e, t)) e
    ];
  }

  void _attach() => _hosts++;
  void _detach() => _hosts--;
}

class ToastEntry {
  final int id;
  final String message;
  Timer? timer;
  ToastEntry(this.id, this.message);
}

/// Renders the active toasts as a bottom-right column. Mount exactly one, in a
/// Stack layer over the desktop shell; position via the surrounding Positioned.
class DesktopToastHost extends StatefulWidget {
  const DesktopToastHost({super.key});

  @override
  State<DesktopToastHost> createState() => _DesktopToastHostState();
}

class _DesktopToastHostState extends State<DesktopToastHost> {
  @override
  void initState() {
    super.initState();
    DesktopToasts.instance._attach();
  }

  @override
  void dispose() {
    DesktopToasts.instance._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ToastEntry>>(
      valueListenable: DesktopToasts.instance.entries,
      builder: (context, toasts, _) {
        if (toasts.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in toasts)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ToastCard(
                  key: ValueKey(t.id),
                  entry: t,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ToastCard extends StatelessWidget {
  final ToastEntry entry;
  const _ToastCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    // Slide-up + fade entry; removal is instant (a transient toast doesn't
    // earn an exit animation's bookkeeping).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: VelvetColors.raised,
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: VelvetColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 17, color: VelvetColors.primary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    entry.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13, color: VelvetColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => DesktopToasts.instance.dismiss(entry),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        size: 15, color: VelvetColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
