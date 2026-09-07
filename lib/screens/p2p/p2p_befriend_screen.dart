import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import '../../widgets/iroh_scanner.dart';
import 'p2p_controller.dart';

/// Befriend a server by its endpoint ticket (paste, scan, type), with
/// "Remember this friend" for the config; below it, your own ticket to
/// hand out — an address, not a credential.
class P2pBefriendScreen extends StatefulWidget {
  final P2pController controller;
  const P2pBefriendScreen({super.key, required this.controller});

  @override
  State<P2pBefriendScreen> createState() => _P2pBefriendScreenState();
}

class _P2pBefriendScreenState extends State<P2pBefriendScreen> {
  final _ticketCtrl = TextEditingController();
  bool _pasted = false;
  bool _remember = true;
  bool _joining = false;

  P2pController get c => widget.controller;

  @override
  void dispose() {
    _ticketCtrl.dispose();
    super.dispose();
  }

  /// The sidecar's ticket is an iroh endpoint string; anything that is
  /// not one whitespace-free token cannot be one.
  bool get _looksLikeTicket {
    final t = _ticketCtrl.text.trim();
    return t.length >= 16 && !t.contains(RegExp(r'\s'));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _ticketCtrl.text = text;
      _pasted = true;
    });
  }

  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final raw = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => IrohScannerPage(title: l.p2pScannerTitle)));
    if (raw == null || raw.isEmpty) return;
    setState(() {
      _ticketCtrl.text = raw.trim();
      _pasted = false;
    });
  }

  Future<void> _join() async {
    final l = AppLocalizations.of(context);
    setState(() => _joining = true);
    try {
      await c.api.join(_ticketCtrl.text, persist: _remember);
      await c.load(quiet: true);
      showGlobalSnack(l.p2pJoinedFriend);
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.p2pJoinFriendFailed(e.message));
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _share(String ticket) async {
    final l = AppLocalizations.of(context);
    await SharePlus.instance.share(ShareParams(
      text: l.p2pShareMessage(ticket),
      subject: l.p2pShareSubject,
    ));
  }

  Future<void> _copy(String ticket) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: ticket));
    showGlobalSnack(l.p2pTicketCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mine = c.status?.ticket;
    final who = c.status?.serverName.isNotEmpty == true
        ? c.status!.serverName
        : c.server.displayName;
    final text = _ticketCtrl.text.trim();
    final problem = text.isNotEmpty && !_looksLikeTicket;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(l.p2pBefriend),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          Row(children: [
            Expanded(
                child: FedButton(l.federationPaste,
                    icon: Icons.content_paste, kind: FedButtonKind.outline, onPressed: _paste)),
            const SizedBox(width: 10),
            Expanded(
                child: FedButton(l.p2pScanQr,
                    icon: Icons.qr_code_scanner, kind: FedButtonKind.outline, onPressed: _scan)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _ticketCtrl,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(
                fontFamily: 'monospace', fontSize: 12, color: VelvetColors.textPrimary),
            decoration: fedInputDecoration(l.p2pTheirTicket, hint: 'endpoint…'),
            onChanged: (_) => setState(() => _pasted = false),
          ),
          if (problem)
            FedHint(l.p2pNotATicket, color: VelvetColors.error)
          else if (_pasted)
            FedHint(l.p2pTicketPasted)
          else
            FedHint(l.p2pTheirTicketHint),
          const SizedBox(height: 10),
          FedCard(children: [
            FedSwitchRow(
              title: l.p2pRememberFriend,
              subtitle: l.p2pRememberFriendSub,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v),
            ),
          ]),
          FedSection(l.p2pInviteFriend),
          FedCard(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                  mine == null ? l.p2pTicketNotReady : l.p2pYourTicketNote(who),
                  style: TextStyle(
                      fontSize: 13, height: 1.35, color: VelvetColors.textSecondary)),
            ),
            if (mine != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: QrImageView(data: mine, size: 96, backgroundColor: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mine,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.35,
                                  color: VelvetColors.textSecondary)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            FedButton(l.federationSendByText,
                                icon: Icons.chat_bubble_outline,
                                kind: FedButtonKind.outline,
                                height: 34,
                                fontSize: 13,
                                onPressed: () => _share(mine)),
                            FedButton(l.copy,
                                icon: Icons.content_copy,
                                kind: FedButtonKind.text,
                                height: 34,
                                fontSize: 13,
                                onPressed: () => _copy(mine)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]),
        ],
      ),
      bottomNavigationBar: FedBottomBar(children: [
        FedButton(_joining ? l.p2pJoining : l.p2pJoinFriend,
            icon: Icons.add,
            busy: _joining,
            onPressed: _looksLikeTicket && !_joining ? _join : null),
      ]),
    );
  }
}
