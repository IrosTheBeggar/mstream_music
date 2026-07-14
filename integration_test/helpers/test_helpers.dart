// Shared utilities for integration tests.
//
// testApp wraps MStreamApp in a MaterialApp that carries the app's real
// localization delegates. _MStreamAppState.build calls
// AppLocalizations.of(context), which returns null under a bare
// MaterialApp — so the app throws on its first frame without these.
//
// resetAppState wipes servers.json from disk and clears the singletons
// that hold UI state across tests.
//
// MockServer spins up an in-process dart:io HttpServer on emulator
// loopback. Callers pass a map of path → handler; the server matches by
// req.uri.path and returns the handler's output as JSON. /api/v1/ping is
// always handled with a default response so tests don't have to repeat
// it. A `defaultHandler` runs for unmatched paths (used by the playback
// test to serve audio bytes for /media/*).
//
// Handler return values: null → 404; List<int> → returned as
// audio/wav bytes (used for media); anything else → JSON-encoded.
//
// seedServer writes a single-server servers.json so MStreamApp's
// initState loads it on startup, skipping the welcome screen.
//
// buildSilentWav returns an in-memory 8-bit unsigned PCM WAV file
// (mono, 8kHz). Avoids carrying a binary fixture in the repo.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mstream_music/main.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/browser_list.dart';

Widget testApp() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MStreamApp(),
    );

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

  static Future<MockServer> start(
    Map<String, MockRoute> routes, {
    MockRoute? defaultHandler,
  }) async {
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
      final handler = allRoutes[req.uri.path] ?? defaultHandler;
      if (handler == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }

      final body = handler(req);
      if (body == null) {
        req.response.statusCode = 404;
      } else if (body is List<int>) {
        // Serve byte ranges. AVPlayer (just_audio on iOS) probes with
        // Range requests and refuses to stream from a server that
        // answers them with a plain 200 (error -11850 "Operation
        // Stopped"); ExoPlayer on Android doesn't care. Real mStream
        // servers support ranges, so mirror that here.
        final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
        final range = rangeHeader == null
            ? null
            : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(rangeHeader);
        req.response.headers
          ..contentType = ContentType('audio', 'wav')
          ..set(HttpHeaders.acceptRangesHeader, 'bytes');
        if (range != null) {
          final start = int.parse(range.group(1)!);
          final endStr = range.group(2)!;
          var end = endStr.isEmpty ? body.length - 1 : int.parse(endStr);
          if (end > body.length - 1) end = body.length - 1;
          req.response.statusCode = HttpStatus.partialContent;
          req.response.headers
            ..contentLength = end - start + 1
            ..set(HttpHeaders.contentRangeHeader,
                'bytes $start-$end/${body.length}');
          req.response.add(body.sublist(start, end + 1));
        } else {
          req.response.statusCode = 200;
          req.response.headers.contentLength = body.length;
          req.response.add(body);
        }
      } else {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(body));
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

/// Builds a silent 16-bit signed PCM mono WAV file in memory.
/// Default 5 seconds at 8 kHz = 80 KB. 16-bit signed is the most
/// universally supported PCM format on Android's ExoPlayer.
Uint8List buildSilentWav({int seconds = 5, int sampleRate = 8000}) {
  final dataSize = sampleRate * seconds * 2; // 2 bytes per sample
  final fileSize = dataSize + 36;

  final b = BytesBuilder();
  b.add(ascii.encode('RIFF'));
  b.add(_le32(fileSize));
  b.add(ascii.encode('WAVE'));
  b.add(ascii.encode('fmt '));
  b.add(_le32(16));
  b.add(_le16(1)); // PCM
  b.add(_le16(1)); // mono
  b.add(_le32(sampleRate));
  b.add(_le32(sampleRate * 2)); // byte rate
  b.add(_le16(2)); // block align
  b.add(_le16(16)); // bits per sample
  b.add(ascii.encode('data'));
  b.add(_le32(dataSize));
  // 16-bit signed PCM silence is 0 — Uint8List defaults to zero.
  b.add(Uint8List(dataSize));

  return b.toBytes();
}

List<int> _le16(int v) => [v & 0xff, (v >> 8) & 0xff];

List<int> _le32(int v) => [
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ];
