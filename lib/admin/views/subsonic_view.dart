import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Subsonic API" — the bundled Subsonic-compatible endpoint: mode, live stats,
/// jukebox status, token-auth diagnostics, lyrics cache and API-key minting.
class SubsonicView extends StatelessWidget {
  final AdminApi api;
  const SubsonicView({super.key, required this.api});

  static const _modes = {
    'disabled': 'Disabled',
    'same-port': 'Same port as HTTP',
    'separate-port': 'Separate port',
  };

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.getSubsonic,
      builder: (context, s, reload) {
        final mode = _modes.containsKey(s['mode']) ? s['mode'] : 'disabled';
        final port = (s['port'] is num) ? (s['port'] as num).toInt() : 4040;
        return AdminViewBody(children: [
          AdminCard(
            title: 'Subsonic API',
            icon: Icons.play_circle_outline,
            children: [
              AdminDropdownRow<String>(
                label: 'Mode',
                value: mode,
                items: [
                  for (final e in _modes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) async {
                  await api.setSubsonicMode(v,
                      port: v == 'separate-port' ? port : null);
                  await reload();
                },
              ),
              if (mode == 'separate-port')
                AdminSaveField(
                  label: 'Port',
                  number: true,
                  initialValue: '$port',
                  onSave: (v) => api.setSubsonicMode('separate-port',
                      port: int.tryParse(v) ?? port),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AdminActionButton(
                  label: 'Test connection',
                  icon: Icons.network_check,
                  tonal: true,
                  onPressed: () async {
                    final r = await api.subsonicTest();
                    if (!context.mounted) return;
                    final ok = r['ok'] == true;
                    adminToast(
                      context,
                      ok
                          ? 'OK · ${r['version'] ?? ''} · ${r['latencyMs'] ?? '?'}ms'
                          : 'Failed: ${r['reason'] ?? 'unknown'}',
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
    return AdminAsync(
      loader: api.subsonicStats,
      builder: (context, stats, reload) {
        final lyrics = (stats['lyrics'] as Map?) ?? const {};
        final cache = (lyrics['cache'] as Map?) ?? const {};
        final nowPlaying = (stats['nowPlaying'] as List?) ?? const [];
        return AdminCard(
          title: 'Status',
          icon: Icons.insights,
          trailing: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
          children: [
            AdminInfoRow('Methods implemented', '${stats['methodsImplemented'] ?? 0}'),
            AdminInfoRow('Full / stub',
                '${stats['fullCount'] ?? 0} full · ${stats['stubCount'] ?? 0} stub'),
            const Divider(height: 16),
            Text('Now playing',
                style: Theme.of(context).textTheme.bodyMedium),
            if (nowPlaying.isEmpty)
              Text('nobody',
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
            Text('Lyrics (LRCLib)',
                style: Theme.of(context).textTheme.bodyMedium),
            AdminAsyncSwitch(
              title: 'LRCLib fallback',
              value: lyrics['lrclibEnabled'] == true,
              onChanged: (v) async {
                await api.setLyricsCacheEnabled(v);
              },
            ),
            AdminAsyncSwitch(
              title: 'Write .lrc sidecar files',
              value: lyrics['writeSidecarEnabled'] == true,
              onChanged: (v) async {
                await api.setLyricsWriteSidecar(v);
              },
            ),
            if (cache.isNotEmpty)
              AdminInfoRow('Cache',
                  cache.entries.map((e) => '${e.key}: ${e.value}').join(' · ')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              AdminActionButton(
                label: 'Purge cache',
                tonal: true,
                success: 'Lyrics cache purged',
                onPressed: () async {
                  await api.purgeLyricsCache(mode: 'full');
                  await reload();
                },
              ),
              AdminActionButton(
                label: 'Retry failed',
                tonal: true,
                success: 'Transient lyrics entries cleared',
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
    return AdminAsync(
      loader: api.subsonicJukebox,
      builder: (context, j, reload) {
        final available = j['available'] == true;
        return AdminCard(
          title: 'Jukebox',
          icon: Icons.queue_music,
          trailing: [
            StatusPill(
              label: available ? 'Available' : 'Unavailable',
              color: available ? Colors.green : Colors.grey,
            ),
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
          children: [
            if (!available)
              Text('${j['reason'] ?? 'Not available'}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
            else ...[
              AdminInfoRow('State',
                  j['playing'] == true ? 'playing' : (j['paused'] == true ? 'paused' : 'idle')),
              AdminInfoRow('Current', '${j['currentFile'] ?? '—'}'),
              AdminInfoRow('Queue', '${j['queueLength'] ?? 0} tracks'),
              AdminInfoRow('Volume',
                  '${((j['volume'] is num ? j['volume'] : 1.0) * 100).round()}%'),
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
    return AdminAsync(
      loader: api.subsonicTokenAuthAttempts,
      builder: (context, attempts, reload) {
        return AdminCard(
          title: 'Token-auth failures',
          subtitle:
              'Clients defaulting to token auth without a Subsonic password.',
          icon: Icons.warning_amber,
          trailing: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
          children: [
            if (attempts.isEmpty)
              Text('No recent failures',
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
                  label: 'Clear',
                  tonal: true,
                  success: 'Cleared',
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
    return AdminCard(
      title: 'Mint API key',
      subtitle: 'Generate a Subsonic apiKey for a user (shown once).',
      icon: Icons.vpn_key,
      children: [
        TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 8),
        TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Key name / label')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminActionButton(
            label: 'Mint key',
            icon: Icons.add,
            onPressed: () async {
              if (_user.text.trim().isEmpty || _name.text.trim().isEmpty) {
                adminToast(context, 'Username and name required', error: true);
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
