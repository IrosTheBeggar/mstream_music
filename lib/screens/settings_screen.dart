import 'package:flutter/material.dart';

import '../singletons/settings.dart';
import '../singletons/transcode.dart';
import '../theme/velvet_theme.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader('Playback'),
          SwitchListTile(
            title: Text('Transcode audio'),
            subtitle: Text(
              'Stream a transcoded copy from the server (smaller files, '
              'slightly slower start). Off plays original files.',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: TranscodeManager().transcodeOn,
            onChanged: (v) async {
              setState(() {
                TranscodeManager().transcodeOn = v;
              });
              await SettingsManager().setTranscode(v);
            },
            activeThumbColor: VelvetColors.primary,
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader('Browse'),
          SwitchListTile(
            title: Text('Album grid view'),
            subtitle: Text(
              'Show albums as a grid of cards with cover art instead of '
              'a plain list.',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            value: SettingsManager().albumGrid,
            onChanged: (v) async {
              setState(() {});
              await SettingsManager().setAlbumGrid(v);
              setState(() {});
            },
            activeThumbColor: VelvetColors.primary,
          ),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader('About'),
          ListTile(
            leading: Icon(Icons.tune),
            title: Text('Reset to defaults'),
            subtitle: Text(
              'Restore all settings on this screen to their default '
              'values. Servers and downloads are not affected.',
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            onTap: () async {
              await SettingsManager().resetAll();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settings restored to defaults')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: VelvetColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
