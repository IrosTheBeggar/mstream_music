import 'package:material_ui/material_ui.dart';

import '../../theme/velvet_theme.dart';

/// The drag handle at the top of the equalizer's bottom sheets.
class EqSheetHandle extends StatelessWidget {
  const EqSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: VelvetColors.border2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
