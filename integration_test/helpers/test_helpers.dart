// Shared utilities for integration tests.
//
// resetAppState wipes servers.json from disk and clears the singletons
// that hold UI state across tests.
//
// MockServer spins up an in-process dart:io HttpServer on emulator
// loopback. Callers pass a map of path → handler; the server matches by
// req.uri.path and returns the handler's output as JSON. /api/v1/ping is
// always handled with a default response so tests don't have to repeat
// it.
//
// seedServer writes a single-server servers.json so MStreamApp's
// initState loads it on startup, skipping the welcome screen.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/browser_list.dart';

const _seededLocalname = 'integration-test-server';

Future<void> resetAppState() async {
  final dir = await getApplicationDocumentsDirectory();
  final serversFile = File('${dir.path}/servers.json');
  if (await serversFile.exists()) {
    await serversFile.delete();
  }
  ServerManager().serverList.clear();
  ServerManager().currentServer = null;
  BrowserManager().browserCache.clear();
  BrowserManager().browserList.clear();
}

typedef MockRoute = Object? Function(HttpRequest req);

class MockServer {
  MockServer._(this._server, this.url);

  final HttpServer _server;
  final String url;

  static Future<MockServer> start(Map<String, MockRoute> routes) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = 'http://127.0.0.1:${server.port}';

    final allRoutes = <String, MockRoute>{
      '/api/v1/ping': (_) => {
            'vpaths': ['default'],
            'playlists': <String>[],
          },
      ...routes,
    };

    server.listen((HttpRequest req) async {
      req.response.headers.contentType = ContentType.json;
      final handler = allRoutes[req.uri.path];
      if (handler != null) {
        final body = handler(req);
        if (body == null) {
          req.response.statusCode = 404;
        } else {
          req.response.statusCode = 200;
          req.response.write(jsonEncode(body));
        }
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });

    return MockServer._(server, url);
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

Future<void> seedServer(String mockUrl) async {
  final dir = await getApplicationDocumentsDirectory();
  final serversFile = File('${dir.path}/servers.json');
  await serversFile.writeAsString(jsonEncode([
    {
      'url': mockUrl,
      'jwt': null,
      'username': null,
      'password': null,
      'localname': _seededLocalname,
      'autoDJPaths': <String, bool>{},
      'autoDJminRating': null,
      'playlists': <String>[],
      'saveToSdCard': false,
    },
  ]));
}
