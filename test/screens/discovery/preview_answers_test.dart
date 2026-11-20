// The preview answers a Peer Recommendations visit shares with the
// network-lead sheets it opens (mStream plan §2 item 15): found or none
// per lead and plug-in, a change told once, a clip that would not play
// forgotten, the newest 200 leads kept (webapp vp.js CLIP_RESULTS_MAX), and
// never disposed — a sheet still open once its visit has gone may still
// answer into it.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/screens/discovery/preview_answers.dart';

PluginPreview clip({
  String provider = 'deezer',
  String url = 'https://cdns-preview.dzcdn.net/stream/highway.mp3',
  String? title = 'Highway',
}) => PluginPreview(provider: provider, url: Uri.parse(url), title: title);

void main() {
  test('put, of, answersFor: found or none per lead and plug-in', () {
    final answers = PreviewAnswers();
    expect(answers.of('a', 'deezer'), isNull);
    expect(answers.answersFor('a'), isEmpty);

    answers.put('a', 'deezer', clip());
    answers.put('a', 'itunes', null);
    answers.put('b', 'deezer', null);
    expect(answers.of('a', 'deezer')!.found!.title, 'Highway');
    expect(answers.of('a', 'deezer')!.none, isFalse);
    expect(answers.of('a', 'itunes')!.none, isTrue);
    expect(answers.of('b', 'deezer')!.none, isTrue);
    expect(answers.of('b', 'itunes'), isNull);
    expect(answers.answersFor('a').keys, ['deezer', 'itunes']);
    expect(answers.length, 2);
    expect(
      () => answers.answersFor('a')['x'] = const PreviewAnswer(null),
      throwsUnsupportedError,
      reason: 'read only',
    );

    // A later answer replaces the earlier one.
    answers.put('b', 'deezer', clip(title: 'Highway (live)'));
    expect(answers.of('b', 'deezer')!.found!.title, 'Highway (live)');
  });

  test('notifies only when an answer changed', () {
    final answers = PreviewAnswers();
    var told = 0;
    answers.addListener(() => told++);
    answers.put('a', 'deezer', clip());
    expect(told, 1);
    answers.put('a', 'deezer', clip()); // the same clip, asked again
    expect(told, 1);
    answers.put('a', 'itunes', null);
    answers.put('a', 'itunes', null);
    expect(told, 2);
    answers.put('a', 'itunes', clip(provider: 'itunes'));
    answers.put('a', 'deezer', clip(url: 'https://cdns-preview.dzcdn.net/b'));
    expect(told, 4);
  });

  // Round 3's W4: a found clip that would not play (a Deezer address that
  // expired) is dropped, so every surface asks again on its next press.
  test('forget drops a found answer only while it holds that address, and '
      'tells once', () {
    final answers = PreviewAnswers();
    var told = 0;
    answers.addListener(() => told++);
    final dead = clip(url: 'https://cdns-preview.dzcdn.net/stream/expired.mp3');
    answers
      ..put('a', 'deezer', dead)
      ..put('a', 'itunes', null)
      ..put('b', 'deezer', clip());
    expect(told, 3);

    // Another address, a none, a plug-in or lead with no answer: nothing.
    expect(
      answers.forget(
        'a',
        'deezer',
        Uri.parse('https://cdns-preview.dzcdn.net/stream/fresh.mp3'),
      ),
      isFalse,
    );
    expect(answers.forget('a', 'itunes', dead.url), isFalse);
    expect(answers.forget('a', 'youtube', dead.url), isFalse);
    expect(answers.forget('c', 'deezer', dead.url), isFalse);
    expect(told, 3);
    expect(answers.of('a', 'deezer')!.found!.url, dead.url);

    expect(answers.forget('a', 'deezer', dead.url), isTrue);
    expect(told, 4);
    expect(answers.of('a', 'deezer'), isNull);
    expect(answers.of('a', 'itunes')!.none, isTrue, reason: 'others kept');
    expect(answers.forget('a', 'deezer', dead.url), isFalse, reason: 'once');
    expect(told, 4);

    // A lead's last answer: the lead goes too.
    expect(answers.forget('b', 'deezer', clip().url), isTrue);
    expect(answers.answersFor('b'), isEmpty);
    expect(answers.length, 1);

    // The plug-in's next 200 is kept as any answer is.
    answers.put('a', 'deezer', clip());
    expect(answers.of('a', 'deezer')!.found!.url, clip().url);
    expect(told, 6);
  });

  test('clear forgets every answer, and tells only when it held any', () {
    final answers = PreviewAnswers();
    var told = 0;
    answers.addListener(() => told++);
    answers.clear();
    expect(told, 0);
    answers.put('a', 'deezer', null);
    answers.clear();
    expect(told, 2);
    expect(answers.of('a', 'deezer'), isNull);
    expect(answers.length, 0);
  });

  test('the cap keeps the newest 200 leads: the lead first answered goes '
      'first; a lead answered again keeps its place', () {
    final answers = PreviewAnswers();
    expect(answers.cap, 200);
    for (var i = 0; i < 200; i++) {
      answers.put('lead-$i', 'deezer', null);
    }
    answers.put('lead-0', 'itunes', null); // the oldest, answered again
    expect(answers.length, 200);

    answers.put('lead-200', 'deezer', null);
    expect(answers.length, 200);
    expect(answers.answersFor('lead-0'), isEmpty, reason: 'its whole lead');
    expect(answers.of('lead-1', 'deezer'), isNotNull);
    expect(answers.of('lead-200', 'deezer'), isNotNull);

    final small = PreviewAnswers(cap: 2)
      ..put('a', 'deezer', null)
      ..put('b', 'deezer', null)
      ..put('c', 'deezer', null);
    expect(small.of('a', 'deezer'), isNull);
    expect([small.of('b', 'deezer'), small.of('c', 'deezer')], everyElement(isNotNull));
  });

  test('a put after every listener left (the visit gone, a sheet still '
      'open) does not throw', () {
    final answers = PreviewAnswers();
    void page() {}
    answers.addListener(page);
    answers.put('a', 'deezer', null);
    answers.removeListener(page);
    expect(() => answers.put('a', 'deezer', clip()), returnsNormally);
    expect(answers.forget('a', 'deezer', clip().url), isTrue);
    answers.put('a', 'deezer', clip());
    expect(() => answers.clear(), returnsNormally);
    expect(answers.length, 0);
  });
}
