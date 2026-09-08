import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../util/federation_ticket.dart';
import '../../util/server_tree.dart';
import '../../widgets/federation_widgets.dart';
import '../../widgets/iroh_scanner.dart';
import 'federation_controller.dart';

/// Add a friend's server by its ticket: paste it, scan it, or arrive with
/// it (the clipboard banner, and one day a tapped link). The preview —
/// name, libraries, expiry, all read off the ticket — comes before Add;
/// the server re-parses the raw string itself.
class AddPeerScreen extends StatefulWidget {
  final FederationController controller;
  final String? initialTicket;
  const AddPeerScreen({super.key, required this.controller, this.initialTicket});

  @override
  State<AddPeerScreen> createState() => _AddPeerScreenState();
}

class _AddPeerScreenState extends State<AddPeerScreen> {
  final _ticketCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  FederationTicketResult? _parsed;
  bool _pasted = false;
  bool _adding = false;

  FederationController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTicket;
    if (t != null && t.isNotEmpty) {
      _ticketCtrl.text = t;
      _pasted = true;
      _parse();
    }
  }

  @override
  void dispose() {
    _ticketCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _ticketCtrl.text.trim();
    setState(() {
      _parsed = text.isEmpty ? null : FederationTicket.parse(text);
      final name = _parsed?.ticket?.serverName;
      if (name != null && _nameCtrl.text.trim().isEmpty) _nameCtrl.text = name;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _ticketCtrl.text = FederationTicket.extract(text) ?? text;
    _pasted = true;
    _parse();
  }

  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final raw = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => IrohScannerPage(title: l.federationScannerTitle)));
    if (raw == null || raw.isEmpty) return;
    _ticketCtrl.text = FederationTicket.extract(raw) ?? raw;
    _pasted = false;
    _parse();
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final t = _parsed?.ticket;
    if (t == null) return;
    setState(() => _adding = true);
    try {
      final row = await c.api.addPeer(ticket: t.raw, name: _nameCtrl.text);
      await c.refreshPeers();
      c.dismissClipboard();
      showGlobalSnack(l.federationPeerAdded(row.name));
      if (mounted) Navigator.of(context).pop(true);
    } on FederationAdminException catch (e) {
      showGlobalSnack(e.message.toLowerCase().contains('already')
          ? l.federationPeerAlreadyAdded
          : l.federationActionFailed(e.message));
    } catch (_) {
      showGlobalSnack(l.federationAddPeerFailed);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final parsed = _parsed;
    final ticket = parsed?.ticket;
    String? problem;
    if (parsed != null && ticket == null) {
      problem = parsed.error == FederationTicketError.tooNew
          ? l.federationTicketTooNew
          : l.federationNotATicket;
    } else if (ticket != null && ticket.isExpired) {
      problem = l.federationTicketExpiredNote;
    }
    final ready = ticket != null && problem == null && !_adding;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false)),
        title: Text(l.federationAddPeer),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          Row(children: [
            Expanded(
                child: FedButton(l.federationPaste,
                    icon: Icons.content_paste,
                    kind: FedButtonKind.outline,
                    onPressed: _paste)),
            const SizedBox(width: 10),
            Expanded(
                child: FedButton(l.federationScanQr,
                    icon: Icons.qr_code_scanner,
                    kind: FedButtonKind.outline,
                    onPressed: _scan)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _ticketCtrl,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: VelvetColors.textPrimary),
            decoration: fedInputDecoration(l.federationTheirTicket,
                hint: 'mstrfed1:…'),
            onChanged: (_) {
              _pasted = false;
              _parse();
            },
          ),
          if (problem != null)
            FedHint(problem, color: VelvetColors.error)
          else if (_pasted)
            FedHint(l.federationTicketPasted),
          if (ticket != null && problem == null) ...[
            const SizedBox(height: 10),
            FedCard(
              color: Color.alphaBlend(
                  VelvetColors.success.withValues(alpha: 0.10),
                  VelvetColors.card),
              children: [
                FedRow(
                  icon: Icons.check,
                  iconColor: VelvetColors.success,
                  title: ticket.serverName ?? l.federationUnnamedServer,
                  subtitle: [
                    ticket.libraries.isEmpty
                        ? l.federationSharesUnknown
                        : l.federationSharesLibraries(fmtList(ticket.libraries)),
                    if (ticket.expiresAt != null)
                      l.federationValidUntil(fmtDate(context, ticket.expiresAt!)),
                  ].join(' · '),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              maxLength: 64,
              style: TextStyle(color: VelvetColors.textPrimary),
              decoration: fedInputDecoration(l.federationDisplayName)
                  .copyWith(counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            FedHint(l.federationDisplayNameHint),
            const SizedBox(height: 10),
            FedCard(children: [
              FedRow(
                icon: Icons.dns_outlined,
                iconColor: VelvetColors.textSecondary,
                title: l.federationAddPeerShowsUnder(c.parent.displayName),
                subtitle: l.federationAddPeerReadOnly(
                    kPeerBranch,
                    _nameCtrl.text.trim().isEmpty
                        ? (ticket.serverName ?? l.federationUnnamedServer)
                        : _nameCtrl.text.trim()),
              ),
              FedRow(
                icon: Icons.lock_outline,
                iconColor: VelvetColors.textSecondary,
                title: l.federationAddPeerDials,
                subtitle: l.federationAddPeerEncrypted,
              ),
            ]),
          ],
          const SizedBox(height: 8),
          FedHint(l.federationAddPeerNoTicket),
        ],
      ),
      bottomNavigationBar: FedBottomBar(children: [
        FedButton(l.federationAddPeerAction,
            icon: Icons.add, busy: _adding, onPressed: ready ? _add : null),
      ]),
    );
  }
}
