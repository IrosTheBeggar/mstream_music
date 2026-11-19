import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../objects/discovery.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/server_list.dart';
import 'copies_sheet.dart';
import 'destination_sheet.dart';
import 'discovery_jobs_controller.dart';
import 'elsewhere_sheet.dart';
import 'network_lead_sheet.dart';

/// Where the Keep a copy surfaces hand off to the sheets they open but do
/// not draw: "Open elsewhere" (the links plug-in's sub-sheet), the Copies
/// sheet (the strip under Discover's bar), the destination picker ("Change"
/// on the Keep card — a folder's "By your layout" previews the folder),
/// "Show in your library" (a folder copy's files on the user's own server),
/// and the network-lead sheet (a "From the network" row on More like this).
/// The entry points call these; tests set their own to see the call.
class DiscoveryKeepRoutes {
  DiscoveryKeepRoutes._();

  /// "Open elsewhere" on a connected server's song sheet and on the
  /// network-lead sheet: [lead]'s recommendation (its raw, sent to the links
  /// plug-in as the sheet holds it — a connected server's row as received,
  /// a network row repaired — asked only now).
  static void Function(
    BuildContext context,
    DiscoveryJobsController jobs,
    DiscoveryLead lead,
  )
  openElsewhere = _openElsewhere;

  /// The Copies strip's tap: the Copies sheet.
  static void Function(BuildContext context, DiscoveryJobsController jobs)
  openCopies = _openCopies;

  /// "Change" on the Keep card: the destination picker, previewing where
  /// [song] would land ([peerName] fills a layout's server folder).
  static void Function(
    BuildContext context,
    DiscoveryJobsController jobs,
    DestinationPreviewSong? song,
    String peerName,
  )
  changeDestination = _changeDestination;

  /// "Change" under a folder's "By your layout" (a browse-entered Keep
  /// card): the destination picker, previewing where [folder]'s songs land
  /// by the folder rule.
  static void Function(
    BuildContext context,
    DiscoveryJobsController jobs,
    DestinationPreviewFolder folder,
    String peerName,
  )
  changeFolderDestination = _changeFolderDestination;

  /// "Show in your library" on a finished folder copy: the user's own
  /// server ([own]) becomes the browsed one, and its file explorer opens
  /// at [directory] ("/copies/Boukmanflow/Borrowed Tapes"). False when the
  /// explorer did not open there (the caller says so).
  static Future<bool> Function(Server own, String directory) showInLibrary =
      _showInLibrary;

  /// A "From the network" row's tap on More like this, and Copies' way back
  /// to a YouTube add's song (CopiesSheet.reopenLead: "Choose another" —
  /// [autoSearch], the YouTube search starts as it opens, [avoidUrl] the
  /// failed upload not to pick — and the View on its destination toast):
  /// the network-lead sheet for [lead] (showNetworkLeadSheet — [seedTitle]
  /// for its match line, [onLeadAction] on its first lead action).
  static void Function(
    BuildContext context,
    DiscoveryJobsController jobs,
    DiscoveryLead lead, {
    String? seedTitle,
    bool autoSearch,
    String? avoidUrl,
    VoidCallback? onLeadAction,
  })
  openNetworkLead = _openNetworkLead;

  /// Put the real sheets back (tests) — Copies' way back to a YouTube add's
  /// song (CopiesSheet.openLead) too.
  static void reset() {
    openElsewhere = _openElsewhere;
    openCopies = _openCopies;
    changeDestination = _changeDestination;
    changeFolderDestination = _changeFolderDestination;
    showInLibrary = _showInLibrary;
    openNetworkLead = _openNetworkLead;
    CopiesSheet.openLead = CopiesSheet.reopenLead;
  }

  static void _openElsewhere(
    BuildContext context,
    DiscoveryJobsController jobs,
    DiscoveryLead lead,
  ) => unawaited(showElsewhereSheet(context, jobs, lead));

  static void _openCopies(BuildContext context, DiscoveryJobsController jobs) =>
      unawaited(showCopiesSheet(context, jobs));

  static void _openNetworkLead(
    BuildContext context,
    DiscoveryJobsController jobs,
    DiscoveryLead lead, {
    String? seedTitle,
    bool autoSearch = false,
    String? avoidUrl,
    VoidCallback? onLeadAction,
  }) => unawaited(
    showNetworkLeadSheet(
      context,
      jobs: jobs,
      lead: lead,
      seedTitle: seedTitle,
      autoSearch: autoSearch,
      avoidUrl: avoidUrl,
      onLeadAction: onLeadAction,
    ),
  );

  static void _changeDestination(
    BuildContext context,
    DiscoveryJobsController jobs,
    DestinationPreviewSong? song,
    String peerName,
  ) => unawaited(
    showDestinationSheet(context, jobs, song: song, peerName: peerName),
  );

  static void _changeFolderDestination(
    BuildContext context,
    DiscoveryJobsController jobs,
    DestinationPreviewFolder folder,
    String peerName,
  ) => unawaited(
    showDestinationSheet(context, jobs, folder: folder, peerName: peerName),
  );

  /// Once the switch settled (its home reset, an iroh tunnel up), the
  /// explorer goes onto the new stack.
  static Future<bool> _showInLibrary(Server own, String directory) async {
    final sm = ServerManager();
    final index = sm.serverList.indexOf(own);
    if (index < 0) return false;
    if (!identical(sm.currentServer, own)) await sm.changeCurrentServer(index);
    return ApiManager().getFileList(directory, useThisServer: own, quiet: true);
  }
}
