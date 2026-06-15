import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';

/// Credits + third-party attributions. Reachable from the About screen.
///
/// Covers:
///   * the app's own license (GPLv3),
///   * every bundled visualizer shader with author + license + source
///     (CC-BY-3.0 attribution for Cyber Fuji is a license requirement,
///     not just courtesy),
///   * vendored native libraries (projectM, KissFFT),
///   * a link to Flutter's auto-generated license page for the rest of
///     the pub dependencies.
class AttributionsScreen extends StatelessWidget {
  static const _appLicenseUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';

  // Bundled visualizer shaders. Author/license/source mirror the
  // headers in assets/shaders/*.glsl.
  static const _shaders = <_Attribution>[
    _Attribution('Spectrum Bars', 'mStream', 'MIT', null),
    _Attribution('Audio Tunnel', 'mStream', 'MIT', null),
    _Attribution('Plasma Pulse', 'mStream', 'MIT', null),
    _Attribution('Cyber Fuji 2020', 'Jan Mróz (jaszunio15), via kaiware007',
        'CC BY 3.0', 'https://www.shadertoy.com/view/Wt33Wf'),
    _Attribution('Hex marching', 'mrange', 'CC0',
        'https://www.shadertoy.com/view/NdKyDw'),
    _Attribution('4D Beats', 'mrange', 'CC0',
        'https://www.shadertoy.com/view/tfK3Dy'),
    _Attribution('Neonwave sunrise', 'mrange', 'CC0',
        'https://www.shadertoy.com/view/7dyyRy'),
    _Attribution('Neonwave Sunset', 'mrange', 'CC0',
        'https://www.shadertoy.com/view/7dtcRj'),
    _Attribution('MountainBytes (PPPP)', 'mrange; music by Virgill', 'CC0',
        'https://www.shadertoy.com/view/lX2GzD'),
  ];

  // Vendored / linked native libraries.
  static const _libraries = <_Attribution>[
    _Attribution('projectM', 'Milkdrop-compatible music visualizer',
        'LGPL-2.1', 'https://github.com/projectM-visualizer/projectm'),
    _Attribution('KissFFT', 'Mark Borgerding', 'BSD-3-Clause',
        'https://github.com/mborgerding/kissfft'),
  ];

  const AttributionsScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).couldNotOpen(url))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.attributionsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            _sectionHeader(l.attributionsSectionLicense),
            ListTile(
              leading: Icon(Icons.balance, color: VelvetColors.primary),
              title: Text('mStream Mobile',
                  style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(
                l.attributionsLicenseBody,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 12),
              ),
              trailing: Icon(Icons.open_in_new,
                  size: 18, color: VelvetColors.textTertiary),
              onTap: () => _open(context, _appLicenseUrl),
            ),
            Divider(color: VelvetColors.border, height: 1),
            _sectionHeader(l.attributionsSectionShaders),
            ..._shaders.map((a) => _row(context, a)),
            Divider(color: VelvetColors.border, height: 1),
            _sectionHeader(l.attributionsSectionLibraries),
            ..._libraries.map((a) => _row(context, a)),
            Divider(color: VelvetColors.border, height: 1),
            _sectionHeader(l.attributionsSectionEverythingElse),
            ListTile(
              leading: Icon(Icons.article_outlined,
                  color: VelvetColors.primary),
              title: Text(l.attributionsPackages,
                  style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(
                l.attributionsPackagesSubtitle,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 12),
              ),
              trailing: Icon(Icons.chevron_right,
                  size: 20, color: VelvetColors.textTertiary),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'mStream Mobile',
                applicationVersion: kAppVersion,
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _Attribution a) {
    return ListTile(
      title: Text(a.name,
          style: TextStyle(
              color: VelvetColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${a.by}  •  ${a.license}',
        style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
      ),
      trailing: a.url == null
          ? null
          : Icon(Icons.open_in_new, size: 18, color: VelvetColors.textTertiary),
      onTap: a.url == null ? null : () => _open(context, a.url!),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: VelvetColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _Attribution {
  final String name;
  final String by;
  final String license;
  final String? url;
  const _Attribution(this.name, this.by, this.license, this.url);
}
