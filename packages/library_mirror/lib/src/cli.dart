import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'http_transport.dart';
import 'index_db.dart';
import 'models.dart';
import 'runner.dart';

/// Exit codes, after the server's own backup worker: 0 ok, 1 fatal (bad
/// arguments, no sign-in, server unreachable), 2 = the run completed but
/// some files failed (they are retried next run).
abstract final class CliExit {
  static const int ok = 0;
  static const int fatal = 1;
  static const int partial = 2;
}

ArgParser buildParser() => ArgParser()
  ..addOption('server', abbr: 's', help: 'Server URL, e.g. http://nas:3000')
  ..addOption('dest',
      abbr: 'd', help: 'Folder that holds the copy (media/<name>/ underneath)')
  ..addOption('name',
      abbr: 'n', help: 'Local name of the server (default: its host)')
  ..addOption('token',
      abbr: 't', help: 'Token from a previous sign-in (public mode: omit)')
  ..addOption('user', abbr: 'u', help: 'Sign in as this user (with --password)')
  ..addOption('password')
  ..addOption('index', help: 'Index database (default: <dest>/.mstream-index.db)')
  ..addMultiOption('keep',
      abbr: 'k',
      splitCommas: false,
      help: 'Add a rule, kind:key — library:music, folder:/music/Live, '
          'album:Name, artist:Name, playlist:Name, rated:8 (0–10)')
  ..addMultiOption('drop',
      splitCommas: false, help: 'Remove a rule, kind:key')
  ..addFlag('list-rules', negatable: false, help: 'Print the rules and exit')
  ..addOption('retention-days',
      defaultsTo: '30', help: 'Days a trashed file is kept (0 = forever)')
  ..addOption('concurrency', defaultsTo: '3')
  ..addOption('page-size', defaultsTo: '2000')
  ..addFlag('quiet', abbr: 'q', negatable: false, help: 'Only the summary')
  ..addFlag('help', abbr: 'h', negatable: false);

const Set<String> _kinds = {
  RuleKind.library,
  RuleKind.folder,
  RuleKind.album,
  RuleKind.artist,
  RuleKind.playlist,
  RuleKind.rated,
};

/// A `kind:key` rule spec.
({String kind, String key}) parseRule(String spec) {
  final i = spec.indexOf(':');
  if (i <= 0 || i == spec.length - 1) {
    throw FormatException('a rule is kind:key, not "$spec"');
  }
  final kind = spec.substring(0, i).trim();
  if (!_kinds.contains(kind)) {
    throw FormatException('unknown rule kind "$kind" (${_kinds.join(', ')})');
  }
  return (kind: kind, key: spec.substring(i + 1).trim());
}

/// One line for a finished run, in the app's own words.
String summarize(SyncRun run) => run.error != null
    ? 'failed: ${run.error}'
    : 'ok — ${run.downloaded} new, ${run.replaced} replaced, '
        '${run.renamed} renamed, ${run.trashed} trashed, '
        '${run.failed} failed, ${run.unchanged} unchanged';

/// Runs the headless mirror once and returns the exit code. Rules live in
/// the index next to the copy, so `--keep` is needed once; every later
/// invocation is just `--server … --dest …`. [client], [out] and [err] are
/// for tests.
Future<int> runCli(List<String> args,
    {http.Client? client, StringSink? out, StringSink? err}) async {
  final o = out ?? stdout;
  final e = err ?? stderr;
  final parser = buildParser();
  final ArgResults r;
  try {
    r = parser.parse(args);
  } on FormatException catch (x) {
    e.writeln(x.message);
    e.writeln(parser.usage);
    return CliExit.fatal;
  }
  if (r['help'] as bool) {
    o.writeln('mstream_mirror — keep a folder in sync with an mStream server');
    o.writeln(parser.usage);
    return CliExit.ok;
  }
  final base = r['server'] as String?;
  final dest = r['dest'] as String?;
  if (base == null || dest == null) {
    e.writeln('--server and --dest are required');
    e.writeln(parser.usage);
    return CliExit.fatal;
  }
  final name = (r['name'] as String?) ?? (Uri.tryParse(base)?.host ?? 'server');
  final indexPath = (r['index'] as String?) ?? p.join(dest, '.mstream-index.db');
  final quiet = r['quiet'] as bool;

  final c = client ?? http.Client();
  final LibraryIndex index;
  try {
    await Directory(dest).create(recursive: true);
    index = LibraryIndex.open(indexPath);
  } catch (x) {
    e.writeln('cannot open the index at $indexPath: $x');
    if (client == null) c.close();
    return CliExit.fatal;
  }
  try {
    for (final spec in r['keep'] as List<String>) {
      final rule = parseRule(spec);
      index.addSubscription(
          Subscription(server: name, kind: rule.kind, key: rule.key));
    }
    for (final spec in r['drop'] as List<String>) {
      final rule = parseRule(spec);
      for (final s in index.subscriptionsFor(name)) {
        if (s.kind == rule.kind && s.key == rule.key && s.id != null) {
          index.removeSubscription(s.id!);
        }
      }
    }
    final rules = index.subscriptionsFor(name);
    if (r['list-rules'] as bool) {
      for (final s in rules) {
        o.writeln('${s.kind}:${s.key}${s.enabled ? '' : ' (disabled)'}');
      }
      return CliExit.ok;
    }
    if (rules.isEmpty && !quiet) {
      o.writeln('no rules yet: this run refreshes the index only '
          '(add one with --keep kind:key)');
    }

    final user = r['user'] as String?;
    final server = user != null
        ? await MirrorServer.login(base, user, (r['password'] as String?) ?? '',
            client: c)
        : MirrorServer(base, token: r['token'] as String?);

    final cfg = MirrorConfig.under(dest, name,
        artRoot: p.join(dest, 'art', name),
        retentionDays: int.parse(r['retention-days'] as String),
        concurrency: int.parse(r['concurrency'] as String),
        pageSize: int.parse(r['page-size'] as String));
    final runner = MirrorRunner(
      index: index,
      manifest: HttpManifestClient(server, c),
      downloader: HttpDownloader(server, c),
      lists: HttpListsClient(server, c),
      art: HttpArtClient(server, c),
    );
    if (!quiet) o.writeln('checking $base …');
    final run = await runner.run(cfg, trigger: 'cli', onProgress: (pr) {
      if (quiet || pr.phase != 'transfer' || pr.total == 0) return;
      o.writeln('  ${pr.done}/${pr.total}'
          '${pr.failed > 0 ? ' (${pr.failed} failed)' : ''}');
    });
    o.writeln(summarize(run));
    if (run.error != null) return CliExit.fatal;
    return run.failed > 0 ? CliExit.partial : CliExit.ok;
  } on FormatException catch (x) {
    e.writeln(x.message);
    return CliExit.fatal;
  } on Exception catch (x) {
    e.writeln('$x');
    return CliExit.fatal;
  } finally {
    index.close();
    if (client == null) c.close();
  }
}
