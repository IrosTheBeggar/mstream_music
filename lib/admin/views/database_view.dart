import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Database" — scan options, scan/maintenance actions, and shared playlists.
class DatabaseView extends StatelessWidget {
  final AdminApi api;
  const DatabaseView({super.key, required this.api});

  Future<({Map<String, dynamic> params, int files, List<dynamic> shares})>
      _load() async {
    final (params, files, shares) = await (
      api.getScanParams(),
      api.scanStats(),
      api.getSharedPlaylists(),
    ).wait;
    return (params: params, files: files, shares: shares);
  }

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        final l = AppLocalizations.of(context);
        final p = data.params;
        return AdminViewBody(children: [
          AdminCard(
            title: l.adminLibraryTitle,
            icon: Icons.storage_outlined,
            trailing: [
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
            ],
            children: [
              AdminInfoRow(l.adminTracksInDatabase, '${data.files}'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                AdminActionButton(
                  label: l.adminScanAllButton,
                  icon: Icons.search,
                  success: l.adminScanStarted,
                  onPressed: api.scanAll,
                ),
                AdminActionButton(
                  label: l.adminForceRescan,
                  icon: Icons.refresh,
                  tonal: true,
                  success: l.adminFullRescanStarted,
                  onPressed: api.forceRescan,
                ),
                AdminActionButton(
                  label: l.adminCompressImages,
                  icon: Icons.compress,
                  tonal: true,
                  success: l.adminImageCompressionStarted,
                  onPressed: api.forceCompressImages,
                ),
              ]),
            ],
          ),
          AdminCard(
            title: l.adminScanOptions,
            icon: Icons.tune,
            children: [
              AdminSaveField(
                label: l.adminScanInterval,
                number: true,
                initialValue: '${_int(p['scanInterval'], 24)}',
                onSave: (v) => api.setScanInterval(_int(v, 24)),
              ),
              AdminSaveField(
                label: l.adminBootScanDelay,
                number: true,
                initialValue: '${_int(p['bootScanDelay'], 3)}',
                onSave: (v) => api.setBootScanDelay(_int(v, 3)),
              ),
              AdminSaveField(
                label: l.adminScanCommitInterval,
                number: true,
                initialValue: '${_int(p['scanCommitInterval'], 25)}',
                onSave: (v) => api.setScanCommitInterval(_int(v, 25)),
              ),
              AdminSaveField(
                label: l.adminScanThreads,
                number: true,
                initialValue: '${_int(p['scanThreads'], 0)}',
                onSave: (v) => api.setScanThreads(_int(v, 0)),
              ),
              const Divider(height: 16),
              AdminAsyncSwitch(
                title: l.adminSkipImageExtraction,
                value: p['skipImg'] == true,
                onChanged: api.setSkipImg,
              ),
              AdminAsyncSwitch(
                title: l.adminCompressEmbeddedImages,
                value: p['compressImage'] == true,
                onChanged: api.setCompressImage,
              ),
              AdminAsyncSwitch(
                title: l.adminGenerateWaveforms,
                value: p['generateWaveforms'] == true,
                onChanged: api.setGenerateWaveforms,
              ),
              AdminAsyncSwitch(
                title: l.adminAnalyzeBpm,
                value: p['analyzeBpm'] == true,
                onChanged: api.setAnalyzeBpm,
              ),
            ],
          ),
          AdminCard(
            title: l.adminAutomaticAlbumArt,
            icon: Icons.image_outlined,
            children: [
              AdminAsyncSwitch(
                title: l.adminDownloadMissingAlbumArt,
                value: p['autoAlbumArt'] == true,
                onChanged: api.setAutoAlbumArt,
              ),
              AdminDropdownRow<String>(
                label: l.adminTargetLabel,
                value: p['autoAlbumArtMode'] == 'all' ? 'all' : 'missing',
                items: [
                  DropdownMenuItem(
                      value: 'missing', child: Text(l.adminMissingOnly)),
                  DropdownMenuItem(value: 'all', child: Text(l.adminAllAlbums)),
                ],
                onChanged: api.setAutoAlbumArtMode,
              ),
              AdminSaveField(
                label: l.adminAlbumsPerRun,
                number: true,
                initialValue: '${_int(p['autoAlbumArtPerRun'], 100)}',
                onSave: (v) => api.setAutoAlbumArtPerRun(_int(v, 100)),
              ),
              AdminAsyncSwitch(
                title: l.adminAutoDownloadedArtWriteFolder,
                value: p['autoAlbumArtWriteToFolder'] == true,
                onChanged: api.setAutoAlbumArtWriteToFolder,
              ),
              AdminAsyncSwitch(
                title: l.adminManualArtWriteFolder,
                value: p['albumArtWriteToFolder'] == true,
                onChanged: api.setAlbumArtWriteToFolder,
              ),
              AdminAsyncSwitch(
                title: l.adminManualArtEmbedTag,
                value: p['albumArtWriteToFile'] == true,
                onChanged: api.setAlbumArtWriteToFile,
              ),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.adminArtServices)),
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
    final l = AppLocalizations.of(context);
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
                success: l.adminArtServicesUpdated);
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

  String _expiry(AppLocalizations l, dynamic expires) {
    if (expires == null) return l.adminExpiryNever;
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
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AdminCard(
      title: l.adminSharedPlaylists,
      icon: Icons.share_outlined,
      trailing: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
      ],
      children: [
        Wrap(spacing: 8, children: [
          AdminActionButton(
            label: l.adminDeleteExpired,
            tonal: true,
            success: l.adminExpiredSharesDeleted,
            onPressed: () async {
              await api.deleteExpiredShares();
              await reload();
            },
          ),
          AdminActionButton(
            label: l.adminDeleteNeverExpiring,
            destructive: true,
            success: l.adminEternalSharesDeleted,
            onPressed: () async {
              await api.deleteEternalShares();
              await reload();
            },
          ),
        ]),
        const Divider(height: 20),
        if (shares.isEmpty)
          Text(l.adminNoSharedPlaylists,
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final s in shares)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.link),
              title: Text('${s['playlistId']}'),
              subtitle: Text(l.adminSharedPlaylistSubtitle(
                '${s['user'] ?? l.adminUnknownUser}',
                (s['playlist'] as List?)?.length ?? 0,
                _expiry(l, s['expires']),
              )),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () async {
                  await runAdminAction(context,
                      () => api.deleteSharedPlaylist('${s['playlistId']}'),
                      success: l.adminShareDeleted);
                  await reload();
                },
              ),
            ),
      ],
    );
  }
}
