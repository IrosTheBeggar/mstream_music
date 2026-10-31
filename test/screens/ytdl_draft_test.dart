// YtdlDraft, the result card's state machine, against the scripted server
// in ytdl_fakes: the link parsed and looked up (400 ms after typing, at once
// on a paste; never for a playlist or another site; answers to older asks
// dropped; slow after 8 s; failed, timed out, offline and yt-dlp missing),
// manual entry and the late answer that fills only untouched fields; the
// tags as tiers fill them, where each came from, the restore chips, the
// artist strip, Undo all and Swap, the year rule and what is sent; the
// destination (remembered, first use, just this song, Save), the explorer
// sheet's folder and subfolders; the new-folder check (600 ms, walking up,
// a file in the way, the name clash by tier, noMkdir's three choices); the
// format; and Add — every reason it is disabled, the reset after a 200, and
// a failure shown inline or left to a row.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/widgets.dart' show AppLifecycleState, TextEditingController;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/objects/ytdl_job.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/util/ytdl_errors.dart';
import 'package:mstream_music/util/ytdl_guess.dart';
import 'package:mstream_music/util/ytdl_layout.dart';
import 'package:mstream_music/util/ytdl_link.dart';

import '../singletons/ytdl_fakes.dart';

const target = '/Music/Daft Punk/Discovery/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late YtdlHarness h;
  late Server s;
  YtdlServerState st() => h.hub.stateFor(s);
  YtdlDraft draft() => st().screenDraft;

  setUp(() {
    h = YtdlHarness()..wire();
    s = ytdlServer(formats: const ['mp3', 'm4a', 'opus', 'flac']);
  });
  tearDown(() => h.unwire());

  void type(YtdlDraft d, String text) {
    d.link.text = text;
    d.linkChanged();
  }

  /// [url] typed and looked up.
  Future<YtdlDraft> found([String url = kOneMoreTime, YtdlDraft? on]) async {
    final d = on ?? draft();
    type(d, url);
    await h.timers.elapse(YtdlDraft.kLookupDebounce);
    return d;
  }

  /// … and its path checked.
  Future<YtdlDraft> ready([String url = kOneMoreTime, YtdlDraft? on]) async {
    final d = await found(url, on);
    await h.timers.elapse(YtdlDraft.kCheckAfter);
    return d;
  }

  int lookups() => h.fake.count('GET', '/ytdl/metadata');
  List<String> listed() => [
        for (final b in h.fake.bodies('POST', '/api/v1/file-explorer')) b['directory'] as String
      ];

  group('link and lookup (spec §3, §8)', () {
    test('a typed link looks up 400 ms after typing stops', () async {
      final d = draft();
      type(d, 'https://www.youtube.com/watch?v=FGBhQb');
      expect(d.parsed.kind, YtdlLinkKind.video);
      expect(d.lookup, YtdlLookupState.idle);
      expect(d.block, YtdlBlock.lookingUp);
      await h.timers.elapse(const Duration(milliseconds: 300));
      type(d, kOneMoreTime);
      await h.timers.elapse(const Duration(milliseconds: 300));
      expect(lookups(), 0);
      await h.timers.elapse(const Duration(milliseconds: 100));
      expect(lookups(), 1);
      expect(h.fake.calls('GET', '/ytdl/metadata').single.url.queryParameters['url'], kOneMoreTime);
      expect(d.lookup, YtdlLookupState.found);
      expect(d.meta?.title, 'One More Time');
    });

    test('a short link is rewritten and looked up as the watch link', () async {
      final d = await found('youtu.be/FGBhQbmPwH8');
      expect(d.parsed.shortForm, isTrue);
      expect(d.parsed.shown, 'youtube.com/watch?v=FGBhQbmPwH8');
      expect(h.fake.calls('GET', '/ytdl/metadata').single.url.queryParameters['url'], kOneMoreTime);
    });

    test('Paste from clipboard fills the field and looks up at once', () async {
      final d = draft();
      expect(await d.clipboardHasText(), isFalse);
      h.clipboard = 'listen: https://youtu.be/HyHNuVaZJ-k !';
      expect(await d.clipboardHasText(), isTrue);
      await d.pasteFromClipboard();
      await ytdlSettle();
      expect(d.link.text, h.clipboard);
      expect(lookups(), 1);
      expect(d.meta?.title, startsWith('Gorillaz'));
      expect(h.timers.hasActive(YtdlDraft.kLookupDebounce), isFalse);
    });

    test('pasting the link already in the field asks nothing more', () async {
      final d = await found();
      h.clipboard = kOneMoreTime;
      await d.pasteFromClipboard();
      await ytdlSettle();
      expect(lookups(), 1);
    });

    test('playlists and other sites never look up', () async {
      final d = draft();
      type(d, 'https://www.youtube.com/playlist?list=PL0123');
      expect(d.parsed.kind, YtdlLinkKind.playlist);
      expect(d.block, YtdlBlock.noLink);
      type(d, 'https://vimeo.com/12345');
      expect(d.parsed.kind, YtdlLinkKind.notYoutube);
      await h.timers.elapse(const Duration(seconds: 2));
      expect(lookups(), 0);
      expect(d.lookup, YtdlLookupState.idle);
    });

    test('a /live/ link looks up like any video', () async {
      final d = await found('https://www.youtube.com/live/FGBhQbmPwH8');
      expect(d.parsed.live, isTrue);
      expect(lookups(), 1);
      expect(d.lookup, YtdlLookupState.found);
    });

    test('an answer to an older ask is dropped', () async {
      h.fake.holdLookups = true;
      final d = draft();
      type(d, kFeelGood);
      await h.timers.elapse(YtdlDraft.kLookupDebounce);
      type(d, kOneMoreTime);
      await h.timers.elapse(YtdlDraft.kLookupDebounce);
      expect(h.fake.heldLookups, hasLength(2));
      h.fake.heldLookups[1].complete();
      await ytdlSettle();
      h.fake.heldLookups[0].complete();
      await ytdlSettle();
      expect(d.meta?.title, 'One More Time');
      expect(d.guess.tier, YtdlTier.music);
      expect(d.controllerFor(YtdlField.title).text, 'One More Time');
    });

    test('Try again drops the answer still out', () async {
      h.fake.holdLookups = true;
      final d = await found(kFeelGood);
      d.retryLookup();
      await ytdlSettle();
      h.fake.videos[kFeelGood] = {...kFeelGoodVideo, 'title': 'Gorillaz - Feel Good Inc.'};
      h.fake.heldLookups[1].complete();
      await ytdlSettle();
      h.fake.videos[kFeelGood] = {...kFeelGoodVideo, 'title': 'stale'};
      h.fake.heldLookups[0].complete();
      await ytdlSettle();
      expect(d.meta?.title, 'Gorillaz - Feel Good Inc.');
    });

    test('slow after 8 s; Enter details yourself opens the tags and unlocks Add', () async {
      h.fake.holdLookups = true;
      final d = await found();
      expect(d.lookup, YtdlLookupState.loading);
      await h.timers.elapse(const Duration(seconds: 7));
      expect(d.lookup, YtdlLookupState.loading);
      await h.timers.elapse(const Duration(seconds: 1));
      expect(d.lookup, YtdlLookupState.slow);
      expect(d.block, YtdlBlock.lookingUp);
      d.enterManually();
      expect(d.manual, isTrue);
      expect(d.tagsOpen, isTrue);
      expect(d.takeFocusRequest(), YtdlField.title);
      expect(d.takeFocusRequest(), isNull);
      expect(d.block, YtdlBlock.none);
    });

    test('failed (500): Add stays on, into the library\'s top folder', () async {
      h.fake.lookupRefusal = (500, 'Server Error');
      final d = await ready();
      expect(d.lookup, YtdlLookupState.failed);
      expect(d.lookupFailure, const YtdlFailure(YtdlProblem.lookupFailed));
      expect(d.lookupBlank, isTrue);
      expect(d.target.directory, '/Music/');
      expect(d.predictedName, '');
      expect(d.block, YtdlBlock.none);
    });

    test('timed out', () async {
      h.fake.lookupThrows = TimeoutException('slow');
      final d = await found();
      expect(d.lookup, YtdlLookupState.timedOut);
      expect(d.block, YtdlBlock.none);
    });

    test('offline: Add waits, and the lookup runs again when the app is back', () async {
      h.fake.lookupThrows = const SocketException('Network is unreachable');
      final d = await found();
      expect(d.lookup, YtdlLookupState.offline);
      expect(d.block, YtdlBlock.offline);
      h.fake.lookupThrows = null;
      h.hub.didChangeAppLifecycleState(AppLifecycleState.paused);
      h.hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await ytdlSettle();
      expect(lookups(), 2);
      expect(d.lookup, YtdlLookupState.found);
    });

    test('… and when its screen shows again', () async {
      h.fake.lookupThrows = const SocketException('Network is unreachable');
      final d = await found();
      h.fake.lookupThrows = null;
      d.attach();
      await ytdlSettle();
      expect(d.lookup, YtdlLookupState.found);
    });

    test('yt-dlp missing is remembered for the session; Try again asks again', () async {
      h.fake.lookupRefusal = (500, 'yt-dlp is not installed');
      final d = await found();
      expect(d.lookup, YtdlLookupState.ytdlpMissing);
      expect(d.block, YtdlBlock.ytdlpMissing);
      expect(st().ytdlpMissing, isTrue);
      final sheet = st().folderDraft('/Music/');
      type(sheet, kFeelGood);
      await h.timers.elapse(YtdlDraft.kLookupDebounce);
      expect(sheet.lookup, YtdlLookupState.ytdlpMissing);
      expect(lookups(), 1, reason: 'shown at once, not asked');
      h.fake.lookupRefusal = null;
      d.retryLookup();
      await ytdlSettle();
      expect(d.lookup, YtdlLookupState.found);
      expect(st().ytdlpMissing, isFalse);
    });

    test('Clear link discards the whole draft', () async {
      final d = await ready();
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: '', kind: 'top'));
      controller(d, YtdlField.album).text = 'Edited';
      d.clear();
      expect(d.link.text, '');
      expect(d.lookup, YtdlLookupState.idle);
      expect(d.meta, isNull);
      expect(d.guess, YtdlGuess.none);
      expect(d.justThisSong, isNull);
      expect(d.edited(YtdlField.album), isFalse);
      expect(controller(d, YtdlField.title).text, '');
      expect(d.check, YtdlCheckState.idle);
      expect(d.block, YtdlBlock.noLink);
    });

    test('the screen\'s draft and each folder\'s are kept for the session', () async {
      final d = await found();
      expect(identical(st().screenDraft, d), isTrue);
      expect(identical(st().folderDraft('/Music/A/'), st().folderDraft('/Music/A/')), isTrue);
      expect(identical(st().folderDraft('/Music/A/'), st().folderDraft('/Music/B/')), isFalse);
      d.attach();
      expect(d.attached, isTrue);
      d.detach();
      expect(d.attached, isFalse);
      expect(d.meta?.title, 'One More Time', reason: 'leaving loses nothing');
    });
  });

  group('tags (spec §3 Result card)', () {
    test('music tier: as given, from YouTube Music', () async {
      final d = await found();
      expect(d.guess.tier, YtdlTier.music);
      expect([for (final f in YtdlField.values) controller(d, f).text],
          ['One More Time', 'Daft Punk', 'Discovery', '2001']);
      expect([for (final f in YtdlField.values) d.sourceOf(f)], everyElement(YtdlFieldSource.music));
      expect(d.tagsOpen, isFalse);
      expect(d.displayTitle, 'One More Time');
      expect(d.metadataToSend,
          {'title': 'One More Time', 'artist': 'Daft Punk', 'album': 'Discovery', 'year': '2001'});
      expect(d.tags.artist, 'Daft Punk');
    });

    test('split tier: cleaned and split; restore chips, the split, Undo all', () async {
      final d = await found(kFeelGood);
      expect(d.guess.tier, YtdlTier.split);
      expect(controller(d, YtdlField.title).text, 'Feel Good Inc.');
      expect(controller(d, YtdlField.artist).text, 'Gorillaz');
      expect(d.sourceOf(YtdlField.title), YtdlFieldSource.videoTitleCleaned);
      expect(d.sourceOf(YtdlField.artist), YtdlFieldSource.videoTitle);
      expect(d.sourceOf(YtdlField.album), YtdlFieldSource.blank);
      expect(d.canUndoAll, isTrue);
      expect(d.canSwap, isTrue);
      expect(d.tagsOpen, isFalse);

      d.restore(1);
      expect(controller(d, YtdlField.title).text, 'Feel Good Inc. (Official Video)');
      expect(d.restored, {1});
      expect(d.sourceOf(YtdlField.title), YtdlFieldSource.videoTitleCleaned);
      d.restore(2);
      expect(d.sourceOf(YtdlField.title), YtdlFieldSource.videoTitle);
      d.restore(0);
      expect(controller(d, YtdlField.title).text, 'Gorillaz - Feel Good Inc. (Official Video) [HD]');
      expect(controller(d, YtdlField.artist).text, 'Gorillaz');
      expect(d.sourceOf(YtdlField.artist), YtdlFieldSource.youtubeArtist);
      expect(d.canSwap, isFalse);
      expect(d.canUndoAll, isFalse);
    });

    test('Undo all puts every piece back at once', () async {
      final d = await found(kFeelGood);
      d.undoAll();
      expect(controller(d, YtdlField.title).text, 'Gorillaz - Feel Good Inc. (Official Video) [HD]');
      expect(d.restored, {0, 1, 2});
    });

    test('Swap exchanges artist and title', () async {
      final d = await found(kFeelGood);
      d.swap();
      expect(controller(d, YtdlField.title).text, 'Gorillaz');
      expect(controller(d, YtdlField.artist).text, 'Feel Good Inc.');
      expect(d.sourceOf(YtdlField.title), YtdlFieldSource.videoTitle);
      expect(d.edited(YtdlField.title), isFalse);
      d.swap();
      expect(controller(d, YtdlField.title).text, 'Feel Good Inc.');
    });

    test('YouTube-artist tier: the tags open themselves; ↶ VEVO', () async {
      final d = await found(kSweater);
      expect(d.guess.tier, YtdlTier.youtubeArtist);
      expect(d.tagsOpen, isTrue);
      expect(controller(d, YtdlField.artist).text, 'TheNeighbourhood');
      expect(d.sourceOf(YtdlField.artist), YtdlFieldSource.youtubeArtist);
      expect(d.canRestoreArtistStrip, isTrue);
      d.restoreArtistStrip();
      expect(controller(d, YtdlField.artist).text, 'TheNeighbourhoodVEVO');
      expect(d.artistStripRestored, isTrue);
      expect(d.canRestoreArtistStrip, isFalse);
      expect(d.canSwap, isFalse);
    });

    test('a typed field is Edited; a restore that changes it takes it back', () async {
      final d = await found(kFeelGood);
      controller(d, YtdlField.artist).text = 'Gorillaz feat. De La Soul';
      controller(d, YtdlField.title).text = 'Feel Good';
      expect(d.edited(YtdlField.artist), isTrue);
      expect(d.sourceOf(YtdlField.artist), YtdlFieldSource.edited);
      d.restore(1);
      expect(controller(d, YtdlField.title).text, 'Feel Good Inc. (Official Video)');
      expect(d.edited(YtdlField.title), isFalse);
      expect(controller(d, YtdlField.artist).text, 'Gorillaz feat. De La Soul',
          reason: 'the artist did not move');
      expect(d.edited(YtdlField.artist), isTrue);
    });

    test('an emptied field is blank, and its value is not sent', () async {
      final d = await found();
      controller(d, YtdlField.album).text = '';
      controller(d, YtdlField.title).text = '   ';
      expect(d.sourceOf(YtdlField.title), YtdlFieldSource.edited);
      expect(d.metadataToSend.containsKey('album'), isFalse);
      expect(d.metadataToSend.containsKey('title'), isFalse);
      expect(d.displayTitle, 'One More Time', reason: 'the video\'s own title');
    });

    test('the year: four digits, sent as text, else refused', () async {
      final d = await ready();
      controller(d, YtdlField.year).text = '01';
      expect(d.yearInvalid, isTrue);
      expect(d.metadataToSend.containsKey('year'), isFalse);
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.block, YtdlBlock.yearInvalid);
      controller(d, YtdlField.year).text = ' 2001 ';
      expect(d.yearInvalid, isFalse);
      expect(d.metadataToSend['year'], '2001');
      controller(d, YtdlField.year).text = '';
      expect(d.yearInvalid, isFalse);
    });

    test('a late answer fills only what nobody edited ("Use them")', () async {
      h.fake.holdLookups = true;
      final d = await found();
      d.enterManually();
      controller(d, YtdlField.title).text = 'One more time';
      controller(d, YtdlField.artist).text = 'Daft Punk';
      h.fake.heldLookups.single.complete();
      await ytdlSettle();
      expect(d.lookup, YtdlLookupState.found);
      expect(d.lateAnswer, isTrue);
      expect(controller(d, YtdlField.album).text, '');
      expect(controller(d, YtdlField.title).text, 'One more time');
      d.useLateAnswer();
      expect(d.lateAnswer, isFalse);
      expect(controller(d, YtdlField.title).text, 'One more time');
      expect(controller(d, YtdlField.album).text, 'Discovery');
      expect(controller(d, YtdlField.year).text, '2001');
      expect(d.sourceOf(YtdlField.album), YtdlFieldSource.music);
      expect(d.sourceOf(YtdlField.title), YtdlFieldSource.edited);
    });

    test('a lookup that fails after manual entry keeps what was typed', () async {
      h.fake
        ..holdLookups = true
        ..lookupRefusal = (500, 'Server Error');
      final d = await found();
      d.enterManually();
      controller(d, YtdlField.title).text = 'My title';
      h.fake.heldLookups.single.complete();
      await ytdlSettle();
      expect(d.lookup, YtdlLookupState.failed);
      expect(d.manual, isTrue);
      expect(controller(d, YtdlField.title).text, 'My title');
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.block, YtdlBlock.none);
      expect(d.metadataToSend, {'title': 'My title'});
    });
  });

  group('destination (spec §4)', () {
    test('first use: Artist / Album in the first library', () async {
      final d = await found();
      expect(d.choice, const YtdlChoice(library: 'Music', layout: kYtdlLayoutArtistAlbum, kind: 'artistAlbum'));
      expect(d.target.directory, target);
      expect(d.target.crumbs, ['Music', 'Daft Punk', 'Discovery']);
      expect(d.lookupBlank, isFalse);
    });

    test('first use follows Discover\'s library when it is the user\'s own', () async {
      s = ytdlServer(libraries: const ['Music', 'Podcasts'])..discoveryPluginsAvailable = true;
      h.fake.discoverAt('Podcasts');
      await st().loadPresets();
      final d = await found();
      expect(d.target.directory, '/Podcasts/Daft Punk/Discovery/');
    });

    test('"Same as Discover" lands under Discover\'s base folders', () async {
      s.discoveryPluginsAvailable = true;
      h.fake.discoverAt('Music', base: 'From Discover', layout: '{{ARTIST}}');
      await st().loadPresets();
      final d = await found();
      await d.saveChoice(const YtdlChoice(
          library: 'Music', layout: '{{ARTIST}}', kind: 'discover', base: 'From Discover'));
      expect(d.target.directory, '/Music/From Discover/Daft Punk/');
      expect(d.choice.kind, 'discover');
    });

    test('Use for this song, Undo; the remembered choice comes back after a send', () async {
      final d = await ready();
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: kYtdlLayoutTop, kind: 'top'));
      expect(d.justThisSong?.kind, 'top');
      expect(d.target.directory, '/Music/');
      d.undoJustThisSong();
      expect(d.target.directory, target);
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: kYtdlLayoutTop, kind: 'top'));
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(await d.add(), isTrue);
      expect(d.justThisSong, isNull);
      expect(d.choice.kind, 'artistAlbum');
      expect(st().jobs.single.directory, '/Music/');
    });

    test('Save remembers for the server and says where new songs land', () async {
      final d = await found();
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: kYtdlLayoutTop, kind: 'top'));
      await d.saveChoice(const YtdlChoice(library: 'Music', layout: kYtdlLayoutArtist, kind: 'artist'));
      expect(d.justThisSong, isNull);
      expect([s.ytdlLibrary, s.ytdlLayout, s.ytdlLayoutKind], ['Music', kYtdlLayoutArtist, 'artist']);
      expect(d.target.directory, '/Music/Daft Punk/');
      expect(h.toasts.single.message, 'Saved · new songs land in \u2068Music\u2069 › \u2068Artist\u2069');
      expect(h.toasts.single.success, isTrue);
    });

    test('sample paths read the layout with the field names', () {
      expect(ytdlSamplePath(h.l, const YtdlChoice(library: 'Music', layout: kYtdlLayoutArtistAlbum, kind: 'artistAlbum')),
          '\u2068Music\u2069 › \u2068Artist\u2069 › \u2068Album\u2069');
      expect(ytdlSamplePath(h.l, const YtdlChoice(library: 'Music', layout: '', kind: 'top')), '\u2068Music\u2069');
      expect(
          ytdlSamplePath(h.l,
              const YtdlChoice(library: 'Music', layout: '{{ALBUM}} ({{YEAR}})', kind: 'discover', base: 'From Discover')),
          '\u2068Music\u2069 › \u2068From Discover\u2069 › \u2068Album (Year)\u2069');
    });

    test('a layout the allow-list refuses: Add is off', () async {
      final d = await ready();
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: 'Singles: {{ARTIST}}', kind: 'custom'));
      expect(d.target.valid, isFalse);
      expect(d.block, YtdlBlock.invalidLayout);
    });
  });

  group('the explorer sheet (spec §7)', () {
    test('Right here is the folder on screen; subfolders go under it, never remembered', () async {
      final d = st().folderDraft('/Music/Daft Punk/');
      expect(d.isFolderSheet, isTrue);
      await found(kOneMoreTime, d);
      expect(d.subLayout, kYtdlLayoutTop);
      expect(d.target.directory, '/Music/Daft Punk/');
      d.setSubLayout(kYtdlLayoutAlbum);
      expect(d.target.directory, target);
      expect(s.ytdlLayout, isNull);
      expect(st().screenDraft.choice.layout, kYtdlLayoutArtistAlbum);
    });

    test('showing it asks the version tier', () async {
      st().folderDraft('/Music/').attach();
      await ytdlSettle();
      expect(st().tier, YtdlServerTier.full);
    });

    test('Add here sends the folder unchanged and makes nothing, even unchecked', () async {
      h.fake.folder('/Music/Daft Punk/');
      h.fake.listFails.add('/Music/Daft Punk/');
      final d = st().folderDraft('/Music/Daft Punk/');
      await ready(kOneMoreTime, d);
      expect(d.check, YtdlCheckState.unknown, reason: 'listed by its parent, but not itself');
      expect(await d.add(), isTrue);
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 0);
      expect(h.fake.bodies('POST', '/api/v1/ytdl/').single['directory'], '/Music/Daft Punk/');
      expect(d.subLayout, kYtdlLayoutTop);
    });

    test('an older server, the file already in the rows on screen: Add here '
        'stays blocked when the folder won\'t list again (spec §7 name check, '
        '§10)', () async {
      const here = '/Music/Daft Punk/';
      h.fake.hasRecords = false;
      h.fake.file(here, 'One_More_Time.mp3');
      final shownFor = <String>[];
      h.hub.explorerFiles = (server, dir) {
        shownFor.add(dir);
        return identical(server, s) && dir == here
            ? const ['Da Funk.mp3', 'One_More_Time.mp3']
            : null;
      };
      final d = st().folderDraft(here)..attach();
      await ytdlSettle();
      expect(st().tier, YtdlServerTier.older);
      // Listing: the clash blocks.
      await ready(kOneMoreTime, d);
      expect(d.block, YtdlBlock.clashOlder);
      expect(shownFor, isEmpty, reason: 'a listing that answers wins');
      d.clear();
      // The listing fails (a flaky tunnel): the rows already loaded say it.
      h.fake.listFails.add(here);
      await ready(kOneMoreTime, d);
      expect(shownFor, contains(here));
      expect(d.check, YtdlCheckState.known);
      expect(d.clash, isTrue);
      expect(d.block, YtdlBlock.clashOlder);
      expect(await d.add(), isFalse);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0);
    });

    test('… and with no rows on screen for it, the check stays unknown', () async {
      const here = '/Music/Daft Punk/';
      h.fake.hasRecords = false;
      h.fake.file(here, 'One_More_Time.mp3');
      h.fake.listFails.add(here);
      h.hub.explorerFiles = (server, dir) => null;
      final d = st().folderDraft(here)..attach();
      await ytdlSettle();
      await ready(kOneMoreTime, d);
      expect(d.check, YtdlCheckState.unknown);
      expect(d.clash, isFalse);
    });

    test('subfolders that are new are made first', () async {
      h.fake.folder('/Music/Daft Punk/');
      final d = st().folderDraft('/Music/Daft Punk/');
      await found(kOneMoreTime, d);
      d.setSubLayout(kYtdlLayoutAlbum);
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.newSegments, {1});
      await d.add();
      expect(h.fake.bodies('POST', '/file-explorer/mkdir').single['directory'], target);
    });
  });

  group('the new-folder check (BUILD NOTES)', () {
    test('600 ms after the path settles; walks up to the folder that lists', () async {
      final d = await found();
      expect(d.check, YtdlCheckState.checking);
      await h.timers.elapse(const Duration(milliseconds: 500));
      expect(listed(), isEmpty);
      await h.timers.elapse(const Duration(milliseconds: 100));
      expect(listed(), [target, '/Music/Daft Punk/', '/Music/']);
      expect(d.check, YtdlCheckState.known);
      expect(d.newSegments, {0, 1});
      expect(d.deepestExisting, '/Music/');
      expect(d.checkUnknown, isFalse);
      expect(d.clash, isFalse);
    });

    test('a folder that is there: no new tags; its listing feeds the name check', () async {
      h.fake.folder(target, files: ['One_More_Time.mp3']);
      final d = await ready();
      expect(listed(), [target]);
      expect(d.newSegments, isEmpty);
      expect(d.deepestExisting, target);
      expect(d.predictedName, 'One_More_Time.mp3');
      expect(d.clash, isTrue);
    });

    test('a parent there with some folders below it new', () async {
      h.fake.folder('/Music/daft punk/');
      final d = await ready();
      // On-disk case differs: the folder is there, so nothing is new — but it
      // would not list under this case, so it cannot be checked.
      expect(d.check, YtdlCheckState.unknown);
      h.fake.tree.remove('/music/daft punk/');
      h.fake.tree.remove('/Music/daft punk/');
      h.fake.folder('/Music/Daft Punk/');
      controller(d, YtdlField.album).text = 'Homework';
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.check, YtdlCheckState.known);
      expect(d.newSegments, {1});
      expect(d.deepestExisting, '/Music/Daft Punk/');
    });

    test('a new path checks again; an answer for the old one is dropped', () async {
      final d = await found();
      await h.timers.elapse(const Duration(milliseconds: 300));
      controller(d, YtdlField.album).text = 'Homework';
      await h.timers.elapse(const Duration(milliseconds: 300));
      expect(listed(), isEmpty);
      await h.timers.elapse(const Duration(milliseconds: 300));
      expect(listed().first, '/Music/Daft Punk/Homework/');
    });

    test('a file in the way, or nothing that lists: unknown', () async {
      h.fake.file('/Music/', 'Daft Punk');
      final d = await ready();
      expect(d.check, YtdlCheckState.unknown);
      expect(d.checkUnknown, isTrue);
      expect(d.newSegments, isEmpty);

      h.fake.listFails.addAll(['/Music/', '/Music/Gorillaz/', '/Music/Gorillaz/Demon Days/']);
      controller(d, YtdlField.artist).text = 'Gorillaz';
      controller(d, YtdlField.album).text = 'Demon Days';
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.check, YtdlCheckState.unknown);
      expect(d.deepestExisting, isNull);
    });

    test('6.26–6.28.0 list a missing folder as 500: the walk is the same', () async {
      h.fake.missingIs500 = true;
      final d = await ready();
      expect(d.newSegments, {0, 1});
    });

    test('a clash blocks on older servers (and until the probe answers); 6.30+ says Add anyway', () async {
      h.fake.folder(target, files: ['one_more_time.MP3']);
      final d = await ready();
      expect(st().tier, YtdlServerTier.unknown);
      expect(d.clashBlocks, isTrue);
      expect(d.addAnyway, isFalse);
      expect(d.block, YtdlBlock.clashOlder);
      await st().probeTier();
      expect(d.clashBlocks, isFalse);
      expect(d.addAnyway, isTrue);
      expect(d.block, YtdlBlock.none);
    });

    test('another format makes another file: no clash', () async {
      h.fake.folder(target, files: ['One_More_Time.mp3']);
      final d = await ready();
      await d.setFormat('opus');
      expect(d.predictedName, 'One_More_Time.opus');
      expect(d.clash, isFalse);
      expect(listed(), [target], reason: 'the listing is kept');
    });

    test('noMkdir and a new folder: the three choices, never a post into it', () async {
      s.noMkdir = true;
      h.fake.folder('/Music/Daft Punk/');
      final d = await ready();
      expect(d.newSegments, {1});
      expect(d.mkdirBlocked, isTrue);
      expect(d.block, YtdlBlock.mkdirBlocked);
      expect(await d.add(), isFalse);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0);

      d.saveToDeepestInstead();
      expect(d.justThisSong, YtdlChoice.folder('/Music/Daft Punk/'));
      expect(d.target.directory, '/Music/Daft Punk/');
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.block, YtdlBlock.none);

      d.useTopOfLibrary();
      expect(d.target.directory, '/Music/');
      d.useFolder('/Music/Gorillaz/');
      expect(d.target.directory, '/Music/Gorillaz/');
      expect(d.justThisSong?.kind, 'folder');
    });

    test('noMkdir and a folder that could not be checked: blocked too', () async {
      s.noMkdir = true;
      h.fake.file('/Music/', 'Daft Punk');
      final d = await ready();
      expect(d.mkdirBlocked, isTrue);
    });

    test('a refused mkdir this session counts as noMkdir', () async {
      h.fake.mkdirRefusal = (403, 'Create Folder Disabled');
      final d = await ready();
      d.attach();
      expect(await d.add(), isFalse);
      expect(d.addFailure?.problem, YtdlProblem.mkdirOff);
      expect(d.mkdirBlocked, isTrue);
      expect(h.repings, [s]);
    });
  });

  group('format (spec §5)', () {
    test('mp3 by default; a choice is remembered for the server', () async {
      final d = await found();
      expect(d.formats, ['mp3', 'm4a', 'opus', 'flac']);
      expect(d.format, 'mp3');
      await d.setFormat('flac');
      expect(d.format, 'flac');
      expect(s.ytdlFormat, 'flac');
      expect(st().screenDraft.predictedName, 'One_More_Time.flac');
    });

    test('a 400 on outputCodec: shown with the format asked for, which resets', () async {
      s.ytdlFormat = 'opus';
      h.fake.addRefusal = (400, '"outputCodec" must be one of [mp3, m4a, flac]');
      final d = await ready();
      d.attach();
      expect(await d.add(), isFalse);
      expect(d.addFailure?.problem, YtdlProblem.badFormat);
      expect(d.failedCodec, 'opus');
      expect(d.format, 'mp3');
      await d.setFormat('flac');
      expect(d.addFailure, isNull);
    });
  });

  group('Add (spec §6)', () {
    test('disabled while looking up', () async {
      h.fake.holdLookups = true;
      final d = await found();
      expect(d.block, YtdlBlock.lookingUp);
      expect(await d.add(), isFalse);
    });

    test('disabled while the same link is being added to the same folder', () async {
      final d = await ready();
      await st().start(h.request(directory: target));
      expect(d.alreadyAdding, isTrue);
      expect(d.block, YtdlBlock.alreadyAdding);
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: '', kind: 'top'));
      expect(d.alreadyAdding, isFalse);
    });

    test('its own add starting is no "Already adding" (spec §3); another '
        'surface\'s add of the link to the folder still is', () async {
      h.fake.folder(target);
      final d = await ready();
      h.fake.addGate = Completer<void>();
      final first = d.add();
      await ytdlSettle();
      expect(d.addPhase, YtdlAddPhase.starting);
      expect(d.alreadyAdding, isTrue, reason: 'the hub holds its job');
      expect(d.block, YtdlBlock.none);
      h.fake.addGate!.complete();
      expect(await first, isTrue);
      // The folder sheet for the same folder, the same link: an earlier add.
      final other = await ready(kOneMoreTime, st().folderDraft(target));
      expect(other.block, YtdlBlock.alreadyAdding);
    });

    test('an add of the link to the folder that starts while this one waits '
        'for its check: this one sends nothing', () async {
      final d = await found();
      expect(d.check, YtdlCheckState.checking);
      h.fake.listGate = Completer<void>();
      final mine = d.add();
      await ytdlSettle();
      expect(d.addPhase, YtdlAddPhase.starting);
      await st().start(h.request(directory: target, mkdir: target));
      h.fake.listGate!.complete();
      h.fake.listGate = null;
      expect(await mine, isFalse);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1, reason: 'the other one');
      expect(d.block, YtdlBlock.alreadyAdding);
    });

    test('disabled for an account that may not upload', () async {
      s.noUpload = true;
      final d = await ready();
      expect(d.block, YtdlBlock.uploadsOff);
    });

    test('a 200 resets the card: field cleared, tags closed, lookup idle', () async {
      final d = await found(kSweater);
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: kYtdlLayoutArtist, kind: 'artist'));
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.tagsOpen, isTrue);
      expect(await d.add(), isTrue);
      final job = st().jobs.single;
      expect(job.title, 'Sweater Weather');
      expect(job.directory, '/Music/TheNeighbourhood/');
      expect(job.codec, 'mp3');
      expect(job.tags, {'title': 'Sweater Weather', 'artist': 'TheNeighbourhood'});
      expect(job.predictedName, 'Sweater_Weather_Official_Video.mp3');
      expect(job.cover, isNull);
      expect(st().originOf(job), 'screen');
      expect(h.fake.bodies('POST', '/file-explorer/mkdir').single['directory'], '/Music/TheNeighbourhood/');
      expect(d.link.text, '');
      expect(d.lookup, YtdlLookupState.idle);
      expect(d.tagsOpen, isFalse);
      expect(d.justThisSong, isNull);
      expect(d.guess, YtdlGuess.none);
      expect(d.check, YtdlCheckState.idle);
      expect(d.addPhase, YtdlAddPhase.idle);
      expect([for (final f in YtdlField.values) controller(d, f).text], everyElement(''));
      expect(d.choice.kind, 'artistAlbum', reason: 'the remembered choice stays');
    });

    test('Starting… while it runs; a second tap sends nothing', () async {
      h.fake.folder(target);
      final d = await ready();
      h.fake.addGate = Completer<void>();
      final first = d.add();
      await ytdlSettle();
      expect(d.addPhase, YtdlAddPhase.starting);
      expect(await d.add(), isFalse);
      h.fake.addGate!.complete();
      expect(await first, isTrue);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 1);
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 0, reason: 'the folder was there');
    });

    test('tapped before the check ran: it waits for it, then makes the folders', () async {
      final d = await found();
      expect(d.check, YtdlCheckState.checking);
      expect(await d.add(), isTrue);
      expect(listed().first, target);
      expect(h.fake.bodies('POST', '/file-explorer/mkdir').single['directory'], target);
      expect(h.fake.requests.last.url.path, endsWith('/api/v1/ytdl/'));
    });

    test('an unchecked folder is made anyway when the account may', () async {
      h.fake.file('/Music/', 'Daft Punk');
      final d = await ready();
      await d.add();
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 1);
    });

    test('a timed-out add resets like a 200: its row looks for it', () async {
      h.fake.addThrows = TimeoutException('no answer');
      final d = await ready();
      expect(await d.add(), isTrue);
      expect(d.link.text, '');
      expect(st().jobs.single.state, YtdlJobState.startUnsure);
    });

    test('a failure while the screen shows stays on the card, with no row', () async {
      h.fake.addRefusal = (500, 'FFmpeg is not available yet');
      final d = await ready();
      d.attach();
      expect(await d.add(), isFalse);
      expect(d.addPhase, YtdlAddPhase.failed);
      expect(d.addFailure, const YtdlFailure(YtdlProblem.ffmpegNotReady));
      expect(d.link.text, kOneMoreTime);
      expect(st().jobs, isEmpty);
      expect(h.toasts, isEmpty);
      expect(d.block, YtdlBlock.none, reason: 'Try again');
    });

    test('a failure after the screen closed becomes a row and a toast', () async {
      h.fake.addRefusal = (500, 'Server Error');
      final d = await ready();
      d.detach();
      expect(await d.add(), isFalse);
      expect(d.addPhase, YtdlAddPhase.idle);
      expect(d.addFailure, isNull);
      expect(st().jobs.single.state, YtdlJobState.startFailed);
      expect(h.toastTexts, ['Couldn\'t add “One More Time”']);
    });

    test('a 403 shown inline turns Add off for the session', () async {
      h.fake.addRefusal = (403, 'Uploading Disabled');
      final d = await ready();
      d.attach();
      await d.add();
      expect(d.addFailure?.problem, YtdlProblem.uploadsOff);
      expect(d.block, YtdlBlock.uploadsOff);
      expect(h.repings, [s]);
    });

    test('a link changed while it started is a new card, kept', () async {
      final d = await ready();
      h.fake.addGate = Completer<void>();
      final pending = d.add();
      await ytdlSettle();
      type(d, kFeelGood);
      h.fake.addGate!.complete();
      expect(await pending, isTrue);
      expect(d.link.text, kFeelGood);
      expect(d.addPhase, YtdlAddPhase.idle);
    });
  });

  group('the add posts only into a path it checked', () {
    test('the target moving during the pre-start check is checked again, and made', () async {
      h.fake.holdLookups = true;
      final d = await found();
      d.enterManually();
      expect(d.target.directory, '/Music/');
      h.fake.listGate = Completer<void>();
      final pending = d.add();
      await ytdlSettle();
      // The lookup answers while /Music/ is still being listed.
      h.fake.heldLookups.single.complete();
      await ytdlSettle();
      expect(d.target.directory, target);
      h.fake.listGate!.complete();
      h.fake.listGate = null;
      expect(await pending, isTrue);
      expect(h.fake.bodies('POST', '/api/v1/ytdl/').single['directory'], target);
      expect(h.fake.bodies('POST', '/file-explorer/mkdir').single['directory'], target);
    });

    test('… and under noMkdir a new folder found then is refused, never posted into', () async {
      s.noMkdir = true;
      h.fake.holdLookups = true;
      final d = await found();
      d.enterManually();
      h.fake.listGate = Completer<void>();
      final pending = d.add();
      await ytdlSettle();
      h.fake.heldLookups.single.complete();
      await ytdlSettle();
      h.fake.listGate!.complete();
      h.fake.listGate = null;
      expect(await pending, isFalse);
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0);
      expect(d.block, YtdlBlock.mkdirBlocked);
      expect(d.addPhase, YtdlAddPhase.idle);
    });

    test('a change on the owner that moves the target checks the new path', () async {
      s = ytdlServer(libraries: const ['Music', 'Podcasts'])..discoveryPluginsAvailable = true;
      h.fake
        ..folder('/Podcasts/')
        ..folder(target);
      final d = await ready();
      expect(d.check, YtdlCheckState.known);
      expect(d.newSegments, isEmpty);
      // Discover's destination answers late (the first read failed).
      h.fake.discoverAt('Podcasts');
      await st().loadPresets();
      expect(d.target.directory, '/Podcasts/Daft Punk/Discovery/');
      expect(d.check, YtdlCheckState.checking);
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(d.newSegments, {0, 1});
      expect(await d.add(), isTrue);
      expect(h.fake.bodies('POST', '/file-explorer/mkdir').single['directory'],
          '/Podcasts/Daft Punk/Discovery/');
    });

    test('Add here under noMkdir: the explorer\'s own folder needs no check', () async {
      s.noMkdir = true;
      h.fake
        ..folder('/Music/Daft Punk/')
        ..listFails.add('/Music/Daft Punk/');
      final d = st().folderDraft('/Music/Daft Punk/');
      await ready(kOneMoreTime, d);
      expect(d.check, YtdlCheckState.unknown);
      expect(d.mkdirBlocked, isFalse);
      expect(d.block, YtdlBlock.none);
      expect(await d.add(), isTrue);
      expect(h.fake.count('POST', '/file-explorer/mkdir'), 0);
      // Subfolders still need the check.
      final sub = st().folderDraft('/Music/Daft Punk/');
      await ready(kFeelGood, sub);
      sub.setSubLayout(kYtdlLayoutAlbum);
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      expect(sub.mkdirBlocked, isTrue);
    });
  });

  group('failure routing by link', () {
    test('a failure for a link the card no longer shows is a row, not the new card\'s', () async {
      final d = await ready();
      d.attach();
      h.fake
        ..addGate = Completer<void>()
        ..addRefusal = (500, 'Server Error');
      final pending = d.add();
      await ytdlSettle();
      type(d, kFeelGood);
      h.fake.addGate!.complete();
      expect(await pending, isFalse);
      expect(d.addPhase, YtdlAddPhase.idle);
      expect(d.addFailure, isNull);
      expect(d.link.text, kFeelGood);
      final row = st().jobs.single;
      expect(row.url, kOneMoreTime);
      expect(row.state, YtdlJobState.startFailed);
      expect(h.toastTexts, ['Couldn\'t add “One More Time”']);
    });

    test('✕ during Starting… then a failure: a row and a toast, the card empty', () async {
      final d = await ready();
      d.attach();
      h.fake
        ..addGate = Completer<void>()
        ..addRefusal = (500, 'Server Error');
      final pending = d.add();
      await ytdlSettle();
      d.clear();
      h.fake.addGate!.complete();
      expect(await pending, isFalse);
      expect(d.addFailure, isNull);
      expect(st().jobs.single.state, YtdlJobState.startFailed);
      expect(h.toasts, hasLength(1));
    });

    test('a folder that could not be made reads as that, with its name', () async {
      h.fake
        ..folder('/Music/Daft Punk/')
        ..mkdirRefusal = (500, 'Server Error');
      final d = await ready();
      expect(d.newSegments, {1});
      d.attach();
      expect(await d.add(), isFalse);
      expect(d.addPhase, YtdlAddPhase.failed);
      expect(d.addFailure, const YtdlFailure(YtdlProblem.mkdirFailed, 'Discovery'));
      expect(h.fake.count('POST', '/api/v1/ytdl/'), 0);
    });

    test('a failure cleared by a change takes "Try again" with it', () async {
      s.ytdlFormat = 'opus';
      h.fake.addRefusal = (400, '"outputCodec" must be one of [mp3, m4a, flac]');
      final d = await ready();
      d.attach();
      await d.add();
      expect(d.addPhase, YtdlAddPhase.failed);
      await d.setFormat('flac');
      expect(d.addFailure, isNull);
      expect(d.addPhase, YtdlAddPhase.idle);

      h.fake.addRefusal = (404, "Library 'Music' not found");
      await d.add();
      expect(d.addPhase, YtdlAddPhase.failed);
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: '', kind: 'top'));
      expect(d.addPhase, YtdlAddPhase.idle);
      await h.timers.elapse(YtdlDraft.kCheckAfter);
      await d.add();
      expect(d.addPhase, YtdlAddPhase.failed);
      final sheet = st().folderDraft('/Music/');
      await ready(kFeelGood, sheet);
      sheet.attach();
      await sheet.add();
      expect(sheet.addPhase, YtdlAddPhase.failed);
      sheet.setSubLayout(kYtdlLayoutAlbum);
      expect(sheet.addPhase, YtdlAddPhase.idle);
    });

    test('a re-ping that turns conversion off takes the button away, and is heard', () async {
      h.hub.reping = (srv) async {
        await Future<void>.delayed(Duration.zero);
        srv.transcodeAvailable = false;
      };
      h.fake.addRefusal = (500, 'FFmpeg is not available yet');
      final d = await ready();
      d.attach();
      var heard = 0;
      d.addListener(() => heard++);
      await d.add();
      heard = 0;
      await ytdlSettle();
      expect(heard, greaterThan(0));
      expect(d.block, YtdlBlock.convertOff);
      expect(st().entryAllowed, isFalse);
    });
  });

  group('the path note and one-off paths', () {
    test('no tags, but a folder below the library: no "top folder" note', () async {
      h.fake.lookupRefusal = (500, 'Server Error');
      final sheet = st().folderDraft('/Music/Daft Punk/');
      await found(kOneMoreTime, sheet);
      expect(sheet.lookup, YtdlLookupState.failed);
      expect(sheet.target.directory, '/Music/Daft Punk/');
      expect(sheet.lookupBlank, isFalse);

      final d = await found();
      expect(d.lookupBlank, isTrue);
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: 'Singles/{{ARTIST}}', kind: 'custom'));
      expect(d.target.directory, '/Music/Singles/');
      expect(d.lookupBlank, isFalse);
    });

    test('a just-this-song path goes when another video replaces its song', () async {
      final d = await ready();
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: '', kind: 'top'));
      type(d, kFeelGood);
      expect(d.justThisSong, isNull);
      expect(d.choice.kind, 'artistAlbum');
      // The same link typed again keeps it.
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: '', kind: 'top'));
      type(d, '');
      type(d, kFeelGood);
      expect(d.justThisSong?.kind, 'top');
    });

    test('one chosen before any link is the first video\'s', () async {
      final d = draft();
      d.useForThisSong(const YtdlChoice(library: 'Music', layout: '', kind: 'top'));
      await found(kOneMoreTime, d);
      expect(d.justThisSong?.kind, 'top');
      type(d, kFeelGood);
      expect(d.justThisSong, isNull);
    });
  });

  group('previews and coming back online', () {
    test('checkTarget checks a choice not applied, leaving the draft\'s check alone', () async {
      h.fake.folder('/Music/Daft Punk/');
      final d = st().folderDraft('/Music/Daft Punk/');
      await ready(kOneMoreTime, d);
      expect(d.check, YtdlCheckState.known);
      final pending = d.targetFor(YtdlChoice.folder('/Music/Daft Punk/', layout: kYtdlLayoutAlbum));
      expect(pending.directory, target);
      final c = await d.checkTarget(pending);
      expect(c.state, YtdlCheckState.known);
      expect(c.newSegments, {1});
      expect([for (final i in c.newSegments) pending.segments[i]], ['Discovery']);
      expect(c.deepest, '/Music/Daft Punk/');
      expect(d.subLayout, kYtdlLayoutTop);
      expect(d.target.directory, '/Music/Daft Punk/');
      expect(d.newSegments, isEmpty);
    });

    test('an offline lookup runs again when the connection comes back', () async {
      h.fake.lookupThrows = const SocketException('Network is unreachable');
      final d = await found();
      expect(d.lookup, YtdlLookupState.offline);
      h.fake.lookupThrows = null;
      h.hub.connectivityRestored();
      await ytdlSettle();
      expect(d.lookup, YtdlLookupState.found);
    });

    test('… or when the same link is pasted again', () async {
      h.fake.lookupThrows = const SocketException('Network is unreachable');
      final d = await found();
      h.fake.lookupThrows = null;
      h.clipboard = kOneMoreTime;
      await d.pasteFromClipboard();
      await ytdlSettle();
      expect(lookups(), 2);
      expect(d.lookup, YtdlLookupState.found);
    });
  });

  group('failure words', () {
    test('a lost library\'s name, from the words or the folder', () {
      expect(ytdlGoneLibrary(const YtdlFailure(YtdlProblem.libraryGone, 'Podcasts'), target), 'Podcasts');
      expect(ytdlGoneLibrary(const YtdlFailure(YtdlProblem.libraryGone), target), 'Music');
    });

    test('the server\'s words to quote, never a bare status', () {
      expect(ytdlServerWords(const YtdlFailure(YtdlProblem.other, 'Not A Directory')), 'Not A Directory');
      expect(ytdlServerWords(const YtdlFailure(YtdlProblem.other, 'HTTP 502')), isNull);
      expect(ytdlServerWords(const YtdlFailure(YtdlProblem.serverError)), isNull);
    });
  });
}

TextEditingController controller(YtdlDraft d, YtdlField f) => d.controllerFor(f);
