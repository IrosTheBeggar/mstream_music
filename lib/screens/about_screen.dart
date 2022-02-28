import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("About"),
        ),
        body: Container(
            padding: EdgeInsets.all(40.0),
            child: ListView(children: [
              Image(image: AssetImage('graphics/mstream-logo.png')),
              Container(
                height: 15,
              ),
              Text('mStream Mobile v0.12',
                  style: TextStyle(
                      fontFamily: 'Jura',
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              Container(
                height: 45,
              ),
              Text('Developed By:',
                  style: TextStyle(
                      fontFamily: 'Jura',
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              Text('Paul Sori',
                  style: TextStyle(
                      fontFamily: 'Jura',
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              Text('paul@mstream.io',
                  style: TextStyle(
                      fontFamily: 'Jura',
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ])));
  }
}
