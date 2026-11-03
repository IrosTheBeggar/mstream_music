// What a mix page asks the server for (MixFilters.toRequest) and what a new
// page opens with (MixFilterStore). Each filter's keys go out only while it
// is set, and never a key the route refuses by name (bpmRangesWide,
// includeSeed, variety…); tempo and key only around a song seed's own; the
// badge counts the mood's choices and one per other row; the strip names
// what is set in the sheet's order. The store lasts the app run, shares the
// app's parts across servers and keeps each server's own, never touches
// Auto DJ's, and leaves an open page's filters alone.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/genre_source.dart';
import 'package:mstream_music/objects/instant_mix.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/mix_filters.dart';
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/widgets/mix_filters_sheet.dart'
    show mixFilterLabels;

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  late Server server;

  setUp(() {
    server = Server('http://music.example', null, null, 'JWT', 'home')
      ..moodFiltersAvailable = true
      ..autoDJPaths = {'music': true, 'podcasts': true};
    MixFilterStore().reset();
  });

  /// Dolo: 87 BPM, Bb minor (3A).
  MixSeed dolo([Server? on]) => MixSeed.song(DisplayItem(on ?? server,
      '/demo/Boukmanflow/Dolo.mp3', 'file', '/demo/Boukmanflow/Dolo.mp3',
      null, null)
    ..metadata = MusicMetadata('Boukmanflow', 'Stim Pack Volume one', 'Dolo',
        null, null, null, 'h1', null, null,
        bpm: 87, musicalKey: 'Bb minor'));

  MixSeed album([Server? on]) => MixSeed.album(DisplayItem(on ?? server,
      'Stim Pack Volume one', 'album', 'Stim Pack Volume one', null, null));

  /// [f]'s keys beyond `from` and `limit`, for [seed] (Dolo by default).
  Map<String, dynamic> sent(MixFilters f, [MixSeed? seed]) =>
      f.toRequest(seed ?? dolo())
        ..remove('from')
        ..remove('limit');

  test('nothing set: nothing counted, nothing named', () {
    expect(MixFilters.empty.isEmpty, isTrue);
    expect(MixFilters.empty.count, 0);
    expect(const MixFilters(), MixFilters.empty);
    expect(mixFilterLabels(l, MixFilters.empty, server), isEmpty);
    expect(
        const MixFilters(
                mood: MoodFilter(level: MoodLevel.strict),
                genres: GenreChoice(mode: 'blacklist'),
                bpmTolerance: 12,
                allowUnknownDuration: true)
            .isEmpty,
        isTrue,
        reason: 'a level, a mode, a tolerance or unknown lengths alone '
            'filter nothing');
  });

  test('the body is from and limit, for every kind of seed', () {
    final song = DisplayItem(server, '/demo/Dolo.mp3', 'file',
        '/demo/Dolo.mp3', null, null);
    final album = DisplayItem(server, 'Stim Pack Volume one', 'album',
        'Stim Pack Volume one', null, null)
      ..year = 2019;
    final seeds = {
      MixSeed.song(song): {'song': 'demo/Dolo.mp3'},
      MixSeed.album(album): {
        'album': {'album': 'Stim Pack Volume one', 'year': 2019},
      },
      MixSeed.artist(server, 'Boukmanflow'): {'artist': 'Boukmanflow'},
      MixSeed.playlist(server, 'Road trip'): {'playlist': 'Road trip'},
    };
    for (final MapEntry(key: seed, value: from) in seeds.entries) {
      final body = MixFilters.empty.toRequest(seed);
      expect(body, {'from': from, 'limit': 50}, reason: seed.kind.name);
    }
  });

  test("the body's from is a copy: a request never edits its seed", () {
    final seed = MixSeed.artist(server, 'Boukmanflow');
    final body = MixFilters.empty.toRequest(seed);
    (body['from'] as Map)['artist'] = 'Someone else';
    expect(seed.from, {'artist': 'Boukmanflow'});
  });

  group('each row, only while it is set', () {
    test('Smart filters: the mood, its level when not Standard — only where '
        'the server filters by mood', () {
      expect(sent(const MixFilters(mood: MoodFilter(energy: 'relaxed'))), {
        'moods': {'energy': 'relaxed'},
      });
      expect(
          sent(const MixFilters(
              mood: MoodFilter(tags: ['party'], level: MoodLevel.strict))),
          {
            'moods': {
              'tags': ['party'],
              'threshold': 0.7,
            },
          });
      server.moodFiltersAvailable = false;
      expect(sent(const MixFilters(mood: MoodFilter(energy: 'relaxed'))),
          isEmpty);
    });

    test('Genres: the list, its mode, and its kind unless Mixed', () {
      expect(
          sent(const MixFilters(genres: GenreChoice(genres: ['Jazz', 'Soul']))),
          {
            'genres': ['Jazz', 'Soul'],
            'genreMode': 'whitelist',
          });
      expect(
          sent(const MixFilters(
              genres: GenreChoice(
                  mode: 'blacklist',
                  genres: ['Rock'],
                  source: GenreSource.model))),
          {
            'genres': ['Rock'],
            'genreMode': 'blacklist',
            'genreSource': 'model',
          });
      expect(
          sent(const MixFilters(
              genres: GenreChoice(mode: 'blacklist', source: GenreSource.tag))),
          isEmpty,
          reason: 'Skip alone, with no genre, asks nothing');
    });

    test('Rating: 1–10; Any sends nothing', () {
      expect(sent(const MixFilters(minRating: 7)), {'minRating': 7});
      expect(sent(const MixFilters(minRating: 0)), isEmpty);
    });

    test('Length: each limit on its own; unknown lengths only beside one', () {
      expect(sent(const MixFilters(minDuration: 120)), {'minDuration': 120});
      expect(sent(const MixFilters(maxDuration: 360)), {'maxDuration': 360});
      expect(
          sent(const MixFilters(
              minDuration: 120, maxDuration: 360, allowUnknownDuration: true)),
          {
            'minDuration': 120,
            'maxDuration': 360,
            'allowUnknownDuration': true,
          });
      expect(sent(const MixFilters(allowUnknownDuration: true)), isEmpty);
    });

    test("Beat matching: the windows around the seed's tempo, half and "
        'double it', () {
      expect(sent(const MixFilters(tempo: true)), {
        'bpmRanges': [
          {'min': 79, 'max': 95},
          {'min': 36, 'max': 52},
          {'min': 166, 'max': 182},
        ],
      });
      expect(sent(const MixFilters(tempo: true, bpmTolerance: 2))['bpmRanges'],
          [
            {'min': 85, 'max': 89},
            {'min': 42, 'max': 46},
            {'min': 172, 'max': 176},
          ]);
      expect(sent(const MixFilters(bpmTolerance: 2)), isEmpty,
          reason: 'a tolerance with Beat matching off');
    });

    test('Beat matching: a window past either end of 0–1000 is cut there', () {
      MixSeed at(int bpm) => MixSeed.song(
          DisplayItem(server, '/a.mp3', 'file', '/a.mp3', null, null)
            ..metadata = MusicMetadata(
                null, null, 'A', null, null, null, 'h', null, null,
                bpm: bpm));
      expect(sent(const MixFilters(tempo: true), at(10))['bpmRanges'], [
        {'min': 2, 'max': 18},
        {'min': 0, 'max': 13},
        {'min': 12, 'max': 28},
      ]);
      expect(
          sent(const MixFilters(tempo: true, bpmTolerance: 20), at(600))[
              'bpmRanges'],
          [
            {'min': 580, 'max': 620},
            {'min': 280, 'max': 320},
            {'min': 1000, 'max': 1000},
          ]);
    });

    test("Harmonic mixing: the seed's key and the five that mix with it, "
        'tagged songs only', () {
      final keys = sent(const MixFilters(harmonic: true));
      expect(keys['requireMusicalKey'], isTrue);
      expect((keys['musicalKeys'] as List).toSet(),
          {'3A', '3B', '2A', '2B', '4A', '4B'},
          reason: "SPEC §3.2's example body for Dolo (Bb minor)");
    });

    test('Skip words and the folders switched off', () {
      expect(sent(const MixFilters(skipWords: ['live', 'remix'])), {
        'skipWords': ['live', 'remix'],
      });
      expect(sent(const MixFilters(foldersOff: ['podcasts'])), {
        'ignoreVPaths': ['podcasts'],
      });
    });
  });

  test('tempo and key only for a song seed that has them', () {
    const both = MixFilters(tempo: true, harmonic: true);
    for (final seed in [
      album(),
      MixSeed.artist(server, 'ALM'),
      MixSeed.playlist(server, 'Road trip'),
      MixSeed.song(DisplayItem(
          server, '/untagged.mp3', 'file', '/untagged.mp3', null, null)),
      MixSeed.song(
          DisplayItem(server, '/odd.mp3', 'file', '/odd.mp3', null, null)
            ..metadata = MusicMetadata(
                null, null, 'Odd', null, null, null, 'h', null, null,
                bpm: 0, musicalKey: 'Q major')),
    ]) {
      expect(sent(both, seed), isEmpty, reason: seed.title);
      expect(both.forSeed(seed), MixFilters.empty,
          reason: '${seed.title}: its page offers neither');
    }
  });

  test('never a key the route refuses by name', () {
    final body = const MixFilters(
      mood: MoodFilter(energy: 'relaxed'),
      genres: GenreChoice(genres: ['Jazz']),
      minRating: 6,
      minDuration: 60,
      maxDuration: 600,
      allowUnknownDuration: true,
      tempo: true,
      harmonic: true,
      skipWords: ['live'],
      foldersOff: ['podcasts'],
    ).toRequest(dolo());
    for (final refused in const [
      'bpmRangesWide',
      'requireBpm',
      'includeSeed',
      'variety',
      'maxPerArtist',
      'offset',
      'similarTo',
      'minSimilarity',
      'ignoreList',
      'ignoreArtists',
      'artists',
    ]) {
      expect(body.containsKey(refused), isFalse, reason: refused);
    }
  });

  group('count and the strip', () {
    test("the board's: Relaxed and Harmonic mixing, two", () {
      const f =
          MixFilters(mood: MoodFilter(energy: 'relaxed'), harmonic: true);
      expect(f.count, 2);
      expect(mixFilterLabels(l, f, server).join(' · '),
          'Relaxed · Harmonic mixing');
    });

    test("every row, in the sheet's order", () {
      const f = MixFilters(
        mood: MoodFilter(energy: 'relaxed', tags: ['party']),
        genres: GenreChoice(mode: 'blacklist', genres: ['Soul', 'Jazz']),
        minRating: 7,
        minDuration: 120,
        maxDuration: 360,
        tempo: true,
        harmonic: true,
        skipWords: ['live', 'remix'],
        foldersOff: ['podcasts'],
      );
      expect(f.count, 9, reason: 'two mood choices, and one per other row');
      expect(mixFilterLabels(l, f, server), [
        'Relaxed',
        'Party',
        'Skip Jazz · Soul',
        '3.5★+',
        '2:00–6:00',
        '± 8 BPM',
        'Harmonic mixing',
        'live',
        'remix',
        'music',
      ]);
    });

    test('a length on one side reads as Auto DJ says it', () {
      expect(mixFilterLabels(l, const MixFilters(minDuration: 120), server),
          ['2:00+']);
      expect(mixFilterLabels(l, const MixFilters(maxDuration: 360), server),
          ['Under 6:00']);
    });
  });

  group('a page holds what it applies (forSeed)', () {
    test('no mood where the server has no scores to filter by', () {
      server.moodFiltersAvailable = null;
      const f = MixFilters(mood: MoodFilter(voice: 'vocals'), minRating: 4);
      expect(f.forSeed(dolo()), const MixFilters(minRating: 4));
    });

    test('folders the server has, in its order; never every one', () {
      server.autoDJPaths = {'music': true, 'podcasts': true, 'spoken': true};
      expect(
          const MixFilters(foldersOff: ['spoken', 'gone', 'music'])
              .forSeed(dolo())
              .foldersOff,
          ['music', 'spoken']);
      expect(
          const MixFilters(foldersOff: ['music', 'podcasts', 'spoken'])
              .forSeed(dolo())
              .foldersOff,
          isEmpty,
          reason: 'the server would have nothing to draw from');
      server.autoDJPaths = {'music': true};
      expect(
          const MixFilters(foldersOff: ['podcasts']).forSeed(dolo()).foldersOff,
          isEmpty,
          reason: 'one folder: nothing to switch');
    });
  });

  group('the store', () {
    final store = MixFilterStore();

    test("empty at first; a page's filters are the next page's start", () {
      expect(store.of(dolo()), MixFilters.empty);
      const f = MixFilters(
          mood: MoodFilter(energy: 'relaxed'),
          harmonic: true,
          minRating: 6,
          skipWords: ['live']);
      store.set(dolo(), f);
      expect(store.of(dolo()), f);
    });

    test("the app's parts on every server, each server's parts its own", () {
      final other = Server('http://other.example', null, null, 'JWT', 'other')
        ..moodFiltersAvailable = true
        ..autoDJPaths = {'music': true, 'podcasts': true};
      store.set(
          dolo(),
          const MixFilters(
            mood: MoodFilter(energy: 'relaxed'),
            minDuration: 120,
            tempo: true,
            bpmTolerance: 4,
            harmonic: true,
            skipWords: ['live'],
            genres: GenreChoice(genres: ['Jazz']),
            minRating: 6,
            foldersOff: ['podcasts'],
          ));
      expect(
          store.of(dolo(other)),
          const MixFilters(
            mood: MoodFilter(energy: 'relaxed'),
            minDuration: 120,
            tempo: true,
            bpmTolerance: 4,
            harmonic: true,
            skipWords: ['live'],
          ),
          reason: "another server's genres, rating and folders are its own");
      expect(store.of(dolo()).genres, const GenreChoice(genres: ['Jazz']));
      expect(store.of(dolo()).minRating, 6);
      expect(store.of(dolo()).foldersOff, ['podcasts']);
    });

    test('what a page cannot apply stays for the pages that can', () {
      store.set(dolo(), const MixFilters(tempo: true, harmonic: true));
      expect(store.of(album()), MixFilters.empty,
          reason: "an album's page has no tempo or key");
      // Clear on the album's page.
      store.set(album(), MixFilters.empty);
      expect(store.of(dolo()), const MixFilters(tempo: true, harmonic: true));
      // Clear on a song's page.
      store.set(dolo(), MixFilters.empty);
      expect(store.of(dolo()), MixFilters.empty);

      // A mood set where the server filters by mood stays through a page
      // on one that can't.
      store.set(dolo(), const MixFilters(mood: MoodFilter(energy: 'relaxed')));
      final scoreless = Server('http://old.example', null, null, 'JWT', 'old');
      store.set(dolo(scoreless), MixFilters.empty);
      expect(store.of(dolo()).mood, const MoodFilter(energy: 'relaxed'));
    });

    test("never Auto DJ's: it neither reads nor writes them", () {
      final mgr = AutoDJManager();
      mgr
        ..harmonicMixingEnabled = true
        ..keywordFilterEnabled = true
        ..keywordFilterWords = ['interlude'];
      server.autoDJminRating = 8;
      addTearDown(() => mgr
        ..harmonicMixingEnabled = false
        ..keywordFilterEnabled = false
        ..keywordFilterWords = []);
      expect(store.of(dolo()), MixFilters.empty);
      store.set(dolo(), const MixFilters(minRating: 2, skipWords: ['live']));
      expect(mgr.keywordFilterWords, ['interlude']);
      expect(mgr.harmonicMixingEnabled, isTrue);
      expect(server.autoDJminRating, 8);
      expect(server.autoDJPaths, {'music': true, 'podcasts': true});
    });

    test("a page's filters are its own copy: a later page's change leaves "
        'them as they were', () {
      store.set(dolo(), const MixFilters(skipWords: ['live']));
      final opened = store.of(dolo());
      store.set(dolo(), const MixFilters(skipWords: ['remix']));
      expect(opened, const MixFilters(skipWords: ['live']));
      expect(store.of(dolo()), const MixFilters(skipWords: ['remix']));
    });
  });
}
