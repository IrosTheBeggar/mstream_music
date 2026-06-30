// Standalone probe for the server-binary acquisition pipeline. For THIS
// platform it resolves the mStream release asset, downloads it, prints the
// SHA-256 (pin it in ServerBinaryManager.target.sha256ByPlatform), extracts it,
// and checks the Bun executable is present inside.
//
//   dart run tool/server_binary_probe.dart
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mstream_music/server/server_release.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  const release = ServerRelease(repo: 'IrosTheBeggar/mStream', version: '6.15.1');
  final key = ServerRelease.platformKey();
  if (key == null) {
    stdout.writeln('unsupported platform — no mStream release');
    return;
  }
  stdout.writeln('platform key : $key');
  stdout.writeln('asset        : ${release.assetName}');
  stdout.writeln('url          : ${release.downloadUrl}');

  final tmp = Directory.systemTemp.createTempSync('mstream_probe_');
  try {
    final zip = File(p.join(tmp.path, release.assetName!));
    stdout.writeln('downloading…');
    final client = http.Client();
    final resp = await client.send(http.Request('GET', Uri.parse(release.downloadUrl!)));
    if (resp.statusCode != 200) {
      stdout.writeln('download HTTP ${resp.statusCode}');
      return;
    }
    var got = 0;
    final sink = zip.openWrite();
    await for (final c in resp.stream) {
      sink.add(c);
      got += c.length;
    }
    await sink.close();
    client.close();
    stdout.writeln('downloaded   : ${(got / 1024 / 1024).toStringAsFixed(1)} MB');

    final digest = await sha256.bind(zip.openRead()).single;
    stdout.writeln('SHA-256      : $digest');
    stdout.writeln("  → pin as     '$key': '$digest',");

    stdout.writeln('extracting…');
    final out = Directory(p.join(tmp.path, 'x'))..createSync();
    await extractFileToDisk(zip.path, out.path);
    final exe = p.join(out.path, release.archiveRootDir!, ServerRelease.executableName);
    final exists = File(exe).existsSync();
    stdout.writeln('executable   : ${exists ? "PRESENT" : "MISSING"}  '
        '(${ServerRelease.executableName})');
    if (exists) {
      stdout.writeln('exe size     : '
          '${(File(exe).lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB');
    }
    stdout.writeln(exists
        ? 'OK — full download → hash → extract pipeline works.'
        : 'FAIL — executable not found at expected path.');
  } finally {
    tmp.deleteSync(recursive: true);
    stdout.writeln('cleaned up temp');
  }
}
