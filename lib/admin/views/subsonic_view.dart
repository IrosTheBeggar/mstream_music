import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Subsonic API" — the bundled Subsonic-compatible endpoint: mode, live stats,
/// jukebox status, token-auth diagnostics, lyrics cache and API-key minting.
class SubsonicView extends StatelessWidget {
  final AdminApi api;
  const SubsonicView({super.key, required this.api});

  static const _modeTokens = ['disabled', 'same-port', 'separate-port'];

  static String _modeLabel(AppLocalizations l, String token) {
    switch (token) {
      case 'same-port':
        return l.adminSamePortAsHttp;
      case 'separate-port':
        return l.adminSeparatePort;
      default:
        return l.adminDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminAsync(
      loader: api.getSubsonic,
      builder: (context, s, reload) {
        final mode = _modeTokens.contains(s['mode']) ? s['mode'] : 'disabled';
        final port = (s['port'] is num) ? (s['port'] as num).toInt() : 4040;
        return AdminViewBody(children: [
          AdminCard(
            title: l.adminSubsonicApiTitle,
            icon: Icons.play_circle_outline,
            children: [
              AdminDropdownRow<String>(
                label: l.adminMode,
                value: mode,
                items: [
                  for (final t in _modeTokens)
                    DropdownMenuItem(value: t, child: Text(_modeLabel(l, t))),
                ],
                onChanged: (v) async {
                  await api.setSubsonicMode(v,
                      port: v == 'separate-port' ? port : null);
                  await reload();
                },
              ),
              if (mode == 'separate-port')
                AdminSaveField(
                  label: l.adminPort,
                  number: true,
                  initialValue: '$port',
                  onSave: (v) => api.setSubsonicMode('separate-port',
                      port: int.tryParse(v) ?? port),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AdminActionButton(
                  label: l.adminTestConnection,
                  icon: Icons.network_check,
                  tonal: true,
                  onPressed: () async {
                    final r = await api.subsonicTest();
                    if (!context.mounted) return;
                    final ok = r['ok'] == true;
                    adminToast(
                      context,
                      ok
                          ? l.adminSubsonicTestSuccess(
                              '${r['version'] ?? ''}', '${r['latencyMs'] ?? '?'}')
                          : l.adminSubsonicTestFailed('${r['reason'] ?? 'unknown'}'),
                      error: !ok,
                    );
                  },
                ),
              ),
            ],
          ),
          _StatsCard(api: api),
          _JukeboxCard(api: api),
          _TokenAuthCard(api: api),
          _MintKeyCard(api: api),
        ]);
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  final AdminApi api;
  const _StatsCard({required this.api});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminAsync(
      loader: api.subsonicStats,
      builder: (context, stats, reload) {
        final lyrics = (stats['lyrics'] as Map?) ?? const {};
        final cache = (lyrics['cache'] as Map?) ?? const {};
        final nowPlaying = (stats['nowPlaying'] as List?) ?? const [];
        return AdminCard(
          title: l.adminStatus,
          icon: Icons.insights,
          trailing: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
          children: [
            AdminInfoRow(l.adminMethodsImplemented, '${stats['methodsImplemented'] ?? 0}'),
            AdminInfoRow(l.adminFullStub,
                '${stats['fullCount'] ?? 0} full · ${stats['stubCount'] ?? 0} stub'),
            const Divider(height: 16),
            Text(l.adminNowPlaying,
                style: Theme.of(context).textTheme.bodyMedium),
            if (nowPlaying.isEmpty)
              Text(l.adminNobody,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              for (final np in nowPlaying)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, size: 18),
                  title: Text('${np['username']}'),
                  subtitle: Text(
                      '${np['artist'] ?? ''} — ${np['title'] ?? np['trackId']}'),
                ),
            const Divider(height: 16),
            Text(l.adminLyricsLrclib,
                style: Theme.of(context).textTheme.bodyMedium),
            AdminAsyncSwitch(
              title: l.adminLrclibFallback,
              value: lyrics['lrclibEnabled'] == true,
              onChanged: (v) async {
                await api.setLyricsCacheEnabled(v);
              },
            ),
            AdminAsyncSwitch(
              title: l.adminWriteLrcSidecarFiles,
              value: lyrics['writeSidecarEnabled'] == true,
              onChanged: (v) async {
                await api.setLyricsWriteSidecar(v);
              },
            ),
            if (cache.isNotEmpty)
              AdminInfoRow(l.adminCache,
                  cache.entries.map((e) => '${e.key}: ${e.value}').join(' · ')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              AdminActionButton(
                label: l.adminPurgeCache,
                tonal: true,
                success: l.adminLyricsCachePurged,
                onPressed: () async {
                  await api.purgeLyricsCache(mode: 'full');
                  await reload();
                },
              ),
              AdminActionButton(
                label: l.adminRetryFailed,
                tonal: true,
                success: l.adminTransientLyricsEntriesCleared,
                onPressed: () async {
                  await api.purgeLyricsCache(mode: 'retry');
                  await reload();
                },
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _JukeboxCard extends StatelessWidget {
  final AdminApi api;
  const _JukeboxCard({required this.api});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminAsync(
      loader: api.subsonicJukebox,
      builder: (context, j, reload) {
        final available = j['available'] == true;
        return AdminCard(
          title: l.adminJukebox,
          icon: Icons.queue_music,
          trailing: [
            StatusPill(
              label: available ? l.adminAvailable : l.adminUnavailable,
              color: available ? Colors.green : Colors.grey,
            ),
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
          children: [
            if (!available)
              Text('${j['reason'] ?? l.adminNotAvailable}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
            else ...[
              AdminInfoRow(l.adminState,
                  j['playing'] == true ? l.adminPlaying : (j['paused'] == true ? l.adminPaused : l.adminIdle)),
              AdminInfoRow(l.adminCurrent, '${j['currentFile'] ?? '—'}'),
              AdminInfoRow(l.adminQueue,
                  l.adminQueueTracks((j['queueLength'] is num ? (j['queueLength'] as num).toInt() : 0))),
              AdminInfoRow(l.adminVolume,
                  l.adminVolumePercent(((j['volume'] is num ? j['volume'] : 1.0) * 100).round())),
            ],
          ],
        );
      },
    );
  }
}

class _TokenAuthCard extends StatelessWidget {
  final AdminApi api;
  const _TokenAuthCard({required this.api});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminAsync(
      loader: api.subsonicTokenAuthAttempts,
      builder: (context, attempts, reload) {
        return AdminCard(
          title: l.adminTokenAuthFailures,
          subtitle: l.adminTokenAuthFailuresSubtitle,
          icon: Icons.warning_amber,
          trailing: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
          children: [
            if (attempts.isEmpty)
              Text(l.adminNoRecentFailures,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              for (final a in attempts)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key_off, size: 18),
                  title: Text('${a['username'] ?? a['user'] ?? 'unknown'}'),
                  subtitle: Text(a.toString()),
                ),
            if (attempts.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: AdminActionButton(
                  label: l.adminClear,
                  tonal: true,
                  success: l.adminCleared,
                  onPressed: () async {
                    await api.clearSubsonicTokenAuthAttempts();
                    await reload();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MintKeyCard extends StatefulWidget {
  final AdminApi api;
  const _MintKeyCard({required this.api});

  @override
  State<_MintKeyCard> createState() => _MintKeyCardState();
}

class _MintKeyCardState extends State<_MintKeyCard> {
  final _user = TextEditingController();
  final _name = TextEditingController();
  String? _key;

  @override
  void dispose() {
    _user.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminCard(
      title: l.adminMintApiKey,
      subtitle: l.adminMintApiKeySubtitle,
      icon: Icons.vpn_key,
      children: [
        TextField(
            controller: _user,
            decoration: InputDecoration(labelText: l.adminUsername)),
        const SizedBox(height: 8),
        TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l.adminKeyNameLabel)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminActionButton(
            label: l.adminMintKey,
            icon: Icons.add,
            onPressed: () async {
              if (_user.text.trim().isEmpty || _name.text.trim().isEmpty) {
                adminToast(context, l.adminUsernameAndNameRequired, error: true);
                return;
              }
              final r = await widget.api
                  .mintSubsonicKey(_user.text.trim(), _name.text.trim());
              if (mounted) setState(() => _key = '${r['key']}');
            },
          ),
        ),
        if (_key != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              Expanded(
                  child: SelectableText(_key!,
                      style: const TextStyle(fontFamily: 'monospace'))),
              const Icon(Icons.warning_amber, size: 16),
            ]),
          ),
        ],
      ],
    );
  }
}
