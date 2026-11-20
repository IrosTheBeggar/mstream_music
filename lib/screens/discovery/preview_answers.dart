import 'package:flutter/foundation.dart';

import '../../objects/discovery_plugins.dart';

/// One preview plug-in's answer for one lead this visit: a clip, or none
/// (the plug-in answered `preview: null`). Busy and unavailable are never
/// stored: the next press asks again.
@immutable
class PreviewAnswer {
  /// The clip the plug-in found; null when it found none.
  final PluginPreview? found;
  const PreviewAnswer(this.found);

  bool get none => found == null;
}

/// The preview answers of one Peer Recommendations visit, shared with the
/// network-lead sheets it opens (mStream plan §2 item 15: one window for
/// every network lead, its previews shared with the page): keyed by lead
/// key (plan §5.3, peerLeadKey) and plug-in. The page's resolves write
/// every 200 into it, and so do a sheet's rows; a sheet opened from the
/// page is seeded from it, and both read it again on a press. A found clip
/// that fails to play on either is forgotten ([forget]).
///
/// Never disposed: a sheet still open after its visit ended (the page
/// popped under it) may still put into it, and it is garbage once nobody
/// holds it. Whoever listens removes only its own listener.
class PreviewAnswers extends ChangeNotifier {
  /// [cap]: the most leads held (webapp vp.js CLIP_RESULTS_MAX); past it,
  /// the answers of the lead first answered go first.
  PreviewAnswers({this.cap = 200});

  final int cap;

  // Lead key → plug-in → answer, in the order each lead was first answered.
  final Map<String, Map<String, PreviewAnswer>> _byLead = {};

  /// [plugin]'s answer for [leadKey] this visit, if it gave one.
  PreviewAnswer? of(String leadKey, String plugin) => _byLead[leadKey]?[plugin];

  /// Every answer [leadKey] got this visit, plug-in → answer.
  Map<String, PreviewAnswer> answersFor(String leadKey) =>
      Map.unmodifiable(_byLead[leadKey] ?? const <String, PreviewAnswer>{});

  /// [plugin] answered [leadKey] with [found] (null: no preview). Notifies
  /// only when the answer changed.
  void put(String leadKey, String plugin, PluginPreview? found) {
    final had = _byLead[leadKey]?[plugin];
    if (had != null && _same(had.found, found)) return;
    final answers = _byLead[leadKey];
    if (answers == null) {
      // A lead answered again keeps its place (webapp clipRemember).
      while (_byLead.length >= cap && _byLead.isNotEmpty) {
        _byLead.remove(_byLead.keys.first);
      }
      _byLead[leadKey] = {plugin: PreviewAnswer(found)};
    } else {
      answers[plugin] = PreviewAnswer(found);
    }
    notifyListeners();
  }

  /// [plugin]'s clip for [leadKey] at [url] would not load or broke while
  /// playing (a signed CDN address that expired, as Deezer's do): the
  /// answer is dropped, so the next press on the page, on the same sheet or
  /// on a sheet opened later asks the plug-in again rather than replay a
  /// dead address. Only while the answer still holds [url]: one given since
  /// stays. Notifies, and is true, when it dropped one.
  bool forget(String leadKey, String plugin, Uri url) {
    final answers = _byLead[leadKey];
    if (answers == null || answers[plugin]?.found?.url != url) return false;
    answers.remove(plugin);
    if (answers.isEmpty) _byLead.remove(leadKey);
    notifyListeners();
    return true;
  }

  /// Forgets every answer (the provider changed, the plug-ins were
  /// refused); notifies when it held any.
  void clear() {
    if (_byLead.isEmpty) return;
    _byLead.clear();
    notifyListeners();
  }

  /// How many leads have an answer.
  int get length => _byLead.length;

  static bool _same(PluginPreview? a, PluginPreview? b) {
    if (a == null || b == null) return a == null && b == null;
    return identical(a, b) ||
        (a.provider == b.provider &&
            a.url == b.url &&
            a.seconds == b.seconds &&
            a.title == b.title &&
            a.artist == b.artist &&
            a.album == b.album &&
            a.attribution == b.attribution &&
            a.link == b.link &&
            a.artwork == b.artwork &&
            a.match == b.match);
  }
}

/// What a sheet opened from a page shares with it: the visit's answers and
/// the lead's key in them.
typedef LeadPreviewAnswers = ({PreviewAnswers store, String leadKey});
