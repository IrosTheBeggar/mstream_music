import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Settings" — live server configuration (GET /api/v1/admin/config) plus
/// server-audio backends, SSL and the JWT secret.
class SettingsView extends StatelessWidget {
  final AdminApi api;
  const SettingsView({super.key, required this.api});

  Future<({Map<String, dynamic> config, Map<String, dynamic> audio})>
      _load() async {
    // Both run concurrently; server audio may be unavailable, so tolerate its
    // failure (→ empty map) without blocking the rest of the page.
    final (config, audio) = await (
      api.getConfig(),
      api.serverAudioInfo().catchError((_) => <String, dynamic>{}),
    ).wait;
    return (config: config, audio: audio);
  }

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        final l = AppLocalizations.of(context);
        final c = data.config;
        final sslOn = c['ssl']?['cert'] != null;
        return AdminViewBody(children: [
          AdminCard(
            title: l.adminNetwork,
            subtitle: l.adminNetworkSubtitle,
            icon: Icons.lan_outlined,
            children: [
              AdminSaveField(
                label: l.adminBindAddress,
                initialValue: '${c['address'] ?? '0.0.0.0'}',
                onSave: api.setAddress,
              ),
              AdminSaveField(
                label: l.adminPort,
                number: true,
                initialValue: '${_int(c['port'], 3000)}',
                onSave: (v) => api.setPort(_int(v, 3000)),
              ),
              AdminAsyncSwitch(
                title: l.adminTrustProxyHeaders,
                subtitle: l.adminTrustProxyHeadersSubtitle,
                value: c['trustProxy'] == true,
                onChanged: api.setTrustProxy,
              ),
            ],
          ),
          AdminCard(
            title: l.adminPermissions,
            icon: Icons.lock_outline,
            children: [
              AdminAsyncSwitch(
                title: l.adminAllowUploads,
                value: c['noUpload'] != true,
                onChanged: (v) => api.setNoUpload(!v),
              ),
              AdminAsyncSwitch(
                title: l.adminAllowMakingDirectories,
                value: c['noMkdir'] != true,
                onChanged: (v) => api.setNoMkdir(!v),
              ),
              AdminAsyncSwitch(
                title: l.adminAllowModifyingFiles,
                value: c['noFileModify'] != true,
                onChanged: (v) => api.setNoFileModify(!v),
              ),
              AdminSaveField(
                label: l.adminMaxRequestSize,
                helperText: l.adminMaxRequestSizeHelper,
                initialValue: '${c['maxRequestSize'] ?? '50MB'}',
                onSave: api.setMaxRequestSize,
              ),
            ],
          ),
          AdminCard(
            title: l.adminHttpUi,
            icon: Icons.web,
            children: [
              AdminDropdownRow<String>(
                label: l.adminResponseCompression,
                value: ['none', 'gzip', 'brotli'].contains(c['compression'])
                    ? c['compression']
                    : 'none',
                items: [
                  DropdownMenuItem(
                      value: 'none', child: Text(l.adminCompressionNone)),
                  DropdownMenuItem(
                      value: 'gzip', child: Text(l.adminCompressionGzip)),
                  DropdownMenuItem(
                      value: 'brotli', child: Text(l.adminCompressionBrotli)),
                ],
                onChanged: api.setCompression,
              ),
              AdminDropdownRow<String>(
                label: l.adminWebUi,
                value: ['default', 'velvet', 'subsonic'].contains(c['ui'])
                    ? c['ui']
                    : 'default',
                items: [
                  DropdownMenuItem(
                      value: 'default', child: Text(l.adminUiDefault)),
                  DropdownMenuItem(
                      value: 'velvet', child: Text(l.adminUiVelvet)),
                  DropdownMenuItem(
                      value: 'subsonic', child: Text(l.adminUiSubsonic)),
                ],
                onChanged: api.setUi,
              ),
            ],
          ),
          AdminCard(
            title: l.adminDatabaseTuning,
            icon: Icons.tune,
            children: [
              AdminDropdownRow<String>(
                label: l.adminSqliteSynchronous,
                value: c['dbSynchronous'] == 'NORMAL' ? 'NORMAL' : 'FULL',
                items: [
                  DropdownMenuItem(value: 'FULL', child: Text(l.adminSyncFull)),
                  DropdownMenuItem(
                      value: 'NORMAL', child: Text(l.adminSyncNormal)),
                ],
                onChanged: api.setDbSynchronous,
              ),
              AdminSaveField(
                label: l.adminCacheSize,
                number: true,
                initialValue: '${_int(c['dbCacheSizeMb'], 64)}',
                onSave: (v) => api.setDbCacheSize(_int(v, 64)),
              ),
            ],
          ),
          AdminCard(
            title: l.adminLogging,
            icon: Icons.article_outlined,
            children: [
              AdminAsyncSwitch(
                title: l.adminWriteLogsToDisk,
                value: c['writeLogs'] == true,
                onChanged: api.setWriteLogs,
              ),
              AdminSaveField(
                label: l.adminLogBufferSize,
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
            title: l.adminSecurity,
            icon: Icons.key,
            children: [
              AdminInfoRow(l.adminJwtSecretLast4, '…${c['secret'] ?? ''}'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AdminActionButton(
                  label: l.adminRegenerateSecret,
                  icon: Icons.autorenew,
                  destructive: true,
                  success: l.adminSecretRegenerated,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l.adminRegenerateJwtSecretDialog),
                        content: Text(l.adminRegenerateJwtSecretDialogBody),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l.adminCancel)),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l.adminRegenerateButton)),
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
    final l = AppLocalizations.of(context);
    final detected =
        [for (final p in (audio['detectedCliPlayers'] as List?) ?? const []) '$p'];
    return AdminCard(
      title: l.adminServerAudio,
      icon: Icons.speaker,
      children: [
        AdminAsyncSwitch(
          title: l.adminAutoBootServerAudio,
          value: config['autoBootServerAudio'] == true,
          onChanged: api.setAutoBootServerAudio,
        ),
        AdminSaveField(
          label: l.adminRustPlayerPort,
          number: true,
          initialValue: '${_int(config['rustPlayerPort'], 3055)}',
          onSave: (v) => api.setRustPlayerPort(_int(v, 3055)),
        ),
        const Divider(height: 16),
        AdminInfoRow(l.adminActiveBackend, '${audio['backend'] ?? '—'}'),
        AdminInfoRow(l.adminPlayer, '${audio['player'] ?? '—'}'),
        AdminInfoRow(l.adminDetectedCliPlayers,
            detected.isEmpty ? l.adminNone : detected.join(', ')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminActionButton(
            label: l.adminReDetectPlayers,
            icon: Icons.search,
            tonal: true,
            success: l.adminReProbedCliPlayers,
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
    final l = AppLocalizations.of(context);
    return AdminCard(
      title: l.adminSslHttps,
      icon: Icons.https,
      trailing: [
        StatusPill(
          label: sslOn ? l.adminEnabled : l.adminDisabled,
          color: sslOn ? Colors.green : Colors.grey,
        ),
      ],
      children: [
        Wrap(spacing: 8, children: [
          AdminActionButton(
            label: sslOn ? l.adminReplaceCertificate : l.adminSetCertificate,
            icon: Icons.upload_file,
            tonal: true,
            onPressed: () async {
              final certCtrl = TextEditingController();
              final keyCtrl = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l.adminSetSslCertificateDialog),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: certCtrl,
                        decoration: InputDecoration(
                            labelText: l.adminCertificatePath)),
                    const SizedBox(height: 8),
                    TextField(
                        controller: keyCtrl,
                        decoration:
                            InputDecoration(labelText: l.adminKeyPath)),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l.adminCancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l.adminSave)),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await runAdminAction(
                    context,
                    () => api.setSsl(certCtrl.text.trim(), keyCtrl.text.trim()),
                    success: l.adminSslConfigured);
                await reload();
              }
              certCtrl.dispose();
              keyCtrl.dispose();
            },
          ),
          if (sslOn)
            AdminActionButton(
              label: l.adminRemoveSsl,
              destructive: true,
              success: l.adminSslRemoved,
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
