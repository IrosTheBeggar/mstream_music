import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_widgets.dart';

/// "About" — server version (GET /api) + a read-only summary of the live
/// config (GET /api/v1/admin/config).
class AboutView extends StatelessWidget {
  final AdminApi api;
  const AboutView({super.key, required this.api});

  Future<({String version, Map<String, dynamic> config})> _load() async {
    final info = await api.serverInfo();
    final config = await api.getConfig();
    return (version: '${info['server'] ?? '?'}', config: config);
  }

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        final c = data.config;
        String b(dynamic v) => v == true ? 'Yes' : 'No';
        return AdminViewBody(children: [
          AdminCard(
            title: 'mStream v${data.version}',
            icon: Icons.info_outline,
            trailing: [
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
            ],
            children: [
              AdminInfoRow('Bind address', '${c['address']}'),
              AdminInfoRow('Port', '${c['port']}'),
              AdminInfoRow('SSL', (c['ssl']?['cert'] != null) ? 'Enabled' : 'Disabled'),
              AdminInfoRow('UI', '${c['ui'] ?? 'default'}'),
              AdminInfoRow('Compression', '${c['compression'] ?? 'none'}'),
              AdminInfoRow('Trust proxy', b(c['trustProxy'])),
              AdminInfoRow('Secret (last 4)', '…${c['secret'] ?? ''}'),
            ],
          ),
          AdminCard(
            title: 'Permissions',
            icon: Icons.lock_outline,
            children: [
              AdminInfoRow('Uploads', c['noUpload'] == true ? 'Disabled' : 'Allowed'),
              AdminInfoRow('Make dirs', c['noMkdir'] == true ? 'Disabled' : 'Allowed'),
              AdminInfoRow(
                  'File modify', c['noFileModify'] == true ? 'Disabled' : 'Allowed'),
              AdminInfoRow('Max request size', '${c['maxRequestSize'] ?? '—'}'),
            ],
          ),
          AdminCard(
            title: 'Database tuning',
            icon: Icons.tune,
            children: [
              AdminInfoRow('Synchronous', '${c['dbSynchronous'] ?? 'FULL'}'),
              AdminInfoRow('Cache size', '${c['dbCacheSizeMb'] ?? 64} MB'),
            ],
          ),
        ]);
      },
    );
  }
}
