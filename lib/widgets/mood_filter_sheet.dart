// mood_filter_sheet.dart — the mood Filters: the toolbar's button, the
// sheet it opens and the grey strip that says what is set (see
// objects/mood_filter.dart for what each choice means on the server).
//
// The button sits in the toolbar of an Albums or Artists list whose server
// can filter, and before Discover's New seeds; it counts the choices set.
// It opens a bottom sheet — the shape of Discover's "More options" — with
// the three scales as segments (pressing the chosen one again lets it go),
// the tags, and Clear and Done: Done applies the choices, Clear empties
// them, and closing the sheet any other way changes nothing. While anything
// is set, a grey strip under the bar — the File Explorer's path strip —
// names the choices, and its Clear lets them all go.

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/mood_filter.dart';
import '../theme/velvet_theme.dart';
import 'federation_widgets.dart';

/// A choice's words.
String moodLabel(AppLocalizations l, String value) => switch (value) {
      'happy' => l.moodHappy,
      'neutral' => l.moodNeutral,
      'sad' => l.moodSad,
      'relaxed' => l.moodRelaxed,
      'aggressive' => l.moodAggressive,
      'instrumental' => l.moodInstrumental,
      'vocals' => l.moodVocals,
      'acoustic' => l.moodAcoustic,
      'party' => l.moodParty,
      'danceable' => l.moodDanceable,
      _ => value,
    };

/// What is set, in words: the scales' values, then the tags.
List<String> moodLabels(AppLocalizations l, MoodFilter f) => [
      for (final scale in MoodScale.values)
        if (f.valueOf(scale) case final value?) moodLabel(l, value),
      for (final tag in f.tags) moodLabel(l, tag),
    ];

/// The toolbar's Filters button, with the count of choices set.
class MoodFilterButton extends StatelessWidget {
  const MoodFilterButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('mood-filters'),
      tooltip: l.moodFilters,
      onPressed: onPressed,
      color: count > 0 ? VelvetColors.primary : VelvetColors.appBarTextSecondary,
      disabledColor: VelvetColors.appBarTextSecondary.withValues(alpha: 0.4),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: VelvetColors.primary,
        textColor: VelvetColors.onPrimary,
        child: const Icon(Icons.filter_alt_outlined, size: 22),
      ),
    );
  }
}

/// The sheet on [initial]: the choices made when Done is pressed, or null
/// when it is closed any other way (nothing changes then). [title] replaces
/// the browse lists' "Filters" (Auto DJ's sheet is its Mood row's).
Future<MoodFilter?> showMoodFilterSheet(
        BuildContext context, MoodFilter initial, {String? title}) =>
    showModalBottomSheet<MoodFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MoodFilterSheet(initial: initial, title: title),
    );

class MoodFilterSheet extends StatefulWidget {
  const MoodFilterSheet({super.key, required this.initial, this.title});

  final MoodFilter initial;
  final String? title;

  @override
  State<MoodFilterSheet> createState() => _MoodFilterSheetState();
}

class _MoodFilterSheetState extends State<MoodFilterSheet> {
  late MoodFilter _draft = widget.initial;

  String _groupLabel(AppLocalizations l, MoodScale scale) => switch (scale) {
        MoodScale.valence => l.moodValenceGroup,
        MoodScale.energy => l.moodEnergyGroup,
        MoodScale.voice => l.moodVoiceGroup,
      };

  Widget _scale(AppLocalizations l, MoodScale scale) {
    final on = _draft.valueOf(scale);
    return Semantics(
      label: _groupLabel(l, scale),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          key: ValueKey('mood-${scale.name}'),
          segments: [
            for (final v in scale.choices)
              ButtonSegment(
                value: v,
                label: Text(moodLabel(l, v),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          selected: {?on},
          // One value or none: pressing the chosen one again lets it go.
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (set) => setState(() => _draft =
              _draft.withScale(scale, set.isEmpty ? null : set.first)),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: VelvetColors.primary,
            selectedForegroundColor: VelvetColors.onPrimary,
            foregroundColor: VelvetColors.textPrimary,
            side: BorderSide(color: VelvetColors.border2),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _tag(AppLocalizations l, String tag) {
    final on = _draft.tags.contains(tag);
    return FilterChip(
      key: ValueKey('mood-tag-$tag'),
      label: Text(moodLabel(l, tag)),
      selected: on,
      showCheckmark: false,
      onSelected: (_) => setState(() => _draft = _draft.toggleTag(tag)),
      selectedColor: VelvetColors.primary,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: on ? VelvetColors.primary : VelvetColors.border2),
      labelStyle: TextStyle(
        fontSize: 13,
        color: on ? VelvetColors.onPrimary : VelvetColors.textPrimary,
        fontWeight: on ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          key: const ValueKey('mood-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: VelvetColors.border2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
              child: Row(children: [
                Expanded(
                  child: Text(
                    widget.title ?? l.moodFilters,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: VelvetColors.textSecondary),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            // The choices scroll when the screen is short (a phone on its
            // side); the title and the buttons stay.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final scale in MoodScale.values) ...[
                      _scale(l, scale),
                      const SizedBox(height: 10),
                    ],
                    Semantics(
                      label: l.moodTagsGroup,
                      child: Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final t in kMoodTags) _tag(l, t),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(children: [
                Expanded(
                  child: FedButton(
                    l.clear,
                    key: const ValueKey('mood-sheet-clear'),
                    kind: FedButtonKind.muted,
                    height: 44,
                    onPressed: _draft.isEmpty
                        ? null
                        : () => setState(() => _draft = MoodFilter.empty),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FedButton(
                    l.done,
                    key: const ValueKey('mood-sheet-done'),
                    height: 44,
                    onPressed: () => Navigator.of(context).pop(_draft),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// While anything is set: the File Explorer's path strip under the bar,
/// naming the choices, with Clear at its end.
class MoodFilterStrip extends StatelessWidget {
  const MoodFilterStrip({
    super.key,
    required this.filter,
    required this.onClear,
  });

  final MoodFilter filter;

  /// Null draws Clear off (Discover while its route refuses).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('mood-strip'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Row(children: [
        Icon(Icons.filter_alt_outlined,
            size: 13, color: VelvetColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            moodLabels(l, filter).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: VelvetColors.textSecondary),
          ),
        ),
        TextButton(
          key: const ValueKey('mood-strip-clear'),
          onPressed: onClear,
          style: TextButton.styleFrom(
            foregroundColor: VelvetColors.primary,
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: Text(l.clear),
        ),
      ]),
    );
  }
}
