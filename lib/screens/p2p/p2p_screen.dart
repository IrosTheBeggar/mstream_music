import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/server.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/media.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../util/p2p_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import '../discover_screen.dart';
import 'p2p_activity_screen.dart';
import 'p2p_befriend_screen.dart';
import 'p2p_controller.dart';
import 'p2p_peer_screen.dart';
import 'p2p_settings_screen.dart';

/// The discovery network for one server, from the home's NETWORK card.
/// Admins on the network get the status card, the Discover shortcut, and
/// the servers they follow; off, the consent screen; members the shortcut
/// and the downloaded libraries. Polls while on screen.
class P2pScreen extends StatefulWidget {
  final Server server;
  const P2pScreen({super.key, required this.server});

  @override
  State<P2pScreen> createState() => _P2pScreenState();
}

class _P2pScreenState extends State<P2pScreen> with WidgetsBindingObserver {
  late final P2pController c;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _filterCtrl = TextEditingController();
  bool _acceptRequests = true;
  bool _joining = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    c = P2pController(widget.server);
    WidgetsBinding.instance.addObserver(this);
    c.load().then((_) {
      _seedIdentity();
      c.startPolling();
    });
  }

  void _seedIdentity() {
    if (_seeded) return;
    final s = c.status;
    if (s == null) return;
    _seeded = true;
    _nameCtrl.text = s.serverName;
    _descCtrl.text = s.serverDescription;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.load(quiet: true);
      c.startPolling();
    } else if (state == AppLifecycleState.paused) {
      c.stopPolling();
    }
  }

  Future<void> _push(Widget screen) async {
    c.stopPolling();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    c.load(quiet: true);
    c.startPolling();
  }

  Future<void> _join() async {
    final l = AppLocalizations.of(context);
    setState(() => _joining = true);
    try {
      final r = await c.join(
          name: _nameCtrl.text,
          description: _descCtrl.text,
          acceptRequests: _acceptRequests);
      showGlobalSnack(l.p2pJoined);
      if (_acceptRequests && r.federationError != null) {
        showGlobalSnack(l.p2pInboxFailed(r.federationError!));
      }
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.p2pJoinFailed(e.message));
    } catch (e) {
      showGlobalSnack(l.p2pJoinFailed('$e'));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openDiscover() =>
      _push(const DiscoverScreen());

  // ── app bar ─────────────────────────────────────────────────────────
  (String, Color?) _subtitle(AppLocalizations l) {
    final s = c.status;
    final name = widget.server.displayName;
    if (!c.isAdmin || s == null) {
      return (name, c.memberSeesOn ? VelvetColors.success : null);
    }
    if (s.unavailable && !s.enabled) {
      return ('${l.p2pStatusUnavailable} · $name', VelvetColors.textTertiary);
    }
    if (!s.enabled) return ('${l.p2pStatusOff} · $name', VelvetColors.textTertiary);
    final who = s.serverName.isEmpty ? name : l.p2pAnnouncingAs(s.serverName);
    if (s.recovering) {
      return ('${l.p2pStatusReconnecting(s.recoveryAttempts)} · $who', VelvetColors.error);
    }
    if (s.neighbors > 0) {
      return ('${l.p2pStatusConnected} · ${l.p2pNeighborsCount(s.neighbors)} · $who',
          VelvetColors.success);
    }
    if (s.joined) return ('${l.p2pStatusSearching} · $who', VelvetColors.warning);
    return ('${l.p2pStatusNotJoined} · $who', VelvetColors.warning);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final (sub, dot) = _subtitle(l);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.p2pTitle),
                Row(children: [
                  if (dot != null) FedDot(dot),
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
            actions: [
              if (c.isAdmin && c.enabled)
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: l.p2pSettingsTitle,
                  onPressed: () => _push(P2pSettingsScreen(controller: c)),
                ),
            ],
          ),
          body: c.loading && c.status == null && c.access == null
              ? fedLoading()
              : RefreshIndicator(
                  onRefresh: () => c.load(quiet: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    children: _body(context, l),
                  ),
                ),
          bottomNavigationBar: _bottomBar(l),
        );
      },
    );
  }

  Widget? _bottomBar(AppLocalizations l) {
    final s = c.status;
    if (!c.isAdmin || s == null || s.enabled) return null;
    return FedBottomBar(children: [
      FedButton(_joining ? l.p2pJoining : l.p2pJoin,
          icon: Icons.public,
          busy: _joining,
          onPressed: s.unavailable || _nameCtrl.text.trim().isEmpty ? null : _join),
    ]);
  }

  List<Widget> _body(BuildContext context, AppLocalizations l) {
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
    final s = c.status;
    if (c.isAdmin && s != null && !s.enabled) {
      out.addAll(_joinBody(l, s));
      return out;
    }
    if (c.isAdmin && s != null) {
      out.add(s.neighbors > 0 ? _statsCard(context, l, s) : _searchingCard(l, s));
    }
    out.addAll(_fromNetwork(l));
    if (c.isAdmin && s != null) {
      out.addAll(_catalog(context, l));
    } else {
      out.addAll(_memberCatalog(l));
    }
    return out;
  }

  // ── admin, on ───────────────────────────────────────────────────────
  Widget _activityRow(AppLocalizations l, String line) {
    return InkWell(
      onTap: () => _push(P2pActivityScreen(controller: c)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        child: Row(children: [
          Icon(Icons.timeline, size: 16, color: VelvetColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: VelvetColors.textSecondary)),
          ),
          Text(l.p2pActivity,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.primary)),
          fedChevron(),
        ]),
      ),
    );
  }

  Widget _stat(String value, String label, String? sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: VelvetColors.raised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: VelvetColors.textPrimary)),
            Text(label,
                style: TextStyle(fontSize: 12, color: VelvetColors.textSecondary)),
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

  Widget _statsCard(BuildContext context, AppLocalizations l, P2pStatus s) {
    final cat = c.catalog;
    final known = cat.peers.length + (c.showIncompatible ? 0 : cat.hiddenIncompatible);
    final held = cat.held.length;
    final fmt = NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    return FedCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(children: [
          Row(children: [
            _stat('${s.neighbors}', l.p2pStatNeighbors, l.p2pStatNeighborsSub),
            const SizedBox(width: 8),
            _stat('$known', l.p2pStatKnown,
                l.p2pStatKnownSub(cat.hiddenIncompatible, s.blockedPeers.length)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _stat(
                s.autoFetchCount > 0 ? l.p2pStatHeldOf(held, s.autoFetchCount) : '$held',
                l.p2pStatHeld,
                l.p2pStatStorage(fmtBytes(cat.storageUsedBytes), fmtBytes(cat.storageCapBytes))),
            const SizedBox(width: 8),
            _stat(fmt.format(cat.heldTrackTotal), l.p2pStatTracks, l.p2pStatTracksSub(held)),
          ]),
        ]),
      ),
      _activityRow(l, c.latestActivity?.message ?? l.p2pActivitySubtitle),
    ]);
  }

  Widget _searchingCard(AppLocalizations l, P2pStatus s) {
    final recovering = s.recovering;
    return FedCard(children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            FedTile(recovering ? Icons.restart_alt : Icons.settings_input_antenna,
                color: recovering ? VelvetColors.error : VelvetColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recovering ? l.p2pReconnectingTitle : l.p2pSearchingTitle,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: VelvetColors.textPrimary)),
                  Text(
                      recovering
                          ? l.p2pReconnectingBody(s.recoveryAttempts)
                          : l.p2pSearchingBody,
                      style: TextStyle(
                          fontSize: 13, height: 1.3, color: VelvetColors.textSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: VelvetColors.raised,
                color: recovering ? VelvetColors.error : VelvetColors.primary),
          ),
        ]),
      ),
      _activityRow(l, c.latestActivity?.message ?? l.p2pActivitySubtitle),
    ]);
  }

  List<Widget> _fromNetwork(AppLocalizations l) {
    final playing = MediaManager().audioHandler.mediaItem.valueOrNull != null;
    final count = c.isAdmin && c.enabled ? c.catalog.held.length : c.held.length;
    final on = c.isAdmin ? c.enabled : c.memberSeesOn;
    if (!on) return const [];
    return [
      FedSection(l.p2pFromNetwork, first: c.isAdmin ? false : true),
      FedCard(children: [
        FedRow(
          icon: Icons.auto_awesome,
          title: l.p2pFindSimilar,
          subtitle: playing ? l.p2pFindSimilarSub(count) : l.p2pFindSimilarNothingPlaying,
          subtitleLines: 2,
          trailing: fedChevron(),
          onTap: _openDiscover,
        ),
        if (!c.isAdmin)
          FedSwitchRow(
            title: l.discoverNewArtistsOnly,
            subtitle: l.p2pNewArtistsOnlySub,
            value: SettingsManager().discoverNewArtistsOnly,
            onChanged: (v) async {
              await SettingsManager().setDiscoverNewArtistsOnly(v);
              if (mounted) setState(() {});
            },
          ),
      ]),
    ];
  }

  List<Widget> _catalog(BuildContext context, AppLocalizations l) {
    final cat = c.catalog;
    final q = _filterCtrl.text.trim().toLowerCase();
    final peers = q.isEmpty
        ? cat.peers
        : cat.peers
            .where((p) =>
                (p.name ?? '').toLowerCase().contains(q) ||
                (p.description ?? '').toLowerCase().contains(q) ||
                p.endpointId.toLowerCase().contains(q))
            .toList();
    return [
      FedSection(l.p2pServersYouFollow),
      if (cat.peers.length > 5) ...[
        TextField(
          controller: _filterCtrl,
          style: TextStyle(color: VelvetColors.textPrimary),
          decoration: fedInputDecoration(l.p2pSearchServers,
              suffix: Icon(Icons.search, color: VelvetColors.textTertiary)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
      ],
      FedCard(children: [
        if (cat.peers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(l.p2pNoServersYet,
                style: TextStyle(color: VelvetColors.textSecondary, height: 1.4)),
          ),
        for (final p in peers) _peerRow(context, l, p),
        if (cat.hiddenIncompatible > 0 || c.showIncompatible)
          InkWell(
            onTap: c.toggleIncompatible,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              child: Row(children: [
                Expanded(
                  child: Text(
                      c.showIncompatible
                          ? l.p2pChipIncompatible
                          : l.p2pHiddenIncompatible(cat.hiddenIncompatible),
                      style: TextStyle(fontSize: 12, color: VelvetColors.textTertiary)),
                ),
                Text(c.showIncompatible ? l.p2pHide : l.p2pShow,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.primary)),
              ]),
            ),
          ),
        InkWell(
          onTap: () => _push(P2pBefriendScreen(controller: c)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.add, color: VelvetColors.primary, size: 22),
              const SizedBox(width: 12),
              Text(l.p2pBefriend,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: VelvetColors.primary)),
            ]),
          ),
        ),
      ]),
    ];
  }

  Widget _peerRow(BuildContext context, AppLocalizations l, P2pPeer p) {
    final bits = [
      p.online ? l.p2pOnline : l.p2pOfflineFor(fmtAgo(context, p.updatedAt)),
      l.p2pTracksCount(p.trackCount),
      if (p.seeders > 0) l.p2pSeedersCount(p.seeders),
    ];
    final chips = <(String, Color)?>[
      if (p.updateAvailable)
        (l.p2pChipUpdate, VelvetColors.warning)
      else if (p.downloaded)
        (l.p2pChipDownloaded, VelvetColors.success)
      else
        (l.p2pChipNotDownloaded, VelvetColors.textTertiary),
      if (p.fetched?.pinned == true) (l.p2pChipPinned, VelvetColors.textSecondary),
      if (p.compatible == false) (l.p2pChipIncompatible, VelvetColors.error),
      switch (c.relationship(p)) {
        P2pFederationState.federated => (l.p2pChipFederated, VelvetColors.primary),
        P2pFederationState.theirs => (l.p2pChipTheyAsked, const Color(0xFF64B5F6)),
        P2pFederationState.sent => (l.p2pChipRequestSent, VelvetColors.textSecondary),
        P2pFederationState.none => null,
      },
    ].whereType<(String, Color)>().toList();
    return InkWell(
      onTap: () => _push(P2pPeerScreen(controller: c, endpointId: p.endpointId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          const FedTile(Icons.public),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name ?? p.shortId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary)),
                Row(children: [
                  FedDot(p.online ? VelvetColors.success : VelvetColors.textTertiary),
                  Expanded(
                    child: Text(bits.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: VelvetColors.textSecondary)),
                  ),
                ]),
                if (chips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final (label, color) in chips) P2pChip(label, color),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          fedChevron(),
        ]),
      ),
    );
  }

  // ── member ──────────────────────────────────────────────────────────
  List<Widget> _memberCatalog(AppLocalizations l) {
    final name = widget.server.displayName;
    final out = <Widget>[];
    if (c.memberSeesOn) {
      out.add(FedSection(l.p2pServersOnNetwork));
      out.add(FedCard(children: [
        if (c.held.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(l.discoverNetworkWarmingUp,
                style: TextStyle(color: VelvetColors.textSecondary, height: 1.4)),
          ),
        for (final h in c.held)
          FedRow(
            icon: Icons.public,
            title: h.name.isEmpty ? l.p2pUnnamedServer : h.name,
            subtitle: l.p2pTracksCount(h.trackCount),
            trailing: P2pChip(l.p2pChipDownloaded, VelvetColors.success),
          ),
      ]));
    }
    final access = c.access;
    String note;
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
        note = c.memberSeesOn ? l.p2pMemberNote(name) : '${l.p2pMemberOffNote(name)} ${l.p2pMemberNote(name)}';
    }
    out.add(const SizedBox(height: 14));
    out.add(FedNote(note, icon: Icons.lock_outline, color: VelvetColors.textSecondary));
    return out;
  }

  // ── admin, off: consent ─────────────────────────────────────────────
  List<Widget> _joinBody(AppLocalizations l, P2pStatus s) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
        child: Text(l.p2pJoinTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: VelvetColors.textPrimary)),
      ),
      FedSection(l.p2pWhatShared),
      FedCard(children: [
        FedRow(icon: Icons.storage_outlined, iconColor: VelvetColors.success, title: l.p2pShared1, subtitle: l.p2pShared1Sub, subtitleLines: 2),
        FedRow(icon: Icons.public, iconColor: VelvetColors.success, title: l.p2pShared2, subtitle: l.p2pShared2Sub, subtitleLines: 2),
      ]),
      FedSection(l.p2pHowYouAppear),
      TextField(
        controller: _nameCtrl,
        maxLength: 64,
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: fedInputDecoration(l.p2pServerName).copyWith(counterText: ''),
        onChanged: (_) => setState(() {}),
      ),
      FedHint(l.p2pServerNameHint),
      const SizedBox(height: 10),
      TextField(
        controller: _descCtrl,
        maxLength: 180,
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: fedInputDecoration(l.p2pDescription).copyWith(counterText: ''),
      ),
      FedHint(l.p2pDescriptionHint),
      const SizedBox(height: 10),
      FedCard(children: [
        FedSwitchRow(
          title: l.p2pAlsoAcceptRequests,
          subtitle: l.p2pAlsoAcceptRequestsSub,
          value: _acceptRequests,
          onChanged: (v) => setState(() => _acceptRequests = v),
        ),
      ]),
      const SizedBox(height: 10),
      if (s.unavailable)
        FedNote(l.p2pUnavailableNote, color: VelvetColors.error)
      else if (!s.binaryFound)
        FedNote(l.p2pWillDownloadNote, icon: Icons.download_outlined, color: VelvetColors.textSecondary)
      else
        FedHint(l.p2pAdminOnlyNote),
    ];
  }
}

/// A small state chip on a catalog row.
class P2pChip extends StatelessWidget {
  final String label;
  final Color color;
  const P2pChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
