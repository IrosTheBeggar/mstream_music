import 'package:material_ui/material_ui.dart';
import 'package:now_playing_widget/now_playing_widget.dart';

import '../l10n/app_localizations.dart';
import '../singletons/app_messenger.dart';
import '../theme/velvet_theme.dart';

/// The Settings row's sheet on Android: the five sizes the launcher can
/// place, under the names its own picker gives them (from the plugin, in the
/// app's language). A tap asks the launcher to place that size; the launcher
/// shows its own confirmation. A launcher that takes no pin requests gets the
/// hint to use its picker instead.
class HomeWidgetSheet extends StatefulWidget {
  const HomeWidgetSheet({super.key});

  @override
  State<HomeWidgetSheet> createState() => _HomeWidgetSheetState();
}

class _HomeWidgetSheetState extends State<HomeWidgetSheet> {
  PinTargets? _targets;

  @override
  void initState() {
    super.initState();
    NowPlayingWidget.pinTargets().then((t) {
      if (mounted) setState(() => _targets = t);
    });
  }

  Future<void> _pin(PinTarget target) async {
    final l = AppLocalizations.of(context);
    Navigator.of(context).pop();
    if (!await NowPlayingWidget.requestPin(size: target.size)) {
      showGlobalSnack(l.homeWidgetPinUnsupported);
    }
  }

  /// A glyph in the shape of the frame each size takes.
  static IconData _glyph(String size) => switch (size) {
        '2x1' => Icons.crop_7_5,
        '2x2' => Icons.crop_square,
        '4x2' => Icons.crop_landscape,
        '4x3' => Icons.crop_din,
        _ => Icons.crop_16_9,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final targets = _targets;
    final secondary =
        TextStyle(color: VelvetColors.textSecondary, fontSize: 13);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.homeWidgetPickSize,
              style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (targets == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!targets.supported || targets.targets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(l.homeWidgetPinUnsupported, style: secondary),
            )
          else
            for (final t in targets.targets)
              ListTile(
                leading: Icon(_glyph(t.size), color: VelvetColors.textSecondary),
                title: Text(t.label,
                    style: TextStyle(color: VelvetColors.textPrimary)),
                onTap: () => _pin(t),
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
