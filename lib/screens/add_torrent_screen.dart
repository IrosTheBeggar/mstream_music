import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/torrent_meta.dart';

/// The "smart" Add Torrent screen — the webapp's standalone panel: pick a
/// server + library, drop a magnet or .torrent, and it detects
/// artist/album/year (client-side name parse + optional server auto-detect)
/// and resolves the per-library path template into a destination.
/// Everything stays editable. Availability comes from /torrent/preflight —
/// there is no ping flag for torrents, so the screen itself is the gate
/// (a banner explains why when the server can't take one).
class AddTorrentScreen extends StatefulWidget {
  const AddTorrentScreen({super.key});

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
  // On by default: the whole point of the resolved destination path is that
  // the folder on disk matches it, and a scene release name rarely does.
  bool _renameRoot = true;
  bool _forceFresh = false;
  bool _detecting = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _servers = ServerManager().serverList;
    final cur = ServerManager().currentServer;
    _server = cur ?? (_servers.isNotEmpty ? _servers.first : null);
    if (_server != null) {
      _loadForServer(_server!);
    } else {
      _preLoading = false;
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

  /// The rest of the form only means something once there is a torrent to
  /// place, so it stays hidden until one of the two sources is real: a
  /// picked file, or a magnet we can pull an infohash out of.
  bool get _hasSource => _fileBytes != null || isValidMagnetLink(_magnet.text);

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

  // A .torrent almost always arrives through the browser, so start the picker
  // in Downloads. Android's SAF wants a content:// URI, the desktop pickers
  // want a real path, and null just leaves the picker where it was last.
  Future<String?> _pickerStartDirectory() async {
    if (Platform.isAndroid) {
      return 'content://com.android.externalstorage.documents'
          '/document/primary%3ADownload';
    }
    if (Platform.isIOS) return null;
    return (await getDownloadsDirectory())?.path;
  }

  Future<void> _pickFile() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // A single MIME type, so file_selector_android setType()s it directly
    // and the picker lists nothing but torrents — which also means the
    // folder's sort order stops mattering, since two files can't be lost in
    // it. Verified against a real Downloads folder: browser-downloaded
    // .torrent files are reported as application/x-bittorrent, while the
    // APKs/PNGs/PDFs/zips around them carry their own types and drop out.
    // If a torrent ever fails to appear, its provider reported something
    // else — add 'application/octet-stream' here to widen. isTorrentFile()
    // below still gates the bytes, which is what catches a mistyped file on
    // desktop, where the filter is by extension.
    const group = XTypeGroup(
      label: 'Torrent',
      extensions: ['torrent'],
      mimeTypes: ['application/x-bittorrent'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: const [group],
      initialDirectory: await _pickerStartDirectory(),
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (!isTorrentFile(bytes)) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.torrentNotATorrent(file.name))));
      return;
    }
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
    final l = AppLocalizations.of(context);
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
            content: Text(
                res['message']?.toString() ?? l.torrentDetectNoMetadata)));
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
          content: Text(
              conf == 'high' ? l.torrentDetected : l.torrentDetectGuess)));
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
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final s = _server;
    final vpath = _vpath;
    if (s == null || vpath == null || vpath.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.torrentPickLibrary)));
      return;
    }
    final magnet = _magnet.text.trim();
    final hasFile = _fileBytes != null;
    final hasMagnet = magnet.isNotEmpty;
    if (hasFile == hasMagnet) {
      messenger.showSnackBar(SnackBar(content: Text(l.torrentOneSource)));
      return;
    }
    final split = splitTorrentPath(_path.text.trim());
    if (split.directoryName.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.torrentPathEmpty)));
      return;
    }

    setState(() => _submitting = true);

    // Seed-existing pre-check (file-based only). If the files are already
    // on disk, seed them instead of re-downloading. Skipped for magnets
    // (no file list to hash) and when "force fresh" is on.
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
                ? l.torrentSeeded
                : l.torrentAlreadyInClient)));
        Navigator.of(context).pop();
        return;
      }
      if (outcome == 'invalid_torrent') {
        setState(() => _submitting = false);
        messenger.showSnackBar(SnackBar(
            content:
                Text(res['error']?.toString() ?? l.torrentInvalidFile)));
        return;
      }
      if (outcome == 'daemon_error') {
        // The seed-check itself failed (a server/daemon hiccup) — not a
        // reason to block the add. Fall through to a normal fresh download,
        // just letting the user know the existing-files check was skipped.
        messenger
            .showSnackBar(SnackBar(content: Text(l.torrentSeedCheckFailed)));
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
    final l = AppLocalizations.of(context);
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
      messenger.showSnackBar(SnackBar(
          content: Text(r['isDuplicate'] == true
              ? l.torrentDuplicate(name)
              : l.torrentAdded(name))));
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

  // The server found some of the torrent's files already on disk
  // elsewhere. Offer to point the torrent at one of those locations (seed
  // what's there + fetch only the missing files), or download fresh.
  void _showPartialMatch(List<dynamic> matches) {
    final s = _server;
    if (s == null) return;
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(VelvetColors.radiusLarge)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(l.torrentPartialTitle,
                  style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l.torrentPartialBody,
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
                      l.torrentPartialCount('${m['matched'] ?? '?'}',
                              '${m['total'] ?? '?'}') +
                          (m['missing'] != null
                              ? l.torrentPartialMissing('${m['missing']}')
                              : ''),
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
              title: Text(l.torrentDownloadFresh,
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
    if (split.directoryName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context).torrentMatchNoFolder)));
      }
      return;
    }
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(
        backgroundColor: VelvetColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: VelvetColors.textPrimary,
        title: Text(
          l.torrentScreenTitle,
          style: TextStyle(
            color: VelvetColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _server == null
            ? Center(
                child: Text(l.torrentNoServer,
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 14)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_servers.length > 1) ...[
                      _label(l.torrentServerLabel),
                      _serverDropdown(),
                      const SizedBox(height: 16),
                    ],
                    if (_preLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      if (!_featureOk) _reasonBanner(l),
                      // A lone library is not a choice. Zero libraries still
                      // renders, since the "no libraries" line is the
                      // explanation for the dead form below it.
                      if (_vpaths.length != 1) ...[
                        _label(l.torrentLibraryLabel),
                        _vpathDropdown(l),
                        const SizedBox(height: 16),
                      ],
                      _label(l.torrentSourceLabel),
                      _fileButton(l),
                      const SizedBox(height: 10),
                      _orDivider(l),
                      const SizedBox(height: 10),
                      _magnetField(l),
                      if (_hasSource) ...[
                        if (_fileBytes != null) ...[
                          const SizedBox(height: 10),
                          _autoDetectButton(l),
                        ],
                        const SizedBox(height: 16),
                        _label(l.torrentMetadataLabel),
                        _metaField(_artist, l.torrentArtistLabel),
                        const SizedBox(height: 10),
                        _metaField(_album, l.torrentAlbumLabel),
                        const SizedBox(height: 10),
                        _metaField(_year, l.torrentYearLabel,
                            keyboard: TextInputType.number),
                        const SizedBox(height: 16),
                        _label(l.torrentDestinationLabel),
                        _pathField(l),
                        const SizedBox(height: 6),
                        _preview(l),
                        const SizedBox(height: 8),
                        _renameToggle(l),
                        if (_fileBytes != null) _forceFreshToggle(l),
                        const SizedBox(height: 22),
                        _submitButton(l),
                      ],
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

  Widget _vpathDropdown(AppLocalizations l) {
    if (_vpaths.isEmpty) {
      return Text(l.torrentNoLibraries,
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

  Widget _fileButton(AppLocalizations l) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: VelvetColors.textPrimary,
          side: BorderSide(color: VelvetColors.border2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall)),
        ),
        icon: Icon(Icons.attach_file, color: VelvetColors.textSecondary),
        label: Text(_fileName ?? l.torrentChooseFile),
        onPressed: _submitting ? null : _pickFile,
      );

  Widget _orDivider(AppLocalizations l) => Row(children: [
        Expanded(child: Divider(color: VelvetColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(l.torrentOr,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
        ),
        Expanded(child: Divider(color: VelvetColors.border)),
      ]);

  Widget _magnetField(AppLocalizations l) {
    final typed = _magnet.text.trim();
    return TextField(
      controller: _magnet,
      autocorrect: false,
      onChanged: (_) => _onMagnetChanged(),
      style: TextStyle(color: VelvetColors.textPrimary),
      decoration: InputDecoration(
        labelText: l.torrentMagnetLabel,
        hintText: 'magnet:?xt=urn:btih:…',
        prefixIcon: Icon(Icons.link, color: VelvetColors.textSecondary),
        // Without this a typo just leaves the form hidden, which reads as
        // a dead screen.
        errorText: (typed.isNotEmpty && !isValidMagnetLink(typed))
            ? l.torrentMagnetInvalid
            : null,
      ),
    );
  }

  Widget _autoDetectButton(AppLocalizations l) => OutlinedButton.icon(
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
        label:
            Text(_detecting ? l.torrentDetecting : l.torrentAutoDetect),
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

  Widget _pathField(AppLocalizations l) => TextField(
        controller: _path,
        onChanged: (_) => setState(() => _pathEdited = true),
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: InputDecoration(
          labelText: l.torrentPathLabel,
          hintText: 'Artist/Album',
          isDense: true,
          prefixIcon:
              Icon(Icons.folder_outlined, color: VelvetColors.textSecondary),
        ),
      );

  Widget _preview(AppLocalizations l) {
    final vp = _vpath ?? '';
    final p = _path.text.trim().replaceAll(RegExp(r'/+$'), '');
    return Text(
      vp.isEmpty
          ? l.torrentPreviewNoLibrary(p)
          : '/$vp/$p/${l.torrentPreviewContents}',
      style: TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _renameToggle(AppLocalizations l) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.torrentRenameRoot,
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14)),
        subtitle: Text(l.torrentRenameRootSub,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
        value: _renameRoot,
        onChanged: _submitting ? null : (v) => setState(() => _renameRoot = v),
        activeThumbColor: VelvetColors.primary,
      );

  Widget _forceFreshToggle(AppLocalizations l) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.torrentForceFresh,
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14)),
        subtitle: Text(l.torrentForceFreshSub,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
        value: _forceFresh,
        onChanged: _submitting ? null : (v) => setState(() => _forceFresh = v),
        activeThumbColor: VelvetColors.primary,
      );

  Widget _submitButton(AppLocalizations l) => FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: VelvetColors.primary,
          foregroundColor: VelvetColors.bg,
          disabledBackgroundColor: VelvetColors.raised,
          disabledForegroundColor: VelvetColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: _submitting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(VelvetColors.bg)))
            : const Icon(Icons.downloading),
        label: Text(_submitting ? l.torrentSubmitting : l.torrentSubmit),
        onPressed: (_featureOk && !_submitting) ? _submit : null,
      );

  Widget _reasonBanner(AppLocalizations l) {
    final reason =
        _preError ?? _pre?['reason']?.toString() ?? l.torrentUnavailable;
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
