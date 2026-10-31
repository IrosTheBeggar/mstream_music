import 'dart:io';

import 'package:library_mirror/library_mirror.dart';

/// Headless library copy: `dart run library_mirror:mstream_mirror --server
/// http://nas:3000 --dest D:\Music --keep library:music`, or compile it once
/// with `dart compile exe bin/mstream_mirror.dart`. See README.md.
Future<void> main(List<String> args) async => exit(await runCli(args));
