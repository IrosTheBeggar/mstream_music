import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

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

class MyCustomForm extends StatefulWidget {
  @override
  MyCustomFormState createState() {
    return MyCustomFormState();
  }
}

// Create a corresponding State class. This class will hold the data related to
// the form.
class MyCustomFormState extends State<MyCustomForm> {
  // Create a global key that will uniquely identify the Form widget and allow
  // us to validate the form
  // Note: This is a GlobalKey<FormState>, not a GlobalKey<MyCustomFormState>!
  final _formKey = GlobalKey<FormState>();
  bool _isUpdate = false;
  late Directory useThisDir;
  ServerManager serverManager = ServerManager();

  TextEditingController _urlCtrl = TextEditingController();
  TextEditingController _usernameCtrl = TextEditingController();
  TextEditingController _passwordCtrl = TextEditingController();

  bool submitPending = false;

  checkServer() async {
    setState(() {
      submitPending = true;
    });
    Uri lol = Uri.parse(this._urlCtrl.text);
    String origin = lol.origin;
    var response;

    try {
      response = await http.get(lol.resolve('/ping'));
    } catch (err) {
      setState(() {
        submitPending = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not connect to server')));
      return;
    }

    // Check for login
    if (response.statusCode == 200) {
      setState(() {
        submitPending = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Connection Successful!')));
      saveServer(origin);
      return;
    }

    // Try logging in
    try {
      response = await http.post(lol.resolve('/login'), body: {
        "username": this._usernameCtrl.text,
        "password": this._passwordCtrl.text
      });
    } catch (err) {
      setState(() {
        submitPending = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to Login')));
      return;
    }

    if (response.statusCode != 200) {
      setState(() {
        submitPending = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to Login')));
      return;
    }

    var res = jsonDecode(response.body);

    // Save
    saveServer(origin, res['token']);
  }

  Future<void> saveServer(String origin, [String jwt = '']) async {
    Server newServer = new Server(origin, this._usernameCtrl.text,
        this._passwordCtrl.text, jwt, Uuid().v4());
    await serverManager.addServer(newServer);

    // Save Server List
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((filepath) {
      useThisDir = filepath;
    });
  }

  Map<String, String> parseQrCode(String qrValue) {
    if (qrValue[0] != '|') {
      throw new Error();
    }

    List<String> explodeArr = qrValue.split("|");
    if (explodeArr.length < 5) {
      throw new Error();
    }

    return {
      'url': explodeArr[1],
      'username': explodeArr[2],
      'password': explodeArr[3],
      'serverName': explodeArr[4]
    };
  }

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey we created above
    // try {
    //   serverList[editThisServer];
    //   _urlCtrl.text = serverList[editThisServer].url;
    //   _usernameCtrl.text = serverList[editThisServer].username;
    //   _passwordCtrl.text = serverList[editThisServer].password;
    //   _isUpdate = true;
    // } catch (err) {

    // }

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
                  this._urlCtrl.text = value!;
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

                                // _formKey.currentState.save(); // Save our form now.

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
