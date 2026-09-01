import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/server_version.dart';

void main() {
  group('ServerVersion.tryParse', () {
    test('plain and v-prefixed', () {
      expect(ServerVersion.tryParse('6.22.0'), ServerVersion(6, 22, 0, ''));
      expect(ServerVersion.tryParse('v6.22.0'), ServerVersion(6, 22, 0, ''));
    });

    test('a missing patch reads as .0', () {
      expect(ServerVersion.tryParse('6.15'), ServerVersion(6, 15, 0, ''));
    });

    // Paul's own fork tags as `-velvet`; it answers for its base version's
    // features, so the suffix must not defeat the parse.
    test('fork and pre-release suffixes are ignored for comparison', () {
      final v = ServerVersion.tryParse('6.4.2-velvet');
      expect(v, ServerVersion(6, 4, 2, ''));
      expect(v!.raw, '6.4.2-velvet', reason: 'display keeps the suffix');
    });

    test('nonsense parses to null, not to zero', () {
      for (final bad in [null, '', '   ', 'unknown', '<!DOCTYPE html>', 'v']) {
        expect(ServerVersion.tryParse(bad), isNull, reason: 'input: $bad');
      }
    });
  });

  group('ordering', () {
    test('compares component-wise, not lexically', () {
      // The lexical trap: "6.9" > "6.10" as strings.
      final a = ServerVersion.tryParse('6.9.0')!;
      final b = ServerVersion.tryParse('6.10.0')!;
      expect(a < b, isTrue);
      expect(b >= a, isTrue);
    });

    test('major beats minor beats patch', () {
      expect(ServerVersion.tryParse('5.99.99')! < ServerVersion.tryParse('6.0.0')!,
          isTrue);
      expect(ServerVersion.tryParse('6.1.0')! < ServerVersion.tryParse('6.1.1')!,
          isTrue);
    });
  });

  group('isBelowSupportFloor', () {
    // A server that cannot report a version is pre-5.4.2, which is below the
    // 5.5 floor by construction — the whole reason the floor sits there.
    test('unknown counts as below', () {
      expect(isBelowSupportFloor(null), isTrue);
    });

    test('the floor itself is supported', () {
      expect(isBelowSupportFloor(ServerVersion.tryParse('5.5.0')), isFalse);
      expect(isBelowSupportFloor(ServerVersion.tryParse('5.4.9')), isTrue);
    });

    test('everything modern is supported', () {
      for (final v in ['5.10.0', '6.0.0', '6.22.0']) {
        expect(isBelowSupportFloor(ServerVersion.tryParse(v)), isFalse,
            reason: v);
      }
    });
  });

  group('updateBandFor', () {
    test('5.x and unknown get the loud flag', () {
      expect(updateBandFor(null), UpdateBand.urgent);
      expect(updateBandFor(ServerVersion.tryParse('5.5.0')), UpdateBand.urgent);
      expect(updateBandFor(ServerVersion.tryParse('5.16.0')), UpdateBand.urgent);
    });

    test('6.0 through 6.14 get the quiet flag', () {
      for (final v in ['6.0.0', '6.9.0', '6.14.9']) {
        expect(updateBandFor(ServerVersion.tryParse(v)), UpdateBand.suggested,
            reason: v);
      }
    });

    test('6.15 and up show nothing', () {
      for (final v in ['6.15.0', '6.22.0', '7.0.0']) {
        expect(updateBandFor(ServerVersion.tryParse(v)), UpdateBand.none,
            reason: v);
      }
    });

    // The boundary that would break under a lexical compare.
    test('6.9 is behind 6.15, not ahead of it', () {
      expect(updateBandFor(ServerVersion.tryParse('6.9.0')),
          UpdateBand.suggested);
    });
  });

  group('playlistRenameKnownUnsupported', () {
    test('below 5.16.0 the menu item is dropped', () {
      for (final v in ['5.5.0', '5.15.9']) {
        expect(playlistRenameKnownUnsupported(ServerVersion.tryParse(v)),
            isTrue, reason: v);
      }
    });

    test('5.16.0 and up keep it', () {
      for (final v in ['5.16.0', '6.22.0']) {
        expect(playlistRenameKnownUnsupported(ServerVersion.tryParse(v)),
            isFalse, reason: v);
      }
    });

    // "Known to be too old", not "not known to be new enough". A fork's
    // numbering is its own and an unknown version says nothing at all, so
    // both keep the item and let the server answer — hiding a feature a
    // server may well support is the worse mistake.
    test('a fork and an unknown version both keep it', () {
      expect(playlistRenameKnownUnsupported(ServerVersion.tryParse('5.4.2-velvet')),
          isFalse);
      expect(playlistRenameKnownUnsupported(null), isFalse);
    });
  });

  group('autoDjDurationKnownUnsupported', () {
    test('below 6.25.0 the length control is hidden', () {
      // Includes servers that have every OTHER Auto DJ filter: the duration
      // params landed long after the 6.7.1 block, so passing that gate says
      // nothing about this one.
      for (final v in ['6.7.1', '6.15.2', '6.24.0']) {
        expect(autoDjDurationKnownUnsupported(ServerVersion.tryParse(v)),
            isTrue, reason: v);
      }
    });

    test('6.25.0 and up show it', () {
      for (final v in ['6.25.0', '6.25.1', '7.0.0']) {
        expect(autoDjDurationKnownUnsupported(ServerVersion.tryParse(v)),
            isFalse, reason: v);
      }
    });

    test('a fork and an unknown version both keep it', () {
      // Same rule as every other gate: neither can be compared to an upstream
      // milestone, so neither is KNOWN to be too old. Show the control and let
      // a rejection teach us, rather than hiding something that may work.
      for (final v in ['6.24.0-velvet', 'not-a-version', '']) {
        expect(autoDjDurationKnownUnsupported(ServerVersion.tryParse(v)),
            isFalse, reason: v);
      }
      expect(autoDjDurationKnownUnsupported(null), isFalse);
    });

    test('it is gated apart from the 6.7.1 filter block', () {
      // A 6.24.0 server passes the older gate and fails this one — the whole
      // reason this is a separate helper.
      final v = ServerVersion.tryParse('6.24.0');
      expect(autoDjFiltersKnownUnsupported(v), isFalse);
      expect(autoDjDurationKnownUnsupported(v), isTrue);
    });
  });

  group('metadataBatchKnownUnsupported', () {
    test('below 5.11.0 the batch request is skipped', () {
      for (final v in ['5.5.0', '5.10.9']) {
        expect(metadataBatchKnownUnsupported(ServerVersion.tryParse(v)), isTrue,
            reason: v);
      }
    });

    test('5.11.0 and up batch', () {
      for (final v in ['5.11.0', '5.16.0', '6.22.0']) {
        expect(metadataBatchKnownUnsupported(ServerVersion.tryParse(v)),
            isFalse, reason: v);
      }
    });

    // A fork and an unknown version both try it. Costing one 404 that falls
    // straight back to the per-track path is cheaper than never batching for
    // a server that supports it — the floor is an optimisation, and the
    // fallback is what actually has to be right.
    test('a fork and an unknown version both try', () {
      expect(
          metadataBatchKnownUnsupported(ServerVersion.tryParse('5.4.2-velvet')),
          isFalse);
      expect(metadataBatchKnownUnsupported(null), isFalse);
    });
  });

  group('floorVerdictFor (the add-time warning)', () {
    FloorVerdict verdict(String? raw, {bool notFound = false}) =>
        floorVerdictFor(ServerVersion.tryParse(raw), notFound: notFound);

    test('a current server says nothing', () {
      expect(verdict('6.25.0'), FloorVerdict.ok);
      // Patch part optional on the wire.
      expect(verdict('6.25'), FloorVerdict.ok);
      expect(verdict('v6.25.0'), FloorVerdict.ok);
    });

    test('a reported version below the floor warns with the number', () {
      expect(verdict('5.4.2'), FloorVerdict.belowFloor);
    });

    test('a 404 is the one no-version answer that means old', () {
      expect(verdict(null, notFound: true), FloorVerdict.preVersionEndpoint);
    });

    test('a FAILED probe must not read as "older than 5.5"', () {
      // The regression this pins: a just-added Quick Connect server whose
      // tunnel auth had not settled (or any network blip at add time)
      // produced a null version and toasted "older than 5.5" at a v6.25
      // server. No 404 → no age claim.
      expect(verdict(null), FloorVerdict.unknown);
      // Junk body → parse fails → same rule: a server that answered /api/
      // is self-evidently not pre-5.4.2.
      expect(verdict('<!doctype html>'), FloorVerdict.unknown);
    });
  });
}
