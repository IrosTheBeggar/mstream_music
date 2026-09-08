import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../util/p2p_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import 'p2p_controller.dart';

/// The webapp's "Federate…" compose modal as a screen: a message and the
/// libraries this server would share back if they accept (all pre-checked;
/// none = a one-way ask). Nothing changes hands until they accept.
class P2pFederateScreen extends StatefulWidget {
  final P2pController controller;
  final P2pPeer peer;
  const P2pFederateScreen({super.key, required this.controller, required this.peer});

  @override
  State<P2pFederateScreen> createState() => _P2pFederateScreenState();
}

class _P2pFederateScreenState extends State<P2pFederateScreen> {
  final _msgCtrl = TextEditingController();
  List<String>? _libraries;
  Object? _error;
  final Set<String> _selected = {};
  bool _sending = false;

  P2pController get c => widget.controller;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await c.fedApi.composeRequest(widget.peer.endpointId,
          message: _msgCtrl.text,
          offerVpaths: (_libraries ?? const []).where(_selected.contains).toList());
      await c.refreshCatalog();
      showGlobalSnack(l.p2pRequestSent);
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.p2pRequestFailed(e.message));
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = widget.peer;
    final libs = _libraries;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(l.p2pFederateTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          FedCard(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                const FedTile(Icons.public, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name ?? p.shortId,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: VelvetColors.textPrimary)),
                      Text(p.shortId,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: VelvetColors.textTertiary)),
                    ],
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          FedNote(l.p2pFederateNote, icon: Icons.lock_outline, color: const Color(0xFF64B5F6)),
          const SizedBox(height: 10),
          TextField(
            controller: _msgCtrl,
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            style: TextStyle(color: VelvetColors.textPrimary),
            decoration: fedInputDecoration(l.p2pMessage).copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          FedHint(l.p2pMessageHint(_msgCtrl.text.length)),
          FedSection(l.p2pShareBackLibraries),
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
          FedHint(l.p2pShareBackNote),
        ],
      ),
      bottomNavigationBar: FedBottomBar(children: [
        FedButton(l.p2pSendRequest,
            icon: Icons.send_outlined,
            busy: _sending,
            onPressed: libs == null ? null : _send),
      ]),
    );
  }
}
