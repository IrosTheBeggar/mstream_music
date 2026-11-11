/// The explorer's path strip, cut from its HEAD: the folder you are in is
/// the part that matters, so leading folders go first — "…/Various
/// Artists/Night Market Sampler/" — where a tail ellipsis would keep "/music/
/// Various Art…" and lose the folder itself. Pure: the caller measures
/// ([fits], a TextPainter at the strip's style and width).
library;

/// What the strip draws: [text], and whether the last folder alone does not
/// fit even after every other one went ([tailCut]: the strip draws [text]
/// with a tail ellipsis of its own).
class HeadEllipsis {
  final String text;
  final bool tailCut;
  const HeadEllipsis(this.text, {this.tailCut = false});

  @override
  bool operator ==(Object other) =>
      other is HeadEllipsis && other.text == text && other.tailCut == tailCut;

  @override
  int get hashCode => Object.hash(text, tailCut);

  @override
  String toString() => 'HeadEllipsis($text${tailCut ? ', tailCut' : ''})';
}

/// The mark in front of a path cut from its head.
const String kHeadEllipsis = '…/';

/// [path] as it fits: whole when it [fits]; else its leading folders dropped
/// one by one behind [kHeadEllipsis] until the rest fits; else "…/" and the
/// last folder alone, [HeadEllipsis.tailCut]. A trailing slash is kept as
/// given ("/music/Boukmanflow/" → "…/Boukmanflow/"); "/" and "" are drawn as
/// they are.
HeadEllipsis headEllipsis(String path, bool Function(String text) fits) {
  if (fits(path)) return HeadEllipsis(path);
  final trailing = path.endsWith('/');
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return HeadEllipsis(path);
  final tail = trailing ? '/' : '';
  for (var i = 1; i < segs.length; i++) {
    final cut = '$kHeadEllipsis${segs.sublist(i).join('/')}$tail';
    if (fits(cut)) return HeadEllipsis(cut);
  }
  return HeadEllipsis('$kHeadEllipsis${segs.last}$tail', tailCut: true);
}
