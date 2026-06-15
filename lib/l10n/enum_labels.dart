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

extension StartupViewLabel on StartupView {
  String label(AppLocalizations l) {
    switch (this) {
      case StartupView.browser:
        return l.tabBrowser;
      case StartupView.fileExplorer:
        return l.browserFileExplorer;
      case StartupView.playlists:
        return l.browserPlaylists;
      case StartupView.albums:
        return l.browserAlbums;
      case StartupView.artists:
        return l.browserArtists;
      case StartupView.rated:
        return l.browserRated;
      case StartupView.recent:
        return l.browserRecent;
      case StartupView.localFiles:
        return l.browserLocalFiles;
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

extension SearchCategoryLabel on SearchCategory {
  String label(AppLocalizations l) {
    switch (this) {
      case SearchCategory.artists:
        return l.searchCategoryArtists;
      case SearchCategory.albums:
        return l.searchCategoryAlbums;
      case SearchCategory.songs:
        return l.searchCategorySongs;
      case SearchCategory.files:
        return l.searchCategoryFiles;
    }
  }
}

/// Localized label for a built-in browser node, breadcrumb, or tab.
///
/// The browser's section nodes (File Explorer, Albums, …) and the
/// `browserLabelStream` emit fixed English strings from context-less
/// singletons; this maps them to the active locale at render time.
/// Anything not in the known set — e.g. a server folder or album name —
/// is returned unchanged so real library data is never mistranslated.
/// null / empty / root collapse to the generic Browse tab label.
String browserChromeLabel(AppLocalizations l, String? english) {
  switch (english) {
    case null:
    case '':
    case 'Browser':
    case 'Welcome':
      return l.tabBrowser;
    case 'File Explorer':
      return l.browserFileExplorer;
    case 'Local Files':
      return l.browserLocalFiles;
    case 'Playlists':
      return l.browserPlaylists;
    case 'Albums':
      return l.browserAlbums;
    case 'Artists':
      return l.browserArtists;
    case 'Recent':
      return l.browserRecent;
    case 'Rated':
      return l.browserRated;
    case 'Search':
      return l.browserSearch;
    case 'Welcome To mStream':
      return l.browserWelcomeTitle;
    case 'Click here to add server':
      return l.browserWelcomeSubtitle;
    default:
      return english;
  }
}
