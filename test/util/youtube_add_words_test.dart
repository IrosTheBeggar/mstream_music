// lib/util/youtube_add_words.dart — a YouTube add's own words read into
// what the phone shows. The sentences are the server's, verbatim (mStream
// src/discovery-plugins/plugins/youtube.js run(), src/util/yt-dlp.js
// startDownload, src/discovery-plugins/destination.js), so a wording change
// on the server fails here first; the link table is youtube.js
// isYouTubeUrl's, case by case.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/youtube_add_words.dart';

void main() {
  group('youtubeStepOf: the status lines', () {
    test('each step the plug-in names, and the percentage while fetching', () {
      expect(youtubeStepOf('reading the chosen upload'), (step: YoutubeStep.checking, percent: null));
      expect(youtubeStepOf('searching YouTube for “Static Bloom Paper Satellites”'),
          (step: YoutubeStep.searching, percent: null));
      expect(youtubeStepOf('downloading “Paper Satellites (Official Audio)” from Static Bloom - Topic'),
          (step: YoutubeStep.fetching, percent: null));
      expect(youtubeStepOf('downloading “Paper Satellites” from YouTube'), (step: YoutubeStep.fetching, percent: null));
      expect(youtubeStepOf('42% of “Paper Satellites (Official Audio)”'), (step: YoutubeStep.fetching, percent: 42));
      expect(youtubeStepOf('0% of “x”'), (step: YoutubeStep.fetching, percent: 0));
      expect(youtubeStepOf('100% of “x”'), (step: YoutubeStep.fetching, percent: 100));
      expect(youtubeStepOf('tagging'), (step: YoutubeStep.tagging, percent: null));
      expect(youtubeStepOf('adding to your library'), (step: YoutubeStep.filing, percent: null));
    });

    test('a line it does not know names no step (the line shows it as sent), nor does none', () {
      for (final t in [null, '', '   ', 'converting', '1 of 3 songs · 7.4 MB', 'tagging the file', '42 % of “x”']) {
        expect(youtubeStepOf(t), (step: null, percent: null), reason: '$t');
      }
    });
  });

  group('youtubeFailureOf: the job errors', () {
    YoutubeFailure f(String e) => youtubeFailureOf(e);

    test("the server's own sentences, each to its kind", () {
      expect(f('yt-dlp is not installed on this server'), const YoutubeFailure(YoutubeFailureKind.broken));
      expect(f('ffmpeg is not available yet'), const YoutubeFailure(YoutubeFailureKind.broken));
      expect(f('the recommendation has no artist or title to search for'), const YoutubeFailure(YoutubeFailureKind.noTitle));
      expect(f('the account that asked for this download no longer exists'),
          const YoutubeFailure(YoutubeFailureKind.accountGone));
      expect(f('uploads are disabled for this account, and a download is an upload'),
          const YoutubeFailure(YoutubeFailureKind.uploadsOff));
      expect(f('no library to download into'), const YoutubeFailure(YoutubeFailureKind.noLibrary));
      expect(f("the account may no longer put files into library 'music', where this job was asked to land"),
          const YoutubeFailure(YoutubeFailureKind.noLibrary));
      expect(f("the destination's base folder no longer validates: a folder name can't be .."),
          const YoutubeFailure(YoutubeFailureKind.layout));
      expect(f("the destination's layout no longer validates: unknown variable {{TRACK}}"),
          const YoutubeFailure(YoutubeFailureKind.layout));
      expect(f('the layout rendered an unusable path: path segment is empty'), const YoutubeFailure(YoutubeFailureKind.layout));
      expect(f('the chosen upload is a live stream, not a song — pick another'), const YoutubeFailure(YoutubeFailureKind.live));
      expect(f('something this app has never seen'), const YoutubeFailure(YoutubeFailureKind.other));
      expect(youtubeFailureOf(null), const YoutubeFailure(YoutubeFailureKind.other));
      expect(youtubeFailureOf(''), const YoutubeFailure(YoutubeFailureKind.other));
    });

    test('the best score as a whole percentage; the query searched', () {
      expect(f('Nothing matched closely enough (best score 0.48, needs 0.62)'),
          const YoutubeFailure(YoutubeFailureKind.notClose, percent: 48));
      expect(f('Nothing matched closely enough (best score 0.00, needs 0.62)'),
          const YoutubeFailure(YoutubeFailureKind.notClose, percent: 0));
      expect(f('Nothing matched closely enough (best score 0.62, needs 0.62)'),
          const YoutubeFailure(YoutubeFailureKind.notClose, percent: 62));
      expect(f('YouTube returned no results for “Static Bloom Paper Satellites”'),
          const YoutubeFailure(YoutubeFailureKind.noResults, query: 'Static Bloom Paper Satellites'));
      expect(f('YouTube returned no results for “Sigur Rós “Hoppípolla””'),
          const YoutubeFailure(YoutubeFailureKind.noResults, query: 'Sigur Rós “Hoppípolla”'),
          reason: 'quotes inside the phrase stay in it');
    });

    test('"the chosen upload could not be read": a live stream by yt-dlp\'s words, else unreadable', () {
      expect(f('the chosen upload could not be read: ERROR: [youtube] abc: This live event will begin in 3 hours.'),
          const YoutubeFailure(YoutubeFailureKind.live));
      expect(f('the chosen upload could not be read: ERROR: [youtube] abc: Premieres in 2 days'),
          const YoutubeFailure(YoutubeFailureKind.live));
      expect(f('the chosen upload could not be read: ERROR: [youtube] abc: Video unavailable'),
          const YoutubeFailure(YoutubeFailureKind.unreadable));
      expect(f('the chosen upload could not be read: yt-dlp exited with code 1'),
          const YoutubeFailure(YoutubeFailureKind.unreadable));
    });

    test('"YouTube download failed": the size cap (with its MB when named), the clock, a live stream, an upload gone, a refusal', () {
      expect(f('YouTube download failed: the download passed the 100 MB size cap and was stopped'),
          const YoutubeFailure(YoutubeFailureKind.tooBig, sizeMb: 100));
      expect(f('YouTube download failed: the file is larger than the 250 MB size cap, so yt-dlp did not download it'),
          const YoutubeFailure(YoutubeFailureKind.tooBig, sizeMb: 250));
      expect(f('YouTube download failed: the file is larger than the size cap, so yt-dlp did not download it'),
          const YoutubeFailure(YoutubeFailureKind.tooBig));
      expect(f('YouTube download failed: the download took longer than 30 minutes and was stopped'),
          const YoutubeFailure(YoutubeFailureKind.tooLong));
      expect(f('YouTube download failed: it is a live stream, which is not downloaded'),
          const YoutubeFailure(YoutubeFailureKind.live));
      expect(f("YouTube download failed: ERROR: [youtube] abc: Private video. Sign in if you've been granted access to this video"),
          const YoutubeFailure(YoutubeFailureKind.unreadable));
      expect(f('YouTube download failed: ERROR: [youtube] abc: Video unavailable. This video has been removed by the uploader'),
          const YoutubeFailure(YoutubeFailureKind.unreadable));
      // YouTube's bot check and rate limiting are the server's problem, read
      // before "unavailable" though their words can say it.
      expect(f("YouTube download failed: ERROR: [youtube] abc: Sign in to confirm you're not a bot"),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f("YouTube download failed: Video unavailable. This content isn't available, try again later. The current session has been rate-limited by YouTube"),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f('YouTube download failed: yt-dlp exited with code 1'), const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f('YouTube download failed: yt-dlp finished but no output file was found'),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f('YouTube download failed: a file with that name already exists in this folder (x.mp3)'),
          const YoutubeFailure(YoutubeFailureKind.refused));
    });

    // As yt-dlp.js errorLineReason: a failed run's line gives a reason only
    // when an extractor said it ("[youtube] <id>: …") — any other line can
    // carry the staged file's name (--restrict-filenames keeps a title's
    // words), and a title would pass for one.
    test('"YouTube download failed": a reason only from an extractor\'s line, never from a file name', () {
      expect(f("YouTube download failed: unable to open for writing: [Errno 28] No space left on device: '/x/No_Copyright_Music.webm.part'"),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f("YouTube download failed: unable to write data: [Errno 28] No space left on device: '/srv/staging/42/No_Copyright_Music_-_Lofi_Beat.webm.part'"),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f("YouTube download failed: ERROR: unable to rename file: [Errno 2] No such file or directory: '/x/Members-only_Session.webm.part'"),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f("YouTube download failed: Postprocessing: Conversion failed! '/x/Account_Terminated_-_Remix.webm'"),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f('YouTube download failed: a file with that name already exists in this folder (Members-only_Session.mp3)'),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f('YouTube download failed: [youtube] abc123: Video unavailable. This video has been removed'),
          const YoutubeFailure(YoutubeFailureKind.unreadable));
      expect(f('YouTube download failed: [youtube] dQw4w9WgXcQ: Video unavailable'),
          const YoutubeFailure(YoutubeFailureKind.unreadable));
      expect(f('YouTube download failed: [youtube] abc: This live event will begin in 3 hours.'),
          const YoutubeFailure(YoutubeFailureKind.live));
      expect(f('YouTube download failed: [youtube] abc: File is larger than max-filesize (1.2GiB > 500.0MiB)'),
          const YoutubeFailure(YoutubeFailureKind.tooBig));
    });

    test("yt-dlp's words inside a wrapper never pass for one of the server's own reasons", () {
      expect(f('YouTube download failed: ERROR: unable to open “uploads are disabled (Official Video).webm”'),
          const YoutubeFailure(YoutubeFailureKind.refused));
      expect(f('the chosen upload could not be read: ERROR: [youtube] abc: “Nothing matched closely enough (best score 0.9”'),
          const YoutubeFailure(YoutubeFailureKind.unreadable));
    });

    test('Choose another and Retry, per kind', () {
      final offers = {
        for (final k in YoutubeFailureKind.values)
          k: (YoutubeFailure(k).choosesAnother, YoutubeFailure(k).retries),
      };
      expect(offers, {
        YoutubeFailureKind.broken: (false, true),
        YoutubeFailureKind.notClose: (true, true),
        YoutubeFailureKind.noResults: (true, true),
        YoutubeFailureKind.live: (true, false),
        YoutubeFailureKind.tooBig: (true, false),
        YoutubeFailureKind.unreadable: (true, true),
        YoutubeFailureKind.tooLong: (false, true),
        YoutubeFailureKind.refused: (false, true),
        YoutubeFailureKind.noTitle: (false, false),
        YoutubeFailureKind.uploadsOff: (false, false),
        YoutubeFailureKind.noLibrary: (false, false),
        YoutubeFailureKind.layout: (false, true),
        YoutubeFailureKind.accountGone: (false, false),
        YoutubeFailureKind.other: (false, true),
      });
    });
  });

  test("youtubeQueueCap: the jobs route's 429 count, or null", () {
    expect(youtubeQueueCap('you have 20 jobs queued or running — wait for some to finish (the limit is 20)'), 20);
    expect(youtubeQueueCap('You have 3 jobs queued or running — wait for some to finish (the limit is 3)'), 3);
    expect(youtubeQueueCap('HTTP 429'), isNull);
    expect(youtubeQueueCap('plug-in youtube is rate-limited right now — try again shortly'), isNull);
  });

  group('isYouTubeUrl: youtube.js isYouTubeUrl, case by case', () {
    test('a watch page, a short, a live page, a youtu.be link — on YouTube\'s own hosts, over http(s)', () {
      for (final url in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=42',
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RDAMVM',
        'http://www.youtube.com/watch?v=a_b-C',
        'https://WWW.YouTube.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/shorts/abc123',
        'https://www.youtube.com/live/abc123',
        'https://youtu.be/dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ?t=10',
      ]) {
        expect(isYouTubeUrl(url), isTrue, reason: url);
      }
    });

    test('anything else is refused', () {
      for (final url in [
        '',
        'not a link',
        'ftp://www.youtube.com/watch?v=abc',
        'javascript:alert(1)',
        'https://www.youtube.com/',
        'https://www.youtube.com/watch',
        'https://www.youtube.com/watch?v=',
        'https://www.youtube.com/watch?v=has%20space',
        'https://www.youtube.com/watch?x=abc',
        'https://www.youtube.com/embed/abc',
        'https://www.youtube.com/shorts/',
        'https://www.youtube.com/shorts/abc/more',
        'https://www.youtube.com/channel/UC123',
        'https://youtu.be/',
        'https://youtu.be/abc/def',
        'https://gaming.youtube.com/watch?v=abc',
        'https://youtube.com.evil.example/watch?v=abc',
        'https://notyoutube.com/watch?v=abc',
        'https://www.youtube-nocookie.com/embed/abc',
        'https://vimeo.com/123',
      ]) {
        expect(isYouTubeUrl(url), isFalse, reason: url);
      }
    });
  });

  test('youtubeSearchPhrase: "Artist Title", each part trimmed, empty when neither is known', () {
    expect(youtubeSearchPhrase({'artist': 'Static Bloom', 'title': 'Paper Satellites', 'album': 'x'}), 'Static Bloom Paper Satellites');
    expect(youtubeSearchPhrase({'artist': '  Static Bloom ', 'title': ' Paper Satellites  '}), 'Static Bloom Paper Satellites');
    expect(youtubeSearchPhrase({'title': 'Paper Satellites'}), 'Paper Satellites');
    expect(youtubeSearchPhrase({'artist': '   ', 'title': 'Paper Satellites'}), 'Paper Satellites');
    expect(youtubeSearchPhrase({'artist': 42, 'title': null}), '');
    expect(youtubeSearchPhrase({}), '');
  });
}
