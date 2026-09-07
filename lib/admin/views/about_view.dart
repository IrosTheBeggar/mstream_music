import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "About" — server version (GET /api) + a read-only summary of the live
/// config (GET /api/v1/admin/config).
class AboutView extends StatelessWidget {
  final AdminApi api;
  const AboutView({super.key, required this.api});

  Future<({String version, Map<String, dynamic> config})> _load() async {
    final (info, config) = await (api.serverInfo(), api.getConfig()).wait;
    return (version: '${info['server'] ?? '?'}', config: config);
  }

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: _load,
      builder: (context, data, reload) {
        final l = AppLocalizations.of(context);
        final c = data.config;
        String b(dynamic v) => v == true ? l.adminYes : l.adminNo;
        return AdminViewBody(children: [
          AdminCard(
            title: l.adminAboutTitle(data.version),
            icon: Icons.info_outline,
            trailing: [
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
            ],
            children: [
              AdminInfoRow(l.adminBindAddress, '${c['address']}'),
              AdminInfoRow(l.adminAboutPort, '${c['port']}'),
              AdminInfoRow(l.adminSSL, (c['ssl']?['cert'] != null) ? l.adminEnabled : l.adminDisabled),
              AdminInfoRow(l.adminUI, '${c['ui'] ?? 'default'}'),
              AdminInfoRow(l.adminCompression, '${c['compression'] ?? 'none'}'),
              AdminInfoRow(l.adminTrustProxy, b(c['trustProxy'])),
              AdminInfoRow(l.adminSecretLast4, '…${c['secret'] ?? ''}'),
            ],
          ),
          AdminCard(
            title: l.adminPermissions,
            icon: Icons.lock_outline,
            children: [
              AdminInfoRow(l.adminUploads, c['noUpload'] == true ? l.adminDisabled : l.adminAllowed),
              AdminInfoRow(l.adminMakeDirs, c['noMkdir'] == true ? l.adminDisabled : l.adminAllowed),
              AdminInfoRow(
                  l.adminFileModify, c['noFileModify'] == true ? l.adminDisabled : l.adminAllowed),
              AdminInfoRow(l.adminMaxRequestSize, '${c['maxRequestSize'] ?? '—'}'),
            ],
          ),
          AdminCard(
            title: l.adminDatabaseTuning,
            icon: Icons.tune,
            children: [
              AdminInfoRow(l.adminSynchronous, '${c['dbSynchronous'] ?? 'FULL'}'),
              AdminInfoRow(l.adminCacheSizeLabel,
                  l.adminCacheSizeMb((c['dbCacheSizeMb'] as num?)?.toInt() ?? 64)),
            ],
          ),
        ]);
      },
    );
  }
}
