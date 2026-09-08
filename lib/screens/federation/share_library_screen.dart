import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_limits_editor.dart';
import '../../widgets/federation_widgets.dart';
import 'federation_controller.dart';
import 'ticket_screen.dart';

/// Mint a ticket: a name for your own list, the libraries it grants, the
/// limits (presets, exact numbers one tap away). Ends on the ticket screen.
class ShareLibraryScreen extends StatefulWidget {
  final FederationController controller;
  const ShareLibraryScreen({super.key, required this.controller});

  @override
  State<ShareLibraryScreen> createState() => _ShareLibraryScreenState();
}

class _ShareLibraryScreenState extends State<ShareLibraryScreen> {
  final _nameCtrl = TextEditingController();
  List<String>? _libraries;
  Object? _error;
  final Set<String> _selected = {};
  late FederationLimits _limits;
  DateTime? _expiresAt;
  bool _minting = false;

  FederationController get c => widget.controller;

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
      if (mounted) setState(() => _libraries = libs);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _ready =>
      _nameCtrl.text.trim().isNotEmpty && _selected.isNotEmpty && !_minting;

  Future<void> _mint() async {
    final l = AppLocalizations.of(context);
    setState(() => _minting = true);
    try {
      final key = await c.api.mint(
        name: _nameCtrl.text.trim(),
        vpaths: _libraries!.where(_selected.contains).toList(),
        limits: _limits,
        expiresAt: _expiresAt,
      );
      await c.refreshKeys();
      if (!mounted) return;
      // Push, not replace: the Federation screen awaits THIS route, and
      // only when the ticket screen closes should it refresh (the ticket
      // may be on the clipboard by then — the banner reads it).
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TicketScreen(ticketKey: key)));
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
    } catch (_) {
      showGlobalSnack(l.federationMintFailed);
    } finally {
      if (mounted) setState(() => _minting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final libs = _libraries;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop()),
        title: Text(l.federationShareLibrary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          TextField(
            controller: _nameCtrl,
            maxLength: 64,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: VelvetColors.textPrimary),
            decoration: fedInputDecoration(l.federationTicketNameLabel)
                .copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          FedHint(l.federationTicketNameHint),
          FedSection(l.federationLibrariesTheyCanRead),
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
          else if (libs!.isEmpty)
            FedCard(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(l.federationNoLibraries,
                    style: TextStyle(color: VelvetColors.textSecondary)),
              ),
            ])
          else
            FedCard(children: [
              for (final name in libs)
                FedCheckRow(
                  label: name,
                  value: _selected.contains(name),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _selected.add(name);
                    } else {
                      _selected.remove(name);
                    }
                  }),
                ),
            ]),
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
        FedButton(l.federationCreateTicket,
            icon: Icons.vpn_key_outlined,
            busy: _minting,
            onPressed: _ready ? _mint : null),
      ]),
    );
  }
}
