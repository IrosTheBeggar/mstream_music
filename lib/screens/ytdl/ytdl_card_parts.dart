import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart' show pathCrumbs;
import '../../util/image_cache.dart';
import '../discovery/keep_copy_ui.dart';
import 'ytdl_choose_folder_sheet.dart';
import 'ytdl_draft.dart';
import 'ytdl_where_sheet.dart';

export '../../util/ytdl_formats.dart' show ytdlFormatName;

/// The small parts the Add from YouTube screen and the explorer's folder
/// sheet share (the boards' phone kit): an inline text link and an outlined
/// pill on 48 px hit bands, a note panel, a status line (always an icon and
/// words), a field label, the cover, and the words a format and a sample
/// path read as.

/// The destination sheets the card's links open — "Where new songs land"
/// and "Choose a folder" — through a seam widget tests swap.
abstract final class YtdlSheets {
  static Future<void> Function(BuildContext context, YtdlDraft draft) where =
      showYtdlWhereSheet;
  static Future<String?> Function(BuildContext context, YtdlDraft draft)
  chooseFolder = showYtdlChooseFolderSheet;

  @visibleForTesting
  static void reset() {
    where = showYtdlWhereSheet;
    chooseFolder = showYtdlChooseFolderSheet;
  }
}

/// "Choose a folder…": the picked folder, for this song only.
Future<void> ytdlChooseFolder(BuildContext context, YtdlDraft draft) async {
  final dir = await YtdlSheets.chooseFolder(context, draft);
  if (dir != null) draft.useFolder(dir);
}

/// Every tap target here is at least this tall (spec §9); the 32–44 px
/// drawn chips and links get the rest as padding.
const double kYtdlHit = 48;


/// A string's words around its one placeholder: [build] is the generated
/// getter, given a marker no translation contains. A translator may move
/// the placeholder, so a line with a differently styled slot (the mono file
/// name, the path after "Lands in") is split, never concatenated.
(String, String) ytdlAround(String Function(String) build) {
  const mark = '\u0000';
  final parts = build(mark).split(mark);
  return (parts.first, parts.length > 1 ? parts.last : '');
}

/// [c]'s path with sample words for its variables, as crumbs ("Music",
/// "Artist", "Album"): the lands-in line before a link, whatever it is.
/// [ytdlSamplePath]'s crumbs, for a line that cuts or reads them one by one.
List<String> ytdlSampleCrumbs(AppLocalizations l, YtdlChoice c) {
  String word(String name) => switch (name.toUpperCase()) {
    'ARTIST' || 'ALBUMARTIST' => l.torrentArtistLabel,
    'ALBUM' => l.torrentAlbumLabel,
    'YEAR' => l.torrentYearLabel,
    _ => '',
  };
  final folders = c.layout
      .replaceAllMapped(_token, (m) => word(m[1]!))
      .split(RegExp(r'[/\\]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  return [
    c.library,
    if (c.isFolder || c.kind == 'discover') ...pathCrumbs(c.base),
    ...folders,
  ];
}

final RegExp _token = RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}');

/// An inline link in the primary's ink (Change, Undo all, Use them, Try
/// again…): 13–14/600 text on a 48 px band, padded at the sides.
class YtdlTextLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final IconData? icon;
  final IconData? trailingIcon;
  final EdgeInsetsGeometry padding;

  /// Wraps onto more lines instead of ellipsizing (the clash panel's long
  /// "Change format — …" link).
  final bool wrap;

  const YtdlTextLink(
    this.label, {
    super.key,
    required this.onTap,
    this.fontSize = 14,
    this.icon,
    this.trailingIcon,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = onTap == null ? VelvetColors.textTertiary : keepInk();
    final text = Text(
      label,
      maxLines: wrap ? null : 1,
      overflow: wrap ? null : TextOverflow.ellipsis,
      style: TextStyle(
        color: ink,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 18 / 14,
      ),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kYtdlHit),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: ink),
                  const SizedBox(width: 6),
                ],
                Flexible(child: text),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 2),
                  Icon(trailingIcon, size: 18, color: ink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An outlined pill (Enter details, a mkdir's Try again): 40 px drawn,
/// radius 20, on a 48 px band.
class YtdlOutlinedPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const YtdlOutlinedPill(this.label, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: KeepHitArea(
      onTap: onTap,
      minHeight: kYtdlHit,
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: VelvetColors.border2)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A note on the card: [warning] is the amber panel (8% fill, a 45% edge —
/// the live link, a name clash, a folder the account can't make); else the
/// quiet one (the playlist note, the offline banner, the late strip). A
/// full 1 px border, never a left rule. [children] sit under the first
/// line, beside the icon; [below] under both, the panel's full width (the
/// noMkdir choices).
class YtdlNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;
  final List<Widget> children;
  final List<Widget> below;
  final double fontSize;
  final bool live;

  const YtdlNote({
    super.key,
    required this.icon,
    required this.text,
    this.warning = false,
    this.children = const [],
    this.below = const [],
    this.fontSize = 13,
    this.live = true,
  });

  @override
  Widget build(BuildContext context) {
    final amber = VelvetColors.warning;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        warning ? 12 : 10,
        12,
        warning ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: warning ? amber.withValues(alpha: 0.08) : VelvetColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warning ? amber.withValues(alpha: 0.45) : VelvetColors.border2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  icon,
                  size: 18,
                  color: warning
                      ? keepTone(VelvetColors.warning)
                      : VelvetColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: live,
                      child: Text(
                        text,
                        style: TextStyle(
                          color: VelvetColors.textPrimary,
                          fontSize: fontSize,
                          height: (fontSize + 5) / fontSize,
                        ),
                      ),
                    ),
                    ...children,
                  ],
                ),
              ),
            ],
          ),
          ...below,
        ],
      ),
    );
  }
}

/// A status as an icon and its words (spec §9: never colour alone): the
/// lookup's failures, a refused add, the "Already adding" caption.
class YtdlStatusLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Color? textColor;
  final double fontSize;
  final bool live;

  const YtdlStatusLine({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.textColor,
    this.fontSize = 13,
    this.live = true,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: live,
    container: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor ?? color,
              fontSize: fontSize,
              height: (fontSize + 5) / fontSize,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A tag field's or a block's label: 11/700 caps, letter-spaced.
class YtdlFieldLabel extends StatelessWidget {
  final String text;
  const YtdlFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: VelvetColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      height: 14 / 11,
    ),
  );
}

/// A small outlined tag in the primary's ink ("Just this song"): 20 px,
/// radius 10, 11/600.
class YtdlTag extends StatelessWidget {
  final String label;
  const YtdlTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final ink = keepInk();
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ink),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 16 / 11,
        ),
      ),
    );
  }
}

/// A quiet helper line (spec §9's helper token, about 5:1 on the card).
class YtdlHelper extends StatelessWidget {
  final String text;
  final Color? color;
  const YtdlHelper(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: color ?? VelvetColors.helper,
      fontSize: 12,
      height: 16 / 12,
    ),
  );
}

/// The video's cover: the lookup's thumbnail centre-cropped to a square
/// ([size], radius 8), else a placeholder with a music note.
class YtdlCover extends StatelessWidget {
  final String? url;
  final double size;
  const YtdlCover({super.key, this.url, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      color: VelvetColors.border,
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_outlined,
        size: size * 0.4,
        color: VelvetColors.textTertiary,
      ),
    );
    final u = url;
    return Semantics(
      image: true,
      label: l.ytdlA11yCover,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: u == null || u.isEmpty
            ? placeholder
            : Image.network(
                u,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // A 16:9 thumbnail is cropped to its middle square: decode
                // it by height so the crop stays sharp.
                cacheHeight: artCacheSize(size),
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
