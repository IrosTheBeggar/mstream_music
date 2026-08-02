// hotkeys_dialog.dart — the Keyboard Shortcuts editor (Settings > Desktop).
//
// The Flutter twin of the web player's Keyboard Shortcuts modal: a master
// toggle, one row per action showing its current keycap, and per-row
// Change / Clear / Restore. Pressing Change arms capture — the next key
// press becomes the binding, Escape cancels. One combo maps to one action,
// so assigning a taken combo unbinds the other (the row goes to "None" and
// offers Restore). Bindings live in HotkeyManager and persist through
// SettingsManager.saveHotkeys().

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/hotkeys.dart';

Future<void> showHotkeysDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _HotkeysDialog(),
  );
}

// Editor row labels. Kept here (not the ARB files) alongside the other
// desktop-only settings copy.
const Map<HotkeyAction, String> _actionLabels = {
  HotkeyAction.playPause: 'Play / Pause',
  HotkeyAction.playPauseAlt: 'Play / Pause (alternate)',
  HotkeyAction.seekBack: 'Seek back 10 seconds',
  HotkeyAction.seekForward: 'Seek forward 10 seconds',
  HotkeyAction.bigSeekBack: 'Seek back 30 seconds',
  HotkeyAction.bigSeekForward: 'Seek forward 30 seconds',
  HotkeyAction.prevTrack: 'Previous track',
  HotkeyAction.nextTrack: 'Next track',
  HotkeyAction.percentSeek: 'Jump to 0–90% of track',
  HotkeyAction.volumeUp: 'Volume up',
  HotkeyAction.volumeDown: 'Volume down',
  HotkeyAction.mute: 'Mute / Unmute',
  HotkeyAction.shuffle: 'Toggle shuffle',
  HotkeyAction.repeat: 'Toggle repeat',
  HotkeyAction.openSearch: 'Open search',
  HotkeyAction.localFilter: 'Filter the current list',
};

class _HotkeysDialog extends StatefulWidget {
  const _HotkeysDialog();

  @override
  State<_HotkeysDialog> createState() => _HotkeysDialogState();
}

class _HotkeysDialogState extends State<_HotkeysDialog> {
  final HotkeyManager _keys = HotkeyManager.instance;
  final FocusNode _captureFocus = FocusNode();
  HotkeyAction? _capturing;

  @override
  void dispose() {
    _captureFocus.dispose();
    super.dispose();
  }

  void _beginCapture(HotkeyAction action) {
    setState(() => _capturing = action);
    _captureFocus.requestFocus();
  }

  KeyEventResult _onCaptureKey(KeyEvent event) {
    if (event is! KeyDownEvent || _capturing == null) {
      return KeyEventResult.ignored;
    }
    final combo = HotkeyCombo.fromEvent(event);
    // null = a bare modifier (keep waiting) or Escape (cancel).
    if (combo == null) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _capturing = null);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    _assign(_capturing!, combo);
    return KeyEventResult.handled;
  }

  Future<void> _assign(HotkeyAction action, HotkeyCombo? combo) async {
    setState(() {
      _keys.assign(action, combo);
      _capturing = null;
    });
    await SettingsManager().saveHotkeys();
  }

  Future<void> _restoreAll() async {
    setState(() {
      _keys.restoreDefaults();
      _capturing = null;
    });
    await SettingsManager().saveHotkeys();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = SettingsManager().hotkeysEnabled;
    return AlertDialog(
      backgroundColor: VelvetColors.surface,
      title: Text('Keyboard Shortcuts',
          style: TextStyle(color: VelvetColors.textPrimary)),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      content: SizedBox(
        width: 520,
        // Capture listens at the dialog level so a press lands wherever the
        // pointer is; rows are plain widgets.
        child: Focus(
          focusNode: _captureFocus,
          onKeyEvent: (_, event) => _onCaptureKey(event),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: enabled,
                activeThumbColor: VelvetColors.primary,
                title: Text('Enable keyboard shortcuts',
                    style: TextStyle(
                        color: VelvetColors.textPrimary, fontSize: 14)),
                onChanged: (v) async {
                  setState(() => _capturing = null);
                  await SettingsManager().setHotkeysEnabled(v);
                  setState(() {});
                },
              ),
              Divider(height: 1, color: VelvetColors.border),
              Flexible(
                child: Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final a in HotkeyAction.values) _row(a),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _restoreAll,
          child: Text('Restore defaults',
              style: TextStyle(color: VelvetColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Done', style: TextStyle(color: VelvetColors.primary)),
        ),
      ],
    );
  }

  Widget _row(HotkeyAction action) {
    final combo = _keys.bindings[action];
    final capturing = _capturing == action;
    // The digit row is one fixed action — it can be turned off and back on,
    // but not rebound to some other key (matching the web player).
    final rebindable = action != HotkeyAction.percentSeek;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(_actionLabels[action] ?? action.name,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 13)),
          ),
          _keycap(action, combo, capturing),
          SizedBox(
            width: 76,
            child: rebindable
                ? TextButton(
                    onPressed: () => _beginCapture(action),
                    child: Text(capturing ? 'Cancel' : 'Change',
                        style: TextStyle(
                            color: VelvetColors.primary, fontSize: 12)),
                  )
                : null,
          ),
          SizedBox(
            width: 76,
            child: TextButton(
              onPressed: () => combo == null
                  ? _assign(action, kHotkeyDefaults[action])
                  : _assign(action, null),
              child: Text(combo == null ? 'Restore' : 'Clear',
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keycap(HotkeyAction action, HotkeyCombo? combo, bool capturing) {
    final String text;
    if (capturing) {
      text = 'Press a key…';
    } else if (action == HotkeyAction.percentSeek) {
      text = combo == null ? 'None' : '0 – 9';
    } else {
      text = combo?.label ?? 'None';
    }
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: capturing ? VelvetColors.primaryDim : VelvetColors.card,
        border: Border.all(
            color: capturing ? VelvetColors.primary : VelvetColors.border2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: combo == null && !capturing
              ? VelvetColors.textSecondary
              : VelvetColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
