import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Transcoding" — ffmpeg-backed on-the-fly transcode defaults.
class TranscodingView extends StatelessWidget {
  final AdminApi api;
  const TranscodingView({super.key, required this.api});

  static const _codecs = ['mp3', 'opus', 'aac'];
  static const _bitrates = ['64k', '96k', '128k', '192k'];

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.getTranscode,
      builder: (context, t, reload) {
        final downloaded = t['downloaded'] == true;
        return AdminViewBody(children: [
          AdminCard(
            title: 'FFmpeg',
            icon: Icons.transform,
            trailing: [
              StatusPill(
                label: downloaded ? 'Ready' : 'Not downloaded',
                color: downloaded ? Colors.green : Colors.orange,
                icon: downloaded ? Icons.check_circle : Icons.download,
              ),
            ],
            children: [
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: AdminActionButton(
                  label: 'Download / update ffmpeg',
                  icon: Icons.download,
                  tonal: true,
                  success: 'ffmpeg downloaded',
                  onPressed: () async {
                    await api.downloadFfmpeg();
                    await reload();
                  },
                ),
              ),
              const SizedBox(height: 8),
              AdminAsyncSwitch(
                title: 'Auto-update ffmpeg',
                subtitle: 'Keep the bundled ffmpeg up to date automatically',
                value: t['autoUpdate'] == true,
                onChanged: api.setTranscodeAutoUpdate,
              ),
            ],
          ),
          AdminCard(
            title: 'Defaults',
            icon: Icons.tune,
            children: [
              AdminDropdownRow<String>(
                label: 'Default codec',
                value: _codecs.contains(t['defaultCodec'])
                    ? t['defaultCodec']
                    : 'mp3',
                items: [
                  for (final c in _codecs)
                    DropdownMenuItem(value: c, child: Text(c.toUpperCase())),
                ],
                onChanged: api.setDefaultCodec,
              ),
              AdminDropdownRow<String>(
                label: 'Default bitrate',
                value: _bitrates.contains(t['defaultBitrate'])
                    ? t['defaultBitrate']
                    : '128k',
                items: [
                  for (final b in _bitrates)
                    DropdownMenuItem(value: b, child: Text(b)),
                ],
                onChanged: api.setDefaultBitrate,
              ),
            ],
          ),
        ]);
      },
    );
  }
}
