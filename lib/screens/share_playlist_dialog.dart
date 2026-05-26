// Share Playlist dialog — mirrors the webapp's /api/v1/share flow.
//
// The webapp version is straightforward: collect the queue's filepaths,
// POST them with an optional expiry, get back a playlistId, build a
// `<server>/shared/<id>` URL, copy.
//
// The complication on mobile: the queue can contain songs from
// multiple servers OR purely-local files that don't live on any
// server. The share endpoint is per-server, so neither case can be
// expressed as a single share. We surface a clear blocker dialog
// rather than silently dropping items.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';

/// Entry point. Inspects the queue and either opens the share dialog
/// or surfaces a blocker dialog explaining why share is unavailable.
Future<void> showSharePlaylistDialog(BuildContext context) async {
  final analysis = _analyzeQueue();

  switch (analysis) {
    case _Empty():
      await _alert(context, 'Empty queue',
          'Add songs to the queue before sharing.');
      return;
    case _LocalOnly():
      await _alert(
          context,
          "Can't share this queue",
          'The queue contains songs that are only on this device (not '
              'on any server). Sharing only works when every song in '
              'the queue comes from a single server.');
      return;
    case _MultiServer(:final serverNames):
      await _alert(
          context,
          "Can't share this queue",
          'The queue mixes songs from ${serverNames.length} servers '
              '(${serverNames.join(", ")}). Sharing only works when '
              'every song comes from a single server.');
      return;
    case _ServerGone(:final serverName):
      await _alert(
          context,
          "Can't share this queue",
          'The server "$serverName" is no longer in your server list. '
              'Re-add it to share its queue.');
      return;
    case _Shareable(:final server, :final filepaths):
      await showDialog<void>(
        context: context,
        builder: (ctx) =>
            _ShareDialog(server: server, filepaths: filepaths),
      );
      return;
  }
}

// ── Queue analysis ──────────────────────────────────────────────────

sealed class _QueueAnalysis {}

class _Empty extends _QueueAnalysis {}

class _LocalOnly extends _QueueAnalysis {}

class _MultiServer extends _QueueAnalysis {
  final List<String> serverNames;
  _MultiServer(this.serverNames);
}

class _ServerGone extends _QueueAnalysis {
  final String serverName;
  _ServerGone(this.serverName);
}

class _Shareable extends _QueueAnalysis {
  final Server server;
  final List<String> filepaths;
  _Shareable(this.server, this.filepaths);
}

_QueueAnalysis _analyzeQueue() {
  final queue = MediaManager().audioHandler.queue.value;
  if (queue.isEmpty) return _Empty();

  final serverNames = <String>{};
  final filepaths = <String>[];
  for (final item in queue) {
    final serverName = item.extras?['server'] as String?;
    final filepath = item.extras?['path'] as String?;
    // localFile items (added from the on-device FileExplorer) carry
    // no server reference and aren't reachable to anyone but this
    // device — block the whole share if any are present.
    if (serverName == null || filepath == null) return _LocalOnly();
    serverNames.add(serverName);
    filepaths.add(filepath);
  }

  if (serverNames.length > 1) {
    return _MultiServer(serverNames.toList()..sort());
  }

  final wanted = serverNames.first;
  for (final s in ServerManager().serverList) {
    if (s.localname == wanted) return _Shareable(s, filepaths);
  }
  return _ServerGone(wanted);
}

Future<void> _alert(BuildContext context, String title, String body) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}

// ── The share dialog ────────────────────────────────────────────────

class _ShareDialog extends StatefulWidget {
  final Server server;
  final List<String> filepaths;
  const _ShareDialog({required this.server, required this.filepaths});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  // null = never expires (omit `time` from the POST body)
  int? _expiresDays;
  bool _busy = false;
  String? _shareUrl;
  String? _error;
  late final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _shareUrl == null ? _buildForm() : _buildResult();
  }

  Widget _buildForm() {
    return AlertDialog(
      title: Text('Share Playlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.filepaths.length} ${widget.filepaths.length == 1 ? "song" : "songs"} from ${widget.server.url}',
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            decoration: InputDecoration(labelText: 'Link expires'),
            initialValue: _expiresDays,
            items: const [
              DropdownMenuItem(value: null, child: Text('Never')),
              DropdownMenuItem(value: 1, child: Text('After 1 day')),
              DropdownMenuItem(value: 7, child: Text('After 7 days')),
              DropdownMenuItem(value: 30, child: Text('After 30 days')),
            ],
            onChanged: (v) => setState(() => _expiresDays = v),
          ),
          if (_error != null) ...[
            SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: VelvetColors.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _doShare,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Share'),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return AlertDialog(
      title: Text('Playlist shared'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Anyone with this link can play the queue:',
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _urlController,
            readOnly: true,
            maxLines: 2,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _shareUrl!));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied to clipboard')),
              );
            }
          },
          child: Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done'),
        ),
      ],
    );
  }

  Future<void> _doShare() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ApiManager().sharePlaylist(
        server: widget.server,
        filepaths: widget.filepaths,
        expiresInDays: _expiresDays,
      );
      final playlistId = res['playlistId'];
      if (playlistId is! String) {
        throw Exception('Server response missing playlistId');
      }
      final url = '${widget.server.url}/shared/$playlistId';
      _urlController.text = url;
      setState(() {
        _shareUrl = url;
        _busy = false;
      });
    } catch (err) {
      setState(() {
        _error = '$err';
        _busy = false;
      });
    }
  }
}
