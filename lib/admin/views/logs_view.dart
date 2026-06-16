import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Logs" — tails the server's in-memory ring buffer
/// (`GET /api/v1/admin/logs/recent?since=`) and offers a logs.zip download.
class LogsView extends StatefulWidget {
  final AdminApi api;
  const LogsView({super.key, required this.api});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  static const _maxEntries = 1000;
  static const _pollInterval = Duration(seconds: 2);

  final List<Map<String, dynamic>> _entries = [];
  final ScrollController _scroll = ScrollController();
  int _lastSeq = 0;
  bool _paused = false;
  bool _autoscroll = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(_pollInterval, (_) {
      if (!_paused) _poll();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final res = await widget.api.recentLogs(since: _lastSeq);
      final entries = (res['entries'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _error = null;
        for (final e in entries) {
          _entries.add(Map<String, dynamic>.from(e));
        }
        if (_entries.length > _maxEntries) {
          _entries.removeRange(0, _entries.length - _maxEntries);
        }
        if (res['lastSeq'] is num) _lastSeq = (res['lastSeq'] as num).toInt();
      });
      if (_autoscroll && entries.isNotEmpty && _scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Color _levelColor(String level, ColorScheme scheme) {
    switch (level.toLowerCase()) {
      case 'error':
        return scheme.error;
      case 'warn':
      case 'warning':
        return Colors.orange;
      case 'debug':
      case 'verbose':
      case 'silly':
        return scheme.onSurfaceVariant;
      default:
        return scheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Material(
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            IconButton(
              tooltip: _paused ? l.adminLogsResumeButton : l.adminLogsPauseButton,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              onPressed: () => setState(() => _paused = !_paused),
            ),
            IconButton(
              tooltip: l.adminClear,
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(_entries.clear),
            ),
            Row(children: [
              Checkbox(
                value: _autoscroll,
                onChanged: (v) => setState(() => _autoscroll = v ?? true),
              ),
              Text(l.adminLogsAutoScrollTitle),
            ]),
            const Spacer(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(_error!,
                    style: TextStyle(color: scheme.error, fontSize: 12)),
              ),
            Text(l.adminLogsLineCount(_entries.length),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.download, size: 18),
              label: Text(l.adminLogsDownloadZipButton),
              onPressed: () async {
                final uri = widget.api.logsDownloadUrl();
                if (!await launchUrl(uri,
                    mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    adminToast(context, l.couldNotOpen('$uri'), error: true);
                  }
                }
              },
            ),
          ]),
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: Container(
          color: scheme.surface,
          child: _entries.isEmpty
              ? Center(
                  child: Text(l.adminLogsNoEntriesHint,
                      style: TextStyle(color: scheme.onSurfaceVariant)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    final level = '${e['level'] ?? 'info'}';
                    final t = '${e['t'] ?? ''}';
                    final shortTime = t.length >= 19 ? t.substring(11, 19) : t;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText.rich(
                        TextSpan(
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                          children: [
                            TextSpan(
                                text: '$shortTime ',
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                            TextSpan(
                                text: '${level.toUpperCase().padRight(5)} ',
                                style: TextStyle(
                                    color: _levelColor(level, scheme),
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: '${e['message'] ?? ''}',
                                style: TextStyle(color: scheme.onSurface)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}
