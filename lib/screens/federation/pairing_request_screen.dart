import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_limits_editor.dart';
import '../../widgets/federation_widgets.dart';
import 'federation_controller.dart';

/// The state chip a request row wears: the webapp's vocabulary, by
/// direction and state.
(String, Color) requestChip(AppLocalizations l, FederationRequest r) {
  final wait = VelvetColors.warning;
  final dead = VelvetColors.error;
  final mute = VelvetColors.textTertiary;
  switch ('${r.direction}:${r.state}') {
    case 'out:pending-delivery':
      return (l.federationReqSending, wait);
    case 'out:delivered':
      return (l.federationReqWaiting, wait);
    case 'out:granting':
      return (l.federationReqSharingBack, wait);
    case 'in:received':
      return (l.federationReqNeedsAnswer, VelvetColors.primary);
    case 'in:accepted':
      return (l.federationReqSendingTicket, wait);
    case 'in:granting':
      return (l.federationReqWaitingShare, wait);
    case 'out:rejected':
      return (l.federationReqDeclined, dead);
    case 'in:rejected':
      return (l.federationReqYouDeclined, dead);
    case 'out:refused':
      return (l.federationReqInboxClosed, dead);
  }
  switch (r.state) {
    case 'completed':
      return (l.federationReqFederated, VelvetColors.success);
    case 'cancelled':
      return (l.federationReqWithdrawn, mute);
    case 'expired':
      return (l.federationReqExpired, mute);
  }
  return (r.state, mute);
}

String requestOfferLine(AppLocalizations l, FederationRequest r) {
  final libs = fmtList(r.offeredLibraries);
  if (r.inbound) {
    return libs.isEmpty ? l.federationRequestOffersNothing : l.federationRequestOffers(libs);
  }
  return libs.isEmpty
      ? l.federationRequestYouOfferedNothing
      : l.federationRequestYouOffered(libs);
}

/// An inbound pairing request as a screen: who asks, their message and
/// offer; the libraries to share back (pre-checked, like the webapp);
/// the limits they get. Decline or accept.
class PairingRequestScreen extends StatefulWidget {
  final FederationController controller;
  final FederationRequest request;
  const PairingRequestScreen(
      {super.key, required this.controller, required this.request});

  @override
  State<PairingRequestScreen> createState() => _PairingRequestScreenState();
}

class _PairingRequestScreenState extends State<PairingRequestScreen> {
  List<String>? _libraries;
  Object? _error;
  final Set<String> _selected = {};
  late FederationLimits _limits;
  DateTime? _expiresAt;
  bool _busy = false;

  FederationController get c => widget.controller;
  FederationRequest get r => widget.request;

  @override
  void initState() {
    super.initState();
    _limits = c.status?.limitDefaults ?? FederationLimits.fallback;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final libs = await c.loadLibraries();
      if (!mounted) return;
      setState(() {
        _libraries = libs;
        _selected.addAll(libs);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _accept() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final vpaths = _libraries!.where(_selected.contains).toList();
      await c.api.acceptRequest(r.id,
          vpaths: vpaths, limits: _limits, expiresAt: _expiresAt);
      await Future.wait([c.refreshRequests(), c.refreshKeys(), c.refreshPeers()]);
      showGlobalSnack(l.federationRequestAccepted);
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      showGlobalSnack(l.federationRequestActionFailed);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await c.api.rejectRequest(r.id);
      await c.refreshRequests();
      showGlobalSnack(l.federationRequestDeclined);
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final libs = _libraries;
    final name = r.peerName ?? l.federationUnnamedServer;
    final fp = r.peerEndpointId.length > 16
        ? '${r.peerEndpointId.substring(0, 8)} … ${r.peerEndpointId.substring(r.peerEndpointId.length - 4)}'
        : r.peerEndpointId;
    return Scaffold(
      appBar: AppBar(title: Text(l.federationRequestTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          FedCard(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const FedTile(Icons.move_to_inbox_outlined, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: VelvetColors.textPrimary)),
                          Text(fp,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: VelvetColors.textTertiary)),
                        ],
                      ),
                    ),
                  ]),
                  if (r.message != null && r.message!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('“${r.message}”',
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                            color: VelvetColors.textPrimary)),
                  ],
                  const SizedBox(height: 8),
                  Text(requestOfferLine(l, r),
                      style: TextStyle(
                          fontSize: 13, color: VelvetColors.textSecondary)),
                  Text(
                      r.inbound
                          ? l.federationRequestReceived(fmtAgo(context, r.createdAt))
                          : l.federationRequestSent(fmtAgo(context, r.createdAt)),
                      style: TextStyle(
                          fontSize: 12, color: VelvetColors.textTertiary)),
                ],
              ),
            ),
          ]),
          FedSection(l.federationShareBack),
          if (libs == null && _error == null)
            fedLoading()
          else if (_error != null)
            FedCard(children: [
              FedRow(
                  icon: Icons.error_outline,
                  iconColor: VelvetColors.error,
                  title: l.federationLoadFailed,
                  trailing: FedButton(l.federationRetry,
                      kind: FedButtonKind.text, height: 36, onPressed: _load)),
            ])
          else
            FedCard(children: [
              for (final n in libs!)
                FedCheckRow(
                  label: n,
                  value: _selected.contains(n),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _selected.add(n);
                    } else {
                      _selected.remove(n);
                    }
                  }),
                ),
            ]),
          FedHint(l.federationShareBackNote),
          FederationLimitsEditor(
            initial: _limits,
            onChanged: (d) {
              _limits = d.limits;
              _expiresAt = d.expiresAt;
            },
          ),
        ],
      ),
      bottomNavigationBar: FedBottomBar(children: [
        FedButton(l.federationDecline,
            kind: FedButtonKind.muted, busy: _busy, onPressed: _decline),
        FedButton(l.federationAcceptAndShare,
            icon: Icons.check,
            busy: _busy,
            onPressed: libs == null || _selected.isEmpty ? null : _accept),
      ]),
    );
  }
}
