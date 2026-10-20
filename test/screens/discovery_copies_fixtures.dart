// Shared fixtures for the Copies sheet, the destination picker and Open
// elsewhere: the stage's sample rows (the design kit's §4), a many-song
// result, and a host page that opens one sheet over it, with the plug-in
// fake, manual timers and the toasts caught.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/copies_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/singletons/server_list.dart';

import 'discovery_fixtures.dart';
import 'discovery_keep_fixtures.dart';
import 'discovery_plugin_fakes.dart';

Map<String, dynamic> many({
  int copied = 0,
  int skipped = 0,
  int failed = 0,
  String? stopped,
  List<Map<String, dynamic>> copiedSongs = const [],
}) => {
  'scope': 'album',
  'songs': {
    'total': copied + skipped + failed,
    'copied': copiedSongs,
    'skipped': [],
    'failed': [],
  },
  'counts': {
    'total': copied + skipped + failed,
    'copied': copied,
    'skipped': skipped,
    'failed': failed,
  },
  'albums': [],
  'skippedAlbums': [],
  'stopped': stopped,
  'peer': peerB,
};

/// The stage's sample rows (KIT §4).
final tapes = keepRow('Late Train Verse', track: '02 - ');
final brass = keepRow(
  'Brass District',
  artist: 'ALM',
  album: 'Free Instrumentals Vol. 9',
);
final orchard = keepRow(
  'Midnight Orchard',
  artist: 'ALM',
  album: 'Free Instrumentals Vol. 9',
);
final lullaby = keepRow(
  'Static Lullaby',
  artist: 'Night Owl Radio',
  album: 'First Transmission',
  peer: peerC,
);
final transmission = keepRow(
  'Low Frequency Hello',
  artist: 'Night Owl Radio',
  album: 'First Transmission',
  peer: peerC,
);
final sessions = keepRow(
  'Glass Hours',
  artist: 'Color Out',
  album: 'Peer Sessions',
);

class SheetHarness {
  late Server server;
  late FakePluginServer fake;
  late FakeTimers timers;
  late DiscoveryJobsController jobs;
  final List<String> toasts = [];
  final List<bool> toastSuccess = [];

  void setUp() {
    ServerManager().serverList.clear();
    server = discoveryServer()
      ..discoveryPluginsAvailable = true
      ..noUpload = false;
    ServerManager().serverList.add(server);
    fake = FakePluginServer();
    timers = FakeTimers();
    jobs = make(server);
    toasts.clear();
    toastSuccess.clear();
    KeepToast.debugSink = (m, {success = false}) {
      toasts.add(m);
      toastSuccess.add(success);
    };
  }

  DiscoveryJobsController make(Server s) => DiscoveryJobsController(
    server: s,
    api: fake.api(s),
    timer: timers.call,
    watchLifecycle: false,
  );

  void tearDown() {
    KeepToast.debugSink = null;
    jobs.dispose();
    ServerManager().serverList.clear();
  }

  /// A page with one button that opens [open] over it.
  Future<void> pumpHost(
    WidgetTester tester,
    void Function(BuildContext context) open, {
    double width = 390,
    double height = 844,
    double textScale = 1,
    Locale? locale,
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await KeepHarness.pumpFor(tester, 8);
  }

  Future<void> pumpCopies(
    WidgetTester tester, {
    bool fromHome = false,
    double width = 390,
    double height = 844,
    double textScale = 1,
    Locale? locale,
  }) => pumpHost(
    tester,
    (c) => showCopiesSheet(c, jobs, fromHome: fromHome),
    width: width,
    height: height,
    textScale: textScale,
    locale: locale,
  );
}
