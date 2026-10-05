import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../theme/velvet_theme.dart';
import '../../widgets/federation_widgets.dart';
import '../../widgets/song_picker_sheet.dart';
import 'discovery_page_controller.dart';
import 'discovery_widgets.dart';

/// The seeds sheet (the PhoneSeeds canvas board): the window as a segmented
/// control, a switch per seed, the dropped seeds to bring back, and "Pick a
/// song…" to pin one. Nothing is sent until "Use these N" — the sheet edits
/// a draft and hands it to [DiscoveryPageController.applySeeds], which
/// remembers drops and restores server-side (so every client agrees) and
/// keeps pins for this visit only (plan §2.3).
class DiscoverySeedsSheet extends StatefulWidget {
  final DiscoveryPageController controller;
  const DiscoverySeedsSheet({super.key, required this.controller});

  @override
  State<DiscoverySeedsSheet> createState() => _DiscoverySeedsSheetState();
}

/// One pin in the draft: the app path plus what to call it.
class _Pin {
  final String path;
  final String title;
  final String? artist;
  final DisplayItem? item;
  bool on = true;
  _Pin(this.path, this.title, this.artist, this.item);
}

class _DiscoverySeedsSheetState extends State<DiscoverySeedsSheet> {
  DiscoveryPageController get c => widget.controller;

  late int _window;
  final Set<String> _off = {}; // history seeds switched off
  final Set<String> _on = {}; // saved exclusions switched back on
  late final List<_Pin> _pins;

  List<TasteSeed> get _history =>
      c.seeds.where((s) => !s.pinned).toList(growable: false);
  List<TasteExcluded> get _excluded => c.seeded?.excluded ?? const [];

  @override
  void initState() {
    super.initState();
    _window = c.effectiveWindow;
    // The visit's pins, named from the seeds the server resolved them to
    // (a pin it dropped keeps its file name).
    _pins = [
      for (final p in c.pins) _pinFor(p),
    ];
  }

  _Pin _pinFor(String path) {
    for (final s in c.seeds) {
      if (s.pinned && '/${s.filepath}' == path) {
        return _Pin(path, s.displayTitle, s.metadata?.artist,
            discoverySeedItem(c.server, s));
      }
    }
    return _Pin(path, path.split('/').last, null, null);
  }

  int get _onCount =>
      _history.where((s) => !_off.contains(s.hash)).length +
      _on.length +
      _pins.where((p) => p.on).length;

  int get _total => _history.length + _excluded.length + _pins.length;

  void _reset() {
    setState(() {
      _window = kTasteDefaultWindow;
      _off.clear();
      _on
        ..clear()
        ..addAll(_excluded.map((e) => e.hash));
      _pins.clear();
    });
  }

  Future<void> _pickSong() async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<DisplayItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          SongPickerSheet(server: c.server, title: l.discoverPagePickSong),
    );
    final path = picked?.data;
    if (picked == null || path == null || !mounted) return;
    if (_pins.any((p) => p.path == path)) return;
    if (_pins.where((p) => p.on).length >= kTastePinMax) return;
    setState(() => _pins.add(_Pin(path, picked.metadata?.title ?? picked.name,
        picked.metadata?.artist, picked)));
  }

  void _apply() {
    // The page shows the refetch; the sheet's job is done once it is asked.
    // The pending apply is the sheet's result, so the page — which outlives
    // the sheet — can say so when a restore did not take (the server would
    // otherwise go on leaving the song out with no word).
    final pending = c.applySeeds(
      window: _window,
      drop: Set.of(_off),
      restore: Set.of(_on),
      pins: [for (final p in _pins) if (p.on) p.path],
    );
    Navigator.of(context).pop(pending);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final widened = c.seeded?.widenedFrom;
    final source = c.seeded?.seedSource;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: VelvetColors.border2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.discoverPageBasedOn,
                          style: TextStyle(
                            color: VelvetColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.discoverPageSeedsSub,
                          style: TextStyle(
                              color: VelvetColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: VelvetColors.textSecondary),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  for (var i = 0; i < kTasteWindows.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: DiscoveryChoicePill(
                        discoveryWindowLabel(l, kTasteWindows[i]),
                        // Four equal segments are ~85 px at 390: a long
                        // label (or a large text setting) shrinks to fit
                        // rather than reading "Gesamte Z…".
                        fit: true,
                        selected: _window == kTasteWindows[i],
                        onTap: () =>
                            setState(() => _window = kTasteWindows[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                [
                  l.discoverPageSeedsOn(_onCount, _total),
                  if (widened != null)
                    l.discoverPageWidened(discoveryWindowLabel(l, widened)),
                ].join(' · '),
                style:
                    TextStyle(color: VelvetColors.textTertiary, fontSize: 12),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  if (_pins.isNotEmpty) ...[
                    _groupHeader(l.discoverPagePickedHeader),
                    for (final p in _pins) _pinRow(l, p),
                  ],
                  if (_history.isNotEmpty) ...[
                    _groupHeader(
                        source == TasteSeedSource.counters
                            ? l.discoverPageCountersHeader
                            : l.discoverPageRecentHeader,
                        note: source == TasteSeedSource.counters
                            ? null
                            : l.discoverPageNewestFirst),
                    for (final s in _history) _seedRow(l, s),
                  ],
                  if (_excluded.isNotEmpty) ...[
                    _groupHeader(l.discoverPageDroppedHeader,
                        note: l.discoverPageDroppedNote),
                    for (final e in _excluded) _excludedRow(l, e),
                  ],
                  _groupHeader(l.discoverPageAddOwn,
                      note: l.discoverPageAddOwnSub),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VelvetColors.primaryDim,
                        borderRadius:
                            BorderRadius.circular(VelvetColors.radiusSmall),
                      ),
                      child: Icon(Icons.add, color: VelvetColors.primary),
                    ),
                    title: Text(l.discoverPagePickSong,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    subtitle: Text(l.discoverPagePickSongSub,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 13)),
                    onTap: _pickSong,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FedButton(l.reset,
                        kind: FedButtonKind.muted, height: 44, onPressed: _reset),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FedButton(l.discoverPageUseThese(_onCount),
                        height: 44,
                        onPressed: _apply),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(String title, {String? note}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: title.toUpperCase(),
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          if (note != null)
            TextSpan(
              text: '  $note',
              style: TextStyle(color: VelvetColors.textTertiary, fontSize: 12),
            ),
        ]),
      ),
    );
  }

  Widget _row({
    required Widget art,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: value ? 1 : 0.55,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
          child: SizedBox(width: 40, height: 40, child: art),
        ),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15)),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 13)),
        trailing: Switch(
          value: value,
          activeThumbColor: VelvetColors.primary,
          onChanged: onChanged,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }

  Widget _placeholderArt() => Container(
        color: VelvetColors.raised,
        child: Icon(Icons.music_note, color: VelvetColors.textTertiary),
      );

  Widget _pinRow(AppLocalizations l, _Pin p) {
    return _row(
      art: p.item?.getAlbumThumb(size: 40) ?? _placeholderArt(),
      title: p.title,
      subtitle: p.artist ?? '',
      value: p.on,
      onChanged: (v) => setState(() => p.on = v),
    );
  }

  Widget _seedRow(AppLocalizations l, TasteSeed s) {
    final on = !_off.contains(s.hash);
    final last = s.lastPlayed;
    final subtitle = [
      if ((s.metadata?.artist ?? '').trim().isNotEmpty) s.metadata!.artist!.trim(),
      if (last != null) discoveryAgo(l, last, c.now()),
      if (s.plays > 1) l.discoverPagePlayedTimes(s.plays),
      if (s.outcome == 'stopped') l.discoverPageListenedTo,
      if (!s.analyzed) l.discoverPageNotAnalyzed,
    ].join(' · ');
    return _row(
      art: discoverySeedItem(c.server, s).getAlbumThumb(size: 40),
      title: s.displayTitle,
      subtitle: subtitle,
      value: on,
      onChanged: (v) => setState(() => v ? _off.remove(s.hash) : _off.add(s.hash)),
    );
  }

  Widget _excludedRow(AppLocalizations l, TasteExcluded e) {
    final on = _on.contains(e.hash);
    final item = DisplayItem(c.server, e.filepath, 'file', '/${e.filepath}',
        null, null)
      ..metadata = e.metadata;
    return _row(
      art: item.getAlbumThumb(size: 40),
      title: e.displayTitle,
      subtitle: (e.metadata?.artist ?? '').trim(),
      value: on,
      onChanged: (v) => setState(() => v ? _on.add(e.hash) : _on.remove(e.hash)),
    );
  }
}
