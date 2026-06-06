import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../singletons/log_manager.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';

/// User-facing log viewer: shows the in-app diagnostic buffer ([LogManager]) so
/// users can read recent logs and Copy / Share them when reporting an issue.
/// Reached from the drawer. Logging is on by default; the toggle here turns
/// capture off. Secrets are already redacted in the buffer, so copy/share are
/// safe to hand to a maintainer.
class DiagnosticsScreen extends StatefulWidget {
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: LogManager().dump()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.diagnosticsCopied)));
  }

  Future<void> _share() async {
    final text = LogManager().dump();
    final body = text.isEmpty ? '(no logs)' : text;
    try {
      // Share a .txt file so a long log isn't truncated the way a text share
      // can be; fall back to a plain-text share if the file write fails.
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/mstream-log-${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(body);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/plain')],
          subject: 'mStream logs');
    } catch (_) {
      await Share.share(body, subject: 'mStream logs');
    }
  }

  void _clear() {
    LogManager().clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.diagnosticsTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SwitchListTile(
              title: Text(l.diagnosticsEnable),
              subtitle: Text(
                l.diagnosticsHint,
                style:
                    TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
              ),
              value: SettingsManager().diagnosticsLogging,
              onChanged: (v) async {
                await SettingsManager().setDiagnosticsLogging(v);
                if (mounted) setState(() {});
              },
              activeThumbColor: VelvetColors.primary,
            ),
            Divider(height: 1, color: VelvetColors.border),
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: LogManager().stream,
                initialData: LogManager().lines,
                builder: (context, snap) {
                  final lines = snap.data ?? const <String>[];
                  if (lines.isEmpty) {
                    return Center(
                      child: Text(l.diagnosticsEmpty,
                          style:
                              TextStyle(color: VelvetColors.textSecondary)),
                    );
                  }
                  // Newest first so the latest entries are visible immediately.
                  final display = lines.reversed.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: display.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        display[i],
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.3,
                          color: VelvetColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: VelvetColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(child: _action(Icons.copy, l.diagnosticsCopy, _copy)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _action(Icons.share, l.diagnosticsShare, _share)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _action(
                          Icons.delete_outline, l.diagnosticsClear, _clear)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: VelvetColors.primary,
        side: BorderSide(color: VelvetColors.primary.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VelvetColors.radiusSmall)),
      ),
    );
  }
}
