import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../admin_api.dart';
import '../admin_widgets.dart';

/// "Federation" — pairing this server with other mStream servers.
///
/// Two halves that read alike but point opposite ways:
///
///  - **Keys you issued** are credentials this server hands out. Someone else
///    pastes the ticket and can then read the libraries the key grants.
///  - **Servers you read** are tickets handed to *this* server, so it can pull
///    from someone else's libraries.
///
/// The server reports three independent states and the UI has to keep them
/// apart: `available` (the iroh native binary exists for this platform at all),
/// `enabled` (the admin switched it on), and `running`/`online` (the endpoint
/// actually came up and reached a relay). An unavailable platform gets an
/// explanation instead of a dead toggle.
class FederationView extends StatelessWidget {
  final AdminApi api;
  const FederationView({super.key, required this.api});

  /// Federation status plus, when it is actually up, the key and peer rows.
  /// Keys/peers are skipped while it is off — those routes are meaningless
  /// then and only produce noise in the error channel.
  Future<_FedData> _load() async {
    final fed = await api.getFederation();
    if (fed['enabled'] != true || fed['available'] != true) {
      return _FedData(fed, const [], const []);
    }
    final rest = await Future.wait([
      api.federationKeys(),
      api.federationPeers(),
    ]);
    return _FedData(fed, rest[0], rest[1]);
  }

  @override
  Widget build(BuildContext context) {
    return AdminAsync<_FedData>(
      loader: _load,
      builder: (context, data, reload) {
        final l = AppLocalizations.of(context);
        final fed = data.fed;
        final available = fed['available'] == true;
        final enabled = fed['enabled'] == true;
        return AdminViewBody(children: [
          _StatusCard(api: api, fed: fed, reload: reload),
          if (available && enabled) ...[
            _KeysCard(api: api, keys: data.keys, reload: reload),
            _PeersCard(api: api, peers: data.peers, reload: reload),
          ],
          if (!available)
            AdminCard(
              title: l.adminFederationUnsupportedTitle,
              icon: Icons.block,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l.adminFederationUnsupportedBody,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
        ]);
      },
    );
  }
}

class _FedData {
  final Map<String, dynamic> fed;
  final List<dynamic> keys;
  final List<dynamic> peers;
  const _FedData(this.fed, this.keys, this.peers);
}

// ── Status ────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final AdminApi api;
  final Map<String, dynamic> fed;
  final Future<void> Function() reload;
  const _StatusCard({required this.api, required this.fed, required this.reload});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final available = fed['available'] == true;
    final enabled = fed['enabled'] == true;
    final running = fed['running'] == true;
    final online = fed['online'] == true;

    final (String label, Color color, IconData icon) = switch ((
      available,
      enabled,
      running,
      online
    )) {
      (false, _, _, _) => (l.adminNotAvailable, Colors.grey, Icons.block),
      (_, false, _, _) => (l.adminDisabled, Colors.grey, Icons.pause_circle_outline),
      (_, _, false, _) => (l.adminFederationStopped, Colors.orange, Icons.error_outline),
      (_, _, _, false) => (l.adminFederationOffline, Colors.orange, Icons.cloud_off),
      _ => (l.adminFederationOnline, Colors.green, Icons.cloud_done),
    };

    return AdminCard(
      title: l.adminFederation,
      icon: Icons.hub_outlined,
      trailing: [StatusPill(label: label, color: color, icon: icon)],
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l.adminFederationDescription,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        AdminAsyncSwitch(
          title: l.adminFederationEnableTitle,
          subtitle: l.adminFederationEnableSubtitle,
          value: enabled,
          enabled: available,
          onChanged: (v) async {
            final r = await api.setFederationEnabled(v);
            // Stored, but the endpoint refused to come up here.
            if (v && r['available'] == false && context.mounted) {
              adminToast(context, l.adminFederationUnsupportedBody, error: true);
            }
            await reload();
          },
        ),
        if (available && enabled) ...[
          const Divider(height: 24),
          _CopyRow(
            label: l.adminFederationEndpointId,
            value: '${fed['endpointId'] ?? ''}',
            empty: l.adminFederationStopped,
          ),
          // Stacked rather than a label/value row: a relay URL is long enough
          // that right-aligning it wraps mid-scheme on a phone.
          _CopyRow(
            label: l.adminFederationRelay,
            value: '${fed['relayUrl'] ?? ''}',
            empty: l.adminFederationOffline,
          ),
        ],
      ],
    );
  }
}

/// An info row whose value can be copied — endpoint ids and tickets are long
/// opaque strings that exist to be pasted somewhere else.
class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final String? empty;
  const _CopyRow({required this.label, required this.value, this.empty});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (value.isEmpty) return AdminInfoRow(label, empty ?? '—');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: l.adminFederationCopy,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) adminToast(context, l.adminFederationCopied);
          },
        ),
      ]),
    );
  }
}

// ── Keys this server issued ───────────────────────────────────────────────

class _KeysCard extends StatelessWidget {
  final AdminApi api;
  final List<dynamic> keys;
  final Future<void> Function() reload;
  const _KeysCard({required this.api, required this.keys, required this.reload});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminCard(
      title: l.adminFederationKeysTitle,
      subtitle: l.adminFederationKeysSubtitle,
      icon: Icons.key_outlined,
      children: [
        if (keys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l.adminFederationNoKeys,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          for (final k in keys)
            _KeyTile(
                api: api, row: Map<String, dynamic>.from(k), reload: reload),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminActionButton(
            label: l.adminFederationMintTitle,
            icon: Icons.add,
            tonal: true,
            onPressed: () => _mint(context),
          ),
        ),
      ],
    );
  }

  Future<void> _mint(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final dirs = await api.getDirectories();
    if (!context.mounted) return;
    final vpaths = dirs.keys.toList()..sort();
    if (vpaths.isEmpty) {
      adminToast(context, l.adminAddLibraryFirst, error: true);
      return;
    }
    final minted = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MintKeyDialog(api: api, vpaths: vpaths),
    );
    if (minted == null) return;
    // Show the ticket BEFORE reloading. `reload` rebuilds the AdminAsync
    // subtree, which disposes this card and unmounts `context` — reloading
    // first would silently swallow the one-time ticket.
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _TicketDialog(ticket: '${minted['ticket'] ?? ''}'),
      );
    }
    await reload();
  }
}

class _KeyTile extends StatelessWidget {
  final AdminApi api;
  final Map<String, dynamic> row;
  final Future<void> Function() reload;
  const _KeyTile({required this.api, required this.row, required this.reload});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final id = (row['id'] as num).toInt();
    final name = '${row['name'] ?? ''}';
    final libs = (row['library_names'] as List?)?.join(', ') ?? '';
    final expired = row['is_expired'] == 1 || row['is_expired'] == true;
    final bound = '${row['bound_endpoint_id'] ?? ''}'.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          if (expired)
            StatusPill(
                label: l.adminFederationExpired,
                color: scheme.error,
                icon: Icons.timer_off),
          PopupMenuButton<String>(
            tooltip: '',
            onSelected: (v) => _act(context, v, id, name),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'ticket', child: Text(l.adminFederationCopyTicket)),
              PopupMenuItem(
                  value: 'limits', child: Text(l.adminFederationEditLimits)),
              if (bound)
                PopupMenuItem(
                    value: 'unbind',
                    child: Text(l.adminFederationResetBinding)),
              PopupMenuItem(
                  value: 'revoke',
                  child: Text(l.adminFederationRevoke,
                      style: TextStyle(color: scheme.error))),
            ],
          ),
        ]),
        Text(libs, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 2),
        Wrap(spacing: 12, runSpacing: 2, children: [
          Text(_limits(l), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          Text(
              l.adminFederationUsageToday(
                  _bytes(row['usage_today_bytes'] ?? 0)),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          Text(
              bound
                  ? l.adminFederationBound
                  : l.adminFederationUnbound,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ]),
        const Divider(height: 20),
      ]),
    );
  }

  /// "1500 kbps · 2048 MB/day · 3 streams", with 0 rendered as unlimited.
  String _limits(AppLocalizations l) {
    final kbps = (row['stream_kbps'] as num?)?.toInt() ?? 0;
    final mb = (row['daily_mb'] as num?)?.toInt() ?? 0;
    final streams = (row['max_streams'] as num?)?.toInt() ?? 0;
    final u = l.adminFederationUnlimited;
    return [
      kbps == 0 ? u : l.adminFederationKbps(kbps),
      mb == 0 ? u : l.adminFederationMbPerDay(mb),
      streams == 0 ? u : l.adminFederationStreams(streams),
    ].join(' · ');
  }

  Future<void> _act(
      BuildContext context, String action, int id, String name) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case 'ticket':
        final t = '${row['ticket'] ?? ''}';
        if (t.isEmpty) {
          adminToast(context, l.adminFederationNoTicket, error: true);
          return;
        }
        await showDialog<void>(
            context: context, builder: (_) => _TicketDialog(ticket: t));
      case 'limits':
        final saved = await showDialog<bool>(
          context: context,
          builder: (_) => _LimitsDialog(api: api, row: row),
        );
        if (saved == true) await reload();
      case 'unbind':
        final ok = await runAdminAction(
            context, () => api.resetFederationKeyBinding(id),
            success: l.adminFederationResetBindingDone);
        if (ok) await reload();
      case 'revoke':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.adminFederationRevokeTitle(name)),
            content: Text(l.adminFederationRevokeBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l.adminCancel)),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error),
                child: Text(l.adminFederationRevoke),
              ),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;
        final ok = await runAdminAction(context, () => api.deleteFederationKey(id),
            success: l.adminFederationRevoked);
        if (ok) await reload();
    }
  }
}

// ── Peers this server reads from ──────────────────────────────────────────

class _PeersCard extends StatelessWidget {
  final AdminApi api;
  final List<dynamic> peers;
  final Future<void> Function() reload;
  const _PeersCard(
      {required this.api, required this.peers, required this.reload});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminCard(
      title: l.adminFederationPeersTitle,
      subtitle: l.adminFederationPeersSubtitle,
      icon: Icons.dns_outlined,
      children: [
        if (peers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l.adminFederationNoPeers,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          for (final p in peers)
            _PeerTile(
                api: api, row: Map<String, dynamic>.from(p), reload: reload),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminActionButton(
            label: l.adminFederationAddPeer,
            icon: Icons.add,
            tonal: true,
            onPressed: () async {
              final added = await showDialog<bool>(
                context: context,
                builder: (_) => _AddPeerDialog(api: api),
              );
              if (added == true) await reload();
            },
          ),
        ),
      ],
    );
  }
}

class _PeerTile extends StatelessWidget {
  final AdminApi api;
  final Map<String, dynamic> row;
  final Future<void> Function() reload;
  const _PeerTile({required this.api, required this.row, required this.reload});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final id = (row['id'] as num).toInt();
    final name = '${row['name'] ?? ''}';
    final lastSeen = '${row['last_seen'] ?? ''}';
    final status = '${row['last_status'] ?? ''}';
    final ok = status.toLowerCase() == 'ok';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle : Icons.help_outline,
              size: 16, color: ok ? Colors.green : scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          PopupMenuButton<String>(
            tooltip: '',
            onSelected: (v) => _act(context, v, id, name),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'test', child: Text(l.adminTestConnection)),
              PopupMenuItem(
                  value: 'remove',
                  child: Text(l.adminRemove,
                      style: TextStyle(color: scheme.error))),
            ],
          ),
        ]),
        Text(
          lastSeen.isEmpty
              ? l.adminFederationNeverSeen
              : l.adminFederationLastSeen(lastSeen),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        // The server's own diagnosis of the last probe ("unreachable: …").
        // Without it an unreachable peer is just a grey dot with no reason.
        if (!ok && status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(l.adminConnectionFailed(status),
                style: TextStyle(color: scheme.error, fontSize: 12)),
          ),
        AdminAsyncSwitch(
          title: l.adminFederationUseDiscovery,
          subtitle: l.adminFederationUseDiscoverySubtitle,
          value: row['use_discovery'] == 1 || row['use_discovery'] == true,
          onChanged: (v) => api.setFederationPeerDiscovery(id, v),
        ),
        const Divider(height: 20),
      ]),
    );
  }

  Future<void> _act(
      BuildContext context, String action, int id, String name) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case 'test':
        final ok = await runAdminAction(
            context, () => api.testFederationPeer(id),
            success: l.adminFederationTestOk);
        if (ok) await reload();
      case 'remove':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.adminFederationRemovePeerTitle(name)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l.adminCancel)),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error),
                child: Text(l.adminRemove),
              ),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;
        final ok = await runAdminAction(
            context, () => api.deleteFederationPeer(id),
            success: l.adminFederationPeerRemoved);
        if (ok) await reload();
    }
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────

/// Shows a minted key's ticket. This is the only time the full ticket is
/// handed back for a fresh key, so it is deliberately a blocking dialog with
/// copy rather than a toast.
class _TicketDialog extends StatelessWidget {
  final String ticket;
  const _TicketDialog({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.adminFederationTicketTitle),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.adminFederationTicketBody,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(ticket,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.adminClose)),
        FilledButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: ticket));
            if (context.mounted) {
              adminToast(context, l.adminFederationCopied);
              Navigator.pop(context);
            }
          },
          label: Text(l.adminFederationCopy),
        ),
      ],
    );
  }
}

class _MintKeyDialog extends StatefulWidget {
  final AdminApi api;
  final List<String> vpaths;
  const _MintKeyDialog({required this.api, required this.vpaths});

  @override
  State<_MintKeyDialog> createState() => _MintKeyDialogState();
}

class _MintKeyDialogState extends State<_MintKeyDialog> {
  final _name = TextEditingController();
  final _kbps = TextEditingController(text: '0');
  final _mb = TextEditingController(text: '0');
  final _streams = TextEditingController(text: '0');
  final Set<String> _sel = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _kbps.dispose();
    _mb.dispose();
    _streams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.adminFederationMintTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l.adminKeyNameLabel),
              // Mint is gated on this being non-empty, so typing has to rebuild
              // — otherwise filling the name last leaves the button dead.
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l.adminLibraryAccessHeader,
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            for (final v in widget.vpaths)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(v),
                value: _sel.contains(v),
                onChanged: (on) => setState(
                    () => on == true ? _sel.add(v) : _sel.remove(v)),
              ),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l.adminFederationLimitsTitle,
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l.adminFederationUnlimitedHint,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            _numField(_kbps, l.adminFederationStreamKbps),
            const SizedBox(height: 8),
            _numField(_mb, l.adminFederationDailyMb),
            const SizedBox(height: 8),
            _numField(_streams, l.adminFederationMaxStreams),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.adminCancel)),
        FilledButton(
          onPressed: (_busy || _name.text.trim().isEmpty || _sel.isEmpty)
              ? null
              : _submit,
          child: Text(l.adminMintKey),
        ),
      ],
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );

  Future<void> _submit() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final minted = await widget.api.mintFederationKey(
        _name.text.trim(),
        _sel.toList(),
        streamKbps: int.tryParse(_kbps.text.trim()) ?? 0,
        dailyMb: int.tryParse(_mb.text.trim()) ?? 0,
        maxStreams: int.tryParse(_streams.text.trim()) ?? 0,
      );
      navigator.pop(minted);
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      adminToast(context, e.message, error: true);
    }
  }
}

class _LimitsDialog extends StatefulWidget {
  final AdminApi api;
  final Map<String, dynamic> row;
  const _LimitsDialog({required this.api, required this.row});

  @override
  State<_LimitsDialog> createState() => _LimitsDialogState();
}

class _LimitsDialogState extends State<_LimitsDialog> {
  late final _kbps = TextEditingController(
      text: '${(widget.row['stream_kbps'] as num?)?.toInt() ?? 0}');
  late final _mb = TextEditingController(
      text: '${(widget.row['daily_mb'] as num?)?.toInt() ?? 0}');
  late final _streams = TextEditingController(
      text: '${(widget.row['max_streams'] as num?)?.toInt() ?? 0}');
  bool _busy = false;

  @override
  void dispose() {
    _kbps.dispose();
    _mb.dispose();
    _streams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.adminFederationEditLimits),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l.adminFederationUnlimitedHint,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _kbps,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l.adminFederationStreamKbps)),
          const SizedBox(height: 8),
          TextField(
              controller: _mb,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.adminFederationDailyMb)),
          const SizedBox(height: 8),
          TextField(
              controller: _streams,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l.adminFederationMaxStreams)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.adminCancel)),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l.adminSave)),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await runAdminAction(
      context,
      () => widget.api.setFederationKeyLimits(
            (widget.row['id'] as num).toInt(),
            streamKbps: int.tryParse(_kbps.text.trim()) ?? 0,
            dailyMb: int.tryParse(_mb.text.trim()) ?? 0,
            maxStreams: int.tryParse(_streams.text.trim()) ?? 0,
          ),
      success: l.adminFederationLimitsSaved,
    );
    if (!mounted) return;
    if (ok) {
      navigator.pop(true);
    } else {
      setState(() => _busy = false);
    }
  }
}

class _AddPeerDialog extends StatefulWidget {
  final AdminApi api;
  const _AddPeerDialog({required this.api});

  @override
  State<_AddPeerDialog> createState() => _AddPeerDialogState();
}

class _AddPeerDialogState extends State<_AddPeerDialog> {
  final _ticket = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ticket.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.adminFederationAddPeer),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.adminFederationAddPeerBody,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: _ticket,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                  labelText: l.adminFederationTicketLabel,
                  alignLabelWithHint: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration:
                  InputDecoration(labelText: l.adminFederationPeerNameLabel),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.adminCancel)),
        FilledButton(
          onPressed:
              (_busy || _ticket.text.trim().isEmpty) ? null : _submit,
          child: Text(l.adminAdd),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await runAdminAction(
      context,
      () => widget.api.addFederationPeer(_ticket.text.trim(),
          name: _name.text.trim()),
      success: l.adminFederationPeerAdded,
    );
    if (!mounted) return;
    if (ok) {
      navigator.pop(true);
    } else {
      setState(() => _busy = false);
    }
  }
}

/// Compact byte formatting for the per-key daily usage figure.
String _bytes(Object v) {
  final n = (v is num) ? v.toDouble() : 0.0;
  if (n < 1024) return '${n.toInt()} B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  if (n < 1024 * 1024 * 1024) return '${(n / 1048576).toStringAsFixed(1)} MB';
  return '${(n / 1073741824).toStringAsFixed(2)} GB';
}
