import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../singletons/api.dart';
import '../singletons/ytdl_manager.dart';
import '../theme/velvet_theme.dart';

/// "Add media" bottom sheet, replicating the webapp's file-explorer modal:
/// a Download (yt-dlp) tab and a Torrent tab, both acting on [directory]
/// (a server vpath). Built as a segmented sheet so a tab switch keeps
/// each form's in-progress input.
Future<void> showAddMediaSheet(BuildContext context, String directory) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: VelvetColors.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(VelvetColors.radiusLarge)),
    ),
    builder: (ctx) => Padding(
      // Lift the whole sheet above the soft keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AddMediaSheet(directory: directory),
    ),
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

/// Pull the suggested folder name out of a .torrent file's info dict —
/// scan bytes for "4:info" then "4:name<len>:<value>" (a direct port of
/// the webapp's extractTorrentName). Returns '' on any parse failure.
String extractTorrentName(List<int> bytes) {
  int i = 0;
  while (i < bytes.length - 8) {
    // "4:info"
    if (bytes[i] == 0x34 &&
        bytes[i + 1] == 0x3a &&
        bytes[i + 2] == 0x69 &&
        bytes[i + 3] == 0x6e &&
        bytes[i + 4] == 0x66 &&
        bytes[i + 5] == 0x6f) {
      if (bytes[i + 6] != 0x64) {
        i++;
        continue;
      } // expect a dict opener 'd'
      for (int j = i + 7; j < bytes.length - 8; j++) {
        // "4:name"
        if (bytes[j] == 0x34 &&
            bytes[j + 1] == 0x3a &&
            bytes[j + 2] == 0x6e &&
            bytes[j + 3] == 0x61 &&
            bytes[j + 4] == 0x6d &&
            bytes[j + 5] == 0x65) {
          int k = j + 6;
          final lenBuf = StringBuffer();
          while (k < bytes.length && bytes[k] != 0x3a) {
            lenBuf.writeCharCode(bytes[k]);
            k++;
          }
          final len = int.tryParse(lenBuf.toString());
          if (len == null || len <= 0 || len > 1024) return '';
          final start = k + 1;
          if (start + len > bytes.length) return '';
          return utf8.decode(bytes.sublist(start, start + len),
              allowMalformed: true);
        }
      }
      return '';
    }
    i++;
  }
  return '';
}

class _AddMediaSheet extends StatefulWidget {
  final String directory;
  const _AddMediaSheet({Key? key, required this.directory}) : super(key: key);

  @override
  State<_AddMediaSheet> createState() => _AddMediaSheetState();
}

class _AddMediaSheetState extends State<_AddMediaSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: VelvetColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              _seg(0, Icons.cloud_download_outlined, 'Download'),
              const SizedBox(width: 8),
              _seg(1, Icons.downloading, 'Torrent'),
            ]),
          ),
          // Both forms stay alive (IndexedStack) so switching tabs keeps
          // typed input; sized to the taller of the two.
          IndexedStack(
            index: _tab,
            children: [
              YtdlForm(directory: widget.directory),
              TorrentForm(directory: widget.directory),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seg(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? VelvetColors.primary : VelvetColors.raised,
            borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: active ? Colors.white : VelvetColors.textSecondary),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color:
                          active ? Colors.white : VelvetColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Download (yt-dlp) tab ─────────────────────────────────────────────

class YtdlForm extends StatefulWidget {
  final String directory;
  const YtdlForm({Key? key, required this.directory}) : super(key: key);

  @override
  State<YtdlForm> createState() => _YtdlFormState();
}

class _YtdlFormState extends State<YtdlForm> {
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Saves into ${widget.directory}',
              style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
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
                      valueColor: AlwaysStoppedAnimation(VelvetColors.primary))),
              const SizedBox(width: 12),
              Text('Fetching details…',
                  style: TextStyle(color: VelvetColors.textSecondary)),
            ]),
          ],
          if (_metaReady) ...[
            const SizedBox(height: 16),
            if (_thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                child: Image.network(_thumbnail!,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            const SizedBox(height: 12),
            _field(_title, 'Title'),
            const SizedBox(height: 12),
            _field(_artist, 'Artist'),
            const SizedBox(height: 12),
            _field(_album, 'Album'),
            const SizedBox(height: 12),
            _field(_year, 'Year', keyboard: TextInputType.number),
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
          _submitButton(
            label: _submitting ? 'Starting…' : 'Download',
            busy: _submitting,
            icon: Icons.download,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: TextStyle(color: VelvetColors.textPrimary),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

// ── Torrent tab ───────────────────────────────────────────────────────

class TorrentForm extends StatefulWidget {
  final String directory;
  const TorrentForm({Key? key, required this.directory}) : super(key: key);

  @override
  State<TorrentForm> createState() => _TorrentFormState();
}

class _TorrentFormState extends State<TorrentForm> {
  final _magnet = TextEditingController();
  final _dirName = TextEditingController();

  Map<String, dynamic>? _pre; // preflight result
  bool _preLoading = true;
  String? _preError;

  bool _dirAutofilled = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _runPreflight();
  }

  void _setDir(String value) {
    // Programmatic set: doesn't fire the field's onChanged, so the
    // autofilled flag stays true until the user edits the field.
    _dirName.text = value;
    _dirAutofilled = true;
  }

  Future<void> _runPreflight() async {
    try {
      final p = await ApiManager().torrentPreflight(widget.directory);
      if (!mounted) return;
      setState(() {
        _pre = p;
        _preLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preLoading = false;
        _preError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool get _featureOk =>
      _pre != null &&
      _pre!['active'] == true &&
      _pre!['userAllowed'] == true &&
      _pre!['noUpload'] != true &&
      _pre!['vpathConfirmed'] == true;

  void _onMagnetChanged() {
    final m = _magnet.text.trim();
    setState(() {
      if (m.isNotEmpty && (_dirName.text.isEmpty || _dirAutofilled)) {
        try {
          final dn = Uri.parse(m).queryParameters['dn'];
          if (dn != null && dn.isNotEmpty) _setDir(dn);
        } catch (_) {}
      }
    });
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final p = _pre;
    if (p == null) return;
    final vpath = p['vpath']?.toString() ?? '';
    final subPath = p['subPath']?.toString() ?? '';
    final dir = _dirName.text.trim();
    final magnet = _magnet.text.trim();

    if (vpath.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No library path for this folder')));
      return;
    }
    if (magnet.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Paste a magnet link')));
      return;
    }
    if (dir.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Enter a folder name')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final r = await ApiManager().torrentAdd(
        vpath: vpath,
        subPath: subPath,
        directoryName: dir,
        magnet: magnet,
      );
      if (mounted) Navigator.of(context).pop();
      final name = r['name']?.toString() ?? dir;
      final dup = r['isDuplicate'] == true;
      messenger.showSnackBar(SnackBar(
          content: Text(dup
              ? '"$name" is already in the client'
              : 'Added "$name"')));
      final warn = r['renameWarning'];
      if (warn != null) {
        messenger.showSnackBar(SnackBar(content: Text(warn.toString())));
      }
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  void dispose() {
    _magnet.dispose();
    _dirName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_preLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final displayName = _pre?['displayName']?.toString();
    final reason = _preError ?? _pre?['reason']?.toString();
    final daemonPath = _pre?['daemonPath']?.toString();
    final subPath = _pre?['subPath']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_featureOk && displayName != null)
            Text('Add via $displayName',
                style:
                    TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
          if (!_featureOk && reason != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: VelvetColors.error.withValues(alpha: 0.12),
                border: Border.all(color: VelvetColors.error),
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
              ),
              child: Row(children: [
                Icon(Icons.error_outline,
                    color: VelvetColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(reason,
                      style: TextStyle(
                          color: VelvetColors.textPrimary, fontSize: 13)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _magnet,
            autocorrect: false,
            onChanged: (_) => _onMagnetChanged(),
            style: TextStyle(color: VelvetColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Magnet link',
              hintText: 'magnet:?xt=urn:btih:…',
              prefixIcon: Icon(Icons.link, color: VelvetColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dirName,
            onChanged: (_) => setState(() => _dirAutofilled = false),
            style: TextStyle(color: VelvetColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Folder name',
              hintText: 'Auto-filled from the torrent',
              prefixIcon:
                  Icon(Icons.drive_file_rename_outline,
                      color: VelvetColors.textSecondary),
            ),
          ),
          if (daemonPath != null && _dirName.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Destination: $daemonPath${subPath.isNotEmpty ? '/$subPath' : ''}/${_dirName.text.trim()}',
              style:
                  TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),
          _submitButton(
            label: _submitting ? 'Adding…' : 'Add torrent',
            busy: _submitting,
            icon: Icons.downloading,
            onPressed: (_featureOk && !_submitting) ? _submit : null,
          ),
        ],
      ),
    );
  }
}

// Shared primary action button used by both tabs.
Widget _submitButton({
  required String label,
  required bool busy,
  required IconData icon,
  required VoidCallback? onPressed,
}) {
  return ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: VelvetColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: VelvetColors.raised,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
    ),
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white)))
        : Icon(icon),
    label: Text(label),
    onPressed: onPressed,
  );
}
