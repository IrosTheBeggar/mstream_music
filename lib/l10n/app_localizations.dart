import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @mainRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get mainRemove;

  /// Toast shown when creating or renaming a playlist fails (often a duplicate name).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the playlist — the name may already be in use.'**
  String get playlistActionFailed;

  /// Track row menu: insert after the current track.
  ///
  /// In en, this message translates to:
  /// **'Add next'**
  String get queueAddNext;

  /// Track row menu: play this track immediately.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get queuePlayNow;

  /// Track row menu: append to the end of the queue.
  ///
  /// In en, this message translates to:
  /// **'Add to end of queue'**
  String get queueAddToEnd;

  /// Shuffle-play button on the album detail screen.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// Shown as the album artist when an album's tracks span multiple artists.
  ///
  /// In en, this message translates to:
  /// **'Various Artists'**
  String get variousArtists;

  /// Application title (brand name; not translated).
  ///
  /// In en, this message translates to:
  /// **'mStream Music'**
  String get appTitle;

  /// Settings row label for the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// First entry in the language picker: follow the OS locale.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// Subtitle under the language picker row in Settings.
  ///
  /// In en, this message translates to:
  /// **'The app\'s display language. \"System default\" follows your device.'**
  String get settingsLanguageSubtitle;

  /// Snackbar when a URL fails to launch.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String couldNotOpen(String url);

  /// Subtitle showing how many tracks a playlist has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}'**
  String trackCount(int count);

  /// Generic Reset button label.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// AppTheme option label.
  ///
  /// In en, this message translates to:
  /// **'Velvet'**
  String get themeVelvet;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// TapBehavior option: append to queue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get tapAddToQueue;

  /// No description provided for @tapPlayFromHere.
  ///
  /// In en, this message translates to:
  /// **'Play from here'**
  String get tapPlayFromHere;

  /// No description provided for @tapAppendAndJump.
  ///
  /// In en, this message translates to:
  /// **'Add and play'**
  String get tapAppendAndJump;

  /// VisualizerEngine option label.
  ///
  /// In en, this message translates to:
  /// **'Milkdrop'**
  String get visualizerEngineMilkdrop;

  /// No description provided for @visualizerEngineShaders.
  ///
  /// In en, this message translates to:
  /// **'Shaders'**
  String get visualizerEngineShaders;

  /// VisualizerAudioSource option label.
  ///
  /// In en, this message translates to:
  /// **'Synthesized'**
  String get visualizerSourceSynthesized;

  /// No description provided for @visualizerSourceReal.
  ///
  /// In en, this message translates to:
  /// **'Real audio'**
  String get visualizerSourceReal;

  /// Downloads screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// Per-file download progress subtitle.
  ///
  /// In en, this message translates to:
  /// **'progress: {progress}%'**
  String downloadProgress(String progress);

  /// Metadata screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get songInfoTitle;

  /// Lyrics page app bar title and the Song Info lyrics badge label.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTitle;

  /// Empty state on the lyrics page when the server has no lyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found for this song'**
  String get lyricsEmpty;

  /// Error state on the lyrics page when the fetch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load lyrics'**
  String get lyricsError;

  /// Button to retry loading lyrics after an error.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lyricsRetry;

  /// Equalizer screen title / switch label.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get eqTitle;

  /// Shown when the EQ is opened on a non-Android platform.
  ///
  /// In en, this message translates to:
  /// **'Equalizer is only available on Android.'**
  String get eqOnlyAndroid;

  /// Shown when the EQ band layout can't be read because nothing is playing.
  ///
  /// In en, this message translates to:
  /// **'Start a song to configure the EQ.\n\nAndroid\'s native equalizer initializes with the audio session, so we need playback to be active before we can read the band layout.'**
  String get eqNeedsPlayback;

  /// Shown when the native equalizer throws while initializing.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize equalizer:\n{error}'**
  String eqInitFailed(String error);

  /// Shown when the device reports zero EQ bands.
  ///
  /// In en, this message translates to:
  /// **'No EQ bands reported by this device\'s audio driver.'**
  String get eqNoBands;

  /// No description provided for @eqDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on the equalizer to adjust the bands.'**
  String get eqDisabledHint;

  /// EQ enable switch subtitle when on.
  ///
  /// In en, this message translates to:
  /// **'On — gains applied to playback'**
  String get eqEnabledOn;

  /// No description provided for @eqEnabledOff.
  ///
  /// In en, this message translates to:
  /// **'Off — bypass mode'**
  String get eqEnabledOff;

  /// Generic Cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic Continue button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Snackbar action to open the OS app settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// Settings screen app bar title and section headers.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsSectionPlayback;

  /// No description provided for @settingsSectionBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get settingsSectionBrowse;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Theme picker row label + per-theme subtitles.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSubtitleVelvet.
  ///
  /// In en, this message translates to:
  /// **'Navy and purple — the signature dark theme.'**
  String get themeSubtitleVelvet;

  /// No description provided for @themeSubtitleDark.
  ///
  /// In en, this message translates to:
  /// **'Neutral dark with amber accents.'**
  String get themeSubtitleDark;

  /// No description provided for @themeSubtitleLight.
  ///
  /// In en, this message translates to:
  /// **'Light body with a dark app bar and amber accents — matches the older shipped theme.'**
  String get themeSubtitleLight;

  /// Transcode toggle row.
  ///
  /// In en, this message translates to:
  /// **'Transcode audio'**
  String get settingsTranscode;

  /// No description provided for @settingsTranscodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stream a transcoded copy from the server (smaller files, slightly slower start). Off plays original files.'**
  String get settingsTranscodeSubtitle;

  /// No description provided for @transcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcoding'**
  String get transcodeTitle;

  /// No description provided for @transcodeCodec.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get transcodeCodec;

  /// No description provided for @transcodeBitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get transcodeBitrate;

  /// No description provided for @transcodeAuto.
  ///
  /// In en, this message translates to:
  /// **'Server default'**
  String get transcodeAuto;

  /// No description provided for @transcodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t have transcoding enabled — its tracks stream in original quality.'**
  String get transcodeUnavailable;

  /// No description provided for @transcodeReloadQueue.
  ///
  /// In en, this message translates to:
  /// **'Apply to current queue'**
  String get transcodeReloadQueue;

  /// No description provided for @transcodeReloadQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you change transcoding settings — checked: reload the whole queue now (the playing track briefly re-buffers); unchecked: only upcoming tracks change, the current one finishes as-is.'**
  String get transcodeReloadQueueSubtitle;

  /// Tap-behavior picker row label + per-mode subtitles.
  ///
  /// In en, this message translates to:
  /// **'When you tap a song'**
  String get settingsTapBehavior;

  /// No description provided for @settingsStartupPage.
  ///
  /// In en, this message translates to:
  /// **'Startup page'**
  String get settingsStartupPage;

  /// No description provided for @settingsStartupPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the app to this browser view; Back returns to the browser.'**
  String get settingsStartupPageSubtitle;

  /// No description provided for @tapSubtitleAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Tapping a song appends it to the queue. If the queue is empty, playback starts automatically.'**
  String get tapSubtitleAddToQueue;

  /// No description provided for @tapSubtitlePlayFromHere.
  ///
  /// In en, this message translates to:
  /// **'Tapping a song replaces the queue with the songs in the current view and starts playback at the tapped song.'**
  String get tapSubtitlePlayFromHere;

  /// No description provided for @tapSubtitleAppendAndJump.
  ///
  /// In en, this message translates to:
  /// **'Tapping a song appends it to the queue and jumps playback to it, interrupting whatever was playing.'**
  String get tapSubtitleAppendAndJump;

  /// Subtitle on the Equalizer row in Settings.
  ///
  /// In en, this message translates to:
  /// **'Tune bass, mids, and treble. Android only.'**
  String get settingsEqSubtitle;

  /// Visualizer-engine picker row label + per-engine subtitles.
  ///
  /// In en, this message translates to:
  /// **'Visualizer engine'**
  String get settingsVisualizerEngine;

  /// No description provided for @visualizerEngineSubtitleMilkdrop.
  ///
  /// In en, this message translates to:
  /// **'Milkdrop presets via projectM (default). Richer effects, heavier on the GPU.'**
  String get visualizerEngineSubtitleMilkdrop;

  /// No description provided for @visualizerEngineSubtitleShaders.
  ///
  /// In en, this message translates to:
  /// **'Shadertoy-style fragment shaders. Lighter, modular — drop .glsl files in assets/shaders/ to extend the catalog.'**
  String get visualizerEngineSubtitleShaders;

  /// Visualizer audio-source picker row label + per-source subtitles.
  ///
  /// In en, this message translates to:
  /// **'Visualizer audio source'**
  String get settingsVisualizerSource;

  /// No description provided for @visualizerSourceSubtitleSynthesized.
  ///
  /// In en, this message translates to:
  /// **'Default. Visualizer reacts to playback timing only — no microphone permission required.'**
  String get visualizerSourceSubtitleSynthesized;

  /// No description provided for @visualizerSourceSubtitleReal.
  ///
  /// In en, this message translates to:
  /// **'Visualizer reacts to actual audio output. Requires the RECORD_AUDIO permission on Android.'**
  String get visualizerSourceSubtitleReal;

  /// Album-grid toggle row.
  ///
  /// In en, this message translates to:
  /// **'Album grid view'**
  String get settingsAlbumGrid;

  /// No description provided for @settingsAlbumGridSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show albums as a grid of cards with cover art instead of a plain list.'**
  String get settingsAlbumGridSubtitle;

  /// File-explorer metadata toggle row.
  ///
  /// In en, this message translates to:
  /// **'Read song metadata in file explorer'**
  String get settingsFileMetadata;

  /// No description provided for @settingsFileMetadataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fetch title, artist, and album art for each song when browsing server files. Off shows raw filenames (faster for huge folders).'**
  String get settingsFileMetadataSubtitle;

  /// Letter-scrubber threshold slider row.
  ///
  /// In en, this message translates to:
  /// **'Letter scrubber threshold'**
  String get settingsLetterStrip;

  /// No description provided for @settingsLetterStripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the A-Z quick-scrub strip when a list has this many items or more. Below this size the strip is hidden and long folder/file names wrap to multiple lines instead of being truncated. Set 0 to always show the strip.'**
  String get settingsLetterStripSubtitle;

  /// Reset-to-defaults row + confirmation snackbar.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get settingsReset;

  /// No description provided for @settingsResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore all settings on this screen to their default values. Servers and downloads are not affected.'**
  String get settingsResetSubtitle;

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Settings restored to defaults'**
  String get settingsResetDone;

  /// RECORD_AUDIO consent dialog + denial snackbars.
  ///
  /// In en, this message translates to:
  /// **'Use real audio?'**
  String get realAudioDialogTitle;

  /// No description provided for @realAudioDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Real audio mode reads the waveform of music your phone is playing so the visualizer can react to it. Android requires the RECORD_AUDIO permission for this — the app does not record or send any audio anywhere. You can switch back to synthesized at any time.'**
  String get realAudioDialogBody;

  /// No description provided for @realAudioPermPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission permanently denied. Enable it in system settings to use real audio.'**
  String get realAudioPermPermanentlyDenied;

  /// No description provided for @realAudioPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Staying on synthesized audio.'**
  String get realAudioPermDenied;

  /// Overlay hint while the visualizer is rendering.
  ///
  /// In en, this message translates to:
  /// **'Tap = next preset · back arrow (top-left) or long-press to exit'**
  String get visualizerTapHint;

  /// Visualizer status placeholder headings.
  ///
  /// In en, this message translates to:
  /// **'Visualizer failed to start'**
  String get visualizerFailed;

  /// No description provided for @visualizerBringingUp.
  ///
  /// In en, this message translates to:
  /// **'Bringing up renderer…'**
  String get visualizerBringingUp;

  /// No description provided for @visualizerReady.
  ///
  /// In en, this message translates to:
  /// **'Visualizer ready'**
  String get visualizerReady;

  /// No description provided for @visualizerBridgeFailed.
  ///
  /// In en, this message translates to:
  /// **'Bridge failed to start'**
  String get visualizerBridgeFailed;

  /// Status line showing the active visualizer audio source (already-lowercased).
  ///
  /// In en, this message translates to:
  /// **'Audio source: {source}'**
  String visualizerAudioSourceLine(String source);

  /// Hint on the visualizer status placeholder.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to close'**
  String get visualizerTapToClose;

  /// Shown when the visualizer runs on a non-Android platform.
  ///
  /// In en, this message translates to:
  /// **'Visualizer is currently only supported on Android.'**
  String get visualizerUnsupported;

  /// About screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// Author attribution on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Built by {name}'**
  String aboutBuiltBy(String name);

  /// Subtitles for the external links on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Community chat'**
  String get linkDiscordSubtitle;

  /// No description provided for @linkGithubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'mStream server source'**
  String get linkGithubSubtitle;

  /// No description provided for @linkHomepageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Project homepage'**
  String get linkHomepageSubtitle;

  /// Attributions row on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Attributions'**
  String get aboutAttributions;

  /// No description provided for @aboutAttributionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'License, shader credits, and open-source notices.'**
  String get aboutAttributionsSubtitle;

  /// Generic action labels reused across dialogs/menus.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @makeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make Default'**
  String get makeDefault;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Attributions screen labels (credit data itself stays English).
  ///
  /// In en, this message translates to:
  /// **'Attributions'**
  String get attributionsTitle;

  /// No description provided for @attributionsSectionLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get attributionsSectionLicense;

  /// No description provided for @attributionsSectionShaders.
  ///
  /// In en, this message translates to:
  /// **'Visualizer shaders'**
  String get attributionsSectionShaders;

  /// No description provided for @attributionsSectionLibraries.
  ///
  /// In en, this message translates to:
  /// **'Native libraries'**
  String get attributionsSectionLibraries;

  /// No description provided for @attributionsSectionEverythingElse.
  ///
  /// In en, this message translates to:
  /// **'Everything else'**
  String get attributionsSectionEverythingElse;

  /// No description provided for @attributionsLicenseBody.
  ///
  /// In en, this message translates to:
  /// **'Free software under the GNU General Public License v3.0. You may use, study, share, and modify it under those terms.'**
  String get attributionsLicenseBody;

  /// No description provided for @attributionsPackages.
  ///
  /// In en, this message translates to:
  /// **'Open-source package licenses'**
  String get attributionsPackages;

  /// No description provided for @attributionsPackagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full license texts for all bundled Flutter/Dart packages.'**
  String get attributionsPackagesSubtitle;

  /// Manage Servers screen + server info/remove dialogs.
  ///
  /// In en, this message translates to:
  /// **'Manage Servers'**
  String get manageServersTitle;

  /// No description provided for @manageServerInfo.
  ///
  /// In en, this message translates to:
  /// **'Server Info'**
  String get manageServerInfo;

  /// No description provided for @manageServerDownloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download Folder:'**
  String get manageServerDownloadFolder;

  /// No description provided for @manageServerCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Download Path'**
  String get manageServerCopyPath;

  /// No description provided for @manageServerPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path Copied to Clipboard'**
  String get manageServerPathCopied;

  /// No description provided for @confirmRemoveServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Remove Server'**
  String get confirmRemoveServerTitle;

  /// No description provided for @removeSyncedFiles.
  ///
  /// In en, this message translates to:
  /// **'Remove synced files from device?'**
  String get removeSyncedFiles;

  /// Playlists list + detail screens.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistsTitle;

  /// No description provided for @playlistsNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistsNew;

  /// No description provided for @playlistsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistsEmptyTitle;

  /// No description provided for @playlistsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create one with the New playlist button, then use the queue\'s Add-to-playlist swipe action to fill it.'**
  String get playlistsEmptyBody;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistNameHint;

  /// No description provided for @playlistsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get playlistsRename;

  /// No description provided for @playlistFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlistFallbackTitle;

  /// No description provided for @playlistEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Playlist is empty.\nAdd tracks via the queue.'**
  String get playlistEmptyDetail;

  /// No description provided for @shareEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty queue'**
  String get shareEmptyTitle;

  /// No description provided for @shareEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add songs to the queue before sharing.'**
  String get shareEmptyBody;

  /// No description provided for @shareBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t share this queue'**
  String get shareBlockedTitle;

  /// No description provided for @shareLocalOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'The queue contains songs that are only on this device (not on any server). Sharing only works when every song in the queue comes from a single server.'**
  String get shareLocalOnlyBody;

  /// Blocker shown when the queue spans multiple servers.
  ///
  /// In en, this message translates to:
  /// **'The queue mixes songs from {count} servers ({names}). Sharing only works when every song comes from a single server.'**
  String shareMultiServerBody(int count, String names);

  /// Blocker shown when the queue's server was removed.
  ///
  /// In en, this message translates to:
  /// **'The server \"{name}\" is no longer in your server list. Re-add it to share its queue.'**
  String shareServerGoneBody(String name);

  /// Share Playlist dialog labels.
  ///
  /// In en, this message translates to:
  /// **'Share Playlist'**
  String get shareTitle;

  /// Header in the share dialog: how many songs and which server.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}} from {url}'**
  String shareSongCount(int count, String url);

  /// No description provided for @shareLinkExpires.
  ///
  /// In en, this message translates to:
  /// **'Link expires'**
  String get shareLinkExpires;

  /// No description provided for @shareExpireNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get shareExpireNever;

  /// No description provided for @shareExpire1Day.
  ///
  /// In en, this message translates to:
  /// **'After 1 day'**
  String get shareExpire1Day;

  /// No description provided for @shareExpire7Days.
  ///
  /// In en, this message translates to:
  /// **'After 7 days'**
  String get shareExpire7Days;

  /// No description provided for @shareExpire30Days.
  ///
  /// In en, this message translates to:
  /// **'After 30 days'**
  String get shareExpire30Days;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// No description provided for @shareDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist shared'**
  String get shareDoneTitle;

  /// No description provided for @shareDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can play the queue:'**
  String get shareDoneBody;

  /// Generic Save / Start button labels.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Add/Edit Server form labels, validators, and connection-test messages.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServerTitle;

  /// No description provided for @editServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get editServerTitle;

  /// No description provided for @fieldServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get fieldServerUrl;

  /// No description provided for @fieldPublicAccess.
  ///
  /// In en, this message translates to:
  /// **'Public access'**
  String get fieldPublicAccess;

  /// No description provided for @publicAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server is publicly accessible — no username or password needed.'**
  String get publicAccessSubtitle;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldSdCard.
  ///
  /// In en, this message translates to:
  /// **'Download to SD Card'**
  String get fieldSdCard;

  /// No description provided for @sdCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save downloaded music to the removable SD card instead of internal storage.'**
  String get sdCardSubtitle;

  /// No description provided for @testConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnectionButton;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get testing;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @validatorUrlNeeded.
  ///
  /// In en, this message translates to:
  /// **'Server URL is needed'**
  String get validatorUrlNeeded;

  /// No description provided for @validatorUrlParse.
  ///
  /// In en, this message translates to:
  /// **'Cannot parse URL'**
  String get validatorUrlParse;

  /// No description provided for @testEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a server URL first.'**
  String get testEnterUrl;

  /// No description provided for @testParseUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not parse URL.'**
  String get testParseUrl;

  /// No description provided for @testTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out.'**
  String get testTimedOut;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection Successful!'**
  String get connectionSuccessful;

  /// No description provided for @couldNotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach server. If it requires login, turn off \"Public access\" and add credentials.'**
  String get couldNotReachServer;

  /// No description provided for @failedToLogin.
  ///
  /// In en, this message translates to:
  /// **'Failed to Login'**
  String get failedToLogin;

  /// Test-connection success banner with the detected server version.
  ///
  /// In en, this message translates to:
  /// **'Connected — mStream v{version}'**
  String testConnected(String version);

  /// Test-connection failure banner with the raw error.
  ///
  /// In en, this message translates to:
  /// **'Could not connect: {error}'**
  String testConnectFailed(String error);

  /// Sleep-timer bottom sheet labels.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimerTitle;

  /// No description provided for @sleepTimerHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a duration to pause playback after.'**
  String get sleepTimerHint;

  /// No description provided for @sleepTimerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get sleepTimerCustom;

  /// No description provided for @sleepTimerCustomHint.
  ///
  /// In en, this message translates to:
  /// **'minutes (1–600)'**
  String get sleepTimerCustomHint;

  /// No description provided for @sleepTimerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get sleepTimerCancel;

  /// No description provided for @sleepTimerInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 1 and 600 minutes'**
  String get sleepTimerInvalid;

  /// Countdown line in the sleep-timer sheet.
  ///
  /// In en, this message translates to:
  /// **'Pauses in {time}'**
  String sleepTimerPausesIn(String time);

  /// Preset chip label, e.g. '30 min'.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sleepTimerMinutes(int minutes);

  /// Confirmation snackbar after starting the sleep timer.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Sleep timer set for 1 minute} other{Sleep timer set for {minutes} minutes}}'**
  String sleepTimerSet(int minutes);

  /// Generic Add button label.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Auto DJ screen title + section headers.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ'**
  String get autoDjTitle;

  /// No description provided for @autoDjAddServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a server first.'**
  String get autoDjAddServerFirst;

  /// No description provided for @autoDjSectionServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get autoDjSectionServer;

  /// No description provided for @autoDjSectionSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get autoDjSectionSources;

  /// No description provided for @autoDjSectionContinuity.
  ///
  /// In en, this message translates to:
  /// **'Continuity'**
  String get autoDjSectionContinuity;

  /// No description provided for @autoDjSectionFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get autoDjSectionFilters;

  /// BPM continuity row.
  ///
  /// In en, this message translates to:
  /// **'BPM continuity'**
  String get autoDjBpmTitle;

  /// No description provided for @autoDjBpmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer picks within a tempo window of the current song. Honours half/double-tempo equivalence.'**
  String get autoDjBpmSubtitle;

  /// No description provided for @autoDjTolerance.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get autoDjTolerance;

  /// BPM tolerance readout.
  ///
  /// In en, this message translates to:
  /// **'± {bpm} BPM'**
  String autoDjBpmTolerance(int bpm);

  /// Harmonic mixing row.
  ///
  /// In en, this message translates to:
  /// **'Harmonic mixing'**
  String get autoDjHarmonicTitle;

  /// No description provided for @autoDjHarmonicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer picks in keys that mix well with the locked song (Camelot wheel neighbours).'**
  String get autoDjHarmonicSubtitle;

  /// Auto DJ status block + enable button.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ is on'**
  String get autoDjStatusOn;

  /// No description provided for @autoDjStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ is off'**
  String get autoDjStatusOff;

  /// No description provided for @autoDjStatusOffDetail.
  ///
  /// In en, this message translates to:
  /// **'Tap below to start. The current server\'s library will be used.'**
  String get autoDjStatusOffDetail;

  /// No description provided for @autoDjStart.
  ///
  /// In en, this message translates to:
  /// **'Start Auto DJ'**
  String get autoDjStart;

  /// No description provided for @autoDjStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Auto DJ'**
  String get autoDjStop;

  /// Auto DJ on-state detail line.
  ///
  /// In en, this message translates to:
  /// **'Songs are picked from {url} when the queue runs low.'**
  String autoDjStatusOnDetail(String url);

  /// Server-picker + sources section.
  ///
  /// In en, this message translates to:
  /// **'Active source'**
  String get autoDjActiveSource;

  /// No description provided for @autoDjActiveSourceTap.
  ///
  /// In en, this message translates to:
  /// **'Active source — tap to switch'**
  String get autoDjActiveSourceTap;

  /// No description provided for @autoDjSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get autoDjSwitch;

  /// No description provided for @autoDjOneSourceRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one source is required.'**
  String get autoDjOneSourceRequired;

  /// Minimum-rating filter row ('Any' = no minimum).
  ///
  /// In en, this message translates to:
  /// **'Minimum rating'**
  String get autoDjMinRating;

  /// No description provided for @autoDjMinRatingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only pick songs at or above this rating.'**
  String get autoDjMinRatingSubtitle;

  /// No description provided for @autoDjRatingAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get autoDjRatingAny;

  /// Genre filter section.
  ///
  /// In en, this message translates to:
  /// **'Genre filter'**
  String get autoDjGenreTitle;

  /// No description provided for @autoDjGenreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Whitelist plays only matching tracks; blacklist skips them.'**
  String get autoDjGenreSubtitle;

  /// No description provided for @autoDjWhitelist.
  ///
  /// In en, this message translates to:
  /// **'Whitelist'**
  String get autoDjWhitelist;

  /// No description provided for @autoDjBlacklist.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get autoDjBlacklist;

  /// No description provided for @autoDjNoGenres.
  ///
  /// In en, this message translates to:
  /// **'No genres selected. Tap \"Pick genres\" to choose.'**
  String get autoDjNoGenres;

  /// No description provided for @autoDjPickGenres.
  ///
  /// In en, this message translates to:
  /// **'Pick genres'**
  String get autoDjPickGenres;

  /// No description provided for @autoDjGenreLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load genres'**
  String get autoDjGenreLoadError;

  /// Keyword filter section.
  ///
  /// In en, this message translates to:
  /// **'Keyword filter'**
  String get autoDjKeywordTitle;

  /// No description provided for @autoDjKeywordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip picks whose title, artist, album, or filepath contains any of these words.'**
  String get autoDjKeywordSubtitle;

  /// No description provided for @autoDjNoKeywords.
  ///
  /// In en, this message translates to:
  /// **'No keywords. Add words below to start filtering.'**
  String get autoDjNoKeywords;

  /// No description provided for @autoDjKeywordHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"live\" or \"remix\"'**
  String get autoDjKeywordHint;

  /// Genre picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Search genres…'**
  String get autoDjSearchGenres;

  /// No description provided for @autoDjNoGenresOnServer.
  ///
  /// In en, this message translates to:
  /// **'No genres found on this server.'**
  String get autoDjNoGenresOnServer;

  /// Count of selected genres in the picker header.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String autoDjSelectedCount(int count);

  /// Empty-search state in the genre picker.
  ///
  /// In en, this message translates to:
  /// **'No genres match \"{query}\".'**
  String autoDjNoGenresMatch(String query);

  /// Generic Download / Add All action labels (browser toolbar + swipe actions).
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @addAll.
  ///
  /// In en, this message translates to:
  /// **'Add All'**
  String get addAll;

  /// Browser delete-confirmation dialog titles + search hint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete Playlist'**
  String get browserConfirmDeletePlaylist;

  /// No description provided for @browserConfirmDeleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete Folder'**
  String get browserConfirmDeleteFolder;

  /// No description provided for @browserSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Database'**
  String get browserSearchHint;

  /// Search-category checkbox dropdown: tooltip on the icon button, the menu header, and the five category labels (which categories the DB search queries — the user ticks any combination).
  ///
  /// In en, this message translates to:
  /// **'What to search'**
  String get searchCategoriesTooltip;

  /// No description provided for @searchCategoriesHeader.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get searchCategoriesHeader;

  /// No description provided for @searchCategoryArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchCategoryArtists;

  /// No description provided for @searchCategoryAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get searchCategoryAlbums;

  /// No description provided for @searchCategorySongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get searchCategorySongs;

  /// No description provided for @searchCategoryFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get searchCategoryFiles;

  /// No description provided for @searchCategoryLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get searchCategoryLyrics;

  /// Thin subheader on the search-results page echoing the submitted query.
  ///
  /// In en, this message translates to:
  /// **'Results for “{term}”'**
  String searchSubheaderResults(String term);

  /// Thin subheader shown while the server-search field is focused, previewing which categories (e.g. "Artists · Albums") a search will cover.
  ///
  /// In en, this message translates to:
  /// **'Searching: {categories}'**
  String searchSubheaderCategories(String categories);

  /// Snackbar after queueing downloads from the browser.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 download started} other{{count} downloads started}}'**
  String browserDownloadsStarted(int count);

  /// Snackbar after Add-All from the browser.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song added to queue} other{{count} songs added to queue}}'**
  String browserSongsAdded(int count);

  /// Main scaffold: tabs, drawer header, queue header, toolbar.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get tabBrowser;

  /// No description provided for @tabQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get tabQueue;

  /// No description provided for @drawerTagline.
  ///
  /// In en, this message translates to:
  /// **'Personal music streaming'**
  String get drawerTagline;

  /// No description provided for @mainFailedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed To Connect To Server'**
  String get mainFailedToConnect;

  /// No description provided for @mainQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get mainQueueEmpty;

  /// No description provided for @visualizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get visualizerTitle;

  /// No description provided for @mainClearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get mainClearQueue;

  /// No description provided for @mainSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get mainSync;

  /// Queue tab header count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track in queue} other{{count} tracks in queue}}'**
  String mainQueueCount(int count);

  /// Bottom-bar Auto DJ toggle snackbars.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ Enabled'**
  String get autoDjEnabled;

  /// No description provided for @autoDjDisabled.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ Disabled'**
  String get autoDjDisabled;

  /// Bottom-bar Auto DJ enable snackbar naming the server.
  ///
  /// In en, this message translates to:
  /// **'Auto DJ Enabled For {url}'**
  String autoDjEnabledFor(String url);

  /// Add-to-playlist bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylistTitle;

  /// No description provided for @addToPlaylistEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet — tap + to create one.'**
  String get addToPlaylistEmpty;

  /// Snackbar after adding a track to a playlist.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String addedToPlaylist(String name);

  /// Test-connection results after a credentialed login attempt.
  ///
  /// In en, this message translates to:
  /// **'Connected — signed in successfully.'**
  String get testConnectedSignedIn;

  /// No description provided for @testSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Server reached, but sign-in failed — check your username and password.'**
  String get testSignInFailed;

  /// Built-in browser node names + tab/breadcrumb labels. Server folder names are NOT translated.
  ///
  /// In en, this message translates to:
  /// **'File Explorer'**
  String get browserFileExplorer;

  /// No description provided for @browserLocalFiles.
  ///
  /// In en, this message translates to:
  /// **'Local Files'**
  String get browserLocalFiles;

  /// No description provided for @browserPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get browserPlaylists;

  /// No description provided for @browserAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get browserAlbums;

  /// No description provided for @browserArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get browserArtists;

  /// No description provided for @browserRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get browserRecent;

  /// No description provided for @browserRated.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get browserRated;

  /// No description provided for @browserSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get browserSearch;

  /// No description provided for @browserWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to mStream'**
  String get browserWelcomeTitle;

  /// No description provided for @browserWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap here to add a server'**
  String get browserWelcomeSubtitle;

  /// Visualizer tuning-knobs toggle + overlay chrome (DSP param labels stay English).
  ///
  /// In en, this message translates to:
  /// **'Visualizer tuning knobs'**
  String get settingsVisualizerKnobs;

  /// No description provided for @settingsVisualizerKnobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show live sliders over the visualizer to tweak each shader\'s audio reactivity. Shader engine only.'**
  String get settingsVisualizerKnobsSubtitle;

  /// No description provided for @visualizerTuningTitle.
  ///
  /// In en, this message translates to:
  /// **'Tuning'**
  String get visualizerTuningTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @migMoveStopped.
  ///
  /// In en, this message translates to:
  /// **'Move stopped — not enough space, or the location is unavailable.'**
  String get migMoveStopped;

  /// No description provided for @migMoveComplete.
  ///
  /// In en, this message translates to:
  /// **'Move complete'**
  String get migMoveComplete;

  /// Migration banner: move finished, N files skipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Move complete — 1 file skipped (unsupported on the destination)} other{Move complete — {count} files skipped (unsupported on the destination)}}'**
  String migMoveCompleteSkipped(int count);

  /// Migration banner while a move runs; {progress} is a percent or M/T string.
  ///
  /// In en, this message translates to:
  /// **'Moving downloads… {progress} — keep the app open'**
  String migMoving(String progress);

  /// No description provided for @migRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get migRetry;

  /// No description provided for @queueDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get queueDownloadAll;

  /// Queue download-all confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track will be downloaded for offline playback.} other{{count} tracks will be downloaded for offline playback.}}'**
  String queueDownloadAllBody(int count);

  /// No description provided for @mainMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get mainMore;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @settingsCastQuality.
  ///
  /// In en, this message translates to:
  /// **'Cast visualizer quality'**
  String get settingsCastQuality;

  /// No description provided for @settingsCastQualitySubtitle720.
  ///
  /// In en, this message translates to:
  /// **'Resolution the visualizer streams to a TV at. 720p — lightest on the phone.'**
  String get settingsCastQualitySubtitle720;

  /// No description provided for @settingsCastQualitySubtitle1080.
  ///
  /// In en, this message translates to:
  /// **'Resolution the visualizer streams to a TV at. 1080p — sharp on any Chromecast (default).'**
  String get settingsCastQualitySubtitle1080;

  /// No description provided for @settingsCastQualitySubtitle4k.
  ///
  /// In en, this message translates to:
  /// **'Resolution the visualizer streams to a TV at. 4K — needs a 4K Chromecast; much heavier on the phone.'**
  String get settingsCastQualitySubtitle4k;

  /// No description provided for @eqCasting.
  ///
  /// In en, this message translates to:
  /// **'The equalizer adjusts audio on this device, so it’s unavailable while casting. Disconnect to use it.'**
  String get eqCasting;

  /// No description provided for @browserNothingToDownload.
  ///
  /// In en, this message translates to:
  /// **'Nothing to download in this list'**
  String get browserNothingToDownload;

  /// No description provided for @browserDownloadAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get browserDownloadAllTitle;

  /// Browser download-all confirm dialog body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file will be downloaded.} other{{count} files will be downloaded.}}'**
  String browserDownloadAllConfirm(int count);

  /// No description provided for @browserCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get browserCloseSearch;

  /// No description provided for @browserSearchThisList.
  ///
  /// In en, this message translates to:
  /// **'Search this list'**
  String get browserSearchThisList;

  /// No description provided for @browserSearchList.
  ///
  /// In en, this message translates to:
  /// **'Search list'**
  String get browserSearchList;

  /// Browser local-search empty state.
  ///
  /// In en, this message translates to:
  /// **'No matches for \"{query}\"'**
  String browserNoMatches(String query);

  /// Shown in place of the browse list when a loaded folder or section has no items (e.g. the file explorer of a server with no music folders configured).
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get browserEmptyList;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @dlLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Download location unavailable'**
  String get dlLocationUnavailable;

  /// No description provided for @dlLocationUnavailableServer.
  ///
  /// In en, this message translates to:
  /// **'Download location unavailable for this server.'**
  String get dlLocationUnavailableServer;

  /// No description provided for @dlFailed.
  ///
  /// In en, this message translates to:
  /// **'A download failed — check your connection.'**
  String get dlFailed;

  /// No description provided for @dlFatSkip.
  ///
  /// In en, this message translates to:
  /// **'Some tracks can\'t be saved on this card — their names aren\'t supported. They stream instead.'**
  String get dlFatSkip;

  /// No description provided for @dlServerGone.
  ///
  /// In en, this message translates to:
  /// **'That server is no longer configured.'**
  String get dlServerGone;

  /// No description provided for @dlStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Storage location unavailable — reconnect the SD card or change this server\'s storage location in Edit Server.'**
  String get dlStorageUnavailable;

  /// No description provided for @dlCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Could not start download — storage unavailable.'**
  String get dlCouldNotStart;

  /// No description provided for @storageLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage location'**
  String get storageLocationLabel;

  /// No description provided for @storageAppLocal.
  ///
  /// In en, this message translates to:
  /// **'App local'**
  String get storageAppLocal;

  /// No description provided for @storagePermanent.
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get storagePermanent;

  /// No description provided for @storageSdCard.
  ///
  /// In en, this message translates to:
  /// **'SD card'**
  String get storageSdCard;

  /// No description provided for @storageSdSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Save to SD card'**
  String get storageSdSwitchTitle;

  /// No description provided for @storageSdSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.'**
  String get storageSdSwitchSubtitle;

  /// No description provided for @storageHelpAppLocal.
  ///
  /// In en, this message translates to:
  /// **'Saved inside the app. Deleted when you uninstall or clear the app.'**
  String get storageHelpAppLocal;

  /// No description provided for @storageHelpPermanent.
  ///
  /// In en, this message translates to:
  /// **'Saved to a folder you choose. Survives uninstalling the app. Requires \"All files access\".'**
  String get storageHelpPermanent;

  /// No description provided for @storageHelpSdCard.
  ///
  /// In en, this message translates to:
  /// **'Saved to a folder on the SD card you choose. May become unavailable if the card is removed. Some devices don\'t let apps write to SD cards — if folder selection keeps failing, use Permanent or App local.'**
  String get storageHelpSdCard;

  /// No description provided for @storageChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get storageChooseFolder;

  /// No description provided for @storageNoFolderChosen.
  ///
  /// In en, this message translates to:
  /// **'No folder chosen yet'**
  String get storageNoFolderChosen;

  /// No description provided for @storageDownloadFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get storageDownloadFolderLabel;

  /// No description provided for @storageDownloadFolderHint.
  ///
  /// In en, this message translates to:
  /// **'folder name'**
  String get storageDownloadFolderHint;

  /// No description provided for @storageBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get storageBrowse;

  /// No description provided for @storageDownloadFolderHelp.
  ///
  /// In en, this message translates to:
  /// **'Files download to a \'media/<folder>\' directory on this device. Re-using a previous server\'s folder keeps its downloaded songs when you re-add a lost server.'**
  String get storageDownloadFolderHelp;

  /// No description provided for @storageNoStorageAvailable.
  ///
  /// In en, this message translates to:
  /// **'No storage available'**
  String get storageNoStorageAvailable;

  /// No description provided for @storageNoDownloadFolders.
  ///
  /// In en, this message translates to:
  /// **'No existing download folders found'**
  String get storageNoDownloadFolders;

  /// No description provided for @storageExistingFolders.
  ///
  /// In en, this message translates to:
  /// **'Existing download folders'**
  String get storageExistingFolders;

  /// Existing-folders list: item count for a folder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String storageItemCount(int count);

  /// No description provided for @storageAllFilesAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant \"All files access\" to store downloads permanently, then pick the mode again.'**
  String get storageAllFilesAccess;

  /// No description provided for @storageSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get storageSettings;

  /// No description provided for @storageNoVolume.
  ///
  /// In en, this message translates to:
  /// **'Could not locate a storage volume'**
  String get storageNoVolume;

  /// No description provided for @storageNotWritable.
  ///
  /// In en, this message translates to:
  /// **'That folder isn\'t writable — pick another.'**
  String get storageNotWritable;

  /// No description provided for @storageNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get storageNewFolder;

  /// No description provided for @storageFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get storageFolderNameHint;

  /// No description provided for @storageCouldNotCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not create folder'**
  String get storageCouldNotCreateFolder;

  /// No description provided for @storageNoSubfolders.
  ///
  /// In en, this message translates to:
  /// **'No subfolders here'**
  String get storageNoSubfolders;

  /// No description provided for @storageUseThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Use this folder'**
  String get storageUseThisFolder;

  /// No description provided for @storageMovedToNewFolder.
  ///
  /// In en, this message translates to:
  /// **'Moved downloaded files to the new folder.'**
  String get storageMovedToNewFolder;

  /// No description provided for @storageMoveAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A move is already running — let it finish first.'**
  String get storageMoveAlreadyRunning;

  /// No description provided for @storageMigrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Different storage volume'**
  String get storageMigrateTitle;

  /// Cross-volume migration dialog body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This server’s 1 downloaded file ({size}) is on a different storage volume from the new location. Choose what to do:} other{This server’s {count} downloaded files ({size}) are on a different storage volume from the new location. Choose what to do:}}'**
  String storageMigrateBody(int count, String size);

  /// Migration dialog low-space warning.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space at the destination ({free} free). A move may fail partway — free up space first.'**
  String storageMigrateNoSpace(String free);

  /// No description provided for @storageMigrateMove.
  ///
  /// In en, this message translates to:
  /// **'Move them'**
  String get storageMigrateMove;

  /// No description provided for @storageMigrateMoveBody.
  ///
  /// In en, this message translates to:
  /// **'Copy to the new location in the background, deleting each old copy as it goes. Keep the app open until it finishes.'**
  String get storageMigrateMoveBody;

  /// No description provided for @storageMigrateLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave them'**
  String get storageMigrateLeave;

  /// No description provided for @storageMigrateLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Switch now; the old downloads stay where they are and re-download at the new location.'**
  String get storageMigrateLeaveBody;

  /// No description provided for @storageMigrateDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete old downloads'**
  String get storageMigrateDelete;

  /// No description provided for @storageMigrateDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Switch now and remove the old files; they\'ll re-download at the new location.'**
  String get storageMigrateDeleteBody;

  /// No description provided for @storageMovingBackground.
  ///
  /// In en, this message translates to:
  /// **'Moving your downloads in the background — keep the app open.'**
  String get storageMovingBackground;

  /// No description provided for @storageChooseFolderFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a download folder first.'**
  String get storageChooseFolderFirst;

  /// No description provided for @storageChooseSdFolderFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder on the SD card first. If every folder is rejected, your device may not let apps write to the card — use Permanent or App local instead.'**
  String get storageChooseSdFolderFirst;

  /// No description provided for @castPlayOn.
  ///
  /// In en, this message translates to:
  /// **'Play on'**
  String get castPlayOn;

  /// No description provided for @castPlayOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play on…'**
  String get castPlayOnTooltip;

  /// No description provided for @castSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for cast devices…'**
  String get castSearching;

  /// No description provided for @castNotSeeing.
  ///
  /// In en, this message translates to:
  /// **'Don\'t see your device? Make sure it\'s on the same Wi-Fi.'**
  String get castNotSeeing;

  /// No description provided for @castVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Cast visualizer'**
  String get castVisualizer;

  /// No description provided for @castVisualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stream the visualizer to the TV · Chromecast only'**
  String get castVisualizerSubtitle;

  /// No description provided for @visualizerNoKnobs.
  ///
  /// In en, this message translates to:
  /// **'This shader exposes no knobs.'**
  String get visualizerNoKnobs;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @playerLayoutSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get playerLayoutSmall;

  /// No description provided for @playerLayoutMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get playerLayoutMedium;

  /// No description provided for @playerLayoutLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get playerLayoutLarge;

  /// No description provided for @playerLayoutXl.
  ///
  /// In en, this message translates to:
  /// **'XL'**
  String get playerLayoutXl;

  /// No description provided for @playerLayoutSmallDesc.
  ///
  /// In en, this message translates to:
  /// **'Slim bar — maximum queue'**
  String get playerLayoutSmallDesc;

  /// No description provided for @playerLayoutMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'Banner — balanced (default)'**
  String get playerLayoutMediumDesc;

  /// No description provided for @playerLayoutLargeDesc.
  ///
  /// In en, this message translates to:
  /// **'Compact — centered art'**
  String get playerLayoutLargeDesc;

  /// No description provided for @playerLayoutXlDesc.
  ///
  /// In en, this message translates to:
  /// **'Hero — full album art'**
  String get playerLayoutXlDesc;

  /// No description provided for @queueNothingToDownloadEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty — nothing to download'**
  String get queueNothingToDownloadEmpty;

  /// No description provided for @queueNothingToDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Nothing to download — tracks are already saved'**
  String get queueNothingToDownloadSaved;

  /// No description provided for @settingsAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColor;

  /// No description provided for @settingsAccentColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The highlight color used across the app.'**
  String get settingsAccentColorSubtitle;

  /// No description provided for @accentThemeDefault.
  ///
  /// In en, this message translates to:
  /// **'Theme default'**
  String get accentThemeDefault;

  /// No description provided for @accentCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get accentCustom;

  /// No description provided for @lanOnYourNetwork.
  ///
  /// In en, this message translates to:
  /// **'Servers on your local network'**
  String get lanOnYourNetwork;

  /// No description provided for @lanSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for servers…'**
  String get lanSearching;

  /// No description provided for @lanRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get lanRefresh;

  /// No description provided for @lanServerVersion.
  ///
  /// In en, this message translates to:
  /// **'mStream v{version}'**
  String lanServerVersion(String version);

  /// No description provided for @lanLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {name}'**
  String lanLoginTitle(String name);

  /// No description provided for @lanUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach this server on the network.'**
  String get lanUnreachable;

  /// No description provided for @lanNoCode.
  ///
  /// In en, this message translates to:
  /// **'Quick Connect is on for this server, but it didn\'t share a pairing code. Sign in as an admin, or ask the operator to enable code sharing.'**
  String get lanNoCode;

  /// No description provided for @settingsResumeQueue.
  ///
  /// In en, this message translates to:
  /// **'Resume queue on launch'**
  String get settingsResumeQueue;

  /// No description provided for @settingsResumeQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save the play queue and your place, and restore them when you reopen the app.'**
  String get settingsResumeQueueSubtitle;

  /// No description provided for @settingsOfflineQueue.
  ///
  /// In en, this message translates to:
  /// **'Keep queue available offline'**
  String get settingsOfflineQueue;

  /// No description provided for @settingsOfflineQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically download queued tracks to this device so playback survives losing the connection.'**
  String get settingsOfflineQueueSubtitle;

  /// No description provided for @settingsOfflineQueueWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Download on Wi-Fi only'**
  String get settingsOfflineQueueWifiOnly;

  /// No description provided for @settingsOfflineQueueWifiOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wait for Wi-Fi before downloading queued tracks.'**
  String get settingsOfflineQueueWifiOnlySubtitle;

  /// Title of the keep-queue-offline retention-cap setting.
  ///
  /// In en, this message translates to:
  /// **'Auto-download limit'**
  String get settingsAutoDownloadCap;

  /// Subtitle when a finite auto-download cap is set.
  ///
  /// In en, this message translates to:
  /// **'Keep the newest this many auto-downloads; older ones no longer in your queue are removed.'**
  String get settingsAutoDownloadCapSubtitle;

  /// Subtitle when the auto-download cap is unlimited (0).
  ///
  /// In en, this message translates to:
  /// **'Keep every auto-downloaded track (no limit).'**
  String get settingsAutoDownloadCapSubtitleUnlimited;

  /// Shown as the auto-download cap value when there's no limit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get settingsAutoDownloadCapUnlimited;

  /// Text field label in the auto-download limit dialog.
  ///
  /// In en, this message translates to:
  /// **'Number of tracks'**
  String get settingsAutoDownloadCapField;

  /// Explainer in the auto-download limit dialog.
  ///
  /// In en, this message translates to:
  /// **'Automatically downloaded tracks kept for offline play. When you go over, the oldest ones that aren\'t in your queue are deleted. Set to 0 to keep everything.'**
  String get settingsAutoDownloadCapDialogBody;

  /// No description provided for @downloadWaitingWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get downloadWaitingWifi;

  /// No description provided for @settingsRatingHalf.
  ///
  /// In en, this message translates to:
  /// **'Half-star ratings'**
  String get settingsRatingHalf;

  /// No description provided for @settingsRatingHalfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate songs in half-star steps (long-press a star).'**
  String get settingsRatingHalfSubtitle;

  /// No description provided for @ratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get ratingTitle;

  /// No description provided for @ratingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save rating'**
  String get ratingFailed;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable logging'**
  String get diagnosticsEnable;

  /// No description provided for @diagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'Logs stay on your device. Tokens are hidden before copying or sharing.'**
  String get diagnosticsHint;

  /// No description provided for @diagnosticsVerbose.
  ///
  /// In en, this message translates to:
  /// **'Verbose logging'**
  String get diagnosticsVerbose;

  /// No description provided for @diagnosticsVerboseHint.
  ///
  /// In en, this message translates to:
  /// **'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.'**
  String get diagnosticsVerboseHint;

  /// No description provided for @diagnosticsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get diagnosticsCopy;

  /// No description provided for @diagnosticsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get diagnosticsShare;

  /// No description provided for @diagnosticsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diagnosticsClear;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get diagnosticsEmpty;

  /// No description provided for @storageAppExternal.
  ///
  /// In en, this message translates to:
  /// **'App external'**
  String get storageAppExternal;

  /// No description provided for @selfSignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow self-signed certificate'**
  String get selfSignedTitle;

  /// No description provided for @selfSignedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip TLS validation for this server. Only enable on a network you trust.'**
  String get selfSignedSubtitle;

  /// Title of the Imported Shaders screen and its Settings entry.
  ///
  /// In en, this message translates to:
  /// **'Imported shaders'**
  String get importedShadersTitle;

  /// Subtitle under the Imported shaders entry in Settings.
  ///
  /// In en, this message translates to:
  /// **'Add your own .glsl files to the Shader engine rotation.'**
  String get importedShadersSettingsSubtitle;

  /// Tooltip for the button that re-scans the shader folder for new files.
  ///
  /// In en, this message translates to:
  /// **'Rescan folder'**
  String get importedShadersRescan;

  /// Instruction shown above the shader folder path.
  ///
  /// In en, this message translates to:
  /// **'Drop .glsl files in this folder, then Rescan:'**
  String get importedShadersDropHint;

  /// Tooltip for the button that copies the shader folder path to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get importedShadersCopyPath;

  /// Help text explaining where the shader folder is and when imported shaders are used.
  ///
  /// In en, this message translates to:
  /// **'Reachable over USB or a file manager (under Android/data). Imported shaders join the rotation when the Shader engine is active.'**
  String get importedShadersReachableHint;

  /// Tooltip for the button that deletes an imported shader file.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get importedShadersRemove;

  /// Empty-state title when the shader folder has no files.
  ///
  /// In en, this message translates to:
  /// **'No shaders in the folder yet'**
  String get importedShadersEmptyTitle;

  /// Empty-state body when the shader folder has no files.
  ///
  /// In en, this message translates to:
  /// **'Copy Shadertoy-style .glsl files into the folder above, then tap Rescan.'**
  String get importedShadersEmptyBody;

  /// Warning subtitle when an imported file does not look like a fragment shader.
  ///
  /// In en, this message translates to:
  /// **'May not be a valid shader — no mainImage/main entry point.'**
  String get importedShadersInvalid;

  /// Button that copies .glsl shaders found in the device Downloads folder into the shader folder.
  ///
  /// In en, this message translates to:
  /// **'Import .glsl from Downloads'**
  String get importedShadersImportDownloads;

  /// Snackbar after copying shaders in from the Downloads folder.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} shader(s) from Downloads'**
  String importedShadersDownloadsImported(int count);

  /// Snackbar when the Downloads folder has no new shaders to import.
  ///
  /// In en, this message translates to:
  /// **'No new .glsl files in Downloads'**
  String get importedShadersDownloadsNone;

  /// Snackbar when all-files access is denied, so Downloads can't be read.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is needed to read Downloads'**
  String get importedShadersDownloadsNoPermission;

  /// Add-server form: tab label for the classic HTTP URL connection (paired with the 'Quick Connect' tab).
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get addServerTabUrl;

  /// Add-server form: tab label for the iroh peer-to-peer pairing flow (paired with the 'Server URL' tab).
  ///
  /// In en, this message translates to:
  /// **'Quick Connect'**
  String get addServerTabQuickConnect;

  /// Title at the top of the Quick Connect tab.
  ///
  /// In en, this message translates to:
  /// **'Connect peer-to-peer'**
  String get irohConnectHeader;

  /// Header of the manual pairing-code section on the Quick Connect tab.
  ///
  /// In en, this message translates to:
  /// **'Connect with a pairing code'**
  String get irohPairingHeader;

  /// Explainer under the Quick Connect tab title.
  ///
  /// In en, this message translates to:
  /// **'Reach your server from anywhere — no port-forwarding, DNS, or public IP needed.'**
  String get irohConnectBody;

  /// Explainer under the pairing-code section header on the Quick Connect tab.
  ///
  /// In en, this message translates to:
  /// **'Enable Remote Access on the server, then paste its pairing code or scan the QR.'**
  String get irohPairingBody;

  /// Shown on the iroh add-server tab when an iroh server already exists (only one is allowed).
  ///
  /// In en, this message translates to:
  /// **'Only one peer-to-peer (iroh) server is supported. Remove the existing one to connect a different server.'**
  String get irohOneServerLimit;

  /// Text field label for the iroh pairing code (add-server iroh tab and the re-pair sheet).
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get irohPairingCodeLabel;

  /// Hint text inside the iroh pairing-code field.
  ///
  /// In en, this message translates to:
  /// **'Paste the code from the server Remote Access panel'**
  String get irohPairingCodeHint;

  /// Server ⋮ menu action that displays the stored iroh pairing code as a QR.
  ///
  /// In en, this message translates to:
  /// **'Show pairing code'**
  String get irohShowPairingCode;

  /// Body text of the pairing-code QR sheet.
  ///
  /// In en, this message translates to:
  /// **'Scan with the mStream app on another device to connect it to this server, or copy the code and paste it there.'**
  String get irohQrBody;

  /// Caution line under the pairing QR — the code is a credential.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this code can connect to your server.'**
  String get irohQrCaution;

  /// Button that opens the camera to scan an iroh pairing QR code.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get irohScanQr;

  /// Button that pastes an iroh pairing code from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get irohPaste;

  /// Button that tests the iroh tunnel to the server.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get irohTestConnection;

  /// Busy label on the iroh Test-connection button while the test runs.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get irohTesting;

  /// App-bar title of the full-screen iroh QR scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan pairing QR'**
  String get irohScannerTitle;

  /// Shown when QR scanning is attempted where the iroh native lib is unavailable (desktop, or a 32-bit Android device without libiroh_tunnel.so).
  ///
  /// In en, this message translates to:
  /// **'QR scanning isn\'t available on this device.'**
  String get irohQrAndroidOnly;

  /// Chip on a Manage Servers row marking the server that is bundled with and managed by this app (desktop Server Mode).
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get serverBadgeBuiltIn;

  /// Shown in the Quick Connect tab (and on a test-connection attempt) where the iroh native lib is unavailable (desktop, or a 32-bit Android device without libiroh_tunnel.so).
  ///
  /// In en, this message translates to:
  /// **'Quick Connect isn\'t available on this device.'**
  String get irohAndroidOnly;

  /// Shown when the camera permission is denied while trying to scan an iroh QR.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is needed to scan a code.'**
  String get irohCameraPermission;

  /// Validation shown when testing the iroh connection with no pairing code entered.
  ///
  /// In en, this message translates to:
  /// **'Paste or scan a pairing code first.'**
  String get irohPasteFirst;

  /// Validation shown when trying to sign in before a successful iroh test connection.
  ///
  /// In en, this message translates to:
  /// **'Test the connection first.'**
  String get irohTestFirst;

  /// Result shown when the iroh test connection succeeds (server version unknown).
  ///
  /// In en, this message translates to:
  /// **'Connected through the iroh tunnel'**
  String get irohTestConnected;

  /// Result shown when the iroh test connection succeeds and the server reported its version.
  ///
  /// In en, this message translates to:
  /// **'Connected through the iroh tunnel — mStream v{version}'**
  String irohTestConnectedVersion(String version);

  /// Suffix appended to the iroh test result when the path is a direct (hole-punched) connection.
  ///
  /// In en, this message translates to:
  /// **' · direct'**
  String get irohPathSuffixDirect;

  /// Suffix appended to the iroh test result when the connection is routed through a relay.
  ///
  /// In en, this message translates to:
  /// **' · via relay'**
  String get irohPathSuffixRelay;

  /// Shown when the iroh tunnel connects but the server's HTTP reply times out.
  ///
  /// In en, this message translates to:
  /// **'Tunnel opened but the server did not respond in time.'**
  String get irohTunnelTimeout;

  /// Shown when the iroh tunnel test fails; {error} is the raw error text.
  ///
  /// In en, this message translates to:
  /// **'Tunnel test failed: {error}'**
  String irohTunnelTestFailed(String error);

  /// Header of the sign-in step on the iroh tab (after a successful test).
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get irohSignInHeader;

  /// Busy label on the iroh 'Sign in & save' button while signing in.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get irohSigningIn;

  /// Button that signs in through the iroh tunnel and saves the server.
  ///
  /// In en, this message translates to:
  /// **'Sign in & save'**
  String get irohSignInSave;

  /// Shown when signing in through the iroh tunnel times out.
  ///
  /// In en, this message translates to:
  /// **'Sign-in timed out.'**
  String get irohSignInTimeout;

  /// Shown when iroh sign-in fails unexpectedly; {error} is the raw error text.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String irohSignInFailed(String error);

  /// Shown when iroh sign-in returns an HTTP error; {status} is the HTTP status code.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed (HTTP {status}). Check your username and password.'**
  String irohSignInFailedHttp(int status);

  /// Banner while the iroh tunnel is making its first connection.
  ///
  /// In en, this message translates to:
  /// **'Connecting to server…'**
  String get irohBannerConnecting;

  /// Banner while the iroh tunnel is re-dialing after a drop.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to server…'**
  String get irohBannerReconnecting;

  /// Banner when the iroh tunnel is down; paired with a Retry action.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from server.'**
  String get irohBannerDisconnected;

  /// Banner when the iroh tunnel is connected but routed through a relay (not direct).
  ///
  /// In en, this message translates to:
  /// **'Connected via relay — slower path.'**
  String get irohBannerRelay;

  /// Banner when the server's connect secret was rotated; paired with a Re-pair action.
  ///
  /// In en, this message translates to:
  /// **'Server pairing changed — re-pair to reconnect.'**
  String get irohBannerRepair;

  /// Action button to re-pair an iroh server (banner) and confirm in the re-pair sheet.
  ///
  /// In en, this message translates to:
  /// **'Re-pair'**
  String get irohRepairAction;

  /// Action button to retry connecting a down iroh tunnel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get irohRetry;

  /// Title of the iroh re-pair bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Re-pair server'**
  String get irohRepairTitle;

  /// Explainer in the iroh re-pair sheet.
  ///
  /// In en, this message translates to:
  /// **'This server\'s pairing code changed (its secret was rotated). Paste or scan the new code from the server\'s Remote Access panel.'**
  String get irohRepairBody;

  /// Snackbar in the re-pair sheet when the new pairing code fails to connect; the previous code is kept.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect with that code — check it and try again.'**
  String get irohRepairFailed;

  /// Chip label on the active iroh server's tile when the connection is direct (hole-punched).
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get irohPathDirect;

  /// Chip label on the active iroh server's tile when the connection is routed through a relay.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get irohPathRelay;

  /// Note in the cast picker when the active server is an iroh (peer-to-peer) server.
  ///
  /// In en, this message translates to:
  /// **'Casting to external devices isn\'t available for peer-to-peer (iroh) servers — playback stays on this device.'**
  String get irohCastUnavailable;

  /// Shown when trying to share tracks from an iroh (peer-to-peer) server.
  ///
  /// In en, this message translates to:
  /// **'Sharing isn\'t available for peer-to-peer (iroh) servers — they have no public URL to link to.'**
  String get irohShareUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'ja',
    'pl',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
