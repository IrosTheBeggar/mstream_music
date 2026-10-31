import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';

/// How Add from YouTube draws a folder path ("Music › Daft Punk ›
/// Discovery"), on the card, in rows, toasts and the explorer strip.
///
/// Each crumb sits in a Unicode isolate (FSI … PDI) so an Arabic or Hebrew
/// artist or album keeps the › order (spec §9). Inside the result card a
/// path wraps only at the separators ([YtdlCrumbs]); everywhere else it is
/// one line cut at the start so the last folder stays ([YtdlCrumbLine]).

const String kYtdlCrumbSep = ' › ';

/// [s] wrapped in first-strong isolate … pop directional isolate.
String ytdlIsolate(String s) => '\u2068$s\u2069';

/// [crumbs] as one plain line, each crumb isolated.
String ytdlPathText(Iterable<String> crumbs) =>
    crumbs.map(ytdlIsolate).join(kYtdlCrumbSep);

/// The path a toast names: the folders below the library, or the library
/// itself when the song went into its top folder.
String ytdlToastPath(String library, List<String> segments) =>
    segments.isEmpty ? ytdlIsolate(library) : ytdlPathText(segments);

/// A folder made only of brackets and separators ("()", "[ ]", "-").
bool ytdlOnlyBrackets(String crumb) =>
    crumb.trim().isNotEmpty && RegExp(r'^[\s()\[\]{}\-–—_,·&+]+$').hasMatch(crumb);

final RegExp _endsInEmptyPair = RegExp(r'\s*(\(\s*\)|\[\s*\]|\{\s*\})\s*$');

/// How [crumbs] read aloud: "Music, then Daft Punk, then Discovery, a new
/// folder" — [newAt] are the indexes that will be made, [trapAt] those an
/// empty variable left as brackets, [file] the file name the preview ends in.
String ytdlSpokenPath(
  AppLocalizations l,
  List<String> crumbs, {
  Set<int> newAt = const {},
  Set<int> trapAt = const {},
  String? file,
}) {
  String? path;
  for (var i = 0; i < crumbs.length; i++) {
    final c = crumbs[i];
    var word = c;
    if (trapAt.contains(i)) {
      if (ytdlOnlyBrackets(c)) {
        word = l.ytdlCrumbEmptyBrackets;
      } else if (_endsInEmptyPair.hasMatch(c)) {
        word = l.ytdlCrumbWithEmptyBrackets(c.replaceFirst(_endsInEmptyPair, ''));
      }
    }
    if (newAt.contains(i)) word = l.ytdlCrumbNew(word);
    path = path == null ? word : l.ytdlCrumbThen(path, word);
  }
  path ??= '';
  return file == null ? path : l.ytdlCrumbFile(path, file);
}

/// No-break spaces inside a crumb, so a wrapping path breaks only at ›.
String _hold(String s) => s.replaceAll(' ', '\u00A0');

/// A path inside the result card or a sheet's preview: it wraps at the ›
/// separators only, a folder that will be made carries a small "new" tag,
/// and a folder an empty variable left as brackets is drawn in the warning
/// colour. Read aloud as one phrase ([ytdlSpokenPath]).
class YtdlCrumbs extends StatelessWidget {
  final List<String> crumbs;
  final Set<int> newAt;
  final Set<int> trapAt;
  /// Crumbs drawn as sample words (italic, quieter): the preview before any
  /// link was pasted ("Music › Artist › Album").
  final Set<int> sampleAt;
  /// A file name the path ends in, drawn in mono after a separator.
  final String? file;
  final TextStyle? style;
  final int? maxLines;

  const YtdlCrumbs({
    super.key,
    required this.crumbs,
    this.newAt = const {},
    this.trapAt = const {},
    this.sampleAt = const {},
    this.file,
    this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final base = TextStyle(
      fontSize: 13,
      color: VelvetColors.textPrimary,
      height: 1.4,
    ).merge(style);
    final sep = base.copyWith(color: VelvetColors.textSecondary);
    final spans = <InlineSpan>[];
    for (var i = 0; i < crumbs.length; i++) {
      if (i > 0) spans.add(TextSpan(text: kYtdlCrumbSep, style: sep));
      final c = crumbs[i];
      final s = trapAt.contains(i)
          ? base.copyWith(color: VelvetColors.warning)
          : sampleAt.contains(i)
              ? base.copyWith(
                  fontStyle: FontStyle.italic,
                  color: VelvetColors.textSecondary,
                )
              : base;
      spans.add(TextSpan(text: ytdlIsolate(_hold(c)), style: s));
      if (newAt.contains(i)) {
        spans.add(const TextSpan(text: '\u00A0'));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: YtdlNewTag(),
        ));
      }
    }
    if (file != null) {
      spans.add(TextSpan(text: kYtdlCrumbSep, style: sep));
      spans.add(TextSpan(
        text: file,
        style: base.copyWith(fontFamily: 'monospace', fontSize: 12),
      ));
    }
    return Semantics(
      label: ytdlSpokenPath(l, crumbs, newAt: newAt, trapAt: trapAt, file: file),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: spans),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}

/// The small outlined "new" tag after a folder that will be made.
class YtdlNewTag extends StatelessWidget {
  final String? label;
  const YtdlNewTag({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: VelvetColors.border2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label ?? l.ytdlNewTag,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: VelvetColors.textSecondary,
        ),
      ),
    );
  }
}

/// A path on one line, cut at the start so the last folders stay: "… ›
/// Daft Punk › Homework". Used in rows, the lands-in line and the strip.
class YtdlCrumbLine extends StatelessWidget {
  final List<String> crumbs;
  final TextStyle? style;
  /// Text before the path on the same line ("Lands in "), never cut.
  final String prefix;
  /// Text after the path on the same line (" · MP3"), never cut.
  final String suffix;

  const YtdlCrumbLine({
    super.key,
    required this.crumbs,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  /// The longest tail of [crumbs] that fits [maxWidth] with [prefix] and
  /// [suffix], as text: the whole path when it fits, else "… › " plus as
  /// many trailing crumbs as fit (at least the last one, which may ellipsize).
  static String fit({
    required List<String> crumbs,
    required TextStyle style,
    required double maxWidth,
    required TextDirection direction,
    required TextScaler scaler,
    String prefix = '',
    String suffix = '',
  }) {
    bool fits(String text) {
      final tp = TextPainter(
        text: TextSpan(text: '$prefix$text$suffix', style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final ok = tp.width <= maxWidth;
      tp.dispose();
      return ok;
    }

    final whole = ytdlPathText(crumbs);
    if (crumbs.length < 2 || fits(whole)) return whole;
    for (var drop = 1; drop < crumbs.length; drop++) {
      final tail = '…$kYtdlCrumbSep${ytdlPathText(crumbs.sublist(drop))}';
      if (fits(tail) || drop == crumbs.length - 1) return tail;
    }
    return whole;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = TextStyle(fontSize: 12, color: VelvetColors.textSecondary)
        .merge(style);
    return LayoutBuilder(builder: (context, box) {
      final text = fit(
        crumbs: crumbs,
        style: s,
        maxWidth: box.maxWidth,
        direction: Directionality.of(context),
        scaler: MediaQuery.textScalerOf(context),
        prefix: prefix,
        suffix: suffix,
      );
      return Semantics(
        label: '$prefix${ytdlSpokenPath(l, crumbs)}$suffix',
        excludeSemantics: true,
        child: Text(
          '$prefix$text$suffix',
          style: s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    });
  }
}
