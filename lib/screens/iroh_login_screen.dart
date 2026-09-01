import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';

/// Full-screen sign-in for the Quick Connect flows.
///
/// Both Quick Connect paths — pasting/scanning a pairing code and tapping a
/// server discovered on the LAN — used to surface their credential form at
/// the bottom of the add-server page (an inline reveal under the Test button,
/// and a modal sheet respectively). On most phones that landed under the
/// fold: the test reported success and, as far as the user could see,
/// nothing else happened. A pushed page cannot be missed, and backing out of
/// it returns to the Quick Connect tab with the connection still live.
///
/// The page owns only the credentials and their validation round-trip:
/// [validate] runs the actual login (through the live tunnel, or against the
/// LAN address) and returns null on success or a message to show inline —
/// so a wrong password is retryable right here instead of bouncing the user
/// back a screen. On success the page pops with `(username, password)`; the
/// caller finishes its flow (save / pairing-code fetch) exactly as before.
class IrohLoginScreen extends StatefulWidget {
  /// AppBar title — "Sign in" for the pairing-code flow, or
  /// "Sign in to {server}" for a discovered LAN server.
  final String title;

  /// Runs the login attempt; returns null on success, or the error message
  /// to display under the fields.
  final Future<String?> Function(String username, String password) validate;

  const IrohLoginScreen(
      {super.key, required this.title, required this.validate});

  @override
  State<IrohLoginScreen> createState() => _IrohLoginScreenState();
}

class _IrohLoginScreenState extends State<IrohLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.validate(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop((_userCtrl.text, _passCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: VelvetColors.textPrimary,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_outline,
                  size: 40, color: VelvetColors.textSecondary),
              const SizedBox(height: 20),
              TextField(
                controller: _userCtrl,
                autofocus: true,
                enabled: !_busy,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: VelvetColors.textPrimary),
                decoration: InputDecoration(
                  labelText: l.fieldUsername,
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _submit(),
                style: TextStyle(color: VelvetColors.textPrimary),
                decoration: InputDecoration(
                  labelText: l.fieldPassword,
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VelvetColors.error.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: VelvetColors.error, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VelvetColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall),
                  ),
                  textStyle:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(_busy ? l.irohSigningIn : l.irohSignInSave),
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
