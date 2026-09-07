import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../media/audio_stuff.dart';
import '../../objects/server.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/server_list.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import 'federation_controller.dart';
import 'federation_screen.dart';

/// One peer, in words: how it is reached and whether that path is up,
/// the libraries it shares, the discovery opt-in (admin), whether the DJ
/// can use it, the picker switch; Test and Remove for admins; Browse.
class PeerDetailScreen extends StatefulWidget {
  final FederationController controller;
  final Server peer;
  const PeerDetailScreen(
      {super.key, required this.controller, required this.peer});

  @override
  State<PeerDetailScreen> createState() => _PeerDetailScreenState();
}

class _PeerDetailScreenState extends State<PeerDetailScreen> {
  bool _testing = false;
  bool _busy = false;
  bool _discoveryBusy = false;
  String? _testLine;
  Color? _testColor;

  FederationController get c => widget.controller;
  Server get peer => widget.peer;

  Future<void> _test(FederationPeerRow row) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _testing = true;
      _testLine = null;
    });
    try {
      final res = await c.api.testPeer(row.id);
      await c.refreshPeers();
      if (!mounted) return;
      setState(() {
        _testLine = res.ok
            ? l.federationTestOk
            : l.federationTestFailed(res.error ?? '?');
        _testColor = res.ok ? VelvetColors.success : VelvetColors.error;
      });
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _discovery(FederationPeerRow row, bool on) async {
    final l = AppLocalizations.of(context);
    setState(() => _discoveryBusy = true);
    try {
      await c.api.setPeerDiscovery(row.id, on);
      await c.refreshPeers();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
    } catch (_) {
      showGlobalSnack(l.federationDiscoveryFailed);
    } finally {
      if (mounted) setState(() => _discoveryBusy = false);
    }
  }

  Future<void> _remove(FederationPeerRow row) async {
    final l = AppLocalizations.of(context);
    final ok = await fedConfirm(context,
        message: l.federationRemovePeerConfirm(peer.displayName),
        confirmLabel: l.federationRemovePeer,
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await c.api.removePeer(row.id);
      await c.refreshPeers();
      showGlobalSnack(l.federationPeerRemoved(peer.displayName));
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The picker's switch: select the peer, refresh its capabilities, and
  /// go back to the browser on it.
  Future<void> _browse() async {
    final sm = ServerManager();
    final index = sm.serverList.indexOf(peer);
    if (index < 0) return;
    setState(() => _busy = true);
    await sm.changeCurrentServer(index);
    try {
      await sm.getServerPaths(sm.currentServer!, throwErr: true);
      await sm.callAfterEditServer();
    } catch (_) {
      // The home the browser lands on shows the peer's state itself.
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final row = c.isAdmin ? c.rowFor(peer) : null;
        final parent = peer.parentServer;
        final ps = peerState(l, peer);
        final libs = peer.autoDJPaths.keys.toList()..sort();
        final djOk =
            AudioPlayerHandler.canJoinMultiServer(peer, const <String>{});
        String? checked;
        if (row != null) {
          if (row.reachable && row.lastSeen != null) {
            checked = l.federationCheckedAgo(fmtAgo(context, row.lastSeen));
          } else if (row.lastStatus == null) {
            checked = l.federationNeverTested;
          } else {
            checked = l.federationTestFailed(row.lastStatus!);
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(peer.displayName),
                if (parent != null)
                  Text(l.serverPickerVia(parent.displayName),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          color: VelvetColors.appBarTextSecondary)),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              FedCard(children: [
                FedRow(
                  // The state word is written for a row ("live"); as a
                  // title it starts with a capital.
                  title: ps.state.isEmpty
                      ? ps.state
                      : ps.state[0].toUpperCase() + ps.state.substring(1),
                  titleSize: 17,
                  subtitle: peer.isDirect
                      ? '${ps.transport} · ${l.federationTransportRelay}'
                      : ps.transport,
                  dot: ps.dot,
                  trailing: row == null
                      ? null
                      : FedButton(
                          _testing ? l.federationTesting : l.federationTest,
                          kind: FedButtonKind.text,
                          height: 32,
                          fontSize: 14,
                          busy: _testing,
                          onPressed: () => _test(row)),
                ),
                if (checked != null || _testLine != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                    child: Row(children: [
                      Icon(Icons.refresh,
                          size: 14, color: VelvetColors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_testLine ?? checked!,
                            style: TextStyle(
                                fontSize: 12,
                                color: _testLine != null
                                    ? _testColor
                                    : VelvetColors.textTertiary)),
                      ),
                    ]),
                  ),
              ]),
              FedSection(l.federationLibrariesYouCanRead),
              FedCard(children: [
                if (libs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(l.federationPeerLibrariesUnknown,
                        style: TextStyle(color: VelvetColors.textSecondary)),
                  ),
                for (final name in libs)
                  FedRow(icon: Icons.folder_outlined, title: name),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Text(l.federationPeerReadOnlyNote,
                      style: TextStyle(
                          fontSize: 12, color: VelvetColors.textTertiary)),
                ),
              ]),
              if (row != null) ...[
                FedSection(l.federationDiscoverySection),
                FedCard(children: [
                  FedSwitchRow(
                    title: l.federationAskPeerSimilar,
                    subtitle: l.federationAskPeerSimilarNote,
                    value: row.useDiscovery,
                    busy: _discoveryBusy,
                    onChanged: (v) => _discovery(row, v),
                  ),
                ]),
              ],
              FedSection(l.federationAutoDjSection),
              FedCard(children: [
                FedRow(
                  icon: Icons.all_inclusive,
                  iconColor: djOk ? null : VelvetColors.textSecondary,
                  title: djOk
                      ? l.federationAutoDjParticipates
                      : l.federationAutoDjNotCandidate,
                  subtitle: djOk
                      ? l.federationAutoDjParticipatesNote
                      : l.federationAutoDjNotCandidateNote,
                ),
                FedSwitchRow(
                  title: l.federationShowInPicker,
                  subtitle: l.federationShowInPickerNote,
                  value: !peer.federationHidden,
                  onChanged: (v) async {
                    await ServerManager().setFederatedHidden(peer, !v);
                    if (mounted) setState(() {});
                  },
                ),
              ]),
              if (row != null) ...[
                const SizedBox(height: 18),
                Center(
                  child: FedButton(l.federationRemovePeer,
                      icon: Icons.delete_outline,
                      kind: FedButtonKind.danger,
                      height: 40,
                      fontSize: 14,
                      busy: _busy,
                      onPressed: () => _remove(row)),
                ),
              ],
            ],
          ),
          bottomNavigationBar: !peer.isSelectable
              ? null
              : FedBottomBar(children: [
                  FedButton(l.federationBrowseLibrary,
                      icon: Icons.folder_open_outlined,
                      busy: _busy,
                      onPressed: _browse),
                ]),
        );
      },
    );
  }
}
