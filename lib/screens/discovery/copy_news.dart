import 'dart:async';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery_plugins.dart';
import '../../util/discover_jobs.dart';
import 'discovery_jobs_controller.dart';
import 'keep_copy_ui.dart';
import 'keep_toast.dart';

/// What the copy toasts say (the design canvas's PhoneCopies / PhoneElsewhere
/// "Copy toasts"): once per start, after the sheet that started it closes —
/// "Copying Borrowed Tapes from Stage Peer B" — and when a copy this phone
/// saw live ends while the app is open: "Added to your collection" only when
/// something landed (done is not kept), "Already in your library", "Stopped
/// early: (why)" and "Copy failed: (the server's words)". A cancel, nothing
/// to copy, and a file already at the path say nothing: the row says it.

/// The start toast for [job] ([peer] when the job names no server).
String copyStartedToast(
  AppLocalizations l,
  DiscoveryJob job, {
  String peer = '',
}) {
  final rec = job.recommendation;
  String s(String k) => rec[k] is String ? (rec[k] as String).trim() : '';
  final from = (job.peerName ?? '').trim().isNotEmpty ? job.peerName! : peer;
  switch (job.scope) {
    case kScopeArtist:
      return l.discoverToastCopyingEvery(s('artist'), from);
    case kScopeArtistMissing:
      return l.discoverToastCopyingMissing(s('artist'), from);
    case kScopeAlbum:
      return l.discoverToastCopying(s('album'), from);
    default:
      final title = s('title');
      return l.discoverToastCopying(
        title.isNotEmpty ? title : safeFileName(rec['filepath']),
        from,
      );
  }
}

/// Why a copy failed, for its toast and its row: the server's words, else
/// what its counts say ("Nothing copied · 3 failed").
String copyFailedWords(AppLocalizations l, DiscoveryJob job) {
  final err = (job.error ?? '').trim();
  if (err.isNotEmpty) return err;
  final many = job.view.isMany ? job.result : null;
  if (many == null) return l.discoverJobFailedSub;
  final peer = keepJobPeer(job, '');
  final n = manyCounts(many);
  return [
    if (n.copied == 0) l.discoverJobNothingCopiedLead,
    for (final t in manyParts(many)) keepJobText(l, t, peer: peer),
  ].join(' · ');
}

/// The end toast for a copy this phone saw live, or null for an ending
/// that says nothing.
String? copyFinishedToast(AppLocalizations l, DiscoveryJob job) {
  final row = jobRowState(job, plugin: kCopyPlugin);
  switch (row.kind) {
    case JobRowKind.copied:
    case JobRowKind.copiedMany:
    case JobRowKind.downloaded:
      return l.discoverToastAdded;
    case JobRowKind.owned:
      return l.discoverToastAlreadyYours;
    case JobRowKind.stopped:
      final sub = row.sub ?? const <JobText>[];
      final why = sub.isEmpty
          ? l.discoverJobStopped
          : keepJobText(l, sub.first, peer: keepJobPeer(job, ''));
      return l.discoverToastStopped(why);
    case JobRowKind.failed:
      return l.discoverToastFailed(copyFailedWords(l, job));
    default:
      return null;
  }
}

/// Toasts every copy [jobs] saw live as it ends. [l10n] reads the words at
/// the moment (null drops the toast); [show] puts it up (KeepToast by
/// default). Cancel the subscription to stop.
StreamSubscription<DiscoveryJob> attachCopyToasts(
  DiscoveryJobsController jobs, {
  required AppLocalizations? Function() l10n,
  void Function(String message)? show,
}) => jobs.finished.listen((job) {
  if (job.plugin != kCopyPlugin) return;
  final l = l10n();
  if (l == null) return;
  final message = copyFinishedToast(l, job);
  if (message == null) return;
  (show ?? (m) => KeepToast.show(null, m))(message);
});
