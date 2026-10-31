import 'package:material_ui/material_ui.dart';

import '../theme/velvet_theme.dart';

/// One answer in a [showChoiceSheet]: its label, an optional one-line hint
/// under it, and an optional picture between the radio and the label (a
/// theme's palette, a player layout's shape).
class ChoiceOption<T> {
  final T value;
  final String label;
  final String? hint;
  final Widget? preview;

  /// The label's own language, for a list of language names.
  final Locale? locale;

  const ChoiceOption(this.value, this.label,
      {this.hint, this.preview, this.locale});
}

/// A Settings value row's picker: a bottom sheet of radio rows. A tap applies
/// and closes, like the accent presets. Returns the picked option, or null
/// when the sheet is dismissed — an option's own value may be null (Language
/// › System default), so the value alone can't say which happened.
Future<ChoiceOption<T>?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceOption<T>> options,
  required T selected,
}) {
  return showModalBottomSheet<ChoiceOption<T>>(
    context: context,
    backgroundColor: VelvetColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final o in options)
                    _ChoiceRow(
                      option: o,
                      selected: o.value == selected,
                      onTap: () => Navigator.of(ctx).pop(o),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChoiceRow extends StatelessWidget {
  final ChoiceOption<Object?> option;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceRow(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hint = option.hint;
    final preview = option.preview;
    // A language name in its own locale, so a CJK name gets its own glyphs.
    final label = Text(option.label,
        style: TextStyle(
            color: VelvetColors.textPrimary,
            fontSize: 16,
            locale: option.locale));
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: hint == null ? 52 : 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected
                      ? VelvetColors.primary
                      : VelvetColors.textSecondary,
                ),
                const SizedBox(width: 16),
                if (preview != null) ...[
                  ExcludeSemantics(child: preview),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      label,
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(hint,
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ],
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
