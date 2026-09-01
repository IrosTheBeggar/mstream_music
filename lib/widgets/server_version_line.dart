import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/server_version.dart';

/// The current server's version, a quiet refresh control, and — when the
/// server is behind — a flag linking to the download page.
///
/// Two bands rather than one, because "five years old" and "two months old"
/// deserve different volumes: [UpdateBand.urgent] (5.x, or too old to report a
/// version at all) is amber and says update; [UpdateBand.suggested]
/// (6.0–6.14) is green and merely notes one is available. At 6.15+ nothing is
/// drawn at all.
class ServerVersionLine extends StatefulWidget {
  const ServerVersionLine({super.key});

  @override
  State<ServerVersionLine> createState() => _ServerVersionLineState();
}

class _ServerVersionLineState extends State<ServerVersionLine> {
  bool _refreshing = false;

  Future<void> _refresh(Server server) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      // Straight through ensureServerCapabilities' sibling: one unauthenticated
      // GET, and the result is persisted by the caller.
      final v = (await ServerManager().fetchServerVersion(server)).version;
      if (v != null) {
        server.serverVersion = v;
        server.versionCheckedAt = DateTime.now();
        await ServerManager().writeServerFile();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openDownloads() async {
    final uri = Uri.parse(serverDownloadUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(AppLocalizations.of(context).couldNotOpen(serverDownloadUrl))));
    }
  }

  Widget _flag(AppLocalizations l, UpdateBand band) {
    final urgent = band == UpdateBand.urgent;
    // Amber reuses the warning role; the milder band gets green deliberately —
    // it is informational, not a problem to fix today.
    final color = urgent ? VelvetColors.warning : VelvetColors.success;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: _openDownloads,
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(urgent ? Icons.warning_amber : Icons.upgrade,
                  size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                urgent ? l.serverUpdateUrgent : l.serverUpdateAvailable,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<Server?>(
      stream: ServerManager().currentServerStream,
      initialData: ServerManager().currentServer,
      builder: (context, snap) {
        final server = snap.data;
        if (server == null) return const SizedBox.shrink();
        final parsed = ServerVersion.tryParse(server.serverVersion);
        final band = updateBandFor(parsed);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // Unknown reads as "unknown", not as a fake number: the
                  // server genuinely didn't say.
                  server.serverVersion == null
                      ? l.serverVersionUnknown
                      : l.serverVersionLabel(server.serverVersion!),
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _refreshing ? null : () => _refresh(server),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _refreshing
                        ? SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.4,
                                color: VelvetColors.textSecondary),
                          )
                        : Icon(Icons.refresh,
                            size: 13, color: VelvetColors.textTertiary),
                  ),
                ),
              ],
            ),
            if (band != UpdateBand.none) _flag(l, band),
          ],
        );
      },
    );
  }
}
