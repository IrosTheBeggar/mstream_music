import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';

/// "DLNA" — UPnP/DLNA media-server advertising and browse layout.
class DlnaView extends StatelessWidget {
  final AdminApi api;
  const DlnaView({super.key, required this.api});

  static const _modes = {
    'disabled': 'Disabled',
    'same-port': 'Same port as HTTP',
    'separate-port': 'Separate port',
  };
  static const _browse = {
    'flat': 'Flat (all tracks)',
    'dirs': 'Directories',
    'artist': 'By artist',
    'album': 'By album',
    'genre': 'By genre',
  };

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.getDlna,
      builder: (context, d, reload) {
        final mode = _modes.containsKey(d['mode']) ? d['mode'] : 'disabled';
        final port = (d['port'] is num) ? (d['port'] as num).toInt() : 8200;
        return AdminViewBody(children: [
          AdminCard(
            title: 'Server',
            icon: Icons.wifi_tethering,
            children: [
              AdminDropdownRow<String>(
                label: 'Mode',
                value: mode,
                items: [
                  for (final e in _modes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) async {
                  await api.setDlnaMode(v, port: v == 'separate-port' ? port : null);
                  await reload();
                },
              ),
              if (mode == 'separate-port')
                AdminSaveField(
                  label: 'Port',
                  number: true,
                  initialValue: '$port',
                  onSave: (v) =>
                      api.setDlnaMode('separate-port', port: int.tryParse(v) ?? port),
                ),
            ],
          ),
          AdminCard(
            title: 'Identity',
            icon: Icons.badge_outlined,
            children: [
              AdminSaveField(
                label: 'Friendly name',
                initialValue: '${d['name'] ?? ''}',
                onSave: api.setDlnaName,
              ),
              AdminSaveField(
                label: 'Device UUID',
                helperText: 'Canonical GUID',
                initialValue: '${d['uuid'] ?? ''}',
                onSave: api.setDlnaUuid,
              ),
            ],
          ),
          AdminCard(
            title: 'Browse layout',
            icon: Icons.account_tree_outlined,
            children: [
              AdminDropdownRow<String>(
                label: 'Structure',
                value: _browse.containsKey(d['browse']) ? d['browse'] : 'flat',
                items: [
                  for (final e in _browse.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: api.setDlnaBrowse,
              ),
            ],
          ),
        ]);
      },
    );
  }
}
