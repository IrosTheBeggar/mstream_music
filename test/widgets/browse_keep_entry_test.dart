// widgets/browse_keep_entry.dart — focus coming back to what opened a Keep
// sheet (the phone spec's §8.3): the opener's own node while it is still
// mounted, else the one registered under the request's stable key — the
// latest still there when two share it — else the page's fallback, and a
// node whose Focus is gone (it keeps its context) is never chosen.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/widgets/browse_keep_entry.dart';

void main() {
  late Server peer;
  late BrowseKeepRequest request;

  setUp(() {
    final home = Server('http://home.local:3000', null, null, 'JWT', 'home');
    peer = Server('federated://home/1', null, null, null, 'peer-1')
      ..federationParent = 'home'
      ..federationPeerId = 1
      ..federationPeerName = 'Stage Peer B'
      ..parentServer = home;
    request = BrowseKeepRequest.ofFolder(FolderRef.of('/music/Boukmanflow')!, peer, variant: KeepVariant.page)!;
    BrowseKeepEntry.opener = (context, r, {marks}) async {};
  });
  tearDown(BrowseKeepEntry.reset);

  Widget anchor(String? key, {String label = 'x'}) => KeepFocusAnchor(
        focusKey: key,
        builder: (context, node) => TextButton(focusNode: node, onPressed: () {}, child: Text(label)),
      );

  testWidgets('two openers under one key: the later one, then — once it goes — the earlier one', (tester) async {
    final key = request.focusKey;
    await tester.pumpWidget(MaterialApp(home: Column(children: [anchor(key, label: 'a'), anchor(key, label: 'b')])));
    expect(BrowseKeepEntry.anchorOf(key)!.debugLabel, 'keep $key');
    final b = Focus.of(tester.element(find.text('b')));
    expect(identical(BrowseKeepEntry.anchorOf(key), b), isTrue);
    await tester.pumpWidget(MaterialApp(home: Column(children: [anchor(key, label: 'a')])));
    final a = Focus.of(tester.element(find.text('a')));
    expect(identical(BrowseKeepEntry.anchorOf(key), a), isTrue, reason: 'the one still mounted');
  });

  testWidgets("an opener whose Focus is gone is skipped for the next that is there", (tester) async {
    final gone = FocusNode(debugLabel: 'gone');
    final fallback = FocusNode(debugLabel: 'fallback');
    addTearDown(gone.dispose);
    addTearDown(fallback.dispose);
    await tester.pumpWidget(MaterialApp(home: Column(children: [Focus(focusNode: gone, child: const Text('g'))])));
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        context = c;
        return Focus(focusNode: fallback, child: const Text('f'));
      }),
    ));
    expect(gone.context, isNotNull, reason: 'a node keeps its context once its Focus unmounted');
    await BrowseKeepEntry.open(context, request, from: gone, fallback: fallback);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(fallback));
  });
}
