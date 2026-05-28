// Localized dropdown labels for the app's settings enums.
//
// These live in an extension (rather than a `String get label` on the
// enum itself) because a no-arg getter can't reach AppLocalizations,
// which needs a BuildContext. Keeping them here also spares
// settings.dart / velvet_theme.dart from depending on generated l10n.
//
// Call sites: `someEnum.label(AppLocalizations.of(context))`.

import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import 'app_localizations.dart';

extension AppThemeLabel on AppTheme {
  String label(AppLocalizations l) {
    switch (this) {
      case AppTheme.velvet:
        return l.themeVelvet;
      case AppTheme.dark:
        return l.themeDark;
      case AppTheme.light:
        return l.themeLight;
    }
  }
}

extension TapBehaviorLabel on TapBehavior {
  String label(AppLocalizations l) {
    switch (this) {
      case TapBehavior.addToQueue:
        return l.tapAddToQueue;
      case TapBehavior.playFromHere:
        return l.tapPlayFromHere;
      case TapBehavior.appendAndJump:
        return l.tapAppendAndJump;
    }
  }
}

extension VisualizerEngineLabel on VisualizerEngine {
  String label(AppLocalizations l) {
    switch (this) {
      case VisualizerEngine.milkdrop:
        return l.visualizerEngineMilkdrop;
      case VisualizerEngine.shader:
        return l.visualizerEngineShaders;
    }
  }
}

extension VisualizerAudioSourceLabel on VisualizerAudioSource {
  String label(AppLocalizations l) {
    switch (this) {
      case VisualizerAudioSource.synthesized:
        return l.visualizerSourceSynthesized;
      case VisualizerAudioSource.real:
        return l.visualizerSourceReal;
    }
  }
}
