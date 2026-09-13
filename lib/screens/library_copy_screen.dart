import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/browser_list.dart';
import '../singletons/library_index.dart';
import '../singletons/mirror_manager.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/format_bytes.dart';

/// Library copy for one server: which libraries to keep a full copy of, the
/// mirror's status with a Sync now / Cancel button, and the two settings
/// (trash retention, Wi-Fi only on mobile). Reached from the server's ⋮ menu
/// in Manage Servers.
class LibraryCopyScreen extends StatefulWidget {
  final Server server;
  const LibraryCopyScreen({super.key, required this.server});

  @override
  State<LibraryCopyScreen> createState() => _LibraryCopyScreenState();
}

class _LibraryCopyScreenState extends State<LibraryCopyScreen> {
  Server get server => widget.server;

  static const _retentionChoices = [7, 30, 90, 0];

  TextStyle get _label => TextStyle(
      color: VelvetColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600);
  TextStyle get _help =>
      TextStyle(color: VelvetColors.textTertiary, fontSize: 11);
  TextStyle get _body => TextStyle(color: VelvetColors.textPrimary);

  Future<void> _persist() => ServerManager().callAfterEditServer();

  static String _stamp(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mobile = Platform.isAndroid || Platform.isIOS;
    final libraries = server.autoDJPaths.keys.toList()..sort();
    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(
        title: Text(l.libraryCopyTitle),
        backgroundColor: VelvetColors.bg,
      ),
      body: StreamBuilder<Map<String, MirrorStatus>>(
        stream: MirrorManager().statusStream,
        initialData: MirrorManager().current,
        builder: (context, snap) {
          final st = snap.data?[server.localname];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(server.displayName,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              if (server.syncAvailable != true) ...[
                _banner(l.libraryCopyUnsupported),
              ] else ...[
                Text(l.libraryCopyKeepSection, style: _label),
                const SizedBox(height: 4),
                Text(l.libraryCopyKeepHelp, style: _help),
                const SizedBox(height: 8),
                if (libraries.isEmpty)
                  Text(l.libraryCopyNoLibraries, style: _help)
                else
                  for (final vpath in libraries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(vpath, style: _body),
                      value: MirrorManager().keepsFullCopy(server, vpath),
                      activeThumbColor: VelvetColors.primary,
                      onChanged: (v) => setState(
                          () => MirrorManager().setKeepFullCopy(server, vpath, v)),
                    ),
                const SizedBox(height: 16),
                _status(context, l, st),
                const SizedBox(height: 16),
                _offlineSwitch(l),
                const SizedBox(height: 16),
              ],
              Text(l.libraryCopyRetention, style: _label),
              const SizedBox(height: 6),
              InputDecorator(
                decoration: const InputDecoration(
                    isDense: true, prefixIcon: Icon(Icons.delete_sweep_outlined)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _retentionChoices.contains(server.mirrorRetentionDays)
                        ? server.mirrorRetentionDays
                        : 30,
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: VelvetColors.surface,
                    style: _body,
                    items: [
                      for (final d in _retentionChoices)
                        DropdownMenuItem(
                            value: d,
                            child: Text(d == 0
                                ? l.libraryCopyRetentionForever
                                : l.libraryCopyRetentionDays(d))),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => server.mirrorRetentionDays = v);
                      _persist();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (mobile)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.wifi),
                  title: Text(l.libraryCopyWifiOnly, style: _body),
                  value: server.mirrorWifiOnly,
                  activeThumbColor: VelvetColors.primary,
                  onChanged: (v) {
                    setState(() => server.mirrorWifiOnly = v);
                    _persist();
                  },
                )
              else
                Text(l.libraryCopyDesktopNote, style: _help),
            ],
          );
        },
      ),
    );
  }

  /// Browse from the index instead of the server (A4). Needs index rows,
  /// i.e. one completed run; flips the runtime flag and resets the browser so
  /// the next list comes from the chosen source.
  Widget _offlineSwitch(AppLocalizations l) {
    final indexed =
        (LibraryIndexManager().index?.remoteCount(server.localname) ?? 0) > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.cloud_off_outlined),
        title: Text(l.offlineBrowseTitle, style: _body),
        subtitle: Text(indexed ? l.offlineBrowseHelp : l.offlineBrowseUnavailable,
            style: _help),
        value: server.browseOffline,
        activeThumbColor: VelvetColors.primary,
        onChanged: !indexed && !server.browseOffline
            ? null
            : (v) {
                setState(() {
                  server.browseOffline = v;
                  server.offlineAuto = false;
                });
                ServerManager().notifyServerChanged();
                BrowserManager().goToNavScreen();
              },
      ),
    ]);
  }

  Widget _banner(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VelvetColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 16, color: VelvetColors.warning),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: VelvetColors.warning, fontSize: 12))),
        ]),
      );

  Widget _status(BuildContext context, AppLocalizations l, MirrorStatus? st) {
    final running = st?.running ?? false;
    final pr = st?.progress;
    final last = st?.lastRun;
    final children = <Widget>[];
    if (running) {
      final total = pr?.total ?? 0;
      children.add(LinearProgressIndicator(
          value: total > 0 ? (pr!.done / total) : null,
          color: VelvetColors.primary,
          backgroundColor: VelvetColors.border));
      children.add(const SizedBox(height: 8));
      children.add(Text(
          pr != null && pr.phase == 'transfer'
              ? l.libraryCopySyncing(pr.done, total)
              : l.libraryCopyPreparing,
          style: _body));
    } else if (last == null) {
      children.add(Text(l.libraryCopyNeverSynced, style: _body));
    } else {
      children.add(Text(
          l.libraryCopyStatus(_stamp(last.finished ?? last.started), st!.files,
              formatBytes(st.bytes)),
          style: _body));
      if (last.error != null) {
        children.add(const SizedBox(height: 4));
        children.add(Text(l.libraryCopyLastRunError(last.error!),
            style: TextStyle(color: VelvetColors.warning, fontSize: 12)));
      }
    }
    if ((st?.failed ?? 0) > 0) {
      children.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _showFailed(context, l),
          child: Text(l.libraryCopyFailed(st!.failed),
              style: TextStyle(color: VelvetColors.error)),
        ),
      ));
    }
    children.add(const SizedBox(height: 8));
    children.add(SizedBox(
      width: double.infinity,
      child: running
          ? OutlinedButton.icon(
              icon: const Icon(Icons.stop, size: 18),
              label: Text(l.cancel),
              onPressed: () => MirrorManager().cancel(server),
            )
          : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: VelvetColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(VelvetColors.radiusSmall))),
              icon: const Icon(Icons.sync, size: 18),
              label: Text(l.libraryCopySyncNow),
              onPressed: () => MirrorManager().sync(server, trigger: 'manual'),
            ),
    ));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VelvetColors.surface,
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  void _showFailed(BuildContext context, AppLocalizations l) {
    final rows =
        LibraryIndexManager().index?.localFailed(server.localname) ?? const [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.libraryCopyFailedTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: rows.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(rows[i].path, style: _body, maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(rows[i].error ?? '',
                  style: TextStyle(color: VelvetColors.error, fontSize: 11)),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: Text(l.goBack)),
        ],
      ),
    );
  }
}
