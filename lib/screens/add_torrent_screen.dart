import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/torrent_meta.dart';

/// The "smart" Add Torrent screen — the webapp's standalone panel (not the
/// directory-tied modal tab): pick a server + library, drop a magnet or
/// .torrent, and it detects artist/album/year (client-side name parse +
/// optional server auto-detect) and resolves the per-library path
/// template into a destination. Everything stays editable.
class AddTorrentScreen extends StatefulWidget {
  const AddTorrentScreen({Key? key}) : super(key: key);

  @override
  State<AddTorrentScreen> createState() => _AddTorrentScreenState();
}

class _AddTorrentScreenState extends State<AddTorrentScreen> {
  late List<Server> _servers;
  Server? _server;

  List<String> _vpaths = const [];
  String? _vpath;

  Map<String, dynamic>? _pre;
  bool _preLoading = true;
  String? _preError;
  Map<String, String> _templates = const {};

  final _magnet = TextEditingController();
  final _artist = TextEditingController();
  final _album = TextEditingController();
  final _year = TextEditingController();
  final _path = TextEditingController();

  List<int>? _fileBytes;
  String? _fileName;
  bool _pathEdited = false;
  bool _renameRoot = false;
  bool _forceFresh = false;
  bool _detecting = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Only supported (non-velvet) servers can take torrents.
    _servers = ServerManager().serverList.where((s) => !s.unsupported).toList();
    final cur = ServerManager().currentServer;
    _server = (cur != null && !cur.unsupported)
        ? cur
        : (_servers.isNotEmpty ? _servers.first : null);
    if (_server != null) {
      _loadForServer(_server!);
    } else {
      _preLoading = false;
      _preError = 'No supported server is configured.';
    }
  }

  Future<void> _loadForServer(Server s) async {
    setState(() {
      _preLoading = true;
      _preError = null;
      _pre = null;
      _vpaths = s.autoDJPaths.keys.toList();
      _vpath = _vpaths.isNotEmpty ? _vpaths.first : null;
      _templates = const {};
    });

    try {
      // Empty path → global gates (client active, user allowed, uploads
      // enabled). Per-vpath confirmation is enforced by /torrent/add.
      final pre = await ApiManager().torrentPreflight('', server: s);
      if (!mounted || _server != s) return;
      setState(() {
        _pre = pre;
        _preLoading = false;
      });
    } catch (e) {
      if (!mounted || _server != s) return;
      setState(() {
        _preLoading = false;
        _preError = e.toString().replaceFirst('Exception: ', '');
      });
    }

    // Path templates are best-effort (older servers may not have them).
    try {
      final tpl = await ApiManager().torrentPathTemplates(server: s);
      if (!mounted || _server != s) return;
      final raw = tpl['vpaths'];
      final map = <String, String>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          final t = (v is Map) ? v['template'] : null;
          if (t is String && t.isNotEmpty) map[k.toString()] = t;
        });
      }
      setState(() => _templates = map);
      _recomputePath();
    } catch (_) {
      // No templates — the legacy artist/album fallback still applies.
    }
  }

  bool get _featureOk =>
      _pre != null &&
      _pre!['active'] == true &&
      _pre!['userAllowed'] == true &&
      _pre!['noUpload'] != true;

  TorrentMeta get _meta => TorrentMeta(
      _artist.text.trim(), _album.text.trim(), _year.text.trim(), '');

  void _recomputePath() {
    if (_pathEdited) return;
    final tmpl = _vpath != null ? _templates[_vpath] : null;
    setState(() => _path.text = computeTorrentPath(tmpl, _meta));
  }

  void _applyMeta(TorrentMeta m, {bool resetPathEdited = false}) {
    setState(() {
      _artist.text = m.artist;
      _album.text = m.album;
      _year.text = m.year;
      if (resetPathEdited) _pathEdited = false;
    });
    _recomputePath();
  }

  Future<void> _pickFile() async {
    final group = XTypeGroup(label: 'Torrent', extensions: const ['torrent']);
    final XFile? file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _fileBytes = bytes;
      _fileName = file.name;
      _magnet.clear();
    });
    final name = extractTorrentName(bytes);
    if (name.isNotEmpty) {
      _applyMeta(parseMusicTorrentName(name), resetPathEdited: true);
    }
  }

  void _onMagnetChanged() {
    final m = _magnet.text.trim();
    setState(() {
      if (m.isNotEmpty && _fileBytes != null) {
        _fileBytes = null;
        _fileName = null;
      }
    });
    if (m.isNotEmpty) {
      String? dn;
      try {
        dn = Uri.parse(m).queryParameters['dn'];
      } catch (_) {}
      if (dn != null && dn.isNotEmpty) {
        _applyMeta(parseMusicTorrentName(dn), resetPathEdited: true);
      }
    }
  }

  Future<void> _autoDetect() async {
    final bytes = _fileBytes;
    final s = _server;
    if (bytes == null || s == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _detecting = true);
    try {
      final res = await ApiManager().torrentAutoDetect(
        torrentBytes: bytes,
        torrentFilename: _fileName,
        vpath: _vpath,
        server: s,
      );
      if (!mounted) return;
      if (res['ok'] != true) {
        messenger.showSnackBar(SnackBar(
            content: Text(res['message']?.toString() ??
                'Not enough metadata — fill the fields in manually')));
        return;
      }
      final md = res['metadata'];
      if (md is Map) {
        _applyMeta(
          TorrentMeta((md['artist'] ?? '').toString(),
              (md['album'] ?? '').toString(), (md['year'] ?? '').toString(), ''),
          resetPathEdited: true,
        );
      }
      final conf = res['confidence']?.toString();
      messenger.showSnackBar(SnackBar(
          content: Text(conf == 'high'
              ? 'Metadata detected'
              : 'Best-effort guess — please verify the fields')));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final s = _server;
    final vpath = _vpath;
    if (s == null || vpath == null || vpath.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a library')));
      return;
    }
    final magnet = _magnet.text.trim();
    final hasFile = _fileBytes != null;
    final hasMagnet = magnet.isNotEmpty;
    if (hasFile == hasMagnet) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Add a magnet link or a .torrent file (one)')));
      return;
    }
    final split = splitTorrentPath(_path.text.trim());
    if (split.directoryName.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Destination path is empty')));
      return;
    }

    setState(() => _submitting = true);

    // Phase C: seed-existing pre-check (file-based only). If the files
    // are already on disk, seed them instead of re-downloading. Skipped
    // for magnets (no file to hash) and when "force fresh" is on.
    if (hasFile && !_forceFresh) {
      Map<String, dynamic> res;
      try {
        res = await ApiManager()
            .torrentSeedExisting(torrentBytes: _fileBytes!, server: s);
      } catch (e) {
        if (mounted) {
          setState(() => _submitting = false);
          messenger.showSnackBar(SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', ''))));
        }
        return;
      }
      if (!mounted) return;
      final outcome = res['outcome']?.toString();
      if (outcome == 'seeded' || outcome == 'already_in_daemon') {
        messenger.showSnackBar(SnackBar(
            content: Text(outcome == 'seeded'
                ? 'Already on disk — seeding it now'
                : 'Already in the torrent client')));
        Navigator.of(context).pop();
        return;
      }
      if (outcome == 'invalid_torrent' || outcome == 'daemon_error') {
        setState(() => _submitting = false);
        messenger.showSnackBar(SnackBar(
            content: Text(res['error']?.toString() ??
                'Could not check for existing files')));
        return;
      }
      if (outcome == 'partial_match') {
        setState(() => _submitting = false);
        _showPartialMatch((res['matches'] as List?) ?? const []);
        return;
      }
      // no_match (or anything unexpected) → fall through to a fresh add.
    }

    await _doAdd(
      server: s,
      vpath: vpath,
      magnet: hasMagnet ? magnet : null,
      bytes: hasFile ? _fileBytes : null,
      subPath: split.subPath,
      directoryName: split.directoryName,
    );
  }

  // The actual /torrent/add. Assumes _submitting is already true.
  Future<void> _doAdd({
    required Server server,
    required String vpath,
    String? magnet,
    List<int>? bytes,
    required String subPath,
    required String directoryName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ApiManager().torrentAdd(
        server: server,
        vpath: vpath,
        subPath: subPath,
        directoryName: directoryName,
        renameRoot: _renameRoot,
        magnet: magnet,
        torrentBytes: bytes,
        torrentFilename: _fileName,
      );
      if (!mounted) return;
      final name = r['name']?.toString() ?? directoryName;
      final dup = r['isDuplicate'] == true;
      messenger.showSnackBar(SnackBar(
          content: Text(
              dup ? '"$name" is already in the client' : 'Added "$name"')));
      final warn = r['renameWarning'];
      if (warn != null) {
        messenger.showSnackBar(SnackBar(content: Text(warn.toString())));
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  // Phase C: the server found some of the torrent's files already on
  // disk elsewhere. Offer to point the torrent at one of those locations
  // (seed what's there + fetch only the missing files), or download fresh.
  void _showPartialMatch(List<dynamic> matches) {
    final s = _server;
    if (s == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(VelvetColors.radiusLarge)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Some files already exist',
                  style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                  'Point the torrent at an existing copy to seed it and '
                  'download only what is missing.',
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12)),
            ),
            for (final m in matches)
              if (m is Map)
                ListTile(
                  leading:
                      Icon(Icons.folder_open, color: VelvetColors.primary),
                  title: Text('${m['vpath'] ?? ''}/${m['relativePath'] ?? ''}',
                      style: TextStyle(color: VelvetColors.textPrimary)),
                  subtitle: Text(
                      '${m['matched'] ?? '?'}/${m['total'] ?? '?'} files here'
                      '${m['missing'] != null ? ' · ${m['missing']} to download' : ''}',
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _useMatch(s, m);
                  },
                ),
            Divider(height: 1, color: VelvetColors.border),
            ListTile(
              leading:
                  Icon(Icons.download, color: VelvetColors.textSecondary),
              title: Text('Download fresh anyway',
                  style: TextStyle(color: VelvetColors.textPrimary)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                final split = splitTorrentPath(_path.text.trim());
                setState(() => _submitting = true);
                _doAdd(
                  server: s,
                  vpath: _vpath ?? '',
                  bytes: _fileBytes,
                  subPath: split.subPath,
                  directoryName: split.directoryName,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _useMatch(Server s, Map m) {
    final mv = (m['vpath'] ?? _vpath ?? '').toString();
    final split = splitTorrentPath((m['relativePath'] ?? '').toString());
    if (split.directoryName.isEmpty) return;
    setState(() => _submitting = true);
    _doAdd(
      server: s,
      vpath: mv,
      bytes: _fileBytes,
      subPath: split.subPath,
      directoryName: split.directoryName,
    );
  }

  @override
  void dispose() {
    _magnet.dispose();
    _artist.dispose();
    _album.dispose();
    _year.dispose();
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Torrent')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_servers.length > 1) ...[
                _label('Server'),
                _serverDropdown(),
                const SizedBox(height: 16),
              ],
              if (_preLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (!_featureOk) _reasonBanner(),
                _label('Library'),
                _vpathDropdown(),
                const SizedBox(height: 16),
                _label('Source'),
                _fileButton(),
                const SizedBox(height: 10),
                _orDivider(),
                const SizedBox(height: 10),
                _magnetField(),
                if (_fileBytes != null) ...[
                  const SizedBox(height: 10),
                  _autoDetectButton(),
                ],
                const SizedBox(height: 16),
                _label('Metadata'),
                _metaField(_artist, 'Artist'),
                const SizedBox(height: 10),
                _metaField(_album, 'Album'),
                const SizedBox(height: 10),
                _metaField(_year, 'Year', keyboard: TextInputType.number),
                const SizedBox(height: 16),
                _label('Destination'),
                _pathField(),
                const SizedBox(height: 6),
                _preview(),
                const SizedBox(height: 8),
                _renameToggle(),
                if (_fileBytes != null) _forceFreshToggle(),
                const SizedBox(height: 22),
                _submitButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── widget helpers ──────────────────────────────────────────────────

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s.toUpperCase(),
            style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _dropdownBox(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: VelvetColors.raised,
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        ),
        child: DropdownButtonHideUnderline(child: child),
      );

  Widget _serverDropdown() => _dropdownBox(
        DropdownButton<Server>(
          isExpanded: true,
          value: _server,
          dropdownColor: VelvetColors.raised,
          style: TextStyle(color: VelvetColors.textPrimary),
          items: _servers
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.url, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (_submitting || _detecting)
              ? null
              : (s) {
                  if (s == null || s == _server) return;
                  setState(() => _server = s);
                  _loadForServer(s);
                },
        ),
      );

  Widget _vpathDropdown() {
    if (_vpaths.isEmpty) {
      return Text('No libraries on this server',
          style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13));
    }
    return _dropdownBox(
      DropdownButton<String>(
        isExpanded: true,
        value: _vpath,
        dropdownColor: VelvetColors.raised,
        style: TextStyle(color: VelvetColors.textPrimary),
        items: _vpaths
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: _submitting
            ? null
            : (v) {
                setState(() => _vpath = v);
                _recomputePath();
              },
      ),
    );
  }

  Widget _fileButton() => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: VelvetColors.textPrimary,
          side: BorderSide(color: VelvetColors.border2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall)),
        ),
        icon: Icon(Icons.attach_file, color: VelvetColors.textSecondary),
        label: Text(_fileName ?? 'Choose .torrent file'),
        onPressed: _submitting ? null : _pickFile,
      );

  Widget _orDivider() => Row(children: [
        Expanded(child: Divider(color: VelvetColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('or',
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
        ),
        Expanded(child: Divider(color: VelvetColors.border)),
      ]);

  Widget _magnetField() => TextField(
        controller: _magnet,
        autocorrect: false,
        onChanged: (_) => _onMagnetChanged(),
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Magnet link',
          hintText: 'magnet:?xt=urn:btih:…',
          prefixIcon: Icon(Icons.link, color: VelvetColors.textSecondary),
        ),
      );

  Widget _autoDetectButton() => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: VelvetColors.primary,
          side: BorderSide(color: VelvetColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall)),
        ),
        icon: _detecting
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(VelvetColors.primary)))
            : const Icon(Icons.auto_fix_high),
        label: Text(_detecting ? 'Detecting…' : 'Auto-detect metadata'),
        onPressed: (_detecting || _submitting) ? null : _autoDetect,
      );

  Widget _metaField(TextEditingController c, String label,
          {TextInputType? keyboard}) =>
      TextField(
        controller: c,
        keyboardType: keyboard,
        onChanged: (_) => _recomputePath(),
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  Widget _pathField() => TextField(
        controller: _path,
        onChanged: (_) => setState(() => _pathEdited = true),
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Path in library',
          hintText: 'Artist/Album',
          isDense: true,
          prefixIcon:
              Icon(Icons.folder_outlined, color: VelvetColors.textSecondary),
        ),
      );

  Widget _preview() {
    final vp = _vpath ?? '';
    final p = _path.text.trim().replaceAll(RegExp(r'/+$'), '');
    return Text(
      vp.isEmpty ? '<no library>/$p' : '/$vp/$p/<torrent contents>',
      style: TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _renameToggle() => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text("Rename the torrent's root folder",
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14)),
        subtitle: Text('Match the destination folder name',
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
        value: _renameRoot,
        onChanged: _submitting ? null : (v) => setState(() => _renameRoot = v),
        activeThumbColor: VelvetColors.primary,
      );

  Widget _forceFreshToggle() => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Force fresh download',
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14)),
        subtitle: Text('Skip checking for files already on the server',
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
        value: _forceFresh,
        onChanged: _submitting ? null : (v) => setState(() => _forceFresh = v),
        activeThumbColor: VelvetColors.primary,
      );

  Widget _submitButton() => ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: VelvetColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: VelvetColors.raised,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall)),
        ),
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white)))
            : const Icon(Icons.downloading),
        label: Text(_submitting ? 'Adding…' : 'Add torrent'),
        onPressed: (_featureOk && !_submitting) ? _submit : null,
      );

  Widget _reasonBanner() {
    final reason = _preError ??
        _pre?['reason']?.toString() ??
        'Torrents are unavailable on this server.';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: VelvetColors.error.withValues(alpha: 0.12),
        border: Border.all(color: VelvetColors.error),
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: VelvetColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(reason,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 13))),
      ]),
    );
  }
}
