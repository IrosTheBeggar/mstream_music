import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../objects/instant_mix.dart';
import '../../objects/mix_filters.dart';
import '../../objects/mood_filter.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/server_list.dart';

typedef MixFetch = Future<DiscoveryFetchResult<MixAnswer>> Function(
    Server server, Map<String, dynamic> body);

/// What an Instant mix page shows below its banner.
enum InstantMixState {
  /// The first answer is out: placeholder rows, no words.
  loading,

  /// Songs to play, the verbs in the toolbar.
  ready,

  /// The filters left nothing beyond the seed: "No songs match your
  /// filters", with the Filters still there to change them.
  noMatch,

  /// Nothing beyond the seed sounds like it yet.
  nothingSimilar,

  /// The seed — or every song of the item — has not been analyzed yet.
  notAnalyzed,

  /// Discovery was switched off since the entry was drawn (a 403).
  off,

  /// The first answer failed: one line and Try again.
  failed,
}

/// One Instant mix page: the seed, the page's filters and the answer they
/// were asked with. It asks once at open and again on every filter change
/// ([apply]); never on Back, and with no pull to refresh — the same seed
/// under the same filters is the same list.
///
/// Every ask is one generation: an answer that lands after a newer ask went
/// out is dropped. A re-ask leaves the answer on screen until its own lands
/// ([refreshing]: the rows go inert and the toolbar's verbs off); one that
/// fails keeps those rows and puts back the filters they were built with,
/// so the page never names filters its rows ignore — [apply] says so, and
/// the caller shows "Couldn't build the mix". For the same reason a mood
/// the answer did not keep to (the server's scores went since its flag was
/// read: no echo, moodEchoFits) leaves the page's filters. A 403 latches
/// the page off and re-pings once, so the entries hide themselves if the
/// flag went with it (DiscoveryPageController's rule).
class InstantMixController extends ChangeNotifier {
  final MixSeed seed;
  final MixFetch _fetch;
  final Future<void> Function(Server) _reping;

  /// [filters] are what the page opens with (none by default); [fetch] and
  /// [reping] are injected by tests.
  InstantMixController({
    required this.seed,
    MixFilters? filters,
    MixFetch? fetch,
    Future<void> Function(Server)? reping,
  })  : _filters = filters ?? MixFilters.empty,
        _fetch = fetch ?? ApiManager().fetchInstantMix,
        _reping = reping ?? ServerManager().getServerPaths;

  Server get server => seed.server;

  MixFilters _filters;

  /// The page's filters: what the Filters button and its strip name, and
  /// what the next ask sends.
  MixFilters get filters => _filters;

  /// The answer on screen, null until the first one lands.
  MixAnswer? answer;

  /// The filters [answer] was asked with — what a failed re-ask goes back
  /// to.
  MixFilters _answered = MixFilters.empty;

  /// An ask is out.
  bool asking = false;

  /// The first ask failed: there is no answer to keep up.
  bool failed = false;

  /// The route refused (403): latched until the page is opened again.
  bool disabled = false;
  bool _repinged = false;

  /// Asks so far; the one out (or last) is current.
  int generation = 0;
  bool _disposed = false;

  InstantMixState get state {
    if (disabled) return InstantMixState.off;
    final a = answer;
    if (a == null) {
      return failed ? InstantMixState.failed : InstantMixState.loading;
    }
    if (a.notAnalyzed) return InstantMixState.notAnalyzed;
    if (!a.beyond(seed)) {
      return a.filteredOut
          ? InstantMixState.noMatch
          : InstantMixState.nothingSimilar;
    }
    return InstantMixState.ready;
  }

  /// The songs the page draws, in play order: the answer's rows when it
  /// has songs beyond the seed, none in an empty state. Built once per
  /// answer, so a rebuild hands the browser the same row objects.
  List<DisplayItem> get rows =>
      state == InstantMixState.ready ? answer!.rows : const [];

  /// A re-ask is out while an answer is up: the rows stay, inert, and the
  /// toolbar's verbs and Filters are off.
  bool get refreshing => asking && answer != null && !disabled;

  /// Play, Shuffle, Add All and Save: only with songs to act on.
  bool get showsVerbs => state == InstantMixState.ready;

  /// Whether the toolbar offers Filters: with songs, and when the filters
  /// emptied the list (the way back); while the first answer is out only
  /// when filters carried over from the last mix. Never for nothing
  /// similar (filters can only narrow), not analyzed, off or failed.
  bool get showsFilters => switch (state) {
        InstantMixState.ready || InstantMixState.noMatch => true,
        InstantMixState.loading => !_filters.isEmpty,
        _ => false,
      };

  /// The first ask, at open.
  Future<void> load() => _ask();

  /// Try again on the failed line.
  Future<void> retry() => _ask();

  /// The Filters sheet's Done, or the strip's Clear: [next] becomes the
  /// page's filters at once, and the server is asked again under them.
  /// False when that ask failed with songs up — the rows stayed and the
  /// filters went back to theirs — so the caller can say so; true
  /// otherwise (landed, overtaken by a newer ask, refused). Nothing is
  /// asked when [next] is what the page has, or asks what the answer up
  /// was asked with (a tolerance changed with Beat matching off, Skip with
  /// no genre): the same body is the same mix.
  Future<bool> apply(MixFilters next) async {
    if (_disposed || disabled || next == _filters) return true;
    if (!asking && answer != null && _sameAsk(next, _answered)) {
      _filters = next;
      _answered = next;
      notifyListeners();
      return true;
    }
    _filters = next;
    return _ask();
  }

  bool _sameAsk(MixFilters a, MixFilters b) =>
      jsonEncode(a.toRequest(seed)) == jsonEncode(b.toRequest(seed));

  /// The strip's Clear: every filter goes, and the page asks again.
  Future<bool> clearFilters() => apply(MixFilters.empty);

  Future<bool> _ask() async {
    if (_disposed || disabled) return true;
    final gen = ++generation;
    final asked = _filters;
    asking = true;
    failed = false;
    notifyListeners();
    final r = await _fetch(server, asked.toRequest(seed));
    if (_disposed || gen != generation) return true;
    asking = false;
    if (r.disabled) {
      disabled = true;
      notifyListeners();
      await _repingOnce();
      return true;
    }
    final data = r.data;
    if (data == null) {
      if (answer == null) {
        failed = true;
        notifyListeners();
        return true;
      }
      _filters = _answered;
      notifyListeners();
      return false;
    }
    answer = data;
    // A mood the rows were not filtered by goes: the page names only what
    // its rows keep to.
    final kept = asked.mood.isEmpty || moodEchoFits(data.moods, asked.mood)
        ? asked
        : asked.copyWith(mood: MoodFilter.empty);
    _answered = kept;
    _filters = kept;
    notifyListeners();
    return true;
  }

  /// Settle a 403 once per page: a route the flag advertised refusing
  /// almost always means discovery was switched off since the last ping,
  /// and only a re-ping says so (the entries then hide with the flag).
  Future<void> _repingOnce() async {
    if (_repinged) return;
    _repinged = true;
    await _reping(server);
    if (!_disposed) notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Idempotent: the listing lets go of its controller on its own, and a
  /// test may dispose the one it injected.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
