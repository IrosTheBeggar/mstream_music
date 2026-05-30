import 'dart:async';

import 'package:flutter/material.dart';

import '../singletons/api.dart';
import '../singletons/ytdl_manager.dart';
import '../theme/velvet_theme.dart';

/// Bottom-sheet form replicating the webapp's file-explorer "ytdl" tab:
/// paste a YouTube URL → live metadata preview (editable title / artist /
/// album / year + thumbnail) → pick an output codec → download into
/// [directory] on the server. A successful submit kicks off YtdlManager
/// polling so the browser shows progress + auto-refreshes on completion.
Future<void> showYtdlSheet(BuildContext context, String directory) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: VelvetColors.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(VelvetColors.radiusLarge)),
    ),
    builder: (_) => _YtdlForm(directory: directory),
  );
}

bool _isYoutubeUrl(String url) {
  try {
    final h = Uri.parse(url.trim()).host.toLowerCase();
    return h == 'youtube.com' || h.endsWith('.youtube.com') || h == 'youtu.be';
  } catch (_) {
    return false;
  }
}

class _YtdlForm extends StatefulWidget {
  final String directory;
  const _YtdlForm({Key? key, required this.directory}) : super(key: key);

  @override
  State<_YtdlForm> createState() => _YtdlFormState();
}

class _YtdlFormState extends State<_YtdlForm> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _album = TextEditingController();
  final _year = TextEditingController();

  Timer? _debounce;
  bool _metaLoading = false;
  bool _metaReady = false;
  String? _thumbnail;

  List<String> _codecs = const ['mp3'];
  String _codec = 'mp3';

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _url.addListener(_onUrlChanged);
    _loadCodecs();
  }

  Future<void> _loadCodecs() async {
    final codecs = await ApiManager().ytdlCodecs();
    if (!mounted) return;
    setState(() {
      _codecs = codecs;
      _codec = codecs.contains('mp3') ? 'mp3' : codecs.first;
    });
  }

  // Debounced, YouTube-only metadata preview — mirrors the webapp's
  // 500 ms input handler.
  void _onUrlChanged() {
    _debounce?.cancel();
    final url = _url.text.trim();
    setState(() {
      _metaReady = false;
      _thumbnail = null;
      _metaLoading = false;
    });
    if (!_isYoutubeUrl(url)) return;
    setState(() => _metaLoading = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _fetchMeta(url));
  }

  Future<void> _fetchMeta(String url) async {
    try {
      final meta = await ApiManager().ytdlMetadata(url);
      // Ignore a stale response if the URL changed while in flight.
      if (!mounted || _url.text.trim() != url) return;
      setState(() {
        _metaLoading = false;
        _metaReady = true;
        _title.text = (meta['title'] ?? '').toString();
        _artist.text = (meta['artist'] ?? '').toString();
        _album.text = (meta['album'] ?? '').toString();
        _year.text = (meta['year'] ?? '').toString();
        _thumbnail = meta['thumbnail']?.toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _metaLoading = false);
    }
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (!_isYoutubeUrl(url)) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a valid YouTube URL')));
      return;
    }

    final metadata = <String, String>{};
    if (_title.text.trim().isNotEmpty) metadata['title'] = _title.text.trim();
    if (_artist.text.trim().isNotEmpty) metadata['artist'] = _artist.text.trim();
    if (_album.text.trim().isNotEmpty) metadata['album'] = _album.text.trim();
    if (_year.text.trim().isNotEmpty) metadata['year'] = _year.text.trim();

    setState(() => _submitting = true);
    try {
      await ApiManager().ytdl(
        url: url,
        directory: widget.directory,
        outputCodec: _codec,
        metadata: metadata,
      );
      YtdlManager().start();
      if (mounted) Navigator.of(context).pop();
      messenger
          .showSnackBar(const SnackBar(content: Text('Download started')));
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _url.removeListener(_onUrlChanged);
    _url.dispose();
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the soft keyboard.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.cloud_download_outlined, color: VelvetColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Download from URL',
                    style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Saves into ${widget.directory}',
                style:
                    TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: TextStyle(color: VelvetColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://www.youtube.com/watch?v=…',
                prefixIcon: Icon(Icons.link, color: VelvetColors.textSecondary),
              ),
            ),
            if (_metaLoading) ...[
              const SizedBox(height: 16),
              Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(VelvetColors.primary))),
                const SizedBox(width: 12),
                Text('Fetching details…',
                    style: TextStyle(color: VelvetColors.textSecondary)),
              ]),
            ],
            if (_metaReady) ...[
              const SizedBox(height: 16),
              if (_thumbnail != null)
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(VelvetColors.radiusSmall),
                  child: Image.network(_thumbnail!,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              const SizedBox(height: 12),
              _metaField(_title, 'Title'),
              const SizedBox(height: 12),
              _metaField(_artist, 'Artist'),
              const SizedBox(height: 12),
              _metaField(_album, 'Album'),
              const SizedBox(height: 12),
              _metaField(_year, 'Year', keyboard: TextInputType.number),
            ],
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Format',
                prefixIcon:
                    Icon(Icons.audiotrack, color: VelvetColors.textSecondary),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _codec,
                  dropdownColor: VelvetColors.raised,
                  style: TextStyle(color: VelvetColors.textPrimary),
                  items: _codecs
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.toUpperCase())))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _codec = v ?? _codec),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                ),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Icon(Icons.download),
              label: Text(_submitting ? 'Starting…' : 'Download'),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaField(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: TextStyle(color: VelvetColors.textPrimary),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}
