import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';

void main() {
  // Fixed times, so every clock reads the same on every run.
  final t0 = DateTime.utc(2026, 11, 17, 12);
  DateTime at(int minutes, [int seconds = 0]) =>
      t0.add(Duration(minutes: minutes, seconds: seconds));

  TrackFacts song(String path, {String server = 'home'}) =>
      TrackFacts(server: server, path: path, title: path);
  String key(String path, {String server = 'home'}) => seedKey(server, path);

  // A list as its wire paths, oldest first; a trailing '*' marks the user's
  // own pin.
  List<String> rows(List<AutoDjSeed> list) =>
      [for (final s in list) '${s.wirePath}${s.pinned ? '*' : ''}'];

  // Drift: [n] DJ picks p0..p(n-1) played in turn, a minute apart.
  AutoDjSeeds picks(int n, {AutoDjSeeds from = AutoDjSeeds.empty}) {
    var s = from;
    for (var i = 0; i < n; i++) {
      s = s.pushPick(song('p$i'), now: at(i));
    }
    return s;
  }

  // [list] filled with [n] of the user's own rows m0..m(n-1).
  AutoDjSeeds manual(SeedList list, int n,
      {AutoDjSeeds from = AutoDjSeeds.empty, String prefix = 'm'}) {
    var s = from;
    for (var i = 0; i < n; i++) {
      s = s.addManual(list, song('$prefix$i'), now: at(i));
    }
    return s;
  }

  group('seedKey / seedWirePath', () {
    test('the wire path drops the leading slash a queue row keeps', () {
      expect(seedWirePath('/Music/a.flac'), 'Music/a.flac');
      expect(seedWirePath('Music/a.flac'), 'Music/a.flac');
    });

    test('one song is one key whichever form its path came in', () {
      expect(seedKey('home', '/Music/a.flac'), seedKey('home', 'Music/a.flac'));
      expect(seedKey('home', 'Music/a.flac'), 'home\u0000Music/a.flac');
      // The same vpath on another server is another song.
      expect(seedKey('lab', 'Music/a.flac'),
          isNot(seedKey('home', 'Music/a.flac')));
    });

    test('a row keeps the raw path and normalises its key and wire path', () {
      final s = AutoDjSeed(
          song: song('/Music/a.flac'), origin: SeedOrigin.manual, addedAt: t0);
      expect(s.song.path, '/Music/a.flac');
      expect(s.wirePath, 'Music/a.flac');
      expect(s.key, key('Music/a.flac'));
      expect(s.server, 'home');
    });

    test('a browsed /-path and a DJ pick of the same song are one row', () {
      final s = AutoDjSeeds.empty
          .pushPick(song('/Music/a.flac'), now: t0)
          .pushPick(song('p1'), now: at(1))
          .pushPick(song('Music/a.flac'), now: at(2));
      expect(rows(s.moreLike), ['p1', 'Music/a.flac']);
      expect(s.has(SeedList.moreLike, key('/Music/a.flac')), isTrue);
    });
  });

  group('fresh / empty', () {
    test('empty is not frozen and holds nothing', () {
      expect(AutoDjSeeds.empty.isEmpty, isTrue);
      expect(AutoDjSeeds.empty.frozen, isFalse);
      expect(AutoDjSeeds.empty.frozenAt, isNull);
    });

    test('a fresh set follows the stored mode', () {
      final close = AutoDjSeeds.fresh(frozen: true, now: t0);
      expect(close.frozen, isTrue);
      expect(close.frozenAt, t0);
      expect(close.isEmpty, isTrue);
      final drift = AutoDjSeeds.fresh(frozen: false, now: t0);
      expect(drift.frozen, isFalse);
      expect(drift.frozenAt, isNull);
    });
  });

  group('pushPick (More like, Drift)', () {
    test('a pick comes in unpinned as the newest row', () {
      final s = picks(2);
      expect(rows(s.moreLike), ['p0', 'p1']);
      expect(s.moreLike.last.origin, SeedOrigin.pick);
      expect(s.moreLike.last.addedAt, at(1));
      expect(s.lessLike, isEmpty);
    });

    test('five unpinned rows stay, the oldest leaving first', () {
      expect(rows(picks(7).moreLike), ['p2', 'p3', 'p4', 'p5', 'p6']);
    });

    test('pinned rows survive the rotation', () {
      var s = picks(5);
      s = s
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(5))
          .setPinned(SeedList.moreLike, key('p1'), true, now: at(5));
      for (var i = 5; i < 9; i++) {
        s = s.pushPick(song('p$i'), now: at(i));
      }
      // Two pins leave room for five unpinned rows.
      expect(rows(s.moreLike), ['p0*', 'p1*', 'p4', 'p5', 'p6', 'p7', 'p8']);
    });

    test('the unpinned room is what the pins leave of eight', () {
      var s = picks(5);
      for (var i = 0; i < 4; i++) {
        s = s.setPinned(SeedList.moreLike, key('p$i'), true, now: at(5));
      }
      for (var i = 0; i < 5; i++) {
        s = s.pushPick(song('q$i'), now: at(6 + i));
      }
      expect(rows(s.moreLike),
          ['p0*', 'p1*', 'p2*', 'p3*', 'q1', 'q2', 'q3', 'q4']);
    });

    test('eight rows of the user\'s own leave no room: the pick stays out',
        () {
      final s = manual(SeedList.moreLike, 8);
      expect(s.pushPick(song('x'), now: at(9)), same(s));
    });

    test('a re-pick moves to the newest place and keeps its pin', () {
      final s = picks(3)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(3))
          .pushPick(song('p0'), now: at(4));
      expect(rows(s.moreLike), ['p1', 'p2', 'p0*']);
      expect(s.moreLike.last.addedAt, at(4));
    });

    test('a re-pick of the newest row is no change', () {
      final s = picks(3);
      expect(s.pushPick(song('p2'), now: at(9)), same(s));
    });

    test('a song in Less like is never pushed', () {
      final s = AutoDjSeeds.empty.addManual(SeedList.lessLike, song('x'), now: t0);
      expect(s.pushPick(song('x'), now: at(1)), same(s));
      final skipped =
          picks(2).quickSkip(song('p1'), learn: true, now: at(2));
      expect(skipped.pushPick(song('p1'), now: at(3)), same(skipped));
    });

    // Drift's blend (PLAN-3 R1): at a lane's first pick the song playing
    // joins as the opener, beside the pins the lane carried over.
    test('the song playing joins beside the pins: they stay pinned and in '
        'place, it comes in unpinned as the newest row', () {
      final carried = picks(3)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(3))
          .setPinned(SeedList.moreLike, key('p2'), true, now: at(3))
          .carryOver(at(4), frozen: false);
      expect(rows(carried.moreLike), ['p0*', 'p2*']);
      final s = carried.pushPick(song('/user/a.flac'),
          origin: SeedOrigin.opener, now: at(5));
      expect(rows(s.moreLike), ['p0*', 'p2*', 'user/a.flac']);
      expect(s.moreLike.last.origin, SeedOrigin.opener);
      expect(s.moreLike.last.pinned, isFalse);
      expect(s.moreLike.last.addedAt, at(5));
      // Five new picks rotate it out like any pick: the oldest unpinned row.
      var later = s;
      for (var i = 0; i < 5; i++) {
        later = later.pushPick(song('q$i'), now: at(6 + i));
      }
      expect(rows(later.moreLike),
          ['p0*', 'p2*', 'q0', 'q1', 'q2', 'q3', 'q4']);
    });

    test('with eight pins the song playing stays out', () {
      final full = manual(SeedList.moreLike, 8);
      expect(
          full.pushPick(song('user'), origin: SeedOrigin.opener, now: at(9)),
          same(full));
    });

    test('the opener comes in as its own origin, unpinned', () {
      final s = AutoDjSeeds.empty
          .pushPick(song('/Music/o.flac'), origin: SeedOrigin.opener, now: t0);
      expect(rows(s.moreLike), ['Music/o.flac']);
      expect(s.moreLike.single.origin, SeedOrigin.opener);
    });

    test('a local file or a row with no path is never a seed', () {
      const local = TrackFacts(server: '', path: '/sdcard/Music/a.mp3');
      expect(AutoDjSeeds.empty.pushPick(local, now: t0), same(AutoDjSeeds.empty));
      expect(AutoDjSeeds.empty.pushPick(song('/'), now: t0),
          same(AutoDjSeeds.empty));
      expect(AutoDjSeeds.empty.quickSkip(local, learn: true, now: t0),
          same(AutoDjSeeds.empty));
      expect(AutoDjSeeds.empty.addManual(SeedList.lessLike, local, now: t0),
          same(AutoDjSeeds.empty));
    });
  });

  group('quickSkip', () {
    test('without learning: the song leaves More like, nothing is added', () {
      final s = picks(3).quickSkip(song('p1'), learn: false, now: at(3));
      expect(rows(s.moreLike), ['p0', 'p2']);
      expect(s.lessLike, isEmpty);
    });

    test('learning: the song moves to Less like, unpinned, its clock from now',
        () {
      final s = picks(3).quickSkip(song('p1'), learn: true, now: at(3));
      expect(rows(s.moreLike), ['p0', 'p2']);
      expect(rows(s.lessLike), ['p1']);
      expect(s.lessLike.single.origin, SeedOrigin.skip);
      expect(s.lessLike.single.addedAt, at(3));
    });

    test('a song the user pinned in More like stays, and is not learned', () {
      final s = picks(3).setPinned(SeedList.moreLike, key('p1'), true, now: at(3));
      expect(s.quickSkip(song('p1'), learn: true, now: at(4)), same(s));
      expect(s.quickSkip(song('p1'), learn: false, now: at(4)), same(s));
    });

    test('a song outside More like is still learned', () {
      final s = AutoDjSeeds.empty.quickSkip(song('x'), learn: true, now: t0);
      expect(rows(s.lessLike), ['x']);
    });

    test('a skip that drops and learns nothing is no change', () {
      final s = picks(2);
      expect(s.quickSkip(song('x'), learn: false, now: at(3)), same(s));
    });

    test('a re-skip moves to the newest place with a fresh clock, keeping its '
        'pin', () {
      var s = AutoDjSeeds.empty
          .quickSkip(song('a'), learn: true, now: t0)
          .quickSkip(song('b'), learn: true, now: at(1));
      s = s.quickSkip(song('a'), learn: true, now: at(2));
      expect(rows(s.lessLike), ['b', 'a']);
      expect(s.lessLike.last.addedAt, at(2));
      final pinned = AutoDjSeeds.empty
          .addManual(SeedList.lessLike, song('a'), now: t0)
          .quickSkip(song('b'), learn: true, now: at(1))
          .quickSkip(song('a'), learn: true, now: at(2));
      expect(rows(pinned.lessLike), ['b', 'a*']);
    });

    test('Less like keeps eight, the oldest unpinned leaving first', () {
      var s = AutoDjSeeds.empty;
      for (var i = 0; i < 9; i++) {
        s = s.quickSkip(song('s$i'), learn: true, now: at(i));
      }
      expect(rows(s.lessLike), ['s1', 's2', 's3', 's4', 's5', 's6', 's7', 's8']);
      // With pins among them, a skip past eight pushes out the oldest
      // unpinned row, never a pin.
      var mixed = manual(SeedList.lessLike, 3)
          .quickSkip(song('a'), learn: true, now: at(3));
      for (var i = 0; i < 5; i++) {
        mixed = mixed.quickSkip(song('s$i'), learn: true, now: at(4 + i));
      }
      expect(rows(mixed.lessLike),
          ['m0*', 'm1*', 'm2*', 's0', 's1', 's2', 's3', 's4']);
      final next = mixed.quickSkip(song('z'), learn: true, now: at(9));
      expect(rows(next.lessLike),
          ['m0*', 'm1*', 'm2*', 's1', 's2', 's3', 's4', 'z']);
    });

    test('with eight pinned Less like rows a skip is not added', () {
      final s = manual(SeedList.lessLike, 8);
      expect(s.quickSkip(song('x'), learn: true, now: at(9)), same(s));
      // It still leaves More like.
      final both = picks(1, from: s);
      final skipped = both.quickSkip(song('p0'), learn: true, now: at(9));
      expect(skipped.moreLike, isEmpty);
      expect(rows(skipped.lessLike), rows(s.lessLike));
    });
  });

  group('expiry (Drift time)', () {
    test('an unpinned row is kept at 29:59 and expires at 30:00', () {
      final s = AutoDjSeeds.empty.quickSkip(song('x'), learn: true, now: t0);
      expect(s.prune(at(29, 59)), same(s));
      expect(s.prune(at(30)).lessLike, isEmpty);
    });

    test('a pinned row never expires', () {
      final s = AutoDjSeeds.empty.addManual(SeedList.lessLike, song('x'), now: t0);
      expect(s.prune(at(600)), same(s));
    });

    test('unpinning a Less like row starts its 30 minutes over', () {
      final s = AutoDjSeeds.empty
          .addManual(SeedList.lessLike, song('x'), now: t0)
          .setPinned(SeedList.lessLike, key('x'), false, now: at(20));
      expect(s.lessLike.single.addedAt, at(20));
      expect(s.prune(at(49, 59)), same(s));
      expect(s.prune(at(50)).lessLike, isEmpty);
    });

    test('nextExpiry is the earliest unpinned row\'s, none while frozen', () {
      final s = AutoDjSeeds.empty
          .addManual(SeedList.lessLike, song('pin'), now: t0)
          .quickSkip(song('b'), learn: true, now: at(5))
          .quickSkip(song('a'), learn: true, now: at(2));
      expect(s.nextExpiry, at(32));
      expect(s.freeze(at(10)).nextExpiry, isNull);
      expect(AutoDjSeeds.empty.nextExpiry, isNull);
      expect(manual(SeedList.lessLike, 2).nextExpiry, isNull);
    });
  });

  group('Stay close (frozen)', () {
    AutoDjSeeds frozenSet() => picks(2)
        .quickSkip(song('x'), learn: true, now: at(2))
        .setPinned(SeedList.moreLike, key('p0'), true, now: at(3))
        .freeze(at(4));

    test('pushPick, quickSkip, prune and setPinned change nothing', () {
      final s = frozenSet();
      expect(s.pushPick(song('y'), now: at(5)), same(s));
      expect(s.quickSkip(song('p1'), learn: true, now: at(5)), same(s));
      expect(s.quickSkip(song('p1'), learn: false, now: at(5)), same(s));
      expect(s.prune(at(600)), same(s));
      expect(s.setPinned(SeedList.moreLike, key('p1'), true, now: at(5)),
          same(s));
      expect(s.setPinned(SeedList.lessLike, key('x'), true, now: at(5)),
          same(s));
    });

    test('every row shows pinned; the stored pins are untouched', () {
      final s = frozenSet();
      expect([for (final r in s.moreLike) s.shownPinned(r)], [true, true]);
      expect(s.shownPinned(s.lessLike.single), isTrue);
      expect(rows(s.moreLike), ['p0*', 'p1']);
      expect(rows(s.lessLike), ['x']);
    });

    test('the user\'s own edits still work', () {
      final s = frozenSet()
          .addManual(SeedList.moreLike, song('m'), now: at(5))
          .remove(SeedList.lessLike, key('x'))
          .move(key('p1'), now: at(6));
      expect(rows(s.moreLike), ['p0*', 'm*']);
      expect(rows(s.lessLike), ['p1*']);
      expect(s.frozen, isTrue);
    });

    test('freeze and thaw are idempotent', () {
      final s = frozenSet();
      expect(s.freeze(at(9)), same(s));
      expect(s.frozenAt, at(4));
      final drift = picks(2);
      expect(drift.thaw(at(9)), same(drift));
    });

    // A device that slept past a row's 30 minutes can still list it when the
    // user switches: the expiry timers run on the monotonic clock.
    test('a Less like row whose Drift time ran out is not frozen in', () {
      final drift = AutoDjSeeds.empty
          .quickSkip(song('x'), learn: true, now: t0)
          .addManual(SeedList.lessLike, song('pin'), now: t0);
      final late = drift.freeze(at(30));
      expect(late.frozen, isTrue);
      expect(late.frozenAt, at(30));
      expect(rows(late.lessLike), ['pin*']);
      expect(late.negativesFor('home').paths, ['pin']);
      // Thawed hours later, nothing comes back.
      expect(rows(late.thaw(at(300)).prune(at(300)).lessLike), ['pin*']);
    });

    test('one with time left is frozen in, its clock stopped', () {
      final drift =
          AutoDjSeeds.empty.quickSkip(song('x'), learn: true, now: t0);
      final s = drift.freeze(at(29, 59));
      expect(rows(s.lessLike), ['x']);
      expect(s.shownPinned(s.lessLike.single), isTrue);
      expect(s.prune(at(600)), same(s));
      // A second left of its 30 minutes once thawed.
      final thawed = s.thaw(at(90));
      expect(rows(thawed.prune(at(90, 0)).lessLike), ['x']);
      expect(thawed.prune(at(90, 1)).lessLike, isEmpty);
    });

    test('a freeze keeps the stored pins and More like as they were', () {
      final drift = picks(2)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(2))
          .quickSkip(song('x'), learn: true, now: at(2));
      final s = drift.freeze(at(60));
      expect(rows(s.moreLike), ['p0*', 'p1']);
      expect(s.lessLike, isEmpty);
      expect(rows(s.thaw(at(61)).moreLike), ['p0*', 'p1']);
    });

    test('thaw shows the user\'s own pins again', () {
      final s = frozenSet().thaw(at(10));
      expect(s.frozen, isFalse);
      expect(s.frozenAt, isNull);
      expect([for (final r in s.moreLike) s.shownPinned(r)], [true, false]);
      expect(s.shownPinned(s.lessLike.single), isFalse);
    });

    test('thaw moves the unpinned Less like clocks forward by the pause', () {
      final s = AutoDjSeeds.empty
          .quickSkip(song('x'), learn: true, now: t0)
          .addManual(SeedList.lessLike, song('pin'), now: at(1))
          .freeze(at(10))
          .thaw(at(70));
      // Frozen for an hour: x has run 10 minutes of its 30.
      expect(s.lessLike.first.addedAt, at(60));
      expect(s.lessLike.last.addedAt, at(1));
      expect(s.prune(at(89, 59)), same(s));
      expect(rows(s.prune(at(90)).lessLike), ['pin*']);
    });

    test('a row that came in after the freeze began stood still only since',
        () {
      final s = AutoDjSeeds(
        lessLike: [
          AutoDjSeed(song: song('x'), origin: SeedOrigin.skip, addedAt: at(20)),
        ],
        frozen: true,
        frozenAt: at(10),
      ).thaw(at(70));
      expect(s.lessLike.single.addedAt, at(70));
    });

    test('thaw trims More like to the ring, the oldest unpinned first', () {
      final s = picks(5)
          .freeze(at(5))
          .admitAnchor(song('a'), usable: (_) => false, now: at(6));
      expect(s.moreLike.length, 6);
      expect(rows(s.thaw(at(7)).moreLike), ['p1', 'p2', 'p3', 'p4', 'a']);
    });
  });

  group('admitAnchor (the Stay close bootstrap)', () {
    final close = AutoDjSeeds.fresh(frozen: true, now: t0);

    test('an empty More like admits the anchor, though the lists are frozen',
        () {
      final s = close.admitAnchor(song('/Music/a.flac'),
          usable: (_) => true, now: at(1));
      expect(rows(s.moreLike), ['Music/a.flac']);
      expect(s.moreLike.single.origin, SeedOrigin.anchor);
      expect(s.moreLike.single.pinned, isFalse);
      expect(s.shownPinned(s.moreLike.single), isTrue);
      expect(s.frozen, isTrue);
    });

    test('rows usable rejects admit it; a second admission keeps the first '
        'anchor beside it', () {
      final base = picks(2).freeze(at(2));
      final first =
          base.admitAnchor(song('a'), usable: (_) => false, now: at(3));
      expect(rows(first.moreLike), ['p0', 'p1', 'a']);
      final second =
          first.admitAnchor(song('b'), usable: (_) => false, now: at(4));
      expect(rows(second.moreLike), ['p0', 'p1', 'a', 'b']);
      expect(
          second.moreLike.where((s) => s.origin == SeedOrigin.anchor).length, 2);
    });

    // A Stay close lane on 'nas' anchored on a1; the DJ moved to home, and
    // the new lane carried a1 over but can't send it: the lane admits its
    // own song, and a1 stays listed.
    test('a carried anchor the lane can\'t use stays listed beside the new one',
        () {
      final carried = AutoDjSeeds.fresh(frozen: true, now: t0)
          .admitAnchor(song('a1', server: 'nas'),
              usable: (_) => false, now: at(1))
          .carryOver(at(5), frozen: true);
      expect(rows(carried.moreLike), ['a1']);
      final s = carried.admitAnchor(song('b'),
          usable: (r) => r.server == 'home', now: at(6));
      expect([for (final r in s.moreLike) '${r.server}:${r.wirePath}'],
          ['nas:a1', 'home:b']);
      expect([for (final r in s.moreLike) r.origin],
          [SeedOrigin.anchor, SeedOrigin.anchor]);
      expect(s.frozen, isTrue);
      expect(s.frozenAt, t0);
    });

    test('a usable row: no anchor', () {
      final s = picks(2).freeze(at(2));
      expect(
          s.admitAnchor(song('a'), usable: (r) => r.wirePath == 'p1', now: at(3)),
          same(s));
    });

    test('a song in Less like, or already in More like: no anchor', () {
      final s = AutoDjSeeds.empty
          .addManual(SeedList.lessLike, song('a'), now: t0)
          .pushPick(song('p0'), now: at(1))
          .freeze(at(2));
      expect(s.admitAnchor(song('a'), usable: (_) => false, now: at(3)),
          same(s));
      expect(s.admitAnchor(song('p0'), usable: (_) => false, now: at(3)),
          same(s));
    });

    test('eight of the user\'s own pins, none usable: the one song comes in '
        'as a ninth row and every pin stays', () {
      final s = manual(SeedList.moreLike, 8).freeze(at(9));
      final admitted =
          s.admitAnchor(song('a'), usable: (_) => false, now: at(10));
      expect(rows(admitted.moreLike), [
        for (var i = 0; i < 8; i++) 'm$i*',
        'a',
      ]);
      expect(admitted.moreLike.last.origin, SeedOrigin.anchor);
      expect(admitted.canAdd(SeedList.moreLike), isFalse,
          reason: 'the page shows the list full until rows go');
    });

    test('a full More like with nothing usable takes the one song in past '
        'eight', () {
      // Frozen, all eight show pinned, though five are the DJ's own picks:
      // the old server's songs after a move of the DJ, say.
      final s = manual(SeedList.moreLike, 3, from: picks(5)).freeze(at(9));
      expect(rows(s.moreLike),
          ['p0', 'p1', 'p2', 'p3', 'p4', 'm0*', 'm1*', 'm2*']);
      final admitted =
          s.admitAnchor(song('a'), usable: (_) => false, now: at(10));
      expect(rows(admitted.moreLike),
          ['p0', 'p1', 'p2', 'p3', 'p4', 'm0*', 'm1*', 'm2*', 'a'],
          reason: 'nothing is removed to make room');
      // A usable row anchors the lane instead: nothing comes in.
      expect(
          s.admitAnchor(song('a'), usable: (r) => r.wirePath == 'p0', now: at(10)),
          same(s));
    });

    test('at eight rows the one song comes in beside an older anchor, and '
        'nothing leaves', () {
      // An anchor from earlier, then seven more rows, frozen at eight.
      final s = manual(SeedList.moreLike, 3,
              from: picks(4,
                  from: AutoDjSeeds.empty.admitAnchor(song('old'),
                      usable: (_) => false, now: t0)))
          .freeze(at(9));
      expect(rows(s.moreLike),
          ['old', 'p0', 'p1', 'p2', 'p3', 'm0*', 'm1*', 'm2*']);
      final admitted =
          s.admitAnchor(song('a'), usable: (_) => false, now: at(10));
      expect(rows(admitted.moreLike),
          ['old', 'p0', 'p1', 'p2', 'p3', 'm0*', 'm1*', 'm2*', 'a']);
    });

    test('it stops at the bound a restart brings back', () {
      // A server that keeps refusing what each lane takes in: one song per
      // lane, never past what a launch keeps.
      var s = manual(SeedList.moreLike, 8).freeze(at(9));
      for (var i = 0; i < 20; i++) {
        s = s.admitAnchor(song('a$i'), usable: (_) => false, now: at(10 + i));
      }
      expect(s.moreLike, hasLength(AutoDjSeeds.maxStoredPerList));
      expect(rows(s.moreLike).take(8), [for (var i = 0; i < 8; i++) 'm$i*'],
          reason: 'every pin stays');
      final full = s;
      expect(full.admitAnchor(song('z'), usable: (_) => false, now: at(40)),
          same(full));
    });

    test('past eight the list keeps what it holds through a merge, a load '
        'and a new lane, and Drift trims it back at the thaw', () {
      // Eight unusable rows and the ninth, the one song.
      final nine = manual(SeedList.moreLike, 3, from: picks(5))
          .freeze(at(9))
          .admitAnchor(song('a'), usable: (_) => false, now: at(10));
      expect(nine.moreLike, hasLength(9));
      // A new lane in Stay close keeps every row.
      expect(nine.carryOver(at(11), frozen: true).moreLike, hasLength(9));
      // A merge of rows held aside makes room as an edit would, one in and
      // the oldest unpinned out, but takes nothing of its own.
      final held = AutoDjSeeds.fresh(frozen: true, now: at(11))
          .addManual(SeedList.moreLike, song('h'), now: at(11));
      final merged = nine.merge(held, now: at(12));
      expect(merged.moreLike, hasLength(9));
      expect(rows(merged.moreLike).last, 'h*');
      expect(rows(merged.moreLike).first, 'p1',
          reason: 'the oldest unpinned row made room for the add');
      expect(nine.merge(AutoDjSeeds.empty, now: at(12)), same(nine));
      // The launch brings all nine back in Stay close, and the pins alone in
      // Drift.
      final stored = nine.storedRows;
      expect(stored.where((r) => r.list == SeedList.moreLike), hasLength(9));
      final back = loadStoredPins(AutoDjSeeds.empty, stored,
          knownServer: (_) => true, frozen: true, frozenAt: at(10), now: at(20));
      expect(rows(back.seeds.moreLike), rows(nine.moreLike));
      final drift = loadStoredPins(AutoDjSeeds.empty, stored,
          knownServer: (_) => true, frozen: false, now: at(20));
      expect(rows(drift.seeds.moreLike), ['m0*', 'm1*', 'm2*']);
      // Back in Drift the caps apply again: eight rows at most, the oldest
      // unpinned one out, and the ring's five unpinned beside the three pins.
      final thawed = nine.thaw(at(30));
      expect(rows(thawed.moreLike),
          ['p1', 'p2', 'p3', 'p4', 'm0*', 'm1*', 'm2*', 'a']);
    });

    test('it pushes out no pick, even where Drift would rotate one', () {
      // Five unpinned picks fill Drift's ring; the anchor is a sixth row.
      final s = picks(5);
      final admitted =
          s.admitAnchor(song('a'), usable: (_) => false, now: at(6));
      expect(rows(admitted.moreLike), ['p0', 'p1', 'p2', 'p3', 'p4', 'a']);
    });

    test('an anchor the user pinned is their own row and stays', () {
      final s = AutoDjSeeds.empty
          .admitAnchor(song('a'), usable: (_) => false, now: t0)
          .setPinned(SeedList.moreLike, key('a'), true, now: at(1))
          .freeze(at(2))
          .admitAnchor(song('b'), usable: (_) => false, now: at(3));
      expect(rows(s.moreLike), ['a*', 'b']);
    });
  });

  group('caps and canAdd', () {
    test('a list takes rows until eight of them show pinned', () {
      expect(AutoDjSeeds.empty.canAdd(SeedList.moreLike), isTrue);
      final full = manual(SeedList.lessLike, 8);
      expect(full.canAdd(SeedList.lessLike), isFalse);
      expect(full.canAdd(SeedList.moreLike), isTrue);
    });

    test('an unpinned row makes room in Drift, but not while frozen', () {
      final s = manual(SeedList.lessLike, 7)
          .quickSkip(song('x'), learn: true, now: at(8));
      expect(s.lessLike.length, 8);
      expect(s.canAdd(SeedList.lessLike), isTrue);
      expect(s.freeze(at(9)).canAdd(SeedList.lessLike), isFalse);
    });

    test('an add at eight rows pushes out the unpinned one', () {
      final s = manual(SeedList.lessLike, 7)
          .quickSkip(song('x'), learn: true, now: at(8))
          .addManual(SeedList.lessLike, song('y'), now: at(9));
      expect(rows(s.lessLike),
          ['m0*', 'm1*', 'm2*', 'm3*', 'm4*', 'm5*', 'm6*', 'y*']);
    });

    test('addManual and move into eight shown-pinned rows change nothing', () {
      final pins = manual(SeedList.moreLike, 8)
          .quickSkip(song('x'), learn: true, now: at(9));
      expect(pins.addManual(SeedList.moreLike, song('y'), now: at(10)),
          same(pins));
      expect(pins.move(key('x'), now: at(10)), same(pins));
      // Frozen, eight rows show pinned whatever their stored pin.
      final frozen = picks(5)
          .quickSkip(song('x'), learn: true, now: at(5))
          .addManual(SeedList.moreLike, song('m0'), now: at(6))
          .addManual(SeedList.moreLike, song('m1'), now: at(6))
          .addManual(SeedList.moreLike, song('m2'), now: at(6))
          .freeze(at(7));
      expect(frozen.moreLike.length, 8);
      expect(frozen.addManual(SeedList.moreLike, song('y'), now: at(8)),
          same(frozen));
      expect(frozen.move(key('x'), now: at(8)), same(frozen));
    });
  });

  group('manual edits', () {
    test('Add song pins the row and takes it out of the other list', () {
      final s = picks(2).addManual(SeedList.lessLike, song('p0'), now: at(2));
      expect(rows(s.moreLike), ['p1']);
      expect(rows(s.lessLike), ['p0*']);
      expect(s.lessLike.single.origin, SeedOrigin.manual);
      expect(s.lessLike.single.addedAt, at(2));
    });

    test('adding a song already in the list pins it as the newest row', () {
      final s = picks(3).addManual(SeedList.moreLike, song('p0'), now: at(3));
      expect(rows(s.moreLike), ['p1', 'p2', 'p0*']);
    });

    test('an add in Drift keeps More like within the ring', () {
      final s = manual(SeedList.moreLike, 3, from: picks(5))
          .addManual(SeedList.moreLike, song('m3'), now: at(9));
      // Four pins leave room for four unpinned rows.
      expect(rows(s.moreLike),
          ['p1', 'p2', 'p3', 'p4', 'm0*', 'm1*', 'm2*', 'm3*']);
    });

    test('move takes a row to the other list, pinned, with its vector', () {
      final s = picks(1)
          .quickSkip(song('x'), learn: true, now: at(1))
          .withVector(key('x'), 'VEC', 'model-1')
          .move(key('x'), now: at(2));
      expect(rows(s.moreLike), ['p0', 'x*']);
      expect(s.lessLike, isEmpty);
      expect(s.moreLike.last.origin, SeedOrigin.manual);
      expect(s.moreLike.last.vector, 'VEC');
      expect(s.moreLike.last.vectorModel, 'model-1');
      final back = s.move(key('p0'), now: at(3));
      expect(rows(back.moreLike), ['x*']);
      expect(rows(back.lessLike), ['p0*']);
    });

    test('move of a row that is not there changes nothing', () {
      final s = picks(2);
      expect(s.move(key('x'), now: at(3)), same(s));
    });

    test('remove deletes a row whatever its pin', () {
      final s = picks(2)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(2))
          .remove(SeedList.moreLike, key('p0'));
      expect(rows(s.moreLike), ['p1']);
      expect(s.remove(SeedList.moreLike, key('p0')), same(s));
      expect(s.remove(SeedList.lessLike, key('p1')), same(s));
    });

    test('setPinned is no change for a missing row or the same pin', () {
      final s = picks(2);
      expect(s.setPinned(SeedList.moreLike, key('p0'), false, now: at(2)),
          same(s));
      expect(s.setPinned(SeedList.lessLike, key('p0'), true, now: at(2)),
          same(s));
    });

    test('unpinning a More like row leaves it until the next pick', () {
      var s = manual(SeedList.moreLike, 1, from: picks(5));
      s = s.setPinned(SeedList.moreLike, key('m0'), false, now: at(6));
      expect(rows(s.moreLike), ['p0', 'p1', 'p2', 'p3', 'p4', 'm0']);
      // The next pick rotates the list back to five unpinned rows.
      s = s.pushPick(song('q'), now: at(7));
      expect(rows(s.moreLike), ['p2', 'p3', 'p4', 'm0', 'q']);
    });
  });

  group('removals', () {
    test('removeOrigin drops the rows of one origin', () {
      final s = AutoDjSeeds.empty
          .pushPick(song('o'), origin: SeedOrigin.opener, now: t0)
          .pushPick(song('p'), now: at(1))
          .quickSkip(song('x'), learn: true, now: at(2));
      expect(rows(s.removeOrigin(SeedOrigin.opener).moreLike), ['p']);
      expect(s.removeOrigin(SeedOrigin.skip).lessLike, isEmpty);
      expect(s.removeOrigin(SeedOrigin.anchor), same(s));
    });

    test('withoutServer drops every row of that server, pinned or not', () {
      final s = AutoDjSeeds.empty
          .pushPick(song('a', server: 'home'), now: t0)
          .pushPick(song('b', server: 'lab'), now: at(1))
          .addManual(SeedList.moreLike, song('c', server: 'lab'), now: at(2))
          .quickSkip(song('d', server: 'lab'), learn: true, now: at(3))
          .addManual(SeedList.lessLike, song('e', server: 'home'), now: at(4));
      final gone = s.withoutServer('lab');
      expect(rows(gone.moreLike), ['a']);
      expect(rows(gone.lessLike), ['e*']);
      expect(gone.withoutServer('lab'), same(gone));
    });

    test('withoutKeys drops the rows named', () {
      final s = picks(3).quickSkip(song('x'), learn: true, now: at(3));
      final less = s.withoutKeys({key('p1'), key('x')});
      expect(rows(less.moreLike), ['p0', 'p2']);
      expect(less.lessLike, isEmpty);
      expect(s.withoutKeys(const {}), same(s));
      expect(s.withoutKeys({key('nope')}), same(s));
    });

    test('withVector caches on the row; the same vector is no change', () {
      final s = AutoDjSeeds.empty
          .quickSkip(song('x'), learn: true, now: t0)
          .withVector(key('x'), 'VEC', 'model-1');
      expect(s.lessLike.single.vector, 'VEC');
      expect(s.lessLike.single.vectorModel, 'model-1');
      expect(s.withVector(key('x'), 'VEC', 'model-1'), same(s));
      expect(s.withVector(key('nope'), 'VEC', 'model-1'), same(s));
      expect(s.withVector(key('x'), 'VEC2', 'model-2').lessLike.single.vector,
          'VEC2');
    });
  });

  group('seedAddHeldAside (where an Add song lands)', () {
    test('while a set is held aside, there', () {
      for (final armed in [true, false]) {
        for (final picked in [true, false]) {
          expect(
              seedAddHeldAside(held: true, armed: armed, lanePicked: picked),
              isTrue);
        }
      }
    });

    test('with the DJ off, aside', () {
      expect(seedAddHeldAside(held: false, armed: false, lanePicked: false),
          isTrue);
    });

    test('with the DJ on before its lane has picked, aside', () {
      // A queue clear keeps the DJ armed and starts a lane that has not
      // picked: the Start from the empty queue clears once more.
      expect(seedAddHeldAside(held: false, armed: true, lanePicked: false),
          isTrue);
    });

    test('once the lane has picked, into the live set', () {
      expect(seedAddHeldAside(held: false, armed: true, lanePicked: true),
          isFalse);
    });

    test('a row held aside outlives the seeded start and joins at its first '
        'pick', () {
      // The lane after a clear: live is fresh, the add is held aside.
      final pending = AutoDjSeeds.fresh(frozen: false, now: t0)
          .addManual(SeedList.moreLike, song('m'), now: at(1))
          .addManual(SeedList.lessLike, song('n'), now: at(1));
      // Start: the seeded start's clear makes live fresh again, then the
      // opener comes in.
      final live = AutoDjSeeds.fresh(frozen: false, now: at(2))
          .pushPick(song('o'), origin: SeedOrigin.opener, now: at(2));
      final s = live.merge(pending, now: at(3));
      expect(rows(s.moreLike), ['o', 'm*']);
      expect(rows(s.lessLike), ['n*']);
    });
  });

  group('merge (the held-aside set)', () {
    test('pending rows come in as they are, the newest of their lists', () {
      final pending = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, song('m'), now: t0)
          .addManual(SeedList.lessLike, song('n'), now: t0);
      final s = picks(2).merge(pending, now: at(5));
      expect(rows(s.moreLike), ['p0', 'p1', 'm*']);
      expect(rows(s.lessLike), ['n*']);
      // A row the user unpinned while it was held aside stays unpinned.
      final unpinned = pending.setPinned(SeedList.moreLike, key('m'), false,
          now: at(1));
      expect(rows(picks(2).merge(unpinned, now: at(5)).moreLike),
          ['p0', 'p1', 'm']);
    });

    test('a pending row wins over the same song in live\'s other list', () {
      final pending =
          AutoDjSeeds.empty.addManual(SeedList.lessLike, song('p0'), now: t0);
      final s = picks(2).merge(pending, now: at(5));
      expect(rows(s.moreLike), ['p1']);
      expect(rows(s.lessLike), ['p0*']);
    });

    test('and over the same song in the same list', () {
      final pending =
          AutoDjSeeds.empty.addManual(SeedList.moreLike, song('p0'), now: t0);
      expect(rows(picks(2).merge(pending, now: at(5)).moreLike), ['p1', 'p0*']);
    });

    test('a vector cached on the live row carries over', () {
      final live = AutoDjSeeds.empty
          .quickSkip(song('x'), learn: true, now: t0)
          .withVector(key('x'), 'VEC', 'model-1');
      final pending =
          AutoDjSeeds.empty.addManual(SeedList.lessLike, song('x'), now: at(1));
      final s = live.merge(pending, now: at(2));
      expect(rows(s.lessLike), ['x*']);
      expect(s.lessLike.single.vector, 'VEC');
    });

    test('an empty pending set changes nothing', () {
      final live = picks(2);
      expect(live.merge(AutoDjSeeds.empty, now: at(3)), same(live));
      expect(live.merge(AutoDjSeeds.fresh(frozen: true, now: t0), now: at(3)),
          same(live));
    });

    test('the caps apply, live\'s oldest unpinned rows making way', () {
      final pending = manual(SeedList.moreLike, 4);
      expect(rows(picks(5).merge(pending, now: at(9)).moreLike),
          ['p1', 'p2', 'p3', 'p4', 'm0*', 'm1*', 'm2*', 'm3*']);
    });

    test('the merge is frozen when either set is', () {
      final pending = AutoDjSeeds.fresh(frozen: true, now: t0)
          .addManual(SeedList.moreLike, song('m'), now: at(1));
      final s = AutoDjSeeds.empty.merge(pending, now: at(2));
      expect(s.frozen, isTrue);
      expect(s.frozenAt, t0);
      expect(rows(s.moreLike), ['m*']);
    });

    test('an unpinned Less like row keeps the Drift time it has run', () {
      // Drift on both sides: the clock carries over as it is.
      final drift = AutoDjSeeds.empty
          .addManual(SeedList.lessLike, song('x'), now: t0)
          .setPinned(SeedList.lessLike, key('x'), false, now: at(3));
      expect(picks(1).merge(drift, now: at(9)).lessLike.single.addedAt, at(3));
      // Held aside since a freeze at 10 after running 10 minutes, merged into
      // a set frozen at 20: thawed at 80, it has still run only 10.
      final pending = AutoDjSeeds(
        lessLike: [
          AutoDjSeed(song: song('x'), origin: SeedOrigin.manual, addedAt: t0),
        ],
        frozen: true,
        frozenAt: at(10),
      );
      final live = AutoDjSeeds.fresh(frozen: true, now: at(20));
      final merged = live.merge(pending, now: at(30));
      expect(merged.lessLike.single.addedAt, at(10));
      final thawed = merged.thaw(at(80));
      expect(thawed.lessLike.single.addedAt, at(70));
      expect(thawed.prune(at(99, 59)), same(thawed));
      expect(thawed.prune(at(100)).lessLike, isEmpty);
    });
  });

  group('the wire', () {
    test('positivePaths: More like\'s wire paths, oldest first', () {
      final s = AutoDjSeeds.empty
          .pushPick(song('/Music/a.flac'), now: t0)
          .pushPick(song('b', server: 'lab'), now: at(1))
          .pushPick(song('c'), now: at(2));
      expect(s.positivePaths(), ['Music/a.flac', 'b', 'c']);
      expect(s.positivePaths(server: 'home'), ['Music/a.flac', 'c']);
      expect(s.positivePaths(server: 'lab'), ['b']);
      expect(s.positivePaths(server: 'nope'), isEmpty);
    });

    test('positivePaths sends at most eight, the newest kept', () {
      final s = AutoDjSeeds(moreLike: [
        for (var i = 0; i < 10; i++)
          AutoDjSeed(song: song('p$i'), origin: SeedOrigin.pick, addedAt: at(i)),
      ]);
      expect(s.positivePaths(), [for (var i = 2; i < 10; i++) 'p$i']);
    });

    test('negativesFor: own paths, then other servers\' vectors in the model',
        () {
      final s = AutoDjSeeds.empty
          .quickSkip(song('/Music/own.flac'), learn: true, now: t0)
          .quickSkip(song('peer1', server: 'lab'), learn: true, now: at(1))
          .quickSkip(song('peer2', server: 'lab'), learn: true, now: at(2))
          .quickSkip(song('peer3', server: 'lab'), learn: true, now: at(3))
          .withVector(key('peer1', server: 'lab'), 'V1', 'model-1')
          .withVector(key('peer2', server: 'lab'), 'V2', 'model-2')
          // An own row with a vector still goes as its path.
          .withVector(key('/Music/own.flac'), 'V0', 'model-1');
      final home = s.negativesFor('home', modelId: 'model-1');
      expect(home.paths, ['Music/own.flac']);
      expect(home.vectors, ['V1']);
      // No model in hand: paths only.
      final single = s.negativesFor('home');
      expect(single.paths, ['Music/own.flac']);
      expect(single.vectors, isEmpty);
      final lab = s.negativesFor('lab', modelId: 'model-1');
      expect(lab.paths, ['peer1', 'peer2', 'peer3']);
      expect(lab.vectors, ['V0']);
    });

    test('negativesFor stays within eight in total, paths first', () {
      final s = AutoDjSeeds(lessLike: [
        for (var i = 0; i < 5; i++)
          AutoDjSeed(
              song: song('peer$i', server: 'lab'),
              origin: SeedOrigin.skip,
              addedAt: at(i),
              vector: 'V$i',
              vectorModel: 'm'),
        for (var i = 0; i < 6; i++)
          AutoDjSeed(
              song: song('own$i'), origin: SeedOrigin.skip, addedAt: at(10 + i)),
      ]);
      final n = s.negativesFor('home', modelId: 'm');
      expect(n.paths, [for (var i = 0; i < 6; i++) 'own$i']);
      expect(n.vectors, ['V3', 'V4']);
    });

    test('tiles: the newest More like rows, newest first', () {
      final s = picks(5);
      expect(rows(s.tiles()), ['p4', 'p3', 'p2']);
      expect(rows(s.tiles(2)), ['p4', 'p3']);
      expect(rows(picks(1).tiles()), ['p0']);
      expect(AutoDjSeeds.empty.tiles(), isEmpty);
      expect(s.tiles(0), isEmpty);
    });
  });

  // ── Pins that outlive the lane (PLAN-2 A) ─────────────────────────────

  // A stored pin as the load hands it back.
  StoredSeed stored(SeedList list, String path,
          {String server = 'home',
          SeedOrigin origin = SeedOrigin.manual,
          DateTime? addedAt}) =>
      (
        list: list,
        seed: AutoDjSeed(
            song: song(path, server: server),
            pinned: true,
            origin: origin,
            addedAt: addedAt ?? t0),
      );
  // Stored pins as "list:wirePath", in order.
  List<String> listed(Iterable<StoredSeed> rows) => [
        for (final r in rows)
          '${r.list == SeedList.moreLike ? 'more' : 'less'}:${r.seed.wirePath}',
      ];

  group('storedSeedToJson / storedSeedFromJson', () {
    test('a pin reads back as it was saved, pinned, with no vector', () {
      final row = AutoDjSeed(
          song: const TrackFacts(
              server: 'home',
              path: '/Music/a.flac',
              title: 'A',
              artist: 'Ar',
              album: 'Al',
              artFile: 'a.jpg',
              durationMs: 1000),
          pinned: true,
          origin: SeedOrigin.skip,
          addedAt: at(5),
          vector: 'VEC',
          vectorModel: 'm');
      final json = storedSeedToJson((list: SeedList.lessLike, seed: row));
      expect(json['list'], 'lessLike');
      expect(json['origin'], 'skip');
      expect(json['pinned'], true);
      expect(json['at'], at(5).millisecondsSinceEpoch);
      expect(json.containsKey('vector'), isFalse);
      final back = storedSeedFromJson(json, now: at(60))!;
      expect(back.list, SeedList.lessLike);
      expect(back.seed.key, row.key);
      expect(back.seed.song.path, '/Music/a.flac');
      expect(back.seed.song.title, 'A');
      expect(back.seed.song.artist, 'Ar');
      expect(back.seed.song.artFile, 'a.jpg');
      expect(back.seed.song.durationMs, 1000);
      expect(back.seed.pinned, isTrue);
      expect(back.seed.origin, SeedOrigin.skip);
      expect(back.seed.addedAt.isAtSameMomentAs(at(5)), isTrue);
      expect(back.seed.vector, isNull);
      expect(back.seed.vectorModel, isNull);
    });

    test('a row keeps its stored pin; only an explicit false reads unpinned',
        () {
      // Stay close keeps the rows it shows pinned only because it is frozen.
      final json = storedSeedToJson((
        list: SeedList.moreLike,
        seed: AutoDjSeed(song: song('a'), origin: SeedOrigin.pick, addedAt: t0)
      ));
      expect(json['pinned'], false);
      final back = storedSeedFromJson(json, now: at(9))!;
      expect(back.seed.pinned, isFalse);
      expect(back.seed.origin, SeedOrigin.pick);
      expect(back.seed.addedAt.isAtSameMomentAs(t0), isTrue);
      // And back out the same way.
      expect(storedSeedToJson(back)['pinned'], false);
      // A file from before the key held the user's pins alone, and a junk
      // value says nothing: both read as pinned.
      expect(
          storedSeedFromJson({...json}..remove('pinned'), now: t0)!.seed.pinned,
          isTrue);
      for (final junk in <Object?>[null, 0, 'false', 'no', 1]) {
        expect(storedSeedFromJson({...json, 'pinned': junk}, now: t0)!
                .seed
                .pinned,
            isTrue,
            reason: '$junk');
      }
      expect(storedSeedFromJson({...json, 'pinned': true}, now: t0)!.seed.pinned,
          isTrue);
    });

    test('anything that is not a pin reads as null', () {
      Map<String, dynamic> good() =>
          storedSeedToJson(stored(SeedList.moreLike, '/Music/a.flac'));
      final cases = <String, Object?>{
        'not a map': 'moreLike',
        'a list': [1, 2],
        'null': null,
        'no list': good()..remove('list'),
        'an unknown list': good()..['list'] = 'maybeLike',
        'a list that is no name': good()..['list'] = 0,
        'no song': good()..remove('song'),
        'a song that is no map': good()..['song'] = 'a.flac',
        'a song with no path': good()..['song'] = {'srv': 'home', 'ti': 'x'},
        'a local file': good()
          ..['song'] = const TrackFacts(server: '', path: '/sdcard/a.mp3')
              .toJson(),
        'an empty wire path': good()
          ..['song'] = const TrackFacts(server: 'home', path: '/').toJson(),
      };
      cases.forEach((what, json) {
        expect(storedSeedFromJson(json, now: t0), isNull, reason: what);
      });
    });

    test('an unknown or missing origin reads as the user\'s own', () {
      final json = storedSeedToJson(stored(SeedList.moreLike, 'a'));
      expect(
          storedSeedFromJson({...json, 'origin': 'fromTheFuture'}, now: t0)!
              .seed
              .origin,
          SeedOrigin.manual);
      expect(
          storedSeedFromJson({...json}..remove('origin'), now: t0)!
              .seed
              .origin,
          SeedOrigin.manual);
      expect(storedSeedFromJson({...json, 'origin': 7}, now: t0)!.seed.origin,
          SeedOrigin.manual);
    });

    test('a missing, non-int or out-of-range time reads as now', () {
      final json = storedSeedToJson(stored(SeedList.lessLike, 'a'));
      for (final at in <Object?>[null, '12', 1.5, 9223372036854775807,
        -9223372036854775807 - 1, 8640000000000001, -8640000000000001]) {
        final back = storedSeedFromJson({...json, 'at': at}, now: t0);
        expect(back!.seed.addedAt, t0, reason: '$at');
      }
    });

    test('junk inside the song never throws', () {
      final json = storedSeedToJson(stored(SeedList.moreLike, 'a'));
      // A server that is no string reads as a local file: no pin.
      expect(
          storedSeedFromJson({
            ...json,
            'song': {'srv': 5, 'p': 'a'},
          }, now: t0),
          isNull);
      expect(
          storedSeedFromJson({
            ...json,
            'song': {'srv': 'home', 'p': 7},
          }, now: t0),
          isNull);
      // A field of the wrong type is left out; the pin stands.
      final back = storedSeedFromJson({
        ...json,
        'song': {'srv': 'home', 'p': 'a', 'dur': 'long', 'ti': 3},
      }, now: t0)!;
      expect(back.seed.key, key('a'));
      expect(back.seed.song.durationMs, isNull);
      expect(back.seed.song.title, isNull);
    });
  });

  group('storedTimeFromJson', () {
    test('null for a missing value, one that is no int, or one out of range',
        () {
      for (final raw in <Object?>[
        null,
        '12',
        1.5,
        true,
        const [1],
        8640000000000001,
        -8640000000000001,
        9223372036854775807,
        -9223372036854775807 - 1,
      ]) {
        expect(storedTimeFromJson(raw), isNull, reason: '$raw');
      }
    });

    test('an int in range is that moment, the range\'s ends included', () {
      final t = storedTimeFromJson(t0.millisecondsSinceEpoch)!;
      expect(t.isAtSameMomentAs(t0), isTrue);
      expect(storedTimeFromJson(0)!.millisecondsSinceEpoch, 0);
      expect(storedTimeFromJson(8640000000000000)!.millisecondsSinceEpoch,
          8640000000000000);
      expect(storedTimeFromJson(-8640000000000000)!.millisecondsSinceEpoch,
          -8640000000000000);
    });
  });

  group('pinnedRows', () {
    test('the stored pins of both lists, More like first, in list order', () {
      final s = picks(2)
          .setPinned(SeedList.moreLike, key('p1'), true, now: at(2))
          .addManual(SeedList.lessLike, song('n0'), now: at(3))
          .addManual(SeedList.moreLike, song('m0'), now: at(4))
          .quickSkip(song('x'), learn: true, now: at(5))
          .addManual(SeedList.lessLike, song('n1'), now: at(6));
      expect(listed(s.pinnedRows),
          ['more:p1', 'more:m0', 'less:n0', 'less:n1']);
      expect(AutoDjSeeds.empty.pinnedRows, isEmpty);
    });

    test('never a row that shows pinned only because the set is frozen', () {
      final s = picks(2)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(2))
          .quickSkip(song('x'), learn: true, now: at(2))
          .freeze(at(3))
          .admitAnchor(song('a'), usable: (_) => false, now: at(4));
      expect([for (final r in s.moreLike) s.shownPinned(r)],
          [true, true, true]);
      expect(listed(s.pinnedRows), ['more:p0']);
    });
  });

  group('storedRows (what auto_dj.json keeps)', () {
    // A stored row as "list:wirePath", '*' marking its own pin.
    List<String> kept(Iterable<StoredSeed> rows) => [
          for (final r in rows)
            '${listed([r]).single}${r.seed.pinned ? '*' : ''}',
        ];

    test('frozen: every row of both lists, each with its own pin, in order',
        () {
      final s = picks(2)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(2))
          .quickSkip(song('x'), learn: true, now: at(2))
          .addManual(SeedList.lessLike, song('n'), now: at(3))
          .freeze(at(4))
          .admitAnchor(song('a'), usable: (_) => false, now: at(5));
      expect(kept(s.storedRows),
          ['more:p0*', 'more:p1', 'more:a', 'less:x', 'less:n*']);
      expect([for (final r in s.storedRows) r.seed.origin], [
        SeedOrigin.pick,
        SeedOrigin.pick,
        SeedOrigin.anchor,
        SeedOrigin.skip,
        SeedOrigin.manual,
      ]);
      // The pins alone are still what a save before any load looks for.
      expect(kept(s.pinnedRows), ['more:p0*', 'less:n*']);
    });

    test('Drift: the rows the user pinned', () {
      final s = picks(2)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(2))
          .quickSkip(song('x'), learn: true, now: at(2))
          .addManual(SeedList.lessLike, song('n'), now: at(3));
      expect(kept(s.storedRows), ['more:p0*', 'less:n*']);
      expect(kept(s.thaw(at(9)).storedRows), kept(s.pinnedRows));
      expect(AutoDjSeeds.empty.storedRows, isEmpty);
      expect(AutoDjSeeds.fresh(frozen: true, now: t0).storedRows, isEmpty);
    });
  });

  group('pinnedSeedsSignature', () {
    test('the same rows in the same lists and order read the same', () {
      final a = [
        stored(SeedList.moreLike, 'a'),
        stored(SeedList.lessLike, 'b'),
      ];
      final b = [
        stored(SeedList.moreLike, '/a', addedAt: at(9)),
        stored(SeedList.lessLike, 'b', origin: SeedOrigin.skip),
      ];
      expect(pinnedSeedsSignature(a), pinnedSeedsSignature(b));
      expect(pinnedSeedsSignature(const []), pinnedSeedsSignature(const []));
    });

    test('another order, list, server or song reads differently', () {
      final base = pinnedSeedsSignature(
          [stored(SeedList.moreLike, 'a'), stored(SeedList.moreLike, 'b')]);
      for (final other in [
        [stored(SeedList.moreLike, 'b'), stored(SeedList.moreLike, 'a')],
        [stored(SeedList.moreLike, 'a'), stored(SeedList.lessLike, 'b')],
        [
          stored(SeedList.moreLike, 'a'),
          stored(SeedList.moreLike, 'b', server: 'lab')
        ],
        [stored(SeedList.moreLike, 'a')],
        <StoredSeed>[],
      ]) {
        expect(pinnedSeedsSignature(other), isNot(base),
            reason: listed(other).join(','));
      }
    });

    test('a pick that only adds unpinned rows leaves it as it was', () {
      final s = manual(SeedList.moreLike, 2);
      final picked = s.pushPick(song('p'), now: at(5));
      expect(picked, isNot(same(s)));
      expect(pinnedSeedsSignature(picked.pinnedRows),
          pinnedSeedsSignature(s.pinnedRows));
    });

    test('the same rows with one pin flipped read differently', () {
      final pinned = [
        stored(SeedList.moreLike, 'a'),
        stored(SeedList.lessLike, 'b'),
      ];
      for (var i = 0; i < pinned.length; i++) {
        final flipped = [
          for (var j = 0; j < pinned.length; j++)
            j == i
                ? (
                    list: pinned[j].list,
                    seed: pinned[j].seed.copyWith(pinned: false),
                  )
                : pinned[j],
        ];
        expect(pinnedSeedsSignature(flipped), isNot(pinnedSeedsSignature(pinned)),
            reason: 'row $i unpinned');
      }
    });

    test('a set of pins alone keeps the same rows in both modes', () {
      final s = manual(SeedList.moreLike, 2)
          .addManual(SeedList.lessLike, song('n'), now: at(3));
      expect(pinnedSeedsSignature(s.freeze(at(4)).storedRows),
          pinnedSeedsSignature(s.storedRows));
    });
  });

  group('restorablePinnedRows', () {
    bool known(String server) => server == 'home' || server == 'lab';

    test('the rows of servers the app no longer has are dropped', () {
      final got = restorablePinnedRows([
        stored(SeedList.moreLike, 'a'),
        stored(SeedList.moreLike, 'b', server: 'gone'),
        stored(SeedList.lessLike, 'c', server: 'lab'),
      ], knownServer: known);
      expect(listed(got), ['more:a', 'less:c']);
    });

    test('a key that appears more than once keeps its last entry', () {
      final got = restorablePinnedRows([
        stored(SeedList.moreLike, 'a'),
        stored(SeedList.moreLike, 'b'),
        stored(SeedList.lessLike, '/a', addedAt: at(9)),
      ], knownServer: known);
      expect(listed(got), ['more:b', 'less:a']);
      expect(got.last.seed.addedAt, at(9));
    });

    test('at most the newest eight of each list, in file order', () {
      final entries = [
        for (var i = 0; i < 10; i++) stored(SeedList.moreLike, 'm$i'),
        for (var i = 0; i < 9; i++) stored(SeedList.lessLike, 'n$i'),
      ];
      final got = restorablePinnedRows(entries, knownServer: known);
      expect(listed(got), [
        for (var i = 2; i < 10; i++) 'more:m$i',
        for (var i = 1; i < 9; i++) 'less:n$i',
      ]);
    });

    test('a Stay close load keeps past eight, up to the bound', () {
      final entries = [
        for (var i = 0; i < 18; i++) stored(SeedList.moreLike, 'm$i'),
        for (var i = 0; i < 9; i++) stored(SeedList.lessLike, 'n$i'),
      ];
      final got = restorablePinnedRows(entries,
          knownServer: known, perList: AutoDjSeeds.maxStoredPerList);
      expect(listed(got), [
        for (var i = 2; i < 18; i++) 'more:m$i',
        for (var i = 0; i < 9; i++) 'less:n$i',
      ]);
    });

    test('past the bound the oldest unpinned rows go before any pin', () {
      // A file edited past the bound: two pins first, then unpinned rows.
      StoredSeed loose(String path) {
        final r = stored(SeedList.moreLike, path);
        return (list: r.list, seed: r.seed.copyWith(pinned: false));
      }

      final entries = [
        stored(SeedList.moreLike, 'p0'),
        stored(SeedList.moreLike, 'p1'),
        for (var i = 0; i < 16; i++) loose('u$i'),
      ];
      final got = restorablePinnedRows(entries,
          knownServer: known, perList: AutoDjSeeds.maxStoredPerList);
      expect(listed(got), [
        'more:p0',
        'more:p1',
        for (var i = 2; i < 16; i++) 'more:u$i',
      ]);
    });

    test('a load followed by a save writes the same list', () {
      final entries = [
        for (var i = 0; i < 10; i++) stored(SeedList.moreLike, 'm$i'),
        stored(SeedList.lessLike, 'n'),
      ];
      final once = restorablePinnedRows(entries, knownServer: known);
      final saved =
          AutoDjSeeds.empty.withPinnedRows(once).pinnedRows;
      expect(listed(saved), listed(once));
      expect(listed(restorablePinnedRows(saved, knownServer: known)),
          listed(once));
    });
  });

  group('loadStoredPins / pinnedSeedsToSave (the launch load and the save)',
      () {
    bool known(String server) => server == 'home';
    final file = [
      stored(SeedList.moreLike, 'a'),
      stored(SeedList.moreLike, 'b'),
      stored(SeedList.lessLike, 'c'),
    ];

    test('before the load nothing is saved, whatever changed', () {
      final s = manual(SeedList.moreLike, 2);
      expect(pinnedSeedsToSave(s, saved: null), isNull);
      expect(pinnedSeedsToSave(AutoDjSeeds.empty, saved: null), isNull);
    });

    test('a file within the caps: the pins come back and the first save '
        'writes nothing', () {
      final load = loadStoredPins(AutoDjSeeds.empty, file,
          knownServer: known, frozen: false, now: t0);
      expect(rows(load.seeds.moreLike), ['a*', 'b*']);
      expect(rows(load.seeds.lessLike), ['c*']);
      expect(pinnedSeedsToSave(load.seeds, saved: load.saved), isNull);
      // Nor does a pick that starts playing after it.
      final picked = load.seeds.pushPick(song('p'), now: at(1));
      expect(pinnedSeedsToSave(picked, saved: load.saved), isNull);
    });

    test('in Stay close they come back frozen, from the stored freeze when '
        'there is one', () {
      final stored = loadStoredPins(AutoDjSeeds.empty, file,
          knownServer: known, frozen: true, frozenAt: at(1), now: at(3));
      expect(stored.seeds.frozen, isTrue);
      expect(stored.seeds.frozenAt, at(1));
      expect(rows(stored.seeds.moreLike), ['a*', 'b*']);
      expect(rows(stored.seeds.lessLike), ['c*']);
      // A file with no frozenAt (one written in Drift, or by an older
      // build): frozen from now.
      final none = loadStoredPins(AutoDjSeeds.empty, file,
          knownServer: known, frozen: true, now: at(3));
      expect(none.seeds.frozen, isTrue);
      expect(none.seeds.frozenAt, at(3));
      expect(rows(none.seeds.moreLike), ['a*', 'b*']);
      // Pins alone are what the file holds: nothing to write.
      expect(pinnedSeedsToSave(none.seeds, saved: none.saved), isNull);
    });

    test('a deleted server\'s pins or a capped list: the first save writes '
        'what is left, once', () {
      final load = loadStoredPins(
          AutoDjSeeds.empty,
          [
            stored(SeedList.moreLike, 'x', server: 'gone'),
            for (var i = 0; i < 9; i++) stored(SeedList.moreLike, 'm$i'),
          ],
          knownServer: known,
          frozen: false,
          now: t0);
      final save = pinnedSeedsToSave(load.seeds, saved: load.saved)!;
      expect(listed(save.rows), [for (var i = 1; i < 9; i++) 'more:m$i']);
      expect(pinnedSeedsToSave(load.seeds, saved: save.signature), isNull);
    });

    test('rows pinned before the load are written at the first save', () {
      final before = AutoDjSeeds.empty
          .addManual(SeedList.lessLike, song('early'), now: t0);
      final load = loadStoredPins(before, file,
          knownServer: known, frozen: false, now: at(1));
      final save = pinnedSeedsToSave(load.seeds, saved: load.saved)!;
      expect(listed(save.rows),
          ['more:a', 'more:b', 'less:c', 'less:early']);
    });

    test('an empty file and no pins: the set as it was, nothing to write', () {
      final live = picks(2);
      final load = loadStoredPins(live, const [],
          knownServer: known, frozen: false, now: t0);
      expect(load.seeds, same(live));
      expect(pinnedSeedsToSave(load.seeds, saved: load.saved), isNull);
    });

    test('a pin, an unpin, a move or a removal is written; then not again',
        () {
      final load = loadStoredPins(AutoDjSeeds.empty, file,
          knownServer: known, frozen: false, now: t0);
      var saved = load.saved;
      var s = load.seeds;
      final edits = <AutoDjSeeds Function(AutoDjSeeds)>[
        (s) => s.setPinned(SeedList.moreLike, key('a'), false, now: at(1)),
        (s) => s.setPinned(SeedList.moreLike, key('a'), true, now: at(2)),
        (s) => s.move(key('c'), now: at(3)),
        (s) => s.remove(SeedList.moreLike, key('b')),
        (s) => s.addManual(SeedList.lessLike, song('d'), now: at(4)),
      ];
      for (final edit in edits) {
        s = edit(s);
        final save = pinnedSeedsToSave(s, saved: saved);
        expect(save, isNotNull);
        saved = save!.signature;
        expect(pinnedSeedsToSave(s, saved: saved), isNull);
      }
      expect(listed(s.pinnedRows), ['more:a', 'more:c', 'less:d']);
    });

    test('the box\'s clear: no pins, and a save of none', () {
      final load = loadStoredPins(AutoDjSeeds.empty, file,
          knownServer: known, frozen: false, now: t0);
      final cleared = load.seeds.carryOver(at(1), frozen: false).withoutPinned();
      expect(cleared.pinnedRows, isEmpty);
      final save = pinnedSeedsToSave(cleared, saved: load.saved)!;
      expect(save.rows, isEmpty);
      expect(save.signature, pinnedSeedsSignature(const []));
    });
  });

  // ── Stay close keeps everything it shows (PLAN-3 R2) ──────────────────

  group('Stay close through restarts: the save and the load', () {
    bool known(String server) => server == 'home';
    // A stored row as "list:wirePath", '*' marking its own pin.
    List<String> kept(Iterable<StoredSeed> rows) => [
          for (final r in rows)
            '${listed([r]).single}${r.seed.pinned ? '*' : ''}',
        ];
    // The stored rows through the file's own format.
    List<StoredSeed> viaJson(Iterable<StoredSeed> rows) => [
          for (final r in rows)
            storedSeedFromJson(storedSeedToJson(r), now: DateTime(2000))!,
        ];

    test('a freeze writes every row and when it froze; the thaw that follows '
        'writes the pins alone', () {
      // Drift, saved: p0 pinned, p1 a pick.
      final drift = picks(2)
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(2));
      var saved = pinnedSeedsSignature(drift.storedRows);
      expect(pinnedSeedsToSave(drift, saved: saved), isNull);

      final frozen = drift.freeze(at(4));
      final onFreeze = pinnedSeedsToSave(frozen, saved: saved)!;
      expect(kept(onFreeze.rows), ['more:p0*', 'more:p1']);
      expect(onFreeze.frozenAt, at(4));
      saved = onFreeze.signature;
      expect(pinnedSeedsToSave(frozen, saved: saved), isNull);

      final thawed = frozen.thaw(at(9));
      final onThaw = pinnedSeedsToSave(thawed, saved: saved)!;
      expect(kept(onThaw.rows), ['more:p0*']);
      expect(onThaw.frozenAt, isNull);
    });

    test('a set of pins alone writes nothing at the freeze or the thaw', () {
      final pins = manual(SeedList.moreLike, 2);
      final saved = pinnedSeedsSignature(pins.storedRows);
      final frozen = pins.freeze(at(4));
      expect(pinnedSeedsToSave(frozen, saved: saved), isNull);
      expect(pinnedSeedsToSave(frozen.thaw(at(9)), saved: saved), isNull);
    });

    // The plan check's case. Five picks played from 9:50, a skip at 10:00,
    // Stay close at 10:05 and its anchor at 10:06: six rows the page shows
    // pinned, none the user's own, and a skip with 25 of its 30 minutes
    // left, all saved with the freeze's 10:05.
    DateTime clock(int h, int m, [int s = 0]) =>
        DateTime.utc(2026, 11, 17, h, m, s);
    final ten05 = clock(10, 5);
    AutoDjSeeds stayClose() {
      var s = AutoDjSeeds.empty;
      for (var i = 0; i < 5; i++) {
        s = s.pushPick(song('p$i'), now: clock(9, 50 + i));
      }
      return s
          .quickSkip(song('x'), learn: true, now: clock(10, 0))
          .freeze(ten05)
          .admitAnchor(song('a'), usable: (_) => false, now: clock(10, 6));
    }

    test('Stay close: restored hours later, every row is back as it was '
        'shown, with the pause the lists stood in', () {
      final shown = stayClose();
      final save = pinnedSeedsToSave(shown, saved: '')!;
      expect(save.frozenAt, ten05);
      final file = viaJson(save.rows);
      expect(kept(file), [
        'more:p0', 'more:p1', 'more:p2', 'more:p3', 'more:p4', 'more:a',
        'less:x',
      ]);

      final load = loadStoredPins(AutoDjSeeds.empty, file,
          knownServer: known,
          frozen: true,
          frozenAt: save.frozenAt,
          now: clock(14, 0));
      final s = load.seeds;
      expect(s.frozen, isTrue);
      expect(s.frozenAt, ten05);
      expect(rows(s.moreLike), ['p0', 'p1', 'p2', 'p3', 'p4', 'a'],
          reason: 'unpinned, and no ring trims them while frozen');
      expect(rows(s.lessLike), ['x'], reason: 'the skip is not pruned');
      expect([for (final r in s.moreLike) s.shownPinned(r)], everyElement(true));
      // The restore's lane start keeps it as it is.
      expect(s.carryOver(clock(14, 1), frozen: true), same(s));
      // What it holds is what the file holds: the first save writes nothing.
      expect(pinnedSeedsToSave(s, saved: load.saved), isNull);

      // Back in Drift at 14:10: 25 minutes left on the skip, and More like
      // trimmed to the ring.
      final drift = s.thaw(clock(14, 10));
      expect(rows(drift.prune(clock(14, 34, 59)).lessLike), ['x']);
      expect(drift.prune(clock(14, 35)).lessLike, isEmpty);
      expect(rows(drift.moreLike), ['p1', 'p2', 'p3', 'p4', 'a']);
    });

    test('the same file into a set an arm already froze: its freeze stands, '
        'and the skip keeps its time', () {
      final save = pinnedSeedsToSave(stayClose(), saved: '')!;
      // A headless arm (or a Start before the launch restore) froze the
      // empty set at 14:00 before the load ran.
      final armed = AutoDjSeeds.fresh(frozen: true, now: clock(14, 0));
      final load = loadStoredPins(armed, viaJson(save.rows),
          knownServer: known,
          frozen: true,
          frozenAt: save.frozenAt,
          now: clock(14, 0, 30));
      final s = load.seeds;
      expect(s.frozen, isTrue);
      expect(s.frozenAt, clock(14, 0));
      expect(rows(s.moreLike), ['p0', 'p1', 'p2', 'p3', 'p4', 'a']);
      final drift = s.thaw(clock(14, 10));
      expect(rows(drift.prune(clock(14, 34, 59)).lessLike), ['x']);
      expect(drift.prune(clock(14, 35)).lessLike, isEmpty,
          reason: 'the hours the app was closed are no Drift time');
    });

    test('Drift: only the pins come back, and the first save writes them '
        'alone', () {
      final shown = stayClose()
          .addManual(SeedList.moreLike, song('pin'), now: clock(10, 7));
      final save = pinnedSeedsToSave(shown, saved: '')!;
      expect(kept(save.rows), contains('more:pin*'));
      final load = loadStoredPins(AutoDjSeeds.empty, viaJson(save.rows),
          knownServer: known,
          frozen: false,
          frozenAt: save.frozenAt,
          now: clock(14, 0));
      expect(load.seeds.frozen, isFalse);
      expect(rows(load.seeds.moreLike), ['pin*']);
      expect(load.seeds.lessLike, isEmpty);
      final first = pinnedSeedsToSave(load.seeds, saved: load.saved)!;
      expect(kept(first.rows), ['more:pin*']);
      expect(first.frozenAt, isNull);
    });

    test('the box\'s clear in Stay close: both lists empty, still frozen, '
        'and a save of none', () {
      final shown = stayClose()
          .addManual(SeedList.moreLike, song('pin'), now: clock(10, 7));
      final saved = pinnedSeedsToSave(shown, saved: '')!.signature;
      final cleared =
          shown.carryOver(clock(11, 0), frozen: true).withoutPinned();
      expect(cleared.isEmpty, isTrue);
      expect(cleared.frozen, isTrue);
      expect(cleared.frozenAt, ten05);
      final save = pinnedSeedsToSave(cleared, saved: saved)!;
      expect(save.rows, isEmpty);
      expect(save.signature, pinnedSeedsSignature(const []));
    });
  });

  group('pinsLoadOwed (a save before any load)', () {
    final pinned = AutoDjSeeds.empty
        .addManual(SeedList.moreLike, song('a'), now: t0);

    test('a pin made before any load, with a server known, runs the load',
        () {
      expect(pinsLoadOwed(pinned, saved: null, serversKnown: true), isTrue);
      final skip = AutoDjSeeds.empty
          .addManual(SeedList.lessLike, song('s'), now: t0);
      expect(pinsLoadOwed(skip, saved: null, serversKnown: true), isTrue);
    });

    test('with no server known the load waits', () {
      // A fresh install before its first server, and the integration
      // harness, whose DJ server is never in the list.
      expect(pinsLoadOwed(pinned, saved: null, serversKnown: false), isFalse);
    });

    test('no pin in view: nothing to save, nothing loaded', () {
      expect(pinsLoadOwed(AutoDjSeeds.empty, saved: null, serversKnown: true),
          isFalse);
      expect(pinsLoadOwed(picks(2), saved: null, serversKnown: true), isFalse);
      // Rows drawn pinned only because Stay close froze them are no pins.
      expect(
          pinsLoadOwed(picks(2).freeze(at(2)),
              saved: null, serversKnown: true),
          isFalse);
    });

    test('once loaded the save goes its usual way, an empty baseline too', () {
      expect(pinsLoadOwed(pinned, saved: '', serversKnown: true), isFalse);
      expect(
          pinsLoadOwed(pinned,
              saved: pinnedSeedsSignature(pinned.pinnedRows),
              serversKnown: true),
          isFalse);
    });

    test('a run that launched with no server: the first pin once a server is '
        'known is saved', () {
      // Launch: no server, so the load waits and leaves no baseline.
      String? saved;
      var live = AutoDjSeeds.empty;
      // The user adds a server, then a song on the Seeds page with the DJ
      // off: held aside, pinned.
      final pending = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, song('first'), now: at(1));
      var view = live.merge(pending, now: at(1));
      // Before, nothing was saved: no baseline, and nothing would set one.
      expect(pinnedSeedsToSave(view, saved: saved), isNull);
      expect(pinsLoadOwed(view, saved: saved, serversKnown: true), isTrue);
      // The load it runs: nothing stored yet.
      final load = loadStoredPins(live, const [],
          knownServer: (_) => true, frozen: false, now: at(1));
      live = load.seeds;
      saved = load.saved;
      view = live.merge(pending, now: at(1));
      final save = pinnedSeedsToSave(view, saved: saved)!;
      expect(listed(save.rows), ['more:first']);
      expect(pinsLoadOwed(view, saved: save.signature, serversKnown: true),
          isFalse);
    });
  });

  group('withPinnedRows', () {
    // A stored row the user never pinned: one Stay close kept.
    StoredSeed unpinned(SeedList list, String path,
            {SeedOrigin origin = SeedOrigin.pick, DateTime? addedAt}) =>
        (
          list: list,
          seed: AutoDjSeed(
              song: song(path), origin: origin, addedAt: addedAt ?? t0),
        );

    test('loaded rows go to the oldest end with their own pins, in their '
        'order', () {
      final live = picks(2).quickSkip(song('x'), learn: true, now: at(2));
      final s = live.withPinnedRows([
        stored(SeedList.moreLike, 'a'),
        unpinned(SeedList.moreLike, 'b'),
        stored(SeedList.lessLike, 'c'),
        unpinned(SeedList.lessLike, 'd', origin: SeedOrigin.skip),
      ]);
      expect(rows(s.moreLike), ['a*', 'b', 'p0', 'p1']);
      expect(rows(s.lessLike), ['c*', 'd', 'x']);
      expect(s.moreLike[1].origin, SeedOrigin.pick);
      expect(s.frozen, isFalse);
    });

    test('into a frozen set, a stored skip keeps the time it had run, moved '
        'onto that set\'s freeze', () {
      // Skipped at 0:00, the stored lists froze at 0:05; this set froze at
      // 1:00.
      final s = AutoDjSeeds.fresh(frozen: true, now: at(60)).withPinnedRows([
        unpinned(SeedList.lessLike, 'x', origin: SeedOrigin.skip),
        stored(SeedList.lessLike, 'pin', addedAt: at(1)),
      ], storedFrozenAt: at(5));
      expect(s.lessLike.first.addedAt, at(55));
      expect(s.lessLike.last.addedAt, at(1), reason: 'a pin has no clock');
      // Thawed at 2:00: 25 of its 30 minutes left.
      final drift = s.thaw(at(120));
      expect(rows(drift.prune(at(144, 59)).lessLike), ['x', 'pin*']);
      expect(rows(drift.prune(at(145)).lessLike), ['pin*']);
      // The same freeze as the stored one, or none stored: nothing moves.
      for (final from in [at(60), null]) {
        expect(
            AutoDjSeeds.fresh(frozen: true, now: at(60))
                .withPinnedRows([
                  unpinned(SeedList.lessLike, 'x', origin: SeedOrigin.skip)
                ], storedFrozenAt: from)
                .lessLike
                .single
                .addedAt,
            t0,
            reason: '$from');
      }
    });

    test('a song the set already holds, in either list, keeps the set\'s row',
        () {
      final live = picks(2)
          .addManual(SeedList.lessLike, song('n'), now: at(2))
          .setPinned(SeedList.lessLike, key('n'), false, now: at(3));
      final s = live.withPinnedRows([
        stored(SeedList.moreLike, 'p1'),
        stored(SeedList.moreLike, 'n'),
        stored(SeedList.lessLike, 'p0'),
        stored(SeedList.moreLike, 'a'),
      ]);
      expect(rows(s.moreLike), ['a*', 'p0', 'p1']);
      expect(rows(s.lessLike), ['n']);
    });

    test('nothing new to take in: the same set', () {
      final live = picks(2);
      expect(live.withPinnedRows(const []), same(live));
      expect(live.withPinnedRows([stored(SeedList.lessLike, 'p0')]),
          same(live));
      expect(AutoDjSeeds.empty.withPinnedRows(const []),
          same(AutoDjSeeds.empty));
    });

    test('a song named twice keeps its last entry; a local file never comes '
        'in', () {
      final s = AutoDjSeeds.empty.withPinnedRows([
        stored(SeedList.moreLike, 'a'),
        stored(SeedList.lessLike, 'a'),
        (
          list: SeedList.moreLike,
          seed: AutoDjSeed(
              song: const TrackFacts(server: '', path: '/sdcard/x.mp3'),
              pinned: true,
              origin: SeedOrigin.manual,
              addedAt: t0)
        ),
      ]);
      expect(s.moreLike, isEmpty);
      expect(rows(s.lessLike), ['a*']);
    });

    test('the caps apply as for an edit: the set\'s unpinned rows make way',
        () {
      // Drift: six loaded pins leave room for two of the five picks.
      final s = picks(5).withPinnedRows(
          [for (var i = 0; i < 6; i++) stored(SeedList.moreLike, 'm$i')]);
      expect(rows(s.moreLike),
          ['m0*', 'm1*', 'm2*', 'm3*', 'm4*', 'm5*', 'p3', 'p4']);
      // Frozen (a Stay close load): every row the page showed stays, past
      // eight too, since Stay close's one song can carry More like there.
      final frozen = picks(5).freeze(at(5)).withPinnedRows(
          [for (var i = 0; i < 4; i++) stored(SeedList.moreLike, 'm$i')]);
      expect(rows(frozen.moreLike),
          ['m0*', 'm1*', 'm2*', 'm3*', 'p0', 'p1', 'p2', 'p3', 'p4']);
      expect(frozen.frozen, isTrue);
      expect(frozen.frozenAt, at(5));
      // Only a file edited by hand passes the bound: past it the oldest
      // unpinned rows go, the pins stay.
      final bounded = picks(5).freeze(at(5)).withPinnedRows(
          [for (var i = 0; i < 14; i++) stored(SeedList.moreLike, 'm$i')]);
      expect(bounded.moreLike, hasLength(AutoDjSeeds.maxStoredPerList));
      expect(rows(bounded.moreLike).skip(14), ['p3', 'p4']);
      // Eight of the user's own already: the set's later pins win.
      final full = manual(SeedList.lessLike, 8)
          .withPinnedRows([stored(SeedList.lessLike, 'old')]);
      expect(rows(full.lessLike),
          ['m0*', 'm1*', 'm2*', 'm3*', 'm4*', 'm5*', 'm6*', 'm7*']);
    });
  });

  group('inMode', () {
    test('a set already in the mode asked is kept, frozenAt included', () {
      final frozen = picks(2).freeze(at(5));
      expect(frozen.inMode(at(60), frozen: true), same(frozen));
      expect(frozen.inMode(at(60), frozen: true).frozenAt, at(5));
      final drift = picks(2);
      expect(drift.inMode(at(60), frozen: false), same(drift));
    });

    test('otherwise it freezes from now, or thaws', () {
      final drift = AutoDjSeeds.empty.quickSkip(song('x'), learn: true, now: t0);
      final frozen = drift.inMode(at(5), frozen: true);
      expect(frozen.frozen, isTrue);
      expect(frozen.frozenAt, at(5));
      final thawed = frozen.inMode(at(65), frozen: false);
      expect(thawed.frozen, isFalse);
      // An hour frozen: the skip has 25 minutes left.
      expect(thawed.lessLike.single.addedAt, at(60));
    });
  });

  group('carryOver (a new lane)', () {
    test('Drift: pins and unpinned skips stay, clocks untouched; picks go',
        () {
      final s = picks(3)
          .setPinned(SeedList.moreLike, key('p1'), true, now: at(3))
          .pushPick(song('o'), origin: SeedOrigin.opener, now: at(4))
          .quickSkip(song('x'), learn: true, now: at(5))
          .addManual(SeedList.lessLike, song('n'), now: at(6))
          .withVector(key('x'), 'VEC', 'm');
      final next = s.carryOver(at(10), frozen: false);
      expect(rows(next.moreLike), ['p1*']);
      expect(rows(next.lessLike), ['x', 'n*']);
      expect(next.lessLike.first.addedAt, at(5));
      expect(next.lessLike.first.vector, 'VEC');
      expect(next.frozen, isFalse);
    });

    test('frozen: every row stays as it is, its pin, clock and vector, and '
        'frozenAt is kept', () {
      // An opener and two picks played in Drift, p0 pinned, a skip; then
      // Stay close, its anchor and the user's own row.
      final s = AutoDjSeeds.empty
          .pushPick(song('o'), origin: SeedOrigin.opener, now: t0)
          .pushPick(song('p0'), now: at(1))
          .pushPick(song('p1'), now: at(2))
          .setPinned(SeedList.moreLike, key('p0'), true, now: at(2))
          .quickSkip(song('x'), learn: true, now: at(2))
          .withVector(key('x'), 'VEC', 'm')
          .withVector(key('p1'), 'VP1', 'm')
          .freeze(at(3))
          .admitAnchor(song('a'), usable: (_) => false, now: at(4))
          .addManual(SeedList.moreLike, song('m'), now: at(5));
      expect(rows(s.moreLike), ['o', 'p0*', 'p1', 'a', 'm*']);
      final next = s.carryOver(at(30), frozen: true);
      expect(next, same(s));
      expect(rows(next.moreLike), ['o', 'p0*', 'p1', 'a', 'm*']);
      expect([for (final r in next.moreLike) r.origin], [
        SeedOrigin.opener,
        SeedOrigin.pick,
        SeedOrigin.pick,
        SeedOrigin.anchor,
        SeedOrigin.manual,
      ]);
      expect(next.moreLike[2].vector, 'VP1');
      expect(rows(next.lessLike), ['x']);
      expect(next.lessLike.single.addedAt, at(2));
      expect(next.lessLike.single.vector, 'VEC');
      expect(next.frozen, isTrue);
      expect(next.frozenAt, at(3));
      // Still only the user's own rows are pins: Drift gives back exactly
      // them.
      expect(listed(next.pinnedRows), ['more:p0', 'more:m']);
      final drift = next.carryOver(at(31), frozen: false);
      expect(rows(drift.moreLike), ['p0*', 'm*']);
      expect(rows(drift.lessLike), ['x']);
      expect(drift.lessLike.single.addedAt, at(30),
          reason: 'frozen from 0:03 to 0:31, after 1 minute of Drift time');
    });

    test('a skip, Stay close, a new lane, then Drift: the frozen time counts '
        'as pause', () {
      // A skip at 0:00 in Drift, Stay close at 0:05, Stop/Start at 1:00 and
      // Drift at 1:01: the skip has 25 minutes left.
      final skipped =
          AutoDjSeeds.empty.quickSkip(song('x'), learn: true, now: t0);
      final lane = skipped
          .inMode(at(5), frozen: true)
          .carryOver(at(60), frozen: true)
          .inMode(at(61), frozen: false);
      expect(lane.prune(at(85, 59)).lessLike.length, 1);
      expect(lane.prune(at(86)).lessLike, isEmpty);
    });

    test('a set never armed takes the stored mode: frozen from now', () {
      final s = AutoDjSeeds.empty.carryOver(at(7), frozen: true);
      expect(s.frozen, isTrue);
      expect(s.frozenAt, at(7));
      expect(s.isEmpty, isTrue);
      expect(AutoDjSeeds.empty.carryOver(at(7), frozen: false),
          same(AutoDjSeeds.empty));
    });

    test('a frozen set carried into Drift thaws there', () {
      final s = AutoDjSeeds.empty
          .quickSkip(song('x'), learn: true, now: t0)
          .freeze(at(10))
          .carryOver(at(70), frozen: false);
      expect(s.frozen, isFalse);
      // Frozen for an hour after running ten minutes.
      expect(s.lessLike.single.addedAt, at(60));
    });

    test('nothing to drop and the mode unchanged: the same set', () {
      final s = manual(SeedList.moreLike, 2)
          .quickSkip(song('x'), learn: true, now: at(3));
      expect(s.carryOver(at(9), frozen: false), same(s));
    });
  });

  group('withoutPinned', () {
    AutoDjSeeds mixed() => picks(2)
        .setPinned(SeedList.moreLike, key('p0'), true, now: at(2))
        .quickSkip(song('x'), learn: true, now: at(3))
        .addManual(SeedList.lessLike, song('n'), now: at(4));

    test('Drift: both lists lose the user\'s pins; the picks and the skips '
        'stay, with their clocks', () {
      final rest = mixed().withoutPinned();
      expect(rows(rest.moreLike), ['p1']);
      expect(rows(rest.lessLike), ['x']);
      expect(rest.lessLike.single.addedAt, at(3));
      expect(rest.frozen, isFalse);
    });

    test('Stay close: every row shows pinned, so both lists empty, still '
        'frozen from when they froze', () {
      final rest = mixed().freeze(at(5)).withoutPinned();
      expect(rest.isEmpty, isTrue);
      expect(rest.frozen, isTrue);
      expect(rest.frozenAt, at(5));
    });

    test('a frozen set held aside with only a row the user unpinned comes '
        'back empty', () {
      // Unpinned while held aside in Drift, then Stay close froze it.
      final pending = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, song('m'), now: t0)
          .setPinned(SeedList.moreLike, key('m'), false, now: at(1))
          .freeze(at(2));
      expect(pending.pinnedRows, isEmpty);
      expect(pending.withoutPinned().isEmpty, isTrue);
    });

    test('no pin: the same set', () {
      final s = picks(2).quickSkip(song('x'), learn: true, now: at(3));
      expect(s.withoutPinned(), same(s));
      expect(AutoDjSeeds.empty.withoutPinned(), same(AutoDjSeeds.empty));
    });
  });

  group('clearsPinsOnClear', () {
    test('only a clear of the user\'s, of a queue that held a row, with the '
        'box ticked', () {
      for (final userClear in [true, false]) {
        for (final queueHadRows in [true, false]) {
          for (final setting in [true, false]) {
            expect(
                clearsPinsOnClear(
                    userClear: userClear,
                    queueHadRows: queueHadRows,
                    setting: setting),
                userClear && queueHadRows && setting,
                reason: 'user $userClear, rows $queueHadRows, box $setting');
          }
        }
      }
      expect(
          clearsPinsOnClear(
              userClear: true, queueHadRows: true, setting: true),
          isTrue);
    });
  });

  group('culprits (rows a server refused)', () {
    test('Drift: an engine row is dropped, the user\'s pin set aside', () {
      final s = picks(3)
          .setPinned(SeedList.moreLike, key('p1'), true, now: at(3));
      final c = s.culprits({key('p0'), key('p1'), key('nope')});
      expect(c.drop, {key('p0')});
      expect(c.setAside, {key('p1')});
    });

    test('Stay close: every row shows pinned, so none is dropped', () {
      final s = picks(3)
          .freeze(at(3))
          .admitAnchor(song('a'), usable: (_) => false, now: at(4));
      final c = s.culprits({key('p0'), key('a')});
      expect(c.drop, isEmpty);
      expect(c.setAside, {key('p0'), key('a')});
    });

    test('keys of no More like row are in neither set', () {
      final s = picks(1).quickSkip(song('x'), learn: true, now: at(1));
      final c = s.culprits({key('x'), key('fallback')});
      expect(c.drop, isEmpty);
      expect(c.setAside, isEmpty);
    });
  });

  group('AutoDjSeed.copyWith', () {
    test('a null keeps the field', () {
      final s = AutoDjSeed(
          song: song('x'),
          origin: SeedOrigin.skip,
          addedAt: t0,
          vector: 'V',
          vectorModel: 'm');
      final c = s.copyWith(pinned: true);
      expect(c.pinned, isTrue);
      expect(c.origin, SeedOrigin.skip);
      expect(c.addedAt, t0);
      expect(c.vector, 'V');
      expect(c.vectorModel, 'm');
      expect(c.song, same(s.song));
    });
  });
}
