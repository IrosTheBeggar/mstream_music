import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/server.dart';
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

/// Before a sheet or a menu opens over the screen or the folder sheet:
/// whatever holds the focus lets go of it (spec §3: nothing autofocuses).
/// A route gives the focus back to the field that had it when another
/// closes over it — the link field, after Back hid the keyboard and left
/// it focused — so the keyboard would rise and the list scroll to it.
void ytdlDropFocus() => FocusManager.instance.primaryFocus?.unfocus();

/// "Choose a folder…": the picked folder, for this song only.
Future<void> ytdlChooseFolder(BuildContext context, YtdlDraft draft) async {
  final dir = await YtdlSheets.chooseFolder(context, draft);
  if (dir != null) draft.useFolder(dir);
}

/// Why Add from YouTube went away for [server], for the toast an entry
/// point shows as it declines to open (spec §8): uploads off, else audio
/// conversion not ready; null for anything else (no library left).
String? ytdlEntryOffReason(AppLocalizations l, Server server) =>
    server.noUpload == true
        ? l.ytdlErrUploadsOff
        : server.transcodeAvailable == false
        ? l.ytdlErrFfmpeg
        : null;

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

/// The ground the parts below are drawn on, when it is not the sheet's:
/// the result card and a sheet's preview card are raised. Their inks are
/// measured against it ([ytdlInk], [ytdlTone]), so small text stays at
/// 4.5:1 on the card it sits on (spec §9) in every theme and accent.
class YtdlGround extends InheritedWidget {
  final Color color;
  const YtdlGround({super.key, required this.color, required super.child});

  static Color? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<YtdlGround>()?.color;

  @override
  bool updateShouldNotify(YtdlGround oldWidget) => oldWidget.color != color;
}

/// Text in the primary's place ([keepInk]), on the ground it is drawn on.
Color ytdlInk(BuildContext context) {
  final ground = YtdlGround.maybeOf(context);
  return ground == null ? keepInk() : keepInkOn(ground);
}

/// A status colour as text ([keepTone]), on the ground it is drawn on.
Color ytdlTone(BuildContext context, Color c) {
  final ground = YtdlGround.maybeOf(context);
  return ground == null ? keepTone(c) : keepToneOn(c, ground);
}

/// An inline link in the primary's ink (Change, Undo all, Use them, Try
/// again…): 13–14/600 text on a 48 px band, padded at the sides.
class YtdlTextLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final IconData? icon;
  final IconData? trailingIcon;
  final EdgeInsetsGeometry padding;

  /// Wraps onto more lines rather than cut its words — a long translation
  /// ("Künstler und Titel tauschen") or large text, where an ellipsis would
  /// leave a button that no longer says what it does. False keeps one line,
  /// ellipsized.
  final bool wrap;

  const YtdlTextLink(
    this.label, {
    super.key,
    required this.onTap,
    this.fontSize = 14,
    this.icon,
    this.trailingIcon,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.wrap = true,
  });

  /// The same link on other [padding] (one that moves under its words).
  YtdlTextLink withPadding(EdgeInsetsGeometry padding) => YtdlTextLink(
    label,
    key: key,
    onTap: onTap,
    fontSize: fontSize,
    icon: icon,
    trailingIcon: trailingIcon,
    padding: padding,
    wrap: wrap,
  );

  TextStyle _style(Color ink) => TextStyle(
    color: ink,
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    height: 18 / 14,
  );

  /// How wide the link draws on one line — words, icons and padding, in
  /// the face and text scale of [context] — for a row deciding whether it
  /// still fits beside other words.
  double naturalWidth(BuildContext context) {
    final dir = Directionality.of(context);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(
          context,
        ).style.merge(_style(VelvetColors.primary)),
      ),
      textDirection: dir,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final words = tp.width;
    tp.dispose();
    return words.ceilToDouble() +
        padding.resolve(dir).horizontal +
        (icon != null ? 18 + 6 : 0) +
        (trailingIcon != null ? 2 + 18 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final ink = onTap == null ? VelvetColors.textTertiary : ytdlInk(context);
    final text = Text(
      label,
      maxLines: wrap ? null : 1,
      overflow: wrap ? null : TextOverflow.ellipsis,
      style: _style(ink),
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

/// Words with a link at their end ("Cleaned from …" · Undo all, "Details
/// found" · Use them): the link beside them while it takes at most half
/// the row, else on its own line under them ([below] its padding there, so
/// it lines up with the words). A long translation of the link, or large
/// text, would otherwise squeeze the words into a column a word wide.
class YtdlWordsWithLink extends StatelessWidget {
  final Widget words;
  final YtdlTextLink link;
  final EdgeInsetsGeometry below;

  const YtdlWordsWithLink({
    super.key,
    required this.words,
    required this.link,
    this.below = const EdgeInsetsDirectional.only(end: 8),
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (!box.maxWidth.isFinite ||
          link.naturalWidth(context) <= box.maxWidth / 2) {
        return Row(
          children: [
            Expanded(child: words),
            link,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [words, link.withPadding(below)],
      );
    },
  );
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
    final ink = ytdlInk(context);
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
