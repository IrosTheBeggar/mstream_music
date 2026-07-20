import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../theme/velvet_theme.dart';

/// Song picker bottom sheet — debounced title search against [server], plus
/// a "Random song" row for a surprise pick. Pops with the chosen
/// DisplayItem, or null when dismissed. Shared by the Auto DJ sonic-seed
/// picker and the sonic-path destination picker; [title] names the purpose.

class SongPickerSheet extends StatefulWidget {
  final Server server;

  /// Sheet heading — the caller's purpose ("Seed song", "Play a path to…").
  final String title;
  const SongPickerSheet(
      {super.key, required this.server, required this.title});

  @override
  State<SongPickerSheet> createState() => SongPickerSheetState();
}

class SongPickerSheetState extends State<SongPickerSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  int _reqId = 0;
  bool _loading = false;
  bool _failed = false;
  List<DisplayItem> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final term = _ctrl.text.trim();
    final rid = ++_reqId;
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final hits = await ApiManager().fetchSongSearch(widget.server, term);
    if (!mounted || rid != _reqId) return;
    setState(() {
      _loading = false;
      _results = hits;
    });
  }

  Future<void> _random() async {
    final rid = ++_reqId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final item = await ApiManager().fetchRandomSong(widget.server);
    if (!mounted || rid != _reqId) return;
    if (item == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final term = _ctrl.text.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: VelvetColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.autoDjSonicSeedSearchHint,
                  isDense: true,
                  prefixIcon:
                      Icon(Icons.search, color: VelvetColors.textSecondary),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (_) => _search(),
              ),
            ),
            // "Surprise me" — one random library song as the seed.
            ListTile(
              dense: true,
              leading: Icon(Icons.casino, color: VelvetColors.primary),
              title: Text(
                l.autoDjSonicSeedRandom,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              ),
              onTap: _random,
            ),
            Divider(color: VelvetColors.border, height: 1),
            Expanded(
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VelvetColors.primary,
                        ),
                      ),
                    )
                  : _failed
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              l.autoDjSonicSeedFailed,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: VelvetColors.textSecondary,
                                  fontSize: 13),
                            ),
                          ),
                        )
                      : (_results.isEmpty && term.length >= 2)
                          ? Center(
                              child: Text(
                                l.discoverNothingFound,
                                style: TextStyle(
                                    color: VelvetColors.textSecondary,
                                    fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _results.length,
                              itemBuilder: (context, i) {
                                final item = _results[i];
                                final artist = item.metadata?.artist;
                                return ListTile(
                                  dense: true,
                                  leading: item.getAlbumThumb(size: 40),
                                  title: Text(
                                    item.metadata?.title ?? item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: VelvetColors.textPrimary,
                                        fontSize: 14),
                                  ),
                                  subtitle: artist == null
                                      ? null
                                      : Text(
                                          artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color:
                                                  VelvetColors.textSecondary,
                                              fontSize: 12),
                                        ),
                                  onTap: () =>
                                      Navigator.of(context).pop(item),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}
