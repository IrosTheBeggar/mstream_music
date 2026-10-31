// The Add from YouTube screen (spec §3, §8; the Empty, LookingUp,
// LinkStates and KeyboardTags boards) against the scripted server: the
// empty screen (the clipboard chip only while the clipboard has text, the
// limits and web-app lines only on 6.30+, the server's name only with two
// servers of the user's own, no action bar, nothing focused), the
// lands-in line and its Change, every link state (not YouTube, a playlist,
// a short link, a scheme added, a video in a playlist, a live link by
// tier), every lookup state (reading, slow and Enter details yourself,
// failed and timed out with Enter details and Try again, failed after
// manual entry, the late answer and Use them, offline, yt-dlp missing),
// Add (the field clears and focus drops after a 200), Clear link, the
// screen closing when a re-ping turns the feature off, a tag field kept in
// view with SAVES TO above the keyboard — also when the Where sheet asks
// for one — the iPhone's Done bar over the Year number pad, and 360 dp at
// 200% text without overflow or a word cut off.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/ytdl/ytdl_crumbs.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/screens/ytdl/ytdl_saves_block.dart';
import 'package:mstream_music/screens/ytdl/ytdl_screen.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';

import '../singletons/ytdl_fakes.dart';
import 'ytdl_ui_fixtures.dart';

void main() {
  final ui = YtdlUi();
  late Server s;

  setUp(() {
    ui.setUp();
    s = ytdlServer(formats: const ['mp3', 'm4a', 'opus', 'flac']);
  });
  tearDown(ui.tearDown);

  YtdlHarness h() => ui.h;
  YtdlServerState st() => h().hub.stateFor(s);

  group('empty (the Empty board)', () {
    testWidgets('paste card, chip, lands-in line and the empty state; no bar',
        (t) async {
      ServerManager().serverList.addAll([s, ytdlServer()]);
      h().clipboard = kOneMoreTime;
      await ui.pumpScreen(t, s);
      final l = h().l;
      expect(find.text(l.ytdlTitle), findsOneWidget);
      expect(byKey('ytdl-server-name'), findsOneWidget);
      expect(byKey('ytdl-paste'), findsOneWidget);
      final lands = t.widget<YtdlCrumbLine>(find.byType(YtdlCrumbLine));
      expect(lands.crumbs, ['Music', 'Artist', 'Album']);
      expect(lands.prefix, 'Lands in ');
      expect(lands.suffix, ' · MP3 ·');
      expect(byKey('ytdl-limits'), findsOneWidget);
      expect(byKey('ytdl-lists-empty'), findsOneWidget);
      expect(find.text(l.ytdlEmptyTitle), findsOneWidget);
      expect(find.text(l.ytdlEmptyWebApp), findsOneWidget);
      expect(byKey('ytdl-add'), findsNothing);
      // Nothing autofocuses: the keyboard stays down.
      expect(FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()));
    });

    testWidgets('one own server: no subtitle; empty clipboard: no chip',
        (t) async {
      ServerManager().serverList.add(s);
      await ui.pumpScreen(t, s);
      expect(byKey('ytdl-server-name'), findsNothing);
      expect(byKey('ytdl-paste'), findsNothing);
    });

    testWidgets('older server: no limits line, no web-app line', (t) async {
      h().fake.hasRecords = false;
      await ui.pumpScreen(t, s);
      expect(byKey('ytdl-limits'), findsNothing);
      expect(find.text(h().l.ytdlEmptyWebApp), findsNothing);
      expect(find.text(h().l.ytdlEmptyTitle), findsOneWidget);
    });

    testWidgets('the chip pastes and looks up at once; the card and bar come',
        (t) async {
      h().clipboard = kOneMoreTime;
      h().fake.folder('/Music/Daft Punk/');
      await ui.pumpScreen(t, s);
      await t.tap(byKey('ytdl-paste'));
      await ui.settle(t);
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(h().fake.count('GET', '/ytdl/metadata'), 1);
      expect(byKey('ytdl-card'), findsOneWidget);
      expect(byKey('ytdl-add'), findsOneWidget);
      expect(byKey('ytdl-paste'), findsNothing);
      expect(byKey('ytdl-lists-empty'), findsNothing);
    });

    testWidgets('Change on the lands-in line opens Where new songs land',
        (t) async {
      final d = await ui.pumpScreen(t, s);
      await t.tap(byKey('ytdl-lands-change'));
      await t.pump();
      expect(ui.sheets.where, [d]);
    });

    testWidgets('a just-this-song choice before any link: tag and Undo',
        (t) async {
      final d = await ui.pumpScreen(t, s);
      d.useFolder('/Music/Singles/');
      await t.pump();
      expect(find.text(h().l.ytdlJustThisSong), findsOneWidget);
      expect(t.widget<YtdlCrumbLine>(find.byType(YtdlCrumbLine)).crumbs,
          ['Music', 'Singles']);
      await t.tap(byKey('ytdl-just-undo'));
      await t.pump();
      expect(d.justThisSong, isNull);
      expect(find.text(h().l.ytdlJustThisSong), findsNothing);
    });
  });

  group('link states (the LinkStates board)', () {
    testWidgets('not a YouTube link: the error line, no card, no bar',
        (t) async {
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, 'https://vimeo.com/76979871');
      expect(find.text(h().l.ytdlLinkNotYoutube), findsOneWidget);
      expect(byKey('ytdl-link-error'), findsOneWidget);
      expect(byKey('ytdl-card'), findsNothing);
      expect(byKey('ytdl-add'), findsNothing);
      expect(h().fake.count('GET', '/ytdl/metadata'), 0);
    });

    testWidgets('a playlist', (t) async {
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d,
          'https://www.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG');
      expect(find.text(h().l.ytdlLinkPlaylist), findsOneWidget);
      expect(byKey('ytdl-card'), findsNothing);
    });

    testWidgets('a short link names the link the server gets', (t) async {
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, 'https://youtu.be/FGBhQbmPwH8?si=Rk3vT0');
      expect(find.text(h().l.ytdlLinkShortSent('youtube.com/watch?v=FGBhQbmPwH8')),
          findsOneWidget);
    });

    testWidgets('typed without https', (t) async {
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, 'YouTube.com/watch?v=FGBhQbmPwH8');
      expect(find.text(h().l.ytdlLinkSentAs('youtube.com/watch?v=FGBhQbmPwH8')),
          findsOneWidget);
    });

    testWidgets('a video in a playlist: "Just this video" on the card',
        (t) async {
      final d = await ui.pumpScreen(t, s);
      await ui.paste(
          t, d, 'https://www.youtube.com/watch?v=FGBhQbmPwH8&list=OLAK5uy_kVQ2');
      expect(byKey('ytdl-in-playlist'), findsOneWidget);
      expect(find.text(h().l.ytdlLinkInPlaylist), findsOneWidget);
    });

    testWidgets('a live link on 6.30+', (t) async {
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, 'https://www.youtube.com/live/jfKfPfyJRdk');
      expect(find.text(h().l.ytdlLinkLive), findsOneWidget);
    });

    testWidgets('a live link on an older server', (t) async {
      h().fake.hasRecords = false;
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, 'https://www.youtube.com/live/jfKfPfyJRdk');
      expect(find.text(h().l.ytdlLinkLiveOlder), findsOneWidget);
    });
  });

  group('lookup states (the LookingUp and LinkStates boards)', () {
    testWidgets('reading, then slow: Enter details yourself opens the tags',
        (t) async {
      h().fake.holdLookups = true;
      final d = await ui.pumpScreen(t, s);
      d.link.text = kOneMoreTime;
      await ui.settle(t, YtdlDraft.kLookupDebounce);
      expect(byKey('ytdl-skeleton'), findsOneWidget);
      expect(find.text(h().l.ytdlLookupReading), findsOneWidget);
      expect(_addEnabled(t), isFalse);
      await ui.settle(t, YtdlDraft.kSlowAfter);
      expect(find.text(h().l.ytdlLookupSlow), findsOneWidget);
      await t.tap(byKey('ytdl-enter-yourself'));
      await t.pump();
      await t.pump();
      expect(d.manual, isTrue);
      expect(byKey('ytdl-field-title'), findsOneWidget);
      expect(d.focusFor(YtdlField.title).hasFocus, isTrue);
      expect(_addEnabled(t), isTrue);
      for (final c in h().fake.heldLookups) {
        c.complete();
      }
      await ui.settle(t);
    });

    testWidgets('failed (500): the copy, Enter details, Try again, "Music › file"',
        (t) async {
      h().fake.lookupRefusal = (500, 'Server Error');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      final l = h().l;
      expect(find.text(l.ytdlLookupFailed), findsOneWidget);
      expect(shows(t, 'Music › ${l.ytdlSampleFile}'), isTrue);
      expect(find.text(l.ytdlLookupNoTags), findsOneWidget);
      expect(_addEnabled(t), isTrue);
      h().fake.lookupRefusal = null;
      await t.tap(byKey('ytdl-retry-lookup'));
      await ui.settle(t);
      expect(h().fake.count('GET', '/ytdl/metadata'), 2);
      expect(byKey('ytdl-card'), findsOneWidget);
    });

    testWidgets('failed: Enter details opens the fields, focused', (t) async {
      h().fake.lookupRefusal = (500, 'Server Error');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      await t.tap(byKey('ytdl-enter-details'));
      await t.pump();
      await t.pump();
      expect(d.tagsOpen, isTrue);
      expect(d.focusFor(YtdlField.title).hasFocus, isTrue);
      expect(byKey('ytdl-using-yours'), findsOneWidget);
      expect(find.text(h().l.ytdlLookupFailedUsingYours), findsOneWidget);
    });

    testWidgets('timed out', (t) async {
      h().fake.lookupThrows = TimeoutException('slow');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      expect(find.text(h().l.ytdlLookupTimedOut), findsOneWidget);
      expect(byKey('ytdl-enter-details'), findsOneWidget);
      expect(byKey('ytdl-retry-lookup'), findsOneWidget);
    });

    testWidgets('typed first, the answer late: Use them fills what nobody edited',
        (t) async {
      h().fake.holdLookups = true;
      h().fake.folder('/Music/Daft Punk/');
      final d = await ui.pumpScreen(t, s);
      d.link.text = kOneMoreTime;
      await ui.settle(t, YtdlDraft.kLookupDebounce);
      await ui.settle(t, YtdlDraft.kSlowAfter);
      await t.tap(byKey('ytdl-enter-yourself'));
      await t.pump();
      await t.enterText(byKey('ytdl-field-title'), 'One more time');
      await t.enterText(byKey('ytdl-field-artist'), 'Daft Punk');
      for (final c in h().fake.heldLookups) {
        c.complete();
      }
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(byKey('ytdl-late'), findsOneWidget);
      expect(find.text(h().l.ytdlLateEditsStay), findsOneWidget);
      // Not used yet: what shows is what was typed — no source line (it
      // would call the typed artist a guess), no "No album" line.
      expect(byKey('ytdl-source'), findsNothing);
      expect(find.text(h().l.ytdlSourceMusic), findsNothing);
      expect(find.text(h().l.ytdlCardNoAlbum), findsNothing);
      expect(find.text('Discovery'), findsNothing);
      await tapIn(t, byKey('ytdl-use-late'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(byKey('ytdl-late'), findsNothing);
      expect(byKey('ytdl-source'), findsOneWidget);
      expect(d.controllerFor(YtdlField.title).text, 'One more time');
      expect(d.controllerFor(YtdlField.album).text, 'Discovery');
      expect(d.controllerFor(YtdlField.year).text, '2001');
    });

    group('a lookup refused (spec §8 Errors)', () {
      Future<void> refused(WidgetTester t, YtdlRefusal r) async {
        h().fake.lookupRefusal = r;
        final d = await ui.pumpScreen(t, s);
        await ui.paste(t, d, kOneMoreTime);
        expect(byKey('ytdl-lookup-failed'), findsOneWidget);
        expect(byKey('ytdl-retry-lookup'), findsOneWidget);
        expect(find.text(h().l.ytdlLookupFailed), findsNothing);
      }

      testWidgets('a 404 with no JSON body: no route, no Enter details',
          (t) async {
        await refused(t, (404, null));
        expect(find.text(h().l.ytdlErrNoRoute), findsOneWidget);
        expect(byKey('ytdl-enter-details'), findsNothing);
      });

      testWidgets('a 400: about the link, never the raw text', (t) async {
        await refused(t, (400, '"url" must be a valid uri'));
        expect(find.text(h().l.ytdlErrBadRequest), findsOneWidget);
        expect(shows(t, 'valid uri'), isFalse);
        expect(byKey('ytdl-enter-details'), findsOneWidget);
      });

      testWidgets('anything else: the server\'s own words', (t) async {
        await refused(t, (500, 'Not A Directory'));
        expect(find.text(h().l.ytdlErrOther('Not A Directory')),
            findsOneWidget);
        expect(byKey('ytdl-enter-details'), findsOneWidget);
      });
    });

    testWidgets('a live link: its warning while reading and while offline',
        (t) async {
      const live = 'https://www.youtube.com/live/jfKfPfyJRdk';
      h().fake.holdLookups = true;
      final d = await ui.pumpScreen(t, s);
      d.link.text = live;
      await ui.settle(t, YtdlDraft.kLookupDebounce);
      expect(byKey('ytdl-skeleton'), findsOneWidget);
      expect(byKey('ytdl-live'), findsOneWidget);
      h().fake.holdLookups = false;
      h().fake.lookupThrows = const SocketException('Failed host lookup');
      d.retryLookup();
      await ui.settle(t);
      expect(byKey('ytdl-offline'), findsOneWidget);
      expect(byKey('ytdl-live'), findsOneWidget);
      for (final c in h().fake.heldLookups) {
        c.complete();
      }
      await ui.settle(t);
    });

    testWidgets('offline: the banner, Add off', (t) async {
      h().fake.lookupThrows = const SocketException('Failed host lookup');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      expect(byKey('ytdl-offline'), findsOneWidget);
      expect(find.text(h().l.ytdlOffline), findsOneWidget);
      expect(_addEnabled(t), isFalse);
    });

    testWidgets('yt-dlp missing: the panel in place of the card, no bar',
        (t) async {
      h().fake.lookupRefusal = (500, 'yt-dlp is not installed');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      expect(byKey('ytdl-ytdlp-missing'), findsOneWidget);
      expect(find.text(h().l.ytdlYtdlpMissing), findsOneWidget);
      expect(byKey('ytdl-add'), findsNothing);
      h().fake.lookupRefusal = null;
      await t.tap(byKey('ytdl-ytdlp-retry'));
      await ui.settle(t);
      expect(h().fake.count('GET', '/ytdl/metadata'), 2);
      expect(byKey('ytdl-card'), findsOneWidget);
    });
  });

  group('add and clear', () {
    testWidgets('Add to library: Starting…, then the field clears and focus drops',
        (t) async {
      h().fake.folder('/Music/Daft Punk/Discovery/');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      await t.tap(byKey('ytdl-link'));
      await t.pump();
      h().fake.addGate = Completer<void>();
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      // The card's own add shows on its button only: no ADDING row yet,
      // and no "Already adding" over it — that note is for an earlier add
      // (spec §3).
      expect(find.text(h().l.discoverJobStarting), findsOneWidget);
      expect(byKey('ytdl-section-adding'), findsNothing);
      expect(byKey('ytdl-already-adding'), findsNothing);
      h().fake.addGate!.complete();
      await ui.settle(t);
      await ui.settle(t);
      expect(h().fake.bodies('POST', '/api/v1/ytdl/').single['directory'],
          '/Music/Daft Punk/Discovery/');
      expect(d.link.text, '');
      expect(byKey('ytdl-card'), findsNothing);
      // On 200 the card collapses into the top ADDING row (spec §6).
      expect(byKey('ytdl-section-adding'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()));
    });

    testWidgets('Clear link discards the draft', (t) async {
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      await t.tap(byKey('ytdl-clear'));
      await t.pump();
      expect(d.link.text, '');
      expect(d.lookup, YtdlLookupState.idle);
      expect(byKey('ytdl-card'), findsNothing);
    });
  });

  testWidgets('a re-ping that turns uploads off closes the screen, saying why',
      (t) async {
    await ui.pumpScreen(t, s);
    expect(find.byType(YtdlScreen), findsOneWidget);
    s.noUpload = true;
    await st().rememberFormat('mp3'); // any change the state tells
    await t.pumpAndSettle();
    expect(find.byType(YtdlScreen), findsNothing);
    expect(h().toastTexts, [h().l.ytdlErrUploadsOff]);
  });

  testWidgets('the re-ping closes the screen under the open format menu too',
      (t) async {
    h().fake.folder('/Music/Daft Punk/Discovery/');
    final d = await ui.pumpScreen(t, s);
    await ui.paste(t, d, kOneMoreTime);
    await t.tap(byKey('ytdl-format'));
    await t.pumpAndSettle();
    expect(byKey('ytdl-format-menu'), findsOneWidget);
    s.noUpload = true;
    await st().rememberFormat('mp3');
    await t.pumpAndSettle();
    expect(byKey('ytdl-format-menu'), findsNothing);
    expect(find.byType(YtdlScreen), findsNothing);
    expect(byKey('test-open'), findsOneWidget);
    expect(h().toastTexts, [h().l.ytdlErrUploadsOff]);
  });

  group('opened at NEEDS A LOOK (the strip\'s Details)', () {
    /// Stand-in lists: 300 px of ADDING, then the NEEDS A LOOK header on
    /// the anchor, then 900 px of rows.
    void fakeLists() {
      YtdlScreen.listsBuilder = (state, anchor, {required showEmpty}) => Column(
            children: [
              const SizedBox(height: 300),
              SizedBox(
                key: anchor,
                height: 40,
                child: const Text('NEEDS A LOOK'),
              ),
              const SizedBox(height: 900),
            ],
          );
    }

    bool inView(WidgetTester t, Finder f) {
      final list = t.getRect(byKey('ytdl-list'));
      final r = t.getRect(f);
      return r.top >= list.top && r.bottom <= list.bottom;
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('under a tall kept card at ${scale}x: the header in view',
          (t) async {
        fakeLists();
        h().fake.folder('/Music/');
        // The card kept from before: the YouTube-artist tier opens its tags.
        final d = st().screenDraft;
        d.link.text = kSweater;
        await ui.settle(t, YtdlDraft.kLookupDebounce);
        await ui.settle(t, YtdlDraft.kCheckAfter);
        expect(d.tagsOpen, isTrue);
        await ui.pumpScreen(t, s, openNeedsLook: true, textScale: scale);
        await t.pumpAndSettle();
        expect(inView(t, find.text('NEEDS A LOOK')), isTrue);
        // Once only: scrolled back up, the next change doesn't pull it down.
        final scroll = t.widget<SingleChildScrollView>(
            byKey('ytdl-list')).controller!;
        scroll.jumpTo(0);
        await t.pump();
        d.controllerFor(YtdlField.album).text = 'Wiped Out!';
        await t.pumpAndSettle();
        expect(scroll.offset, 0);
      });
    }

    testWidgets('nothing needs a look: nothing scrolls, nothing waits',
        (t) async {
      YtdlScreen.listsBuilder = (state, anchor, {required showEmpty}) =>
          const SizedBox(height: 1200);
      h().fake.folder('/Music/Daft Punk/Discovery/');
      final d = await ui.pumpScreen(t, s, openNeedsLook: true);
      final scroll =
          t.widget<SingleChildScrollView>(byKey('ytdl-list')).controller!;
      expect(scroll.offset, 0);
      // The header turning up later (a poll) doesn't yank the list.
      fakeLists();
      await ui.paste(t, d, kOneMoreTime);
      await t.pumpAndSettle();
      expect(scroll.offset, 0);
    });
  });

  group('keyboard (the KeyboardTags board)', () {
    testWidgets('a focused tag field keeps itself and SAVES TO above the keyboard',
        (t) async {
      h().fake.folder('/Music/Gorillaz/');
      final d = await ui.pumpScreen(t, s, keyboard: 300);
      await ui.paste(t, d, kFeelGood);
      d.openTags(focus: YtdlField.artist);
      await t.pump();
      await t.pump();
      await t.pumpAndSettle();
      final list = t.getRect(byKey('ytdl-list'));
      final field = t.getRect(byKey('ytdl-field-artist'));
      final saves = t.getRect(find.descendant(
          of: find.byType(YtdlSavesBlock), matching: find.byType(YtdlCrumbs)));
      expect(d.focusFor(YtdlField.artist).hasFocus, isTrue);
      expect(list.top <= field.top && field.bottom <= list.bottom, isTrue,
          reason: 'field $field in $list');
      expect(list.top <= saves.top && saves.bottom <= list.bottom, isTrue,
          reason: 'SAVES TO crumbs $saves in $list');
    });

    testWidgets('the Where sheet asks for Album: the tags open on it',
        (t) async {
      h().fake.folder('/Music/Daft Punk/');
      final d = await ui.pumpScreen(t, s);
      await ui.paste(t, d, kOneMoreTime);
      expect(d.tagsOpen, isFalse);
      // As the sheet's "Edit tags" link does, then closes.
      d.useForThisSong(d.choice);
      d.openTags(focus: YtdlField.album);
      await t.pump();
      await t.pump();
      expect(byKey('ytdl-field-album'), findsOneWidget);
      expect(d.focusFor(YtdlField.album).hasFocus, isTrue);
    });
  });

  testWidgets('iPhone (the iPhone board): the Year number pad gets a Done bar',
      (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    h().fake.folder('/Music/Daft Punk/');
    final d = await ui.pumpScreen(t, s);
    await ui.paste(t, d, kOneMoreTime);
    expect(byKey('ytdl-ios-done'), findsNothing);
    d.openTags(focus: YtdlField.year);
    await t.pump();
    await t.pump();
    expect(d.focusFor(YtdlField.year).hasFocus, isTrue);
    expect(byKey('ytdl-ios-done'), findsOneWidget);
    expect(t.getSize(byKey('ytdl-ios-done')).height, greaterThanOrEqualTo(48));
    await t.tap(byKey('ytdl-ios-done'));
    await t.pump();
    expect(d.focusFor(YtdlField.year).hasFocus, isFalse);
    expect(byKey('ytdl-ios-done'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android: no Done bar over the Year field', (t) async {
    h().fake.folder('/Music/Daft Punk/');
    final d = await ui.pumpScreen(t, s);
    await ui.paste(t, d, kOneMoreTime);
    d.openTags(focus: YtdlField.year);
    await t.pump();
    await t.pump();
    expect(d.focusFor(YtdlField.year).hasFocus, isTrue);
    expect(byKey('ytdl-ios-done'), findsNothing);
  });

  group('narrow and large text (the Narrow360 board)', () {
    testWidgets('360 dp at 200%: the empty screen fits', (t) async {
      ServerManager().serverList.addAll([s, ytdlServer()]);
      h().clipboard = kOneMoreTime;
      await ui.pumpScreen(t, s, size: const Size(360, 800), textScale: 2);
      expect(t.takeException(), isNull);
    });

    testWidgets('360 dp at 200%: nothing on the empty screen is cut — the '
        'chip grows with its words, the lands-in line keeps its format',
        (t) async {
      h().clipboard = kOneMoreTime;
      await ui.pumpScreen(t, s, size: const Size(360, 800), textScale: 2);
      final chip = t.renderObject<RenderParagraph>(find.descendant(
          of: byKey('ytdl-paste'),
          matching: find.text(h().l.ytdlPasteFromClipboard)));
      expect(chip.size.height,
          greaterThanOrEqualTo(chip.getMaxIntrinsicHeight(chip.size.width) - 0.5),
          reason: 'every line of "Paste from clipboard" shows');
      final lands = t.renderObject<RenderParagraph>(find.descendant(
          of: find.byType(YtdlCrumbLine), matching: find.byType(RichText)));
      expect(lands.text.toPlainText(), endsWith(' · MP3 ·'));
      // Even the last folder leaves the format no room on one line: the
      // line wraps rather than cut it (the test font is wider than the
      // app's, so how much fits is ytdl_crumbs_test's to pin).
      expect(lands.maxLines, 2);
    });

    testWidgets('360 dp at 200%: a cleaned card with its tags open fits',
        (t) async {
      h().fake.folder('/Music/Gorillaz/');
      final d = await ui.pumpScreen(t, s,
          size: const Size(360, 800), textScale: 2);
      await ui.paste(t, d, kFeelGood);
      d.openTags();
      await t.pump();
      expect(t.takeException(), isNull);
      await t.drag(byKey('ytdl-list'), const Offset(0, -2000));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('semantics: the link field, Clear link, the format chip',
      (t) async {
    final handle = t.ensureSemantics();
    final d = await ui.pumpScreen(t, s);
    await ui.paste(t, d, kOneMoreTime);
    final l = h().l;
    expect(find.bySemanticsLabel(RegExp(l.ytdlA11yLinkField)), findsWidgets);
    expect(find.byTooltip(l.ytdlA11yClearLink), findsOneWidget);
    expect(find.bySemanticsLabel(l.ytdlA11yFormat('MP3')), findsOneWidget);
    handle.dispose();
  });
}

/// The Add button takes taps.
bool _addEnabled(WidgetTester t) {
  final ink = t.widget<InkWell>(find.descendant(
      of: byKey('ytdl-add'), matching: find.byType(InkWell)));
  return ink.onTap != null;
}
