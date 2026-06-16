import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "MP3 Player" — mDNS / DNS-SD advertise-only LAN discovery so zero-config
/// clients can find the server without typing an IP.
class MdnsView extends StatelessWidget {
  final AdminApi api;
  const MdnsView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return AdminAsync(
      loader: api.getMdns,
      builder: (context, m, reload) {
        final l = AppLocalizations.of(context);
        return AdminViewBody(children: [
          AdminCard(
            title: l.adminMdnsLocalNetworkDiscoveryTitle,
            subtitle: l.adminMdnsLocalNetworkDiscoverySubtitle,
            icon: Icons.travel_explore,
            children: [
              AdminAsyncSwitch(
                title: l.adminMdnsEnableAdvertisingTitle,
                value: m['enabled'] == true,
                onChanged: (v) async {
                  await api.setMdnsEnabled(v);
                },
              ),
              const Divider(height: 24),
              AdminSaveField(
                label: l.adminMdnsFriendlyNameLabel,
                helperText: l.adminMdnsFriendlyNameHelper,
                initialValue: '${m['name'] ?? ''}',
                onSave: api.setMdnsName,
              ),
              const SizedBox(height: 8),
              AdminInfoRow(l.adminMdnsInstanceIdLabel, '${m['instanceId'] ?? '—'}'),
            ],
          ),
        ]);
      },
    );
  }
}
