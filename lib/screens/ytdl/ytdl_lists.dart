import 'package:material_ui/material_ui.dart';

import '../../singletons/ytdl_hub.dart';

/// ADDING, NEEDS A LOOK and ADDED under the result card (spec §6). Stub —
/// phase C2 replaces it.
class YtdlLists extends StatelessWidget {
  final YtdlServerState state;

  /// Put on the NEEDS A LOOK header so the screen can scroll to it
  /// ([YtdlScreen.openNeedsLook]).
  final GlobalKey? needsLookAnchor;

  const YtdlLists({super.key, required this.state, this.needsLookAnchor});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
