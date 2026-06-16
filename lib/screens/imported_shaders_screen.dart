// Lets the user add their own Shadertoy-style `.glsl` files to the
// visualizer's Shader-engine rotation: drop files into the shown folder,
// then Rescan. Files are read straight off disk and compiled at runtime
// by the native engine, so no rebuild/reinstall is needed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../native/user_shaders.dart';
import '../native/visualizer_presets.dart';
import '../theme/velvet_theme.dart';

/// One imported shader: its absolute [path], the `// title:` parsed from
/// the file (or null), and whether it looks like a usable fragment shader.
class _ShaderEntry {
  final String path;
  final String? title;
  final bool valid;
  const _ShaderEntry(this.path, this.title, this.valid);
}

class ImportedShadersScreen extends StatefulWidget {
  @override
  State<ImportedShadersScreen> createState() => _ImportedShadersScreenState();
}

class _ImportedShadersScreenState extends State<ImportedShadersScreen> {
  List<_ShaderEntry> _entries = const [];
  String? _folder;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final shaders = UserShaders();
    final folder = await shaders.folderPath();
    final paths = await shaders.list();
    final entries = <_ShaderEntry>[
      for (final path in paths)
        _ShaderEntry(
          path,
          await shaders.titleOf(path),
          await shaders.looksValid(path),
        ),
    ];
    // Make the visualizer re-scan on its next open so changes here show up.
    VisualizerPresets().invalidateCache();
    if (!mounted) return;
    setState(() {
      _folder = folder;
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _delete(String path) async {
    await UserShaders().delete(path);
    await _refresh();
  }

  void _copyPath() {
    final f = _folder;
    if (f == null) return;
    Clipboard.setData(ClipboardData(text: f));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)),
    );
  }

  /// Scans the device Downloads folder for `.glsl` files and copies them into
  /// the shader folder (so the user doesn't have to reach the awkward
  /// Android/data path with a file manager). Reading Downloads needs all-files
  /// access on Android 11+ (the `full` flavor's MANAGE_EXTERNAL_STORAGE), so
  /// request it the same way Add Server's storage picker does.
  Future<void> _importFromDownloads() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      if (!status.isGranted) {
        messenger.showSnackBar(SnackBar(
            content: Text(l.importedShadersDownloadsNoPermission)));
        return;
      }
    }
    setState(() => _loading = true);
    final copied = await UserShaders().importFromDownloads();
    await _refresh();
    messenger.showSnackBar(SnackBar(
      content: Text(copied > 0
          ? l.importedShadersDownloadsImported(copied)
          : l.importedShadersDownloadsNone),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.importedShadersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.importedShadersRescan,
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _folderCard(l),
                  Divider(color: VelvetColors.border, height: 1),
                  Expanded(
                    child: _entries.isEmpty
                        ? _empty(l)
                        : ListView.separated(
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => Divider(
                                color: VelvetColors.border, height: 1),
                            itemBuilder: (_, i) => _shaderTile(l, _entries[i]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _shaderTile(AppLocalizations l, _ShaderEntry e) {
    final name = p.basename(e.path);
    // When a `// title:` was parsed it becomes the primary line and the
    // file name drops to the subtitle; an invalid file shows a warning
    // subtitle instead.
    final String? subtitle = !e.valid
        ? l.importedShadersInvalid
        : (e.title != null ? name : null);
    return ListTile(
      leading: Icon(
        e.valid ? Icons.auto_awesome : Icons.warning_amber_rounded,
        color: e.valid ? VelvetColors.primary : VelvetColors.error,
      ),
      title: Text(e.title ?? name,
          style: TextStyle(color: VelvetColors.textPrimary)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: TextStyle(
                  color: e.valid
                      ? VelvetColors.textSecondary
                      : VelvetColors.error,
                  fontSize: 12)),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: VelvetColors.textSecondary),
        tooltip: l.importedShadersRemove,
        onPressed: () => _delete(e.path),
      ),
    );
  }

  Widget _folderCard(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.importedShadersDropHint,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: VelvetColors.raised,
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
              border: Border.all(color: VelvetColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _folder ?? '',
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon:
                      Icon(Icons.copy, size: 18, color: VelvetColors.primary),
                  tooltip: l.importedShadersCopyPath,
                  onPressed: _copyPath,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.importedShadersReachableHint,
            style: TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          // Convenience: pull any .glsl the user downloaded straight into the
          // shader folder, so they never have to navigate the Android/data path.
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _importFromDownloads,
              icon: const Icon(Icons.move_to_inbox, size: 18),
              label: Text(l.importedShadersImportDownloads),
              style: OutlinedButton.styleFrom(
                foregroundColor: VelvetColors.primary,
                side: BorderSide(color: VelvetColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                size: 48, color: VelvetColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              l.importedShadersEmptyTitle,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              l.importedShadersEmptyBody,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
