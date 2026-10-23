import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../objects/discovery.dart';
import 'copies_sheet.dart';
import 'destination_sheet.dart';
import 'discovery_jobs_controller.dart';
import 'elsewhere_sheet.dart';

/// Where the Keep a copy surfaces hand off to the sheets they open but do
/// not draw: "Open elsewhere" (the links plug-in's sub-sheet), the Copies
/// sheet (the strip under Discover's bar), and the destination picker
/// ("Change" on the Keep card). The entry points call these; tests set
/// their own to see the call.
class DiscoveryKeepRoutes {
  DiscoveryKeepRoutes._();

  /// "Open elsewhere" on a connected server's song sheet: [lead]'s
  /// recommendation (sent unchanged to the links plug-in, asked only now).
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

  /// Put the real sheets back (tests).
  static void reset() {
    openElsewhere = _openElsewhere;
    openCopies = _openCopies;
    changeDestination = _changeDestination;
  }

  static void _openElsewhere(
    BuildContext context,
    DiscoveryJobsController jobs,
    DiscoveryLead lead,
  ) => unawaited(showElsewhereSheet(context, jobs, lead));

  static void _openCopies(BuildContext context, DiscoveryJobsController jobs) =>
      unawaited(showCopiesSheet(context, jobs));

  static void _changeDestination(
    BuildContext context,
    DiscoveryJobsController jobs,
    DestinationPreviewSong? song,
    String peerName,
  ) => unawaited(
    showDestinationSheet(context, jobs, song: song, peerName: peerName),
  );
}
