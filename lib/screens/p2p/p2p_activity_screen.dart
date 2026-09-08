import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/p2p_admin_api.dart';
import '../../widgets/federation_widgets.dart';
import 'p2p_controller.dart';

/// The sidecar's activity ring, newest first, with the Logs page's level
/// colours. Delta-polled every ten seconds while open; the ring is held
/// in memory server-side, the full history lives in the logs.
class P2pActivityScreen extends StatefulWidget {
  final P2pController controller;
  const P2pActivityScreen({super.key, required this.controller});

  @override
  State<P2pActivityScreen> createState() => _P2pActivityScreenState();
}

class _P2pActivityScreenState extends State<P2pActivityScreen> {
  final List<P2pActivityEntry> _entries = [];
  int _lastSeq = 0;
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.controller.api.activity(since: _lastSeq);
      if (!mounted) return;
      setState(() {
        // A cursor below ours means the server restarted and its counter
        // reset — start over instead of appending a second copy.
        if (r.lastSeq < _lastSeq) _entries.clear();
        _entries.addAll(r.entries);
        if (_entries.length > 500) _entries.removeRange(0, _entries.length - 500);
        _lastSeq = r.lastSeq;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _color(String level) {
    switch (level) {
      case 'error':
        return VelvetColors.error;
      case 'warn':
        return VelvetColors.warning;
      case 'info':
        return VelvetColors.success;
      case 'debug':
        return VelvetColors.textTertiary;
      default:
        return VelvetColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _entries.reversed.take(200).toList();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.p2pActivity),
            Text(l.p2pActivitySubtitle,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: VelvetColors.appBarTextSecondary)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading && _entries.isEmpty
            ? fedLoading()
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                children: [
                  FedCard(children: [
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(l.p2pActivityEmpty,
                            style: TextStyle(color: VelvetColors.textSecondary, height: 1.4)),
                      ),
                    for (final e in rows)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                  e.at == null
                                      ? '—'
                                      : TimeOfDay.fromDateTime(e.at!).format(context),
                                  style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: VelvetColors.textTertiary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(e.message,
                                  style: TextStyle(
                                      fontSize: 13, height: 1.3, color: _color(e.level))),
                            ),
                          ],
                        ),
                      ),
                  ]),
                  FedHint(l.p2pActivityNote),
                ],
              ),
      ),
    );
  }
}
