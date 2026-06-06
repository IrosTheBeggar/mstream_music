import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../build_variant.dart';
import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/file_explorer.dart';
import '../singletons/server_list.dart';
import '../singletons/browser_list.dart';
import '../singletons/migration_manager.dart';
import '../singletons/downloads.dart';
import '../theme/velvet_theme.dart';
import '../util/server_compat.dart';

class AddServerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).addServerTitle),
        ),
        body: MyCustomForm());
  }
}

class EditServerScreen extends StatelessWidget {
  final int editThisServer;
  const EditServerScreen({Key? key, required this.editThisServer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).editServerTitle),
        ),
        body: MyCustomForm(editThisServer: editThisServer));
  }
}

class MyCustomForm extends StatefulWidget {
  final int? editThisServer;
  const MyCustomForm({Key? key, this.editThisServer}) : super(key: key);

  @override
  MyCustomFormState createState() {
    return MyCustomFormState(editThisServer: editThisServer);
  }
}

// Create a corresponding State class. This class will hold the data related to
// the form.
class MyCustomFormState extends State<MyCustomForm> {
  // Create a global key that will uniquely identify the Form widget and allow
  // us to validate the form
  // Note: This is a GlobalKey<FormState>, not a GlobalKey<MyCustomFormState>!
  final _formKey = GlobalKey<FormState>();

  TextEditingController _urlCtrl = TextEditingController();
  TextEditingController _usernameCtrl = TextEditingController();
  TextEditingController _passwordCtrl = TextEditingController();
  // Per-server download subfolder (downloads live in media/<this>).
  // Defaults to a generated id; making it editable lets a re-added
  // server reuse its old folder and recover its downloaded songs.
  final TextEditingController _downloadFolderCtrl = TextEditingController();
  // True once the user types in / picks the download folder, so the URL
  // auto-fill (subdomain-domain) stops overwriting their choice. Also set
  // in edit mode, where the existing folder must be preserved.
  bool _folderManuallyEdited = false;

  bool submitPending = false;
  // Download storage destination: 'appLocal' | 'permanent' | 'sdCard'
  // (+ migration-only 'legacyExternal', shown as App local). 'permanent'
  // and 'sdCard' also keep an absolute base dir in _storageBasePath.
  String _storageMode = 'appLocal';
  // Full flavor only: accept a self-signed / untrusted TLS cert for this server.
  bool _allowSelfSigned = false;
  String? _storageBasePath;
  // Browsable volume roots derived in _detectSdCard for the folder picker.
  String? _sharedStorageRoot;
  String? _sdCardRoot;
  // Public-access mode: server is reachable without authentication.
  // Disables the username/password fields and skips the login
  // fallback in checkServer. checkServer's existing /api/v1/ping
  // path already handles public servers; the toggle just makes that
  // explicit in the UI.
  bool _publicAccess = false;
  // Hidden by default until we know. Set to true once
  // _detectSdCard finds a real removable storage volume.
  bool _hasSdCard = false;
  // Test-connection state. Null result = no banner shown; true =
  // green success banner; false = red error banner.
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  final int? editThisServer;
  MyCustomFormState({this.editThisServer}) : super();

  @protected
  @mustCallSuper
  void initState() {
    super.initState();

    bool isEdit = false;
    try {
      Server s = ServerManager().serverList[editThisServer ?? -1];
      _urlCtrl.text = s.url;
      _usernameCtrl.text = s.username ?? '';
      _passwordCtrl.text = s.password ?? '';
      _storageMode = s.storageMode;
      _allowSelfSigned = s.allowSelfSigned;
      _storageBasePath = s.storageBasePath;
      _downloadFolderCtrl.text = s.localname;
      isEdit = true;
      // An existing server saved without credentials is a public
      // server — start in public mode so the toggle reflects reality.
      if ((s.username ?? '').isEmpty && (s.password ?? '').isEmpty) {
        _publicAccess = true;
      }
    } catch (err) {}

    // Existing server: keep its folder as-is (it maps to already-downloaded
    // files). New server: auto-derive the folder from the URL as the user
    // types it, until they edit it themselves.
    _folderManuallyEdited = isEdit;
    if (!isEdit) {
      _maybeAutofillFolder();
    }

    _detectSdCard();

    // Stale-result-clearing: editing the URL invalidates whatever
    // banner the last test produced (it was for a different URL).
    _urlCtrl.addListener(_clearTestResult);
    // Auto-name the download folder from the URL (new servers only).
    _urlCtrl.addListener(_maybeAutofillFolder);
  }

  void _clearTestResult() {
    if (_testResult != null) {
      setState(() {
        _testResult = null;
        _testSuccess = null;
      });
    }
  }

  // Auto-fills the download folder from the server URL as
  // "${subdomain}-${domain}" (e.g. music.rum.st -> music-rum.st), unless
  // the user has already typed or picked a folder. New servers only.
  void _maybeAutofillFolder() {
    if (_folderManuallyEdited) return;
    final name = _computeAutoFolder();
    if (name != null && _downloadFolderCtrl.text != name) {
      _downloadFolderCtrl.text = name;
    }
  }

  // The auto folder name: "${subdomain}-${domain}", plus a stable short id
  // when another configured server already uses that name — so two servers
  // on the same domain don't share one download directory. (Checks the
  // server list, not the filesystem, so re-adding a lost server can still
  // reuse its orphaned folder for recovery.)
  String? _computeAutoFolder() {
    final base = _defaultLocalName(_urlCtrl.text);
    if (base == null) return null;
    return _localNameTaken(base) ? '$base-$_folderSuffix' : base;
  }

  // Does any *other* configured server already use this folder name?
  bool _localNameTaken(String name) {
    final list = ServerManager().serverList;
    for (int i = 0; i < list.length; i++) {
      if (i == editThisServer) continue; // ignore the server being edited
      if (list[i].localname == name) return true;
    }
    return false;
  }

  // Stable per-screen short id, generated once and reused so the suffix
  // doesn't churn while the user is still typing the URL.
  String? _cachedFolderSuffix;
  String get _folderSuffix => _cachedFolderSuffix ??= _nanoId();

  String _nanoId([int length = 6]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  // Derives a clean folder name from a server URL: the host's first label
  // (subdomain), a dash, then the remaining labels (domain). IP / single-
  // label / no-subdomain hosts use the bare host. Returns null if no host
  // can be parsed yet. Sanitized for FAT/ext filesystems (SD cards).
  String? _defaultLocalName(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return null;
    String host;
    try {
      host = Uri.parse(raw.contains('://') ? raw : 'https://$raw').host;
    } catch (_) {
      return null;
    }
    if (host.isEmpty) return null;
    if (host.startsWith('www.')) host = host.substring(4);

    final isIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    final labels = host.split('.');
    final String name;
    if (isIpv4 || host.contains(':') || labels.length < 3) {
      name = host; // IP / single label / bare domain — use as-is
    } else {
      name = '${labels.first}-${labels.sublist(1).join('.')}';
    }
    // Keep only filesystem-safe characters, then strip any leading or
    // trailing separators so a no-subdomain or odd host can't yield a name
    // starting with '-', '.', or '/'.
    final safe = name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')
        .replaceAll(RegExp(r'^[-._]+'), '')
        .replaceAll(RegExp(r'[-._]+$'), '');
    return safe.isEmpty ? null : safe;
  }

  // Verifies the connection the same way the Save button does: an
  // unauthenticated /api/v1/ping first, then — if the server requires
  // auth — a login with the entered credentials. Previously this only
  // hit the public /api/ version endpoint and treated any non-200 as a
  // failure, so it falsely reported a 401 on servers that require
  // authentication even though Save (which logs in) worked fine.
  Future<void> _testConnection() async {
    final l = AppLocalizations.of(context);
    if (_urlCtrl.text.trim().isEmpty) {
      setState(() {
        _testResult = l.testEnterUrl;
        _testSuccess = false;
      });
      return;
    }

    Uri url;
    try {
      url = Uri.parse(_urlCtrl.text.trim());
      if (url.origin is Error || url.origin.isEmpty) throw Exception();
    } catch (_) {
      setState(() {
        _testResult = l.testParseUrl;
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      // Fail unsupported builds with the same generic message Save uses.
      if (!await isServerSupported(url.toString())) {
        _showTestResult(false, l.testCouldNotConnect);
        return;
      }

      // 1) Unauthenticated ping — succeeds for public servers (and any
      //    server that doesn't gate /api/v1/ping behind auth).
      final ping = await http
          .get(url.resolve('/api/v1/ping'))
          .timeout(Duration(seconds: 5));
      if (ping.statusCode == 200) {
        _showTestResult(
            true, l.connectionSuccessful + await _serverVersionSuffix(url));
        return;
      }

      // 2) Server needs auth. In public-access mode there are no
      //    credentials to try, so report that plainly.
      if (_publicAccess) {
        _showTestResult(false, l.couldNotReachServer);
        return;
      }

      // 3) Authenticate with the entered credentials — exactly what Save
      //    does — so the test reflects real, credentialed connectivity.
      final login = await http.post(url.resolve('/api/v1/auth/login'), body: {
        'username': _usernameCtrl.text,
        'password': _passwordCtrl.text,
      }).timeout(Duration(seconds: 6));

      if (login.statusCode == 200) {
        _showTestResult(true, l.testConnectedSignedIn);
      } else {
        _showTestResult(false, l.testSignInFailed);
      }
    } on TimeoutException {
      _showTestResult(false, l.testTimedOut);
    } catch (e) {
      _showTestResult(false, l.testConnectFailed('$e'));
    }
  }

  void _showTestResult(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSuccess = success;
      _testResult = message;
    });
  }

  // Best-effort version string for the success banner. Never throws: the
  // public /api/ endpoint may be unreachable on auth-walled servers, in
  // which case the version is simply omitted.
  Future<String> _serverVersionSuffix(Uri url) async {
    try {
      final resp =
          await http.get(url.resolve('/api/')).timeout(Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final version = data['server']?.toString();
        if (version != null && version.isNotEmpty) {
          return ' — mStream v$version';
        }
      }
    } catch (_) {}
    return '';
  }

  // path_provider's getExternalStorageDirectories returns one Directory
  // per storage volume on Android. Modern phones with only internal
  // storage emulating "external" return a single entry; an actual
  // removable SD card adds a second. So length > 1 is our signal.
  // Throws on iOS / desktop — caught, leaving the switch hidden.
  Future<void> _detectSdCard() async {
    try {
      final dirs = await getExternalStorageDirectories();
      final hasSd = dirs != null && dirs.length > 1;
      // Derive the browsable volume roots for the folder picker by
      // stripping the "/Android/data/<pkg>/files" app-private suffix.
      String? sharedRoot;
      String? sdRoot;
      if (dirs != null && dirs.isNotEmpty) {
        sharedRoot = _volumeRoot(dirs[0].path);
        if (dirs.length > 1) sdRoot = _volumeRoot(dirs[1].path);
      }
      if (mounted) {
        setState(() {
          _hasSdCard = hasSd;
          _sharedStorageRoot = sharedRoot;
          _sdCardRoot = sdRoot;
        });
      }
    } catch (_) {
      // Platform doesn't support it — stay hidden.
    }
  }

  // ".../Android/data/<pkg>/files" -> the volume root the user can browse
  // (e.g. /storage/emulated/0 or /storage/<uuid>). Falls back to the input
  // when the app-private suffix isn't present.
  String _volumeRoot(String appDirPath) {
    final idx = appDirPath.indexOf('/Android/');
    return idx > 0 ? appDirPath.substring(0, idx) : appDirPath;
  }

  @override
  void dispose() {
    _urlCtrl.removeListener(_clearTestResult);
    _urlCtrl.removeListener(_maybeAutofillFolder);
    _urlCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _downloadFolderCtrl.dispose();

    super.dispose();
  }

  checkServer() async {
    final l = AppLocalizations.of(context);
    setState(() {
      submitPending = true;
    });
    Uri lol = Uri.parse(this._urlCtrl.text);
    var response;

    // Compatibility gate: refuse server builds this client doesn't
    // support, surfacing only a generic failure (no special-casing
    // shown to the user).
    if (!await isServerSupported(lol.toString())) {
      if (mounted) {
        setState(() {
          submitPending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.connectFailedSnack)));
      }
      return;
    }

    try {
      // Do a quick check on /ping to see if this server even needs authentication
      response = await http
          .get(lol.resolve('/api/v1/ping'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        // setState(() {
        //   submitPending = false;
        // });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.connectionSuccessful)));
        saveServer(lol);
        return;
      }
    } catch (err) {}

    // Public access mode: no credentials to try, so surface the
    // failure clearly instead of falling through to a login attempt
    // that would just produce "Failed to Login."
    if (_publicAccess) {
      if (mounted) {
        setState(() {
          submitPending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.couldNotReachServer),
        ));
      }
      return;
    }

    // Try logging in
    try {
      response = await http.post(lol.resolve('/api/v1/auth/login'), body: {
        "username": this._usernameCtrl.text,
        "password": this._passwordCtrl.text
      }).timeout(Duration(seconds: 6));

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to server');
      }

      var res = jsonDecode(response.body);

      // Save
      saveServer(lol, res['token']);
    } catch (err) {
      print(err);
      try {
        setState(() {
          submitPending = false;
        });
      } catch (e) {}

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.failedToLogin)));
      return;
    }
  }

  // Before an edited server's storage pointers change, relocate its
  // already-downloaded files (the media/<localname> subtree). Within one
  // volume this is an instant, atomic rename; across volumes (App local on
  // internal storage -> a Permanent/SD folder) rename can't cross
  // filesystems, so we offer an async copy (copy -> verify -> delete
  // originals) or a switch-without-copying. Returns false only when the user
  // cancels (so the save is aborted).
  Future<bool> _migrateDownloads({
    required String oldMode,
    required String? oldBasePath,
    required String oldLocalname,
    required String newMode,
    required String? newBasePath,
    required String newLocalname,
  }) async {
    final oldBase = await FileExplorer().getDownloadDir(oldMode, oldBasePath);
    if (oldBase == null) return true; // old location gone — nothing to move
    final oldDir = Directory(path.join(oldBase.path, 'media', oldLocalname));
    bool hasFiles = false;
    try {
      hasFiles = oldDir.existsSync() && oldDir.listSync().isNotEmpty;
    } catch (_) {}
    if (!hasFiles) return true; // nothing downloaded yet

    final newBase = await FileExplorer().getDownloadDir(newMode, newBasePath);
    if (newBase == null) return true; // new location unavailable right now
    final newDir = Directory(path.join(newBase.path, 'media', newLocalname));
    if (oldDir.path == newDir.path) return true; // same target, no-op
    // Don't clobber a destination that already holds files — the user is
    // pointing at an existing folder (recovery), not moving into a fresh one.
    try {
      if (newDir.existsSync() && newDir.listSync().isNotEmpty) return true;
    } catch (_) {}

    // Try an atomic move — succeeds only within the same volume.
    try {
      Directory(path.join(newBase.path, 'media')).createSync(recursive: true);
      oldDir.renameSync(newDir.path);
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.storageMovedToNewFolder)));
      }
      return true;
    } catch (_) {
      // Cross-volume: rename can't cross filesystems — ask what to do.
      return await _promptCrossVolume(oldDir, newDir);
    }
  }

  // Cross-volume relocation. The files can't be instantly moved, so offer
  // three clear choices: move them in the background (per-file copy+delete,
  // resumable), leave them where they are, or delete the old copies. All
  // three proceed with the storage change; only Cancel aborts it.
  Future<bool> _promptCrossVolume(Directory oldDir, Directory newDir) async {
    if (!mounted) return false;
    final l = AppLocalizations.of(context);
    if (MigrationManager().isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.storageMoveAlreadyRunning)));
      return false;
    }
    // Count + size for the prompt.
    int count = 0;
    int bytes = 0;
    try {
      await for (final e in oldDir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          count++;
          bytes += await e.length();
        }
      }
    } catch (_) {}

    // Free space on the destination volume (nearest existing ancestor of the
    // target). If the library won't fit, warn — a "Move" may fail partway.
    Directory probe = newDir;
    while (!probe.existsSync() && probe.parent.path != probe.path) {
      probe = probe.parent;
    }
    final free = await MigrationManager().freeBytes(probe.path);
    final tight = free != null && bytes > free;

    if (!mounted) return false;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.storageMigrateTitle,
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 18)),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(l.storageMigrateBody(count, _formatBytes(bytes)),
                style:
                    TextStyle(color: VelvetColors.textSecondary, fontSize: 13)),
          ),
          if (tight)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: VelvetColors.warning),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(l.storageMigrateNoSpace(_formatBytes(free)),
                        style: TextStyle(
                            color: VelvetColors.warning, fontSize: 12)),
                  ),
                ],
              ),
            ),
          _migrateOption(
              ctx,
              'move',
              Icons.drive_file_move_outline,
              l.storageMigrateMove,
              l.storageMigrateMoveBody),
          _migrateOption(
              ctx,
              'leave',
              Icons.inventory_2_outlined,
              l.storageMigrateLeave,
              l.storageMigrateLeaveBody),
          _migrateOption(
              ctx,
              'delete',
              Icons.delete_outline,
              l.storageMigrateDelete,
              l.storageMigrateDeleteBody),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 4, 12, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: Text(l.cancel,
                    style: TextStyle(color: VelvetColors.textSecondary)),
              ),
            ),
          ),
        ],
      ),
    );

    switch (choice) {
      case 'move':
        await MigrationManager().start(oldDir.path, newDir.path, count, bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l.storageMovingBackground)));
        }
        return true;
      case 'leave':
        return true; // switch; old files stay put
      case 'delete':
        try {
          await oldDir.delete(recursive: true);
        } catch (_) {}
        return true;
      default: // cancel / dismissed
        return false;
    }
  }

  // One tappable option row in the cross-volume dialog.
  Widget _migrateOption(BuildContext ctx, String value, IconData icon,
      String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: VelvetColors.primary),
      title: Text(title,
          style: TextStyle(
              color: VelvetColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: VelvetColors.textTertiary, fontSize: 12)),
      onTap: () => Navigator.of(ctx).pop(value),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  // Collapses a typed folder name to a single safe path segment: strips path
  // separators and parent refs (no traversal out of media/), then trims
  // leading/trailing separators and whitespace.
  String _sanitizeFolderName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/]+'), '_')
        .replaceAll(RegExp(r'\.\.+'), '_')
        .replaceAll(RegExp(r'^[\s._-]+'), '')
        .replaceAll(RegExp(r'[\s._-]+$'), '');
  }

  Future<void> saveServer(Uri lol, [String jwt = '']) async {
    // Permanent / SD card need a folder the app can actually write to. If the
    // mode was selected but no (writable) folder was picked, _storageBasePath
    // is null — saving would store a null base path and route every download to
    // "unavailable". Block it with a clear message instead of a silently broken
    // server. (_storageBasePath is only set after the write-probe in
    // _chooseStorageFolder passes, so a non-null value already means writable.)
    if ((_storageMode == 'permanent' || _storageMode == 'sdCard') &&
        _storageBasePath == null) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() => submitPending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_storageMode == 'sdCard'
                ? l.storageChooseSdFolderFirst
                : l.storageChooseFolderFirst)));
      }
      return;
    }
    bool shouldUpdate = false;
    try {
      ServerManager().serverList[editThisServer ?? -1];
      shouldUpdate = true;
    } catch (err) {}

    // Don't persist credentials that the user wasn't allowed to edit:
    // when the public-access toggle is on, the username/password
    // fields are disabled — store empty strings regardless of any
    // residual text in the controllers.
    final username = _publicAccess ? '' : _usernameCtrl.text;
    final password = _publicAccess ? '' : _passwordCtrl.text;
    // The user-chosen download folder (media/<this>). If they cleared it,
    // fall back to the URL-derived name, then a generated id.
    String folder = _sanitizeFolderName(_downloadFolderCtrl.text.trim());
    if (folder.isEmpty) {
      folder = _computeAutoFolder() ?? Uuid().v4();
    }

    // permanent/sdCard carry an absolute base path; the other modes
    // resolve their base at runtime, so null it out.
    final basePath = (_storageMode == 'permanent' || _storageMode == 'sdCard')
        ? _storageBasePath
        : null;

    if (shouldUpdate) {
      final s = ServerManager().serverList[editThisServer!];
      // If the storage target is changing, cancel in-flight downloads first so
      // none land at the old location after the switch (they'd be stranded).
      if (s.storageMode != _storageMode ||
          s.storageBasePath != basePath ||
          s.localname != folder) {
        await DownloadManager().cancelAll();
      }
      // Relocate already-downloaded files before flipping the server's
      // storage pointers. Same-volume = instant atomic move; cross-volume =
      // warn (files stay, user re-downloads). Cancel aborts the save.
      final migrationOk = await _migrateDownloads(
        oldMode: s.storageMode,
        oldBasePath: s.storageBasePath,
        oldLocalname: s.localname,
        newMode: _storageMode,
        newBasePath: basePath,
        newLocalname: folder,
      );
      if (!migrationOk) {
        if (mounted) setState(() => submitPending = false);
        return;
      }
      // localname + storage aren't part of editServer's signature — set
      // them directly (callAfterEditServer below persists the change).
      s.localname = folder;
      s.storageMode = _storageMode;
      s.allowSelfSigned = _allowSelfSigned;
      s.storageBasePath = basePath;
      ServerManager()
          .editServer(editThisServer!, _urlCtrl.text, username, password);
      await ServerManager().getServerPaths(s);
      await ServerManager().callAfterEditServer();
      // The browser may be showing this server's files with download badges
      // computed against the OLD location — re-check them against the new one
      // so stale "downloaded" marks correct themselves.
      BrowserManager().refreshDownloadStatus(s);
    } else {
      Server newServer =
          new Server(lol.origin, username, password, jwt, folder);
      newServer.storageMode = _storageMode;
      newServer.allowSelfSigned = _allowSelfSigned;
      newServer.storageBasePath = basePath;
      await ServerManager().getServerPaths(newServer);

      await ServerManager().addServer(newServer);
    }

    // Save Server List
    if (mounted) Navigator.pop(context);
  }

  Map<String, String> parseQrCode(String qrValue) {
    if (qrValue[0] != '|') {
      throw new Error();
    }

    List<String> explodeArr = qrValue.split("|");
    if (explodeArr.length < 4) {
      throw new Error();
    }

    return {
      'url': explodeArr[1],
      'username': explodeArr[2],
      'password': explodeArr[3],
    };
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    checkServer();
  }

  // Lists the existing per-server download folders (media/<id>) so the
  // user can point this server at one — recovering a re-added server's
  // previously-downloaded songs.
  Future<void> _browseDownloadFolders() async {
    final l = AppLocalizations.of(context);
    final base =
        await FileExplorer().getDownloadDir(_storageMode, _storageBasePath);
    if (!mounted) return;
    if (base == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.storageNoStorageAvailable)));
      return;
    }
    final mediaDir = Directory(path.join(base.path, 'media'));
    final folders = mediaDir.existsSync()
        ? mediaDir.listSync().whereType<Directory>().toList()
        : <Directory>[];
    if (!mounted) return;
    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.storageNoDownloadFolders)));
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VelvetColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l.storageExistingFolders,
                    style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: folders.map((d) {
                  final name = path.basename(d.path);
                  int count = 0;
                  DateTime? modified;
                  try {
                    count = d.listSync().length;
                    modified = d.statSync().modified;
                  } catch (_) {}
                  return ListTile(
                    leading: Icon(Icons.folder, color: VelvetColors.primary),
                    title: Text(name,
                        style: TextStyle(color: VelvetColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        l.storageItemCount(count) +
                            (modified != null
                                ? ' · ${modified.toString().split('.').first}'
                                : ''),
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 12)),
                    onTap: () => Navigator.of(ctx).pop(name),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      _folderManuallyEdited = true;
      setState(() => _downloadFolderCtrl.text = chosen);
    }
  }

  // The dropdown offers only the three real modes; a migrated
  // 'legacyExternal' server displays as App local but keeps its stored
  // mode until the user actively changes it (so its old downloads aren't
  // orphaned just by opening this screen).
  String get _displayStorageMode {
    // Map the stored mode to a value the dropdown actually offers, so a hidden
    // (Play flavor omits permanent/sdCard) or legacy value never breaks the
    // DropdownButton's value==one-of-items invariant.
    if (_storageMode == 'appExternal') return 'appExternal';
    if (!isPlayBuild &&
        (_storageMode == 'permanent' || _storageMode == 'sdCard')) {
      return _storageMode;
    }
    return 'appLocal';
  }

  Future<void> _onStorageModeChanged(String? v) async {
    if (v == null || v == _storageMode) return;
    // Permanent / SD card write outside the app sandbox -> need all-files
    // access. If the user declines, keep the previous mode (the dropdown
    // is value-controlled, so it snaps back).
    if (v == 'permanent' || v == 'sdCard') {
      final granted = await _ensureAllFilesAccess();
      if (!granted) return;
    }
    // Reset the chosen folder so each mode starts fresh — avoids carrying a
    // Permanent path over to SD card (or vice versa) without re-picking.
    if (mounted) {
      setState(() {
        _storageMode = v;
        _storageBasePath = null;
      });
    }
  }

  // Requests MANAGE_EXTERNAL_STORAGE ("All files access"). On Android 11+
  // request() bounces to a system settings screen, so the just-returned
  // status can still be denied — the user grants there, then re-selects.
  Future<bool> _ensureAllFilesAccess() async {
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.storageAllFilesAccess),
        action:
            SnackBarAction(label: l.storageSettings, onPressed: openAppSettings),
      ));
    }
    return false;
  }

  Future<void> _chooseStorageFolder() async {
    final l = AppLocalizations.of(context);
    if (!await _ensureAllFilesAccess()) return;
    final root = _storageMode == 'sdCard' ? _sdCardRoot : _sharedStorageRoot;
    if (root == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.storageNoVolume)));
      }
      return;
    }
    final chosen = await _browseForFolder(root);
    if (chosen == null || !mounted) return;
    // Confirm we can actually write there before committing — catches
    // read-only roots / SD cards before downloads silently fail later.
    if (!await _isWritable(chosen)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.storageNotWritable)));
      }
      return;
    }
    setState(() => _storageBasePath = chosen);
  }

  Future<bool> _isWritable(String dirPath) async {
    try {
      final probe = File(path.join(dirPath, '.mstream_write_test'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Minimal navigable folder browser (no plugin — pure dart:io). Starts at
  // [rootPath], descends on tap; "Use this folder" returns the current
  // absolute path. Cannot navigate above the root.
  Future<String?> _browseForFolder(String rootPath) {
    final l = AppLocalizations.of(context);
    String current = rootPath;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          List<Directory> subs = [];
          try {
            subs = Directory(current)
                .listSync()
                .whereType<Directory>()
                .toList()
              ..sort((a, b) => path
                  .basename(a.path)
                  .toLowerCase()
                  .compareTo(path.basename(b.path).toLowerCase()));
          } catch (_) {}
          final canGoUp = current != rootPath;
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_upward,
                              color: canGoUp
                                  ? VelvetColors.textPrimary
                                  : VelvetColors.textTertiary),
                          onPressed: canGoUp
                              ? () =>
                                  setSheet(() => current = path.dirname(current))
                              : null,
                        ),
                        Expanded(
                          child: Text(current,
                              style: TextStyle(
                                  color: VelvetColors.textSecondary,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          icon: Icon(Icons.create_new_folder_outlined,
                              color: VelvetColors.primary),
                          tooltip: l.storageNewFolder,
                          onPressed: () => _createSubfolder(ctx, current,
                              (p) => setSheet(() => current = p)),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: VelvetColors.border2, height: 1),
                  Expanded(
                    child: subs.isEmpty
                        ? Center(
                            child: Text(l.storageNoSubfolders,
                                style: TextStyle(
                                    color: VelvetColors.textTertiary)))
                        : ListView(
                            children: subs
                                .map((d) => ListTile(
                                      leading: Icon(Icons.folder,
                                          color: VelvetColors.primary),
                                      title: Text(path.basename(d.path),
                                          style: TextStyle(
                                              color: VelvetColors.textPrimary),
                                          overflow: TextOverflow.ellipsis),
                                      onTap: () =>
                                          setSheet(() => current = d.path),
                                    ))
                                .toList(),
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VelvetColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Icon(Icons.check),
                        label: Text(l.storageUseThisFolder),
                        onPressed: () => Navigator.of(ctx).pop(current),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Prompts for a name and creates a subfolder under [parent], then calls
  // [onCreated] with the new absolute path so the picker descends into it.
  Future<void> _createSubfolder(BuildContext sheetCtx, String parent,
      void Function(String) onCreated) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: sheetCtx,
      builder: (dctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.storageNewFolder,
            style: TextStyle(color: VelvetColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          autocorrect: false,
          style: TextStyle(color: VelvetColors.textPrimary),
          decoration: InputDecoration(hintText: l.storageFolderNameHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: Text(l.cancel,
                  style: TextStyle(color: VelvetColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(ctrl.text.trim()),
              child: Text(l.create)),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    // Single safe path segment so a name can't escape the current directory.
    final safe = _sanitizeFolderName(name);
    if (safe.isEmpty) return;
    try {
      final newDir = Directory(path.join(parent, safe));
      newDir.createSync(recursive: true);
      onCreated(newDir.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.storageCouldNotCreateFolder)));
      }
    }
  }

  // Per-mode explanation under the dropdown. App local gets a prominent
  // warning that its files vanish on uninstall (the whole reason this
  // picker exists).
  Widget _storageHelp() {
    final l = AppLocalizations.of(context);
    switch (_storageMode) {
      case 'permanent':
        return Text(
          l.storageHelpPermanent,
          style: TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
        );
      case 'sdCard':
        return Text(
          l.storageHelpSdCard,
          style: TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
        );
      case 'appLocal':
      default:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 14, color: VelvetColors.warning),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                l.storageHelpAppLocal,
                style: TextStyle(color: VelvetColors.warning, fontSize: 11),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      // SingleChildScrollView ensures the Save button is reachable
      // when the on-screen keyboard appears for the password field
      // on small phones.
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l.validatorUrlNeeded;
                  }
                  try {
                    final parsed = Uri.parse(value);
                    if (parsed.origin is Error || parsed.origin.isEmpty) {
                      return l.validatorUrlParse;
                    }
                  } catch (_) {
                    return l.validatorUrlParse;
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: l.fieldServerUrl,
                  hintText: 'https://mstream.example.com',
                  prefixIcon: Icon(Icons.link),
                ),
                onSaved: (v) => _urlCtrl.text = v ?? '',
              ),
              SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.fieldPublicAccess),
                subtitle: Text(
                  l.publicAccessSubtitle,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12),
                ),
                value: _publicAccess,
                onChanged: submitPending
                    ? null
                    : (v) => setState(() => _publicAccess = v),
                activeThumbColor: VelvetColors.primary,
              ),
              // Full flavor only: opt into a self-signed / untrusted TLS cert
              // for this server (API + streaming). Hidden on the Play build.
              if (!isPlayBuild)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.selfSignedTitle),
                  subtitle: Text(
                    l.selfSignedSubtitle,
                    style: TextStyle(
                        color: VelvetColors.warning, fontSize: 12),
                  ),
                  value: _allowSelfSigned,
                  onChanged: submitPending
                      ? null
                      : (v) => setState(() => _allowSelfSigned = v),
                  activeThumbColor: VelvetColors.primary,
                ),
              SizedBox(height: 8),
              // Stacked instead of side-by-side: bigger tap targets
              // and a single-column flow plays nicer with autofill /
              // password-manager prompts. Disabled visually when
              // public access is on — Material dims the field, drops
              // the label color, and rejects taps.
              TextFormField(
                controller: _usernameCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !_publicAccess,
                decoration: InputDecoration(
                  labelText: l.fieldUsername,
                  hintText: l.fieldUsername,
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onSaved: (v) => _usernameCtrl.text = v ?? '',
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_publicAccess,
                decoration: InputDecoration(
                  labelText: l.fieldPassword,
                  hintText: l.fieldPassword,
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSaved: (v) => _passwordCtrl.text = v ?? '',
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: VelvetColors.textPrimary,
                  side: BorderSide(color: VelvetColors.border2),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall),
                  ),
                ),
                icon: _testing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(VelvetColors.primary),
                        ),
                      )
                    : Icon(Icons.network_check),
                label: Text(_testing ? l.testing : l.testConnectionButton),
                onPressed:
                    _testing || submitPending ? null : _testConnection,
              ),
              if (_testResult != null) ...[
                SizedBox(height: 10),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_testSuccess ?? false)
                        ? VelvetColors.success.withValues(alpha: 0.12)
                        : VelvetColors.error.withValues(alpha: 0.12),
                    border: Border.all(
                      color: (_testSuccess ?? false)
                          ? VelvetColors.success
                          : VelvetColors.error,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(
                        VelvetColors.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_testSuccess ?? false)
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: (_testSuccess ?? false)
                            ? VelvetColors.success
                            : VelvetColors.error,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                              color: VelvetColors.textPrimary,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Storage location: App local (default) / Permanent / SD card
              // (the SD option only when a removable card is present, or when
              // this server is already configured for it). Replaces the old
              // SD-card toggle; see _storageHelp for the per-mode caveats.
              SizedBox(height: 16),
              Text(l.storageLocationLabel,
                  style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.sd_storage_outlined),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _displayStorageMode,
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: VelvetColors.surface,
                    style: TextStyle(color: VelvetColors.textPrimary),
                    items: [
                      DropdownMenuItem(
                          value: 'appLocal', child: Text(l.storageAppLocal)),
                      DropdownMenuItem(
                          value: 'appExternal',
                          child: Text(l.storageAppExternal)),
                      // Permanent / SD card write to a user-chosen shared-storage
                      // folder, which needs All-files-access — full flavor only.
                      // The Play build omits the permission from its manifest, so
                      // these modes aren't offered there.
                      if (!isPlayBuild)
                        DropdownMenuItem(
                            value: 'permanent',
                            child: Text(l.storagePermanent)),
                      if (!isPlayBuild &&
                          (_hasSdCard || _storageMode == 'sdCard'))
                        DropdownMenuItem(
                            value: 'sdCard', child: Text(l.storageSdCard)),
                    ],
                    onChanged: submitPending ? null : _onStorageModeChanged,
                  ),
                ),
              ),
              SizedBox(height: 8),
              _storageHelp(),
              if (_storageMode == 'permanent' ||
                  _storageMode == 'sdCard') ...[
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _storageBasePath ?? l.storageNoFolderChosen,
                        style: TextStyle(
                            color: _storageBasePath == null
                                ? VelvetColors.textTertiary
                                : VelvetColors.textPrimary,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VelvetColors.textPrimary,
                        side: BorderSide(color: VelvetColors.border2),
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(VelvetColors.radiusSmall),
                        ),
                      ),
                      icon: Icon(Icons.folder_open, size: 18),
                      label: Text(l.storageChooseFolder),
                      onPressed: submitPending ? null : _chooseStorageFolder,
                    ),
                  ],
                ),
              ],
              SizedBox(height: 8),
              Text(l.storageDownloadFolderLabel,
                  style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _downloadFolderCtrl,
                      autocorrect: false,
                      onChanged: (_) => _folderManuallyEdited = true,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.folder_outlined),
                        hintText: l.storageDownloadFolderHint,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VelvetColors.textPrimary,
                      side: BorderSide(color: VelvetColors.border2),
                      padding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(VelvetColors.radiusSmall),
                      ),
                    ),
                    icon: Icon(Icons.folder_open, size: 18),
                    label: Text(l.storageBrowse),
                    onPressed: submitPending ? null : _browseDownloadFolders,
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                l.storageDownloadFolderHelp,
                style:
                    TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
              ),
              SizedBox(height: 24),
              // QR Code button hidden — flutter_barcode_scanner is
              // commented out in pubspec.yaml (hasn't kept up with
              // recent AGP / androidx changes). Restore the
              // OutlinedButton.icon block here + uncomment the dep
              // when scanning is back online. The parseQrCode helper
              // above is preserved.
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VelvetColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall),
                  ),
                  textStyle: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: submitPending ? null : _onSavePressed,
                child: submitPending
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(l.connecting),
                        ],
                      )
                    : Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
