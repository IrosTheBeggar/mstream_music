// ApiManager.fileExplorerRows: the one row builder for a
// `POST /api/v1/file-explorer` answer, shared by getFileList (a folder
// opened in the File Explorer) and Add from YouTube's in-place re-list
// (screens/ytdl/ytdl_folder_strip.dart). Pins what getFileList built before
// the extraction, so a re-listed folder draws exactly as a freshly opened
// one: folders first, then files, in the server's order; each row's data
// is the server path joined with its name; an .m3u wears the playlist
// icon; a file's metadata is read one level in ({filepath, metadata: {…}})
// and an unscanned file (no inner map) is still listed, bare.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';

void main() {
  final server = Server('http://music.example', null, null, 'JWT', 'home');

  final answer = {
    'path': '/Music/Daft Punk/',
    'directories': [
      {'name': 'Homework'},
      {'name': 'Discovery'},
    ],
    'files': [
      {
        'name': 'One_More_Time.mp3',
        'metadata': {
          'filepath': 'Music/Daft Punk/One_More_Time.mp3',
          'metadata': {
            'title': 'One More Time',
            'artist': 'Daft Punk',
            'album': 'Discovery',
          },
        },
      },
      {'name': 'Unscanned.flac', 'metadata': {'filepath': 'x', 'metadata': null}},
      {'name': 'Mix.m3u'},
    ],
  };

  test('folders then files, data joined onto the server path', () {
    final rows = ApiManager().fileExplorerRows(server, answer);
    expect([for (final r in rows) r.type],
        ['directory', 'directory', 'file', 'file', 'file']);
    expect([for (final r in rows) r.data], [
      '/Music/Daft Punk/Homework',
      '/Music/Daft Punk/Discovery',
      '/Music/Daft Punk/One_More_Time.mp3',
      '/Music/Daft Punk/Unscanned.flac',
      '/Music/Daft Punk/Mix.m3u',
    ]);
    expect(rows.every((r) => identical(r.server, server)), isTrue);
  });

  test('icons: folder, track, playlist file', () {
    final rows = ApiManager().fileExplorerRows(server, answer);
    IconData? icon(int i) => rows[i].icon?.icon;
    expect(icon(0), Icons.folder);
    expect(icon(2), Icons.music_note);
    expect(icon(4), Icons.queue_music);
  });

  test('metadata one level in; an unscanned file listed without it', () {
    final rows = ApiManager().fileExplorerRows(server, answer);
    expect(rows[2].metadata?.title, 'One More Time');
    expect(rows[2].metadata?.artist, 'Daft Punk');
    expect(rows[3].metadata, isNull);
    expect(rows[4].metadata, isNull);
  });

  test('the server root: libraries only', () {
    final rows = ApiManager().fileExplorerRows(server, {
      'path': '/',
      'directories': [
        {'name': 'Music'},
      ],
      'files': [],
    });
    expect(rows.single.data, '/Music');
    expect(rows.single.type, 'directory');
  });
}
