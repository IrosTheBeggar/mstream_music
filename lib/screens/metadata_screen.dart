import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';
import '../util/media_format.dart';

/// Song-info screen shown from the queue row's Info action: a blurred album-art
/// backdrop, a hero cover, the title / artist / album·year, a track/disc line,
/// self-labelling metadata chips (length, BPM, key, genre), and the file
/// location with a copy button. Reads straight off the [MediaItem], so every
/// field the queue carries is surfaced — and only when present.
class MetadataScreen extends StatelessWidget {
  const MetadataScreen({Key? key, required this.item}) : super(key: key);

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final extras = item.extras ?? const <String, dynamic>{};

    final art = extras['artUrl'] as String? ?? item.artUri?.toString();
    final path = extras['path'] as String?;
    final year = extras['year'];
    final key = extras['musicalKey'] as String?;
    final genre = item.genre;

    final subtitle = <String>[
      if (item.album != null && item.album!.trim().isNotEmpty) item.album!.trim(),
      if (year != null && '$year'.isNotEmpty && '$year' != '0') '$year',
    ].join('   ·   ');

    // Track / disc as a plain line under the album.
    final trackDisc = <String>[
      if (extras['track'] != null) 'track: ${_v(extras['track'])}',
      if (extras['disc'] != null) 'disc: ${_v(extras['disc'])}',
    ].join(', ');

    // Self-labelling chips (icon + value) — no extra translated strings, shown
    // only when the field is present.
    final chips = <Widget>[
      if (item.duration != null)
        _chip(Icons.schedule_rounded, formatDuration(item.duration!)),
      if (extras['bpm'] != null)
        _chip(Icons.speed_rounded, '${_v(extras['bpm'])} BPM'),
      if (key != null && key.trim().isNotEmpty)
        _chip(Icons.music_note_rounded, key.trim()),
      if (genre != null && genre.trim().isNotEmpty)
        _chip(Icons.category_rounded, genre.trim()),
    ];

    return Scaffold(
      backgroundColor: VelvetColors.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: VelvetColors.textPrimary,
        title: Text(
          l.songInfoTitle,
          style: TextStyle(
            color: VelvetColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Blurred album-art backdrop, faded into the background.
          if (art != null) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 400,
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: 48, sigmaY: 48, tileMode: TileMode.decal),
                  child: Image.network(
                    art,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 400,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VelvetColors.bg.withValues(alpha: 0.45),
                      VelvetColors.bg,
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Content.
          ListView(
            padding: EdgeInsets.fromLTRB(24, mq.padding.top + kToolbarHeight + 12,
                24, 28 + mq.padding.bottom),
            children: [
              // Hero cover.
              Center(
                child: Container(
                  width: 224,
                  height: 224,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: art != null
                        ? Image.network(
                            art,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                albumArtFallback(iconSize: 60),
                          )
                        : albumArtFallback(iconSize: 60),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              // Title.
              Text(
                item.title.trim().isNotEmpty ? item.title : '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              if (item.artist != null && item.artist!.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  item.artist!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VelvetColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
              if (trackDisc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  trackDisc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VelvetColors.textDim,
                    fontSize: 12.5,
                  ),
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: chips,
                ),
              ],
              if (path != null && path.trim().isNotEmpty) ...[
                const SizedBox(height: 30),
                _LocationCard(path: path),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Render a numeric tag value without a trailing ".0" (servers send int or
  // double); pass strings through unchanged.
  static String _v(dynamic value) =>
      value is num ? value.round().toString() : '$value';

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VelvetColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: VelvetColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The file-location row: a folder glyph, the (monospace) path, and a copy
/// button that drops it on the clipboard.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: VelvetColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VelvetColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Icon(Icons.folder_outlined,
              size: 18, color: VelvetColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              path,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded,
                size: 18, color: VelvetColors.textTertiary),
            tooltip: l.manageServerCopyPath,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: VelvetColors.raised,
                content: Text(l.manageServerPathCopied,
                    style: TextStyle(color: VelvetColors.textPrimary)),
              ));
            },
          ),
        ],
      ),
    );
  }
}
