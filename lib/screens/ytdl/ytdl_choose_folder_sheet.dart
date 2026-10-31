import 'package:material_ui/material_ui.dart';

import 'ytdl_draft.dart';

/// "Choose a folder" for an account that can't make folders (spec §8
/// noMkdir): browse the folders that exist and pick one. Returns its
/// directory ('/Music/Daft Punk/'), or null when cancelled; the caller
/// applies it with [YtdlDraft.useFolder]. Stub — phase C3 replaces it.
Future<String?> showYtdlChooseFolderSheet(
  BuildContext context,
  YtdlDraft draft,
) async =>
    null;
