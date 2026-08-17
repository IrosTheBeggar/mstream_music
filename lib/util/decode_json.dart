import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Body size above which JSON decoding moves off the UI isolate.
///
/// The whole-library endpoints (/db/artists, /db/albums, /playlist/load,
/// /file-explorer/recursive) return multi-MB bodies on a big library, and a
/// jsonDecode that size blocks the UI thread for tens to hundreds of ms —
/// right while the loading bar is animating. Small bodies stay inline: an
/// isolate round-trip (spawn + copy) costs more than it saves there.
const int kIsolateDecodeThreshold = 100 * 1024;

/// jsonDecode, off-thread for large bodies (see [kIsolateDecodeThreshold]).
/// async so a parse error always surfaces as a failed future, never a
/// synchronous throw.
Future<dynamic> decodeJsonBody(String body) async =>
    body.length > kIsolateDecodeThreshold
        ? await compute(jsonDecode, body)
        : jsonDecode(body);
