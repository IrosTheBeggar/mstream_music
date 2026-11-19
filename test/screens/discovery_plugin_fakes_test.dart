// The scripted plug-in server (discovery_plugin_fakes.dart) through the real
// DiscoveryPluginsApi: the routes the network-lead sheet's tests lean on —
// the preview and YouTube resolves, any plug-in's start (matched on its whole
// path), the single lookup, one job — answer as the server's do.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/discovery_plugins_api.dart';

import 'discovery_plugin_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePluginServer fake;
  late DiscoveryPluginsApi api;
  const rec = {
    'artist': 'Static Bloom',
    'title': 'Paper Satellites',
    'album': 'Tidewater',
    'peer': {'endpointId': 'ep1', 'name': 'Vinyl Vault'},
    'source': 'p2p',
  };
  const pick = {'url': 'https://www.youtube.com/watch?v=abc123'};

  setUp(() {
    fake = FakePluginServer();
    api = fake.api(Server('http://home.local:3000', null, null, 'JWT', 'home'));
  });

  test("the lead plug-ins listed beside the default two", () async {
    fake.listLeadPlugins(itunes: false);
    final l = await api.plugins();
    expect([for (final p in l.plugins) p.name], ['links', 'federation-copy', 'youtube', 'deezer']);
    expect([l.youtube?.name, [for (final p in l.previews) p.name]], ['youtube', ['deezer']]);
  });

  test('a preview resolve: none by default, the clip set for its plug-in; a gate holds it', () async {
    expect(await api.preview('deezer', rec), isNull);
    fake.previews['itunes'] = {'provider': 'itunes', 'url': 'https://audio-ssl.itunes.apple.com/x.m4a', 'seconds': 30, 'attribution': 'Provided courtesy of iTunes', 'match': 0.9};
    expect((await api.preview('itunes', rec))?.attribution, 'Provided courtesy of iTunes');
    expect(fake.resolves('itunes').single, {'recommendation': rec});
    final gate = fake.resolveGates['deezer'] = Completer<void>();
    var done = false;
    final asked = api.preview('deezer', rec).then((_) => done = true);
    await settle();
    expect(done, isFalse);
    gate.complete();
    await asked;
    expect(done, isTrue);
  });

  test("the YouTube search: the row's phrase, the candidates set, or the library's own copy instead", () async {
    fake.youtubeCandidates = [
      {'id': 'abc123', 'url': pick['url'], 'title': 'Paper Satellites', 'channel': 'Static Bloom - Topic', 'durationSec': 238, 'thumbnail': null, 'topic': true, 'score': 0.93},
    ];
    final s = await api.searchYoutube(rec);
    expect([s.query, s.minScore, s.candidates.single.url, s.owned], ['Static Bloom Paper Satellites', 0.62, pick['url'], false]);
    fake.youtubeOwned = {'vpath': 'music', 'filepath': 'music/Static Bloom/Paper Satellites.flac', 'by': 'tags'};
    final owned = await api.searchYoutube(rec);
    expect([owned.ownedFilepath, owned.candidates], ['music/Static Bloom/Paper Satellites.flac', isEmpty]);
  });

  test("a start on its plug-in's own path: a YouTube add keeps its pick; the copy takes none; refusals are per plug-in", () async {
    final yt = await api.startJob(rec, plugin: kYoutubePlugin, choice: pick, destination: ShownPlace(CollectionDestination.fromServerMap(fake.destination['destination'])));
    expect([yt.created, yt.job.plugin, yt.job.choiceUrl, yt.job.destination?.vpath], [true, 'youtube', pick['url'], 'copies']);
    expect(fake.starts('youtube').single['choice'], pick);
    expect(fake.starts('federation-copy'), isEmpty);
    expect(fake.count('POST', '/plugins/federation-copy/jobs'), 0);

    await expectLater(api.startJob(rec, choice: pick),
        throwsA(isA<DiscoveryPluginsException>().having((e) => e.status, 'status', 400)), reason: 'no lookup, no choice');
    await expectLater(api.startJob(rec, plugin: kYoutubePlugin, choice: {'url': 'https://vimeo.com/1'}),
        throwsA(isA<DiscoveryPluginsException>().having((e) => e.message, 'message', 'the chosen upload must be a YouTube link')));

    fake.refuse['/plugins/youtube/jobs'] = (429, 'you have 20 jobs queued or running — wait for some to finish (the limit is 20)');
    await expectLater(api.startJob(rec, plugin: kYoutubePlugin, choice: pick),
        throwsA(isA<DiscoveryPluginsException>().having((e) => e.status, 'status', 429)));
    final copy = await api.startJob(rec);
    expect([copy.created, copy.job.plugin, copy.job.choice], [true, 'federation-copy', null], reason: "the YouTube refusal is YouTube's alone");
  });

  test('the single lookup and one job: the newest job per plug-in under the song key', () async {
    final copy = fake.addJob(rec, state: 'done');
    final older = fake.addJob(rec, plugin: 'youtube', state: 'failed', error: 'Nothing matched closely enough (best score 0.48, needs 0.62)');
    final newer = fake.addJob(rec, plugin: 'youtube', state: 'running', choice: pick, statusText: '42% of “Paper Satellites”', progress: 0.436);
    final l = await api.lookupOne(rec);
    expect(l.key, fakeKeysOf(rec)['song']);
    expect([for (final j in l.jobs) j.id], [newer['id'], copy['id']]);
    expect(l.jobs.first.choiceUrl, pick['url']);
    final one = await api.job(older['id'] as int);
    expect([one.plugin, one.state, one.error], ['youtube', JobState.failed, 'Nothing matched closely enough (best score 0.48, needs 0.62)']);
    await expectLater(api.job(9999), throwsA(isA<DiscoveryPluginsException>().having((e) => e.status, 'status', 404)));
  });
}
