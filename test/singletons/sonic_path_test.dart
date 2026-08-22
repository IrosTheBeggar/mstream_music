import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/sonic_path_state.dart';
import 'package:mstream_music/singletons/track_capture.dart';

Server _server(String name) => Server('http://$name', null, null, null, name);

DisplayItem _file(Server? s, String path, {String type = 'file'}) =>
    DisplayItem(s, path.split('/').last, type, path, null, null);

/// A request with the banner/return-route boilerplate filled in — these tests
/// are about which rows a capture accepts, not about what it displays.
TrackCaptureRequest _req(Server s, void Function(DisplayItem) onPicked) =>
    TrackCaptureRequest(
      server: s,
      bannerLabel: (l) => 'pick',
      returnScreen: (_) => const SizedBox.shrink(),
      onPicked: onPicked,
    );

void main() {
  final a = _server('alpha');
  final b = _server('beta');

  setUp(() {
    // Both are process-wide singletons — start every test pristine.
    SonicPathState()
      ..server = null
      ..reset();
    TrackCapture.cancel();
  });

  group('SonicPathState', () {
    test('beginSetup on a new server clears endpoints and length', () {
      final s = SonicPathState();
      s.beginJourney(a, SonicPathEndpoint('/x.mp3'), SonicPathEndpoint('/y.mp3'));
      s.length = 22;
      s.beginSetup(b);
      expect(s.server, same(b));
      expect(s.start, isNull);
      expect(s.end, isNull);
      expect(s.length, 14);
    });

    test('beginSetup on the same server keeps picked endpoints', () {
      final s = SonicPathState();
      s.beginSetup(a);
      s.start = SonicPathEndpoint('/x.mp3', title: 'X');
      s.length = 8;
      s.beginSetup(a);
      expect(s.start?.title, 'X');
      expect(s.end, isNull);
      expect(s.length, 8);
    });

    test('beginJourney sets both ends and resets length', () {
      final s = SonicPathState();
      s.length = 30;
      s.beginJourney(a, SonicPathEndpoint('/x.mp3'), SonicPathEndpoint('/y.mp3'));
      expect(s.ready, isTrue);
      expect(s.length, 14);
    });

    test('reset clears endpoints + length but keeps the server', () {
      final s = SonicPathState();
      s.beginJourney(a, SonicPathEndpoint('/x.mp3'), SonicPathEndpoint('/y.mp3'));
      s.length = 20;
      s.reset();
      expect(s.server, same(a));
      expect(s.start, isNull);
      expect(s.end, isNull);
      expect(s.length, 14);
      expect(s.ready, isFalse);
    });

    test('ready only once server and both endpoints are set', () {
      final s = SonicPathState();
      expect(s.ready, isFalse);
      s.beginSetup(a);
      expect(s.ready, isFalse);
      s.start = SonicPathEndpoint('/x.mp3');
      expect(s.ready, isFalse);
      s.end = SonicPathEndpoint('/y.mp3');
      expect(s.ready, isTrue);
    });
  });

  group('TrackCapture.tryCapture', () {
    test('passes when nothing is armed', () {
      expect(TrackCapture.tryCapture(_file(a, '/x.mp3')), CaptureResult.pass);
    });

    test('captures a matching-server track, delivers it, and disarms', () {
      DisplayItem? picked;
      TrackCapture.arm(_req(a, (i) => picked = i));
      final item = _file(a, '/music/x.mp3');
      expect(TrackCapture.tryCapture(item), CaptureResult.captured);
      expect(picked, same(item));
      expect(TrackCapture.active.value, isNull);
      // Disarmed — the next tap runs the normal handling.
      expect(TrackCapture.tryCapture(item), CaptureResult.pass);
    });

    test('rejects another server\'s track and stays armed', () {
      TrackCapture.arm(_req(a, (_) => fail('must not pick')));
      expect(TrackCapture.tryCapture(_file(b, '/x.mp3')),
          CaptureResult.rejected);
      expect(TrackCapture.active.value, isNotNull);
    });

    test('rejects local files and rows without a path, then still captures',
        () {
      DisplayItem? picked;
      TrackCapture.arm(_req(a, (i) => picked = i));
      expect(TrackCapture.tryCapture(_file(a, '/x.mp3', type: 'localFile')),
          CaptureResult.rejected);
      expect(TrackCapture.tryCapture(_file(null, '/x.mp3')),
          CaptureResult.rejected);
      final noPath = DisplayItem(a, 'x', 'file', null, null, null);
      expect(TrackCapture.tryCapture(noPath), CaptureResult.rejected);
      // A valid row after the rejections still lands.
      final item = _file(a, '/music/ok.mp3');
      expect(TrackCapture.tryCapture(item), CaptureResult.captured);
      expect(picked, same(item));
    });

    test('cancel disarms without picking', () {
      TrackCapture.arm(_req(a, (_) => fail('must not pick')));
      TrackCapture.cancel();
      expect(TrackCapture.active.value, isNull);
      expect(TrackCapture.tryCapture(_file(a, '/x.mp3')), CaptureResult.pass);
    });
  });
}
