import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/federation_inbox_alerts.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import '../../widgets/federation_widgets.dart';
import 'federation_controller.dart';

/// The switches behind the Federation screen: federation itself, the
/// endpoint's status and id, the pairing-request inbox, and the limit
/// defaults every new ticket starts from.
class FederationSettingsScreen extends StatefulWidget {
  final FederationController controller;
  const FederationSettingsScreen({super.key, required this.controller});

  @override
  State<FederationSettingsScreen> createState() =>
      _FederationSettingsScreenState();
}

class _FederationSettingsScreenState extends State<FederationSettingsScreen> {
  bool _toggling = false;
  bool _inboxBusy = false;

  FederationController get c => widget.controller;

  Future<void> _toggle(bool on) async {
    final l = AppLocalizations.of(context);
    setState(() => _toggling = true);
    try {
      await c.setEnabled(on);
      if (c.status?.available == false) {
        showGlobalSnack(l.federationUnavailableNote);
      } else {
        showGlobalSnack(on ? l.federationTurnedOn : l.federationTurnedOff);
      }
    } catch (_) {
      showGlobalSnack(l.federationToggleFailed);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _inbox(bool on) async {
    final l = AppLocalizations.of(context);
    setState(() => _inboxBusy = true);
    try {
      await c.setAcceptRequests(on);
      // Opening the inbox is the moment the OS permission makes sense.
      if (on && SettingsManager().notifyFederationRequests) {
        unawaited(FederationInboxAlerts().ensurePermission());
      }
    } catch (_) {
      showGlobalSnack(l.federationInboxFailed);
    } finally {
      if (mounted) setState(() => _inboxBusy = false);
    }
  }

  Future<void> _notify(bool on) async {
    await SettingsManager().setNotifyFederationRequests(on);
    if (on) await FederationInboxAlerts().ensurePermission();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.federationSettingsTitle)),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final s = c.status;
            final on = s?.enabled == true;
            final endpoint = s?.endpointId;
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                FedCard(children: [
                  FedSwitchRow(
                    title: l.federationTitle,
                    subtitle: l.federationSwitchSubtitle,
                    value: on,
                    busy: _toggling,
                    onChanged: s == null || s.available == false ? null : _toggle,
                  ),
                ]),
                if (s?.available == false) ...[
                  const SizedBox(height: 10),
                  FedNote(l.federationUnavailableNote),
                ],
                if (on) ...[
                  FedSection(l.federationStatusSection),
                  FedCard(children: [
                    FedRow(
                      title: s!.running
                          ? (s.online
                              ? l.federationConnectedRelay
                              : l.federationStatusConnecting)
                          : l.federationNotRunning,
                      subtitle: s.relayUrl,
                      dot: s.running
                          ? (s.online ? VelvetColors.success : VelvetColors.warning)
                          : VelvetColors.error,
                    ),
                    if (endpoint != null)
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: endpoint));
                          showGlobalSnack(l.federationEndpointCopied);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.federationEndpointId,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: VelvetColors.textSecondary)),
                                  Text(endpoint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: VelvetColors.textPrimary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.content_copy,
                                size: 20, color: VelvetColors.primary),
                          ]),
                        ),
                      ),
                  ]),
                  if (c.requestsSupported) ...[
                    FedSection(l.federationPairingRequestsSection),
                    FedCard(children: [
                      FedSwitchRow(
                        title: l.federationRequestsInboxTitle,
                        subtitle: l.federationRequestsInboxSubtitle,
                        value: c.acceptRequests,
                        busy: _inboxBusy,
                        onChanged: _inbox,
                      ),
                    ]),
                  ],
                  FedSection(l.federationDefaultsSection),
                  FedCard(children: [
                    FedRow(
                      icon: Icons.vpn_key_outlined,
                      iconColor: VelvetColors.textSecondary,
                      title: fmtLimitsSummary(context, s.limitDefaults),
                      titleLines: 2,
                      subtitle: l.federationDefaultsNote,
                      subtitleLines: 2,
                    ),
                    FedSwitchRow(
                      title: l.federationNotifyTitle,
                      subtitle: l.federationNotifySubtitle,
                      value: SettingsManager().notifyFederationRequests,
                      onChanged: _notify,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  FedNote(l.federationOffWarning),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
