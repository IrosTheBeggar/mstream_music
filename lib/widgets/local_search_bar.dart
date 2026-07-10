import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';

/// A small, reusable local-search input: a search-icon-prefixed field
/// with an inline clear button. Purely client-side — it owns its text
/// controller and just reports changes via [onChanged]; the host screen
/// decides how to filter its own list (e.g. DisplayItem.matchesQuery).
///
/// Designed to drop into any list screen's header. Pair it with a search
/// toggle and a close affordance owned by the host (see browser.dart).
class LocalSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;

  const LocalSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search this list',
    this.autofocus = true,
  });

  @override
  State<LocalSearchBar> createState() => _LocalSearchBarState();
}

class _LocalSearchBarState extends State<LocalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Explicitly grab focus when the bar appears. `autofocus` alone is
    // suppressed when another node in the scope already holds focus (e.g. the
    // desktop browser's type-to-jump handler), which left the field unfocused
    // on open — requestFocus overrides that.
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
      cursorColor: VelvetColors.primary,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: VelvetColors.raised,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        hintText: widget.hintText,
        hintStyle: TextStyle(color: VelvetColors.textSecondary),
        prefixIcon: Icon(Icons.search, color: VelvetColors.textSecondary),
        // Rebuild only the clear button as text comes and goes, rather
        // than the whole field, by listening to the controller directly.
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(Icons.clear, color: VelvetColors.textSecondary),
              tooltip: l.clear,
              onPressed: _clear,
            );
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
