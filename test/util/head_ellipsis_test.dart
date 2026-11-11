// util/head_ellipsis.dart — the explorer's path strip cut from its head: the
// folder you are in is the part that matters.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/head_ellipsis.dart';

void main() {
  // A strip that fits [n] characters (the UI measures with a TextPainter).
  bool Function(String) width(int n) => (s) => s.length <= n;
  const path = '/music/Various Artists/Night Market Sampler/';

  test('whole when it fits', () {
    expect(headEllipsis(path, width(80)), const HeadEllipsis(path));
    expect(headEllipsis('/music/', width(80)), const HeadEllipsis('/music/'));
  });

  test('leading folders dropped behind "…/" until the rest fits', () {
    expect(headEllipsis(path, width(40)), const HeadEllipsis('…/Various Artists/Night Market Sampler/'));
    expect(headEllipsis(path, width(24)), const HeadEllipsis('…/Night Market Sampler/'));
  });

  test('the last folder alone does not fit: "…/" and it, cut at its tail by the strip', () {
    expect(headEllipsis(path, width(10)), const HeadEllipsis('…/Night Market Sampler/', tailCut: true));
    expect(headEllipsis('/music/', width(3)), const HeadEllipsis('…/music/', tailCut: true));
  });

  test('no trailing slash stays none; "/" and "" are drawn as they are', () {
    expect(headEllipsis('/music/Boukmanflow/Borrowed Tapes', width(20)), const HeadEllipsis('…/Borrowed Tapes'));
    expect(headEllipsis('/', width(0)), const HeadEllipsis('/'));
    expect(headEllipsis('', width(0)), const HeadEllipsis(''));
  });

  test('every candidate is measured whole, shortest last', () {
    final asked = <String>[];
    headEllipsis(path, (s) {
      asked.add(s);
      return false;
    });
    expect(asked, [path, '…/Various Artists/Night Market Sampler/', '…/Night Market Sampler/']);
  });
}
