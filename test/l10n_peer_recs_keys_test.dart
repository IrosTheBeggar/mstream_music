// The Peer Recommendations page's strings (the page, its peer strip, its
// cards, the preview band and the home card; mStream plan §4.2 Strings).
//
// They read the ARBs themselves, as l10n_lead_strings_test.dart does: every
// key has a description and declares exactly the placeholders its message
// uses, typed String; no message says "download"; English apostrophes stay
// straight. The nine other languages are the webapp's reviewed strings
// (webapp/locales/*.json nav.peerRecs, peerRecs.*, peerRecs.a11y.*), so each
// must carry every key, non-empty, with the same placeholder names. One
// differs on purpose: peerRecsAdding in German, Spanish, Polish, Portuguese
// and Russian is a shorter word than the webapp's peerRecs.adding, so that
// it fits the phone strip's 68 px item whole
// (screens/discovery/peer_recs_strip_locale_test.dart).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';

/// Every key the Peer Recommendations page added.
const peerRecsKeys = [
  'peerRecsTitle',
  'peerRecsAll',
  'peerRecsAdding',
  'peerRecsNoRoom',
  'peerRecsNoPeers',
  'peerRecsNothingNew',
  'peerRecsPreviewAll',
  'peerRecsCopyList',
  'peerRecsCopied',
  'peerRecsNoPreview',
  'peerRecsPeers',
  'peerRecsOffline',
  'peerRecsAddPeer',
  'peerRecsPreviewTrack',
  'peerRecsPauseTrack',
  'peerRecsNextPreview',
];

const locales = ['de', 'en', 'es', 'fr', 'it', 'ja', 'pl', 'pt', 'ru', 'zh'];

final argument = RegExp(r'\{\s*([A-Za-z_]\w*)\s*[},]');

Set<String> argumentsOf(String message) =>
    {for (final m in argument.allMatches(message)) m[1]!};

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final text = {
    for (final l in locales) l: File('lib/l10n/app_$l.arb').readAsStringSync(),
  };
  final arbs = {
    for (final l in locales)
      l: jsonDecode(text[l]!) as Map<String, dynamic>,
  };
  final arb = arbs['en']!;

  group('the app_en.arb entries', () {
    test('every peerRecs key is in app_en.arb once, with a description and exactly its placeholders, typed String', () {
      expect(peerRecsKeys.toSet(), hasLength(peerRecsKeys.length));
      // The list is the whole set: no peerRecs key is left out of it.
      expect(
          arb.keys.where((k) => k.startsWith('peerRecs')).toSet(), peerRecsKeys.toSet());
      for (final k in peerRecsKeys) {
        // jsonDecode keeps the last of two equal keys, so count the text.
        expect('"$k":'.allMatches(text['en']!), hasLength(1), reason: k);
        expect('"@$k":'.allMatches(text['en']!), hasLength(1), reason: k);
        expect(arb[k], isA<String>(), reason: k);
        final meta = arb['@$k'] as Map<String, dynamic>?;
        expect(meta?['description'], isA<String>(), reason: k);
        expect((meta!['description'] as String).trim(), isNotEmpty, reason: k);
        final placeholders =
            (meta['placeholders'] as Map<String, dynamic>?) ?? const {};
        expect(argumentsOf(arb[k] as String), placeholders.keys.toSet(), reason: k);
        for (final p in placeholders.entries) {
          expect((p.value as Map)['type'], 'String', reason: '$k ${p.key}');
        }
      }
    });

    test('no message says download; EN apostrophes straight', () {
      for (final k in peerRecsKeys) {
        final message = arb[k] as String;
        expect(message.toLowerCase(), isNot(contains('download')), reason: k);
        expect(message, isNot(contains('’')), reason: k);
      }
    });
  });

  test('every key is present and non-empty in all 10 ARBs with the same placeholder names', () {
    expect(AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        locales.toSet());
    for (final l in locales) {
      for (final k in peerRecsKeys) {
        expect('"$k":'.allMatches(text[l]!), hasLength(1), reason: '$l $k');
        final message = arbs[l]![k];
        expect(message, isA<String>(), reason: '$l $k');
        expect((message as String).trim(), isNotEmpty, reason: '$l $k');
        expect(argumentsOf(message), argumentsOf(arb[k] as String), reason: '$l $k');
      }
    }
  });

  group('the words on screen', () {
    test('the a11y lines as built', () {
      expect(en.peerRecsAddPeer('Lighthouse Tapes'), 'Add Lighthouse Tapes');
      expect(en.peerRecsPauseTrack('Signal Fires'), 'Pause preview of Signal Fires');
      expect(en.peerRecsPreviewTrack('Signal Fires'), 'Preview Signal Fires');
      expect(en.peerRecsNextPreview, 'Next preview');
      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(ja.peerRecsAddPeer('Lighthouse Tapes'), 'Lighthouse Tapesを追加');
      expect(ja.peerRecsPauseTrack('Signal Fires'), 'Signal Firesの試聴を一時停止');
    });

    // The strip reads "label, offline" with the same word the P2P screen's
    // "offline {ago}" uses in each language.
    test('a peer is offline in the P2P screen\'s words', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final t = lookupAppLocalizations(locale);
        expect(t.p2pOfflineFor(''), contains(t.peerRecsOffline), reason: '$locale');
      }
    });
  });

  // The page's toolbar and the home card: never English in another language.
  test('no locale leaves peerRecsTitle in English', () {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final t = lookupAppLocalizations(locale);
      expect(t.peerRecsTitle, isNot(en.peerRecsTitle), reason: '$locale');
    }
  });
}
