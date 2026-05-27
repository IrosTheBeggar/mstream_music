import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/velvet_theme.dart';

class AboutScreen extends StatelessWidget {
  // Bump alongside pubspec.yaml's `version:` line. Hardcoded rather
  // than read via package_info_plus to avoid pulling another platform
  // plugin just for one string.
  static const _versionLabel = 'v0.14.1';

  static const _links = <_LinkRow>[
    _LinkRow(
      label: 'Discord',
      url: 'https://discord.gg/AM896Rr',
      subtitle: 'Community chat',
      icon: Icons.forum,
    ),
    _LinkRow(
      label: 'GitHub',
      url: 'https://github.com/IrosTheBeggar/mStream',
      subtitle: 'mStream server source',
      icon: Icons.code,
    ),
    _LinkRow(
      label: 'mstream.io',
      url: 'https://mstream.io/',
      subtitle: 'Project homepage',
      icon: Icons.public,
    ),
  ];

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About')),
      body: ListView(
        children: [
          SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Image.asset('graphics/mstream-logo.png'),
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              'mStream Mobile',
              style: TextStyle(
                fontFamily: 'Jura',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: VelvetColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 4),
          Center(
            child: Text(
              _versionLabel,
              style: TextStyle(
                fontSize: 13,
                color: VelvetColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 32),
          Center(
            child: Text(
              'Built by Paul Sori',
              style: TextStyle(
                fontSize: 14,
                color: VelvetColors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 24),
          Divider(color: VelvetColors.border, height: 1),
          ..._links.map((l) => ListTile(
                leading: Icon(l.icon, color: VelvetColors.primary),
                title: Text(l.label,
                    style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  l.subtitle,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.open_in_new,
                    size: 18, color: VelvetColors.textTertiary),
                onTap: () => _open(context, l.url),
              )),
        ],
      ),
    );
  }
}

class _LinkRow {
  final String label;
  final String url;
  final String subtitle;
  final IconData icon;
  const _LinkRow({
    required this.label,
    required this.url,
    required this.subtitle,
    required this.icon,
  });
}
