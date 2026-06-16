import 'package:flutter/material.dart';

import 'admin_api.dart';

/// Shared building blocks for the admin views. Keeping the common patterns
/// (load-with-retry, async toggle, labelled save-field, section card) here is
/// what lets each of the ~14 views stay short and declarative.

/// SnackBar helper that survives `await` gaps (captures the messenger first).
void adminToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? scheme.errorContainer : null,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Runs [action], toasts [success] on completion or the error message on
/// failure. Returns true on success. Used by every mutating control.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) adminToast(context, success);
    return true;
  } on AdminApiException catch (e) {
    if (context.mounted) adminToast(context, e.message, error: true);
    return false;
  } catch (e) {
    if (context.mounted) adminToast(context, '$e', error: true);
    return false;
  }
}

/// FutureBuilder with consistent loading / error-retry chrome and a [reload]
/// callback passed to the data builder.
class AdminAsync<T> extends StatefulWidget {
  final Future<T> Function() loader;
  final Widget Function(BuildContext, T, Future<void> Function()) builder;
  const AdminAsync({super.key, required this.loader, required this.builder});

  @override
  State<AdminAsync<T>> createState() => _AdminAsyncState<T>();
}

class _AdminAsyncState<T> extends State<AdminAsync<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.loader());
    await _future.catchError((_) => null as T);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return AdminErrorRetry(error: snap.error!, onRetry: _reload);
        }
        return widget.builder(context, snap.data as T, _reload);
      },
    );
  }
}

class AdminErrorRetry extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const AdminErrorRetry({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: scheme.error, size: 40),
          const SizedBox(height: 12),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}

/// A titled section card. Views are built by stacking these in a scroll view.
class AdminCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final List<Widget>? trailing;
  const AdminCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (icon != null) ...[
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              ...?trailing,
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A switch whose change drives an async server call. Flips optimistically and
/// reverts (with a toast) if the call fails.
class AdminAsyncSwitch extends StatefulWidget {
  final bool value;
  final String title;
  final String? subtitle;
  final Future<void> Function(bool) onChanged;
  final bool enabled;
  const AdminAsyncSwitch({
    super.key,
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  @override
  State<AdminAsyncSwitch> createState() => _AdminAsyncSwitchState();
}

class _AdminAsyncSwitchState extends State<AdminAsyncSwitch> {
  late bool _value = widget.value;
  bool _busy = false;

  @override
  void didUpdateWidget(AdminAsyncSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  Future<void> _toggle(bool v) async {
    setState(() {
      _value = v;
      _busy = true;
    });
    final ok = await runAdminAction(context, () => widget.onChanged(v));
    if (!mounted) return;
    setState(() {
      if (!ok) _value = !v;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      secondary: _busy
          ? const SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      value: _value,
      onChanged: (widget.enabled && !_busy) ? _toggle : null,
    );
  }
}

/// Labelled text/number field with an inline Save button that calls an async
/// setter. Used for address, names, ports, sizes, etc.
class AdminSaveField extends StatefulWidget {
  final String label;
  final String initialValue;
  final String? helperText;
  final bool number;
  final bool obscure;
  final Future<void> Function(String) onSave;
  final String savedMessage;
  const AdminSaveField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onSave,
    this.helperText,
    this.number = false,
    this.obscure = false,
    this.savedMessage = 'Saved',
  });

  @override
  State<AdminSaveField> createState() => _AdminSaveFieldState();
}

class _AdminSaveFieldState extends State<AdminSaveField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);
  bool _busy = false;

  @override
  void didUpdateWidget(AdminSaveField old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue && !_busy) {
      _ctrl.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await runAdminAction(context, () => widget.onSave(_ctrl.text.trim()),
        success: widget.savedMessage);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            obscureText: widget.obscure,
            keyboardType:
                widget.number ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: widget.helperText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ),
      ]),
    );
  }
}

/// Labelled dropdown that drives an async setter.
class AdminDropdownRow<T> extends StatefulWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final Future<void> Function(T) onChanged;
  const AdminDropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<AdminDropdownRow<T>> createState() => _AdminDropdownRowState<T>();
}

class _AdminDropdownRowState<T> extends State<AdminDropdownRow<T>> {
  late T _value = widget.value;
  bool _busy = false;

  @override
  void didUpdateWidget(AdminDropdownRow<T> old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(widget.label)),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        DropdownButton<T>(
          value: _value,
          items: widget.items,
          onChanged: _busy
              ? null
              : (v) async {
                  if (v == null) return;
                  final prev = _value;
                  setState(() {
                    _value = v;
                    _busy = true;
                  });
                  final ok = await runAdminAction(
                      context, () => widget.onChanged(v),
                      success: 'Saved');
                  if (!mounted) return;
                  setState(() {
                    if (!ok) _value = prev;
                    _busy = false;
                  });
                },
        ),
      ]),
    );
  }
}

/// A button that shows a spinner while its async [onPressed] runs.
class AdminActionButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function() onPressed;
  final bool tonal;
  final bool destructive;
  final String? success;
  const AdminActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tonal = false,
    this.destructive = false,
    this.success,
  });

  @override
  State<AdminActionButton> createState() => _AdminActionButtonState();
}

class _AdminActionButtonState extends State<AdminActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    await runAdminAction(context, widget.onPressed, success: widget.success);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = _busy
        ? const SizedBox(
            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : (widget.icon != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, size: 18),
                const SizedBox(width: 6),
                Text(widget.label),
              ])
            : Text(widget.label));
    final onPressed = _busy ? null : _run;
    if (widget.destructive) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
        onPressed: onPressed,
        child: child,
      );
    }
    return widget.tonal
        ? FilledButton.tonal(onPressed: onPressed, child: child)
        : FilledButton(onPressed: onPressed, child: child);
  }
}

/// Small status badge (connected/disconnected, enabled/disabled, etc.).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusPill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Read-only label/value row.
class AdminInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const AdminInfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: SelectableText(value)),
      ]),
    );
  }
}

/// Standard outer padding + max-width clamp so views read well on a wide web
/// window as well as a phone. Wrap each view's scroll body with this.
class AdminViewBody extends StatelessWidget {
  final List<Widget> children;
  const AdminViewBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final child in children) ...[child, const SizedBox(height: 16)],
          ],
        ),
      ),
    );
  }
}
