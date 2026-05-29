// Lets the user add their own Shadertoy-style `.glsl` files to the
// visualizer's Shader-engine rotation: drop files into the shown folder,
// then Rescan. Files are read straight off disk and compiled at runtime
// by the native engine, so no rebuild/reinstall is needed.
//
// Strings here are intentionally plain (not yet localized), matching the
// other recently-added visualizer settings.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../native/user_shaders.dart';
import '../native/visualizer_presets.dart';
import '../theme/velvet_theme.dart';

class ImportedShadersScreen extends StatefulWidget {
  @override
  State<ImportedShadersScreen> createState() => _ImportedShadersScreenState();
}

class _ImportedShadersScreenState extends State<ImportedShadersScreen> {
  List<String> _paths = const [];
  String? _folder;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final folder = await UserShaders().folderPath();
    final paths = await UserShaders().list();
    // Make the visualizer re-scan on its next open so changes here show up.
    VisualizerPresets().invalidateCache();
    if (!mounted) return;
    setState(() {
      _folder = folder;
      _paths = paths;
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
      const SnackBar(content: Text('Folder path copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imported shaders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan folder',
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
                  _folderCard(),
                  Divider(color: VelvetColors.border, height: 1),
                  Expanded(
                    child: _paths.isEmpty
                        ? _empty()
                        : ListView.separated(
                            itemCount: _paths.length,
                            separatorBuilder: (_, __) => Divider(
                                color: VelvetColors.border, height: 1),
                            itemBuilder: (_, i) {
                              final path = _paths[i];
                              return ListTile(
                                leading: Icon(Icons.auto_awesome,
                                    color: VelvetColors.primary),
                                title: Text(p.basename(path)),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: VelvetColors.textSecondary),
                                  tooltip: 'Remove',
                                  onPressed: () => _delete(path),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _folderCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drop .glsl files in this folder, then Rescan:',
            style:
                TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
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
                  icon: Icon(Icons.copy,
                      size: 18, color: VelvetColors.primary),
                  tooltip: 'Copy path',
                  onPressed: _copyPath,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reachable over USB or a file manager (under Android/data). '
            'Imported shaders join the rotation when the Shader engine is '
            'active.',
            style:
                TextStyle(color: VelvetColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
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
              'No shaders in the folder yet',
              style:
                  TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Copy Shadertoy-style .glsl files into the folder above, '
              'then tap Rescan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
