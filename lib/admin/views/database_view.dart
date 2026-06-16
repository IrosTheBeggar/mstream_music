import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Database" — scan options, scan/maintenance actions, and shared playlists.
class DatabaseView extends StatelessWidget {
  final AdminApi api;
  const DatabaseView({super.key, required this.api});

  Future<({Map<String, dynamic> params, int files, List<dynamic> shares})>
      _load() async {
    final params = await api.getScanParams();
    final files = await api.scanStats();
    final shares = await api.getSharedPlaylists();
    return (params: params, files: files, shares: shares);
  }

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        final p = data.params;
        return AdminViewBody(children: [
          AdminCard(
            title: 'Library',
            icon: Icons.storage_outlined,
            trailing: [
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
            ],
            children: [
              AdminInfoRow('Tracks in database', '${data.files}'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                AdminActionButton(
                  label: 'Scan all',
                  icon: Icons.search,
                  success: 'Scan started',
                  onPressed: api.scanAll,
                ),
                AdminActionButton(
                  label: 'Force rescan',
                  icon: Icons.refresh,
                  tonal: true,
                  success: 'Full rescan started',
                  onPressed: api.forceRescan,
                ),
                AdminActionButton(
                  label: 'Compress images',
                  icon: Icons.compress,
                  tonal: true,
                  success: 'Image compression started',
                  onPressed: api.forceCompressImages,
                ),
              ]),
            ],
          ),
          AdminCard(
            title: 'Scan options',
            icon: Icons.tune,
            children: [
              AdminSaveField(
                label: 'Scan interval (hours, 0 = off)',
                number: true,
                initialValue: '${_int(p['scanInterval'], 24)}',
                onSave: (v) => api.setScanInterval(_int(v, 24)),
              ),
              AdminSaveField(
                label: 'Boot scan delay (seconds)',
                number: true,
                initialValue: '${_int(p['bootScanDelay'], 3)}',
                onSave: (v) => api.setBootScanDelay(_int(v, 3)),
              ),
              AdminSaveField(
                label: 'Scan commit interval (1–1000)',
                number: true,
                initialValue: '${_int(p['scanCommitInterval'], 25)}',
                onSave: (v) => api.setScanCommitInterval(_int(v, 25)),
              ),
              AdminSaveField(
                label: 'Scan threads (0 = auto)',
                number: true,
                initialValue: '${_int(p['scanThreads'], 0)}',
                onSave: (v) => api.setScanThreads(_int(v, 0)),
              ),
              const Divider(height: 16),
              AdminAsyncSwitch(
                title: 'Skip image extraction',
                value: p['skipImg'] == true,
                onChanged: api.setSkipImg,
              ),
              AdminAsyncSwitch(
                title: 'Compress embedded images',
                value: p['compressImage'] == true,
                onChanged: api.setCompressImage,
              ),
              AdminAsyncSwitch(
                title: 'Generate waveforms after scan',
                value: p['generateWaveforms'] == true,
                onChanged: api.setGenerateWaveforms,
              ),
              AdminAsyncSwitch(
                title: 'Analyze BPM/key (deprecated, no-op)',
                value: p['analyzeBpm'] == true,
                onChanged: api.setAnalyzeBpm,
              ),
            ],
          ),
          AdminCard(
            title: 'Automatic album art',
            icon: Icons.image_outlined,
            children: [
              AdminAsyncSwitch(
                title: 'Download missing album art',
                value: p['autoAlbumArt'] == true,
                onChanged: api.setAutoAlbumArt,
              ),
              AdminDropdownRow<String>(
                label: 'Target',
                value: p['autoAlbumArtMode'] == 'all' ? 'all' : 'missing',
                items: const [
                  DropdownMenuItem(value: 'missing', child: Text('Missing only')),
                  DropdownMenuItem(value: 'all', child: Text('All albums')),
                ],
                onChanged: api.setAutoAlbumArtMode,
              ),
              AdminSaveField(
                label: 'Albums per run (1–10000)',
                number: true,
                initialValue: '${_int(p['autoAlbumArtPerRun'], 100)}',
                onSave: (v) => api.setAutoAlbumArtPerRun(_int(v, 100)),
              ),
              AdminAsyncSwitch(
                title: 'Auto-downloaded art → write into folder',
                value: p['autoAlbumArtWriteToFolder'] == true,
                onChanged: api.setAutoAlbumArtWriteToFolder,
              ),
              AdminAsyncSwitch(
                title: 'Manual set-art → write into folder',
                value: p['albumArtWriteToFolder'] == true,
                onChanged: api.setAlbumArtWriteToFolder,
              ),
              AdminAsyncSwitch(
                title: 'Manual set-art → embed into file tag',
                value: p['albumArtWriteToFile'] == true,
                onChanged: api.setAlbumArtWriteToFile,
              ),
              const SizedBox(height: 8),
              const Align(
                  alignment: Alignment.centerLeft, child: Text('Art services')),
              _AlbumArtServices(
                api: api,
                selected: [
                  for (final s in (p['albumArtServices'] as List?) ?? const [])
                    '$s'
                ],
              ),
            ],
          ),
          _SharedPlaylistsCard(api: api, shares: data.shares, reload: reload),
        ]);
      },
    );
  }
}

class _AlbumArtServices extends StatefulWidget {
  final AdminApi api;
  final List<String> selected;
  const _AlbumArtServices({required this.api, required this.selected});

  @override
  State<_AlbumArtServices> createState() => _AlbumArtServicesState();
}

class _AlbumArtServicesState extends State<_AlbumArtServices> {
  static const _all = ['musicbrainz', 'itunes', 'deezer'];
  late final Set<String> _sel = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, children: [
      for (final s in _all)
        FilterChip(
          label: Text(s),
          selected: _sel.contains(s),
          onSelected: (v) async {
            final prev = {..._sel};
            setState(() => v ? _sel.add(s) : _sel.remove(s));
            final ok = await runAdminAction(
                context, () => widget.api.setAlbumArtServices(_sel.toList()),
                success: 'Art services updated');
            if (!ok && mounted) {
              setState(() => _sel
                ..clear()
                ..addAll(prev));
            }
          },
        ),
    ]);
  }
}

class _SharedPlaylistsCard extends StatelessWidget {
  final AdminApi api;
  final List<dynamic> shares;
  final Future<void> Function() reload;
  const _SharedPlaylistsCard(
      {required this.api, required this.shares, required this.reload});

  String _expiry(dynamic expires) {
    if (expires == null) return 'never';
    final secs = expires is num ? expires.toInt() : int.tryParse('$expires');
    if (secs == null) return '$expires';
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000)
        .toLocal()
        .toString()
        .split('.')
        .first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminCard(
      title: 'Shared playlists',
      icon: Icons.share_outlined,
      trailing: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
      ],
      children: [
        Wrap(spacing: 8, children: [
          AdminActionButton(
            label: 'Delete expired',
            tonal: true,
            success: 'Expired shares deleted',
            onPressed: () async {
              await api.deleteExpiredShares();
              await reload();
            },
          ),
          AdminActionButton(
            label: 'Delete never-expiring',
            destructive: true,
            success: 'Eternal shares deleted',
            onPressed: () async {
              await api.deleteEternalShares();
              await reload();
            },
          ),
        ]),
        const Divider(height: 20),
        if (shares.isEmpty)
          Text('No shared playlists',
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final s in shares)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.link),
              title: Text('${s['playlistId']}'),
              subtitle: Text(
                  'by ${s['user'] ?? 'unknown'} · '
                  '${(s['playlist'] as List?)?.length ?? 0} tracks · '
                  'expires ${_expiry(s['expires'])}'),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () async {
                  await runAdminAction(context,
                      () => api.deleteSharedPlaylist('${s['playlistId']}'),
                      success: 'Share deleted');
                  await reload();
                },
              ),
            ),
      ],
    );
  }
}
