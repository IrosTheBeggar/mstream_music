import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../util/p2p_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import '../federation/federation_screen.dart';
import 'p2p_controller.dart';
import 'p2p_federate_screen.dart';

/// A server heard on the network, as a screen: its description and
/// numbers, the snapshot (download / update, pin, remove), the federation
/// relationship (federated, they asked, request sent, or ask), forget and
/// block.
class P2pPeerScreen extends StatefulWidget {
  final P2pController controller;
  final String endpointId;
  const P2pPeerScreen({super.key, required this.controller, required this.endpointId});

  @override
  State<P2pPeerScreen> createState() => _P2pPeerScreenState();
}

class _P2pPeerScreenState extends State<P2pPeerScreen> {
  bool _fetching = false;
  bool _busy = false;

  P2pController get c => widget.controller;

  Future<void> _run(Future<void> Function() action, String success,
      {bool popAfter = false, String Function(String)? failure}) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
      await c.refreshCatalog();
      showGlobalSnack(success);
      if (popAfter && mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(failure != null ? failure(e.message) : l.federationActionFailed(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetch(P2pPeer p) async {
    final l = AppLocalizations.of(context);
    setState(() => _fetching = true);
    try {
      await c.api.fetchSnapshot(p.endpointId);
      await c.refreshCatalog();
      showGlobalSnack(l.p2pDownloaded);
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.p2pDownloadFailed(e.message));
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _block(P2pPeer p, String name) async {
    final l = AppLocalizations.of(context);
    final ok = await fedConfirm(context,
        message: l.p2pBlockConfirm(name), confirmLabel: l.p2pBlockServer, danger: true);
    if (!ok || !mounted) return;
    await _run(() => c.api.block(p.endpointId), l.p2pBlocked(name), popAfter: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.peerById(widget.endpointId);
        if (p == null) {
          return Scaffold(appBar: AppBar(title: Text(l.p2pTitle)), body: fedLoading());
        }
        final name = p.name ?? p.shortId;
        final rotation = c.status?.rotationDays ?? 0;
        final sub = [
          p.online ? l.p2pOnline : l.p2pOfflineFor(fmtAgo(context, p.updatedAt)),
          l.p2pSeedersCount(p.seeders),
          p.compatible == null
              ? l.p2pModelUnknown
              : (p.compatible! ? l.p2pCompatible : l.p2pChipIncompatible),
        ].join(' · ');
        final rel = c.relationship(p);
        final f = p.fetched;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name),
                Row(children: [
                  FedDot(p.online ? VelvetColors.success : VelvetColors.textTertiary),
                  Flexible(
                    child: Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                            color: VelvetColors.appBarTextSecondary)),
                  ),
                ]),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              FedCard(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Text(
                      p.description != null ? '“${p.description}”' : l.p2pNoDescription,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: p.description != null
                              ? VelvetColors.textPrimary
                              : VelvetColors.textTertiary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(children: [
                    _stat('${p.trackCount}', l.p2pTracksLabel, null),
                    const SizedBox(width: 8),
                    _stat('${p.seeders}', l.p2pSeedersLabel, null),
                    const SizedBox(width: 8),
                    _stat(
                        f?.firstFetchedAt != null
                            ? MaterialLocalizations.of(context)
                                .formatShortMonthDay(f!.firstFetchedAt!)
                            : '—',
                        l.p2pHeldSince,
                        null),
                  ]),
                ),
              ]),
              if (p.compatible == false) ...[
                const SizedBox(height: 10),
                FedNote(l.p2pIncompatibleNote),
              ],
              FedSection(l.p2pSnapshotSection),
              FedCard(children: [
                FedRow(
                  icon: Icons.download_outlined,
                  iconColor: f == null ? VelvetColors.textSecondary : null,
                  title: f == null ? l.p2pNotDownloaded : l.p2pDownloadedSize(fmtBytes(f.sizeBytes)),
                  subtitle: f == null
                      ? l.p2pNotDownloadedSub
                      : (f.stale
                          ? '${l.p2pSnapshotSeq(f.snapshotSeq)} · ${l.p2pNewerAnnounced(p.snapshotSeq)}'
                          : l.p2pSnapshotSeq(f.snapshotSeq)),
                  subtitleLines: 2,
                  dot: f == null ? null : (f.stale ? VelvetColors.warning : VelvetColors.success),
                  trailing: FedButton(
                      _fetching ? l.p2pDownloading : (f == null ? l.p2pDownload : l.p2pUpdate),
                      kind: FedButtonKind.text,
                      height: 32,
                      fontSize: 14,
                      busy: _fetching,
                      onPressed: (f != null && !f.stale) || p.compatible == false
                          ? null
                          : () => _fetch(p)),
                ),
                if (f != null)
                  FedSwitchRow(
                    title: l.p2pPin,
                    subtitle: rotation > 0 ? l.p2pPinSub(rotation) : l.p2pPinSubNoRotation,
                    value: f.pinned,
                    busy: _busy,
                    onChanged: (v) => _run(() => c.api.pinSnapshot(p.endpointId, v), l.p2pSaved),
                  ),
              ]),
              FedSection(l.federationTitle),
              FedCard(children: [_relationshipRow(l, p, name, rel)]),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (f != null)
                    FedButton(l.p2pRemoveSnapshot,
                        icon: Icons.delete_outline,
                        kind: FedButtonKind.text,
                        height: 36,
                        fontSize: 13,
                        busy: _busy,
                        onPressed: () => _run(
                            () => c.api.removeSnapshot(p.endpointId), l.p2pSnapshotRemoved)),
                  if (f == null && !p.online)
                    FedButton(l.p2pForget,
                        icon: Icons.visibility_off_outlined,
                        kind: FedButtonKind.text,
                        height: 36,
                        fontSize: 13,
                        busy: _busy,
                        onPressed: () => _run(() => c.api.forget(p.endpointId),
                            l.p2pForgotten(name), popAfter: true)),
                  FedButton(l.p2pBlockServer,
                      icon: Icons.block,
                      kind: FedButtonKind.danger,
                      height: 36,
                      fontSize: 13,
                      busy: _busy,
                      onPressed: () => _block(p, name)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _relationshipRow(AppLocalizations l, P2pPeer p, String name, P2pFederationState rel) {
    switch (rel) {
      case P2pFederationState.federated:
        return FedRow(
          icon: Icons.hub_outlined,
          iconColor: VelvetColors.success,
          title: l.p2pFederatedWithYou,
          subtitle: l.p2pFederatedWithYouSub,
          subtitleLines: 2,
          trailing: FedButton(l.p2pOpen,
              kind: FedButtonKind.text, height: 32, fontSize: 14, onPressed: _openFederation),
        );
      case P2pFederationState.theirs:
        return FedRow(
          icon: Icons.move_to_inbox_outlined,
          iconColor: const Color(0xFF64B5F6),
          title: l.p2pTheyAskedYou,
          subtitle: l.p2pTheyAskedYouSub,
          subtitleLines: 2,
          trailing: FedButton(l.p2pReview,
              kind: FedButtonKind.text, height: 32, fontSize: 14, onPressed: _openFederation),
        );
      case P2pFederationState.sent:
        return FedRow(
          icon: Icons.outbox_outlined,
          iconColor: VelvetColors.textSecondary,
          title: l.p2pRequestSentTitle,
          subtitle: l.p2pRequestSentSub,
          subtitleLines: 2,
          trailing: FedButton(l.p2pOpen,
              kind: FedButtonKind.text, height: 32, fontSize: 14, onPressed: _openFederation),
        );
      case P2pFederationState.none:
        return FedRow(
          icon: Icons.hub_outlined,
          title: l.p2pAskToFederate,
          subtitle: l.p2pAskToFederateSub,
          subtitleLines: 2,
          trailing: fedChevron(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => P2pFederateScreen(controller: c, peer: p))),
        );
    }
  }

  void _openFederation() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FederationScreen(parent: c.server)));

  Widget _stat(String value, String label, String? sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
            color: VelvetColors.raised, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: VelvetColors.textPrimary)),
            Text(label, style: TextStyle(fontSize: 12, color: VelvetColors.textSecondary)),
            if (sub != null)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: VelvetColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
