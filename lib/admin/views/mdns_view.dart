import 'package:flutter/material.dart';

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
        return AdminViewBody(children: [
          AdminCard(
            title: 'Local network discovery',
            subtitle:
                'Advertises this server as an _mstream._tcp mDNS service. '
                'Publishes metadata only — exposes no library data or new routes.',
            icon: Icons.travel_explore,
            children: [
              AdminAsyncSwitch(
                title: 'Enable advertising',
                value: m['enabled'] == true,
                onChanged: (v) async {
                  await api.setMdnsEnabled(v);
                },
              ),
              const Divider(height: 24),
              AdminSaveField(
                label: 'Friendly name',
                helperText: 'Empty = derive from hostname (max 63 bytes)',
                initialValue: '${m['name'] ?? ''}',
                onSave: api.setMdnsName,
              ),
              const SizedBox(height: 8),
              AdminInfoRow('Instance ID', '${m['instanceId'] ?? '—'}'),
            ],
          ),
        ]);
      },
    );
  }
}
