import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_limits_editor.dart';
import '../../widgets/federation_widgets.dart';
import 'federation_controller.dart';
import 'ticket_screen.dart';

/// One ticket you minted: who it is for, what it reads, whether it has
/// been claimed and how much it served today; the limits (editable live);
/// send it again while unclaimed; reset the claim; revoke.
class KeyDetailScreen extends StatefulWidget {
  final FederationController controller;
  final int keyId;
  const KeyDetailScreen(
      {super.key, required this.controller, required this.keyId});

  @override
  State<KeyDetailScreen> createState() => _KeyDetailScreenState();
}

class _KeyDetailScreenState extends State<KeyDetailScreen> {
  FederationLimitsDraft? _draft;
  bool _saving = false;
  bool _busy = false;

  FederationController get c => widget.controller;

  FederationKey? get _key {
    for (final k in c.keys) {
      if (k.id == widget.keyId) return k;
    }
    return null;
  }

  Future<void> _save(FederationKey k) async {
    final l = AppLocalizations.of(context);
    final d = _draft;
    if (d == null) return;
    setState(() => _saving = true);
    try {
      await c.api.setKeyLimits(k.id, d.limits,
          expiresAt: d.expiryChanged ? d.expiresAt : null,
          clearExpiry: d.expiryChanged && d.expiresAt == null);
      await c.refreshKeys();
      showGlobalSnack(l.federationLimitsSaved);
      if (mounted) setState(() => _draft = null);
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
    } catch (_) {
      showGlobalSnack(l.federationLimitsFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset(FederationKey k) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await c.api.resetBinding(k.id);
      await c.refreshKeys();
      showGlobalSnack(l.federationBindingReset);
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(FederationKey k) async {
    final l = AppLocalizations.of(context);
    final ok = await fedConfirm(context,
        message: l.federationRevokeConfirm(k.name),
        confirmLabel: l.federationRevoke,
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await c.api.revokeKey(k.id);
      await c.refreshKeys();
      showGlobalSnack(l.federationRevoked);
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _dirty(FederationKey k) {
    final d = _draft;
    if (d == null) return false;
    return d.limits != k.limits || d.expiryChanged;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final k = _key;
        if (k == null) {
          return Scaffold(
              appBar: AppBar(title: Text(l.federationKeyTitle)), body: fedLoading());
        }
        final claimedLine = k.claimed
            ? (k.boundAt != null
                ? l.federationKeyClaimedAgo(fmtAgo(context, k.boundAt))
                : l.federationKeyClaimed)
            : l.federationKeyNotClaimed;
        final usedLine = k.lastUsed != null
            ? l.federationKeyLastUsed(fmtAgo(context, k.lastUsed))
            : l.federationKeyNeverUsed;
        return Scaffold(
          appBar: AppBar(title: Text(l.federationKeyTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              FedCard(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    FedTile(Icons.vpn_key_outlined,
                        size: 48,
                        color: k.expired
                            ? VelvetColors.error
                            : (k.claimed
                                ? VelvetColors.success
                                : VelvetColors.warning)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.name,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: VelvetColors.textPrimary)),
                          Text(l.federationTicketReads(fmtList(k.libraryNames)),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: VelvetColors.textSecondary)),
                          Text(
                              '$claimedLine · ${l.federationKeyTodayUsage(fmtBytes(k.usageTodayBytes))}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: k.claimed
                                      ? VelvetColors.success
                                      : VelvetColors.warning)),
                          Text(usedLine,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: VelvetColors.textTertiary)),
                        ],
                      ),
                    ),
                  ]),
                ),
                if (k.ticket != null)
                  FedRow(
                    icon: Icons.chat_bubble_outline,
                    title: l.federationSendByText,
                    subtitle: k.claimed
                        ? l.federationKeyClaimed
                        : l.federationKeyNotClaimed,
                    trailing: fedChevron(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TicketScreen(ticketKey: k))),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: Text(l.federationTicketNotRunning,
                        style: TextStyle(
                            fontSize: 12, color: VelvetColors.textTertiary)),
                  ),
              ]),
              FederationLimitsEditor(
                initial: k.limits,
                initialExpiry: k.expiresAt,
                onChanged: (d) => setState(() => _draft = d),
              ),
              if (_dirty(k)) ...[
                const SizedBox(height: 10),
                FedButton(l.federationSaveLimits,
                    icon: Icons.check,
                    busy: _saving,
                    onPressed: () => _save(k)),
              ],
              if (k.claimed) ...[
                FedSection(l.federationResetBinding),
                FedCard(children: [
                  FedRow(
                    icon: Icons.restart_alt,
                    iconColor: VelvetColors.textSecondary,
                    title: l.federationResetBinding,
                    subtitle: l.federationResetBindingNote,
                    trailing: fedChevron(),
                    onTap: _busy ? null : () => _reset(k),
                  ),
                ]),
              ],
              const SizedBox(height: 18),
              Center(
                child: FedButton(l.federationRevoke,
                    icon: Icons.delete_outline,
                    kind: FedButtonKind.danger,
                    height: 40,
                    fontSize: 14,
                    busy: _busy,
                    onPressed: () => _revoke(k)),
              ),
            ],
          ),
        );
      },
    );
  }
}
