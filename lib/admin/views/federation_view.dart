import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Federation" — the server feature is currently disabled (being rebuilt). The
/// server's `POST /api/v1/admin/federation/enable` returns HTTP 410 with a
/// status message, so this view simply surfaces that state faithfully rather
/// than pretending the toggle works.
class FederationView extends StatelessWidget {
  final AdminApi api;
  const FederationView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AdminViewBody(children: [
      AdminCard(
        title: l.adminFederation,
        icon: Icons.hub_outlined,
        trailing: [
          StatusPill(
              label: l.adminFederationUnavailable,
              color: Colors.orange,
              icon: Icons.build),
        ],
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.adminFederationDescription,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AdminActionButton(
              label: l.adminCheckStatus,
              icon: Icons.refresh,
              tonal: true,
              // Will surface the server's 410 message via the error toast.
              onPressed: () => api.enableFederation(true),
            ),
          ),
        ],
      ),
    ]);
  }
}
