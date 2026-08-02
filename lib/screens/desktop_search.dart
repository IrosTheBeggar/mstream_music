// desktop_search.dart — the desktop's server-wide search page (⌘K).
//
// One query, organized results: horizontal shelves for artists and albums,
// boxed rows for songs / lyrics / files — each section only when it has
// hits. Results come from ApiManager.searchServerRaw, the side-effect-free
// search: nothing here touches the browse stack until the user PICKS a
// result, at which point taps dispatch through the shared browse action
// table (util/browse_actions.dart) so a hit behaves exactly like the same
// row in the browser — artists drill in, albums open the detail overlay
// (both pop this page to reveal them), songs enqueue/play per the user's
// tap-behavior setting and keep the page open for more picks.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../objects/display_item.dart';
import '../singletons/api.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/browse_actions.dart';
import '../util/image_cache.dart';
import '../util/stream_url.dart';
import '../widgets/album_grid.dart';

class DesktopSearchScreen extends StatefulWidget {
  const DesktopSearchScreen({super.key});

  @override
  State<DesktopSearchScreen> createState() => _DesktopSearchScreenState();
}

class _DesktopSearchScreenState extends State<DesktopSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();
  Timer? _debounce;
  ServerSearchResults? _results;
  bool _loading = false;
  // The query the shown results answer (lags the field while typing).
  String _resultsFor = '';
  // Monotonic guard: only the latest request may publish results.
  int _searchSeq = 0;

  static const _kAlbumShelfWidth = 176.0;
  static const _kArtistTileWidth = 128.0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(text));
  }

  Future<void> _run(String text) async {
    _debounce?.cancel();
    final q = text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _resultsFor = '';
        _loading = false;
      });
      return;
    }
    final seq = ++_searchSeq;
    setState(() => _loading = true);
    final r = await ApiManager().searchServerRaw(q);
    if (!mounted || seq != _searchSeq) return; // superseded by newer keystrokes
    setState(() {
      _results = r;
      _resultsFor = q;
      _loading = false;
    });
  }

  // Esc clears a non-empty field; a second Esc (or Esc on an empty field)
  // closes the page back to browse.
  KeyEventResult _onEsc() {
    if (_controller.text.isNotEmpty) {
      _controller.clear();
      _run('');
    } else {
      Navigator.of(context).maybePop();
    }
    return KeyEventResult.handled;
  }

  // Result taps dispatch through the shared browse action table. Navigating
  // hits (artist drill-in, album detail) happen in the browse view UNDER
  // this route — pop so the user sees where they landed. Songs/files just
  // queue; the page stays for more picks.
  void _tap(List<DisplayItem> section, int index) {
    final type = section[index].type;
    handleBrowseTap(section, index, context);
    if (type == 'artist' || type == 'album') {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          return _onEsc();
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: VelvetColors.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchHeader(l),
            SizedBox(
              height: 2,
              child: _loading
                  ? LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor:
                          AlwaysStoppedAnimation(VelvetColors.primaryDim),
                    )
                  : null,
            ),
            Expanded(child: _body(l)),
          ],
        ),
      ),
    );
  }

  // The query field on the chrome band, mirroring the toolbar's type: a
  // borderless field with the search glyph, plus the category chips that
  // persist through SettingsManager (same set the classic search uses).
  Widget _searchHeader(AppLocalizations l) {
    return Container(
      color: VelvetColors.bg,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            focusNode: _fieldFocus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _run,
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 22),
            cursorColor: VelvetColors.primary,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search,
                  color: VelvetColors.textSecondary, size: 26),
              hintText: l.browserSearchHint,
              hintStyle:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 22),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final c in SearchCategory.values)
                FilterChip(
                  label: Text(c.label(l)),
                  selected:
                      SettingsManager().searchCategories.contains(c),
                  onSelected: (_) async {
                    await SettingsManager().toggleSearchCategory(c);
                    setState(() {});
                    if (_resultsFor.isNotEmpty) _run(_resultsFor);
                  },
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: SettingsManager().searchCategories.contains(c)
                        ? VelvetColors.bg
                        : VelvetColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: VelvetColors.primary,
                  backgroundColor: VelvetColors.card,
                  side: BorderSide(color: VelvetColors.border),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    final r = _results;
    if (_resultsFor.isEmpty) {
      return _centered(Icons.search, 'Search your library',
          'Albums, artists, songs, file paths and lyrics — ⌘K from anywhere.');
    }
    if (r == null) {
      return _centered(Icons.cloud_off, 'Search unavailable',
          'The server could not be reached. Check the connection and try again.');
    }
    if (r.isEmpty) {
      return _centered(Icons.search_off, 'No results for “$_resultsFor”',
          'Try fewer words, or widen the categories above.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (r.artists.isNotEmpty) ...[
          _sectionLabel('ARTISTS', r.artists.length),
          _artistShelf(r.artists),
        ],
        if (r.albums.isNotEmpty) ...[
          _sectionLabel('ALBUMS', r.albums.length),
          _albumShelf(r.albums),
        ],
        if (r.titles.isNotEmpty) ...[
          _sectionLabel('SONGS', r.titles.length),
          _rowsSection(r.titles),
        ],
        if (r.lyrics.isNotEmpty) ...[
          _sectionLabel('LYRICS', r.lyrics.length),
          _rowsSection(r.lyrics, snippetStyle: true),
        ],
        if (r.files.isNotEmpty) ...[
          _sectionLabel('FILES', r.files.length),
          _rowsSection(r.files),
        ],
      ],
    );
  }

  Widget _centered(IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: VelvetColors.textSecondary),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              )),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                color: VelvetColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  // ── Artists: horizontal shelf of round-art tiles ─────────────────────────
  Widget _artistShelf(List<DisplayItem> items) {
    return SizedBox(
      height: _kArtistTileWidth + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            _ArtistTile(item: items[i], onTap: () => _tap(items, i)),
      ),
    );
  }

  // ── Albums: horizontal shelf of the browse grid's own cards ──────────────
  Widget _albumShelf(List<DisplayItem> items) {
    return SizedBox(
      // Card = square art + two text lines; mirror AlbumGrid's aspect ratio.
      height: _kAlbumShelfWidth / AlbumGrid.aspectRatio,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(
          width: _kAlbumShelfWidth,
          child: AlbumCard(
            // Display copy without the classic flat list's 'album' type-hint
            // subtext — the section header already says what these are.
            item: _withoutSubtext(items[i]),
            onTap: () => _tap(items, i),
            cacheWidth: artCacheSize(_kAlbumShelfWidth),
          ),
        ),
      ),
    );
  }

  static DisplayItem _withoutSubtext(DisplayItem i) {
    final copy =
        DisplayItem(i.server, i.name, i.type, i.data, i.icon, null);
    copy.altAlbumArt = i.altAlbumArt;
    copy.metadata = i.metadata;
    copy.partialMetadata = i.partialMetadata;
    return copy;
  }

  // ── Songs / lyrics / files: contiguous boxed rows, browse-style ──────────
  Widget _rowsSection(List<DisplayItem> items, {bool snippetStyle = false}) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _ResultRow(
            item: items[i],
            first: i == 0,
            snippetStyle: snippetStyle,
            onTap: () => _tap(items, i),
          ),
      ],
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final DisplayItem item;
  final VoidCallback onTap;
  const _ArtistTile({required this.item, required this.onTap});

  static const double _size = 128;

  @override
  Widget build(BuildContext context) {
    final aaFile = item.altAlbumArt;
    Widget art;
    if (item.server != null && aaFile != null) {
      art = Image.network(
        buildAlbumArtUrl(item.server!, aaFile, compress: 'm'),
        fit: BoxFit.cover,
        width: _size,
        height: _size,
        cacheWidth: artCacheSize(_size),
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      art = _placeholder();
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _size,
        child: Column(
          children: [
            ClipOval(child: SizedBox(width: _size, height: _size, child: art)),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: _size,
      height: _size,
      color: VelvetColors.card,
      child: Icon(Icons.person, size: 48, color: VelvetColors.textSecondary),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final DisplayItem item;
  final bool first;
  final bool snippetStyle;
  final VoidCallback onTap;
  const _ResultRow(
      {required this.item,
      required this.first,
      required this.snippetStyle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final aaFile = item.altAlbumArt ?? item.metadata?.albumArt;
    final title = item.metadata?.title ?? item.name;
    // Lyrics rows carry the matched excerpt as subtext — show it as the
    // "why it matched" line; other rows fall back to artist/folder context.
    final sub = item.subtext ?? item.metadata?.artist;
    return Material(
      color: VelvetColors.card,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              top: first
                  ? BorderSide(color: VelvetColors.border2)
                  : BorderSide.none,
              left: BorderSide(color: VelvetColors.border2),
              right: BorderSide(color: VelvetColors.border2),
              bottom: BorderSide(color: VelvetColors.border2),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: (item.server != null && aaFile != null)
                      ? Image.network(
                          buildAlbumArtUrl(item.server!, aaFile),
                          fit: BoxFit.cover,
                          cacheWidth: artCacheSize(36),
                          errorBuilder: (_, _, _) => _iconBox(),
                        )
                      : _iconBox(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 14)),
                    if (sub != null && sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: VelvetColors.textSecondary,
                          fontSize: 12,
                          fontStyle: snippetStyle
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.playlist_add,
                  size: 18, color: VelvetColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      color: VelvetColors.raised,
      child: Center(
        child: item.icon ??
            Icon(Icons.music_note,
                size: 18, color: VelvetColors.textSecondary),
      ),
    );
  }
}
