import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/server_tree.dart';

/// The libraries other servers share with [parent], from the home's
/// Federation card: one row per peer, tap to browse it. The same switch the
/// app-bar picker makes — the row's index into the stored list, then the
/// capability refresh — so a peer opened from here behaves exactly like one
/// picked from the top bar.
Future<void> showFederationSheet(BuildContext context, Server parent) {
  final l = AppLocalizations.of(context);
  final peers = ServerManager()
      .federatedChildren(parent)
      .where((p) => p.isSelectable)
      .toList();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: VelvetColors.surface,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(VelvetColors.radiusLarge))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(l.federationSheetTitle,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l.serverPickerVia(parent.displayName),
                style: TextStyle(
                    fontSize: 13, color: VelvetColors.textSecondary)),
          ),
          for (final peer in peers)
            ListTile(
              leading: Text(kPeerBranch,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 18)),
              title: Row(children: [
                Icon(Icons.hub_outlined,
                    size: 18, color: VelvetColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(peer.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: VelvetColors.textPrimary)),
                ),
              ]),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final index = ServerManager().serverList.indexOf(peer);
                if (index < 0) return;
                // Awaited like the picker's switch: the capability refresh
                // used to race the tunnel bring-up and toast a spurious
                // failure on every iroh switch.
                await ServerManager().changeCurrentServer(index);
                try {
                  await ServerManager().getServerPaths(
                      ServerManager().currentServer!,
                      throwErr: true);
                  await ServerManager().callAfterEditServer();
                } catch (_) {
                  // The picker toasts here; a peer that cannot be reached
                  // shows its state on the home it just switched to.
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
