// Add All's toast and the docked mini player. The toast floats above the
// mini player for the 4 s it shows, so play/pause and next still take taps.
// A plain snackbar landed on them and swallowed the taps. The harness nests
// the toolbar the way main.dart does: in the home Scaffold's app bar, under
// the outer Scaffold that shows the app's snackbars, with the mini player
// docked across the bottom.
//
// Onto an empty queue, Add All also starts playback, and it waited on the
// handler's play(), which returns late: on an idle player once the first
// song has loaded, otherwise only when playback stops (just_audio's play()).
// Its toast came that late; now it comes at once. The fake player takes the
// worst case: its play() does not return while the song plays.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';
import 'package:mstream_music/widgets/player_panel.dart';
import 'package:rxdart/rxdart.dart';

/// A player whose queue takes what Add All sends, and whose play() does not
/// return while the song plays.
class _Player implements AudioPlayerHandler {
  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(null);
  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject.seeded(PlaybackState());
  @override
  final BehaviorSubject<List<MediaItem>> queue =
      BehaviorSubject.seeded(const []);
  @override
  final BehaviorSubject<dynamic> customState = BehaviorSubject.seeded(null);
  int plays = 0;
  Completer<void>? _playing;

  /// play() was called and has not returned: the song is still playing.
  bool get playing => _playing != null && !_playing!.isCompleted;

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async =>
      queue.add([...queue.value, ...mediaItems]);

  @override
  Future<void> play() {
    plays++;
    return (_playing ??= Completer<void>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The mini player's play/pause and next taps.
class _Taps {
  int plays = 0;
  int nexts = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Player player;

  setUp(() {
    player = _Player();
    MediaManager().audioHandler = player;
    BrowserManager().goToNavScreen();
  });
  tearDown(() => BrowserManager().goToNavScreen());

  final toast = find.text('3 songs added to queue');

  /// The toolbar in the home Scaffold's app bar, under the outer Scaffold,
  /// with the mini player docked across the bottom, on a 402 × 874 phone
  /// whose bottom 34 dp are the home bar's. The browser lists three songs.
  Future<_Taps> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    tester.view.viewPadding =
        const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);

    final taps = _Taps();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Builder(builder: (context) {
        final inset = MediaQuery.viewPaddingOf(context).bottom;
        return Scaffold(
          body: Stack(children: [
            Scaffold(
              appBar: AppBar(bottom: const BrowserToolbar()),
              body: const SizedBox.expand(),
            ),
            // The mini player's footprint, with its transport row at the
            // bottom as player_panel.dart lays it out.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                key: const ValueKey('mini-player'),
                height: PlayerPanel.kCollapsedHeight + inset,
                color: Colors.black,
                padding: EdgeInsets.fromLTRB(6, 0, 6, 4 + inset),
                alignment: Alignment.bottomLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    key: const ValueKey('mini-play'),
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => taps.plays++,
                  ),
                  IconButton(
                    key: const ValueKey('mini-next'),
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => taps.nexts++,
                  ),
                ]),
              ),
            ),
          ]),
        );
      }),
    ));

    BrowserManager().addListToStack([
      for (final t in ['Rooftop Cypher', 'Late Train Verse', 'Corner Store Loop'])
        DisplayItem(
            null, '$t.mp3', 'localFile', '/storage/music/$t.mp3', null, null),
    ]);
    await tester.pump();
    return taps;
  }

  Future<void> addAll(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  testWidgets(
      "Add All's toast floats above the mini player, whose play/pause and "
      'next still take taps', (tester) async {
    player.queue.add([MediaItem(id: 'now', title: 'Now playing')]);
    final taps = await pumpShell(tester);
    await addAll(tester);
    expect(toast, findsOneWidget);
    expect(player.queue.value, hasLength(4));

    final miniTop =
        tester.getTopLeft(find.byKey(const ValueKey('mini-player'))).dy;
    final surface = find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first;
    expect(tester.getRect(surface).bottom, lessThanOrEqualTo(miniTop));

    await tester.tap(find.byKey(const ValueKey('mini-play')));
    await tester.tap(find.byKey(const ValueKey('mini-next')));
    expect((taps.plays, taps.nexts), (1, 1));
    expect(toast, findsOneWidget, reason: 'the taps landed while it showed');

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
  });

  testWidgets(
      'onto an empty queue, the toast comes at once, without waiting for '
      'playback', (tester) async {
    await pumpShell(tester);
    await addAll(tester);
    expect(player.plays, 1, reason: 'the first add starts playback');
    expect(player.playing, isTrue, reason: 'and the song is still playing');
    expect(toast, findsOneWidget);
    expect(player.queue.value, hasLength(3));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
  });
}
