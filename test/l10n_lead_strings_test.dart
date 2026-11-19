// The network-lead sheet's English strings (the network-song sheet on More
// like this: previews, the YouTube card, its job line, the Copies rows and
// toasts for a YouTube add).
//
// They read app_en.arb itself, as l10n_ytdl_strings_test.dart does: every
// key has a description and declares exactly the placeholders its message
// uses; no message says "download" (saving to this phone everywhere else in
// the app — an add goes to the user's server); apostrophes stay straight.
// And they pin the parts an ARB edit breaks most easily: the curly quotes
// around titles and queries, the ' · ' separator, the counts.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';

/// Every key the network-lead sheet added.
const leadKeys = [
  'discoverLeadPinned',
  'discoverLeadMatchTo',
  'discoverLeadMatch',
  'discoverLeadCopyTitle',
  'discoverLeadPreviewLabel',
  'discoverLeadPreviewTap',
  'discoverLeadPreviewLookingUp',
  'discoverLeadPreviewNone',
  'discoverLeadPreviewBusy',
  'discoverLeadPreviewUnavailable',
  'discoverLeadPreviewProgress',
  'discoverLeadPreviewPlayA11y',
  'discoverLeadPreviewStopA11y',
  'discoverLeadPreviewOpenIn',
  'discoverLeadMatchPill',
  'discoverLeadLooseMatchPill',
  'discoverLeadYtIdle',
  'discoverLeadYtSearch',
  'discoverLeadYtSearchingTag',
  'discoverLeadYtAsking',
  'discoverLeadYtStopWaiting',
  'discoverLeadYtSlowHint',
  'discoverLeadYtFound',
  'discoverLeadYtMore',
  'discoverLeadYtFewer',
  'discoverLeadYtUploadsA11y',
  'discoverLeadYtOpenOnYoutube',
  'discoverLeadYtAddThis',
  'discoverLeadYtOnlyPick',
  'discoverLeadYtNothing',
  'discoverLeadYtSearchAgain',
  'discoverLeadYtBusy',
  'discoverLeadYtCouldnt',
  'discoverLeadYtTimedOut',
  'discoverLeadYtSomeoneElse',
  'discoverLeadYtQueueFull',
  'discoverLeadYtQueueFullNoCount',
  'discoverLeadYtStartFailed',
  'discoverLeadYtAlreadyAdding',
  'discoverLeadAddOff',
  'discoverLeadOptionOff',
  'discoverJobYtChecking',
  'discoverJobYtSearching',
  'discoverJobYtFetching',
  'discoverJobYtFetchingPercent',
  'discoverJobYtTagging',
  'discoverJobYtFiling',
  'discoverJobYtFromChannel',
  'discoverJobAddFailed',
  'discoverJobYtCancelled',
  'discoverJobYtChooseAnother',
  'discoverJobYtErrBroken',
  'discoverJobYtErrNotClose',
  'discoverJobYtErrNoResults',
  'discoverJobYtErrLive',
  'discoverJobYtErrTooBig',
  'discoverJobYtErrTooBigNoSize',
  'discoverJobYtErrUnreadable',
  'discoverJobYtErrTooLong',
  'discoverJobYtErrRefused',
  'discoverJobYtErrNoTitle',
  'discoverJobYtErrNoLibrary',
  'discoverJobYtErrLayout',
  'discoverJobYtErrAccountGone',
  'discoverJobYtErrOther',
  'discoverToastAddingYt',
  'discoverToastAddFailedYt',
  'discoverCopiesDestChangedYt',
  'discoverLeadYtChangeHint',
];

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('the app_en.arb entries', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;

    test('every key is there once, has a description and declares the placeholders it uses', () {
      expect(leadKeys.toSet(), hasLength(leadKeys.length));
      final argument = RegExp(r'\{\s*([A-Za-z_]\w*)\s*[},]');
      for (final k in leadKeys) {
        expect(arb[k], isA<String>(), reason: k);
        final meta = arb['@$k'] as Map<String, dynamic>?;
        expect(meta?['description'], isA<String>(), reason: k);
        final placeholders =
            (meta?['placeholders'] as Map<String, dynamic>?) ?? const {};
        final used = {
          for (final m in argument.allMatches(arb[k] as String)) m[1]!,
        };
        expect(used, placeholders.keys.toSet(), reason: k);
        // Counts and percentages are typed numbers, grouped the locale's way.
        for (final p in placeholders.entries) {
          final type = (p.value as Map)['type'];
          if (const {'count', 'percent', 'size'}.contains(p.key)) {
            expect([type, (p.value as Map)['format']], ['int', 'decimalPattern'], reason: '$k ${p.key}');
          } else {
            expect(type, 'String', reason: '$k ${p.key}');
          }
        }
      }
    });

    test('no message says download, and apostrophes stay straight', () {
      for (final k in leadKeys) {
        final message = arb[k] as String;
        expect(message.toLowerCase(), isNot(contains('download')), reason: k);
        expect(message, isNot(contains('’')), reason: k);
      }
    });

    test('plurals use one{{count} …}, never =1 (a CLDR "one" is not always 1)', () {
      for (final k in leadKeys) {
        expect(arb[k] as String, isNot(contains('=1{')), reason: k);
      }
    });
  });

  group('the words on screen', () {
    test('queries and the seed sit in curly quotes', () {
      expect(en.discoverLeadMatchTo(88, 'Tidewater'), '88% match to “Tidewater”');
      expect(en.discoverLeadYtIdle('Static Bloom Paper Satellites'),
          'Finds the closest upload for “Static Bloom Paper Satellites” · nothing is added yet');
      expect(en.discoverLeadYtAsking('Static Bloom Paper Satellites'), 'Asking YouTube for “Static Bloom Paper Satellites”…');
      expect(en.discoverLeadYtNothing('Static Bloom Paper Satellites'), 'YouTube has nothing close to “Static Bloom Paper Satellites”');
      expect(en.discoverJobYtErrNoResults('Static Bloom Paper Satellites'),
          'YouTube found nothing for “Static Bloom Paper Satellites”.');
    });

    test('the counts', () {
      expect(en.discoverLeadYtFound(1), '1 upload found');
      expect(en.discoverLeadYtFound(5), '5 uploads found · pick one');
      expect(en.discoverLeadYtMore(4), '4 more');
      expect(en.discoverLeadYtQueueFull(20), 'You have 20 waiting or running — let some finish first.');
      expect(en.discoverJobYtErrTooBig(1000), 'That upload is bigger than this server allows (1,000 MB).');
    });

    test('the lines the plan fixes, as the screens build them', () {
      expect(en.discoverLeadMatch(88), '88% match');
      expect(en.discoverLeadPreviewProgress('0:12', '0:30'), '0:12 of 0:30');
      expect(en.discoverLeadPreviewPlayA11y('Deezer'), 'Play the Deezer preview');
      expect(en.discoverLeadPreviewOpenIn('Apple Music'), 'Open in Apple Music');
      expect(en.discoverLeadMatchPill(91), 'match 91%');
      expect(en.discoverLeadLooseMatchPill(48), 'loose match 48%');
      expect(en.discoverJobYtFetchingPercent(42), 'Fetching from YouTube · 42%');
      expect(en.discoverJobYtFromChannel('Static Bloom - Topic'), 'from Static Bloom - Topic');
      expect(en.discoverJobYtCancelled, 'Stopped · nothing was added');
      expect(en.discoverJobYtErrNotClose(48), 'Nothing on YouTube was close enough (best match 48%).');
      expect(en.discoverToastAddingYt('Paper Satellites'), 'Adding Paper Satellites from YouTube');
      expect(en.discoverToastAddFailedYt(en.discoverJobYtErrLive),
          "Couldn't add from YouTube: That upload is a live stream — pick another.");
      expect(en.discoverLeadYtChangeHint, 'Change where added songs go');
    });
  });

  // The sheet's close toast ("Adding … from YouTube") and Copies' YouTube
  // toast carry View: never English in another language.
  test('View on the start toasts is in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final t = lookupAppLocalizations(locale);
      expect(t.discoverToastView, isNot(en.discoverToastView), reason: '$locale');
    }
  });
}
