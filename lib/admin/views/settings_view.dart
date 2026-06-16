import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Settings" — live server configuration (GET /api/v1/admin/config) plus
/// server-audio backends, SSL and the JWT secret.
class SettingsView extends StatelessWidget {
  final AdminApi api;
  const SettingsView({super.key, required this.api});

  Future<({Map<String, dynamic> config, Map<String, dynamic> audio})>
      _load() async {
    final config = await api.getConfig();
    Map<String, dynamic> audio = {};
    try {
      audio = await api.serverAudioInfo();
    } catch (_) {/* server audio may be unavailable */}
    return (config: config, audio: audio);
  }

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        final c = data.config;
        final sslOn = c['ssl']?['cert'] != null;
        return AdminViewBody(children: [
          AdminCard(
            title: 'Network',
            subtitle: 'Changing these soft-reboots the server.',
            icon: Icons.lan_outlined,
            children: [
              AdminSaveField(
                label: 'Bind address',
                initialValue: '${c['address'] ?? '0.0.0.0'}',
                onSave: api.setAddress,
              ),
              AdminSaveField(
                label: 'Port',
                number: true,
                initialValue: '${_int(c['port'], 3000)}',
                onSave: (v) => api.setPort(_int(v, 3000)),
              ),
              AdminAsyncSwitch(
                title: 'Trust proxy headers',
                subtitle: 'Enable when behind a reverse proxy (X-Forwarded-*)',
                value: c['trustProxy'] == true,
                onChanged: api.setTrustProxy,
              ),
            ],
          ),
          AdminCard(
            title: 'Permissions',
            icon: Icons.lock_outline,
            children: [
              AdminAsyncSwitch(
                title: 'Allow uploads',
                value: c['noUpload'] != true,
                onChanged: (v) => api.setNoUpload(!v),
              ),
              AdminAsyncSwitch(
                title: 'Allow making directories',
                value: c['noMkdir'] != true,
                onChanged: (v) => api.setNoMkdir(!v),
              ),
              AdminAsyncSwitch(
                title: 'Allow modifying files',
                value: c['noFileModify'] != true,
                onChanged: (v) => api.setNoFileModify(!v),
              ),
              AdminSaveField(
                label: 'Max request size',
                helperText: 'e.g. 50MB or 512KB',
                initialValue: '${c['maxRequestSize'] ?? '50MB'}',
                onSave: api.setMaxRequestSize,
              ),
            ],
          ),
          AdminCard(
            title: 'HTTP & UI',
            icon: Icons.web,
            children: [
              AdminDropdownRow<String>(
                label: 'Response compression',
                value: ['none', 'gzip', 'brotli'].contains(c['compression'])
                    ? c['compression']
                    : 'none',
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None')),
                  DropdownMenuItem(value: 'gzip', child: Text('gzip')),
                  DropdownMenuItem(value: 'brotli', child: Text('brotli')),
                ],
                onChanged: api.setCompression,
              ),
              AdminDropdownRow<String>(
                label: 'Web UI',
                value: ['default', 'velvet', 'subsonic'].contains(c['ui'])
                    ? c['ui']
                    : 'default',
                items: const [
                  DropdownMenuItem(value: 'default', child: Text('Default')),
                  DropdownMenuItem(value: 'velvet', child: Text('Velvet')),
                  DropdownMenuItem(value: 'subsonic', child: Text('Subsonic')),
                ],
                onChanged: api.setUi,
              ),
            ],
          ),
          AdminCard(
            title: 'Database tuning',
            icon: Icons.tune,
            children: [
              AdminDropdownRow<String>(
                label: 'SQLite synchronous',
                value: c['dbSynchronous'] == 'NORMAL' ? 'NORMAL' : 'FULL',
                items: const [
                  DropdownMenuItem(value: 'FULL', child: Text('FULL (safest)')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL (faster)')),
                ],
                onChanged: api.setDbSynchronous,
              ),
              AdminSaveField(
                label: 'Cache size (MB, 1–2048)',
                number: true,
                initialValue: '${_int(c['dbCacheSizeMb'], 64)}',
                onSave: (v) => api.setDbCacheSize(_int(v, 64)),
              ),
            ],
          ),
          AdminCard(
            title: 'Logging',
            icon: Icons.article_outlined,
            children: [
              AdminAsyncSwitch(
                title: 'Write logs to disk',
                value: c['writeLogs'] == true,
                onChanged: api.setWriteLogs,
              ),
              AdminSaveField(
                label: 'Log buffer size (0–10000, 0 = disabled)',
                number: true,
                initialValue: '${_int(c['logBufferSize'], 0)}',
                onSave: (v) => api.setLogBufferSize(_int(v, 0)),
              ),
            ],
          ),
          _ServerAudioCard(
              api: api, config: c, audio: data.audio, reload: reload),
          _SslCard(api: api, sslOn: sslOn, reload: reload),
          AdminCard(
            title: 'Security',
            icon: Icons.key,
            children: [
              AdminInfoRow('JWT secret (last 4)', '…${c['secret'] ?? ''}'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AdminActionButton(
                  label: 'Regenerate secret',
                  icon: Icons.autorenew,
                  destructive: true,
                  success: 'Secret regenerated — all sessions invalidated',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Regenerate JWT secret?'),
                        content: const Text(
                            'This invalidates every existing login (including '
                            'this one). Everyone must sign in again.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Regenerate')),
                        ],
                      ),
                    );
                    if (ok == true) await api.regenerateSecret(32);
                  },
                ),
              ),
            ],
          ),
        ]);
      },
    );
  }
}

class _ServerAudioCard extends StatelessWidget {
  final AdminApi api;
  final Map<String, dynamic> config;
  final Map<String, dynamic> audio;
  final Future<void> Function() reload;
  const _ServerAudioCard(
      {required this.api,
      required this.config,
      required this.audio,
      required this.reload});

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  @override
  Widget build(BuildContext context) {
    final detected =
        [for (final p in (audio['detectedCliPlayers'] as List?) ?? const []) '$p'];
    return AdminCard(
      title: 'Server audio',
      icon: Icons.speaker,
      children: [
        AdminAsyncSwitch(
          title: 'Auto-boot server audio (Rust player)',
          value: config['autoBootServerAudio'] == true,
          onChanged: api.setAutoBootServerAudio,
        ),
        AdminSaveField(
          label: 'Rust player port',
          number: true,
          initialValue: '${_int(config['rustPlayerPort'], 3055)}',
          onSave: (v) => api.setRustPlayerPort(_int(v, 3055)),
        ),
        const Divider(height: 16),
        AdminInfoRow('Active backend', '${audio['backend'] ?? '—'}'),
        AdminInfoRow('Player', '${audio['player'] ?? '—'}'),
        AdminInfoRow(
            'Detected CLI players', detected.isEmpty ? 'none' : detected.join(', ')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminActionButton(
            label: 'Re-detect players',
            icon: Icons.search,
            tonal: true,
            success: 'Re-probed CLI players',
            onPressed: () async {
              await api.detectServerAudio();
              await reload();
            },
          ),
        ),
      ],
    );
  }
}

class _SslCard extends StatelessWidget {
  final AdminApi api;
  final bool sslOn;
  final Future<void> Function() reload;
  const _SslCard(
      {required this.api, required this.sslOn, required this.reload});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: 'SSL / HTTPS',
      icon: Icons.https,
      trailing: [
        StatusPill(
          label: sslOn ? 'Enabled' : 'Disabled',
          color: sslOn ? Colors.green : Colors.grey,
        ),
      ],
      children: [
        Wrap(spacing: 8, children: [
          AdminActionButton(
            label: sslOn ? 'Replace certificate' : 'Set certificate',
            icon: Icons.upload_file,
            tonal: true,
            onPressed: () async {
              final certCtrl = TextEditingController();
              final keyCtrl = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Set SSL certificate'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: certCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Certificate path')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: keyCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Key path')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await runAdminAction(
                    context,
                    () => api.setSsl(certCtrl.text.trim(), keyCtrl.text.trim()),
                    success: 'SSL configured — reboot to apply');
                await reload();
              }
              certCtrl.dispose();
              keyCtrl.dispose();
            },
          ),
          if (sslOn)
            AdminActionButton(
              label: 'Remove SSL',
              destructive: true,
              success: 'SSL removed',
              onPressed: () async {
                await api.removeSsl();
                await reload();
              },
            ),
        ]),
      ],
    );
  }
}
