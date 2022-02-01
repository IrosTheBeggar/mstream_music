import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';

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
    } catch (err) {}
  }

  @override
  void dispose() {
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
    String origin = lol.origin;
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
        saveServer(origin);
        return;
      }
    } catch (err) {}

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
      saveServer(origin, res['token']);
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

  Future<void> saveServer(String origin, [String jwt = '']) async {
    bool shouldUpdate = false;
    try {
      ServerManager().serverList[editThisServer ?? -1];
      shouldUpdate = true;
    } catch (err) {}

    if (shouldUpdate) {
      ServerManager().editServer(editThisServer!, _urlCtrl.text,
          _usernameCtrl.text, _passwordCtrl.text, saveToSdCard);
    } else {
      Server newServer = new Server(origin, this._usernameCtrl.text,
          this._passwordCtrl.text, jwt, Uuid().v4());
      if (saveToSdCard == true) {
        newServer.saveToSdCard = true;
      }
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

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey we created above
    return Container(
      color: Color(0xFF3f3f3f),
      padding: EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
                controller: _urlCtrl,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Server URL is needed';
                  }
                  try {
                    var lol = Uri.parse(value);
                    if (lol.origin is Error || lol.origin.length < 1) {
                      return 'Cannot Parse URL';
                    }
                  } catch (err) {
                    return 'Cannot Parse URL';
                  }
                },
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'https://mstream.io',
                  labelText: 'Server URL',
                ),
                onSaved: (String? value) {
                  this._urlCtrl.text = value ?? '';
                }),
            Container(
                width: MediaQuery.of(context).size.width,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      Expanded(
                          child: TextFormField(
                              controller: _usernameCtrl,
                              validator: (value) {},
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                  hintText: 'Username', labelText: 'Username'),
                              onSaved: (String? value) {
                                this._usernameCtrl.text = value!;
                              })),
                      Container(width: 8), // Make a gap between the buttons
                      Expanded(
                          child: TextFormField(
                              controller: _passwordCtrl,
                              validator: (value) {},
                              obscureText:
                                  true, // Use secure text for passwords.
                              decoration: InputDecoration(
                                  hintText: 'Password', labelText: 'Password'),
                              onSaved: (String? value) {
                                this._passwordCtrl.text = value!;
                              })),
                    ])),
            Container(
              height: 20,
            ),
            // if (this.editThisServer == null) ...[
            Row(
              children: [
                Switch(
                  value: this.saveToSdCard,
                  onChanged: (value) {
                    setState(() {
                      this.saveToSdCard = value;
                    });
                  },
                ),
                Text('Download to SD Card')
              ],
            ),
            // ],
            Container(
              width: MediaQuery.of(context).size.width,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(primary: Colors.blue),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.photo_camera, color: Colors.white),
                              Container(width: 8),
                              Text('QR Code',
                                  style: TextStyle(color: Colors.white)),
                            ]),
                        onPressed: submitPending
                            ? null
                            : () {
                                FlutterBarcodeScanner.scanBarcode(
                                        '#ff6666', 'Cancel', false, ScanMode.QR)
                                    .then((qrValue) {
                                  if (qrValue == '-1' || qrValue == '') {
                                    return;
                                  }

                                  try {
                                    Map<String, String> parsedValues =
                                        parseQrCode(qrValue);
                                    _urlCtrl.text = parsedValues['url'] ?? '';
                                    _usernameCtrl.text =
                                        parsedValues['username'] ?? '';
                                    _passwordCtrl.text =
                                        parsedValues['password'] ?? '';
                                  } catch (err) {
                                    Scaffold.of(context).showSnackBar(SnackBar(
                                        content: Text('Invalid Code')));
                                  }
                                });

                                //});
                                // new QRCodeReader().scan().then((qrValue) {
                                //   if (qrValue == null || qrValue == '') {
                                //     return;
                                //   }

                                //   try {
                                //     Map<String, String> parsedValues =
                                //         parseQrCode(qrValue);
                                //     _urlCtrl.text = parsedValues['url'];
                                //     _usernameCtrl.text = parsedValues['username'];
                                //     _passwordCtrl.text = parsedValues['password'];
                                //   } catch (err) {
                                //     Scaffold.of(context).showSnackBar(
                                //         SnackBar(content: Text('Invalid Code')));
                                //   }
                                // });
                              },
                      ),
                    ),
                    Container(width: 8), // Make a gap between the buttons
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(primary: Colors.green),
                        child: Text(submitPending ? 'Checking Server' : 'Save',
                            style: TextStyle(color: Colors.white)),
                        onPressed: submitPending
                            ? null
                            : () {
                                // Validate will return true if the form is valid, or false if
                                // the form is invalid.
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }

                                _formKey.currentState!
                                    .save(); // Save our form now.

                                // Ping server
                                checkServer();
                              },
                      ),
                    ),
                  ]),
              margin: EdgeInsets.only(top: 20.0),
            ),
          ],
        ),
      ),
    );
  }
}
