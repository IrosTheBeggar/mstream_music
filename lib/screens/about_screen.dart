import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';
import 'attributions_screen.dart';

// Stable identifier per external link, so the const list below stays
// const while the human-readable subtitle is resolved per-locale at
// build time. Labels stay literal — they're brand names.
enum _LinkId { discord, github, homepage }

class AboutScreen extends StatelessWidget {
  // Bump alongside pubspec.yaml's `version:` line. Hardcoded rather
  // than read via package_info_plus to avoid pulling another platform
  // plugin just for one string.
  static const _versionLabel = 'v0.19.0';

  static const _links = <_LinkRow>[
    _LinkRow(
      label: 'Discord',
      url: 'https://discord.gg/AM896Rr',
      id: _LinkId.discord,
      icon: Icons.forum,
    ),
    _LinkRow(
      label: 'GitHub',
      url: 'https://github.com/IrosTheBeggar/mStream',
      id: _LinkId.github,
      icon: Icons.code,
    ),
    _LinkRow(
      label: 'mstream.io',
      url: 'https://mstream.io/',
      id: _LinkId.homepage,
      icon: Icons.public,
    ),
  ];

  static String _linkSubtitle(AppLocalizations l, _LinkId id) {
    switch (id) {
      case _LinkId.discord:
        return l.linkDiscordSubtitle;
      case _LinkId.github:
        return l.linkGithubSubtitle;
      case _LinkId.homepage:
        return l.linkHomepageSubtitle;
    }
  }

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
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
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
              l.aboutBuiltBy('Paul Sori'),
              style: TextStyle(
                fontSize: 14,
                color: VelvetColors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 24),
          Divider(color: VelvetColors.border, height: 1),
          ..._links.map((link) => ListTile(
                leading: Icon(link.icon, color: VelvetColors.primary),
                title: Text(link.label,
                    style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _linkSubtitle(l, link.id),
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.open_in_new,
                    size: 18, color: VelvetColors.textTertiary),
                onTap: () => _open(context, link.url),
              )),
          Divider(color: VelvetColors.border, height: 1),
          ListTile(
            leading: Icon(Icons.favorite_border, color: VelvetColors.primary),
            title: Text(l.aboutAttributions,
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(
              l.aboutAttributionsSubtitle,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right,
                size: 20, color: VelvetColors.textTertiary),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AttributionsScreen()),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _LinkRow {
  final String label;
  final String url;
  final _LinkId id;
  final IconData icon;
  const _LinkRow({
    required this.label,
    required this.url,
    required this.id,
    required this.icon,
  });
}
