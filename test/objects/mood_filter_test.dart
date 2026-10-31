// The mood filter's model (mStream #1092): the wire form a page's filter is
// sent in, the one-value-per-scale and toggling-tag choices, the level sent
// as `threshold` (#1099), the answer's echo that says a list can filter,
// each page's own filter and Sort, and a filtered song list's best match
// first.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/mood_filter.dart';

void main() {
  group('the wire form', () {
    test('only the groups that filter, tags in a fixed order; nothing when '
        'empty', () {
      expect(MoodFilter.empty.toJson(), isNull);
      final f = MoodFilter.empty
          .withScale(MoodScale.valence, 'neutral')
          .toggleTag('danceable')
          .toggleTag('acoustic');
      expect(f.toJson(), {
        'valence': 'neutral',
        'tags': ['acoustic', 'danceable'],
      });
      final all = f
          .withScale(MoodScale.energy, 'relaxed')
          .withScale(MoodScale.voice, 'vocals');
      expect(all.toJson(), {
        'valence': 'neutral',
        'energy': 'relaxed',
        'voice': 'vocals',
        'tags': ['acoustic', 'danceable'],
      });
      final none = f
          .withScale(MoodScale.valence, null)
          .toggleTag('acoustic')
          .toggleTag('danceable');
      expect(none.isEmpty, isTrue);
      expect(none.toJson(), isNull, reason: 'no `moods` key at all');
    });
  });

  group('read back (a saved filter, an answer\'s echo)', () {
    test('the wire form round-trips; nothing reads as empty', () {
      const f = MoodFilter(
          energy: 'relaxed', voice: 'instrumental', tags: ['acoustic', 'party']);
      expect(MoodFilter.fromJson(f.toJson()), f);
      expect(MoodFilter.fromJson(null), MoodFilter.empty);
    });

    test('an unknown value or tag, and junk, are dropped rather than sent', () {
      final f = MoodFilter.fromJson({
        'valence': 'ecstatic',
        'energy': 'relaxed',
        'voice': 3,
        'tags': ['party', 'loud', 'party', 7],
        'extra': true,
      });
      expect(f, const MoodFilter(energy: 'relaxed', tags: ['party']));
      expect(f.toJson(), {
        'energy': 'relaxed',
        'tags': ['party']
      });
      expect(MoodFilter.fromJson('relaxed'), MoodFilter.empty);
      expect(MoodFilter.fromJson({'tags': 'party'}), MoodFilter.empty);
    });
  });

  group('an Auto DJ answer echoes the mood it picked under', () {
    const asked = MoodFilter(energy: 'relaxed', voice: 'instrumental');

    test('the same filter fits, whatever order its tags come in', () {
      expect(
          moodEchoFits({'energy': 'relaxed', 'voice': 'instrumental'}, asked),
          isTrue);
      expect(
          moodEchoFits({
            'tags': ['party', 'acoustic']
          }, const MoodFilter(tags: ['acoustic', 'party'])),
          isTrue);
    });

    test('no echo, {}, junk or another filter does not', () {
      expect(moodEchoFits(null, asked), isFalse,
          reason: 'a server that cannot filter leaves the key out');
      expect(moodEchoFits(<String, dynamic>{}, asked), isFalse,
          reason: '{} is a pick under no filter');
      expect(moodEchoFits('relaxed', asked), isFalse);
      expect(moodEchoFits({'energy': 'relaxed'}, asked), isFalse);
    });

    test('the level is part of it', () {
      final strict = asked.withLevel(MoodLevel.strict);
      expect(
          moodEchoFits(
              {'energy': 'relaxed', 'voice': 'instrumental', 'threshold': 0.7},
              strict),
          isTrue);
      expect(
          moodEchoFits({'energy': 'relaxed', 'voice': 'instrumental'}, strict),
          isFalse,
          reason: 'picked at the default bar, not the strict one');
    });
  });

  group('choices', () {
    test('one value per scale; null lets it go; an unknown value changes '
        'nothing', () {
      var f = MoodFilter.empty.withScale(MoodScale.energy, 'relaxed');
      expect(f.energy, 'relaxed');
      f = f.withScale(MoodScale.energy, 'aggressive');
      expect(f.valueOf(MoodScale.energy), 'aggressive');
      expect(f.withScale(MoodScale.energy, 'sad'), f,
          reason: 'sad is not on the relaxed / aggressive scale');
      expect(f.withScale(MoodScale.energy, null).isEmpty, isTrue);
      expect(MoodScale.voice.choices, ['instrumental', 'vocals']);
    });

    test('tags toggle; an unknown tag changes nothing', () {
      var f = MoodFilter.empty.toggleTag('party');
      expect(f.tags, ['party']);
      f = f.toggleTag('acoustic');
      expect(f.tags, ['acoustic', 'party'], reason: 'always in the sheet order');
      f = f.toggleTag('party');
      expect(f.tags, ['acoustic']);
      expect(f.toggleTag('sad'), f);
    });

    test('count: the scales that filter plus the tags', () {
      expect(MoodFilter.empty.count, 0);
      expect(const MoodFilter(energy: 'relaxed').count, 1);
      expect(
          const MoodFilter(
              valence: 'sad',
              energy: 'neutral',
              voice: 'vocals',
              tags: ['acoustic', 'party', 'danceable']).count,
          6);
    });
  });

  group('the level', () {
    test('sent as `threshold` beside the choices, never on its own; '
        'Standard sends nothing', () {
      final f = const MoodFilter(energy: 'relaxed').withLevel(MoodLevel.strict);
      expect(f.toJson(), {'energy': 'relaxed', 'threshold': 0.7});
      expect(f.withLevel(MoodLevel.loose).toJson(),
          {'energy': 'relaxed', 'threshold': 0.3});
      expect(f.withLevel(MoodLevel.standard).toJson(), {'energy': 'relaxed'});
      const lone = MoodFilter(level: MoodLevel.strict);
      expect(lone.isEmpty, isTrue);
      expect(lone.toJson(), isNull,
          reason: 'nothing set: nothing to be strict about');
      expect(lone == MoodFilter.empty, isFalse,
          reason: 'kept for the sheet, which shows it either way');
      expect(f.count, 1, reason: 'not a choice: the badge does not count it');
      expect(f, const MoodFilter(energy: 'relaxed', level: MoodLevel.strict));
    });

    test('kept through the choices, and with the last one gone', () {
      const f = MoodFilter(energy: 'relaxed', level: MoodLevel.loose);
      expect(f.toggleTag('party').level, MoodLevel.loose);
      expect(f.withScale(MoodScale.voice, 'vocals').level, MoodLevel.loose);
      expect(f.withScale(MoodScale.energy, null),
          const MoodFilter(level: MoodLevel.loose));
    });

    test('read back: a threshold names its level; another, or none, is '
        'Standard', () {
      expect(MoodFilter.fromJson({'energy': 'relaxed', 'threshold': 0.7}),
          const MoodFilter(energy: 'relaxed', level: MoodLevel.strict));
      expect(MoodFilter.fromJson({'energy': 'relaxed', 'threshold': 0.3}).level,
          MoodLevel.loose);
      expect(
          MoodFilter.fromJson({'energy': 'relaxed', 'threshold': 0.45}).level,
          MoodLevel.standard,
          reason: 'not one the sheet offers');
      expect(
          MoodFilter.fromJson({'energy': 'relaxed', 'threshold': '0.7'}).level,
          MoodLevel.standard);
      expect(MoodLevel.of(0.7000001), MoodLevel.strict);
      expect(MoodLevel.of(null), MoodLevel.standard);
    });

    test('the saved form keeps a level picked with nothing set', () {
      const lone = MoodFilter(level: MoodLevel.strict);
      expect(lone.toSavedJson(), {'threshold': 0.7});
      expect(MoodFilter.fromJson(lone.toSavedJson()), lone);
      expect(MoodFilter.empty.toSavedJson(), isNull);
      const f = MoodFilter(energy: 'relaxed', level: MoodLevel.loose);
      expect(f.toSavedJson(), f.toJson());
      expect(MoodFilter.fromJson(f.toSavedJson()), f);
    });
  });

  group('best match first', () {
    DisplayItem song(String name, double? match) =>
        DisplayItem(null, name, 'file', '/$name', null, null)
          ..moodMatch = match;
    List<String> names(List<DisplayItem> l) => [for (final e in l) e.name];

    test("best first; equal matches keep the list's order; none goes last",
        () {
      final list = [
        song('a', 0.6),
        song('b', 0.9),
        song('c', 0.6),
        song('d', null),
        song('e', 0.75),
      ];
      expect(names(byMoodMatch(list)), ['b', 'e', 'a', 'c', 'd']);
      expect(names(list), ['a', 'b', 'c', 'd', 'e'],
          reason: 'a new list: the answer as it came is left alone');
      final plain = [song('a', null), song('b', null)];
      expect(identical(byMoodMatch(plain), plain), isTrue,
          reason: 'unfiltered: as it came');
    });

    test('a long run of equal matches stays in order', () {
      final list = [for (var i = 0; i < 100; i++) song('s$i', 0.5)];
      expect(names(byMoodMatch(list)), names(list));
    });

    test("a song's match from the answer: a number, or nothing", () {
      expect(moodMatchOf({'moodMatch': 0.85}), 0.85);
      expect(moodMatchOf({'moodMatch': 1}), 1.0);
      expect(moodMatchOf({'moodMatch': '0.8'}), isNull);
      expect(moodMatchOf({'filepath': 'x'}), isNull);
      expect(moodMatchOf('junk'), isNull);
    });
  });

  group('the answer says whether the list can filter', () {
    test('an echo (an object) makes a frame; none, or junk, does not', () {
      final frame = MoodListFrame.fromAnswer(
          {'albums': [], 'moods': {}}, null, MoodPage.albums);
      expect(frame, isNotNull);
      expect(frame!.page, MoodPage.albums);
      expect(MoodListFrame.fromAnswer({'albums': []}, null, MoodPage.albums),
          isNull, reason: 'an older server, or one with no scores');
      expect(
          MoodListFrame.fromAnswer(
              {'artists': [], 'moods': null}, null, MoodPage.artists),
          isNull);
      expect(
          MoodListFrame.fromAnswer(
              {'artists': [], 'moods': true}, null, MoodPage.artists),
          isNull);
      expect(MoodListFrame.fromAnswer(null, null, MoodPage.artists), isNull);
    });
  });

  group('each page keeps its own filter', () {
    setUp(() => MoodFilters().reset());
    tearDown(() => MoodFilters().reset());

    test('setting Albums leaves Artists and Discover alone, and counts the '
        'change', () {
      final relaxed = MoodFilter.empty.withScale(MoodScale.energy, 'relaxed');
      MoodFilters().set(MoodPage.albums, relaxed);
      expect(MoodFilters().of(MoodPage.albums), relaxed);
      expect(MoodFilters().of(MoodPage.artists).isEmpty, isTrue);
      expect(MoodFilters().of(MoodPage.discover).isEmpty, isTrue);
      expect(MoodFilters().generation(MoodPage.albums), 1);
      expect(MoodFilters().generation(MoodPage.artists), 0);
    });

    test('a level picked with no mood set, or the same choice again, asks '
        'nothing', () {
      expect(
          MoodFilters()
              .set(MoodPage.rated, const MoodFilter(level: MoodLevel.strict)),
          isFalse);
      expect(MoodFilters().of(MoodPage.rated).level, MoodLevel.strict,
          reason: 'kept for the sheet');
      expect(MoodFilters().generation(MoodPage.rated), 0);
      const relaxed = MoodFilter(energy: 'relaxed', level: MoodLevel.strict);
      expect(MoodFilters().set(MoodPage.rated, relaxed), isTrue);
      expect(MoodFilters().set(MoodPage.rated, relaxed), isFalse);
      expect(MoodFilters().generation(MoodPage.rated), 1);
      expect(
          MoodFilters()
              .set(MoodPage.rated, relaxed.withLevel(MoodLevel.loose)),
          isTrue);
      expect(MoodFilters().generation(MoodPage.rated), 2);
    });

    test("a song list's Sort: Match rests while no mood is set, and comes "
        'back with one', () {
      const relaxed = MoodFilter(energy: 'relaxed');
      expect(MoodFilters().orderOf(MoodPage.rated), MoodSort.list);
      expect(MoodFilters().set(MoodPage.rated, MoodFilter.empty,
              sort: MoodSort.match),
          isFalse, reason: 'nothing to rank by: the list is the same');
      expect(MoodFilters().sortOf(MoodPage.rated), MoodSort.match);
      expect(MoodFilters().orderOf(MoodPage.rated), MoodSort.list);
      expect(MoodFilters().set(MoodPage.rated, relaxed), isTrue);
      expect(MoodFilters().orderOf(MoodPage.rated), MoodSort.match);
      expect(MoodFilters().set(MoodPage.rated, relaxed, sort: MoodSort.list),
          isTrue, reason: 'the order shown changed');
      expect(MoodFilters().orderOf(MoodPage.recent), MoodSort.list,
          reason: 'each list keeps its own');
      expect(MoodPage.values.where((p) => p.sorts),
          [MoodPage.rated, MoodPage.recent]);
    });
  });
}
