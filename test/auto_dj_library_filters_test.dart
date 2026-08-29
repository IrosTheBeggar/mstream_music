import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';

/// The Auto DJ library filters are built in ONE place and sent by two callers
/// — the DJ's own picks and the "Surprise me" opening track. They used to be
/// built separately, and the opener quietly omitted genre and track length, so
/// track one ignored filters that every later track honoured. These pin the
/// shared shape so a filter added in future reaches both.
void main() {
  Server serverWith({
    Map<String, bool>? paths,
    int? minRating,
    bool genreEnabled = false,
    String genreMode = 'whitelist',
    List<String> genres = const [],
  }) {
    final s = Server('http://x', 'u', 'p', '', 'local');
    s.autoDJPaths = paths ?? {'music': true};
    s.autoDJminRating = minRating;
    s.autoDJGenreEnabled = genreEnabled;
    s.autoDJGenreMode = genreMode;
    s.autoDJGenres = List<String>.from(genres);
    return s;
  }

  final mgr = AutoDJManager();

  setUp(() {
    // The manager is a singleton, so each test starts from a known baseline.
    mgr.durationFilterEnabled = false;
    mgr.minDurationSec = 120;
    mgr.maxDurationSec = AutoDJManager.durationCeilSec;
    mgr.allowUnknownDuration = false;
  });

  test('a wide-open config sends nothing', () {
    expect(mgr.libraryFilters(serverWith()), isEmpty);
  });

  test('only vpaths switched OFF are excluded', () {
    final f = mgr.libraryFilters(
        serverWith(paths: {'music': true, 'podcasts': false, 'spoken': false}));
    expect(f['ignoreVPaths'], containsAll(<String>['podcasts', 'spoken']));
    expect(f['ignoreVPaths'], isNot(contains('music')));
  });

  test('rating rides along when set', () {
    expect(mgr.libraryFilters(serverWith(minRating: 6))['minRating'], 6);
    expect(mgr.libraryFilters(serverWith())..remove('x'),
        isNot(contains('minRating')));
  });

  test('genre needs both the switch and a non-empty list', () {
    expect(
        mgr.libraryFilters(
            serverWith(genreEnabled: true, genres: const [])),
        isNot(contains('genres')),
        reason: 'an empty list constrains nothing');
    expect(
        mgr.libraryFilters(serverWith(genres: const ['jazz'])),
        isNot(contains('genres')),
        reason: 'switched off');
    final on = mgr.libraryFilters(serverWith(
        genreEnabled: true, genreMode: 'blacklist', genres: const ['jazz']));
    expect(on['genres'], ['jazz']);
    expect(on['genreMode'], 'blacklist');
  });

  group('track length', () {
    test('a bound on a rail is not sent', () {
      mgr.durationFilterEnabled = true;
      mgr.minDurationSec = AutoDJManager.durationFloorSec;
      mgr.maxDurationSec = AutoDJManager.durationCeilSec;
      final f = mgr.libraryFilters(serverWith());
      expect(f, isNot(contains('minDuration')));
      expect(f, isNot(contains('maxDuration')));
    });

    test('min-only sends just the minimum', () {
      mgr.durationFilterEnabled = true;
      mgr.minDurationSec = 120;
      mgr.maxDurationSec = AutoDJManager.durationCeilSec;
      final f = mgr.libraryFilters(serverWith());
      expect(f['minDuration'], 120);
      expect(f, isNot(contains('maxDuration')));
    });

    test('max-only sends just the maximum', () {
      mgr.durationFilterEnabled = true;
      mgr.minDurationSec = AutoDJManager.durationFloorSec;
      mgr.maxDurationSec = 120;
      final f = mgr.libraryFilters(serverWith());
      expect(f['maxDuration'], 120);
      expect(f, isNot(contains('minDuration')));
    });

    test('the switch being off suppresses the window entirely', () {
      mgr.durationFilterEnabled = false;
      mgr.minDurationSec = 120;
      mgr.maxDurationSec = 300;
      expect(mgr.libraryFilters(serverWith()), isEmpty);
    });

    test('allowUnknownDuration only rides along with a real bound', () {
      mgr.durationFilterEnabled = true;
      mgr.allowUnknownDuration = true;
      mgr.minDurationSec = AutoDJManager.durationFloorSec;
      mgr.maxDurationSec = AutoDJManager.durationCeilSec;
      expect(mgr.libraryFilters(serverWith()), isEmpty,
          reason: 'the server no-ops it without a window to apply it to');

      mgr.minDurationSec = 120;
      expect(mgr.libraryFilters(serverWith())['allowUnknownDuration'], isTrue);
    });
  });

  test('everything at once composes into one body', () {
    mgr.durationFilterEnabled = true;
    mgr.minDurationSec = 120;
    mgr.maxDurationSec = 600;
    final f = mgr.libraryFilters(serverWith(
      paths: {'music': true, 'podcasts': false},
      minRating: 8,
      genreEnabled: true,
      genres: const ['jazz', 'funk'],
    ));
    expect(f.keys, containsAll(<String>[
      'ignoreVPaths',
      'minRating',
      'genres',
      'genreMode',
      'minDuration',
      'maxDuration',
    ]));
  });
}
