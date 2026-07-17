// Desktop first-run onboarding. Shown as the app's home whenever NO servers
// are configured (main.dart swaps it in for the DesktopShell): a full-window
// mode chooser —
//   Client Mode → Quick Connect (LAN discovery) or Standard Connection, both
//                 deep-linking into the existing AddServerScreen tabs;
//   Server Mode → quick setup that writes a music folder + first user + port
//                 into the bundled server's config, restarts it, signs in,
//                 and registers it as this app's server.
// The cover watches the server list: the moment a server exists (any path),
// it pops the onboarding route stack and main.dart renders the shell.

import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../objects/server.dart';
import '../server/server_controller.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import 'add_server.dart';

class DesktopOnboardingScreen extends StatefulWidget {
  const DesktopOnboardingScreen({super.key});

  @override
  State<DesktopOnboardingScreen> createState() =>
      _DesktopOnboardingScreenState();
}

class _DesktopOnboardingScreenState extends State<DesktopOnboardingScreen> {
  StreamSubscription<List<Server>>? _sub;

  @override
  void initState() {
    super.initState();
    // A server appearing (added via any of the flows) ends onboarding: pop
    // whatever onboarding routes are stacked above home; main.dart's builder
    // then renders the DesktopShell in place of this screen.
    _sub = ServerManager().serverListStream.listen((list) {
      if (list.isNotEmpty && mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Top-anchored with a proportional gap instead of dead-center: optically
    // balanced (content sits a bit above the midline) and stable when the
    // window resizes.
    return Material(
      color: VelvetColors.bg,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.sizeOf(context).height * 0.16,
            bottom: 40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq, color: VelvetColors.primary, size: 56),
                  const SizedBox(height: 14),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'm',
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            color: VelvetColors.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: 'Stream',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: VelvetColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 34, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'How do you want to use mStream on this PC?',
                    style: TextStyle(
                      fontSize: 15,
                      color: VelvetColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // IntrinsicHeight bounds the stretch (equal-height cards):
                  // inside the scroll view the height is otherwise unbounded
                  // and stretch would demand infinite height — which is
                  // exactly the layout failure that blanked this page.
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ModeCard(
                          icon: Icons.speaker_group_outlined,
                          title: 'Client Mode',
                          body:
                              'Connect to an mStream server you already run — on your '
                              'network or across the internet.',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const _ClientModeScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        _ModeCard(
                          icon: Icons.dns_outlined,
                          title: 'Server Mode',
                          body:
                              'Turn this PC into a music server. Pick your music '
                              'folder, create a login, and stream anywhere.',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const _ServerModeScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Client Mode: pick how to connect, then deep-link into AddServerScreen.
// ---------------------------------------------------------------------------

class _ClientModeScreen extends StatelessWidget {
  const _ClientModeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(title: const Text('Client Mode')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height * 0.14,
          bottom: 40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Connect to your server',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: VelvetColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Both options land you in the same place — signed in and '
                  'browsing your library.',
                  style: TextStyle(
                    fontSize: 14,
                    color: VelvetColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                // Same IntrinsicHeight rationale as the cover's card row.
                IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ModeCard(
                        icon: Icons.wifi_find_outlined,
                        title: 'Quick Connect',
                        body:
                            'Find mStream servers on your local network and pair '
                            'with one tap.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AddServerScreen(initialTab: 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      _ModeCard(
                        icon: Icons.link_outlined,
                        title: 'Standard Connection',
                        body:
                            'Enter your server\'s address and sign in with your '
                            'account.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AddServerScreen(initialTab: 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Server Mode: folder + first user + port -> configure, restart, sign in.
// ---------------------------------------------------------------------------

class _ServerModeScreen extends StatefulWidget {
  const _ServerModeScreen();

  @override
  State<_ServerModeScreen> createState() => _ServerModeScreenState();
}

class _ServerModeScreenState extends State<_ServerModeScreen> {
  final _folderCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '3000');

  bool _busy = false;
  String? _status; // progress line while _busy
  String? _error;

  @override
  void dispose() {
    _folderCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final dir = await getDirectoryPath();
    if (dir != null) setState(() => _folderCtrl.text = dir);
  }

  Future<void> _submit() async {
    final folder = _folderCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    final port = int.tryParse(_portCtrl.text.trim()) ?? 0;
    setState(() => _error = null);
    if (folder.isEmpty) {
      setState(() => _error = 'Choose your music folder.');
      return;
    }
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter a username and password.');
      return;
    }
    if (port < 1 || port > 65535) {
      setState(() => _error = 'Port must be between 1 and 65535.');
      return;
    }

    setState(() => _busy = true);
    try {
      // 1) Start the server (usually already up — it boots with the app) and
      //    create the library + first admin user through the admin API. A
      //    server that already has users throws ServerHasUsersException — then
      //    the submitted credentials must MATCH an existing login (attach).
      var attaching = false;
      setState(() => _status = 'Configuring and starting the server…');
      // mStream's directory vpath is a name, not a path — sanitize the
      // folder's basename to its accepted alphabet.
      var vpath = p
          .basename(folder)
          .replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      if (vpath.isEmpty) vpath = 'music';
      try {
        await ServerController.instance.quickSetup(
          folderName: vpath,
          folderRoot: folder,
          username: username,
          password: password,
          port: port,
        );
      } on ServerHasUsersException {
        attaching = true;
      }

      // 2) Sign in (proves the created login round-trips; for the attach case
      //    this is the actual gate) and register it as this app's server.
      setState(() => _status = 'Signing in…');
      final base = Uri.parse(ServerController.instance.baseUrl);
      final login = await http
          .post(
            base.resolve('/api/v1/auth/login'),
            body: {'username': username, 'password': password},
          )
          .timeout(const Duration(seconds: 8));
      if (login.statusCode != 200) {
        throw Exception(attaching
            ? 'this PC\'s server already has a login configured, and these '
                'credentials don\'t match it — sign in with the existing '
                'login, or use Client Mode'
            : 'sign-in failed (HTTP ${login.statusCode})');
      }
      final jwt =
          (jsonDecode(login.body) as Map<String, dynamic>)['token'] as String?;

      final server = Server(
        ServerController.instance.baseUrl,
        username,
        password,
        jwt,
        '__local__',
      );
      // Mark it as the app-managed embedded server — the UI keys its
      // management affordances (status/restart/logs/admin) off this flag.
      server.isAttachedServer = true;
      await ServerManager().getServerPaths(server);
      // 3) addServer lands the first server on its configured startup section
      //    (the desktop path inside it); the onboarding cover pops itself when
      //    the server-list emission arrives.
      await ServerManager().addServer(server);
    } catch (e) {
      // Curated errors arrive as Exception('reason') — show the reason, not
      // the exception wrapper.
      var msg = '$e';
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length);
      }
      setState(() {
        _busy = false;
        _status = null;
        _error = 'Setup failed: $msg';
      });
      return;
    }
    // Success: the cover's server-list listener dismisses the whole flow.
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(title: const Text('Server Mode')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.sizeOf(context).height * 0.08,
          24,
          40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set up this PC as a server',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: VelvetColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'mStream runs its server right here on this PC. Point it '
                  'at your music, create your login, and this app connects '
                  'to it automatically.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: VelvetColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                Text('MUSIC FOLDER', style: _sectionStyle),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _folderCtrl,
                        readOnly: true,
                        decoration: _dec(
                          'Folder',
                          hint: 'Choose the folder with your music',
                        ),
                        onTap: _busy ? null : _browse,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _browse,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Browse…'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('YOUR LOGIN', style: _sectionStyle),
                const SizedBox(height: 10),
                TextField(
                  controller: _userCtrl,
                  enabled: !_busy,
                  decoration: _dec('Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: _dec('Password'),
                ),
                const SizedBox(height: 24),
                Text('OPTIONS', style: _sectionStyle),
                const SizedBox(height: 10),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _portCtrl,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Port'),
                  ),
                ),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: VelvetColors.error, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: _busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _status ?? 'Working…',
                              style: TextStyle(
                                color: VelvetColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Start my server'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _sectionStyle => TextStyle(
    fontSize: 11,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w700,
    color: VelvetColors.textTertiary,
  );
}

// ---------------------------------------------------------------------------
// Shared big option card (hover-aware), used by both chooser screens.
// ---------------------------------------------------------------------------

class _ModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            decoration: BoxDecoration(
              color: _hover ? VelvetColors.raised : VelvetColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hover ? VelvetColors.primary : VelvetColors.border,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: VelvetColors.primaryDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: VelvetColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: VelvetColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: VelvetColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
