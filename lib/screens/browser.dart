import 'package:flutter/material.dart';

class Browser extends StatelessWidget {
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Material(
          color: Color(0xFFffffff),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                    icon: Icon(Icons.keyboard_arrow_left, color: Colors.black),
                    tooltip: 'Go Back',
                    onPressed: () {}),
              ])),
      // Expanded(
      //   child: SizedBox(
      //     child: ListView.separated(itemBuilder: itemBuilder, separatorBuilder: (BuildContext context, int index) => Divider( height: 3, color: Colors.white), itemCount: itemCount)
      //   )
      // )
    ]);
  }
}
