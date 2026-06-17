import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Torrent" — optional torrent-client integration (Transmission / qBittorrent
/// / Deluge): client selection, per-client connection, the live torrent list,
/// per-library daemon path mapping, and path templates.
class TorrentView extends StatelessWidget {
  final AdminApi api;
  const TorrentView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.getTorrent,
      builder: (context, t, reload) {
        final l = AppLocalizations.of(context);
        final client = t['client'] ?? 'disabled';
        return AdminViewBody(children: [
          AdminCard(
            title: l.adminTorrentClient,
            icon: Icons.download_outlined,
            children: [
              AdminDropdownRow<String>(
                label: l.adminActiveClient,
                value: ['disabled', 'transmission', 'qbittorrent', 'deluge']
                        .contains(client)
                    ? client
                    : 'disabled',
                items: [
                  DropdownMenuItem(
                      value: 'disabled', child: Text(l.adminDisabled)),
                  DropdownMenuItem(
                      value: 'transmission', child: Text(l.adminTransmission)),
                  DropdownMenuItem(
                      value: 'qbittorrent', child: Text(l.adminQbittorrent)),
                  DropdownMenuItem(value: 'deluge', child: Text(l.adminDeluge)),
                ],
                onChanged: (v) async {
                  await api.setTorrentClient(v);
                  await reload();
                },
              ),
              AdminDropdownRow<String>(
                label: l.adminEnabledFor,
                value: t['enabledFor'] == 'whitelist' ? 'whitelist' : 'all',
                items: [
                  DropdownMenuItem(value: 'all', child: Text(l.adminAllUsers)),
                  DropdownMenuItem(
                      value: 'whitelist',
                      child: Text(l.adminWhitelistedUsers)),
                ],
                onChanged: api.setTorrentEnabledFor,
              ),
            ],
          ),
          _ConnectionCard(
            api: api,
            client: 'transmission',
            title: l.adminTransmission,
            creds: Map<String, dynamic>.from(t['transmission'] ?? {}),
            hasUsername: true,
            hasRpcPath: true,
            reload: reload,
          ),
          _ConnectionCard(
            api: api,
            client: 'qbittorrent',
            title: l.adminQbittorrent,
            creds: Map<String, dynamic>.from(t['qbittorrent'] ?? {}),
            hasUsername: true,
            hasRpcPath: false,
            reload: reload,
          ),
          _ConnectionCard(
            api: api,
            client: 'deluge',
            title: l.adminDeluge,
            creds: Map<String, dynamic>.from(t['deluge'] ?? {}),
            hasUsername: false,
            hasRpcPath: false,
            reload: reload,
          ),
          if (client != 'disabled') ...[
            _TorrentListCard(api: api),
            _VpathAccessCard(api: api),
            _PathTemplatesCard(api: api),
          ],
        ]);
      },
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  final AdminApi api;
  final String client;
  final String title;
  final Map<String, dynamic> creds;
  final bool hasUsername;
  final bool hasRpcPath;
  final Future<void> Function() reload;
  const _ConnectionCard({
    required this.api,
    required this.client,
    required this.title,
    required this.creds,
    required this.hasUsername,
    required this.hasRpcPath,
    required this.reload,
  });

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  late final _host = TextEditingController(text: '${widget.creds['host'] ?? ''}');
  late final _port =
      TextEditingController(text: '${widget.creds['port'] ?? ''}');
  late final _user =
      TextEditingController(text: '${widget.creds['username'] ?? ''}');
  final _pass = TextEditingController();
  late final _rpcPath = TextEditingController(
      text: '${widget.creds['rpcPath'] ?? '/transmission/rpc'}');
  late bool _useHttps = widget.creds['useHttps'] == true;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _rpcPath.dispose();
    super.dispose();
  }

  Map<String, dynamic> _body() => {
        'host': _host.text.trim(),
        if (_port.text.trim().isNotEmpty) 'port': int.tryParse(_port.text.trim()),
        if (widget.hasUsername) 'username': _user.text.trim(),
        'password': _pass.text,
        if (widget.hasRpcPath) 'rpcPath': _rpcPath.text.trim(),
        'useHttps': _useHttps,
      }..removeWhere((_, v) => v == null);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final configured = widget.creds['configured'] == true;
    return AdminCard(
      title: widget.title,
      icon: Icons.dns_outlined,
      trailing: [
        StatusPill(
          label: configured ? l.adminConfigured : l.adminNotConfigured,
          color: configured ? Colors.green : Colors.grey,
        ),
      ],
      children: [
        TextField(
            controller: _host,
            decoration: InputDecoration(labelText: l.adminHost)),
        const SizedBox(height: 8),
        TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.adminPort)),
        if (widget.hasUsername) ...[
          const SizedBox(height: 8),
          TextField(
              controller: _user,
              decoration: InputDecoration(labelText: l.adminUsername)),
        ],
        const SizedBox(height: 8),
        TextField(
            controller: _pass,
            obscureText: true,
            decoration: InputDecoration(
                labelText: l.adminPassword,
                hintText: l.adminPasswordUnchangedIfBlank)),
        if (widget.hasRpcPath) ...[
          const SizedBox(height: 8),
          TextField(
              controller: _rpcPath,
              decoration: InputDecoration(labelText: l.adminRpcPath)),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.adminUseHttps),
          value: _useHttps,
          onChanged: (v) => setState(() => _useHttps = v),
        ),
        Wrap(spacing: 8, children: [
          AdminActionButton(
            label: l.adminTest,
            tonal: true,
            onPressed: () async {
              final r = await widget.api.torrentTest(widget.client, _body());
              if (!context.mounted) return;
              final ok = r['ok'] == true;
              adminToast(
                  context,
                  ok
                      ? l.adminReachable(
                          r['version'] != null ? ' (${r['version']})' : '')
                      : l.adminConnectionFailed(
                          '${r['message'] ?? r['error'] ?? 'unknown'}'),
                  error: !ok);
            },
          ),
          AdminActionButton(
            label: l.adminConnectAndSave,
            onPressed: () async {
              final r = await widget.api.torrentConnect(widget.client, _body());
              if (r['ok'] != true) {
                if (context.mounted) {
                  adminToast(context,
                      l.adminSaveFailed(
                          '${r['message'] ?? r['error'] ?? 'unknown'}'),
                      error: true);
                }
                return;
              }
              if (context.mounted) {
                adminToast(context, l.adminConnectedAndSaved);
              }
              await widget.reload();
            },
          ),
          if (configured)
            AdminActionButton(
              label: l.adminDisconnect,
              destructive: true,
              success: l.adminDisconnected,
              onPressed: () async {
                await widget.api.torrentDisconnect(widget.client);
                await widget.reload();
              },
            ),
        ]),
      ],
    );
  }
}

class _TorrentListCard extends StatefulWidget {
  final AdminApi api;
  const _TorrentListCard({required this.api});

  @override
  State<_TorrentListCard> createState() => _TorrentListCardState();
}

class _TorrentListCardState extends State<_TorrentListCard> {
  Map<String, dynamic> _status = {};
  List<dynamic> _torrents = [];
  String? _error;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = AdminViewActive.of(context);
    if (active && _timer == null) {
      _poll();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    } else if (!active && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final (status, list) =
          await (widget.api.torrentStatus(), widget.api.torrentList()).wait;
      if (!mounted) return;
      setState(() {
        _status = status;
        _torrents = (list['torrents'] as List?) ?? const [];
        _error = list['error']?.toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final connected = _status['connected'] == true;
    return AdminCard(
      title: l.adminTorrents,
      icon: Icons.swap_vert,
      trailing: [
        StatusPill(
          label: connected ? l.adminConnected : l.adminDisconnected,
          color: connected ? Colors.green : Colors.orange,
          icon: connected ? Icons.link : Icons.link_off,
        ),
      ],
      children: [
        if (_error != null && _torrents.isEmpty)
          Text(_error!, style: TextStyle(color: scheme.onSurfaceVariant))
        else if (_torrents.isEmpty)
          Text(l.adminNoTorrents,
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final t in _torrents) _torrentRow(context, t),
      ],
    );
  }

  Widget _torrentRow(BuildContext context, dynamic t) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final progress =
        (t['progress'] is num) ? (t['progress'] as num).toDouble() : 0.0;
    final managed = t['managedByMstream'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${t['name'] ?? t['infoHash']}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (managed)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: StatusPill(label: l.adminMstream, color: Colors.blue),
            ),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          if (managed)
            IconButton(
              tooltip: l.adminRemove,
              iconSize: 18,
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: () async {
                await runAdminAction(
                    context, () => widget.api.removeTorrent('${t['infoHash']}'),
                    success: l.adminTorrentRemoved);
                await _poll();
              },
            ),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress.clamp(0, 1)),
        const SizedBox(height: 2),
        Text(
          '${t['status'] ?? ''} · ↓${t['downloadRate'] ?? 0} ↑${t['uploadRate'] ?? 0}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
      ]),
    );
  }
}

class _VpathAccessCard extends StatelessWidget {
  final AdminApi api;
  const _VpathAccessCard({required this.api});

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.torrentVpathAccess,
      builder: (context, data, reload) {
        final l = AppLocalizations.of(context);
        final vpaths = (data['vpaths'] as Map?) ?? const {};
        return AdminCard(
          title: l.adminLibraryDaemonPathMapping,
          subtitle: l.adminLibraryDaemonPathMappingSubtitle,
          icon: Icons.alt_route,
          trailing: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
          children: [
            if (data['error'] != null)
              Text('${data['error']}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            for (final entry in vpaths.entries)
              _mappingRow(context, entry.key, Map.from(entry.value), reload),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AdminActionButton(
                label: l.adminAutoDetectAll,
                icon: Icons.auto_fix_high,
                tonal: true,
                success: l.adminAutoDetectionComplete,
                onPressed: () async {
                  await api.torrentVpathAutoDetect();
                  await reload();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mappingRow(BuildContext context, String name, Map info,
      Future<void> Function() reload) {
    final l = AppLocalizations.of(context);
    final verified = info['verified'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(name),
      subtitle: Text('${info['daemonPath'] ?? AppLocalizations.of(context).adminNotMapped}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        StatusPill(
          label: verified ? l.adminVerified : l.adminUnverified,
          color: verified ? Colors.green : Colors.orange,
        ),
        IconButton(
          tooltip: l.adminSetManually,
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () async {
            final ctrl =
                TextEditingController(text: '${info['daemonPath'] ?? ''}');
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.adminDaemonPathFor(name)),
                content: TextField(
                  controller: ctrl,
                  decoration:
                      InputDecoration(labelText: l.adminPathOnDaemonHost),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.adminCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l.adminVerifyAndSave)),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              final r =
                  await api.torrentVpathManual(name, ctrl.text.trim());
              if (context.mounted) {
                adminToast(
                    context,
                    r['verified'] == true
                        ? l.adminVpathVerified
                        : l.adminVpathSavedUnverified);
              }
              await reload();
            }
            ctrl.dispose();
          },
        ),
      ]),
    );
  }
}

class _PathTemplatesCard extends StatelessWidget {
  final AdminApi api;
  const _PathTemplatesCard({required this.api});

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.torrentPathTemplates,
      builder: (context, data, reload) {
        final l = AppLocalizations.of(context);
        final vpaths = (data['vpaths'] as Map?) ?? const {};
        final vars = [
          for (final v in (data['supportedVars'] as List?) ?? const []) '$v'
        ];
        return AdminCard(
          title: l.adminDownloadPathTemplates,
          subtitle:
              vars.isEmpty ? null : l.adminPathTemplateVars(vars.join(', ')),
          icon: Icons.account_tree,
          children: [
            if (vpaths.isEmpty)
              Text(l.adminNoLibraries,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            for (final entry in vpaths.entries)
              AdminSaveField(
                label: '${entry.key}',
                helperText: data['suggestedTemplate'] != null
                    ? l.adminSuggestedTemplate('${data['suggestedTemplate']}')
                    : null,
                initialValue: '${(entry.value as Map?)?['template'] ?? ''}',
                savedMessage: l.adminTemplateSaved,
                onSave: (v) async {
                  await api.setTorrentPathTemplate(
                      entry.key, v.isEmpty ? null : v);
                },
              ),
          ],
        );
      },
    );
  }
}
