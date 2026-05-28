import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';
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

  bool submitPending = false;
  bool saveToSdCard = false;
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

    try {
      Server s = ServerManager().serverList[editThisServer ?? -1];
      _urlCtrl.text = s.url;
      _usernameCtrl.text = s.username ?? '';
      _passwordCtrl.text = s.password ?? '';
      saveToSdCard = s.saveToSdCard;
      // An existing server saved without credentials is a public
      // server — start in public mode so the toggle reflects reality.
      if ((s.username ?? '').isEmpty && (s.password ?? '').isEmpty) {
        _publicAccess = true;
      }
    } catch (err) {}

    _detectSdCard();

    // Stale-result-clearing: editing the URL invalidates whatever
    // banner the last test produced (it was for a different URL).
    _urlCtrl.addListener(_clearTestResult);
  }

  void _clearTestResult() {
    if (_testResult != null) {
      setState(() {
        _testResult = null;
        _testSuccess = null;
      });
    }
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
      if (mounted && hasSd != _hasSdCard) {
        setState(() => _hasSdCard = hasSd);
      }
    } catch (_) {
      // Platform doesn't support it — stay hidden.
    }
  }

  @override
  void dispose() {
    _urlCtrl.removeListener(_clearTestResult);
    _urlCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();

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

  Future<void> saveServer(Uri lol, [String jwt = '']) async {
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

    if (shouldUpdate) {
      ServerManager().editServer(
          editThisServer!, _urlCtrl.text, username, password, saveToSdCard);
      await ServerManager()
          .getServerPaths(ServerManager().serverList[editThisServer!]);
      await ServerManager().callAfterEditServer();
    } else {
      Server newServer =
          new Server(lol.origin, username, password, jwt, Uuid().v4());
      if (saveToSdCard == true) {
        newServer.saveToSdCard = true;
      }
      await ServerManager().getServerPaths(newServer);

      await ServerManager().addServer(newServer);
    }

    // Save Server List
    Navigator.pop(context);
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
              // Switch only renders when an actual removable SD card
              // is present (see _detectSdCard). Hidden on internal-
              // storage-only phones — most modern devices.
              if (_hasSdCard) ...[
                SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.fieldSdCard),
                  subtitle: Text(
                    l.sdCardSubtitle,
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 12),
                  ),
                  value: saveToSdCard,
                  onChanged: (v) => setState(() => saveToSdCard = v),
                  activeThumbColor: VelvetColors.primary,
                ),
              ],
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
