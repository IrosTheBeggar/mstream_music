import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:mstream_music/native/user_shaders.dart';

// Unit tests for the pure file-reading helpers on UserShaders — `// title:`
// header parsing and the shader sanity check. The folder resolver
// (folderPath/list/delete) goes through path_provider platform channels and
// is not exercised here; these helpers take an explicit path and only touch
// the filesystem, so they run as plain VM tests.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('user_shaders_test');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> writeShader(String name, String content) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsString(content);
    return f.path;
  }

  group('titleOf', () {
    test('parses the // title: header', () async {
      final path = await writeShader('a.glsl',
          '// title: Spectrum Bars\n// author: x\nvoid mainImage() {}\n');
      expect(await UserShaders().titleOf(path), 'Spectrum Bars');
    });

    test('is case-insensitive and trims surrounding whitespace', () async {
      final path = await writeShader(
          'b.glsl', '//   TITLE:   Neon Hexagons  \nvoid main(){}');
      expect(await UserShaders().titleOf(path), 'Neon Hexagons');
    });

    test('returns null when there is no title header', () async {
      final path = await writeShader('c.glsl', 'void mainImage() {}\n');
      expect(await UserShaders().titleOf(path), isNull);
    });

    test('ignores a // title: that appears after the first code line',
        () async {
      final path = await writeShader(
          'd.glsl', 'void mainImage() {}\n// title: TooLate\n');
      expect(await UserShaders().titleOf(path), isNull);
    });

    test('returns null for a missing file', () async {
      expect(
          await UserShaders().titleOf(p.join(tmp.path, 'nope.glsl')), isNull);
    });
  });

  group('looksValid', () {
    test('true with a mainImage entry point', () async {
      final path =
          await writeShader('e.glsl', 'void mainImage(out vec4 c, in vec2 u){}');
      expect(await UserShaders().looksValid(path), isTrue);
    });

    test('true with a void main entry point', () async {
      final path = await writeShader('f.glsl', 'void main(){}');
      expect(await UserShaders().looksValid(path), isTrue);
    });

    test('false for an empty / whitespace-only file', () async {
      final path = await writeShader('g.glsl', '   \n\n  ');
      expect(await UserShaders().looksValid(path), isFalse);
    });

    test('false when there is no entry point', () async {
      final path =
          await writeShader('h.glsl', '// comment only\nfloat x = 1.0;');
      expect(await UserShaders().looksValid(path), isFalse);
    });

    test('false for a missing file', () async {
      expect(await UserShaders().looksValid(p.join(tmp.path, 'nope.glsl')),
          isFalse);
    });
  });

  group('isImported', () {
    test('asset keys are bundled, not imported', () {
      expect(UserShaders().isImported('assets/shaders/x.glsl'), isFalse);
    });
    test('absolute filesystem paths are imported', () {
      expect(UserShaders().isImported('/storage/emulated/0/shaders/x.glsl'),
          isTrue);
    });
  });
}
