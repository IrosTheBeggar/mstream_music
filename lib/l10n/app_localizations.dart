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

  /// No description provided for @testCouldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check the URL and try again.'**
  String get testCouldNotConnect;

  /// No description provided for @testTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out.'**
  String get testTimedOut;

  /// No description provided for @connectFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server. Check the URL and try again.'**
  String get connectFailedSnack;

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

  /// Search-category checkbox dropdown: tooltip on the icon button, the menu header, and the four category labels (which categories the DB search queries — the user ticks any combination).
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

  /// Log out action in the admin panel (drawer and web app bar).
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get adminLogOut;

  /// Navigation group header for configuration sections in the admin drawer.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get adminConfigGroup;

  /// Nav label and DLNA dropdown item for the Directories / library directories section.
  ///
  /// In en, this message translates to:
  /// **'Directories'**
  String get adminDirectories;

  /// Navigation label for the Users management section.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// Navigation label for the DLNA section (protocol acronym, not translated).
  ///
  /// In en, this message translates to:
  /// **'DLNA'**
  String get adminDLNA;

  /// Navigation label and card title for the Subsonic API section.
  ///
  /// In en, this message translates to:
  /// **'Subsonic API'**
  String get adminSubsonicAPI;

  /// Navigation label for the MP3 Player (server audio) section.
  ///
  /// In en, this message translates to:
  /// **'MP3 Player'**
  String get adminMP3Player;

  /// Navigation label and per-user permission toggle for the Torrent feature.
  ///
  /// In en, this message translates to:
  /// **'Torrent'**
  String get adminTorrent;

  /// Navigation label and card title for the Federation section.
  ///
  /// In en, this message translates to:
  /// **'Federation'**
  String get adminFederation;

  /// Navigation group header for server sections in the admin drawer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get adminServerGroup;

  /// Navigation label for the About section.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get adminAbout;

  /// Navigation label for the Settings section.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get adminSettings;

  /// Navigation label for the Database section.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get adminDatabase;

  /// Navigation label for the Backups section.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get adminBackups;

  /// Navigation label for the Transcoding section.
  ///
  /// In en, this message translates to:
  /// **'Transcoding'**
  String get adminTranscoding;

  /// Navigation label for the Logs section.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get adminLogs;

  /// Navigation label for the Admin Access (network access control) section.
  ///
  /// In en, this message translates to:
  /// **'Admin Access'**
  String get adminAccess;

  /// Admin app bar title combining the brand with the active section label.
  ///
  /// In en, this message translates to:
  /// **'mStream Admin · {label}'**
  String adminAppBarTitle(String label);

  /// Brand title shown on admin panel card, login card, and web app bar.
  ///
  /// In en, this message translates to:
  /// **'mStream Admin'**
  String get adminPanelTitle;

  /// Login validation error when server URL or username is empty.
  ///
  /// In en, this message translates to:
  /// **'Server and username are required'**
  String get adminLoginErrorRequired;

  /// Login form field label for the server URL.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get adminLoginServerURL;

  /// Login form field label for the username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get adminLoginUsername;

  /// Login form field label for the password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get adminLoginPassword;

  /// Login submit button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get adminLoginSignIn;

  /// Retry button shown on error states to re-attempt loading.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// Inline confirmation shown after a setting is saved (text fields and dropdowns).
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get adminSaved;

  /// Generic Save button used across dialogs and forms.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminSave;

  /// Close button/action for dialogs and the embedded admin launcher.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminClose;

  /// Overflow menu item in Manage Server that opens the admin panel.
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminPanelMenuItem;

  /// Empty-state title on the Directories view when no libraries exist.
  ///
  /// In en, this message translates to:
  /// **'No libraries yet'**
  String get adminNoLibrariesYetTitle;

  /// Empty-state hint on the Directories view.
  ///
  /// In en, this message translates to:
  /// **'Add a directory to start scanning music into the library.'**
  String get adminAddDirectoryHint;

  /// Button to add a new library directory (also used as the add-directory dialog button).
  ///
  /// In en, this message translates to:
  /// **'Add directory'**
  String get adminAddDirectoryButton;

  /// Confirmation dialog title when removing a library directory; {name} is the library name.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String adminRemoveDirectoryTitle(String name);

  /// Warning body in the remove-directory confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This removes the library and its scanned tracks from the database. Files on disk are left untouched.'**
  String get adminRemoveDirectoryWarning;

  /// Generic Cancel button used across dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// Generic Remove button/tooltip used to remove an item (library, torrent, etc.).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminRemove;

  /// Toast confirming a library was removed.
  ///
  /// In en, this message translates to:
  /// **'Library removed'**
  String get adminLibraryRemovedToast;

  /// Info row label showing a directory's filesystem path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get adminDirectoryPathLabel;

  /// Info row label showing a directory's library type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminDirectoryTypeLabel;

  /// Toggle title for following symlinks when scanning a directory.
  ///
  /// In en, this message translates to:
  /// **'Follow symlinks'**
  String get adminFollowSymlinksTitle;

  /// Toggle subtitle clarifying when the follow-symlinks setting applies.
  ///
  /// In en, this message translates to:
  /// **'Takes effect on the next scan'**
  String get adminFollowSymlinksSubtitle;

  /// Validation toast when adding a directory without a folder or name.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder and enter a name'**
  String get adminPickFolderAndNameError;

  /// Toast confirming a directory was added and scanning began.
  ///
  /// In en, this message translates to:
  /// **'Directory added — scanning started'**
  String get adminDirectoryAddedToast;

  /// Title of the add-directory dialog.
  ///
  /// In en, this message translates to:
  /// **'Add directory'**
  String get adminAddDirectoryDialogTitle;

  /// Button opening the server folder picker in the add-directory dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose folder on server…'**
  String get adminChooseFolderButton;

  /// Field label for the library name (virtual path) when adding a directory.
  ///
  /// In en, this message translates to:
  /// **'Library name (vpath)'**
  String get adminLibraryNameLabel;

  /// Helper text describing allowed characters for the library name.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers and dashes'**
  String get adminLibraryNameHelper;

  /// Toggle title to give every user access to the new library.
  ///
  /// In en, this message translates to:
  /// **'Grant all users access'**
  String get adminGrantAllUsersAccessTitle;

  /// Toggle title marking the library as an audiobook library.
  ///
  /// In en, this message translates to:
  /// **'Audiobook library'**
  String get adminAudiobookLibraryTitle;

  /// Add button confirming the add-directory dialog.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get adminAdd;

  /// Title of the server directory picker dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get adminChooseFolderTitle;

  /// Button confirming the currently browsed folder in the directory picker.
  ///
  /// In en, this message translates to:
  /// **'Select this folder'**
  String get adminSelectFolderButton;

  /// Empty-state title on the Users view when no users exist.
  ///
  /// In en, this message translates to:
  /// **'No users'**
  String get adminNoUsersTitle;

  /// Empty-state subtitle on the Users view.
  ///
  /// In en, this message translates to:
  /// **'With no users the server runs in open/public mode. Add one to require login.'**
  String get adminNoUsersSubtitle;

  /// Button to add a new user.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get adminAddUserButton;

  /// Dialog title for editing a user's per-library access.
  ///
  /// In en, this message translates to:
  /// **'Library access'**
  String get adminLibraryAccessDialogTitle;

  /// Toast confirming a user's library access was saved.
  ///
  /// In en, this message translates to:
  /// **'Library access updated'**
  String get adminLibraryAccessUpdatedToast;

  /// Dialog title and menu item for setting a user's Subsonic password.
  ///
  /// In en, this message translates to:
  /// **'Set Subsonic password'**
  String get adminSetSubsonicPasswordTitle;

  /// Dialog title and menu item for setting a user's password.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get adminSetPasswordTitle;

  /// Toast confirming a user's password was updated.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get adminPasswordUpdatedToast;

  /// Confirmation dialog title when deleting a user; {username} is the account name.
  ///
  /// In en, this message translates to:
  /// **'Delete {username}?'**
  String adminDeleteUserTitle(String username);

  /// Warning body in the delete-user confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes the user account.'**
  String get adminDeleteUserWarning;

  /// Generic Delete button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminDelete;

  /// Toast confirming a user was deleted.
  ///
  /// In en, this message translates to:
  /// **'User deleted'**
  String get adminUserDeletedToast;

  /// Status pill on a user row marking an administrator (lowercase token).
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get adminStatusPillLabel;

  /// Overflow menu item to delete a user.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get adminDeleteUserMenuItem;

  /// Info row shown when a user has access to no libraries.
  ///
  /// In en, this message translates to:
  /// **'No library access'**
  String get adminNoLibraryAccessLabel;

  /// Button on a user row opening the per-library access editor.
  ///
  /// In en, this message translates to:
  /// **'Libraries'**
  String get adminLibrariesButton;

  /// Compact permission toggle title marking a user as admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminAdminToggleTitle;

  /// Compact permission toggle: allow user to create directories.
  ///
  /// In en, this message translates to:
  /// **'Make dirs'**
  String get adminMakeDirsToggleTitle;

  /// Compact permission toggle: allow user to upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get adminUploadToggleTitle;

  /// Compact permission toggle: allow user to modify files.
  ///
  /// In en, this message translates to:
  /// **'Modify files'**
  String get adminModifyFilesToggleTitle;

  /// Compact permission toggle: allow user to use server audio.
  ///
  /// In en, this message translates to:
  /// **'Server audio'**
  String get adminServerAudioToggleTitle;

  /// Title of the add-user dialog.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get adminAddUserDialogTitle;

  /// Field label for a username (add-user dialog and Subsonic mint-key form).
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get adminUsername;

  /// Field label for a password (add-user dialog and torrent client form).
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get adminPassword;

  /// Field label for the optional Subsonic password in the add-user dialog.
  ///
  /// In en, this message translates to:
  /// **'Subsonic password (optional)'**
  String get adminSubsonicPasswordLabel;

  /// Group header in the add-user dialog for per-library access toggles.
  ///
  /// In en, this message translates to:
  /// **'Library access'**
  String get adminLibraryAccessHeader;

  /// Validation toast when creating a user without username or password.
  ///
  /// In en, this message translates to:
  /// **'Username and password are required'**
  String get adminUsernamePasswordRequiredError;

  /// Toast confirming a new user was created.
  ///
  /// In en, this message translates to:
  /// **'User created'**
  String get adminUserCreatedToast;

  /// Full-width permission toggle marking a user as administrator (add-user dialog).
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get adminAdministratorToggleTitle;

  /// Permission toggle: allow user to create directories (add-user dialog).
  ///
  /// In en, this message translates to:
  /// **'Allow make directories'**
  String get adminAllowMakeDirectoriesTitle;

  /// Permission toggle: allow user to upload (add-user dialog).
  ///
  /// In en, this message translates to:
  /// **'Allow upload'**
  String get adminAllowUploadTitle;

  /// Permission toggle: allow user to use server audio (add-user dialog).
  ///
  /// In en, this message translates to:
  /// **'Allow server audio'**
  String get adminAllowServerAudioTitle;

  /// Create button confirming creation dialogs (user, backup destination).
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get adminCreate;

  /// Message shown in the library-access editor when no libraries exist.
  ///
  /// In en, this message translates to:
  /// **'No libraries configured.'**
  String get adminNoLibrariesConfigured;

  /// Field label for entering a new password in the set-password dialog.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get adminNewPasswordLabel;

  /// Card title and field label for a library (Database view, backup destination dialog).
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get adminLibraryTitle;

  /// Info row label showing the number of tracks stored in the database.
  ///
  /// In en, this message translates to:
  /// **'Tracks in database'**
  String get adminTracksInDatabase;

  /// Button to start scanning all libraries.
  ///
  /// In en, this message translates to:
  /// **'Scan all'**
  String get adminScanAllButton;

  /// Toast confirming a library scan has started.
  ///
  /// In en, this message translates to:
  /// **'Scan started'**
  String get adminScanStarted;

  /// Button to force a full rescan of all libraries.
  ///
  /// In en, this message translates to:
  /// **'Force rescan'**
  String get adminForceRescan;

  /// Toast confirming a forced full rescan has started.
  ///
  /// In en, this message translates to:
  /// **'Full rescan started'**
  String get adminFullRescanStarted;

  /// Button to start compressing stored images.
  ///
  /// In en, this message translates to:
  /// **'Compress images'**
  String get adminCompressImages;

  /// Toast confirming image compression has started.
  ///
  /// In en, this message translates to:
  /// **'Image compression started'**
  String get adminImageCompressionStarted;

  /// Card title for the scan options section.
  ///
  /// In en, this message translates to:
  /// **'Scan options'**
  String get adminScanOptions;

  /// Field label for the automatic scan interval in hours.
  ///
  /// In en, this message translates to:
  /// **'Scan interval (hours, 0 = off)'**
  String get adminScanInterval;

  /// Field label for the delay before the boot-time scan.
  ///
  /// In en, this message translates to:
  /// **'Boot scan delay (seconds)'**
  String get adminBootScanDelay;

  /// Field label for how often the scanner commits to the database.
  ///
  /// In en, this message translates to:
  /// **'Scan commit interval (1–1000)'**
  String get adminScanCommitInterval;

  /// Field label for the number of scanner threads.
  ///
  /// In en, this message translates to:
  /// **'Scan threads (0 = auto)'**
  String get adminScanThreads;

  /// Toggle title to skip extracting embedded images during scan.
  ///
  /// In en, this message translates to:
  /// **'Skip image extraction'**
  String get adminSkipImageExtraction;

  /// Toggle title to compress embedded images during scan.
  ///
  /// In en, this message translates to:
  /// **'Compress embedded images'**
  String get adminCompressEmbeddedImages;

  /// Toggle title to generate waveforms after a scan completes.
  ///
  /// In en, this message translates to:
  /// **'Generate waveforms after scan'**
  String get adminGenerateWaveforms;

  /// Toggle title for deprecated BPM/key analysis (currently does nothing).
  ///
  /// In en, this message translates to:
  /// **'Analyze BPM/key (deprecated, no-op)'**
  String get adminAnalyzeBpm;

  /// Card title for the automatic album art section.
  ///
  /// In en, this message translates to:
  /// **'Automatic album art'**
  String get adminAutomaticAlbumArt;

  /// Toggle title to auto-download missing album art.
  ///
  /// In en, this message translates to:
  /// **'Download missing album art'**
  String get adminDownloadMissingAlbumArt;

  /// Field label for the album-art download target scope.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get adminTargetLabel;

  /// Dropdown option to fetch art only for albums missing it.
  ///
  /// In en, this message translates to:
  /// **'Missing only'**
  String get adminMissingOnly;

  /// Dropdown option to fetch art for all albums.
  ///
  /// In en, this message translates to:
  /// **'All albums'**
  String get adminAllAlbums;

  /// Field label for how many albums to process per art-download run.
  ///
  /// In en, this message translates to:
  /// **'Albums per run (1–10000)'**
  String get adminAlbumsPerRun;

  /// Toggle title to write auto-downloaded art into the album folder.
  ///
  /// In en, this message translates to:
  /// **'Auto-downloaded art → write into folder'**
  String get adminAutoDownloadedArtWriteFolder;

  /// Toggle title to write manually set art into the album folder.
  ///
  /// In en, this message translates to:
  /// **'Manual set-art → write into folder'**
  String get adminManualArtWriteFolder;

  /// Toggle title to embed manually set art into the file's tags.
  ///
  /// In en, this message translates to:
  /// **'Manual set-art → embed into file tag'**
  String get adminManualArtEmbedTag;

  /// Section label for configuring album-art lookup services.
  ///
  /// In en, this message translates to:
  /// **'Art services'**
  String get adminArtServices;

  /// Toast confirming art-service settings were saved.
  ///
  /// In en, this message translates to:
  /// **'Art services updated'**
  String get adminArtServicesUpdated;

  /// Card title for the shared playlists management section.
  ///
  /// In en, this message translates to:
  /// **'Shared playlists'**
  String get adminSharedPlaylists;

  /// Button to delete expired shared playlists.
  ///
  /// In en, this message translates to:
  /// **'Delete expired'**
  String get adminDeleteExpired;

  /// Toast confirming expired shared playlists were deleted.
  ///
  /// In en, this message translates to:
  /// **'Expired shares deleted'**
  String get adminExpiredSharesDeleted;

  /// Button to delete shared playlists that never expire.
  ///
  /// In en, this message translates to:
  /// **'Delete never-expiring'**
  String get adminDeleteNeverExpiring;

  /// Toast confirming never-expiring shared playlists were deleted.
  ///
  /// In en, this message translates to:
  /// **'Eternal shares deleted'**
  String get adminEternalSharesDeleted;

  /// Empty-state message when there are no shared playlists.
  ///
  /// In en, this message translates to:
  /// **'No shared playlists'**
  String get adminNoSharedPlaylists;

  /// Subtitle for a shared playlist row: owner, track count, and expiry.
  ///
  /// In en, this message translates to:
  /// **'by {user} · {count} tracks · expires {expiry}'**
  String adminSharedPlaylistSubtitle(String user, int count, String expiry);

  /// Toast confirming a single shared playlist was deleted.
  ///
  /// In en, this message translates to:
  /// **'Share deleted'**
  String get adminShareDeleted;

  /// Card title for the network settings section.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get adminNetwork;

  /// Subtitle warning that network setting changes restart the server.
  ///
  /// In en, this message translates to:
  /// **'Changing these soft-reboots the server.'**
  String get adminNetworkSubtitle;

  /// Field/info label for the server bind address.
  ///
  /// In en, this message translates to:
  /// **'Bind address'**
  String get adminBindAddress;

  /// Field label for a network port (settings, DLNA, Subsonic).
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get adminPort;

  /// Toggle title to trust X-Forwarded-* proxy headers.
  ///
  /// In en, this message translates to:
  /// **'Trust proxy headers'**
  String get adminTrustProxyHeaders;

  /// Subtitle explaining when to enable trusting proxy headers.
  ///
  /// In en, this message translates to:
  /// **'Enable when behind a reverse proxy (X-Forwarded-*)'**
  String get adminTrustProxyHeadersSubtitle;

  /// Card title for the permissions section.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get adminPermissions;

  /// Toggle title for the server-wide allow-uploads permission.
  ///
  /// In en, this message translates to:
  /// **'Allow uploads'**
  String get adminAllowUploads;

  /// Toggle title for the server-wide allow-make-directories permission.
  ///
  /// In en, this message translates to:
  /// **'Allow making directories'**
  String get adminAllowMakingDirectories;

  /// Toggle title for the server-wide allow-modify-files permission.
  ///
  /// In en, this message translates to:
  /// **'Allow modifying files'**
  String get adminAllowModifyingFiles;

  /// Field/info label for the maximum request body size.
  ///
  /// In en, this message translates to:
  /// **'Max request size'**
  String get adminMaxRequestSize;

  /// Helper text giving examples of max request size values.
  ///
  /// In en, this message translates to:
  /// **'e.g. 50MB or 512KB'**
  String get adminMaxRequestSizeHelper;

  /// Card title for the HTTP and UI settings section.
  ///
  /// In en, this message translates to:
  /// **'HTTP & UI'**
  String get adminHttpUi;

  /// Field label for the HTTP response compression mode.
  ///
  /// In en, this message translates to:
  /// **'Response compression'**
  String get adminResponseCompression;

  /// Dropdown option: no response compression.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get adminCompressionNone;

  /// Dropdown option for gzip compression (codec token, not translated).
  ///
  /// In en, this message translates to:
  /// **'gzip'**
  String get adminCompressionGzip;

  /// Dropdown option for brotli compression (codec token, not translated).
  ///
  /// In en, this message translates to:
  /// **'brotli'**
  String get adminCompressionBrotli;

  /// Field label for selecting the served web UI.
  ///
  /// In en, this message translates to:
  /// **'Web UI'**
  String get adminWebUi;

  /// Dropdown option for the default web UI.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get adminUiDefault;

  /// Dropdown option for the Velvet web UI (brand name, not translated).
  ///
  /// In en, this message translates to:
  /// **'Velvet'**
  String get adminUiVelvet;

  /// Dropdown option for the Subsonic web UI (brand name, not translated).
  ///
  /// In en, this message translates to:
  /// **'Subsonic'**
  String get adminUiSubsonic;

  /// Card title for the database tuning section.
  ///
  /// In en, this message translates to:
  /// **'Database tuning'**
  String get adminDatabaseTuning;

  /// Field label for the SQLite synchronous pragma setting.
  ///
  /// In en, this message translates to:
  /// **'SQLite synchronous'**
  String get adminSqliteSynchronous;

  /// Dropdown option: SQLite synchronous=FULL (safest). FULL is a SQLite token; surrounding text is translatable.
  ///
  /// In en, this message translates to:
  /// **'FULL (safest)'**
  String get adminSyncFull;

  /// Dropdown option: SQLite synchronous=NORMAL (faster). NORMAL is a SQLite token; surrounding text is translatable.
  ///
  /// In en, this message translates to:
  /// **'NORMAL (faster)'**
  String get adminSyncNormal;

  /// Field label for the SQLite cache size in megabytes.
  ///
  /// In en, this message translates to:
  /// **'Cache size (MB, 1–2048)'**
  String get adminCacheSize;

  /// Card title for the logging settings section.
  ///
  /// In en, this message translates to:
  /// **'Logging'**
  String get adminLogging;

  /// Toggle title to persist logs to disk.
  ///
  /// In en, this message translates to:
  /// **'Write logs to disk'**
  String get adminWriteLogsToDisk;

  /// Field label for the in-memory log buffer size.
  ///
  /// In en, this message translates to:
  /// **'Log buffer size (0–10000, 0 = disabled)'**
  String get adminLogBufferSize;

  /// Card title for the server audio (Rust player) section.
  ///
  /// In en, this message translates to:
  /// **'Server audio'**
  String get adminServerAudio;

  /// Toggle title to auto-start the Rust server-audio player.
  ///
  /// In en, this message translates to:
  /// **'Auto-boot server audio (Rust player)'**
  String get adminAutoBootServerAudio;

  /// Field label for the Rust player's network port.
  ///
  /// In en, this message translates to:
  /// **'Rust player port'**
  String get adminRustPlayerPort;

  /// Info row label showing the active server-audio backend.
  ///
  /// In en, this message translates to:
  /// **'Active backend'**
  String get adminActiveBackend;

  /// Info row label showing the active player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get adminPlayer;

  /// Info row label listing detected command-line players.
  ///
  /// In en, this message translates to:
  /// **'Detected CLI players'**
  String get adminDetectedCliPlayers;

  /// Lowercase placeholder shown when no CLI players are detected.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get adminNone;

  /// Button to re-probe for available CLI players.
  ///
  /// In en, this message translates to:
  /// **'Re-detect players'**
  String get adminReDetectPlayers;

  /// Toast confirming CLI players were re-probed.
  ///
  /// In en, this message translates to:
  /// **'Re-probed CLI players'**
  String get adminReProbedCliPlayers;

  /// Card title for the SSL/HTTPS settings section.
  ///
  /// In en, this message translates to:
  /// **'SSL / HTTPS'**
  String get adminSslHttps;

  /// Status pill/value indicating a feature is enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminEnabled;

  /// Status pill/value indicating a feature is disabled; also a dropdown option (SSL, Subsonic).
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminDisabled;

  /// Button to replace the existing SSL certificate.
  ///
  /// In en, this message translates to:
  /// **'Replace certificate'**
  String get adminReplaceCertificate;

  /// Button to set an SSL certificate when none exists.
  ///
  /// In en, this message translates to:
  /// **'Set certificate'**
  String get adminSetCertificate;

  /// Title of the set-SSL-certificate dialog.
  ///
  /// In en, this message translates to:
  /// **'Set SSL certificate'**
  String get adminSetSslCertificateDialog;

  /// Field label for the SSL certificate file path.
  ///
  /// In en, this message translates to:
  /// **'Certificate path'**
  String get adminCertificatePath;

  /// Field label for the SSL private key file path.
  ///
  /// In en, this message translates to:
  /// **'Key path'**
  String get adminKeyPath;

  /// Toast confirming SSL was configured and a reboot is needed.
  ///
  /// In en, this message translates to:
  /// **'SSL configured — reboot to apply'**
  String get adminSslConfigured;

  /// Button to remove the configured SSL certificate.
  ///
  /// In en, this message translates to:
  /// **'Remove SSL'**
  String get adminRemoveSsl;

  /// Toast confirming SSL configuration was removed.
  ///
  /// In en, this message translates to:
  /// **'SSL removed'**
  String get adminSslRemoved;

  /// Card title for the security settings section.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get adminSecurity;

  /// Info row label showing the last 4 characters of the JWT secret.
  ///
  /// In en, this message translates to:
  /// **'JWT secret (last 4)'**
  String get adminJwtSecretLast4;

  /// Button to regenerate the JWT signing secret.
  ///
  /// In en, this message translates to:
  /// **'Regenerate secret'**
  String get adminRegenerateSecret;

  /// Toast confirming the JWT secret was regenerated and sessions invalidated.
  ///
  /// In en, this message translates to:
  /// **'Secret regenerated — all sessions invalidated'**
  String get adminSecretRegenerated;

  /// Confirmation dialog title for regenerating the JWT secret.
  ///
  /// In en, this message translates to:
  /// **'Regenerate JWT secret?'**
  String get adminRegenerateJwtSecretDialog;

  /// Warning body in the regenerate-JWT-secret confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This invalidates every existing login (including this one). Everyone must sign in again.'**
  String get adminRegenerateJwtSecretDialogBody;

  /// Confirm button in the regenerate-JWT-secret dialog.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get adminRegenerateButton;

  /// Dropdown option: admin API reachable from all networks.
  ///
  /// In en, this message translates to:
  /// **'All networks'**
  String get adminAllNetworks;

  /// Dropdown option: admin API reachable from localhost only.
  ///
  /// In en, this message translates to:
  /// **'Localhost only'**
  String get adminLocalhostOnly;

  /// Dropdown option: admin API restricted to a whitelist of IPs.
  ///
  /// In en, this message translates to:
  /// **'IP whitelist'**
  String get adminIpWhitelist;

  /// Dropdown option: lock the admin API entirely.
  ///
  /// In en, this message translates to:
  /// **'None (lock admin)'**
  String get adminNoneLockAdmin;

  /// Card title for the admin network access section.
  ///
  /// In en, this message translates to:
  /// **'Network access'**
  String get adminNetworkAccess;

  /// Subtitle for the admin network access section.
  ///
  /// In en, this message translates to:
  /// **'Restrict which networks may reach the admin API.'**
  String get adminNetworkAccessSubtitle;

  /// Field label for selecting an access/operation mode (admin access, DLNA, Subsonic).
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get adminMode;

  /// Section label for the list of whitelisted IP addresses and CIDR ranges.
  ///
  /// In en, this message translates to:
  /// **'Whitelisted IPs / CIDRs'**
  String get adminWhitelistedIps;

  /// Empty-state text when no IPs/CIDRs have been whitelisted.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get adminNoneYet;

  /// Field label for adding an IP address or CIDR range to the whitelist.
  ///
  /// In en, this message translates to:
  /// **'Add IP or CIDR'**
  String get adminAddIpOrCidr;

  /// Example CIDR hint text in the add-IP field (literal example, not translated).
  ///
  /// In en, this message translates to:
  /// **'192.168.1.0/24'**
  String get adminCidrExample;

  /// Button to apply whitelist changes.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get adminApply;

  /// Card title for destructive admin-access actions.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get adminDangerZone;

  /// Action title to disable the entire admin API.
  ///
  /// In en, this message translates to:
  /// **'Lock admin API'**
  String get adminLockAdminApi;

  /// Subtitle warning about locking the admin API.
  ///
  /// In en, this message translates to:
  /// **'Disable the entire admin API. Cannot be undone from here.'**
  String get adminLockAdminApiSubtitle;

  /// Button to confirm locking the admin API.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get adminLockButton;

  /// Confirmation dialog title for locking the admin API.
  ///
  /// In en, this message translates to:
  /// **'Lock the admin API?'**
  String get adminLockAdminApiDialog;

  /// Warning body in the lock-admin-API confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This disables the entire /admin API for everyone. You will not be able to undo it from this panel — it requires editing the server config file and restarting. Continue?'**
  String get adminLockAdminApiDialogBody;

  /// Toast confirming the admin API was locked.
  ///
  /// In en, this message translates to:
  /// **'Admin API locked'**
  String get adminAdminApiLocked;

  /// Toast confirming admin network-access settings were saved.
  ///
  /// In en, this message translates to:
  /// **'Admin access updated'**
  String get adminAccessUpdated;

  /// Card title for the FFmpeg transcoding section.
  ///
  /// In en, this message translates to:
  /// **'FFmpeg'**
  String get adminTranscodingFFmpegTitle;

  /// Status pill indicating ffmpeg is downloaded and ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get adminFFmpegStatusReady;

  /// Status pill indicating ffmpeg has not been downloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get adminFFmpegStatusNotDownloaded;

  /// Button to download or update the bundled ffmpeg binary.
  ///
  /// In en, this message translates to:
  /// **'Download / update ffmpeg'**
  String get adminFFmpegDownloadButton;

  /// Toast confirming ffmpeg was downloaded.
  ///
  /// In en, this message translates to:
  /// **'ffmpeg downloaded'**
  String get adminFFmpegDownloadedToast;

  /// Toggle title to keep ffmpeg updated automatically.
  ///
  /// In en, this message translates to:
  /// **'Auto-update ffmpeg'**
  String get adminFFmpegAutoUpdateTitle;

  /// Subtitle for the ffmpeg auto-update toggle.
  ///
  /// In en, this message translates to:
  /// **'Keep the bundled ffmpeg up to date automatically'**
  String get adminFFmpegAutoUpdateSubtitle;

  /// Card title for the default transcoding settings section.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get adminTranscodingDefaultsTitle;

  /// Field label for the default transcoding codec.
  ///
  /// In en, this message translates to:
  /// **'Default codec'**
  String get adminDefaultCodecLabel;

  /// Field label for the default transcoding bitrate.
  ///
  /// In en, this message translates to:
  /// **'Default bitrate'**
  String get adminDefaultBitrateLabel;

  /// Button to resume the live log stream.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get adminLogsResumeButton;

  /// Button to pause the live log stream.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get adminLogsPauseButton;

  /// Button to clear a list (log entries, token-auth failures).
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adminClear;

  /// Toggle title for auto-scrolling the log view.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll'**
  String get adminLogsAutoScrollTitle;

  /// Count of log lines currently shown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String adminLogsLineCount(int count);

  /// Button to download logs as a zip file.
  ///
  /// In en, this message translates to:
  /// **'Download zip'**
  String get adminLogsDownloadZipButton;

  /// Empty-state hint when the log view has no entries.
  ///
  /// In en, this message translates to:
  /// **'No log entries yet'**
  String get adminLogsNoEntriesHint;

  /// DLNA mode dropdown option: DLNA disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminDlnaModeDisabled;

  /// Mode dropdown option: serve on the same port as HTTP (DLNA, Subsonic).
  ///
  /// In en, this message translates to:
  /// **'Same port as HTTP'**
  String get adminSamePortAsHttp;

  /// Mode dropdown option: serve on a separate port (DLNA, Subsonic).
  ///
  /// In en, this message translates to:
  /// **'Separate port'**
  String get adminSeparatePort;

  /// DLNA browse layout option: flat list of all tracks.
  ///
  /// In en, this message translates to:
  /// **'Flat (all tracks)'**
  String get adminDlnaBrowseFlat;

  /// DLNA browse layout option: browse by directory structure.
  ///
  /// In en, this message translates to:
  /// **'Directories'**
  String get adminDlnaBrowseDirectories;

  /// DLNA browse layout option: browse by artist.
  ///
  /// In en, this message translates to:
  /// **'By artist'**
  String get adminDlnaBrowseArtist;

  /// DLNA browse layout option: browse by album.
  ///
  /// In en, this message translates to:
  /// **'By album'**
  String get adminDlnaBrowseAlbum;

  /// DLNA browse layout option: browse by genre.
  ///
  /// In en, this message translates to:
  /// **'By genre'**
  String get adminDlnaBrowseGenre;

  /// Card title for the DLNA server settings.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get adminDlnaServerTitle;

  /// Card title for the DLNA device identity settings.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get adminDlnaIdentityTitle;

  /// Field label for the DLNA device friendly name.
  ///
  /// In en, this message translates to:
  /// **'Friendly name'**
  String get adminDlnaFriendlyNameLabel;

  /// Field label for the DLNA device UUID.
  ///
  /// In en, this message translates to:
  /// **'Device UUID'**
  String get adminDlnaDeviceUuidLabel;

  /// Helper text describing the DLNA device UUID format.
  ///
  /// In en, this message translates to:
  /// **'Canonical GUID'**
  String get adminDlnaDeviceUuidHelper;

  /// Card title for the DLNA browse layout settings.
  ///
  /// In en, this message translates to:
  /// **'Browse layout'**
  String get adminDlnaBrowseLayoutTitle;

  /// Field label for the DLNA browse structure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get adminDlnaStructureLabel;

  /// Card title for the mDNS local network discovery section.
  ///
  /// In en, this message translates to:
  /// **'Local network discovery'**
  String get adminMdnsLocalNetworkDiscoveryTitle;

  /// Subtitle explaining what mDNS advertising does.
  ///
  /// In en, this message translates to:
  /// **'Advertises this server as an _mstream._tcp mDNS service. Publishes metadata only — exposes no library data or new routes.'**
  String get adminMdnsLocalNetworkDiscoverySubtitle;

  /// Toggle title to enable mDNS advertising.
  ///
  /// In en, this message translates to:
  /// **'Enable advertising'**
  String get adminMdnsEnableAdvertisingTitle;

  /// Field label for the mDNS friendly name.
  ///
  /// In en, this message translates to:
  /// **'Friendly name'**
  String get adminMdnsFriendlyNameLabel;

  /// Helper text for the mDNS friendly name field.
  ///
  /// In en, this message translates to:
  /// **'Empty = derive from hostname (max 63 bytes)'**
  String get adminMdnsFriendlyNameHelper;

  /// Info row label showing the mDNS instance ID.
  ///
  /// In en, this message translates to:
  /// **'Instance ID'**
  String get adminMdnsInstanceIdLabel;

  /// Card title for the Subsonic API settings.
  ///
  /// In en, this message translates to:
  /// **'Subsonic API'**
  String get adminSubsonicApiTitle;

  /// Button to test the Subsonic API connection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get adminTestConnection;

  /// Toast on successful Subsonic connection test: version and latency.
  ///
  /// In en, this message translates to:
  /// **'OK · {version} · {latency}ms'**
  String adminSubsonicTestSuccess(String version, String latency);

  /// Toast when the Subsonic connection test fails; {reason} is the failure reason.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String adminSubsonicTestFailed(String reason);

  /// Card title for a status section (Subsonic).
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminStatus;

  /// Info row label for the count of implemented Subsonic API methods.
  ///
  /// In en, this message translates to:
  /// **'Methods implemented'**
  String get adminMethodsImplemented;

  /// Info row label distinguishing fully-implemented vs stubbed methods.
  ///
  /// In en, this message translates to:
  /// **'Full / stub'**
  String get adminFullStub;

  /// Group header for the Subsonic now-playing list.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get adminNowPlaying;

  /// Placeholder shown when no one is currently playing.
  ///
  /// In en, this message translates to:
  /// **'nobody'**
  String get adminNobody;

  /// Group header for the LRCLib lyrics settings (LRCLib is a service name).
  ///
  /// In en, this message translates to:
  /// **'Lyrics (LRCLib)'**
  String get adminLyricsLrclib;

  /// Toggle title to use LRCLib as a lyrics fallback.
  ///
  /// In en, this message translates to:
  /// **'LRCLib fallback'**
  String get adminLrclibFallback;

  /// Toggle title to write .lrc sidecar lyric files.
  ///
  /// In en, this message translates to:
  /// **'Write .lrc sidecar files'**
  String get adminWriteLrcSidecarFiles;

  /// Info row label for the lyrics cache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get adminCache;

  /// Button to purge the lyrics cache.
  ///
  /// In en, this message translates to:
  /// **'Purge cache'**
  String get adminPurgeCache;

  /// Toast confirming the lyrics cache was purged.
  ///
  /// In en, this message translates to:
  /// **'Lyrics cache purged'**
  String get adminLyricsCachePurged;

  /// Button to retry failed lyrics lookups.
  ///
  /// In en, this message translates to:
  /// **'Retry failed'**
  String get adminRetryFailed;

  /// Toast confirming transient lyrics cache entries were cleared.
  ///
  /// In en, this message translates to:
  /// **'Transient lyrics entries cleared'**
  String get adminTransientLyricsEntriesCleared;

  /// Card title for the Subsonic jukebox section.
  ///
  /// In en, this message translates to:
  /// **'Jukebox'**
  String get adminJukebox;

  /// Status pill indicating the jukebox is available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get adminAvailable;

  /// Status pill indicating the jukebox is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get adminUnavailable;

  /// Info row label for the jukebox playback state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get adminState;

  /// Jukebox state value: playing.
  ///
  /// In en, this message translates to:
  /// **'playing'**
  String get adminPlaying;

  /// Jukebox state value: paused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get adminPaused;

  /// Jukebox state value: idle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get adminIdle;

  /// Info row label for the jukebox current track.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get adminCurrent;

  /// Info row label for the jukebox queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get adminQueue;

  /// Number of tracks in the jukebox queue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String adminQueueTracks(int count);

  /// Info row label for the jukebox volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get adminVolume;

  /// Jukebox volume shown as a percentage.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String adminVolumePercent(int percent);

  /// Card title for the Subsonic token-auth failures section.
  ///
  /// In en, this message translates to:
  /// **'Token-auth failures'**
  String get adminTokenAuthFailures;

  /// Subtitle explaining the token-auth failures list.
  ///
  /// In en, this message translates to:
  /// **'Clients defaulting to token auth without a Subsonic password.'**
  String get adminTokenAuthFailuresSubtitle;

  /// Empty-state text when there are no recent token-auth failures.
  ///
  /// In en, this message translates to:
  /// **'No recent failures'**
  String get adminNoRecentFailures;

  /// Toast confirming the token-auth failures list was cleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get adminCleared;

  /// Card title for minting a Subsonic API key.
  ///
  /// In en, this message translates to:
  /// **'Mint API key'**
  String get adminMintApiKey;

  /// Subtitle for the mint-API-key section.
  ///
  /// In en, this message translates to:
  /// **'Generate a Subsonic apiKey for a user (shown once).'**
  String get adminMintApiKeySubtitle;

  /// Field label for the name/label of a minted API key.
  ///
  /// In en, this message translates to:
  /// **'Key name / label'**
  String get adminKeyNameLabel;

  /// Button to mint a new Subsonic API key.
  ///
  /// In en, this message translates to:
  /// **'Mint key'**
  String get adminMintKey;

  /// Validation toast when minting a key without a username or key name.
  ///
  /// In en, this message translates to:
  /// **'Username and name required'**
  String get adminUsernameAndNameRequired;

  /// Card title for the torrent client configuration.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get adminTorrentClient;

  /// Field label for selecting the active torrent client.
  ///
  /// In en, this message translates to:
  /// **'Active client'**
  String get adminActiveClient;

  /// Torrent client dropdown option (product name, not translated).
  ///
  /// In en, this message translates to:
  /// **'Transmission'**
  String get adminTransmission;

  /// Torrent client dropdown option (product name, not translated).
  ///
  /// In en, this message translates to:
  /// **'qBittorrent'**
  String get adminQbittorrent;

  /// Torrent client dropdown option (product name, not translated).
  ///
  /// In en, this message translates to:
  /// **'Deluge'**
  String get adminDeluge;

  /// Field label for which users the torrent feature is enabled for.
  ///
  /// In en, this message translates to:
  /// **'Enabled for'**
  String get adminEnabledFor;

  /// Dropdown option: torrent feature enabled for all users.
  ///
  /// In en, this message translates to:
  /// **'All users'**
  String get adminAllUsers;

  /// Dropdown option: torrent feature enabled for whitelisted users only.
  ///
  /// In en, this message translates to:
  /// **'Whitelisted users'**
  String get adminWhitelistedUsers;

  /// Field label for the torrent daemon host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get adminHost;

  /// Helper text indicating a blank password field keeps the existing value.
  ///
  /// In en, this message translates to:
  /// **'unchanged if blank'**
  String get adminPasswordUnchangedIfBlank;

  /// Field label for the torrent daemon RPC path.
  ///
  /// In en, this message translates to:
  /// **'RPC path'**
  String get adminRpcPath;

  /// Toggle title to use HTTPS for the torrent daemon connection.
  ///
  /// In en, this message translates to:
  /// **'Use HTTPS'**
  String get adminUseHttps;

  /// Button to test the torrent daemon connection.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get adminTest;

  /// Toast when the torrent daemon is reachable; {version} is an optional version suffix already including parentheses/space.
  ///
  /// In en, this message translates to:
  /// **'Reachable{version}'**
  String adminReachable(String version);

  /// Toast when a torrent daemon connection test fails; {error} is the error message.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String adminConnectionFailed(String error);

  /// Button to connect to the torrent daemon and save the configuration.
  ///
  /// In en, this message translates to:
  /// **'Connect & save'**
  String get adminConnectAndSave;

  /// Toast when saving the torrent configuration fails; {error} is the error message.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String adminSaveFailed(String error);

  /// Toast confirming the torrent daemon connected and config was saved.
  ///
  /// In en, this message translates to:
  /// **'Connected & saved'**
  String get adminConnectedAndSaved;

  /// Button to disconnect from the torrent daemon.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get adminDisconnect;

  /// Toast confirming disconnect, and status pill indicating disconnected state.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get adminDisconnected;

  /// Status pill indicating the torrent client is configured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get adminConfigured;

  /// Status pill indicating the torrent client is not configured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get adminNotConfigured;

  /// Card title for the list of active torrents.
  ///
  /// In en, this message translates to:
  /// **'Torrents'**
  String get adminTorrents;

  /// Status pill indicating the torrent client is connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get adminConnected;

  /// Empty-state text when there are no active torrents.
  ///
  /// In en, this message translates to:
  /// **'No torrents'**
  String get adminNoTorrents;

  /// Status pill marking a torrent as managed by mStream (brand name, not translated).
  ///
  /// In en, this message translates to:
  /// **'mStream'**
  String get adminMstream;

  /// Toast confirming a torrent was removed.
  ///
  /// In en, this message translates to:
  /// **'Torrent removed'**
  String get adminTorrentRemoved;

  /// Card title for mapping library paths to torrent daemon paths.
  ///
  /// In en, this message translates to:
  /// **'Library → daemon path mapping'**
  String get adminLibraryDaemonPathMapping;

  /// Subtitle explaining the library-to-daemon path mapping.
  ///
  /// In en, this message translates to:
  /// **'Maps each library to its path as the torrent daemon sees it.'**
  String get adminLibraryDaemonPathMappingSubtitle;

  /// Button to auto-detect daemon paths for all libraries.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect all'**
  String get adminAutoDetectAll;

  /// Toast confirming daemon path auto-detection finished.
  ///
  /// In en, this message translates to:
  /// **'Auto-detection complete'**
  String get adminAutoDetectionComplete;

  /// Status pill indicating a daemon path mapping is verified.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get adminVerified;

  /// Status pill indicating a daemon path mapping is unverified.
  ///
  /// In en, this message translates to:
  /// **'unverified'**
  String get adminUnverified;

  /// Button to set a daemon path mapping manually.
  ///
  /// In en, this message translates to:
  /// **'Set manually'**
  String get adminSetManually;

  /// Dialog title for entering the daemon path of a specific library; {name} is the library name.
  ///
  /// In en, this message translates to:
  /// **'Daemon path for \"{name}\"'**
  String adminDaemonPathFor(String name);

  /// Field label for the library path as seen on the torrent daemon host.
  ///
  /// In en, this message translates to:
  /// **'Path on daemon host'**
  String get adminPathOnDaemonHost;

  /// Button to verify and save a daemon path mapping.
  ///
  /// In en, this message translates to:
  /// **'Verify & save'**
  String get adminVerifyAndSave;

  /// Toast confirming a daemon path mapping was verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get adminVpathVerified;

  /// Toast confirming a daemon path mapping was saved without verification.
  ///
  /// In en, this message translates to:
  /// **'Saved (unverified)'**
  String get adminVpathSavedUnverified;

  /// Card title for torrent download path templates.
  ///
  /// In en, this message translates to:
  /// **'Download path templates'**
  String get adminDownloadPathTemplates;

  /// Subtitle listing the variables available in download path templates.
  ///
  /// In en, this message translates to:
  /// **'Vars: {vars}'**
  String adminPathTemplateVars(String vars);

  /// Empty-state text when there are no libraries to configure path templates for.
  ///
  /// In en, this message translates to:
  /// **'No libraries'**
  String get adminNoLibraries;

  /// Helper text suggesting a download path template; {template} is the suggested value.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {template}'**
  String adminSuggestedTemplate(String template);

  /// Toast confirming a download path template was saved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get adminTemplateSaved;

  /// Empty-state title when no backup destinations are configured.
  ///
  /// In en, this message translates to:
  /// **'No backup destinations'**
  String get adminNoBackupDestinations;

  /// Empty-state hint for backup destinations.
  ///
  /// In en, this message translates to:
  /// **'Add a destination to mirror a library to another folder.'**
  String get adminBackupDestinationInfo;

  /// Button to add a backup destination.
  ///
  /// In en, this message translates to:
  /// **'Add destination'**
  String get adminAddDestination;

  /// Toast shown when trying to add a backup destination with no libraries.
  ///
  /// In en, this message translates to:
  /// **'Add a library first'**
  String get adminAddLibraryFirst;

  /// Card title for the backup task queue.
  ///
  /// In en, this message translates to:
  /// **'Backup queue'**
  String get adminBackupQueue;

  /// Number of backup tasks currently queued.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task queued} other{{count} tasks queued}}'**
  String adminTasksQueued(int count);

  /// Card title shown while a backup is running; {library} is the library name.
  ///
  /// In en, this message translates to:
  /// **'Backing up: {library}'**
  String adminBackingUp(String library);

  /// Status pill indicating a backup is currently running.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get adminRunning;

  /// Progress line for a running backup: files done, optional total suffix, and optional stats suffix.
  ///
  /// In en, this message translates to:
  /// **'{done} files{total}{stats}'**
  String adminBackupStats(int done, String total, String stats);

  /// Status pill indicating a backup destination is disabled.
  ///
  /// In en, this message translates to:
  /// **'disabled'**
  String get adminBackupDisabled;

  /// Info row label for a backup destination path.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get adminDestination;

  /// Info row label for a backup destination's trigger.
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get adminTrigger;

  /// Display of a daily backup trigger and its hour; {trigger} is the trigger type, {hour} the hour.
  ///
  /// In en, this message translates to:
  /// **'{trigger} @ {hour}:00'**
  String adminDailyTriggerTime(String trigger, String hour);

  /// Info row label for a backup destination's retention policy.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get adminRetention;

  /// Backup retention period in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String adminRetentionDays(int count);

  /// Info row label for a backup destination's last run.
  ///
  /// In en, this message translates to:
  /// **'Last run'**
  String get adminLastRun;

  /// Summary of a backup's last run: status and number of files copied.
  ///
  /// In en, this message translates to:
  /// **'{status} · {files} copied'**
  String adminLastRunStatus(String status, int files);

  /// Button to run a backup destination immediately.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get adminRunNow;

  /// Toast confirming a backup was queued.
  ///
  /// In en, this message translates to:
  /// **'Backup queued'**
  String get adminBackupQueued;

  /// Toast shown when a backup is already running and the request was skipped.
  ///
  /// In en, this message translates to:
  /// **'Already running — skipped'**
  String get adminAlreadyRunningSkipped;

  /// Button to view a backup destination's run history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get adminHistory;

  /// Button to edit a backup destination.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminEdit;

  /// Toast confirming a backup destination was deleted.
  ///
  /// In en, this message translates to:
  /// **'Destination deleted'**
  String get adminDestinationDeleted;

  /// Dialog title showing a backup destination's run history.
  ///
  /// In en, this message translates to:
  /// **'Backup history'**
  String get adminBackupHistory;

  /// Empty-state text when a backup destination has no run history.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get adminNoHistoryYet;

  /// Title of the edit-backup-destination dialog.
  ///
  /// In en, this message translates to:
  /// **'Edit destination'**
  String get adminEditDestination;

  /// Title of the add-backup-destination dialog.
  ///
  /// In en, this message translates to:
  /// **'Add backup destination'**
  String get adminAddBackupDestination;

  /// Field label for the backup destination folder path.
  ///
  /// In en, this message translates to:
  /// **'Destination path'**
  String get adminDestinationPath;

  /// Button to browse the server filesystem for a backup destination.
  ///
  /// In en, this message translates to:
  /// **'Browse server'**
  String get adminBrowseServer;

  /// Button to validate the entered backup destination path.
  ///
  /// In en, this message translates to:
  /// **'Check path'**
  String get adminCheckPath;

  /// Field label for selecting a backup trigger type in the destination dialog.
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get adminTriggerField;

  /// Backup trigger dropdown option: run after each scan.
  ///
  /// In en, this message translates to:
  /// **'After each scan'**
  String get adminAfterEachScan;

  /// Backup trigger dropdown option: run daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get adminDaily;

  /// Backup trigger dropdown option: run only when triggered manually.
  ///
  /// In en, this message translates to:
  /// **'Manual only'**
  String get adminManualOnly;

  /// Label preceding the hour selector for daily backups.
  ///
  /// In en, this message translates to:
  /// **'Run at hour: '**
  String get adminRunAtHour;

  /// Field label for the backup retention period in days.
  ///
  /// In en, this message translates to:
  /// **'Retention (days, 0 = keep all)'**
  String get adminRetentionFieldLabel;

  /// Toggle title to enable a backup destination.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminEnabledToggle;

  /// Toast confirming a backup destination was updated.
  ///
  /// In en, this message translates to:
  /// **'Destination updated'**
  String get adminDestinationUpdated;

  /// Toast confirming a backup destination was created.
  ///
  /// In en, this message translates to:
  /// **'Destination created'**
  String get adminDestinationCreated;

  /// Validation toast when saving a backup destination without choosing a library.
  ///
  /// In en, this message translates to:
  /// **'Pick a library'**
  String get adminPickLibrary;

  /// Validation toast when saving a backup destination without a path.
  ///
  /// In en, this message translates to:
  /// **'Pick a destination path'**
  String get adminPickDestinationPath;

  /// About card title showing the mStream server version (brand + version, not translated).
  ///
  /// In en, this message translates to:
  /// **'mStream v{version}'**
  String adminAboutTitle(String version);

  /// Info row label for the server port on the About view.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get adminAboutPort;

  /// Info row label for SSL status on the About view.
  ///
  /// In en, this message translates to:
  /// **'SSL'**
  String get adminSSL;

  /// Info row label for the active web UI on the About view.
  ///
  /// In en, this message translates to:
  /// **'UI'**
  String get adminUI;

  /// Info row label for the response compression mode on the About view.
  ///
  /// In en, this message translates to:
  /// **'Compression'**
  String get adminCompression;

  /// Info row label for the trust-proxy setting on the About view.
  ///
  /// In en, this message translates to:
  /// **'Trust proxy'**
  String get adminTrustProxy;

  /// Generic affirmative value used in info rows.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get adminYes;

  /// Generic negative value used in info rows.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get adminNo;

  /// Info row label showing the last 4 characters of the JWT secret on the About view.
  ///
  /// In en, this message translates to:
  /// **'Secret (last 4)'**
  String get adminSecretLast4;

  /// Info row label for the uploads permission on the About view.
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get adminUploads;

  /// Info row label for the make-directories permission on the About view.
  ///
  /// In en, this message translates to:
  /// **'Make dirs'**
  String get adminMakeDirs;

  /// Info row label for the file-modify permission on the About view.
  ///
  /// In en, this message translates to:
  /// **'File modify'**
  String get adminFileModify;

  /// Info row label for the SQLite synchronous setting on the About view.
  ///
  /// In en, this message translates to:
  /// **'Synchronous'**
  String get adminSynchronous;

  /// Info row label for the database cache size on the About view.
  ///
  /// In en, this message translates to:
  /// **'Cache size'**
  String get adminCacheSizeLabel;

  /// Database cache size shown in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String adminCacheSizeMb(int size);

  /// Status pill indicating federation is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get adminFederationUnavailable;

  /// Explanatory body text on the Federation view.
  ///
  /// In en, this message translates to:
  /// **'Federation is being rebuilt around the new local-backup story and is currently unavailable on the server. The endpoint stays mounted so older clients get a clear status instead of a 404.'**
  String get adminFederationDescription;

  /// Button to re-check federation status.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get adminCheckStatus;

  /// Permission value (About view): action is allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get adminAllowed;

  /// Backup destination status pill: enabled (lowercase).
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get adminBackupEnabled;

  /// Fallback when a jukebox/feature status is not available.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get adminNotAvailable;

  /// Torrent library→daemon path mapping: no path mapped yet.
  ///
  /// In en, this message translates to:
  /// **'not mapped'**
  String get adminNotMapped;

  /// Shared-playlist expiry value: never expires.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get adminExpiryNever;

  /// Fallback for an unknown shared-playlist owner.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get adminUnknownUser;
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
