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
import 'package:flutter/services.dart';
import '../widgets/iroh_scanner.dart';
import '../build_variant.dart';
import '../native/iroh_tunnel.dart';
import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/file_explorer.dart';
import '../singletons/lan_discovery.dart';
import '../singletons/server_list.dart';
import '../singletons/log_manager.dart';
import '../singletons/app_messenger.dart';
import '../singletons/browser_list.dart';
import '../singletons/migration_manager.dart';
import '../singletons/downloads.dart';
import '../theme/velvet_theme.dart';

class AddServerScreen extends StatelessWidget {
  const AddServerScreen({super.key});

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
  const EditServerScreen({super.key, required this.editThisServer});

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
  const MyCustomForm({super.key, this.editThisServer});

  @override
  MyCustomFormState createState() => MyCustomFormState();
}

// Create a corresponding State class. This class will hold the data related to
// the form.
class MyCustomFormState extends State<MyCustomForm> {
  // Create a global key that will uniquely identify the Form widget and allow
  // us to validate the form
  // Note: This is a GlobalKey<FormState>, not a GlobalKey<MyCustomFormState>!
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
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
  // True when editing an existing iroh server. iroh connects through the loopback
  // tunnel, not a fetchable URL, so the URL field is read-only, the self-signed
  // TLS switch + Test-connection button are hidden, and Save skips the HTTP probe.
  bool _editingIroh = false;

  // Show/hide toggle for the password field.
  bool _obscurePassword = true;
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

  // --- iroh pairing tab state ---
  final TextEditingController _irohCodeCtrl = TextEditingController();
  final TextEditingController _irohUserCtrl = TextEditingController();
  final TextEditingController _irohPassCtrl = TextEditingController();
  bool _irohTesting = false;
  String? _irohTestResult;
  bool? _irohTestSuccess;
  // Live tunnel port after a passing test (null = no tunnel up).
  int? _irohPort;
  // Test passed → reveal the sign-in form.
  bool _irohSignedInReady = false;
  bool _irohPublic = false;
  bool _irohSaving = false;
  // Set once the server is saved, so dispose() won't stop the now-active tunnel.
  bool _irohSaved = false;
  // id of the mDNS-discovered server currently being paired (spinner on its
  // tile + blocks re-taps); null when idle.
  String? _connectingId;

  @override
  @protected
  @mustCallSuper
  void initState() {
    super.initState();

    bool isEdit = false;
    try {
      Server s = ServerManager().serverList[widget.editThisServer ?? -1];
      _urlCtrl.text = s.url;
      _usernameCtrl.text = s.username ?? '';
      _passwordCtrl.text = s.password ?? '';
      _storageMode = s.storageMode;
      _allowSelfSigned = s.allowSelfSigned;
      _storageBasePath = s.storageBasePath;
      _downloadFolderCtrl.text = s.localname;
      isEdit = true;
      _editingIroh = s.isIroh;
      // An existing server saved without credentials is a public
      // server — start in public mode so the toggle reflects reality.
      if ((s.username ?? '').isEmpty && (s.password ?? '').isEmpty) {
        _publicAccess = true;
      }
    } catch (err) {
      // No server at that index (e.g. the "add server" flow) — leave the form
      // blank.
    }

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

    // Add mode only: browse the LAN for iroh-capable servers so the Quick
    // Connect tab can offer them. No-op on builds without the native tunnel.
    if (!isEdit && LanDiscovery().isSupported) {
      LanDiscovery().start();
    }
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

  // The auto folder name: "${subdomain}-${domain}-${id}" — always suffixed with
  // a short random id (stable per screen) so no two servers ever share a
  // download directory, even on the same domain or after a re-add. The folder
  // field stays editable, so re-adding a lost server can still recover its
  // downloads by pointing at the old folder name.
  //
  // A bare IP host (e.g. a LAN server at 192.168.1.71) makes a poor,
  // collision-prone folder name, so those become "my-server-N" with the lowest
  // free N instead — distinct folders for multiple LAN instances.
  String? _computeAutoFolder() {
    if (_hostIsIp(_urlCtrl.text)) return _nextMyServerName();
    final base = _defaultLocalName(_urlCtrl.text);
    if (base == null) return null;
    return '$base-$_folderSuffix';
  }

  // True when the server URL's host is a bare IP address (v4 or v6).
  bool _hostIsIp(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return false;
    try {
      final host = Uri.parse(raw.contains('://') ? raw : 'https://$raw').host;
      return host.isNotEmpty && InternetAddress.tryParse(host) != null;
    } catch (_) {
      return false;
    }
  }

  // Lowest free "my-server-N" (N starts at 1) so multiple LAN-IP servers each
  // get a distinct download folder. Deterministic given the current server
  // list, so it doesn't churn while the user is still typing the URL.
  String _nextMyServerName() {
    for (int n = 1; ; n++) {
      final candidate = 'my-server-$n';
      if (!_localNameTaken(candidate)) return candidate;
    }
  }

  // Does any *other* configured server already use this folder name?
  bool _localNameTaken(String name) {
    final list = ServerManager().serverList;
    for (int i = 0; i < list.length; i++) {
      if (i == widget.editThisServer) {
        continue; // ignore the server being edited
      }
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

    // Trust this host's self-signed cert for the duration of the test — it isn't
    // in serverList yet, so SelfSignedHttpOverrides can't know to otherwise.
    // Full flavor only: the toggle is hidden on Play and isPlayBuild short-
    // circuits both this and allowsSelfSigned().
    if (!isPlayBuild && _allowSelfSigned) {
      ServerManager().addPendingSelfSigned(url.host);
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {

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
    _irohCodeCtrl.dispose();
    _irohUserCtrl.dispose();
    _irohPassCtrl.dispose();
    // A tunnel left running from a test that was never saved is torn down here.
    if (_irohPort != null && !_irohSaved) IrohTunnel.instance.stop();
    ServerManager().clearPendingSelfSigned();
    LanDiscovery().stop();

    super.dispose();
  }

  Future<void> checkServer() async {
    final l = AppLocalizations.of(context);
    setState(() {
      submitPending = true;
    });
    Uri lol = Uri.parse(_urlCtrl.text);
    http.Response response;

    try {
      // Do a quick check on /ping to see if this server even needs authentication
      response = await http
          .get(lol.resolve('/api/v1/ping'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        // App-wide messenger (not ScaffoldMessenger.of(context)): this runs
        // after an await and saveServer pops the form, so a context-bound
        // SnackBar would be lost / unsafe.
        showGlobalSnack(l.connectionSuccessful);
        saveServer(lol);
        return;
      }
    } catch (err) {
      // Ping probe failed (unreachable / non-200) — fall through to the login
      // attempt below.
    }

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
        "username": _usernameCtrl.text,
        "password": _passwordCtrl.text
      }).timeout(Duration(seconds: 6));

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to server');
      }

      var res = jsonDecode(response.body);

      // Save
      saveServer(lol, res['token']);
    } catch (err) {
      appLog('[add-server] login failed: $err');
      try {
        setState(() {
          submitPending = false;
        });
      } catch (e) {
        // Widget already disposed — nothing to update.
      }

      showGlobalSnack(l.failedToLogin);
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

    // Trust this host's self-signed cert during the first getServerPaths below
    // (a brand-new server isn't in serverList yet). Full flavor only.
    if (!isPlayBuild && _allowSelfSigned) {
      ServerManager().addPendingSelfSigned(lol.host);
    }

    bool shouldUpdate = false;
    try {
      ServerManager().serverList[widget.editThisServer ?? -1];
      shouldUpdate = true;
    } catch (err) {
      // No existing entry at that index → treat as a new server.
    }

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
      final s = ServerManager().serverList[widget.editThisServer!];
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
          .editServer(widget.editThisServer!, _urlCtrl.text, username, password);
      await ServerManager().getServerPaths(s);
      await ServerManager().callAfterEditServer();
      // The browser may be showing this server's files with download badges
      // computed against the OLD location — re-check them against the new one
      // so stale "downloaded" marks correct themselves.
      BrowserManager().refreshDownloadStatus(s);
    } else {
      Server newServer =
          Server(lol.origin, username, password, jwt, folder);
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
      throw Error();
    }

    List<String> explodeArr = qrValue.split("|");
    if (explodeArr.length < 4) {
      throw Error();
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
    if (_editingIroh) {
      // iroh reaches the backend through the loopback tunnel, not a fetchable
      // URL — the HTTP ping/login probe in checkServer() can't reach an iroh://
      // URL and would always fail. The pairing already validated the connection,
      // so persist the edited credentials/folder directly (URL stays unchanged).
      setState(() => submitPending = true);
      saveServer(Uri.parse(_urlCtrl.text));
      return;
    }
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
    // Add mode shows two tabs (Server URL / iroh); edit mode targets one
    // existing URL server, so it skips the pairing tab.
    if (widget.editThisServer != null) {
      return _buildStandardForm(context);
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: VelvetColors.surface,
            child: TabBar(
              labelColor: VelvetColors.primary,
              unselectedLabelColor: VelvetColors.textSecondary,
              indicatorColor: VelvetColors.primary,
              tabs: [
                Tab(text: AppLocalizations.of(context).addServerTabUrl),
                Tab(text: AppLocalizations.of(context).addServerTabQuickConnect),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStandardForm(context),
                _buildIrohTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Shared success/error banner used by both the standard and iroh test flows.
  Widget _statusBanner(String message, bool success) {
    final color = success ? VelvetColors.success : VelvetColors.error;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle_outline : Icons.error_outline,
              color: color, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // --- iroh pairing tab ---
  // Strings are intentionally plain English for this first slice; localize via
  // the .arb files once the flow is confirmed end to end.

  // Editing/replacing the code invalidates a prior test: drop the (now stale)
  // tunnel and hide the sign-in form.
  void _clearIrohTestResult() {
    if (_irohTestResult == null && !_irohSignedInReady && _irohPort == null) {
      return;
    }
    if (_irohPort != null && !_irohSaved) IrohTunnel.instance.stop();
    setState(() {
      _irohTestResult = null;
      _irohTestSuccess = null;
      _irohSignedInReady = false;
      _irohPort = null;
    });
  }

  Future<void> _pasteIrohCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty && mounted) {
      if (_irohPort != null && !_irohSaved) IrohTunnel.instance.stop();
      setState(() {
        _irohCodeCtrl.text = text;
        _irohTestResult = null;
        _irohTestSuccess = null;
        _irohSignedInReady = false;
        _irohPort = null;
      });
    }
  }

  Future<void> _scanQr() async {
    final l = AppLocalizations.of(context);
    if (!IrohTunnel.isSupported) {
      _showIrohResult(false, l.irohQrAndroidOnly);
      return;
    }
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.irohCameraPermission)));
      }
      return;
    }
    if (!mounted) return;
    final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const IrohScannerPage()));
    if (code != null && code.trim().isNotEmpty && mounted) {
      if (_irohPort != null && !_irohSaved) IrohTunnel.instance.stop();
      setState(() {
        _irohCodeCtrl.text = code.trim();
        _irohTestResult = null;
        _irohTestSuccess = null;
        _irohSignedInReady = false;
        _irohPort = null;
      });
    }
  }

  // Opens the tunnel from the pairing code and fetches the server's public /api/
  // through it. On success the tunnel is LEFT RUNNING and the sign-in form is
  // revealed (sign-in + save reuse it); a failed test tears the tunnel down.
  Future<void> _testIrohConnection() async {
    final l = AppLocalizations.of(context);
    final code = _irohCodeCtrl.text.trim();
    if (code.isEmpty) {
      _showIrohResult(false, l.irohPasteFirst);
      return;
    }
    if (!IrohTunnel.isSupported) {
      _showIrohResult(false, l.irohAndroidOnly);
      return;
    }
    // Re-test: drop any tunnel left from a previous test (the code may differ).
    if (_irohPort != null && !_irohSaved) IrohTunnel.instance.stop();
    if (_connectingId != null) return; // a discovered pairing is mid-flight
    setState(() {
      _irohTesting = true;
      _irohTestResult = null;
      _irohTestSuccess = null;
      _irohSignedInReady = false;
      _irohPort = null;
    });
    try {
      final port = await IrohTunnel.instance.start(code);
      final lt = IrohTunnel.instance.localToken ?? '';
      final resp = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/?__lt=$lt'))
          .timeout(Duration(seconds: 10));
      String? version;
      if (resp.statusCode == 200) {
        try {
          final v = (jsonDecode(resp.body) as Map<String, dynamic>)['server']
              ?.toString();
          if (v != null && v.isNotEmpty) version = v;
        } catch (_) {}
      }
      if (!mounted) {
        IrohTunnel.instance.stop();
        return;
      }
      // Any response proves the tunnel carried HTTP to the server → keep it up
      // for sign-in + save.
      // Report the path the handshake landed on (it may upgrade direct↔relay
      // shortly after; this is the snapshot at test time).
      final pathSuffix = switch (IrohTunnel.instance.pathKind) {
        IrohPathKind.direct => l.irohPathSuffixDirect,
        IrohPathKind.relay => l.irohPathSuffixRelay,
        IrohPathKind.unknown => '',
      };
      final v = version;
      final base =
          v != null ? l.irohTestConnectedVersion(v) : l.irohTestConnected;
      // Detect whether the server requires auth: an unauthenticated ping that
      // returns 200 means it's public. Public -> skip the sign-in form and save
      // straight away; otherwise reveal the form (no public toggle — we already
      // know it isn't public).
      bool isPublic = false;
      try {
        final ping = await http
            .get(Uri.parse('http://127.0.0.1:$port/api/v1/ping?__lt=$lt'))
            .timeout(Duration(seconds: 8));
        isPublic = ping.statusCode == 200;
      } catch (_) {
        // Probe failed (blip / endpoint quirk) — fall back to the sign-in form
        // rather than wrongly saving a public server.
      }
      if (!mounted) {
        IrohTunnel.instance.stop();
        return;
      }
      setState(() {
        // Public: stay "testing" through the straight-to-save below so the Test
        // button can't be re-tapped mid-save. Private: clear it and reveal the
        // sign-in form.
        _irohTesting = isPublic;
        _irohTestSuccess = true;
        _irohTestResult = base + pathSuffix;
        _irohPort = port;
        _irohPublic = isPublic;
        _irohSignedInReady = !isPublic;
      });
      if (isPublic) {
        // No credentials needed — save immediately (the form pops on success;
        // the one-iroh cap backstop in _saveIrohServer clears state otherwise).
        showGlobalSnack(l.connectionSuccessful);
        await _saveIrohServer(code: code, port: port, jwt: '');
      }
    } on IrohTunnelException catch (e) {
      IrohTunnel.instance.stop();
      _showIrohResult(false, e.message);
    } on TimeoutException {
      IrohTunnel.instance.stop();
      _showIrohResult(false, l.irohTunnelTimeout);
    } catch (e) {
      IrohTunnel.instance.stop();
      _showIrohResult(false, l.irohTunnelTestFailed('$e'));
    }
  }

  void _showIrohResult(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _irohTesting = false;
      _irohTestSuccess = success;
      _irohTestResult = message;
    });
  }

  // Authenticate THROUGH the live tunnel (mirrors the standard login), then save
  // the iroh server, adopting the test tunnel as the active connection.
  Future<void> _signInAndSaveIroh() async {
    final l = AppLocalizations.of(context);
    final code = _irohCodeCtrl.text.trim();
    final port = _irohPort;
    if (port == null) {
      _showIrohResult(false, l.irohTestFirst);
      return;
    }
    setState(() => _irohSaving = true);
    String jwt = '';
    try {
      if (!_irohPublic) {
        final login = await http.post(
          Uri.parse(
              'http://127.0.0.1:$port/api/v1/auth/login?__lt=${IrohTunnel.instance.localToken ?? ''}'),
          body: {
            'username': _irohUserCtrl.text,
            'password': _irohPassCtrl.text,
          },
        ).timeout(Duration(seconds: 8));
        if (login.statusCode != 200) {
          if (mounted) setState(() => _irohSaving = false);
          _showIrohResult(false, l.irohSignInFailedHttp(login.statusCode));
          return;
        }
        jwt = (jsonDecode(login.body)['token'] ?? '').toString();
      }
      await _saveIrohServer(code: code, port: port, jwt: jwt);
    } on TimeoutException {
      if (mounted) setState(() => _irohSaving = false);
      _showIrohResult(false, l.irohSignInTimeout);
    } catch (e) {
      if (mounted) setState(() => _irohSaving = false);
      _showIrohResult(false, l.irohSignInFailed('$e'));
    }
  }

  // Persist an iroh server keyed by its pairing code (its durable identity), with
  // the live tunnel adopted as the active connection, then switch to it.
  Future<void> _saveIrohServer(
      {required String code, required int port, required String jwt}) async {
    // Backstop the one-iroh-server cap (the tab UI normally blocks reaching here).
    if (ServerManager().hasIrohServer) {
      if (mounted) setState(() => _irohSaving = false);
      _showIrohResult(false, AppLocalizations.of(context).irohOneServerLimit);
      return;
    }
    final id = code.hashCode.toUnsigned(32).toRadixString(16);
    final username = _irohPublic ? '' : _irohUserCtrl.text;
    final password = _irohPublic ? '' : _irohPassCtrl.text;
    final server = Server('iroh://$id', username, password, jwt, 'iroh-$id')
      ..connectionType = 'iroh'
      ..irohPairingCode = code
      ..tunnelPort = port
      ..storageMode = 'appLocal';
    // Ping through the live tunnel to populate vpaths / transcode caps.
    await ServerManager().getServerPaths(server);
    await ServerManager().addServer(server);
    // Adopt the test tunnel as the active one, then make this the current server.
    ServerManager().registerActiveTunnel(server, port);
    _irohSaved = true; // dispose() must not stop the now-active tunnel
    final idx = ServerManager().serverList.indexOf(server);
    if (idx >= 0) await ServerManager().changeCurrentServer(idx);
    if (mounted) Navigator.pop(context);
  }

  // --- mDNS-discovered Quick Connect ---
  // Bootstrap a roaming iroh connection from a server found on the LAN: log in
  // over plain LAN HTTP, fetch the server's iroh pairing code over that
  // authenticated connection, then start the tunnel and save it as an iroh
  // server (so it keeps working away from home). The connect secret never rides
  // the mDNS broadcast — it comes back over the authenticated HTTP fetch.
  Future<void> _connectDiscovered(DiscoveredServer server) async {
    final l = AppLocalizations.of(context);
    if (_connectingId != null) return; // one pairing at a time
    // The manual paste/scan Test dials the SAME single native tunnel; two
    // concurrent dials hand one flow the other's port and it silently binds
    // the wrong server. The tiles and the Test button also disable while the
    // sibling flow runs — this is the backstop.
    if (_irohTesting) return;
    if (ServerManager().hasIrohServer) {
      _showIrohResult(false, l.irohOneServerLimit);
      return;
    }
    if (!IrohTunnel.isSupported) {
      _showIrohResult(false, l.irohAndroidOnly);
      return;
    }
    final candidates = server.baseUrls;
    if (candidates.isEmpty) {
      _showIrohResult(false, l.lanUnreachable);
      return;
    }
    // A leftover tunnel from a paste/scan test would collide (single native
    // tunnel) — drop it first.
    if (_irohPort != null && !_irohSaved) {
      IrohTunnel.instance.stop();
      _irohPort = null;
    }

    // Full flavor: trust each candidate host's self-signed cert for the
    // bootstrap HTTP probes only (none is in serverList yet; the saved server
    // talks over the loopback tunnel). All removed in the finally — an
    // unauthenticated mDNS advert must not leave blanket TLS trust behind for
    // a host the user merely tapped.
    final trusted = <String>{};
    if (!isPlayBuild && server.scheme == 'https') {
      for (final c in candidates) {
        final h = Uri.parse(c).host;
        ServerManager().addPendingSelfSigned(h);
        trusted.add(h);
      }
    }

    setState(() {
      _connectingId = server.id;
      _irohTestResult = null;
      _irohTestSuccess = null;
    });

    (String, String)? creds;
    // Only tear the tunnel down on failure if THIS flow dialed it — a
    // code-fetch failure must not stop a tunnel it never started.
    var dialed = false;
    Uri? baseUri;
    try {
      // 1) Find a reachable address and detect public mode. A multi-homed
      //    host advertises addresses that don't all route from the phone
      //    (a WSL/Docker/VPN virtual adapter's IP), so probe each until one
      //    ANSWERS; 200 means public (no login), any other status means the
      //    auth wall replied. If NONE connect the advert is stale (server
      //    left / changed IP) — say so rather than show a doomed login sheet.
      bool isPublic = false;
      for (final c in candidates) {
        try {
          final ping = await http
              .get(Uri.parse(c).resolve('/api/v1/ping'))
              .timeout(Duration(seconds: 6));
          baseUri = Uri.parse(c);
          isPublic = ping.statusCode == 200;
          break;
        } catch (_) {
          // Try the next advertised address.
        }
      }
      if (baseUri == null) {
        _showIrohResult(false, l.lanUnreachable);
        return;
      }
      if (!mounted) return; // backed out during the ping

      String jwt = '';
      if (!isPublic) {
        creds = await _promptDiscoveredLogin(server);
        if (creds == null) {
          if (mounted) setState(() => _connectingId = null);
          return; // user cancelled
        }
        final login = await http.post(
          baseUri.resolve('/api/v1/auth/login'),
          body: {'username': creds.$1, 'password': creds.$2},
        ).timeout(Duration(seconds: 8));
        if (!mounted) return;
        if (login.statusCode != 200) {
          _showIrohResult(false, l.irohSignInFailedHttp(login.statusCode));
          return;
        }
        jwt = (jsonDecode(login.body)['token'] ?? '').toString();
      }

      // 2) Fetch the pairing code over the now-authenticated LAN connection.
      final codeResp = await http.get(
        baseUri.resolve('/api/v1/iroh/code'),
        headers: {'x-access-token': jwt},
      ).timeout(Duration(seconds: 8));
      String? code;
      if (codeResp.statusCode == 200) {
        try {
          final body = jsonDecode(codeResp.body) as Map<String, dynamic>;
          if (body['available'] == true && body['code'] is String) {
            code = body['code'] as String;
          }
        } catch (_) {}
      }
      if (code == null) {
        _showIrohResult(false, l.lanNoCode);
        return;
      }

      // 3) Start the tunnel from the code and prove it carries HTTP, mirroring
      //    _testIrohConnection.
      dialed = true;
      final port = await IrohTunnel.instance.start(code);
      final lt = IrohTunnel.instance.localToken ?? '';
      await http
          .get(Uri.parse('http://127.0.0.1:$port/api/?__lt=$lt'))
          .timeout(Duration(seconds: 10));
      if (!mounted) {
        IrohTunnel.instance.stop();
        return;
      }

      // 4) Save as an iroh server (adopts the tunnel as the active connection).
      //    _saveIrohServer reads these fields for the stored credentials.
      _irohPublic = isPublic;
      _irohUserCtrl.text = isPublic ? '' : creds!.$1;
      _irohPassCtrl.text = isPublic ? '' : creds!.$2;
      showGlobalSnack(l.connectionSuccessful);
      await _saveIrohServer(code: code, port: port, jwt: jwt);
    } on IrohTunnelException catch (e) {
      if (dialed) IrohTunnel.instance.stop();
      _showIrohResult(false, e.message);
    } on TimeoutException {
      if (dialed) IrohTunnel.instance.stop();
      _showIrohResult(false, l.irohTunnelTimeout);
    } catch (e) {
      if (dialed) IrohTunnel.instance.stop();
      _showIrohResult(false, l.irohTunnelTestFailed('$e'));
    } finally {
      for (final h in trusted) {
        ServerManager().removePendingSelfSigned(h);
      }
      if (mounted) setState(() => _connectingId = null);
    }
  }

  // Modal sheet collecting credentials for a discovered private server.
  // Returns (username, password), or null if cancelled.
  Future<(String, String)?> _promptDiscoveredLogin(DiscoveredServer server) {
    final l = AppLocalizations.of(context);
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.lanLoginTitle(server.name),
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            TextField(
              controller: userCtrl,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: VelvetColors.textPrimary),
              decoration: InputDecoration(
                labelText: l.fieldUsername,
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) =>
                  Navigator.of(ctx).pop((userCtrl.text, passCtrl.text)),
              style: TextStyle(color: VelvetColors.textPrimary),
              decoration: InputDecoration(
                labelText: l.fieldPassword,
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(Icons.login),
              label: Text(l.irohSignInSave),
              onPressed: () =>
                  Navigator.of(ctx).pop((userCtrl.text, passCtrl.text)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      userCtrl.dispose();
      passCtrl.dispose();
    });
  }

  // "On your network": live list of mDNS-discovered iroh servers. Always shows
  // the header + a searching hint so the user knows discovery is running.
  Widget _discoveredSection() {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<DiscoveredServer>>(
      stream: LanDiscovery().stream,
      initialData: LanDiscovery().current,
      builder: (context, snap) {
        final servers = snap.data ?? const <DiscoveredServer>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.lanOnYourNetwork,
                      style: TextStyle(
                          color: VelvetColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: VelvetColors.textSecondary),
                  tooltip: l.lanRefresh,
                  onPressed: () => LanDiscovery().refresh(),
                ),
              ],
            ),
            if (servers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(VelvetColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(l.lanSearching,
                        style: TextStyle(
                            color: VelvetColors.textTertiary, fontSize: 13)),
                  ],
                ),
              )
            else
              ...servers.map(_discoveredTile),
            const SizedBox(height: 20),
            Divider(color: VelvetColors.border2),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _discoveredTile(DiscoveredServer server) {
    final l = AppLocalizations.of(context);
    final busy = _connectingId == server.id;
    final blocked = (_connectingId != null && !busy) || _irohTesting;
    final subtitle = server.version != null
        ? l.lanServerVersion(server.version!)
        : (server.hostAddresses.isNotEmpty ? server.hostAddresses.first : '');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: VelvetColors.border2),
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        ),
        child: ListTile(
          enabled: !blocked,
          leading: Icon(Icons.dns_outlined, color: VelvetColors.primary),
          title: Text(server.name,
              style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
          trailing: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(VelvetColors.primary),
                  ),
                )
              : Icon(Icons.chevron_right, color: VelvetColors.textSecondary),
          onTap: (busy || blocked) ? null : () => _connectDiscovered(server),
        ),
      ),
    );
  }

  Widget _buildIrohTab(BuildContext context) {
    final l = AppLocalizations.of(context);
    // No native tunnel lib on this device/ABI (e.g. 32-bit armeabi-v7a, which ships
    // without libiroh_tunnel.so). Say so instead of offering pairing UI that can't
    // connect — IrohTunnel.isSupported gates every native call.
    if (!IrohTunnel.isSupported) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined,
                  size: 40, color: VelvetColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                l.irohAndroidOnly,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    // One iroh server max (a single native tunnel). If one's already configured,
    // show why instead of the pairing UI.
    if (ServerManager().hasIrohServer) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined,
                  size: 40, color: VelvetColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                l.irohOneServerLimit,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Servers found on the LAN (mDNS). Tapping one bootstraps an iroh
            // connection over the network; the manual paste/scan below is the
            // fallback (and the only path away from home).
            _discoveredSection(),
            Text(l.irohConnectHeader,
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              l.irohConnectBody,
              style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _irohCodeCtrl,
              enabled: !_irohTesting,
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => _clearIrohTestResult(),
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: l.irohPairingCodeLabel,
                hintText: l.irohPairingCodeHint,
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VelvetColors.textPrimary,
                      side: BorderSide(color: VelvetColors.border2),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(VelvetColors.radiusSmall),
                      ),
                    ),
                    icon: Icon(Icons.qr_code_scanner, size: 18),
                    label: Text(l.irohScanQr),
                    onPressed: (_irohTesting || _connectingId != null)
                        ? null
                        : _scanQr,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VelvetColors.textPrimary,
                      side: BorderSide(color: VelvetColors.border2),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(VelvetColors.radiusSmall),
                      ),
                    ),
                    icon: Icon(Icons.content_paste, size: 18),
                    label: Text(l.irohPaste),
                    onPressed: (_irohTesting || _connectingId != null)
                        ? null
                        : _pasteIrohCode,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              icon: _irohTesting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(Icons.network_check),
              label: Text(_irohTesting ? l.irohTesting : l.irohTestConnection),
              onPressed: (_irohTesting || _connectingId != null)
                  ? null
                  : _testIrohConnection,
            ),
            if (_irohTestResult != null) ...[
              SizedBox(height: 12),
              _statusBanner(_irohTestResult!, _irohTestSuccess ?? false),
            ],
            if (_irohSignedInReady) ...[
              SizedBox(height: 20),
              Divider(color: VelvetColors.border2),
              SizedBox(height: 12),
              Text(l.irohSignInHeader,
                  style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              // No public-server toggle: the test already determined this server
              // needs auth (a public one would have skipped straight to saved).
              TextField(
                controller: _irohUserCtrl,
                enabled: !_irohSaving,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: VelvetColors.textPrimary),
                decoration: InputDecoration(
                  labelText: l.fieldUsername,
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _irohPassCtrl,
                enabled: !_irohSaving,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(color: VelvetColors.textPrimary),
                decoration: InputDecoration(
                  labelText: l.fieldPassword,
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VelvetColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall),
                  ),
                  textStyle:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                icon: _irohSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(Icons.login),
                label: Text(_irohSaving ? l.irohSigningIn : l.irohSignInSave),
                onPressed: _irohSaving ? null : _signInAndSaveIroh,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStandardForm(BuildContext context) {
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
                // iroh server: reached through the loopback tunnel, not this URL
                // (it's an iroh:// pairing id), so it's read-only when editing one.
                enabled: !_editingIroh,
                keyboardType: TextInputType.url,
                autocorrect: false,
                // Skip the http/https validator for iroh — an iroh:// URL has no
                // origin, so it would otherwise fail validation and block Save.
                validator: _editingIroh
                    ? null
                    : (value) {
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
              // for this server (API + streaming). Hidden on the Play build, and
              // for iroh (it tunnels over QUIC — there's no TLS cert to trust).
              if (!isPlayBuild && !_editingIroh)
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
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_publicAccess,
                decoration: InputDecoration(
                  labelText: l.fieldPassword,
                  hintText: l.fieldPassword,
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: _publicAccess
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onSaved: (v) => _passwordCtrl.text = v ?? '',
              ),
              // Test connection is an HTTP probe — meaningless for an iroh server
              // (it's reached through the tunnel, tested during pairing), so hide
              // it when editing one.
              if (!_editingIroh) ...[
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
                  _statusBanner(_testResult!, _testSuccess ?? false),
                ],
              ],
              // Storage location. Play build keeps it simple: internal storage by
              // default, with an optional "Save to SD card" switch when a
              // removable card is present (the card's app-specific dir — no
              // permission, but cleared on uninstall). Full build offers the
              // app-local / external / permanent / SD modes via a dropdown. Either
              // way the download folder is auto-named (the field below).
              if (isPlayBuild) ...[
                if (_hasSdCard) ...[
                  SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Icons.sd_storage_outlined),
                    title: Text(l.storageSdSwitchTitle),
                    subtitle: Text(
                      l.storageSdSwitchSubtitle,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12),
                    ),
                    value: _storageMode == 'sdCardApp',
                    onChanged: submitPending
                        ? null
                        : (v) => setState(() =>
                            _storageMode = v ? 'sdCardApp' : 'appLocal'),
                    activeThumbColor: VelvetColors.primary,
                  ),
                ],
              ] else ...[
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
                        // folder, which needs All-files-access (full flavor only).
                        DropdownMenuItem(
                            value: 'permanent',
                            child: Text(l.storagePermanent)),
                        if (_hasSdCard || _storageMode == 'sdCard')
                          DropdownMenuItem(
                              value: 'sdCard', child: Text(l.storageSdCard)),
                      ],
                      onChanged: submitPending ? null : _onStorageModeChanged,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                _storageHelp(),
              ],
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

// The QR scanner page moved to lib/widgets/iroh_scanner.dart (IrohScannerPage),
// shared with the re-pair sheet.
