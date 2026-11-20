// The browser's chrome on the Peer Recommendations page (mStream
// docs/peer-recommendations-plan.md §4.2): the home's card opens the page
// as a browser frame, and the toolbar over it reads back · the title · New
// seeds — on only while the page's controller can ask again, a plain re-ask
// — with no Filters, no page-wide Play / Add all / Download, no search and
// no overflow (the page's footer carries Preview all · Copy list).

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/peer_recs_listing.dart';
import 'package:mstream_music/screens/discovery/peer_recs_view.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';
import 'package:mstream_music/widgets/mood_filter_sheet.dart';
import 'package:rxdart/rxdart.dart';

import '../media/preview_fakes.dart';
import '../screens/discovery/peer_recs_fakes.dart';
import '../screens/discovery/peer_recs_fixtures.dart';

/// The player with nothing playing: the home's Auto DJ card and the page's
/// now-playing pin read it, and nothing else is asked.
class _NothingPlaying implements AudioPlayerHandler {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Server s;

  setUp(() {
    FakePreviewPlayer.install();
    MediaManager().audioHandler = _NothingPlaying();
    s = peerRecsServer();
    ServerManager().serverList
      ..clear()
      ..add(s);
    ServerManager().currentServer = s;
    BrowserManager().goToNavScreen();
  });

  tearDown(() {
    // Off the stack, so the visit lets go of its controller.
    while (BrowserManager().browserCache.length > 1) {
      BrowserManager().popBrowser();
    }
    BrowserManager().goToNavScreen();
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  });

  Future<void> pumpApp(WidgetTester t, {double height = 844}) async {
    t.view.physicalSize = Size(390 * 3, height * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: const Scaffold(appBar: BrowserToolbar(), body: Browser()),
    ));
    await t.pump();
  }

  final toolbar = find.byType(BrowserToolbar);
  Finder inBar(IconData icon) =>
      find.descendant(of: toolbar, matching: find.byIcon(icon));
  final newSeeds = find.byKey(const ValueKey('discovery-new-seeds'));
  bool newSeedsOn(WidgetTester t) =>
      t.widget<IconButton>(newSeeds).onPressed != null;

  testWidgets(
      'the toolbar on the page: back, the title, New seeds (on only when '
      'canRefresh), no Filters, no Play/Add all, no search, no overflow',
      (t) async {
    final f = FakePeerRecs(server: s)
      ..peersAuto = () => peersOk(peersAdminJson);
    final c = f.makeController();
    await pumpApp(t);
    PeerRecsListing().open(s, controller: c);
    await t.pump();
    await t.pump();
    expect(identical(PeerRecsListing().controller, c), isTrue);
    expect(f.requests, hasLength(1), reason: 'R1 is out, held');

    // back · the title · New seeds, and nothing else.
    expect(inBar(Icons.arrow_back), findsOneWidget);
    expect(
        find.descendant(
            of: toolbar, matching: find.text('Peer Recommendations')),
        findsOneWidget);
    expect(find.descendant(of: toolbar, matching: newSeeds), findsOneWidget);
    expect(t.widget<IconButton>(newSeeds).tooltip, 'New seeds');
    expect(inBar(Icons.refresh), findsOneWidget);
    expect(find.descendant(of: toolbar, matching: find.byType(MoodFilterButton)),
        findsNothing,
        reason: 'no Filters: the page does not filter by mood');
    expect(inBar(Icons.play_arrow), findsNothing);
    expect(inBar(Icons.library_add), findsNothing);
    expect(inBar(Icons.download_sharp), findsNothing);
    expect(inBar(Icons.shuffle), findsNothing);
    expect(inBar(Icons.search), findsNothing, reason: 'nothing to search');
    expect(inBar(Icons.smart_display_outlined), findsNothing);
    expect(inBar(Icons.more_vert), findsNothing,
        reason: 'no overflow: nothing page-wide to put in it');
    expect(find.descendant(of: toolbar, matching: find.byType(PopupMenuButton)),
        findsNothing);
    expect(t.takeException(), isNull);

    // While R1 is out the controller cannot ask again: off.
    expect(c.canRefresh, isFalse);
    expect(newSeedsOn(t), isFalse);

    // The answer lands: on.
    f.answerTaste(tasteOk(tasteJson()));
    await t.pump();
    await t.pump();
    expect(c.canRefresh, isTrue);
    expect(newSeedsOn(t), isTrue);

    // A tap asks again, and the button is off while that call is out.
    await t.tap(newSeeds);
    await t.pump();
    expect(f.requests, hasLength(2));
    expect(c.canRefresh, isFalse);
    expect(newSeedsOn(t), isFalse);
    f.answerTaste(tasteOk(tasteJson()));
    await t.pump();
    await t.pump();
    expect(newSeedsOn(t), isTrue);

    // Another list opened over the page keeps its own bar (search), and no
    // New seeds; Back on the page: New seeds again, and no search.
    BrowserManager().setBrowserLabel('File Explorer');
    BrowserManager().addListToStack(
        [DisplayItem(s, 'music', 'directory', '/music', null, null)],
        path: '/');
    await t.pump();
    expect(inBar(Icons.search), findsOneWidget);
    expect(newSeeds, findsNothing);
    BrowserManager().popBrowser();
    await t.pump();
    expect(find.descendant(of: toolbar, matching: newSeeds), findsOneWidget);
    expect(inBar(Icons.search), findsNothing);
    expect(
        find.descendant(
            of: toolbar, matching: find.text('Peer Recommendations')),
        findsOneWidget,
        reason: 'the label is restored');

    // Back from the page: the home.
    await t.tap(inBar(Icons.arrow_back));
    await t.pump();
    await t.pump();
    expect(BrowserManager.isHomeList(BrowserManager().browserList), isTrue);
    expect(newSeeds, findsNothing);
  });

  testWidgets('tapping the card opens the page', (t) async {
    // Tall enough that the whole home is laid out, the LISTEN group too.
    await pumpApp(t, height: 2600);
    expect(find.byType(PeerRecsView), findsNothing);
    final card = find.text('Peer Recommendations');
    expect(card, findsOneWidget, reason: 'the home card');

    await t.tap(card);
    await t.pump();
    await t.pump();

    // One marker frame for the page, which the browser hands to its view.
    final frame = BrowserManager().browserList;
    expect(PeerRecsListing.isListing(frame), isTrue);
    expect(frame, hasLength(1));
    expect(frame.single.server, same(s));
    expect(BrowserManager().browserCache, hasLength(2),
        reason: 'over the home: Back returns to it');
    expect(PeerRecsListing().controller, isNotNull);
    expect(PeerRecsListing().controller!.server, same(s));
    expect(find.byType(PeerRecsView), findsOneWidget);
    expect(
        find.descendant(
            of: toolbar, matching: find.text('Peer Recommendations')),
        findsOneWidget,
        reason: "the toolbar's title");
    expect(inBar(Icons.arrow_back), findsOneWidget);
    expect(find.descendant(of: toolbar, matching: newSeeds), findsOneWidget);

    // Back: the home again, and the visit let go.
    await t.tap(inBar(Icons.arrow_back));
    await t.pump();
    await t.pump();
    expect(BrowserManager.isHomeList(BrowserManager().browserList), isTrue);
    expect(find.byType(PeerRecsView), findsNothing);
    expect(PeerRecsListing().controller, isNull);
    expect(find.text('Peer Recommendations'), findsOneWidget,
        reason: 'the home card again');
  });
}
