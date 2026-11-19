// lib/screens/discovery/youtube_add_ui.dart — a YouTube add's words in the
// user's language: the running step, why one failed, why a start was
// refused. In English; the readings themselves are youtube_add_words_test's.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/screens/discovery/youtube_add_ui.dart';
import 'package:mstream_music/util/discovery_plugins_api.dart';
import 'package:mstream_music/util/youtube_add_words.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  DiscoveryJob running(String? statusText, {double? progress, String? error}) => DiscoveryJob(
        id: 1,
        plugin: kYoutubePlugin,
        state: error == null ? JobState.running : JobState.failed,
        statusText: statusText,
        progress: progress,
        error: error,
      );

  test('youtubeStepText: each step, the percentage while fetching, Starting… with no text', () {
    expect(youtubeStepText(l, running('reading the chosen upload', progress: 0.02)), 'Checking the upload');
    expect(youtubeStepText(l, running('searching YouTube for “Static Bloom Paper Satellites”', progress: 0.02)), 'Searching YouTube');
    expect(youtubeStepText(l, running('downloading “Paper Satellites” from Static Bloom - Topic', progress: 0.08)),
        'Fetching from YouTube');
    expect(youtubeStepText(l, running('42% of “Paper Satellites”', progress: 0.436)), 'Fetching from YouTube · 42%',
        reason: "the text's own percentage, not the bar's");
    expect(youtubeStepText(l, running('tagging', progress: 0.93)), 'Tagging');
    expect(youtubeStepText(l, running('adding to your library', progress: 0.97)), 'Putting it in your library');
    expect(youtubeStepText(l, running(null)), 'Starting…');
    expect(youtubeStepText(l, running('  ', progress: 0.5)), 'Starting…');
  });

  test("youtubeStepText: a line it does not know shows as the server wrote it, the bar's percentage added as the copy rows add it", () {
    expect(youtubeStepText(l, running('converting the audio')), 'converting the audio');
    expect(youtubeStepText(l, running('converting the audio', progress: 0.9)), 'converting the audio · 90%');
    expect(youtubeStepText(l, running('converting 90%', progress: 0.9)), 'converting 90%');
  });

  test('youtubeFailureText: one sentence per kind', () {
    String t(YoutubeFailure f) => youtubeFailureText(l, f);
    expect(t(const YoutubeFailure(YoutubeFailureKind.broken)), "YouTube isn't working on this server right now.");
    expect(t(const YoutubeFailure(YoutubeFailureKind.notClose, percent: 48)), 'Nothing on YouTube was close enough (best match 48%).');
    expect(t(const YoutubeFailure(YoutubeFailureKind.noResults, query: 'Static Bloom Paper Satellites')),
        'YouTube found nothing for “Static Bloom Paper Satellites”.');
    expect(t(const YoutubeFailure(YoutubeFailureKind.live)), 'That upload is a live stream — pick another.');
    expect(t(const YoutubeFailure(YoutubeFailureKind.tooBig, sizeMb: 100)), 'That upload is bigger than this server allows (100 MB).');
    expect(t(const YoutubeFailure(YoutubeFailureKind.tooBig)), 'That upload is bigger than this server allows.');
    expect(t(const YoutubeFailure(YoutubeFailureKind.unreadable)), "That upload couldn't be read — pick another.");
    expect(t(const YoutubeFailure(YoutubeFailureKind.tooLong)), 'It took longer than 30 minutes and was stopped.');
    expect(t(const YoutubeFailure(YoutubeFailureKind.refused)), "YouTube wouldn't hand it over — try again later.");
    expect(t(const YoutubeFailure(YoutubeFailureKind.noTitle)), 'This song has no artist or title to search for.');
    expect(t(const YoutubeFailure(YoutubeFailureKind.uploadsOff)), l.ytdlErrUploadsOff);
    expect(t(const YoutubeFailure(YoutubeFailureKind.noLibrary)), "There's no library you can add files to.");
    expect(t(const YoutubeFailure(YoutubeFailureKind.layout)), "Your folder layout can't place this song.");
    expect(t(const YoutubeFailure(YoutubeFailureKind.accountGone)), 'The account that asked for this no longer exists.');
    expect(t(const YoutubeFailure(YoutubeFailureKind.other)), 'Something went wrong.');
  });

  test("youtubeJobFailureText: a failed job's own error, read", () {
    expect(youtubeJobFailureText(l, running(null, error: 'Nothing matched closely enough (best score 0.48, needs 0.62)')),
        'Nothing on YouTube was close enough (best match 48%).');
    expect(youtubeJobFailureText(l, running(null, error: null)), 'Something went wrong.');
  });

  test("youtubeStartRefusalText: the start's refusals, per status", () {
    String t(DiscoveryPluginsException e) => youtubeStartRefusalText(l, e);
    expect(t(const DestinationChangedException('your collection destination has changed', named: true)), l.discoverKeepDestChanged);
    expect(t(const DiscoveryPluginsException(409, 'someone else on this server is already getting this — try again in a moment', fromServer: true)),
        'Someone else on this server is adding this right now — try again in a moment.');
    expect(t(const DiscoveryPluginsException(429, 'you have 20 jobs queued or running — wait for some to finish (the limit is 20)', fromServer: true)),
        'You have 20 waiting or running — let some finish first.');
    expect(t(const DiscoveryPluginsException(429, 'HTTP 429')), 'Too many waiting — let some finish first.');
    expect(t(const DiscoveryPluginsException(403, 'Uploading Disabled', fromServer: true)), 'Adding songs was just turned off for your account.');
    expect(t(const DiscoveryPluginsException(404, 'unknown discovery plug-in', fromServer: true)), 'That option was just switched off on this server.');
    expect(t(const DiscoveryPluginsException(400, 'the chosen upload must be a YouTube link', fromServer: true)), "Couldn't start this. Try again.");
    expect(t(const DiscoveryPluginsException(502, 'HTTP 502')), "Couldn't start this. Try again.");
    expect(t(const DiscoveryPluginsException(0, 'your server did not answer in time', timedOut: true)), l.discoverKeepStartFailed);
  });
}
