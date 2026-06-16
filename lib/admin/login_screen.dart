import 'package:flutter/material.dart';

import 'admin_api.dart';
import 'admin_session.dart';

/// Login form for the standalone web build. Authenticates against
/// `POST /api/v1/auth/login` and hands the resulting [AdminSession] back to the
/// host (see `admin_main.dart`). Defaults the server URL to the page origin,
/// which is correct when the build is served from the mStream server itself.
class LoginScreen extends StatefulWidget {
  final void Function(AdminSession) onLoggedIn;

  /// Pre-filled server origin. On web this is the page origin.
  final String defaultBaseUrl;

  /// Hide the server-URL field when the origin is fixed (served from server).
  final bool allowServerEdit;

  const LoginScreen({
    super.key,
    required this.onLoggedIn,
    required this.defaultBaseUrl,
    this.allowServerEdit = true,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _server = TextEditingController(text: widget.defaultBaseUrl);
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final baseUrl = _server.text.trim();
    if (baseUrl.isEmpty || _username.text.trim().isEmpty) {
      setState(() => _error = 'Server and username are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await AdminApi.login(
          baseUrl, _username.text.trim(), _password.text);
      widget.onLoggedIn(AdminSession(
        baseUrl: baseUrl,
        token: '${res['token']}',
        label: _username.text.trim(),
      ));
    } on AdminApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.settings_suggest, size: 48, color: scheme.primary),
                  const SizedBox(height: 8),
                  Text('mStream Admin',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  if (widget.allowServerEdit) ...[
                    TextField(
                      controller: _server,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        prefixIcon: Icon(Icons.dns),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _username,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
