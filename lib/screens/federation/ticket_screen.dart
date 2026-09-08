import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_widgets.dart';

/// A minted ticket, built to be sent: the QR for the same room, the text
/// for everything else, and the share sheet — a written message with the
/// ticket on its own line — as the sticky action. Reached right after
/// minting and again from a key's detail while the ticket is unclaimed.
class TicketScreen extends StatelessWidget {
  final FederationKey ticketKey;
  const TicketScreen({super.key, required this.ticketKey});

  Future<void> _send(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ticket = ticketKey.ticket;
    if (ticket == null) return;
    await SharePlus.instance.share(ShareParams(
      text: l.federationShareMessage(fmtList(ticketKey.libraryNames), ticket),
      subject: l.federationShareSubject,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final k = ticketKey;
    final ticket = k.ticket;
    final qrSize = (MediaQuery.of(context).size.width * 0.42).clamp(140.0, 200.0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop()),
        title: Text(l.federationTicketTitle),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.done,
                  style: TextStyle(
                      color: VelvetColors.primary, fontWeight: FontWeight.w600))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          FedCard(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const FedTile(Icons.vpn_key_outlined, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.federationTicketFor(k.name),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: VelvetColors.textPrimary)),
                      Text(l.federationTicketReads(fmtList(k.libraryNames)),
                          style: TextStyle(
                              fontSize: 13, color: VelvetColors.textSecondary)),
                      Text(
                          fmtLimitsSummary(context, k.limits,
                              expiresAt: k.expiresAt, expired: k.expired),
                          style: TextStyle(
                              fontSize: 12, color: VelvetColors.textTertiary)),
                    ],
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          if (ticket == null)
            FedNote(l.federationTicketNotRunning)
          else ...[
            Center(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusLarge),
                  ),
                  child: QrImageView(
                      data: ticket,
                      size: qrSize,
                      backgroundColor: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(l.federationTicketQrHint,
                    style: TextStyle(
                        fontSize: 12, color: VelvetColors.textTertiary)),
              ]),
            ),
            const SizedBox(height: 12),
            Material(
              color: VelvetColors.raised,
              borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
              child: InkWell(
                onTap: () => _copy(context, ticket),
                borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(ticket,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: VelvetColors.textSecondary)),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.content_copy,
                          size: 20, color: VelvetColors.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FedNote(l.federationTicketWarning),
            const SizedBox(height: 10),
            FedButton(l.federationCopyTicket,
                icon: Icons.content_copy,
                kind: FedButtonKind.outline,
                onPressed: () => _copy(context, ticket)),
            const SizedBox(height: 8),
            FedHint(l.federationTicketRevokeNote),
          ],
        ],
      ),
      bottomNavigationBar: ticket == null
          ? null
          : FedBottomBar(children: [
              FedButton(l.federationSendByText,
                  icon: Icons.chat_bubble_outline,
                  onPressed: () => _send(context)),
            ]),
    );
  }

  Future<void> _copy(BuildContext context, String ticket) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: ticket));
    showGlobalSnack(l.federationTicketCopied);
  }
}
