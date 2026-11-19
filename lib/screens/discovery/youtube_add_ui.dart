import '../../l10n/app_localizations.dart';
import '../../objects/discovery_plugins.dart';
import '../../util/discovery_plugins_api.dart';
import '../../util/youtube_add_words.dart';

/// A YouTube add's words in the user's language: a running add's step, why
/// one failed, and why the server would not start one — from the pure
/// readings in util/youtube_add_words.dart. What the network-song sheet's
/// job line, the Copies rows and the toasts show. The server's own words
/// pass through only where no reading knows them (a step a newer server
/// names).

/// A running YouTube add's line: its step ("Fetching from YouTube · 42%"),
/// [AppLocalizations.discoverJobStarting] while it names none, or — a step
/// this app does not know — the server's own text as the copy rows show
/// it (its percentage added when the text carries none).
String youtubeStepText(AppLocalizations l, DiscoveryJob job) {
  final text = (job.statusText ?? '').trim();
  if (text.isEmpty) return l.discoverJobStarting;
  final read = youtubeStepOf(text);
  final step = read.step;
  if (step == null) {
    final p = job.progress;
    final pct = p == null ? null : (p * 100).round();
    return pct == null || text.contains('%') ? text : '$text · $pct%';
  }
  return switch (step) {
    YoutubeStep.checking => l.discoverJobYtChecking,
    YoutubeStep.searching => l.discoverJobYtSearching,
    YoutubeStep.fetching => read.percent == null
        ? l.discoverJobYtFetching
        : l.discoverJobYtFetchingPercent(read.percent!),
    YoutubeStep.tagging => l.discoverJobYtTagging,
    YoutubeStep.filing => l.discoverJobYtFiling,
  };
}

/// Why a YouTube add failed, as one sentence (under "Couldn't add", and in
/// the failed toast).
String youtubeFailureText(AppLocalizations l, YoutubeFailure failure) =>
    switch (failure.kind) {
      YoutubeFailureKind.broken => l.discoverJobYtErrBroken,
      YoutubeFailureKind.notClose =>
        l.discoverJobYtErrNotClose(failure.percent ?? 0),
      YoutubeFailureKind.noResults =>
        l.discoverJobYtErrNoResults(failure.query ?? ''),
      YoutubeFailureKind.live => l.discoverJobYtErrLive,
      YoutubeFailureKind.tooBig => failure.sizeMb == null
          ? l.discoverJobYtErrTooBigNoSize
          : l.discoverJobYtErrTooBig(failure.sizeMb!),
      YoutubeFailureKind.unreadable => l.discoverJobYtErrUnreadable,
      YoutubeFailureKind.tooLong => l.discoverJobYtErrTooLong,
      YoutubeFailureKind.refused => l.discoverJobYtErrRefused,
      YoutubeFailureKind.noTitle => l.discoverJobYtErrNoTitle,
      YoutubeFailureKind.uploadsOff => l.ytdlErrUploadsOff,
      YoutubeFailureKind.noLibrary => l.discoverJobYtErrNoLibrary,
      YoutubeFailureKind.layout => l.discoverJobYtErrLayout,
      YoutubeFailureKind.accountGone => l.discoverJobYtErrAccountGone,
      YoutubeFailureKind.other => l.discoverJobYtErrOther,
    };

/// A failed YouTube [job]'s reason ([youtubeFailureOf] its `error`) as
/// [youtubeFailureText] words it.
String youtubeJobFailureText(AppLocalizations l, DiscoveryJob job) =>
    youtubeFailureText(l, youtubeFailureOf(job.error));

/// Why the jobs route would not start a YouTube add ([error], what
/// DiscoveryPluginsApi.startJob threw): where files land changed (409
/// `destination_changed`), another account is adding the song (409), the
/// account's queue is full (429, with its count when the words say it), the
/// account may no longer add files (403), the plug-in is gone (404), the
/// server gave no reason (400, 5xx), or it could not be reached (status 0).
/// A surface that removes the YouTube block on a 403 or 404 shows these as
/// its toast.
String youtubeStartRefusalText(
    AppLocalizations l, DiscoveryPluginsException error) {
  if (error is DestinationChangedException) return l.discoverKeepDestChanged;
  switch (error.status) {
    case 0:
      return l.discoverKeepStartFailed;
    case 403:
      return l.discoverLeadAddOff;
    case 404:
      return l.discoverLeadOptionOff;
    case 409:
      return l.discoverLeadYtSomeoneElse;
    case 429:
      final count = youtubeQueueCap(error.message);
      return count == null
          ? l.discoverLeadYtQueueFullNoCount
          : l.discoverLeadYtQueueFull(count);
    default:
      return l.discoverLeadYtStartFailed;
  }
}
