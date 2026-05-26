import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';

class AddServerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Add Server"),
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
          title: Text("Edit Server"),
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

  // Hits the server's public /api/ endpoint, parses the version
  // string, and surfaces the result inline as a banner. Independent
  // of the Save button — and of public-vs-authenticated mode, since
  // /api/ requires no credentials.
  Future<void> _testConnection() async {
    if (_urlCtrl.text.trim().isEmpty) {
      setState(() {
        _testResult = 'Enter a server URL first.';
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
        _testResult = 'Could not parse URL.';
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
      final response = await http
          .get(url.resolve('/api/'))
          .timeout(Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final version = data['server']?.toString() ?? 'unknown';
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = 'Connected — mStream v$version';
          _testSuccess = true;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = 'Connection timed out.';
          _testSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = 'Could not connect: $e';
          _testSuccess = false;
        });
      }
    }
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
    setState(() {
      submitPending = true;
    });
    Uri lol = Uri.parse(this._urlCtrl.text);
    var response;

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
            .showSnackBar(SnackBar(content: Text('Connection Successful!')));
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
          content: Text('Could not reach server. If it requires login, '
              'turn off "Public access" and add credentials.'),
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
          .showSnackBar(SnackBar(content: Text('Failed to Login')));
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
                    return 'Server URL is needed';
                  }
                  try {
                    final parsed = Uri.parse(value);
                    if (parsed.origin is Error || parsed.origin.isEmpty) {
                      return 'Cannot parse URL';
                    }
                  } catch (_) {
                    return 'Cannot parse URL';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://mstream.example.com',
                  prefixIcon: Icon(Icons.link),
                ),
                onSaved: (v) => _urlCtrl.text = v ?? '',
              ),
              SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Public access'),
                subtitle: Text(
                  "Server is publicly accessible — no username or "
                  'password needed.',
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
                  labelText: 'Username',
                  hintText: 'Username',
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
                  labelText: 'Password',
                  hintText: 'Password',
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
                label: Text(_testing ? 'Testing…' : 'Test Connection'),
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
                  title: Text('Download to SD Card'),
                  subtitle: Text(
                    'Save downloaded music to the removable SD card '
                    'instead of internal storage.',
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
                          Text('Connecting…'),
                        ],
                      )
                    : Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
