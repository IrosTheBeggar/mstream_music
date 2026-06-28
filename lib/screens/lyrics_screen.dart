import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/lyrics.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../theme/velvet_theme.dart';

/// Full lyrics page, reached from the Song Info lyrics badge. Fetches the
/// track's lyrics on open via `GET /api/v1/lyrics` and renders them as scrollable
/// (selectable) text — the plain version when present, otherwise a synced LRC
/// flattened to plain lines. Loading / empty / error states are handled inline so
/// the badge is always one tap from *something* sensible.
class LyricsScreen extends StatefulWidget {
  const LyricsScreen({
    super.key,
    required this.server,
    required this.path,
    required this.title,
    this.artist,
  });

  /// The track's source server and data path — together they address the
  /// lyrics endpoint (the badge only opens this screen when both resolve).
  final Server server;
  final String path;

  /// Shown in the app bar for context.
  final String title;
  final String? artist;

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  late Future<LyricsResult?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<LyricsResult?> _load() =>
      ApiManager().fetchLyrics(widget.server, widget.path);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasArtist = widget.artist != null && widget.artist!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(
        backgroundColor: VelvetColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: VelvetColors.textPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title.trim().isNotEmpty ? widget.title : l.lyricsTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasArtist)
              Text(
                widget.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: VelvetColors.textTertiary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
      body: FutureBuilder<LyricsResult?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: VelvetColors.primary),
            );
          }
          if (snap.hasError) {
            return _Message(
              icon: Icons.error_outline_rounded,
              text: l.lyricsError,
              action: TextButton(onPressed: _retry, child: Text(l.lyricsRetry)),
            );
          }
          final text = snap.data?.displayText;
          if (text == null) {
            return _Message(
              icon: Icons.lyrics_outlined,
              text: l.lyricsEmpty,
            );
          }
          return _LyricsBody(text: text);
        },
      ),
    );
  }
}

/// The lyrics text itself: a comfortable, centered, selectable reading column.
class _LyricsBody extends StatelessWidget {
  const _LyricsBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 32 + mq.padding.bottom),
      children: [
        SelectableText(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: VelvetColors.textSecondary,
            fontSize: 16,
            height: 1.8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Centered glyph + message (+ optional action) for the empty / error states.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: VelvetColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 14.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
