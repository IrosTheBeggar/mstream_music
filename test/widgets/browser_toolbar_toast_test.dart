// Add All's toast and the docked mini player. The toast floats above the
// mini player for the 4 s it shows, so play/pause and next still take taps.
// A plain snackbar landed on them and swallowed the taps. The harness nests
// the toolbar the way main.dart does: in the home Scaffold's app bar, under
// the outer Scaffold that shows the app's snackbars, with the mini player
// docked across the bottom.

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

/// A player with nothing playing whose queue takes what Add All sends.
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

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async =>
      queue.add([...queue.value, ...mediaItems]);

  @override
  Future<void> play() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MediaManager().audioHandler = _Player();
    BrowserManager().goToNavScreen();
  });
  tearDown(() => BrowserManager().goToNavScreen());

  testWidgets(
      "Add All's toast floats above the mini player, whose play/pause and "
      'next still take taps', (tester) async {
    // A 402 × 874 phone whose bottom 34 dp are the home bar's.
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    tester.view.viewPadding =
        const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);

    var plays = 0;
    var nexts = 0;
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
                    onPressed: () => plays++,
                  ),
                  IconButton(
                    key: const ValueKey('mini-next'),
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => nexts++,
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
    await tester.tap(find.byTooltip('Add All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    final toast = find.text('3 songs added to queue');
    expect(toast, findsOneWidget);
    expect(MediaManager().audioHandler.queue.value, hasLength(3));

    final miniTop =
        tester.getTopLeft(find.byKey(const ValueKey('mini-player'))).dy;
    final surface = find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first;
    expect(tester.getRect(surface).bottom, lessThanOrEqualTo(miniTop));

    await tester.tap(find.byKey(const ValueKey('mini-play')));
    await tester.tap(find.byKey(const ValueKey('mini-next')));
    expect((plays, nexts), (1, 1));
    expect(toast, findsOneWidget, reason: 'the taps landed while it showed');

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
  });
}
