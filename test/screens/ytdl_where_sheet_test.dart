// "Where new songs land" (screens/ytdl/ytdl_where_sheet.dart), driven by
// the scripted server in ytdl_fakes: it opens on the choice in force (the
// remembered one, or a just-this-song one), LIBRARY only with more than one
// library and locked to Discover's under "Same as Discover", the layouts
// offered (Same as Discover only for the user's own destination, Library
// layout only when set and different), the preview of the choice being
// edited — sample words before a link, slot words, the "new" tags from its
// own folder check (an answer for a path left behind dropped), the file
// note, the missing and always-empty notes, the bracket warnings and their
// links (sheet closed, the choice kept for this song, Album or Year asked
// to focus), read out 800 ms after it settles through one live region that
// never carries a refusal over a path or back — the Custom editor (chips
// insert at the caret and tick, named by what they show in every language,
// the YouTube check's three refusals, both
// buttons off and the preview amber, the preview pinned over the form with
// the keyboard up when there is room, the field keeping its focus), the
// noMkdir note, Save (remembered, toasted; on with a just-this-song choice
// in force) and Use for this song (this song only; the remembered layout
// drops the one-off instead), ✕ dropping changes, the sheet staying open
// when a re-ping turns the feature off, and 360 dp at 200% text without
// overflow, keyboard up included, a "new" tag scaled once.

import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/destination_pieces.dart'
    show destInsertLabel;
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/screens/ytdl/ytdl_where_sheet.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/util/ytdl_layout.dart';

import '../singletons/ytdl_fakes.dart';

const kLibraryLayout = '{{ARTIST}}/{{ALBUM}} ({{YEAR}})';

void main() {
  late YtdlHarness h;
  late Server s;
  final host = GlobalKey();

  YtdlServerState st() => h.hub.stateFor(s);
  YtdlDraft draft() => st().screenDraft;

  setUp(() {
    h = YtdlHarness()..wire();
    s = ytdlServer(libraries: const ['Music', 'Mixes']);
    h.fake.folder('/Music/Daft Punk/');
  });
  tearDown(() => h.unwire());

  /// Discover's destination (the user's own) and a library layout for
  /// Music, read by the state's presets.
  void presets({String? template = kLibraryLayout, String source = 'user'}) {
    s.discoveryPluginsAvailable = true;
    h.fake.discoverAt('Music', base: 'From Discover', source: source);
    h.fake.pathTemplates = {
      'vpaths': {
        if (template != null) 'Music': {'template': template},
      },
    };
  }

  /// The draft with [url] looked up and its path checked (null: no link).
  Future<YtdlDraft> ready(WidgetTester tester, [String? url = kOneMoreTime]) async {
    final d = draft();
    await tester.runAsync(() async {
      await st().loadPresets();
      if (url != null) {
        d.link.text = url;
        await h.timers.elapse(YtdlDraft.kLookupDebounce);
        await h.timers.elapse(YtdlDraft.kCheckAfter);
      }
    });
    return d;
  }

  Future<void> pumps(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Move the hub's clock (the sheet's check and voice run on it) and let
  /// the fake server answer.
  Future<void> elapse(WidgetTester tester, Duration d) async {
    await tester.runAsync(() => h.timers.elapse(d));
    await pumps(tester);
  }

  /// What the sheet's show call returns: done once it has closed.
  late Future<void> closed;

  /// The sheet open over a plain page at [size] and [textScale].
  Future<void> open(
    WidgetTester tester,
    YtdlDraft d, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(key: host, body: const SizedBox.expand()),
    ));
    closed = showYtdlWhereSheet(host.currentContext!, d);
    await pumps(tester);
    // The preview's own check, and anything the presets bring.
    await elapse(tester, const Duration(seconds: 1));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tap(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pump();
    await tester.tap(key(k));
    await pumps(tester);
  }

  /// The preview as read out.
  String spoken(WidgetTester tester) => tester
      .getSemantics(find
          .descendant(
            of: key('ytdl-where-preview'),
            matching: find.byWidgetPredicate((w) =>
                w is Semantics &&
                w.properties.liveRegion == true &&
                w.properties.label != null),
          )
          .first)
      .label;

  bool customFocused(WidgetTester tester) =>
      tester.widget<TextField>(key('ytdl-where-custom')).focusNode!.hasFocus;

  void expectChosen(WidgetTester tester, String kind, [bool on = true]) =>
      expect(tester.getSemantics(key('ytdl-where-layout-$kind')),
          isSemantics(isChecked: on),
          reason: kind);

  void expectEnabled(WidgetTester tester, String k, bool on) => expect(
      tester.getSemantics(key(k)), isSemantics(isButton: true, isEnabled: on),
      reason: k);

  group('opening (spec §4)', () {
    testWidgets('on the remembered choice, with the subtitle, LIBRARY and '
        'both buttons off', (tester) async {
      final semantics = tester.ensureSemantics();
      final d = await ready(tester);
      await open(tester, d);
      expect(find.text(h.l.ytdlWhereTitle), findsOneWidget);
      expect(find.text(h.l.ytdlWhereSub('music.example')), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(key('ytdl-where-library-Music'), findsOneWidget);
      expect(key('ytdl-where-library-Mixes'), findsOneWidget);
      expectChosen(tester, 'artistAlbum');
      expect(find.text(h.l.ytdlWhereLandsAt('One More Time')), findsOneWidget);
      expect(find.text(h.l.ytdlWhereFileNote('One More Time')), findsOneWidget);
      // "Discovery" isn't there yet: a new folder.
      expect(find.text(h.l.ytdlNewTag), findsOneWidget);
      expect(
        spoken(tester),
        startsWith('${h.l.ytdlWhereLandsAt('One More Time')} '
            'Music, then Daft Punk, then Discovery, a new folder, '
            'file One_More_Time.mp3.'),
      );
      expectEnabled(tester, 'ytdl-where-use', false);
      expectEnabled(tester, 'ytdl-where-save', false);
      semantics.dispose();
    });

    testWidgets('before a link: sample words and the sample note',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final d = await ready(tester, null);
      await open(tester, d);
      expect(find.text(h.l.ytdlWhereLandsAtSample), findsOneWidget);
      expect(find.text(h.l.ytdlWhereSampleNote), findsOneWidget);
      expect(find.text(h.l.ytdlNewTag), findsNothing);
      expect(
        spoken(tester),
        startsWith('${h.l.ytdlWhereLandsAtSample} Music, then Artist, then '
            'Album, file Video_title.mp3.'),
      );
      // Nothing listed for sample words.
      expect(h.fake.count('POST', '/api/v1/file-explorer'), 0);
      semantics.dispose();
    });

    testWidgets('one library: no LIBRARY section', (tester) async {
      s = ytdlServer();
      final d = await ready(tester);
      await open(tester, d);
      expect(find.text('LIBRARY'), findsNothing);
      expect(key('ytdl-where-library-Music'), findsNothing);
    });

    testWidgets('a just-this-song choice is what it opens on', (tester) async {
      final d = await ready(tester);
      d.useForThisSong(const YtdlChoice(
          library: 'Mixes', layout: kYtdlLayoutArtist, kind: 'artist'));
      await open(tester, d);
      expectChosen(tester, 'artist');
      // Already in force for this song; not yet remembered.
      expectEnabled(tester, 'ytdl-where-use', false);
      expectEnabled(tester, 'ytdl-where-save', true);
    });
  });

  group('the layouts', () {
    testWidgets('Same as Discover and Library layout come with the presets',
        (tester) async {
      presets();
      final d = await ready(tester);
      await open(tester, d);
      expect(key('ytdl-where-layout-discover'), findsOneWidget);
      expect(find.text('From Discover/{{ALBUMARTIST}}/{{ALBUM}}'), findsOneWidget);
      expect(key('ytdl-where-layout-library'), findsOneWidget);
      expect(find.text(kLibraryLayout), findsOneWidget);
    });

    testWidgets('Discover\'s library default and a template like a preset '
        'are not offered', (tester) async {
      presets(template: kYtdlLayoutArtistAlbum, source: 'default');
      final d = await ready(tester);
      await open(tester, d);
      expect(key('ytdl-where-layout-discover'), findsNothing);
      expect(key('ytdl-where-layout-library'), findsNothing);
    });

    testWidgets('the presets answering while it is open add their layouts',
        (tester) async {
      presets();
      final d = draft()..link.text = kOneMoreTime;
      await tester.runAsync(() => h.timers.elapse(YtdlDraft.kLookupDebounce));
      expect(st().presetsLoaded, isFalse);
      await open(tester, d);
      expect(st().presetsLoaded, isTrue);
      expect(key('ytdl-where-layout-discover'), findsOneWidget);
    });

    testWidgets('a radio re-renders the preview and turns both buttons on',
        (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-artist');
      expectChosen(tester, 'artist');
      expect(find.text(h.l.ytdlNewTag), findsNothing); // Daft Punk is there
      expectEnabled(tester, 'ytdl-where-use', true);
      expectEnabled(tester, 'ytdl-where-save', true);
      // Back where it opened: nothing changed.
      await tap(tester, 'ytdl-where-layout-artistAlbum');
      expectEnabled(tester, 'ytdl-where-use', false);
      expectEnabled(tester, 'ytdl-where-save', false);
    });

    testWidgets('Same as Discover locks LIBRARY to Discover\'s and checks its '
        'base folders', (tester) async {
      final semantics = tester.ensureSemantics();
      presets();
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-discover');
      await elapse(tester, YtdlDraft.kCheckAfter);
      expect(key('ytdl-where-library-locked'), findsOneWidget);
      expect(key('ytdl-where-library-Mixes'), findsNothing);
      expect(find.text(h.l.ytdlWhereSetByDiscover), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(h.l.ytdlA11yLocked)), findsOneWidget);
      // From Discover, Daft Punk and Discovery are all to be made.
      expect(find.text(h.l.ytdlNewTag), findsNWidgets(3));
      await elapse(tester, const Duration(milliseconds: 800));
      expect(
        spoken(tester),
        contains('Music, then From Discover, a new folder, then Daft Punk, '
            'a new folder, then Discovery, a new folder'),
      );
      await tap(tester, 'ytdl-where-save');
      expect(s.ytdlLayoutKind, 'discover');
      expect(s.ytdlLibrary, 'Music');
      expect(s.ytdlLayout, 'From Discover/{{ALBUMARTIST}}/{{ALBUM}}');
      semantics.dispose();
    });

    testWidgets('a library\'s own layout leaving with it moves into Custom',
        (tester) async {
      presets();
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-library');
      await tap(tester, 'ytdl-where-library-Mixes');
      expect(key('ytdl-where-layout-library'), findsNothing);
      expectChosen(tester, 'custom');
      expect(
        tester.widget<TextField>(key('ytdl-where-custom')).controller!.text,
        kLibraryLayout,
      );
    });
  });

  group('the preview\'s notes and check', () {
    testWidgets('a tag the layout names but the song lacks is named',
        (tester) async {
      h.fake.folder('/Music/Gorillaz/');
      final d = await ready(tester, kFeelGood);
      await open(tester, d);
      expect(
        find.byKey(const ValueKey('ytdl-where-missing')),
        findsOneWidget,
      );
      expect(find.text(h.l.discoverDestMissing('{{ALBUM}}')), findsOneWidget);
    });

    testWidgets('a preset variable YouTube never fills is named as always '
        'empty', (tester) async {
      presets(template: '{{GENRE}}/{{ARTIST}}');
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-library');
      expect(find.text(h.l.ytdlWhereAlwaysEmpty('{{GENRE}}')), findsOneWidget);
      // A preset with one is still allowed.
      expectEnabled(tester, 'ytdl-where-save', true);
    });

    testWidgets('an answer for a path the form has left is dropped',
        (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      h.fake.listGate = Completer<void>();
      await tap(tester, 'ytdl-where-layout-custom');
      await tester.enterText(key('ytdl-where-custom'), 'Singles');
      await pumps(tester);
      // The check for /Music/Singles/ is asked and held …
      await tester.runAsync(() async {
        await h.timers.elapse(YtdlDraft.kCheckAfter);
      });
      // … the form goes back to Artist / Album (the card's own check) …
      await tap(tester, 'ytdl-where-layout-artistAlbum');
      expect(find.text(h.l.ytdlNewTag), findsOneWidget);
      // … and the late answer ("Singles" is new) changes nothing.
      await tester.runAsync(() async {
        h.fake.listGate!.complete();
        await ytdlSettle();
      });
      await pumps(tester);
      expect(find.text(h.l.ytdlNewTag), findsOneWidget);
      expectChosen(tester, 'artistAlbum');
    });

    testWidgets('the preview is read out 800 ms after it settles',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final d = await ready(tester);
      await open(tester, d);
      final before = spoken(tester);
      await tap(tester, 'ytdl-where-layout-top');
      // Drawn at once …
      expect(find.text(h.l.ytdlWhereLandsAt('One More Time')), findsOneWidget);
      expect(spoken(tester), before);
      await elapse(tester, const Duration(milliseconds: 700));
      expect(spoken(tester), before);
      // … read once it has been still for 800 ms.
      await elapse(tester, const Duration(milliseconds: 100));
      expect(spoken(tester), startsWith(
          '${h.l.ytdlWhereLandsAt('One More Time')} Music, file One_More_Time.mp3.'));
      semantics.dispose();
    });

    testWidgets('one live region whether or not the layout is refused, '
        'never carrying the other state\'s words', (tester) async {
      final semantics = tester.ensureSemantics();
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-custom');
      await elapse(tester, const Duration(seconds: 1));
      final fix = h.l.discoverDestFixLayout;
      final landsAt = h.l.ytdlWhereLandsAt('One More Time');

      /// Every live region on screen, as (node, words).
      List<(int, String)> live() {
        final out = <(int, String)>[];
        void walk(SemanticsNode n) {
          final data = n.getSemanticsData();
          if (data.flagsCollection.isLiveRegion) {
            out.add((n.id, data.label));
          }
          n.visitChildren((c) {
            walk(c);
            return true;
          });
        }

        walk(tester.binding.renderViews.first.owner!.semanticsOwner!
            .rootSemanticsNode!);
        return out;
      }

      final voice = live().single;
      expect(voice.$2, startsWith(landsAt));

      // A token half typed: drawn at once, read only once it has settled.
      await tester.enterText(key('ytdl-where-custom'), '{{ARTIST');
      await pumps(tester);
      expect(find.text(fix), findsOneWidget);
      expect(live().single.$1, voice.$1);
      expect(live().single.$2, isNot(contains(fix)));
      expect(live().single.$2, isNot(startsWith(landsAt)));
      await elapse(tester, const Duration(milliseconds: 800));
      expect(live().single, (voice.$1, fix));

      // Whole again: the path is drawn at once and the refusal is not read
      // over it, before or after its own check.
      await tester.enterText(key('ytdl-where-custom'), '{{ARTIST}}/Singles');
      await pumps(tester);
      expect(find.text(fix), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(live().single.$1, voice.$1);
        expect(live().single.$2, isNot(contains(fix)));
        await elapse(tester, const Duration(milliseconds: 400));
      }
      expect(live().single.$2, startsWith(landsAt));
      expect(live().single.$2, contains('then Singles, a new folder'));
      semantics.dispose();
    });

    testWidgets('noMkdir: only folders that exist work', (tester) async {
      s.noMkdir = true;
      final d = await ready(tester);
      await open(tester, d);
      expect(find.text(h.l.ytdlWhereNoMkdir), findsOneWidget);
    });

    testWidgets('no note for an account that makes folders', (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      expect(key('ytdl-where-nomkdir'), findsNothing);
    });
  });

  group('bracket traps (YearTrap)', () {
    testWidgets('no album, no year: "()" and Edit tags opens Album for this '
        'song', (tester) async {
      presets();
      h.fake.folder('/Music/Gorillaz/');
      final d = await ready(tester, kFeelGood);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-library');
      expect(find.text(h.l.ytdlTrapEmpty('()')), findsOneWidget);
      expect(find.text(h.l.ytdlWhereFileNote('Feel Good Inc.')), findsNothing);
      await tap(tester, 'ytdl-where-trap-link');
      await closed;
      expect(key('ytdl-where-sheet'), findsNothing);
      expect(d.justThisSong?.kind, 'library');
      expect(d.justThisSong?.layout, kLibraryLayout);
      expect(d.tagsOpen, isTrue);
      expect(d.takeFocusRequest(), YtdlField.album);
      // Nothing remembered.
      expect(s.ytdlLayoutKind, isNull);
    });

    testWidgets('album, no year: "Discovery ()" and Add a year opens Year',
        (tester) async {
      presets();
      final d = await ready(tester);
      d.controllerFor(YtdlField.year).text = '';
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-library');
      expect(find.text(h.l.ytdlTrapNoYear('Discovery ()')), findsOneWidget);
      expect(find.text(h.l.ytdlTrapAddYear), findsOneWidget);
      // Save stays allowed: songs with every tag render fine.
      expectEnabled(tester, 'ytdl-where-save', true);
      await tap(tester, 'ytdl-where-trap-link');
      await closed;
      expect(d.justThisSong?.kind, 'library');
      expect(d.takeFocusRequest(), YtdlField.year);
    });
  });

  group('bracket traps on the remembered layout', () {
    testWidgets('the link drops a just-this-song one instead of repeating '
        'the remembered layout as one', (tester) async {
      presets();
      h.fake.folder('/Music/Gorillaz/');
      final d = await ready(tester, kFeelGood);
      await tester.runAsync(() => st().rememberDestination(
          library: 'Music', layout: kLibraryLayout, kind: 'library'));
      d.useForThisSong(const YtdlChoice(
          library: 'Music', layout: kYtdlLayoutArtist, kind: 'artist'));
      await open(tester, d);
      expectChosen(tester, 'artist');
      await tap(tester, 'ytdl-where-layout-library');
      await tap(tester, 'ytdl-where-trap-link');
      await closed;
      expect(d.justThisSong, isNull);
      expect(d.choice.kind, 'library');
      expect(d.tagsOpen, isTrue);
      expect(d.takeFocusRequest(), YtdlField.album);
    });
  });

  group('Custom (WhereCustom)', () {
    testWidgets('the chips insert at the caret and tick once used',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-custom');
      // The layout chosen until now starts the field.
      final field = tester.widget<TextField>(key('ytdl-where-custom'));
      expect(field.controller!.text, kYtdlLayoutArtistAlbum);
      await tester.enterText(key('ytdl-where-custom'), 'Singles');
      field.controller!.selection = const TextSelection.collapsed(offset: 0);
      await pumps(tester);
      expect(find.bySemanticsLabel(h.l.discoverDestInsertArtist), findsOneWidget);
      await tap(tester, 'ytdl-where-var-ARTIST');
      expect(field.controller!.text, '{{ARTIST}}Singles');
      expect(find.bySemanticsLabel(h.l.ytdlA11yVarUsed(h.l.discoverDestInsertArtist)),
          findsOneWidget);
      expect(find.bySemanticsLabel(h.l.ytdlA11yInsertVariable), findsOneWidget);
      // Named by what it shows too, where its words don't say it: Voice
      // Control finds a button by its label ("Tap ALBUMARTIST").
      expect(
          find.bySemanticsLabel(
              '${h.l.discoverDestInsertAlbumArtist}, ALBUMARTIST'),
          findsOneWidget);
      // A spaced token is the engine's too.
      await tester.enterText(key('ytdl-where-custom'), '{{ album }}');
      await pumps(tester);
      expect(
          find.bySemanticsLabel(
              h.l.ytdlA11yVarUsed(h.l.discoverDestInsertAlbum)),
          findsOneWidget);
      semantics.dispose();
    });

    test('in another language every chip carries what it shows', () {
      final de = lookupAppLocalizations(const Locale('de'));
      for (final v in ['ARTIST', 'ALBUMARTIST', 'ALBUM', 'YEAR']) {
        final label = destInsertLabel(de, v);
        expect(label.toLowerCase(), contains(v.toLowerCase()), reason: label);
      }
      expect(destInsertLabel(de, 'ARTIST'), 'Künstler einfügen, ARTIST');
    });

    testWidgets('a valid layout previews and saves as Custom', (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-custom');
      await tester.enterText(key('ytdl-where-custom'), '{{ARTIST}}/Singles');
      await elapse(tester, YtdlDraft.kCheckAfter);
      expect(key('ytdl-where-custom-error'), findsNothing);
      expect(find.text(h.l.ytdlNewTag), findsOneWidget); // Singles
      await tap(tester, 'ytdl-where-save');
      expect(s.ytdlLayoutKind, 'custom');
      expect(s.ytdlLayout, '{{ARTIST}}/Singles');
      expect(h.toastTexts.single,
          h.l.ytdlToastSaved('\u2068Music\u2069 › \u2068Artist\u2069 › \u2068Singles\u2069'));
    });

    for (final (name, layout, words) in [
      (
        'an unknown variable',
        '{{ARTIST}}/{{TITLE}}',
        'Unknown variable {{TITLE}}. Use ARTIST, ALBUMARTIST, ALBUM, YEAR.',
      ),
      (
        'a variable always empty for YouTube',
        '{{GENRE}}/{{ARTIST}}',
        '{{GENRE}} is always empty for YouTube songs. Use ARTIST, ALBUMARTIST, ALBUM, YEAR.',
      ),
      (
        'a character a folder can\'t hold',
        'Singles: 2024',
        'A folder name can\'t contain : * ? " < > or |.',
      ),
    ]) {
      testWidgets('$name: the line, the amber preview, both buttons off',
          (tester) async {
        final d = await ready(tester);
        await open(tester, d);
        await tap(tester, 'ytdl-where-layout-custom');
        await tester.enterText(key('ytdl-where-custom'), layout);
        await pumps(tester);
        expect(find.text(words), findsOneWidget);
        expect(find.text(h.l.discoverDestFixLayout), findsOneWidget);
        expectEnabled(tester, 'ytdl-where-use', false);
        expectEnabled(tester, 'ytdl-where-save', false);
      });
    }

    testWidgets('the keyboard up with room: the preview pinned over the form, '
        'the subtitle gone', (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-custom');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await pumps(tester);
      expect(tester.takeException(), isNull);
      expect(key('ytdl-where-preview'), findsOneWidget);
      expect(
        find.descendant(
            of: key('ytdl-where-form'), matching: key('ytdl-where-preview')),
        findsNothing,
      );
      expect(find.text(h.l.ytdlWhereSub('music.example')), findsNothing);
      expect(
        tester.getRect(key('ytdl-where-preview')).bottom,
        lessThanOrEqualTo(tester.getRect(key('ytdl-where-form')).top),
      );
      // The field kept its focus as the layout changed under it, and is
      // brought into view.
      expect(customFocused(tester), isTrue);
      expect(
        tester
            .getRect(key('ytdl-where-form'))
            .overlaps(tester.getRect(key('ytdl-where-custom'))),
        isTrue,
      );
    });
  });

  group('Save, Use for this song, closing', () {
    testWidgets('Save remembers the choice for the server and toasts',
        (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-library-Mixes');
      await tap(tester, 'ytdl-where-layout-artist');
      await tap(tester, 'ytdl-where-save');
      await closed;
      expect(key('ytdl-where-sheet'), findsNothing);
      expect(s.ytdlLibrary, 'Mixes');
      expect(s.ytdlLayout, kYtdlLayoutArtist);
      expect(s.ytdlLayoutKind, 'artist');
      expect(h.persisted, contains(s));
      expect(h.toasts.single.success, isTrue);
      expect(h.toastTexts.single,
          h.l.ytdlToastSaved('\u2068Mixes\u2069 › \u2068Artist\u2069'));
      expect(d.justThisSong, isNull);
    });

    testWidgets('Use for this song applies it to the card only',
        (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-top');
      await tap(tester, 'ytdl-where-use');
      await closed;
      expect(d.justThisSong,
          const YtdlChoice(library: 'Music', layout: '', kind: 'top'));
      expect(d.target.directory, '/Music/');
      expect(s.ytdlLayoutKind, isNull);
      expect(h.toasts, isEmpty);
    });

    testWidgets('back to the remembered layout from a just-this-song one: '
        'both on, and Use drops the one-off', (tester) async {
      final d = await ready(tester);
      d.useForThisSong(const YtdlChoice(
          library: 'Music', layout: kYtdlLayoutArtist, kind: 'artist'));
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-artistAlbum');
      expectEnabled(tester, 'ytdl-where-use', true);
      expectEnabled(tester, 'ytdl-where-save', true);
      await tap(tester, 'ytdl-where-use');
      await closed;
      // No "Just this song · Undo" for the layout that is remembered anyway.
      expect(d.justThisSong, isNull);
      expect(d.choice, st().rememberedChoice);
      expect(s.ytdlLayoutKind, isNull);
    });

    testWidgets('a folder in force: Save makes the remembered layout stick '
        'and drops the folder', (tester) async {
      final d = await ready(tester);
      d.useFolder('/Music/Daft Punk/');
      await open(tester, d);
      expectChosen(tester, 'artistAlbum');
      expectEnabled(tester, 'ytdl-where-use', true);
      expectEnabled(tester, 'ytdl-where-save', true);
      await tap(tester, 'ytdl-where-save');
      await closed;
      expect(d.justThisSong, isNull);
      expect(s.ytdlLayoutKind, 'artistAlbum');
      expect(d.target.directory, '/Music/Daft Punk/Discovery/');
    });

    testWidgets('a folder in force: Use for this song with the remembered '
        'layout drops the folder', (tester) async {
      final d = await ready(tester);
      d.useFolder('/Music/Daft Punk/');
      await open(tester, d);
      await tap(tester, 'ytdl-where-use');
      await closed;
      expect(d.justThisSong, isNull);
      expect(s.ytdlLayoutKind, isNull);
    });

    testWidgets('✕ drops what changed', (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-artist');
      expect(find.byTooltip(h.l.close), findsOneWidget);
      await tap(tester, 'ytdl-where-close');
      await closed;
      expect(d.justThisSong, isNull);
      expect(s.ytdlLayoutKind, isNull);
      expect(d.choice.kind, 'artistAlbum');
    });

    testWidgets('the feature going away closes nothing (spec §8): the form '
        'stays, and Use for this song still applies', (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      var done = false;
      unawaited(closed.then((_) => done = true));
      // A re-ping found audio conversion off; the state tells its drafts.
      s.transcodeAvailable = false;
      await tester.runAsync(() => st().rememberFormat('mp3'));
      await pumps(tester);
      expect(st().entryAllowed, isFalse);
      expect(key('ytdl-where-sheet'), findsOneWidget);
      expect(done, isFalse);
      await tap(tester, 'ytdl-where-layout-artist');
      await tap(tester, 'ytdl-where-use');
      await closed;
      expect(d.justThisSong?.layout, kYtdlLayoutArtist);
    });
  });

  group('360 dp at 200% text', () {
    Future<void> check(WidgetTester tester, Future<void> Function() state) async {
      await state();
      expect(tester.takeException(), isNull);
      await tester.drag(key('ytdl-where-form'), const Offset(0, -3000));
      await pumps(tester);
      expect(tester.takeException(), isNull);
    }

    testWidgets('the preview, LIBRARY and the layouts', (tester) async {
      presets();
      final d = await ready(tester, kFeelGood);
      await check(tester, () => open(tester, d,
          size: const Size(360, 800), textScale: 2));
    });

    testWidgets('a bracket warning', (tester) async {
      presets();
      final d = await ready(tester, kFeelGood);
      await check(tester, () async {
        await open(tester, d, size: const Size(360, 800), textScale: 2);
        await tap(tester, 'ytdl-where-layout-library');
        await tester.drag(key('ytdl-where-form'), const Offset(0, 3000));
        await pumps(tester);
        expect(key('ytdl-where-trap-link'), findsOneWidget);
      });
    });

    testWidgets('a new folder with the keyboard up: its tag scaled once, the '
        'path kept to two lines, nothing cut, the field in view',
        (tester) async {
      // One More Time: "Discovery" is new.
      final d = await ready(tester);
      await open(tester, d, size: const Size(360, 800), textScale: 2);
      expect(find.text(h.l.ytdlNewTag), findsOneWidget);
      // As drawn: 16 px of line at 200%, not twice that again.
      expect(tester.getRect(find.text(h.l.ytdlNewTag)).height,
          moreOrLessEquals(32, epsilon: 1));
      await tap(tester, 'ytdl-where-layout-custom');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await pumps(tester);
      expect(tester.takeException(), isNull);
      // Two 40 px lines at most (a tag's baseline may add a little).
      expect(tester.getRect(key('ytdl-where-path')).height,
          lessThanOrEqualTo(84));
      // Nothing pinned can leave the field room here: the preview scrolls
      // with the form, which keeps the field in view.
      expect(
        find.descendant(
            of: key('ytdl-where-form'), matching: key('ytdl-where-preview')),
        findsOneWidget,
      );
      expect(find.text(h.l.ytdlWhereSub('music.example')), findsNothing);
      final form = tester.getRect(key('ytdl-where-form'));
      expect(form.height, greaterThanOrEqualTo(48));
      expect(form.overlaps(tester.getRect(key('ytdl-where-custom'))), isTrue);
      expect(customFocused(tester), isTrue);
    });

    testWidgets('Custom with a refusal', (tester) async {
      final d = await ready(tester);
      await check(tester, () async {
        await open(tester, d, size: const Size(360, 800), textScale: 2);
        await tap(tester, 'ytdl-where-layout-custom');
        await tester.enterText(key('ytdl-where-custom'), '{{GENRE}}/{{ARTIST}}');
        await pumps(tester);
        expect(key('ytdl-where-custom-error'), findsOneWidget);
      });
    });

    testWidgets('the touch targets are 48 px', (tester) async {
      final d = await ready(tester);
      await open(tester, d);
      await tap(tester, 'ytdl-where-layout-custom');
      // The hit band around the drawn control: around the key on the
      // footer's text and pill, inside the chips' own widgets.
      for (final band in [
        find.ancestor(of: key('ytdl-where-use'), matching: find.byType(GestureDetector)),
        find.ancestor(of: key('ytdl-where-save'), matching: find.byType(GestureDetector)),
        find.descendant(of: key('ytdl-where-var-ARTIST'), matching: find.byType(GestureDetector)),
        find.descendant(
            of: key('ytdl-where-library-Music'),
            matching: find.byType(GestureDetector)),
      ]) {
        expect(tester.getSize(band.first).height, greaterThanOrEqualTo(48));
      }
      // The variable chip is drawn 32 px tall.
      expect(
        tester.getSize(find.descendant(
          of: key('ytdl-where-var-ARTIST'),
          matching: find.byType(Container),
        ).first).height,
        32,
      );
      expect(tester.getSize(key('ytdl-where-close')).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(key('ytdl-where-layout-artist')).height,
          greaterThanOrEqualTo(48));
    });
  });
}
