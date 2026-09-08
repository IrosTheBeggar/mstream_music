import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/server.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/server_list.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import 'add_peer_screen.dart';
import 'federation_controller.dart';
import 'federation_settings_screen.dart';
import 'key_detail_screen.dart';
import 'pairing_request_screen.dart';
import 'peer_detail_screen.dart';
import 'share_library_screen.dart';
import 'ticket_screen.dart';

/// Federation for one server, from the home's NETWORK card. Three
/// sections and one primary action: the libraries shared with you (any
/// signed-in user; tap to browse), the pairing requests and the tickets
/// you minted (admins), and Share a library. Off, platform-unavailable,
/// member and restricted states each say what they are.
class FederationScreen extends StatefulWidget {
  final Server parent;
  const FederationScreen({super.key, required this.parent});

  @override
  State<FederationScreen> createState() => _FederationScreenState();
}

class _FederationScreenState extends State<FederationScreen>
    with WidgetsBindingObserver {
  late final FederationController c;
  bool _turningOn = false;

  @override
  void initState() {
    super.initState();
    c = FederationController(widget.parent);
    WidgetsBinding.instance.addObserver(this);
    c.load().then((_) => c.checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.load(quiet: true).then((_) => c.checkClipboard());
    }
  }

  Future<void> _turnOn() async {
    final l = AppLocalizations.of(context);
    setState(() => _turningOn = true);
    try {
      await c.setEnabled(true);
      showGlobalSnack(c.status?.available == false
          ? l.federationUnavailableNote
          : l.federationTurnedOn);
    } catch (_) {
      showGlobalSnack(l.federationToggleFailed);
    } finally {
      if (mounted) setState(() => _turningOn = false);
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) c.load(quiet: true).then((_) => c.checkClipboard());
  }

  String _subtitle(AppLocalizations l) {
    final s = c.status;
    final name = widget.parent.displayName;
    if (!c.isAdmin || s == null) return name;
    final String state;
    if (!s.available) {
      state = l.federationStatusUnavailable;
    } else if (!s.enabled) {
      state = l.federationStatusOff;
    } else if (s.running && s.online) {
      state = l.federationStatusOn;
    } else {
      state = l.federationStatusConnecting;
    }
    return '$state · $name';
  }

  Color? _subtitleDot() {
    final s = c.status;
    if (!c.isAdmin || s == null) return null;
    if (!s.available || !s.enabled) return VelvetColors.textTertiary;
    return s.running && s.online ? VelvetColors.success : VelvetColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final dot = _subtitleDot();
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.federationTitle),
                Row(children: [
                  if (dot != null) FedDot(dot),
                  Flexible(
                    child: Text(_subtitle(l),
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
            actions: [
              if (c.isAdmin)
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: l.federationSettingsTitle,
                  onPressed: () =>
                      _push(FederationSettingsScreen(controller: c)),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: c.loading && c.status == null && c.access == null
                ? fedLoading()
                : RefreshIndicator(
                    onRefresh: () => c.load(quiet: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                      children: _body(context, l),
                    ),
                  ),
          ),
          bottomNavigationBar: _bottomBar(l),
        );
      },
    );
  }

  Widget? _bottomBar(AppLocalizations l) {
    if (!c.isAdmin || c.status == null) return null;
    if (c.enabled) {
      return FedBottomBar(children: [
        FedButton(l.federationShareLibrary,
            icon: Icons.ios_share,
            onPressed: () => _push(ShareLibraryScreen(controller: c))),
      ]);
    }
    return FedBottomBar(children: [
      FedButton(l.federationTurnOn,
          icon: Icons.hub_outlined,
          busy: _turningOn,
          onPressed: c.available ? _turnOn : null),
    ]);
  }

  List<Widget> _body(BuildContext context, AppLocalizations l) {
    final peers = c.peers;
    final admin = c.isAdmin;
    final on = admin && c.enabled;
    final out = <Widget>[];

    if (c.error != null) {
      out.add(FedCard(children: [
        FedRow(
            icon: Icons.cloud_off_outlined,
            iconColor: VelvetColors.error,
            title: l.federationLoadFailed,
            trailing: FedButton(l.federationRetry,
                kind: FedButtonKind.text,
                height: 36,
                onPressed: () => c.load(quiet: true))),
      ]));
      out.add(const SizedBox(height: 4));
    }

    if (admin && !c.enabled) {
      out.addAll(_offHero(l, admin: true));
    }

    final clip = c.clipboardTicket;
    if (on && clip != null) {
      out.add(FedCard(
        color: Color.alphaBlend(
            VelvetColors.primary.withValues(alpha: 0.10), VelvetColors.card),
        children: [
          FedRow(
            icon: Icons.content_paste,
            title: l.federationClipboardTicket,
            subtitle: clip.libraries.isEmpty
                ? l.federationTicketPreviewNoLibraries(
                    clip.serverName ?? l.federationUnnamedServer)
                : l.federationTicketPreview(
                    clip.serverName ?? l.federationUnnamedServer,
                    fmtList(clip.libraries)),
            trailing: FedButton(l.federationAddPeerAction,
                height: 36,
                fontSize: 14,
                onPressed: () => _push(
                    AddPeerScreen(controller: c, initialTicket: clip.raw))),
          ),
        ],
      ));
      out.add(const SizedBox(height: 4));
    }

    // ── Shared with you ─────────────────────────────────────────────
    if (!(admin && !c.enabled) || peers.isNotEmpty) {
      out.add(FedSection(l.federationSharedWithYou, first: out.isEmpty));
      out.add(FedCard(children: [
        if (peers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(l.federationNoPeersYet,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
        for (final p in peers) _peerRow(context, l, p),
        if (on)
          InkWell(
            onTap: () => _push(AddPeerScreen(controller: c)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(Icons.add, color: VelvetColors.primary, size: 22),
                const SizedBox(width: 12),
                Text(l.federationAddPeer,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.primary)),
              ]),
            ),
          ),
      ]));
    }

    // ── Requests ────────────────────────────────────────────────────
    if (on && c.requestsSupported && (c.requests.isNotEmpty || c.acceptRequests)) {
      out.add(FedSection(l.federationRequestsSection, badge: c.pendingInbound));
      out.add(FedCard(children: [
        if (c.requests.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(l.federationNoRequests,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
        for (final r in c.requests) _requestRow(context, l, r),
      ]));
    }

    // ── Your shared libraries ───────────────────────────────────────
    if (on) {
      out.add(FedSection(l.federationYourSharedLibraries));
      out.add(FedCard(children: [
        if (c.keys.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(l.federationNoKeysYet,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
        for (final k in c.keys) _keyRow(context, l, k),
      ]));
    }

    // ── Not an admin here ───────────────────────────────────────────
    final access = c.access;
    if (access != null && access != FederationAccess.admin) {
      final String note;
      switch (access) {
        case FederationAccess.restricted:
          note = l.federationRestrictedNote;
          break;
        case FederationAccess.disabled:
          note = l.federationDisabledNote;
          break;
        case FederationAccess.unsupported:
          note = l.federationUnsupportedNote;
          break;
        default:
          note = peers.isEmpty && widget.parent.federationAvailable == true
              ? '${l.federationOffMemberNote(widget.parent.displayName)} ${l.federationMemberNote(widget.parent.displayName)}'
              : l.federationMemberNote(widget.parent.displayName);
      }
      out.add(const SizedBox(height: 14));
      out.add(FedNote(note,
          icon: Icons.lock_outline, color: VelvetColors.textSecondary));
    }
    return out;
  }

  List<Widget> _offHero(AppLocalizations l, {required bool admin}) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
        child: Column(children: [
          const FedTile(Icons.hub_outlined, size: 84),
          const SizedBox(height: 14),
          Text(l.federationOffTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textPrimary)),
          const SizedBox(height: 10),
          Text(l.federationOffBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, height: 1.4, color: VelvetColors.textSecondary)),
        ]),
      ),
      const SizedBox(height: 8),
      FedCard(children: [
        FedRow(
            icon: Icons.lock_outline,
            iconColor: VelvetColors.success,
            title: l.federationOffPoint1Title,
            subtitle: l.federationOffPoint1Body,
            subtitleLines: 2),
        FedRow(
            icon: Icons.settings_input_antenna,
            iconColor: VelvetColors.success,
            title: l.federationOffPoint2Title,
            subtitle: l.federationOffPoint2Body,
            subtitleLines: 2),
        FedRow(
            icon: Icons.vpn_key_outlined,
            iconColor: VelvetColors.success,
            title: l.federationOffPoint3Title,
            subtitle: l.federationOffPoint3Body,
            subtitleLines: 2),
      ]),
      const SizedBox(height: 6),
      if (c.status?.available == false)
        FedNote(l.federationUnavailableNote)
      else
        FedHint(l.federationOffAdminOnly),
      const SizedBox(height: 6),
    ];
  }

  Widget _peerRow(BuildContext context, AppLocalizations l, Server p) {
    final libs = p.autoDJPaths.keys.toList()..sort();
    final ps = peerState(l, p);
    // Libraries, then the transport (the dot carries live/connecting);
    // a hidden or vanished peer says so in words instead.
    final tail = p.federationHidden || p.federationMissing ? ps.state : ps.transport;
    final subtitle = [if (libs.isNotEmpty) fmtList(libs), if (tail.isNotEmpty) tail].join(' · ');
    return FedRow(
      icon: Icons.hub_outlined,
      title: p.displayName,
      subtitle: subtitle,
      dot: ps.dot,
      trailing: fedChevron(),
      onTap: () => _push(PeerDetailScreen(controller: c, peer: p)),
    );
  }

  Widget _requestRow(BuildContext context, AppLocalizations l, FederationRequest r) {
    final name = r.peerName ?? l.federationUnnamedServer;
    final (chip, chipColor) = requestChip(l, r);
    if (r.awaitingAnswer) {
      final bits = [
        requestOfferLine(l, r),
        if (r.message != null && r.message!.isNotEmpty) '“${r.message}”',
        fmtAgo(context, r.createdAt),
      ];
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        child: Column(children: [
          Row(children: [
            const FedTile(Icons.move_to_inbox_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.federationRequestWantsToPair(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: VelvetColors.textPrimary)),
                  Text(bits.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: VelvetColors.textSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FedButton(l.federationDecline,
                  kind: FedButtonKind.muted,
                  height: 36,
                  fontSize: 14,
                  onPressed: () => _decline(l, r)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FedButton(l.federationAccept,
                  height: 36,
                  fontSize: 14,
                  onPressed: () =>
                      _push(PairingRequestScreen(controller: c, request: r))),
            ),
          ]),
        ]),
      );
    }
    Widget? trailing;
    if (r.canCancel) {
      trailing = FedButton(l.cancel,
          kind: FedButtonKind.text,
          height: 32,
          fontSize: 13,
          onPressed: () => _requestAction(l, () => c.api.cancelRequest(r.id),
              l.federationRequestCancelled));
    } else if (!r.isActive) {
      trailing = FedButton(l.federationDismiss,
          kind: FedButtonKind.text,
          height: 32,
          fontSize: 13,
          onPressed: () => _requestAction(l, () => c.api.dismissRequest(r.id), null));
    }
    final detail = [
      requestOfferLine(l, r),
      if (r.state == 'rejected' && !r.inbound && r.rejectReason != null)
        '“${r.rejectReason}”',
      if (r.state == 'rejected' && r.inbound) l.federationRequestIgnored,
    ].join(' · ');
    return FedRow(
      icon: r.inbound ? Icons.move_to_inbox_outlined : Icons.outbox_outlined,
      iconColor: VelvetColors.textSecondary,
      title: r.inbound
          ? l.federationRequestWantsToPair(name)
          : l.federationRequestToName(name),
      subtitle: '$chip · $detail',
      subtitleColor: chipColor,
      trailing: trailing,
    );
  }

  Future<void> _decline(AppLocalizations l, FederationRequest r) =>
      _requestAction(l, () => c.api.rejectRequest(r.id), l.federationRequestDeclined);

  Future<void> _requestAction(AppLocalizations l, Future<void> Function() action,
      String? success) async {
    try {
      await action();
      await c.refreshRequests();
      if (success != null) showGlobalSnack(success);
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
    } catch (_) {
      showGlobalSnack(l.federationRequestActionFailed);
    }
  }

  Widget _keyRow(BuildContext context, AppLocalizations l, FederationKey k) {
    final bits = [
      fmtList(k.libraryNames),
      if (k.expired)
        l.federationExpired
      else if (k.claimed)
        '${l.federationKeyClaimed} ✓'
      else
        l.federationKeyNotClaimed,
      if (k.claimed) l.federationKeyTodayUsage(fmtBytes(k.usageTodayBytes)),
      if (!k.claimed && k.expiresAt != null && !k.expired)
        fmtExpiry(context, k.expiresAt),
    ];
    return FedRow(
      icon: Icons.vpn_key_outlined,
      iconColor: k.expired ? VelvetColors.error : null,
      title: k.name,
      subtitle: bits.join(' · '),
      subtitleColor: k.expired
          ? VelvetColors.error
          : (k.claimed ? null : VelvetColors.warning),
      trailing: !k.claimed && k.ticket != null && !k.expired
          ? FedButton(l.federationSend,
              kind: FedButtonKind.text,
              height: 32,
              fontSize: 14,
              onPressed: () => _push(TicketScreen(ticketKey: k)))
          : fedChevron(),
      onTap: () => _push(KeyDetailScreen(controller: c, keyId: k.id)),
    );
  }
}

/// A peer's state in a word, its dot, and the transport line: hidden or
/// gone; live over its own tunnel, or dialing; live through the parent
/// (over the parent's tunnel when the parent is a Quick Connect server),
/// or waiting on that tunnel.
({String state, Color dot, String transport}) peerState(
    AppLocalizations l, Server p) {
  final sm = ServerManager();
  final parent = p.parentServer;
  final String transport;
  if (p.isDirect) {
    transport = l.federationTransportDirect;
  } else if (parent == null) {
    transport = '';
  } else if (parent.isIroh) {
    transport = l.federationTransportViaParentTunnel(parent.displayName);
  } else {
    transport = l.federationTransportViaParent(parent.displayName);
  }
  if (p.federationHidden) {
    return (state: l.federationPeerHidden, dot: VelvetColors.textTertiary, transport: transport);
  }
  if (p.federationMissing) {
    return (state: l.federationPeerMissing, dot: VelvetColors.textTertiary, transport: transport);
  }
  final bool live;
  if (p.isDirect) {
    live = sm.tunnelServes(p);
  } else if (parent == null) {
    live = false;
  } else if (parent.isIroh) {
    live = sm.tunnelServes(parent);
  } else {
    live = true;
  }
  return live
      ? (state: l.federationPeerLive, dot: VelvetColors.success, transport: transport)
      : (state: l.federationPeerConnecting, dot: VelvetColors.warning, transport: transport);
}
