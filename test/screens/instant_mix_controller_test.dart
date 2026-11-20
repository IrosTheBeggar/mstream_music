// InstantMixController (mStream POST /api/v1/discovery/local/mix): one ask
// at open, the state each answer draws (the empty ones counted beyond the
// seed), the generations that drop a late answer, the 403 latch with ONE
// re-ping, and a filter change's re-ask — the rows kept up meanwhile, and
// a failed one putting back the filters those rows were built with; a mood
// the answer did not keep to leaving the page; a change the request does
// not see asking nothing.
//
// The route and the re-ping are injected, so nothing here touches the
// network or a singleton's state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/instant_mix.dart';
import 'package:mstream_music/objects/genre_source.dart';
import 'package:mstream_music/objects/mix_filters.dart';
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/instant_mix/instant_mix_controller.dart';

import 'instant_mix_fixtures.dart';

void main() {
  late Server server;
  late FakeMix mix;
  late int repings;
  late MixSeed seed;

  setUp(() {
    server = mixServer();
    mix = FakeMix();
    repings = 0;
    seed = MixSeed.song(doloRow(server));
  });

  InstantMixController make({MixFilters? filters}) {
    final c = InstantMixController(
      seed: seed,
      filters: filters,
      fetch: mix.call,
      reping: (_) async => repings++,
    );
    addTearDown(c.dispose);
    return c;
  }

  DiscoveryFetchResult<MixAnswer> ok(Map<String, dynamic> m) =>
      DiscoveryFetchResult.ok(MixAnswer.fromServerMap(server, m));

  group('the states', () {
    test('loading until the first answer, then ready with its rows', () async {
      final c = make();
      expect(c.state, InstantMixState.loading,
          reason: 'drawn before the ask goes out');
      final load = c.load();
      expect(c.state, InstantMixState.loading);
      expect(c.asking, isTrue);
      expect(c.refreshing, isFalse, reason: 'nothing up to keep');
      expect(mix.bodies.single,
          {'from': {'song': 'demo/Boukmanflow/Dolo.mp3'}, 'limit': 50});
      mix.pending.single.complete(ok(doloMix()));
      await load;
      expect(c.state, InstantMixState.ready);
      expect([for (final r in c.rows) r.metadata?.title],
          ['Dolo', 'Elevation', 'TopRanking', 'Enfance']);
      expect(c.showsVerbs, isTrue);
      expect(c.showsFilters, isTrue);
      expect(c.asking, isFalse);
    });

    test('not analyzed', () async {
      mix.auto = (_) => ok({'notAnalyzed': true, 'songs': []});
      final c = make();
      await c.load();
      expect(c.state, InstantMixState.notAnalyzed);
      expect(c.rows, isEmpty);
      expect(c.showsVerbs, isFalse);
      expect(c.showsFilters, isFalse);
    });

    test('nothing beyond the seed: nothing similar, or — filteredOut — no '
        'match, which keeps the Filters', () async {
      final leadOnly = [mixSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow')];
      mix.auto = (_) => ok({'songs': leadOnly, 'filteredOut': false});
      final c = make();
      await c.load();
      expect(c.state, InstantMixState.nothingSimilar);
      expect(c.rows, isEmpty, reason: 'the seed alone is no mix');
      expect(c.showsVerbs, isFalse);
      expect(c.showsFilters, isFalse, reason: 'filters can only narrow');

      mix.auto = (_) => ok({'songs': leadOnly, 'filteredOut': true});
      final d = make();
      await d.load();
      expect(d.state, InstantMixState.noMatch);
      expect(d.rows, isEmpty);
      expect(d.showsVerbs, isFalse);
      expect(d.showsFilters, isTrue, reason: 'the way back out');

      mix.auto = (_) => ok({'songs': [], 'filteredOut': true});
      final e = make();
      await e.load();
      expect(e.state, InstantMixState.noMatch,
          reason: 'the filters left the seed out too');
    });

    test('a seed a filter left out: songs beyond it are a mix', () async {
      mix.auto = (_) => ok({
            'songs': [mixSong('demo/ALM/Enfance.mp3', 'Enfance', 'ALM')],
          });
      final c = make();
      await c.load();
      expect(c.state, InstantMixState.ready);
      expect(c.rows.single.metadata?.title, 'Enfance');
    });

    test('a failed first answer: failed, and Try again asks again', () async {
      mix.auto = (_) => const DiscoveryFetchResult.error();
      final c = make();
      await c.load();
      expect(c.state, InstantMixState.failed);
      expect(c.showsVerbs, isFalse);
      expect(c.showsFilters, isFalse);

      mix.auto = null;
      final retry = c.retry();
      expect(c.state, InstantMixState.loading,
          reason: 'placeholders again while it asks');
      mix.pending.single.complete(ok(doloMix()));
      await retry;
      expect(c.state, InstantMixState.ready);
      expect(mix.bodies, hasLength(2));
      expect(mix.bodies.last, mix.bodies.first, reason: 'the same question');
    });

    test('carried filters show the Filters while the first answer is out',
        () async {
      final c = make(filters: skipLive);
      unawaited(c.load());
      expect(c.state, InstantMixState.loading);
      expect(c.showsFilters, isTrue);
      expect(mix.bodies.single['skipWords'], ['live'],
          reason: "the open asks under the page's filters");
      expect(make().showsFilters, isFalse);
    });
  });

  group('generations', () {
    test('every ask is one; a late answer to an older one is dropped',
        () async {
      final c = make();
      final first = c.load();
      expect(c.generation, 1);
      final second = c.apply(skipLive);
      expect(c.generation, 2);
      mix.pending[1].complete(ok(doloMix()));
      await second;
      expect(c.state, InstantMixState.ready);
      final shown = c.rows;
      // The first ask's answer lands last: nothing changes.
      mix.pending[0].complete(ok({'notAnalyzed': true, 'songs': []}));
      await first;
      expect(c.state, InstantMixState.ready);
      expect(c.rows, same(shown));
      expect(c.asking, isFalse);
    });

    test('the rows are built once per answer', () async {
      mix.auto = (_) => ok(doloMix());
      final c = make();
      await c.load();
      expect(c.rows, same(c.rows));
      expect(c.rows.first, same(c.answer!.rows.first));
    });
  });

  group('the 403', () {
    test('off, re-pinged once, and asked no more', () async {
      mix.auto = (_) => const DiscoveryFetchResult.disabled();
      final c = make();
      var notified = 0;
      c.addListener(() => notified++);
      await c.load();
      expect(c.state, InstantMixState.off);
      expect(repings, 1);
      expect(notified, greaterThan(0));
      await c.retry();
      await c.apply(skipLive);
      expect(mix.bodies, hasLength(1), reason: 'latched: nothing is asked');
      expect(repings, 1);
      expect(c.showsVerbs, isFalse);
      expect(c.showsFilters, isFalse);
      expect(c.refreshing, isFalse);
    });

    test('a 403 on a re-ask takes the rows away too', () async {
      final c = make();
      final load = c.load();
      mix.pending.single.complete(ok(doloMix()));
      await load;
      final apply = c.apply(skipLive);
      mix.pending.last.complete(const DiscoveryFetchResult.disabled());
      expect(await apply, isTrue, reason: 'not a failure to toast');
      expect(c.state, InstantMixState.off);
      expect(c.rows, isEmpty);
      expect(repings, 1);
    });
  });

  group('a filter change asks again', () {
    late InstantMixController c;

    setUp(() async {
      c = make();
      final load = c.load();
      mix.pending.single.complete(ok(doloMix()));
      await load;
    });

    test('the filters are the page\'s at once; the rows stay up, inert, '
        'until the answer replaces them', () async {
      final before = c.rows;
      final apply = c.apply(skipLive);
      expect(c.filters, skipLive);
      expect(mix.bodies.last['skipWords'], ['live']);
      expect(c.refreshing, isTrue);
      expect(c.rows, same(before), reason: 'the old rows, until it lands');
      expect(c.state, InstantMixState.ready);
      mix.pending.last.complete(ok(relaxedMix()));
      expect(await apply, isTrue);
      expect(c.refreshing, isFalse);
      expect([for (final r in c.rows) r.metadata?.title],
          ['Dolo', 'Enfance', 'The Hangout']);
    });

    test('the same filters ask nothing', () async {
      expect(await c.apply(MixFilters.empty), isTrue);
      expect(await c.clearFilters(), isTrue);
      expect(mix.bodies, hasLength(1));
    });

    test('a failed re-ask keeps the rows and puts back their filters',
        () async {
      final before = c.rows;
      final apply = c.apply(skipLive);
      mix.pending.last.complete(const DiscoveryFetchResult.error());
      expect(await apply, isFalse, reason: 'the caller says so');
      expect(c.filters, MixFilters.empty,
          reason: 'never a filter the rows ignore');
      expect(c.rows, same(before));
      expect(c.state, InstantMixState.ready);
      expect(c.refreshing, isFalse);
    });

    test('a failed second change goes back to the first, which landed',
        () async {
      final first = c.apply(skipLive);
      mix.pending.last.complete(ok(relaxedMix()));
      await first;
      final second = c.apply(skipRemix);
      mix.pending.last.complete(const DiscoveryFetchResult.error());
      expect(await second, isFalse);
      expect(c.filters, skipLive);
      expect([for (final r in c.rows) r.metadata?.title],
          ['Dolo', 'Enfance', 'The Hangout']);
    });

    test('Clear asks again with nothing set', () async {
      final set = c.apply(skipLive);
      mix.pending.last.complete(ok(relaxedMix()));
      await set;
      final clear = c.clearFilters();
      expect(c.filters, MixFilters.empty);
      expect(mix.bodies.last,
          {'from': {'song': 'demo/Boukmanflow/Dolo.mp3'}, 'limit': 50});
      mix.pending.last.complete(ok(doloMix()));
      expect(await clear, isTrue);
      expect(c.rows, hasLength(4));
    });

    test('filters that empty the list: no match, the Filters kept', () async {
      final apply = c.apply(skipLive);
      mix.pending.last.complete(ok({'songs': [], 'filteredOut': true}));
      await apply;
      expect(c.state, InstantMixState.noMatch);
      expect(c.showsFilters, isTrue);
      expect(c.filters, skipLive);
    });
  });

  group('what the answer kept to', () {
    const relaxed = MixFilters(
        mood: MoodFilter(energy: 'relaxed'), skipWords: ['live']);

    setUp(() => server.moodFiltersAvailable = true);

    test("a mood the answer kept to stays; one it didn't — no scores now — "
        "leaves the page's filters", () async {
      mix.auto = (_) => ok(relaxedMix());
      final c = make(filters: relaxed);
      await c.load();
      expect(mix.bodies.single['moods'], {'energy': 'relaxed'});
      expect(c.filters, relaxed, reason: 'the echo is the mood asked for');

      mix.auto = (_) => ok({...relaxedMix()}..remove('moods'));
      final d = make(filters: relaxed);
      await d.load();
      expect(d.filters, const MixFilters(skipWords: ['live']),
          reason: 'the rows ignore the mood: the page no longer names it');
      expect(d.filters.count, 1);

      mix.auto = (_) => ok({...relaxedMix(), 'moods': const {}});
      final e = make(filters: relaxed);
      await e.load();
      expect(e.filters.mood, MoodFilter.empty);
    });

    test("a failed re-ask goes back to the filters as the answer kept them",
        () async {
      mix.auto = (_) => ok({...relaxedMix()}..remove('moods'));
      final c = make(filters: relaxed);
      await c.load();
      mix.auto = (_) => const DiscoveryFetchResult.error();
      expect(await c.apply(skipRemix), isFalse);
      expect(c.filters, const MixFilters(skipWords: ['live']));
    });
  });

  group('a change the request does not see', () {
    test('is the page\'s at once, and asks nothing', () async {
      mix.auto = (_) => ok(doloMix());
      final c = make();
      await c.load();
      final rows = c.rows;
      var notified = 0;
      c.addListener(() => notified++);
      for (final f in const [
        MixFilters(bpmTolerance: 12),
        MixFilters(bpmTolerance: 12, genres: GenreChoice(mode: 'blacklist')),
      ]) {
        expect(await c.apply(f), isTrue);
        expect(c.filters, f);
      }
      expect(mix.bodies, hasLength(1), reason: 'the same body, the same mix');
      expect(notified, 2);
      expect(c.rows, same(rows));
      expect(c.refreshing, isFalse);

      // One it does see asks.
      final apply = c.apply(const MixFilters(bpmTolerance: 12, tempo: true));
      expect(mix.bodies, hasLength(2));
      expect(mix.bodies.last['bpmRanges'], isNotEmpty);
      await apply;
    });
  });

  test('disposed: a late answer changes nothing, and dispose is idempotent',
      () async {
    final c = InstantMixController(
        seed: seed, fetch: mix.call, reping: (_) async => repings++);
    var notified = 0;
    c.addListener(() => notified++);
    final load = c.load();
    final before = notified;
    c.dispose();
    c.dispose();
    mix.pending.single.complete(ok(doloMix()));
    await load;
    expect(notified, before);
    expect(c.answer, isNull);
  });
}
