// The mood filter's model (mStream #1092): the wire form a page's filter is
// sent in, the one-value-per-scale and toggling-tag choices, the answer's
// echo that says a list can filter, and each page's own filter.

import 'package:flutter_test/flutter_test.dart';
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
  });
}
