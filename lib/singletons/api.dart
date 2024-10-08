import './server_list.dart';
import './browser_list.dart';
import '../objects/server.dart';
import '../objects/display_item.dart';
import '../objects/metadata.dart';
import 'media.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:audio_service/audio_service.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiManager {
  ApiManager._privateConstructor();
  static final ApiManager _instance = ApiManager._privateConstructor();
  factory ApiManager() {
    return _instance;
  }

  Future makeServerCall(Server? currentServer, String location, Map payload,
      String getOrPost) async {
    Server server = ServerManager().currentServer ??
        (throw Exception('No Server Selected'));

    Uri currentUri = Uri.parse(server.url).resolve(location);

    var response;
    if (getOrPost == 'GET') {
      response = await http
          .get(currentUri, headers: {'x-access-token': server.jwt ?? ''});
    } else {
      response = await http.post(currentUri,
          body: json.encode(payload),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.jwt ?? ''
          });
    }

    if (response.statusCode > 299) {
      throw Exception('Server Call Failed');
    }

    return jsonDecode(response.body);
  }

  Future<void> getRecursiveFiles(String directory,
      {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer,
          '/api/v1/file-explorer/recursive', {"directory": directory}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    // String prefix =
    //     TranscodeManager().transcodeOn == true ? '/transcode' : '/media';

    res.forEach((e) {
      String lolUrl = Uri.encodeFull(useThisServer!.url +
          '/media' +
          (e.toString()[0] != '/' ? '/' : '') +
          e +
          '?app_uuid=' +
          Uuid().v4() +
          (useThisServer.jwt == null ? '' : '&token=' + useThisServer.jwt!));

      MediaItem lol = new MediaItem(
          id: lolUrl,
          title: e.split("/").last,
          extras: {'server': useThisServer.localname, 'path': e});
      MediaManager().audioHandler.addQueueItem(lol);
    });
  }

  Future<void> getPlaylists({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/playlist/getall', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Playlists');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'playlist',
          e['name'],
          Icon(Icons.queue_music, color: Colors.black),
          null);
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> removePlaylist(String playlistId,
      {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/playlist/delete',
          {'playlistname': playlistId}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().removeAll(playlistId, useThisServer!, 'playlist');
  }

  Future<void> searchServer(String search) async {
    try {
      var res = await makeServerCall(null, '/api/v1/db/search',
          {'noFiles': true, 'search': search}, 'POST');

      BrowserManager().setBrowserLabel('Search');
      List<DisplayItem> newList = [];
      res['artists'].forEach((e) {
        DisplayItem newItem = new DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'artist',
            e['name'],
            Icon(Icons.library_music, color: Colors.black),
            'artist');
        newItem.altAlbumArt = e['album_art_file'];
        newList.add(newItem);
      });

      res['albums'].forEach((e) {
        DisplayItem newItem = new DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'album',
            e['name'],
            Icon(Icons.library_music, color: Colors.black),
            'album');
        newItem.altAlbumArt = e['album_art_file'];
        newList.add(newItem);
      });

      res['title'].forEach((e) {
        DisplayItem newItem = new DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'file',
            '/' + e['filepath'],
            Icon(Icons.music_note, color: Colors.blue),
            'song');
        newItem.altAlbumArt = e['album_art_file'];
        newList.add(newItem);
      });

      BrowserManager().addListToStack(newList);
    } catch (err) {
      print(err);
    }
  }

  Future<void> getAlbums({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/albums', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Albums');

    List<DisplayItem> newList = [];
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'album',
          e['name'],
          Icon(Icons.album, color: Colors.black),
          e['year']?.toString() ?? '');
      newItem.altAlbumArt = e['album_art_file'];
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getAlbumSongs(String? album, {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/db/album-songs', {'album': album}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: Colors.blue),
          null);

      newItem.metadata = m;

      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getRecentlyAdded({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/db/recent/added', {'limit': 100}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Recent');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: Colors.blue),
          null);

      newItem.metadata = m;

      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList);
  }

  Future<void> getRated({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/rated', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Rated');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: Colors.blue),
          m.artist);

      newItem.metadata = m;
      newItem.showRating = true;

      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList);
  }

  Future<void> getArtists({Server? useThisServer}) async {
    var res;
    try {
      res =
          await makeServerCall(useThisServer, '/api/v1/db/artists', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Artists');

    List<DisplayItem> newList = [];
    res['artists'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e, 'artist', e,
          Icon(Icons.library_music, color: Colors.black), null);
      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList);
  }

  Future<void> getArtistAlbums(String artist, {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/artists-albums',
          {'artist': artist}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    List<DisplayItem> newList = [];
    res['albums'].forEach((e) {
      String name = e['name'] ?? 'SINGLES';

      // TODO: Errors on singles
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          name,
          'album',
          e['name'],
          Icon(Icons.album, color: Colors.black),
          e['year']?.toString() ?? '');
      newItem.altAlbumArt = e['album_art_file'];

      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getPlaylistContents(String playlistName,
      {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/playlist/load',
          {'playlistname': playlistName}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: Colors.blue),
          null);

      newItem.metadata = m;
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getFileList(String directory, {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/file-explorer',
          {"directory": directory}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('File Explorer');

    List<DisplayItem> newList = [];
    res['directories'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'directory',
          path.join(res['path'], e['name']),
          Icon(Icons.folder, color: Color(0xFFffab00)),
          null);
      newList.add(newItem);
    });

    res['files'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'file',
          path.join(res['path'], e['name']),
          Icon(Icons.music_note, color: Colors.blue),
          null);
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }
}
