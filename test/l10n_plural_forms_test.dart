// Plural categories in the locale ARBs.
//
// gen-l10n turns an ARB "=1{...}" case into intl's `one:` argument, and intl
// picks `one` by the LOCALE's CLDR rule, not by the literal number: Russian
// "one" covers 1, 21, 31, …; French and Brazilian Portuguese "one" covers 0
// and 1. So a Russian "=1{1 трек}" rendered "1 трек" for 21 tracks, and a
// French "=1{1 piste}" rendered "1 piste" for an empty count. The ARBs now
// spell those cases as "one{{count} …}" and give Russian and Polish all of
// one/few/many/other; this pins that down for every locale.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/l10n/app_localizations.dart';

void main() {
  AppLocalizations l(String code) => lookupAppLocalizations(Locale(code));

  test('Russian: one / few / many by CLDR, including 21 and 11', () {
    final ru = l('ru');
    expect(ru.p2pTracksCount(1), '1 трек');
    expect(ru.p2pTracksCount(21), '21 трек');
    expect(ru.p2pTracksCount(3), '3 трека');
    expect(ru.p2pTracksCount(5), '5 треков');
    expect(ru.p2pTracksCount(11), '11 треков');
    expect(ru.federationInDays(22), 'через 22 дня');
    expect(ru.federationInboxBanner(31), '31 запрос объединения ожидает');
  });

  test('Polish: few is 2–4 and 22–24, many is 5+', () {
    final pl = l('pl');
    expect(pl.p2pNeighborsCount(1), '1 sąsiad');
    expect(pl.p2pNeighborsCount(2), '2 sąsiedzi');
    expect(pl.p2pNeighborsCount(5), '5 sąsiadów');
    expect(pl.p2pNeighborsCount(22), '22 sąsiedzi');
    expect(pl.federationDays(12), '12 dni');
  });

  test('French and Portuguese: zero takes the singular form, not "1"', () {
    expect(l('fr').mainQueueCount(0), '0 morceau');
    expect(l('fr').mainQueueCount(1), '1 morceau');
    expect(l('fr').mainQueueCount(2), '2 morceaux');
    expect(l('pt').p2pNeighborsCount(0), '0 vizinho');
    expect(l('pt').p2pNeighborsCount(1), '1 vizinho');
    expect(l('pt').p2pNeighborsCount(2), '2 vizinhos');
    // The listening-history counts.
    expect(l('fr').listeningPlays(0), '0 lecture');
    expect(l('fr').listeningPlays(21), '21 lectures');
    expect(l('fr').songInfoDevicePlays(0), '0 lecture sur ce téléphone');
    expect(l('pt').listeningTracksCount(0), '0 faixa');
    expect(l('pt').listeningTracksCount(1), '1 faixa');
    expect(l('pt').songInfoServerPlays(0, 'x'), '0 reprodução em x');
  });

  test('every locale keeps the number in a count of 21 and of 0', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final t = l(locale.languageCode);
      for (final f in <String Function(int)>[
        t.mainQueueCount,
        t.p2pTracksCount,
        t.p2pNeighborsCount,
        t.federationDays,
        t.storageItemCount,
        t.agoMinutes,
        t.federationStreamsCount,
        t.listeningPlays,
        t.listeningTracksCount,
        t.listeningDays,
        t.listeningUnsynced,
        t.songInfoDevicePlays,
      ]) {
        expect(f(21), contains('21'), reason: '$locale ${f(21)}');
        expect(f(0), contains('0'), reason: '$locale ${f(0)}');
      }
    }
  });
}
