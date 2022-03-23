import 'package:flutter/material.dart';
import '../objects/metadata.dart';

class MeteDataScreen extends StatelessWidget {
  // In the constructor, require a Todo.
  const MeteDataScreen({Key? key, required this.meta, required this.path})
      : super(key: key);

  // Declare a field that holds the Todo.
  final MusicMetadata meta;

  final String? path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFF3f3f3f),
        appBar: AppBar(
          title: Text("Song Info"),
        ),
        body: Container(
            // padding: EdgeInsets.all(20.0),
            child: ListView(children: [
          if (meta.albumArt != null) ...[Image.network(meta.albumArt!)],
          Container(height: 20),
          if (meta.title != null) ...[
            Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(meta.title!)),
          ],
          if (meta.artist != null) ...[
            Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(meta.artist!))
          ],
          if (meta.album != null) ...[
            Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(meta.album!)),
          ],
          if (meta.year != null) ...[
            Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(meta.year!.toString()))
          ],
          Container(height: 20),
          if (path != null) ...[
            Container(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(path!))
          ]
        ])));
  }
}
