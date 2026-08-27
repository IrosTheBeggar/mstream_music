import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../l10n/language_names.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import 'add_server.dart';

/// Shown once, on the first launch of a brand new install (see main.dart's
/// _maybeShowWelcome). Strictly one-shot: SettingsManager.welcomeShown is set
/// the moment it's pushed, so deleting every server later drops the user back
/// to the browser's plain add-server row rather than replaying this.
///
/// Carries the language picker because a user whose device isn't English
/// shouldn't have to read English to find Settings.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // Repo the "help translate" link points at.
  static const _repoUrl = 'https://github.com/IrosTheBeggar/mStream';

  Future<void> _openRepo(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(_repoUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotOpen(_repoUrl)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The note keys off the language actually being RENDERED, not the stored
    // setting — "System default" on a French device still shows machine
    // translations, so it still earns the note.
    final machineTranslated =
        Localizations.localeOf(context).languageCode != 'en';

    return Scaffold(
      backgroundColor: VelvetColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Leaves without adding anything; the browser underneath already
            // has its add-server row.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l.setupSkip,
                    style: TextStyle(color: VelvetColors.textSecondary),
                  ),
                ),
              ),
            ),
            // The logo owns ALL the slack above the action block and centres
            // itself in it, which puts it midway between the top of the screen
            // and the Add Server button. Expanded (not a fixed offset) so it
            // holds on any screen height; it collapses first if a large text
            // scale grows the block below.
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  // The source PNG is the navy wordmark, which all but
                  // disappears on the dark themes' near-black background.
                  // Tinting it to the primary text colour reproduces the
                  // flat-white treatment the Android splash already uses
                  // (res/drawable-*/splash_logo.png); the Light theme gets
                  // the untouched navy.
                  child: Image.asset(
                    'graphics/mstream-logo.png',
                    width: 240,
                    fit: BoxFit.contain,
                    semanticLabel: 'mStream',
                    color: Theme.of(context).brightness == Brightness.light
                        ? null
                        : VelvetColors.textPrimary,
                  ),
                ),
              ),
            ),
            // Action + footer, anchored to the bottom.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // pushReplacement, not push: once the user is heading
                  // into Add Server this screen has done its job, so
                  // backing out (or saving) lands on the browser rather
                  // than bouncing through the welcome again.
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddServerScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 22),
                    label: Text(l.addServerTitle),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: onAccent(VelvetColors.primary),
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Divider(color: VelvetColors.border, height: 1),
                  const SizedBox(height: 12),
                  _languageRow(context, l),
                  if (machineTranslated) ...[
                    const SizedBox(height: 10),
                    Text(
                      l.welcomeTranslationNote,
                      style: TextStyle(
                        color: VelvetColors.textTertiary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _openRepo(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate,
                            size: 15,
                            color: VelvetColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l.welcomeTranslationCta,
                              style: TextStyle(
                                color: VelvetColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Same item list as Settings → Language (built from supportedLocales so new
  // ARB files show up automatically). Writing through setLanguage re-emits the
  // locale stream, which rebuilds MaterialApp — hence no local state here.
  Widget _languageRow(BuildContext context, AppLocalizations l) {
    return Row(
      children: [
        Icon(Icons.language, size: 20, color: VelvetColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l.settingsLanguage,
            style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
          ),
        ),
        DropdownButton<String?>(
          value: SettingsManager().language,
          underline: const SizedBox.shrink(),
          dropdownColor: VelvetColors.surface,
          style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l.languageSystemDefault),
            ),
            ...AppLocalizations.supportedLocales.map(
              (loc) => DropdownMenuItem<String?>(
                value: loc.languageCode,
                child: Text(
                  kLanguageEndonyms[loc.languageCode] ?? loc.languageCode,
                ),
              ),
            ),
          ],
          onChanged: (v) => SettingsManager().setLanguage(v),
        ),
      ],
    );
  }
}
