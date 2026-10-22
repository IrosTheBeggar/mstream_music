// Where copies land, and Open elsewhere (the design canvas's
// PhoneDestination and PhoneElsewhere boards): the destination picker from
// the Keep card's Change — the library default, the live preview of where
// this song lands, the writable libraries, the base folder, the layouts and
// Custom (a layout typed by hand: its field, the variables, the validator's
// words as typed), Save and "Use the library default", a refusal in the
// server's words, saving, loading, no library, uploads off, a failed read,
// the keyboard, German — and the links plug-in's sub-sheet over the song
// sheet: loading, exact pages then searches, opening outside the app, a
// link that will not open, empty, and the server's error.
//
// The plug-in API is the scripted fake; the URL launcher is the test's.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/screens/discovery/destination_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/elsewhere_sheet.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/theme/velvet_theme.dart';

import 'discovery_copies_fixtures.dart';
import 'discovery_keep_fixtures.dart';

const _dest = '/api/v1/discovery/collection/destination';
const _resolve = '/plugins/links/resolve';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final k = KeepHarness();
  final toasts = <String>[];
  final successes = <bool>[];

  setUpAll(mockPathProvider);
  setUp(() {
    k.setUp();
    // The real sheets behind Change and Open elsewhere.
    DiscoveryKeepRoutes.reset();
    toasts.clear();
    successes.clear();
    KeepToast.debugSink = (m, {success = false}) {
      toasts.add(m);
      successes.add(success);
    };
    SettingsManager().discoverKeepNoteSeen = true;
  });
  tearDown(() {
    KeepToast.debugSink = null;
    elsewhereLaunch = (uri) async => false;
    BrowserManager().closeAlbumDetail();
    ServerManager().currentServer = null;
    SettingsManager().discoverKeepNoteSeen = false;
    k.tearDown();
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) =>
      KeepHarness.pumpFor(tester, n);

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await frames(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await frames(tester);
  }

  /// The song sheet of [title], then its Change.
  Future<void> openPicker(
    WidgetTester tester, {
    String title = 'Late Train Verse',
  }) async {
    await k.pumpDiscover(tester);
    await tester.longPress(find.text(title));
    await frames(tester, 8);
    await tapKey(tester, 'keep-change');
    await frames(tester, 4);
  }

  /// The preview as read (a segment's no-break spaces and word joiners —
  /// it never breaks inside itself — read as plain text).
  String preview(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('destination-preview')))
      .textSpan!
      .toPlainText()
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u2060', '');

  Map<String, dynamic> lastPut() =>
      jsonDecode(k.fake.calls('PUT', _dest).last.body) as Map<String, dynamic>;

  group('the destination picker', () {
    testWidgets(
      'Change opens it over the sheet: the library default in force, where '
      'this song lands, the writable libraries, the base folder, the '
      'layouts; Save waits for a change',
      (tester) async {
        await openPicker(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Where copies land'), findsOneWidget);
        expect(find.text('library default'), findsOneWidget);
        expect(
          find.text('One setting for your account · every copy uses it'),
          findsOneWidget,
        );
        // The picker reads the destination afresh (after Discover's visit
        // and the Keep card's open).
        expect(k.fake.count('GET', _dest), 3);
        expect(find.text('Late Train Verse lands at'), findsOneWidget);
        expect(
          preview(tester),
          'copies › Boukmanflow › Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        expect(
          find.byKey(const ValueKey('destination-library-copies')),
          findsOneWidget,
        );
        expect(find.text('copies /'), findsOneWidget);
        expect(find.text('library root'), findsOneWidget);
        expect(
          find.text('Inside copies. Leave empty for the library root.'),
          findsOneWidget,
        );
        expect(find.text('Artist / Album'), findsOneWidget);
        expect(find.text('{{ALBUMARTIST}}/{{ALBUM}}'), findsOneWidget);
        expect(find.text('Server / Artist / Album'), findsOneWidget);
        expect(find.text('{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}'), findsOneWidget);
        expect(find.text('Library layout'), findsNothing);
        // The server's own default is the Artist / Album preset: a fresh
        // account's layout is no Custom one.
        expect(find.text('Custom'), findsOneWidget);
        expect(find.byKey(const ValueKey('destination-custom')), findsNothing);
        expect(find.text('Use the library default'), findsNothing);
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 0, reason: 'nothing changed yet');
      },
    );

    testWidgets(
      'typing a base folder moves the preview; Save sends it, toasts where '
      'copies land, the tag reads yours; Use the library default saves none',
      (tester) async {
        await openPicker(tester);
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          'from-peers',
        );
        await frames(tester, 2);
        expect(
          preview(tester),
          'copies › from-peers › Boukmanflow › Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        await tapKey(tester, 'destination-save');
        expect(lastPut(), {
          'destination': {
            'vpath': 'copies',
            'base': 'from-peers',
            'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
          },
        });
        expect(toasts, ['Saved · copies land in copies › from-peers']);
        expect(successes, [true], reason: 'the check toast');
        expect(find.text('yours'), findsOneWidget);
        expect(find.text('Use the library default'), findsOneWidget);
        expect(SettingsManager().discoverKeepNoteSeen, isTrue);
        // Saved: Save waits for the next change again.
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 1);

        await tapText(tester, 'Use the library default');
        expect(lastPut(), {'destination': null});
        expect(find.text('library default'), findsOneWidget);
        expect(find.text('Use the library default'), findsNothing);
        expect(toasts.last, 'Saved · copies land in copies');
        // The Keep card behind it follows.
        Navigator.of(tester.element(find.text('Where copies land'))).pop();
        await frames(tester, 8);
        expect(find.text('Where copies land'), findsNothing);
      },
    );

    testWidgets(
      "a compilation's song lands under the album's credit, one folder for "
      'the whole album; the server preset keeps it',
      (tester) async {
        k.peersAnswer = () => keepPeersPayload(extraB: compilationRows());
        await k.pumpDiscover(tester);
        await tester.ensureVisible(find.text('Block Rocker'));
        await tester.pump();
        await tester.longPress(find.text('Block Rocker'));
        await frames(tester, 8);
        await tapKey(tester, 'keep-change');
        await frames(tester, 4);
        expect(
          preview(tester),
          startsWith('copies › Various Artists › Block Party Comp › '),
        );
        await tapText(tester, 'Server / Artist / Album');
        expect(
          preview(tester),
          startsWith(
            'copies › Stage Peer B › Various Artists › Block Party Comp › ',
          ),
        );
        await tapKey(tester, 'destination-save');
        expect(
          (lastPut()['destination'] as Map)['layout'],
          '{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}',
          reason: 'never a per-track-artist layout from a preset',
        );
      },
    );

    testWidgets(
      "an older server's default ({{ARTIST}}/{{ALBUM}}) is its Artist / "
      'Album preset, not Custom',
      (tester) async {
        k.fake.destination = {
          ...k.fake.destination,
          'destination': {
            'vpath': 'copies',
            'base': '',
            'layout': '{{ARTIST}}/{{ALBUM}}',
            'source': 'default',
          },
          'defaultLayout': '{{ARTIST}}/{{ALBUM}}',
        };
        await openPicker(tester);
        expect(find.text('{{ARTIST}}/{{ALBUM}}'), findsOneWidget);
        expect(find.byKey(const ValueKey('destination-custom')), findsNothing);
        expect(find.text('{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}'), findsOneWidget);
      },
    );

    testWidgets(
      "Server / Artist / Album adds the server's folder; a library with its "
      'own Path Template offers it as a third layout',
      (tester) async {
        k.fake.destination = {
          ...k.fake.destination,
          'libraries': [
            {'vpath': 'copies', 'template': null},
            {
              'vpath': 'demo',
              'template': '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
            },
          ],
        };
        await openPicker(tester);
        await tapText(tester, 'Server / Artist / Album');
        expect(
          preview(tester),
          'copies › Stage Peer B › Boukmanflow › Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        await tapKey(tester, 'destination-library-demo');
        expect(find.text('Library layout'), findsOneWidget);
        expect(
          find.text('{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}'),
          findsOneWidget,
        );
        await tapText(tester, 'Library layout');
        expect(
          preview(tester),
          'demo › Boukmanflow › 2019 - Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        expect(
          find.text('Inside demo. Leave empty for the library root.'),
          findsOneWidget,
        );
        await tapKey(tester, 'destination-save');
        expect(lastPut(), {
          'destination': {
            'vpath': 'demo',
            'base': '',
            'layout': '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
          },
        });
      },
    );

    testWidgets(
      "a base folder the server would refuse: the preview waits; Save's 400 "
      "puts the server's words under the field; typing clears them",
      (tester) async {
        await openPicker(tester);
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          '../shared',
        );
        await frames(tester, 2);
        expect(
          find.text('Fix the base folder to see where files land'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('destination-preview')), findsNothing);
        k.fake.refuseOn['PUT $_dest'] = (
          400,
          'destination base folder: Resolved path cannot contain .. segments',
        );
        await tapKey(tester, 'destination-save');
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('destination-base-error')),
            matching: find.text(
              'destination base folder: Resolved path cannot contain .. segments',
            ),
          ),
          findsOneWidget,
        );
        expect(toasts, isEmpty);
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          'shared',
        );
        await frames(tester, 2);
        expect(
          find.byKey(const ValueKey('destination-base-error')),
          findsNothing,
        );
      },
    );

    testWidgets('saving: Saving…, the inputs locked, then the saved one', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.enterText(
        find.byKey(const ValueKey('destination-base')),
        'from-peers',
      );
      await frames(tester, 2);
      k.fake.destinationGate = Completer<void>();
      await tapKey(tester, 'destination-save');
      expect(find.text('Saving…'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('destination-base')),
      );
      expect(field.enabled, isFalse);
      k.fake.destinationGate!.complete();
      k.fake.destinationGate = null;
      await frames(tester);
      expect(find.text('Saving…'), findsNothing);
      expect(find.text('yours'), findsOneWidget);
    });

    testWidgets("from the album sheet it previews the album's first song", (
      tester,
    ) async {
      await k.pumpDiscover(tester);
      await tester.longPress(find.text('Borrowed Tapes').first);
      await frames(tester, 8);
      await tapKey(tester, 'keep-change');
      await frames(tester, 4);
      expect(find.text('Rooftop Cypher lands at'), findsOneWidget);
      expect(
        preview(tester),
        'copies › Boukmanflow › Borrowed Tapes › 01 - Rooftop Cypher.mp3',
      );
    });
  });

  group('the destination picker: Custom, a layout typed by hand', () {
    TextField customField(WidgetTester tester) => tester.widget<TextField>(
      find.byKey(const ValueKey('destination-custom')),
    );

    Future<void> typeCustom(WidgetTester tester, String text) async {
      await tester.enterText(
        find.byKey(const ValueKey('destination-custom')),
        text,
      );
      await frames(tester, 2);
    }

    double top(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text)).dy;

    /// The layout rows: the presets, then Custom.
    int presetRows() => find
        .byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> &&
              key.value.startsWith('destination-layout-') &&
              key.value != 'destination-layout-error';
        })
        .evaluate()
        .length;

    /// The colour of Custom's frame.
    Color? frame(WidgetTester tester) {
      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('destination-custom')),
              matching: find.byType(Container),
            )
            .first,
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    /// The icon and the colour of the line under the field named [key].
    (IconData?, Color?) tone(WidgetTester tester, String key) {
      final line = find.byKey(ValueKey(key));
      final icon = tester.widget<Icon>(
        find.descendant(of: line, matching: find.byType(Icon)),
      );
      final text = tester.widget<Text>(
        find.descendant(of: line, matching: find.byType(Text)),
      );
      return (icon.icon, text.style?.color);
    }

    testWidgets(
      'Custom comes third, after the presets; choosing it opens an empty '
      'field with the keyboard up, the variables under it; Save waits',
      (tester) async {
        await openPicker(tester);
        expect(find.text('Type your own path'), findsOneWidget);
        expect(
          top(tester, 'Artist / Album'),
          lessThan(top(tester, 'Server / Artist / Album')),
        );
        expect(
          top(tester, 'Server / Artist / Album'),
          lessThan(top(tester, 'Custom')),
        );
        expect(find.byKey(const ValueKey('destination-custom')), findsNothing);

        await tapKey(tester, 'destination-custom-option');
        expect(tester.takeException(), isNull);
        expect(customField(tester).controller!.text, isEmpty);
        expect(
          find.text('e.g. From friends or {{ARTIST}}/{{ALBUM}}'),
          findsOneWidget,
        );
        expect(customField(tester).focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          tester.getSemantics(find.byKey(const ValueKey('destination-custom'))),
          isSemantics(
            // Its name, then the hint while it is empty.
            label: 'Custom layout\ne.g. From friends or {{ARTIST}}/{{ALBUM}}',
            isTextField: true,
          ),
        );
        // Typed as typed: no autocorrect, no suggestions, no smart dashes
        // or quotes turning "--" or quotes into other characters.
        final typed = customField(tester);
        expect(
          [
            typed.autocorrect,
            typed.enableSuggestions,
            typed.smartDashesType,
            typed.smartQuotesType,
          ],
          [false, false, SmartDashesType.disabled, SmartQuotesType.disabled],
        );
        // The hint wraps rather than lose its example with variables.
        expect(typed.decoration!.hintMaxLines, 2);
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey('destination-custom-option')),
          ),
          isSemantics(
            label: 'Custom',
            hint: 'Type your own path',
            isChecked: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(
            find.byKey(
              const ValueKey('destination-layout-{{ALBUMARTIST}}/{{ALBUM}}'),
            ),
          ),
          isSemantics(label: 'Artist / Album', isChecked: false),
        );
        for (final v in [
          'ARTIST',
          'ALBUM',
          'YEAR',
          'GENRE',
          'ALBUMARTIST',
          'PEER',
        ]) {
          expect(find.text('{{$v}}'), findsOneWidget, reason: v);
        }
        expect(
          find.text(
            'Use / between folders. Variables sort copies by artist, '
            'album…; a plain name puts every copy in the same folder.',
          ),
          findsOneWidget,
        );
        // Nothing typed: a quiet line where the path goes, and no warning.
        expect(
          find.text('Type a path to see where files land'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('destination-preview')), findsNothing);
        expect(
          find.byKey(const ValueKey('destination-custom-invalid')),
          findsNothing,
        );
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 0, reason: 'an empty layout');
      },
    );

    testWidgets(
      'a plain folder: the preview follows it, Save sends exactly that '
      'layout, and the picker keeps Custom with it',
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');
        await typeCustom(tester, 'From friends');
        expect(
          preview(tester),
          'copies › From friends › 02 - Late Train Verse.mp3',
        );
        await tapKey(tester, 'destination-save');
        expect(lastPut(), {
          'destination': {
            'vpath': 'copies',
            'base': '',
            'layout': 'From friends',
          },
        });
        expect(toasts, ['Saved · copies land in copies']);
        expect(find.text('yours'), findsOneWidget);
        expect(customField(tester).controller!.text, 'From friends');
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 1, reason: 'saved: nothing new');
      },
    );

    testWidgets(
      'a saved layout that is no preset opens in Custom, its field holding '
      'it',
      (tester) async {
        const mine = {
          'vpath': 'copies',
          'base': '',
          'layout': 'From friends/{{ARTIST}}',
        };
        k.fake.destination = {
          ...k.fake.destination,
          'destination': {...mine, 'source': 'user'},
          'saved': mine,
        };
        await openPicker(tester);
        expect(find.text('yours'), findsOneWidget);
        // No row of its own for the layout in force: the two presets, and
        // Custom holding it.
        expect(presetRows(), 2);
        expect(
          find.byKey(const ValueKey('destination-custom-option')),
          findsOneWidget,
        );
        expect(customField(tester).controller!.text, 'From friends/{{ARTIST}}');
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey('destination-custom-option')),
          ),
          isSemantics(label: 'Custom', isChecked: true),
        );
        expect(
          tester.getSemantics(
            find.byKey(
              const ValueKey('destination-layout-{{ALBUMARTIST}}/{{ALBUM}}'),
            ),
          ),
          isSemantics(label: 'Artist / Album', isChecked: false),
        );
        expect(customField(tester).focusNode!.hasFocus, isFalse);
        expect(
          preview(tester),
          'copies › From friends › Boukmanflow › 02 - Late Train Verse.mp3',
        );
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 0, reason: 'nothing changed');
      },
    );

    testWidgets(
      'a variable button puts its token at the caret; each is named for a '
      'screen reader',
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');
        await typeCustom(tester, 'Copies/ - {{ALBUM}}');
        final c = customField(tester).controller!;
        c.selection = const TextSelection.collapsed(offset: 7);
        await frames(tester, 2);
        expect(find.bySemanticsLabel('Insert artist'), findsOneWidget);
        // The name it shows is in its name when the words do not say it.
        expect(
          find.bySemanticsLabel('Insert album artist, ALBUMARTIST'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Insert server name, PEER'),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey('destination-var-ARTIST')),
          ),
          isSemantics(
            label: 'Insert artist',
            isButton: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        await tapKey(tester, 'destination-var-ARTIST');
        expect(c.text, 'Copies/{{ARTIST}} - {{ALBUM}}');
        expect(c.selection, const TextSelection.collapsed(offset: 17));
        expect(customField(tester).focusNode!.hasFocus, isTrue);
        expect(
          preview(tester),
          'copies › Copies › Boukmanflow - Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        // Over a selection: the token takes its place.
        c.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
        await frames(tester, 2);
        await tapKey(tester, 'destination-var-YEAR');
        expect(c.text, '{{YEAR}}/{{ARTIST}} - {{ALBUM}}');
        await tapKey(tester, 'destination-save');
        expect(
          (lastPut()['destination'] as Map)['layout'],
          '{{YEAR}}/{{ARTIST}} - {{ALBUM}}',
        );
      },
    );

    testWidgets(
      "what the server would refuse: the validator's words under the field "
      'as typed, the preview waits, Save stays off',
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');

        Future<void> refused(String typed, String words) async {
          await typeCustom(tester, typed);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('destination-custom-invalid')),
              matching: find.text(words),
            ),
            findsOneWidget,
            reason: typed,
          );
          expect(
            find.text('Fix the layout to see where files land'),
            findsOneWidget,
          );
          await tapKey(tester, 'destination-save');
          expect(k.fake.count('PUT', _dest), 0, reason: typed);
        }

        await refused(
          '{{ARTST}}/{{ALBUM}}',
          'Unknown variable {{ARTST}}. Use ARTIST, ALBUM, YEAR, GENRE, '
              'ALBUMARTIST, PEER.',
        );
        await refused(
          'Inbox/{ARTIST}',
          'A brace is out of place — variables are written like {{ARTIST}}.',
        );
        await refused(
          'Inbox/../{{ARTIST}}',
          "A path can't contain .. folders.",
        );
        await refused(
          '/Inbox',
          "A layout can't start with / — it begins inside the base folder.",
        );
        await refused('~/Inbox', r"A path can't contain ~ or $HOME.");
        await refused(r'$HOME/Inbox', r"A path can't contain ~ or $HOME.");
        await refused('C:/Inbox', "A path can't use a drive letter like C:.");
        await refused('Inbox/C:x', "A path can't use a drive letter like C:.");
        await refused(
          'Inbox\tFriends',
          "A path can't contain tabs or other control characters.",
        );
        await refused(
          '   ',
          'That makes no folder — add a name or a variable.',
        );
        // As typed, braces and spaces kept: the server names it so.
        await refused(
          'Inbox/{{ artst }}',
          'Unknown variable {{ artst }}. Use ARTIST, ALBUM, YEAR, GENRE, '
              'ALBUMARTIST, PEER.',
        );
        // 300 emoji are 300 characters to the keyboard's limit and 600 to
        // the server's (JS counts UTF-16 units, as the validator does).
        await refused('🎵' * 300, 'A layout can be at most 500 characters.');
        // In the warning tone, and not announced over the typing.
        expect(tone(tester, 'destination-custom-invalid'), (
          Icons.warning_amber_rounded,
          keepTone(VelvetColors.warning),
        ));
        expect(frame(tester), keepTone(VelvetColors.warning));
        expect(
          tester.getSemantics(
            find.text('A layout can be at most 500 characters.'),
          ),
          isSemantics(isLiveRegion: false),
        );

        await typeCustom(tester, '{{ARTIST}}/{{ALBUM}}');
        expect(
          find.byKey(const ValueKey('destination-custom-invalid')),
          findsNothing,
        );
        await tapKey(tester, 'destination-save');
        expect(
          (lastPut()['destination'] as Map)['layout'],
          '{{ARTIST}}/{{ALBUM}}',
        );
      },
    );

    testWidgets(
      'a preset after typing keeps the typed text for Custom; Save sends '
      'the preset',
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');
        await typeCustom(tester, 'Inbox');
        expect(preview(tester), 'copies › Inbox › 02 - Late Train Verse.mp3');
        await tapText(tester, 'Server / Artist / Album');
        expect(find.byKey(const ValueKey('destination-custom')), findsNothing);
        expect(
          preview(tester),
          'copies › Stage Peer B › Boukmanflow › Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        await tapKey(tester, 'destination-custom-option');
        expect(customField(tester).controller!.text, 'Inbox');
        expect(preview(tester), 'copies › Inbox › 02 - Late Train Verse.mp3');
        await tapText(tester, 'Server / Artist / Album');
        await tapKey(tester, 'destination-save');
        expect(lastPut(), {
          'destination': {
            'vpath': 'copies',
            'base': '',
            'layout': '{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}',
          },
        });
        // Saved as the preset: Custom still holds what was typed.
        expect(find.byKey(const ValueKey('destination-custom')), findsNothing);
        await tapKey(tester, 'destination-custom-option');
        expect(customField(tester).controller!.text, 'Inbox');
      },
    );

    testWidgets("a library's own layout that leaves with its library stays the "
        'layout, in Custom', (tester) async {
      k.fake.destination = {
        ...k.fake.destination,
        'libraries': [
          {'vpath': 'copies', 'template': null},
          {'vpath': 'demo', 'template': '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}'},
        ],
      };
      await openPicker(tester);
      await tapKey(tester, 'destination-library-demo');
      await tapText(tester, 'Library layout');
      await tapKey(tester, 'destination-library-copies');
      expect(find.text('Library layout'), findsNothing);
      expect(
        customField(tester).controller!.text,
        '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
      );
      expect(
        preview(tester),
        'copies › Boukmanflow › 2019 - Borrowed Tapes › 02 - Late Train Verse.mp3',
      );
      await tapKey(tester, 'destination-save');
      expect(lastPut(), {
        'destination': {
          'vpath': 'copies',
          'base': '',
          'layout': '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
        },
      });
    });

    testWidgets(
      "Save's 400 puts the server's words right under Custom's field; "
      'editing the field clears them',
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');
        await typeCustom(tester, 'Inbox/{{PEER}}');
        const words =
            'destination layout: Unknown variable {{PEER}}. Supported: '
            '{{ARTIST}}, {{ALBUM}}';
        k.fake.refuseOn['PUT $_dest'] = (400, words);
        await tapKey(tester, 'destination-save');
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('destination-layout-error')),
            matching: find.text(words),
          ),
          findsOneWidget,
        );
        expect(toasts, isEmpty);
        // In the error tone, announced, between the field and the variables
        // (where the keyboard leaves it in view).
        expect(tone(tester, 'destination-layout-error'), (
          Icons.error_outline,
          keepTone(VelvetColors.error),
        ));
        expect(frame(tester), keepTone(VelvetColors.error));
        expect(
          tester.getSemantics(find.text(words)),
          isSemantics(isLiveRegion: true),
        );
        final line = tester.getRect(
          find.byKey(const ValueKey('destination-layout-error')),
        );
        expect(
          line.top,
          greaterThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('destination-custom')))
                .bottom,
          ),
        );
        expect(
          line.bottom,
          lessThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('destination-var-ARTIST')))
                .top,
          ),
        );
        expect(customField(tester).controller!.text, 'Inbox/{{PEER}}');
        await typeCustom(tester, 'Inbox');
        expect(
          find.byKey(const ValueKey('destination-layout-error')),
          findsNothing,
        );
      },
    );

    testWidgets(
      "a variable the phone can't see (the file's genre) stands as a slot "
      'in the path, with a note; the path is never shallower than the '
      "server's",
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');
        await typeCustom(tester, '{{GENRE}}/{{ARTIST}}');
        expect(
          preview(tester),
          'copies › ‹genre› › Boukmanflow › 02 - Late Train Verse.mp3',
        );
        expect(
          find.text(
            "‹genre› is filled from each file's genre tag (left out when a "
            'file has none).',
          ),
          findsOneWidget,
        );
        // The slot reads apart from the folders the layout names.
        final slot = tester
            .widget<Text>(find.byKey(const ValueKey('destination-preview')))
            .textSpan!;
        TextSpan? genre;
        slot.visitChildren((span) {
          if (span is TextSpan && span.text == '‹genre›') genre = span;
          return genre == null;
        });
        expect(genre?.style?.fontStyle, FontStyle.italic);
        // Mixed into a folder's name too.
        await typeCustom(tester, '{{ARTIST}} - {{GENRE}}');
        expect(
          preview(tester),
          'copies › Boukmanflow - ‹genre› › 02 - Late Train Verse.mp3',
        );
        // No genre: no slot, no note.
        await typeCustom(tester, '{{ARTIST}}');
        expect(
          find.byKey(const ValueKey('destination-preview-genre')),
          findsNothing,
        );
        await tapKey(tester, 'destination-save');
        expect((lastPut()['destination'] as Map)['layout'], '{{ARTIST}}');
      },
    );

    testWidgets(
      'an empty Custom under a base folder the server would refuse: the '
      'preview asks to fix the base folder first',
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          '../x',
        );
        await frames(tester, 2);
        expect(
          find.text('Fix the base folder to see where files land'),
          findsOneWidget,
        );
        expect(find.text('Type a path to see where files land'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          'x',
        );
        await frames(tester, 2);
        expect(
          find.text('Type a path to see where files land'),
          findsOneWidget,
        );
      },
    );

    testWidgets("a library's own layout carried into Custom and back again: its "
        "preset again, and Custom's field as it was", (tester) async {
      k.fake.destination = {
        ...k.fake.destination,
        'libraries': [
          {'vpath': 'copies', 'template': null},
          {'vpath': 'demo', 'template': '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}'},
        ],
      };
      await openPicker(tester);
      await tapKey(tester, 'destination-custom-option');
      await typeCustom(tester, 'Inbox');
      await tapKey(tester, 'destination-library-demo');
      await tapText(tester, 'Library layout');
      await tapKey(tester, 'destination-library-copies');
      expect(
        customField(tester).controller!.text,
        '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
      );
      await tapKey(tester, 'destination-library-demo');
      const library = ValueKey(
        'destination-layout-{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
      );
      expect(
        tester.getSemantics(find.byKey(library)),
        isSemantics(label: 'Library layout', isChecked: true),
      );
      expect(find.byKey(const ValueKey('destination-custom')), findsNothing);
      expect(
        preview(tester),
        'demo › Boukmanflow › 2019 - Borrowed Tapes › 02 - Late Train Verse.mp3',
      );
      await tapKey(tester, 'destination-custom-option');
      expect(customField(tester).controller!.text, 'Inbox');
      // Edited in the other library, it stays Custom's.
      await tapText(tester, 'Library layout');
      await tapKey(tester, 'destination-library-copies');
      await typeCustom(tester, '{{ALBUMARTIST}}/{{YEAR}}');
      await tapKey(tester, 'destination-library-demo');
      expect(customField(tester).controller!.text, '{{ALBUMARTIST}}/{{YEAR}}');
      expect(
        tester.getSemantics(find.byKey(library)),
        isSemantics(label: 'Library layout', isChecked: false),
      );
    });

    testWidgets(
      'Use the library default from a saved Custom layout: the preset in '
      "force, Custom's field keeps the text, Save waits",
      (tester) async {
        const mine = {
          'vpath': 'copies',
          'base': '',
          'layout': 'From friends/{{ALBUM}}',
        };
        k.fake.destination = {
          ...k.fake.destination,
          'destination': {...mine, 'source': 'user'},
          'saved': mine,
        };
        await openPicker(tester);
        await tapText(tester, 'Use the library default');
        expect(lastPut(), {'destination': null});
        expect(find.byKey(const ValueKey('destination-custom')), findsNothing);
        expect(
          tester.getSemantics(
            find.byKey(
              const ValueKey('destination-layout-{{ALBUMARTIST}}/{{ALBUM}}'),
            ),
          ),
          isSemantics(label: 'Artist / Album', isChecked: true),
        );
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 1, reason: 'nothing changed');
        await tapKey(tester, 'destination-custom-option');
        expect(customField(tester).controller!.text, 'From friends/{{ALBUM}}');
      },
    );

    testWidgets(
      'a variable button with no caret set appends at the end; after an '
      'emoji it lands after the emoji',
      (tester) async {
        const mine = {
          'vpath': 'copies',
          'base': '',
          'layout': 'From friends/{{ALBUM}}',
        };
        k.fake.destination = {
          ...k.fake.destination,
          'destination': {...mine, 'source': 'user'},
          'saved': mine,
        };
        await openPicker(tester);
        final c = customField(tester).controller!;
        expect(customField(tester).focusNode!.hasFocus, isFalse);
        expect(c.selection.isValid, isFalse, reason: 'never focused');
        await tapKey(tester, 'destination-var-YEAR');
        expect(c.text, 'From friends/{{ALBUM}}{{YEAR}}');
        expect(c.selection, const TextSelection.collapsed(offset: 30));

        await typeCustom(tester, '🎵/x');
        c.selection = const TextSelection.collapsed(offset: 2);
        await frames(tester, 2);
        await tapKey(tester, 'destination-var-ARTIST');
        expect(c.text, '🎵{{ARTIST}}/x');
        expect(c.selection, const TextSelection.collapsed(offset: 12));
      },
    );

    testWidgets(
      "a variable button never takes the layout past the server's 500: "
      'one with no room is off',
      (tester) async {
        await openPicker(tester);
        await tapKey(tester, 'destination-custom-option');
        await typeCustom(tester, 'a' * 490);
        void on(String v, bool enabled) => expect(
          tester.getSemantics(find.byKey(ValueKey('destination-var-$v'))),
          isSemantics(isButton: true, isEnabled: enabled),
          reason: v,
        );
        on('ARTIST', true); // 490 + 10 = 500
        on('ALBUMARTIST', false); // 490 + 15
        await tapKey(tester, 'destination-var-ALBUMARTIST');
        expect(customField(tester).controller!.text, 'a' * 490);
        await tapKey(tester, 'destination-var-ARTIST');
        expect(customField(tester).controller!.text, '${'a' * 490}{{ARTIST}}');
        on('YEAR', false);
        expect(
          find.byKey(const ValueKey('destination-custom-invalid')),
          findsNothing,
        );
      },
    );

    testWidgets('saving: the variable buttons are off with the field', (
      tester,
    ) async {
      await openPicker(tester);
      await tapKey(tester, 'destination-custom-option');
      await typeCustom(tester, 'Inbox');
      k.fake.destinationGate = Completer<void>();
      await tapKey(tester, 'destination-save');
      expect(find.text('Saving…'), findsOneWidget);
      expect(customField(tester).enabled, isFalse);
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('destination-var-ARTIST')),
        ),
        isSemantics(isButton: true, isEnabled: false),
      );
      await tester.tap(find.byKey(const ValueKey('destination-var-ARTIST')));
      await tester.pump();
      expect(customField(tester).controller!.text, 'Inbox');
      k.fake.destinationGate!.complete();
      k.fake.destinationGate = null;
      await frames(tester);
      expect(find.text('yours'), findsOneWidget);
    });
  });

  group('the destination picker on its own: its states', () {
    final h = SheetHarness();
    setUp(h.setUp);
    tearDown(h.tearDown);

    const song = DestinationPreviewSong(
      title: 'Rooftop Cypher',
      artist: 'Boukmanflow',
      album: 'Borrowed Tapes',
      year: 2019,
      filepath: 'peerlib/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3',
    );

    Future<void> pumpPicker(
      WidgetTester tester, {
      double width = 390,
      double height = 844,
      double textScale = 1,
      Locale? locale,
      DestinationPreviewSong previewing = song,
    }) => h.pumpHost(
      tester,
      (c) => showDestinationSheet(
        c,
        h.jobs,
        song: previewing,
        peerName: 'Stage Peer B',
      ),
      width: width,
      height: height,
      textScale: textScale,
      locale: locale,
    );

    testWidgets('loading: still blocks, Save off; then the form in place', (
      tester,
    ) async {
      h.fake.destinationGate = Completer<void>();
      await pumpPicker(tester);
      expect(find.byKey(const ValueKey('destination-loading')), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('destination-save')));
      await tester.pump();
      expect(h.fake.count('PUT', _dest), 0);
      h.fake.destinationGate!.complete();
      h.fake.destinationGate = null;
      await KeepHarness.pumpFor(tester);
      expect(find.byKey(const ValueKey('destination-loading')), findsNothing);
      expect(find.text('Rooftop Cypher lands at'), findsOneWidget);
    });

    testWidgets('no library takes new files: one line and Close', (
      tester,
    ) async {
      h.fake.destination = {
        'destination': null,
        'saved': null,
        'libraries': [],
        'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
        'variables': [],
      };
      await pumpPicker(tester);
      expect(
        find.text('No library on your server takes new files'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('destination-form')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('destination-close-blocked')));
      await KeepHarness.pumpFor(tester);
      expect(find.text('Where copies land'), findsNothing);
    });

    testWidgets("uploads off: \"Your account can't add files\"", (
      tester,
    ) async {
      h.server.noUpload = true;
      h.fake.destination = {
        'destination': null,
        'saved': null,
        'libraries': [],
      };
      await pumpPicker(tester);
      expect(
        find.text("Your account can't add files to this server"),
        findsOneWidget,
      );
      expect(
        find.text('No library on your server takes new files'),
        findsNothing,
      );
    });

    testWidgets("a failed read: the sentence, the server's words, Try again", (
      tester,
    ) async {
      h.fake.refuse[_dest] = (500, 'database is locked');
      await pumpPicker(tester);
      expect(find.text("Couldn't load where copies land"), findsOneWidget);
      expect(find.text('database is locked'), findsOneWidget);
      h.fake.refuse.clear();
      await tester.tap(find.byKey(const ValueKey('destination-try-again')));
      await KeepHarness.pumpFor(tester);
      expect(find.text('Rooftop Cypher lands at'), findsOneWidget);
    });

    testWidgets(
      'the keyboard up: the sheet lifts above it and Save stays in reach',
      (tester) async {
        await pumpPicker(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(find.byKey(const ValueKey('destination-base')));
        await KeepHarness.pumpFor(tester);
        expect(tester.takeException(), isNull);
        final save = tester.getRect(
          find.byKey(const ValueKey('destination-save')),
        );
        expect(save.bottom, lessThanOrEqualTo(844 - 300));
        final field = tester.getRect(
          find.byKey(const ValueKey('destination-base')),
        );
        expect(field.bottom, lessThanOrEqualTo(844 - 300));
      },
    );

    testWidgets(
      'Custom with the keyboard up: its field and the variables under it '
      'scroll into view above it',
      (tester) async {
        await pumpPicker(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
        addTearDown(tester.view.resetViewInsets);
        await KeepHarness.pumpFor(tester);
        // Custom's row at the bottom edge, where the thumb finds it: what
        // opens under it starts out of view.
        final option = find.byKey(const ValueKey('destination-custom-option'));
        unawaited(
          Scrollable.ensureVisible(tester.element(option), alignment: 1),
        );
        await KeepHarness.pumpFor(tester);
        // What the form shows between the preview and the footer.
        Rect form() =>
            tester.getRect(find.byKey(const ValueKey('destination-form')));
        expect(form().bottom, lessThanOrEqualTo(844 - 300));
        expect(tester.getRect(option).bottom, moreOrLessEquals(form().bottom));
        await tester.tap(option);
        await KeepHarness.pumpFor(tester);
        expect(tester.takeException(), isNull);
        expect(form().bottom, lessThanOrEqualTo(844 - 300));
        final field = tester.getRect(
          find.byKey(const ValueKey('destination-custom')),
        );
        expect(field.top, greaterThanOrEqualTo(form().top));
        expect(field.bottom, lessThanOrEqualTo(form().bottom));
        final chip = tester.getRect(
          find.byKey(const ValueKey('destination-var-ARTIST')),
        );
        expect(chip.bottom, lessThanOrEqualTo(form().bottom));
        expect(chip.height, greaterThanOrEqualTo(44), reason: 'its target');
        final save = tester.getRect(
          find.byKey(const ValueKey('destination-save')),
        );
        expect(save.bottom, lessThanOrEqualTo(844 - 300));
      },
    );

    testWidgets(
      "a variable this song has no value for: the path without it, and a "
      'note naming it',
      (tester) async {
        await pumpPicker(
          tester,
          previewing: const DestinationPreviewSong(
            title: 'Rooftop Cypher',
            artist: 'Boukmanflow',
            album: 'Borrowed Tapes',
            filepath: 'peerlib/Boukmanflow/01 - Rooftop Cypher.mp3',
          ),
        );
        final option = find.byKey(const ValueKey('destination-custom-option'));
        await tester.ensureVisible(option);
        await tester.pump();
        await tester.tap(option);
        await KeepHarness.pumpFor(tester);
        await tester.enterText(
          find.byKey(const ValueKey('destination-custom')),
          '{{YEAR}}/{{ALBUM}}',
        );
        await KeepHarness.pumpFor(tester, 2);
        tester.testTextInput.hide();
        await KeepHarness.pumpFor(tester, 2);
        expect(
          find.text(
            'No value for this song, so left out of the path: {{YEAR}}',
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('destination-custom')),
          '{{ALBUM}}',
        );
        await KeepHarness.pumpFor(tester, 2);
        expect(
          find.byKey(const ValueKey('destination-preview-missing')),
          findsNothing,
        );
      },
    );

    testWidgets(
      "the server's variables only: its chips, and the unknown variable's "
      'words name only them',
      (tester) async {
        h.fake.destination = {
          ...h.fake.destination,
          'variables': ['ARTIST', 'ALBUM'],
        };
        await pumpPicker(tester);
        final option = find.byKey(const ValueKey('destination-custom-option'));
        await tester.ensureVisible(option);
        await tester.pump();
        await tester.tap(option);
        await KeepHarness.pumpFor(tester);
        expect(find.byKey(const ValueKey('destination-var-ARTIST')), findsOne);
        expect(find.byKey(const ValueKey('destination-var-ALBUM')), findsOne);
        for (final v in ['YEAR', 'GENRE', 'ALBUMARTIST', 'PEER']) {
          expect(
            find.byKey(ValueKey('destination-var-$v')),
            findsNothing,
            reason: v,
          );
        }
        await tester.enterText(
          find.byKey(const ValueKey('destination-custom')),
          '{{ARTST}}',
        );
        await KeepHarness.pumpFor(tester, 2);
        expect(
          find.text('Unknown variable {{ARTST}}. Use ARTIST, ALBUM.'),
          findsOneWidget,
        );
      },
    );

    // Real keyboards, at the sizes people use: the field being typed in
    // stays in the form's view, and nothing overflows.
    for (final (name, width, height, keyboard, scale, locale) in const [
      ('390 × 844, a 336 px keyboard, 1.3×', 390.0, 844.0, 336.0, 1.3, null),
      ('375 × 667, a 260 px keyboard', 375.0, 667.0, 260.0, 1.0, null),
      (
        '360 × 780 German, a 300 px keyboard, 1.3×',
        360.0,
        780.0,
        300.0,
        1.3,
        Locale('de'),
      ),
    ]) {
      testWidgets('the keyboard up on $name: Custom and the base folder in '
          'view', (tester) async {
        await pumpPicker(
          tester,
          width: width,
          height: height,
          textScale: scale,
          locale: locale,
        );
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
        addTearDown(tester.view.resetViewInsets);
        await KeepHarness.pumpFor(tester);
        expect(tester.takeException(), isNull);
        Rect form() =>
            tester.getRect(find.byKey(const ValueKey('destination-form')));
        Future<void> inView(String key) async {
          final field = tester.getRect(find.byKey(ValueKey(key)));
          expect(
            form().height,
            greaterThanOrEqualTo(field.height),
            reason: key,
          );
          expect(
            field.top,
            greaterThanOrEqualTo(form().top - 0.5),
            reason: key,
          );
          expect(
            field.bottom,
            lessThanOrEqualTo(form().bottom + 0.5),
            reason: key,
          );
          expect(form().bottom, lessThanOrEqualTo(height - keyboard));
        }

        final option = find.byKey(const ValueKey('destination-custom-option'));
        await tester.ensureVisible(option);
        await tester.pump();
        await tester.tap(option);
        await KeepHarness.pumpFor(tester);
        expect(tester.takeException(), isNull);
        await inView('destination-custom');
        await tester.enterText(
          find.byKey(const ValueKey('destination-custom')),
          '{{ARTST}}',
        );
        await KeepHarness.pumpFor(tester);
        expect(tester.takeException(), isNull);
        await inView('destination-custom');

        await tester.showKeyboard(
          find.byKey(const ValueKey('destination-base')),
        );
        await KeepHarness.pumpFor(tester);
        expect(tester.takeException(), isNull);
        await inView('destination-base');
        expect(
          tester.getRect(find.byKey(const ValueKey('destination-save'))).bottom,
          lessThanOrEqualTo(height - keyboard),
        );
      });
    }

    testWidgets('320 px at 1.3×: the variable buttons fit', (tester) async {
      await pumpPicker(tester, width: 320, height: 700, textScale: 1.3);
      final option = find.byKey(const ValueKey('destination-custom-option'));
      await tester.ensureVisible(option);
      await tester.pump();
      await tester.tap(option);
      await KeepHarness.pumpFor(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('destination-var-ALBUMARTIST')),
        findsOneWidget,
      );
    });

    testWidgets('German at 1.3× on 360 px: nothing overflows', (tester) async {
      await pumpPicker(
        tester,
        width: 360,
        height: 780,
        textScale: 1.3,
        locale: const Locale('de'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Wo Kopien landen'), findsOneWidget);
      expect(find.text('Bibliotheksstandard'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('destination-form')),
        const Offset(0, -400),
      );
      await KeepHarness.pumpFor(tester);
      expect(tester.takeException(), isNull);
      // Custom open, a refusal under it.
      final option = find.byKey(const ValueKey('destination-custom-option'));
      await tester.ensureVisible(option);
      await tester.pump();
      await tester.tap(option);
      await KeepHarness.pumpFor(tester);
      expect(find.text('Eigenes'), findsOneWidget);
      expect(find.text('Eigenen Pfad eingeben'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('destination-custom')),
        'Von Freunden/{{ARTST}}',
      );
      await KeepHarness.pumpFor(tester);
      expect(
        find.text(
          'Unbekannte Variable {{ARTST}}. Verwende ARTIST, ALBUM, YEAR, '
          'GENRE, ALBUMARTIST, PEER.',
        ),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('destination-form')),
        const Offset(0, -400),
      );
      await KeepHarness.pumpFor(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Open elsewhere', () {
    final links = [
      {
        'id': 'musicbrainz-recording',
        'label': 'MusicBrainz recording',
        'url': 'https://musicbrainz.org/recording/abc',
        'kind': 'canonical',
      },
      {
        'id': 'musicbrainz-release-group',
        'label': 'MusicBrainz release group',
        'url': 'https://musicbrainz.org/release-group/def',
        'kind': 'canonical',
      },
      {
        'id': 'musicbrainz-search',
        'label': 'Search MusicBrainz',
        'url': 'https://musicbrainz.org/search?query=x',
        'kind': 'search',
      },
      {
        'id': 'deezer-search',
        'label': 'Search Deezer',
        'url':
            'https://www.deezer.com/search/Boukmanflow%20Late%20Train%20Verse',
        'kind': 'search',
      },
      {
        'id': 'youtube-search',
        'label': 'Search YouTube',
        'url': 'https://www.youtube.com/results?search_query=x',
        'kind': 'search',
      },
      {
        'id': 'some-new-search',
        'label': 'Search Elsewhere FM',
        'url': 'https://elsewhere.example/search?q=x',
        'kind': 'search',
      },
    ];

    Future<void> openElsewhere(WidgetTester tester) async {
      await k.pumpDiscover(tester);
      await tester.longPress(find.text('Late Train Verse'));
      await frames(tester, 8);
      await tapText(tester, 'Open elsewhere');
      await frames(tester, 4);
    }

    testWidgets(
      'asked only when tapped, the row unchanged; loading keeps the list\'s '
      'shape; exact pages first, then searches',
      (tester) async {
        k.fake.links = links;
        k.fake.linksGate = Completer<void>();
        await k.pumpDiscover(tester);
        await tester.longPress(find.text('Late Train Verse'));
        await frames(tester, 8);
        expect(k.fake.count('POST', _resolve), 0, reason: 'never prefetched');
        await tapText(tester, 'Open elsewhere');
        await frames(tester, 2);
        expect(find.byKey(const ValueKey('elsewhere-loading')), findsOneWidget);
        expect(find.text('Late Train Verse · Boukmanflow'), findsOneWidget);
        final body =
            jsonDecode(k.fake.calls('POST', _resolve).single.body) as Map;
        expect(
          body['recommendation'],
          jsonDecode(jsonEncode(k.lead('Late Train Verse').raw)),
        );
        k.fake.linksGate!.complete();
        k.fake.linksGate = null;
        await frames(tester);
        expect(find.text('EXACT PAGES'), findsOneWidget);
        expect(find.text('SEARCH'), findsOneWidget);
        expect(find.text('MusicBrainz recording'), findsOneWidget);
        expect(find.text('MusicBrainz release group'), findsOneWidget);
        expect(find.text('MusicBrainz'), findsOneWidget);
        expect(find.text('Deezer'), findsOneWidget);
        expect(find.text('YouTube'), findsOneWidget);
        expect(
          find.text('Search Elsewhere FM'),
          findsOneWidget,
          reason: "the plug-in's own label",
        );
        expect(
          tester.getTopLeft(find.text('MusicBrainz release group')).dy,
          lessThan(tester.getTopLeft(find.text('Deezer')).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a row opens outside the app; one that will not says so and '
        'the sheet stays', (tester) async {
      k.fake.links = links;
      final opened = <Uri>[];
      var ok = true;
      elsewhereLaunch = (uri) async {
        opened.add(uri);
        return ok;
      };
      await openElsewhere(tester);
      await tapText(tester, 'Deezer');
      expect(
        opened.single.toString(),
        'https://www.deezer.com/search/Boukmanflow%20Late%20Train%20Verse',
      );
      expect(toasts, isEmpty);
      ok = false;
      await tapText(tester, 'YouTube');
      expect(toasts, ["Couldn't open that link"]);
      expect(find.text('EXACT PAGES'), findsOneWidget, reason: 'still open');
    });

    testWidgets('empty: one sentence and Close', (tester) async {
      k.fake.links = [];
      await openElsewhere(tester);
      expect(find.text('No links for this song'), findsOneWidget);
      expect(
        find.text(
          'It has no MusicBrainz ids, and no title or artist to search for.',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'elsewhere-close-empty');
      await frames(tester, 6);
      expect(find.text('No links for this song'), findsNothing);
      expect(
        find.text('KEEP A COPY'),
        findsOneWidget,
        reason: 'back on the song sheet',
      );
    });

    testWidgets("the server's error verbatim, Try again", (tester) async {
      k.fake.links = links;
      k.fake.refuse[_resolve] = (
        502,
        'plug-in links could not resolve this recommendation',
      );
      await openElsewhere(tester);
      expect(find.text("Couldn't look up links right now"), findsOneWidget);
      expect(
        find.text('plug-in links could not resolve this recommendation'),
        findsOneWidget,
      );
      k.fake.refuse.clear();
      await tapKey(tester, 'elsewhere-try-again');
      expect(find.text('Deezer'), findsOneWidget);
    });

    testWidgets('an error with no words of the server: only the first line', (
      tester,
    ) async {
      k.fake.refuse[_resolve] = (502, '');
      await openElsewhere(tester);
      expect(find.text("Couldn't look up links right now"), findsOneWidget);
      expect(find.textContaining('HTTP'), findsNothing);
    });

    testWidgets('German at 1.3× on 360 px', (tester) async {
      k.fake.links = links;
      await k.pumpDiscover(
        tester,
        width: 360,
        height: 2400,
        textScale: 1.3,
        locale: const Locale('de'),
      );
      await tester.longPress(find.text('Late Train Verse'));
      await frames(tester, 8);
      await tapText(tester, 'Woanders öffnen');
      await frames(tester, 4);
      expect(tester.takeException(), isNull);
      expect(find.text('GENAUE SEITEN'), findsOneWidget);
      expect(find.text('MusicBrainz-Aufnahme'), findsOneWidget);
    });
  });
}
