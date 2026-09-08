import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../singletons/app_messenger.dart';
import '../../theme/velvet_theme.dart';
import '../../util/federation_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import 'p2p_controller.dart';

/// The webapp's Config tab and identity modal, folded: the network switch
/// (off = leave), name and description, the snapshot knobs as preset
/// chips, community seeds (a config-file setting, shown), the blocked list.
class P2pSettingsScreen extends StatefulWidget {
  final P2pController controller;
  const P2pSettingsScreen({super.key, required this.controller});

  @override
  State<P2pSettingsScreen> createState() => _P2pSettingsScreenState();
}

class _P2pSettingsScreenState extends State<P2pSettingsScreen> {
  bool _toggling = false;
  String? _savingKnob;

  P2pController get c => widget.controller;

  static const _autoFetch = [0, 3, 6, 12];
  static const _storageMb = [500, 1024, 2048, 5120];
  static const _rotation = [0, 7, 30];
  static const _retention = [0, 7, 30, 90];

  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    final ok = await fedConfirm(context,
        message: l.p2pLeaveConfirm, confirmLabel: l.p2pLeave, danger: true);
    if (!ok || !mounted) return;
    setState(() => _toggling = true);
    try {
      await c.leave();
      showGlobalSnack(l.p2pLeft);
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.p2pLeaveFailed(e.message));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _knob(String key, Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() => _savingKnob = key);
    try {
      await action();
      await c.load(quiet: true);
      showGlobalSnack(l.p2pSaved);
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.p2pSaveFailed(e.message));
    } finally {
      if (mounted) setState(() => _savingKnob = null);
    }
  }

  /// Chip labels for [presets] plus, when [value] is not one, a trailing
  /// chip for the value itself; returns (labels, selected index).
  (List<String>, int) _chips(List<int> presets, int value, String Function(int) fmt) {
    final labels = [for (final p in presets) fmt(p)];
    var idx = presets.indexOf(value);
    if (idx < 0) {
      labels.add(fmt(value));
      idx = labels.length - 1;
    }
    return (labels, idx);
  }

  String _days(AppLocalizations l, int d) => d <= 0 ? l.federationNever : l.federationDays(d);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.status;
        if (s == null) {
          return Scaffold(appBar: AppBar(title: Text(l.p2pSettingsTitle)), body: fedLoading());
        }
        final (autoLabels, autoIdx) = _chips(_autoFetch, s.autoFetchCount,
            (v) => v == 0 ? l.p2pOff : l.p2pServersCount(v));
        final (storLabels, storIdx) = _chips(_storageMb, s.maxPeerDbStorageMb,
            (v) => fmtBytes(v * 1024 * 1024));
        final (rotLabels, rotIdx) = _chips(_rotation, s.rotationDays, (v) => _days(l, v));
        final (retLabels, retIdx) = _chips(_retention, s.peerRetentionDays, (v) => _days(l, v));
        return Scaffold(
          appBar: AppBar(title: Text(l.p2pSettingsTitle)),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                FedCard(children: [
                  FedSwitchRow(
                    title: l.p2pSwitchTitle,
                    subtitle: l.p2pSwitchSub,
                    value: s.enabled,
                    busy: _toggling,
                    onChanged: s.enabled ? (_) => _leave() : null,
                  ),
                ]),
                FedSection(l.p2pHowYouAppear),
                FedCard(children: [
                  FedRow(
                    icon: Icons.edit_outlined,
                    iconColor: VelvetColors.textSecondary,
                    title: s.serverName.isEmpty ? c.server.displayName : s.serverName,
                    subtitle: s.serverDescription.isEmpty ? l.p2pNoDescription : s.serverDescription,
                    subtitleLines: 2,
                    trailing: fedChevron(),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => P2pIdentityScreen(controller: c)));
                    },
                  ),
                ]),
                FedSection(l.p2pSnapshotsSection),
                FedCard(children: [
                  FedChipRow(
                    label: l.p2pAutoDownload,
                    options: autoLabels,
                    selected: autoIdx,
                    onSelected: (i) {
                      if (i < _autoFetch.length && _savingKnob == null) {
                        _knob('auto', () => c.api.setAutoFetchCount(_autoFetch[i]));
                      }
                    },
                  ),
                  FedChipRow(
                    label: l.p2pStorageCap,
                    options: storLabels,
                    selected: storIdx,
                    onSelected: (i) {
                      if (i < _storageMb.length && _savingKnob == null) {
                        _knob('storage', () => c.api.setMaxStorageMb(_storageMb[i]));
                      }
                    },
                  ),
                  FedChipRow(
                    label: l.p2pRotate,
                    options: rotLabels,
                    selected: rotIdx,
                    onSelected: (i) {
                      if (i < _rotation.length && _savingKnob == null) {
                        _knob('rotation', () => c.api.setRotationDays(_rotation[i]));
                      }
                    },
                  ),
                  FedChipRow(
                    label: l.p2pForgetOffline,
                    options: retLabels,
                    selected: retIdx,
                    onSelected: (i) {
                      if (i < _retention.length && _savingKnob == null) {
                        _knob('retention', () => c.api.setPeerRetentionDays(_retention[i]));
                      }
                    },
                  ),
                ]),
                FedSection(l.p2pMeshSection),
                FedCard(children: [
                  FedRow(
                    icon: Icons.settings_input_antenna,
                    iconColor: VelvetColors.textSecondary,
                    title: l.p2pCommunitySeeds,
                    subtitle: s.communitySeeds ? l.p2pCommunitySeedsOn : l.p2pCommunitySeedsOff,
                    subtitleLines: 2,
                  ),
                  FedRow(
                    icon: Icons.block,
                    iconColor: VelvetColors.textSecondary,
                    title: l.p2pBlockedServers(s.blockedPeers.length),
                    subtitle: l.p2pBlockedSub,
                    trailing: s.blockedPeers.isEmpty ? null : fedChevron(),
                    onTap: s.blockedPeers.isEmpty
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => P2pBlockedScreen(controller: c))),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Name and description as other operators see them.
class P2pIdentityScreen extends StatefulWidget {
  final P2pController controller;
  const P2pIdentityScreen({super.key, required this.controller});

  @override
  State<P2pIdentityScreen> createState() => _P2pIdentityScreenState();
}

class _P2pIdentityScreenState extends State<P2pIdentityScreen> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.status;
    _name = TextEditingController(text: s?.serverName ?? '');
    _desc = TextEditingController(text: s?.serverDescription ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    setState(() => _saving = true);
    try {
      if (_name.text.trim() != c.status?.serverName) await c.api.setName(_name.text);
      if (_desc.text.trim() != c.status?.serverDescription) {
        await c.api.setDescription(_desc.text);
      }
      await c.load(quiet: true);
      showGlobalSnack(l.p2pIdentitySaved);
      if (mounted) Navigator.of(context).pop();
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.p2pSaveFailed(e.message));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.p2pEditIdentity)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          TextField(
            controller: _name,
            maxLength: 64,
            style: TextStyle(color: VelvetColors.textPrimary),
            decoration: fedInputDecoration(l.p2pServerName).copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          FedHint(l.p2pServerNameHint),
          const SizedBox(height: 10),
          TextField(
            controller: _desc,
            maxLength: 180,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(color: VelvetColors.textPrimary),
            decoration: fedInputDecoration(l.p2pDescription).copyWith(counterText: ''),
          ),
          FedHint(l.p2pDescriptionHint),
        ],
      ),
      bottomNavigationBar: FedBottomBar(children: [
        FedButton(l.p2pSave,
            icon: Icons.check,
            busy: _saving,
            onPressed: _name.text.trim().isEmpty ? null : _save),
      ]),
    );
  }
}

/// Endpoints whose announcements are ignored; unblock one here.
class P2pBlockedScreen extends StatefulWidget {
  final P2pController controller;
  const P2pBlockedScreen({super.key, required this.controller});

  @override
  State<P2pBlockedScreen> createState() => _P2pBlockedScreenState();
}

class _P2pBlockedScreenState extends State<P2pBlockedScreen> {
  String? _busy;

  Future<void> _unblock(String id) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = id);
    try {
      await widget.controller.api.unblock(id);
      await widget.controller.load(quiet: true);
      showGlobalSnack(l.p2pUnblocked);
    } on FederationAdminException catch (e) {
      showGlobalSnack(l.federationActionFailed(e.message));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ids = widget.controller.status?.blockedPeers ?? const [];
        return Scaffold(
          appBar: AppBar(title: Text(l.p2pBlockedTitle)),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                FedCard(children: [
                  if (ids.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(l.p2pBlockedServers(0),
                          style: TextStyle(color: VelvetColors.textSecondary)),
                    ),
                  for (final id in ids)
                    FedRow(
                      icon: Icons.block,
                      iconColor: VelvetColors.error,
                      title: id.length > 12 ? '${id.substring(0, 12)}…' : id,
                      subtitle: l.p2pBlockedSub,
                      trailing: FedButton(l.p2pUnblock,
                          kind: FedButtonKind.text,
                          height: 32,
                          fontSize: 14,
                          busy: _busy == id,
                          onPressed: () => _unblock(id)),
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
