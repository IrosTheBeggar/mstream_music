import 'package:material_ui/material_ui.dart';

import '../../objects/server.dart';

/// Add from YouTube (spec §3): paste a link, check what the server read,
/// see where it lands, Add. Stub — phase C1 replaces it.
class YtdlScreen extends StatefulWidget {
  final Server server;

  /// Opened from the explorer strip's "Details": scroll to NEEDS A LOOK.
  final bool openNeedsLook;

  const YtdlScreen({
    super.key,
    required this.server,
    this.openNeedsLook = false,
  });

  @override
  State<YtdlScreen> createState() => _YtdlScreenState();
}

class _YtdlScreenState extends State<YtdlScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
