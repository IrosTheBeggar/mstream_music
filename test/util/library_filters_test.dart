// The library filters (util/library_filters.dart) as random-songs' keys,
// built in one place for Auto DJ (AutoDJManager.libraryFilters) and an
// Instant mix page (MixFilters.toRequest). The drift test: the same choices
// made on Auto DJ and on a mix page go out as the same keys with the same
// values, so a filter added to one reaches the other the same way.
// test/auto_dj_library_filters_test.dart pins Auto DJ's own shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/genre_source.dart';
import 'package:mstream_music/objects/instant_mix.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/mix_filters.dart';
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/util/library_filters.dart';

/// The keys a library filter goes out as.
const _libraryKeys = {
  'ignoreVPaths',
  'minRating',
  'genres',
  'genreMode',
  'genreSource',
  'minDuration',
  'maxDuration',
  'allowUnknownDuration',
  'moods',
};

void main() {
  final mgr = AutoDJManager();

  // The manager is a singleton: every comparison starts from Auto DJ's
  // defaults, everything off.
  void resetDj() => mgr
    ..durationFilterEnabled = false
    ..minDurationSec = 120
    ..maxDurationSec = AutoDJManager.durationCeilSec
    ..allowUnknownDuration = false
    ..moodFilterEnabled = false
    ..moodFilter = MoodFilter.empty;

  setUp(resetDj);

  Server server({bool? moods = true, Map<String, bool>? paths}) =>
      Server('http://music.example', 'u', 'p', 'JWT', 'home')
        ..autoDJPaths = paths ?? {'music': true, 'podcasts': true}
        ..moodFiltersAvailable = moods;

  /// Dolo on [s], with its tempo and key: every row a song mix offers.
  MixSeed seedOn(Server s) => MixSeed.song(DisplayItem(
      s, '/demo/Dolo.mp3', 'file', '/demo/Dolo.mp3', null, null)
    ..metadata = MusicMetadata('Boukmanflow', 'Stim Pack Volume one', 'Dolo',
        null, null, null, 'h1', null, null,
        bpm: 87, musicalKey: 'Bb minor'));

  /// A mix request's library part: what is left without the seed, the
  /// limit, and the mix's own keys (tempo, key, skip words).
  Map<String, dynamic> libraryPart(Map<String, dynamic> body) => {
        for (final e in body.entries)
          if (_libraryKeys.contains(e.key)) e.key: e.value,
      };

  group('the drift test: Auto DJ and a mix page, the same choices', () {
    /// Makes [choose] on Auto DJ (the server's fields and the manager's)
    /// and [mix] on a mix page, and compares what each sends.
    void same(String why,
        {required void Function(Server s) choose,
        required MixFilters mix,
        Server? on}) {
      resetDj();
      final s = on ?? server();
      choose(s);
      final dj = mgr.libraryFilters(s);
      final page = libraryPart(mix.toRequest(seedOn(s)));
      expect(page, dj, reason: why);
    }

    test('nothing chosen: nothing sent by either', () {
      same('a wide-open config', choose: (_) {}, mix: MixFilters.empty);
      expect(mgr.libraryFilters(server()), isEmpty);
    });

    test('folders, rating, genres, length and mood, each alone', () {
      same('a folder off',
          choose: (s) => s.autoDJPaths = {'music': true, 'podcasts': false},
          mix: const MixFilters(foldersOff: ['podcasts']));
      same('a minimum rating',
          choose: (s) => s.autoDJminRating = 7,
          mix: const MixFilters(minRating: 7));
      same('genres, Only, every kind',
          choose: (s) => s
            ..autoDJGenreEnabled = true
            ..autoDJGenres = ['Jazz', 'Soul'],
          mix: const MixFilters(
              genres: GenreChoice(genres: ['Jazz', 'Soul'])));
      same('genres, Skip, the generated kind',
          choose: (s) => s
            ..autoDJGenreEnabled = true
            ..autoDJGenreMode = 'blacklist'
            ..autoDJGenres = ['Rock']
            ..autoDJGenreSource = GenreSource.model,
          mix: const MixFilters(
              genres: GenreChoice(
                  mode: 'blacklist',
                  genres: ['Rock'],
                  source: GenreSource.model)));
      same('a shortest length',
          choose: (_) => mgr
            ..durationFilterEnabled = true
            ..minDurationSec = 120,
          mix: const MixFilters(minDuration: 120));
      same('a longest length, unknown lengths in',
          choose: (_) => mgr
            ..durationFilterEnabled = true
            ..minDurationSec = 0
            ..maxDurationSec = 360
            ..allowUnknownDuration = true,
          mix: const MixFilters(maxDuration: 360, allowUnknownDuration: true));
      same('a mood, Strict',
          choose: (_) => mgr
            ..moodFilterEnabled = true
            ..moodFilter = const MoodFilter(
                energy: 'relaxed', tags: ['party'], level: MoodLevel.strict),
          mix: const MixFilters(
              mood: MoodFilter(
                  energy: 'relaxed',
                  tags: ['party'],
                  level: MoodLevel.strict)));
    });

    test('everything at once', () {
      same('one body',
          choose: (s) {
            s
              ..autoDJPaths = {'music': true, 'podcasts': false}
              ..autoDJminRating = 8
              ..autoDJGenreEnabled = true
              ..autoDJGenres = ['Jazz']
              ..autoDJGenreSource = GenreSource.tag;
            mgr
              ..durationFilterEnabled = true
              ..minDurationSec = 120
              ..maxDurationSec = 600
              ..moodFilterEnabled = true
              ..moodFilter = const MoodFilter(valence: 'happy');
          },
          mix: const MixFilters(
            foldersOff: ['podcasts'],
            minRating: 8,
            genres: GenreChoice(genres: ['Jazz'], source: GenreSource.tag),
            minDuration: 120,
            maxDuration: 600,
            mood: MoodFilter(valence: 'happy'),
          ));
    });

    test('a mood goes to neither on a server that cannot filter by it', () {
      for (final flag in [false, null]) {
        same('moodFiltersAvailable $flag',
            on: server(moods: flag),
            choose: (_) => mgr
              ..moodFilterEnabled = true
              ..moodFilter = const MoodFilter(voice: 'instrumental'),
            mix: const MixFilters(mood: MoodFilter(voice: 'instrumental')));
      }
    });

    test("the mix's own keys are not library keys, and Auto DJ never sends "
        'them as library filters', () {
      final body = const MixFilters(
        tempo: true,
        harmonic: true,
        skipWords: ['live'],
      ).toRequest(seedOn(server()));
      expect(body.keys, containsAll(['bpmRanges', 'musicalKeys', 'skipWords']));
      expect(libraryPart(body), isEmpty);
      for (final k in ['bpmRanges', 'musicalKeys', 'skipWords']) {
        expect(_libraryKeys, isNot(contains(k)));
      }
    });
  });

  group('libraryFilterFields', () {
    test('each key only while it filters', () {
      final s = server();
      expect(libraryFilterFields(s), isEmpty);
      expect(
          libraryFilterFields(s,
              genreMode: 'blacklist',
              genreSource: GenreSource.model,
              allowUnknownDuration: true,
              mood: const MoodFilter(level: MoodLevel.strict)),
          isEmpty,
          reason: 'a mode, a kind, unknown lengths or a level filter nothing '
              'on their own');
      expect(libraryFilterFields(s, duration: (min: 60, max: null)),
          {'minDuration': 60});
    });

    test('a peer gets no rating (its key has no user to rate)', () {
      final peer = Server('federated://home/3', null, null, null, 'peer-3')
        ..federationParent = 'home'
        ..federationPeerId = 3;
      expect(libraryFilterFields(peer, minRating: 6), isEmpty);
      expect(libraryFilterFields(server(), minRating: 6), {'minRating': 6});
    });
  });
}
